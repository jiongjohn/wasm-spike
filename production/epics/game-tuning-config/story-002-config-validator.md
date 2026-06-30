# Story 002: validate_tuning_config 校验器

> **Epic**: 游戏调参配置 (TuningConfig)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M（2-4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/game-tuning-config.md`
**Requirement**: `TR-tuning-001`（纯配置层——校验面；实现 GDD `validate_tuning_config` 契约 + Edge Cases 数据合法性）

**ADR Governing Implementation**: ADR-0005（主）；ADR-0002（次）
**ADR Decision Summary**: 必填字段缺失 → `push_error` + 报错，**不降级、不填默认值**（AC-09 可检测性）；`assert()` 在 release 被剥离，不能作唯一手段。校验结果以结构化对象返回（GDD 契约 `ValidationResult{is_valid, errors[]}`，每条 errors 含 `field`/`code`/`message`）。

**Engine**: Godot 4.5.2 | **Risk**: MEDIUM
**Engine Notes**: 校验逻辑为纯函数,不依赖场景树,headless 可测。`assert()` release 剥离——校验失败用返回 ValidationResult（非 assert）。

**Control Manifest Rules (Foundation)**:
- Required: 缺字段/非法值 → push_error + 返回 null/错误（不填默认）；JSON null-check
- Forbidden: 填默认值掩盖缺失字段；只靠 assert 做生产校验

---

## Acceptance Criteria

*From GDD `design/gdd/game-tuning-config.md`, scoped to this story:*

- [ ] AC-TC-01：合法完整 MVP 配置（3 行）→ `is_valid==true`，errors 长度 0
- [ ] AC-TC-01b：合法 VS 5 行配置 → `is_valid==true`，errors 长度 0（校验器不限行数上限）
- [ ] AC-TC-02：某行 player_ATK_expected=9 → `is_valid==false`，errors 含 `field=="player_ATK_expected"`/`code=="ATK_EXPECTED_TOO_LOW"`
- [ ] AC-TC-03：HP_BUDGET_RATIO=0.04 → errors 含 `field=="HP_BUDGET_RATIO"`/`code=="HP_RATIO_TOO_LOW"`
- [ ] AC-TC-04：N_max=4 → errors 含 `field=="N_max"`/`code=="N_MAX_OUT_OF_RANGE"`
- [ ] AC-TC-05：N_max=21 → 同 code（上下界共用）
- [ ] AC-TC-06：省略 base_MaxHP → errors 含 `field=="base_MaxHP"`/`code=="MISSING_REQUIRED_FIELD"`；不填默认
- [ ] AC-TC-15：BATTLE_ROUND_DURATION=0 → errors 含 `code=="ROUND_DURATION_NON_POSITIVE"`
- [ ] AC-TC-16：base_ATK=0 → errors 含 `field=="base_ATK"`/`code=="BASE_ATK_TOO_LOW"`（存在但非法，区别于缺失）
- [ ] AC-TC-17：base_MaxHP=0 → errors 含 `code=="BASE_MAX_HP_TOO_LOW"`（值非法分支，独立于 null 路径）
- [ ] AC-TC-18：floor_tuning_table 空数组 → errors 含 `code=="EMPTY_TUNING_TABLE"`
- [ ] AC-TC-19：floor_number 重复 → errors 含 `field=="floor_number"`/`code=="DUPLICATE_FLOOR_NUMBER"`

---

## Implementation Notes

*Derived from GDD Edge Cases + ADR-0005:*

- `validate_tuning_config(config: TuningConfigData) -> ValidationResult`；`ValidationResult{ is_valid: bool, errors: Array }`，每条 error = `{field, code, message}`。
- 校验项（GDD Edge Cases）：必填字段存在性（MISSING_REQUIRED_FIELD）；base_ATK≥1、base_DEF≥0、base_MaxHP≥1；N_max∈[5,20]；HP_BUDGET_RATIO∈[0.05,1.0]；BATTLE_ROUND_DURATION>0；floor_tuning_table 非空；每行必填字段 + 行号；player_ATK_expected≥10（D1 硬约束）、player_HP_expected≥1、player_DEF_expected≥0；floor_number 非正/重复。
- 错误用稳定 `code` 常量（AC 断言 code，非 message 文案）。
- 区分「缺失」（AC-TC-06，字段不存在）与「存在但非法」（AC-TC-16/17，字段存在值越界）——不同 code、不同分支。
- 校验器为独立纯函数,不触场景树（headless 可测）。

---

## Out of Scope

- Story 001：数据类型 + 加载 + get_*/只读副本
- Story 003：TuningFormulas 公式
- 「表必须覆盖 floor1..max_floor 全部行」的主动覆盖校验（GDD Open Q3，未定，本 story 不实现，留待 ADR/后续）

---

## QA Test Cases

*由 GDD AC 直接转写。每条断言 `is_valid` + 对应 `errors[].code`。*

- **AC-TC-01 / 01b**（合法路径）
  - Given: 全字段合法的 3 行 / 5 行 config
  - When: `validate_tuning_config(config)`
  - Then: `is_valid==true` && `errors.size()==0`
  - Edge cases: 恰好边界合法值（N_max=5 与 20、HP_BUDGET_RATIO=0.05 与 1.0、base_ATK=1、player_ATK_expected=10）须 PASS

- **AC-TC-02/03/04/05/15/16/17**（单字段非法 → 对应 code）
  - Given: 仅改一个字段为非法值，其余合法
  - When: `validate_tuning_config(config)`
  - Then: `is_valid==false` && errors 含期望 `field`+`code`
  - Edge cases: 一次只破坏一个字段，确保 code 精确归因；上下界双侧（N_max 4 与 21）

- **AC-TC-06**（缺失字段）
  - Given: 省略 base_MaxHP（不赋值/null）
  - When: validate
  - Then: errors 含 `MISSING_REQUIRED_FIELD`；**断言未填默认值**（不出现 base_MaxHP=某默认）
  - Edge cases: 逐个必填字段缺失各测一次

- **AC-TC-18**（空表）/ **AC-TC-19**（重复楼层号）
  - Given: floor_tuning_table=[] / 含两行 floor_number==1
  - When: validate
  - Then: 对应 `EMPTY_TUNING_TABLE` / `DUPLICATE_FLOOR_NUMBER`
  - Edge cases: 三行中两行重复 vs 全不重复（负向对照）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tuning_config/config_validator_test.gd` — 须存在且通过（GDUnit4 headless）。建议参数化（多 (字段,非法值,期望 code) 组）。

**Status**: [x] Complete 2026-06-30 — GDUnit4 34/34 PASSED（Godot 4.5.2）

---

## Dependencies

- Depends on: Story 001（需 TuningConfigData 类型；校验对象是该类型实例）
- Unlocks: TuningConfig Autoload `_ready()` 中调用校验 → 失败显示错误屏（与 #1 EntityDB 启动校验一致）

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 12/12 AC 通过（+ 边界合法值 + 负向对照 = 34 测试函数）
**Deviations**:
- [ADVISORY] API 签名偏离 story 的单一 `validate(config)` → 实现为双函数 `validate_dict(data)`（缺失+范围，AC-TC-06 路径）+ `validate(config)`（仅范围，AC-TC-17 路径）。理由：实例层无法区分"字段未提供"与"提供了 0"；符合 story Implementation Notes 自身建议 + ADR-0005「缺失检测在 dict 层 data.has()」。
- [过程] engine-programmer 初版违反 error.field=snake_case 决策（用 GDD 大小写 + _to_gdd_field_name 翻译），已纠正为全 snake_case。
**Test Evidence**: Logic — `tests/unit/tuning_config/config_validator_test.gd`（34 test cases / 0 failures / PASSED ~1.1s，Godot 4.5.2 + GDUnit4 v6.0.0）
**Code Review**: Complete（score 76 → W3 errors:Array[Dictionary] / W1 per-row fail-fast 注释 / I1 int 截断注释；W2/I2 接受现状）
**Files**: src/tuning_config/{validation_result,tuning_config_validator}.gd + 测试
**新增 code 常量（GDD Edge Cases 全覆盖）**: 含 FLOOR_NUMBER_NON_POSITIVE / BASE_DEF_NEGATIVE / HP_RATIO_TOO_HIGH / HP_EXPECTED_TOO_LOW / DEF_EXPECTED_NEGATIVE（12 AC 之外的 GDD 校验项）
