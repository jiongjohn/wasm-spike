# ADR-0006: 确定性战斗系统完整接口

## Status
Accepted

## Date
2026-06-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM — post-LLM-cutoff；但 GDScript 静态类型、typed Array 和 enum 自 4.0 起稳定，4.4/4.5/4.6 breaking-changes 中无相关变更 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None（`Array[RoundEvent]` typed array 自 4.0 起稳定） |
| **Verification Required** | (1) headless GDUnit4 测试中验证 `Array[RoundEvent]` 赋值与断言正常工作；(2) WASM 导出后验证 `push_error()` 日志可达 Douyin 控制台（低优先级，不影响逻辑正确性） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（RoundEvent 必须以 class_name + RefCounted 实现）；ADR-0003（CombatSystem 宿主为 Autoload，resolve_combat 基础签名已确立）；ADR-0004（GDUnit4 headless 测试框架） |
| **Enables** | #5 确定性回合战斗系统 epic 全部 Logic/Integration 故事；#10 战斗预演系统（依赖 forecast_combat/generate_round_sequence 的确定性契约） |
| **Blocks** | CombatSystem 所有 Logic 类型故事（coding-standards.md：Logic story 须有自动化单测，单测设计依赖本 ADR 确立的返回类型和状态机守卫） |
| **Ordering Note** | ADR-0001/0003/0004 须先于本 ADR 被 Accepted（已全部 Accepted，2026-06-26）；本 ADR 须先于 #5 epic 的首个故事实现 |

## Context

### Problem Statement

ADR-0003 已确立 CombatSystem 作为 Autoload、`resolve_combat(monster_id: String)` 的基础签名、三个信号契约，以及 `forecast_combat` / `generate_round_sequence` 的参数签名。但三个架构层级的决策尚未正式化：

1. **TR-combat-003** — `generate_round_sequence` 的返回类型（`Array[RoundEvent]` 强类型 vs 未类型化 Array）及 `forecast_combat` 必须内部委托给它的契约（防止双路数值漂移，GDD F-SEQ 节明确要求）。
2. **TR-combat-005** — 零随机数约束须从「GDD grep 测试」升级为已注册的架构约束，使其对所有后续实现者可见，而非依赖单独阅读 GDD。
3. **TR-combat-008** — 战斗状态机（NoCombat/Resolving/Victory/Defeat 四状态）的实现模式及重入保护守卫须形成架构决策，否则实现者可能独立选择不一致的状态管理方案。

这三个决策构成 CombatSystem 公开契约（ADR-0003）之上的**实现约束层**：前者决定接口的类型完整性，后两者决定系统在运行时的可靠性。三者共同构成「可测试的确定性战斗引擎」的完整架构边界。

### Constraints
- **ADR-0001**：公共接口返回类型必须使用 class_name + RefCounted，禁止 untyped Dictionary 和 untyped Array 作为公开 API 返回值
- **ADR-0003**：CombatSystem 宿主为 Autoload（不可更改）；`resolve_combat` 同步完成，无 await（AC-C7-SYNC）
- **GDD combat-system.md**：`forecast_combat` 内部必须复用 `generate_round_sequence` 取末态值（F-SEQ 节末段明确约束）；零 RNG 是 P2「算得清的确定性」的硬约束（C6）
- **WASM/Douyin**：战斗结算在主线程同步执行，不可引入异步等待（ADR-0002 同步初始化原则延伸至运行时结算）
- **headless 可测**：三个公开函数必须可在无场景树的 GDUnit4 测试中直接调用

### Requirements
- `generate_round_sequence` 的返回类型在 GDScript 签名层强类型标注为 `Array[RoundEvent]`
- `forecast_combat` 的实现必须通过调用 `generate_round_sequence` 并从结果序列推导摘要值，不得独立实现平行计算路径
- 零 RNG 约束须以 forbidden_pattern 形式注册进 `docs/registry/architecture.yaml`，使其对不阅读 GDD 的实现者可见
- 状态机必须使用私有 enum 实现四个状态，`resolve_combat()` 入口必须检查并拒绝重入
- DEFEAT 状态必须持续至 GameState 调用 `reset_for_new_game()` 清除，不得自动恢复

## Decision

### 决策 1 — generate_round_sequence 返回类型：Array[RoundEvent]

`generate_round_sequence` 的返回类型正式确立为 `Array[RoundEvent]`（强类型，GDScript 4 typed array）。

禁止返回 `Array`（untyped）或 `Array[Dictionary]`，违反 ADR-0001 的 `untyped_dictionary_public_interface` 禁用模式。

`RoundEvent` 类型已由 ADR-0001 确立为 class_name + RefCounted 子类（字段：`round_index: int`、`dmg_to_monster: int`、`monster_hp_remaining: int`、`dmg_to_player: int`、`player_hp_remaining: int`）。

### 决策 2 — forecast_combat 内部委托契约

`forecast_combat` 的**实现** MUST 内部调用 `generate_round_sequence` 并从返回序列推导摘要（n_rounds、total_damage、survives、hp_after）。禁止实现独立的并行计算路径。

**原因**：GDD F-SEQ 节末段明确约束「`forecast_combat` 内部应复用 `generate_round_sequence` 取末态值，防止两条独立实现路径数值漂移」。任何独立实现路径都会创建第二个权威源，违背确定性保证（P2）。

### 决策 3 — 零 RNG 架构约束

CombatSystem 实现文件（`src/combat_system.gd` 及其依赖文件）中不得出现任何随机数调用：

- 禁止：`randf()`、`randi()`、`randf_range()`、`randi_range()`、`RandomNumberGenerator`、`seed()`
- 禁止：通过依赖注入将 RNG 注入 CombatSystem（RNG 从外部传入仍违反 P2 硬约束）
- 此约束以 forbidden_pattern 注册进架构注册表，使其在代码审查和故事创建时可被 `/dev-story`、`/story-done` 自动引用

### 决策 4 — 战斗状态机：私有 enum + 重入守卫

状态机以私有 enum `_CombatState` 实现四个状态，`_state` 变量作为运行时状态持有者。`resolve_combat()` 在入口处以 if 守卫拒绝重入。

**状态与转换**：

```
NoCombat  ──resolve_combat()──▶  Resolving  ──monster_hp≤0──▶  Victory ──▶  NoCombat（即时回转，同步帧内）
                                            └──player_died()──▶  Defeat ──▶ （冻结，等待 reset_for_new_game()）
```

Victory 在发出 `combat_won` 信号后**立即**回转至 NoCombat（同步帧内），允许连续战斗（同层多怪）。
Defeat 在发出 `combat_lost` 信号后**冻结**，等待 `GameState.reset_for_new_game()` 显式清除。

重入时行为：`push_error(...)` + 返回 `null`（调用方 GameState 须检查 null 返回）。

### Architecture Diagram

```
CombatSystem (Autoload)
│
├── _state: _CombatState
│       ┌─────────────────┐
│       │   NO_COMBAT     │◀──── reset_for_new_game() ──── GameState
│       └────────┬────────┘
│     resolve_combat(monster_id)
│       ┌────────▼────────┐
│       │   RESOLVING     │ ─── reentry guard ──▶ push_error + return null
│       └────────┬────────┘
│           ┌────┴────┐
│    won     ▼         ▼     lost (player_died received)
│   ┌──────────┐  ┌─────────┐
│   │ VICTORY  │  │ DEFEAT  │ ──── combat_lost signal ──▶ GameState (#13)
│   └────┬─────┘  └─────────┘
│        │ 即时回转（同步帧内）
│        ▼
│   NO_COMBAT
│
├── generate_round_sequence(6 int) → Array[RoundEvent]   [纯函数，无状态修改，无 await]
│       ↑ 委托（内部调用）
└── forecast_combat(6 int)         [从序列推导摘要，不独立实现]
    → CombatForecast                [供 #10 战斗预演调用]
```

### Key Interfaces

```gdscript
# ── CombatSystem（本 ADR 正式化的部分，补充 ADR-0003 接口）──

class_name CombatSystem extends Node:

    # 私有状态机（决策 4）
    enum _CombatState { NO_COMBAT, RESOLVING, VICTORY, DEFEAT }
    var _state: _CombatState = _CombatState.NO_COMBAT

    # 决策 1：强类型返回值（纯函数，无 await，无状态副作用）
    func generate_round_sequence(monster_hp: int, monster_atk: int, monster_def: int,
                                  player_atk: int, player_def: int,
                                  player_current_hp: int) -> Array[RoundEvent]:
        # 零 RNG — 任何 randf/randi 调用在此为架构违规（决策 3）
        var seq: Array[RoundEvent] = []
        # ... 纯确定性计算，引用 TuningConfig F1-A/F1-B，无 await ...
        return seq

    # 决策 2：内部委托契约——实现必须通过 generate_round_sequence，不得独立并行计算
    func forecast_combat(monster_hp: int, monster_atk: int, monster_def: int,
                         player_atk: int, player_def: int,
                         player_current_hp: int) -> CombatForecast:
        var seq := generate_round_sequence(monster_hp, monster_atk, monster_def,
                                           player_atk, player_def, player_current_hp)
        var last: RoundEvent = seq.back() if not seq.is_empty() else null
        var fc := CombatForecast.new()
        fc.n_rounds = seq.size()
        fc.total_damage_to_player = (player_current_hp
                                     - (last.player_hp_remaining if last else player_current_hp))
        fc.player_survives = (last.player_hp_remaining > 0) if last else true
        fc.predicted_hp_after = last.player_hp_remaining if last else player_current_hp
        return fc

    # 决策 4：重入守卫（补充 ADR-0003 的 resolve_combat 签名）
    func resolve_combat(monster_id: String) -> CombatResult:
        if _state == _CombatState.RESOLVING:
            push_error("CombatSystem: reentry blocked — resolve_combat called while Resolving")
            return null  # GameState 调用方须检查 null，并在 debug build 加 assert
        _state = _CombatState.RESOLVING
        # ... 同步战斗循环，无 await，引用 EntityDB/PlayerStats/TuningConfig ...
        # WIN 路径：
        #   _state = _CombatState.VICTORY
        #   combat_won.emit(monster_id)
        #   _state = _CombatState.NO_COMBAT  ← 即时回转
        #   return result
        # DEFEAT 路径（收到 player_died 信号）：
        #   _state = _CombatState.DEFEAT
        #   combat_lost.emit(monster_id)
        #   return result  ← 冻结，等待 reset_for_new_game()
        return null  # 占位，实际实现填充两路返回

    # 供 GameState.reset_for_new_game() 依次调用（与 ADR-0003 中其他 Autoload 一致）
    func reset_for_new_game() -> void:
        _state = _CombatState.NO_COMBAT
```

## Alternatives Considered

### Alternative 1: generate_round_sequence 返回 Array（untyped）
- **Description**: 返回无类型 `Array`，调用方按约定转型访问每个元素。
- **Pros**: 无需 typed array 语法；与 Godot 3 风格兼容。
- **Cons**: 违反 ADR-0001 `untyped_dictionary_public_interface` 禁用模式（untyped Array 公共接口与 untyped Dictionary 同属「运行时类型错误」风险）；`#10` 预演系统无法在 GDScript 中对元素做编译期类型检查；GDUnit4 的 `assert_array` 无法推断元素类型。
- **Rejection Reason**: ADR-0001 的架构原则是「强类型跨模块接口」，typed array 是该原则在集合返回值上的自然延伸；untyped Array 在此等同于 untyped Dictionary，直接违反已注册的 forbidden_pattern。

### Alternative 2: forecast_combat 独立并行实现
- **Description**: `forecast_combat` 以单独的数学公式实现（与 generate_round_sequence 互相独立），两者各自直接引用 F-C/F-FC 公式。
- **Pros**: 两函数可独立单测；`forecast_combat` 可略去序列分配的开销（O(1) 而非 O(N)）。
- **Cons**: 创建了「第二个确定性权威源」——任何公式微调都必须在两处同步更新；GDD F-SEQ 节明确禁止此模式（「防止两条独立实现路径数值漂移」）；AC-SEQ-CONSISTENCY 的三路末态一致性断言在独立实现下更难维护。
- **Rejection Reason**: GDD 是权威设计文档，明确要求委托关系；独立实现引入的维护风险不符合「确定性」设计支柱（P2）。

### Alternative 3: 使用 bool 标志替代四状态 enum
- **Description**: 用 `var _is_resolving: bool = false` 代替四状态 enum。
- **Pros**: 实现更简单；只有一个状态需要维护。
- **Cons**: 无法区分 Victory 和 Defeat 的不同后置行为（Victory 立即回 NoCombat；Defeat 冻结）；无法在 GDUnit4 测试中断言当前状态类型；GDD 明确定义了四状态机，bool 是对设计规格的简化省略。
- **Rejection Reason**: GDD States and Transitions 节明确定义四个状态和不同的退出条件，架构 ADR 不应在不修改 GDD 的前提下降维化 GDD 的状态机定义。

## Consequences

### Positive
- `Array[RoundEvent]` 强类型返回值消除了 `#10` 预演、`#11` 视觉反馈读取序列时的运行时类型错误风险
- `forecast_combat` 委托 `generate_round_sequence` 保证 AC-SEQ-CONSISTENCY（三路末态一致性）可以结构性满足，而非靠「两处实现恰好同步」
- 零 RNG 注册为 forbidden_pattern 后，`/dev-story` 和 `architecture-review` 可自动检测未来系统违反此约束
- Victory 路径内的即时状态回转（VICTORY→NO_COMBAT 同一帧）确保连续战斗（同层多怪）不会因状态未清除被误拒

### Negative
- `forecast_combat` 每次调用都分配完整事件序列（`Array[RoundEvent]`），N_max=10 时最多 10 个 RoundEvent 对象（约 600 字节/次调用）——在预演 UI 频繁调用时有分配开销
- GameState.reset_for_new_game() 必须显式调用 CombatSystem.reset_for_new_game()，否则游戏重开后 DEFEAT 状态残留导致所有后续战斗被拒

### Risks
- **风险（ES-6 引擎专家）**：`push_error()` 在 Douyin WASM 运行时中可能被静默丢弃，重入时调用方 GameState 收到 null 但无日志辅助调试。
  - **缓解**：GameState 的 `on_combat_cell_entered()` 必须在调用 `resolve_combat()` 后检查返回值是否为 null，并在 debug build 中加 `assert(result != null, "CombatSystem reentry")` 守卫；故事验收须覆盖「重入返回 null 后 GameState 不崩溃」。
- **风险（ES-6 引擎专家）**：scene reload（楼层切换）发生在 `_state == DEFEAT` 时，若 GameState 未调用 `reset_for_new_game()` 即启动新战斗，状态冻结传染至新局。
  - **缓解**：GameState 的楼层切换入口（`on_stair_cell_entered()`）必须在楼层内容重置之前调用 `CombatSystem.reset_for_new_game()`；集成测试须覆盖「DEFEAT 后 reset → 新战斗正常触发」路径。
- **风险**：`#10` 战斗预演系统在每次玩家碰触怪物格时调用 `forecast_combat`，若实现为按帧轮询（而非单次触发），GC 压力累积在 Douyin 低端设备上可能产生帧率抖动。
  - **缓解**：`#10` GDD 设计时须限制 `forecast_combat` 调用频率（玩家确认攻击时调用一次，而非 `_process()` 按帧调用）；若 Profile 显示 GC 压力，可为 `forecast_combat` 增加内部参数缓存，但属于实现优化，不影响本架构决策。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| combat-system.md | TR-combat-003：`generate_round_sequence(6 int) -> Array[RoundEvent]` 纯函数契约 | 决策 1 正式确立返回类型为 `Array[RoundEvent]`；决策 2 确立 forecast_combat 委托约束 |
| combat-system.md | TR-combat-005：零 RNG 约束（C6 P2 硬约束） | 决策 3 将零 RNG 注册为架构 forbidden_pattern，对所有实现者强制可见 |
| combat-system.md | TR-combat-008：战斗状态机 + Resolving 重入保护（States and Transitions 节） | 决策 4 确立四状态 enum 实现模式和 resolve_combat() 入口重入守卫 |
| combat-system.md | F-SEQ 节末段：forecast_combat 必须复用 generate_round_sequence（防漂移） | 决策 2 将 GDD 设计约束提升为架构决策，使其在代码审查时可被引用为架构违规 |
| combat-system.md | AC-SCOPE-NORNG：CI lint grep 验证零 RNG | 决策 3 的 forbidden_pattern 注册提供架构层面约束；AC-SCOPE-NORNG 的 CI lint 检验实现合规 |
| combat-system.md | AC-EC-REENTRY：Resolving 期间拒绝新 resolve_combat 调用 | 决策 4 的重入守卫（push_error + return null）直接满足此 AC 的架构前提 |

## Performance Implications
- **CPU**: `generate_round_sequence` 在 MVP N_max=10 时最多 10 次整数运算循环，<1µs；`forecast_combat` 委托调用增加一次函数调用开销，可忽略
- **Memory**: N_max=10 时 `Array[RoundEvent]` 分配 10 个 RefCounted 对象（每个约 5 个 int 字段，~60 字节），共约 600 字节/次；在 `forecast_combat` 调用后立即失去引用，GC 回收
- **Load Time**: N/A（运行时计算，与启动无关）
- **Network**: N/A（单机）

## Migration Plan
无现有实现。本 ADR 在首行 CombatSystem 代码编写前确立约束，无迁移。

## Validation Criteria
1. `grep -nE "randf|randi|RandomNumberGenerator|seed\(" src/combat_system.gd` 返回零匹配（决策 3）
2. `grep -n "await" src/combat_system.gd` 返回零匹配（AC-C7-SYNC，ADR-0003 延伸）
3. GDUnit4 单测：`forecast_combat(50,18,5,14,13,90)` 的 `predicted_hp_after` 与 `generate_round_sequence(50,18,5,14,13,90).back().player_hp_remaining` 完全相等（决策 2 委托正确性）
4. GDUnit4 单测：`generate_round_sequence(...)` 返回值中每个元素可直接访问 `.dmg_to_monster` 等字段（无需类型转型），返回数组类型为 `Array[RoundEvent]`
5. GDUnit4 集成测试：Resolving 期间重调 `resolve_combat()` 返回 null，不崩溃（决策 4 重入守卫）
6. GDUnit4 集成测试：DEFEAT 后调 `reset_for_new_game()`，再次 `resolve_combat()` 正常返回 CombatResult（决策 4 状态清除）

## Related Decisions
- ADR-0001（数据类型）— RoundEvent/CombatForecast/CombatResult 作为 class_name + RefCounted；Array[RoundEvent] 类型化的前提
- ADR-0003（系统宿主）— CombatSystem 宿主为 Autoload；resolve_combat/forecast_combat/generate_round_sequence 基础签名；Victory/Defeat 后通过信号通知下游
- ADR-0004（测试框架）— GDUnit4 headless 测试覆盖本 ADR 的所有 Validation Criteria
- design/gdd/combat-system.md — TR-combat-003/005/008 来源；F-SEQ 委托约束来源；四状态机定义来源
