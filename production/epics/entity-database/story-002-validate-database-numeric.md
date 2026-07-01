# Story 002: validate_database — 数值/公式校验（D1/D3 + 范围）

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L（4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-001`（启动 D1/D3 校验，需 TuningConfig 就绪后执行——本 story 实现校验**逻辑**，参数经依赖注入；执行时机在 006）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002（校验流程/依赖注入，主）；ADR-0005（数据合法性约束，次）
**ADR Decision Summary**: 校验器通过 `ValidationConfig` 依赖注入构造，**不依赖全局 Autoload**（headless 可测）。校验失败以结构化 `ValidationResult{is_valid, errors[], computed{}}` 返回（每条 error 含 `entry_id`/`field`/`code`/`message`）；所有伤害/预算中间值存入 `computed` 前须 `int()` 化。

**Engine**: Godot 4.5.2 | **Risk**: MEDIUM
**Engine Notes**: 纯函数校验，不触场景树（headless 可测）。`assert()` release 被剥离——校验失败用返回 ValidationResult（非 assert）。GDScript `ceil()` 返回 float，须 `int(ceil(...))`；`round()` 类同。

**Control Manifest Rules (Foundation)**:
- Required: ValidationConfig 依赖注入；computed 中间值 `int()` 化；结构化 errors（entry_id/field/code/message）
- Forbidden: 校验依赖全局 Autoload；只靠 assert 做生产校验；填默认值掩盖非法数据
- Guardrail: 校验在启动一次性执行

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md`, scoped to this story:*

- [ ] 建立 `validate_database(entries: Array, config: ValidationConfig, build_scope: String = "MVP") -> ValidationResult` 骨架 + `ValidationConfig`（`player_atk_expected`/`player_hp_expected`/`player_def_expected`/`n_max`/`hp_budget_ratio`）+ `ValidationResult`（`is_valid`/`errors[]`/`computed{}`）
- [ ] **输入越界根因校验（优先，避免逐怪误报）**：`n_max` 不在 5–20 / `player_atk_expected < 10` / `player_hp_expected < 1` / `hp_budget_ratio < 0.05` → 报单条根因错误，**不**逐怪报 D1/D3 违反
- [ ] **AC-02**：D1 通过路径 — `test_skeleton_valid`(hp=90,def=10)，config.player_atk_expected=35,n_max=10 → `is_valid==true`；`computed["test_skeleton_valid"]["damage_per_round"]==25` 且 `["min_damage_required"]==9`
- [ ] **AC-03**：D1 违反 — `test_tank`(hp=90,def=34)，同 config → `is_valid==false`，errors 含 `entry_id=="test_tank"`/`code=="D1_VIOLATION"`，message 含 `damage_per_round=1 < min_damage_required=9`
- [ ] **AC-15**：DEF 独立上限 — `test_highdef`(hp=20,def=12,atk=5)，player_atk_expected=10（故 def≥atk 净伤钳到 1）→ errors 含 `field=="def"`/`code=="DEF_EXCEEDS_ATK"`，独立于 D1 回合校验
- [ ] **AC-04**：D3 违反 — `test_glasscannon`(hp=50,atk=200,def=0)，player_atk_expected=20,player_hp_expected=100,player_def_expected=0,n_max=10,hp_budget_ratio=0.35 → errors 含 `code=="D3_VIOLATION"`；`computed["test_glasscannon"]["total_damage_to_kill"]==600` 且 `["hp_budget"]==35`
- [ ] **AC-07**：`monster_HP ≤ 0`（含 0 与负）— `test_zero_hp`(hp=0)、`test_neg_hp`(hp=-1) → 两条 `field=="hp"`/`code=="HP_NONPOSITIVE"`
- [ ] **AC-17**：`effect_value < 0` — `test_negval`(HP_RESTORE, effect_value=-10) → `field=="effect_value"`/`code=="NEGATIVE_EFFECT_VALUE"`
- [ ] **AC-20**：`gold_drop < 1` — `test_zerogold`(gold_drop=0) → `field=="gold_drop"`/`code=="INVALID_GOLD_DROP"`

---

## Implementation Notes

*Derived from GDD Formulas D1/D3 + Edge Cases + ADR-0002:*

- 文件：`src/entity/validation_config.gd`（`class_name ValidationConfig`）、`src/entity/entity_validation_result.gd`（`class_name`，参照 TuningConfig 的 ValidationResult；含 `computed: Dictionary`）、`src/entity/entity_db_validator.gd`（`class_name EntityDBValidator`，静态类）。
- **D1**：`min_damage_required = int(ceil(float(monster_hp) / float(n_max)))`；`damage_per_round = max(1, player_atk_expected - monster_def)`；违反条件 `damage_per_round < min_damage_required` → `D1_VIOLATION`。两个中间值存 `computed[entry_id]`（`int()` 化）。
- **DEF 独立上限**（AC-15，独立于 D1）：`monster_def >= player_atk_expected` → `DEF_EXCEEDS_ATK`（GDD Formulas D1「HP=1 漏洞」补充；即使 D1 因 HP 小而恒过也须报）。
- **D3**：`player_damage_taken_per_round = max(0, monster_atk - player_def_expected)`；`n_rounds_to_kill = int(ceil(float(monster_hp) / float(max(1, player_atk_expected - monster_def))))`；`total_damage_to_kill = player_damage_taken_per_round * n_rounds_to_kill`；`hp_budget = int(hp_budget_ratio * player_hp_expected)`（向下取整）；违反 `total_damage_to_kill > hp_budget` → `D3_VIOLATION`。两个中间值存 `computed`。
- **根因优先**：config 越界时先报 `N_MAX_OUT_OF_RANGE`/`PLAYER_ATK_EXPECTED_TOO_LOW`/`PLAYER_HP_EXPECTED_TOO_LOW`/`HP_BUDGET_RATIO_TOO_LOW` 并跳过逐怪 D1/D3（避免误导根因）。
- error.field 用 **snake_case**（与 GDD schema 字段名一致：`hp`/`def`/`effect_value`/`gold_drop`）。code 用稳定 UPPER_SNAKE 常量。
- `computed` 对**通过**的 entry 也记录（供 AC-02 断言算法精度）。
- 本 story 只做数值/公式校验；schema/引用/唯一性（悬空引用、重复 ID、key 颜色、非 boss 掉落、FRAGMENT、非法组合）→ 003（同一 validate_database 扩展）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003：两遍加载、悬空引用、重复 ID、key_color、非 boss 稀有掉落、FRAGMENT、entity_type×effect_type 组合（AC-08/10/13/14/16/18）
- Story 006：在 EntityDB._ready() 中用 TuningConfig 楼层参数构造 ValidationConfig 并执行本校验器（运行时装配）
- D2 金币参考公式（GDD 非强制，仅离线工具，不在运行时——不实现）

---

## QA Test Cases

*Transcribed from GDD AC. 每条断言 `is_valid` + `errors[].code`/`entry_id` 或 `computed[entry_id]` 整数值。*

- **AC-02**（D1 通过 + computed 精度）
  - Given: `test_skeleton_valid`(hp=90,def=10)；config.player_atk_expected=35,n_max=10（其余 std_config：player_hp_expected=100,player_def_expected=5,hp_budget_ratio=0.35）
  - When: `validate_database([entry], config, "MVP")`
  - Then: `is_valid==true`；无 `entry_id=="test_skeleton_valid"` 的 error；`computed[...]["damage_per_round"]==25`、`["min_damage_required"]==9`
- **AC-03**（D1 违反）
  - Given: `test_tank`(hp=90,def=34)；player_atk_expected=35,n_max=10
  - Then: `is_valid==false`；一条 `entry_id=="test_tank"`/`code=="D1_VIOLATION"`，message 含 `1 < 9`
- **AC-15**（DEF 独立上限）
  - Given: `test_highdef`(hp=20,def=12,atk=5)；player_atk_expected=10,n_max=10
  - Then: `field=="def"`/`code=="DEF_EXCEEDS_ATK"`；即使 D1 因低 HP 恒过也报
- **AC-04**（D3 违反 + computed）
  - Given: `test_glasscannon`(hp=50,atk=200,def=0)；player_atk_expected=20,player_hp_expected=100,player_def_expected=0,n_max=10,hp_budget_ratio=0.35
  - Then: `code=="D3_VIOLATION"`；`computed[...]["total_damage_to_kill"]==600`、`["hp_budget"]==35`
- **AC-07 / AC-17 / AC-20**（范围违反）
  - Given: 分别 hp=0/hp=-1、effect_value=-10、gold_drop=0
  - Then: 对应 `HP_NONPOSITIVE`(两条)/`NEGATIVE_EFFECT_VALUE`/`INVALID_GOLD_DROP`，field 正确
  - Edge cases: 边界合法值须 PASS——hp=1、effect_value=0、gold_drop=1、n_max=5 与 20、player_atk_expected=10、hp_budget_ratio=0.05
- **根因优先**（负向对照）
  - Given: 一条本会触发 D1 的怪 + config.n_max=25（越界）
  - Then: 只报 `N_MAX_OUT_OF_RANGE`，不报该怪 `D1_VIOLATION`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/validate_database_numeric_test.gd` — 须存在且通过（GDUnit4 headless）。建议参数化（(字段,非法值,期望 code) 组）。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（校验对象是 MonsterEntry/ItemEntry 实例或其 dict）
- Unlocks: Story 003（扩展同一 validate_database）、Story 005（smoke 用校验器）、Story 006（运行时执行）

---

## Completion Notes
**Completed**: 2026-07-01
**Criteria**: 7/7 AC 通过（AC-02/03/04/07/15/17/20）+ 6 边界合法值 + 根因/负向对照 = 23 测试函数全过；审查员手算逐条核对 D1/D3/DEF/computed 公式无误
**Deviations**（均 ADVISORY，已文档化，无遗留 tech debt）:
- `EntityDBValidator.validate_database` / `EntityValidationResult.add_error` 增 `entry_id` 参数（逐怪追踪必需；config 根因错误传 `""`）
- D1/D3 的 `error.field="def"/"atk"` 表「建议优先调参字段」（多因素公式，非唯一根因；AC 不断言 field）——已加代码注释
- DEF_EXCEEDS_ATK 触发时不 early-return，可与 D1_VIOLATION 双报——GDD D1「与 D1 同时检查」，有意为之，已加代码注释
- ValidationConfig/EntityValidationResult 用 `RefCounted`（与 tuning ValidationResult 先例一致；校验辅助对象非 8 个跨模块数据类型，不受 manifest「数据类型用 Resource」约束）
**Out of Scope（留 003）**: 两遍加载/重复 ID/悬空引用/key_color/非 boss 稀有掉落/FRAGMENT 越界/entity_type×effect_type 联合组合
**Test Evidence**: Logic — `tests/unit/entity/validate_database_numeric_test.gd`（23 test cases / 0 failures / PASSED ~0.8s，Godot 4.5.2 + GDUnit4）
**Code Review**: Complete（godot-gdscript-specialist，9/10 → APPROVE WITH SUGGESTIONS；I-05 测试注释 + W-05 DEF 双报注释 + W-01 field 语义注释 已修，重跑 23/23）
**Files**: src/entity/{validation_config,entity_validation_result,entity_db_validator}.gd + tests/unit/entity/validate_database_numeric_test.gd
