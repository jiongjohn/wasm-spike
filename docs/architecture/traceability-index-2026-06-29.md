# Architecture Traceability Index

> Last Updated: 2026-06-29（本版取代同日早先一版 + traceability-index-2026-06-26.md）
> Engine: Godot 4.6.3（Compatibility，2D，抖音小游戏 WASM）
> Source: `/architecture-review full`（9 ADR，含 ADR-0009）

## Coverage Summary

- Total requirements: **52**（entity 6 + floor 5 + tuning 3 + stats 7 + combat 8 + cross 6 + grid 9 + forecast 8）
- ✅ Covered（Accepted ADR 显式）: **17**
- 🟡 Proposed ADR 覆盖（未生效）: **11**
- ⚠️ Partial / 无 ADR 形式化: **18**
- 🅽 N/A（设计决策）: **2**
- ❌ 真缺口: **0**（早版 TR-grid-007 已被 ADR-0009 关闭）

## Full Matrix

| TR-ID | GDD | 需求摘要 | ADR | 状态 |
|-------|-----|---------|-----|------|
| TR-entity-001 | entity-database | 启动 D1/D3 校验 | ADR-0002 | ✅ |
| TR-entity-002 | entity-database | 只读 duplicate() 副本 | ADR-0001 | ✅ |
| TR-entity-003 | entity-database | entity_type 判别字段 | ADR-0001,0005 | ✅ |
| TR-entity-004 | entity-database | HIGHEST_WINS vs ADDITIVE | ADR-0001,0005 | ✅ |
| TR-entity-005 | entity-database | JSON 路径 res:// | ADR-0005 | ✅ |
| TR-entity-006 | entity-database | 启动校验失败 inline 错误屏 | ADR-0002 | ✅ |
| TR-floor-001 | floor-layout-data | 16×16 网格 + 两遍校验 | ADR-0001,0005 | ✅ |
| TR-floor-002 | floor-layout-data | 六种 cell_type | ADR-0001,0005 | ✅ |
| TR-floor-003 | floor-layout-data | get_cell/get_floor 只读副本 | ADR-0001 | ✅ |
| TR-floor-004 | floor-layout-data | F-SC1d BFS 拓扑校验 | ADR-0002(流程) | ⚠️ 算法未形式化 |
| TR-floor-005 | floor-layout-data | FloorDB 启动序在 EntityDB 后 | ADR-0002 | ✅ |
| TR-tuning-001 | game-tuning-config | 纯配置层只读副本 | ADR-0001,0003 | ✅ |
| TR-tuning-002 | game-tuning-config | TuningFormulas 独立静态类 | ADR-0003(隐含) | ⚠️ 无明确决策 |
| TR-tuning-003 | game-tuning-config | 楼层调参表查询 null 处理 | ADR-0003,0005 | ✅ |
| TR-stats-001 | player-stats-growth | 四条运行时属性 | ADR-0003 | ✅ |
| TR-stats-002 | player-stats-growth | stat_changed 信号（含 old==new） | ADR-0003 | ⚠️ old==new 边界未覆盖 |
| TR-stats-003 | player-stats-growth | pickup_item(item_id) | ADR-0003 | ✅（本轮翻正陈旧"冲突"注释） |
| TR-stats-004 | player-stats-growth | apply_damage(amount≥0) | ADR-0003 | ⚠️ 方法未显式列出 |
| TR-stats-005 | player-stats-growth | 装备叠加内部处理 | ADR-0001,0005 | ⚠️ 内部逻辑无 ADR |
| TR-stats-006 | player-stats-growth | player_died() 信号 | ADR-0003 | ⚠️ 信号未显式列出 |
| TR-stats-007 | player-stats-growth | ATK/DEF 只读 getter | ADR-0001,0003 | ✅ |
| TR-combat-001 | combat-system | resolve_combat(monster_id) 同步 | ADR-0003,0006 | ✅（本轮翻正陈旧"冲突"注释） |
| TR-combat-002 | combat-system | forecast_combat 纯函数 | ADR-0003 | ⚠️ 分配到 #10 |
| TR-combat-003 | combat-system | generate_round_sequence → Array[RoundEvent] | ADR-0006 | ✅ |
| TR-combat-004 | combat-system | 三个输出信号 | ADR-0003 | ⚠️ 信号未全列 |
| TR-combat-005 | combat-system | 零 RNG | ADR-0006 | ✅（forbidden_pattern 已注册） |
| TR-combat-006 | combat-system | 逻辑/动画解耦无 await | ADR-0003(隐含) | ⚠️ 未显式 |
| TR-combat-007 | combat-system | 结算类型强类型 RefCounted | ADR-0001 | ✅ |
| TR-combat-008 | combat-system | 战斗状态机 + 重入保护 | ADR-0006 | ✅ |
| TR-cross-001 | (all) | GDUnit4 headless | ADR-0004 | ✅ |
| TR-cross-002 | (all) | WASM bundle ≤ 50MB | ADR-0007 | 🟡 Proposed(spike) |
| TR-cross-003 | (all) | Compatibility 渲染后端 | ADR-0007 | 🟡 Proposed / tech-pref |
| TR-cross-004 | (all) | 触控单指为主输入 | tech-pref | ⚠️ 无 ADR |
| TR-cross-005 | (all) | 30fps/<50 draw/<256MB | ADR-0007,0009 | ⚠️ 部分（budget 已注册） |
| TR-cross-006 | (all) | Callable 信号连接 | architecture.md/deprecated-apis | ⚠️ 无 ADR 形式化 |
| TR-grid-001 | grid-movement | Scene Node + TileMapLayer + 池化覆盖 | ADR-0003,0009 | ✅（0009 Proposed） |
| TR-grid-002 | grid-movement | 四状态机 + tap 路由 | — | ⚠️ 内部实现细节 |
| TR-grid-003 | grid-movement | BFS 4 方向寻路 | — | ⚠️ 内部算法 |
| TR-grid-004 | grid-movement | _passable 缓存 + floor_id 校验 | — | ⚠️ 内部缓存 |
| TR-grid-005 | grid-movement | CombatForecast 拆分访问 | ADR-0008 | 🟡 Proposed |
| TR-grid-006 | grid-movement | 触控拦截方案 B（Rect2 命中） | ADR-0008 | 🟡 Proposed |
| TR-grid-007 | grid-movement | 楼层切换重建性能 <2ms | ADR-0009 | 🟡 Proposed（早版 ❌ 已关闭） |
| TR-grid-008 | grid-movement | 可测性约束（DI/Flag 模式） | — | ⚠️ CI-Lint，无 ADR |
| TR-grid-009 | grid-movement | 信号契约 | — | ⚠️ 未注册进 interfaces:[] |
| TR-forecast-001 | combat-forecast | 宿主拆分 Service+Overlay | ADR-0008 | 🟡 Proposed |
| TR-forecast-002 | combat-forecast | forecast 转调 #5（不重复数学） | ADR-0006,0008 | ✅/🟡 |
| TR-forecast-003 | combat-forecast | 对外 5 接口 | ADR-0008 | 🟡 Proposed |
| TR-forecast-004 | combat-forecast | Rect2 同帧缓存 | ADR-0008 | 🟡 Proposed |
| TR-forecast-005 | combat-forecast | 屏幕空间坐标系一致性 | ADR-0008 | 🟡 Proposed |
| TR-forecast-006 | combat-forecast | LOSE 不展示推算数字 | — | 🅽 设计决策 |
| TR-forecast-007 | combat-forecast | 确认手势可发现性（呈现层） | — | 🅽 设计决策 |
| TR-forecast-008 | combat-forecast | mouse_filter + 启动顺序守卫 | ADR-0008,0002 | 🟡 Proposed |

## Known Gaps

- **无真缺口（❌ = 0）。** 早版报告的 `TR-grid-007`（楼层切换性能 perf ADR 缺失）已由 **ADR-0009** 关闭（Proposed，待 Accept 生效）。
- ⚠️ 类项为"系统内部实现细节"或"technical-preferences 已定但无 ADR 形式化"，按既有约定由 GDD AC + CI grep 强制，不视为缺口。
- 🟡 类项由 Proposed ADR（0007/0008/0009）覆盖，待其转 Accepted 后升为 ✅。

## Superseded Requirements

- 无需求被废弃。`TR-stats-003`、`TR-combat-001` 本轮将陈旧的"冲突"注释翻正为 ✅（需求本身未变，2026-06-26 冲突早已闭合，仅注释滞后）。
