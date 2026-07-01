## EntityDBValidator 数值/公式校验单元测试
## story: production/epics/entity-database/story-002-validate-database-numeric.md
## 覆盖：AC-02（D1 通过 + computed 精度）、AC-03（D1 违反）、AC-15（DEF 独立上限）、
##         AC-04（D3 违反 + computed）、AC-07（hp≤0）、AC-17（effect_value<0）、
##         AC-20（gold_drop<1）、边界合法值 PASS、根因优先负向对照
## 运行：godot --headless --script tests/gdunit4_runner.gd
extends GdUnitTestSuite


# ── 夹具工厂 ──────────────────────────────────────────────────────────────────

## 标准测试配置（std_config）：不触发 D1/D3 误报的通用入参
## player_atk_expected=20, player_hp_expected=100, player_def_expected=5,
## n_max=10, hp_budget_ratio=0.35
## （GDD §AC 顶部「标准测试配置」定义；story-002 QA Test Cases 通用入参）
func _make_std_config() -> ValidationConfig:
	var cfg := ValidationConfig.new()
	cfg.player_atk_expected = 20
	cfg.player_hp_expected  = 100
	cfg.player_def_expected = 5
	cfg.n_max               = 10
	cfg.hp_budget_ratio     = 0.35
	return cfg


## 构造合法 MonsterEntry（所有必填字段均合法）
## [param entry_id] — id 字段值（用于 computed/errors 断言的 entry_id）
func _make_monster(
		entry_id: String,
		hp: int = 50,
		atk: int = 10,
		defense: int = 0,
		gold_drop: int = 5,
		is_boss: bool = false) -> MonsterEntry:
	var e := MonsterEntry.new()
	e.id           = entry_id
	e.display_name = entry_id  # 测试不需要真实显示名
	e.hp           = hp
	e.atk          = atk
	e.defense      = defense
	e.gold_drop    = gold_drop
	e.is_boss      = is_boss
	e.entity_type  = MonsterEntry.ENTITY_TYPE_MONSTER
	return e


## 构造合法 ItemEntry（所有必填字段均合法）
func _make_item(
		entry_id: String,
		effect_type: int = ItemEntry.EFFECT_TYPE_HP_RESTORE,
		effect_value: int = 40) -> ItemEntry:
	var e := ItemEntry.new()
	e.id           = entry_id
	e.display_name = entry_id
	e.entity_type  = ItemEntry.ENTITY_TYPE_ITEM
	e.effect_type  = effect_type
	e.effect_value = effect_value
	e.stack_rule   = ItemEntry.STACK_RULE_ADDITIVE
	return e


## 在 errors 数组中查找匹配指定 code 的第一条记录
func _find_error_by_code(errors: Array, code: String) -> Variant:
	for err: Variant in errors:
		var e: Dictionary = err as Dictionary
		if e.get("code", "") == code:
			return e
	return null


## 在 errors 数组中查找匹配指定 entry_id 且 code 相符的记录
func _find_error_by_id_and_code(errors: Array, entry_id: String, code: String) -> Variant:
	for err: Variant in errors:
		var e: Dictionary = err as Dictionary
		if e.get("entry_id", "") == entry_id and e.get("code", "") == code:
			return e
	return null


# ── AC-02 — D1 通过路径 + computed 精度断言 ───────────────────────────────────
# Given: test_skeleton_valid(hp=90, def=10)；config.player_atk_expected=35, n_max=10
# Then: is_valid==true；computed["damage_per_round"]==25、["min_damage_required"]==9
func test_validator_d1_pass_computed_precision() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 35
	config.n_max = 10
	var entry := _make_monster("test_skeleton_valid", 90, 10, 10)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_true()
	# errors 不含 test_skeleton_valid 的任何错误
	var d1_err: Variant = _find_error_by_id_and_code(result.errors, "test_skeleton_valid",
		EntityDBValidator.D1_VIOLATION)
	assert_object(d1_err).is_null()
	# computed 精度断言（整数相等）
	assert_bool(result.computed.has("test_skeleton_valid")).is_true()
	var c: Dictionary = result.computed["test_skeleton_valid"] as Dictionary
	assert_int(c.get("damage_per_round", -1)).is_equal(25)
	assert_int(c.get("min_damage_required", -1)).is_equal(9)


# ── AC-03 — D1 违反报错 + message 含关键数值 ──────────────────────────────────
# Given: test_tank(hp=90, def=34)；player_atk_expected=35, n_max=10
# Then: is_valid==false；code==D1_VIOLATION；entry_id=="test_tank"；message 含 "1 < 9"
func test_validator_d1_violation_tank_returns_error() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 35
	config.n_max = 10
	var entry := _make_monster("test_tank", 90, 10, 34)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_tank",
		EntityDBValidator.D1_VIOLATION)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_tank")
	# message 须含 damage_per_round=1 和 min_damage_required=9 两个关键值
	# （story-002 AC-03：message 含 "damage_per_round=1 < min_damage_required=9"）
	var msg: String = (err as Dictionary).get("message", "")
	assert_str(msg).contains("damage_per_round=1")
	assert_str(msg).contains("min_damage_required=9")


# ── AC-15 — DEF 独立上限：def >= player_atk_expected → DEF_EXCEEDS_ATK ────────
# Given: test_highdef(hp=20, def=12, atk=5)；player_atk_expected=10, n_max=10
# Then: field=="def"；code==DEF_EXCEEDS_ATK（独立于 D1 回合数校验）
func test_validator_def_exceeds_atk_returns_error() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 10
	config.n_max = 10
	var entry := _make_monster("test_highdef", 20, 5, 12)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_highdef",
		EntityDBValidator.DEF_EXCEEDS_ATK)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("def")
	# DEF_EXCEEDS_ATK 独立于 D1 —— 此处 hp=20：ceil(20/10)=2，damage_per_round=max(1,10-12)=1，
	# 1<2 故 D1 亦 fail；确认 DEF_EXCEEDS_ATK 作为独立断言仍在 errors 中（不被 D1 结果吸收）。
	# 「D1 pass 但 DEF_EXCEEDS_ATK 仍报」的场景见下方 hp=1 低 HP 测试。
	assert_object(_find_error_by_id_and_code(result.errors, "test_highdef",
		EntityDBValidator.DEF_EXCEEDS_ATK)).is_not_null()


# ── AC-15 补充 — DEF 独立上限与 D1 结果无关（低 HP 场景验证独立性）─────────────
# Given: test_highdef_low_hp(hp=1, def=15, atk=0)；player_atk_expected=10
# hp=1 时 ceil(1/10)=1, damage_per_round=max(1,10-15)=1, 1>=1 → D1 pass
# 但 def=15 >= atk_expected=10 → 仍须报 DEF_EXCEEDS_ATK
func test_validator_def_exceeds_atk_independent_of_d1_low_hp() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 10
	var entry := _make_monster("test_highdef_low_hp", 1, 0, 15)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert — DEF_EXCEEDS_ATK 须存在（def=15 >= atk_expected=10）
	assert_object(_find_error_by_id_and_code(result.errors, "test_highdef_low_hp",
		EntityDBValidator.DEF_EXCEEDS_ATK)).is_not_null()


# ── AC-04 — D3 违反 + computed 精度断言 ───────────────────────────────────────
# Given: test_glasscannon(hp=50, atk=200, def=0)
#   player_atk_expected=20, player_hp_expected=100, player_def_expected=0,
#   n_max=10, hp_budget_ratio=0.35
# Then: code==D3_VIOLATION；computed["total_damage_to_kill"]==600, ["hp_budget"]==35
func test_validator_d3_violation_glasscannon_returns_error() -> void:
	# Arrange
	var config := ValidationConfig.new()
	config.player_atk_expected = 20
	config.player_hp_expected  = 100
	config.player_def_expected = 0
	config.n_max               = 10
	config.hp_budget_ratio     = 0.35
	var entry := _make_monster("test_glasscannon", 50, 200, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_glasscannon",
		EntityDBValidator.D3_VIOLATION)
	assert_object(err).is_not_null()
	# computed 精度断言
	assert_bool(result.computed.has("test_glasscannon")).is_true()
	var c: Dictionary = result.computed["test_glasscannon"] as Dictionary
	assert_int(c.get("total_damage_to_kill", -1)).is_equal(600)
	assert_int(c.get("hp_budget", -1)).is_equal(35)


# ── AC-07 — monster_HP ≤ 0（hp=0 与 hp=-1 各报一条 HP_NONPOSITIVE）─────────────
func test_validator_hp_zero_and_negative_each_report_hp_nonpositive() -> void:
	# Arrange
	var entry_zero := _make_monster("test_zero_hp", 0)
	var entry_neg  := _make_monster("test_neg_hp", -1)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry_zero, entry_neg], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err_zero: Variant = _find_error_by_id_and_code(result.errors, "test_zero_hp",
		EntityDBValidator.HP_NONPOSITIVE)
	assert_object(err_zero).is_not_null()
	assert_str((err_zero as Dictionary).get("field", "")).is_equal("hp")
	var err_neg: Variant = _find_error_by_id_and_code(result.errors, "test_neg_hp",
		EntityDBValidator.HP_NONPOSITIVE)
	assert_object(err_neg).is_not_null()
	assert_str((err_neg as Dictionary).get("field", "")).is_equal("hp")
	# 恰好两条 HP_NONPOSITIVE
	var hp_errors: int = 0
	for err: Variant in result.errors:
		if (err as Dictionary).get("code", "") == EntityDBValidator.HP_NONPOSITIVE:
			hp_errors += 1
	assert_int(hp_errors).is_equal(2)


# ── AC-17 — effect_value < 0 → NEGATIVE_EFFECT_VALUE ────────────────────────
func test_validator_item_negative_effect_value_returns_error() -> void:
	# Arrange
	var entry := _make_item("test_negval", ItemEntry.EFFECT_TYPE_HP_RESTORE, -10)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_negval",
		EntityDBValidator.NEGATIVE_EFFECT_VALUE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("effect_value")


# ── AC-20 — gold_drop < 1 → INVALID_GOLD_DROP ────────────────────────────────
func test_validator_gold_drop_zero_returns_error() -> void:
	# Arrange
	var entry := _make_monster("test_zerogold", 50, 10, 0, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_zerogold",
		EntityDBValidator.INVALID_GOLD_DROP)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("field", "")).is_equal("gold_drop")


# ── 边界合法值 PASS — hp=1 ────────────────────────────────────────────────────
func test_validator_hp_boundary_1_passes() -> void:
	# Arrange
	var entry := _make_monster("test_hp_boundary", 1, 0, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert — 不含 HP_NONPOSITIVE
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.HP_NONPOSITIVE)).is_null()


# ── 边界合法值 PASS — effect_value=0 ─────────────────────────────────────────
func test_validator_effect_value_zero_passes() -> void:
	# Arrange
	var entry := _make_item("test_ev_zero", ItemEntry.EFFECT_TYPE_HP_RESTORE, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.NEGATIVE_EFFECT_VALUE)).is_null()


# ── 边界合法值 PASS — gold_drop=1 ────────────────────────────────────────────
func test_validator_gold_drop_boundary_1_passes() -> void:
	# Arrange
	var entry := _make_monster("test_gold_boundary", 50, 10, 0, 1)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.INVALID_GOLD_DROP)).is_null()


# ── 边界合法值 PASS — n_max=5（下界）────────────────────────────────────────
func test_validator_n_max_lower_boundary_5_passes() -> void:
	# Arrange
	var config := _make_std_config()
	config.n_max = 5
	var entry := _make_monster("test_nmax5", 50, 10, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.N_MAX_OUT_OF_RANGE)).is_null()


# ── 边界合法值 PASS — n_max=20（上界）────────────────────────────────────────
func test_validator_n_max_upper_boundary_20_passes() -> void:
	# Arrange
	var config := _make_std_config()
	config.n_max = 20
	var entry := _make_monster("test_nmax20", 50, 10, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.N_MAX_OUT_OF_RANGE)).is_null()


# ── 边界合法值 PASS — player_atk_expected=10（最小合法值）───────────────────
func test_validator_player_atk_expected_boundary_10_passes() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 10
	var entry := _make_monster("test_atk10", 20, 5, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.PLAYER_ATK_EXPECTED_TOO_LOW)).is_null()


# ── 边界合法值 PASS — hp_budget_ratio=0.05（最小合法值）─────────────────────
func test_validator_hp_budget_ratio_boundary_005_passes() -> void:
	# Arrange
	var config := _make_std_config()
	config.hp_budget_ratio = 0.05
	var entry := _make_monster("test_ratio005", 20, 5, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.HP_BUDGET_RATIO_TOO_LOW)).is_null()


# ── 根因优先 — n_max=25（越界）→ 只报 N_MAX_OUT_OF_RANGE，不报 D1_VIOLATION ──
# 负向对照：会触发 D1 的怪（高 DEF）+ n_max 越界 → 只有根因错误
func test_validator_root_cause_n_max_out_of_range_skips_d1() -> void:
	# Arrange: test_tank 在合法 n_max 下会触发 D1（def=34, atk_expected=35 → damage_per_round=1 < ceil(90/10)=9）
	var config := _make_std_config()
	config.player_atk_expected = 35
	config.n_max = 25  # 越界
	var entry := _make_monster("test_tank_d1", 90, 10, 34)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert — 只报根因，不报逐怪 D1_VIOLATION
	assert_bool(result.is_valid).is_false()
	var root_err: Variant = _find_error_by_code(result.errors, EntityDBValidator.N_MAX_OUT_OF_RANGE)
	assert_object(root_err).is_not_null()
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.D1_VIOLATION)).is_null()


# ── 根因优先 — player_atk_expected=9（越界）→ 只报根因，不报 D1_VIOLATION ────
func test_validator_root_cause_atk_expected_too_low_skips_d1() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_atk_expected = 9  # 越界（须 >= 10）
	var entry := _make_monster("test_any_monster", 50, 5, 2)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		EntityDBValidator.PLAYER_ATK_EXPECTED_TOO_LOW)).is_not_null()
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.D1_VIOLATION)).is_null()


# ── 根因优先 — player_hp_expected=0（越界）→ 只报根因，不报 D3_VIOLATION ────
func test_validator_root_cause_hp_expected_too_low_skips_d3() -> void:
	# Arrange
	var config := _make_std_config()
	config.player_hp_expected = 0  # 越界（须 >= 1）
	var entry := _make_monster("test_any_monster2", 50, 200, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		EntityDBValidator.PLAYER_HP_EXPECTED_TOO_LOW)).is_not_null()
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.D3_VIOLATION)).is_null()


# ── 根因优先 — hp_budget_ratio=0.04（越界）→ 只报根因，不报 D3_VIOLATION ────
func test_validator_root_cause_hp_budget_ratio_too_low_skips_d3() -> void:
	# Arrange
	var config := _make_std_config()
	config.hp_budget_ratio = 0.04  # 越界（须 >= 0.05）
	var entry := _make_monster("test_any_monster3", 50, 200, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database([entry], config, "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_code(result.errors,
		EntityDBValidator.HP_BUDGET_RATIO_TOO_LOW)).is_not_null()
	assert_object(_find_error_by_code(result.errors, EntityDBValidator.D3_VIOLATION)).is_null()


# ── 全合法 entry 返回 is_valid==true ─────────────────────────────────────────
func test_validator_all_valid_entries_passes() -> void:
	# Arrange: MVP 数据（slime + potion_small）
	var slime := _make_monster("slime", 20, 8, 2, 5)
	var potion := _make_item("potion_small", ItemEntry.EFFECT_TYPE_HP_RESTORE, 40)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[slime, potion], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


# ── 空 entries 数组返回 is_valid==true ───────────────────────────────────────
func test_validator_empty_entries_passes() -> void:
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_true()


# ── gold_drop 负数同样触发 INVALID_GOLD_DROP ─────────────────────────────────
func test_validator_gold_drop_negative_returns_error() -> void:
	# Arrange
	var entry := _make_monster("test_neg_gold", 50, 10, 0, -1)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[entry], _make_std_config(), "MVP")
	# Assert
	assert_object(_find_error_by_id_and_code(result.errors, "test_neg_gold",
		EntityDBValidator.INVALID_GOLD_DROP)).is_not_null()


# ── D1 通过时 computed 同样记录（AC-02 补充：通过也记录）──────────────────────
func test_validator_d1_pass_still_records_computed() -> void:
	# Arrange: goblin（GDD MVP 数据）用 std_config（atk_expected=20）
	# min_damage_required = ceil(50/10)=5; damage_per_round = max(1, 20-5)=15; 15>=5 → pass
	var goblin := _make_monster("goblin", 50, 18, 5, 10)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[goblin], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.computed.has("goblin")).is_true()
	var c: Dictionary = result.computed["goblin"] as Dictionary
	assert_int(c.get("damage_per_round", -1)).is_equal(15)
	assert_int(c.get("min_damage_required", -1)).is_equal(5)
