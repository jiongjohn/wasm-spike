## entity_types_test.gd — EntityDB 数据类型 + from_dict 反序列化器单元测试
## story: production/epics/entity-database/story-001-entity-types-deserializer.md
## 覆盖 QA Test Cases: 类型/字段构造、AC-09 必填字段缺失、KeyEntry effect_value 缺省、enum 未知字符串
## 全内存构造夹具，不依赖 res:// 文件（headless 安全）
extends GdUnitTestSuite


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助：构造合法的 MonsterEntry dict（含全字段）
# ═══════════════════════════════════════════════════════════════════════════════

func _make_monster_dict() -> Dictionary:
	return {
		"entity_type": "MONSTER",
		"id": "slime",
		"display_name": "史莱姆",
		"hp": 20,
		"atk": 8,
		"defense": 2,
		"gold_drop": 5,
		"is_boss": false,
		"rare_drop_item_id": "",
		"floor_first_appears": 1,
		"sprite_id": "slime_idle",
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助：构造合法的 ItemEntry dict（含全字段）
# ═══════════════════════════════════════════════════════════════════════════════

func _make_item_dict() -> Dictionary:
	return {
		"entity_type": "ITEM",
		"id": "potion_small",
		"display_name": "小回血药",
		"effect_type": "HP_RESTORE",
		"effect_value": 40,
		"stack_rule": "ADDITIVE",
		"sprite_id": "potion_small_icon",
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助：构造合法的 KeyEntry dict（含全字段）
# ═══════════════════════════════════════════════════════════════════════════════

func _make_key_dict() -> Dictionary:
	return {
		"entity_type": "KEY",
		"id": "key_yellow",
		"display_name": "黄钥匙",
		"effect_type": "KEY",
		"effect_value": 0,
		"key_color": "YELLOW",
		"opens_door_color": "YELLOW",
		"sprite_id": "key_yellow_icon",
	}


# ═══════════════════════════════════════════════════════════════════════════════
# MonsterEntry 类型/字段构造
# ═══════════════════════════════════════════════════════════════════════════════

## 合法 dict → from_dict 返回非 null，entity_type==MONSTER(0)
func test_monster_entry_valid_dict_returns_non_null() -> void:
	# Arrange
	var data := _make_monster_dict()
	# Act
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "slime")
	# Assert
	assert_object(entry).is_not_null()


## 合法 dict → entity_type 等于 MONSTER=0
func test_monster_entry_entity_type_equals_monster() -> void:
	var entry: MonsterEntry = MonsterEntry.from_dict(_make_monster_dict(), "slime")
	assert_int(entry.entity_type).is_equal(MonsterEntry.ENTITY_TYPE_MONSTER)


## hp/atk/defense/gold_drop 字段为 int（typeof == TYPE_INT）
func test_monster_entry_numeric_fields_are_int_type() -> void:
	var entry: MonsterEntry = MonsterEntry.from_dict(_make_monster_dict(), "slime")
	assert_int(typeof(entry.hp)).is_equal(TYPE_INT)
	assert_int(typeof(entry.atk)).is_equal(TYPE_INT)
	assert_int(typeof(entry.defense)).is_equal(TYPE_INT)
	assert_int(typeof(entry.gold_drop)).is_equal(TYPE_INT)


## hp/atk/defense/gold_drop 字段数值正确
func test_monster_entry_field_values_correct() -> void:
	var entry: MonsterEntry = MonsterEntry.from_dict(_make_monster_dict(), "slime")
	assert_int(entry.hp).is_equal(20)
	assert_int(entry.atk).is_equal(8)
	assert_int(entry.defense).is_equal(2)
	assert_int(entry.gold_drop).is_equal(5)
	assert_bool(entry.is_boss).is_false()


## defense 字段存在（非 def）
func test_monster_entry_has_defense_field_not_def() -> void:
	var entry: MonsterEntry = MonsterEntry.from_dict(_make_monster_dict(), "slime")
	# defense 字段存在且类型正确
	assert_int(typeof(entry.defense)).is_equal(TYPE_INT)
	assert_int(entry.defense).is_equal(2)


## JSON 中 hp 为整数 20（int）→ entry.hp == 20 且 typeof==TYPE_INT
func test_monster_entry_hp_integer_json_value_converts_to_int() -> void:
	var data := _make_monster_dict()
	data["hp"] = 20  # 整数
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "slime_int")
	assert_int(typeof(entry.hp)).is_equal(TYPE_INT)
	assert_int(entry.hp).is_equal(20)


## JSON 中 hp 为浮点 20.0（模拟 JSON.parse_string float 化）→ entry.hp == 20 且 typeof==TYPE_INT
func test_monster_entry_hp_float_json_value_converts_to_int() -> void:
	var data := _make_monster_dict()
	data["hp"] = 20.0  # 模拟 JSON float 化
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "slime_float")
	assert_int(typeof(entry.hp)).is_equal(TYPE_INT)
	assert_int(entry.hp).is_equal(20)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-09 — MonsterEntry 必填字段缺失
# ═══════════════════════════════════════════════════════════════════════════════

## 缺 id → from_dict 返回 null
func test_monster_entry_missing_id_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("id")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_id")
	assert_object(entry).is_null()


## 缺 hp → from_dict 返回 null
func test_monster_entry_missing_hp_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("hp")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_hp")
	assert_object(entry).is_null()


## 缺 atk → from_dict 返回 null（AC-09 核心测试用例）
func test_monster_entry_missing_atk_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("atk")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_atk")
	assert_object(entry).is_null()


## 缺 defense → from_dict 返回 null
func test_monster_entry_missing_defense_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("defense")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_defense")
	assert_object(entry).is_null()


## 缺 gold_drop → from_dict 返回 null
func test_monster_entry_missing_gold_drop_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("gold_drop")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_gold_drop")
	assert_object(entry).is_null()


## 缺 is_boss → from_dict 返回 null
func test_monster_entry_missing_is_boss_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("is_boss")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_is_boss")
	assert_object(entry).is_null()


## 缺 entity_type → from_dict 返回 null
func test_monster_entry_missing_entity_type_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("entity_type")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_entity_type")
	assert_object(entry).is_null()


## 缺 display_name → from_dict 返回 null（W-01/02/03 决策：display_name 必填）
func test_monster_entry_missing_display_name_returns_null() -> void:
	var data := _make_monster_dict()
	data.erase("display_name")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_display_name")
	assert_object(entry).is_null()


# ═══════════════════════════════════════════════════════════════════════════════
# ItemEntry 类型/字段构造
# ═══════════════════════════════════════════════════════════════════════════════

## 合法 dict → from_dict 返回非 null
func test_item_entry_valid_dict_returns_non_null() -> void:
	var entry: ItemEntry = ItemEntry.from_dict(_make_item_dict(), "potion_small")
	assert_object(entry).is_not_null()


## entity_type == ITEM(1)
func test_item_entry_entity_type_equals_item() -> void:
	var entry: ItemEntry = ItemEntry.from_dict(_make_item_dict(), "potion_small")
	assert_int(entry.entity_type).is_equal(ItemEntry.ENTITY_TYPE_ITEM)


## effect_type == HP_RESTORE(0)
func test_item_entry_effect_type_hp_restore_maps_correctly() -> void:
	var entry: ItemEntry = ItemEntry.from_dict(_make_item_dict(), "potion_small")
	assert_int(entry.effect_type).is_equal(ItemEntry.EFFECT_TYPE_HP_RESTORE)


## stack_rule == ADDITIVE(0)
func test_item_entry_stack_rule_additive_maps_correctly() -> void:
	var entry: ItemEntry = ItemEntry.from_dict(_make_item_dict(), "potion_small")
	assert_int(entry.stack_rule).is_equal(ItemEntry.STACK_RULE_ADDITIVE)


## effect_value 为 int 类型
func test_item_entry_effect_value_is_int_type() -> void:
	var data := _make_item_dict()
	data["effect_value"] = 40.0  # 模拟 JSON float 化
	var entry: ItemEntry = ItemEntry.from_dict(data, "potion_small_float")
	assert_int(typeof(entry.effect_value)).is_equal(TYPE_INT)
	assert_int(entry.effect_value).is_equal(40)


## HIGHEST_WINS stack_rule 正确映射
func test_item_entry_stack_rule_highest_wins_maps_correctly() -> void:
	var data := _make_item_dict()
	data["stack_rule"] = "HIGHEST_WINS"
	var entry: ItemEntry = ItemEntry.from_dict(data, "sword_iron")
	assert_int(entry.stack_rule).is_equal(ItemEntry.STACK_RULE_HIGHEST_WINS)


## ATK_BOOST effect_type 正确映射
func test_item_entry_effect_type_atk_boost_maps_correctly() -> void:
	var data := _make_item_dict()
	data["effect_type"] = "ATK_BOOST"
	var entry: ItemEntry = ItemEntry.from_dict(data, "sword_iron")
	assert_int(entry.effect_type).is_equal(ItemEntry.EFFECT_TYPE_ATK_BOOST)


## DEF_BOOST effect_type 正确映射
func test_item_entry_effect_type_def_boost_maps_correctly() -> void:
	var data := _make_item_dict()
	data["effect_type"] = "DEF_BOOST"
	var entry: ItemEntry = ItemEntry.from_dict(data, "shield_wood")
	assert_int(entry.effect_type).is_equal(ItemEntry.EFFECT_TYPE_DEF_BOOST)


## MAXHP_BOOST effect_type 正确映射
func test_item_entry_effect_type_maxhp_boost_maps_correctly() -> void:
	var data := _make_item_dict()
	data["effect_type"] = "MAXHP_BOOST"
	var entry: ItemEntry = ItemEntry.from_dict(data, "crystal_life")
	assert_int(entry.effect_type).is_equal(ItemEntry.EFFECT_TYPE_MAXHP_BOOST)


# ═══════════════════════════════════════════════════════════════════════════════
# enum 未知字符串 → 返回 null
# ═══════════════════════════════════════════════════════════════════════════════

## ItemEntry effect_type 拼写错误 → from_dict 返回 null
func test_item_entry_unknown_effect_type_returns_null() -> void:
	var data := _make_item_dict()
	data["effect_type"] = "HP_RESTOER"  # 拼写错误
	var entry: ItemEntry = ItemEntry.from_dict(data, "x")
	assert_object(entry).is_null()


## ItemEntry stack_rule 未知字符串 → from_dict 返回 null
func test_item_entry_unknown_stack_rule_returns_null() -> void:
	var data := _make_item_dict()
	data["stack_rule"] = "UNKNOWN_RULE"
	var entry: ItemEntry = ItemEntry.from_dict(data, "x")
	assert_object(entry).is_null()


## MonsterEntry entity_type 未知字符串 → from_dict 返回 null
func test_monster_entry_unknown_entity_type_returns_null() -> void:
	var data := _make_monster_dict()
	data["entity_type"] = "UNKNOWN_TYPE"
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "x")
	assert_object(entry).is_null()


# ═══════════════════════════════════════════════════════════════════════════════
# KeyEntry 类型/字段构造
# ═══════════════════════════════════════════════════════════════════════════════

## 合法 dict → from_dict 返回非 null
func test_key_entry_valid_dict_returns_non_null() -> void:
	var entry: KeyEntry = KeyEntry.from_dict(_make_key_dict(), "key_yellow")
	assert_object(entry).is_not_null()


## entity_type == KEY(2)
func test_key_entry_entity_type_equals_key() -> void:
	var entry: KeyEntry = KeyEntry.from_dict(_make_key_dict(), "key_yellow")
	assert_int(entry.entity_type).is_equal(KeyEntry.ENTITY_TYPE_KEY)


## effect_type == KEY(5)
func test_key_entry_effect_type_equals_key() -> void:
	var entry: KeyEntry = KeyEntry.from_dict(_make_key_dict(), "key_yellow")
	assert_int(entry.effect_type).is_equal(KeyEntry.EFFECT_TYPE_KEY)


## key_color == YELLOW(0)，opens_door_color == YELLOW(0)
func test_key_entry_yellow_color_maps_correctly() -> void:
	var entry: KeyEntry = KeyEntry.from_dict(_make_key_dict(), "key_yellow")
	assert_int(entry.key_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)
	assert_int(entry.opens_door_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)


## key_color == BLUE(1)，opens_door_color == BLUE(1)
func test_key_entry_blue_color_maps_correctly() -> void:
	var data := _make_key_dict()
	data["id"] = "key_blue"
	data["key_color"] = "BLUE"
	data["opens_door_color"] = "BLUE"
	var entry: KeyEntry = KeyEntry.from_dict(data, "key_blue")
	assert_int(entry.key_color).is_equal(KeyEntry.KEY_COLOR_BLUE)
	assert_int(entry.opens_door_color).is_equal(KeyEntry.KEY_COLOR_BLUE)


# ═══════════════════════════════════════════════════════════════════════════════
# KeyEntry effect_value 缺省（GDD 规则 C5）
# ═══════════════════════════════════════════════════════════════════════════════

## 无 effect_value 字段 → from_dict 返回非 null，effect_value==0，不报缺失
func test_key_entry_missing_effect_value_defaults_to_zero() -> void:
	var data := _make_key_dict()
	data.erase("effect_value")
	var entry: KeyEntry = KeyEntry.from_dict(data, "key_yellow")
	assert_object(entry).is_not_null()
	assert_int(entry.effect_value).is_equal(0)


## effect_value 为 0 时 typeof==TYPE_INT
func test_key_entry_effect_value_is_int_type() -> void:
	var data := _make_key_dict()
	data.erase("effect_value")
	var entry: KeyEntry = KeyEntry.from_dict(data, "key_yellow")
	assert_int(typeof(entry.effect_value)).is_equal(TYPE_INT)


## 无 effect_type 字段 → from_dict 仍返回非 null，effect_type 固定 KEY(5)
func test_key_entry_missing_effect_type_defaults_to_key() -> void:
	var data := _make_key_dict()
	data.erase("effect_type")
	var entry: KeyEntry = KeyEntry.from_dict(data, "key_yellow")
	assert_object(entry).is_not_null()
	assert_int(entry.effect_type).is_equal(KeyEntry.EFFECT_TYPE_KEY)


# ═══════════════════════════════════════════════════════════════════════════════
# KeyEntry 必填字段缺失
# ═══════════════════════════════════════════════════════════════════════════════

## 缺 key_color → from_dict 返回 null
func test_key_entry_missing_key_color_returns_null() -> void:
	var data := _make_key_dict()
	data.erase("key_color")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_key_color")
	assert_object(entry).is_null()


## 缺 opens_door_color → from_dict 返回 null
func test_key_entry_missing_opens_door_color_returns_null() -> void:
	var data := _make_key_dict()
	data.erase("opens_door_color")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_opens_door_color")
	assert_object(entry).is_null()


## key_color 未知字符串 → from_dict 返回 null
func test_key_entry_unknown_key_color_returns_null() -> void:
	var data := _make_key_dict()
	data["key_color"] = "RED"  # 未知颜色
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_bad_key_color")
	assert_object(entry).is_null()


## opens_door_color 未知字符串 → from_dict 返回 null
func test_key_entry_unknown_opens_door_color_returns_null() -> void:
	var data := _make_key_dict()
	data["opens_door_color"] = "GREEN"  # 未知颜色
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_bad_opens_door_color")
	assert_object(entry).is_null()


# ═══════════════════════════════════════════════════════════════════════════════
# Resource.duplicate() 只读副本独立性（ADR-0001 只读契约冒烟测试）
# ═══════════════════════════════════════════════════════════════════════════════

## MonsterEntry 副本写入不污染原始对象
func test_monster_entry_duplicate_is_independent_from_original() -> void:
	# Arrange
	var entry: MonsterEntry = MonsterEntry.from_dict(_make_monster_dict(), "slime")
	var copy: MonsterEntry = entry.duplicate()
	# Act：修改副本
	copy.hp = 999
	# Assert：原始对象未变
	assert_int(entry.hp).is_equal(20)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-09 — ItemEntry 必填字段缺失（W-05 对称补齐）
# ═══════════════════════════════════════════════════════════════════════════════

## 缺 entity_type → from_dict 返回 null
func test_item_entry_missing_entity_type_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("entity_type")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_entity_type")
	assert_object(entry).is_null()


## 缺 id → from_dict 返回 null
func test_item_entry_missing_id_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("id")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_id")
	assert_object(entry).is_null()


## 缺 display_name → from_dict 返回 null（W-01/02/03 决策：display_name 必填）
func test_item_entry_missing_display_name_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("display_name")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_display_name")
	assert_object(entry).is_null()


## 缺 effect_type → from_dict 返回 null
func test_item_entry_missing_effect_type_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("effect_type")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_effect_type")
	assert_object(entry).is_null()


## 缺 effect_value → from_dict 返回 null
func test_item_entry_missing_effect_value_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("effect_value")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_effect_value")
	assert_object(entry).is_null()


## 缺 stack_rule → from_dict 返回 null
func test_item_entry_missing_stack_rule_returns_null() -> void:
	var data := _make_item_dict()
	data.erase("stack_rule")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_stack_rule")
	assert_object(entry).is_null()


## 缺 sprite_id → from_dict 仍返回非 null，sprite_id 默认为空串（sprite_id 可选）
func test_item_entry_missing_sprite_id_returns_non_null_with_empty_string() -> void:
	var data := _make_item_dict()
	data.erase("sprite_id")
	var entry: ItemEntry = ItemEntry.from_dict(data, "test_missing_sprite_id")
	assert_object(entry).is_not_null()
	assert_str(entry.sprite_id).is_equal("")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-09 — KeyEntry 必填字段缺失（W-05 对称补齐）
# ═══════════════════════════════════════════════════════════════════════════════

## 缺 entity_type → from_dict 返回 null
func test_key_entry_missing_entity_type_returns_null() -> void:
	var data := _make_key_dict()
	data.erase("entity_type")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_entity_type")
	assert_object(entry).is_null()


## 缺 id → from_dict 返回 null
func test_key_entry_missing_id_returns_null() -> void:
	var data := _make_key_dict()
	data.erase("id")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_id")
	assert_object(entry).is_null()


## 缺 display_name → from_dict 返回 null（W-01/02/03 决策：display_name 必填）
func test_key_entry_missing_display_name_returns_null() -> void:
	var data := _make_key_dict()
	data.erase("display_name")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_display_name")
	assert_object(entry).is_null()


## 缺 key_color（已有测试，此处确保逻辑一致）→ 由 test_key_entry_missing_key_color_returns_null 覆盖

## 缺 opens_door_color（已有测试，此处确保逻辑一致）→ 由 test_key_entry_missing_opens_door_color_returns_null 覆盖

## 缺 sprite_id → from_dict 仍返回非 null，sprite_id 默认为空串（sprite_id 可选）
func test_key_entry_missing_sprite_id_returns_non_null_with_empty_string() -> void:
	var data := _make_key_dict()
	data.erase("sprite_id")
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_missing_sprite_id")
	assert_object(entry).is_not_null()
	assert_str(entry.sprite_id).is_equal("")


## MonsterEntry 缺 sprite_id → from_dict 仍返回非 null，sprite_id 默认为空串（sprite_id 可选）
func test_monster_entry_missing_sprite_id_returns_non_null_with_empty_string() -> void:
	var data := _make_monster_dict()
	data.erase("sprite_id")
	var entry: MonsterEntry = MonsterEntry.from_dict(data, "test_missing_sprite_id")
	assert_object(entry).is_not_null()
	assert_str(entry.sprite_id).is_equal("")


# ═══════════════════════════════════════════════════════════════════════════════
# W-04 对应测试 — KeyEntry effect_type = 非 KEY 合法值 → 返回 null
# ═══════════════════════════════════════════════════════════════════════════════

## KeyEntry effect_type = "HP_RESTORE"（合法枚举值但非 KEY）→ from_dict 返回 null（GDD 规则 C5）
func test_key_entry_effect_type_hp_restore_returns_null() -> void:
	var data := _make_key_dict()
	data["effect_type"] = "HP_RESTORE"
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_illegal_effect_type")
	assert_object(entry).is_null()


## KeyEntry effect_type = "ATK_BOOST"（合法枚举值但非 KEY）→ from_dict 返回 null
func test_key_entry_effect_type_atk_boost_returns_null() -> void:
	var data := _make_key_dict()
	data["effect_type"] = "ATK_BOOST"
	var entry: KeyEntry = KeyEntry.from_dict(data, "test_illegal_effect_type_atk")
	assert_object(entry).is_null()


# ═══════════════════════════════════════════════════════════════════════════════
# Resource.duplicate() 只读副本独立性 — ItemEntry / KeyEntry（W-06 对称补齐）
# ═══════════════════════════════════════════════════════════════════════════════

## ItemEntry 副本写入不污染原始对象
func test_item_entry_duplicate_is_independent_from_original() -> void:
	# Arrange
	var entry: ItemEntry = ItemEntry.from_dict(_make_item_dict(), "potion_small")
	var copy: ItemEntry = entry.duplicate()
	# Act：修改副本
	copy.effect_value = 9999
	# Assert：原始对象未变
	assert_int(entry.effect_value).is_equal(40)


## KeyEntry 副本写入不污染原始对象
func test_key_entry_duplicate_is_independent_from_original() -> void:
	# Arrange
	var entry: KeyEntry = KeyEntry.from_dict(_make_key_dict(), "key_yellow")
	var copy: KeyEntry = entry.duplicate()
	# Act：修改副本
	copy.key_color = KeyEntry.KEY_COLOR_BLUE
	# Assert：原始对象未变
	assert_int(entry.key_color).is_equal(KeyEntry.KEY_COLOR_YELLOW)
