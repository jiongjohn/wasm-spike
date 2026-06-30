# Active Session State

## 当前工作 (2026-06-29)
- Task: 设计 #10 战斗预演系统 GDD
- File: design/gdd/combat-forecast.md
- Current section: 全部 8 节完成（Overview / Player Fantasy / Detailed Design / Formulas / Edge Cases / Dependencies / Tuning Knobs / Visual/Audio + AC）
- 前置完成: #6 网格移动 Round 6 修订完成（Approved）
- Next dependency unlock: #10 Approved → #6 实现解除阻断

## Session Extract — /architecture-review 2026-06-26
- Verdict: CONCERNS
- Requirements: 35 总 — 16 覆盖 / 15 部分 / 4 缺口
- New TR-IDs registered: 35（tr-registry.yaml 首次填入）
- GDD revision flags: None
- Top ADR gaps: TR-combat-005（零RNG约束）, TR-combat-008（状态机+重入）, TR-cross-002（WASM bundle ADR-P001）
- Report: docs/architecture/architecture-review-2026-06-26.md
- ADR-0003 接口冲突已修正（pickup_item + resolve_combat 签名）
- **ADR-0001–0005 全部 Accepted（2026-06-26）** — MVP 实现阻断已解除
- **ADR-0006 已写入（2026-06-26）**: CombatSystem 完整接口（TR-combat-003/005/008 全部 ✅）
- **ADR-0007 已写入（2026-06-26）**: WASM 导出 + Douyin 适配器验证（Proposed，spike-gated）；三级体积策略 + QQ-01 验证清单
- 剩余 ADR 缺口: ADR-C003（信号连接模式，architecture.md Required ADRs 列表项）
- ADR-0007 待操作: 执行导出 spike QQ-01，全部 Validation Criteria 通过后将 Status 改为 Accepted

## Current Task
**#6 网格移动与交互系统 GDD 设计完成 (2026-06-26)**
- 文件：design/gdd/grid-movement.md — **全部节已写入**
- 已完成节：Overview ✅ / Player Fantasy ✅ / Detailed Design ✅ / Formulas ✅ / Edge Cases ✅ / Dependencies ✅ / Tuning Knobs ✅ / Visual/Audio ✅ / UI ✅ / Acceptance Criteria ✅ / Open Questions ✅
- systems-index #6 → Designed（2026-06-26）
- entities.yaml → T_cell 常量已注册
- **下一步：新 session 运行 /design-review design/gdd/grid-movement.md 独立复评**
<!-- CONSISTENCY-CHECK: 2026-06-25 | GDDs checked: 5 | Conflicts found: 1 (resolved) | Stale registry: 2 (resolved) | Report: docs/consistency-failures.md -->

## Session Extract — /review-all-gdds 2026-06-25
- Verdict: CONCERNS
- GDDs reviewed: 5
- Flagged for revision: None (all warnings are doc cleanups, no status downgrade)
- Blocking issues: None
- Recommended next: /create-architecture（5 个警告项快速修复后，或直接开始架构）
- Report: design/gdd/gdd-cross-review-2026-06-25.md
全节已写: Overview/PlayerFantasy/DetailedDesign/Formulas/EdgeCases/Dependencies/TuningKnobs/Visual-Audio/UI/AC/OpenQuestions。
核心决策: 回合模型=玩家先手+致命回合豁免(怪反击 N-1 次);伤害引用 #3 F1-A/B/C 不自定义。
信号: combat_won/combat_lost/round_resolved;接口 resolve_combat(实际)/forecast_combat(纯函数预演)。
公式: F-C(总伤=F1-B×(N-1))/F-FC(预演,survives严格<,实时HP)/F-SEQ(逐回合,末回合dmg=0)/F-D(时长N×0.3)。
systems-index #5 → Designed + 链接。注册表: slime/goblin referenced_by 加 combat-system.md。
qa-lead 8 BLOCKING 已并入 AC;systems-designer 3 BLOCKING 已并入 Formulas/EdgeCases。

#5 一致性检查完成 (2026-06-25): 注册表轴 PASS(无冲突);修正 2 处叙事数字(Overview/PlayerFantasy 回合数对齐权威算法:哥布林铁剑6→精钢剑4,史莱姆裸装5刀→铁剑2刀)。

** 待办 (下一步): /clear 后新会话运行 /design-review design/gdd/combat-system.md 独立复评。**
** 外部 BLOCKER (technical-director, 卡 #4+#5 测试编写): technical-preferences.md L44 GUT→GDUnit4 框架 ADR。**
设计顺序下一个 Not Started: #6 网格移动与交互系统 (依赖 1,2) 或 #7 钥匙与门 (依赖 1,6)。
<!-- CONSISTENCY-CHECK: 2026-06-25 | GDDs checked: 5 (combat-system new) | Conflicts found: 0 | Intra-doc narrative fixed: 2 -->

核心设计决策已锁: 回合模型 = 玩家先手、致命回合怪不反击(经典魔塔,怪反击 N-1 次);伤害公式引用 #3 F1-A/B/C。
信号契约: combat_won / combat_lost / round_resolved;预演纯函数 forecast_combat。
职责定位: #5 是运行时战斗编排引擎(读 #1 怪物 + #4 玩家 → 回合循环 → 调 #4 apply_damage → 监听 player_died → 判胜负)。
**回合先后顺序(谁先手)是 #5 核心待设计规则,#3 未定义。** 伤害公式引用 #3 F1-A/B/C/D,不自定义。

### #4 玩家属性与成长 — 第9轮 design-review 完成 (2026-06-25, full, 5 specialists + CD)。
Verdict: **APPROVED**。5 项 BLOCKING 即时修订 + grep 验证闭环;长期外部阻断 #2 已闭环(L234 Design Constraints + F-SC1a-d, 锁 3 层)。
systems-index #4 → Approved。评审记录: design/gdd/reviews/player-stats-growth-review-log.md (含第9轮条目)。
**遗留外部 BLOCKING (technical-director 责任,同样卡 #5):** technical-preferences.md L44 仍写 GUT,而 AC 用 GDUnit4 → 须出框架 ADR。
<!-- CONSISTENCY-CHECK: 2026-06-25 | GDDs checked: 4 | Conflicts found: 1 (resolved) -->

Pivoted away from the archived dash-cleave PC roguelike.

## Key Decisions
- **Fresh start**: old PC roguelike concept + prototype archived to `archive/dash-cleave-roguelike/`.
- **Engine**: Godot retained. Douyin mini-game platform has OFFICIAL Godot adapter
  (抖音小游戏引擎团队, docs at developer.open-douyin.com). No engine switch needed.
- **Platform target change**: PC (Steam/Epic) → 抖音小游戏 (Douyin mini-game). To be
  formalized via /setup-engine (update technical-preferences platform + verify
  adapter support for Godot 4.6 vs the ~4.5 baseline).
- **Open risk**: possible individual-developer licensing/access limits on Douyin —
  verify qualification requirements on the Douyin developer platform before release.

## Current Phase
PROTOTYPE COMPLETE — Verdict: PROCEED. Report at prototypes/pixel-tower-concept/REPORT.md.
Hypothesis CONFIRMED: 确定性逐回合战斗 + 数值反馈 → 核心循环成立,玩家确认"类型就是这种"。
Key tuning found: 战斗 0.3s/回合; 伤害=max(1,ATK−敌DEF)。
Design-phase inputs (玩家提出): 扩怪物种类/地形丰富度/层数/难度曲线; 加随机事件。
LOCKED CONSTRAINT: 随机仅限地图/事件层,战斗保持确定 (守支柱2 算得清的确定性)。

## Design Review (2026-06-23, full, 5 specialists + CD)
Verdict: NEEDS REVISION → REVISED. game-concept.md updated.
Root causes found: (A) 确定性+滚雪球+无随机经济 互相绞杀(碾压/死局+砍变现);(B) 原型1人自测=自我验证。
Decisions locked: ① MVP 手工固定关卡 ② 钥匙碎片软通货(广告位=碎片翻倍+复活补偿,砍加速)
③ 真北=Pillar1看得见的成长,确定性降为支撑 ④ 加容错机制。
Concept doc + prototype REPORT (改 PRELIMINARY) 已更新。

Art Bible: COMPLETE (2026-06-23). design/art/art-bible.md — all 9 sections authored.
Key decisions locked in art bible:
- Visual rule: FC像素16×16格+32色+成长反馈破界
- States: 探索=冷灰蓝; 成长反馈=全游戏亮度峰值; 胜利=唯一暖金橙
- 两步确认触控战斗预演(UX决策); 属性逐步解锁; DEF首次战斗微教学
- Section 8: Godot导出实测清单(TileMapLayer/OGG/WASM体积等)

Systems Index: COMPLETE (2026-06-23). design/gdd/systems-index.md — 21 systems.
MVP: 13 systems (#1-13). VS: 4 (#14-17). Alpha: 3 (#18-20). Full Vision: 1 (#21).
Design order: 实体数据库→楼层关卡数据→调参配置→玩家属性与成长(最大瓶颈)→战斗系统→...
New systems added: 掉落奖励系统(#8,MVP)+ 商店系统(#16,VS) — gold coin economy.
Key constraints: drops fully deterministic; random events Alpha+ only with solvability validator.

GDD: entity-database.md — 二轮 design-review 完成 (2026-06-24, full, 5 specialists + CD).
Verdict: NEEDS REVISION → REVISED. 5 blocker 全解决 + 6 recommended + entities.yaml v2 同步.
关键修订: AC 断言契约(validate_database→ValidationResult); JSON 硬约束(禁 .tres);
stack_rule ONCE→HIGHEST_WINS; D3 死墙兜底裁定+「过D3≠层安全」; AC 14→19; scope-gate 豁免.
评审记录: design/gdd/reviews/entity-database-review-log.md (含三轮复评核对清单).

(entity-database #1: Approved — 三轮复评已闭环。)
Next in design order (#4 复评通过后): #5 确定性回合战斗系统 (依赖 1,3,4)。
Parallel high-priority: 导出spike + 字节开发者平台广告资质申请
(CD-PLAYTEST skipped — lean mode.)

## Concept Summary (locked)
- 怀旧像素回合制爬塔, 抖音小游戏, F2P + 激励广告
- 半策略确定性战斗(无随机数, 伤害预演) + 数值爆发即时反馈
- 4 pillars: 看得见的成长 / 算得清的确定性 / 三秒上手 / 怀旧的克制
- Visual anchor: 8-bit 怀旧魔塔, 16×16 网格, 有限调色板, 高对比数值反馈
- MVP (1-2 周): 3 层单塔 (第4轮评审锁定,原 3-5 层), 黄钥匙+门, 确定性战斗, 数值反馈表现
- Top risk: 确定性数值曲线调成"成长爽"而非"数学题" → 用 /prototype 验证

## Review Mode
lean

## Files
- archive/dash-cleave-roguelike/ — old game, preserved for reference (do not import to src/)
- design/gdd/ — empty, awaiting new game-concept.md
- prototypes/ — empty
<!-- CONSISTENCY-CHECK: 2026-06-25 | GDDs checked: 4 | Conflicts found: 1 (resolved) | Stale registry: 3 (resolved) | Report: docs/consistency-failures.md -->

## Session Extract — /architecture-review 2026-06-29
- Verdict: CONCERNS
- Requirements: 52 总（35 原有 + 9 grid + 8 forecast）；新增 TR-grid-001..009 + TR-forecast-001..008，tr-registry 升 version 2
- ADRs: 0001-0006 Accepted（自洽）；0007/0008 Proposed
- 已修 BLOCKING：B1 ADR-0004 旧 resolve_combat 签名（→ forecast_combat 纯函数模板，移除 monster.def）；B2 architecture.yaml combat_forecast_hosting_split status → proposed_pending: ADR-0008
- GDD revision flags: None
- Top ADR gaps: TR-grid-007（#6 楼层切换性能/对象池 → 建议 ADR-0009）；信号契约 architecture.yaml interfaces 仍空
- 待落地：ADR-0008 Accept 时须同步 amend ADR-0003 [9] 条目 + #6 GDD 调用名；ADR-0007 spike QQ-01 门控
- architecture.md 严重陈旧（仍写「0 ADR」、只列 #1-5）→ 建议重生成
- Pre-gate 全缺：tests/ + CI workflow + UX/无障碍规格 → 须先 /test-setup + /ux-design，暂不能 /gate-check
- Report: docs/architecture/architecture-review-2026-06-29.md

## Session Extract — /ux-design patterns 2026-06-29
- 产出：design/ux/interaction-patterns.md（交互模式库，Status: In Design）
- 12 个模式：P1 点格移动 / P2 两步确认(无CTA) / P3 预演覆盖层 / P4 _input Rect2 拦截 / P5 ×纯取消 / P6 目标格脉冲高亮 / P7 tap拒绝反馈 / P8 输入锁定 / P9 数值跳涨(provisional #11) / P10 色盲双信道 / P11 HUD渐进解锁(provisional #12) / P12 多指仅取首指
- 权威：行为以 #6/#10 GDD 为准，视觉以 art-bible 为准
- 发现冲突：art-bible §7.5 仍画「进攻」CTA，与 #10 无CTA决策冲突 → 待 art-director 更新（Open Q#3）
- 仍缺：design/ux/accessibility-requirements.md（正式无障碍层级，建议 WCAG-AA）；player-journey.md
- 下一步：/ux-review interaction-patterns 验证；或起草 accessibility-requirements 基线
- Pre-gate 进度：tests/ ✅ + CI ✅ + interaction-patterns ✅；仍缺 accessibility-requirements + 示例测试

## Session Extract — accessibility baseline 2026-06-29
- 产出：design/ux/accessibility-requirements.md（Status: Baseline Committed，Tier: WCAG-AA BLOCKING 基线）
- 维度：视觉/运动(触控)/认知/听觉/动效/平台，含 Commit vs Aspire 划分 + 各系统验收钩子表
- 平台 N/A 项：键盘/手柄导航（纯触控，无此输入）；屏幕朗读列 Aspire（抖音 WebView 未验证 AccessKit）
- ⚠️ 路径提示：本文档置于 design/ux/accessibility-requirements.md（design/CLAUDE.md 规范路径）；部分 skill 模板检查 design/accessibility-requirements.md（无 /ux）——gate-check 时留意路径口径
- Pre-gate UX 缺口已补齐：interaction-patterns ✅ + accessibility-requirements ✅
- 剩余 pre-gate：至少一个示例测试文件（tests/unit/combat_system/forecast 纯函数）

## Session Extract — 示例测试 2026-06-29
- 产出：tests/unit/combat_system/combat_system_forecast_test.gd
- 内容：框架健全性测试（跑绿，证 GDUnit4 headless 可执行 — ADR-0004 Val#2）+ 注释形式的 forecast_combat TDD 模板（待 src/combat_system.gd 实现后取消注释）
- 原因：CombatSystem 未实现，直接引用 class_name 会编译失败致 CI 红；故 sanity 测试跑绿 + TDD 模板留注释
- ✅ Pre-gate 6/6 全通过：tests/unit + tests/integration + CI + interaction-patterns + accessibility-requirements + 示例测试
- 下一步：开【全新会话】跑 /architecture-review 复核 → /gate-check pre-production

## Session Extract — /architecture-review 2026-06-29（9 ADR 完整复核）
- Verdict: 🟡 CONCERNS
- Requirements: 52 总 — 17 ✅ / 11 🟡(Proposed ADR 门控) / 18 ⚠️ / 2 🅽 / 0 ❌ 真缺口
- New TR-IDs registered: None（52 条已稳定）；本轮翻正 TR-stats-003 + TR-combat-001 陈旧"冲突"注释 → ✅
- GDD revision flags: None（无引擎现实与 GDD 假设冲突）
- Top 发现：AD-1 architecture.md 严重陈旧（已加 SUPERSEDED 横幅）；C-1 ADR-0003 通信图残留 preview()（待 ADR-0008 amend）；3 个 Proposed ADR(0007/0008/0009) 门控 #6 UI/#10/内容生产
- Engine specialist(godot-specialist)：确认 4 主张 + 补 4 风险(E-1 冗余cast/E-2 双重padding/E-3 spike未测切换帧/E-4 pivot_offset)
- 写出：architecture-review-2026-06-29.md（取代早版8ADR）+ traceability-index-2026-06-29.md + tr-registry 翻正 + architecture.md 横幅 + consistency-failures C-1
- 下一步：推进 3 Proposed ADR 转 Accepted（ADR-0007 spike / ADR-0008·0009 吸收引擎建议后落地 amend）；architecture.md 后续 /create-architecture 重建；pre-gate 全 ✅ 可 /gate-check pre-production

## Session Extract — /gate-check pre-production 2026-06-29
- Verdict: 🟡 CONCERNS（四位 director 全 CONCERNS、无 NOT READY；用户接受并推进）
- 必需工件 11/11 实质满足（2 路径口径差异：traceability-index vs requirements-traceability.md；accessibility 在 design/ux/ 非 design/）；质量检查全过（Foundation 零缺口 / 无 ADR 环 / 无弃用 API / 高风险域已门控）
- Director CONCERNS 汇总：CD=成长约束#4→#2未落地+#10 In Revision+核心假设仅1人；TD=architecture.md陈旧+3 Proposed ADR+楼层切换<2ms未实测(E-3)；PR=建议 Sprint 0 收口 C1导出spike/C2三ADR/C3 #10复评+#5前置+开发者资质；AD=art-bible§7.5 CTA与interaction-patterns「无CTA」冲突(Open Q#3)+调色板色值缺+触控口径未裁
- 已写：production/gate-checks/gate-check-2026-06-29-pre-production.md
- ✅ stage.txt：Concept(错误) → Pre-Production
- 建议 Sprint 0（先于内容生产）：ADR-0007 spike(+P5 加 E-3) + 开发者资质并行 → ADR-0008/0009 吸收 E-1~E-4 转 Accepted + amend ADR-0003/#6 → #10 第4轮复评 + floor-layout-data 补 Design Constraints → art-bible §7.5 同步 + /create-architecture 重建

## Session Extract — Sprint 0 启动：导出 spike 准备 2026-06-29
- 现状核实：项目纯文档，**无 project.godot / src 代码 / data JSON / addons/gdunit4**，godot 不在 PATH。spike 必须人工在外部工具(Godot 4.6.3 + Douyin IDE + 真机 + 开发者账号)跑，Claude 无法代跑。
- 已搭一次性最小 spike 工程 prototypes/wasm-export-spike/（project.godot gl_compatibility + 2 Autoload + SpikeMain.tscn + spike_main.gd harness + data/spike_data.json）；逐项验 ADR-0007 P3（Autoload序/FileAccess/JSON int cast/duplicate_deep/signal/touch），防御式 has_method() 不崩，屏显+console PASS/FAIL
- 🔴 **重要发现待验证**：ADR-0001 用 RefCounted 载体并调 duplicate()/duplicate_deep()，但 breaking-changes.md 记 duplicate_deep() 是 4.5 给 **Resource** 新增——纯 RefCounted 很可能**没有**这俩方法。若属实=ADR-0001 Foundation 级隐患(波及 0005/0009)。harness P3-4a/4b 专门探测；须同时查 Godot 4.6 文档/问 godot-specialist 独立确认
- 已写：prototypes/wasm-export-spike/{project.godot,SpikeMain.tscn,spike_main.gd,spike_config_a.gd,spike_config_b.gd,data/spike_data.json,README.md,RUNBOOK.md} + production/platform/douyin-developer-qualification.md
- 下一步（人工）：① 装 Godot 4.6.3 + Web 模板 + Douyin IDE；② 按 RUNBOOK 跑 spike 回填 ADR-0007；③ 按 qualification 文档启动字节平台资质/广告申请；④ 若 P3-4 FAIL→修 ADR-0001。注意 harness 未经 4.6.3 编辑器验证，首开若报错以编辑器为准

## Session Extract — spike headless 实跑 + ADR-0001 实证 2026-06-29
- 环境：Godot 4.6.3.stable 已装(/Applications/Godot.app)；Web 导出模板未装(P1/P4 导出待人工)
- headless 实跑 spike(--quit-after 30)：harness 零语法错误。P3-1/2/3/3b/5 全 ✅；P3-6 n/a(headless 无 tap)
- 🔴🔴 **ADR-0001 缺陷实证确认**：RefCounted.duplicate=false, duplicate_deep=false；Resource.duplicate=true, duplicate_deep=true(深拷贝独立性✅)。ADR-0001 选 RefCounted 载体+调 .duplicate()/.duplicate_deep() **运行时必崩**
- **修复方向**：8 个数据类型载体 RefCounted→Resource(用 .new()/from_dict 从 JSON 构造，无 .tres/无 ResourceLoader 缓存，ADR-0001 当初拒 Resource 的理由不成立)。波及：ADR-0001 决策+Key Interfaces+Alternatives；ADR-0005 from_dict 返回类型；ADR-0009 get_floor 契约；architecture.yaml cross_module_data_types + readonly_data_source_access。注：engine-reference 当初写的就是"Resource→duplicate_deep"(正确)，是 ADR-0001 误用到 RefCounted
- 已记录：RUNBOOK §5b 实跑结果 + 此 finding；verify_dup.gd 留证
- 仍待人工：装 Web 模板→导出量体积(P1/P4)；Douyin IDE 装适配器(P2/P5/P3-6)；开发者资质申请

## Session Extract — /architecture-decision 修订 ADR-0001 完成 2026-06-29
- 决策：就地修订(非 supersede，因无代码实现) + 全 8 类型统一 Resource(保留 ADR-0001「单载体」初衷)
- 已改 ADR-0001：Status 加 Revision Note(2026-06-29 实证证据)；决策细则1 RefCounted→Resource + 澄清"JSON 构造不碰 .tres/缓存"；Engine Compat 三字段；Key Interfaces 8 个 extends Resource；Architecture Diagram；Alternatives(原 RefCounted 决策下移为 Alt2 实证否决 + 新增 Alt3 双载体否决)；Consequences/Risks/Validation(加✅实测)/Migration
- 波及已同步：ADR-0005(extends Resource×2 + Memory/Related 注)；ADR-0009(Post-Cutoff Resource.duplicate_deep)；architecture.yaml(cross_module_data_types RefCounted→Resource + readonly_data_source_access 澄清，均加 revised 注释，referenced_by 追加 0005/0009)
- 评审模式 lean→TD-ADR 门跳过；引擎专家校验由"直接跑 Godot 4.6.3 引擎"替代(更强权威)
- 已补 consistency-failures：DEFECT「post-cutoff API 挂错基类」教训(验证优先级：跑引擎 has_method > 专家 > changelog)
- ⚠️ 须开【全新会话】跑 /architecture-review 复核本次修订(不可与本会话同跑——评审须独立于作者上下文)
- Sprint 0 剩余：ADR-0007 导出 spike(P1/P4/P2/P5 待人工，需先装 Web 模板) + ADR-0008/0009 转 Accepted + #10 第4轮复评 + floor-layout-data 补 Design Constraints + 开发者资质

## Session Extract — ADR-0008 部分 Accept 完成 2026-06-29
- 决策：部分 Accept —— 结构决策(Service Autoload + Overlay Scene Node + @export 访问 + show_overlay 3 参 + mouse_filter)转 Accepted 生效；**决策 4(Viewport/坐标 canvas_items+follow_viewport_enabled) 标 spike-pending QQ-ADR8-01**(Douyin/WASM 坐标对齐未实测)
- ADR-0008：Status→Accepted(部分)+ 吸收 E-1(去冗余 cast + Autoload 名==class_name)、E-4(新增 B-3 pivot_offset 风险)
- ADR-0003 amend：日期注；Autoload 列表[9] CombatForecast→CombatForecastService；#10 分类行→拆分(Autoload+SceneNode)；架构图；通信图 preview()→forecast_combat(C-1 闭合)
- #6 grid-movement.md 同步：5 处调用名(forecast_combat→CombatForecastService.*;show_overlay/hide_overlay/get_*_screen_rect→forecast_overlay.* @export)；_input 访问机制描述(Autoload全局名→@export Scene Node 引用)；M4 新增权威访问方式说明
- architecture.yaml：combat_forecast_hosting_split proposed_pending→active(结构)+坐标子项 spike-pending 注+referenced_by 追加 ADR-0003/grid-movement；core_feature_system_hosting revised 同步
- ⚠️ 改动多，须开【全新会话】跑 /architecture-review 复核(尤其 ADR-0001 载体改 Resource + ADR-0008 部分 Accept + #6 同步)
- Sprint 0 剩余：ADR-0009 转 Accepted(吸收 E-2 双重 padding)；ADR-0007 导出 spike(人工，需装 Web 模板+Douyin IDE)；#10 第4轮复评；floor-layout-data 补 Design Constraints(#4→#2 成长分布)；开发者资质申请

## Session Extract — spike 二阶发现：@export 必需 2026-06-29
- 用户去跑导出 spike 前，先把 harness P3-4 从测 RefCounted 改测 Resource(ADR-0001 修复后载体)
- headless 重跑发现 **P3-4c FAIL**：Resource.duplicate_deep() 对 plain `var grid: Array` 嵌套 Resource **不深拷贝**(副本 grid 为空)
- 探针 verify_dup2/verify_dup3 精确定位：**duplicate()/duplicate_deep() 只拷贝 @export 属性；plain var 字段不进 STORAGE，副本重置默认值**(plain var hp 副本=0；plain var grid 副本=空)。@export 后标量保留+嵌套深拷贝+独立性全 PASS
- 这是比载体更深的二阶缺陷：仅 RefCounted→Resource **不够**，还须**所有数据字段 @export**
- ADR-0001 补全：Revision Note 追加 + 决策细则 5(所有字段 @export) + Key Interfaces 8 类全字段加 @export + Validation 0b；ADR-0005 from_dict 字段注；architecture.yaml cross_module_data_types reason 补 @export；consistency-failures 补二阶教训(API"可调用"≠"按预期工作"，spike 须断言行为正确性非仅 has_method)
- harness 修为 @export 后 P3-4a/b/c 桌面全 PASS —— 用户的 WASM run 现验证正确模式
- ⚠️ /architecture-review 复核范围再增：ADR-0001 @export 细则 + Key Interfaces 全改
- spike 待人工：P1/P4 导出量体积(装 Web 模板)、P2/P5 Douyin IDE、P3-6 触控、QQ-ADR8-01/03 坐标实测

## Session Extract — 官方适配器只支持 4.5 的重大发现 2026-06-29
- 联网核实官方 Godot 集成指南(developer.open-douyin.com)：**官方「Godot 开发者插件」仅支持 Godot 4.5(推荐)、「不支持自定义」版本——未列 4.6/4.6.3**。印证项目 VERSION.md 早标的风险 + ADR-0007 最高风险项
- 项目全 pin 4.6.3(VERSION/CLAUDE/9 ADR/tech-pref)，与平台现实冲突。ADR-0007 已预案降级 4.5
- 用户决策：**先用 4.6.3 跑 spike 经验性测试**(若适配器集成 §4 P2 拒绝 4.6.3=实证确认仅 4.5 → 再 re-pin 4.5)。4.5 风险更低(4.6 的 Jolt/glow/D3D12 变更不影响 2D Compatibility)
- 下载入口已记 RUNBOOK §0：IDE = developer.open-douyin.com 小游戏开发者工具**独立版本**；适配器 = 同站 Godot 集成指南
- 已记：RUNBOOK §0(下载 URL + 4.5-only 警告 + 备一份 4.5)；ADR-0007 Risks(HIGH 风险实证升级 + re-pin 预案)
- ⚠️ 潜在后续大动作：若 spike 确认 4.6.3 不兼容 → 引擎 re-pin 4.5(改 VERSION+CLAUDE+全 ADR Engine 字段+tech-pref，须用户拍板)

## Session Extract — Douyin SDK 1.0.3 安装 2026-06-29
- 用户下载 douyin_godot_sdk_1.0.3_517fd34.zip(需登录平台，Claude 无法代下)；Claude 解压放入 prototypes/wasm-export-spike/addons/(ttsdk + ttsdk.editor)
- 文件级关键发现：ttsdkeditor.gdextension **compatibility_minimum="4.5"、无 maximum** → GDExtension 向上兼容，预计可在 4.6.3 加载；官方仅"支持"4.5，4.6.3 加载亦脱离支持区
- SDK 自带 Web 导出模板(templates/web_release.zip / web_debug.zip)→ 可能无需单独装 Godot 官方 Web 模板
- 决定性测试后移：从"插件能否启用"(≥4.5 技术上允许)→"导出+Douyin 运行时是否工作于 4.6.3"
- 待用户：Godot 4.6.3 打开工程 → Plugins 启用 ttsdk/ttsdk.editor → 看 Output 加载结果回报
- macOS Apple Silicon 坑(已修)：dylib 报 library load disallowed by system policy + Brotli 未声明(Brotli 是扩展注册类，dylib 没加载→类缺失)。根因 dylib 原签名 adhoc,linker-signed(0x20002) arm64 拒载。修：xattr -dr quarantine + codesign --force --sign -(重签为正常 adhoc 0x2，verify 通过)+ 重启 Godot
- ✅✅ **重启后 Output 干净，ttsdkeditor GDExtension 在 4.6.3 成功加载**(Brotli 类已注册，无报错)。4.6.3 兼容性正面信号：插件加载关已过(尽管官方文档说仅 4.5)。判定点后移到"导出+Douyin 运行时"
- 待用户：Project→Export→Add 看是否出现抖音导出平台
- ✅✅✅ 4.6.3 导出全程通过(2026-06-29，dummy app_id)：插件加载✅ + 抖音导出平台注册✅ + 导出产出 web 包✅ + 体积 ≈7.2MB(godot.wasm.br 6.5M+js 354K+main.pck 136K[空]+wrapper 68K)≪50MB✅。无害警告：wasm32 无 ttsdkeditor 库(editor 插件不进运行时，正常)
- 4.6.3 兼容性初步结论：官方称"仅 4.5"，但插件加载+导出+出包全过，无真不兼容。**最终判定待 P2/P5(Douyin IDE/真机运行)**，需真 AppID(平台创建小游戏)。ADR-0007 维持 Proposed 直至 P2/P5
- P4 体积风险大幅消解(引擎压缩后 6.5M，2D 像素 50MB 上限基本无忧)
- 已记：ADR-0007 Validation「Spike 部分结果 2026-06-29」+ RUNBOOK §5a-bis(macOS codesign 坑)
- 下一步：① 试把导出包(dummy appid)拖进 Douyin IDE 看能否预览/渲染；或 ② 平台创建小游戏取真 AppID 再正式跑 IDE(P2/P5/P3-6/坐标)
- IDE 实测(2026-06-29，dummy appid)：包被 IDE 正常导入、抖音运行时**启动**(iPhone 15 Pro 模拟器显示 SDK「正在初始化」绿条)=P2 部分过；但**卡在 init、屏幕空白、Godot 未渲染**=P5 未过。判断为 dummy appid 致 SDK init 不通过(非 4.6.3 兼容问题)
- 4.6.3 兼容性证据链至此：插件加载✅+导出✅+出包✅+体积✅+IDE 接受并启动运行时✅；唯一未验=越过 SDK init 后的真实渲染/触控/坐标 → **硬卡在需要真 AppID**
- 🔑 关键路径收敛到一件事：**developer.open-douyin.com 注册+创建小游戏取真 AppID** → 填回预设重导 → 再跑 IDE 验 P5/P3-6/QQ-ADR8-01。这条=资质任务(production/platform/douyin-developer-qualification.md)，建议立即推进

## Session Extract — 启动代码实现：control-manifest 完成 2026-06-29
- 用户决定：先启动代码实现，AppID 注册后再收尾 spike(代码/测试不需 AppID；ADR-0007 仅挡大规模内容投入，代码可并行)
- 已写 docs/architecture/control-manifest.md(Manifest Version 2026-06-29)：7 个 Accepted ADR(0001-0006+0008部分)抽成分层规则表，每条标 source ADR
- 收进关键新规则：Foundation=Resource 载体+全字段@export+禁裸RefCounted/plain var；Core=零RNG+宿主调节面+Array[RoundEvent]+状态机重入；Feature=#10 Service+Overlay拆分+Autoload名==class_name，决策4坐标 spike-pending
- 末尾 Pending ADR 提示：ADR-0007/0009(Proposed)规则未纳入，待 Accept 重生成
- 实现链下一步：/create-epics layer:foundation → /create-stories [epic] → /dev-story(真正写代码+测试，headless 不需 AppID)
- lean 模式：TD-MANIFEST 门跳过

## Session Extract — Foundation 史诗创建完成 2026-06-29
- 已写 production/epics/{game-tuning-config,entity-database,floor-layout-data}/EPIC.md + index.md
- 覆盖：entity-database 6/6 ✅（最干净）；game-tuning-config TR-tuning-002 TuningFormulas 归属 ⚠️部分；floor-layout-data TR-floor-004 BFS 算法 ⚠️部分 + **Design Constraints 节 GDD 缺口**（#4→#2 成长分布，关卡内容 story 前须补，结构/加载/校验 story 不受影响）
- 实现顺序（ADR-0002 启动依赖序）：TuningConfig → EntityDB → FloorDB
- lean：PR-EPIC 门跳过
- 实现链进度：control-manifest ✅ → create-epics(Foundation) ✅ → 下一步 /create-stories [epic]（建议从 game-tuning-config 起）→ /dev-story 真正写代码(headless 测试，不需 AppID)
- Core 层史诗待 Foundation 推进后 /create-epics layer:core

## Session Extract — game-tuning-config story 拆分完成 2026-06-29
- 已写 3 个 story 到 production/epics/game-tuning-config/：
  - story-001 TuningConfig 数据类型+加载+只读访问（TR-tuning-001/003，ADR-0001 主，含 @export 强提示+AC-TC-11/12/13）
  - story-002 validate_tuning_config 校验器（TR-tuning-001 校验面，ADR-0005 主，AC-TC-01~06/15~19 共12条）
  - story-003 TuningFormulas 静态公式类（TR-tuning-002，ADR-0003 主，AC-TC-07~10/14，内锁定独立静态类解 ⚠️部分覆盖）
- 均 Logic、headless 可测、GDD AC 直转 QA test cases；lean→QL-STORY-READY 跳过；无 qa-plan→从 GDD 生成 specs
- 实现建议序：003(纯函数无依赖最易)→001(类型+加载)→002(校验依赖001)
- 实现链：control-manifest✅→create-epics✅→create-stories(tuning)✅→story-readiness(003)✅→**dev-story(003) 实现中**
- 其余 Foundation 史诗(entity-database/floor-layout-data)story 待拆

## Session Extract — /dev-story story-003 TuningFormulas 完成 2026-06-30
- 已创建：src/tuning_config/tuning_formulas.gd（4 个 static func：damage_player/damage_monster/n_rounds/calc_player_ATK）
- 已创建：tests/unit/tuning_config/tuning_formulas_test.gd（8 个测试函数：5 AC + 3 边界值）
- 实现要点：maxi() 代替 max() 用于 int（GDScript 4 infix）；n_rounds 先 float() 再除再 ceil 再 int（防整数截断）；calc_player_ATK 空数组 guard（Array.max() 空时返回 null）
- GDUnit4 插件(addons/gdunit4/)未装 → runner 报 File not found；语法检查干净无报错
- 阻断项：GDUnit4 插件须安装后才能 headless 跑通测试(ADR-0004 Validation #1/2)；插件从编辑器 AssetLib 安装
- 下一步：① Godot 编辑器安装 GDUnit4 → headless 跑通 8 个测试 → /code-review → /story-done story-003；② 或先继续 story-001(TuningConfig 数据类型+加载)

## Session Extract — GDUnit4 v6 不兼容 4.6.3 + 引擎 re-pin 证据收敛 2026-06-30
- 用户经 AssetLib 装 GDUnit4 v6.0.0，但装进了 spike 工程(prototypes/wasm-export-spike/addons/gdUnit4，大写U)，非主项目
- 🔴 **GDUnit4 v6.0.0 在 Godot 4.6.3 编译失败**：内部 get_as_text() 传1参(4.6.3 为0参)+ current_dir 不存在 → CmdTool 整链 Compilation failed，跑不了任何测试。这是 ADR-0004 Risks 预设的"安装时验证框架"步骤，结果 FAIL
- 附带发现：tests/gdunit4_runner.gd 对 v6 是错的(引用不存在的 GdUnitRunner.gd；v6 入口是 bin/GdUnitCmdTool.gd；大小写 gdunit4 vs gdUnit4)——runner 须修
- ✅ story-003 TuningFormulas 逻辑用独立 preload 脚本在 4.6.3 实测 **8/8 全过**(暂代 GDUnit4 跑通前的逻辑验证)；代码正确，但 /story-done BLOCKING 门(GDUnit4 测试通过)未满足
- 🔑🔑 **引擎 re-pin 证据收敛**：(a) Douyin 官方适配器仅支持 4.5；(b) GDUnit4 v6 不兼容 4.6.3 —— 两个独立工具都指向 **Godot 4.5**。强烈建议 re-pin 4.5(ADR-0007 Migration 已预案；4.5 风险更低)
- 主项目仍无 project.godot（src/tests 写在主目录但非 Godot 工程）——re-pin/setup 时一并初始化
- 已记：story-003 状态、ADR-0004 版本兼容 FAIL 注、本条
- 待用户决策：是否 re-pin 到 Godot 4.5（解 Douyin 适配器 + GDUnit4 双问题），还是先找 4.6.3 兼容的 GDUnit4 版本

## Session Extract — 引擎 re-pin 4.6.3 → 4.5.2 完成 2026-06-30
- 决策：re-pin 到 **Godot 4.5.2**（4.5 分支最新稳定补丁，4.5 现 partial support）。理由实证：Douyin 适配器仅支持 4.5 + GDUnit4 v6 不兼容 4.6.3
- 用 /setup-engine 做权威 pin：重写 VERSION.md（pin 4.5.2 + Re-pin Note + 4.6 降为 NOT USED + Douyin 注记对齐 + GDUnit4 须 4.5 兼容版 + ADR 复审提示）；CLAUDE.md + technical-preferences Engine 字段
- 扫描更新 Engine 字段：9 个 ADR（0007/0008/0009 附 4.6 特性复审注）、control-manifest、epics/index、3 个 story、game-concept、art-bible
- 有意保留 4.6.3 的历史记录：spike 实测事实、GDUnit4 失败发现、VERSION Re-pin Note、SUPERSEDED architecture.md、story-003 spike 记录、review/gate/traceability 历史报告、archive/
- 4.5 仍 post-cutoff（cutoff ~4.3）：breaking-changes/deprecated-apis 参考文档保留（覆盖 4.4/4.5 适用；4.6 条目标 NOT USED）
- ⚠️ 遗留语义复审：ADR-0007（D3D12/glow 4.6 引用）、ADR-0008（4.6 Dual-focus 引用）正文须在下次 /architecture-review（全新会话）复审剔除
- 下一步（人工）：① 装 **Godot 4.5.2** + 4.5 兼容的 GDUnit4；② 初始化主项目 project.godot(4.5，含 src/tests/addons)；③ 跑通 TuningFormulas 8 测试（逻辑已验 8/8）；④ 真 AppID 重导验 Douyin IDE
- 主项目仍无 project.godot（re-pin/setup 时一并初始化）

## Session Extract — 4.5.2 复测：GDUnit4 跑通 + re-pin 实证 2026-06-30
- 用户替换 /Applications/Godot.app → Godot 4.5.2.stable；Godot Launcher 也已装
- ✅✅ **同一 GDUnit4 v6.0.0 在 4.5.2 编译并跑通**：story-003 TuningFormulas 8 测试经真 GDUnit4 框架全 PASSED(8 cases/0 failures/279ms，spike 工程)。确认 v6 编译错误是 4.6.3 专有 → re-pin 4.5.2 决策实证正确
- TuningFormulas 逻辑独立脚本亦 8/8(4.5.2)
- **版本锁定**：GDUnit4 v6.0.0 + Godot 4.5.2 = 已验证兼容组合(记入 ADR-0004)；CLI 入口 bin/GdUnitCmdTool.gd(大写U)+ --ignoreHeadlessMode
- story-003 状态 → 实现+测试通过(spike 内验证)；**形式化 /story-done 前置**：主项目须初始化 project.godot + addons/gdUnit4 + 在主项目重跑
- 下一步：① 起草/初始化主项目 project.godot(4.5/GDScript/Compatibility) + 装 GDUnit4 v6 进主 addons + 修 tests/gdunit4_runner.gd(v6 入口) ② 主项目内重跑 8 测试 → /code-review → /story-done story-003 ③ 真 AppID 重导验 Douyin IDE

## Session Extract — 主项目初始化 + GDUnit4 在主项目跑通 2026-06-30
- ✅ 已建主项目 project.godot：Godot 4.5.2 / GDScript / **Compatibility 渲染**(gl_compatibility，ADR-0007 硬约束) / window stretch canvas_items / 触控模拟 / GDUnit4 plugin enabled；Autoload 留空+注释 ADR-0002/0003 顺序(待各系统实现逐个启用)
- ✅ 从 spike 拷 GDUnit4 v6.0.0 → 主项目 addons/gdUnit4
- ✅✅✅ **主项目内 GDUnit4 实跑 story-003 8/8 PASSED**(8 cases/0 failures/285ms，Godot 4.5.2)——满足 /story-done 的 Logic story BLOCKING 门
- 运维细节：fresh 项目须先 `godot --headless --import` 建 .godot/global_script_class_cache.cfg(305 类含 GdUnit)，否则 GdUnitTestCIRunner class_name 未注册
- 修 tests/gdunit4_runner.gd → 重定向桩(旧 load GdUnitRunner.gd 在 v6 失效)；权威命令改为官方 bin/GdUnitCmdTool.gd(--import 前置 + --ignoreHeadlessMode)，记入 ADR-0004 §3
- story-003 状态 → 实现+测试通过(主项目正式验证)，可 /code-review → /story-done
- 注：spike 工程残留 tuning 临时文件 + verify_*.gd（rm 被拦，可手动清；不影响）
- ✅ /code-review: score 82, W1(命名)+W2(类型) 已修, 重测 8/8 通过
- ✅ /story-done story-003: COMPLETE 2026-06-30 — 5/5 AC，GDUnit4 8 test cases / 0 failures，Godot 4.5.2
- 下一步：story-001(TuningConfig 数据类型+加载，Logic，ADR-0001 主) 或 story-002(校验器，Logic，ADR-0005 主)

## Session Extract — /dev-story story-001 TuningConfig 数据类型+加载 2026-06-30
- 已创建：src/tuning_config/floor_tuning_row.gd(FloorTuningRow Resource+@export)
- 已创建：src/tuning_config/tuning_config_data.gd(TuningConfigData Resource+@export+Array[FloorTuningRow])
- 已创建：src/tuning_config/tuning_config.gd(TuningConfig extends Node Autoload；get_tuning_config duplicate(true)/get_floor_tuning/_inject_config_for_test/_show_error_screen)
- 已创建：data/tuning_config.json(GDD T4/T5/T6 权威数值 floor1-3)
- 已创建：tests/unit/tuning_config/config_type_and_loader_test.gd(5 测试函数 AC-TC-11/12/13+边界2)
- GDUnit4 Godot 4.5.2 实跑：5/5 PASSED(188ms)
- 实现要点：GDScript 每文件只能一个 class_name(FloorTuningRow 拆独立文件)；duplicate(true)=深拷贝嵌套 Array[FloorTuningRow]；_inject_config_for_test 绕开文件加载供单测用
- ✅ /code-review story-001: score 83。W1(duplicate(true)→duplicate_deep + 补嵌套行隔离测试，揭示 AC-TC-13 原盲点) + W2(_initialized 仅 _config!=null 置 true，fail-fast) + I1(doc 注释) + I2(_inject assert debug build) 全修
- 改后重跑 6/6 PASSED(含新增 test_get_tuning_config_nested_row_is_deep_copied)
- ✅✅ /story-done story-001 COMPLETE 2026-06-30 — 3/3 AC + 边界 + 嵌套隔离 = 6/6 GDUnit4 PASSED
- TuningConfig epic 进度：001 ✅ + 003 ✅ Complete；剩 002(校验器)
- 下一步：story-002(validate_tuning_config 校验器，依赖 001 的 TuningConfigData 类型，现已就绪)

## Session Extract — /dev-story story-002 validate_tuning_config 校验器 2026-06-30
- 已创建：src/tuning_config/validation_result.gd(ValidationResult RefCounted: is_valid+errors[]+add_error)
- 已创建：src/tuning_config/tuning_config_validator.gd(TuningConfigValidator 静态类；validate_dict(缺失+范围) + validate(仅范围) 双函数；13 个 code 常量)
- 已创建：tests/unit/tuning_config/config_validator_test.gd(34 测试函数，覆盖 12 AC + 边界合法值 + 负向对照)
- 决策：① 双函数(AC-TC-06 缺失走 validate_dict，AC-TC-17 值非法走 validate；实例无法区分"未提供"vs"0"，story Impl Notes 已预设) ② FLOOR_NUMBER_NON_POSITIVE 单独 code ③ error.field=snake_case
- ⚠️ 纠偏：engine-programmer 初版违反 snake_case 决策(用了 GDD 大小写 base_ATK/N_max + _to_gdd_field_name 翻译)。已全部改回 snake_case(移除翻译函数 + validator/test 各 9 字段串 replace_all)
- GDUnit4 4.5.2 实跑：validator 34/34；全 tuning_config 套件 48/48(formulas 8+validator 34+loader 6)
- 偏差(待 story-done 记)：story 写的单一 validate(config) 签名 → 实际两函数 validate_dict/validate(有据，符合 story Impl Notes + ADR-0005)
- ✅ /code-review story-002: score 76。W3(errors→Array[Dictionary] 静态类型) 修；W1(floor_number≤0 per-row fail-fast) + I1(int 截断) 加注释；W2(EMPTY 复用于非Array)+I2(field 裸名vs路径) 接受现状(裸 snake 名正是既定决策)。doc 注释 GDD 大小写示例→snake
- 改后重跑 48/48 全过(formulas8+validator34+loader6)
- ✅✅✅ /story-done story-002 COMPLETE WITH NOTES 2026-06-30 — 12 AC / 34 测试全过；偏差记录(双函数签名+snake纠偏)
- 🎉🎉 **TuningConfig epic (#3) 全完成** — 001✅+002✅+003✅，Foundation 第一个 epic 齐活；全套件 48/48 PASSED
- 下一步：① 继续 Foundation 其余 epic(entity-database / floor-layout-data 拆 story) ② 或先 git commit 落盘(re-pin + 3 story 大量改动) ③ 整个 TuningConfig 完成可考虑 /sprint-plan 正式排
