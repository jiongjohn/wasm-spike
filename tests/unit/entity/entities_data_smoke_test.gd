extends GdUnitTestSuite
## entities.json 数据完整性 smoke（story-005，Config/Data）
##
## 验证【已发布的真实数据文件】在【真实 tuning 曲线】下的合法性——不是纯单元逻辑，
## 而是数据交付冒烟：故意读取 res:// 随包数据（data/entities.json + data/tuning_config.json），
## 用 story-001 的 from_dict 构造实体、story-002/003 的 validate_database 校验。
##
## 关键：D1/D3 是逐怪约束，须按【该怪出现的楼层】的 player 期望值校验（GDD Open Q1）。
## 怪的 floor_first_appears 决定用哪一层的 tuning 行（最不利=其首次出现的最低层）。
## slime→floor1、goblin→floor2。若换用其它层会得出不同（甚至违反）结论——见 goblin@floor1 反例。

const ENTITIES_PATH := "res://data/entities.json"
const TUNING_PATH := "res://data/tuning_config.json"


# ── 加载辅助 ──────────────────────────────────────────────────────────────

func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	assert_str(text).override_failure_message("数据文件缺失或为空：%s" % path).is_not_empty()
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).override_failure_message("非法 JSON：%s" % path).is_true()
	return parsed as Dictionary


func _load_monsters(data: Dictionary) -> Array:
	var out: Array = []
	for m: Dictionary in data.get("monsters", []):
		var e := MonsterEntry.from_dict(m, str(m.get("id", "?")))
		assert_object(e).override_failure_message("MonsterEntry from_dict 返回 null：%s" % str(m)).is_not_null()
		out.append(e)
	return out


func _load_items(data: Dictionary) -> Array:
	var out: Array = []
	for it: Dictionary in data.get("items", []):
		var e := ItemEntry.from_dict(it, str(it.get("id", "?")))
		assert_object(e).override_failure_message("ItemEntry from_dict 返回 null：%s" % str(it)).is_not_null()
		out.append(e)
	return out


func _load_keys(data: Dictionary) -> Array:
	var out: Array = []
	for k: Dictionary in data.get("keys", []):
		var e := KeyEntry.from_dict(k, str(k.get("id", "?")))
		assert_object(e).override_failure_message("KeyEntry from_dict 返回 null：%s" % str(k)).is_not_null()
		out.append(e)
	return out


## 从 tuning_config.json 按 floor_number 构造 ValidationConfig（全局 n_max/hp_budget_ratio + 该层 player 期望）
func _config_for_floor(tuning: Dictionary, floor_number: int) -> ValidationConfig:
	var cfg := ValidationConfig.new()
	cfg.n_max = int(tuning["n_max"])
	cfg.hp_budget_ratio = float(tuning["hp_budget_ratio"])
	for row: Dictionary in tuning["floor_tuning_table"]:
		if int(row["floor_number"]) == floor_number:
			cfg.player_atk_expected = int(row["player_atk_expected"])
			cfg.player_def_expected = int(row["player_def_expected"])
			cfg.player_hp_expected = int(row["player_hp_expected"])
			return cfg
	assert_bool(false).override_failure_message("tuning 无 floor_number=%d 行" % floor_number).is_true()
	return cfg


# ── Smoke 用例 ────────────────────────────────────────────────────────────

## 全部实体可从 entities.json 成功构造（from_dict 不返 null）+ 数量正确
func test_smoke_all_entities_construct_from_shipped_json() -> void:
	var data := _load_json(ENTITIES_PATH)
	var monsters := _load_monsters(data)
	var items := _load_items(data)
	var keys := _load_keys(data)
	assert_int(monsters.size()).is_equal(2)
	assert_int(items.size()).is_equal(7)
	assert_int(keys.size()).is_equal(2)


## slime 在 floor1（其首次出现层）真实 tuning 下过 D1/D3/DEF/范围/schema
func test_smoke_slime_valid_at_floor1() -> void:
	var data := _load_json(ENTITIES_PATH)
	var tuning := _load_json(TUNING_PATH)
	var slime: MonsterEntry = _load_monsters(data)[0]
	assert_str(slime.id).is_equal("slime")
	var cfg := _config_for_floor(tuning, 1)  # atk14/def8/hp100
	var result := EntityDBValidator.validate_database([slime], cfg, "MVP")
	assert_bool(result.is_valid).override_failure_message(
		"slime@floor1 校验失败：%s" % str(result.errors)).is_true()


## goblin 在 floor2（其首次出现层）真实 tuning 下过 D1/D3——D3 边距紧（总伤30 vs 预算31）
func test_smoke_goblin_valid_at_floor2() -> void:
	var data := _load_json(ENTITIES_PATH)
	var tuning := _load_json(TUNING_PATH)
	var goblin: MonsterEntry = _load_monsters(data)[1]
	assert_str(goblin.id).is_equal("goblin")
	var cfg := _config_for_floor(tuning, 2)  # atk14/def13/hp90
	var result := EntityDBValidator.validate_database([goblin], cfg, "MVP")
	assert_bool(result.is_valid).override_failure_message(
		"goblin@floor2 校验失败：%s" % str(result.errors)).is_true()
	# D3 边距记录：total_damage_to_kill=30，hp_budget=int(0.35*90)=31（仅差 1，VS 重平衡须复核）
	assert_int(result.computed["goblin"]["total_damage_to_kill"]).is_equal(30)
	assert_int(result.computed["goblin"]["hp_budget"]).is_equal(31)


## 反例固定：goblin 若按 floor1（更弱玩家）校验会 D3 违反——证明「按出现楼层校验」的必要性（供 006 实现参考）
func test_smoke_goblin_would_violate_d3_at_floor1() -> void:
	var data := _load_json(ENTITIES_PATH)
	var tuning := _load_json(TUNING_PATH)
	var goblin: MonsterEntry = _load_monsters(data)[1]
	var cfg := _config_for_floor(tuning, 1)  # atk14/def8/hp100 —— goblin 不在此层
	var result := EntityDBValidator.validate_database([goblin], cfg, "MVP")
	assert_bool(result.is_valid).is_false()
	var has_d3 := false
	for e: Dictionary in result.errors:
		if e.get("code", "") == EntityDBValidator.D3_VIOLATION:
			has_d3 = true
	assert_bool(has_d3).override_failure_message("预期 goblin@floor1 触发 D3_VIOLATION").is_true()


## 道具 + 钥匙的 schema 合法（无 D1/D3；FRAGMENT 越界/联合组合/key 颜色等全过）
func test_smoke_items_and_keys_pass_schema() -> void:
	var data := _load_json(ENTITIES_PATH)
	var tuning := _load_json(TUNING_PATH)
	var entries: Array = _load_items(data) + _load_keys(data)
	var cfg := _config_for_floor(tuning, 1)  # 任意合法层；items/keys 无 D1/D3
	var result := EntityDBValidator.validate_database(entries, cfg, "MVP")
	assert_bool(result.is_valid).override_failure_message(
		"items/keys schema 校验失败：%s" % str(result.errors)).is_true()


## 抽查权威数值（防数据文件被误改偏离 GDD Tuning Knobs）
func test_smoke_spot_check_authoritative_values() -> void:
	var data := _load_json(ENTITIES_PATH)
	var monsters := _load_monsters(data)
	var items := _load_items(data)
	var keys := _load_keys(data)
	# slime hp/gold（GDD 权威）
	assert_int((monsters[0] as MonsterEntry).hp).is_equal(20)
	assert_int((monsters[0] as MonsterEntry).gold_drop).is_equal(5)
	# 精钢剑 effect_value=14
	var steel: ItemEntry = null
	for it: ItemEntry in items:
		if it.id == "sword_steel":
			steel = it
	assert_object(steel).is_not_null()
	assert_int(steel.effect_value).is_equal(14)
	# 蓝钥匙 opens_door_color==BLUE
	var kb: KeyEntry = null
	for k: KeyEntry in keys:
		if k.id == "key_blue":
			kb = k
	assert_object(kb).is_not_null()
	assert_int(kb.opens_door_color).is_equal(KeyEntry.KEY_COLOR_BLUE)


## MVP 数据集不含 FRAGMENT、不含 Boss（GDD C6 / C9：VS 才引入）
func test_smoke_mvp_dataset_has_no_fragment_no_boss() -> void:
	var data := _load_json(ENTITIES_PATH)
	for m: MonsterEntry in _load_monsters(data):
		assert_bool(m.is_boss).override_failure_message("MVP 不应含 Boss：%s" % m.id).is_false()
		assert_str(m.rare_drop_item_id).override_failure_message("MVP 普通怪不应有 rare_drop：%s" % m.id).is_empty()
	for it: ItemEntry in _load_items(data):
		assert_int(it.effect_type).override_failure_message("MVP 不应含 FRAGMENT：%s" % it.id).is_not_equal(ItemEntry.EFFECT_TYPE_FRAGMENT)
