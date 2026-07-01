## EntityDBValidator — 实体数据库校验器（TR-entity-001）
## 封装 entity-database.md Formulas D1/D3 + Edge Cases 定义的数值/公式校验，
## 以及 story-003 新增的 schema/引用/唯一性校验（两遍加载）。
## 纯静态函数，无实例状态，无场景树依赖，headless 可直接断言。
##
## 校验分层（按执行顺序）：
##   1. ValidationConfig 输入越界根因校验 → 越界时 early-return，跳过 2/3
##   2. pass1：按 entity_type 建临时表（monsters/items/keys），同时捕获重复 ID（AC-10）
##   3. pass2：跨引用 + Schema + 数值逐 entry 校验（AC-08/13/14/16/18 + D1/D3）
##
## story-002 数值校验（D1/D3/DEF/HP/gold/effect_value）保持原样，在 pass2 中并行执行。
##
## 硬性约束（GDD D1 / ADR-0002 / story-002 / story-003）：
##   - config 越界时报单条根因错误，跳过全部逐怪校验（避免误导根因）
##   - 重复 ID 须在写入表之前捕获（if table.has(id) 先判再写）
##   - assert() 在 Release 被剥离——校验失败通过返回 EntityValidationResult（非 assert）
##   - computed 对通过的 entry 同样记录（供 AC-02 断言算法精度）
##   - 所有伤害/预算中间值存入 computed 前须 int() 化
##
## 用法示例：
##   var cfg := ValidationConfig.new()
##   cfg.player_atk_expected = 20
##   cfg.player_hp_expected  = 100
##   cfg.player_def_expected = 5
##   cfg.n_max               = 10
##   cfg.hp_budget_ratio     = 0.35
##   var result := EntityDBValidator.validate_database(entries, cfg, "MVP")
##   if not result.is_valid:
##       for err in result.errors:
##           push_error("[%s] %s.%s: %s" % [err.code, err.entry_id, err.field, err.message])
class_name EntityDBValidator


# ── 错误码常量（AC 断言 code，不断言 message 文案）────────────────────────────

## n_max 不在 [5, 20] 范围内（根因错误，跳过逐怪 D1/D3）
const N_MAX_OUT_OF_RANGE := "N_MAX_OUT_OF_RANGE"

## player_atk_expected < 10（根因错误，跳过逐怪 D1/D3）
const PLAYER_ATK_EXPECTED_TOO_LOW := "PLAYER_ATK_EXPECTED_TOO_LOW"

## player_hp_expected < 1（根因错误，跳过逐怪 D1/D3）
const PLAYER_HP_EXPECTED_TOO_LOW := "PLAYER_HP_EXPECTED_TOO_LOW"

## hp_budget_ratio < 0.05（根因错误，跳过逐怪 D1/D3）
const HP_BUDGET_RATIO_TOO_LOW := "HP_BUDGET_RATIO_TOO_LOW"

## D1 违反：玩家净伤 < min_damage_required（怪物无法在 N_max 回合内被击杀）
const D1_VIOLATION := "D1_VIOLATION"

## DEF 独立上限：monster_def >= player_atk_expected（净伤被钳到 1，DEF 形同虚设）
## 独立于 D1 回合数校验，即使 D1 因低 HP 恒过也报（GDD D1「HP=1 漏洞」补充）
const DEF_EXCEEDS_ATK := "DEF_EXCEEDS_ATK"

## D3 违反：玩家击杀该怪所受总伤超过血量预算
const D3_VIOLATION := "D3_VIOLATION"

## monster_hp ≤ 0（含 0 与负数）
const HP_NONPOSITIVE := "HP_NONPOSITIVE"

## effect_value < 0（ItemEntry 负效果值无定义语义）
const NEGATIVE_EFFECT_VALUE := "NEGATIVE_EFFECT_VALUE"

## gold_drop < 1（GDD Edge Cases：gold_drop 须 ≥ 1）
const INVALID_GOLD_DROP := "INVALID_GOLD_DROP"

## 同 entity_type 内出现重复 id（AC-10；两遍加载 pass1 捕获，在写入表前检测）
const DUPLICATE_ID := "DUPLICATE_ID"

## rare_drop_item_id 引用的 ItemEntry 不存在于 items 表（AC-08；pass2 跨引用校验）
const DANGLING_REF := "DANGLING_REF"

## 普通怪（is_boss=false）设置了 rare_drop_item_id（AC-16；GDD 规则 C6）
const NONBOSS_RARE_DROP := "NONBOSS_RARE_DROP"

## KeyEntry 的 key_color != opens_door_color（AC-13；GDD 规则 C5 1:1 映射）
const KEY_COLOR_MISMATCH := "KEY_COLOR_MISMATCH"

## entity_type=ITEM 且 effect_type=KEY 的非法组合（AC-18；GDD 规则 C4 联合校验）
## 逐字段均合法，但组合语义非法（KEY 只允许出现在 entity_type=KEY 的 Entry 上）
const ILLEGAL_TYPE_EFFECT_COMBO := "ILLEGAL_TYPE_EFFECT_COMBO"

## MVP 构建范围下 ItemEntry 的 effect_type=FRAGMENT（AC-14；MVP 无 FRAGMENT 处理器）
## VS scope 下不报此错误（FRAGMENT 处理器在 VS 实现）
const FRAGMENT_OUT_OF_SCOPE := "FRAGMENT_OUT_OF_SCOPE"

# ── build_scope 标准化常量（F-06）────────────────────────────────────────────
## MVP 构建范围标准化值（validate_database 入口对入参 strip_edges().to_upper() 后与此比对）
const BUILD_SCOPE_MVP := "MVP"
## VS（Vertical Slice）构建范围标准化值
const BUILD_SCOPE_VS := "VS"


## 校验 entries 数组中所有实体的数值合法性、公式约束（D1/D3）及 schema/引用/唯一性。
##
## 执行顺序：
##   1. ValidationConfig 越界根因校验 → 越界 early-return
##   2. pass1：按 entity_type 分表 + 写入前捕获重复 ID（AC-10）
##   3. pass2：跨引用（AC-08）+ schema（AC-13/14/16/18）+ 数值（D1/D3 等）
##
## [param entries] — 已构造的 MonsterEntry / ItemEntry / KeyEntry 实例混合数组
## [param config] — D1/D3 所需的玩家预期值（依赖注入；不依赖全局 Autoload）
## [param build_scope] — 构建范围；"MVP" 启用 FRAGMENT 越界校验，"VS" 不报
## [return] EntityValidationResult，含 is_valid / errors[] / computed{}
static func validate_database(
		entries: Array,
		config: ValidationConfig,
		build_scope: String = "MVP") -> EntityValidationResult:

	# F-06：对 build_scope 入参标准化，避免 "mvp"/"MVP " 等变体静默放行 FRAGMENT
	var scope := build_scope.strip_edges().to_upper()

	var result := EntityValidationResult.new()

	# ── 1. ValidationConfig 输入越界根因校验（优先，跳过所有逐怪校验避免误导）──────
	# 任一根因错误 → early-return（GDD D1 / story-002 硬性约束）
	var has_config_error := false

	if config.n_max < 5 or config.n_max > 20:
		result.add_error(
			"",
			"n_max",
			N_MAX_OUT_OF_RANGE,
			"N_max=%d 不在 [5, 20] 范围内，校验跳过逐怪 D1/D3" % config.n_max
		)
		has_config_error = true

	if config.player_atk_expected < 10:
		result.add_error(
			"",
			"player_atk_expected",
			PLAYER_ATK_EXPECTED_TOO_LOW,
			"player_atk_expected=%d 须 >= 10（D1 硬约束）" % config.player_atk_expected
		)
		has_config_error = true

	if config.player_hp_expected < 1:
		result.add_error(
			"",
			"player_hp_expected",
			PLAYER_HP_EXPECTED_TOO_LOW,
			"player_hp_expected=%d 须 >= 1（D3 输入）" % config.player_hp_expected
		)
		has_config_error = true

	if config.hp_budget_ratio < 0.05:
		result.add_error(
			"",
			"hp_budget_ratio",
			HP_BUDGET_RATIO_TOO_LOW,
			"hp_budget_ratio=%s 须 >= 0.05（D3 输入下界）" % str(config.hp_budget_ratio)
		)
		has_config_error = true

	# config 越界 → 跳过两遍加载与逐怪校验
	if has_config_error:
		return result

	# ── 2. pass1：按 entity_type 建临时表，写入前捕获重复 ID（AC-10）─────────────
	# 键 = entry.id，值 = entry 实例
	# 重复 ID：写入前 if table.has(id) → 报 DUPLICATE_ID，仍继续（覆盖，保留后者以供 pass2）
	# 这样 pass2 可以继续做跨引用，不因重复而崩溃
	var monsters: Dictionary = {}  # id → MonsterEntry
	var items: Dictionary    = {}  # id → ItemEntry
	var keys: Dictionary     = {}  # id → KeyEntry

	for entry: Variant in entries:
		if entry is MonsterEntry:
			var m := entry as MonsterEntry
			if monsters.has(m.id):
				result.add_error(
					m.id, "id", DUPLICATE_ID,
					"[%s] MONSTER 类型出现重复 id（AC-10）" % m.id
				)
			monsters[m.id] = m
		elif entry is ItemEntry:
			var it := entry as ItemEntry
			if items.has(it.id):
				result.add_error(
					it.id, "id", DUPLICATE_ID,
					"[%s] ITEM 类型出现重复 id（AC-10）" % it.id
				)
			items[it.id] = it
		elif entry is KeyEntry:
			var k := entry as KeyEntry
			if keys.has(k.id):
				result.add_error(
					k.id, "id", DUPLICATE_ID,
					"[%s] KEY 类型出现重复 id（AC-10）" % k.id
				)
			keys[k.id] = k
		else:
			# F-03：未知或 null 类型跳过并警告，利于 story-006 运行时发现 from_dict null 未过滤
			push_warning("EntityDBValidator: 跳过未知或 null 的 Entry 类型（%s）——可能是 from_dict 返回 null 未过滤" % str(entry))

	# ── 3. pass2：跨引用 + schema + 数值逐 entry 校验 ────────────────────────
	# 遍历各表已去重（后者覆盖前者），顺序与原 entries 无关
	# 注意：数值校验（story-002）也在此遍历中执行，与 schema 校验并行

	# 3a. MonsterEntry
	for entry: Variant in monsters.values():
		var m := entry as MonsterEntry
		# 跨引用 + 稀有掉落资格（F-04 根因优先：普通怪不该有 rare_drop → 引用有效性无意义）
		# 每次碰撞各报一次：n 条同 id → n-1 条 DUPLICATE_ID
		if not m.is_boss and m.rare_drop_item_id != "":
			# AC-16：普通怪（is_boss=false）有 rare_drop_item_id → NONBOSS_RARE_DROP（根因）
			# 不再检查引用有效性，避免 DANGLING_REF 噪音
			result.add_error(
				m.id, "rare_drop_item_id", NONBOSS_RARE_DROP,
				"[%s] 普通怪（is_boss=false）不允许设置 rare_drop_item_id（AC-16）" % m.id
			)
		elif m.rare_drop_item_id != "":
			# AC-08：仅 boss（或合法持有 rare_drop）才检查引用有效性
			if not items.has(m.rare_drop_item_id):
				result.add_error(
					m.id, "rare_drop_item_id", DANGLING_REF,
					"[%s] rare_drop_item_id=\"%s\" 在 items 表中不存在（悬空引用，AC-08）" % [
						m.id, m.rare_drop_item_id]
				)
		# 数值校验（story-002，保持原有行为）
		_validate_monster(m, config, result)

	# 3b. ItemEntry
	for entry: Variant in items.values():
		var it := entry as ItemEntry
		# 联合组合校验（AC-18；GDD 规则 C4）
		# entity_type=ITEM 且 effect_type=KEY → 非法（KEY 只允许出现在 entity_type=KEY 的条目）
		if it.entity_type == ItemEntry.ENTITY_TYPE_ITEM \
				and it.effect_type == ItemEntry.EFFECT_TYPE_KEY:
			result.add_error(
				it.id, "effect_type", ILLEGAL_TYPE_EFFECT_COMBO,
				"[%s] entity_type=ITEM 且 effect_type=KEY 为非法组合（AC-18；规则 C4）" % it.id
			)
		# FRAGMENT 越界（AC-14；MVP 无 FRAGMENT 处理器，VS 放开）
		# F-06：使用标准化后的 scope 与常量，避免 "mvp"/"MVP " 等变体静默放行
		if scope == BUILD_SCOPE_MVP and it.effect_type == ItemEntry.EFFECT_TYPE_FRAGMENT:
			result.add_error(
				it.id, "effect_type", FRAGMENT_OUT_OF_SCOPE,
				"[%s] effect_type=FRAGMENT 在 MVP 构建下越界（AC-14；FRAGMENT 处理器在 VS）" % it.id
			)
		# 数值校验（story-002，保持原有行为）
		_validate_item(it, result)

	# 3c. KeyEntry
	for entry: Variant in keys.values():
		var k := entry as KeyEntry
		# key_color 与 opens_door_color 必须相等（AC-13；GDD 规则 C5 1:1 映射）
		if k.key_color != k.opens_door_color:
			result.add_error(
				k.id, "key_color", KEY_COLOR_MISMATCH,
				"[%s] key_color=%d 与 opens_door_color=%d 不匹配（AC-13；规则 C5）" % [
					k.id, k.key_color, k.opens_door_color]
			)
		# KeyEntry 本 story 无数值/公式校验项

	return result


# ── 内部辅助函数 ──────────────────────────────────────────────────────────────

## 校验单只 MonsterEntry 的所有数值/公式约束。
## [param monster] — 待校验的 MonsterEntry 实例
## [param config] — 已通过根因检查的 ValidationConfig
## [param result] — 累积校验结果（直接修改）
static func _validate_monster(
		monster: MonsterEntry,
		config: ValidationConfig,
		result: EntityValidationResult) -> void:

	var eid: String = monster.id

	# ── 2a. 范围校验：monster_hp ≤ 0 ────────────────────────────────────────
	# hp=0 与 hp=-1 均触发（GDD Edge Cases / AC-07）
	if monster.hp <= 0:
		result.add_error(eid, "hp", HP_NONPOSITIVE,
			"[%s] monster_hp=%d 须 >= 1（hp=0 与负数均非法）" % [eid, monster.hp])
		# hp 非正时 D1/D3 计算无意义（除零/负除），跳过此怪的公式校验
		return

	# ── 2b. 范围校验：gold_drop < 1 ─────────────────────────────────────────
	if monster.gold_drop < 1:
		result.add_error(eid, "gold_drop", INVALID_GOLD_DROP,
			"[%s] gold_drop=%d 须 >= 1" % [eid, monster.gold_drop])
		# gold_drop 错误不阻断 D1/D3（公式不依赖 gold_drop）

	# ── 2c. DEF 独立上限（独立于 D1 回合数校验）────────────────────────────
	# monster.defense >= player_atk_expected → 净伤被钳到 1，DEF 形同虚设
	# 即使 D1 因低 HP 恒过也须报（GDD D1「HP=1 漏洞」补充 / AC-15）
	# 注：本校验【不 early-return】——GDD D1「与 D1 同时检查」。DEF 过高时下方 D1
	# 亦可能触发（净伤被钳 1 → 打不死），DEF_EXCEEDS_ATK 与 D1_VIOLATION 双报为有意，
	# 二者是同一根因（DEF 过高）的两个独立断言面（code-review story-002 W-05）。
	if monster.defense >= config.player_atk_expected:
		result.add_error(eid, "def", DEF_EXCEEDS_ATK,
			"[%s] monster_def=%d >= player_atk_expected=%d（净伤被钳到 1，DEF 形同虚设）" % [
				eid, monster.defense, config.player_atk_expected])

	# ── 2d. D1 校验 ──────────────────────────────────────────────────────────
	# min_damage_required = int(ceil(float(monster_hp) / float(n_max)))
	# damage_per_round    = max(1, player_atk_expected - monster_def)
	var min_damage_required: int = int(ceil(float(monster.hp) / float(config.n_max)))
	var damage_per_round: int    = max(1, config.player_atk_expected - monster.defense)

	# ── 2e. D3 校验 ──────────────────────────────────────────────────────────
	# player_damage_taken_per_round = max(0, monster_atk - player_def_expected)
	# n_rounds_to_kill = int(ceil(float(monster_hp) / float(max(1, player_atk_expected - monster_def))))
	# total_damage_to_kill = player_damage_taken_per_round * n_rounds_to_kill
	# hp_budget = int(hp_budget_ratio * player_hp_expected)（向下取整）
	var player_damage_taken_per_round: int = max(0, monster.atk - config.player_def_expected)
	var n_rounds_to_kill: int = int(ceil(
		float(monster.hp) / float(max(1, config.player_atk_expected - monster.defense))
	))
	var total_damage_to_kill: int = player_damage_taken_per_round * n_rounds_to_kill
	var hp_budget: int            = int(config.hp_budget_ratio * float(config.player_hp_expected))

	# ── 2f. 记录 computed（通过与违反均记录，供 AC-02 断言算法精度）────────
	# 所有中间值 int() 化（ADR-0002 / story-002 硬性约束）
	result.computed[eid] = {
		"damage_per_round":           damage_per_round,
		"min_damage_required":        min_damage_required,
		"total_damage_to_kill":       total_damage_to_kill,
		"hp_budget":                  hp_budget,
	}

	# ── 2g. 报 D1 违反 ───────────────────────────────────────────────────────
	# field="def"：D1 由 hp+def 共同决定，此处标 def 表「建议优先下调的调参字段」
	# （GDD 调整策略：降 DEF → 降 HP → 提该层玩家 ATK 预期），非唯一根因。AC-03 不断言 field。
	if damage_per_round < min_damage_required:
		result.add_error(eid, "def", D1_VIOLATION,
			"[%s] damage_per_round=%d < min_damage_required=%d（D1 违反：不能在 %d 回合内击杀）" % [
				eid, damage_per_round, min_damage_required, config.n_max])

	# ── 2h. 报 D3 违反 ───────────────────────────────────────────────────────
	# field="atk"：D3 由 atk+def+hp 共同决定，此处标 atk 表「建议优先下调的调参字段」
	# （怪物 ATK 直接决定单回合伤害），非唯一根因。AC-04 不断言 field。
	if total_damage_to_kill > hp_budget:
		result.add_error(eid, "atk", D3_VIOLATION,
			"[%s] total_damage_to_kill=%d > hp_budget=%d（D3 违反：玩家受伤超出血量预算）" % [
				eid, total_damage_to_kill, hp_budget])


## 校验单件 ItemEntry 的数值约束。
## [param item] — 待校验的 ItemEntry 实例
## [param result] — 累积校验结果（直接修改）
static func _validate_item(item: ItemEntry, result: EntityValidationResult) -> void:
	var eid: String = item.id

	# ── effect_value < 0（GDD Edge Cases / AC-17）───────────────────────────
	if item.effect_value < 0:
		result.add_error(eid, "effect_value", NEGATIVE_EFFECT_VALUE,
			"[%s] effect_value=%d 须 >= 0（负效果值无定义语义）" % [eid, item.effect_value])
