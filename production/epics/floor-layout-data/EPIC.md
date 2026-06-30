# Epic: 楼层关卡数据系统 (FloorDB)

> **Layer**: Foundation
> **GDD**: design/gdd/floor-layout-data.md
> **Architecture Module**: #2 FloorDB (Autoload — EntityDB 之后)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories floor-layout-data`
> **Manifest Version**: 2026-06-29

## Overview

所有楼层布局的唯一静态数据来源,以 16×16 网格存储每层内容（空地/墙/怪物/道具/钥匙/门/楼梯/玩家起点），启动一次性加载进内存,运行期只读。MVP 共 **3 层**手工固定关卡（已锁定，原「3-5 层」收紧），无随机生成（随机布局为 Alpha+）。所有需要「某格是什么」「玩家从哪出现」「上行楼梯在哪」的系统（#6 网格移动、#9 楼层进程）从本库只读读取。纯数据层,不含格子交互或战斗判断。Autoload,在 EntityDB 之后（F-REF 校验调 EntityDB 查询）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: 数据类型实现 | FloorEntry/CellEntry = `class_name + Resource` 子类，**全字段 @export**；FloorEntry.grid 嵌套用 `duplicate_deep()`（4.5+，@export 才会深拷贝） | MEDIUM |
| ADR-0002: Autoload 启动顺序 | FloorDB 为列表 [3]（EntityDB 后）；`_ready()` assert(EntityDB.is_initialized)；F-REF 查询前守卫 | HIGH |
| ADR-0005: 数据文件组织 | 每层独立 `floor_NNN.json` + `manifest.json` 清单发现（禁 DirAccess）；完整命名字段编码 cell_type | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-floor-001 | 16×16 网格数据结构（FloorEntry.grid: Array[Array[CellEntry]]），启动两遍校验 | ADR-0001, ADR-0005 ✅ |
| TR-floor-002 | 六种 cell_type（EMPTY/WALL/ENTITY/DOOR/STAIR_UP/STAIR_DOWN/PLAYER_START）带条件附加字段 | ADR-0001, ADR-0005 ✅ |
| TR-floor-003 | `get_cell()`/`get_floor()` 返回 `duplicate()` 只读副本，写副本不污染数据库（AC-FL-13） | ADR-0001 ✅ |
| TR-floor-004 | F-SC1d BFS 拓扑校验：防具（盾甲）在第一个哥布林之前必须可达 | ⚠️ 部分 — 校验流程在 ADR-0002，BFS 算法未形式化；story 内定算法或补 quick ADR |
| TR-floor-005 | FloorDB Autoload 启动顺序在 EntityDB 之后（F-REF 校验依赖 EntityDB） | ADR-0002 ✅ |

## ⚠️ 已知 GDD 缺口（实现关卡数据前须解决）

- **Design Constraints 节缺失**：systems-index L189 记 #2 须新增 Design Constraints 节，落实 #4→#2 成长分布约束（「3 层每层 ≥1 次永久成长事件 effect_type∈{ATK_BOOST,DEF_BOOST,MAXHP_BOOST} 的格 ≥1，不含 HP_RESTORE；Floor 1 不豁免；单层成长事件 ≤2；同类更弱装备同层 ≤1」）。当前 GDD 无此节。**关卡 JSON 内容 story 不应在该约束落地前创建**（结构/加载/校验类 story 不受影响，可先做）。建议 `/quick-design` 或 producer 协调补节。

## Definition of Done

本史诗完成的标准:
- 所有 story 经 `/story-done` 实现、评审、关闭
- `design/gdd/floor-layout-data.md` 全部验收条件验证通过（含补齐后的 Design Constraints）
- 所有 Logic/Integration story 在 `tests/` 有通过测试（含「get_floor 返回 duplicate_deep 副本，改副本 grid 不污染库」「manifest 加载」「F-SC1d 拓扑可达性」单测）
- TR-floor-004 BFS 算法在实现前已形式化（story 内或 quick ADR）
- Design Constraints 节已补并被关卡数据满足

## Next Step

运行 `/create-stories floor-layout-data` 把本史诗拆成可实现的 story（结构/加载/校验类先行；关卡内容类待 Design Constraints 补齐）。
