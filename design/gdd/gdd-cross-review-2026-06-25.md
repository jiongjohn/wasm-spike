# Cross-GDD Review Report
**Date**: 2026-06-25
**Scope**: Full (Consistency + Design Theory + Scenario Walkthrough)
**GDDs Reviewed**: 5 (#1–#5, all Approved)
**Systems Covered**: 游戏实体数据库 / 楼层关卡数据 / 游戏调参配置 / 玩家属性成长 / 确定性回合战斗
**Pillars**: P1「看得见的成长」(真北) / P2「确定性+容错」/ P3「三秒上手」/ P4「每层都有新发现」
**Anti-Pillars**: NOT 随机数战斗 / NOT 打断式广告 / NOT 加速类广告 / NOT 联网 / NOT 复杂装备搭配

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

**None.**

### Warnings (should resolve, won't block)

**W-01 — entity-database.md 下游依赖列表缺少 #2 floor-layout-data**
entity-database.md Dependencies L283–294 列出下游 #4/#5/#6/#7/#8/#14/#16，**不包含 #2**。
但 floor-layout-data.md 明确声明 #1 为上游硬依赖（F6/F-K1/F-T1 校验）。
→ 修复：在 entity-database.md 下游依赖表追加「#2 楼层关卡数据系统 | 硬依赖 | F6/F-K1/F-T1 校验」

**W-02 — entity-database.md 包含陈旧的「MVP(3–5 层)」文本**
entity-database.md C6 写「**MVP(3–5 层)不含 Boss**」，但 MVP 已在第 4 轮评审后锁定为 3 层。
→ 修复：改为「**MVP（3 层，固定）不含 Boss**」

**W-03 — entity-database.md GDD 头部 Status 字段与 systems-index 不符**
GDD 头：「Status: Revised (四轮 design-review, NEEDS REVISION) — pending re-review」
systems-index：「Approved」
→ 修复：GDD 头部改为「Approved」

**W-04 — combat-system.md Interactions 表中 forecast_combat 保留旧签名**
L91：`forecast_combat(monster_id) -> CombatForecast`（旧签名）
正式接口已更新为 6 参数版本（Dependencies 接口约定节）。
→ 修复：更新 L91 为 `forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp) -> CombatForecast`

**W-05 — MVP 阶段金币无消耗点（经济可读性缺口）**
#8 掉落奖励（MVP）发放 gold_drop 金币，但 #16 商店（VS）才提供消耗点。
MVP 3 层玩家积累 40–80 金币无处花用，可能对 P3「三秒上手」造成轻微困惑。
→ 建议：在 #12 HUD 设计时加「金币：待解锁」工具提示，或在 game-concept 中说明此为 VS 预告。

---

## Game Design Issues

### Blocking

**None.**

### Warnings

**D-01 — #13 游戏状态管理的信号连接约束未跨 GDD 声明**
combat-system.md C7 要求「本系统无 await」，并说明「若 #13 的接收函数用了 await，逻辑/动画解耦会被破坏」。
但此约束仅存在于 combat-system.md 内部——#13 设计者若不知此约束，可能在 player_died() 处理器中加 await，
导致死亡处理在战斗循环内同步执行，产生破损状态转换。
→ 修复：在 combat-system.md Dependencies 中将 #13 条目明确为「须用 CONNECT_DEFERRED 或确保回调无 await」

### No Issues Found

- **P1 成长内核一致性** ✓ 三个成长爽感瞬间（武器/盾牌/宝石）分布 3 层内，调参曲线、叠加规则、回合压缩三路对齐
- **单一进度循环** ✓ 5 个 GDD 服务同一「移动→战斗/拾取→属性跳升→上楼」循环，无竞争循环
- **认知负荷 ≤ 2 项主动决策** ✓ 战斗全被动，导航+钥匙路由各 1 项，符合 P3
- **无主导策略问题** ✓ HIGHEST_WINS 使装备升级顺序而非选择，设计有意为之
- **支柱对齐 5/5** ✓ 全部系统 Player Fantasy 可追溯到支柱
- **Anti-Pillar 检查全部通过** ✓ 确定性/无强制广告/无加速广告

---

## Cross-System Scenario Issues

**Scenarios walked**: 3
1. 捡 shield_iron → 立即撞 goblin（装备→战斗交接）
2. 战斗中 HP 归零 → 触发死亡（多系统信号链）
3. 清完 floor 1 → 上楼过渡（楼层状态持久化）

### Blockers

**None.**

### Warnings

**S-01 — 死亡信号在战斗循环内同步触发（场景 2）**
系统链：#5 → #4.apply_damage() → #4 emits player_died() → 若 #13 用直接连接，死亡处理在 apply_damage() 调用栈内同步执行。
若 #13 修改游戏场景，#5 的战斗循环尚未返回，CombatResult 尚未生成。
→ #13 GDD 设计时须硬性要求 player_died() 接收器使用 CONNECT_DEFERRED（已在 D-01 合并记录）

### Info

**S-02 — Floor 过渡运行时状态（场景 3）**
floor-layout-data F10 声明「运行时格子状态由 #9 维护」但 #9 未设计。
正常的下游 GDD 待设计缺口，不阻断现有 GDD 正确性。
→ 设计 #9 时须显式声明：「维护每层已清除格子的运行时快照」

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| entity-database.md | 下游依赖列表缺 #2（W-01）| Consistency | Warning |
| entity-database.md | 陈旧文本「3–5 층」（W-02）| Consistency | Warning |
| entity-database.md | 头部 Status 字段不符（W-03）| Consistency | Warning |
| combat-system.md | Interactions 表旧签名（W-04）| Consistency | Warning |
| combat-system.md | #13 约束未跨 GDD 声明（D-01）| Design Theory | Warning |

---

## Verdict: **CONCERNS**

5 个 Warning，0 个 Blocking。架构设计可以开始。

W-01~W-04 集中在文档格式清洁度（3 个在 entity-database.md，1 个在 combat-system.md），预计各需 30-120 秒修复。
D-01 需要在 #13 设计时落实，不需要立即修改现有 GDD。
W-05（金币 MVP 可读性）是设计传播问题，不需修改已批准 GDD。

**推荐下一步**：快速修复 entity-database.md 三处（W-01/W-02/W-03）+ combat-system.md 两处（W-04/D-01），然后运行 `/create-architecture`。
