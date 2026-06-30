# Systems Index: 像素魔塔·无尽塔 (Pixel Tower)

> **Status**: Approved
> **Created**: 2026-06-23
> **Last Updated**: 2026-06-24
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《像素魔塔·无尽塔》是一款怀旧像素风回合制爬塔游戏,核心循环是「点格移动 → 开门 → 确定性战斗 → 数值跳涨 → 上楼」。游戏的机械范围相对精简:以「确定性(无随机数)战斗 + 可见数值成长」为核心差异化,MVP 共 13 个系统,全部用手工固定关卡。随机事件层在 Alpha 才引入,届时需配可解性验证器。经济层分两轨:金币(战斗掉落,商店消费)+ 钥匙碎片(探索积累,激励广告载体)。

**设计顺序原则**:Foundation → Core → Feature → Presentation;瓶颈系统(玩家属性与成长系统)最先设计,其余系统依赖它的接口。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 游戏实体数据库 | Foundation | MVP | Approved | design/gdd/entity-database.md | — |
| 2 | 楼层关卡数据系统 | Foundation | MVP | Approved（第2轮复评 2026-06-25；实现前置：架构 ADR + F-SC1 AC 待补充） | design/gdd/floor-layout-data.md | — |
| 3 | 游戏调参配置 | Foundation | MVP | Approved（第2轮复评 2026-06-25；实现前置：架构 ADR + TuningFormulas 函数归属 ADR） | design/gdd/game-tuning-config.md | — |
| 4 | 玩家属性与成长系统 | Core | MVP | Approved（第9轮复评 2026-06-25；实现前置:GUT→GDUnit4 ADR 待 TD） | design/gdd/player-stats-growth.md | 1, 3 |
| 5 | 确定性回合战斗系统 | Core | MVP | Approved（复评 2026-06-25；实现前置：架构 ADR 须在实现前完成，含数据类型定义 + GUT→GDUnit4 框架选型） | design/gdd/combat-system.md | 1, 3, 4 |
| 6 | 网格移动与交互系统 | Core | MVP | Approved（2026-06-29 Round 6；6轮评审 50+ Blocking 全闭合；触控拦截方案B锁定；OQ#2 ADR-0003 关闭。2026-06-29 #10 评审同步修订：CTA 设计废止 → AC-COMB-7 RESOLVED-VOID、AC-COMB-2b 解锁、新增 PREVIEWING 目标格高亮、OQ#1 关闭） | design/gdd/grid-movement.md | 1, 2, 10 |
| 7 | 钥匙与门系统 | Core | MVP | Not Started | — | 1, 6 |
| 8 | 掉落奖励系统 | Economy | MVP | Not Started | — | 1, 4, 5 |
| 9 | 楼层进程系统 | Gameplay | MVP | Not Started | — | 2, 6, 7 |
| 10 | 战斗预演系统 | Gameplay | MVP | In Revision（第3轮复评 2026-06-29：MAJOR REVISION → 根因 A/B/C 已会话内修订闭合：LOSE 改纯「会死」定性展示（废弃数学错误的「能撑 K 回合」公式）、show_overlay 退回 3 参（与 #6 一致，#6 无需改）、AC 全面纠正（删错误 K 测试/锁 damage_label·hint_label 节点名/grep 白名单/const→var）。根因 D 方向已定（拆 CombatForecastService(Autoload)+CombatForecastOverlay(SceneNode)），**实现前 BLOCKING 前提待 technical-director 走 /architecture-decision**：ADR-0003 宿主修订 + #6 对 Overlay 访问方式同步 + 整体 Viewport 架构（OQ#5）。待第4轮复评） | design/gdd/combat-forecast.md | 5 |
| 11 | 数值反馈视觉系统 | Presentation | MVP | Not Started | — | 4, 5 |
| 12 | HUD 系统 | UI | MVP | Not Started | — | 4, 7, (14) |
| 13 | 游戏状态管理 | Gameplay | MVP | Not Started | — | 4, 5, 6, 7, 9 |
| 14 | 钥匙碎片经济系统 ⚠️ | Economy | VS | Not Started | — | 4, 7 |
| 15 | 容错安全机制 | Gameplay | VS | Not Started | — | 2, 4 |
| 16 | 商店系统 | Economy | VS | Not Started | — | 1, 2, 4, 8 |
| 17 | 激励广告集成 | Meta | VS | Not Started | — | 14, 13 |
| 18 | 存档系统 | Persistence | Alpha | Not Started | — | 4, 9, 14 |
| 19 | 音效系统 | Audio | Alpha | Not Started | — | 5, 6 |
| 20 | 随机事件系统 ⚠️ | Meta | Alpha | Not Started | — | 2, 4, 9 |
| 21 | 排行榜系统 | Meta | Full Vision | Not Started | — | 13 |

> ⚠️ **系统 14「钥匙碎片经济系统」**:设计评审标注的关键缺失系统——整个激励广告变现逻辑的经济载体。必须在 VS 阶段作为独立子系统设计,不可后期外挂。
>
> ⚠️ **系统 20「随机事件系统」**:「随机仅限地图/事件层,战斗保持确定」的硬约束。Alpha+ 才引入,且必须配套可解性验证器(钥匙充足 + 数值可通过路径)。

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Foundation** | 零依赖的数据基础,其他所有系统读取它 | 实体数据库、楼层关卡数据、调参配置 |
| **Core** | 网格 RPG 的骨架,是核心循环最底层的机制 | 玩家属性、战斗系统、网格移动、钥匙门 |
| **Gameplay** | 核心循环的组合与推进逻辑 | 掉落奖励、楼层进程、战斗预演、状态管理、容错安全、随机事件 |
| **Economy** | 资源的产出与消耗 | 碎片经济、商店 |
| **Presentation** | 把数据变成玩家感知到的爽感 | 数值反馈视觉 |
| **UI** | 玩家面向的信息展示 | HUD |
| **Persistence** | 跨会话的状态持续 | 存档 |
| **Audio** | 声音与音乐 | 音效 |
| **Meta** | 变现、运营、社交 | 激励广告、排行榜 |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems |
|------|------------|------------------|---------|
| **MVP** | 核心循环可运行、可测试「好不好玩」 | **3 层**手工单塔首个可玩版本（原 3-5 层，因 #4 成长事件总数=5 的数学上限于第4轮评审锁定为 3 层；floor 4+ 属 VS） | 13 个 (#1–13) |
| **VS** | 完整游戏体验,可验证完整游戏循环 | 10 层 + Boss + 激励广告 | 4 个 (#14–17) |
| **Alpha** | 所有功能粗稿,关卡内容有量 | 20-30 层多主题 | 3 个 (#18–20) |
| **Full Vision** | 抛光 + 运营功能 | 正式上线 | 1 个 (#21) |

---

## Dependency Map

### Foundation Layer(零依赖,最先设计)

1. **游戏实体数据库** — 所有怪物/道具/钥匙的静态定义;6 个系统依赖它
2. **楼层关卡数据系统** — MVP 手工地图格式;楼层进程、移动、容错都读它
3. **游戏调参配置** — 所有可调数值的集中存放;编码规范强制数据驱动

### Core Layer(依赖 Foundation)

4. **玩家属性与成长系统** → 依赖: 1, 3 — **最大瓶颈**:8 个系统依赖此系统;最先设计
5. **确定性回合战斗系统** → 依赖: 1, 3, 4 — 核心循环心脏;零随机数
6. **网格移动与交互系统** → 依赖: 1, 2 — 点格移动的物理基础
7. **钥匙与门系统** → 依赖: 1, 6 — 「门作为必经路径」的执行者

### Feature/Gameplay Layer(依赖 Core)

8. **掉落奖励系统** → 依赖: 1, 4, 5 — 战斗后金币/稀有装备分发(全确定性)
9. **楼层进程系统** → 依赖: 2, 6, 7 — 楼梯上下行、楼层状态持久化
10. **战斗预演系统** → 依赖: 5 — 伤害预演 + 两步确认 UI
14. **钥匙碎片经济系统** → 依赖: 4, 7 — 碎片产出/消耗,激励广告载体(VS)
15. **容错安全机制** → 依赖: 2, 4 — 保底资源 + 卡关出路(VS)
16. **商店系统** → 依赖: 1, 2, 4, 8 — 金币消费场所(VS)

### Presentation Layer(依赖 Feature)

11. **数值反馈视觉系统** → 依赖: 4, 5 — 飘字、升级闪光、属性跳涨动画
12. **HUD 系统** → 依赖: 4, 7, (14) — 属性展示、渐进解锁、DEF 微教学
13. **游戏状态管理** → 依赖: 4, 5, 6, 7, 9 — 开始/进行/死亡/通关/重玩

### Polish/Meta Layer(Alpha+)

17. **激励广告集成** → 依赖: 14, 13
18. **存档系统** → 依赖: 4, 9, 14
19. **音效系统** → 依赖: 5, 6
20. **随机事件系统** → 依赖: 2, 4, 9 — **需可解性验证器**
21. **排行榜系统** → 依赖: 13

---

## Recommended Design Order

| 顺序 | 系统 | 优先级 | 层级 | 推荐专家 | 工作量 |
|---|---|---|---|---|---|
| 1 | 游戏实体数据库 | MVP | Foundation | game-designer, systems-designer | S |
| 2 | 楼层关卡数据系统 | MVP | Foundation | game-designer, level-designer | S |
| 3 | 游戏调参配置 | MVP | Foundation | systems-designer | S |
| 4 | **玩家属性与成长系统** ⭐ | MVP | Core | game-designer, systems-designer | M |
| 5 | 确定性回合战斗系统 | MVP | Core | game-designer, systems-designer | M |
| 6 | 网格移动与交互系统 | MVP | Core | game-designer | S |
| 7 | 钥匙与门系统 | MVP | Core | game-designer | S |
| 8 | 掉落奖励系统 | MVP | Feature | game-designer, economy-designer | S |
| 9 | 楼层进程系统 | MVP | Feature | game-designer | S |
| 10 | 战斗预演系统 | MVP | Feature | game-designer, ux-designer | S |
| 11 | 数值反馈视觉系统 | MVP | Presentation | game-designer, technical-artist | S |
| 12 | HUD 系统 | MVP | Presentation | ux-designer, ui-programmer | M |
| 13 | 游戏状态管理 | MVP | Presentation | game-designer | S |
| 14 | **钥匙碎片经济系统** ⚠️ | VS | Feature | economy-designer, game-designer | M |
| 15 | 容错安全机制 | VS | Feature | game-designer, systems-designer | S |
| 16 | 商店系统 | VS | Feature | game-designer, economy-designer | M |
| 17 | 激励广告集成 | VS | Meta | game-designer, devops-engineer | M |
| 18 | 存档系统 | Alpha | Persistence | lead-programmer | S |
| 19 | 音效系统 | Alpha | Audio | audio-director, sound-designer | M |
| 20 | 随机事件系统 ⚠️ | Alpha | Meta | game-designer, systems-designer | L |
| 21 | 排行榜系统 | Full Vision | Meta | game-designer, devops-engineer | S |

> 工作量估算:S = 1 次会话,M = 2-3 次会话,L = 4+ 次会话。
> 同一层级的独立系统可以并行设计。

---

## Circular Dependencies

无发现。所有依赖关系是单向有向无环图(DAG)。

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 玩家属性与成长系统 | Design + Scope | 「成长爽快而非烧脑」的平衡是成败关键;数值曲线双极化风险(碾压/死局) | 第二轮原型(N≥3 真实用户,8-10 层+难度拐点)在 VS 前验证;设计时定义容错带宽(≤1.3x) |
| 确定性回合战斗系统 | Design | 「确定性」要同时让轻用户不挫败、让有经验的玩家感觉有掌控 | 战斗预演 + 容错机制双保险;DEF 上限约束防止「1 伤死磨」退化 |
| 钥匙碎片经济系统 ⚠️ | Design + Business | 变现的核心载体;「翻倍/复活补偿」逻辑必须对确定性游戏有意义 | 独立 GDD 设计;先定经济模型再定 SDK 接入方式 |
| 随机事件系统 ⚠️ | Technical | 随机楼层布局可能产生不可解种子(钥匙不够/打不过) | Alpha+ 才引入;必须配可解性验证器(洪水填充 + 钥匙状态追踪),实现成本需提前评估 |
| 激励广告集成 | Technical | 抖音 SDK 对 Godot WASM 导出的兼容性未验证;个人开发者资质审核周期 | 现在即申请字节开发者平台资质(并行);VS 阶段做 SDK 技术 spike |
| 楼层关卡数据系统 | Scope | 手工平衡 3-5 层的确定性数值曲线是首作设计瓶颈 | 用原型发现的调参起点(0.3s/回合、max(1,ATK-DEF));用电子表格模拟 10 层轨迹后再手工排布 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 21 |
| Design docs started | 4 |
| Design docs reviewed | 1 |
| Design docs approved | 1 |
| MVP systems designed | 4 / 13 |
| VS systems designed | 0 / 4 |

---

## Design Constraints (from Design Review & Art Bible)

以下约束必须贯穿所有系统 GDD:

- **随机边界**:随机仅限于「地图/事件层」且仅 Alpha+。战斗结算永远确定性。
- **掉落永远确定性**:金币数量固定;稀有装备是保证掉落,不是概率掉落。
- **DEF 上限约束**:玩家每回合对任意怪物的伤害 ≥ 敌 HP / N_max(N_max 建议 ≤20),防止「1 伤死磨」退化。详见 combat-system GDD。
- **容错带宽**:最优路线 HP / 随机路线 HP ≤ 1.3(同楼层),防止确定性最优解强制化。
- **Anti-Pillars**:每个系统 GDD 的 Acceptance Criteria 节必须包含「该系统不引入随机数到战斗结算」「该系统不增加主游戏循环的操作步骤超过现有上限」「激励广告触发点均为玩家主动触发」三项 scope-gate 检查。
- **成长分布约束（#4 玩家属性与成长 → #2 楼层关卡数据，第4轮评审锁定）**:MVP 永久成长事件总数 = 5（数学上限），对应 **MVP 楼层数上限 = 3 层**。#2 floor-layout-data **必须新增 Design Constraints 节**落实:「3 层每层 ≥1 次永久成长事件（effect_type∈{ATK_BOOST,DEF_BOOST,MAXHP_BOOST} 的格 ≥1，不含 HP_RESTORE）、Floor 1 不豁免、单层成长事件 ≤2、同类更弱装备同层 ≤1」。**当前 #2 无该节，约束未落地——为 #4 第5轮复审的跨文档前置阻断,须 producer 协调先行闭合。**

## Next Steps

- [ ] 用 `/design-system 游戏实体数据库` 开始第一个 GDD
- [ ] 按设计顺序逐个完成 MVP 系统 GDD(优先 #4 玩家属性与成长系统,它是最大瓶颈)
- [ ] 每个 GDD 完成后运行 `/design-review` 校验
- [ ] 所有 MVP 系统 GDD 完成后运行 `/gate-check pre-production`
- [ ] **并行高优**:导出 spike + 字节开发者平台广告资质申请
