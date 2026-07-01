# ADR-0010: Autoload 命名与引用约定（Autoload 脚本不声明 class_name）

## Status
Proposed

## Date
2026-07-01

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 pinned；抖音小游戏 Compatibility/WebGL2 2D） |
| **Domain** | Core / Scripting（Autoload 单例 + 全局命名空间） |
| **Knowledge Risk** | HIGH（post-LLM-cutoff）→ **已 spike 实证消解**（2026-07-01） |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`（无相关变更）；本会话 spike 实测；godot-specialist 验证 |
| **Post-Cutoff APIs Used** | None（Autoload 全局名机制 + class_name 全局注册自 Godot 3.x 稳定；无 4.4/4.5 新 API） |
| **Verification Required** | ✅ 已验证：`class_name X` + 同名 autoload `X` → `Parse Error: Class "X" hides an autoload singleton`（spike 实测，SpikeAutoload/TuningConfig/EntityDB 皆复现）。⏳ 重做 story-006 时在 GDUnit 运行时确认：autoload 全局名访问（`EntityDB.get_monster()`）+ `preload().new()` 实例化 + 跨 autoload `_ready` 顺序 assert 守卫，均随 006 集成测试落地 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None（本 ADR 是对既有 ADR-0002/0008 的实证订正，不依赖未 Accept 的 ADR） |
| **Enables** | 所有 Autoload 实现（ADR-0002 列的 11 个：TuningConfig/EntityDB/FloorDB/PlayerStats/CombatSystem/KeyDoor/DropReward/FloorProgress/CombatForecastService/GameState/GameBootstrap） |
| **Blocks** | EntityDB story-006（Autoload 装配）——本 ADR Accepted 后方可重做；后续所有 Autoload 装配 story |
| **Ordering Note** | 订正 ADR-0002（autoload 模板）+ ADR-0008 E-1（已随本 ADR 同步修订正文，标注实证证伪）。本 ADR 须在任何 Autoload 注册进 project.godot 前 Accepted |

## Context

### Problem Statement
ADR-0002 的 Foundation Autoload 模板用 `var tuning := TuningConfig as TuningConfig`，并假设「autoload 注册名 == class_name」（ADR-0008 E-1 明确要求：「Autoload 注册名必须与 class_name 完全一致，否则 `X as X` 转型静默返回 null」）。但**在 Godot 4.5.2 实测中，这套假设不成立**：

一个带 `class_name X` 的脚本被注册为**同名** autoload `X` 时，引擎报 `Parse Error: Class "X" hides an autoload singleton`，脚本无法编译、autoload 创建失败。根因：`class_name` 在全局命名空间注册一个标识符，autoload 注册名也在全局命名空间注册一个标识符，二者同名 → 冲突。因此 `X as X`（X 既是 autoload 名又是 class 名）根本无法运行到转型那一步——ADR-0008 E-1 的结论是错的（它假设的失败模式是「静默 null」，实际是「编译错误」）。

这阻塞了 EntityDB story-006（Autoload 装配），并影响全部 11 个计划中的 Autoload。

### Constraints
- **GDD 全局访问约定**：所有 GDD 用干净单例名访问服务（`EntityDB.get_monster()`、`PlayerStats.pickup_item()`、`CombatSystem.resolve_combat()` 等）。命名约定不得破坏这些引用。
- **强类型编码规范**：项目要求强类型（`.claude/docs/coding-standards.md`）；须评估单例访问失去静态类型的代价。
- **headless 可测**（ADR-0004）：测试须能实例化这些脚本（不依赖全局 Autoload；ADR-0002 DI 原则）。
- **数据/值类不受影响**：MonsterEntry/ItemEntry/KeyEntry/CellEntry/FloorEntry/CombatResult/CombatForecast/RoundEvent/ValidationConfig/EntityValidationResult/TuningConfigData/FloorTuningRow 等**非 autoload**，保留 class_name（无冲突）。

### Requirements
- Autoload 单例可在生产代码 + GDUnit 测试运行时按名访问其属性/方法
- Autoload 脚本可在测试中实例化（绕开全局 Autoload）
- 跨 autoload 就绪检查（EntityDB._ready 检查 TuningConfig.is_initialized）可实现
- 与 GDD 的干净单例名一致

## Decision

**Autoload 节点脚本一律不声明 `class_name`；单例通过其 Project Settings 注册的干净全局名访问（与 GDD 用法一致）。**

### 决策细则

1. **Autoload 脚本无 `class_name`**：`tuning_config.gd`/`entity_db.gd`/`floor_db.gd`/… 顶部为 `extends Node`（**不写** `class_name X`）。Project Settings 的 autoload 注册名（`TuningConfig`/`EntityDB`/…）成为全局标识符，指向单例实例。

2. **单例访问 = 干净全局名，无 `as` 转型**：
   ```gdscript
   # 生产代码 / 其它系统
   var entry := EntityDB.get_monster("slime")     # EntityDB = autoload 全局名
   if not TuningConfig.is_initialized: ...
   ```
   与 GDD 用法完全一致（GDD 写的就是 `EntityDB.get_monster()`）。

3. **就绪检查（ADR-0002 模板订正）**：依赖方 `_ready()` 开头用全局名直接 assert，**不用 `as X` 转型**：
   ```gdscript
   func _ready() -> void:
       assert(TuningConfig != null and TuningConfig.is_initialized,
           "STARTUP ORDER VIOLATION: TuningConfig must be listed before EntityDB in Project Settings > Autoloads")
       _load_and_validate()
       _initialized = true
       database_ready.emit()
   ```
   GameBootstrap 的 release 守卫同理用 `if TuningConfig == null or not TuningConfig.is_initialized ...`（无 `as`）。

4. **数据/值类保留 class_name**：非 autoload 的类型（MonsterEntry 等）继续用 `class_name + Resource/RefCounted`（ADR-0001）——它们不注册为 autoload，无冲突。返回类型标注（如 `func get_monster(id) -> MonsterEntry`）不受影响，静态类型保留。

5. **测试实例化用 `preload().new()`**：测试不依赖全局 Autoload（ADR-0002 DI 原则），用 preload 构造 autoload 脚本实例：
   ```gdscript
   var db = preload("res://src/entity/entity_db.gd").new()   # 局部变量无静态类型标注
   db._inject_entries_for_test(...)                            # 动态方法调用正常
   ```
   `_inject_*_for_test` 保持 debug 守卫（`assert(OS.is_debug_build())` + release push_error）。

6. **静态类型代价（明确接受）**：单例访问（`EntityDB.foo()`）与 `preload().new()` 的局部变量**失去编译期静态类型检查**（方法仍动态解析、运行正常）。这是 Godot 单例的通行取舍。**数据类型、纯函数类、校验器等仍全静态类型**——只有 autoload 单例访问点失去。

### Architecture Diagram

```
Project Settings > Autoloads（干净名，脚本无 class_name）:
  [1] TuningConfig  = res://src/tuning_config/tuning_config.gd   (extends Node，无 class_name)
  [2] EntityDB      = res://src/entity/entity_db.gd              (extends Node，无 class_name)
  [3] FloorDB       = ...
  ...
        │ 全局名指向单例实例
        ▼
  生产/其它系统：EntityDB.get_monster("slime")   ← 与 GDD 一致，动态解析
  就绪检查：       assert(TuningConfig.is_initialized)  ← 无 as 转型

数据/值类（非 autoload，保留 class_name + 静态类型）:
  MonsterEntry / ItemEntry / ... / EntityValidationResult   ← func get_monster() -> MonsterEntry 静态类型不受影响

测试（不依赖全局 Autoload）:
  var db = preload("res://src/entity/entity_db.gd").new()   ← 无静态类型，动态调用
```

### Key Interfaces

```gdscript
# ── Autoload 脚本骨架（无 class_name）──
# src/entity/entity_db.gd
extends Node   # ← 不写 class_name EntityDB

var _initialized: bool = false
var is_initialized: bool:
    get: return _initialized
signal database_ready

func _ready() -> void:
    assert(TuningConfig != null and TuningConfig.is_initialized,
        "STARTUP ORDER VIOLATION: TuningConfig must be listed before EntityDB")
    _load_and_validate()   # 纯同步，禁 await（ADR-0002）
    _initialized = true
    database_ready.emit()

# 单例访问 TuningConfig 参数（返回的 TuningConfigData 仍是静态类型）:
#   var cfg: TuningConfigData = TuningConfig.get_tuning_config()
```

## Alternatives Considered

### Alternative 1: 保持 class_name，autoload 注册同名（原 ADR-0002/0008 E-1 方案）
- **Description**: 脚本 `class_name EntityDB`，autoload 也注册为 `EntityDB`，用 `EntityDB as EntityDB` 转型。
- **Pros**: 若可行则单例访问有静态类型。
- **Cons**: **在 Godot 4.5.2 编译失败**（`Class "EntityDB" hides an autoload singleton`，spike 实证）。根本无法运行。
- **Rejection Reason**: 引擎硬性禁止 class_name 与 autoload 同名。ADR-0008 E-1 的前提错误。

### Alternative 2: class_name 与 autoload 异名（如 class `EntityDbNode` + autoload `EntityDB`）
- **Description**: 脚本 `class_name EntityDbNode`，autoload 注册为干净名 `EntityDB`；测试用 `var db: EntityDbNode = preload(...).new()` 保静态类型；生产用 `EntityDB.foo()`。
- **Pros**: 保留测试端静态类型标注 + IDE 补全；不破坏 GDD 干净名；不冲突。
- **Cons**: 每个 autoload 有「class 名 vs 单例名」双名，认知分裂；团队须记住「注册名 != class_name」惯例；ADR/GDD 引用须明确区分。
- **Rejection Reason**: 用户裁定（2026-07-01）优先「无 class_name 的简洁 + 惯用」而非保留单例访问的静态类型；单例访问失去静态类型是 Godot 通行取舍，可接受。**若未来团队认为测试静态类型重要，可低成本切到本方案（仅加异名 class_name + 测试改类型标注），不影响 GDD/生产代码。** godot-specialist 亦将此列为可选优化。

### Alternative 3: 不用 Project Settings Autoload，改 GameBootstrap 手动实例化 + DI
- **Description**: TuningConfig/EntityDB 等为普通 `class_name` 类（不注册 autoload），由单一 GameBootstrap 构造并注入下游。
- **Pros**: 无 class_name 冲突；全静态类型；初始化顺序显式。
- **Cons**: 与 ADR-0002 已 Accepted 的 Autoload 顺序方案冲突；与 GDD 多处 `EntityDB.foo()` 全局访问假设冲突；下游须 DI 传递引用，接口复杂度上升。
- **Rejection Reason**: ADR-0002 Alternative 2 已否决同类方案；GDD 全局访问约定已铺开；改动面过大。

## Consequences

### Positive
- 与 Godot 惯用模式一致（autoload 脚本通常不带 class_name）
- 单例访问名与 GDD 完全一致（`EntityDB.get_monster()`），无重映射
- 就绪检查更简洁（`assert(Dep.is_initialized)`，无 `as` 转型样板）
- 数据/值类、纯函数、校验器全部保留静态类型（不受影响）
- 解锁 story-006 + 全部 Autoload 装配

### Negative
- Autoload 单例访问点 + `preload().new()` 局部变量**失去编译期静态类型检查**（方法仍动态解析、运行正常）——Godot 单例通行取舍
- 现有 `TuningConfig`/`EntityDB` 须去掉 class_name；测试 `.new()` 须改 `preload().new()`（tuning 测试 6 处、entity query 测试 14 处；数据类不动）
- 团队须知晓约定：**autoload 脚本不写 class_name**（否则重蹈同名冲突）——已写入 control-manifest

### Risks
- **风险**：开发者给新 autoload 脚本误加 class_name（与注册名同名）→ 编译错误。
  - **缓解**：control-manifest Foundation 规则明确「autoload 脚本禁 class_name」；CI 可 grep `src/**/(autoload脚本)` 的 class_name。首次注册即报错，debug 立即暴露。
- **风险**：单例访问失去静态类型 → 拼写错误/错误方法名运行时才暴露。
  - **缓解**：单例接口稳定、少变；集成测试覆盖启动路径；必要时未来切 Alternative 2 恢复类型。
- **风险**：`preload().new()` 的 autoload 实例在测试中 `_ready()` 可能触发（若加入场景树）→ 引用其它未注册 autoload 而崩（story-006 已遇）。
  - **缓解**：测试用 DI（`_inject_*_for_test` / `_tuning_override`）绕开 `_ready` 的全局依赖；测试若不加入场景树则 `_ready` 不触发。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| entity-database.md | 接口约定：`EntityDB.get_monster(id)` 等全局单例访问 | 方案① autoload 用干净全局名 `EntityDB`，与 GDD 写法一致 |
| game-tuning-config.md | `TuningConfig.get_tuning_config()` 全局只读访问 | 同上，`TuningConfig` 干净全局名 |
| （全局，ADR-0002/0003） | 11 个 Autoload 的 `_ready` 就绪顺序 + is_initialized | 就绪检查用全局名 assert（无 as），顺序保证由 Project Settings 列表（4.5.2 已证） |

## Performance Implications
- **CPU**: 无（命名/引用约定，不改运行期行为）。全局名单例访问与 `as` 转型访问性能等价。
- **Memory**: 无。
- **Load Time**: 无。
- **Network**: N/A。

## Migration Plan
1. `src/tuning_config/tuning_config.gd`、`src/entity/entity_db.gd`：删除 `class_name` 声明（改 `extends Node`）。
2. `tests/unit/tuning_config/config_type_and_loader_test.gd`（6 处）、`tests/unit/entity/entity_query_test.gd`（14 处）：`X.new()` → `preload("res://src/.../x.gd").new()`，局部变量去静态类型标注。数据类 class_name 引用、`_inject_*` 动态调用不动。
3. 订正 ADR-0002 Key Interfaces（去 `as X`，用全局名 assert）+ ADR-0008 E-1（标实证证伪，指向本 ADR）。
4. 重新生成 control-manifest（加「autoload 脚本禁 class_name」规则）。
5. 重做 story-006（EntityDB Autoload 装配）：逻辑草稿已备（逐楼层 D1/D3 校验 + 内联错误屏 + `_tuning_override` DI seam），按本约定调 `_ready` 引用 + 注册 project.godot autoload。

## Validation Criteria
1. ✅ 已验证：`class_name X` + 同名 autoload `X` → 编译错误（spike）。
2. ⏳ story-006：注册 TuningConfig[1]+EntityDB[2]（无 class_name）后 `godot --headless --import` 无「hides autoload」错误。
3. ⏳ story-006 集成测试：GDUnit 运行时 `EntityDB.get_monster("slime")`（若走 autoload）或 `preload().new()` + `_inject`（DI）正常；`_ready` 中 `assert(TuningConfig.is_initialized)` 在正确顺序下通过。
4. 现有 123 entity 测试 + tuning 测试改 preload 后仍全绿。
5. CI lint：autoload 脚本（project.godot [autoload] 段引用的 .gd）中无 `class_name`。

## Related Decisions
- ADR-0002（Autoload 启动顺序）— 本 ADR 订正其 autoload 模板的 `as X` 转型写法（改全局名 assert）；顺序机制不变
- ADR-0008（CombatForecast 拆分）— 本 ADR **证伪并订正其 E-1 条**（「autoload 名必须==class_name」在 4.5.2 是编译错误，非静默 null）
- ADR-0001（数据类型）— 数据/值类保留 class_name，不受本 ADR 影响
- ADR-0003（系统宿主）— 13 系统的 Autoload/Scene Node 分类不变，仅 Autoload 的命名约定由本 ADR 定
- 记忆 `godot-autoload-classname-conflict`；EntityDB story-006 Blocker
