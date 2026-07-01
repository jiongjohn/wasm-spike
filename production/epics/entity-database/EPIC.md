# Epic: 游戏实体数据库 (EntityDB)

> **Layer**: Foundation
> **GDD**: design/gdd/entity-database.md
> **Architecture Module**: #1 EntityDB (Autoload — TuningConfig 之后)
> **Status**: Ready
> **Stories**: 6 created（见 ## Stories）
> **Manifest Version**: 2026-06-29

## Stories

| # | Story | Type | Status | ADR | 覆盖 TR |
|---|-------|------|--------|-----|---------|
| 001 | 数据类型 + JSON 反序列化器 | Logic | ✅ Complete | ADR-0001, ADR-0005 | TR-entity-003, 004 |
| 002 | validate_database — 数值/公式校验（D1/D3+范围） | Logic | ✅ Complete | ADR-0002, ADR-0005 | TR-entity-001 |
| 003 | validate_database — schema/引用/唯一性（两遍加载） | Logic | ✅ Complete | ADR-0005, ADR-0002 | TR-entity-001, 003 |
| 004 | 查询接口 + 只读副本 | Logic | ✅ Complete | ADR-0001 | TR-entity-002 |
| 005 | entities.json MVP 数据文件 | Config/Data | ✅ Complete | ADR-0005 | TR-entity-005 |
| 006 | Autoload 装配 + 启动校验集成 | Integration | ⛔ Blocked | ADR-0002, ADR-0005 | TR-entity-001, 005, 006 |

> **⛔ 006 BLOCKED（2026-07-01，架构）**：Godot 4.5.2 `class_name X` + 同名 autoload `X` → `Parse Error: Class hides an autoload singleton`（实证）。证伪 ADR-0008 E-1，破坏 ADR-0002 autoload 模板。须先 `/architecture-decision` 修订 ADR-0002 + 订正 ADR-0008 E-1 选定 autoload 命名约定（影响全部 11 个计划 autoload），再重做 006。逻辑已由 engine-programmer 草稿（逐楼层校验 + 错误屏 + DI seam）。见记忆 godot-autoload-classname-conflict。

> 实现建议序：001（类型）→ 002（数值校验，建 validate_database 骨架）→ 003（schema 校验，扩展）→ 004（查询）→ 005（数据 + smoke）→ 006（Autoload 集成）。
> 20 条 GDD AC 全覆盖：001=AC-09；002=AC-02/03/04/07/15/17/20；003=AC-08/10/13/14/16/18；004=AC-05/06/11/12；005=数据 smoke；006=AC-01/19。

## Overview

所有静态游戏对象属性的唯一权威来源,定义三类实体:怪物(Monsters)、道具(Items)、钥匙(Keys)。所有需要「某怪物 ATK 多少」「某道具恢复多少 HP」「这钥匙开哪种门」的系统（确定性战斗、玩家成长、网格移动、钥匙门、掉落奖励）都从本库只读读取,自身不维护副本。纯数据层,无游戏逻辑;数据由关卡设计师手填,启动一次性加载进内存,运行期只读;无可见 UI,但支撑 MVP 中 6 个系统的运算。Autoload,在 TuningConfig 之后加载（D1/D3 校验需 TuningConfig 参数）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: 数据类型实现 | MonsterEntry/ItemEntry/KeyEntry = `class_name + Resource` 子类，**全字段 @export**；getter 返回 `.duplicate()` 副本（扁平浅拷贝）；道具叠加 HIGHEST_WINS/ADDITIVE 由数据字段表达 | MEDIUM |
| ADR-0002: Autoload 启动顺序 | EntityDB 为列表 [2]（TuningConfig 后）；`_ready()` assert(TuningConfig.is_initialized)；启动校验失败禁 OS.quit()，内联错误屏 | HIGH |
| ADR-0005: 数据文件组织 | `res://data/entities.json`（monsters/items/keys 三数组）；`from_dict` 静态工厂 + `int()` 转型；缺字段 push_error 返回 null；enum 用字符串名；`defense` 非 `def` | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-entity-001 | 启动 D1/D3 校验（需 TuningConfig 就绪后执行） | ADR-0002 ✅ |
| TR-entity-002 | 只读访问模式（getter 返回 `duplicate()` 副本，下游写入不污染数据库） | ADR-0001 ✅ |
| TR-entity-003 | `entity_type` 判别字段（MONSTER/ITEM/KEY），所有条目必须携带 | ADR-0001, ADR-0005 ✅ |
| TR-entity-004 | 道具叠加规则：HIGHEST_WINS（ATK/DEF 装备）vs ADDITIVE（MaxHP） | ADR-0001, ADR-0005 ✅ |
| TR-entity-005 | WASM JSON 数据文件路径在 `res://` 而非 `user://`（PCK 随包） | ADR-0005 ✅ |
| TR-entity-006 | 启动校验失败：显示 inline 错误屏（禁止 `OS.quit()`，WASM 兼容） | ADR-0002 ✅ |

## Definition of Done

本史诗完成的标准:
- 所有 story 经 `/story-done` 实现、评审、关闭
- `design/gdd/entity-database.md` 全部验收条件验证通过
- 所有 Logic/Integration story 在 `tests/` 有通过的测试文件（含「getter 返回副本，写副本不污染库」「缺字段报错不崩」「叠加规则」单测）
- 所有 Visual/Feel 与 UI story 在 `production/qa/evidence/` 有带签字证据（本系统纯数据层，预计无 Visual）

## Next Step

运行 `/create-stories entity-database` 把本史诗拆成可实现的 story。
