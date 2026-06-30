# Control Manifest

> **Engine**: Godot 4.5.2（Compatibility 后端 / WebGL2，2D，抖音小游戏 WASM；2026-06-30 re-pinned from 4.6.3）
> **Last Updated**: 2026-06-29
> **Manifest Version**: 2026-06-29
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0008（部分 Accept — 结构决策）
> **Status**: Active — ADR 变更时用 `/create-control-manifest update` 重新生成

`Manifest Version` 是本手册生成日期。story 文件创建时嵌入此日期；`/story-readiness` 比对 story 嵌入版本与本字段以检测"基于陈旧规则写的 story"。与 `Last Updated` 同值,服务不同消费者。

本手册是程序员速查表,从所有 Accepted ADR、技术偏好、引擎参考中提取。每条规则的"为什么"见所引 ADR。

> **未纳入(Pending ADR)**:ADR-0007（WASM 导出，Proposed/spike-gated）、ADR-0009（GridMovement TileMapLayer 静态底 + 池化覆盖节点，Proposed）的规则**暂未纳入**——待其转 Accepted 后重新生成。详见本手册末尾「Pending ADR 提示」。

---

## Foundation Layer Rules

*适用于：游戏实体数据库、楼层关卡数据、调参配置、Autoload 启动/初始化、数据文件加载*

### Required Patterns
- **全部 8 个跨模块数据类型用 `class_name + Resource` 子类**（MonsterEntry/ItemEntry/KeyEntry/FloorEntry/CellEntry/CombatResult/CombatForecast/RoundEvent）— source: ADR-0001
- **数据类型的每个数据字段必须 `@export var`** — `Resource.duplicate()/duplicate_deep()` 只拷贝 @export（STORAGE）属性；plain `var` 字段在副本中重置为默认值（标量→0/""、数组→空）。2026-06-29 spike 实证 — source: ADR-0001（决策细则 5）
- **只读数据源 getter 返回副本**：扁平结构 `.duplicate()`；嵌套（FloorEntry.grid: `Array[Array[CellEntry]]`）用 `.duplicate_deep()`（4.5+） — source: ADR-0001
- **JSON 数值字段反序列化显式 `int()` 转型**（`JSON.parse_string()` 把整数解析为 float） — source: ADR-0005
- **enum 字段在 JSON 用字符串名 + 反序列化器维护 字符串→int 映射表** — source: ADR-0005
- **数据打包进 `res://` JSON**，`FileAccess.get_file_as_string()` 读取；楼层用 `manifest.json` 清单发现 — source: ADR-0005
- **`JSON.parse_string()` 返回值先 null-check + `is Dictionary` 再使用**（文件缺失时 `get_file_as_string` 返回 ""，`parse_string("")` 返回 null） — source: ADR-0005
- **必填字段缺失 → `push_error` + 返回 `null`**（不可只靠 assert[release 被剥离]，不可填默认值；AC-09） — source: ADR-0005
- **Autoload 列表顺序固定**：`TuningConfig[1] → EntityDB[2] → FloorDB[3] → PlayerStats[4] → CombatSystem[5] → KeyDoor[6] → DropReward[7] → FloorProgress[8] → CombatForecastService[9] → GameState[10] → GameBootstrap[11]`（GameBootstrap 始终最后） — source: ADR-0002, ADR-0003, ADR-0008
- **每个 Autoload 暴露 `is_initialized: bool`（只读 getter），`_ready()` 末尾成功后置 true** — source: ADR-0002
- **依赖方 `_ready()` 开头 `assert(dep != null and dep.is_initialized, "...")`（debug 守卫，类型化 `as` 转型）** — source: ADR-0002
- **GameBootstrap 用 `if + push_error`（非 assert）做 release 守卫 + 内联错误屏** — source: ADR-0002
- **`_load_and_validate()` 必须纯同步** — source: ADR-0002

### Forbidden Approaches
- **禁止裸 `RefCounted` 作数据类型载体** — RefCounted 在 4.6.3 无 `duplicate()`/`duplicate_deep()`，只读副本契约无法实现（spike 实证）— source: ADR-0001
- **禁止 plain `var`（非 @export）数据字段** — duplicate* 不拷贝 → 副本为空，静默数据丢失 — source: ADR-0001
- **禁止 untyped `Dictionary` 作公共接口**（getter 返回值/信号参数/跨模块签名） — source: ADR-0001
- **禁止只读数据源 getter 返回内部原始引用**（必须返回副本，防污染权威数据） — source: ADR-0001
- **禁止用 `def` 作字段名**（GDScript 保留字）→ 用 `defense`；JSON 键同步 — source: ADR-0005, ADR-0001
- **禁止 `.tres` Resource 文件**作这些数据类型的载体（.tres 对缺失字段静默填默认，违反 AC-09 可检测性） — source: ADR-0005
- **禁止 `DirAccess.get_files_at()` 等目录枚举发现数据文件**（WASM PCK VFS 不返回目录列表，静默失败）→ 用 manifest.json — source: ADR-0005
- **禁止 `user://` 路径存数据**（WASM 首启 IndexedDB 可能为空） — source: ADR-0005
- **禁止 `_load_and_validate()` / Foundation `_ready()` 内出现 `await`**（推迟到下一帧 → 破坏 Autoload 顺序保证，assert 守卫在前置未就绪时误触发） — source: ADR-0002
- **禁止场景节点在自身 `_ready()` 中连接 Foundation `database_ready` 信号后期望收到 emit**（信号在场景节点 _ready 前已发出）→ 用 `is_initialized` 标志轮询 — source: ADR-0002

### Performance Guardrails
- 启动校验失败 **禁用 `OS.quit()` / `get_tree().quit()`**（WASM 容器内可能静默冻结）→ 内联代码构建可见错误屏，不依赖 .tscn — source: ADR-0002

---

## Core Layer Rules

*适用于：玩家属性与成长、确定性战斗、网格移动逻辑、钥匙门、宿主架构*

### Required Patterns
- **宿主分类调节面**：① 持有跨楼层状态、② 无状态服务且 ≥3 消费者、③ 无场景树需求 → **Autoload**；① 渲染、② 管理可见子节点、③ 按帧视觉更新、④ 处理触控 → **Scene Node**。破平规则：持有跨楼层状态 → 强制 Autoload — source: ADR-0003
- **13 系统宿主分类**：Autoload = PlayerStats / CombatSystem / KeyDoor / DropReward / FloorProgress / GameState / CombatForecastService；Scene Node = GridMovement / HUD / NumberFeedback / CombatForecastOverlay — source: ADR-0003, ADR-0008
- **Scene Node → Autoload = 直接方法调用**（类型化 `as` 转型）；**Autoload → Scene Node = 信号**（Scene Node 在自身 `_ready()` 连接） — source: ADR-0003
- **`generate_round_sequence(6 int) -> Array[RoundEvent]`（强类型 typed array）** — source: ADR-0006
- **`forecast_combat` 实现必须内部委托 `generate_round_sequence` 取末态**（不得另写并行数学路径） — source: ADR-0006
- **战斗状态机 = 私有 `enum _CombatState { NO_COMBAT, RESOLVING, VICTORY, DEFEAT }` + `resolve_combat()` 入口重入守卫**（重入 → `push_error` + 返回 `null`，调用方须检查 null） — source: ADR-0006
- **`resolve_combat(monster_id: String)` 同步完成，无 `await`** — source: ADR-0003, ADR-0006
- **Victory 发 `combat_won` 后即时回转 NO_COMBAT（同步帧内）；Defeat 发 `combat_lost` 后冻结，等 `GameState.reset_for_new_game()` 清除** — source: ADR-0006
- **`PlayerStats.pickup_item(item_id: String)` / `resolve_combat(monster_id: String)` 单参签名**（EntityDB 查找在内部执行） — source: ADR-0003

### Forbidden Approaches
- **禁止战斗结算中出现任何 RNG**：`randf` / `randi` / `randf_range` / `randi_range` / `RandomNumberGenerator` / `seed()`，**亦不得通过依赖注入传入 RNG** — 零随机数是 P2 硬约束（CI grep 验证） — source: ADR-0006
- **禁止 Autoload 在类变量持有具体 Scene Node 引用**（如 `var grid: GridMovement`）——场景重载引用失效 — source: ADR-0003
- **禁止 Scene Node 持有业务逻辑/持久化游戏状态**（无法跨楼层持久化、无法 headless 测试）→ 委托给对应 Autoload — source: ADR-0003
- **禁止 `generate_round_sequence` 返回 untyped `Array` 或 `Array[Dictionary]`** — source: ADR-0006, ADR-0001

### Performance Guardrails
- 战斗 `forecast_combat` 在玩家确认时调用一次,**禁止 `_process()` 按帧轮询**（N_max=10 时每次分配 ~10 个 RoundEvent，按帧调用致 GC 抖动） — source: ADR-0006

---

## Feature Layer Rules

*适用于：战斗预演（#10）、掉落奖励、楼层进程、游戏状态管理*

### Required Patterns
- **#10 拆分为两对象**：`CombatForecastService`（Autoload，纯代理 #5 forecast_combat，无状态无 UI）+ `CombatForecastOverlay`（Scene Node，`CanvasLayer > Control` @game.tscn，持 UI 子树） — source: ADR-0008
- **#6 GridMovement 访问 #10**：`forecast_combat()` 经 **`CombatForecastService` 全局名**调用；4 个 UI 接口（`show_overlay`/`hide_overlay`/`get_overlay_screen_rect`/`get_x_button_screen_rect`）经 **`@export var forecast_overlay: CombatForecastOverlay`** 引用调用 — source: ADR-0008
- **Autoload 注册名必须 == `class_name`**（否则 `CombatSystem as CombatSystem` 式转型静默返回 null；godot-specialist E-1） — source: ADR-0008
- **`show_overlay(forecast, col, row)` 3 参签名** — source: ADR-0008
- **`CombatForecastService._ready()` 含 `assert(CombatSystem != null)`**；`GridMovement._ready()` 含 `assert(forecast_overlay != null)` — source: ADR-0008
- **× 按钮 `MOUSE_FILTER_IGNORE`，覆盖层根 Control `MOUSE_FILTER_STOP`**；触控拦截由 #6 `_input()` 的 Rect2 命中负责 — source: ADR-0008

### Forbidden Approaches
- **禁止单一 Autoload 同时持有 UI Control 子树**（违反 `autoload_holds_scene_node_reference`） — source: ADR-0008
- **禁止 `(CombatSystem as CombatSystem)` 冗余 `as` 转型**——直接用 Autoload 全局名调用 — source: ADR-0008（E-1）

### Performance Guardrails / Spike-Pending
- ⏳ **Spike-Pending（决策 4，未生效硬约束）**：Viewport/坐标方案（项目 `stretch/mode=canvas_items`、无 SubViewport、Overlay CanvasLayer `follow_viewport_enabled=true`、`offset=ZERO`、`scale=ONE`，F-RECT 方案 a）的触控命中坐标对齐前提**依赖导出 spike `QQ-ADR8-01` 实测确认**。**QQ-ADR8-01 未过前，#6 不得把该坐标命中当作已验证；若 spike 否决，决策 4 须修订**。参与命中的 Control `pivot_offset` 须为零（E-4） — source: ADR-0008

---

## Presentation Layer Rules

*适用于：数值反馈视觉（#11）、HUD（#12）、渲染、动效*

### Required Patterns
- **HUD / NumberFeedback 为 Scene Node**，通过连接 Autoload 信号（`PlayerStats.stat_changed` / `GameState.combat_resolved`）显示快照/播放 VFX，不持业务状态 — source: ADR-0003
- **逻辑/动画解耦**：战斗结算代码无 `await`，视觉响应经信号（命令模式）触发 — source: ADR-0003, ADR-0006

### Forbidden Approaches
- **禁止 Presentation 层 Scene Node 持有/计算业务数值**（数值来自 Autoload 信号携带的数据） — source: ADR-0003

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerDash` |
| Variables/Functions | snake_case | `dash_charges`, `perform_dash()` |
| Signals/Events | snake_case 过去式 | `enemy_killed`, `charge_depleted` |
| Files | snake_case 匹配 class | `player_dash.gd` |
| Scenes/Prefabs | PascalCase 匹配根节点 | `PlayerDash.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_DASH_CHARGES` |

来源:technical-preferences.md

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 30 fps |
| Frame budget | 33.3 ms |
| Draw calls | < 50 |
| Memory ceiling | 256 MB |
| WASM bundle | < 50 MB |

来源:technical-preferences.md（spike 实测空包 ~7.2MB，余量大）

### Approved Libraries / Addons
- **GDUnit4**（`addons/gdunit4/`）— 唯一测试框架；headless runner：`godot --headless --script tests/gdunit4_runner.gd` — source: ADR-0004
- **抖音 Godot SDK（ttsdk / ttsdk.editor，1.0.3）**— 抖音小游戏接入 + 导出（编辑器期 GDExtension；运行时 ttsdk 为纯 GDScript）— source: spike（ADR-0007 待 Accept 形式化）

### Forbidden APIs (Godot 4.5.2)
弃用/不可用,见 `docs/engine-reference/godot/deprecated-apis.md`：
- `TileMap` → 用 `TileMapLayer`（4.3）
- 字符串式 `connect("sig", obj, "method")` → 用 `signal.connect(callable)`（4.0）
- `instance()` / `PackedScene.instance()` → `instantiate()`（4.0）
- `yield()` → `await signal`（4.0）
- `VisibilityNotifier2D` → `VisibleOnScreenNotifier2D`；`YSort` → `Node2D.y_sort_enabled`
- `OS.get_ticks_msec()` → `Time.get_ticks_msec()`
- 嵌套资源浅 `duplicate()` → `duplicate_deep()`（4.5，**仅 Resource 有此方法**）

### Cross-Cutting Constraints
- **Compatibility 渲染后端唯一**：`renderer/rendering_method = gl_compatibility`（含 mobile）；**禁止 Forward+/Mobile**（依赖 Vulkan/D3D12/Metal，WASM 不支持）— technical-preferences.md（ADR-0007 待形式化）
- **所有信号连接用 Callable 语法**（禁字符串式 connect）— deprecated-apis.md
- **所有公共 API 强类型**（字段显式类型标注；禁 untyped 集合公共返回）— ADR-0001
- **触控单指为主输入**（无手柄、无键盘游戏流程）— technical-preferences.md
- **核心逻辑 headless 可测**（Autoload 服务/纯函数可 `new()` 直接断言，不依赖场景树）— ADR-0004

---

## Pending ADR 提示（规则尚未生效，勿据此实现）

以下 ADR 仍 Proposed，其规则**未纳入本手册**，转 Accepted 后重新生成 manifest：

- **ADR-0007（WASM 导出 / Compatibility 渲染形式化）— Proposed（spike-gated）**：渲染后端选择当前由 technical-preferences 兜底；导出 spike P2/P5 待真 AppID 跑通后转 Accepted。spike 已实证：4.6.3 插件加载/导出/出包/体积全通过。
- **ADR-0009（GridMovement 楼层渲染：TileMapLayer 静态底 + 池化覆盖 Node2D）— Proposed**：`#6 楼层切换用单 TileMapLayer 批量 set_cell`、`每次切换仅一次 FloorDB.get_floor`、`禁 cell 级 _process` 等规则**待 0009 Accept 后纳入**。在此之前 #6 楼层渲染实现不应按"256 独立 CellNode"也不应锁死 TileMapLayer——等 ADR Accept。
