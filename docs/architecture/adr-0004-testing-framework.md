# ADR-0004: 测试框架选型 — GDUnit4

## Status
Accepted

## Date
2026-06-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core / Scripting（测试基础设施） |
| **Knowledge Risk** | MEDIUM — GDUnit4 为第三方插件，版本更新快；LLM 训练数据中的 API 可能过时 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md` |
| **Post-Cutoff APIs Used** | GDUnit4 本身（第三方插件，需在 addons/ 中固定版本） |
| **Verification Required** | 验证所选 GDUnit4 版本在 Godot 4.6.3 下兼容（无 breaking change）；验证 `godot --headless --script tests/gdunit4_runner.gd` 在 Douyin 适配器 WASM 导出环境之外的 headless 模式正常运行（CI 服务器，非 WASM） |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（数据类型——测试须能 new() 构造 RefCounted 类型）；ADR-0003（系统宿主——定义哪些系统可 headless 测试、哪些须 Scene Node）|
| **Enables** | 所有系统实现 epic（#1–#13）的 Logic/Integration 类型 story——AC 测试文件须在 GDUnit4 框架下编写 |
| **Blocks** | 任何 Logic 类型 story 的 Done 状态（coding-standards.md 规定 Logic story 须有自动化单测作为阻断门控） |
| **Ordering Note** | 须在首个 Logic 类型 story 实现前完成 |

## Context

### Problem Statement
所有五个已批准 GDD 及 `coding-standards.md` 的 CI 命令均引用 GDUnit4，但 `technical-preferences.md` 仍写 "GUT (Godot Unit Testing framework)"，产生文档矛盾。无架构 ADR 正式确立：① 选用哪个框架；② 固定哪个版本；③ 测试文件和函数的命名约定；④ CI headless 运行命令；⑤ GDDs 中提到的 `SignalOrderSpy` helper 的归属。

### Constraints
- **Godot 4.6.3**：框架必须支持 Godot 4.x
- **headless CI**：测试必须能在无 GPU 的 CI 服务器上运行（不需要 WASM——测试在原生 headless 模式下运行，不在 WASM 中）
- **coding-standards.md**：Logic 类型 story 的单测为阻断门控；Integration 类型须有集成测试或文档化 playtest
- **GDD 引用**：player-stats-growth.md 和 combat-system.md 均直接引用 GDUnit4 API（`assert_that()`、`SignalOrderSpy`）
- **GUT 已过时**：项目 GDD 已全部按 GDUnit4 设计 AC，GUT 切换成本 > 继续 GDUnit4 成本

### Requirements
- 框架支持 Godot 4.6.x headless 运行
- 框架提供断言 API（数值断言、对象断言、数组断言）
- 框架支持信号测试（player-stats-growth.md AC 要求信号顺序断言）
- 框架支持 GDUnit4 headless runner 命令（coding-standards.md CI 命令）
- 测试文件可在无场景树的情况下构造 RefCounted 类型并断言（headless 单元测试）

## Decision

**选用 GDUnit4 作为项目唯一测试框架，替代 technical-preferences.md 中的 GUT 记录。**

### 决策细则

1. **框架**：GDUnit4（`addons/gdunit4/`）。GUT 不在项目中使用；若 `addons/` 中存在 GUT，须删除。

2. **版本锁定**：在 `addons/gdunit4/plugin.cfg` 中固定 GDUnit4 版本（在安装时记录版本号于本 ADR）。版本升级须单独 PR 并验证 Godot 4.6.x 兼容性。
   > **待补充**：GDUnit4 具体版本号须在首次安装时更新至本 ADR。
   >
   > 🔴 **2026-06-30 实测发现（本 ADR Risks 预设的验证步骤已执行，结果 FAIL）**：经 AssetLib 安装的 **GDUnit4 v6.0.0 在 Godot 4.6.3 下编译失败**——其内部 `GdUnitTestSessionRunner.gd` 调用 `get_as_text()` 传 1 参（4.6.3 为 0 参）+ `current_dir`（4.6.3 不存在），CmdTool 整链 Compilation failed，无法运行任何测试。注意目录大小写为官方 `addons/gdUnit4`（大写 U），而 `tests/gdunit4_runner.gd` 写的是 `gdunit4`（小写）且引用了 v6 不存在的 `GdUnitRunner.gd`（v6 入口是 `bin/GdUnitCmdTool.gd`）——runner 脚本须修。
   > **结论**：须选用与最终 pinned 引擎版本兼容的 GDUnit4 版本。该发现与「Douyin 适配器仅支持 4.5」共同构成 **引擎 re-pin 到 4.5** 的证据（详见 ADR-0007 + session-state）。
   >
   > ✅ **2026-06-30 re-pin 后复测**：同一 **GDUnit4 v6.0.0** 在 **Godot 4.5.2** 下**编译并运行通过** —— story-003 TuningFormulas 8 个测试经真 GDUnit4 框架全部 PASSED（8 test cases / 0 errors / 0 failures，279ms，spike 工程内）。确认 v6.0.0 的编译错误是 4.6.3 专有不兼容，4.5.2 无此问题。
   > **版本锁定**：GDUnit4 **v6.0.0** + Godot **4.5.2** = 已验证兼容组合（替换上方"待补充版本号"）。CLI 入口 `addons/gdUnit4/bin/GdUnitCmdTool.gd`（大写 U；headless 加 `--ignoreHeadlessMode`）。

3. **CI headless 运行命令**（GDUnit4 v6 官方入口，2026-06-30 修正——旧 `tests/gdunit4_runner.gd` 自定义 runner 在 v6 失效，已改为重定向桩）：
   ```bash
   godot --headless --import                                     # 先建全局类缓存（否则 class_name 未注册）
   godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
         -a res://tests/unit -a res://tests/integration
   ```
   - 原生 Linux/macOS 下运行，不涉及 WASM
   - CI 须安装 Godot **4.5.2** 可执行文件（与项目引擎版本一致）；GitHub Actions 用 `MikeSchulze/gdUnit4-action`（已配 4.5.2，自动处理导入+版本）
   - 目录大小写为 `addons/gdUnit4`（大写 U）

4. **测试文件命名约定**（与 coding-standards.md 一致）：
   - **文件**：`[system]_[feature]_test.gd`（例：`combat_system_resolve_test.gd`）
   - **函数**：`func test_[scenario]_[expected]() -> void`（例：`func test_player_survives_exact_hp_kill_hp_equals_1() -> void`）
   - **位置**：`tests/unit/[system]/`（单元测试）、`tests/integration/[system]/`（集成测试）

5. **信号测试 — SignalOrderSpy helper**：
   player-stats-growth.md AC 明确指出「GDUnit4 无内置信号顺序断言，必须实现 SignalOrderSpy helper」。
   - 此 helper 须创建于 `tests/helpers/signal_order_spy.gd`
   - 归属：测试基础设施，在首个需要信号顺序测试的 story（`AC-FP04` 系列）实现前创建
   - 实现参考：player-stats-growth.md §AC-FP04 注释

6. **框架不在 WASM 中运行**：单元测试和集成测试仅在原生 headless 模式下运行（CI 服务器）。WASM/Douyin 导出测试通过 playtest 和 smoke check 覆盖，不通过自动化框架。

### Architecture Diagram

```
tests/
├── gdunit4_runner.gd           ← CI 入口（headless 模式启动）
├── helpers/
│   └── signal_order_spy.gd    ← 信号顺序断言辅助类
├── unit/
│   ├── entity_db/
│   │   └── entity_db_load_test.gd
│   ├── combat_system/
│   │   └── combat_system_resolve_test.gd
│   ├── player_stats/
│   │   └── player_stats_apply_item_test.gd
│   └── ...（每个 Autoload 系统一个目录）
└── integration/
    ├── combat_flow/
    │   └── combat_flow_test.gd   ← 跨系统（PlayerStats + CombatSystem）
    └── ...

addons/
└── gdunit4/                    ← GDUnit4 插件（版本锁定）
```

### Key Interfaces

```gdscript
# ── GDUnit4 测试文件模板 ──

extends GdUnitTestSuite

# 纯函数模板：forecast_combat 无 Autoload / 场景树依赖，是 headless 单测的正确范式。
# 注：resolve_combat(monster_id: String) 须 EntityDB/PlayerStats Autoload 就绪，属 Integration 测试，
# 不在 headless 单测中直接构造（见 ADR-0003 测试边界分离 + ADR-0006 签名权威）。
func test_forecast_combat_player_wins_returns_survives() -> void:
    # Arrange
    var combat := CombatSystem.new()

    # Act — 6 个 int 参数：monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp
    var forecast: CombatForecast = combat.forecast_combat(50, 18, 5, 14, 13, 90)

    # Assert（夹具与 ADR-0006 Validation Criteria #3 / AC-CF-5 一致）
    assert_bool(forecast.player_survives).is_true()
    assert_int(forecast.n_rounds).is_equal(6)
    assert_int(forecast.predicted_hp_after).is_equal(65)

# ── SignalOrderSpy（player-stats-growth.md 要求）──

class_name SignalOrderSpy extends RefCounted:
    var _received: Array[Dictionary] = []

    func watch(source: Object, signal_name: String) -> void:
        source.connect(signal_name, func(*args): _received.append({"signal": signal_name, "args": args}))

    func assert_order(expected: Array[String]) -> void:
        var actual := _received.map(func(e): return e.signal)
        assert_array(actual).is_equal(expected)
```

## Alternatives Considered

### Alternative 1: GUT (Godot Unit Testing)
- **Description**: GUT 是 Godot 生态中较早的测试框架，语法类 BDD。
- **Pros**: 更简单的 API；在 Godot 3/4 社区有历史积累。
- **Cons**: Godot 4 支持相对滞后；GDD 已全部按 GDUnit4 的 API 设计 AC（`assert_that`、`SignalOrderSpy`）；切换回 GUT 须重写所有 GDD AC；coding-standards.md 已写 GDUnit4 runner 命令。
- **Rejection Reason**: 项目 GDD 已不可逆地按 GDUnit4 API 设计，切换成本远大于继续成本；GDUnit4 对 Godot 4 的支持更好。

### Alternative 2: 无框架（原生 GDScript 断言脚本）
- **Description**: 直接用 `assert()` 和 `push_error()` 编写自定义测试脚本，无第三方框架依赖。
- **Pros**: 零外部依赖；无框架版本兼容性风险。
- **Cons**: 无测试发现机制（须手动维护测试列表）；无结构化断言 API（调试信息不足）；无信号断言支持；无 CI 集成出的标准报告格式；无参数化测试支持（player-stats-growth.md AC-FP04 用参数化）。
- **Rejection Reason**: 缺少测试发现和信号断言导致 GDD 中的多个 AC 无法编写；维护成本随测试规模线性增长。

## Consequences

### Positive
- 统一框架消除 GUT/GDUnit4 文档矛盾
- GDUnit4 headless runner 与 CI 直接集成（`--headless --script`）
- 断言 API 丰富（数值/对象/数组/信号），GDD AC 可直接映射到代码
- RefCounted 类型（ADR-0001）和 Autoload 服务（ADR-0003）均可在 headless 模式下直接 `new()` 并测试，无场景树依赖
- 参数化测试支持 player-stats-growth.md 的 `AC-FP04-FILL`（三种前置值参数化运行）

### Negative
- 引入第三方 addons/ 依赖，须版本维护
- GDUnit4 版本升级须测试兼容性
- SignalOrderSpy helper 须自行实现（GDUnit4 无内置信号顺序断言）

### Risks
- **风险**：GDUnit4 与 Godot 4.6.3 的某个具体版本存在兼容性 bug（LLM 训练数据过时，无法验证）。
  - **缓解**：安装时在 CI 中运行一个最简单测试（空 TestSuite + 1 个 assert_int 断言）验证框架本身可正常执行；将 GDUnit4 版本号锁定在通过验证的版本。
- **风险**：`godot --headless` 在 Godot 4.6.3 中的行为变化导致 runner 脚本失效。
  - **缓解**：breaking-changes.md 4.4/4.5/4.6 中无与 headless 启动相关的变更记录；低风险。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| player-stats-growth.md | 实现前置：GUT→GDUnit4 框架 ADR（status 字段） | 本 ADR 正式选定 GDUnit4，移除 GUT |
| player-stats-growth.md | AC-FP04 注释：须实现 SignalOrderSpy helper | 本 ADR 定义 helper 归属（`tests/helpers/`）及创建时机 |
| combat-system.md | 实现前置：GUT→GDUnit4 框架选型 ADR | 本 ADR 正式确立，消除阻断 |
| combat-system.md | §测试框架：GDUnit4（与 #3/#4 一致），运行命令 | 本 ADR 固定命令与命名约定 |

## Performance Implications
- **CPU/Build Time**: 测试仅在 CI 和本地开发中运行，不影响游戏运行时性能
- **Memory**: GDUnit4 插件在编辑器中加载，导出时须设置为 "Tool" 类型且不打包进游戏 PCK（addons/ 导出设置须排除 gdunit4）
- **Load Time**: N/A（运行时不加载测试框架）

## Migration Plan
无 GUT 代码须迁移（项目尚无已实现测试）。
若 `addons/gut/` 存在，须删除后安装 GDUnit4。

## Validation Criteria
1. `addons/gdunit4/plugin.cfg` 存在，版本号已记录
2. `godot --headless --script tests/gdunit4_runner.gd` 在 CI 中运行 0 个测试时退出码为 0（框架本身可执行）
3. 首个 Logic story 实现时：测试文件遵循命名约定，使用 `extends GdUnitTestSuite`，可在 headless 模式下运行
4. `tests/helpers/signal_order_spy.gd` 在首个需要信号顺序断言的 story 实现时创建
5. `technical-preferences.md` §Testing 更新为 "GDUnit4"（本 ADR 写入时同步更新）
6. `grep -r "extends GDTest\|extends GutTest\|gut.p(" --include="*.gd" tests/` 返回空（无 GUT 残余）

## Related Decisions
- ADR-0001（数据类型）— RefCounted 类型在 headless 测试中直接 new() 可测的前提
- ADR-0003（系统宿主）— Autoload 系统（CombatSystem/KeyDoor 等）须可 headless 测试，Scene Node 系统（GridMovement/HUD）的 Logic 逻辑须委托给 Autoload 才可测
- design/gdd/player-stats-growth.md（SignalOrderSpy 需求来源）
- design/gdd/combat-system.md（GDUnit4 框架声明来源）
- .claude/docs/coding-standards.md（CI 命令来源）
