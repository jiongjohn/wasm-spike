## EntityValidationResult — 实体数据库校验结果容器（TR-entity-001）
## 封装 EntityDBValidator.validate_database() 的返回值。
## 每条 errors 条目含四个键：
##   entry_id — 违规 Entry 的 id 字段（如 "slime"）
##   field    — 违规字段名（snake_case，如 "hp"、"defense"、"effect_value"）
##   code     — 稳定错误码常量（AC 断言此值，不断言 message 文案）
##   message  — 人类可读描述（仅用于日志/调试）
##
## computed 按 entry_id 存储 D1/D3 校验的中间值（通过的 entry 同样记录，供测试断言精度）。
## 所有伤害/预算中间值在存入前须 int() 化。
##
## 与 tuning 的 ValidationResult 区别：
##   - add_error 额外接收 entry_id 参数（逐怪追踪）
##   - 多出 computed: Dictionary 字段（存 D1/D3 中间值）
##
## 用法示例：
##   var result: EntityValidationResult = EntityDBValidator.validate_database(entries, cfg)
##   if not result.is_valid:
##       for err in result.errors:
##           push_error("[%s] %s.%s: %s" % [err.code, err.entry_id, err.field, err.message])
##   # 断言 D1 中间值（AC-02）：
##   assert(result.computed["test_skeleton_valid"]["damage_per_round"] == 25)
class_name EntityValidationResult extends RefCounted

## 校验是否全部通过（errors 长度为 0 时为 true）
var is_valid: bool = true

## 错误条目列表；每项为 Dictionary{ entry_id: String, field: String, code: String, message: String }
var errors: Array[Dictionary] = []

## 中间值字典；键为 entry_id，值为 Dictionary（含 D1/D3 中间值，int 化）
## 通过与违反的 entry 均记录，供 AC-02 断言算法精度
var computed: Dictionary = {}


## 追加一条错误并将 is_valid 置为 false
## [param entry_id] — 违规 Entry 的 id（如 "slime"）
## [param field] — 违规字段名（snake_case，如 "hp"、"defense"）
## [param code] — 稳定错误码（使用 EntityDBValidator 常量区的 const 值）
## [param message] — 人类可读错误描述
func add_error(entry_id: String, field: String, code: String, message: String) -> void:
	is_valid = false
	errors.append({
		"entry_id": entry_id,
		"field": field,
		"code": code,
		"message": message
	})
