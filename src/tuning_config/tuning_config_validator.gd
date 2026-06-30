## TuningConfigValidator — 调参配置校验器（TR-tuning-001）
## 封装 game-tuning-config.md Edge Cases 定义的全部启动时数据合法性校验。
## 纯静态函数，无实例状态，无场景树依赖，headless 可直接断言。
##
## 双函数方案（ADR-0005 + story-002 Implementation Notes）：
##   validate_dict(data)   — 接受 Dictionary（JSON 反序列化原始输入）；
##                           同时检查「必填字段缺失」(MISSING_REQUIRED_FIELD) +
##                           「值范围」（AC-TC-06 路径）
##   validate(config)      — 接受已构造的 TuningConfigData 实例；
##                           仅检查「值范围」，不检测缺失（AC-TC-17 路径）
##
## 用法示例：
##   # 从 JSON dict 校验（含缺失检查）：
##   var result: ValidationResult = TuningConfigValidator.validate_dict(parsed_dict)
##   # 从已构造对象校验（仅值范围）：
##   var result: ValidationResult = TuningConfigValidator.validate(config_data)
##   if not result.is_valid:
##       for err in result.errors:
##           push_error("[%s] %s: %s" % [err.code, err.field, err.message])
class_name TuningConfigValidator


# ── 错误码常量（AC 断言 code，不断言 message 文案）────────────────────────────

## 必填字段在 dict 中完全缺失
const MISSING_REQUIRED_FIELD := "MISSING_REQUIRED_FIELD"

## base_ATK 存在但值 < 1
const BASE_ATK_TOO_LOW := "BASE_ATK_TOO_LOW"

## base_DEF 存在但值 < 0
const BASE_DEF_NEGATIVE := "BASE_DEF_NEGATIVE"

## base_MaxHP 存在但值 < 1
const BASE_MAX_HP_TOO_LOW := "BASE_MAX_HP_TOO_LOW"

## N_max 不在 [5, 20] 范围内
const N_MAX_OUT_OF_RANGE := "N_MAX_OUT_OF_RANGE"

## HP_BUDGET_RATIO < 0.05（下界）
const HP_RATIO_TOO_LOW := "HP_RATIO_TOO_LOW"

## HP_BUDGET_RATIO > 1.0（上界）
const HP_RATIO_TOO_HIGH := "HP_RATIO_TOO_HIGH"

## BATTLE_ROUND_DURATION <= 0
const ROUND_DURATION_NON_POSITIVE := "ROUND_DURATION_NON_POSITIVE"

## floor_tuning_table 为空数组（0 行）
const EMPTY_TUNING_TABLE := "EMPTY_TUNING_TABLE"

## floor_number 非正整数（<= 0）
const FLOOR_NUMBER_NON_POSITIVE := "FLOOR_NUMBER_NON_POSITIVE"

## floor_number 在表中重复出现
const DUPLICATE_FLOOR_NUMBER := "DUPLICATE_FLOOR_NUMBER"

## player_ATK_expected < 10（D1 硬约束）
const ATK_EXPECTED_TOO_LOW := "ATK_EXPECTED_TOO_LOW"

## player_HP_expected < 1
const HP_EXPECTED_TOO_LOW := "HP_EXPECTED_TOO_LOW"

## player_DEF_expected < 0
const DEF_EXPECTED_NEGATIVE := "DEF_EXPECTED_NEGATIVE"


# ── 顶层必填字段列表（validate_dict 用于缺失检查）──────────────────────────────
const _REQUIRED_TOP_FIELDS: Array = [
	"base_atk", "base_def", "base_max_hp",
	"n_max", "hp_budget_ratio", "battle_round_duration",
	"floor_tuning_table"
]

# ── 行级必填字段列表（validate_dict 行缺失检查）────────────────────────────────
const _REQUIRED_ROW_FIELDS: Array = [
	"floor_number", "player_atk_expected",
	"player_def_expected", "player_hp_expected"
]


## validate_dict — 从 JSON 反序列化原始 Dictionary 校验（AC-TC-06 路径）
## 同时检查「必填字段缺失」和「值范围」。
## [param data] — JSON.parse_string() 返回的 Dictionary
## 返回 ValidationResult；is_valid==false 时 errors 列表含所有违规条目。
static func validate_dict(data: Dictionary) -> ValidationResult:
	var result := ValidationResult.new()

	# ── 1. 顶层必填字段缺失检查 ──────────────────────────────────────────────
	for field_name: String in _REQUIRED_TOP_FIELDS:
		if not data.has(field_name):
			# error.field 用实际 snake_case 字段名（决策：与 TuningConfigData 字段一致）
			result.add_error(
				field_name,
				MISSING_REQUIRED_FIELD,
				"必填字段缺失：%s" % field_name
			)

	# 若顶层字段有缺失，值范围检查可能引发 null 访问——直接返回
	if not result.is_valid:
		return result

	# ── 2. 顶层值范围检查（字段存在但值越界）───────────────────────────────
	_validate_top_level_values(data, result)

	# ── 3. floor_tuning_table 行级校验 ──────────────────────────────────────
	var table: Variant = data.get("floor_tuning_table")
	if table is Array:
		_validate_rows_from_array(table as Array, result)

	return result


## validate — 从已构造的 TuningConfigData 实例校验（AC-TC-17 路径）
## 仅检查「值范围」，不检查字段缺失（实例字段已有默认值，缺失语义不适用）。
## [param config] — 已构造并赋值的 TuningConfigData
## 返回 ValidationResult；is_valid==false 时 errors 列表含所有违规条目。
static func validate(config: TuningConfigData) -> ValidationResult:
	var result := ValidationResult.new()

	# ── 1. 顶层值范围检查 ────────────────────────────────────────────────────
	if config.base_atk < 1:
		result.add_error("base_atk", BASE_ATK_TOO_LOW,
			"base_ATK 必须 >= 1，当前值：%d" % config.base_atk)

	if config.base_def < 0:
		result.add_error("base_def", BASE_DEF_NEGATIVE,
			"base_DEF 必须 >= 0，当前值：%d" % config.base_def)

	if config.base_max_hp < 1:
		result.add_error("base_max_hp", BASE_MAX_HP_TOO_LOW,
			"base_MaxHP 必须 >= 1，当前值：%d" % config.base_max_hp)

	if config.n_max < 5 or config.n_max > 20:
		result.add_error("n_max", N_MAX_OUT_OF_RANGE,
			"N_max 必须在 [5, 20] 范围内，当前值：%d" % config.n_max)

	if config.hp_budget_ratio < 0.05:
		result.add_error("hp_budget_ratio", HP_RATIO_TOO_LOW,
			"HP_BUDGET_RATIO 必须 >= 0.05，当前值：%s" % str(config.hp_budget_ratio))

	if config.hp_budget_ratio > 1.0:
		result.add_error("hp_budget_ratio", HP_RATIO_TOO_HIGH,
			"HP_BUDGET_RATIO 必须 <= 1.0，当前值：%s" % str(config.hp_budget_ratio))

	if config.battle_round_duration <= 0.0:
		result.add_error("battle_round_duration", ROUND_DURATION_NON_POSITIVE,
			"BATTLE_ROUND_DURATION 必须 > 0，当前值：%s" % str(config.battle_round_duration))

	# ── 2. floor_tuning_table 行级校验 ──────────────────────────────────────
	if config.floor_tuning_table.is_empty():
		result.add_error("floor_tuning_table", EMPTY_TUNING_TABLE,
			"floor_tuning_table 不得为空")
	else:
		_validate_rows_from_instances(config.floor_tuning_table, result)

	return result


# ── 内部辅助函数 ──────────────────────────────────────────────────────────────

## 顶层值范围检查（validate_dict 内部调用；data 中所有必填字段已确认存在）
## 注：JSON.parse_string() 整数值可能为 float，int() 做截断转型（int(6.0)=6）。
## 非整数/负浮点（如 0.9→0）会被截断后再触发范围检查，行为正确但非严格整数校验。
static func _validate_top_level_values(data: Dictionary, result: ValidationResult) -> void:
	var base_atk: int = int(data["base_atk"])
	if base_atk < 1:
		result.add_error("base_atk", BASE_ATK_TOO_LOW,
			"base_ATK 必须 >= 1，当前值：%d" % base_atk)

	var base_def: int = int(data["base_def"])
	if base_def < 0:
		result.add_error("base_def", BASE_DEF_NEGATIVE,
			"base_DEF 必须 >= 0，当前值：%d" % base_def)

	var base_max_hp: int = int(data["base_max_hp"])
	if base_max_hp < 1:
		result.add_error("base_max_hp", BASE_MAX_HP_TOO_LOW,
			"base_MaxHP 必须 >= 1，当前值：%d" % base_max_hp)

	var n_max: int = int(data["n_max"])
	if n_max < 5 or n_max > 20:
		result.add_error("n_max", N_MAX_OUT_OF_RANGE,
			"N_max 必须在 [5, 20] 范围内，当前值：%d" % n_max)

	var hp_ratio: float = float(data["hp_budget_ratio"])
	if hp_ratio < 0.05:
		result.add_error("hp_budget_ratio", HP_RATIO_TOO_LOW,
			"HP_BUDGET_RATIO 必须 >= 0.05，当前值：%s" % str(hp_ratio))
	if hp_ratio > 1.0:
		result.add_error("hp_budget_ratio", HP_RATIO_TOO_HIGH,
			"HP_BUDGET_RATIO 必须 <= 1.0，当前值：%s" % str(hp_ratio))

	var duration: float = float(data["battle_round_duration"])
	if duration <= 0.0:
		result.add_error("battle_round_duration", ROUND_DURATION_NON_POSITIVE,
			"BATTLE_ROUND_DURATION 必须 > 0，当前值：%s" % str(duration))

	var table: Variant = data.get("floor_tuning_table")
	if not (table is Array) or (table as Array).is_empty():
		result.add_error("floor_tuning_table", EMPTY_TUNING_TABLE,
			"floor_tuning_table 不得为空")


## 行级校验（validate_dict 路径：从原始 Dictionary 数组读取）
static func _validate_rows_from_array(table: Array, result: ValidationResult) -> void:
	var seen_floor_numbers: Dictionary = {}
	for i: int in range(table.size()):
		var row: Variant = table[i]
		if not row is Dictionary:
			result.add_error(
				"floor_tuning_table[%d]" % i,
				MISSING_REQUIRED_FIELD,
				"行 %d 不是合法 Dictionary" % i
			)
			continue
		var rd: Dictionary = row as Dictionary

		# 行级必填字段缺失检查
		for field_name: String in _REQUIRED_ROW_FIELDS:
			if not rd.has(field_name):
				result.add_error(
					"floor_tuning_table[%d].%s" % [i, field_name],
					MISSING_REQUIRED_FIELD,
					"行 %d 缺少必填字段：%s" % [i, field_name]
				)

		if not rd.has("floor_number"):
			continue

		var floor_num: int = int(rd["floor_number"])

		# floor_number 非正
		if floor_num <= 0:
			result.add_error(
				"floor_number",
				FLOOR_NUMBER_NON_POSITIVE,
				"行 %d 的 floor_number=%d 为非正整数" % [i, floor_num]
			)
			# 该行 floor_number 无效 → 跳过本行其余字段校验（per-row fail-fast）；
			# 后续行仍继续校验。非正 floor_num 不入 seen 表，避免污染重复检测。
			continue

		# floor_number 重复
		if seen_floor_numbers.has(floor_num):
			result.add_error(
				"floor_number",
				DUPLICATE_FLOOR_NUMBER,
				"floor_number=%d 在第 %d 行与第 %d 行重复" % [floor_num, seen_floor_numbers[floor_num], i]
			)
		else:
			seen_floor_numbers[floor_num] = i

		# 行值范围检查（仅在字段存在时进行）
		if rd.has("player_atk_expected") and int(rd["player_atk_expected"]) < 10:
			result.add_error(
				"player_atk_expected",
				ATK_EXPECTED_TOO_LOW,
				"行 %d player_ATK_expected=%d，必须 >= 10（D1 硬约束）" % [i, int(rd["player_atk_expected"])]
			)
		if rd.has("player_hp_expected") and int(rd["player_hp_expected"]) < 1:
			result.add_error(
				"player_hp_expected",
				HP_EXPECTED_TOO_LOW,
				"行 %d player_HP_expected=%d，必须 >= 1" % [i, int(rd["player_hp_expected"])]
			)
		if rd.has("player_def_expected") and int(rd["player_def_expected"]) < 0:
			result.add_error(
				"player_def_expected",
				DEF_EXPECTED_NEGATIVE,
				"行 %d player_DEF_expected=%d，必须 >= 0" % [i, int(rd["player_def_expected"])]
			)


## 行级校验（validate 路径：从 FloorTuningRow 实例数组读取）
static func _validate_rows_from_instances(
		table: Array[FloorTuningRow], result: ValidationResult) -> void:
	var seen_floor_numbers: Dictionary = {}
	for i: int in range(table.size()):
		var row: FloorTuningRow = table[i]

		# floor_number 非正
		if row.floor_number <= 0:
			result.add_error(
				"floor_number",
				FLOOR_NUMBER_NON_POSITIVE,
				"行 %d 的 floor_number=%d 为非正整数" % [i, row.floor_number]
			)
			continue

		# floor_number 重复
		if seen_floor_numbers.has(row.floor_number):
			result.add_error(
				"floor_number",
				DUPLICATE_FLOOR_NUMBER,
				"floor_number=%d 在第 %d 行与第 %d 行重复" % [
					row.floor_number, seen_floor_numbers[row.floor_number], i]
			)
		else:
			seen_floor_numbers[row.floor_number] = i

		# 行值范围检查
		if row.player_atk_expected < 10:
			result.add_error(
				"player_atk_expected",
				ATK_EXPECTED_TOO_LOW,
				"行 %d player_ATK_expected=%d，必须 >= 10（D1 硬约束）" % [i, row.player_atk_expected]
			)
		if row.player_hp_expected < 1:
			result.add_error(
				"player_hp_expected",
				HP_EXPECTED_TOO_LOW,
				"行 %d player_HP_expected=%d，必须 >= 1" % [i, row.player_hp_expected]
			)
		if row.player_def_expected < 0:
			result.add_error(
				"player_def_expected",
				DEF_EXPECTED_NEGATIVE,
				"行 %d player_DEF_expected=%d，必须 >= 0" % [i, row.player_def_expected]
			)


# （已移除 _to_gdd_field_name：error.field 统一用 snake_case 实际字段名，无需翻译）
