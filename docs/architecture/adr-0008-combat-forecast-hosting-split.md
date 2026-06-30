# ADR-0008: 战斗预演宿主拆分 — CombatForecastService（Autoload）+ CombatForecastOverlay（Scene Node）

## Status
Accepted（部分 — 2026-06-29）

> **部分 Accepted**：宿主拆分结构决策（Service Autoload + Overlay Scene Node、`@export` 访问、show_overlay 3 参、mouse_filter）已 Accepted 并生效，解锁 #10 结构实现与 ADR-0003/#6 接口名同步。**决策 4（Viewport/坐标系：canvas_items + follow_viewport_enabled=true，F-RECT 方案 a）仍为 spike-pending**：其触控命中坐标前提依赖导出 spike `QQ-ADR8-01`（Douyin/WASM 物理≠逻辑分辨率下 `get_global_rect()` 与 `InputEventScreenTouch.position` 对齐）实测确认。QQ-ADR8-01 未过前，#6 不得把该坐标命中当作已验证；若 spike 否决，决策 4 须修订（不影响已 Accepted 的结构部分）。

## Date
2026-06-29（Accept 结构部分；决策 4 坐标前提 spike-pending）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3 — 正文「4.6 Dual-focus」不再适用，须复审；4.5 Recursive Control 仍适用） |
| **Domain** | UI（Control / CanvasLayer / 触控坐标）+ Core（Autoload / Node 架构） |
| **Knowledge Risk** | HIGH — UI 域为 post-LLM-cutoff 高风险：4.6 Dual-focus、4.5 Recursive Control；CanvasLayer canvas transform 行为在 `canvas_items` stretch + 物理≠逻辑分辨率下须实测 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/modules/ui.md`、`docs/engine-reference/godot/VERSION.md`；ADR-0003 |
| **Post-Cutoff APIs Used** | `CanvasLayer.follow_viewport_enabled`（4.0+ 稳定）；4.6 Dual-focus / 4.5 Recursive Control 行为对触控 `_input()` 传播的影响（未实测，列入 Verification Required） |
| **Verification Required** | QQ-ADR8-01..06（见 Validation Criteria 实测清单）——核心是 `follow_viewport_enabled=true` 下 `get_global_rect()` 与 `InputEventScreenTouch.position` 同坐标系、同帧 `get_global_rect()` 实机正确性、Dual-focus/Recursive Control 对触控传播无影响 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003（系统宿主决策 — 本 ADR amend 其 #10 分类与 Autoload 列表 [9] 条目）；ADR-0001（数据类型）；ADR-0002（Autoload 启动顺序 / is_initialized 模式） |
| **Enables** | #10 战斗预演系统实现 epic（宿主与访问方式确定后可实现）；解锁 combat-forecast.md OQ#5 |
| **Blocks** | #10 实现 epic 不可在本 ADR Accepted 前开始；#6 GridMovement 对 Overlay 的调用名同步亦待本 ADR Accepted |
| **Ordering Note** | 本 ADR amend ADR-0003（非取代），二者并存；ADR-0003 仍为宿主调节面权威，本 ADR 仅就 #10 一个系统的拆分做细化裁决。须先于 #10 实现，可与 #6 实现并行（#6 调用名同步随本 ADR Accepted 落地） |

## Context

### Problem Statement
ADR-0003（2026-06-25）将 #10 CombatForecast 分类为 **Autoload**，理由是「纯无状态计算（包装 CombatSystem）」。但 combat-forecast.md 历经三轮 design-review 后已演进：本系统不再是纯计算代理，而是**持有覆盖层 UI Control 子树、向屏幕渲染预演卡片、缓存两个屏幕空间 Rect2 供 #6 做触控命中判断**。这命中 ADR-0003 的 Scene Node 判定条件（rule 1：向屏幕渲染内容），且与 ADR-0003 禁止模式 `autoload_holds_scene_node_reference`（Autoload 不持有 Scene Node 引用）直接冲突——一个持有并管理 Control 子树的对象若注册为 Autoload，其 UI 子树的生命周期、坐标系与 ADR-0003 的 Autoload 模型相矛盾。

第三轮 design-review（根因 D / OQ#5）裁定方向为「拆分」，但 Overlay 挂载点、#6 对 4 个 UI 接口的访问方式、整体 Viewport/缩放架构（决定 F-RECT 触控命中方案）须由本 ADR 正式裁定。

### Constraints
- **ADR-0003 调节面**：渲染 UI + 触控相关 Rect2 → Scene Node；无状态服务 + 多消费者 → Autoload。本系统同时具备两种性质，须拆分而非二选一。
- **ADR-0003 禁止模式**：`autoload_holds_scene_node_reference` 仅约束 **Autoload**；Scene Node 之间引用不受此约束。
- **抖音单场景**：ADR-0003 line 37——无场景切换，game.tscn 生命周期 = 整局游戏；Scene Node 间引用无失效风险。
- **触控坐标一致性**：F-RECT 要求 `get_overlay_screen_rect()` / `get_x_button_screen_rect()` 与 `InputEventScreenTouch.position` 同坐标系（#6 `_input()` Rect2 命中判断前提）。
- **#5 forecast_combat 权威**：预演数学唯一来源是 #5 `CombatSystem.forecast_combat()`（ADR-0006）；本系统不重新实现战斗数学。

### Requirements
- 拆分后两个对象各自的宿主类型须符合 ADR-0003 调节面，且消除 Autoload-持有-UI 的冲突。
- #6 GridMovement 须能调用 5 个接口（1 个计算 + 4 个 UI），且不违反任何 ADR-0003 禁止模式。
- 确定整体 Viewport/缩放架构，使 F-RECT 坐标系约束在设计层成立（实测在 spike 兜底）。

## Decision

将 CombatForecast 拆为两个对象：

### 1. CombatForecastService（Autoload，无状态代理）
- 仅提供 `forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp) -> CombatForecast`，直接转调 #5 `CombatSystem.forecast_combat()`，零状态、零 UI。
- 符合 ADR-0003 Autoload 判定（无状态服务，被 #6 + #13 + 测试 ≥3 消费者调用，无场景存在需求）。
- 在 ADR-0003 Autoload 列表中**替换原 `[9] CombatForecast` 条目为 `[9] CombatForecastService`**。`_ready()` 守卫：`assert(CombatSystem != null)`（若 CombatSystem 提供 `is_initialized` 则追加；否则仅 null 检查，与 ADR-0003 守卫模式保持透明）。

### 2. CombatForecastOverlay（Scene Node，持有 UI）
- 结构：**game.tscn 下的 `CanvasLayer > Control`**（与 HUD 同构），与 GridMovement 网格同一 root viewport / canvas 空间。
- 持有覆盖层 Control 子树（手动定位 Label：`lose_indicator` / `hint_label` / `damage_label` 等，CF-4 禁用 Container）+ × 按钮，缓存两个屏幕空间 Rect2。
- 提供 4 个 UI 接口：`show_overlay(forecast, col, row)`（3 参，LOSE 不再自算 K——见 combat-forecast.md 根因 A）、`hide_overlay()`、`get_overlay_screen_rect() -> Rect2`、`get_x_button_screen_rect() -> Rect2`。
- 符合 ADR-0003 Scene Node 判定（渲染 UI + 触控 Rect2 命中支持）；**不出现在 Autoload 列表**。

### 3. #6 访问方式
- `forecast_combat()` → 通过 **`CombatForecastService` 全局名**调用（Autoload 模式，#6 现有调用方式不变）。
- 4 个 UI 接口 → GridMovement 通过 **`@export var forecast_overlay: CombatForecastOverlay`** 在 game.tscn 中连线引用后调用。
- **合规性**：ADR-0003 的引用禁令 `autoload_holds_scene_node_reference` **仅约束 Autoload 层**。GridMovement 是 Scene Node，Scene Node 之间通过 `@export` 连线引用是 Godot 惯用模式，不受该禁令约束。combat-forecast.md 中曾误引「ADR-0003『Scene Node 不存储实例引用』」——该禁令在 ADR-0003 原文不存在，已随本 ADR 同步修正 GDD 措辞。
- `GridMovement._ready()` 须加 `assert(forecast_overlay != null, "forecast_overlay export not wired in game.tscn")`（与 ADR-0003 assert 守卫模式一致）。

### 4. Viewport / 缩放架构
- 项目级 **`window/stretch/mode = canvas_items`**，gameplay **不使用 SubViewport**。
- Overlay 与网格同 root viewport；`InputEventScreenTouch.position` 经 viewport `canvas_transform` 已映射到逻辑 canvas 空间，与 Control `get_global_rect()` 同坐标系（F-RECT 方案 a）。
- **BLOCKING 实现约束（B-1，godot-specialist 验证）**：Overlay 的 CanvasLayer 须**显式设置 `follow_viewport_enabled = true`**（默认 `false`）、`offset = Vector2.ZERO`、`scale = Vector2.ONE`。否则在物理分辨率 ≠ 逻辑分辨率（抖音低端机典型）时，CanvasLayer 自身独立 canvas transform 会使 `get_global_rect()` 与已映射的触点坐标系统性偏移。此项纸面不可代替，须实机验证（QQ-ADR8-01）。

### 5. mouse_filter
- × 按钮 `MOUSE_FILTER_IGNORE`，覆盖层根 Control `MOUSE_FILTER_STOP`（仅防 `_unhandled_input()`，对 `_input()` 无拦截）；触控拦截由 #6 `_input()` 的 Rect2 命中判断负责（combat-forecast.md CF-5）。4.5 Recursive Control / 4.6 Dual-focus 对此无破坏性影响（消费语义非禁用语义、本项目无 gamepad 且不依赖 Control focus），但列入实测清单（QQ-ADR8-04/05）。

### Architecture Diagram

```
Autoload 层:
  CombatSystem            ← #5（ADR-0003 [5]）
  CombatForecastService   ← #10 计算代理（ADR-0003 [9] 改名）；转调 CombatSystem.forecast_combat

Scene 层（game.tscn）:
  GridMovement（Node2D）            ← #6
    @export forecast_overlay ─────┐  （编辑器连线，单场景持久，无失效）
  CombatForecastOverlay            │  ← #10 UI（CanvasLayer > Control）
    （follow_viewport_enabled=true）◀┘
    ├── Label: lose_indicator / hint_label / damage_label / 回合行 / 剩血行（手动定位）
    └── × Button（MOUSE_FILTER_IGNORE）
  HUD（CanvasLayer > Control）       ← #12（同构参照）

通信:
  GridMovement ──全局名 call──▶ CombatForecastService.forecast_combat() → 返回值
  GridMovement ──@export call──▶ CombatForecastOverlay.show_overlay()/hide_overlay()/get_*_screen_rect()
```

### Key Interfaces

```gdscript
# ── CombatForecastService（Autoload）──
class_name CombatForecastService extends Node:
    func _ready() -> void:
        assert(CombatSystem != null, "STARTUP ORDER: CombatSystem must precede CombatForecastService")
    func forecast_combat(monster_hp: int, monster_atk: int, monster_def: int,
                         player_atk: int, player_def: int, player_current_hp: int) -> CombatForecast:
        # 直接用 Autoload 全局名调用，不加冗余 `as` 转型（godot-specialist E-1）。
        # 实现约束：CombatForecastService 与 CombatSystem 的 Autoload 注册名必须与各自
        # class_name 完全一致——否则 `CombatSystem as CombatSystem` 式转型会静默返回 null。
        return CombatSystem.forecast_combat(
            monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp)

# ── CombatForecastOverlay（Scene Node：CanvasLayer > Control）──
class_name CombatForecastOverlay extends CanvasLayer:
    # 编辑器设：follow_viewport_enabled = true, offset = ZERO, scale = ONE
    func show_overlay(forecast: CombatForecast, col: int, row: int) -> void
    func hide_overlay() -> void
    func get_overlay_screen_rect() -> Rect2
    func get_x_button_screen_rect() -> Rect2

# ── GridMovement（#6，Scene Node）──
@export var forecast_overlay: CombatForecastOverlay
func _ready() -> void:
    assert(forecast_overlay != null, "forecast_overlay export not wired in game.tscn")
```

## Alternatives Considered

### Alternative 1: 维持单一 CombatForecast Autoload 持有 UI（现状）
- **Description**: 不拆分，CombatForecast 作为 Autoload 同时持有覆盖层 Control 子树。
- **Pros**: #6 全部 5 个接口走单一全局名，调用最简单；无需 @export 连线。
- **Cons**: Autoload 持有并管理 UI Control 子树与 ADR-0003 禁止模式 `autoload_holds_scene_node_reference` 冲突；Autoload 默认挂在 root 下，脱离游戏场景 canvas 空间，`get_global_rect()` 与触控坐标对齐困难；UI 无法用 Godot 编辑器场景工具检视。
- **Rejection Reason**: 这正是触发本 ADR 的违规现状；ADR-0003 调节面明确「渲染 UI → Scene Node」。

### Alternative 2: 整体改为单一 Scene Node（forecast_combat 也移出 Autoload）
- **Description**: CombatForecast 整体为 Scene Node，forecast_combat 与 UI 都在其上。
- **Pros**: 单对象、改动集中。
- **Cons**: `forecast_combat` 是纯无状态服务，被 #6/#13/测试调用——置于 Scene Node 后失去 Autoload 全局可达性，#6 须改为引用调用、#13 亦然，且 headless 测试须实例化场景节点；与 ADR-0003「无状态多消费者服务 → Autoload」判定相悖。
- **Rejection Reason**: 拆分让计算服务保持 Autoload（符合调节面、保留 #6 现有全局调用、headless 可测），仅 UI 部分下沉 Scene Node，是更贴合 ADR-0003 的解法。

## Consequences

### Positive
- 消除 Autoload-持有-UI 与 ADR-0003 禁止模式的冲突；两对象各自符合调节面。
- `forecast_combat` 保持 Autoload 全局可达 → #6 该调用方式不变、#13 不变、headless 可测。
- Overlay 作为 game.tscn Scene Node，可用 Godot 编辑器检视/连线，坐标系与网格一致（F-RECT 方案 a）。
- `show_overlay` 退回 3 参与 #6 现有调用一致（combat-forecast.md 根因 B 一并消解）。

### Negative
- #6 须区分两种调用：`forecast_combat` 走全局名、4 个 UI 接口走 @export 引用——比单一全局名多一层认知。
- ADR-0003 须 amend（[9] 条目改名 + #10 分类细化）；二文档须保持一致。
- @export 连线是编辑器级操作，无代码级保证；game.tscn 重构时须复检连线（migration 注意事项）。

### Risks
- **风险（B-1，HIGH）**：CanvasLayer `follow_viewport_enabled` 漏设为 true → 物理≠逻辑分辨率下触控命中系统性偏移。
  - **缓解**：列为 BLOCKING 实现约束 + Validation Criteria grep 检查 + QQ-ADR8-01 实机实测。
- **风险（B-2）**：`show_overlay()` 内手动设 `size` 后误用 `reset_size()` 覆盖手动 size，或漏强制 transform 同步致同帧 `get_global_rect()` 返回旧值。
  - **缓解**：实现约束明确区分——固定 size 时直接赋值后访问 `get_global_rect()`（Godot 4 访问即同步）即可；内容自适应 size 时先 `reset_size()` 再读。CF-4 (2a) 已记，QQ-ADR8-03 实机兜底。
- **风险（B-3，E-4 godot-specialist）**：F-RECT 坐标系对齐还须排除 Overlay 内参与命中的 Control 的非零 `pivot_offset`——B-1 仅约束 CanvasLayer 的 follow_viewport/offset/scale，B-2 仅覆盖 `reset_size`。若某 Label 为居中动画设了非零 `pivot_offset`，`get_global_rect()` 原点仍可能偏移。
  - **缓解**：实现约束追加——产出两个命中 Rect2 的来源 Control 的 `pivot_offset` 须为零（或算 Rect 时显式补偿）；纳入 QQ-ADR8-01 实测核对项。
- **风险（post-cutoff）**：4.6 Dual-focus / 4.5 Recursive Control 改变触控事件经 `MOUSE_FILTER_STOP` Control 的传播规则。
  - **缓解**：QQ-ADR8-04/05 实测确认触控仍到达 #6 `_input()`；预期无影响（消费非禁用、不依赖 focus）。
- **风险（Douyin 适配器）**：适配器基线 ~4.5，4.6.3 兼容性未验证；`follow_viewport_enabled` / stretch 行为在 WASM 下可能不同。
  - **缓解**：QQ-ADR8-06 并入 QQ-01 导出 spike。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-forecast.md | OQ#5：宿主拆分正式落地 + Overlay 挂载 + #6 访问方式 + Viewport 架构 | 本 ADR 全部裁定：Service(Autoload)+Overlay(SceneNode, CanvasLayer>Control@game.tscn)、#6 @export 引用、canvas_items 无 SubViewport + follow_viewport_enabled=true |
| combat-forecast.md | CF-4 / F-RECT：同帧 Rect2 缓存与坐标系约束 | 方案 a 成立前提（canvas_items + follow_viewport_enabled=true）裁定；B-1/B-2 实现约束 + 实测清单 |
| combat-forecast.md | 根因 A/B：LOSE 不自算 K、show_overlay 退 3 参 | Key Interfaces 锁定 `show_overlay(forecast, col, row)` 3 参；forecast_combat 6 参（#5 签名）不变 |
| grid-movement.md (#6) | 对 #10 的 5 接口调用 | forecast_combat 走 Service 全局名（#6 不变）；4 UI 接口改 @export 引用调用（#6 调用名待本 ADR Accepted 后同步） |
| systems-index.md | #10 宿主分类 | amend ADR-0003：#10 = Autoload(Service) + Scene Node(Overlay) 拆分 |

## Performance Implications
- **CPU**: 拆分不增加运行期开销；forecast_combat 仍 O(1) 全局调用；Overlay 渲染为单 CanvasLayer + 少量手动定位 Label，draw call 增量 < 5（符合 < 50 预算）。
- **Memory**: CombatForecastService 无状态、近零内存；Overlay 为常驻 Scene Node（隐藏时不渲染），内存开销 < 0.5MB。
- **Load Time**: Service 加入 Autoload 列表（替换原条目，数量不变）；Overlay 随 game.tscn 加载，无额外启动开销。
- **Network**: N/A。

## Migration Plan
无现有代码（实现前架构裁决）。落地动作：
1. ADR-0003 amend：Autoload 列表 `[9] CombatForecast` → `[9] CombatForecastService`；#10 分类行改为「Autoload(Service) + Scene Node(Overlay)，见 ADR-0008」。
2. #6 grid-movement.md：4 个 UI 接口调用从全局名 `CombatForecast.*` 改为 `forecast_overlay.*`（@export），`forecast_combat` 保持 `CombatForecastService.forecast_combat`；Interactions 表与 `_input()` 注释同步。随本 ADR Accepted 后处理（#6 已 Approved，属接口名同步）。
3. combat-forecast.md：误引「ADR-0003『Scene Node 不存储实例引用』」措辞已修正（随本 ADR 写入同步）。
4. game.tscn 重构时复检 `GridMovement.forecast_overlay` @export 连线。

## Validation Criteria
1. Project Settings > Autoloads：`CombatForecastService` 在列、`CombatForecastOverlay` **不在列**。
2. game.tscn：`CombatForecastOverlay` 为 `CanvasLayer > Control`，`follow_viewport_enabled = true`（`grep -r 'follow_viewport' ` 可验证）、`offset = (0,0)`、`scale = (1,1)`。
3. `GridMovement.forecast_overlay` @export 已连线；`_ready()` 含 null assert。
4. `show_overlay` 签名为 3 参；`grep` 确认无 4 参残留。
5. **实测清单（Verification Required）**：

| ID | 项目 | 优先级 |
|----|------|--------|
| QQ-ADR8-01 | 目标设备实测 `follow_viewport_enabled=true` 下 `get_global_rect()` 与 `InputEventScreenTouch.position` 命中无系统性偏移 | BLOCKING |
| QQ-ADR8-02 | game.tscn 中 `GridMovement.forecast_overlay` @export 已连线 + `_ready()` null assert | BLOCKING |
| QQ-ADR8-03 | 手动定位（无 Container）+ 手动 size 后同帧 `get_global_rect()` 返回新值（headless AC-CF-1 + 实机/导出环境实测） | BLOCKING |
| QQ-ADR8-04 | 4.6.3 中 `MOUSE_FILTER_STOP` 根 + `MOUSE_FILTER_IGNORE` 子不触发 4.5 Recursive Control 意外递归禁用 | ADVISORY |
| QQ-ADR8-05 | 4.6.3 Dual-focus 下 `InputEventScreenTouch` 经 `MOUSE_FILTER_STOP` Control 仍到达 `_input()` | ADVISORY |
| QQ-ADR8-06 | Douyin 适配器 WASM 下 `follow_viewport_enabled` / canvas_items stretch 行为与桌面一致（并入 QQ-01） | ADVISORY |

## Related Decisions
- ADR-0003（系统宿主决策）— 本 ADR amend 其 #10 分类与 Autoload 列表 [9] 条目
- ADR-0002（Autoload 启动顺序）— CombatForecastService 沿用 assert 守卫模式
- ADR-0006（确定性战斗完整接口）— forecast_combat 权威来源，本系统不重复战斗数学
- ADR-0007（WASM 抖音导出管线）— QQ-01 spike 覆盖本 ADR 的 Viewport/适配器实测项
- design/gdd/combat-forecast.md（#10，第三轮 design-review 根因 D / OQ#5）
- design/gdd/grid-movement.md（#6，UI 接口调用名待同步）
