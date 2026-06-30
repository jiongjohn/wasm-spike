# ADR-0003: 系统宿主决策 — Autoload vs Scene Node

## Status
Accepted

## Date
2026-06-25（Amended 2026-06-29：ADR-0008 将 #10 CombatForecast 拆为 Service(Autoload)+Overlay(Scene Node)——结构部分已 Accepted；并修正通信图 `preview()` → `forecast_combat`，C-1）

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core（Autoload / Node Architecture） |
| **Knowledge Risk** | HIGH — post-LLM-cutoff；但 Autoload 全局访问机制和 Node _ready() 生命周期自 4.0 起稳定，4.4/4.5/4.6 breaking-changes.md 中无相关变更 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | 验证 Autoload → Scene Node 通信模式（Autoload 发信号，场景节点 _ready() 连接）在 Douyin 适配器 WASM 中无时序异常（导出 spike QQ-01） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（class_name + RefCounted 数据类型），ADR-0002（Foundation Autoload 列表顺序及 is_initialized 标志模式） |
| **Enables** | 所有 13 个 MVP 系统实现 epic（#1–#13）——每个系统的宿主类型已由本 ADR 确定，可直接开始实现 |
| **Blocks** | 所有 MVP 系统实现（宿主模式未定则无法创建正确类型的系统文件） |
| **Ordering Note** | ADR-0001 和 ADR-0002 须先于本 ADR 被 Accepted；本 ADR 须先于任何 Core/Feature/Presentation 系统实现 |

## Context

### Problem Statement
Foundation 层（EntityDB/FloorDB/TuningConfig）的宿主类型已由 ADR-0002 确立为 Autoload。但 13 个 MVP 系统中的 Core/Feature/Presentation 层（#4–#13）无架构指导：combat-system.md 明确将「战斗结算用 Autoload 还是节点」标记为架构 ADR 的决策权，player-stats-growth.md 未预设技术方案。若无统一调节面，各系统实现者将独立做出不一致的宿主选择，导致：状态散落于 Scene Nodes（难以跨楼层持久化）、Autoload 持有场景引用（场景切换时引用失效）、测试依赖场景树（无法 headless 运行核心逻辑）。

### Constraints
- **持久化需求**：玩家 HP/ATK/DEF/金币/钥匙须跨楼层切换保留；该状态必须与具体场景解耦
- **测试可注入**：核心游戏逻辑（战斗结算、道具效果）必须可在 GDUnit4 headless 模式下测试，不依赖场景树
- **Douyin 小游戏**：无多场景切换（同一个 game.tscn 换楼层内容）；但 GameState 仍需作为唯一的游戏相位权威
- **ADR-0002 约束**：Core/Feature Autoload 须遵循 is_initialized 标志模式；其 _ready() 若访问 Foundation Autoload 须加 assert 守卫

### Requirements
- 提供可操作的分类调节面：给定任意系统，可确定性地判断它应为 Autoload 还是 Scene Node
- 对所有 13 个 MVP 系统给出具体分类，消除歧义
- 定义 Autoload ↔ Scene Node 的合法通信模式，避免场景引用耦合
- 定义 Core/Feature Autoload 在 ADR-0002 列表中的位置（Foundation 之后，GameBootstrap 之前）

## Decision

### 分类调节面（Decision Rubric）

**系统应为 Autoload，当满足以下任一条件：**
1. 持有须跨楼层（或任意场景切换）存活的游戏状态
2. 提供无状态逻辑服务，且被 3 个或更多其他系统调用
3. 无任何必要的场景树存在需求（无渲染、无触控输入处理、无按帧视觉更新）

**系统应为 Scene Node，当满足以下任一条件：**
1. 向屏幕渲染内容（精灵、UI 控件、VFX）
2. 直接作为其他可见节点的父节点并管理其生命周期
3. 需要按帧视觉更新（`_process`/`_physics_process` 用于动画或效果）
4. 直接处理玩家触控输入（tap/swipe）

**破平规则**（同时满足双方条件时）：若系统持有须跨楼层存活的游戏状态，则强制为 Autoload，其视觉反馈通过信号委托给 Scene Node。

### 13 个 MVP 系统具体分类

| # | 系统 | 宿主 | 判定理由 |
|---|------|------|----------|
| 1 | 游戏实体数据库 (EntityDB) | **Autoload** | ADR-0002 已定；Foundation 数据层 |
| 2 | 楼层关卡数据系统 (FloorDB) | **Autoload** | ADR-0002 已定；Foundation 数据层 |
| 3 | 游戏调参配置 (TuningConfig) | **Autoload** | ADR-0002 已定；Foundation 数据层 |
| 4 | 玩家属性与成长系统 (PlayerStats) | **Autoload** | 持有跨楼层状态（HP/ATK/DEF/Gold/Keys）；8 个系统依赖其状态 |
| 5 | 确定性回合战斗系统 (CombatSystem) | **Autoload** | 无状态确定性解算器；被 #8/#10/#13 调用（3 个消费者）；无场景存在需求 |
| 6 | 网格移动与交互系统 (GridMovement) | **Scene Node** | 渲染 16×16 网格；处理格子 tap 输入；管理格子视觉节点为子节点 |
| 7 | 钥匙与门系统 (KeyDoor) | **Autoload** | 无状态规则层（读 EntityDB 颜色规则 + 读/写 PlayerStats 钥匙数）；通过信号通知 GridMovement 更新格子；无场景存在需求 |
| 8 | 掉落奖励系统 (DropReward) | **Autoload** | 无状态确定性掉落解算（读 EntityDB + 写 PlayerStats）；无场景存在需求 |
| 9 | 楼层进程系统 (FloorProgress) | **Autoload** | 持有楼层进度状态（当前楼层、已通关楼层集合）；协调楼层切换（通知 GridMovement 换楼层内容） |
| 10 | 战斗预演系统 (CombatForecast) | **Autoload + Scene Node（拆分，见 ADR-0008）** | 拆为 CombatForecastService（Autoload 纯代理，被 #6/#13 调用）+ CombatForecastOverlay（Scene Node UI，CanvasLayer>Control@game.tscn，#6 经 @export 引用）|
| 11 | 数值反馈视觉系统 (NumberFeedback) | **Scene Node** | 渲染飘字/闪光 VFX；是场景的视觉子系统；无业务状态 |
| 12 | HUD 系统 | **Scene Node** | UI Control 覆盖层；渲染属性数值/钥匙图标；直接显示 PlayerStats 快照 |
| 13 | 游戏状态管理 (GameState) | **Autoload** | 持有游戏相位状态（Playing/GameOver/Win/Title）；是场景切换的权威协调者 |

### 扩展 Autoload 列表顺序

在 ADR-0002 Foundation 顺序基础上追加 Core/Feature Autoloads（均在 GameBootstrap 之前）：

```
Project Settings > Autoloads（完整 MVP 列表）:
  [1]  TuningConfig     ← Foundation（ADR-0002）
  [2]  EntityDB         ← Foundation（ADR-0002）
  [3]  FloorDB          ← Foundation（ADR-0002）
  [4]  PlayerStats      ← Core；assert(TuningConfig.is_initialized)
  [5]  CombatSystem     ← Core；无状态，_ready() 无 Foundation 依赖（可在 [4] 前后任意）
  [6]  KeyDoor          ← Core；无状态，_ready() 无 Foundation 依赖
  [7]  DropReward       ← Feature；无状态，_ready() 无 Foundation 依赖
  [8]  FloorProgress    ← Feature；assert(FloorDB.is_initialized + PlayerStats.is_initialized)
  [9]  CombatForecastService ← Feature（ADR-0008 改名）；纯代理；assert(CombatSystem != null)。UI 部分 CombatForecastOverlay 为 game.tscn Scene Node，不在 Autoload 列表
  [10] GameState        ← Gameplay；assert(PlayerStats.is_initialized)
  [11] GameBootstrap    ← 启动协调器（ADR-0002）— 始终最后
```

> **顺序原则**：持有状态且被后续 Autoload 依赖的系统排前；无状态系统可在同层内任意排序。所有 Core/Feature Autoload 的 assert 守卫（如有）须遵循 ADR-0002 模式（`assert(dep.is_initialized, "...")`）。

### Autoload ↔ Scene Node 通信模式

**Scene Node → Autoload（调用）**：
Scene Node 直接通过全局名调用 Autoload 方法（类型化 `as` 转型，同 ADR-0002 模式）。这是主数据流向：玩家交互事件 → 规则层处理。

```gdscript
# GridMovement（Scene Node）接触一个战斗格后调用 GameState：
func _on_cell_activated(cell: CellEntry, pos: Vector2i) -> void:
    var game_state := GameState as GameState
    game_state.on_combat_cell_entered(cell, pos)
```

**Autoload → Scene Node（信号）**：
Autoload 通过自身信号通知变化；Scene Node 在自身 `_ready()` 中连接。Autoload **不持有 Scene Node 引用**。

```gdscript
# PlayerStats（Autoload）发出属性变化信号：
signal stat_changed(stat_type: String, old_val: int, new_val: int)

# HUD（Scene Node）在 _ready() 中连接（Autoload 此时已初始化）：
func _ready() -> void:
    var player_stats := PlayerStats as PlayerStats
    player_stats.stat_changed.connect(_on_stat_changed)
```

**Autoload 通知 Scene Node 执行视觉动作（命令模式）**：
当 Autoload 需要 Scene Node 执行特定视觉操作（如「在(3,2)格播放飘字+100」），Autoload 发出携带数据的信号；Scene Node 响应时自行决定如何渲染。

```gdscript
# GameState（Autoload）发出战斗结果信号：
signal combat_resolved(result: CombatResult, pos: Vector2i)

# NumberFeedback（Scene Node）连接并执行 VFX：
func _ready() -> void:
    (GameState as GameState).combat_resolved.connect(_on_combat_resolved)

func _on_combat_resolved(result: CombatResult, pos: Vector2i) -> void:
    _spawn_damage_number(-result.total_damage_to_player, pos)
    _spawn_kill_flash(pos)
```

**禁止的通信模式**：
- Autoload 不得在 Autoload 类变量中持有具体 Scene Node 引用（`var grid: GridMovement`）——场景重载时引用失效
- 如需 Autoload 主动调用 Scene Node 方法，须通过 SceneTree 信号或 `get_tree().get_first_node_in_group()` 动态查找（不推荐；优先用信号反转依赖）

### Architecture Diagram

```
Autoload 层（持久化状态 + 规则层）:
  TuningConfig, EntityDB, FloorDB      ← Foundation 数据（ADR-0002）
  PlayerStats, GameState, FloorProgress ← 持久化状态持有者
  CombatSystem, KeyDoor, DropReward    ← 无状态规则服务
  CombatForecastService                 ← 无状态计算代理（ADR-0008；UI 部分 CombatForecastOverlay 在 Scene 层）

Scene 层（game.tscn，GameBootstrap 加载后）:
  GridMovement（Node2D）
    ├── CellNode × 256（16×16 格子视觉）
    └── PlayerMarker
  HUD（CanvasLayer > Control）
    ├── StatsPanel（HP/ATK/DEF/Gold）
    └── KeyPanel（Yellow/Blue key count）
  NumberFeedback（Node）
    └── FloatingLabel（动态生成）

通信：
  GridMovement ──call──▶ GameState.on_cell_activated()
  GameState    ──call──▶ CombatSystem.resolve_combat()
  GameState    ──call──▶ DropReward.resolve_drops()
  GameState    ──call──▶ PlayerStats.apply_item()
  GameState ──signal──▶ HUD._on_stat_changed()
  GameState ──signal──▶ NumberFeedback._on_combat_resolved()
  PlayerStats ──signal──▶ HUD._on_stat_changed()
  GridMovement ──call──▶ CombatForecastService.forecast_combat() → CombatForecast return value
```

### Key Interfaces

```gdscript
# ── Autoload 服务接口示例 ──

class_name CombatSystem extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready

    func _ready() -> void:
        _initialized = true
        database_ready.emit()

    # 无状态服务接口（EntityDB/PlayerStats 查询在 CombatSystem 内部执行）
    signal combat_won(monster_id: String)
    signal combat_lost(monster_id: String)
    signal round_resolved(round_index: int, dmg_to_monster: int,
                          monster_hp_remaining: int, dmg_to_player: int,
                          player_hp_remaining: int)

    func resolve_combat(monster_id: String) -> CombatResult: ...   # 同步，无 await
    func forecast_combat(monster_hp: int, monster_atk: int, monster_def: int,
                         player_atk: int, player_def: int,
                         player_current_hp: int) -> CombatForecast: ...  # 纯函数
    func generate_round_sequence(monster_hp: int, monster_atk: int, monster_def: int,
                                  player_atk: int, player_def: int,
                                  player_current_hp: int) -> Array: ...  # Array[RoundEvent]

class_name PlayerStats extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready
    signal stat_changed(stat_type: String, old_val: int, new_val: int)

    func _ready() -> void:
        var tuning := TuningConfig as TuningConfig
        assert(tuning != null and tuning.is_initialized,
            "STARTUP ORDER VIOLATION: TuningConfig must be before PlayerStats in Autoloads")
        _init_from_config(tuning)
        _initialized = true
        database_ready.emit()

    # 公共 API（只读属性 + 命令方法）
    var current_hp: int:
        get: return _current_hp
    func pickup_item(item_id: String) -> void: ...  # EntityDB 查找在 PlayerStats 内部执行
    func apply_damage(amount: int) -> void: ...      # amount >= 0（调用方契约）
    func reset_for_new_game() -> void: ...

class_name GameState extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready
    signal combat_resolved(result: CombatResult, grid_pos: Vector2i)
    signal game_phase_changed(new_phase: int)  # 使用 enum Phase

    func _ready() -> void:
        var player_stats := PlayerStats as PlayerStats
        assert(player_stats != null and player_stats.is_initialized,
            "STARTUP ORDER VIOLATION: PlayerStats must be before GameState in Autoloads")
        _initialized = true
        database_ready.emit()

    # 被 GridMovement 调用的命令入口
    func on_combat_cell_entered(cell: CellEntry, pos: Vector2i) -> void: ...
    func on_stair_cell_entered(cell: CellEntry, pos: Vector2i) -> void: ...
    func on_door_cell_entered(cell: CellEntry, pos: Vector2i) -> void: ...
```

## Alternatives Considered

### Alternative 1: 所有 Core/Feature 系统均为 Autoload
- **Description**: 无分类调节面；所有 #4–#13 均作为 Autoload，包括 GridMovement、HUD、NumberFeedback。
- **Pros**: 发现简单（所有系统都是全局可访问的）；跨系统调用无需传引用。
- **Cons**: GridMovement 作为 Autoload 须管理自身场景节点的实例化，违背 Godot 节点模型；HUD 作为 Autoload 须手动 add_child 到 scene tree，增加生命周期复杂度；Autoload 命名空间污染（11 个全局名）；视觉系统无法被编辑器直接检视。
- **Rejection Reason**: 视觉系统必须是 Scene Node 才能利用 Godot 编辑器的场景编辑、节点检视和信号连接工具；强制 Autoload 管理自身 Node 实例违反 Godot 节点架构。

### Alternative 2: 依赖注入模式（Core/Feature 均为 RefCounted，无 Autoload）
- **Description**: 所有 Core/Feature 系统为普通 class_name RefCounted 类；由 GameBootstrap 实例化后通过 DI 注入下游。
- **Pros**: 无全局状态；测试最友好（直接 new() 构造）；依赖关系显式可见。
- **Cons**: PlayerStats 跨楼层持久化须特殊保存/恢复机制（无 Autoload 自然持久化）；GDScript 无通用 DI 框架，须手写引用传递链（深度嵌套场景难以传递）；与 GDD 约定的「PlayerStats Autoload 全局访问」不符。
- **Rejection Reason**: Godot 的 Autoload 机制本质就是轻量依赖注入（全局单例）；对 13 个系统手写 DI 链的工程负担在 MVP 规模下不合比例；持久化状态需要跨场景存活，Autoload 是最自然的 Godot 解法。

## Consequences

### Positive
- 分类调节面可在 30 秒内判断任意新系统的宿主类型，无歧义
- 持久化状态（PlayerStats/FloorProgress/GameState）集中于 Autoload，楼层切换时自然存活
- 无状态规则层（CombatSystem/KeyDoor/DropReward）可在 GDUnit4 headless 模式下直接测试，不依赖场景树
- Scene Node（GridMovement/HUD/NumberFeedback）完全利用 Godot 编辑器的场景工具（可视化、节点检视、信号连接）
- 通信模式（Node→Autoload call / Autoload→Node signal）消除场景引用耦合，场景重载安全

### Negative
- Autoload 列表扩展至 11 个条目（Foundation 3 + Core/Feature 7 + GameBootstrap 1）；须在 Project Settings 中维护完整顺序
- Node → Autoload 的调用是单向的（Node 知道 Autoload 存在，Autoload 不知道具体 Node）；如 Autoload 需主动触发 Node 动作，须通过信号（略多一层间接）
- 场景重启（如重新开始一局）须手动 reset Autoload 状态（`PlayerStats.reset_for_new_game()`），不能简单 reload scene

### Risks
- **风险**：信号连接在 Scene Node 之前的 Autoload _ready() 中连接到尚未存在的 Scene Node——ADR-0002 已建立规则（Autoload 不在 _ready() 中连接 Scene Node 信号）。
  - **缓解**：由本 ADR 的通信模式约定（Scene Node 在自身 _ready() 中连接 Autoload 信号）保证时序正确。
- **风险**：场景重启（`reset_for_new_game()`）漏掉某个 Autoload 的状态重置，导致旧局数据污染新局。
  - **缓解**：GameState 是场景重启的单一入口；GameState.reset_for_new_game() 负责依次调用所有有状态 Autoload 的 reset（PlayerStats、FloorProgress、GameState 自身相位）；GDUnit4 测试须覆盖「重开局后全部有状态 Autoload 属性回到初始值」，不仅做手工验证。
- **风险（HIGH — Douyin 特有，继承自 ADR-0002）**：`GameState` 调用 `get_tree().change_scene_to_file()` 进行游戏相位切换（Title→Playing→GameOver/Win）时，若 Douyin 适配器使用 VFS 懒加载，目标 `.tscn` 文件可能不在内存中，导致调用静默返回 `ERR_CANT_OPEN`。`GameState` 是所有相位切换场景加载的单一拥有者，因此一旦确认需改方案，改动范围集中。
  - **缓解**：QQ-01 导出 spike 的 VFS 验证结论（ADR-0002 Risks 已规划）同时覆盖 `GameState` 的所有 `change_scene_to_file()` 调用；若确认懒加载，`GameState` 中的所有 `change_scene_to_file()` 调用须改为 `ResourceLoader.load_threaded_request()` + 加载完成回调方案（与 ADR-0002 中 GameBootstrap 的改法一致，单一模式变更，影响集中）。
- **风险**：GridMovement（Scene Node）直接访问 CombatForecast（Autoload），若 CombatForecast 发生 bug 则导致触控响应卡死。
  - **缓解**：CombatForecast.preview() 是纯计算，单测覆盖所有边界值；GridMovement 不应内联处理战斗状态——调用 CombatForecast 后立即返回数据，由 GameState 决策后续行为。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | 架构边界：战斗结算用 Autoload 还是节点属架构 ADR 决策 | CombatSystem 为 Autoload（无状态解算器）；在架构图中定义调用边界：GridMovement call → GameState → CombatSystem |
| combat-system.md | Open Questions：resolve_combat 的宿主与 #6 网格移动的调用边界 | GameState.on_combat_cell_entered() 是边界；GridMovement 触发，GameState 调用 CombatSystem |
| combat-system.md | TR-combat-001：resolve_combat 签名 | 本 ADR 确立 `resolve_combat(monster_id: String)` 单参数签名；EntityDB/PlayerStats 查询在 CombatSystem 内部执行（2026-06-26 /architecture-review 冲突修正） |
| combat-system.md | TR-combat-004：三个输出信号（combat_won/lost/round_resolved） | 本 ADR Key Interfaces 补充了 CombatSystem 完整信号列表 |
| player-stats-growth.md | 玩家属性须在整局游戏中持久化（跨楼层） | PlayerStats 为 Autoload，不随场景重载消亡 |
| player-stats-growth.md | TR-stats-003：pickup_item(item_id) 公开 API | 本 ADR 确立 `pickup_item(item_id: String)` 签名；与 GDD + architecture.md 一致（2026-06-26 /architecture-review 冲突修正） |
| player-stats-growth.md | TR-stats-004：apply_damage(amount≥0) 公开 API | 本 ADR Key Interfaces 补充了 apply_damage 方法签名 |
| systems-index.md | Category 分层（Foundation/Core/Feature/Presentation） | 分类调节面与 systems-index 的 Category 列对齐：Foundation=Autoload（ADR-0002），Core/Feature 按调节面判定，Presentation=Scene Node |

## Performance Implications
- **CPU**: Autoload 全局访问为直接指针查找，O(1)，无运行期开销；信号分发为 Godot 原生实现，多接收者时轻微线性开销（MVP 接收者数 ≤ 3，可接受）
- **Memory**: 11 个 Autoload 全程常驻内存；但均为纯数据/逻辑节点，无纹理/音频资源，总内存开销 < 1MB
- **Load Time**: 11 个 Autoload 的 _ready() 在 GameBootstrap 之前完成；同步初始化总时长估计 < 20ms（MVP 数据量）
- **Network**: N/A

## Migration Plan
无现有代码。本 ADR 在首行代码编写前定义宿主规范。

## Validation Criteria
1. Project Settings > Autoloads 列表包含全部 10 个 Autoload（Foundation 3 + Core/Feature 7）+ GameBootstrap，顺序符合本 ADR 规定
2. GridMovement、HUD、NumberFeedback 均为 game.tscn 中的 Scene Node，不出现在 Autoload 列表
3. `grep -r "var grid.*GridMovement" --include="*.gd" addons/ res/autoloads/` 返回空（Autoload 不持有 Scene Node 引用）
4. CombatSystem.resolve_combat()、KeyDoor.try_open_door()、DropReward.resolve_drops() 可在 GDUnit4 headless 模式下直接调用并断言（无场景树依赖）
5. 场景重启后：PlayerStats 所有属性回到初始值（GDUnit4 测试验证）

## Related Decisions
- ADR-0001（数据类型）— Autoload 暴露的接口类型
- ADR-0002（Autoload 启动顺序）— Foundation Autoload 位置；is_initialized 标志模式（本 ADR Core/Feature Autoload 沿用）
- design/gdd/combat-system.md（架构边界：战斗结算宿主）
- design/gdd/systems-index.md（系统分类与依赖关系）
