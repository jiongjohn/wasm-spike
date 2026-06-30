# 网格移动与交互系统 (Grid Movement & Interaction)

> **Status**: In Review
> **Author**: lumen + agents
> **Last Updated**: 2026-06-26 (post design-review 5th-round revision)
> **Implements**: P3「三秒上手」/ **Enables**: P4「每层都有新发现」（作为关卡发现的呈现载体；P4 由 FloorDB 数据与关卡布局驱动，GridMovement 是其物理舞台）

## Overview

网格移动与交互系统是《像素魔塔·无尽塔》的**行动输入层**。它以 16×16 的像素网格渲染当前楼层，并将玩家的单指点按转化为格子激活事件——向 GameState 分发「触碰了一只怪」「踩到楼梯」「尝试开门」三类语义信号，供战斗、进程、钥匙门等系统响应。本系统是 Scene Node（Node2D）：静态楼层由一个 **TileMapLayer 子节点**渲染，per-cell 动态视觉效果（CF-7 目标格脉冲高亮、门/楼梯过渡）由**少量按需池化的覆盖 Node2D** 承载，外加一个玩家标记节点（**渲染/重建方案见 ADR-0009；宿主决策见 ADR-0003**）。它不持有游戏状态，只负责「展示当前楼层 + 把玩家操作翻译成语义事件」。

从玩家视角，网格是每一次决策的舞台：点一格，格子立刻响应——怪物格触发战斗预演、道具格一触即拾、楼梯格自动上行。探索的节奏由这个系统决定：每层都有新格子等待揭开，每次点击都是一次「我去哪里」的主动选择。

## Player Fantasy

玩家在这个系统里感受到的是**完全的行动掌控感**：每一格都在等我去踩，每一次点按都精确发生了「我想要发生的事」。

具体体验锚点：

- **探索揭幕** — 走到没去过的区域，格子内容随之显现，有一种「亲手揭开那一层」的满足。不是地图迷雾揭开，而是「我走到哪里，那里才有意义」。
- **路线掌握** — 望一眼整层，脑子里立刻开始规划：先拿这把钥匙，绕过那只现在打不过的怪，再走楼梯。网格让路径推演在视觉上是直觉的，不需要数字辅助。
- **零摩擦响应（EMPTY 格）** — 点哪里去哪里，没有延迟、没有「我想走左边但系统带我去右边」的挫败感。一根手指、一个点按、一格位移——这是 Pillar 3「三秒上手」最底层的承诺。本锚点特指空格移动；MONSTER 格对应的是「知情后的主动掌控」（见下）。
- **知情后的主动掌控（MONSTER 格）** — 点怪不是「撞上去」而是「选择打」。预演覆盖层让玩家在确认前看到结果，第二次点按是主动的决策动作，不是对系统无反应的重试。「确定性」Pillar 2 在操作层的体现是：每次战斗的发起都是知情同意，而非随机后果。

这个系统同时是 Pillar 4「每层都有新发现」的物理载体：每一层的网格布局陌生，玩家走进去的第一眼就是一次路线推演的起始——门在哪、怪有几只、楼梯藏在哪里。没有网格，这种「踏入新楼层 → 扫一眼 → 计划路线」的玩家瞬间就不存在了。

**设计反例**：「点格子出现确认弹窗」「格子之间有大段移动动画」——这些都会把「即点即达」的掌控感打散成「等待 + 确认」的操作负担。

## Detailed Design

### Core Rules

**规则 M1 — 点格移动：触发逻辑**

玩家单指点按网格中任意格子，GridMovement 根据 `cell_type` 分发行为（仅 IDLE 状态有效）：

| `cell_type` | 行为 |
|---|---|
| `EMPTY` | 寻路移动至目标格 |
| `ENTITY`（MONSTER） | 进入 PREVIEWING — 显示战斗预演，等待二次确认 |
| `ENTITY`（ITEM / KEY） | 立即分发：调用 `GameState.on_item_cell_entered(cell, pos)` |
| `DOOR` | 立即分发：调用 `GameState.on_door_cell_entered(cell, pos)` |
| `STAIR_UP / STAIR_DOWN` | 立即分发：调用 `GameState.on_stair_cell_entered(cell, pos)` |
| `WALL` | 忽略此 tap |
| 不可达（路径被阻挡） | 忽略此 tap，**必须**提供视觉拒绝反馈（参见 TK-3 `REJECT_FEEDBACK_DURATION`）|

非 IDLE 状态（PREVIEWING/MOVING/LOCKED）时所有 tap 被丢弃，不缓存不延迟。

**规则 M2 — 路径寻路（EMPTY 格目标）**

1. BFS/A* 从玩家当前位置寻路至目标 EMPTY 格
2. 仅穿越 `EMPTY`（含已清除的格子，视觉已变 EMPTY）和 `PLAYER_START` 格；`WALL`、未清除的 `ENTITY`、`DOOR`、`STAIR` 均阻挡路径
3. 路径存在：PlayerMarker 沿路径移动（每格 ≤ 50ms，快进动画）；**每到达路径中的一格，发出 `player_moved(new_pos: Vector2i)` 信号（每格一次，非整条路径一次）**；进入 MOVING 状态
4. 路径不存在：忽略此 tap

**规则 M3 — ENTITY/DOOR/STAIR 格可达性**

点按非 EMPTY 格时，GridMovement 对该格的 4 方向相邻格（排除 WALL）执行 BFS 可达性检测。若至少一个相邻格可达：视为可达，立即分发行为（玩家无需先步行到旁边）。不可达则忽略。

**规则 M4 — 两步战斗确认**

> **#10 访问方式（2026-06-29 同步 ADR-0008 拆分）**：`forecast_combat()` 经 **`CombatForecastService`**（Autoload 纯代理）全局名调用；4 个覆盖层 UI 接口（`show_overlay`/`hide_overlay`/`get_overlay_screen_rect`/`get_x_button_screen_rect`）经 **`@export var forecast_overlay: CombatForecastOverlay`**（game.tscn Scene Node 引用）调用——Scene Node 间 @export 引用是 Godot 惯用模式，不受 ADR-0003 `autoload_holds_scene_node_reference` 禁令约束（该禁令仅约束 Autoload）。`GridMovement._ready()` 须 `assert(forecast_overlay != null)`。

1. 玩家点按可达 MONSTER 格 → GridMovement 调用 `CombatForecastService.forecast_combat(…)`（同步纯函数）获取 CombatForecast 对象
2. GridMovement 调用 `forecast_overlay.show_overlay(forecast, col, row)` 触发覆盖层显示（显示：回合数、WIN/LOSE、WIN 路径受伤量）；进入 PREVIEWING 状态。**接口约束（已随 #10 GDD 锁定）**：`show_overlay` 接受 forecast 数据对象和目标格 (col, row)，内部计算锚点翻转；GridMovement 不持有覆盖层 UI 节点。
3. **确认**：**再次点按同一 MONSTER 格**（唯一确认手势）→ GridMovement 进入 LOCKED，调用 `GameState.on_combat_cell_entered(cell, pos)`，调用 `forecast_overlay.hide_overlay()`。**注（2026-06-29 同步）**：覆盖层**不含显式 CTA 确认区域**——#10 采用「无 CTA + 再 tap 确认」设计（creative-director 裁决）；确认手势的可发现性由 #10 覆盖层常驻提示文字 + 本系统对目标怪物格的脉冲高亮共同保证（见 Visual/Audio Requirements）。
4. **取消或转向**：点按覆盖层 × 按钮或其他格时，覆盖层立刻隐藏，行为按触发源分支：
   - **覆盖层 × 按钮**：覆盖层立刻隐藏，回到 IDLE，不分发任何事件（**纯取消专用手势，零副作用**）
   - **EMPTY 格（可达）**：同时触发寻路移动，进入 MOVING
   - **ITEM / KEY / DOOR / STAIR（可达）**：立即分发对应 `GameState.on_*_cell_entered(cell, pos)`，进入 LOCKED
   - **另一个 MONSTER（可达）**：覆盖层切换到新目标怪物，保持 PREVIEWING（见 Edge Cases）
   - **WALL / 不可达格**：回到 IDLE，不分发任何事件

**规则 M5 — 输入锁定**

MOVING 和 LOCKED 状态下所有 tap 丢弃。GameState 处理完事件后发出 `grid_unlock` 信号 → IDLE。

**规则 M6 — 格子视觉状态同步（只响应信号，不持有运行时状态）**

- `GameState.cell_cleared(floor_id, col, row)` → **先校验 `floor_id == _current_floor_id`，不匹配则静默丢弃，不更新任何 CellNode 也不更新 `_passable` 缓存。** 匹配时：隐藏对应 CellNode 的实体精灵，显示 EMPTY 外观，并将 `_passable[col + row * 16]` 更新为 `true`。
- `KeyDoor.door_opened(floor_id, col, row)` → **先校验 `floor_id == _current_floor_id`，不匹配则静默丢弃，不更新任何 CellNode 也不更新 `_passable` 缓存。** 匹配时：门格变 EMPTY 外观，**同步将该 CellNode 的 `cell_type` 更新为 `EMPTY`**（使 M1 的点击分发逻辑与可穿性一致；若不更新，玩家点击已开启门格时 M1 仍读 `DOOR` → 误触 `on_door_cell_entered` 双重触发），并将 `_passable[col + row * 16]` 更新为 `true`。
- GridMovement 不主动查询「哪些格子已清除」；仅被动响应信号

> **实现约束（可穿性查表）**：GridMovement 在楼层加载时构建内部查表 `_passable: Array[bool]`（16×16 = 256 元素），响应 `cell_cleared`、`door_opened` 信号时**先做 floor_id 校验**，匹配后同步更新对应索引。BFS 通过查表运行，不在执行期间遍历 CellNode 子节点树。此查表为**渲染辅助状态**（布局可达性缓存），不是游戏业务状态（HP/钥匙数等），不违反 Overview「不持有游戏状态」约束——该约束指业务状态。初始状态来自 `FloorDB.get_floor()` 数据直接构建，不依赖任何历史信号重放（楼层切换前的 `cell_cleared`/`door_opened` 信号不影响新楼层初始 `_passable`）。

**规则 M7 — 楼层加载**

接收 `FloorProgress.floor_changed(new_floor_id)` 信号时（**重建方案见 ADR-0009**）：
1. 读取 `FloorDB.get_floor(new_floor_id)` 新楼层布局（**每次切换仅调用一次** get_floor，遍历 grid 时不重复调用 — ADR-0009 调用契约，防 duplicate_deep GC 压力）
2. 遍历 `floor.grid[r][c]`，对每格 `TileMapLayer.set_cell(Vector2i(col,row), source, atlas_coords)` 批量更新静态外观，并重建 `_passable[col + row*16]`
3. 归还所有活动覆盖节点到对象池（清除上一层的高亮/动画）
4. PlayerMarker 定位到 `PLAYER_START` 格
5. 进入 IDLE

> **性能方案（已由 ADR-0009 决策）**：原「256 个独立 CellNode 销毁+实例化」在低端安卓约耗 2.5–13ms/帧（含 Sprite2D 纹理注册），逼近 33ms 帧预算。**ADR-0009 采用混合方案**：静态楼层用单个 **TileMapLayer**（`set_cell` 批量重绘，引擎级 C++，单 atlas TileSet 合并 draw call 至近 1 次，切换预期 < 2ms）；per-cell 动态效果用**按需池化覆盖 Node2D**（典型同屏 ≤ 数个）。约束：EMPTY/WALL 用专属 atlas tile（非 `visible` 切换）；禁用 cell 级 `_process()`；atlas region 对齐 ETC2/ASTC 4px 块 + 2px padding + `filter:off`。`_passable` 缓存与 BFS/状态机保留在 GridMovement 逻辑层（headless 可测）。

---

### States and Transitions

| 状态 | 描述 | 接受 tap？ |
|------|------|-----------|
| **IDLE** | 空闲，等待玩家操作 | ✅ 全部 |
| **PREVIEWING** | 战斗预演覆盖层显示中 | ✅ 仅确认/取消 |
| **MOVING** | PlayerMarker 移动动画中 | ❌ |
| **LOCKED** | GameState/FloorProgress 处理事件中 | ❌ |

```
IDLE ── tap EMPTY（可达）──────────────────── MOVING
IDLE ── tap MONSTER（可达）───────────────── PREVIEWING
IDLE ── tap ITEM/KEY/DOOR/STAIR（可达）───── LOCKED
IDLE ── tap WALL/不可达 ──────────────────── IDLE（忽略）

PREVIEWING ── 再次点按同格/确认 ────────────────────── LOCKED
PREVIEWING ── 覆盖层 × 按钮（纯取消） ──────────────── IDLE（零副作用）
PREVIEWING ── 点按 EMPTY（取消+移动）──────────────── MOVING
PREVIEWING ── tap 可达 ITEM/KEY/DOOR/STAIR（取消+分发）── LOCKED
PREVIEWING ── 点按另一 MONSTER（切换目标）──────────── PREVIEWING
PREVIEWING ── 点按 WALL/不可达 ──────────────────────── IDLE

MOVING ── PlayerMarker 到达目标格 ────────── IDLE

LOCKED ── GameState.grid_unlock 信号 ─────── IDLE
```

---

### Interactions with Other Systems

| 系统 | 方向 | 接口 |
|------|------|------|
| FloorDB (#2) | #6 读 | `get_floor(floor_id)` → FloorEntry；`get_cell(floor_id, col, row)` → CellEntry |
| EntityDB (#1) | #6 读 | `get_entity(entity_id)` → MonsterEntry/ItemEntry/KeyEntry（由 CellEntry.entity_id 查） |
| CombatForecast (#10) | #6 调用 | `forecast_combat(6 int 参数)` → CombatForecast（同步纯函数，仅 PREVIEWING 触发时调用）；`show_overlay(forecast, col, row)` / `hide_overlay()`；`get_overlay_screen_rect() -> Rect2`（供 GridMovement `_input()` 覆盖层整体拦截，**MUST 返回屏幕空间坐标，在 `show_overlay()` 时缓存**，遵守 ADR-0003）；`get_x_button_screen_rect() -> Rect2`（供 `_input()` × 按钮子区域分流，**MUST 同上：屏幕空间坐标，`show_overlay()` 时缓存**，遵守 ADR-0003）|
| GameState (#13) | #6 调用 | `on_combat_cell_entered(cell, pos)` / `on_item_cell_entered(cell, pos)` / `on_door_cell_entered(cell, pos)` / `on_stair_cell_entered(cell, pos)` |
| GameState (#13) | 信号 → #6 | `cell_cleared(floor_id, col, row)` — 格子清除；`grid_unlock()` — 解锁输入 |
| FloorProgress (#9) | 信号 → #6 | `floor_changed(new_floor_id)` — 重载楼层（触发 M7） |
| KeyDoor (#7) | 信号 → #6 | `door_opened(floor_id, col, row)` — 门格变 EMPTY 外观 |

> **ADR-0003 约束**：GridMovement 通过 Autoload 全局名访问上游服务；不持有任何 Autoload 的实例引用变量。

## Formulas

GridMovement 是纯粹的**输入翻译与视觉编排系统**，不持有游戏状态，不执行数值计算。本节仅包含属于本系统边界内的两条形式化定义与一条来源声明。战斗预演数字（总伤害、回合数、胜负）来自 #10 CombatForecast 的 `forecast_combat()` 纯函数调用；本系统不重定义任何战斗数学。

---

### F-MOV — 移动动画时序

`T_total = path_length × T_cell`

**变量：**

| 变量 | 符号 | 类型 | 范围 | 描述 |
|------|------|------|------|------|
| 单格移动时间 | T_cell | float | 0ms < T_cell ≤ 2帧（≤ 66.7ms @ 30fps） | PlayerMarker 移动一格的动画时长（Tween 按 delta 时间步进，在稳定 30fps 下实际完成于第 1 或第 2 个 process 帧；默认 50ms 对应约 1.5 帧间隔）；调参旋钮见 Tuning Knobs |
| 路径长度 | path_length | int | 1 ≤ path_length ≤ 30 | BFS/A* 步骤数；保守上界（实践上 EMPTY 连通区远小于 256 格） |
| 总移动时间 | T_total | float | 0ms < T_total ≤ 1500ms | MOVING 状态最长持续时长；超出即为异常路径 |

**path_length 上界说明**：16×16 = 256 格，WALL 和 ENTITY 阻挡路径，设计草稿取保守上界 30 格（约 12% 直径）；若实测 EMPTY 连通区域超出，需修订并同步更新 T_total 上界。

**输出范围**：40ms（1 格/40ms，正常相邻移动）到 1500ms（30 格/50ms，最坏情况）

**示例**：8 格迂回路径，T_cell = 40ms → T_total = 320ms

---

### F-REACH — 格子可达性算法规范

> F-REACH 不是数学公式，而是**算法约束规范**，确保实现者对可穿越格子类型的理解一致（特别是「已清除 ENTITY 格是否可穿」这类歧义点）。

**可穿越格子类型：**

| 格子类型 | 可穿越？ | 说明 |
|---|---|---|
| EMPTY（初始空格）| ✅ | 无实体 |
| EMPTY（已清除 ENTITY 格）| ✅ | `cell_cleared` 信号后格子转为 EMPTY，寻路可穿越 |
| PLAYER_START | ✅ | 玩家出生格，始终可穿越 |
| WALL | ❌ | 不可穿越 |
| ENTITY（未清除）| ❌ | 怪物/道具/钥匙仍在，阻挡路径 |
| DOOR（未开启）| ❌ | 阻挡路径 |
| DOOR（已开启）| ✅ | `door_opened` 信号后格子转为 EMPTY 外观，视为可穿 |
| STAIR_UP / STAIR_DOWN | ❌ | 点按触发分发；不作为寻路中间路径节点 |

**目标格的特殊终止条件**（规则 M3）：当目标格为 MONSTER/ITEM/KEY/DOOR/STAIR 时，BFS 终止条件是「到达目标格的任意 4 方向可穿越相邻格（见上表）」，而非到达目标格本身。至少一个相邻格可达即视为可达。特殊情况：若目标格的所有 4 方向相邻格均不可穿越（例如全被 WALL 包围），等价于路径不存在，tap 被忽略。

**BFS 方向约束**：BFS 采用 **4 方向移动**（上/下/左/右），不允许对角移动。`path_length` 定义为 BFS 图上的**边数**（即玩家标记需要移动的格子步数）。

**DOOR（已开启）作用域说明**：上表中"DOOR（已开启）✅ 可穿"仅约束 **BFS 中间节点**穿越行为。响应 `door_opened` 信号时，M6 同步将该 CellNode `cell_type` 更新为 `EMPTY`，因此后续点击分发由 M1 的 EMPTY 分支处理（寻路移动），不再走 DOOR 分支。此行可视为历史说明，实现以 M6 的 cell_type 更新为准。

**时间复杂度**：O(256) = O(1)，< 0.1ms，无性能风险。

---

### F-PREV — 战斗预演数字来源声明

> 本条目不定义公式，仅明确边界与接口：战斗预演覆盖层中显示的所有数字（预计总伤害、回合数、WIN/LOSE 判定）**均来自 #10 CombatForecast 的 `forecast_combat(monster_HP, monster_ATK, monster_DEF, player_ATK, player_DEF, player_current_HP)` 同步纯函数调用结果**（规则 M4）。GridMovement 持有返回的 CombatForecast 对象后，调用 **`forecast_overlay.show_overlay(forecast, cell_col, cell_row)`**，将 forecast 数据对象和目标格坐标传入；CombatForecast (#10) 持有覆盖层 UI 节点，负责数字渲染和锚点定位计算（含翻转逻辑）。GridMovement 离开 PREVIEWING 时调用 **`forecast_overlay.hide_overlay()`**。本系统不做任何预演数学推导，不持有覆盖层 UI 节点。

## Edge Cases

- **如果玩家在 MOVING 或 LOCKED 状态下点按任意格子**：tap 被丢弃，不缓存，不延迟执行。防止战斗结算期间的误触积压导致连续触发。

- **如果寻路目标 EMPTY 格被未清除的 ENTITY 格完全包围（路径不存在）**：忽略此 tap，可选播放轻微的视觉拒绝反馈（格子抖动或红色描边闪一下）。GridMovement 保持 IDLE，玩家需先清除阻挡格才能到达。

- **如果玩家在 PREVIEWING 状态下点按一个 EMPTY 格（取消预演+移动）**：预演覆盖层立刻隐藏，同时对该 EMPTY 格启动寻路移动（进入 MOVING 状态）。不需要玩家先点「取消」按钮。

- **如果玩家在 PREVIEWING 状态下点按另一个 MONSTER 格（换目标）**：视为取消当前预演并立即为新 MONSTER 格触发预演（PREVIEWING → 新 PREVIEWING，覆盖层切换到新怪物）。

- **如果 `cell_cleared` 信号到达时，该格在 GridMovement 中已显示为 EMPTY 外观**：no-op（幂等），不触发任何节点操作，不报错。防止 GameState 重复发信号导致的异常。

- **如果玩家点按自身当前所在格（path_length = 0）**：忽略此 tap（不进入 MOVING，不产生任何效果）。

- **如果玩家在 PREVIEWING 状态下点按自身当前所在格（path_length = 0 的 EMPTY 格）**：M4 步骤 4 将 EMPTY 映射为「取消+寻路」，但 M2 规定 path_length = 0 时忽略此 tap。两规则冲突时 **M2 优先**：覆盖层立刻隐藏，回到 IDLE，不触发寻路，不分发任何事件。（用覆盖层 × 按钮取消更直觉，本分支为防御性处理。）

- **如果 `grid_unlock` 信号在 PREVIEWING 状态（非 LOCKED 状态）下到达**：GridMovement 关闭预演覆盖层，转为 IDLE。此为防御性处理——正常流程中 GameState 仅在处理完事件后发 grid_unlock，不应在 PREVIEWING 期间到达；若到达则意味着外部状态异常，保守回 IDLE 最安全。

- **如果寻路路径中途的格子在 MOVING 状态中被 `cell_cleared` 清除（原本阻挡）**：路径已在寻路时计算完成（BFS 结果为格子坐标列表），中途变化不影响当前 MOVING 执行，PlayerMarker 按原路径到达目标。下一次 tap 将基于最新格子状态重新寻路。

- **如果 ENTITY 格被点按但 EntityDB 中查不到对应 entity_id**：GridMovement 无法确定格子类型，忽略此 tap 并输出 `push_error("GridMovement: entity_id not found: [id]")`。此情况属于 FloorDB 数据错误，应在启动校验时捕获（FloorDB 规则 F6），运行时不应出现。

## Dependencies

### 上游依赖（本系统依赖的系统）

| # | 系统 | 类型 | 接口 | 若缺失 |
|---|------|------|------|--------|
| 1 | 游戏实体数据库 (EntityDB) | **硬依赖** | `EntityDB.get_entity(entity_id)` → MonsterEntry/ItemEntry/KeyEntry；判断 ENTITY 格的交互类型 | GridMovement 无法区分怪物/道具/钥匙，无法分发正确事件 |
| 2 | 楼层关卡数据系统 (FloorDB) | **硬依赖** | `FloorDB.get_floor(floor_id)` → FloorEntry；`FloorDB.get_cell(floor_id, col, row)` → CellEntry；提供 16×16 布局 | GridMovement 无布局数据，无法初始化网格，系统无法启动 |
| 10 | 战斗预演系统 (CombatForecast) | **功能依赖** | `CombatForecastService.forecast_combat(…)` → CombatForecast；`show_overlay(forecast, col, row)` / `hide_overlay()` — 覆盖层显示接口；`get_overlay_screen_rect()` / `get_x_button_screen_rect()` — 屏幕空间触控拦截接口 | 两步确认功能缺失；可降级为「点怪直接确认无预演」运行（MVP 临时桩）**接口约束（#10 GDD 已锁定，2026-06-29 同步）**：(a) forecast_combat 签名以 AC-COMB-1 为准；(b) **覆盖层无显式 CTA 确认区域**——确认唯一手势为再次 tap 怪物格（原「必须定义 CTA」要求已废止，AC-COMB-7 → RESOLVED-VOID）；(c) `show_overlay` / `hide_overlay` / 两个 `get_*_screen_rect()` 接口为硬依赖 |

> **依赖缺口提示**：systems-index 当前列 #6 依赖 1 和 2，未列 #10。#10 是功能依赖（两步确认的预演数字来源）。建议在 systems-index 中将 #10 加入 #6 的依赖列，或保持现状并在代码层用临时桩（mock CombatForecast）开发 #6 的核心移动功能。

### 下游依赖（依赖本系统的系统）

| # | 系统 | 类型 | 接口期望 |
|---|------|------|---------|
| 7 | 钥匙与门系统 (KeyDoor) | **硬依赖** | 需接收 `GameState.on_door_cell_entered(cell, pos)`（由 GridMovement 触发）；需发出 `KeyDoor.door_opened(floor_id, col, row)` 信号供 GridMovement 更新门格视觉 |
| 9 | 楼层进程系统 (FloorProgress) | **硬依赖** | 需接收 `GameState.on_stair_cell_entered(cell, pos)`（由 GridMovement 触发）；需发出 `FloorProgress.floor_changed(new_floor_id)` 供 GridMovement 重载楼层 |
| 13 | 游戏状态管理 (GameState) | **硬依赖** | 需提供 `on_combat_cell_entered` / `on_item_cell_entered` / `on_door_cell_entered` / `on_stair_cell_entered` 四个入口方法；需发出 `cell_cleared` 和 `grid_unlock` 信号 |
| 19 | 音效系统（Alpha） | **软依赖** | 可监听 GridMovement 发出的 `player_moved(new_pos)` 信号触发移动音效；GridMovement 无需感知音效系统的存在 |

### 双向一致性注记

- **FloorDB (#2)** 的 Interactions 节已明确 `#6 网格移动与交互` 消费 `get_cell()`，双向一致 ✅
- **EntityDB (#1)** 的 Overview 节提及 `#6 网格移动交互` 依赖本数据库，双向一致 ✅
- **#7/#9/#13** 尚无 GDD；本系统在 Interactions 节定义的接口（`on_combat_cell_entered` 等）将成为这些系统 GDD 设计时的输入约束

## Tuning Knobs

GridMovement 是输入路由器，可调旋钮少而精确。

| 旋钮 | 默认 | 安全范围 | 影响维度 |
|------|------|---------|---------|
| `T_cell` | 50 ms | 20–67 ms（≤2帧@30fps） | 移动节奏感 / F-MOV 总时长 ⚠️ 联合约束见下方 |
| `MAX_PATH_LENGTH` | 30 格 | 16 格 ≤ 上界 = floor(1500 / T_cell) | BFS 性能上限 / 可达范围 ⚠️ 联合约束见下方 |

> **联合约束**：`T_cell × MAX_PATH_LENGTH ≤ 1500ms`（即 T_total 上界）。默认组合 50ms × 30 = 1500ms，恰好满足。若调高 T_cell，须相应降低 MAX_PATH_LENGTH。**禁区示例**：T_cell = 67ms 时，MAX_PATH_LENGTH 最大 = 22；T_cell = 50ms 时，MAX_PATH_LENGTH 最大 = 30。MAX_PATH_LENGTH 安全上界从 40 降至 30 以防止默认值之外的配置意外违反约束。
| `REJECT_FEEDBACK_DURATION` | 150 ms | 80–300 ms | tap 拒绝反馈时长（**必须实装**）|
| `CELL_TOUCH_SIZE_DP` | 40 dp | ≥22 dp（16×16 缩放后约 22dp；40dp 为目标） | 每格触控响应区域设计目标值（独立于精灵渲染尺寸；16 列密集网格下约 22dp，需实机验证后确认下限，见触控目标尺寸节）|
| `LOCK_TIMEOUT_MS` | 5000 ms | 0（禁用）– 10000 ms | LOCKED 状态超时自愈：0 = 禁用；正值 = 超出后强制回 IDLE 并 push_error |

#### TK-1 — `T_cell`（单格移动时长）

玩家标记从当前格移动到下一格的动画时长。Godot Tween 按 delta 时间步进（非帧计数）：50ms 在稳定 30fps（帧时 33.3ms）下对应约 1.5 帧，实际完成于第 1 或第 2 个 process 帧（33–67ms），这是 F-MOV 规格改写为帧规格的依据。调低增加速度感；调高须按联合约束相应降低 MAX_PATH_LENGTH。< 20ms（< 1 帧）在 30fps 设备下可能跳格。安全范围上界从 100ms 降至 67ms（2 帧上限），保证不违反联合约束。

#### TK-2 — `MAX_PATH_LENGTH`（最大寻路步数）

BFS 性能兜底：防止极角路径触发过长遍历。超限的目标格拒绝寻路（视觉显示不可达）。< 16 在 16×16 网格中会出现明显「到不了对角」的体验断裂。安全上界从 40 降至 30（与默认 T_cell = 50ms 满足联合约束 `T_cell × MAX_PATH_LENGTH ≤ 1500ms`）。若需调高，须同步降低 T_cell 满足联合约束。

#### TK-3 — `REJECT_FEEDBACK_DURATION`（tap 拒绝视觉反馈时长）

tap 不可达格时轻抖/闪烁动画时长。此动画为**必须实装**（Pillar 3：三秒上手，拒绝反馈明确）——此旋钮控制其时长。太短（< 80ms）玩家不确定「我是否点到了」；太长（> 300ms）变成错误惩罚感，打断输入节奏。

## Visual/Audio Requirements

### 视觉需求

- **格子视觉状态**：CellNode 区分 5 类外观：EMPTY（地板）、WALL（障碍）、ENTITY（怪/道具/钥匙各不同）、DOOR（开/关两态）、STAIR（上/下两态）。16×16 像素精灵，遵循艺术圣经 2-3 色限制
- **格子触控目标尺寸（锁定：16×16 布局 + 整体缩放方案）**：本 GDD 锁定 16×16 网格（256 格）布局，所有公式和 AC 基于此，≤9 列备选方案已弃用。实现方式：GridMovement 根节点 Node2D 以 `scale` 整体缩放，使 16×16 网格在目标屏幕内完整可见；触控检测基于 InputEventScreenTouch 屏幕坐标→格子局部坐标逆变换，每格触控响应区域等于渲染后格子尺寸。精灵仍为 16×16px 像素艺术渲染，独立于触控检测。`CELL_TOUCH_SIZE_DP = 40dp`（TK-4）为设计目标值：在 360dp 竖屏上 16 列网格每格约 22dp，属密集网格可接受 compromise（全格触控场景与孤立按钮 40dp 标准情境不同）；在横屏（≥640dp）或大屏设备上实际值接近 40dp。HUD 系统 (#12) 布局应为网格保留最大可用屏幕区域以提升每格触控尺寸，此为 #12 的前提输入。
- **PlayerMarker**：16×16 像素精灵，格子中心对齐；移动中格间线性位置补间（无骨骼动画）
- **战斗预演覆盖层**：显示 HP 差值 / 预测回合数 / WIN-LOSE 判断；字体最小 12pt（触屏可读）；出现/消失动画时长 ≤ 150ms。覆盖层宽度不得小于 3 格。**锚点翻转阈值（已锁定）**：目标格 col ≥ 13（右边界区）时覆盖层向左锚定；col ≤ 2（左边界区）时向右锚定；其余默认右上锚定，覆盖层显示在目标格右上方。**渲染层级**：覆盖层节点 `z_index ≥ 100`（或置于独立 CanvasLayer），确保渲染在格子精灵层之上。**触控事件拦截（关键实现约束）**：覆盖层显示期间必须拦截其 Rect2 范围内所有 InputEventScreenTouch 事件，不得穿透到下方格子。**唯一有效实现（方案 B：全部在 `_input()` 内分流，不依赖 GUI 传播路径）**：在 GridMovement 的 `_input()` 入口，`_state == PREVIEWING` 时通过以下两个接口获取屏幕空间 Rect2（均在 `show_overlay()` 时由 CombatForecastOverlay 缓存；**经 `@export var forecast_overlay: CombatForecastOverlay` 引用调用——Overlay 是 game.tscn Scene Node，非 Autoload 全局名；ADR-0008**）：**`forecast_overlay.get_overlay_screen_rect() -> Rect2`**（覆盖层整体）和 **`forecast_overlay.get_x_button_screen_rect() -> Rect2`**（× 按钮子区域）。`_input()` 分流逻辑：(1) 若触点**在 × 按钮 Rect2 内**：执行取消（`hide_overlay()` + 回 IDLE），调用 `get_viewport().set_input_as_handled()` 消费事件，不分发任何 `GameState.on_*`；(2) 若触点**在覆盖层 Rect2 内但不在 × 按钮 Rect2 内**：调用 `get_viewport().set_input_as_handled()` 消费事件，不进入格子点击逻辑（**无 CTA 分支**——#10 覆盖层不含确认区域，此分支纯吞事件，见 AC-COMB-7 RESOLVED-VOID）；(3) 若触点**在覆盖层 Rect2 外**：正常进入格子点击逻辑（M1 规则）——确认进攻即落在此分支：覆盖层锚点翻转保证目标怪物格在 Rect2 外可被再次 tap 命中。**接口约束（#10 CombatForecast GDD 必须满足）**：`get_overlay_screen_rect()` 和 `get_x_button_screen_rect()` 均须返回**屏幕空间坐标**（与 `InputEventScreenTouch.position` 坐标系一致；禁止返回 Control 局部坐标，否则拦截判断系统性偏移），且均须**在 `show_overlay()` 调用时缓存坐标**（防止同帧内 CanvasLayer 布局未完成时返回旧值或零矩形）。覆盖层 Control 节点的 `mouse_filter` 设置不影响此方案——拦截完全由 `_input()` 负责。
- **覆盖层 × 关闭按钮**：最小 **40×40dp**（字号 ≥ 16pt）；点按后覆盖层立刻隐藏，GridMovement 回 IDLE，不分发任何事件。× 按钮须位于覆盖层内部安全区域（不超出覆盖层 Rect2 边界），确保其触控区域不与格子触控区域重叠。**锚点翻转时的 × 按钮位置规则（已锁定）**：× 按钮始终位于「离目标格最远的角」——右上锚定（默认）时位于覆盖层右上角；左锚定（col ≥ 13）时位于覆盖层**左上角**；右锚定（col ≤ 2）时位于覆盖层右上角。此规则降低玩家想取消时误触目标怪物格触发战斗确认的概率。
- **PREVIEWING 目标怪物格脉冲高亮（必须实装，2026-06-29 新增 — #10 CF-7 协调项）**：进入 PREVIEWING 后，GridMovement 对**目标怪物格**施加低频脉冲/高亮（呼吸式 alpha 或描边），持续至离开 PREVIEWING。**目的**：由于覆盖层不含显式「进攻」CTA 按钮，确认手势是「再次 tap 该怪物格」——高亮把玩家视线引向「可再次点击的目标」，与 #10 覆盖层内常驻提示文字「再次点击怪物进攻」共同保证确认手势的可发现性（Pillar 3「三秒上手」）。此线索归 GridMovement 渲染（#10 不跨域绘制网格格子）。建议作为 TK 旋钮 `PREVIEW_HIGHLIGHT_PERIOD`（默认 ~600ms 一个脉冲周期）。
- **tap 拒绝反馈（必须实装）**：目标格轻抖或半透明闪烁，时长 = TK-3 `REJECT_FEEDBACK_DURATION`（默认 150ms）。静默无反馈违反 Pillar 3「三秒上手」自解释原则，玩家无法区分精度失误与路径阻塞。
- **楼层重载过渡**：淡出-淡入或直切均可；最大过渡时长 ≤ 300ms

### 音频需求

- **GridMovement 不直接调用音效**；所有音效触发通过信号/状态变化由音效系统 #19 订阅
- **脚步音**：订阅 `player_moved(new_pos)` 信号，每格到达触发一次（见 AC-VIS-4）
- **战斗预演**：订阅 PREVIEWING 状态进入/退出
- **楼层切换**：由 `FloorProgress.floor_changed` 触发，#19 直接订阅该信号

## UI Requirements

GridMovement 是 Node2D Scene Node（非 Control），无 UI 层级或布局约束。

战斗预演覆盖层由 CombatForecast (#10) 持有并管理。GridMovement 通过两个接口与之交互：进入 PREVIEWING 时调用 `forecast_overlay.show_overlay(forecast, cell_col, cell_row)`，离开 PREVIEWING 时调用 `forecast_overlay.hide_overlay()`（规则 M4 / F-PREV）。覆盖层的 UI 布局规范（数字排版、锚点计算实现）属于 #10 GDD 范围。GridMovement 仅在 Visual/Audio Requirements 节定义锚点翻转的**触发条件**（col 阈值），供 #10 GDD 实现时参考。GridMovement 本身无需独立 UI 规范文档。

## Acceptance Criteria

Criteria are grouped by functional area. **[BLOCKING]** = automated test required (hard gate for Done). **[CI-Lint]** = CI static-analysis check (not a GDUnit4 test). **[ADVISORY]** = manual walkthrough or playtest evidence sufficient. Post 5th-round design-review 2026-06-26: net ~47 BLOCKING / 5 ADVISORY / 3 CI-Lint (Round 5 changes: +AC-SIG-4b, +AC-COMB-7 [placeholder]; AC-COMB-2 split into AC-COMB-2a [BLOCKING] + AC-COMB-2b [BLOCKED]; +AC-SIG-5b [CI-Lint]; AC-LOCK-5a frames 300→10; AC-MOV-1a tolerance ±33ms→±66ms). **2026-06-29 sync (#10 design-review)**: AC-COMB-7 → RESOLVED-VOID (CTA 设计废止，BLOCKING −1)；AC-COMB-2b 解除 BLOCKED（#10 已锁定 CombatForecast 字段名：`n_rounds` / `total_damage_to_player` / `player_survives` / `predicted_hp_after`）。

Test file targets: `tests/unit/grid_movement/` (Logic), `tests/integration/grid_movement/` (Integration), `production/qa/evidence/` (Visual/Feel).

### 1. 状态机转换

**AC-SM-1** [BLOCKING — Logic] GIVEN IDLE, WHEN tap reachable EMPTY, THEN transitions to MOVING before first animation frame, does not remain IDLE.

**AC-SM-2** [BLOCKING — Logic] GIVEN IDLE and reachable MONSTER, WHEN tapped, THEN transitions to PREVIEWING, `CombatForecastService.forecast_combat()` called exactly once with correct 6-int args, preview overlay visible.

**AC-SM-3** [BLOCKING — Logic] GIVEN IDLE, WHEN tap reachable ITEM/KEY/DOOR/STAIR, THEN transitions to LOCKED immediately and the corresponding `GameState.on_*` method is called before any frame passes.

**AC-SM-4** [BLOCKING — Logic] GIVEN IDLE, WHEN tap WALL or unreachable cell, THEN remains IDLE and no dispatch is called.

**AC-SM-5** [BLOCKING — Logic] GIVEN PREVIEWING with MONSTER M targeted, WHEN tap M a second time, THEN transitions to LOCKED, `GameState.on_combat_cell_entered(cell, pos)` called exactly once, preview overlay hidden.

**AC-SM-6** [BLOCKING — Logic] GIVEN PREVIEWING, WHEN tap reachable EMPTY, THEN preview overlay hidden, transitions to MOVING (not IDLE), BFS begins toward tapped cell; `on_combat_cell_entered` not called for cancelled MONSTER.

**AC-SM-7** [BLOCKING — Logic] GIVEN PREVIEWING, WHEN tap a WALL cell or any unreachable cell, THEN transitions to IDLE, overlay hidden, no dispatch called. (For reachable ITEM/KEY/DOOR/STAIR, see AC-SM-10. AC-EC-2 describes the same scenario — test cases merged here.)

**AC-SM-10** [BLOCKING — Logic] GIVEN PREVIEWING with MONSTER M targeted, WHEN tap a reachable ITEM, KEY, DOOR, or STAIR cell, THEN preview overlay hidden, corresponding `GameState.on_*_cell_entered(cell, pos)` called exactly once, transitions to LOCKED. `on_combat_cell_entered` NOT called for the cancelled MONSTER M.

**AC-SM-11** [BLOCKING — Logic] GIVEN PREVIEWING with any MONSTER targeted and preview overlay visible, WHEN player taps the × close button on the overlay, THEN overlay hidden, transitions to IDLE, no `GameState.on_*` dispatch called, `CombatForecastService.forecast_combat()` NOT called a second time. × button is the only gesture that guarantees cancel with zero side-effects regardless of surrounding cell types.

**AC-SM-8** [BLOCKING — Logic] GIVEN MOVING, WHEN PlayerMarker arrives at final path cell, THEN transitions to IDLE; no further movement; ready for next tap.

**AC-SM-9** [BLOCKING — Integration] GIVEN LOCKED, WHEN `GameState.grid_unlock` emitted, THEN transitions to IDLE within the same frame.

---

### 2. 分发路由（Rule M1）

**AC-DISP-1** [BLOCKING — Logic] GIVEN IDLE and reachable EMPTY target, WHEN tapped, THEN BFS initiated, enters MOVING, no `GameState.on_*` called.

**AC-DISP-2** [BLOCKING — Logic] GIVEN IDLE and reachable MONSTER, WHEN tapped, THEN enters PREVIEWING; `on_combat_cell_entered` NOT called until second confirmation tap; `CombatForecastService.forecast_combat()` IS called on first tap.

**AC-DISP-3** [BLOCKING — Logic] GIVEN IDLE and reachable ITEM, WHEN tapped, THEN `GameState.on_item_cell_entered(cell, pos)` called exactly once; enters LOCKED.

**AC-DISP-4** [BLOCKING — Logic] GIVEN IDLE and reachable KEY, WHEN tapped, THEN `GameState.on_item_cell_entered(cell, pos)` called exactly once (KEY routes to `on_item_cell_entered`, not a separate method); enters LOCKED.

**AC-DISP-5** [BLOCKING — Logic] GIVEN IDLE and reachable DOOR (any key state), WHEN tapped, THEN `GameState.on_door_cell_entered(cell, pos)` called exactly once; enters LOCKED; GridMovement does not read key inventory.

**AC-DISP-6** [BLOCKING — Logic] GIVEN IDLE and reachable STAIR_UP or STAIR_DOWN, WHEN tapped, THEN `GameState.on_stair_cell_entered(cell, pos)` called exactly once; enters LOCKED; PlayerMarker does NOT animate toward or reposition to the stair cell.

**AC-DISP-7** [BLOCKING — Logic] GIVEN IDLE, WHEN tap WALL, THEN remains IDLE; no `GameState.on_*` called; no pathfinding initiated.

**AC-DISP-8** [BLOCKING — Logic] GIVEN IDLE and target with no valid BFS path, WHEN tapped, THEN remains IDLE; no dispatch called. (Optional reject visual does not constitute a state change.)

---

### 3. 输入锁定

**AC-LOCK-1** [BLOCKING — Logic] GIVEN MOVING, WHEN player taps any cell (any type, any position), THEN tap discarded with zero side-effects: no state change, no dispatch, no queued input.

**AC-LOCK-2** [BLOCKING — Logic] GIVEN LOCKED, WHEN player taps any cell, THEN tap discarded with zero side-effects; state remains LOCKED until `grid_unlock` received.

**AC-LOCK-3** [BLOCKING — Logic] GIVEN IDLE, WHEN tap the cell currently occupied by PlayerMarker (path_length = 0), THEN ignored: no state change, no dispatch, no animation.

**AC-LOCK-4** [BLOCKING — Logic] GIVEN multi-finger touch, WHEN two or more fingers contact screen simultaneously, THEN only first finger's position is evaluated; subsequent fingers ignored for the gesture lifetime; result identical to single-tap at first finger's position.

**AC-LOCK-5a** [BLOCKING — Logic] GIVEN LOCKED state and `LOCK_TIMEOUT_MS = 0` (disabled), WHEN `grid_unlock` signal is withheld AND test advances 10 frames of simulated time (use `GdUnitSceneRunner.simulate_frames(10, 0.033)` — fixed delta 0.033 s, sufficient to prove the "disabled = never fires" invariant without running 10 s of simulation; do not use `OS.delay_msec`), THEN GridMovement state = LOCKED throughout, no `push_error` emitted, all tap inputs discarded during the period. Final state = LOCKED. No automatic recovery occurs. **断言方式（Option A — state_changed 信号监控，已锁定）**：在 `simulate_frames(10, 0.033)` 调用**之前**订阅 `GridMovement.state_changed` 信号（用 GDUnit4 `monitor_signals(grid_movement)` 或等价方式）；10 帧结束后断言 `assert_signal_not_emitted(grid_movement, "state_changed")`。若任何状态转换发生（即使最终回到 LOCKED），信号监控均能捕获——这比轮询 `grid_movement.state` 更严格，防止「短暂离开 LOCKED 再回来」的漏报。

**AC-LOCK-5b** [CI-Lint] GridMovement LOCK_TIMEOUT_MS countdown timer must not be a hardcoded SceneTree `Timer` child node — it must support dependency injection so tests can advance time with `simulate_frames`. **Verification**: `grep -rE 'Timer\.new|SceneTree.*create_timer' src/grid_movement/` returns empty set. Runs in CI lint pass (not GDUnit4 runtime).

**AC-LOCK-6** [BLOCKING — Logic] GIVEN LOCKED state and `LOCK_TIMEOUT_MS > 0` (e.g. 5000ms), WHEN the configured duration elapses without receiving `grid_unlock`, THEN GridMovement emits `push_error("GridMovement: LOCKED timeout exceeded — forcing IDLE")`, transitions to IDLE, and is ready to accept tap inputs again. GameState is NOT notified of the forced unlock.

---

### 4. BFS 路径寻路（F-REACH）

**AC-BFS-1** [BLOCKING — Logic] GIVEN path to target passes through WALL cells, WHEN BFS runs, THEN computed path does not traverse any WALL cell; if no WALL-avoiding path exists, tap ignored.

**AC-BFS-2** [BLOCKING — Logic] GIVEN uncleared ENTITY cell lies between player and EMPTY target, WHEN BFS runs, THEN path routes around ENTITY; if no route exists, tap ignored.

**AC-BFS-3** [BLOCKING — Logic] GIVEN unopened DOOR lies between player and EMPTY target, WHEN BFS runs, THEN path does not pass through DOOR; if no detour, tap ignored.

**AC-BFS-4** [BLOCKING — Logic] GIVEN STAIR cell lies between player and EMPTY target, WHEN BFS runs, THEN path does not route through STAIR; STAIR cells are legal tap targets but illegal intermediate nodes.

**AC-BFS-5** [BLOCKING — Logic] GIVEN cell previously held ENTITY and received `cell_cleared`, WHEN subsequent tap triggers BFS, THEN that cell is treated as passable (EMPTY) and may appear in computed path.

**AC-BFS-6** [BLOCKING — Logic] GIVEN DOOR cell received `door_opened`, WHEN BFS runs, THEN that cell treated as passable and may appear in computed path.

**AC-BFS-7** [BLOCKING — Logic] PLAYER_START cell is always passable regardless of any prior occupancy or visual state.

**AC-BFS-8** [BLOCKING — Logic] GIVEN tap on non-EMPTY target (MONSTER/ITEM/KEY/DOOR/STAIR), WHEN BFS evaluates reachability, THEN termination condition = any 4-directional adjacent passable cell of the target is reachable (not the target cell itself); if none reachable, tap ignored.

**AC-BFS-9** → 已合并入 **AC-EC-3**（MOVING 路径中途 cell_cleared 信号 → 路径不重算）。不需要独立测试用例。

---

### 5. 移动时序（F-MOV）

**AC-MOV-1a** [BLOCKING — Logic] GIVEN path of `n` cells where `n ≥ 2` and configured `T_cell` (0 < T_cell ≤ 66.7ms / ≤ 2 frames @ 30fps), WHEN PlayerMarker completes animation, THEN elapsed time ∈ [`n × T_cell − 66ms`, `n × T_cell + 66ms`] (±two-frame tolerance **total for the entire path**, not per step; expanded from ±33ms to ±66ms to provide test-stability margin against `simulate_frames` timing precision in CI; valid when per-cell Tween steps are chained — frame boundaries do not accumulate across chained steps. Implementer must use `Tween.chain()` or equivalent; do not `await` each step individually, as that accumulates per-step timing error). **Test timing**: use `GdUnitSceneRunner.simulate_frames(N, 0.033)` with fixed delta 0.033 s — do not measure real-clock wall time. Must pass for default T_cell = 50ms. **经过时间测量方法**：循环调用 `simulate_frames(1, 0.033)` 直到 GridMovement 状态回到 IDLE，计数帧数 × 0.033s 即为 T_total（避免预先计算 N 值时的 off-by-one；也可通过 `state_changed` 信号监听 IDLE 转换时机）。

**AC-MOV-1b** [BLOCKING — Logic] GIVEN path of exactly 1 cell and configured `T_cell` (0 < T_cell ≤ 66.7ms), WHEN PlayerMarker completes animation, THEN elapsed time ∈ [`T_cell × 0.9`, `T_cell + 33ms`]. Lower bound derivation: a Godot Tween starting mid-frame loses at most one frame-start delta before its first step; for T_cell ≥ 20ms this loss is ≤ 10% of T_cell, giving the 0.9× factor. Upper bound is T_cell plus one frame (33ms). AC must pass for T_cell = 50ms (range [45ms, 83ms]) and T_cell = 20ms (range [18ms, 53ms]).

**AC-MOV-2** [BLOCKING — Logic] GIVEN T_cell = 50ms and path_length = 30, WHEN movement completes, THEN T_total ≤ 1500ms. Any path where path_length × T_cell > 1500ms is an anomalous state — must be logged as push_error.

**AC-MOV-3** [BLOCKING — Logic] GIVEN adjacent EMPTY cell (path_length = 1) and T_cell = 50ms, WHEN tapped, THEN MOVING state lasts ≥ 1 frame and ≤ 83ms before returning to IDLE; T_total must not be 0ms (no instant teleport). 上界 83ms = T_cell(50ms) + one frame(33ms)，与 AC-MOV-1b 单格上界 [45ms, 83ms] 一致；原文「≤ T_cell」与 AC-MOV-1b 矛盾，已修正。

**AC-MOV-4** [ADVISORY — Visual/Feel] GIVEN T_cell in [20ms, 67ms] (updated per TK-1 safe range) on 30fps device, THEN PlayerMarker does not visually skip cells for paths of 5+ cells. Manual verification on low-end Android representative of Douyin install base.

---

### 6. 信号接收

**AC-SIG-1** [BLOCKING — Integration] GIVEN CellNode displaying ENTITY visual, WHEN `GameState.cell_cleared(floor_id, col, row)` emitted with matching coordinates, THEN CellNode switches to EMPTY visual in same frame and subsequent BFS treats cell as passable.

**AC-SIG-2** [BLOCKING — Logic] GIVEN CellNode already in EMPTY state, WHEN `cell_cleared` fires for that cell, THEN no visual change, no scene-tree operations, no error. Call is a no-op.

**AC-SIG-3** → 已合并入 **AC-SM-9**（内容完全相同）。不需要独立测试用例。

**AC-SIG-4** [BLOCKING — Logic] GIVEN PREVIEWING (not LOCKED), WHEN `GameState.grid_unlock` received, THEN hides preview overlay, transitions to IDLE; no error raised. Defensive path: tests must assert no crash and final state = IDLE.

**AC-SIG-4b** [BLOCKING — Logic] GIVEN MOVING, WHEN `GameState.grid_unlock` received at any point during path animation, THEN signal silently discarded (no state change, no dispatch, no log); MOVING state and animation continue unaffected; GridMovement transitions to IDLE only when PlayerMarker reaches the final path cell per normal MOVING completion. **测试方式（分段 simulate_frames）**：(1) `simulate_frames(1, 0.033)` 让动画开始进入 MOVING；(2) 发出 `GameState.grid_unlock` 信号；(3) assert state = MOVING（信号不影响 MOVING）；(4) `simulate_frames(N, 0.033)` 直到动画完成；(5) assert final state = IDLE；(6) assert no `push_error` emitted. 步骤 (1) 必须在信号发出前执行，确保系统已进入 MOVING（而非 IDLE），否则信号在 IDLE 态触发，语义不同。

**AC-SIG-5** [BLOCKING — Integration] GIVEN MOVING mid-path executing step N, WHEN `FloorProgress.floor_changed(new_floor_id)` received during that cell's animation, THEN step N animation completes (PlayerMarker reaches cell N center — no teleport mid-cell), remaining path steps after step N are cancelled, floor reload begins immediately for `new_floor_id`. PlayerMarker does not continue along old path after reload begins. (AC-EC-4 describes the same scenario — test cases merged here.) **实现约束（Flag 标记模式，已锁定）**：接收 `floor_changed` 时设置内部 `_pending_floor_id` 标记，不立即截断当前格 Tween；当前格 Tween `finished` 信号触发后检查标记，若存在则启动楼层重载并清除标记，否则继续下一格路径。禁止使用 `tween.stop()` 直接截断（`tween.stop()` 不触发 `finished` 信号，导致 `await tween.finished` 的协程永久挂起，在节点销毁前无法被清理，等效于协程泄漏）。

**AC-SIG-5b** [CI-Lint] GridMovement 的 `floor_changed` 信号处理函数中，禁止直接调用 `tween.stop()` 或 `tween.kill()` 截断路径动画——必须使用 Flag 模式（`_pending_floor_id`）延迟处理。**验证**：`grep -rE 'tween\.(stop|kill)\(\)' src/grid_movement/` 返回空集，纳入 CI lint 检查（与 AC-LOCK-5b 同批执行）。注：`tween.stop()` 与 `tween.kill()` 均不触发 `finished` 信号，导致 `await tween.finished` 协程永久挂起，须一并禁止。

**AC-SIG-6** [BLOCKING — Integration] GIVEN door CellNode in unopened state, WHEN `KeyDoor.door_opened(floor_id, col, row)` emitted with matching coordinates, THEN CellNode switches to EMPTY visual, CellNode `cell_type` updated to `EMPTY`, and `_passable` cache updated; subsequent BFS treats cell as passable, and subsequent tap on that cell triggers pathfinding (not `on_door_cell_entered`).

**AC-SIG-7** [BLOCKING — Logic] GIVEN floor_id = X loaded, WHEN `cell_cleared` or `door_opened` arrives with floor_id ≠ X, THEN no CellNode updated, no error emitted. Signal silently discarded.

**AC-SIG-7b** [BLOCKING — Logic] GIVEN floor_id = X loaded AND 一个 DOOR 格（col=5, row=5）在 `_passable` 中为 false，WHEN `KeyDoor.door_opened(floor_id=Y, col=5, row=5)` 到达（Y ≠ X），THEN `_passable[5 + 5 * 16]` 仍为 false（`_passable` 缓存未被污染），对应 CellNode visual 状态不变，BFS 仍将该格视为不可通行。Test: assert `_passable[85] == false` after signal; assert CellNode.cell_type unchanged.

---

### 7. 楼层重载（Rule M7）

> **⚠️ 待 AC 重表述（ADR-0009 同步，2026-06-29）**：本节 AC-FLOOR-1/2/5 原按「256 个独立 CellNode 销毁/实例化」措辞编写。ADR-0009 已将渲染/重建方案改为 **TileMapLayer 批量 set_cell + 池化覆盖节点**——不再有「256 个 CellNode 子节点」。下列 AC 的断言对象须在 #6 下一次 design-review / 实现前重表述为 TileMapLayer 语义（如 AC-FLOOR-1 → 「所有 256 格经 set_cell 更新为新楼层 tile，无上一层 tile 残留；活动覆盖节点全部归还池」；AC-FLOOR-2 → 「每格 TileMapLayer cell 的 atlas tile 与 FloorEntry 该坐标 cell_type 一致」）。断言**意图**不变（重建完整性 + 无残留），仅实现载体由 CellNode 改为 TileMapLayer cell。

**AC-FLOOR-1** [BLOCKING — Integration] GIVEN 256 CellNode children loaded, WHEN `floor_changed(new_floor_id)` received, THEN all 256 existing CellNodes removed from scene tree before any new CellNode instantiated. No previous-floor CellNode persists after reload. *(措辞待按 ADR-0009 重表述为 TileMapLayer set_cell 语义 — 见本节顶部注记)*

**AC-FLOOR-2** [BLOCKING — Integration] GIVEN `FloorDB.get_floor(new_floor_id)` returns valid FloorEntry, WHEN floor reload completes, THEN each of 256 CellNodes has cell_type and visual state matching FloorEntry at its (col, row) coordinate.

**AC-FLOOR-3** [BLOCKING — Integration] GIVEN floor reload triggered by `floor_changed`, WHEN new floor fully instantiated, THEN PlayerMarker grid position = PLAYER_START cell of new floor. If no PLAYER_START exists: `push_error` + fallback position (0,0).

**AC-FLOOR-4** [BLOCKING — Logic] GIVEN floor reload triggered from any state (IDLE/PREVIEWING/MOVING/LOCKED), WHEN new floor instantiated and PlayerMarker positioned, THEN GridMovement is in IDLE. No residual MOVING/PREVIEWING/LOCKED state.

**AC-FLOOR-4b** [BLOCKING — Logic] GIVEN PREVIEWING (overlay visible, MONSTER targeted) and `floor_changed` signal fires, WHEN processed, THEN `forecast_overlay.hide_overlay()` called, GridMovement transitions to IDLE, no `GameState.on_*` dispatch called. Test: assert hide_overlay called exactly once; assert final state = IDLE; assert `GameState.on_combat_cell_entered`、`GameState.on_door_cell_entered`、`GameState.on_stair_cell_entered`、`GameState.on_item_cell_entered` 均未调用（mock GameState 四个方法，各自调用计数均为 0）。

**AC-FLOOR-5** [BLOCKING — Logic] GIVEN `FloorDB.get_floor(new_floor_id)` returns null or raises error, WHEN floor reload attempted, THEN all 256 CellNodes initialized as WALL, `push_error` emitted with the failing floor_id, GridMovement enters IDLE, game does not crash.

---

### 8. 两步战斗确认

**AC-COMB-1** [BLOCKING — Logic] GIVEN IDLE and reachable MONSTER with entity_id resolving to valid MonsterEntry, WHEN tapped, THEN `CombatForecastService.forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp)` called exactly once with values from EntityDB and live PlayerStats. GridMovement performs no combat math itself.

**AC-COMB-2a** [BLOCKING — Logic] GIVEN IDLE and reachable MONSTER, WHEN tapped, THEN GridMovement passes the CombatForecast object returned by `forecast_combat()` **unmodified** to `forecast_overlay.show_overlay(forecast, col, row)` — no field extraction, no math re-derivation, no copy. Test: mock `forecast_combat()` returning a fixed sentinel object（`RefCounted` 派生）；用 GDUnit4 `assert_object(captured_arg).is_same(sentinel)` 断言 `show_overlay` 接收到的**正是同一对象实例**（非值相等，是引用同一性）。注：`RefCounted` 在 GDUnit4 中需用 `is_same()` 而非 `is_equal()`，因 `RefCounted` 不实现 `==` 操作符，`is_equal()` 可能 fallback 到指针比较以外的行为。GridMovement must never touch the forecast object's fields. Test location: `tests/unit/grid_movement/`.

**AC-COMB-2b** [RESOLVED → 委托 #10，2026-06-29] [原 BLOCKED 已解除：#10 GDD 已锁定字段名] CombatForecast 字段名已确认为 `n_rounds` / `total_damage_to_player` / `player_survives` / `predicted_hp_after`。「覆盖层展示值与 CombatForecast 字段逐字段一致、无重舍入、无二次计算」的渲染验证**归 #10**（由 #10 AC-CF-7a / AC-CF-8a 覆盖，因覆盖层渲染由 #10 持有）。GridMovement 侧的职责仅为「不修改对象、原样透传」，已由 **AC-COMB-2a**（引用同一性断言）保证。本条不再需要 #6 侧独立测试。This criterion's "informed consent" guard for Pillar 2 is now enforced jointly by AC-COMB-2a (#6, pass-through) + AC-CF-7a/8a (#10, render-match).

**AC-COMB-3** [BLOCKING — Logic] GIVEN PREVIEWING with MONSTER cell M, WHEN player taps M again, THEN `GameState.on_combat_cell_entered(cell, pos)` called exactly once; overlay hidden; transitions to LOCKED.

**AC-COMB-4** [BLOCKING — Logic] GIVEN PREVIEWING, WHEN player taps same MONSTER to confirm, THEN `CombatForecastService.forecast_combat()` is NOT called a second time. Forecast from first tap is reused.

**AC-COMB-5** [BLOCKING — Logic] GIVEN PREVIEWING with MONSTER A targeted, WHEN player taps different reachable MONSTER B, THEN overlay for A hidden, `forecast_combat` called once for B's stats, GridMovement remains PREVIEWING (not IDLE), overlay for B shown. `on_combat_cell_entered` not called for either A or B.

**AC-COMB-6** [BLOCKING — Logic] GIVEN PREVIEWING with any MONSTER targeted and preview overlay visible, WHEN player taps the × close button on the overlay, THEN overlay hidden, transitions to IDLE, no `GameState.on_*` dispatch called, `CombatForecastService.forecast_combat()` NOT called a second time. × button is the designated pure-cancel gesture — no side-effects regardless of surrounding cell layout. See also AC-SM-11.

**AC-COMB-7** [RESOLVED-VOID — 2026-06-29] ~~CTA 确认区域确认路径~~。**已废止**：#10 CombatForecast GDD 经 creative-director 裁决采用「无 CTA + 再次 tap 怪物格确认」设计，覆盖层不含显式 CTA 确认区域。本 AC 描述的场景（「tap 覆盖层内专用 CTA 区域」）**不存在**，无需实现或测试。确认进攻路径完全由 **AC-COMB-3**（再次 tap 同一 MONSTER 格 → LOCKED）覆盖。原计划的 `pending()` 测试骨架应移除（不存在的功能不需要占位测试）。CTA 不存在性由 #10 AC-CF-11（CI-Lint）从 CombatForecast 侧验证。

---

### 9. 边缘情况

**AC-EC-1** [BLOCKING — Logic] GIVEN two-finger touch where finger 1 contacts WALL and finger 2 contacts EMPTY simultaneously, WHEN processed, THEN only finger 1 evaluated (WALL → ignored); finger 2's EMPTY tap does not trigger movement.

**AC-EC-2** → 已合并入 **AC-SM-7**（PREVIEWING + WALL 或不可达格 → IDLE，覆盖层隐藏，不分发事件）。不需要独立测试用例。

**AC-EC-3** [BLOCKING — Logic] GIVEN MOVING on path [A→B→C→D] (all cells were EMPTY at path-computation time — BFS precondition) and `cell_cleared` fires for cell B mid-path (B was already EMPTY; `cell_cleared` on an already-EMPTY cell is a no-op per AC-EC-9), WHEN signal processed, THEN PlayerMarker continues A→B→C→D without deviation. Path not recomputed mid-execution. See also AC-BFS-9 (merged).

**AC-EC-3b** [BLOCKING — Logic] GIVEN MOVING on path [A→B→C→D] and `cell_cleared` fires for cell E（**不在**当前路径上，cell_type = ENTITY → EMPTY），WHEN signal processed during MOVING，THEN (1) 当前路径执行不受影响（PlayerMarker 完成 A→B→C→D）；(2) `_passable[E]` 更新为 true（M6 规则）；(3) MOVING 结束回 IDLE 后，若再次 tap E，BFS 正常将 E 纳入候选路径。Test: assert path completes unmodified; assert `_passable[E_index] == true` after signal; assert no BFS recomputation triggered during MOVING.

**AC-EC-4** → 已合并入 **AC-SIG-5**（MOVING + floor_changed，含「不得 teleport mid-cell」约束）。不需要独立测试用例。

**AC-EC-5** [BLOCKING — Logic] GIVEN `FloorDB.get_cell()` returns null for any cell during init, WHEN processed, THEN affected cell initialized as WALL, `push_error` emitted identifying coordinates and floor_id, no exception propagates. All 256 cells initialize even if individual cells error.

**AC-EC-6** [BLOCKING — Logic] GIVEN IDLE and PlayerMarker occupying cell P, WHEN player taps P, THEN remains IDLE; no BFS; no dispatch; no animation. Path_length = 0 rejected before any processing.

**AC-EC-7** [BLOCKING — Logic] GIVEN IDLE and reachable STAIR, WHEN tapped, THEN `GameState.on_stair_cell_entered(cell, pos)` called; enters LOCKED; PlayerMarker grid position unchanged (does not animate toward or reposition to stair cell).

**AC-EC-8** [BLOCKING — Logic] GIVEN IDLE and reachable DOOR with player holding zero keys, WHEN tapped, THEN `GameState.on_door_cell_entered(cell, pos)` called; enters LOCKED; GridMovement does not read key inventory. KeyDoor (#7) decides the outcome.

**AC-EC-9** [BLOCKING — Logic] GIVEN CellNode in EMPTY state, WHEN `cell_cleared` fires for it, THEN no visual update, no scene-tree operations, no re-emitted signal, no error logged. Pure no-op.

**AC-EC-10** [BLOCKING — Logic] GIVEN cell with cell_type = ENTITY whose entity_id is not in EntityDB, WHEN tapped, THEN tap ignored, `push_error("GridMovement: entity_id not found: [id]")` emitted, remains IDLE. No dispatch called.

**AC-EC-11** → 已合并入 **AC-SIG-4**（PREVIEWING + grid_unlock → IDLE，覆盖层隐藏）。不需要独立测试用例。

---

### 10. Scope-Gate 检查（Anti-Pillars）

**AC-SCOPE-1** [CI-Lint — 非 GDUnit4 测试] GridMovement 在任何代码路径中不持有、不生成、不传入任何随机数到战斗结算流程。`forecast_combat()` 接收的所有 6 个参数均来自 EntityDB 和 PlayerStats 的确定性只读查询。**验证方式**：CI 静态分析——`grep -rE 'randf|randi|RandomNumberGenerator' src/grid_movement/` 返回空集，纳入 CI lint 检查。不属于 GDUnit4 运行时测试套件（全称命题无法在运行时穷举验证）。

**AC-SCOPE-2** [ADVISORY — Design Review] GridMovement 对核心循环增加的操作步骤上限：EMPTY 格 1 次 tap（见 AC-DISP-1, AC-SM-1）；ITEM/KEY/DOOR/STAIR 1 次 tap（见 AC-DISP-3~6, AC-SM-3）；MONSTER 格最多 2 次 tap（见 AC-COMB-3, AC-COMB-5）。上述具体行为已由对应 AC 覆盖测试；本条作为架构级设计约束声明，通过状态机图审核 + code review 验证，不产生独立 GDUnit4 测试用例。

**AC-SCOPE-3** [ADVISORY — CI-Lint（待 ADR-0007）] GridMovement 不主动触发任何激励广告事件。本系统对外分发的所有方法均由玩家 tap 直接驱动；不存在定时器、信号转发或自动调用路径。**验证方式**：grep Douyin SDK 广告触发接口名称（如 `tt.showRewardedVideoAd` 等，完整列表待 ADR-0007 定义）。ADR-0007 完成后升级为 [CI-Lint] 并补充具体接口名称；当前通过 code review 验证。

---

### 11. 视觉与音频（Advisory）

**AC-VIS-1** [ADVISORY — Visual/Feel] Manual verification: tap MONSTER cell → combat forecast overlay appears above target with non-zero values. Cancel or confirm → overlay disappears without residual artifacts. Lead sign-off in `production/qa/evidence/`.

**AC-VIS-2** [BLOCKING — Integration] GIVEN IDLE and tap on WALL or unreachable cell, WHEN processed, THEN configured reject animation (TK-3) fires exactly once and completes within `REJECT_FEEDBACK_DURATION` without looping or persisting. Test: mock animation driver; assert triggered once, assert no residual state after REJECT_FEEDBACK_DURATION elapses. Test location: `tests/integration/grid_movement/`. **实现前提**：拒绝反馈动画必须通过**可注入接口**触发（如 `_play_reject_feedback(col: int, row: int)` 虚方法或可替换的 `AnimationPlayer` 引用），而非在逻辑层直接创建 Tween；否则测试无法 mock animation driver。GDD 未规定具体 DI 方式，由实现者选择，但须在实现开始前确定接口以保障 AC-VIS-2 可测。(Upgraded from ADVISORY: reject feedback is mandatory per Pillar 3 — see Rule M1 and TK-3.)

**AC-VIS-3** [ADVISORY — Visual/Feel] Manual verification on Douyin mini-game target hardware (30fps): path of 5+ cells, PlayerMarker traverses each intermediate cell without skipping. Test on low-end Android representative of Douyin install base.

**AC-VIS-4** [BLOCKING — Integration] For path of N cells, `player_moved(new_pos)` emitted exactly N times (once per cell arrival, not once per path). Audio system (#19) relies on this signal count for per-step sound triggers. Automatable: use GDUnit4 signal monitor to assert emission count equals path length. Test location: `tests/integration/grid_movement/`.

**AC-VIS-5** [ADVISORY] Real-device adjacent mis-tap rate: on target Douyin hardware (360dp竖屏低端机), 10 consecutive intentional taps at center of a 22dp cell must register on the correct cell in ≥ 9 / 10 attempts (mis-tap rate ≤ 10%). Manual verification evidence in `production/qa/evidence/`. Baseline for 40dp target comparison.

**AC-VIS-6** [DELEGATE → 已落地 #10 AC-CF-9，2026-06-29] GIVEN PREVIEWING with MONSTER at col ≥ 13（右边界区），WHEN overlay shows，THEN `get_x_button_screen_rect()` 返回的 × 按钮 Rect2 须位于覆盖层**左上角**（col ≥ 13 时覆盖层左锚定，× 按钮在离目标格最远的角）；col ≤ 2 时 × 须位于右上角；其余默认右上角。**此 AC 已由 #10 GDD AC-CF-9 接收并定义具体可测断言**（左/右锚定 ≤2px 容差对称断言 + `has_area()`），#6 侧保留为接口约束声明记录，实际测试在 `tests/integration/combat_forecast/`。

---

### 12. 配置验证

**AC-CFG-1** [BLOCKING — Logic] GIVEN GridMovement node enters scene tree (`_ready()`), WHEN configured `T_cell` and `MAX_PATH_LENGTH` loaded, THEN assert `T_cell * MAX_PATH_LENGTH ≤ 1500` — if violated, `push_error("GridMovement: config violates joint constraint T_cell × MAX_PATH_LENGTH ≤ 1500ms")` and clamp `MAX_PATH_LENGTH = floor(1500.0 / T_cell)`. GridMovement must never silently enter a state where valid paths can exceed the 1500ms T_total budget.

---

## Open Questions

1. ~~**CombatForecast (#10) 接口待确认**~~ **[已解决 — 2026-06-29 #10 /design-review]**：#10 CombatForecast GDD 已设计并首轮评审。接口已锁定：`forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp) -> CombatForecast{n_rounds, total_damage_to_player, player_survives, predicted_hp_after}`，与 AC-COMB-1 / F-PREV 一致；AC-COMB-2b 字段名占位符已填充。**关键设计变更**：#10 采用「无 CTA + 再 tap 确认」设计 → 本 GDD 的 CTA 相关内容已同步修订（M4 步骤3、Dependencies #10、`_input()` 分流注释、AC-COMB-7 → RESOLVED-VOID、新增 PREVIEWING 目标格脉冲高亮）。本问题关闭。

2. ~~**PlayerStats 接入方式待确认**~~ **[已解决 — 2026-06-29 第6轮评审]**：ADR-0003 已明确规则——Scene Nodes 通过全局名访问 Autoload，不存储实例引用。PlayerStats (#4) 为 Autoload，GridMovement 直接以全局名读取（`PlayerStats.player_atk` 等），与访问 `CombatForecast`、`GameState` 的模式完全一致，无需新决策。本问题关闭。

3. **#10 依赖是否加入 systems-index** `[#10 GDD 设计时决策]`：当前 systems-index 列 #6 依赖 1 和 2，未列 #10。建议在 #10 GDD 设计时决策：若 #10 是 MVP 必要依赖（GridMovement 两步确认功能必须有），则加入 #6 依赖列；若接受临时桩开发策略，则在桩接口上明确 mock API。

4. ~~**PREVIEWING 状态下 tap DOOR/ITEM/KEY/STAIR 的处理**~~：**已锁定（2026-06-26 设计评审）**。规则 M4 步骤 4 和 AC-SM-10 已明确：取消预演 + 立即分发对应 `on_*_cell_entered` + 进入 LOCKED。

5. **DOOR 无钥匙时玩家反馈的责任归属** `[#7 KeyDoor GDD 设计时解决]`：GridMovement 的正确行为是「tap DOOR → 分发 `on_door_cell_entered` → 进入 LOCKED，不读钥匙库存」（规则 M1、AC-EC-8）。「持有 0 钥匙时告知玩家」的视觉/音效反馈**责任归 #7 KeyDoor**；#7 设计时**必须**定义该反馈（防止「tap→静默→回到原状」的零反馈体验，违反 Pillar 3「三秒上手」）；若反馈需要 GridMovement 提供触发载体（如门格抖动动画），届时回填 #6 接口约束。
