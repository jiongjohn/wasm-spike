# 架构评审报告 — 2026-06-26

> 模式: full（完整审查）  
> 引擎: Godot 4.6.3 (Compatibility backend, 2D, WASM/Douyin)  
> GDD 审查: 5 个（#1–#5，均 Approved）  
> ADR 审查: 5 个（ADR-0001–0005）  
> 专家咨询: godot-specialist（引擎兼容性二次审查）

---

## 追溯汇总

| 状态 | 数量 | 占比 |
|------|------|------|
| ✅ 已覆盖 | 16 | 46% |
| ⚠️ 部分覆盖 | 15 | 43% |
| ❌ 缺口 | 4 | 11% |
| **合计** | **35** | **100%** |

---

## 完整追溯矩阵

| TR-ID | GDD | 系统 | 需求摘要 | ADR 覆盖 | 状态 |
|-------|-----|------|----------|----------|------|
| TR-entity-001 | entity-database.md | #1 EntityDB | 启动 D1/D3 校验（需 TuningConfig 就绪） | ADR-0002 | ✅ |
| TR-entity-002 | entity-database.md | #1 EntityDB | 只读访问（返回 duplicate() 副本） | ADR-0001 | ✅ |
| TR-entity-003 | entity-database.md | #1 EntityDB | entity_type 判别字段（MONSTER/ITEM/KEY） | ADR-0001 + ADR-0005 | ✅ |
| TR-entity-004 | entity-database.md | #1 EntityDB | HIGHEST_WINS vs ADDITIVE 叠加规则 | ADR-0001 + ADR-0005 | ✅ |
| TR-entity-005 | entity-database.md | #1 EntityDB | WASM JSON 路径 res:// 而非 user:// | ADR-0005 | ✅ |
| TR-entity-006 | entity-database.md | #1 EntityDB | 启动校验失败 inline 错误屏（禁 OS.quit()） | ADR-0002 | ✅ |
| TR-floor-001 | floor-layout-data.md | #2 FloorDB | 16×16 网格数据结构，两遍校验 | ADR-0001 + ADR-0005 | ✅ |
| TR-floor-002 | floor-layout-data.md | #2 FloorDB | 六种 cell_type 带条件附加字段 | ADR-0001 + ADR-0005 | ✅ |
| TR-floor-003 | floor-layout-data.md | #2 FloorDB | get_cell/get_floor 返回只读副本 | ADR-0001 | ✅ |
| TR-floor-004 | floor-layout-data.md | #2 FloorDB | F-SC1d BFS 拓扑校验（shield 在 goblin 前可达） | 无（校验算法未在 ADR 中形式化） | ⚠️ |
| TR-floor-005 | floor-layout-data.md | #2 FloorDB | FloorDB 启动顺序在 EntityDB 之后 | ADR-0002 | ✅ |
| TR-tuning-001 | game-tuning-config.md | #3 TuningConfig | 纯配置层，get_tuning_config() 只读 | ADR-0001 + ADR-0003 | ✅ |
| TR-tuning-002 | game-tuning-config.md | #3 TuningConfig | TuningFormulas 独立静态函数（headless 可测） | ADR-0003（隐含，非明确决策） | ⚠️ |
| TR-tuning-003 | game-tuning-config.md | #3 TuningConfig | 楼层调参表按 floor_number 查询（null 处理） | ADR-0003 + ADR-0005 | ✅ |
| TR-stats-001 | player-stats-growth.md | #4 PlayerStats | 四条运行时属性（current_HP/MaxHP/ATK/DEF） | ADR-0003 | ✅ |
| TR-stats-002 | player-stats-growth.md | #4 PlayerStats | stat_changed 信号（含 old==new 时） | ADR-0003（信号已列，old==new 边界未覆盖） | ⚠️ |
| TR-stats-003 | player-stats-growth.md | #4 PlayerStats | pickup_item(item_id) 公开 API | ADR-0003（**命名/签名冲突**：写作 apply_item(item: ItemEntry)） | ⚠️ |
| TR-stats-004 | player-stats-growth.md | #4 PlayerStats | apply_damage(amount≥0) → 可能触发 player_died | ADR-0003 Key Interfaces 未列出此方法 | ⚠️ |
| TR-stats-005 | player-stats-growth.md | #4 PlayerStats | HIGHEST_WINS(ATK/DEF); ADDITIVE(MaxHP) 处理逻辑 | ADR-0001（数据字段）；PlayerStats 处理逻辑无 ADR | ⚠️ |
| TR-stats-006 | player-stats-growth.md | #4 PlayerStats | player_died() 信号（HP 归零） | ADR-0003 Key Interfaces 未显式列出 | ⚠️ |
| TR-stats-007 | player-stats-growth.md | #4 PlayerStats | ATK/DEF 只读 getter（无外部写入路径） | ADR-0001（边界声明）+ ADR-0003（模式） | ✅ |
| TR-combat-001 | combat-system.md | #5 CombatSystem | resolve_combat(monster_id) 同步无 await | ADR-0003（**签名冲突**：4 参数而非 monster_id） | ⚠️ |
| TR-combat-002 | combat-system.md | #5 CombatSystem | forecast_combat(6 int 参数) 纯函数 | ADR-0003（#10 CombatForecast 独立 Autoload 包装） | ⚠️ |
| TR-combat-003 | combat-system.md | #5 CombatSystem | generate_round_sequence(6 int 参数) 纯函数 | 无 | ❌ |
| TR-combat-004 | combat-system.md | #5 CombatSystem | 三个输出信号：combat_won/lost/round_resolved | ADR-0003 CombatSystem Key Interfaces 未列出信号 | ⚠️ |
| TR-combat-005 | combat-system.md | #5 CombatSystem | 零 RNG（grep 验证：无 randf/randi） | 无 | ❌ |
| TR-combat-006 | combat-system.md | #5 CombatSystem | 逻辑/动画解耦（无 await in combat code） | ADR-0003 模式隐含，未显式约束 | ⚠️ |
| TR-combat-007 | combat-system.md | #5 CombatSystem | CombatResult/Forecast/RoundEvent 强类型类 | ADR-0001 | ✅ |
| TR-combat-008 | combat-system.md | #5 CombatSystem | 战斗状态机 + 重入保护 | 无 | ❌ |
| TR-cross-001 | (all) | 全局 | GDUnit4 测试框架（headless 运行） | ADR-0004 | ✅ |
| TR-cross-002 | (all) | 全局 | WASM bundle ≤ 50MB（Douyin 限制） | 无（ADR-P001 规划中未创建） | ❌ |
| TR-cross-003 | (all) | 全局 | Compatibility 渲染后端（2D + 低端设备） | technical-preferences.md，无 ADR | ⚠️ |
| TR-cross-004 | (all) | 全局 | 触控输入（无手柄/键盘游戏流程） | technical-preferences.md，无 ADR | ⚠️ |
| TR-cross-005 | (all) | 全局 | 30fps/<50 draw calls/<256MB 性能预算 | technical-preferences.md，无 ADR | ⚠️ |
| TR-cross-006 | (all) | 全局 | Callable 信号连接（禁字符串式 connect） | architecture.md 注记，无 ADR | ⚠️ |

---

## ADR 交叉冲突检测

### 🔴 冲突 1：PlayerStats 公开 API 命名与签名（ADR-0003 vs architecture.md）

**类型**：Integration Contract Conflict  
**ADR-0003 Key Interfaces 写**：`func apply_item(item: ItemEntry) -> void`  
**architecture.md + GDD 写**：`func pickup_item(item_id: String) -> void`  
**影响**：#6 GridMovement 实现时调用方法名与参数类型无从判断；EntityDB 查询应在调用方还是 PlayerStats 内部完成存在歧义。  
**解决方案**：
1. ADR-0003 Accept 前须修正 Key Interfaces：`pickup_item(item_id: String)`（与 GDD + architecture.md 一致）

---

### 🔴 冲突 2：CombatSystem.resolve_combat 签名（ADR-0003 vs architecture.md）

**类型**：Integration Contract Conflict  
**ADR-0003 写**：`func resolve_combat(player_atk: int, player_def: int, player_hp: int, monster: MonsterEntry) -> CombatResult`  
**architecture.md + GDD 写**：`func resolve_combat(monster_id: String) -> CombatResult`  
**影响**：调用约定根本不同；第一种要求调用方预先提取所有参数，第二种由 CombatSystem 内部查 EntityDB/PlayerStats。architecture.md 数据流明确写 `CombatSystem.resolve_combat("goblin")` 单参数形式。  
**解决方案**：
1. ADR-0003 修正签名为 `resolve_combat(monster_id: String) -> CombatResult`

---

### ⚠️ 状态一致性问题：ADR-0005 Accepted 但依赖项 ADR-0001 仍 Proposed

**类型**：Dependency Ordering  
**影响**：违反 docs/CLAUDE.md 状态生命周期规则；ADR-0005 内容正确，流程上须 ADR-0001 先 Accept。  
**解决方案**：先将 ADR-0001 升为 Accepted（内容无需改动，需解决两个冲突后再 Accept ADR-0003）。

---

## ADR 依赖顺序（拓扑排序）

### 推荐 Accept 顺序

**Foundation（无依赖）：**
1. **ADR-0001**：数据类型实现方案 ← **当前阻断所有下游**

**依赖 ADR-0001：**
2. **ADR-0005**：数据文件组织方案（内容已正确，Accepted 合规）
3. **ADR-0002**：Autoload 启动顺序

**依赖 ADR-0001 + ADR-0002：**
4. **ADR-0003**：系统宿主决策 ← **须先修正 2 个接口冲突**

**依赖 ADR-0001 + ADR-0003：**
5. **ADR-0004**：测试框架选型

### 未解决依赖警告

> ⚠️ ADR-0002、ADR-0003、ADR-0004 均依赖 ADR-0001（Proposed）→ 所有 MVP 系统实现 epic 被阻断
>
> ⚠️ ADR-0005（Accepted）依赖 ADR-0001（Proposed）→ 流程违规，ADR-0001 需优先 Accept

**无循环依赖** ✅

---

## 覆盖缺口（无 ADR 覆盖）

### Core 层缺口

❌ **TR-combat-003**: CombatSystem → `generate_round_sequence(6 int 参数)` 纯函数  
→ 建议 ADR：`/architecture-decision CombatSystem 完整公开接口规范`  
→ Domain: Core / Scripting | 引擎风险: LOW

❌ **TR-combat-005**: CombatSystem → 零 RNG 强制（Forbidden Pattern 注册）  
→ 建议 ADR：同上（合并）或补充到 technical-preferences.md Forbidden Patterns 节  
→ Domain: Core / 架构约束 | **设计级 CRITICAL**（违反 Pillar 2「算得清的确定性」）

❌ **TR-combat-008**: CombatSystem → 战斗状态机 + 重入保护  
→ 建议 ADR：同上（合并 TR-combat-003/005/008 为一条 CombatSystem 接口 ADR）  
→ Domain: Core / Scripting | 引擎风险: LOW

### Platform 层缺口

❌ **TR-cross-002**: 全局 → WASM bundle ≤ 50MB（Douyin 限制）  
→ 建议 ADR：`/architecture-decision WASM 导出与 Douyin 适配器验证 (ADR-P001)`  
→ Domain: Platform | **引擎风险: HIGHEST**（项目可行性级别）

---

## GDD 修订标记

无 GDD 修订标记 — 所有 GDD 设计假设与已验证引擎行为一致。

---

## 引擎兼容性

### 自动审计结果

**引擎**：Godot 4.6.3  
**含 Engine Compatibility 节的 ADR**：5/5 ✅  
**版本一致性**：全部 ADR 均标注 Godot 4.6.3 ✅  
**废弃 API**：
- ADR-0001 `duplicate_deep()` 正确用法（取代嵌套资源的 duplicate()）✅
- 所有 ADR 使用 Callable 信号连接 ✅

### 引擎专家额外发现

| 编号 | ADR | 问题 | 等级 |
|------|-----|------|------|
| ES-1 | ADR-0001 | `var grid: Array` 无法强类型为 `Array[Array[CellEntry]]`（GDScript 嵌套泛型限制），ADR 须显式说明 | MEDIUM |
| ES-2 | ADR-0002 | `ResourceLoader.load_threaded_request()` 在 Douyin WASM 单线程降级行为须 spike 专项验证 | MEDIUM |
| ES-3 | ADR-0005 | `manifest["floor_ids"]` 直接索引无 `has()` 检查 — 崩溃路径 | **HIGH** |
| ES-4 | ADR-0005 | `bool(data["is_boss"])` 对字符串 "true" 静默接受，建议加 `is bool` 类型检查 | LOW |

---

## 架构文档覆盖

| 项目 | 状态 |
|------|------|
| architecture.md 系统覆盖（#1–#5） | ✅ 完整 |
| 孤儿架构（#6–#21 在图中无 GDD） | ✅ 预期状态 |
| control-manifest.md | ❌ 不存在 |
| ADR-C003 信号连接规范 | ❌ 未创建 |
| ADR-P001 WASM/Douyin 验证 | ❌ 未创建 |

---

## Verdict: CONCERNS

**理由**：
- Foundation/Core ADR 质量高，架构意图清晰
- 2 个接口冲突均在 Proposed ADR 中，修正路径明确，不影响已 Accepted 的 ADR-0005
- 4 个 TR 缺口（TR-combat-003/005/008/cross-002）可通过 1–2 条新 ADR 关闭
- ADR-0001–0004 全部处于 Proposed 状态，全部 MVP 实现 epic 被阻断（阻断条件已知且可解除）
- 不判定 FAIL：无 Accepted ADR 存在内容冲突；阻断条件是流程状态而非架构设计错误

**解除阻断的最短路径**：
1. 修正 ADR-0003 Key Interfaces（2 个接口冲突）→ Accept ADR-0001 → Accept ADR-0002 → Accept ADR-0003 → Accept ADR-0004
2. 创建 ADR-P001（WASM 导出 spike）

---

## 所需 ADR（按优先级排列）

1. **修正并 Accept ADR-0001**（最优先，阻断所有下游）
2. **修正并 Accept ADR-0003**（pickup_item + resolve_combat 签名，接口冲突）
3. **Accept ADR-0002, ADR-0004**（内容无冲突，依赖解除后直接 Accept）
4. **创建 ADR-P001**：WASM 导出与 Douyin 适配器验证（项目可行性级别，VS 阶段前必须）
5. **CombatSystem 完整接口 ADR**：覆盖 generate_round_sequence、零 RNG 约束、状态机+重入保护（合并 TR-combat-003/005/008）
