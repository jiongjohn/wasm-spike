# 像素魔塔·无尽塔 — Master Architecture

> ## ⚠️ SUPERSEDED — 本文档已过时（2026-06-25 快照，ADR 阶段之前）
>
> 本文件写于任何 ADR 创建之前，**其后未更新**，多处与现实脱节：
> 仍写「ADRs Referenced: None yet」「PlayerStats/CombatSystem 宿主 ADR 待定」
> 「0 ADR / 35 缺口」「Required ADRs 待创建」，且仅覆盖 #1–#5。
>
> **当前权威来源（均为最新）**：
> - **ADR**：`docs/architecture/adr-0001 … adr-0009`（9 个，0001–0006 已 Accepted；0007/0008/0009 Proposed）
> - **需求追溯**：`docs/architecture/tr-registry.yaml`（v2，52 条 TR）
> - **架构注册表（state/interface/budget/forbidden_pattern）**：`docs/registry/architecture.yaml`
> - **最新评审**：`docs/architecture/architecture-review-2026-06-29.md`
>
> 实际宿主已裁定：**#4 PlayerStats = Autoload、#5 CombatSystem = Autoload**（ADR-0003）。
> 重建本文档请运行 `/create-architecture`。在重建前，**请勿**将以下内容当作权威。

## Document Status

- **Version**: 1.0
- **Created**: 2026-06-25
- **Engine**: Godot 4.6.3 (Compatibility backend, 2D only)
- **GDDs Covered**: #1 entity-database · #2 floor-layout-data · #3 game-tuning-config · #4 player-stats-growth · #5 combat-system
- **ADRs Referenced**: None yet — see Required ADRs section
- **Technical Director Sign-Off**: 2026-06-25 — APPROVED (lean mode)
- **Lead Programmer Feasibility**: N/A (lean mode, skipped)

---

## Engine Knowledge Gap Summary

| Domain | Risk Level | Impact on This Project |
|--------|-----------|----------------------|
| WASM / Douyin adapter | ⚠️ HIGHEST | Godot 4.6.3 ↔ Douyin adapter 兼容性 **UNVERIFIED** — must spike before VS |
| `duplicate_deep()` (4.5+) | MEDIUM | Must use instead of `duplicate()` for nested data structures (CombatResult/FloorEntry etc.) |
| Dual-focus system (4.6) | LOW | Touch-only game; no keyboard focus path needed in gameplay |
| 2D Physics | NONE | Unchanged since 4.3; no 3D physics used |
| Rendering (glow/D3D12) | NONE | Compatibility backend; pixel art; no complex shaders |
| GDScript variadic / @abstract (4.5+) | LOW | Available as enhancement; not required for MVP |

> All signal connections MUST use Callable syntax — string-based `connect()` is deprecated since 4.0.

---

## Architecture Principles

1. **数据驱动强制**：所有平衡数值存在 JSON 文件中（`res://data/`）；GDScript 代码零硬编码。
2. **Foundation 先行**：Foundation 层 (#1/#2/#3) 必须在 Core 层任何节点的 `_ready()` 触发前完成加载和校验。
3. **同步结算，延迟渲染**：战斗逻辑同步完成（无 `await`）；视觉/音频响应通过 `CONNECT_DEFERRED` 异步播放，不阻塞逻辑循环。
4. **强类型数据契约**：所有跨模块数据结构使用 `class_name + RefCounted`（禁用 `Dictionary` 作为公共接口），每次调用返回 `.duplicate()` 或 `.duplicate_deep()` 副本。
5. **测试边界分离**：纯函数（`forecast_combat`、`generate_round_sequence`、`TuningFormulas.*`）为 Logic 类型 GDUnit4 测试；有状态接口（`resolve_combat`、`pickup_item`）为 Integration 测试；视觉/Feel 类测试用手工 playtest 兜底。

---

## System Layer Map

```
┌──────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                          │
│  #11 VisualFeedback · #12 HUD · (Alpha: #19 Audio)          │
│  消费 stat_changed / round_resolved 信号，只做渲染           │
├──────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                               │
│  #8 DropRewards · #9 FloorProgress · #10 CombatPreview       │
│  #13 GameState                                               │
│  VS: #14 Fragment · #15 Failsafe · #16 Shop · #17 AdSDK      │
├──────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                  │
│  #4 PlayerStats · #5 CombatSystem                            │
│  (MVP+: #6 GridMovement · #7 KeyDoor)                        │
├──────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                            │
│  #3 TuningConfig ──→ #1 EntityDB ──→ #2 FloorDB             │
│  (启动顺序从左到右；右侧模块等待左侧 ready 信号)              │
│  PlayerStats 并行等待 TuningConfig ready                      │
├──────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER                                              │
│  Godot 4.6.3 · Compatibility Renderer (2D) · Touch Input     │
│  WASM · ⚠️ Douyin mini-game adapter (兼容性 UNVERIFIED)      │
└──────────────────────────────────────────────────────────────┘
```

**层间通信规则**：
- 上层可以调用/监听下层
- 下层绝不调用上层（Foundation 不调用 Core，Core 不调用 Feature）
- 跨系统通信通过信号（signals）或公开 API，禁止直接访问私有字段

---

## Module Ownership

### Foundation Layer

| 模块 | Owns | Exposes | Consumes | 宿主类型 |
|------|------|---------|----------|---------|
| **#3 TuningConfig** | 所有数值参数 + 楼层曲线表 | `get_tuning_config()`, `get_floor_tuning(n)`, `TuningFormulas` (static class) | 无 | Autoload（首个加载）|
| **#1 EntityDB** | 静态实体数据 (MonsterEntry/ItemEntry/KeyEntry) | `get_monster/item/key/entity(id)` → 返回 `.duplicate()` 副本 | TuningConfig (D1/D3 校验) | Autoload（TuningConfig 之后）|
| **#2 FloorDB** | 楼层布局数据 (FloorEntry/CellEntry) | `get_floor(id)`, `get_cell(id,col,row)` → 返回 `.duplicate()` 副本 | EntityDB (F6/F-K1/F-T1 校验) | Autoload（EntityDB 之后）|

### Core Layer

| 模块 | Owns | Exposes | Consumes | 宿主类型 |
|------|------|---------|----------|---------|
| **#4 PlayerStats** | 运行时属性状态 (HP/ATK/DEF/MaxHP + boost 追踪器) | `pickup_item()`, `apply_damage()`, ATK/DEF getter (只读); 信号: `stat_changed`, `player_died` | EntityDB (#1), TuningConfig (#3) | Autoload 或主场景节点（ADR 待定）|
| **#5 CombatSystem** | 战斗状态机 (NoCombat/Resolving/Victory/Defeat) | `resolve_combat()`, `forecast_combat()`, `generate_round_sequence()`; 信号: `combat_won`, `combat_lost`, `round_resolved` | EntityDB (#1), TuningConfig (#3), PlayerStats (#4) | Autoload 或主场景节点（ADR 待定）|

---

## Module Dependency Diagram

```
TuningConfig (#3)
    ↓ 读取 base_ATK/DEF/MaxHP, 公式
EntityDB (#1) ←── TuningConfig (#3) [D1/D3 N_max, HP_BUDGET_RATIO]
    ↓
FloorDB (#2) ←─── EntityDB (#1) [F6/F-K1/F-T1]
    ↓
PlayerStats (#4) ←─ TuningConfig (#3), EntityDB (#1)
    ↓ apply_damage / player_died signal
CombatSystem (#5) ←─ EntityDB (#1), TuningConfig (#3), PlayerStats (#4)
    ↓ signals
Feature / Presentation layers
```

---

## Data Flow

### 启动序列

```
Game Boot
  1. TuningConfig._ready()
     → 加载 res://data/tuning_config.json
     → validate_tuning_config() — 失败则显示 inline 错误屏（无 OS.quit()）
     → emit database_ready
  2. EntityDB._ready() [等待 TuningConfig.database_ready]
     → 加载 res://data/entities.json
     → validate_database(entries, TuningConfig.get_tuning_config()) — D1/D3 校验
     → 失败则 inline 错误屏
     → emit database_ready
  3. FloorDB._ready() [等待 EntityDB.database_ready]
     → 加载 res://data/floors/ JSON 文件
     → validate_floors(floors, EntityDB, TuningConfig, "MVP")
     → 失败则 inline 错误屏
     → emit database_ready
  4. PlayerStats._ready() [等待 TuningConfig.database_ready]
     → 读取 base_ATK, base_DEF, base_MaxHP
     → 初始化: current_HP = MaxHP = 100, ATK = 6, DEF = 3
  5. CombatSystem._ready()
     → 连接 PlayerStats.player_died（CONNECT_DEFERRED）
  6. 主场景进入 — 游戏循环开始
```

### 战斗数据流（同步结算 + 延迟渲染）

```
#6 GridMovement → CombatSystem.resolve_combat("goblin")    [同步调用]
  ├→ EntityDB.get_monster("goblin")                        [同步读取]
  ├→ PlayerStats.ATK getter / DEF getter                   [同步读取]
  └→ Round loop (no await, C7 保证):
       PlayerStats.apply_damage(F1-B)                      [同步]
         └→ 若 HP≤0: player_died.emit()                   [同步发射]
              └→ CombatSystem listener (CONNECT_DEFERRED)
                   └→ 设 _player_died_flag = true
       round_resolved.emit(...)                            [同步发射]
         └→ #11 VisualFeedback (CONNECT_DEFERRED)          [下一帧]
  └→ 返回 CombatResult → #6 处理胜负
     combat_won.emit() / combat_lost.emit()                [同步发射]
       └→ #8 DropRewards (CONNECT_DEFERRED)
       └→ #13 GameState (CONNECT_DEFERRED) ⚠️ 必须 DEFERRED
```

### 道具拾取数据流

```
#6 GridMovement → PlayerStats.pickup_item("sword_iron")    [同步]
  ├→ EntityDB.get_item("sword_iron")                       [同步读取]
  └→ 更新 atk_boost_effective → ATK 重算
     stat_changed.emit("ATK", 6, 14)                       [同步发射]
       ├→ #11 VisualFeedback (CONNECT_DEFERRED)            [下一帧：ATK 跳升动画]
       └→ #12 HUD (SYNC / CONNECT_IMMEDIATE)               [同帧：数字刷新]
```

> ⚠️ **HUD 连接模式规则**：`#12 HUD` 监听 `stat_changed` 必须用 **CONNECT_IMMEDIATE**（同步），确保显示不落帧。其他所有视觉响应用 `CONNECT_DEFERRED`。

### 存档数据流（Alpha 阶段）

```
#18 Save System (Alpha)
  ├→ 序列化: PlayerStats.serialize_state() → JSON
  ├→ 序列化: FloorProgress.serialize_state() → JSON
  └→ 写入 user://save.json (WASM: IndexedDB by Godot runtime)
```

---

## API Boundaries

### Foundation Layer API (GDScript 强类型伪代码)

```gdscript
## #3 TuningConfig (Autoload)
class_name TuningConfig extends Node:
    func get_tuning_config() -> TuningConfigData      # 返回只读副本或守卫对象
    func get_floor_tuning(floor_number: int) -> FloorTuningRow  # null if not found

## 伴随静态工具类
class_name TuningFormulas:
    static func damage_player(player_atk: int, monster_def: int) -> int   # max(1, atk-def)
    static func damage_monster(monster_atk: int, player_def: int) -> int  # max(0, atk-def)
    static func n_rounds(monster_hp: int, player_atk: int, monster_def: int) -> int  # ceil(hp/dmg)

## #1 EntityDB (Autoload)
class_name EntityDB extends Node:
    func get_monster(id: String) -> MonsterEntry    # null if not found
    func get_item(id: String) -> ItemEntry          # null if not found
    func get_key(id: String) -> KeyEntry            # null if not found
    func get_entity(id: String) -> Variant          # any type, null if not found

## #2 FloorDB (Autoload)
class_name FloorDB extends Node:
    func get_floor(floor_id: String) -> FloorEntry        # null if not found
    func get_cell(floor_id: String, col: int, row: int) -> CellEntry  # null if OOB/not found
```

### Core Layer API

```gdscript
## #4 PlayerStats (Autoload or SceneNode — ADR 待定)
class_name PlayerStats extends Node:
    signal stat_changed(stat_name: String, old_value: int, new_value: int)
    signal item_pickup_no_change(stat_name: String, item_id: String)
    signal player_died()

    var ATK: int:     get = _get_atk   # computed property, no setter
    var DEF: int:     get = _get_def   # computed property, no setter
    var current_HP: int:  get = _get_hp
    var MaxHP: int:       get = _get_maxhp

    func pickup_item(item_id: String) -> void   # 调用方须确保 item_id 存在于 EntityDB
    func apply_damage(amount: int) -> void      # amount MUST be >= 0 (caller contract)

## #5 CombatSystem (Autoload or SceneNode — ADR 待定)
class_name CombatSystem extends Node:
    signal combat_won(monster_id: String)
    signal combat_lost(monster_id: String)
    signal round_resolved(round_index: int, dmg_to_monster: int,
                          monster_hp_remaining: int, dmg_to_player: int,
                          player_hp_remaining: int)

    func resolve_combat(monster_id: String) -> CombatResult   # synchronous, no await
    func forecast_combat(monster_hp: int, monster_atk: int, monster_def: int,
                         player_atk: int, player_def: int,
                         player_current_hp: int) -> CombatForecast  # pure function
    func generate_round_sequence(monster_hp: int, monster_atk: int, monster_def: int,
                                  player_atk: int, player_def: int,
                                  player_current_hp: int) -> Array[RoundEvent]  # pure function
```

### 数据类型接口（架构 ADR 须锁定实现方式）

```gdscript
# 所有跨模块数据类型：class_name + RefCounted（禁用 Dictionary 作为公共接口）
class_name CombatResult extends RefCounted:
    var result: int          # WON = 0, LOST = 1
    var monster_id: String
    var n_rounds: int               # 理论击杀回合数
    var actual_rounds_played: int   # 实际结算回合数（LOSS时 ≤ n_rounds）
    var total_damage_to_player: int # WIN: F1-B×(n-1)；LOSS: F1-B×actual_rounds_played

class_name CombatForecast extends RefCounted:
    var n_rounds: int
    var total_damage_to_player: int   # WIN 路径理论值
    var player_survives: bool
    var predicted_hp_after: int

class_name RoundEvent extends RefCounted:
    var round_index: int
    var dmg_to_monster: int
    var monster_hp_remaining: int
    var dmg_to_player: int
    var player_hp_remaining: int

# ⚠️ duplicate_deep() (Godot 4.5+) 必须用于含嵌套 RefCounted 的返回值
# 简单扁平结构用 duplicate() 即可
```

---

## ADR Audit

| ADR | 存在? | 状态 |
|-----|-------|------|
| 无 | — | 架构目录仅有 tr-registry.yaml |

**TR 需求追溯覆盖**：35 条技术需求，0 条被 ADR 覆盖，**35 条缺口**。所有缺口由下方 Required ADRs 填补。

---

## Required ADRs

### Foundation 层（实现任何代码前必须创建）

**ADR-F001: 数据类型实现方案**
→ 覆盖：CombatResult/CombatForecast/RoundEvent/FloorEntry/CellEntry/MonsterEntry/ItemEntry/KeyEntry 的实现载体（class_name + RefCounted vs Resource）、只读强制方式、返回值拷贝策略（duplicate vs duplicate_deep）
→ 解锁：所有系统实现、AC 强类型断言

**ADR-F002: Autoload 启动顺序与初始化保证**
→ 覆盖：TuningConfig → EntityDB → FloorDB → PlayerStats → CombatSystem 的顺序保证机制（Autoload 列表排序 vs 信号等待 vs 依赖注入）
→ 解锁：Entity DB 的 D1/D3 校验（需 TuningConfig 就绪）、FloorDB 校验（需 EntityDB 就绪）

**ADR-F003: 测试框架 GUT → GDUnit4**
→ 覆盖：正式选型决定（所有 GDD 已写 GDUnit4 AC），运行命令（`godot --headless --script tests/gdunit4_runner.gd`）
→ 解锁：qa-tester 可以开始编写测试；CI/CD 测试命令配置

**ADR-F004: 数据文件组织方式**
→ 覆盖：单 JSON 文件 vs 多文件（entities.json / tuning_config.json / floors/*.json）；文件路径规范；Autoload 加载方式
→ 解锁：FloorDB、EntityDB 实现

### Core 层

**ADR-C001: CombatSystem 宿主架构**
→ 覆盖：Autoload vs 场景节点；与 #6 GridMovement 的调用边界；重入保护实现方式
→ 解锁：CombatSystem 实现、#5 story 文件编写

**ADR-C002: PlayerStats 宿主架构**
→ 覆盖：Autoload vs 场景节点；跨场景状态持久化（重要：死亡后重新加载场景时属性是否重置？）
→ 解锁：PlayerStats 实现

**ADR-C003: 信号连接模式规范**
→ 覆盖：SYNC vs CONNECT_DEFERRED 的使用原则；#12 HUD 须 SYNC、#11/#13 须 DEFERRED 的显式规则；防止 combat loop 内死亡处理竞态的强制约束
→ 解锁：所有信号连接代码

### VS 阶段前

**ADR-P001: WASM 导出与 Douyin 适配器验证结论**
→ 覆盖：Godot 4.6.3 + Douyin adapter spike 结果；WASM bundle size 实测值；是否需要自定义 JS loader；导出参数设置
→ 解锁：可以进入 VS 垂直切片阶段

---

## Technical Requirements Baseline

*35 条需求，从 5 个 GDD 提取。均未被 ADR 覆盖 — 待 ADR 创建后通过 `/architecture-review` 更新追溯矩阵。*

| Req ID | GDD | 系统 | 需求 | 状态 |
|--------|-----|------|------|------|
| TR-entity-001 | entity-database.md | #1 EntityDB | 启动 D1/D3 校验（需 TuningConfig 就绪） | active |
| TR-entity-002 | entity-database.md | #1 EntityDB | 只读访问模式（返回 duplicate() 副本） | active |
| TR-entity-003 | entity-database.md | #1 EntityDB | entity_type 判别字段（MONSTER/ITEM/KEY） | active |
| TR-entity-004 | entity-database.md | #1 EntityDB | HIGHEST_WINS vs ADDITIVE 叠加规则支持 | active |
| TR-entity-005 | entity-database.md | #1 EntityDB | WASM JSON 文件路径在 res:// 而非 user:// | active |
| TR-entity-006 | entity-database.md | #1 EntityDB | 启动校验失败：inline 错误屏（禁 OS.quit()） | active |
| TR-floor-001 | floor-layout-data.md | #2 FloorDB | 16×16 网格数据结构，两遍校验 | active |
| TR-floor-002 | floor-layout-data.md | #2 FloorDB | 六种 cell_type 带条件附加字段 | active |
| TR-floor-003 | floor-layout-data.md | #2 FloorDB | get_cell/get_floor 返回 duplicate() 只读副本 | active |
| TR-floor-004 | floor-layout-data.md | #2 FloorDB | F-SC1d BFS 拓扑校验（shield 在 goblin 前可达） | active |
| TR-floor-005 | floor-layout-data.md | #2 FloorDB | FloorDB 启动顺序在 EntityDB 之后 | active |
| TR-tuning-001 | game-tuning-config.md | #3 TuningConfig | 纯配置层，get_tuning_config() 返回只读 | active |
| TR-tuning-002 | game-tuning-config.md | #3 TuningConfig | TuningFormulas 独立静态函数（可 headless 测试） | active |
| TR-tuning-003 | game-tuning-config.md | #3 TuningConfig | 楼层调参表按 floor_number 查询（null 处理） | active |
| TR-stats-001 | player-stats-growth.md | #4 PlayerStats | 四条运行时属性（current_HP/MaxHP/ATK/DEF） | active |
| TR-stats-002 | player-stats-growth.md | #4 PlayerStats | stat_changed 信号（包括 old==new 时） | active |
| TR-stats-003 | player-stats-growth.md | #4 PlayerStats | pickup_item(item_id) 公开 API | active |
| TR-stats-004 | player-stats-growth.md | #4 PlayerStats | apply_damage(amount≥0) → 可能触发 player_died | active |
| TR-stats-005 | player-stats-growth.md | #4 PlayerStats | HIGHEST_WINS (ATK/DEF)；ADDITIVE (MaxHP) | active |
| TR-stats-006 | player-stats-growth.md | #4 PlayerStats | player_died() 信号（HP 归零时） | active |
| TR-stats-007 | player-stats-growth.md | #4 PlayerStats | ATK/DEF 只读 getter（无外部写入路径） | active |
| TR-combat-001 | combat-system.md | #5 CombatSystem | resolve_combat(monster_id) 同步无 await | active |
| TR-combat-002 | combat-system.md | #5 CombatSystem | forecast_combat(6 int 参数) 纯函数 | active |
| TR-combat-003 | combat-system.md | #5 CombatSystem | generate_round_sequence(6 int 参数) 纯函数 | active |
| TR-combat-004 | combat-system.md | #5 CombatSystem | 三个输出信号：combat_won/lost/round_resolved | active |
| TR-combat-005 | combat-system.md | #5 CombatSystem | 零 RNG（grep 验证：无 randf/randi） | active |
| TR-combat-006 | combat-system.md | #5 CombatSystem | 逻辑/动画解耦（无 await in combat code） | active |
| TR-combat-007 | combat-system.md | #5 CombatSystem | CombatResult/Forecast/RoundEvent 强类型类 | active |
| TR-combat-008 | combat-system.md | #5 CombatSystem | 战斗状态机 + 重入保护 | active |
| TR-cross-001 | (all) | 全局 | GDUnit4 测试框架（headless 运行） | active |
| TR-cross-002 | (all) | 全局 | WASM bundle ≤ 50MB（Douyin 限制） | active |
| TR-cross-003 | (all) | 全局 | Compatibility 渲染后端（2D + 低端设备） | active |
| TR-cross-004 | (all) | 全局 | 触控输入（无手柄/键盘游戏流程） | active |
| TR-cross-005 | (all) | 全局 | 30fps 目标，<50 draw calls，<256MB | active |
| TR-cross-006 | (all) | 全局 | Callable 信号连接（禁止字符串式 connect） | active |

---

## Open Questions

| ID | 摘要 | 优先级 | 解决路径 |
|----|------|--------|---------|
| QQ-01 | Godot 4.6.3 ↔ Douyin mini-game adapter 兼容性未验证 | High | ADR-P001（VS 阶段 spike 后填写）|
| QQ-02 | WASM bundle size 实测值（是否超 50MB？） | High | 导出 spike 实测后 → ADR-P001 |
| QQ-03 | CombatSystem/PlayerStats 宿主：Autoload vs 场景节点 | High | ADR-C001 / ADR-C002 |
| QQ-04 | `TuningFormulas` 函数归属：TuningConfig 实例方法 vs 独立静态类 vs 内联 #5 | High | ADR-F001 |
| QQ-05 | 玩家死亡后重启局时 PlayerStats 状态如何重置（跨场景持久化策略） | Medium | ADR-C002 |
| QQ-06 | Alpha+ 随机楼层 (#20) 引入后 FloorDB 需升级 BFS 完整可达性校验 | Low | #20 系统设计时处理 |
