## ValidationResult — 校验结果容器（TR-tuning-001）
## 封装 validate_tuning_config / TuningConfigValidator 的返回值。
## 每条 errors 条目含三个键：
##   field   — 违规字段名（snake_case 实际字段名，如 "base_max_hp"）
##   code    — 稳定错误码常量（不随 message 文案变更而变化）
##   message — 人类可读描述（仅用于日志/调试，AC 不断言此值）
##
## 用法示例：
##   var result: ValidationResult = TuningConfigValidator.validate(config)
##   if not result.is_valid:
##       for err in result.errors:
##           push_error("TuningConfig: [%s] %s — %s" % [err.field, err.code, err.message])
class_name ValidationResult extends RefCounted

## 校验是否全部通过（errors 长度为 0 时为 true）
var is_valid: bool = true

## 错误条目列表；每项为 Dictionary{ field: String, code: String, message: String }
var errors: Array[Dictionary] = []


## 追加一条错误并将 is_valid 置为 false
## [param field] — 违规字段名（snake_case 实际字段名，如 "base_max_hp"）
## [param code] — 稳定错误码（使用 TuningConfigValidator 常量区的 const 值）
## [param message] — 人类可读错误描述
func add_error(field: String, code: String, message: String) -> void:
	is_valid = false
	errors.append({"field": field, "code": code, "message": message})
