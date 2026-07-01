## entity_query_test.gd — EntityDB 查询接口 + 只读副本 单元测试
## story: production/epics/entity-database/story-004-query-api-readonly.md
## 覆盖 QA Test Cases: AC-05（查询正确性）、AC-06（副本隔离防污染）、
##                     AC-11（不存在 ID 返回 null）、AC-12（类型分表 + 错类型返 null）
## 全内存构造夹具 + _inject_entries_for_test，不依赖 res:// 文件（headless 安全）
extends GdUnitTestSuite


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助：构造测试用实体（直接用 .new() + 字段赋值，无需 JSON 文件加载）
# ═══════════════════════════════════════════════════════════════════════════════

## 构造 slime MonsterEntry（hp=20, gold_drop=5, is_boss=false, rare_drop_item_id=""）
func _make_slime() -> MonsterEntry:
	var e := MonsterEntry.new()
	e.entity_type       = MonsterEntry.ENTITY_TYPE_MONSTER  # 0
	e.id                = "slime"
	e.display_name      = "史莱姆"
	e.hp                = 20
	e.atk               = 8
	e.defense           = 2
	e.gold_drop         = 5
	e.is_boss           = false
	e.rare_drop_item_id = ""  # "" 表示无稀有掉落（ADR-0001 null↔"" 映射）
	e.floor_first_appears = 1
	e.sprite_id         = ""
	return e


## 构造 key_yellow KeyEntry（key_color=YELLOW, opens_door_color=YELLOW）
func _make_key_yellow() -> KeyEntry:
	var e := KeyEntry.new()
	e.entity_type      = KeyEntry.ENTITY_TYPE_KEY      # 2
	e.id               = "key_yellow"
	e.display_name     = "黄钥匙"
	e.effect_type      = KeyEntry.EFFECT_TYPE_KEY      # 5（固定）
	e.effect_value     = 0
	e.key_color        = KeyEntry.KEY_COLOR_YELLOW     # 0
	e.opens_door_color = KeyEntry.KEY_COLOR_YELLOW     # 0
	e.sprite_id        = ""
	return e


# ═══════════════════════════════════════════════════════════════════════════════
# AC-05 — 查询正确性：get_monster 返回正确字段值
# ═══════════════════════════════════════════════════════════════════════════════

## AC-05：注入 slime → get_monster("slime") 返回 gold_drop==5
func test_get_monster_slime_gold_drop_equals_5() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var entry: MonsterEntry = db.get_monster("slime")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.gold_drop).is_equal(5)
	db.free()


## AC-05：get_monster("slime") 返回 is_boss==false
func test_get_monster_slime_is_boss_equals_false() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var entry: MonsterEntry = db.get_monster("slime")

	# Assert
	assert_object(entry).is_not_null()
	assert_bool(entry.is_boss).is_false()
	db.free()


## AC-05：get_monster("slime") 返回 rare_drop_item_id=="" （无稀有掉落）
func test_get_monster_slime_rare_drop_item_id_is_empty_string() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var entry: MonsterEntry = db.get_monster("slime")

	# Assert
	assert_object(entry).is_not_null()
	assert_str(entry.rare_drop_item_id).is_equal("")
	db.free()


## AC-05：get_monster("slime") 返回 entity_type==MONSTER（==0）
func test_get_monster_slime_entity_type_equals_monster() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var entry: MonsterEntry = db.get_monster("slime")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.entity_type).is_equal(MonsterEntry.ENTITY_TYPE_MONSTER)
	db.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-06 — 副本隔离：写 A.hp 不污染数据库，B.hp 保持原值
# ═══════════════════════════════════════════════════════════════════════════════

## AC-06：A=get_monster("slime"); A.hp=999; B=get_monster("slime") → B.hp==20
func test_get_monster_returns_copy_write_a_does_not_pollute_b() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var a: MonsterEntry = db.get_monster("slime")
	a.hp = 999  # 对副本写入，模拟下游误写

	var b: MonsterEntry = db.get_monster("slime")

	# Assert：B 保持原值，写 A 不污染数据库
	assert_object(b).is_not_null()
	assert_int(b.hp).is_equal(20)
	db.free()


## AC-06（edge case）：连续两次 get_monster 返回不同实例（引用不等）
func test_get_monster_two_calls_return_different_instances() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var a: MonsterEntry = db.get_monster("slime")
	var b: MonsterEntry = db.get_monster("slime")

	# Assert：两个副本是不同的对象引用（duplicate() 每次产生新实例）
	assert_object(a).is_not_same(b)
	db.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-11 — 不存在 ID 返回 null，不抛异常
# ═══════════════════════════════════════════════════════════════════════════════

## AC-11：get_monster("nonexistent_id_xyz") → null
func test_get_monster_nonexistent_id_returns_null() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([_make_slime()], [], [])

	# Act
	var entry: MonsterEntry = db.get_monster("nonexistent_id_xyz")

	# Assert
	assert_object(entry).is_null()
	db.free()


## AC-11（get_item 变体）：get_item("nonexistent_id_xyz") → null
func test_get_item_nonexistent_id_returns_null() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [])

	# Act
	var entry: ItemEntry = db.get_item("nonexistent_id_xyz")

	# Assert
	assert_object(entry).is_null()
	db.free()


## AC-11（get_key 变体）：get_key("nonexistent_id_xyz") → null
func test_get_key_nonexistent_id_returns_null() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [])

	# Act
	var entry: KeyEntry = db.get_key("nonexistent_id_xyz")

	# Assert
	assert_object(entry).is_null()
	db.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-12 — 类型分表：get_key 返回正确 KEY 对象；get_monster/get_item 对 KEY id 返回 null
# ═══════════════════════════════════════════════════════════════════════════════

## AC-12：get_key("key_yellow") 返回 entity_type==KEY
func test_get_key_yellow_entity_type_equals_key() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: KeyEntry = db.get_key("key_yellow")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.entity_type).is_equal(KeyEntry.ENTITY_TYPE_KEY)
	db.free()


## AC-12：get_key("key_yellow") 返回 effect_type==KEY（5）
func test_get_key_yellow_effect_type_equals_key() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: KeyEntry = db.get_key("key_yellow")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.effect_type).is_equal(KeyEntry.EFFECT_TYPE_KEY)
	db.free()


## AC-12：get_key("key_yellow") 返回 key_color==YELLOW（0）
func test_get_key_yellow_key_color_equals_yellow() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: KeyEntry = db.get_key("key_yellow")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.key_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)
	db.free()


## AC-12：get_key("key_yellow") 返回 opens_door_color==YELLOW（0）
func test_get_key_yellow_opens_door_color_equals_yellow() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: KeyEntry = db.get_key("key_yellow")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.opens_door_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)
	db.free()


## AC-12：get_monster("key_yellow") 返回 null（KEY id 不在 monster 表）
func test_get_monster_key_yellow_returns_null() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: MonsterEntry = db.get_monster("key_yellow")

	# Assert
	assert_object(entry).is_null()
	db.free()


## AC-12：get_item("key_yellow") 返回 null（get_item 不含 KEY，AC-12 核心约束）
func test_get_item_key_yellow_returns_null() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var entry: ItemEntry = db.get_item("key_yellow")

	# Assert
	assert_object(entry).is_null()
	db.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-05（Item 变体）— get_item 字段正确性（W-05 补测）
# ═══════════════════════════════════════════════════════════════════════════════

## AC-05：注入 sword_iron → get_item("sword_iron") 返回正确字段值
## 覆盖 effect_type / effect_value / stack_rule / entity_type 四字段
func test_get_item_existing_returns_correct_fields() -> void:
	# Arrange
	var sword := ItemEntry.new()
	sword.entity_type  = ItemEntry.ENTITY_TYPE_ITEM         # 1
	sword.id           = "sword_iron"
	sword.display_name = "铁剑"
	sword.effect_type  = ItemEntry.EFFECT_TYPE_ATK_BOOST    # 1
	sword.effect_value = 8
	sword.stack_rule   = ItemEntry.STACK_RULE_HIGHEST_WINS  # 1
	sword.sprite_id    = ""

	var db := EntityDB.new()
	db._inject_entries_for_test([], [sword], [])

	# Act
	var entry: ItemEntry = db.get_item("sword_iron")

	# Assert
	assert_object(entry).is_not_null()
	assert_int(entry.entity_type).is_equal(ItemEntry.ENTITY_TYPE_ITEM)
	assert_int(entry.effect_type).is_equal(ItemEntry.EFFECT_TYPE_ATK_BOOST)
	assert_int(entry.effect_value).is_equal(8)
	assert_int(entry.stack_rule).is_equal(ItemEntry.STACK_RULE_HIGHEST_WINS)
	db.free()


# ═══════════════════════════════════════════════════════════════════════════════
# AC-06（Item / Key 变体）— 副本隔离（W-03 补测）
# ═══════════════════════════════════════════════════════════════════════════════

## AC-06：A=get_item("sword_iron"); A.effect_value=999; B=get_item("sword_iron") → B.effect_value==8
func test_get_item_returns_copy_write_a_does_not_pollute_b() -> void:
	# Arrange
	var sword := ItemEntry.new()
	sword.entity_type  = ItemEntry.ENTITY_TYPE_ITEM
	sword.id           = "sword_iron"
	sword.display_name = "铁剑"
	sword.effect_type  = ItemEntry.EFFECT_TYPE_ATK_BOOST
	sword.effect_value = 8
	sword.stack_rule   = ItemEntry.STACK_RULE_HIGHEST_WINS
	sword.sprite_id    = ""

	var db := EntityDB.new()
	db._inject_entries_for_test([], [sword], [])

	# Act
	var a: ItemEntry = db.get_item("sword_iron")
	a.effect_value = 999  # 对副本写入，模拟下游误写

	var b: ItemEntry = db.get_item("sword_iron")

	# Assert：B 保持原值，写 A 不污染数据库
	assert_object(b).is_not_null()
	assert_int(b.effect_value).is_equal(8)
	assert_object(a).is_not_same(b)
	db.free()


## AC-06：A=get_key("key_yellow"); A.key_color=KeyEntry.KEY_COLOR_BLUE; B=get_key("key_yellow") → B.key_color==KEY_COLOR_YELLOW
func test_get_key_returns_copy_write_a_does_not_pollute_b() -> void:
	# Arrange
	var db := EntityDB.new()
	db._inject_entries_for_test([], [], [_make_key_yellow()])

	# Act
	var a: KeyEntry = db.get_key("key_yellow")
	a.key_color = KeyEntry.KEY_COLOR_BLUE  # 对副本写入，模拟下游误写

	var b: KeyEntry = db.get_key("key_yellow")

	# Assert：B 保持原值，写 A 不污染数据库
	assert_object(b).is_not_null()
	assert_int(b.key_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)
	assert_object(a).is_not_same(b)
	db.free()
