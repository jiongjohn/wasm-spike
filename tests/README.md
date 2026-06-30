# Test Infrastructure

**Engine**: Godot 4.6.3（Compatibility 后端，2D，抖音小游戏 WASM）
**Test Framework**: GDUnit4（`addons/gdunit4/`）— ADR-0004
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-06-29

## Directory Layout

```
tests/
  unit/           # 隔离单元测试（公式、状态机、纯逻辑）— 按系统分子目录
  integration/    # 跨系统 + 楼层重载 / 战斗流程
  smoke/          # /smoke-check 关键路径清单（≤15 分钟手动门）
  evidence/       # 截图日志与手动测试签核记录
  helpers/        # 测试辅助库（如 signal_order_spy.gd — ADR-0004 §5）
  gdunit4_runner.gd  # headless runner（CI / 本地）
```

## Running Tests

```bash
# 本地 headless（ADR-0004 指定命令）
godot --headless --script tests/gdunit4_runner.gd
```

CI 通过 `MikeSchulze/gdUnit4-action` 在每次 push/PR to `main` 运行 `tests/unit` 与 `tests/integration`。

## Installing GDUnit4

```
1. 打开 Godot → AssetLib → 搜索 "GdUnit4" → Download & Install
2. 启用插件：Project → Project Settings → Plugins → GdUnit4 ✓
3. 重启编辑器
4. 验证：res://addons/gdunit4/ 存在
5. 导出设置须排除 addons/gdunit4（不打包进游戏 PCK — ADR-0004 §Performance）
```

## Test Naming（ADR-0004 §4）

- **文件**：`[system]_[feature]_test.gd`（例：`combat_system_resolve_test.gd`）
- **函数**：`func test_[scenario]_[expected]() -> void`
- **位置**：`tests/unit/[system]/`（单元）、`tests/integration/[system]/`（集成）

## Story Type → Test Evidence（coding-standards.md）

| Story Type | Required Evidence | Location | Gate |
|---|---|---|---|
| Logic（公式/状态机/AI） | 自动化单测 — 必须通过 | `tests/unit/[system]/` | BLOCKING |
| Integration（多系统） | 集成测试 OR 文档化 playtest | `tests/integration/[system]/` | BLOCKING |
| Visual/Feel | 截图 + lead 签核 | `tests/evidence/` 或 `production/qa/evidence/` | ADVISORY |
| UI | 手动走查 OR 交互测试 | `tests/evidence/` | ADVISORY |
| Config/Data | smoke check 通过 | `production/qa/smoke-*.md` | ADVISORY |

## 确定性与隔离规则（coding-standards.md）

- **确定性**：测试每次运行结果一致——无随机种子、无时间依赖断言。
- **隔离**：每个测试自建/自拆状态；不依赖执行顺序。
- **无外部依赖**：单元测试不调外部 API/DB/文件 I/O——用依赖注入（ValidationConfig 等，ADR-0002）。
- **无随机数**：战斗相关测试须可复算（ADR-0006 零 RNG forbidden_pattern）。

## CI

测试在每次 push 到 `main` 和每个 PR 自动运行。测试套件失败阻断合并（coding-standards.md）。
