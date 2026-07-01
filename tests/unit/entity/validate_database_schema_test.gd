## EntityDBValidator schema/引用/唯一性校验单元测试
## story: production/epics/entity-database/story-003-validate-database-schema.md
## 覆盖：AC-10（重复 ID）、AC-08（悬空引用）、AC-16（普通怪稀有掉落）、
##         AC-13（key 颜色不匹配）、AC-18（非法联合组合）、AC-14（FRAGMENT 越界）、
##         全合法数据集回归（含 story-005 等价合法集）
## 运行：godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##         --ignoreHeadlessMode -a res://tests/unit/entity/
extends GdUnitTestSuite


# ── 夹具工厂 ──────────────────────────────────────────────────────────────────

## 标准测试配置（不触发 D1/D3/config 根因误报的通用入参）
func _make_std_config() -> ValidationConfig:
	var cfg := ValidationConfig.new()
	cfg.player_atk_expected = 20
	cfg.player_hp_expected  = 100
	cfg.player_def_expected = 5
	cfg.n_max               = 10
	cfg.hp_budget_ratio     = 0.35
	return cfg


## 构造合法 MonsterEntry（数值满足 D1/D3，不触发数值校验误报）
func _make_monster(
		entry_id: String,
		hp: int = 20,
		atk: int = 5,
		defense: int = 0,
		gold_drop: int = 5,
		is_boss: bool = false,
		rare_drop_item_id: String = "") -> MonsterEntry:
	var e := MonsterEntry.new()
	e.id                 = entry_id
	e.display_name       = entry_id
	e.hp                 = hp
	e.atk                = atk
	e.defense            = defense
	e.gold_drop          = gold_drop
	e.is_boss            = is_boss
	e.rare_drop_item_id  = rare_drop_item_id
	e.entity_type        = MonsterEntry.ENTITY_TYPE_MONSTER
	return e


## 构造合法 ItemEntry（effect_type 默认 HP_RESTORE，不触发联合/FRAGMENT 校验）
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


## 构造合法 KeyEntry（key_color 与 opens_door_color 相等）
func _make_key(
		entry_id: String,
		key_color: int = KeyEntry.KEY_COLOR_YELLOW,
		opens_door_color: int = KeyEntry.KEY_COLOR_YELLOW) -> KeyEntry:
	var e := KeyEntry.new()
	e.id               = entry_id
	e.display_name     = entry_id
	e.entity_type      = KeyEntry.ENTITY_TYPE_KEY
	e.effect_type      = KeyEntry.EFFECT_TYPE_KEY
	e.effect_value     = 0
	e.key_color        = key_color
	e.opens_door_color = opens_door_color
	return e


## 在 errors 数组中查找匹配指定 entry_id 且 code 相符的第一条记录
## F-08：强类型参数 + 循环变量，EntityValidationResult.errors 已是 Array[Dictionary]
func _find_error_by_id_and_code(errors: Array[Dictionary], entry_id: String, code: String) -> Variant:
	for e: Dictionary in errors:
		if e.get("entry_id", "") == entry_id and e.get("code", "") == code:
			return e
	return null


## 统计 errors 中指定 code 的条数
## F-08：强类型参数 + 循环变量
func _count_errors_by_code(errors: Array[Dictionary], code: String) -> int:
	var count := 0
	for e: Dictionary in errors:
		if e.get("code", "") == code:
			count += 1
	return count


# ── AC-10 — 重复 ID（同 entity_type 内）──────────────────────────────────────

## 正向：两条 entity_type=MONSTER、id="test_dup" → is_valid==false，含 DUPLICATE_ID
func test_validator_schema_duplicate_monster_id_returns_error() -> void:
	# Arrange
	var dup1 := _make_monster("test_dup", 20, 5, 0, 5)
	var dup2 := _make_monster("test_dup", 30, 8, 0, 8)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[dup1, dup2], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_dup",
		EntityDBValidator.DUPLICATE_ID)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_dup")
	assert_str((err as Dictionary).get("code", "")).is_equal(EntityDBValidator.DUPLICATE_ID)


## 边界：三条中「两条 id 相同」（e1/e2 重复，e3 不同）→ 恰好一条 DUPLICATE_ID
## 命名说明：「three_entries_two_duplicate」= 三条 entry 中有两条 id 相同（报一次碰撞）
## 不要与「三条全同」场景混淆；全同场景见 test_validator_schema_three_all_same_id_reports_twice
func test_validator_schema_three_entries_two_duplicate_reports_once() -> void:
	# Arrange：e1/e2 同 id，e3 不同 id
	var e1 := _make_monster("test_dup", 20, 5, 0, 5)
	var e2 := _make_monster("test_dup", 30, 8, 0, 8)    # 与 e1 重复
	var e3 := _make_monster("test_unique", 20, 5, 0, 5) # 不重复
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[e1, e2, e3], _make_std_config(), "MVP")
	# Assert：仅 e1/e2 碰撞 → 1 条 DUPLICATE_ID；test_unique 不报
	assert_bool(result.is_valid).is_false()
	assert_int(_count_errors_by_code(result.errors, EntityDBValidator.DUPLICATE_ID)).is_equal(1)
	# test_unique 不含 DUPLICATE_ID
	assert_object(_find_error_by_id_and_code(result.errors, "test_unique",
		EntityDBValidator.DUPLICATE_ID)).is_null()


## 边界（F-12）：三条全同 id → 恰好两条 DUPLICATE_ID（每次碰撞各报一次：n 条同 id → n-1 条）
## 固定现有 pass1 行为（写入前 if table.has(id) → 报一次），防回归。
func test_validator_schema_three_all_same_id_reports_twice() -> void:
	# Arrange：三条全使用同一 id
	var e1 := _make_monster("test_dup", 20, 5, 0, 5)
	var e2 := _make_monster("test_dup", 30, 8, 0, 8)
	var e3 := _make_monster("test_dup", 40, 6, 0, 6)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[e1, e2, e3], _make_std_config(), "MVP")
	# Assert：3 条同 id → 2 次碰撞 → 2 条 DUPLICATE_ID（n-1 条：pass1 每次碰撞独立报）
	assert_bool(result.is_valid).is_false()
	assert_int(_count_errors_by_code(result.errors, EntityDBValidator.DUPLICATE_ID)).is_equal(2)


## 负向：三条 id 各不相同 → 不报 DUPLICATE_ID，is_valid==true
func test_validator_schema_no_duplicate_id_passes() -> void:
	# Arrange
	var e1 := _make_monster("m1", 20, 5, 0, 5)
	var e2 := _make_monster("m2", 20, 5, 0, 5)
	var e3 := _make_monster("m3", 20, 5, 0, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[e1, e2, e3], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(_count_errors_by_code(result.errors, EntityDBValidator.DUPLICATE_ID)).is_equal(0)


# ── AC-08 — 悬空引用（pass2 跨引用）─────────────────────────────────────────

## 正向：test_boss(is_boss=true, rare_drop_item_id="nonexistent_id")，items 无该 id
## → DANGLING_REF；message 含 "nonexistent_id"
func test_validator_schema_dangling_ref_boss_returns_error() -> void:
	# Arrange
	var boss := _make_monster("test_boss", 80, 10, 2, 30, true, "nonexistent_id")
	# Act（无 items 条目）
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[boss], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_boss",
		EntityDBValidator.DANGLING_REF)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_boss")
	assert_str((err as Dictionary).get("field", "")).is_equal("rare_drop_item_id")
	# message 须含无效引用值（AC-08 规格）
	var msg: String = (err as Dictionary).get("message", "")
	assert_str(msg).contains("nonexistent_id")


## 负向：rare_drop_item_id 指向存在的 item → 不报 DANGLING_REF
func test_validator_schema_valid_rare_drop_ref_passes() -> void:
	# Arrange
	var boss  := _make_monster("test_boss", 80, 10, 2, 30, true, "sword_iron")
	var sword := _make_item("sword_iron", ItemEntry.EFFECT_TYPE_ATK_BOOST, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[boss, sword], _make_std_config(), "MVP")
	# Assert — 不含 DANGLING_REF（rare_drop_item_id 引用有效）
	assert_object(_find_error_by_id_and_code(result.errors, "test_boss",
		EntityDBValidator.DANGLING_REF)).is_null()


## 边界：rare_drop_item_id=="" → 不报 DANGLING_REF（空串表示「无稀有掉落」）
func test_validator_schema_empty_rare_drop_id_passes() -> void:
	# Arrange：boss 无稀有掉落（空串）
	var boss := _make_monster("test_boss_noloot", 80, 10, 2, 30, true, "")
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[boss], _make_std_config(), "MVP")
	# Assert
	assert_object(_find_error_by_id_and_code(result.errors, "test_boss_noloot",
		EntityDBValidator.DANGLING_REF)).is_null()


# ── AC-16 — 普通怪稀有掉落（GDD 规则 C6）────────────────────────────────────

## 正向：test_fakeboss(is_boss=false, rare_drop_item_id="sword_iron") → NONBOSS_RARE_DROP
func test_validator_schema_nonboss_rare_drop_returns_error() -> void:
	# Arrange
	var fakeboss := _make_monster("test_fakeboss", 50, 10, 0, 10, false, "sword_iron")
	var sword    := _make_item("sword_iron", ItemEntry.EFFECT_TYPE_ATK_BOOST, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[fakeboss, sword], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_fakeboss",
		EntityDBValidator.NONBOSS_RARE_DROP)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_fakeboss")
	assert_str((err as Dictionary).get("field", "")).is_equal("rare_drop_item_id")


## 负向：is_boss=true 带 rare_drop_item_id → 不报 NONBOSS_RARE_DROP
func test_validator_schema_boss_with_rare_drop_no_nonboss_error() -> void:
	# Arrange
	var boss  := _make_monster("real_boss", 80, 10, 2, 30, true, "sword_iron")
	var sword := _make_item("sword_iron", ItemEntry.EFFECT_TYPE_ATK_BOOST, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[boss, sword], _make_std_config(), "MVP")
	# Assert — 不含 NONBOSS_RARE_DROP
	assert_object(_find_error_by_id_and_code(result.errors, "real_boss",
		EntityDBValidator.NONBOSS_RARE_DROP)).is_null()


# ── AC-13 — key 颜色不匹配（GDD 规则 C5）────────────────────────────────────

## 正向：test_badkey(key_color=YELLOW, opens_door_color=BLUE) → KEY_COLOR_MISMATCH
func test_validator_schema_key_color_mismatch_returns_error() -> void:
	# Arrange
	var badkey := _make_key("test_badkey",
		KeyEntry.KEY_COLOR_YELLOW, KeyEntry.KEY_COLOR_BLUE)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[badkey], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_badkey",
		EntityDBValidator.KEY_COLOR_MISMATCH)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_badkey")
	assert_str((err as Dictionary).get("field", "")).is_equal("key_color")


## 负向：key_color==opens_door_color → 不报 KEY_COLOR_MISMATCH
func test_validator_schema_key_color_match_passes() -> void:
	# Arrange
	var key_y := _make_key("key_yellow",
		KeyEntry.KEY_COLOR_YELLOW, KeyEntry.KEY_COLOR_YELLOW)
	var key_b := _make_key("key_blue",
		KeyEntry.KEY_COLOR_BLUE, KeyEntry.KEY_COLOR_BLUE)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[key_y, key_b], _make_std_config(), "MVP")
	# Assert
	assert_int(_count_errors_by_code(result.errors, EntityDBValidator.KEY_COLOR_MISMATCH)).is_equal(0)


# ── AC-18 — 非法联合组合（GDD 规则 C4）──────────────────────────────────────

## 正向：test_itemkey(entity_type=ITEM, effect_type=KEY, effect_value=0) → ILLEGAL_TYPE_EFFECT_COMBO
func test_validator_schema_item_with_key_effect_returns_error() -> void:
	# Arrange：ItemEntry，effect_type 强制设为 KEY（5）
	var bad_item := _make_item("test_itemkey", ItemEntry.EFFECT_TYPE_KEY, 0)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[bad_item], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_itemkey",
		EntityDBValidator.ILLEGAL_TYPE_EFFECT_COMBO)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_itemkey")
	assert_str((err as Dictionary).get("field", "")).is_equal("effect_type")


## 负向：KeyEntry 的 effect_type=KEY → 合法，不报 ILLEGAL_TYPE_EFFECT_COMBO
func test_validator_schema_key_entry_with_key_effect_passes() -> void:
	# Arrange：KeyEntry（entity_type=KEY，effect_type=KEY）为合法组合
	var k := _make_key("key_yellow")
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[k], _make_std_config(), "MVP")
	# Assert
	assert_int(_count_errors_by_code(result.errors,
		EntityDBValidator.ILLEGAL_TYPE_EFFECT_COMBO)).is_equal(0)


# ── AC-14 — FRAGMENT 越界（build_scope 门控）────────────────────────────────

## 正向：MVP scope 下 test_fragment(effect_type=FRAGMENT) → FRAGMENT_OUT_OF_SCOPE
func test_validator_schema_fragment_mvp_scope_returns_error() -> void:
	# Arrange
	var frag := _make_item("test_fragment", ItemEntry.EFFECT_TYPE_FRAGMENT, 1)
	# Act：build_scope="MVP"
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[frag], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_false()
	var err: Variant = _find_error_by_id_and_code(result.errors, "test_fragment",
		EntityDBValidator.FRAGMENT_OUT_OF_SCOPE)
	assert_object(err).is_not_null()
	assert_str((err as Dictionary).get("entry_id", "")).is_equal("test_fragment")
	assert_str((err as Dictionary).get("field", "")).is_equal("effect_type")


## 负向：VS scope 下同数据 → 不报 FRAGMENT_OUT_OF_SCOPE
func test_validator_schema_fragment_vs_scope_passes() -> void:
	# Arrange：同一条 FRAGMENT 道具
	var frag := _make_item("test_fragment", ItemEntry.EFFECT_TYPE_FRAGMENT, 1)
	# Act：build_scope="VS"（FRAGMENT 处理器在 VS 可用）
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[frag], _make_std_config(), "VS")
	# Assert — 不含 FRAGMENT_OUT_OF_SCOPE
	assert_int(_count_errors_by_code(result.errors,
		EntityDBValidator.FRAGMENT_OUT_OF_SCOPE)).is_equal(0)


# ── 全合法数据集回归（确认 schema 校验不误报合法数据）────────────────────────

## 回归：3 怪（普通 x2 + boss x1）+ 7 道具 + 2 钥匙的等价合法集，所有 schema 校验均不报错
## F-11：新增 is_boss=true 的 boss + 有效 rare_drop_item_id（指向集合内 sword_iron），
##        使全合法集真正走一遍 DANGLING_REF happy-path（有效引用 → 不报 DANGLING_REF）
## 等价集参照 story-005 的 MVP 数据规模（确保 schema 层不引入误报）
func test_validator_schema_full_valid_dataset_passes() -> void:
	# Arrange：合法的完整数据集
	# 3 怪物（普通 x2 + boss x1）；数值满足 D1/D3，使用 player_atk_expected=20 std_config
	# slime:  D1 ceil(20/10)=2, damage_per_round=max(1,20-0)=20, 20>=2 pass
	#         D3 n_rounds=ceil(20/20)=1, per_round=max(0,3-5)=0, total=0<=35 pass
	# goblin: D1 ceil(50/10)=5, damage_per_round=max(1,20-5)=15, 15>=5 pass
	#         D3 n_rounds=ceil(50/15)=4, per_round=max(0,8-5)=3, total=12<=35 pass
	# dragon_boss: D1 ceil(60/10)=6, damage_per_round=max(1,20-3)=17, 17>=6 pass
	#              D3 n_rounds=ceil(60/17)=4, per_round=max(0,10-5)=5, total=20<=35 pass
	#              rare_drop_item_id="sword_iron"（集合内存在，happy-path 不报 DANGLING_REF）
	var slime       := _make_monster("slime",       20, 3, 0, 5, false, "")
	var goblin      := _make_monster("goblin",      50, 8, 5, 10, false, "")
	var dragon_boss := _make_monster("dragon_boss", 60, 10, 3, 30, true, "sword_iron")
	# 7 道具（各合法 effect_type，不含 KEY/FRAGMENT）
	var potion_s  := _make_item("potion_small",  ItemEntry.EFFECT_TYPE_HP_RESTORE, 50)
	var potion_l  := _make_item("potion_large",  ItemEntry.EFFECT_TYPE_HP_RESTORE, 100)
	var sword_b   := _make_item("sword_basic",   ItemEntry.EFFECT_TYPE_ATK_BOOST, 3)
	var sword_i   := _make_item("sword_iron",    ItemEntry.EFFECT_TYPE_ATK_BOOST, 5)
	var shield_b  := _make_item("shield_basic",  ItemEntry.EFFECT_TYPE_DEF_BOOST, 2)
	var maxhp_gem := _make_item("crystal_life",  ItemEntry.EFFECT_TYPE_MAXHP_BOOST, 50)
	# stack_rule 设为 HIGHEST_WINS 给武器/盾
	sword_b.stack_rule  = ItemEntry.STACK_RULE_HIGHEST_WINS
	sword_i.stack_rule  = ItemEntry.STACK_RULE_HIGHEST_WINS
	shield_b.stack_rule = ItemEntry.STACK_RULE_HIGHEST_WINS
	var exp_gem   := _make_item("exp_gem", ItemEntry.EFFECT_TYPE_ATK_BOOST, 2)
	# 2 钥匙（颜色匹配）
	var key_y := _make_key("key_yellow", KeyEntry.KEY_COLOR_YELLOW, KeyEntry.KEY_COLOR_YELLOW)
	var key_b := _make_key("key_blue",   KeyEntry.KEY_COLOR_BLUE,   KeyEntry.KEY_COLOR_BLUE)

	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[slime, goblin, dragon_boss,
		 potion_s, potion_l, sword_b, sword_i, shield_b, maxhp_gem, exp_gem,
		 key_y, key_b],
		_make_std_config(),
		"MVP")
	# Assert：全合法数据集不触发任何 schema 错误（含 DANGLING_REF happy-path：dragon_boss 引用有效）
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)
	# 明确断言 DANGLING_REF 未报（有效引用不误报）
	assert_object(_find_error_by_id_and_code(result.errors, "dragon_boss",
		EntityDBValidator.DANGLING_REF)).is_null()


## 回归：空 entries 数组仍通过（边界）
func test_validator_schema_empty_entries_passes() -> void:
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[], _make_std_config(), "MVP")
	# Assert
	assert_bool(result.is_valid).is_true()
	assert_int(result.errors.size()).is_equal(0)


# ── schema 与数值校验并存（确保两类校验同时触发）────────────────────────────

## 当同一 entry 同时触发 schema 与数值违规时，两者都应出现在 errors 中
## 场景：普通怪 rare_drop_item_id 非空（NONBOSS_RARE_DROP）且 hp=0（HP_NONPOSITIVE）
## 注意：hp=0 时数值校验 early-return 不跑 D1/D3，但 schema 校验先跑
func test_validator_schema_and_numeric_both_reported() -> void:
	# Arrange
	var bad := _make_monster("test_bad", 0, 5, 0, 5, false, "sword_iron")
	var sword := _make_item("sword_iron", ItemEntry.EFFECT_TYPE_ATK_BOOST, 5)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[bad, sword], _make_std_config(), "MVP")
	# Assert — 同时含 NONBOSS_RARE_DROP 与 HP_NONPOSITIVE
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_id_and_code(result.errors, "test_bad",
		EntityDBValidator.NONBOSS_RARE_DROP)).is_not_null()
	assert_object(_find_error_by_id_and_code(result.errors, "test_bad",
		EntityDBValidator.HP_NONPOSITIVE)).is_not_null()


# ── config 根因越界 → 跳过 schema 校验（根因优先不变）──────────────────────

## config 越界（n_max=25）时，schema 校验（如 DUPLICATE_ID）也不应出现
## 这验证 config 根因 early-return 未被 story-003 的扩展破坏
func test_validator_schema_config_error_skips_schema_checks() -> void:
	# Arrange
	var cfg := _make_std_config()
	cfg.n_max = 25  # 越界
	var dup1 := _make_monster("test_dup", 20, 5, 0, 5)
	var dup2 := _make_monster("test_dup", 30, 8, 0, 8)
	# Act
	var result: EntityValidationResult = EntityDBValidator.validate_database(
		[dup1, dup2], cfg, "MVP")
	# Assert — 只有 config 根因错误，不含 DUPLICATE_ID
	assert_bool(result.is_valid).is_false()
	assert_object(_find_error_by_id_and_code(result.errors, "",
		EntityDBValidator.N_MAX_OUT_OF_RANGE)).is_not_null()
	assert_int(_count_errors_by_code(result.errors, EntityDBValidator.DUPLICATE_ID)).is_equal(0)
