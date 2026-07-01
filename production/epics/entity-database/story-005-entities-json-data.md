# Story 005: entities.json MVP 数据文件

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: S（1-2h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-005`（WASM JSON 数据文件路径在 `res://` 而非 `user://`，PCK 随包）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005（数据文件组织）
**ADR Decision Summary**: `res://data/entities.json`，含 `monsters`/`items`/`keys` 三个数组；enum 用字符串名；键名与 class 字段名严格一致（snake_case）；`defense` 非 `def`；`rare_drop_item_id` 空用 `""`。

**Engine**: Godot 4.5.2 | **Risk**: LOW（纯数据文件）
**Engine Notes**: N/A — 数据文件，无引擎 API。

**Control Manifest Rules (Foundation)**:
- Required: 数据在 `res://` JSON；enum 字符串名；键名 snake_case 与字段一致
- Forbidden: `user://` 路径；`def` 键名；FRAGMENT/Boss 进 MVP 数据集
- Guardrail: MVP 数据量 < 10KB

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md` Tuning Knobs（MVP 数据表），scoped to this story:*

- [ ] `data/entities.json` 存在，结构为 `{monsters:[], items:[], keys:[]}`，键名与 ADR-0001 字段名一致（snake_case，`defense` 非 `def`）
- [ ] **怪物（GDD Tuning Knobs 权威值，无 Boss）**：`slime`(hp=20,atk=8,defense=2,gold_drop=5,is_boss=false,rare_drop_item_id="")；`goblin`(hp=50,atk=18,defense=5,gold_drop=10,is_boss=false,rare_drop_item_id="")
- [ ] **道具（7 个，无 FRAGMENT）**：potion_small(HP_RESTORE,40,ADDITIVE)、potion_large(HP_RESTORE,80,ADDITIVE)、sword_iron(ATK_BOOST,8,HIGHEST_WINS)、sword_steel(ATK_BOOST,14,HIGHEST_WINS)、shield_wood(DEF_BOOST,5,HIGHEST_WINS)、shield_iron(DEF_BOOST,10,HIGHEST_WINS)、crystal_life(MAXHP_BOOST,50,ADDITIVE)
- [ ] **钥匙（2 个）**：key_yellow(YELLOW/YELLOW)、key_blue(BLUE/BLUE)
- [ ] Smoke：`validate_database(<从 entities.json 加载的 entries>, <从 tuning_config.json 构造的 ValidationConfig>, "MVP")` 返回 `is_valid==true`（真实数据在真实调参下过 D1/D3/schema）

---

## Implementation Notes

*Derived from GDD Tuning Knobs + ADR-0005:*

- **⚠️ 用 GDD Tuning Knobs 表为准，非 ADR-0005 示例**：ADR-0005 的 entities.json 示例（slime atk3/def0、goblin hp30/atk5）是**格式占位**，数值非权威。GDD「MVP 怪物数据表」（slime hp20/atk8/def2/gold5、goblin hp50/atk18/def5/gold10）已过 D1 验证（N_max=10），是权威来源。
- **⚠️ D1/D3 需对真实 TuningConfig 重跑（GDD Open Q1）**：smoke check 用**已落地的** `data/tuning_config.json` 的楼层参数构造 ValidationConfig。GDD D1 示例用 player_ATK_expected=10@floor1-2、20@floor3；须核对 `tuning_config.json` 的 `floor_tuning` 实际值。**若 slime/goblin 在真实 tuning 曲线下未过 D1/D3，是需要回报的真实发现**（调 tuning 或调怪物），在本 story 的 smoke 阶段暴露 → 升级为 blocking 决策点，不静默改数据掩盖。
- 怪物按哪个楼层的 player_expected 验证：slime 属 floor1-2、goblin 属 floor2-3（GDD 示例）。smoke 须对每怪选合适楼层参数（最不利/其出现的最低层）验证。
- JSON 键：`entity_type`/`id`/`hp`/`atk`/`defense`/`gold_drop`/`is_boss`/`rare_drop_item_id`（怪）；`entity_type`/`id`/`effect_type`/`effect_value`/`stack_rule`（道具）；`entity_type`/`id`/`key_color`/`opens_door_color`（钥匙）。
- 无 Boss、无 FRAGMENT、无 rare_drop（所有怪 `is_boss=false`、`rare_drop_item_id=""`）——VS 数据追加不进 MVP。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 001/002/003：类型、校验器（本 story 只写数据 + 跑 smoke）
- Story 006：Autoload 加载此文件 + 运行时校验装配
- VS 数据（skeleton/beast_king/sword_great/fragment）——不进 MVP

---

## QA Test Cases

*Config/Data — smoke check（非单元测试）。*

- **Smoke check**（`production/qa/smoke-*.md` 记录）
  - Setup: 加载 `data/entities.json` → from_dict 构造全部 entries；从 `data/tuning_config.json` 构造 ValidationConfig
  - Verify: `validate_database(entries, config, "MVP").is_valid == true`；抽查 `get_monster("slime").hp==20`、`get_item("sword_steel").effect_value==14`、`get_key("key_blue").opens_door_color==BLUE`
  - Pass condition: is_valid==true 且抽查值匹配 GDD Tuning Knobs
  - **若 D1/D3 不过**：记录违反的怪 + computed 值 + 建议调整（降 DEF→降 HP→提该层 ATK 预期，GDD 策略），回报用户决策，**不静默改数据**

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass（`production/qa/smoke-[date].md`）——记录 validate_database 对真实数据 is_valid==true + 抽查值。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（schema/from_dict）、Story 002+003（validate_database 跑 smoke）；TuningConfig（已完成，提供 tuning_config.json）
- Unlocks: Story 006（AC-01 加载成功需真实数据）
