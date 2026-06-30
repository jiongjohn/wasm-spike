# 架构评审报告 — 2026-06-29

| 字段 | 值 |
|------|----|
| **日期** | 2026-06-29（取代同日早先一版：早版评审 8 ADR，本版覆盖 9 ADR，含新增的 ADR-0009 perf ADR——早版的 ❌ TR-grid-007 缺口已被 ADR-0009 关闭） |
| **引擎** | Godot 4.6.3（Compatibility / WebGL2） |
| **模式** | full（`/architecture-review`，含 godot-specialist 引擎二次意见） |
| **GDD 评审数** | 8（entity-database, floor-layout-data, game-tuning-config, player-stats-growth, combat-system, grid-movement, combat-forecast, game-concept） |
| **ADR 评审数** | 9（ADR-0001~0006 Accepted；ADR-0007/0008/0009 Proposed） |
| **TR 注册表** | v2 — 52 条需求 |
| **裁决** | 🟡 **CONCERNS** |

> **已知冲突易发区**（`consistency-failures.md`）：接口签名跨文档拷贝、F1-A/F1-B 算例方向混淆、`def` 保留字 → `defense`。本轮重点核验这些"指纹"是否全库闭合。

---

## 一、可追溯性摘要

| 状态 | 数量 | 说明 |
|------|------|------|
| ✅ 已覆盖（Accepted ADR 显式） | 17 | Foundation/Core 骨架 + 战斗完整接口 |
| 🟡 Proposed ADR 覆盖（未生效） | 11 | cross-002(0007)、grid-005/006(0008)、forecast-001/003/004/005/008(0008)、grid-007(0009 但 Proposed) |
| ⚠️ 部分覆盖 / 无 ADR 形式化 | 18 | 系统内部实现细节、信号边界、technical-preferences 已定但无 ADR |
| 🅽 N/A（设计决策，无需 ADR） | 2 | forecast-006/007（呈现层） |
| ❌ 真缺口（无任何覆盖） | **0** | 早版的 TR-grid-007 缺口已被 ADR-0009 关闭 |

**关键结论：零真缺口。** 全部 Foundation + Core 层需求由 **Accepted** ADR（0001–0006）覆盖。剩余未闭合项集中于 (a) Proposed ADR（pre-production 预期门控）与 (b) 有意不写 ADR 的系统内部细节（由 GDD AC + CI grep 强制）。

> **相对早版的变化**：早版（8 ADR）将 `TR-grid-007 #6 楼层切换性能`列为 ❌「perf ADR 不存在」。本版确认 **ADR-0009（TileMapLayer 静态底 + 池化覆盖节点）已创建**并覆盖该需求（✅，Proposed），缺口关闭。

---

## 二、跨 ADR 冲突检测

**未发现新的阻断性冲突。** 9 个 ADR 互洽，接口签名权威一致（`resolve_combat(monster_id)`、`pickup_item(item_id)`、`forecast_combat(6 int)`、`defense` 非 `def`）。历史两轮冲突（2026-06-26 ADR-0003、2026-06-29 ADR-0004）均已闭合。

发现 3 处文档陈旧 / 同根缺陷残留位置（均 CONCERN，非逻辑冲突）：

### 🟡 C-1 — ADR-0003 通信图残留 `CombatForecast.preview()`
ADR-0003 第 174 行通信图写 `GridMovement ──call──▶ CombatForecast.preview()`，而同文档 Key Interfaces（第 200 行）与权威接口均为 `forecast_combat(6 int)`。`preview()` 是不存在的旧名——"接口名当指纹全库 grep"教训的一处漏网位置。
**建议**：随 ADR-0008 Accept，将 `preview()` → `CombatForecastService.forecast_combat()`。

### 🟡 C-2 — tr-registry 两条注释陈旧，错标为"冲突"（本轮已修复）
- `TR-stats-003`：注释曾写「⚠️ 冲突 — apply_item 须修正」，但 ADR-0003 第 225 行已是 `pickup_item(item_id: String)`，2026-06-26 已闭合。**本轮已翻正为 ✅。**
- `TR-combat-001`：注释曾写「⚠️ 冲突 — 4 参签名」，但 ADR-0003 第 199 行已是 `resolve_combat(monster_id: String)`。**本轮已翻正为 ✅。**

---

## 三、ADR 依赖顺序（拓扑排序，无环）

```
Foundation（无依赖）:
  ① ADR-0001 数据类型 ✅Accepted
依赖 ①:
  ② ADR-0002 启动顺序 ✅   ③ ADR-0005 数据文件 ✅
依赖 ①②:
  ④ ADR-0003 系统宿主 ✅
依赖 ①③④:
  ⑤ ADR-0004 测试框架 ✅   ⑥ ADR-0006 战斗接口 ✅
Proposed 层（Depends On 均为 Accepted）:
  ⑦ ADR-0008 预演拆分 🟡Proposed（amend ④）
  ⑧ ADR-0009 网格性能 🟡Proposed
  ⑨ ADR-0007 WASM导出 🟡Proposed（spike 门控，可与全部并行）
```

✅ 无依赖环；无 Proposed-依赖-Proposed（三个 Proposed ADR 的 `Depends On` 全部指向 Accepted ADR）。

**待 Accept 后必须落地的 amend**（`architecture.yaml` 已标 `proposed_pending`，但 ADR-0003 正文尚未改）：
- **ADR-0008 Accept 后**：ADR-0003 Autoload 列表 `[9] CombatForecast` → `CombatForecastService`、#10 分类行、通信图 `preview()`（C-1）；#6 grid-movement.md 4 个 UI 接口调用名同步。
- **ADR-0009 Accept 后**：ADR-0003 架构图「CellNode × 256」+ #6 GDD M7/Overview/Visual「256 CellNode」→ TileMapLayer + 覆盖节点。

---

## 四、引擎兼容性

- **版本一致性** ✅ — 全部 9 ADR 锁定 Godot 4.6.3。
- **弃用 API** ✅ — 无引用弃用 API；ADR-0009 主动用 `TileMapLayer` 替代弃用的 `TileMap`（4.3）。
- **Post-cutoff API 一致性** ✅ — `duplicate_deep()`(4.5+)、`TileMapLayer`(4.3+)、`follow_viewport_enabled`、Dual-focus(4.6)、Recursive Control(4.5) 均带 Verification Required + 并入 spike QQ-01；无矛盾假设。
- **Engine Compatibility 节** ✅ — 9/9 ADR 均有。

### Engine Specialist Findings（godot-specialist 二次意见）

确认 4 项主张成立（follow_viewport 坐标系方向、Dual-focus/Recursive Control 不影响 `_input()` 传播、TileMapLayer 批量 set_cell 性能、Compatibility 唯一 WASM 后端 + Shader Baker 影响评估）。补充 4 项审计遗漏的引擎风险：

| # | ADR | 风险 | 严重度 |
|---|-----|------|--------|
| E-1 | 0008 | `(CombatSystem as CombatSystem).forecast_combat()` 冗余 cast；若 Autoload 注册名 ≠ class_name 会静默返回 null。建议直接全局名调用 + 明确"Autoload 注册名 == class_name" | 中 |
| E-2 | 0009 | TileSet `use_texture_padding`（编辑器内置）与手动 2px padding 双重 padding → atlas_coords 偏移。须二选一，Migration Plan 注明 | 中 |
| E-3 | 0007/0009 | spike P5 只测首帧 + JSON 加载，未测"楼层切换帧"耗时（`duplicate_deep` 256 CellEntry + 256 `set_cell`，WASM 单线程 GC）。建议 P5 增此项 | 中 |
| E-4 | 0008 | F-RECT 坐标系还需排除 `pivot_offset` 非零边角（B-2 仅覆盖 `reset_size`） | 低 |

> 均为对 Proposed ADR 的实现约束补强建议，不阻断；建议在 ADR-0008/0009 Accept 前吸收进各自 Validation Criteria / Migration Plan。

---

## 五、架构文档覆盖（Phase 6）

### 🔴 AD-1（主要发现）— `architecture.md` 严重陈旧

写于 2026-06-25（ADR 阶段之前），此后从未更新：

| 陈旧处 | 现状 | 现实 |
|--------|------|------|
| `ADRs Referenced: None yet` | "无" | 9 个 ADR |
| `#4 PlayerStats (... ADR 待定)` | "待定" | ADR-0003 = Autoload |
| `#5 CombatSystem (... ADR 待定)` | "待定" | ADR-0003 = Autoload |
| ADR Audit「0 ADR / 35 缺口」 | 旧 | 9 ADR / 0 真缺口 |
| Required ADRs F001~P001"待创建" | 旧 | 已落地为 ADR-0001~0007 |
| TR Baseline 35 条「均未覆盖」 | 旧 | 52 条 / 17 ✅ |
| Open Questions QQ-03/04/05 | "未解决" | 已由 ADR-0003/0001 解决 |
| GDDs Covered 仅 #1–#5 | 缺 #6/#10 | 已有 GDD + ADR(0008/0009) |

**影响**：任何把 architecture.md 当主蓝图阅读者会得到失真图景。权威已转移到 ADR + tr-registry + architecture.yaml（三者最新）。
**处置（本轮已执行）**：已在 architecture.md 头部加 **SUPERSEDED 横幅**，指向权威来源并消除即时误导。后续建议运行 `/create-architecture` 重建。

无孤立架构（architecture.md 中系统均有对应 GDD）。

---

## 六、裁决：🟡 CONCERNS

- **非 PASS**：11 条需求由 Proposed ADR 门控；architecture.md 陈旧（已加横幅缓解）；注册表 2 条注释陈旧（已翻正）。
- **非 FAIL**：无 Foundation/Core 真缺口；无阻断性跨 ADR 冲突；无依赖环。

### 进入 Production 前建议处理（按优先级）

1. **🔴 重建 architecture.md**（AD-1）——本轮已加 SUPERSEDED 横幅止损；彻底解决需 `/create-architecture`。
2. **🟡 推进 3 个 Proposed ADR 转 Accepted**：
   - **ADR-0007**：执行导出 spike QQ-01（平台最高风险；P5 增 E-3 楼层切换帧耗时）。
   - **ADR-0008**：吸收 E-1 / E-4；Accept 后落地对 ADR-0003 + #6 的 amend（含 C-1 `preview()` 修正）。
   - **ADR-0009**：吸收 E-2；Accept 后落地对 ADR-0003 + #6 GDD「256 CellNode」表述修订。
3. **🟡 更新 tr-registry 陈旧注释**（C-2）——**本轮已完成**（stats-003、combat-001 → ✅）。

### 必需的 ADR（优先级排序）

无新增 ADR 缺口。下一步是让现有 3 个 Proposed ADR 通过其门控（spike / amend 落地）转为 Accepted。

---

*本报告由 `/architecture-review` 生成，取代同日早先一版（早版评审 8 ADR、缺 ADR-0009）。裁决为咨询性，是否在 CONCERNS 下继续由用户决定。*
