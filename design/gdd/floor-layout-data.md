# 楼层关卡数据系统 (Floor Layout Data)

> **Status**: Approved（第2轮复评 2026-06-25；实现前置：架构 ADR 须确定 FloorEntry/CellEntry 类型 + 启动顺序；F-SC1a/b/c/d AC 待补充）
> **Author**: lumen + agents
> **Last Updated**: 2026-06-24
> **Implements Pillar**: P3「三秒上手」(布局直觉可读) + P4「每层都有新发现」(手工布局创造节奏变化)

## Overview

楼层关卡数据系统是《像素魔塔·无尽塔》中所有**楼层布局的唯一静态数据来源**。它以结构化格式存储每一层的 16×16 网格内容——每个单元格填什么（空地、墙壁、怪物、道具、钥匙、门、楼梯、玩家起点）——供游戏启动时一次性加载到内存，运行期间只读。

MVP 阶段共定义 **3 层**手工固定关卡（已锁定，见 player-stats-growth #4 第4轮评审；原「3-5层」已收紧），所有布局由关卡设计师手工编写，无随机生成（随机楼层布局为 Alpha+ 功能，见 Anti-Pillars）。所有需要知道「某格是什么」「玩家从哪里出现」「上行楼梯在哪里」的系统——包括 #6 网格移动与交互、#9 楼层进程——都从本数据库读取布局，自身不维护副本。

本系统是纯数据层，不包含任何格子交互逻辑或战斗判断。它不为玩家所见，但决定了玩家每一步走到哪里、遇见什么。做得好，玩家感受不到它的存在；数据出错（格子放错了实体 ID、楼梯指向不存在的层），玩家会立即撞墙。

## Player Fantasy

玩家永远不会意识到「楼层数据库」的存在。但他们能感受到它的结果：每一层的格局都合理、直觉可读——钥匙在看得见的地方，门挡在必经路上，楼梯藏在清完障碍之后。玩家下意识地信任「这一层是有逻辑的」，专注于路线决策而非质疑关卡合理性。

做得好，玩家不会说「布局很好」；他们只会自然地继续爬。做得不好（格子引用了不存在的实体、楼梯指向错误的层），玩家会立刻感到「游戏坏了」，直接流失。

> **可证伪判据（供 QA / 玩测验证）：** 在一次完整的 **3 层** MVP 试玩中，玩家**零次**遇到「踩到空白/穿墙」「捡到不存在的道具」「楼梯通向错误的层」「钥匙/门颜色引用无效」的情况。任一出现即视为本系统未交付其隐性 Fantasy。

## Detailed Design

### Core Rules

**规则 F1 — 单一权威来源**
所有楼层布局只在本数据系统中定义一次。其他系统通过只读接口查询，不得维护副本，不得在运行时修改任何格子内容。

**规则 F2 — 固定网格尺寸 16×16**
每层都是 16 列 × 16 行的网格，共 256 格。坐标系使用 `(col, row)`，原点 `(0, 0)` 在左上角，col 向右递增，row 向下递增。所有层采用相同尺寸，与美术规范中的 16×16 格子对齐。

**规则 F3 — 六种单元格类型（扁平，每格唯一）**
每格有且仅有一种 `cell_type`。完整类型集合：

| cell_type | 描述 | 附加字段 |
|---|---|---|
| `EMPTY` | 可行走，无内容 | — |
| `WALL` | 不可穿越障碍物 | — |
| `ENTITY` | 含游戏实体（怪物 / 道具 / 钥匙） | `entity_id: String`（须存在于 EntityDB） |
| `DOOR` | 需对应颜色钥匙才可开启的门 | `door_color: YELLOW \| BLUE` |
| `STAIR_UP` | 上行楼梯（通往更高层） | `target_floor_id: String` |
| `STAIR_DOWN` | 下行楼梯（通往更低层） | `target_floor_id: String` |
| `PLAYER_START` | 玩家进入本层时的初始位置 | — |

**规则 F4 — 楼层记录字段**

| 字段 | 类型 | 约束 | 描述 |
|---|---|---|---|
| `floor_id` | String | 全局唯一，snake_case | 唯一标识符（如 `floor_1`），供楼梯 `target_floor_id` 引用 |
| `floor_number` | int | ≥1，全局唯一 | 显示顺序与楼层号（1-based，1=底层） |
| `grid` | Array[Array[Cell]] | 固定 16 行 × 16 列 | 二维数组，外层为行（row），内层为列（col） |

**规则 F5 — PLAYER_START 唯一性约束**
每层必须有**恰好一个** `PLAYER_START` 格。零个或多个 PLAYER_START 均为数据错误，启动校验报错，不进入游戏。

**规则 F6 — ENTITY 引用完整性**
ENTITY 格的 `entity_id` 必须是 EntityDB 中存在的合法 ID（MONSTER、ITEM 或 KEY 类型均可）。引用不存在 ID 为悬挂引用错误，启动校验第二遍捕获。

**规则 F7 — DOOR 颜色约束**
`door_color` 必须为 `YELLOW` 或 `BLUE`（与 EntityDB 中 KeyEntry 的 `opens_door_color` 枚举一致）。其他值报错。

**规则 F8 — STAIR 引用完整性与方向约束**
- `target_floor_id` 必须引用本楼层集合中另一层的合法 `floor_id`（不得自引用）。
- `STAIR_UP` 的目标层 `floor_number` 必须 > 当前层；`STAIR_DOWN` 的目标层 `floor_number` 必须 < 当前层。违反方向约束为数据错误。

**规则 F9 — MVP 楼层集合约束**
MVP 定义 **3 个楼层**（固定，见 F-MVP 约束）。底层（`floor_number=1`）须有 `PLAYER_START`，不要求有 `STAIR_DOWN`（无下方楼层）。顶层的退出逻辑（`STAIR_UP` 通向通关状态还是下一楼段）由 #9 楼层进程定义。

**规则 F10 — 只读原则：布局 vs 运行时状态**
楼层布局记录**初始放置状态**——它定义"这一格初始有一只史莱姆"，不记录"史莱姆是否已被击败"。击败 / 捡起实体后的**格子运行时状态**（哪些格子已清空）由 #9 楼层进程维护，本数据系统不持有运行时状态。

---

### States and Transitions

本系统无运行时状态变化。加载流程：

1. 游戏启动 → 从 `res://data/floors/` 读取所有楼层 JSON 文件
2. **第一遍**：逐层加载格子，检测格式错误、必填字段缺失、PLAYER_START 数量
3. **第二遍**：跨引用校验（ENTITY 的 `entity_id` 是否在 EntityDB 中存在；STAIR 的 `target_floor_id` 是否在已加载楼层集合中；STAIR 方向是否合法）
4. 全部通过 → 数据就绪，供下游系统查询（只读）
5. 任一失败 → 不进入游戏，显示错误屏（WASM 端须纯代码内联构建，见 Edge Cases）

---

### Interactions with Other Systems

| 下游系统 | 查询内容 | 接口方向 |
|---|---|---|
| #6 网格移动与交互 | `get_cell(floor_id, col, row)` → cell_type + 附加字段 | 读取 FloorEntry |
| #9 楼层进程 | `get_floor(floor_id)` → 楼层元数据、STAIR target | 读取 FloorEntry |
| #15 容错安全（VS） | 全层格子布局（寻路分析） | 读取 FloorEntry |
| #16 商店（VS） | 商店格的 entity_id | 读取 ENTITY 格 |

## Formulas

> 本节包含**布局合法性约束公式**，供启动时校验器运行。所有公式均为强制（违反则不进入游戏）。D1/D3 为转引，由 entity-database.md 定义并在 EntityDB 加载阶段执行；本系统校验须在其之后运行（启动顺序：EntityDB 加载 → FloorDB 第一遍 → FloorDB 第二遍）。

---

### 公式 F-G1 — 网格尺寸严格校验

```
rows(floor.grid) == 16
AND ∀ row r ∈ floor.grid: len(r) == 16
```

| 变量 | 类型 | 约束 | 描述 |
|---|---|---|---|
| `rows(floor.grid)` | int | 须为 16 | floor.grid 外层数组长度（行数） |
| `len(r)` | int | 须为 16 | 每行内层数组长度（列数） |

**输出**：布尔值（通过/违反）。违反时报告 `floor_id + 实际行数或列数`。
**执行轮次**：第一遍（格式校验）。

---

### 公式 F-G2 — cell_type 枚举完备性

```
∀ cell ∈ floor.grid: cell.cell_type ∈ {EMPTY, WALL, ENTITY, DOOR, STAIR_UP, STAIR_DOWN, PLAYER_START}
```

**输出**：布尔值。违反时报告 `floor_id + (col, row) + 非法 cell_type 值`。防御拼写错误（如 `"STAR_UP"`）被静默忽略。
**执行轮次**：第一遍。

---

### 公式 F-G3 — 附加字段存在性

```
cell.cell_type = ENTITY   → cell.entity_id 字段存在且非空字符串
cell.cell_type = DOOR     → cell.door_color 字段存在且非空
cell.cell_type ∈ {STAIR_UP, STAIR_DOWN} → cell.target_floor_id 字段存在且非空
cell.cell_type ∈ {EMPTY, WALL, PLAYER_START} → 无必填附加字段（出现多余字段报 WARNING）
```

**输出**：必填字段缺失为 ERROR；多余字段为 WARNING。报告 `floor_id + (col, row) + 缺失字段名`。
**执行轮次**：第一遍（F-G2 通过后）。

---

### 公式 F-K1 — 单层钥匙-门颜色平衡约束（防死锁）

对每层 `f`，对每种颜色 `c ∈ {YELLOW, BLUE}`：

```
KEY_COUNT(f, c) ≥ DOOR_COUNT(f, c)
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `f` | FloorEntry | 被校验楼层 |
| `c` | Enum | `YELLOW` 或 `BLUE` |
| `KEY_COUNT(f, c)` | int | 层 f 中 entity_id 指向 `entity_type=KEY` 且 `key_color=c` 的 ENTITY 格数量 |
| `DOOR_COUNT(f, c)` | int | 层 f 中 `cell_type=DOOR` 且 `door_color=c` 的格数量 |

**输出**：布尔值。违反时报告 `floor_id + 颜色 + KEY_COUNT + DOOR_COUNT`。
**策略**：单层封闭（不跨层累积）。本数据层不持有运行时钥匙状态（规则 F10），此处保证「最差情况下（玩家进层时无钥匙）」该层自洽。设计师可有意让玩家从下层携带钥匙作为奖励，但数据层不依赖这一假设。
**执行轮次**：第二遍（F6 引用完整性之后，才能查询 EntityDB 获取 key_color）。

**示例验证（MVP 布局参考）：**

| 层 | 颜色 | KEY_COUNT | DOOR_COUNT | 结果 |
|---|---|---|---|---|
| floor_1 | YELLOW | 2 | 1 | ✅ 通过 |
| floor_2 | BLUE | 0 | 1 | ❌ 违反，报错 |

---

### 公式 F-R1 — 出口存在性（弱连通性断言）

```
∀ 非顶层楼层 f（floor_number < max_floor_number）：
  STAIR_UP_COUNT(f) ≥ 1
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `f` | FloorEntry | 被校验楼层 |
| `STAIR_UP_COUNT(f)` | int | 层 f 中 `cell_type=STAIR_UP` 的格数量 |
| `max_floor_number` | int | 楼层集合中 `floor_number` 的最大值（顶层豁免） |

**输出**：布尔值。违反时报告 `floor_id + "STAIR_UP_COUNT=0，非顶层楼层必须有上行出口"`。
**说明**：此为必要条件断言（非完整 BFS 连通性验证）。MVP 手工关卡由 QA playtest 补充验证充分连通性；随机楼层引入（Alpha+ #20 系统）时须升级为完整 BFS（DOOR 格视为可穿越）。
**执行轮次**：第一遍。

---

### 公式 F-T1 — MVP 构建 tier 兼容约束

```
当 build_scope = "MVP"：
  ∀ ENTITY 格 cell：EntityDB.lookup(cell.entity_id).tier ≠ VS
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `build_scope` | String | 构建阶段（`"MVP"` 或 `"VS"`） |
| `cell.entity_id` | String | ENTITY 格引用的实体 ID |
| `EntityDB.lookup(...).tier` | Enum | 该实体在 registry 中声明的 tier（MVP/VS） |

**输出**：布尔值。违反时报告 `floor_id + (col, row) + entity_id + "tier=VS 不允许出现在 MVP 构建"`。
**执行轮次**：第二遍（F6 之后，tier 信息需 EntityDB 可查）。

**EntityDB 未就绪防护（重要）**：若 `EntityDB.lookup(entity_id)` 返回 `null`（EntityDB 未完成加载，Autoload 顺序配置错误等），不得视为「tier=null ≠ VS → 静默通过」。**必须报 `code="MISSING_ENTITY_TIER"`**，阻止进入游戏。null 路径静默通过会导致 VS 实体在 MVP 构建中被放行（假阳性），破坏 tier 隔离保证。Open Questions #4（启动顺序形式化保证）须在架构 ADR 中优先决策，此防护是 ADR 落地前的运行时最后防线。

---

### 公式 F-MVP — MVP 楼层数约束

```
当 build_scope = "MVP"：
  COUNT(floors) == 3
```

| 变量 | 类型 | 约束 | 描述 |
|---|---|---|---|
| `build_scope` | String | `"MVP"` 或 `"VS"` 等 | 构建阶段 |
| `COUNT(floors)` | int | 须为 3（MVP） | 已加载楼层总数 |

**输出**：布尔值。违反时（COUNT ≠ 3）报告 `code="INVALID_FLOOR_COUNT_FOR_MVP"`，附实际楼层数。  
**执行轮次**：第一遍（加载完成后立即检查总数）。  
**依据**：player-stats-growth #4 的 Edge Cases 数学推导——MVP 永久成长事件总数=5（4次HIGHEST_WINS + 1次ADDITIVE），对应楼层数上限=3；floor 4+须先引入新成长来源方可解锁。

---

### F-REF-D1 / F-REF-D3（转引，非本 GDD 定义）

> 本系统不重复定义 D1（DEF 上限约束）和 D3（ATK 上限约束）。通过 F6 引用完整性，任何出现在本布局中的怪物（entity_type=MONSTER）已在 EntityDB 加载阶段通过 D1/D3 校验。**本系统校验必须在 EntityDB 校验完成后执行**。详见 `design/gdd/entity-database.md` Formulas 节。

## Design Constraints

> 本节是 player-stats-growth GDD Open Questions 🚧 阻断记录（「#2 floor-layout-data GDD 缺少 Design Constraints 节」）的直接响应。这些约束升格为**强制校验规则**，执行层级与 F-K1 等同——违反则不进入游戏。Tuning Knobs 节的「参考指引」不再是这些约束的权威来源，本节为唯一权威。

### F-SC1a — 每层永久成长事件下限（防 Pillar 1「看得见的成长」静默失效）

```
∀ 楼层 f（包括 floor_number=1，Floor 1 不豁免）：
  GROWTH_EVENT_COUNT(f) ≥ 1
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `f` | FloorEntry | 被校验楼层 |
| `GROWTH_EVENT_COUNT(f)` | int | 层 f 中 `cell_type=ENTITY` 且 `EntityDB.lookup(entity_id).effect_type ∈ {ATK_BOOST, DEF_BOOST, MAXHP_BOOST}` 的格数量（不含 HP_RESTORE） |

**输出**：布尔值。违反时报告 `code="MISSING_GROWTH_EVENT"`，附 `floor_id`。  
**执行轮次**：第二遍（F6 引用完整性之后，需 EntityDB 可查 effect_type）。  
**设计依据**：player-stats-growth Player Fantasy 节承诺「每件道具变强一大截」，每层至少 1 次永久成长事件是该承诺的最低数据层保证。仅靠关卡设计师记忆无法防止 Floor 1 全是药水的设计失误。

---

### F-SC1b — 单层永久成长事件上限（防成长节奏崩塌）

```
∀ 楼层 f：
  GROWTH_EVENT_COUNT(f) ≤ 2
```

**输出**：布尔值。违反时报告 `code="EXCESS_GROWTH_EVENTS"`，附 `floor_id` 和实际数量。  
**执行轮次**：第二遍（与 F-SC1a 同轮）。  
**设计依据**：单层超过 2 次永久成长会使某层成为成长爆炸层，导致后续层成长空洞，破坏跨层成长节奏。player-stats-growth Edge Cases「成长分布约束」已明确此上限。

---

### F-SC1c — 同层同类成长事件数量约束（防连续 item_pickup_no_change 负反馈）

```
∀ 楼层 f，∀ effect_type t ∈ {ATK_BOOST, DEF_BOOST, MAXHP_BOOST}：
  SAME_TYPE_COUNT(f, t) ≤ 1
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `SAME_TYPE_COUNT(f, t)` | int | 层 f 中 effect_type == t 的 ENTITY 格数量 |

**输出**：布尔值。违反时报告 `code="DUPLICATE_EFFECT_TYPE"`，附 `floor_id`、`effect_type`、实际数量。  
**执行轮次**：第二遍。  
**设计依据**：同层放两把武器（同为 ATK_BOOST），玩家捡第二把时因 HIGHEST_WINS 机制得到 `item_pickup_no_change` 负反馈，破坏成长期待。player-stats-growth Edge Cases「成长分布约束」明确「同类更弱装备同层 ≤1」，本公式将其升格为可验证规则。

---

### F-SC1d — Floor 2 盾牌拓扑顺序约束（防 D3 死墙）

> 本约束来源：game-tuning-config GDD 规则 T6 B3 分析（floor 2 goblin D3 余量仅 1 点，依赖关卡布局保证）。

```
Floor 2 中，所有 effect_type = DEF_BOOST 且 effect_value ≥ 10 的 ENTITY 格（即 shield_iron）：
  ∀ 此类 ENTITY 格 e：
    PathToEntity(PLAYER_START, e) 不经过任何 MONSTER ENTITY 格
    （即玩家可在不遭遇任何怪物的情况下先拾取 shield_iron）
```

**输出**：布尔值。违反时报告 `code="SHIELD_BEFORE_GOBLIN_REQUIRED"`，附 floor_id 和 entity 坐标。  
**执行轮次**：第二遍（F6 和 F-SC1a 之后）。  
**实现说明**：路径可达性检查为简化版 BFS（仅遍历 EMPTY/PLAYER_START 格，WALL/DOOR 格视为阻碍，MONSTER 格视为阻断点）。不需要完整连通性验证，仅验证「从 PLAYER_START 到 shield_iron 的某条路径不含 MONSTER」。MVP 3 层手工关卡中，此约束保证玩家在面对 goblin 之前能拿到 shield_iron，避免 D3 预算击穿（rem=1 点）。  
**MVP 范围**：仅应用于 floor_number=2（floor 2 goblin 是 MVP 内唯一超近极限的组合）。VS 阶段引入新高威胁怪物时，须评估是否需要扩展此约束范围。

---

### F-SC1 执行依赖与 AC 注记

F-SC1a/b/c 均属第二遍校验，须在 F6（ENTITY 引用完整性）之后运行（需 EntityDB 提供 effect_type 数据）。`EntityDB.lookup()` 返回 null 时处理规则同 F-T1：视为 MISSING_ENTITY_TIER 错误，不静默通过。

F-SC1 的完整 AC 覆盖见 AC-FL-SC 系列（待 player-stats-growth 联合确认参数后补充）。最低验收要求：F-SC1a 的「Floor 1 缺少 GROWTH_EVENT → MISSING_GROWTH_EVENT 报错」须有专项 AC。

## Edge Cases

**数据合法性（启动校验，违反则不进入游戏并报 floor_id + (col, row) + 错误码）：**

- **`floor_id` 重复**：两个楼层具有相同 `floor_id` 为非法；第一遍建表时捕获（后者不静默覆盖前者），报 `code="DUPLICATE_FLOOR_ID"`。
- **`floor_number` 重复**：两个楼层 `floor_number` 相同为非法，报 `code="DUPLICATE_FLOOR_NUMBER"`。
- **`floor_number < 1`**：非正整数楼层号，报错。
- **grid 不足或超出 16×16**：F-G1 违反，精确报告实际尺寸。
- **cell_type 非法字符串**：F-G2 违反，防拼写错误（如 `"STAR_UP"`）静默通过。
- **ENTITY 格 entity_id 缺失或为空**：F-G3 违反，报 `code="MISSING_ENTITY_ID"`。
- **ENTITY 格 entity_id 在 EntityDB 中不存在**：F6 悬挂引用，报 `code="DANGLING_ENTITY_REF"`。
- **DOOR 格 door_color 为非法值**：F7 违反，报 `code="INVALID_DOOR_COLOR"`。
- **STAIR 格 target_floor_id 不存在于已加载楼层集合**：F8 悬挂引用，报 `code="DANGLING_STAIR_REF"`。
- **STAIR 方向与目标楼层 floor_number 关系错误**：F8 方向约束；STAIR_UP 目标 floor_number ≤ 当前层则报 `code="STAIR_DIRECTION_MISMATCH"`。
- **STAIR 自引用**：`target_floor_id == 当前层 floor_id`，报 `code="STAIR_SELF_REFERENCE"`。
- **PLAYER_START 数量为零**：F5 违反，报 `code="MISSING_PLAYER_START"`。
- **PLAYER_START 多于一个**：F5 违反，报 `code="MULTIPLE_PLAYER_START"`。
- **非顶层楼层无 STAIR_UP**：F-R1 违反，报 `code="MISSING_STAIR_UP"`。
- **F-K1 钥匙-门颜色不平衡**：该层该颜色钥匙数 < 门数，报 `code="KEY_DOOR_IMBALANCE"` 并附 KEY_COUNT 与 DOOR_COUNT。
- **MVP 构建中出现 tier=VS 实体**：F-T1 违反，报 `code="VS_ENTITY_IN_MVP_BUILD"`。
- **楼层集合为空（0 个楼层）**：不进入游戏，报 `code="EMPTY_FLOOR_SET"`。
- **必填字段缺失（floor_id / floor_number / grid）**：报缺失字段 + 楼层序号，**不降级、不填默认值**，不进入游戏。

**已知可解性局限（Accepted Risk — MVP 设计取舍）：**

- **拓扑死锁（钥匙被锁在对应门后方 / STAIR_UP 被 WALL 完全封堵）**：F-K1 只校验数量关系（KEY_COUNT ≥ DOOR_COUNT），F-R1 只校验出口存在性，均不检查空间拓扑顺序和路径可达性。以下场景在数学上合法（通过所有校验）但会导致玩家游戏死锁：黄钥匙被 WALL 围住（数量满足 F-K1，但玩家永远拿不到）、STAIR_UP 被 WALL 完全封堵（存在性满足 F-R1，但玩家无法到达）、黄钥匙在黄门后方（F-K1 通过，拓扑死锁）。**这是 MVP 阶段有意接受的设计局限**：3 层手工关卡的人工兜底成本接近零，引入 BFS 可达性校验的工程代价不成比例（80% 投入换 20% 价值）。**兜底机制**：(1) 关卡设计师提交手工关卡前须**自行走通完整路径**；(2) QA playtest 须**复核每条路径均可达**，包括所有钥匙可拾取、所有楼梯可到达。Player Fantasy 的可证伪判据（零次遇到无法获得的钥匙/到达不了的楼梯）由此人工程序承接，而非数据校验公式。Alpha+ 阶段引入随机楼层（#20 随机事件系统）时**必须**将此处升级为完整 BFS 可达性校验，不可沿用人工兜底。

**运行时语义（非数据校验）：**

- **底层无 STAIR_DOWN**：`floor_number=1` 的楼层不要求有 STAIR_DOWN，但可以有（若有，F8 规则正常校验其目标）。
- **顶层无 STAIR_UP**：顶层（最大 floor_number）豁免 F-R1。玩家到达顶层后的行为（通关触发/段落结束）由 #9 楼层进程定义。
- **DOOR 格被开门后的状态**：DOOR 格的开/关运行时状态由 #9 楼层进程追踪，本数据系统 DOOR 格始终定义「初始关闭状态」。
- **ENTITY 格实体被清除后**：同上，#9 楼层进程维护运行时状态；本数据库不持有「已清除」标记（规则 F10）。
- **`get_cell()` 查询越界坐标**：col 或 row 超出 [0, 15] 范围返回 `null`；调用方（#6 网格移动）负责处理 null，不抛异常。

**WASM / 抖音平台（同 entity-database.md 约束）：**

- 所有楼层 JSON 文件必须打包进 `res://`（随 PCK），不得放 `user://`（WASM 上首次启动可能返回空导致「无楼层 → 无错误」的灾难性假通过）。
- 校验失败的「不进入游戏」在 WASM/小游戏容器内须显示可见错误屏节点（纯代码内联构建，不依赖任何 `.tscn` 或数据文件），不依赖 `get_tree().quit()`。

## Dependencies

### 上游依赖

| 系统 | 依赖性质 | 依赖内容 |
|---|---|---|
| **#1 游戏实体数据库** | 硬依赖（F6/F-K1/F-T1 校验需要 EntityDB 可查） | `EntityDB.lookup(entity_id)` 获取 entity_type、key_color、tier |

> **启动顺序约束**：EntityDB 加载并完成 D1/D3 校验必须先于 FloorDB 加载执行（见 Formulas F-REF-D1/D3）。

### 下游依赖（依赖本系统的）

| 系统 | 依赖性质 | 读取内容 |
|---|---|---|
| #6 网格移动与交互 | 硬依赖 | `get_cell(floor_id, col, row)` → cell_type + 附加字段 |
| #9 楼层进程/游戏状态 | 硬依赖 | `get_floor(floor_id)` → 楼层元数据、STAIR target_floor_id |
| #15 容错安全机制（VS） | 硬依赖 | 全层格子布局（寻路分析、保底资源核验） |
| #16 商店系统（VS） | 硬依赖 | ENTITY 格的 entity_id（商店格放置） |

### 接口约定

- `get_floor(floor_id: String) -> FloorEntry?`：返回指定 floor_id 的楼层记录，不存在返回 null
- `get_cell(floor_id: String, col: int, row: int) -> CellEntry?`：返回指定坐标的格子，越界或不存在返回 null
- 所有查询只读；调用方处理 null，不抛异常；具体数据类型（FloorEntry/CellEntry）由架构阶段 ADR 确定

> **双向性提醒**：上述下游系统的 GDD 编写时，须在其 Dependencies 节反向声明对本系统的依赖。

## Tuning Knobs

本系统为纯数据层，无全局算法参数。「调参」体现在关卡设计师手工编辑楼层 JSON 文件的内容上。

| 调参维度 | 当前值（MVP） | 安全范围 | 影响 | 极端值行为 |
|---|---|---|---|---|
| 楼层数量 | **3（MVP 固定）** | VS=10；Alpha=20-30（各阶段扩展时须重验 F-SC1 成长约束） | 游戏长度、难度坡度 | MVP 固定 3 层；增层须先引入新成长来源（见 player-stats-growth Edge Cases） |
| 每层网格尺寸 | **16×16（固定）** | 不可调（硬约束） | 与美术资源强绑定 | 修改须同步更新美术规范与渲染系统 |
| 每层 DOOR 格数量 | 关卡设计师决定 | 0–8（经验上限） | 探索节奏、钥匙压力 | >8：视觉杂乱；须确保 F-K1 通过 |
| 每层 ENTITY 格总数 | 关卡设计师决定 | 0–30（经验上限） | 战斗密度、资源密度 | 过密：三秒上手受损；过稀：成长感弱 |
| 黄/蓝钥匙各层分布 | 关卡设计师决定 | 每层每色 0–3 颗（参考） | 门谜难度、资源冗余量 | 少于门数→F-K1 报错；多于门数→钥匙冗余（允许） |

### MVP 手工关卡设计参考（非校验规则，仅设计指引；校验规则见 Design Constraints 节 F-SC1a/b/c）

| 楼层 | 推荐怪物 | 推荐道具 | 推荐钥匙 | 推荐门 |
|---|---|---|---|---|
| Floor 1（教学层） | slime × 2–3 | potion_small × 1 | key_yellow × 1–2 | 黄门 × 1 |
| Floor 2（过渡层） | slime × 1–2、goblin × 1 | **shield_iron（必需，见 F-SC1d）** | key_yellow × 1、key_blue × 1 | 黄门 × 1、蓝门 × 1 |
| Floor 3（挑战层） | goblin × 2–3 | potion_large × 1、crystal_life × 1 | key_blue × 1 | 蓝门 × 1–2 |

> 以上为关卡设计参考指引，提供具体的实体选择建议；**成长事件的数量约束（每层 ≥1 次、≤2 次、同类 ≤1 件）已升格为 Design Constraints 节的强制校验规则（F-SC1a/b/c），不再仅是建议**。怪物属性合法性由 EntityDB D1/D3 保证；布局可达性与战斗体验由 QA playtest 验证（见 Edge Cases「已知可解性局限」）。

## Visual/Audio Requirements

N/A — 本系统为无界面纯数据层，自身无视觉/音频产出。各 cell_type 的视觉呈现（格子贴图、怪物 Sprite、门图标等）完全由 #6 网格移动与交互系统和 #11 数值反馈视觉系统自行维护，**本数据库不持有 sprite_id 或任何视觉资产字段**。视觉映射逻辑属 #6/#11 的责任，不在本系统 GDD 中定义。

## UI Requirements

N/A — 本系统无玩家界面。楼层的可视化呈现（地图格子、HUD 楼层号显示）属于 #6 网格移动与 #12 HUD 系统的职责。

## Acceptance Criteria

> **断言契约**：校验逻辑封装为以下函数，返回结构化结果：
> ```
> validate_floors(floors: Array, entity_db: EntityDB, config: FloorValidationConfig, build_scope: String = "MVP") -> ValidationResult
> ```
> `ValidationResult` 含 `is_valid: bool`、`errors: Array`（每条含 `floor_id`、`col`、`row`、`code`、`field`、`detail: Dictionary`）。`detail` 字段用于携带额外诊断信息（如 F-K1 违反时的 `key_count`/`door_count`、F-SC1 违反时的实际成长事件数）；字段不存在时默认空 Dictionary。所有 AC **断言此返回对象**，不断言「游戏是否进入主界面」。全部为 **Logic** 类型，可由 **GDUnit4**（项目标准测试框架）在 headless 模式下无场景树运行。
>
> 查询接口：`get_cell(floor_id, col, row) -> CellEntry?`，`get_floor(floor_id) -> FloorEntry?`，越界或不存在返回 null。
>
> `FloorValidationConfig` 携带校验所需配置（如 build_scope 处理参数），使测试可精确控制，无需依赖全局 Autoload（参照 entity-database.md 的 `ValidationConfig` 模式）。

### AC-FL-01 — 合法楼层集加载成功（Logic）
**GIVEN** 一个包含 3 个楼层的 `floors` 数组，每层均满足：16×16 grid、恰好 1 个 `PLAYER_START`、所有 `entity_id` 在 `entity_db` 中存在、非顶层各有 ≥1 个 `STAIR_UP`、`STAIR` 方向合法、`KEY_COUNT ≥ DOOR_COUNT`（各颜色分别）、无 tier=VS 实体；`build_scope = "MVP"`,
**WHEN** 调用 `validate_floors(floors, entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == true`；`errors` 数组长度为 0。

### AC-FL-02 — F5：PLAYER_START 缺失报错（Logic）
**GIVEN** 一个楼层 `test_no_start`，其 16×16 grid 中无任何 `cell_type == PLAYER_START` 的格子,
**WHEN** 调用 `validate_floors([test_no_start], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_no_start"`、`code == "MISSING_PLAYER_START"` 的记录。

### AC-FL-03 — F5：PLAYER_START 重复报错（Logic）
**GIVEN** 一个楼层 `test_multi_start`，其 grid 中有 2 个 `cell_type == PLAYER_START` 的格子（如 (0,0) 和 (1,0)）,
**WHEN** 调用 `validate_floors([test_multi_start], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_multi_start"`、`code == "MULTIPLE_PLAYER_START"` 的记录。

### AC-FL-04 — F-K1：蓝钥匙数量少于蓝门数量报错（Logic）
**GIVEN** 一个楼层 `test_key_imbalance`，grid 中有 1 个 BLUE 门（`door_color == "BLUE"`）、0 个蓝钥匙 ENTITY；黄色方向满足 F-K1；其余字段合法（含 1 个 PLAYER_START、1 个 STAIR_UP 指向合法顶层）,
**WHEN** 调用 `validate_floors([test_key_imbalance, top_floor], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_key_imbalance"`、`code == "KEY_DOOR_IMBALANCE"` 的记录；该记录的 `detail.color == "BLUE"`、`detail.key_count == 0`、`detail.door_count == 1`。

### AC-FL-05 — F-K1：钥匙数量恰好等于门数量时通过（边界值）（Logic）
**GIVEN** 一个楼层 `test_key_exact`，grid 中有 2 个 YELLOW 门、恰好 2 个黄钥匙 ENTITY；无 BLUE 门；其余字段合法,
**WHEN** 调用 `validate_floors([test_key_exact, top_floor], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == true`；`errors` 中不含任何 `code == "KEY_DOOR_IMBALANCE"` 的记录。

### AC-FL-06 — F-R1：非顶层楼层无 STAIR_UP 报错（Logic）
**GIVEN** 两个楼层：`floor_mid`（floor_number=2，无 `cell_type == STAIR_UP`，有合法 PLAYER_START）；`floor_top`（floor_number=3，顶层）,
**WHEN** 调用 `validate_floors([floor_mid, floor_top], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "floor_mid"`、`code == "MISSING_STAIR_UP"` 的记录。

### AC-FL-07 — F-R1：顶层豁免，无 STAIR_UP 合法（Logic）
**GIVEN** 两个楼层：`floor_1`（floor_number=1，有 PLAYER_START、STAIR_UP 指向 floor_2）；`floor_2`（floor_number=2，有 PLAYER_START，无 STAIR_UP）；`floor_2` 为楼层集中 floor_number 最大的层,
**WHEN** 调用 `validate_floors([floor_1, floor_2], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == true`；`errors` 中不含任何 `code == "MISSING_STAIR_UP"` 的记录。

### AC-FL-08 — F6：ENTITY 格悬挂引用报错（Logic）
**GIVEN** 一个楼层 `test_dangling`，grid 中 (3, 5) 位置为 `cell_type == ENTITY`，`entity_id == "ghost_9999"`；`entity_db` 中不存在该 ID；其余字段合法,
**WHEN** 调用 `validate_floors([test_dangling], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_dangling"`、`col == 3`、`row == 5`、`code == "DANGLING_ENTITY_REF"` 的记录。

### AC-FL-09 — F8：STAIR_UP 方向错误报错（Logic）
**GIVEN** 两个楼层：`floor_a`（floor_number=2），其 STAIR_UP 格 `target_floor_id == "floor_b"`；`floor_b`（floor_number=1，目标 floor_number < 当前层），两层均有合法 PLAYER_START,
**WHEN** 调用 `validate_floors([floor_a, floor_b], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "floor_a"`、`code == "STAIR_DIRECTION_MISMATCH"` 的记录。

### AC-FL-10 — F8：STAIR 自引用报错（Logic）
**GIVEN** 一个楼层 `test_selfref`（floor_number=1），其 STAIR_UP 格 `target_floor_id == "test_selfref"`（指向自身）；有合法 PLAYER_START,
**WHEN** 调用 `validate_floors([test_selfref], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_selfref"`、`code == "STAIR_SELF_REFERENCE"` 的记录。

### AC-FL-11 — F-T1：MVP 构建中出现 tier=VS 实体报错（Logic）
**GIVEN** 一个楼层 `test_vs_entity`，grid 中有一个 ENTITY 格，`entity_id == "vs_only_boss"`，`entity_db.lookup("vs_only_boss").tier == "VS"`；其余字段合法,
**WHEN** 调用 `validate_floors([test_vs_entity], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_vs_entity"`、`code == "VS_ENTITY_IN_MVP_BUILD"`，记录中含 `entity_id == "vs_only_boss"`。

### AC-FL-12 — F-T1：VS 构建中 tier=VS 实体合法通过（Logic）
**GIVEN** 与 AC-FL-11 相同的 `test_vs_entity` 楼层；`build_scope = "VS"`,
**WHEN** 调用 `validate_floors([test_vs_entity], entity_db, config, "VS")`,
**THEN** 返回 `is_valid == true`；`errors` 中不含 `code == "VS_ENTITY_IN_MVP_BUILD"` 的记录。

### AC-FL-13 — F10 只读原则：写入副本不污染数据库（Logic）
**GIVEN** 一个已通过 validate_floors 的楼层集，`floor_1` 中坐标 (2, 3) 为 `cell_type == ENTITY`，`entity_id == "slime"`；取得 `cell_a = get_cell("floor_1", 2, 3)`,
**WHEN** 对 `cell_a.cell_type` 写入 `"EMPTY"`（模拟下游误写），随后再次调用 `get_cell("floor_1", 2, 3)` 取得 `cell_b`,
**THEN** `cell_b.cell_type == "ENTITY"`；`cell_b.entity_id == "slime"`（数据库内部状态未被修改）。
> **实现注（必读）**：若 CellEntry 用 Dictionary 实现，`get_cell()` 须返回 `.duplicate()`（浅拷贝）而非原始引用，否则此 AC 失败（对返回值的写入会污染数据库）。当前 CellEntry 为扁平结构（无嵌套子字典），浅拷贝足够；若未来引入嵌套字段（如 metadata），须升级为 `.duplicate(true)`（深拷贝）并同步更新本 AC 的测试用例。

### AC-FL-14 — get_cell 合法坐标查询返回正确内容（Logic）
**GIVEN** 一个已通过 validate_floors 的楼层集，`floor_1` 中坐标 (7, 4) 预置为 `cell_type == DOOR`，`door_color == "YELLOW"`,
**WHEN** 调用 `get_cell("floor_1", 7, 4)`,
**THEN** 返回值不为 null；`cell_entry.cell_type == "DOOR"`；`cell_entry.door_color == "YELLOW"`。

### AC-FL-15 — get_cell 越界坐标返回 null，不抛异常（Logic）
**GIVEN** 一个已通过 validate_floors 的楼层集，`floor_1` 有效范围 col/row ∈ [0, 15],
**WHEN** 分别调用 `get_cell("floor_1", -1, 0)`、`get_cell("floor_1", 16, 0)`、`get_cell("floor_1", 0, 16)`,
**THEN** 三次调用均返回 `null`；调用过程中不抛出任何异常。

### AC-FL-16 — 空楼层集报错（Logic）【补充缺口】
**GIVEN** 一个空的 `floors` 数组（长度 == 0）,
**WHEN** 调用 `validate_floors([], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `code == "EMPTY_FLOOR_SET"` 的记录。

### AC-FL-17 — F-G1：grid 非 16×16 报错（Logic）【补充缺口】
**GIVEN** 一个楼层 `test_wrong_size`，其 grid 为 15 行（缺少一行），每行 16 格；其余字段合法（有 PLAYER_START 等）,
**WHEN** 调用 `validate_floors([test_wrong_size], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_wrong_size"`、`code == "GRID_SIZE_MISMATCH"` 的记录，记录中包含实际行数（15）。

### AC-FL-18 — floor_id 重复报错（Logic）【补充缺口】
**GIVEN** 一个 `floors` 数组，包含两个楼层，`floor_id` 均为 `"floor_1"`（重复）；两层其他字段均合法,
**WHEN** 调用 `validate_floors(floors, entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `code == "DUPLICATE_FLOOR_ID"`、`floor_id == "floor_1"` 的记录；后者不静默覆盖前者。

### AC-FL-19 — floor_number 重复报错（Logic）【补充缺口】
**GIVEN** 一个 `floors` 数组，包含两个楼层：`floor_id` 分别为 `"floor_a"` 和 `"floor_b"`，但 `floor_number` 均为 `2`（重复）,
**WHEN** 调用 `validate_floors(floors, entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `code == "DUPLICATE_FLOOR_NUMBER"` 的记录。

### AC-FL-20 — F-G2：cell_type 非法字符串报错（Logic）【补充缺口】
**GIVEN** 一个楼层 `test_bad_celltype`，grid 中某格 `cell_type == "STAR_UP"`（拼写错误，不在合法枚举中）；其余格子合法（含 1 个 PLAYER_START）,
**WHEN** 调用 `validate_floors([test_bad_celltype], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "test_bad_celltype"`、`code == "INVALID_CELL_TYPE"` 的记录，记录中含该格坐标和非法值 `"STAR_UP"`。

### AC-FL-21 — F-G3：DOOR 格缺 door_color 字段报错（Logic）【补充缺口】
**GIVEN** 一个楼层 `test_door_no_color`，grid 中某格 `cell_type == "DOOR"`，但 `door_color` 字段完全缺失（与字段存在但值非法不同）；其余格子合法（含 1 个 PLAYER_START）,
**WHEN** 调用 `validate_floors([test_door_no_color], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条含该格坐标的记录，`code` 为 `"MISSING_DOOR_COLOR"` 或等价的 F-G3 必填字段缺失错误码。

### AC-FL-22 — F4：floor_number 非正整数报错（Logic）【补充缺口】
**GIVEN** 一个楼层 `test_zero_floor`，`floor_number == 0`（违反 F4 约束 floor_number ≥ 1）；其他字段合法,
**WHEN** 调用 `validate_floors([test_zero_floor], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `code == "INVALID_FLOOR_NUMBER"` 的记录（含 `floor_id`）。

### AC-FL-23 — F8：STAIR_DOWN 方向错误报错（Logic）【补充缺口】
**GIVEN** 两个楼层：`floor_a`（floor_number=1），其 STAIR_DOWN 格 `target_floor_id == "floor_b"`；`floor_b`（floor_number=2，目标 floor_number=2 > 当前层 floor_number=1，方向错误）；两层均有合法 PLAYER_START,
**WHEN** 调用 `validate_floors([floor_a, floor_b], entity_db, config, "MVP")`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `floor_id == "floor_a"`、`code == "STAIR_DIRECTION_MISMATCH"` 的记录（与 AC-FL-09 的 STAIR_UP 方向对称覆盖 F8 的完整约束）。

## Open Questions

1. **数据文件组织方式（单文件 vs 多文件）**
   当前 GDD 假设楼层文件放在 `res://data/floors/`，但未指定是一个 JSON 文件包含所有楼层（`floors.json`），还是每层一个独立文件（`floor_1.json`，`floor_2.json`，…）。
   *解决方式：架构 ADR 中决定；推荐单文件（MVP 层数少，维护简单）。*

2. **FloorEntry / CellEntry 的具体实现类型**
   同 entity-database.md 的 Open Q2：使用 Resource 子类、内部 GDScript class，还是 Dictionary？影响 `get_cell()` 的只读强制方式。
   *解决方式：与 entity-database.md 合并到同一 ADR（数据格式 + Entry 构造 + 只读强制）。*

3. **cell_type 的 JSON 编码方式**
   每个格子是完整对象（`{"cell_type": "ENTITY", "entity_id": "slime"}`）还是采用紧凑编码？完整对象对关卡设计师更友好，但 256 格 × 多层可能产生较大 JSON 体积。WASM 50MB 约束下，体积影响待评估。
   *解决方式：先用完整对象写 MVP，导出后测量体积；超出再考虑压缩编码。*

4. **EntityDB 与 FloorDB 的启动顺序保证机制**
   GDD 要求 EntityDB 先于 FloorDB 加载完成，但具体保证机制（Autoload 列表顺序 / 信号同步 / 依赖注入）还未在架构层定义。
   *解决方式：在架构 ADR 中明确；推荐 EntityDB Autoload 排在 FloorDB 之前，或 FloorDB 的 `_ready()` 等待 EntityDB 的 `database_ready` 信号。*

5. **顶层通关语义**
   GDD 规定顶层豁免 F-R1（无需 STAIR_UP），但「到达顶层后游戏做什么」（通关屏幕 / 进入新塔段 / 无尽模式循环）属于 #9 楼层进程的职责，还未设计。
   *解决方式：#9 楼层进程 GDD 设计时明确；本 GDD 只保证顶层有 PLAYER_START 即可。*
