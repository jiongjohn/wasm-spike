# Story 006: EntityDB Autoload 装配 + 启动校验集成

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: L（4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-07-01
> **Blocker (2026-07-01)**: Godot 4.5.2 实证——`class_name X` 脚本注册为同名 autoload `X` → `Parse Error: Class "X" hides an autoload singleton`。**解决方案已定于 ADR-0010（autoload 命名约定=方案①：autoload 脚本不声明 class_name、按干净全局名访问、就绪检查 `assert(Dep.is_initialized)` 无 as、测试用 preload().new()）**，并已订正 ADR-0002 模板 + ADR-0008 E-1。**ADR-0010 现为 Proposed——本 story 待其经 `/architecture-review`（全新会话）Accepted 后转 Ready 重做。**
>
> **重做清单（ADR-0010 Accepted 后）**：
> 1. `src/tuning_config/tuning_config.gd`、`src/entity/entity_db.gd`：删除 `class_name`（改 `extends Node`）
> 2. `tests/unit/tuning_config/config_type_and_loader_test.gd`（6 处）、`tests/unit/entity/entity_query_test.gd`（14 处）：`X.new()` → `preload("res://src/.../x.gd").new()`，局部变量去静态类型标注（数据类 class_name 引用、`_inject_*` 动态调用不动）
> 3. entity_db.gd 补 006 装配：`_ready`（`assert(TuningConfig != null and TuningConfig.is_initialized)` 无 as）+ `_load_and_validate`（**逐怪按 floor_first_appears 取 tuning 行校验**，005 smoke 已验证逻辑 + 反例）+ is_initialized + database_ready + `_show_error_screen`（禁 quit）+ `_tuning_override` DI seam。逻辑草稿见本会话 transcript（engine-programmer 已产出）
> 4. 注册 project.godot [autoload]：TuningConfig[1] + EntityDB[2]（无 class_name，故不再冲突）
> 5. 集成测试 `tests/integration/entity/entity_db_startup_test.gd`（AC-01 加载成功 + AC-19 校验失败不进游戏+错误屏，用 DI/场景树夹具）
> 6. 跑通后确认：`godot --headless --import` 无「hides autoload」；entity 全目录 + tuning 测试改 preload 后仍全绿
>
> 详见 ADR-0010、记忆 godot-autoload-classname-conflict。

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-001`（启动 D1/D3 校验执行，需 TuningConfig 就绪后）、`TR-entity-005`（res:// 加载）、`TR-entity-006`（校验失败显示 inline 错误屏，禁 OS.quit，WASM 兼容）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002（Autoload 启动顺序，主）；ADR-0005（JSON 加载，次）
**ADR Decision Summary**: EntityDB 为 Autoload 列表 [2]（TuningConfig[1] 之后）。`_ready()` 开头 `assert(TuningConfig.is_initialized, ...)`（类型化 `as` 转型，debug 守卫）→ 同步 `_load_and_validate()`（禁 await）→ `_initialized=true`。加载 entities.json（`FileAccess.get_file_as_string` + null-check + `is Dictionary`），用 TuningConfig 楼层参数构造 ValidationConfig 跑 validate_database。校验失败**禁 OS.quit/get_tree().quit()**，改内联代码构建错误屏节点（不依赖 .tscn）。

**Engine**: Godot 4.5.2 | **Risk**: HIGH
**Engine Notes**: ADR-0002 HIGH 风险——Autoload `_ready()` 顺序机制自 4.0 稳定，但 Douyin 适配器 VFS/事件循环行为待导出 spike（QQ-01）实测；`_load_and_validate()` **必须纯同步（禁 await）**，否则破坏顺序保证致 assert 误触发。**错误屏 WASM 运行时行为待 spike 验证**——本 story 的 headless Integration 测试验证「装配」（加错误屏节点 + 不调 quit），WASM 真机验证留 QQ-01。

**Control Manifest Rules (Foundation)**:
- Required: Autoload 顺序 EntityDB[2]；`_ready()` assert(TuningConfig.is_initialized)（类型化 as）；`is_initialized` 只读 getter；`_load_and_validate()` 纯同步；GameBootstrap 用 if+push_error 做 release 守卫；null-check + is Dictionary
- Forbidden: `_ready()`/`_load_and_validate()` 内 `await`；`OS.quit()`/`get_tree().quit()` 做校验失败退出；`DirAccess` 发现数据文件；`user://` 路径；场景节点在自身 `_ready()` 连 `database_ready` 期望收 emit
- Guardrail: 启动同步加载 < 10ms（MVP 数据量）；错误屏纯代码内联构建（不依赖 .tscn）

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md`, scoped to this story:*

- [ ] EntityDB 为 Autoload，列表顺序在 TuningConfig 之后（Project Settings）；`_ready()` 开头 `assert(TuningConfig.is_initialized)`（类型化 `as` 转型）
- [ ] `_load_and_validate()` 纯同步（无 await）：读 `res://data/entities.json`（null-check + is Dictionary）→ from_dict 构造 entries → 用 TuningConfig 楼层参数构造 ValidationConfig → 跑 validate_database；成功后 `_initialized=true`；暴露 `is_initialized: bool` 只读 getter
- [ ] **AC-01**：加载合法 MVP 数据后，`validate_database` 返回 PASS；`get_monster("slime")` 非 null 且 `hp==20`/`gold_drop==5`/`is_boss==false`；初始化期间引擎错误日志（severity≥ERROR）**0 条**
- [ ] **AC-19（装配契约，Integration）**：给一份含至少一条非法 Entry（使 validate_database `is_valid==false`）的数据 → 运行时初始化序列消费结果后**不切换到主游戏场景**；且向场景树添加可见错误屏节点（纯代码内联），**不依赖 `get_tree().quit()`**

---

## Implementation Notes

*Derived from ADR-0002 Decision + Key Interfaces:*

- 文件：`src/entity/entity_db.gd`（`class_name EntityDB extends Node`，复用 004 的查询接口 + 内部表）。Autoload 注册名 == `EntityDB`（== class_name，否则 `as` 转型静默 null）。
- `_ready()` 模板（ADR-0002 决策细则 3）：`var tuning := TuningConfig as TuningConfig; assert(tuning != null and tuning.is_initialized, "STARTUP ORDER VIOLATION: TuningConfig must be listed before EntityDB")` → `_load_and_validate()` → `_initialized=true` → `database_ready.emit()`。
- ValidationConfig 构造：从 `TuningConfig.get_tuning_config()`/`get_floor_tuning(n)` 取 `player_atk_expected`/`player_hp_expected`/`player_def_expected`/`n_max`/`hp_budget_ratio`。**每怪按其出现楼层的 expected 值验证**（GDD Open Q1；slime→floor1-2、goblin→floor2-3；实现须决定「按怪的 floor_first_appears 选楼层参数」还是「按最不利楼层」——记录选择）。
- **校验失败 → 内联错误屏**：不 `_initialized=true`；不 quit。GameBootstrap（列表最后）的 if+push_error 守卫捕获 `not EntityDB.is_initialized` → `_show_startup_error_screen()`（纯代码 Control 节点）。EntityDB 自身校验失败的呈现由 GameBootstrap 统一处理（ADR-0002 决策细则 4/5）。
- Autoload 列表须新增 EntityDB[2] + GameBootstrap（若尚未在 project.godot）；本 story 须更新 `project.godot` 的 autoload 段（TuningConfig 之后）。**注意**：GameBootstrap 完整装配（change_scene_to_file / 错误屏）可能跨 ADR-0002 的独立 story；本 story 至少接线 EntityDB 的 is_initialized + 校验失败不 quit 的契约，AC-19 用 Integration 夹具验证「不进场景 + 加错误屏节点」。
- Integration 测试用场景树夹具（GDUnit4 `ISceneRunner` 或手动 add_child）验证 AC-19；AC-01 可用「实例化 EntityDB + 注入 TuningConfig stub + 调 _load_and_validate」或全 Autoload 场景。

---

## Out of Scope

*Handled by neighbouring stories / other systems:*

- Story 001-004：类型、校验器、查询（本 story 装配它们）
- Story 005：entities.json 数据内容（本 story 加载它）
- GameBootstrap 的 `change_scene_to_file` → game.tscn 全链路（ADR-0002；若无独立 story，本 story 仅接 EntityDB 就绪契约 + 错误屏装配，主场景切换待 FloorDB/GameBootstrap story）
- WASM/Douyin 真机错误屏 + Autoload 顺序验证（导出 spike QQ-01，非本 story headless 范围）

---

## QA Test Cases

*AC-01 = Logic-style（加载后查询）；AC-19 = Integration（场景树装配）。*

- **AC-01**（加载成功全链路）
  - Setup: EntityDB 实例 + TuningConfig 就绪（真实 tuning_config.json）+ 真实 entities.json
  - When: `_load_and_validate()` 执行
  - Then: validate_database PASS；`get_monster("slime").hp==20`/`gold_drop==5`/`is_boss==false`；`is_initialized==true`；无 severity≥ERROR 日志
  - Edge cases: `assert(TuningConfig.is_initialized)` 在 TuningConfig 未就绪时（debug）触发
- **AC-19（装配契约，需场景树夹具）**
  - Setup: 注入含非法 Entry 的数据集（validate_database is_valid==false）
  - When: 运行时初始化序列消费结果
  - Verify: 不切换到主游戏场景；场景树中出现可见错误屏节点（纯代码构建）；**未调用 get_tree().quit()**（可断言场景树仍存活 + 错误屏节点存在）
  - Pass condition: EntityDB 未 `_initialized`；错误屏节点 is_inside_tree()；无 quit
- **纯同步约束**（回归）
  - Verify: grep `src/entity/entity_db.gd` 无 `await`（CI lint）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/entity/entity_db_startup_test.gd` — 须存在且通过（GDUnit4，含场景树夹具）。AC-01 部分可 headless；AC-19 需场景树。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（类型）、002+003（validate_database）、004（查询接口）、005（entities.json）；TuningConfig（已完成，列表 [1]）
- Unlocks: FloorDB（#2，列表 [3]，其 F-REF 校验调用 EntityDB 查询）；下游 #4/#5/#6/#7/#8 消费 EntityDB
