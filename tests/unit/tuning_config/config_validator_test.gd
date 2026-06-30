## TuningConfigValidator 单元测试
## story: production/epics/game-tuning-config/story-002-config-validator.md
## 覆盖 AC-TC-01, AC-TC-01b, AC-TC-02, AC-TC-03, AC-TC-04, AC-TC-05,
##         AC-TC-06, AC-TC-15, AC-TC-16, AC-TC-17, AC-TC-18, AC-TC-19
##         及边界值正向/负向对照
## 运行：godot --headless --script tests/gdunit4_runner.gd
extends GdUnitTestSuite


# ── 夹具工厂 ─────────────────────────────────────────────────────────────────

## 构造合法完整的 3 行 TuningConfigData（MVP 标准，GDD T4/T5/T6 权威数值）
func _make_valid_config_3rows() -> TuningConfigData:
	var cfg := TuningConfigData.new()
	cfg.base_atk = 6
	cfg.base_def = 3
	cfg.base_max_hp = 100
	cfg.n_max = 10
	cfg.hp_budget_ratio = 0.35
	cfg.battle_round_duration = 0.3
	cfg.floor_tuning_table = []
	var r1 := FloorTuningRow.new()
	r1.floor_number = 1; r1.player_atk_expected = 14
	r1.player_def_expected = 8;  r1.player_hp_expected = 100
	cfg.floor_tuning_table.append(r1)
	var r2 := FloorTuningRow.new()
	r2.floor_number = 2; r2.player_atk_expected = 14
	r2.player_def_expected = 13; r2.player_hp_expected = 90
	cfg.floor_tuning_table.append(r2)
	var r3 := FloorTuningRow.new()
	r3.floor_number = 3; r3.player_atk_expected = 20
	r3.player_def_expected = 13; r3.player_hp_expected = 135
	cfg.floor_tuning_table.append(r3)
	return cfg


## 构造合法完整的 5 行 TuningConfigData（VS 预规划场景）
func _make_valid_config_5rows() -> TuningConfigData:
	var cfg := _make_valid_config_3rows()
	var r4 := FloorTuningRow.new()
	r4.floor_number = 4; r4.player_atk_expected = 20
	r4.player_def_expected = 13; r4.player_hp_expected = 115
	cfg.floor_tuning_table.append(r4)
	var r5 := FloorTuningRow.new()
	r5.floor_number = 5; r5.player_atk_expected = 20
	r5.player_def_expected = 13; r5.player_hp_expected = 110
	cfg.floor_tuning_table.append(r5)
	return cfg


## 构造与 _make_valid_config_3rows 等价的合法 Dictionary（用于 validate_dict 路径）
func _make_valid_dict_3rows() -> Dictionary:
	return {
		"base_atk": 6,
		"base_def": 3,
		"base_max_hp": 100,
		"n_max": 10,
		"hp_budget_ratio": 0.35,
		"battle_round_duration": 0.3,
		"floor_tuning_table": [
			{"floor_number": 1, "player_atk_expected": 14,
			 "player_def_expected": 8,  "player_hp_expected": 100},
			{"floor_number": 2, "player_atk_expected": 14,
			 "player_def_expected": 13, "player_hp_expected": 90},
			{"floor_number": 3, "player_atk_expected": 20,
			 "player_def_expected": 13, "player_hp_expected": 135},
		]
	}


## 在 errors 数组中查找匹配指定 code 的第一条记录
func _find_error_by_code(errors: Array, code: String) -> Variant:
	for err: Variant in errors:
		var e: Dictionary = err as Dictionary
		if e.get("code", "") == code:
			return e
	return null


# ── AC-TC-01 — 合法完整 MVP 3 行配置（validate）→ is_valid==true ──────────────
func test_validator_valid_mvp_3row_config_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


# ── AC-TC-01b — 合法 VS 5 行配置（validate）→ is_valid==true ──────────────────
func test_validator_valid_vs_5row_config_passes() -> void:
	# Arrange
	var config := _make_valid_config_5rows()
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


# ── AC-TC-02 — player_ATK_expected=9 → ATK_EXPECTED_TOO_LOW ─────────────────
func test_validator_atk_expected_too_low_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.floor_tuning_table[0].player_atk_expected = 9
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.ATK_EXPECTED_TOO_LOW)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("player_atk_expected")


# ── AC-TC-02 边界正向 — player_ATK_expected=10（最小合法值）→ 无错 ─────────────
func test_validator_atk_expected_boundary_10_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.floor_tuning_table[0].player_atk_expected = 10
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.ATK_EXPECTED_TOO_LOW)).is_null()


# ── AC-TC-03 — HP_BUDGET_RATIO=0.04 → HP_RATIO_TOO_LOW ─────────────────────
func test_validator_hp_budget_ratio_too_low_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.hp_budget_ratio = 0.04
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.HP_RATIO_TOO_LOW)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("hp_budget_ratio")


# ── AC-TC-03 边界正向 — HP_BUDGET_RATIO=0.05（最小合法值）→ 无错 ───────────────
func test_validator_hp_budget_ratio_boundary_005_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.hp_budget_ratio = 0.05
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.HP_RATIO_TOO_LOW)).is_null()


# ── AC-TC-04 — N_max=4（下界越界）→ N_MAX_OUT_OF_RANGE ──────────────────────
func test_validator_n_max_below_lower_bound_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.n_max = 4
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.N_MAX_OUT_OF_RANGE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("n_max")


# ── AC-TC-05 — N_max=21（上界越界）→ N_MAX_OUT_OF_RANGE ─────────────────────
func test_validator_n_max_above_upper_bound_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.n_max = 21
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.N_MAX_OUT_OF_RANGE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("n_max")


# ── N_max 边界正向 — N_max=5 / N_max=20 均合法 ──────────────────────────────
func test_validator_n_max_lower_boundary_5_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.n_max = 5
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.N_MAX_OUT_OF_RANGE)).is_null()


func test_validator_n_max_upper_boundary_20_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.n_max = 20
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.N_MAX_OUT_OF_RANGE)).is_null()


# ── AC-TC-06 — 省略 base_max_hp → MISSING_REQUIRED_FIELD（validate_dict 路径）
func test_validator_dict_missing_base_max_hp_returns_missing_field_error() -> void:
	# Arrange: 从合法 dict 中移除 base_max_hp
	var data := _make_valid_dict_3rows()
	data.erase("base_max_hp")
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.MISSING_REQUIRED_FIELD)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("base_max_hp")


# ── AC-TC-06 补充 — 省略 base_atk → MISSING_REQUIRED_FIELD ─────────────────
func test_validator_dict_missing_base_atk_returns_missing_field_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	data.erase("base_atk")
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.MISSING_REQUIRED_FIELD)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("base_atk")


# ── AC-TC-06 补充 — 省略 floor_tuning_table → MISSING_REQUIRED_FIELD ────────
func test_validator_dict_missing_floor_table_returns_missing_field_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	data.erase("floor_tuning_table")
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.MISSING_REQUIRED_FIELD)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("floor_tuning_table")


# ── AC-TC-06 负向对照 — 全字段存在时 MISSING_REQUIRED_FIELD 不出现 ──────────
func test_validator_dict_all_fields_present_no_missing_field_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.MISSING_REQUIRED_FIELD)).is_null()


# ── AC-TC-15 — BATTLE_ROUND_DURATION=0 → ROUND_DURATION_NON_POSITIVE ────────
func test_validator_battle_round_duration_zero_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.battle_round_duration = 0.0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.ROUND_DURATION_NON_POSITIVE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("battle_round_duration")


# ── AC-TC-15 负向 — BATTLE_ROUND_DURATION < 0（负值）同样触发 ─────────────────
func test_validator_battle_round_duration_negative_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.battle_round_duration = -0.1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.ROUND_DURATION_NON_POSITIVE)).is_not_null()


# ── AC-TC-16 — base_ATK=0 → BASE_ATK_TOO_LOW（存在但非法，区别于缺失）────────
func test_validator_base_atk_zero_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.base_atk = 0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.BASE_ATK_TOO_LOW)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("base_atk")


# ── AC-TC-16 边界正向 — base_ATK=1（最小合法值）→ 无错 ─────────────────────
func test_validator_base_atk_boundary_1_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.base_atk = 1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.BASE_ATK_TOO_LOW)).is_null()


# ── AC-TC-17 — base_MaxHP=0 → BASE_MAX_HP_TOO_LOW（validate 路径，独立于 null 路径）
func test_validator_base_max_hp_zero_returns_error() -> void:
	# Arrange: 字段存在但值为 0（非 null 路径，使用 validate 而非 validate_dict）
	var config := _make_valid_config_3rows()
	config.base_max_hp = 0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.BASE_MAX_HP_TOO_LOW)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("base_max_hp")


# ── AC-TC-17 边界正向 — base_MaxHP=1（最小合法值）→ 无错 ────────────────────
func test_validator_base_max_hp_boundary_1_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.base_max_hp = 1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.BASE_MAX_HP_TOO_LOW)).is_null()


# ── AC-TC-18 — floor_tuning_table 空数组 → EMPTY_TUNING_TABLE ───────────────
func test_validator_empty_floor_table_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.floor_tuning_table = []
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.EMPTY_TUNING_TABLE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("floor_tuning_table")


# ── AC-TC-19 — floor_number 重复 → DUPLICATE_FLOOR_NUMBER ───────────────────
func test_validator_duplicate_floor_number_returns_error() -> void:
	# Arrange: 两行 floor_number 均为 1
	var config := _make_valid_config_3rows()
	var extra := FloorTuningRow.new()
	extra.floor_number = 1; extra.player_atk_expected = 14
	extra.player_def_expected = 8; extra.player_hp_expected = 100
	config.floor_tuning_table.append(extra)
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.DUPLICATE_FLOOR_NUMBER)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("floor_number")


# ── AC-TC-19 负向对照 — 全行 floor_number 不重复时不报错 ─────────────────────
func test_validator_unique_floor_numbers_no_duplicate_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.DUPLICATE_FLOOR_NUMBER)).is_null()


# ── floor_number 非正 → FLOOR_NUMBER_NON_POSITIVE（不复用 DUPLICATE）────────
func test_validator_non_positive_floor_number_returns_dedicated_code() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.floor_tuning_table[0].floor_number = 0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.FLOOR_NUMBER_NON_POSITIVE)
	assert_object(err).is_not_null()
	# 确认没有误报为 DUPLICATE_FLOOR_NUMBER
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.DUPLICATE_FLOOR_NUMBER)).is_null()


# ── floor_number 负数同样触发 FLOOR_NUMBER_NON_POSITIVE ──────────────────────
func test_validator_negative_floor_number_returns_non_positive_code() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.floor_tuning_table[1].floor_number = -1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.FLOOR_NUMBER_NON_POSITIVE)).is_not_null()


# ── validate_dict 路径：合法 dict 3 行 → is_valid==true ─────────────────────
func test_validator_dict_valid_3row_passes() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


# ── validate_dict 路径：行级 player_ATK_expected 非法 ─────────────────────────
func test_validator_dict_row_atk_expected_too_low_returns_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	(data["floor_tuning_table"] as Array)[0]["player_atk_expected"] = 9
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.ATK_EXPECTED_TOO_LOW)).is_not_null()


# ── validate_dict 路径：行缺少 floor_number → MISSING_REQUIRED_FIELD ──────────
func test_validator_dict_row_missing_floor_number_returns_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	var rows := data["floor_tuning_table"] as Array
	(rows[0] as Dictionary).erase("floor_number")
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.MISSING_REQUIRED_FIELD)).is_not_null()


# ── validate_dict 路径：floor_number 非正 → FLOOR_NUMBER_NON_POSITIVE ─────────
func test_validator_dict_non_positive_floor_number_returns_dedicated_code() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	(data["floor_tuning_table"] as Array)[0]["floor_number"] = 0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.FLOOR_NUMBER_NON_POSITIVE)
	assert_object(err).is_not_null()
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.DUPLICATE_FLOOR_NUMBER)).is_null()


# ── validate_dict 路径：HP_BUDGET_RATIO > 1.0 → HP_RATIO_TOO_HIGH ───────────
func test_validator_dict_hp_ratio_above_1_returns_error() -> void:
	# Arrange
	var data := _make_valid_dict_3rows()
	data["hp_budget_ratio"] = 1.1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate_dict(data)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.HP_RATIO_TOO_HIGH)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("hp_budget_ratio")


# ── validate 路径：HP_BUDGET_RATIO > 1.0 → HP_RATIO_TOO_HIGH ────────────────
func test_validator_hp_ratio_above_1_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.hp_budget_ratio = 1.1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.HP_RATIO_TOO_HIGH)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("hp_budget_ratio")


# ── HP_BUDGET_RATIO=1.0（上界合法值）→ 无 HP_RATIO_TOO_HIGH ─────────────────
func test_validator_hp_ratio_boundary_1_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.hp_budget_ratio = 1.0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.HP_RATIO_TOO_HIGH)).is_null()


# ── base_DEF < 0 → BASE_DEF_NEGATIVE ────────────────────────────────────────
func test_validator_base_def_negative_returns_error() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.base_def = -1
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_code(result.errors,
		TuningConfigValidator.BASE_DEF_NEGATIVE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("base_def")


# ── base_DEF=0（合法边界值）→ 无 BASE_DEF_NEGATIVE ──────────────────────────
func test_validator_base_def_zero_passes() -> void:
	# Arrange
	var config := _make_valid_config_3rows()
	config.base_def = 0
	# Act
	var result: ValidationResult = TuningConfigValidator.validate(config)
	# Assert
	assert_object(_find_error_by_code(result.errors,
		TuningConfigValidator.BASE_DEF_NEGATIVE)).is_null()
