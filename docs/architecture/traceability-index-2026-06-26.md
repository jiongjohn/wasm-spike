# Architecture Traceability Index
Last Updated: 2026-06-26  
Engine: Godot 4.6.3 (Compatibility, 2D, WASM/Douyin)

## Coverage Summary

| 指标 | 值 |
|------|-----|
| 总需求数 | 35 |
| ✅ 已覆盖 | 16 (46%) |
| ⚠️ 部分覆盖 | 15 (43%) |
| ❌ 缺口 | 4 (11%) |
| ADR 总数 | 5 |
| ADR 已 Accept | 1（ADR-0005）|
| ADR 仍 Proposed | 4（ADR-0001–0004）|

> ⚠️ **实现阻断警告**：ADR-0001 至 ADR-0004 全部处于 Proposed 状态，所有 MVP 系统实现 epic 被阻断。
> 解除路径见"需要 ADR"节。

## Full Matrix

| TR-ID | 系统 | 需求摘要 | 覆盖 ADR | 状态 |
|-------|------|----------|----------|------|
| TR-entity-001 | #1 EntityDB | 启动 D1/D3 校验（TuningConfig 就绪后） | ADR-0002 | ✅ |
| TR-entity-002 | #1 EntityDB | 只读访问（duplicate() 副本） | ADR-0001 | ✅ |
| TR-entity-003 | #1 EntityDB | entity_type 判别字段 | ADR-0001, ADR-0005 | ✅ |
| TR-entity-004 | #1 EntityDB | HIGHEST_WINS / ADDITIVE 叠加规则 | ADR-0001, ADR-0005 | ✅ |
| TR-entity-005 | #1 EntityDB | WASM 路径 res:// | ADR-0005 | ✅ |
| TR-entity-006 | #1 EntityDB | 启动失败 inline 错误屏 | ADR-0002 | ✅ |
| TR-floor-001 | #2 FloorDB | 16×16 网格 + 两遍校验 | ADR-0001, ADR-0005 | ✅ |
| TR-floor-002 | #2 FloorDB | 六种 cell_type | ADR-0001, ADR-0005 | ✅ |
| TR-floor-003 | #2 FloorDB | get_cell/floor 只读副本 | ADR-0001 | ✅ |
| TR-floor-004 | #2 FloorDB | F-SC1d BFS 拓扑校验 | 部分（ADR-0002 校验流程） | ⚠️ |
| TR-floor-005 | #2 FloorDB | FloorDB 启动顺序在 EntityDB 后 | ADR-0002 | ✅ |
| TR-tuning-001 | #3 TuningConfig | 纯配置层，只读副本 | ADR-0001, ADR-0003 | ✅ |
| TR-tuning-002 | #3 TuningConfig | TuningFormulas 独立静态类 | 部分（ADR-0003 隐含） | ⚠️ |
| TR-tuning-003 | #3 TuningConfig | 楼层调参按 floor_number 查 | ADR-0003, ADR-0005 | ✅ |
| TR-stats-001 | #4 PlayerStats | 四条运行时属性 | ADR-0003 | ✅ |
| TR-stats-002 | #4 PlayerStats | stat_changed 信号（含 old==new） | 部分（ADR-0003 列信号，边界未覆盖） | ⚠️ |
| TR-stats-003 | #4 PlayerStats | pickup_item(item_id) API | **⚠️ 冲突** — ADR-0003 写 apply_item | ⚠️ |
| TR-stats-004 | #4 PlayerStats | apply_damage(amount≥0) API | 部分（ADR-0003 未列出） | ⚠️ |
| TR-stats-005 | #4 PlayerStats | HIGHEST_WINS/ADDITIVE 处理逻辑 | 部分（数据字段有，处理逻辑无） | ⚠️ |
| TR-stats-006 | #4 PlayerStats | player_died() 信号 | 部分（ADR-0003 Key Interfaces 未列） | ⚠️ |
| TR-stats-007 | #4 PlayerStats | ATK/DEF 只读 getter | ADR-0001, ADR-0003 | ✅ |
| TR-combat-001 | #5 CombatSystem | resolve_combat(monster_id) 同步 | **⚠️ 冲突** — ADR-0003 签名 4 参数 | ⚠️ |
| TR-combat-002 | #5 CombatSystem | forecast_combat(6 int) 纯函数 | 部分（#10 CombatForecast Autoload） | ⚠️ |
| TR-combat-003 | #5 CombatSystem | generate_round_sequence 纯函数 | — | ❌ |
| TR-combat-004 | #5 CombatSystem | 三个输出信号 | 部分（architecture.md，无 ADR） | ⚠️ |
| TR-combat-005 | #5 CombatSystem | 零 RNG（randf/randi 禁用） | — | ❌ |
| TR-combat-006 | #5 CombatSystem | 逻辑/动画解耦（无 await） | 部分（ADR-0003 模式隐含） | ⚠️ |
| TR-combat-007 | #5 CombatSystem | CombatResult/Forecast/RoundEvent 强类型 | ADR-0001 | ✅ |
| TR-combat-008 | #5 CombatSystem | 战斗状态机 + 重入保护 | — | ❌ |
| TR-cross-001 | 全局 | GDUnit4 框架（headless） | ADR-0004 | ✅ |
| TR-cross-002 | 全局 | WASM bundle ≤ 50MB | — | ❌ |
| TR-cross-003 | 全局 | Compatibility 渲染后端 | 部分（technical-preferences.md） | ⚠️ |
| TR-cross-004 | 全局 | 触控输入 | 部分（technical-preferences.md） | ⚠️ |
| TR-cross-005 | 全局 | 30fps/<50DC/<256MB 预算 | 部分（technical-preferences.md） | ⚠️ |
| TR-cross-006 | 全局 | Callable 信号连接 | 部分（architecture.md 注记） | ⚠️ |

## Known Gaps

### Core 层缺口（优先）

| TR-ID | 建议 ADR | 原因 |
|-------|---------|------|
| TR-combat-003 | CombatSystem 完整接口规范 | generate_round_sequence 是 #10/#11 的关键依赖 |
| TR-combat-005 | CombatSystem 完整接口规范 | 零 RNG 是 Pillar 2 的架构强制约束，必须 ADR 固化 |
| TR-combat-008 | CombatSystem 完整接口规范 | 重入保护防止双重战斗触发 |

**建议**：将以上三条合并为一条 ADR「CombatSystem 完整公开接口」（`/architecture-decision 确定性战斗系统完整接口`）

### Platform 层缺口（项目可行性级别）

| TR-ID | 建议 ADR | 原因 |
|-------|---------|------|
| TR-cross-002 | ADR-P001: WASM 导出 + Douyin 适配器验证 | 整个项目平台可行性依赖此 spike 结论 |

## ADR 冲突修复清单（Accept 前必须完成）

ADR-0003 须修正以下两处后方可 Accept：

1. `PlayerStats.apply_item(item: ItemEntry)` → `pickup_item(item_id: String)`
2. `CombatSystem.resolve_combat(player_atk, player_def, player_hp, monster)` → `resolve_combat(monster_id: String)`

## History

| 日期 | 覆盖率 | 备注 |
|------|--------|------|
| 2026-06-26 | 46% ✅（35 TR 首次登记） | /architecture-review 初次运行，tr-registry.yaml 首次填入 |
