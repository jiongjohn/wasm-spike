## TuningConfig — 游戏调参配置 Autoload（Project Settings 列表 [1]，最先初始化）
## 从 res://data/tuning_config.json 同步加载配置，提供只读访问。
## Autoload 顺序：TuningConfig[1] → EntityDB[2] → FloorDB[3]（ADR-0002）
## 用法示例：
##   var cfg: TuningConfigData = TuningConfig.get_tuning_config()   # 返回深拷贝副本
##   var row: FloorTuningRow = TuningConfig.get_floor_tuning(2)     # 返回副本或 null
class_name TuningConfig extends Node

## 内部初始化状态标志，仅由自身在 _ready() 末尾置 true（ADR-0002）
var _initialized: bool = false

## 只读初始化状态（ADR-0002 is_initialized 模式）
var is_initialized: bool:
	get: return _initialized

## 启动就绪信号（未来异步兼容预留；当前不应被场景节点 _ready() 中连接后期望收到）
signal database_ready

## 内部配置数据，外部只通过 getter 访问副本
var _config: TuningConfigData = null


func _ready() -> void:
	_load_and_validate()
	# 仅加载成功（_config != null）才标就绪——否则 is_initialized 语义失真，
	# 下游按 is_initialized==true 当"数据可用"会撞 null（fail-fast，code-review W2）。
	if _config != null:
		_initialized = true
	database_ready.emit()


## 同步加载并反序列化配置（禁止 await！ADR-0002）
func _load_and_validate() -> void:
	var path := "res://data/tuning_config.json"
	var text := FileAccess.get_file_as_string(path)
	# ADR-0005：文件缺失时 get_file_as_string 返回 ""，须先 null/空检查
	if text.is_empty():
		push_error("TuningConfig: 配置文件缺失或为空：%s" % path)
		_show_error_screen("TuningConfig: 配置文件缺失，请检查 res://data/tuning_config.json")
		return
	# ADR-0005：parse_string 结果须 null-check + is Dictionary
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("TuningConfig: 配置文件不是合法 JSON 对象：%s" % path)
		_show_error_screen("TuningConfig: 配置文件格式错误")
		return
	var data: Dictionary = parsed as Dictionary
	var cfg := TuningConfigData.new()
	# ADR-0005：int 字段显式 int() 转型（JSON.parse_string 可能把整数解为 float）
	cfg.base_atk = int(data.get("base_atk", 0))
	cfg.base_def = int(data.get("base_def", 0))
	cfg.base_max_hp = int(data.get("base_max_hp", 0))
	cfg.n_max = int(data.get("n_max", 0))
	cfg.hp_budget_ratio = float(data.get("hp_budget_ratio", 0.0))
	cfg.battle_round_duration = float(data.get("battle_round_duration", 0.0))
	# 解析楼层调参表
	var table: Variant = data.get("floor_tuning_table", null)
	if table is Array:
		for row_data: Variant in table:
			if not row_data is Dictionary:
				push_error("TuningConfig: floor_tuning_table 包含非 Dictionary 行，已跳过")
				continue
			var rd: Dictionary = row_data as Dictionary
			var row := FloorTuningRow.new()
			row.floor_number = int(rd.get("floor_number", 0))
			row.player_atk_expected = int(rd.get("player_atk_expected", 0))
			row.player_def_expected = int(rd.get("player_def_expected", 0))
			row.player_hp_expected = int(rd.get("player_hp_expected", 0))
			cfg.floor_tuning_table.append(row)
	_config = cfg


## 返回调参配置的深拷贝副本（防止外部写入污染内部嵌套 array，ADR-0001）
## 若加载失败返回 null。
## 注意：每次调用均产生完整深拷贝，应在初始化时调用一次并缓存，勿在帧循环中调用。
func get_tuning_config() -> TuningConfigData:
	if _config == null:
		return null
	# duplicate_deep()：floor_tuning_table 含嵌套 FloorTuningRow，须深拷贝（4.5+ 显式 API）
	return _config.duplicate_deep() as TuningConfigData


## 按楼层编号查找调参行，返回浅拷贝副本；未找到返回 null（TR-tuning-003）
func get_floor_tuning(floor_number: int) -> FloorTuningRow:
	if _config == null:
		return null
	for row: FloorTuningRow in _config.floor_tuning_table:
		if row.floor_number == floor_number:
			return row.duplicate() as FloorTuningRow
	return null


## [仅测试使用] 注入预构造的配置对象，绕开文件加载
## 警告：仅在 GDUnit4 headless 测试中调用，生产代码禁止直接调用
func _inject_config_for_test(cfg: TuningConfigData) -> void:
	assert(OS.is_debug_build(), "_inject_config_for_test 仅在调试构建中可用，禁止生产路径调用")
	_config = cfg


## 内联构建错误屏（禁用 OS.quit()，WASM 兼容，ADR-0002 + control-manifest）
## Autoload _ready() 中 get_tree().get_root() 此时已可用（不需要 call_deferred）
func _show_error_screen(message: String) -> void:
	var label := Label.new()
	label.text = "[TuningConfig 启动失败]\n%s" % message
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.add_theme_color_override("font_color", Color.RED)
	get_tree().get_root().add_child(label)
