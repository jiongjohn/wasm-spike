## TuningConfig 数据类型 + 加载 + 只读访问 单元测试
## story: production/epics/game-tuning-config/story-001-config-type-and-loader.md
## 覆盖 AC-TC-11、AC-TC-12、AC-TC-13
## 内存构造夹具 + _inject_config_for_test，不依赖 res:// 文件（headless 安全）
extends GdUnitTestSuite


## 构造含 3 行的测试用 TuningConfigData（floor1-3，匹配 GDD T6 权威数值）
func _make_test_config() -> TuningConfigData:
	var cfg := TuningConfigData.new()
	cfg.base_atk = 6
	cfg.base_def = 3
	cfg.base_max_hp = 100
	cfg.n_max = 10
	cfg.hp_budget_ratio = 0.35
	cfg.battle_round_duration = 0.3
	cfg.floor_tuning_table = []
	# floor1: ATK=14, DEF=8,  HP=100
	var r1 := FloorTuningRow.new()
	r1.floor_number = 1; r1.player_atk_expected = 14; r1.player_def_expected = 8;  r1.player_hp_expected = 100
	cfg.floor_tuning_table.append(r1)
	# floor2: ATK=14, DEF=13, HP=90
	var r2 := FloorTuningRow.new()
	r2.floor_number = 2; r2.player_atk_expected = 14; r2.player_def_expected = 13; r2.player_hp_expected = 90
	cfg.floor_tuning_table.append(r2)
	# floor3: ATK=20, DEF=13, HP=135
	var r3 := FloorTuningRow.new()
	r3.floor_number = 3; r3.player_atk_expected = 20; r3.player_def_expected = 13; r3.player_hp_expected = 135
	cfg.floor_tuning_table.append(r3)
	return cfg


# ── AC-TC-11 — get_floor_tuning(3) 返回正确数据 ──────────────────────────────
func test_get_floor_tuning_floor3_returns_correct_data() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	var row: FloorTuningRow = tc.get_floor_tuning(3)
	assert_object(row).is_not_null()
	assert_int(row.player_atk_expected).is_equal(20)
	assert_int(row.player_def_expected).is_equal(13)
	assert_int(row.player_hp_expected).is_equal(135)
	tc.free()


# ── AC-TC-12 — get_floor_tuning(99) 返回 null，不崩溃 ────────────────────────
func test_get_floor_tuning_missing_floor_returns_null() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	var row: FloorTuningRow = tc.get_floor_tuning(99)
	assert_object(row).is_null()
	tc.free()


# ── AC-TC-13 — get_tuning_config() 返回副本，写入不污染内部数据 ──────────────
func test_get_tuning_config_returns_deep_copy_not_reference() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	var cfg: TuningConfigData = tc.get_tuning_config()
	# 对副本写入 base_atk
	cfg.base_atk = 999
	# 内部数据不受影响
	var cfg2: TuningConfigData = tc.get_tuning_config()
	assert_int(cfg2.base_atk).is_equal(6)
	tc.free()


# ── AC-TC-13(嵌套) — 改副本的 floor_tuning_table 行不污染内部（深拷贝隔离）──────
func test_get_tuning_config_nested_row_is_deep_copied() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	var cfg: TuningConfigData = tc.get_tuning_config()
	# 改副本第一行的字段
	cfg.floor_tuning_table[0].player_atk_expected = 999
	# 再取一次，内部嵌套行不应被污染
	var cfg2: TuningConfigData = tc.get_tuning_config()
	assert_int(cfg2.floor_tuning_table[0].player_atk_expected).is_equal(14)
	tc.free()


# ── 边界：floor1 首行可查 ──────────────────────────────────────────────────────
func test_get_floor_tuning_floor1_returns_correct_first_row() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	var row: FloorTuningRow = tc.get_floor_tuning(1)
	assert_object(row).is_not_null()
	assert_int(row.player_atk_expected).is_equal(14)
	assert_int(row.player_def_expected).is_equal(8)
	assert_int(row.player_hp_expected).is_equal(100)
	tc.free()


# ── 边界：floor_number=0 边界值返回 null ──────────────────────────────────────
func test_get_floor_tuning_zero_returns_null() -> void:
	var tc := TuningConfig.new()
	tc._inject_config_for_test(_make_test_config())
	assert_object(tc.get_floor_tuning(0)).is_null()
	tc.free()
