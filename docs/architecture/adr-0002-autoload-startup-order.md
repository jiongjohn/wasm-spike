# ADR-0002: Autoload 启动顺序与初始化保证

## Status
Accepted

## Date
2026-06-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core（Autoload / Scene Tree Initialization） |
| **Knowledge Risk** | HIGH — post-LLM-cutoff；但 Autoload 排序机制自 Godot 4.0 起稳定，breaking-changes.md 中 4.4/4.5/4.6 均无相关变更 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None（Autoload 列表顺序机制自 4.0 稳定；`change_scene_to_file()` 自 4.0 起存在，4.6.3 无变更） |
| **Verification Required** | (1) 导出 spike（QQ-01）中验证 Douyin 适配器 WASM 运行时 Autoload `_ready()` 调用顺序与 Project Settings 列表顺序一致；(2) 故意调换 EntityDB/FloorDB 顺序后确认 assert 守卫在 WASM debug build 中可见触发；(3) 验证 Douyin 适配器是否存在 VFS 懒加载行为（见 Risks）——若确认懒加载，GameBootstrap 须改用 `ResourceLoader.load_threaded_request()` 方案 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（数据类型实现方案，必须 Accepted——Foundation Autoload 的公共接口类型依赖 ADR-0001 定义的 RefCounted 类型） |
| **Enables** | 所有 Foundation 系统实现 epic（EntityDB #1、FloorDB #2、TuningConfig #3）；以及所有依赖 Foundation 层的 Core/Feature epic（#4–#13） |
| **Blocks** | 所有 MVP 系统实现 epic（#1–#13）——启动顺序未定则无法安全编写多系统初始化代码 |
| **Ordering Note** | ADR-0001 须先于本 ADR 被 Accepted；本 ADR 须先于任何 Foundation Autoload 实现开始 |

## Context

### Problem Statement
三个 Foundation GDD（entity-database、floor-layout-data、game-tuning-config）均要求特定的启动顺序（TuningConfig → EntityDB → FloorDB），且 floor-layout-data.md Open Questions #4 明确要求此保证机制在架构 ADR 中优先决策。当前没有任何 ADR 定义：① Autoload 的加载顺序是什么；② 依赖方如何在运行时验证前置依赖已就绪；③ 测试环境如何在无全局 Autoload 的前提下构造和断言系统行为。

### Constraints
- **WASM/抖音小游戏**：单线程，无多线程并发风险；但 Douyin 适配器事件循环与 VFS 行为与原生平台可能存在细微差异（待导出 spike 验证）
- **同步加载**：JSON 数据通过 `FileAccess.open()` 同步读取，无异步加载需求；`_load_and_validate()` 必须为纯同步（见 Consequences — 禁止在其中使用 `await`）
- **MVP 数据量极小**：3 层关卡 + 实体数据 < 10KB，启动顺序无需优化加载并行度
- **测试可注入**：GDD 明确要求 D1/D3 校验器通过 `ValidationConfig`（依赖注入）构造，不得依赖全局 Autoload（entity-database.md §AC 注；floor-layout-data.md §AC 注）
- **Release build `assert()` 剥离**：Godot 4 非 debug 导出模板中 `assert()` 被完全移除；生产环境防护须用 `push_error` + 错误屏

### Requirements
- TuningConfig 必须在 EntityDB 之前完成初始化（EntityDB 的 D1/D3 校验需要 `player_ATK_expected` 等参数）
- EntityDB 必须在 FloorDB 之前完成初始化（FloorDB 的 F-REF 校验调用 EntityDB 查询）
- 若顺序被破坏，系统必须在进入游戏场景前快速失败并给出可诊断的错误信息（debug 与 release 均须覆盖）
- 测试不得依赖全局 Autoload——通过依赖注入构造校验所需参数

## Decision

**使用 Godot Project Settings Autoload 列表排序作为启动顺序保证机制，辅以各系统 `_ready()` 中的 `assert()` 守卫（debug）和 GameBootstrap 的 `push_error` + 错误屏（release）实现快速失败检测。**

### 决策细则

1. **Autoload 列表顺序**（Project Settings → Globals → Autoloads）：
   ```
   [1] TuningConfig
   [2] EntityDB
   [3] FloorDB
   [4] GameBootstrap  ← 协调器：验证所有 Foundation 已就绪后加载游戏场景
   ```
   Godot 4 保证：所有 Autoload 先完成实例化，再按列表顺序依次调用 `_ready()`，每个 `_ready()` 同步完成后下一个才开始。同步 JSON 加载在 `_ready()` 中执行，无需 `await`。

2. **`is_initialized` 只读状态标志**：每个 Foundation Autoload 暴露只读布尔标志；`_ready()` 末尾成功后设为 `true`：
   ```gdscript
   var is_initialized: bool:
       get: return _initialized
   var _initialized: bool = false   # 仅 self 写入
   signal database_ready            # _ready() 成功后 emit（供未来异步兼容，见注）
   ```
   > **注**：`database_ready` 信号在 `_ready()` 末尾同步 emit。由于所有 Autoload 的 `_ready()` 在场景节点 `_ready()` 之前完成，场景节点无法通过自身的 `_ready()` 连接此信号后再收到 emit——信号已提前发出。**本信号仅为未来异步扩展预留接口**；当前 MVP 中不应有任何外部代码依赖此信号进行初始化时序协调；应使用 `is_initialized` 标志轮询。

3. **`assert` 守卫（debug 快速失败）**：每个依赖方在 `_ready()` 开头通过类型化引用断言前置依赖已就绪：
   ```gdscript
   # EntityDB._ready() 开头：
   var tuning := TuningConfig as TuningConfig
   assert(tuning != null and tuning.is_initialized,
       "STARTUP ORDER VIOLATION: TuningConfig must be listed before EntityDB in Project Settings > Autoloads")

   # FloorDB._ready() 开头：
   var entity_db := EntityDB as EntityDB
   assert(entity_db != null and entity_db.is_initialized,
       "STARTUP ORDER VIOLATION: EntityDB must be listed before FloorDB in Project Settings > Autoloads")
   ```
   类型化 `as` 转型（`TuningConfig as TuningConfig`）满足 GDScript 严格类型检查，消除「全局名解析为 Node 类型」警告。

4. **GameBootstrap — release 生产防护**（不使用 `assert()`）：
   ```gdscript
   func _ready() -> void:
       var tuning := TuningConfig as TuningConfig
       var entity_db := EntityDB as EntityDB
       var floor_db := FloorDB as FloorDB
       if tuning == null or not tuning.is_initialized \
           or entity_db == null or not entity_db.is_initialized \
           or floor_db == null or not floor_db.is_initialized:
           push_error("Foundation layer not fully initialized — check Autoload order in Project Settings")
           _show_startup_error_screen()  # 纯代码内联构建，不依赖任何 .tscn（见 Edge Cases 约定）
           return
       get_tree().change_scene_to_file("res://scenes/game.tscn")
   ```
   此守卫在 release build 中保留（不依赖被剥离的 `assert()`），Godot 4.5+ 的 script backtracing 确保 `push_error` 产生完整调用栈，便于上线后定位根因。

5. **校验错误通道（WASM 兼容）**：启动校验失败不调用 `get_tree().quit()`（WASM/小游戏容器内可能静默冻结）；改为向场景树添加纯代码内联构建的可见错误屏节点，不依赖任何 `.tscn` 文件（避免「错误屏自身加载失败」的循环依赖）。此模式与 entity-database.md Edge Cases WASM 节约定一致。

6. **测试不依赖 Autoload**：单元测试通过 `ValidationConfig` / `FloorValidationConfig` 依赖注入构造校验参数，无需 TuningConfig/EntityDB/FloorDB 在场景树中存在。

### Architecture Diagram

```
Project Settings > Autoloads（固定顺序）:
  [1] TuningConfig
        _ready(): 加载 res://data/tuning_config.json → 校验 → _initialized=true → emit database_ready
  [2] EntityDB
        _ready(): assert(TuningConfig.is_initialized) → 加载实体 JSON → 校验 D1/D3 → _initialized=true → emit database_ready
  [3] FloorDB
        _ready(): assert(EntityDB.is_initialized) → 加载楼层 JSON → 校验 F-REF → _initialized=true → emit database_ready
  [4] GameBootstrap
        _ready(): push_error 守卫（if 非 assert）→ all initialized → change_scene_to_file("res://scenes/game.tscn")

Godot 4 _ready() 调用顺序保证（4.0+ 稳定机制）:
  TuningConfig._ready() ▶ EntityDB._ready() ▶ FloorDB._ready() ▶ GameBootstrap._ready()
  ↑ 每个同步完成后下一个才开始；场景节点 _ready() 在全部 Autoload _ready() 之后

测试路径（无全局 Autoload）:
  ValidationConfig(player_ATK_expected=..., N_max=...) → EntityDB 实例.validate(config)
  FloorValidationConfig(build_scope=...) → FloorDB 实例.validate(config)
```

### Key Interfaces

```gdscript
# ── Foundation Autoload 统一初始化接口模板 ──

class_name TuningConfig extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready  # 未来异步兼容预留；当前不应被场景节点通过 _ready() 连接

    func _ready() -> void:
        _load_and_validate()  # 必须为纯同步（禁止 await，见 Consequences）
        _initialized = true
        database_ready.emit()

class_name EntityDB extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready

    func _ready() -> void:
        var tuning := TuningConfig as TuningConfig
        assert(tuning != null and tuning.is_initialized,
            "STARTUP ORDER VIOLATION: TuningConfig must be listed before EntityDB in Project Settings > Autoloads")
        _load_and_validate()
        _initialized = true
        database_ready.emit()

class_name FloorDB extends Node:
    var is_initialized: bool:
        get: return _initialized
    var _initialized: bool = false
    signal database_ready

    func _ready() -> void:
        var entity_db := EntityDB as EntityDB
        assert(entity_db != null and entity_db.is_initialized,
            "STARTUP ORDER VIOLATION: EntityDB must be listed before FloorDB in Project Settings > Autoloads")
        _load_and_validate()
        _initialized = true
        database_ready.emit()

class_name GameBootstrap extends Node:
    func _ready() -> void:
        var tuning := TuningConfig as TuningConfig
        var entity_db := EntityDB as EntityDB
        var floor_db := FloorDB as FloorDB
        if tuning == null or not tuning.is_initialized \
                or entity_db == null or not entity_db.is_initialized \
                or floor_db == null or not floor_db.is_initialized:
            push_error("Foundation layer not fully initialized — check Autoload order")
            _show_startup_error_screen()
            return
        get_tree().change_scene_to_file("res://scenes/game.tscn")
```

## Alternatives Considered

### Alternative 1: 信号异步初始化（await dep.database_ready）
- **Description**: 每个 Foundation Autoload 不假设列表顺序；在 `_ready()` 中若前置依赖未就绪则 `await dep.database_ready` 后继续。
- **Pros**: 对 Autoload 列表顺序容错；未来若需异步加载可自然扩展。
- **Cons**: Godot 4 中 `await signal` 在 `_ready()` 会将后续代码推迟到下一帧，期间其他 Autoload 的 `_ready()` 可能开始执行，产生实际的初始化竞态；WASM 事件循环与原生行为差异（`await` 在 Douyin 运行时行为待验证）；若信号在 `await` 之前就已 emit（列表顺序正确时），信号丢失，`await` 永远不返回；对本项目同步 JSON 加载场景引入了不必要的异步机制。
- **Rejection Reason**: 同步加载无需 async 机制；WASM 中 `await` 行为未验证；异步竞态调试复杂度超出 MVP 规模需要。

### Alternative 2: 手动 Bootstrap 脚本（Foundation 层为非 Autoload）
- **Description**: 将 TuningConfig/EntityDB/FloorDB 改为普通 RefCounted 类（非 Autoload）；由单一 `GameBootstrap` Autoload 按显式顺序构造、校验、并通过依赖注入传给下游。
- **Pros**: 完全消除对 Autoload 列表顺序的隐式依赖；初始化顺序在代码中显式可见；纯函数、测试最友好。
- **Cons**: 与现有 GDD 约定不符（GDD 多处直接引用 `EntityDB.` 作为全局 Autoload 访问，如 `EntityDB.lookup()`）；下游系统须通过 DI 接收引用，增加接口复杂度；与 floor-layout-data.md Open Q#4 推荐方案不一致。
- **Rejection Reason**: GDD 已预设 Autoload 访问模式；MVP 规模下 DI 传递工程负担超过 Autoload 列表顺序风险；GDD 推荐的正是 Autoload 列表顺序方案。

## Consequences

### Positive
- 初始化顺序在 Project Settings 中直观可见，无隐藏时序逻辑
- `assert` 守卫在 debug build 中立即暴露顺序错误，不会沉默传播
- `is_initialized` 只读标志模式简单、可轮询、可 headless 测试断言
- `database_ready` 信号为未来异步扩展预留接口，当前零运行期开销
- 与 floor-layout-data.md Open Q#4 推荐方案（「EntityDB Autoload 排在 FloorDB 之前」）完全一致
- 测试路径（ValidationConfig DI）完全不依赖 Autoload，可 headless GDUnit4 运行

### Negative
- Autoload 列表顺序是 Project Settings 中的隐式约束——新增 Foundation Autoload 的开发者须查阅本 ADR 才知道顺序要求（assert 守卫是运行时防线，不是编译期约束）
- `is_initialized` 标志须在所有 Foundation Autoload 中一致维护
- **禁止在 `_load_and_validate()` 中使用 `await`**：`await` 会将后续代码推迟到下一帧，导致当前 Autoload 的 `_ready()` 在 `_initialized = true` 之前「返回」，下一个 Autoload 的 `_ready()` 随即开始——assert 守卫将在前置依赖尚未完成时触发，整个顺序保证机制失效。所有 `_load_and_validate()` 实现必须为纯同步。
- `database_ready` 信号在场景节点 `_ready()` 之前已 emit，不得被任何场景节点通过其自身的 `_ready()` 连接后期望接收

### Risks
- **风险（HIGH — Douyin 特有）**：`change_scene_to_file()` 在标准 Godot WASM 导出中安全（PCK 全量下载后才执行 GDScript）；但 Douyin 适配器可能使用 VFS 懒加载，导致 `res://scenes/game.tscn` 在 `GameBootstrap._ready()` 时尚未就绪，调用静默返回 `ERR_CANT_OPEN` 或崩溃。
  - **缓解**：在导出 spike（QQ-01）中专项验证；若确认懒加载，GameBootstrap 改用 `ResourceLoader.load_threaded_request("res://scenes/game.tscn")` + 完成回调方案，不在 `_ready()` 中直接调用 `change_scene_to_file()`。
- **风险**：Douyin 适配器（基线 ~4.5，4.6.3 兼容性待实测）中 Autoload `_ready()` 顺序与 Godot 原生行为不一致。
  - **缓解**：Autoload 顺序机制自 4.0 起稳定，属引擎核心保证，被 Douyin 适配器破坏的可能性极低；在导出 spike 中加入顺序验证用例（故意调换顺序后确认 assert 在 debug WASM 中触发）。
- **风险**：Release build 中 `assert()` 被剥离，三个 Foundation Autoload 的 assert 守卫失效；顺序配置错误将静默产生未初始化状态。
  - **缓解**：GameBootstrap 的生产守卫使用 `if` + `push_error`（非 `assert`），在 release build 中保留；Godot 4.5+ script backtracing 确保完整调用栈可见。GameBootstrap 是进入游戏场景的唯一入口，其守卫覆盖所有三个 Foundation Autoload 的就绪状态。
- **风险**：新增 Foundation Autoload 时开发者未更新 Project Settings 顺序。
  - **缓解**：assert 守卫在 debug 首次运行时立即报错；本 ADR 和 control manifest 记录必须遵守的顺序规则。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| floor-layout-data.md | Open Questions #4：EntityDB 与 FloorDB 的启动顺序保证机制须在架构 ADR 中优先决策 | Autoload 列表顺序 [2]EntityDB < [3]FloorDB + assert 守卫 + is_initialized 标志三层保证 |
| floor-layout-data.md | Formulas section 启动顺序约束：EntityDB 加载并完成 D1/D3 校验必须先于 FloorDB | EntityDB 在列表[2]，FloorDB 在[3]；FloorDB._ready() assert(EntityDB.is_initialized) |
| floor-layout-data.md | EntityDB 未就绪防护：lookup() 返回 null 时须报 MISSING_ENTITY_TIER，不得静默通过 | assert 守卫在 FloorDB 执行 F-REF 查询前捕获 EntityDB 未就绪；配合 FloorDB 内 null 路径主动报 MISSING_ENTITY_TIER |
| entity-database.md | Dependencies section：启动顺序 EntityDB 先于 FloorDB | Autoload 列表[2] < [3] 正式确立此约束 |
| game-tuning-config.md | D1/D3 校验需要 player_ATK_expected 等参数（由 TuningConfig 提供） | TuningConfig 在列表[1]；EntityDB._ready() assert(TuningConfig.is_initialized) 后再运行 D1/D3 |
| player-stats-growth.md | 玩家初始化须读取 base_ATK/base_DEF/base_MaxHP（TuningConfig 提供） | TuningConfig 在[1]，GameBootstrap 在所有 Foundation 就绪后才加载游戏场景，确保 PlayerStats 初始化时 TuningConfig 可访问 |

## Performance Implications
- **CPU**: assert() 为 O(1)，JSON 同步加载一次性执行（< 10KB、< 5ms，MVP 3 层数据量）；无运行期开销
- **Memory**: `_initialized` 单布尔 + `database_ready` 信号，每个 Autoload 额外开销极小（< 100 bytes）
- **Load Time**: 顺序同步加载，无并行；MVP 数据量下可接受，估计总启动加载 < 50ms
- **Network**: N/A（单机，res:// 资源）

## Migration Plan
无现有代码。本 ADR 在首行代码编写前定义规范，无迁移。

## Validation Criteria
1. Project Settings > Autoloads 列表顺序：TuningConfig [1] → EntityDB [2] → FloorDB [3] → GameBootstrap [4]
2. Debug build：故意将 EntityDB 移至 FloorDB 之前 → 引擎打印 assert 错误，不进入游戏场景
3. Release build：故意调换顺序 → GameBootstrap push_error 可见，错误屏出现，不进入游戏场景
4. 导出 spike（QQ-01）：WASM/Douyin 运行时 Autoload `_ready()` 顺序与 Project Settings 一致；`change_scene_to_file()` 或 ResourceLoader 方案可正常加载游戏场景
5. GDUnit4 headless 测试：TuningConfig/EntityDB/FloorDB 均可通过 ValidationConfig/FloorValidationConfig 依赖注入独立构造，无需 Autoload 在场景树中存在

## Related Decisions
- ADR-0001（数据类型实现方案）— 定义 Foundation Autoload 暴露的类型接口；本 ADR 定义这些类型何时可用（Enabled by ADR-0001）
- ADR-0003（系统宿主：Autoload vs 节点，待写）— 本 ADR 仅定义 Foundation 层顺序；Core/Feature 系统的宿主模式由后续 ADR 决策
- design/gdd/floor-layout-data.md Open Questions #4
- design/gdd/entity-database.md Dependencies section（启动顺序：EntityDB 先于 FloorDB）
- design/gdd/game-tuning-config.md（TuningConfig 必须先于 EntityDB D1/D3 校验）
