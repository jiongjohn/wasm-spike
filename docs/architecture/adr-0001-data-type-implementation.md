# ADR-0001: 数据类型实现方案 (Data Type Implementation Strategy)

## Status
Accepted

## Date
2026-06-25（Revised 2026-06-29 — 载体 RefCounted → Resource）

## Revision Note (2026-06-29)

**载体修正：`RefCounted` → `Resource`。** spike 在 Godot 4.6.3 headless 实证：纯 `RefCounted` 既无 `duplicate()` 也无 `duplicate_deep()`（`has_method` 均返回 false），原方案「getter 返回 `duplicate()` 副本」的只读契约运行时必崩（`Nonexistent function 'duplicate' in base 'RefCounted'`）；`Resource`（本身 extends Resource）两者皆有，`duplicate_deep()` 深拷贝独立性验证通过。修订时尚无任何代码实现（无 `src/`、无 `project.godot`），故**就地修正**而非 supersede。原 2026-06-25 的 RefCounted 选择已下移至 Alternatives Considered（被实证否决）。证据：`prototypes/wasm-export-spike/RUNBOOK.md §5b` + `prototypes/wasm-export-spike/verify_dup.gd`。
>
> **补充实证（同日 verify_dup2/verify_dup3）**：仅改载体为 Resource **不够**——`duplicate()`/`duplicate_deep()` **只拷贝 `@export` 属性**，plain `var` 字段不进 STORAGE，副本里会被重置为默认值（plain `var hp` 的副本 `hp=0`；plain `var grid` 的副本为空数组）。因此**所有数据字段必须 `@export`**（见决策细则 5）。`@export` 后标量保留、嵌套 `Array[[Resource]]` 正确深拷贝、独立性通过。

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM → 已实证消解（`duplicate()`/`duplicate_deep()` 为 `Resource` 方法；`RefCounted` 无此二者——2026-06-29 spike 实测确认）|
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md`、`docs/engine-reference/godot/current-best-practices.md`；`prototypes/wasm-export-spike/verify_dup.gd`（实测） |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep()`（4.5+，嵌套深拷贝）+ `Resource.duplicate()`。注：`RefCounted` 无此二方法，故载体定为 `Resource` |
| **Verification Required** | ✅ 桌面实测（2026-06-29）：`Resource.duplicate_deep()` 深拷贝独立性通过、`RefCounted` 无 duplicate*。仍须导出 spike 确认其在 WASM/Douyin 运行时行为一致（QQ-01）；嵌套 `Array[Array[CellEntry]]` 深拷贝正确性须单测 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None（Foundation 层首个 ADR）|
| **Enables** | ADR-0002（启动顺序）、ADR-C001/C002（系统宿主）、所有系统实现 |
| **Blocks** | 所有 MVP 系统实现 epic（#1–#5）— 数据类型未定则无法编写强类型代码 |
| **Ordering Note** | 必须是第一个被 Accepted 的 ADR；所有系统的公共接口签名依赖此决策 |

## Context

### Problem Statement
5 个已批准 GDD 引用了 8 个跨模块数据类型——静态数据类型（`MonsterEntry`/`ItemEntry`/`KeyEntry`/`FloorEntry`/`CellEntry`，从 JSON 加载）和运行时结算类型（`CombatResult`/`CombatForecast`/`RoundEvent`，纯函数产出）。所有 GDD 均将这些类型的实现载体推迟到「架构阶段 ADR」。在 GDScript 强类型要求下，类型未定则任何依赖这些类型的代码都无法开始，且 AC 的类型断言无法编写。

### Constraints
- **项目编码规范**：所有公共 API 必须强类型（`.claude/docs/coding-standards.md`）；禁止 untyped Dictionary 作为公共接口
- **WASM/低端设备**：256MB 内存上限，避免不必要的对象分配和深拷贝开销
- **headless 可测**：纯函数类型（CombatForecast/RoundEvent）必须能在无场景树的 GDUnit4 测试中构造和断言
- **只读契约**：EntityDB/FloorDB/TuningConfig 是只读数据源，getter 返回值被下游误写不得污染权威数据（AC-FL-13、AC-TC-13）

### Requirements
- 支持 JSON 反序列化（静态数据从 `res://data/*.json` 加载）
- 支持纯函数构造（运行时结算类型由 forecast/sequence 函数 new 出来）
- 强类型字段访问，编译期捕获键名错误
- 跨文件可引用（#11 渲染层须能引用 `RoundEvent` 类型作为信号参数文档）
- 只读副本防污染

## Decision

**全部 8 个数据类型统一使用 `class_name + RefCounted` 子类实现。** 禁止使用 `Dictionary` 或 `Resource` 作为这些类型的载体。

### 决策细则

1. **统一载体 = `class_name + Resource`**
   - 静态数据类型（MonsterEntry/ItemEntry/KeyEntry/FloorEntry/CellEntry）与运行时结算类型（CombatResult/CombatForecast/RoundEvent）使用同一载体，无双载体认知负担。
   - 选 `Resource` 而非 `RefCounted`：**`RefCounted` 在 Godot 4.6.3 既无 `duplicate()` 也无 `duplicate_deep()`（2026-06-29 spike 实证），无法承载本 ADR 的只读副本契约；`Resource`（本身 extends Resource）两者皆有。**
   - **不引入 `.tres` 磁盘/缓存语义**：所有数据均用 `.new()` + `from_dict()` 从 JSON 构造，从不经 `.tres` 或 `ResourceLoader.load()`，因此不产生 `resource_path`、不进 ResourceLoader 共享缓存——原先担心的 Resource 缓存别名/磁盘语义在 JSON 构造路径下不发生。

2. **只读强制 = 返回副本**
   - EntityDB/FloorDB 的 getter 返回 `.duplicate()` 或 `.duplicate_deep()` 副本，下游对副本的写入只污染副本，不触及权威数据源。
   - 不使用「计算属性守卫」作为这些数据类型的只读机制（守卫无法保护对象内嵌套字段，且反射路径可绕过）。注：PlayerStats 的 ATK/DEF 标量仍用计算属性 getter（见 #4 GDD，那是标量不是对象，属不同场景）。

3. **拷贝深度 = 按结构选择**
   - **扁平结构**（MonsterEntry/ItemEntry/KeyEntry/CombatResult/CombatForecast/RoundEvent）：无嵌套 RefCounted 字段，用 `duplicate()`（浅拷贝足够）。
   - **嵌套结构**（FloorEntry，含 `grid: Array[Array[CellEntry]]`）：用 `duplicate_deep()`（Godot 4.5+），确保 grid 内每个 CellEntry 都是独立副本，下游写入 cell 不污染数据库。

4. **强类型字段**：所有数组字段使用 `Array[Type]`（如 `Array[RoundEvent]`、`Array[Array[CellEntry]]`），所有字段显式类型标注。

5. **所有数据字段必须 `@export`**（2026-06-29 实证强制约束）：`Resource.duplicate()`/`duplicate_deep()` 只拷贝带 `PROPERTY_USAGE_STORAGE` 的属性，`@export` 提供该标志；**plain `var` 字段不被拷贝**，副本中重置为默认值（标量→0/""，数组→空）。因此 8 个数据类型的每个数据字段都必须写 `@export var`，否则只读副本契约失效（getter 返回空副本）。CI lint 须 grep 确认数据类型类中无裸 `var`（计算属性 getter 除外）。

### Architecture Diagram

```
res://data/*.json
    ↓ JSON.parse → 反序列化构造器
┌─────────────────────────────────────────────┐
│  静态数据类型 (class_name + Resource)       │
│  MonsterEntry · ItemEntry · KeyEntry          │  ← duplicate() 浅拷贝
│  FloorEntry (含 grid) · CellEntry             │  ← FloorEntry 用 duplicate_deep()
└─────────────────────────────────────────────┘
    ↓ EntityDB/FloorDB getter 返回副本
┌─────────────────────────────────────────────┐
│  运行时结算类型 (class_name + Resource)     │
│  CombatResult · CombatForecast · RoundEvent   │  ← new() 构造，duplicate() 浅拷贝
└─────────────────────────────────────────────┘
    ↓ 作为返回值 / 信号参数文档类型
下游系统（强类型引用）
```

### Key Interfaces

```gdscript
# ── 静态数据类型 ──
# ⚠️ 所有字段必须 @export：Resource.duplicate()/duplicate_deep() 只拷贝 @export 属性；
#    plain `var` 字段不进 STORAGE，副本里会被重置为默认值（2026-06-29 spike verify_dup3 实证）。
class_name MonsterEntry extends Resource:
    @export var entity_type: int    # MONSTER
    @export var id: String
    @export var hp: int
    @export var atk: int
    @export var defense: int        # 注：不用 def（GDScript 保留字）
    @export var gold_drop: int
    @export var is_boss: bool
    @export var rare_drop_item_id: String   # "" 表示无
    # ... (完整字段见 #1 GDD 规则 C3)

class_name ItemEntry extends Resource:
    @export var entity_type: int    # ITEM
    @export var id: String
    @export var effect_type: int    # HP_RESTORE/ATK_BOOST/DEF_BOOST/MAXHP_BOOST/FRAGMENT/KEY
    @export var effect_value: int
    @export var stack_rule: int     # ADDITIVE/HIGHEST_WINS

class_name KeyEntry extends Resource:
    @export var entity_type: int    # KEY
    @export var id: String
    @export var key_color: int      # YELLOW/BLUE
    @export var opens_door_color: int

class_name CellEntry extends Resource:
    @export var cell_type: int      # EMPTY/WALL/ENTITY/DOOR/STAIR_UP/STAIR_DOWN/PLAYER_START
    @export var entity_id: String   # ENTITY 格用
    @export var door_color: int     # DOOR 格用
    @export var target_floor_id: String  # STAIR 格用

class_name FloorEntry extends Resource:
    @export var floor_id: String
    @export var floor_number: int
    @export var grid: Array  # Array[Array[CellEntry]] — 16×16，用 duplicate_deep()（须 @export 才会深拷贝）

# ── 运行时结算类型 ──
class_name CombatResult extends Resource:
    @export var result: int                  # WON=0 / LOST=1
    @export var monster_id: String
    @export var n_rounds: int
    @export var actual_rounds_played: int
    @export var total_damage_to_player: int

class_name CombatForecast extends Resource:
    @export var n_rounds: int
    @export var total_damage_to_player: int
    @export var player_survives: bool
    @export var predicted_hp_after: int

class_name RoundEvent extends Resource:
    @export var round_index: int
    @export var dmg_to_monster: int
    @export var monster_hp_remaining: int
    @export var dmg_to_player: int
    @export var player_hp_remaining: int

# ── 只读 getter 返回副本模式 ──
# EntityDB:
func get_monster(id: String) -> MonsterEntry:
    var entry = _monsters.get(id)
    return entry.duplicate() if entry else null   # 扁平结构浅拷贝

# FloorDB:
func get_floor(floor_id: String) -> FloorEntry:
    var entry = _floors.get(floor_id)
    return entry.duplicate_deep() if entry else null  # 嵌套 grid 深拷贝（4.5+）
```

## Alternatives Considered

### Alternative 1: Dictionary
- **Description**: 所有数据类型用 untyped `Dictionary`，键名字符串访问。
- **Pros**: 反序列化零样板（JSON.parse 直接产出 Dictionary）；构造灵活。
- **Cons**: 键名拼写错误运行时才暴露；违反项目强类型编码规范；AC 类型断言无法编译期验证；信号参数无法标注类型；#11 等下游系统无法引用 RoundEvent 类型。
- **Rejection Reason**: 直接违反 `.claude/docs/coding-standards.md` 的「禁止 untyped Dictionary 作为公共接口」与「强类型」要求。

### Alternative 2: 全 RefCounted 统一载体（原 2026-06-25 决策 — 2026-06-29 实证否决）
- **Description**: 8 个类型统一用 `class_name + RefCounted`，getter 返回 `.duplicate()`/`.duplicate_deep()` 副本。这是本 ADR 2026-06-25 的初始决策。
- **Pros**: RefCounted 比 Resource 略轻；无 `resource_path`/缓存语义。
- **Cons**: **致命：`RefCounted` 在 Godot 4.6.3 没有 `duplicate()` 也没有 `duplicate_deep()`（`has_method` 均 false，2026-06-29 spike 实证）。** getter 返回副本的只读契约在此载体上根本无法实现，`MonsterEntry.new().duplicate()` 运行时报 `Nonexistent function`。
- **Rejection Reason**: 只读副本契约（本 ADR 核心 + forbidden_pattern `return_internal_reference_from_readonly_source`）依赖 duplicate/duplicate_deep，而 RefCounted 不提供。实证：`prototypes/wasm-export-spike/verify_dup.gd`。

### Alternative 3: 静态数据用 Resource、结算类型用 RefCounted（双载体）
- **Description**: 仅需从 DB getter 返回只读副本的静态数据（MonsterEntry/ItemEntry/KeyEntry/FloorEntry/CellEntry）用 Resource；每次 new 新建、无需副本的结算类型（CombatResult/CombatForecast/RoundEvent）保留 RefCounted。
- **Pros**: 技术上最精准——只有需要 duplicate 的类型用 Resource，结算类型保持 RefCounted 轻量。
- **Cons**: 重新引入双载体认知负担（违背决策细则 1 的「统一载体」初衷）；实现者须记忆哪类是哪种载体；结算类型 ~10 个/次的 Resource 开销本就可忽略，分裂收益甚微。
- **Rejection Reason**: 统一 Resource 保留「单载体、无认知负担」的原始卖点；Resource 相对 RefCounted 的额外开销（resource_path 等基类字段）对 MVP 数据量可忽略。

## Consequences

### Positive
- 强类型字段访问，键名错误编译期捕获，符合编码规范
- 单一载体，无双类型认知负担
- 跨文件可引用（class_name 全局可见），信号参数和返回值可强类型标注
- headless 可测：结算类型可直接 `RoundEvent.new()` 构造，无需场景树
- 返回副本模式简单可靠，AC-FL-13/AC-TC-13 直接可验证
- 无 .tres 磁盘开销，WASM bundle 更小

### Negative
- 反序列化需要手写 JSON→Resource 的构造器（相比 Dictionary 多一层样板代码）
- getter 每次返回副本有拷贝开销（扁平结构极小；FloorEntry 深拷贝 16×16=256 格须注意调用频率）
- `Resource` 比 `RefCounted` 略重（含 `resource_path`/`resource_name` 等基类字段）；但 JSON 构造路径无 .tres/无缓存，仅为基类常数内存，对 MVP 数据量可忽略
- 静态数据无法用 Godot Inspector 可视化编辑（数据源是 JSON，不创建 .tres）

### Risks
- **风险**：`Resource.duplicate_deep()` 是 4.5+ API，在 WASM/Douyin 运行时行为未验证（桌面已验证，2026-06-29）。
  - **缓解**：桌面实测已确认深拷贝独立性（`prototypes/wasm-export-spike/verify_dup.gd`）；导出 spike（QQ-01）须再确认 WASM/Douyin 运行时一致性；单测覆盖「修改返回的 grid 不污染数据库」。
- **风险**：FloorDB.get_floor() 频繁调用导致 256 格深拷贝累积开销。
  - **缓解**：#6 网格移动应优先用 get_cell()（单格浅拷贝）而非反复 get_floor()；get_floor() 仅在楼层切换时调用。在 #6 GDD 设计时明确此调用模式。
- **风险**：手写反序列化构造器遗漏字段或类型转换错误（如 JSON number 默认 float，int 字段需显式转型）。
  - **缓解**：反序列化器须对每个 int 字段显式 `int()` 转型；EntityDB/FloorDB 启动校验（D1/D3、F-G*）会捕获缺失/非法字段。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| entity-database.md (#1) | TR-entity-002 只读访问返回 duplicate() 副本；规则 C7 只读原则 | MonsterEntry/ItemEntry/KeyEntry 用 RefCounted；getter 返回 duplicate() 浅拷贝 |
| floor-layout-data.md (#2) | TR-floor-003 get_cell/get_floor 返回只读副本；AC-FL-13 写入不污染数据库 | FloorEntry/CellEntry 用 RefCounted；get_floor 用 duplicate_deep()（嵌套 grid），get_cell 用 duplicate() |
| game-tuning-config.md (#3) | TR-tuning-001 get_tuning_config 只读 | TuningConfigData/FloorTuningRow 用 RefCounted + 返回副本（同模式）|
| player-stats-growth.md (#4) | TR-stats-007 ATK/DEF 只读 getter | （标量用计算属性 getter，非本 ADR 对象类型；本 ADR 不覆盖标量，仅声明边界）|
| combat-system.md (#5) | TR-combat-007 CombatResult/Forecast/RoundEvent 强类型类；接口约定「class_name + RefCounted，禁用 Dictionary」 | 三个结算类型统一 RefCounted；每次调用 new 新实例不复用共享引用 |

## Performance Implications
- **CPU**: 扁平 duplicate() 开销极小（<1µs/次）；FloorEntry.duplicate_deep() 256 格约数十µs，仅楼层切换时触发，可接受
- **Memory**: RefCounted 引用计数自动回收；返回副本短生命周期，无泄漏风险；比 Resource 轻
- **Load Time**: 手写反序列化在启动时一次性执行，3 层 MVP 数据量极小（<10KB JSON）
- **Network**: N/A（单机）

## Migration Plan
无现有代码。本 ADR 是首个 ADR，定义全新实现规范，无迁移。
（2026-06-29 修订：载体 `RefCounted → Resource`，修订时仍无任何实现代码，无迁移成本——本修正在首行实现代码之前完成。）

## Validation Criteria
0. ✅ 已验证（2026-06-29 spike）：`Resource.duplicate_deep()` 深拷贝独立性通过；`RefCounted` 无 `duplicate()`/`duplicate_deep()`——载体故定为 `Resource`
0b. ✅ 已验证（2026-06-29 verify_dup3）：plain `var` 字段不被 duplicate 拷贝（副本重置默认值）；**所有字段须 `@export`**（决策细则 5）。CI lint：数据类型类中无裸 `var` 数据字段（spike harness P3-4c 实测 @export 后独立性 PASS）
1. AC-FL-13 通过：对 get_cell() 返回值写入后，再次 get_cell() 数据未变
2. AC-TC-13 通过：对 get_tuning_config() 返回值写入后，再次查询数据未变
3. 新增单测：修改 get_floor() 返回的 grid[r][c]，验证数据库内 grid 不变（duplicate_deep 正确性）
4. 所有 8 个类型可在 GDUnit4 headless 模式下 new() 构造并断言字段
5. CI lint：grep 确认公共接口签名无 untyped Dictionary 返回类型

## Related Decisions
- ADR-0002（Autoload 启动顺序）— 依赖本 ADR 定义的类型
- ADR-0005（数据文件组织）— 定义 JSON 结构，反序列化器据此构造本 ADR 的类型
- design/gdd/combat-system.md「数据类型实现约定」节
- design/gdd/floor-layout-data.md AC-FL-13、Open Questions #2
- design/gdd/game-tuning-config.md Open Questions #2
