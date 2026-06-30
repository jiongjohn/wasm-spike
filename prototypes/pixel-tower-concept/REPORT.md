# Concept Prototype Report: 像素魔塔·无尽塔 (Pixel Tower)

> **Date**: 2026-06-23
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

如果玩家在一个网格塔里开门、打怪、捡装备,并在每次战斗中**逐回合看到双方掉血**、
属性数字跳涨闪光,他们会产生「再爬一层」的主动驱动力——而**无随机数的确定性战斗**
靠数值反馈表现层,足以替代 RNG 制造的紧张刺激。

可测量信号:玩家自发想继续往上爬 / 想再来一局,且认可确定性战斗"有战斗感"。

---

## Riskiest Assumption Tested

**「无随机数的确定性战斗能否产生兴奋感?」**

大多数 RPG 靠 RNG(暴击/闪避)制造心跳。魔塔是纯确定的——结果走进去之前就知道。
原型必须回答:靠数值爆发的视觉反馈(逐回合掉血、飘字、属性跳涨)能否替代 RNG 的紧张感?

**结论:成立。** 玩家明确反馈"类型就是这种""效果就是这种"。逐回合战斗动画
(你打它掉血 → 它打你掉血 → 循环到一方倒下)被确认为想要的"回合效果",
确定性不仅没削弱体验,反而契合"可掌控、算得清"的核心爽点。

---

## Approach

构建了一个单文件 HTML 原型(`prototype.html`),3 层网格塔,可在任意浏览器双击运行。
玩家点格移动、点怪触发逐回合战斗、捡钥匙开门、捡装备药水加属性、上下楼往返。

**Path chosen:** HTML
**Reason for path:** 回合制不依赖输入延迟,浏览器能等效测试数字反馈与战斗节奏;
85–90% 一次性成功、零安装、可立即分享。Feel 不是时序敏感的,无需引擎原生渲染。

**Shortcuts taken (intentional):**
- 美术全用 emoji + 色块,无像素素材
- 数值、地图全硬编码;无存档、无菜单、无音效
- 只做黄/蓝两种钥匙;3 层;无激励广告
- 无架构、无抽象,单文件全局状态

---

## Result

- 第一版有一个**字段撞名 bug**(道具的 `t` 字段覆盖了格子的 `t` 类型),导致所有装备药水
  变成隐形不可拾取 → 玩家属性不增长 → 第 2 层被怪物"一刀秒"。修复后数值曲线正常。
- 玩家要求**门必须在通往上层的必经之路上**(原版可绕过)→ 改为"整道墙 + 单一门缺口"
  的隔断设计,门成为强制路径;BOSS 堵死顶层楼梯的唯一入口。
- 玩家要求**战斗逐回合扣血、要有回合效果**(原版瞬间结算)→ 改为 0.3 秒/回合的动画战斗,
  怪物血条实时下降 + 双方飘伤害字。玩家反馈:**"对,效果就是这种。"**
- 玩家要求**能回到下层**补打怪/补捡装备 → 加下楼梯 + 每层状态持久化(已捡/已杀/已开门保留)。
- 最终评价:**"类型就是这种嘛"**——核心循环获得确认。提出的改进集中在
  *内容丰富度*(怪物种类、地形、层数、难度)和*重玩性*(随机事件),而非核心玩法缺陷。

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | 3 轮(初版 → 修 bug/门/数值 → 加往返+逐回合战斗) |
| Prototype duration | ~1 session(单日) |
| Playtesters | 1 internal(开发者本人) |
| Feel assessment | 逐回合战斗节奏(0.3s/回合)被确认为"想要的回合效果";确定性战斗"可掌控、有战斗感" |
| Hypothesis verdict | **PRELIMINARY**(原 CONFIRMED——经 design-review 修正:仅 1 名测试者=开发者本人,属自我验证。"feel 好"可信,但"轻用户在确定性滚雪球下不撞墙"未验证。Vertical Slice 前需 N≥3 真实用户外部验证) |

---

## Recommendation: PROCEED

核心循环(开门探索 → 确定性逐回合战斗 → 数值跳涨 → 推门上楼)获得玩家明确确认,
最危险假设(无 RNG 战斗能否兴奋)被证实成立。所有反馈均为内容量与丰富度的扩展需求,
而非玩法缺陷——这正是原型成功的标志。建议进入正式设计阶段,把丰富度需求作为
GDD 的内容量与调参输入。

---

## If Proceeding

- **Core tuning values discovered:**
  - 逐回合战斗间隔 0.3 秒/回合 = "看得清又不拖沓"的甜点区(GDD 的战斗节奏调参起点)
  - 战斗公式 `玩家伤害 = max(1, ATK − 敌DEF)`、`受击 = max(1, 敌ATK − DEF)` 的确定性结算手感良好
  - 当前 3 层数值曲线偏简单 → 需要更长的塔与更陡的成长曲线
- **Assumptions confirmed:**
  - 确定性战斗 + 数值反馈能替代 RNG 制造爽感(支柱 1、支柱 2 同时立住)
  - "门作为强制路径"是必要设计(玩家主动要求,否则探索失去意义)
- **Assumptions disproved:**
  - 无(核心假设全部成立)
- **Emergent / new requirements(带入设计阶段):**
  - **怪物种类**需扩充(当前 4 种偏少)
  - **地图地形丰富度**需提升(机关、特殊地块、多样布局)
  - **层数**需增加(3 层太短;无尽塔/更长主塔)
  - **难度曲线**需做陡(当前偏平)
  - **随机性事件** —— 决策已定:**仅在地图/事件层随机**(随机楼层、宝箱、事件房),
    **战斗保持确定**,以守住支柱 2「算得清的确定性」。这是 /map-systems 阶段的关键约束。

> Note: HTML 路径已充分验证回合制 feel(非时序敏感),无需补做引擎 feel 原型。

**Next steps:**
1. `/design-review design/gdd/game-concept.md` — 用原型发现校验概念文档
2. `/gate-check` — 确认可推进到 Systems Design
3. `/art-bible` — 基于视觉锚点定像素美术规范
4. `/map-systems` — 拆系统(注意把"随机仅限地图/事件层"作为约束)
5. `/design-system [系统]` — 用上面的调参值填充 Tuning Knobs / Formulas

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  没有破坏核心假设;但暴露出"门若可绕过则探索无意义"——空间布局的强制性是魔塔玩法的隐性支柱。

- **What surprised us that didn't show up in the brainstorm?**
  "战斗要逐回合演出过程"在 brainstorm 里被归到"反馈表现层",但实测发现**回合过程本身**
  (而不只是结果飘字)才是"战斗感"的来源——瞬间结算会丢掉这种感觉。

- **What would we test differently next time?**
  下次原型应至少放进 2 种地形机关和 1 个难度拐点,以便同时验证"丰富度"对"再爬一层"的影响,
  而不仅验证最小循环。

---

> *Prototype code location: `prototypes/pixel-tower-concept/`*
> *This code is throwaway. Never refactor into production.*
