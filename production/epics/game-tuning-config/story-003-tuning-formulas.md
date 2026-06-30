# Story 003: TuningFormulas 静态公式类

> **Epic**: 游戏调参配置 (TuningConfig)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S（~2h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30
> **Completed**: 2026-06-30

## Context

**GDD**: `design/gdd/game-tuning-config.md`
**Requirement**: `TR-tuning-002`（TuningFormulas 为独立静态函数类，可 headless 测试，不依赖场景树）

**ADR Governing Implementation**: ADR-0003（主）
**ADR Decision Summary**: ADR-0003 模块表将 `TuningFormulas` 指定为 TuningConfig 的伴随**静态工具类**（`damage_player` / `damage_monster` / `n_rounds`）。GDD Open Q1 推荐方案 (b) 独立静态函数——本 story 据此锁定（解决 TR-tuning-002 的 ⚠️ 部分覆盖）。

> **⚠️ TR-tuning-002 原为部分覆盖**（ADR-0003 模块表隐含、无独立决策文本）。本 story 内显式锁定为「独立 `class_name TuningFormulas`（无 extends Node/Resource 依赖，纯 static func）」。若实现中发现需更强约束，补 quick ADR。

**Engine**: Godot 4.5.2 | **Risk**: LOW
**Engine Notes**: 纯整数运算静态函数,无 post-cutoff API,无场景树依赖。`ceil()` 结果存为 int（GDScript `ceil()` 返回 float，须 `int(ceil(...))`）。

**Control Manifest Rules (Core/Global)**:
- Required: 核心逻辑 headless 可测（静态纯函数,`TuningFormulas.x()` 直接调用断言）；所有公共 API 强类型
- Forbidden: 在 #5 战斗系统内重复定义伤害公式（TuningFormulas 是规范原语,#5 消费,见下方跨系统注）

---

## Acceptance Criteria

*From GDD `design/gdd/game-tuning-config.md`, scoped to this story:*

- [ ] AC-TC-07：`damage_player(14, 8) == 6`（max(1,14-8)）
- [ ] AC-TC-08：`damage_player(5, 10) == 1`（max(1,5-10) 下限保护——玩家永远能伤怪）
- [ ] AC-TC-09：`damage_monster(5, 8) == 0`（max(0,5-8) 盾完全格挡）
- [ ] AC-TC-10：`n_rounds(30, 14, 8) == 5`（ceil(30/6)）
- [ ] AC-TC-14：`calc_player_ATK(6, [5, 8]) == 14`（6 + max(5,8)，HIGHEST_WINS）

---

## Implementation Notes

*Derived from ADR-0003 module table + GDD F1-A/F1-B/F1-C/F3-A:*

- `class_name TuningFormulas`（独立静态工具类,不 extends 场景类型；纯 `static func`）。
- `static func damage_player(player_atk: int, monster_def: int) -> int`：`return max(1, player_atk - monster_def)`（F1-A，下限 1）
- `static func damage_monster(monster_atk: int, player_def: int) -> int`：`return max(0, monster_atk - player_def)`（F1-B，下限 0；与 F1-A 非对称）
- `static func n_rounds(monster_hp: int, player_atk: int, monster_def: int) -> int`：`return int(ceil(float(monster_hp) / float(max(1, player_atk - monster_def))))`（F1-C；注意整除/ceil 用 float 再转 int）
- `static func calc_player_ATK(base_atk: int, weapon_effect_values: Array) -> int`：`return base_atk + (weapon_effect_values.max() if not weapon_effect_values.is_empty() else 0)`（F3-A，HIGHEST_WINS，空集 default 0）
- 全整数运算；无随机数；无副作用。

**跨系统注**：本类是 #5 确定性战斗消费的**规范伤害公式原语**。ADR-0006 的 `generate_round_sequence` 在构建回合序列时应**调用 TuningFormulas.damage_player/damage_monster**,不得在战斗系统内另写 `max(1,a-d)`（防双路数值漂移；与 GDD Dependencies「#5 引用 F1-A/F1-B 而非自行定义」一致）。

---

## Out of Scope

- Story 001/002：数据类型/加载/校验
- F1-D（battle_duration）、F2-A（表查询，已在 001 的 get_floor_tuning）、F4-A（离线关卡设计工具公式）——非本 story；F4-A 属离线工具,不进运行时
- #5 战斗回合序列逻辑（ADR-0006，本 story 仅提供被其调用的原语）

---

## QA Test Cases

*由 GDD AC 直接转写。纯函数,直接调用断言。*

- **AC-TC-07 / 08**（damage_player）
  - Given/When/Then: `damage_player(14,8)==6`；`damage_player(5,10)==1`
  - Edge cases: atk==def（max(1,0)=1）；atk 远大于 def（无上限钳制）；def=0

- **AC-TC-09**（damage_monster）
  - Given/When/Then: `damage_monster(5,8)==0`
  - Edge cases: atk==def（=0）；atk>def（正常正值）；player_def=0（全额受伤）

- **AC-TC-10**（n_rounds）
  - Given/When/Then: `n_rounds(30,14,8)==5`（ceil(30/6)）
  - Edge cases: 整除（hp=30,净伤=6→5 而非 5.x）；one-shot（hp≤净伤→1）；净伤=1 死磨（hp=20→20 回合）；atk≤def 时净伤钳制为 1（不可除零）

- **AC-TC-14**（calc_player_ATK，HIGHEST_WINS）
  - Given/When/Then: `calc_player_ATK(6,[5,8])==14`
  - Edge cases: 空数组→base（裸装 6）；单元素；相等值；乱序（[8,5] 同 14）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tuning_config/tuning_formulas_test.gd` — 须存在且通过（GDUnit4 headless）。纯函数,最适合参数化测试。

**Status**: [x] 实现 + GDUnit4 测试通过 —— 2026-06-30 re-pin Godot 4.5.2 后，GDUnit4 v6.0.0 跑通全部 8 个测试（8 cases / 0 failures，真框架，spike 工程内验证）。代码逻辑亦经独立脚本 8/8。**剩余形式化前置**：主项目尚无 project.godot + addons/gdUnit4，须初始化主工程后在主项目内重跑测试 → 方可正式 /story-done（逻辑+框架兼容性均已证）

---

## Dependencies

- Depends on: None（纯函数,无依赖——**最易,建议作为本 epic 首个落地、用以确认 GDUnit4 headless 流程**）
- Unlocks: #5 确定性战斗（ADR-0006 generate_round_sequence 调用本类原语）；#4 玩家属性（calc_player_ATK）

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 5/5 通过（全 AC 经 GDUnit4 自动测试覆盖 + 额外 3 条边界值）
**Deviations**: None（TR-tuning-002 独立静态类规格完全满足；code-review W1 命名+W2 类型已修）
**Test Evidence**: Logic — `tests/unit/tuning_config/tuning_formulas_test.gd`（8 test cases / 0 failures / PASSED 276ms，Godot 4.5.2 + GDUnit4 v6.0.0）
**Code Review**: Complete（score 82 → W1 calc_player_ATK→calc_player_atk + W2 Array→Array[int] 已修，重测通过）
**Engine**: Godot 4.5.2（re-pinned from 4.6.3 本会话内完成；GDUnit4 v6 在 4.5.2 可用，4.6.3 不可用）
