# ADR-0009: GridMovement 楼层切换性能 — TileMapLayer 静态底 + 池化覆盖节点

## Status
Proposed

## Date
2026-06-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3 — TileMapLayer 4.3+/region_rect 4.0/duplicate_deep 4.5 均 ≤ 4.5，方案不依赖 4.6） |
| **Domain** | Core / Rendering（2D 网格渲染 / Node 生命周期 / 性能） |
| **Knowledge Risk** | MEDIUM — TileMapLayer 自 4.3 起替代 TileMap（post-cutoff，但 API 稳定）；region_rect 自 4.0；duplicate_deep 4.5+；Douyin 适配器 ~4.5 基线，4.6.3 兼容性待 spike |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/current-best-practices.md`；ADR-0001、ADR-0003、ADR-0007 |
| **Post-Cutoff APIs Used** | `TileMapLayer`（4.3+，替代已弃用的 `TileMap`）；`Resource.duplicate_deep()`（4.5+，经 FloorDB.get_floor 间接使用；ADR-0001 载体 2026-06-29 由 RefCounted 改为 Resource——RefCounted 无 duplicate_deep） |
| **Verification Required** | （并入 ADR-0007 导出 spike QQ-01）(1) WASM PCK 下 preload 全部 cell-type 纹理的总内存在 256MB 堆限内；(2) ETC2/ASTC 压缩 atlas 的 region 采样在 Douyin WebGL2 下无边缘 bleeding（4px 块对齐 + 2px padding）；(3) TileMapLayer set_cell 批量重绘在 Douyin 适配器 WASM 下行为与桌面一致 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003（#6 GridMovement = Scene Node 宿主，已 Accepted）；ADR-0001（CellEntry/FloorEntry 类型 + FloorDB.get_floor 返回 duplicate_deep 副本，已 Accepted） |
| **Enables** | #6 网格移动与交互系统实现 epic 的 M7（楼层加载）+ Visual 渲染故事 |
| **Blocks** | #6 楼层重载相关性能敏感故事不应在本 ADR Accepted 前按「256 独立 CellNode」实现 |
| **Ordering Note** | 可与 #6 其他故事并行；TileMapLayer TileSet 资产配置须在首个楼层渲染故事前就绪 |

## Context

### Problem Statement
#6 GridMovement（Scene Node, Node2D）GDD M7 原方案在楼层切换时销毁并重建 256 个 CellNode（16×16）。性能注（GDD M7）量化：256 个 CellNode 的 free + instantiate（含 Sprite2D 纹理注册）在低端安卓约 **2.5–13ms / 单帧**，逼近 30fps 的 33.3ms 帧预算，有掉帧风险（TR-grid-007）。GDD M7 自指「实现前建议通过 perf ADR 决策具体方案」。本 ADR 即该决策。

### Constraints
- **性能预算**（technical-preferences.md）：30fps / 33.3ms 帧预算 / **< 50 draw calls** / < 256MB 内存。
- **抖音 WASM / 低端设备**：纹理须压缩（ETC2/ASTC）；WASM 堆约 256MB（含引擎本体）；Compatibility 渲染后端（ADR-0007）。
- **ADR-0003**：GridMovement 为 Scene Node；不持有业务游戏状态（`_passable` 为渲染辅助状态，允许）。
- **ADR-0001**：FloorDB.get_floor() 返回 duplicate_deep 副本（只读，含 256 个 CellEntry 新实例）。
- **#6 per-cell 动态效果需求**：CF-7 PREVIEWING 目标怪物格脉冲高亮（呼吸 alpha / 描边）；门开关两态；楼梯上下两态——这些是单格视觉效果。

### Requirements
- 楼层切换重建成本远低于帧预算（目标 < 2ms）。
- 网格渲染 draw call 在 < 50 预算内（目标网格部分 < 5）。
- 保留 per-cell 动态视觉效果能力（CF-7 高亮、门/楼梯动画）。
- 不违反 ADR-0003（Scene Node、无业务状态）与 ADR-0001（只读副本）。
- headless 可测的逻辑（BFS/`_passable`/状态机）与渲染解耦。

## Decision

**采用混合方案：静态楼层用单个 `TileMapLayer` 渲染；per-cell 动态视觉效果用按需池化的覆盖 `Node2D`。`_passable` 可达性缓存与所有逻辑保留在 GridMovement 层（不下沉到 tile/cell）。**

### 决策细则

1. **静态楼层 = TileMapLayer（4.3+）**
   - GridMovement（Node2D）下挂一个 `TileMapLayer` 子节点渲染整层。每种 cell 外观（EMPTY/WALL/各 ENTITY/DOOR 开·关/STAIR 上·下）是 TileSet 中的一个 tile。
   - 楼层切换：遍历 FloorEntry.grid，对每格 `set_cell(Vector2i(col,row), source_id, atlas_coords)` 批量更新。引擎以 C++ 批量重绘，比 256 次 GDScript `Sprite2D.texture =` 快 1–2 个数量级，draw call 由引擎合并（共享同一 TileSet atlas → 理论近 1 次）。
   - **EMPTY/WALL 用专属 atlas tile**，不用 `visible` 切换——避免 256 次 `NOTIFICATION_VISIBILITY_CHANGED` 传播开销（专家 (a)/(c)）。

2. **per-cell 动态效果 = 按需池化覆盖 Node2D**
   - 不为 256 格常驻节点。维护一个**小覆盖节点对象池**（典型同屏动态格 ≤ 数个：当前 PREVIEWING 目标格高亮 1 个；门/楼梯动画少量）。
   - CF-7 目标怪物格脉冲高亮：从池取一个覆盖 Node2D，定位到目标格，做呼吸 alpha/描边；离开 PREVIEWING 时归还池。
   - 门开关/楼梯两态：静态终态由 TileMapLayer `set_cell` 切 tile 表达；若需过渡动画，用临时覆盖节点播放后归还。

3. **TileSet atlas 约束（WASM/像素艺术，专家 e-2）**
   - 单张 atlas TileSet；每个 tile region 起点与尺寸对齐 **ETC2/ASTC 4×4 像素块边界**；tile 间留 **2px padding**；导入设置 `filter: off`（像素艺术无缩放过滤，防边缘 bleeding）。
   - cell-type 纹理/atlas 在启动时随 PCK 加载（preload 语义）；规模极小（MVP 十余种 tile）。

4. **逻辑/缓存留在 GridMovement（不下沉 tile）**
   - `_passable: Array[bool]`（256）、四状态机、BFS 均在 GridMovement.gd（headless 可测，ADR-0004）。TileMapLayer 仅是渲染面，不持有可达性/业务状态（符合 ADR-0003 game_logic_in_scene_node 禁用模式）。

5. **楼层切换调用契约（防 GC 压力，专家 d）**
   - 楼层切换时调用 **一次** `FloorDB.get_floor(new_floor_id)` 取整个 FloorEntry 副本（ADR-0001 duplicate_deep），遍历 `floor.grid[r][c]` 批量 `set_cell` 并重建 `_passable`。
   - **禁止**在遍历循环内或 per-cell 路径中重复调用 `get_floor()`（否则单次切换产生 256 次 duplicate_deep ≈ 65536 个 CellEntry 待 GC，低端 WASM GC 暂停显著）。

6. **禁用 cell 级 `_process()`**：覆盖节点的动画用 Tween 或 AnimationPlayer 驱动并在结束后归还池；不让网格渲染产生 256 路 per-frame `_process` 基线开销。

### Architecture Diagram

```
GridMovement (Node2D, Scene Node — ADR-0003)
│  _passable: Array[bool](256)  ← 渲染辅助缓存（业务逻辑层，headless 可测）
│  四状态机 / BFS / _input() 触控分流
│
├── TileMapLayer（静态楼层渲染）
│     set_cell(col,row, source, atlas_coords) ×256（批量，引擎级，~近1 draw call）
│     TileSet: 单 atlas（ETC2/ASTC 4px 对齐 + 2px padding + filter:off）
│
├── OverlayPool（按需池化 Node2D，典型 ≤ 数个）
│     CF-7 脉冲高亮 / 门·楼梯过渡动画（Tween/AnimationPlayer，结束归还）
│
└── PlayerMarker（Node2D，单节点）

楼层切换（M7）:
  FloorProgress.floor_changed(id)
    → FloorDB.get_floor(id)  ←★ 仅一次 duplicate_deep
    → for r,c in grid: tilemap.set_cell(...) + _passable[c+r*16]=…
    → PlayerMarker 定位 PLAYER_START → IDLE
```

### Key Interfaces

```gdscript
# GridMovement.gd（Scene Node, Node2D）
@onready var _tilemap: TileMapLayer = $FloorTileMap
var _passable: Array[bool] = []   # 256，渲染辅助缓存

func _load_floor(floor_id: String) -> void:
    var floor := FloorDB.get_floor(floor_id)   # 仅此一次（ADR-0001 duplicate_deep 副本）
    if floor == null:
        push_error("GridMovement: get_floor null for %s — fill WALL" % floor_id)
        # AC-FLOOR-5：256 格全 WALL fallback
        return
    _passable.resize(256)
    for r in 16:
        for c in 16:
            var cell: CellEntry = floor.grid[r][c]
            _tilemap.set_cell(Vector2i(c, r), _TILESET_SOURCE, _atlas_coords_for(cell))
            _passable[c + r * 16] = _is_passable(cell)
    # PlayerMarker → PLAYER_START；state = IDLE

# 信号响应（M6）：cell_cleared / door_opened 先做 floor_id 校验，匹配则
#   _tilemap.set_cell(...) 切为 EMPTY/EMPTY 外观 + _passable[idx]=true
```

## Alternatives Considered

### Alternative 1: 纯对象池（预分配 256 个 CellNode + reset）
- **Description**: GDD M7 原推荐——预分配 256 个 CellNode（Sprite2D），切楼层调 `reset(cell_entry)` 换 atlas region_rect 而非 free/instantiate。
- **Pros**: per-cell 效果最灵活（直接在 CellNode 上做）；与 GDD M7 原表述一致。
- **Cons**: 256 个常驻 Sprite2D 即便用单 atlas + region_rect，批处理仍需谨慎保证不被纹理切换打断；256 次 GDScript reset 赋值比 TileMapLayer C++ 批量 set_cell 慢 1–2 个数量级；256 个常驻节点的场景树遍历/通知基线开销永久存在（专家 (c)）。
- **Rejection Reason**: TileMapLayer 在静态网格渲染上更惯用、更快、draw call 更省；per-cell 动态效果用少量覆盖节点即可覆盖，无需 256 常驻节点的代价。

### Alternative 2: 纯 TileMapLayer（per-cell 效果用 modulate/shader）
- **Description**: 全部用 TileMapLayer，CF-7 脉冲高亮等改用 tile modulate 或 shader 实现。
- **Pros**: 性能最优，draw call 最少，架构最简。
- **Cons**: TileMapLayer 无法对单个 tile 独立做呼吸 alpha 动画（modulate 作用于整层或需自定义 shader + per-tile 数据，复杂度高）；CF-7 单格脉冲高亮实现变难，需较大重改 #6。
- **Rejection Reason**: CF-7 是 P3「三秒上手」可发现性的 BLOCKING 线索，per-cell 高亮不能牺牲；少量覆盖节点是更低风险的解法。

### Alternative 3: 朴素销毁+重建（现状基线）
- **Description**: 每次切楼层 queue_free 256 + instantiate 256。
- **Pros**: 实现直观。
- **Cons**: 2.5–13ms/帧，逼近帧预算，低端机掉帧（TR-grid-007 问题本身）。
- **Rejection Reason**: 即问题来源，不可接受。

## Consequences

### Positive
- 楼层切换成本从 2.5–13ms 降至预期 < 2ms（TileMapLayer C++ 批量 set_cell）。
- 网格 draw call 由单 atlas TileSet 合并至近 1 次，远在 < 50 预算内。
- per-cell 动态效果（CF-7 高亮、门/楼梯动画）保留，由少量按需覆盖节点承载。
- 逻辑（BFS/`_passable`/状态机）留在 GridMovement，headless 可测不受渲染方案影响。
- 常驻内存极小（TileMapLayer + 小覆盖池 + 单 atlas，< 1MB 增量）。

### Negative
- 引入 TileSet 资产配置（atlas 打包、tile 定义），比纯代码方案多一层编辑器资产管理。
- per-cell 动态效果与静态渲染分属两套机制（TileMapLayer vs 覆盖节点），实现者须理解何时用哪个。
- **#6 GDD M7/Overview/Visual 的「256 CellNode 子节点」表述须同步修订为 TileMapLayer + 覆盖节点**（本 ADR 写入时同步）。

### Risks
- **风险（BLOCKING，专家 e-2）**：ETC2/ASTC 压缩 atlas 的 region 未对齐 4px 块边界 → 采样边缘 bleeding（像素艺术下明显）。
  - **缓解**：atlas 每 tile region 对齐 4×4 块 + 2px padding + `filter: off`；纳入资产流程检查与 ADR-0007 spike 验收。
- **风险（BLOCKING，专家 e-1）**：WASM PCK 下 preload 全部 cell-type 纹理的内存占用。
  - **缓解**：MVP 仅十余种 tile，单 atlas 体积极小；纳入 ADR-0007 spike 内存确认。
- **风险（CONCERN，专家 d）**：实现者在 set_cell 循环内误调 FloorDB.get_floor() → 256 次 duplicate_deep GC 压力。
  - **缓解**：决策细则 5 明确「每次切换仅一次 get_floor」；code review grep `get_floor` 调用点数；集成测试断言切换期间 get_floor 调用计数 = 1。
- **风险（CONCERN，专家 a/c）**：误用 `visible` 切换或 cell 级 `_process` 重新引入通知/帧开销。
  - **缓解**：决策细则 1/6 明确 EMPTY/WALL 用 atlas tile、禁用 cell 级 `_process`。
- **风险（ADVISORY，专家 e-3）**：Douyin 适配器 ~4.5 基线，TileMapLayer 在 4.6.3 WASM 行为未验证。
  - **缓解**：本方案不依赖 4.6 特有 API（TileMapLayer 4.3+、region_rect 4.0）；整体 pipeline 由 ADR-0007 spike 兜底。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| grid-movement.md (#6) | TR-grid-007 / M7 性能注：256 CellNode 单帧重建 2.5–13ms 逼近帧预算 | TileMapLayer 批量 set_cell（C++，近 0 draw call）将切换降至 < 2ms；M7 表述同步改为 TileMapLayer + 覆盖节点 |
| grid-movement.md (#6) | M6 / F-REACH：`_passable` 缓存 + floor_id 校验 | `_passable` 保留在 GridMovement 层（TileMapLayer 下更自然，符合 ADR-0003 无业务状态于渲染面） |
| grid-movement.md (#6) | CF-7（协调）：PREVIEWING 目标格脉冲高亮 | 由按需池化覆盖 Node2D 承载，TileMapLayer 静态底之上叠加 |
| grid-movement.md (#6) | TR-cross-005 性能预算：< 50 draw calls | 单 atlas TileSet 合并网格 draw call 至近 1 次 |

## Performance Implications
- **CPU**: 楼层切换 256 次 `set_cell`（C++ 批量）预期 < 2ms（vs 原 2.5–13ms）；`_passable` 重建 256 次布尔写入 < 0.1ms。
- **Memory**: TileMapLayer + 单 atlas + 小覆盖池常驻 < 1MB；每次切换 1 个 FloorEntry 副本（256 CellEntry ≈ 50KB）切换后 GC 回收。
- **Load Time**: atlas 随 PCK 启动加载一次；MVP 体积极小（< 100KB）。
- **Draw Calls**: 网格部分近 1 次（共享 atlas）；覆盖节点同屏典型 ≤ 数个；远在 < 50 预算内。
- **Network**: N/A（单机 res:// 资源）。

## Migration Plan
无现有代码。本 ADR 在 #6 首行渲染代码前确立渲染/重建方案。#6 GDD M7/Overview/Visual 的「256 CellNode」表述随本 ADR 写入同步修订。TileSet atlas 资产须在首个楼层渲染故事前由 art/technical-artist 产出（对齐 4px 块 + padding + filter:off）。

## Validation Criteria
1. 楼层切换 GDUnit4/perf 测量：3 层间切换单帧 < 2ms（低端代表设备 / Douyin IDE 基线）。
2. `grep -n "get_floor" src/grid_movement/` 确认楼层切换路径每次仅调用一次（非 per-cell）。
3. 网格渲染 draw call 实测 < 5（Godot 监视器 / Compatibility 后端）。
4. CF-7 脉冲高亮由覆盖节点实现，可在单格上独立呼吸 alpha（不影响其余格）。
5. `grep -rnE "_process" src/grid_movement/` 确认无 cell 级 per-frame 处理（覆盖节点动画用 Tween/AnimationPlayer）。
6. 导出 spike（QQ-01，ADR-0007）：WASM 下 preload atlas 内存合规 + ETC2/ASTC region 采样无 bleeding + TileMapLayer set_cell 行为一致。

## Related Decisions
- ADR-0001（数据类型）— FloorDB.get_floor 返回 duplicate_deep 副本；本 ADR 的切换契约依赖其只读语义。
- ADR-0003（系统宿主）— GridMovement = Scene Node；本 ADR 在该宿主内定义渲染/重建方案，`_passable` 保留逻辑层符合 game_logic_in_scene_node 禁用模式。
- ADR-0007（WASM 导出）— 本 ADR 的 atlas 压缩/preload/TileMapLayer WASM 行为验证并入 spike QQ-01。
- design/gdd/grid-movement.md — TR-grid-007 / M7 性能注（问题来源）；CF-7 协调项。
- docs/engine-reference/godot/deprecated-apis.md — TileMap → TileMapLayer（4.3，本 ADR 用 TileMapLayer）。
