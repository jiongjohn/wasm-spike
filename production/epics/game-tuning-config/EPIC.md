# Epic: 游戏调参配置 (TuningConfig)

> **Layer**: Foundation
> **GDD**: design/gdd/game-tuning-config.md
> **Architecture Module**: #3 TuningConfig (Autoload — 首个加载)
> **Status**: ✅ Complete（3/3 stories Done，2026-06-30）
> **Stories**: 3 created（见 ## Stories）
> **Manifest Version**: 2026-06-29

## Stories

| # | Story | Type | Status | ADR | 覆盖 TR |
|---|-------|------|--------|-----|---------|
| 001 | TuningConfig 数据类型 + 加载 + 只读访问 | Logic | ✅ Complete | ADR-0001 | TR-tuning-001, 003 |
| 002 | validate_tuning_config 校验器 | Logic | ✅ Complete | ADR-0005 | TR-tuning-001（校验面）|
| 003 | TuningFormulas 静态公式类 | Logic | ✅ Complete | ADR-0003 | TR-tuning-002 |

> 实现建议序：003（纯函数无依赖，最易，先验 GDUnit4 流程）→ 001（类型+加载）→ 002（校验，依赖 001 类型）。

## Overview

所有平衡参数的集中权威来源:玩家起始属性(HP/ATK/DEF)、各楼层玩家预期中位属性曲线（`player_ATK_expected`/`player_HP_expected`/`player_DEF_expected` 逐层表，供 EntityDB D1/D3 校验与关卡设计参考）、全局战斗参数（伤害公式系数、节奏、D1/D3 约束系数）。纯配置层,JSON 存储,启动一次性加载并校验,运行期只读。是「数据驱动」原则的执行点——调平衡只改 JSON,不改代码。作为 Autoload 列表首个加载（EntityDB 的 D1/D3 校验依赖其参数）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: 数据类型实现 | 跨模块数据类型 = `class_name + Resource` 子类，**全字段 @export**，getter 返回 `duplicate()` 副本（RefCounted 无 duplicate*，已实证修订） | MEDIUM |
| ADR-0002: Autoload 启动顺序 | TuningConfig 为列表 [1] 首个；`is_initialized` 标志 + 同步 `_load_and_validate()`（禁 await） | HIGH |
| ADR-0003: 系统宿主 | TuningConfig = Autoload；**TuningFormulas 为独立静态函数类**（damage_player/damage_monster/n_rounds，headless 可测） | HIGH |
| ADR-0005: 数据文件组织 | `res://data/tuning_config.json`；`int()` 显式转型；缺字段 push_error；JSON null-check | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-tuning-001 | 纯配置层，`get_tuning_config()` 返回只读副本；TuningConfig 本身不含计算逻辑 | ADR-0001, ADR-0003 ✅ |
| TR-tuning-002 | TuningFormulas 为独立静态函数类（damage_player/damage_monster/n_rounds），可 headless 测试，不依赖场景树 | ⚠️ 部分 — ADR-0003 模块表隐含，无明确 ADR 决策；story 内定细节或补 quick ADR |
| TR-tuning-003 | 楼层调参表按 floor_number/floor_id 查询，`get_floor_tuning(n)` 返回 null if not found | ADR-0003, ADR-0005 ✅ |

## Definition of Done

本史诗完成的标准:
- 所有 story 经 `/story-done` 实现、评审、关闭
- `design/gdd/game-tuning-config.md` 全部验收条件验证通过
- 所有 Logic/Integration story 在 `tests/` 有通过的测试文件（TuningFormulas 纯函数须 headless 单测）
- 所有 Visual/Feel 与 UI story 在 `production/qa/evidence/` 有带签字的证据文档（本系统多为 Logic/Config，预计无 Visual）
- TR-tuning-002 的 TuningFormulas 归属在实现前已明确（story 内或 quick ADR）

## Next Step

运行 `/create-stories game-tuning-config` 把本史诗拆成可实现的 story。
