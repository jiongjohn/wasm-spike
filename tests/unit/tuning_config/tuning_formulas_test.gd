## TuningFormulas 单测 — 覆盖 AC-TC-07/08/09/10/14 及边界值
##
## story: production/epics/game-tuning-config/story-003-tuning-formulas.md
## 运行命令：godot --headless --script tests/gdunit4_runner.gd
extends GdUnitTestSuite


# ── AC-TC-07 — F1-A 正常伤害：max(1, 14-8) = 6 ──────────────────────────────
func test_damage_player_normal_returns_difference() -> void:
	assert_int(TuningFormulas.damage_player(14, 8)).is_equal(6)


# ── AC-TC-08 — F1-A 下限保护：atk(5) < def(10) => max(1,-5) = 1 ──────────────
func test_damage_player_atk_less_than_def_returns_one() -> void:
	assert_int(TuningFormulas.damage_player(5, 10)).is_equal(1)


# ── AC-TC-09 — F1-B 盾格挡：max(0, 5-8) = 0 ────────────────────────────────
func test_damage_monster_shield_blocks_returns_zero() -> void:
	assert_int(TuningFormulas.damage_monster(5, 8)).is_equal(0)


# ── AC-TC-10 — F1-C 回合数：ceil(30/6) = 5 ──────────────────────────────────
func test_n_rounds_standard_case_returns_ceil_result() -> void:
	assert_int(TuningFormulas.n_rounds(30, 14, 8)).is_equal(5)


# ── AC-TC-14 — F3-A HIGHEST_WINS：6 + max(5,8) = 14 ────────────────────────
func test_calc_player_atk_highest_wins_returns_base_plus_max() -> void:
	assert_int(TuningFormulas.calc_player_atk(6, [5, 8])).is_equal(14)


# ── 边界：atk == def => max(1, 0) = 1 ────────────────────────────────────────
func test_damage_player_atk_equals_def_returns_one() -> void:
	assert_int(TuningFormulas.damage_player(8, 8)).is_equal(1)


# ── 边界：n_rounds 整除 => ceil 不增加回合 ────────────────────────────────────
func test_n_rounds_exact_division_returns_exact_count() -> void:
	# ceil(12/4) = 3，整除不多加 1
	assert_int(TuningFormulas.n_rounds(12, 10, 6)).is_equal(3)


# ── 边界：空武器数组 => 裸装 base_atk ────────────────────────────────────────
func test_calc_player_atk_empty_weapons_returns_base_only() -> void:
	assert_int(TuningFormulas.calc_player_atk(6, [])).is_equal(6)
