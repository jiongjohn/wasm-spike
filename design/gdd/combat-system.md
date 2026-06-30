# 确定性回合战斗系统 (Deterministic Turn-Based Combat)

> **Status**: Approved（复评 2026-06-25；实现前置：架构 ADR 须完成，含数据类型 + 测试框架选型）
> **Author**: lumen + agents
> **Last Updated**: 2026-06-25（设计评审修订 MAJOR REVISION NEEDED → 修订完成）
> **Implements Pillar**: P2「确定性 + 容错」(战斗无随机数、可预演) + P1「看得见的成长」(伤害飘字与回合压缩 + 伤害数字增长双轨成长信号)

## Overview

确定性回合战斗系统（Deterministic Turn-Based Combat）是《像素魔塔·无尽塔》的**运行时战斗结算引擎**：当玩家在网格上撞向怪物（由 #6 网格移动判定），本系统接管，按固定回合循环逐回合结算双方伤害，直到怪物 HP 归零（玩家胜）或玩家 HP 归零（触发死亡）。每回合的伤害值由 #3 调参配置的权威公式 F1-A（`max(1, player_ATK − monster_DEF)`）与 F1-B（`max(0, monster_ATK − player_DEF)`）决定；本系统从 #4 玩家属性读取 `player_ATK`/`player_DEF`（只读），从 #1 实体数据库读取怪物 `HP`/`ATK`/`DEF`，通过调用 #4 的 `apply_damage()` 施加伤害，并监听 #4 的 `player_died()` 信号终止战斗。**整个结算是纯确定性的——无随机数、无暴击闪避**：给定双方属性，总回合数、总伤害、胜负在战斗开始前即完全可推算，这正是「伤害预演」（#10）得以实现的前提。

对玩家而言，战斗是核心循环里「变强」被反复证明的地方。玩家不在战斗中做操作——半策略性体现在**战斗之前**的选择（先打哪只怪、先开哪扇门），而非回合内。升级武器后，同一只哥布林从铁剑的「打 6 回合」压缩到精钢剑的「打 4 回合」，伤害飘字一跳一跳地落下——这种「可预演的掌控感 + 变强后回合变少的爽感」是本系统服务 P2「确定性」与 P1「看得见的成长」的交汇点。没有它，游戏就只剩移动和开门，「爬塔变强」的核心体验无从落地。

> **设计/实现边界**：谁先手（玩家先攻还是怪物先攻）、回合是否双方各打一次——这些核心规则在 Detailed Design 节定义；战斗结算用 Autoload 还是节点、动画与逻辑如何解耦属实现细节，留待架构阶段 ADR。本 GDD 描述行为，不预设技术方案。

## Player Fantasy

**我算得准，所以我敢打；我在变强，所以越打越轻松。**

战斗的情感内核不是赌博，是**掌控**。玩家撞向一只哥布林之前，就已经知道结果会怎样——要打几回合、会掉多少血、能不能赢。没有暴击的惊喜，也没有闪避的惜败；没有「这把没运气」。所有紧张感都来自**战前的判断**（我现在的属性够不够、要不要先去捡那把剑），而不是战斗中的掷骰。这是经典魔塔三十年长青的那种安心：打不过的怪，是我还不够强，不是我运气不好——而「变得够强」永远是一条看得见、走得到的路。

第二层情感是**变强的实证**。同一只哥布林，铁剑时要砍 6 回合、掉一截血；换上精钢剑只要 4 回合。面对史莱姆，裸装要砍 5 下，捡到铁剑后两刀解决。回合数的压缩是玩家能**亲手数出来**的变强证据——伤害飘字一跳比一跳少落几下，血条掉得一次比一次浅。战斗是把「我变强了」从一个数字（ATK 6→14）翻译成一段**可感知的体验**（原来打得心惊，现在一趟碾过）的地方。

**必须交付的三个战斗时刻：**
- **「我就知道」**：战前预演显示「4 回合、掉 20 血、胜」，实际结算分毫不差——确定性兑现为「说到做到」的信任感。
- **「这次轻松多了」**：升级后重新面对同类怪，肉眼可见回合更少、掉血更浅，变强落到战斗体感上。
- **「打得越来越重」**（P1 高分辨率成长信号）：回合数压缩是粗粒度成长证据，受整数取整影响，在部分数值组合下回合数可能不变。每回合的**伤害数字增长**（铁剑 9 伤/回合 → 精钢剑 15 伤/回合，vs 哥布林 DEF=5）是不依赖取整的细粒度成长信号，与回合压缩形成双保险——#11 必须将 `round_resolved.dmg_to_monster` 的增长作为 P1 等权视觉维度渲染（大号飘字、高对比颜色），而非仅作为 HP 扣减通知。

*服务支柱*：P2「确定性」是本系统的存在理由（无随机、可预演）；P1「看得见的成长」是它的产出（回合压缩 = 成长的战斗层证据）。当二者张力出现时，遵循真北——战斗的确定性始终服务于「让成长可被看见、可被信任」，而非为难玩家。

> **边界声明（避免越界承诺）**：本系统**只负责让上述体验在数学上为真**——它产出确定的回合序列与伤害数列。「战前预演的可视化展示」由 #10 战斗预演实现；「伤害飘字、血条动画、回合压缩的视觉冲击」由 #11 数值反馈视觉实现。本系统是它们渲染的**确定性事实源**，不直接画任何东西（详见 Visual/Audio Requirements 节）。

## Detailed Design

### Core Rules

**C1 — 战斗触发（由 #6 调用）**
玩家在网格上踏向怪物所在格时，#6 网格移动系统判定为「撞怪」，调用本系统公开接口 `resolve_combat(monster_id: String) -> CombatResult`。本系统不自行检测碰撞；触发权属 #6。战斗期间玩家**无任何操作输入**（自动结算）——半策略性发生在战斗之前（选打哪只、先开哪扇门）。

**C2 — 回合结构（玩家先手，致命回合怪不反击）**
每一回合按固定顺序结算：
1. **玩家攻击**：`monster_HP_local −= F1-A` = `max(1, player_ATK − monster_DEF)`
2. **检查怪物**：若 `monster_HP_local ≤ 0` → 战斗立即结束，玩家胜，**本回合怪物不反击**（致命回合豁免）。
3. **怪物反击**：否则调用 `#4.apply_damage(F1-B)`，`F1-B = max(0, monster_ATK − player_DEF)`。
4. **检查玩家**：#4 内部钳制 HP 并在归零时发 `player_died()`；本系统监听到 `player_died()` 即终止回合循环，玩家败。
5. 否则进入下一回合。

> 怪物实际反击 `N−1` 次（N = 击杀回合数 F1-C）。**与 #3 D3 预算的关系**：#3 的 F4-A 用「怪物单回合伤害 × N」（完整 N 回合）作保守上界估算关卡消耗；本模型实际伤害 = 「× (N−1)」≤ #3 估算，故 #3 已验证的 D3 预算对本战斗模型恒为**安全上界**（floor 2 goblin：#3 估 F4-A=30，本系统实际受伤 25，#3 的保守估算 30 ≤ 预算 31，保守余量 1 点；实际余量 6 点）。本系统不修改 #3 的预算模型，仅声明此不等式关系（详见 Formulas F-C 节）。
>
> **LOSS 路径注**：「致命回合豁免」仅适用于 WIN 路径（怪物死亡的那一回合）。玩家死亡时（步骤 4），怪物反击已在步骤 3 发生，无豁免——玩家实际承受 K 回合的怪物伤害（`total_damage_actual = F1-B × K`，K 为实际死亡回合数；见 CombatResult 接口定义）。

**C3 — 胜负判定**
- **玩家胜**：`monster_HP_local ≤ 0`（在某回合步骤 1 后）。本系统发 `combat_won(monster_id)`。
- **玩家败**：在怪物反击后收到 #4 的 `player_died()`。本系统发 `combat_lost(monster_id)`，**不做死亡流程**（由 #13 经 #4 的 `player_died()` 驱动）。

**C4 — 伤害公式来源（引用 #3，不自定义）**
单回合伤害一律使用 #3 调参配置的权威公式 F1-A / F1-B；击杀回合数用 F1-C。本系统**不重新定义任何伤害数学**，只编排其逐回合应用。

**C5 — 怪物 HP 是战斗局部状态**
怪物 `HP/ATK/DEF` 从 #1 实体数据库只读读取；战斗期间怪物 HP 是本系统维护的**局部变量** `monster_HP_local`，不写回 #1（#1 是只读模板）。每场战斗以怪物满血开始（MVP 无「带伤逃跑/再战」——撞怪即打到分出胜负）。

**C6 — 确定性保证（P2 硬约束）**
结算逻辑零随机数（无 `randf/randi/RandomNumberGenerator/seed`）。给定 `(player_ATK, player_DEF, monster_HP/ATK/DEF)`，输出的回合数、每回合伤害、总伤害、胜负完全确定且可复算。

**C7 — 逻辑结算与动画解耦**
本系统的**逻辑结算同步完成**（纯函数，见 Formulas），产出一个「逐回合事件序列」。动画播放节奏（`BATTLE_ROUND_DURATION = 0.3s/回合`，来自 #3）是表现层职责：#11 数值反馈视觉消费该事件序列逐回合播放飘字/血条。逻辑不等待动画——预演（#10）调用同一纯函数即可在零时间内得到结果。**跳过/加速机制完全由 #11 实现**——#11 可按任意速度（含瞬时跳过）消费 F-SEQ 事件序列；本系统逻辑层不感知跳过状态，不增加任何新接口，#11 无需通知本系统即可压缩动画节奏。实现约束：`combat_system.gd` 内不得有 `await`（见 AC-C7-SYNC）；若 #11 用直接连接监听 `round_resolved`，#11 的回调内亦不得含 `await`，否则违反本条款（推荐 #11 用 `CONNECT_DEFERRED` 或独立动画队列）。

**C8 — apply_damage 正向契约（满足 #4 合同）**
传给 `#4.apply_damage(amount)` 的 `amount = max(0, monster_ATK − player_DEF)` 恒 `≥ 0`，满足 #4 接口合同（amount ≥ 0）。**本系统是 #4 的 AC-FP05-NEGATIVE-DAMAGE「路径 (3) 调用方正向契约」的落地点**——#5 集成测试须证明 #5 在任何属性组合下都不向 #4 传负值。

### States and Transitions

| 状态 | 进入条件 | 行为 |
|------|----------|------|
| **NoCombat** | 初始 / 上一场战斗结束 | 不结算；等待 #6 调用 `resolve_combat()` |
| **Resolving** | #6 调用 `resolve_combat(monster_id)` | 执行 C2 回合循环至分出胜负（逻辑同步） |
| **Victory** | `monster_HP_local ≤ 0` | 发 `combat_won(monster_id)` → 回到 NoCombat |
| **Defeat** | 收到 #4 `player_died()` | 发 `combat_lost(monster_id)` → 停留（死亡流程交 #13） |

转换单向：NoCombat → Resolving → (Victory | Defeat)。Victory 后立即回 NoCombat 等待下次撞怪；Defeat 后本系统冻结，等待 #13 重置（复活/重开）。Resolving 期间拒绝新的 `resolve_combat()` 调用（防重入）。

### Interactions with Other Systems

| 系统 | 方向 | 内容 |
|------|------|------|
| #1 实体数据库 | ← 只读 | 战斗开始时按 monster_id 读 `HP`/`ATK`/`DEF`（slime 20/8/2、goblin 50/18/5） |
| #3 调参配置 | ← 只读 | F1-A/F1-B/F1-C 伤害与回合公式；`BATTLE_ROUND_DURATION=0.3s` |
| #4 玩家属性与成长 | ↔ 双向 | ← 读 `player_ATK`/`player_DEF`（只读 getter）；→ 调 `apply_damage(amount≥0)`；← 监听 `player_died()` |
| #6 网格移动与交互 | ← 调用 | 撞怪时调用 `resolve_combat(monster_id)`；战斗结束后 #6 据胜负决定怪物格清除/玩家停留 |
| #8 掉落奖励 | → 信号 | 监听 `combat_won(monster_id)` 触发掉落结算 |
| #10 战斗预演 | → 只读 | 调用本系统纯函数 `forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp) -> CombatForecast` 预测结果，**不修改任何 HP** |
| #11 数值反馈视觉 | → 信号 | 监听 `round_resolved(...)` 逐回合事件序列播放飘字/血条动画 |
| #13 游戏状态管理 | (间接) | 玩家死亡经 #4 `player_died()` 流向 #13；本系统只发 `combat_lost`，不做流程控制。**设计约束（#13 必须遵守）**：#13 监听 `player_died()` 须使用 `CONNECT_DEFERRED` 或确保回调内无 `await`——否则死亡处理会在本系统战斗回合循环内同步执行，产生「循环未返回时游戏状态已变更」的破损状态转换 |

**本系统发出的信号（契约，供下游连接）**：
```
signal combat_won(monster_id: String)
signal combat_lost(monster_id: String)
signal round_resolved(round_index: int, dmg_to_monster: int, monster_hp_remaining: int, dmg_to_player: int, player_hp_remaining: int)
```

> **缺失 GDD 注记**：#1/#3/#4 已有 GDD，接口已对齐其既定契约；#6/#8/#10/#11/#13 尚未设计，上述接口由本 GDD 单方面定义，设计这些系统时须保持双向一致。

## Formulas

> **范围边界**：本节只定义战斗**编排**公式（总受伤、预演、逐回合序列）。单回合伤害（F1-A/B）、击杀回合数（F1-C）、单回合时长（F1-D）的权威来源是 #3 调参配置，本节直接引用，不重新定义。所有公式整数运算。

### F-C — 玩家战斗总受伤（玩家先手 N−1 模型）

```
total_damage_to_player = F1-B × (N_rounds − 1)
  F1-B     = max(0, monster_ATK − player_DEF)                    [引用 #3]
  N_rounds = ceil(monster_HP / max(1, player_ATK − monster_DEF)) [引用 #3 F1-C]
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `monster_ATK` | int | 0–18（MVP goblin） | 怪物攻击力（#1） |
| `player_DEF` | int | 3–13（MVP） | 玩家防御力（#4） |
| `monster_HP` | int | ≥1（slime=20，goblin=50） | 怪物满 HP（#1，战斗局部副本） |
| `player_ATK` | int | 6–20（MVP） | 玩家攻击力（#4） |
| `monster_DEF` | int | 0–5（MVP） | 怪物防御力（#1） |
| `N_rounds` | int | 1–10（D1 保证） | 击杀回合数（F1-C） |
| `total_damage_to_player` | int | **≥0**（D3 保证有上界） | 玩家本场总受伤 |

**输出范围**：下限 0（两种合法情况：F1-B=0 全格挡，或 N_rounds=1 一击必杀）；上限由 #3 D3 约束。**与 #3 D3 的关系**：#3 F4-A 用 `F1-B × N`（完整 N 回合）作保守上界估算关卡消耗，本式 `× (N−1)` ≤ 之，故 #3 已验证的 D3 预算对本战斗模型恒为安全上界。
**算例**：goblin 铁剑+铁盾（ATK=14/DEF=13）：N=ceil(50/9)=6，F1-B=max(0,18-13)=5，total=5×5=**25**（< #3 保守估算 30）。

### F-FC — forecast_combat 预演（纯函数，#10 调用，零状态修改）

```
forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp) -> CombatForecast:
  net_dmg     = max(1, player_atk - monster_def)        // F1-A
  monster_dmg = max(0, monster_atk - player_def)        // F1-B
  n_rounds    = ceil(monster_hp / net_dmg)              // F1-C
  total_dmg   = monster_dmg * (n_rounds - 1)            // F-C
  survives    = total_dmg < player_current_hp           // 严格小于：HP 归零即死，与 #4 ≤0 判定一致
  hp_after    = max(0, player_current_hp - total_dmg)
  return { n_rounds, total_damage_to_player=total_dmg, player_survives=survives, predicted_hp_after=hp_after }
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `player_current_hp` | int | 1–150（MVP） | **战斗开始时玩家实时 HP（从 #4 读取，非 MaxHP）** |
| `n_rounds` | int | 1–10 | 击杀回合数 |
| `total_damage_to_player` | int | ≥0 | =F-C |
| `player_survives` | bool | {true, false} | `total_dmg < player_current_hp`（严格小于） |
| `predicted_hp_after` | int | 0–150 | 战后剩余 HP，钳制 ≥0；survives=false 时为 0 |

**一致性**：survives=false ⇒ hp_after=0，此时实际逐回合 apply_damage 会在 HP 归零时触发 #4 `player_died()`，两路结果一致。**`player_current_hp` 必须是实时当前 HP**——#10 预演与战前 UI 调用时均须传实时值，否则高估存活能力。
**算例**：goblin 铁剑+铁盾，current_hp=90 → n=6，total=25，survives=(25<90)=true，hp_after=65。

### F-SEQ — 逐回合事件序列（供 #11 数值反馈视觉动画）

第 i 回合（i=1..length）产出 `(round_index, dmg_to_monster, monster_hp_remaining, dmg_to_player, player_hp_remaining)`。

- `dmg_to_monster` = `max(1, player_ATK − monster_DEF)`，`dmg_to_player` = `max(0, monster_ATK − player_DEF)`——二者全场为常量（无暴击/状态，实现时可预计算）。
- `player_hp_remaining` 每回合钳制 ≥0。

**WIN vs LOSS 路径序列长度**：

| 路径 | 序列长度 | 末回合 `dmg_to_player` | 末回合 `monster_hp_remaining` | 末回合 `player_hp_remaining` |
|------|----------|----------------------|-----------------------------|---------------------------|
| **WIN**（怪物 HP 归零） | = N_rounds | **0**（致命回合豁免，C2） | 0 | = F-FC `predicted_hp_after` |
| **LOSS**（玩家 HP 归零） | = K（实际死亡回合数，K ≤ N_rounds） | = F1-B（无豁免，怪物反击致死） | > 0（怪物仍存活） | 0（钳制） |

> **LOSS 路径序列不延伸至 N**：避免 #11 渲染「已死玩家被继续攻击 (N−K) 次」的错误动画。K 等于 `CombatResult.actual_rounds_played`（见接口定义）。

**WIN 路径一致性约束**：末事件 `player_hp_remaining` 须与 F-FC 的 `predicted_hp_after` **完全一致**（确定性双路自洽，纳入 AC-SEQ-CONSISTENCY）。

**`forecast_combat` 与 LOSS 路径**：`forecast_combat` 返回的 `total_damage_to_player` 是 WIN 路径理论值（F1-B × (N_rounds−1)）。若 `player_survives=false`，该值为玩家「如果打完 N 轮会受的伤」，实际在第 K 回合（K ≤ N_rounds）死亡时受伤 = F1-B × K ≤ forecast 值。预演不显示玩家死亡前的精确受伤量——预演的作用是警告「你会死」，非精确量化 LOSS 伤害。

**内部实现约束**：`forecast_combat` 内部应复用 `generate_round_sequence` 取末态值，防止两条独立实现路径数值漂移。

**算例**（goblin 铁剑+铁盾，current_hp=90，dmg→m=9，dmg→p=5，N=6）：

| round | dmg→monster | monster_hp | dmg→player | player_hp |
|---|---|---|---|---|
| 1–5 | 9 | 41→32→23→14→5 | 5 | 85→80→75→70→65 |
| 6 | 9 | 0 | **0** | **65** |

total=5×5=25；第 6 回合 dmg_to_player=0（致命回合豁免）；末回合 player_hp=65 与 F-FC predicted_hp_after 一致。

### F-D — 单场战斗总时长（引用 #3 F1-D）

```
battle_duration_seconds = N_rounds × BATTLE_ROUND_DURATION   // BATTLE_ROUND_DURATION=0.3s，来自 #3
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `N_rounds` | int | 1–10（D1 保证） | 击杀回合数（F1-C） |
| `BATTLE_ROUND_DURATION` | float | 固定 **0.3s**（#3 常量） | 单回合动画+结算时长 |
| `battle_duration_seconds` | float | **0.3s–3.0s** | 单场战斗表现层总时长 |

**输出范围**：0.3s（一击必杀）到 3.0s（N_max=10）。供 #11 计算动画总播放时长；逻辑结算同步完成（C7），不等待此时长。
**算例**：goblin 6 回合 × 0.3s = **1.8s**。

> **N_rounds=1 退化**：total = F1-B × 0 = 0（玩家先手一击秒杀，怪零反击）。MVP 属性档无法触发（需 player_ATK − monster_DEF ≥ monster_HP），VS 阶段引入更高 ATK 时须专项测试此退化路径。

## Edge Cases

- **如果玩家裸装撞 goblin（N_rounds > N_max）**：战斗**正常结算**，F-FC 正确返回 `player_survives=false`，玩家死亡触发 #4 `player_died()`。本系统**不在战斗层报错或拦截**——此情形属关卡布局约束违反（玩家不该裸装到达 goblin），由 #2 楼层数据的 F-SC1d（shield/武器须在 goblin 可达路径之前）在数据层阻止。战斗系统只忠实结算。

- **如果玩家总受伤恰好等于当前 HP（total_damage == player_current_hp）**：`player_survives = false`（严格小于判定）。HP 归零即死，与 #4 `apply_damage` 的「HP ≤ 0 发 player_died」判定一致，不存在「0 HP 存活」状态。

- **如果同层连续战斗（多怪）**：每场 `resolve_combat()` 以玩家**当前实时 HP** 为输入，逐场独立结算；本系统**不建模跨场 HP 累积**——累积是 #4 维护实时 HP 的自然结果（每场读取即当前值）。层内总消耗的关卡设计验证由 #3 F4-A 离线工具负责，本系统不感知该层逻辑。

- **如果每回合怪物 0 伤（player_DEF ≥ monster_ATK，F1-B=0）**：玩家零消耗通关（如 slime ATK=8 + 木盾 DEF=8）。这是「装备有用」的正面信号（P1 强化点）。**风险**：若整层全为 0 伤怪，战斗退化为「无意义点击」——关卡须保证每层至少 1 只非 0 伤怪维持策略张力（此为关卡设计约束，#3 边界分析 B1 已记；本系统不约束最小消耗）。

- **如果 N_rounds=1（一击必杀）**：`total_damage = F1-B × 0 = 0`，玩家先手秒杀，怪零反击，玩家 HP 不变。MVP 属性档无法触发（需 player_ATK − monster_DEF ≥ monster_HP），VS 高 ATK 阶段须专项测试。

- **如果 monster_id 在 #1 实体数据库中不存在**：`resolve_combat()` 查询返回 null 时报「未知怪物」错误，不静默结算、不崩溃（与 #1/#3 的「查询不存在返回 null，调用方须处理」契约一致）。

- **如果战斗结算中（Resolving）再次收到 `resolve_combat()` 调用**：拒绝（防重入，见 States 节）。一场战斗须打到分出胜负才接受下一次触发。

- **如果 `resolve_combat()` 在玩家已死（current_HP=0）时被调用**：不应发生（#6 不会让死亡玩家撞怪）。防御性：本系统开战前不主动判定，但首回合怪反击调 `#4.apply_damage` 时 #4 的 Dead 守卫（`if current_HP==0: return`）会兜底，不会产生二次 `player_died()`。建议 #6 在玩家 Dead 状态下不调用本接口。

- **如果玩家在非致命回合被打死（中途死亡）**：某回合怪反击后 #4 发 `player_died()`，本系统监听到立即终止回合循环（不再进入下一回合的玩家攻击），发 `combat_lost(monster_id)`。

## Dependencies

### 上游依赖（本系统依赖）

| 系统 | 类型 | 依赖内容 |
|------|------|----------|
| #1 游戏实体数据库 | 硬依赖（战斗触发时） | 按 monster_id 读 `HP`/`ATK`/`DEF`（slime 20/8/2、goblin 50/18/5）；查询不存在返回 null，本系统须处理 |
| #3 游戏调参配置 | 硬依赖（公式来源） | F1-A/F1-B/F1-C 伤害与回合公式；`BATTLE_ROUND_DURATION=0.3s`；本系统引用不重定义 |
| #4 玩家属性与成长 | 硬依赖（双向） | 读 `player_ATK`/`player_DEF`（只读 getter）；调 `apply_damage(amount≥0)`；监听 `player_died()` |

### 下游依赖（依赖本系统）

| 系统 | 类型 | 期望接口 |
|------|------|----------|
| #6 网格移动与交互 | 硬依赖（战斗触发方） | 撞怪时调 `resolve_combat(monster_id) -> CombatResult`；据胜负决定怪物格清除/玩家停留 |
| #8 掉落奖励 | 软依赖（奖励层） | 监听 `combat_won(monster_id)` 触发掉落结算 |
| #10 战斗预演 | 硬依赖（预演） | 调纯函数 `forecast_combat(...) -> CombatForecast`，只读，不修改任何 HP |
| #11 数值反馈视觉 | 软依赖（表现层） | 监听 `round_resolved(...)` 逐回合事件序列播放飘字/血条 |
| #13 游戏状态管理 | 间接 | 玩家死亡经 #4 `player_died()` 流向 #13；本系统只发 `combat_lost`，不做死亡流程 |

### 接口约定

- `resolve_combat(monster_id: String) -> CombatResult`：执行实际战斗（修改 #4 HP），返回：
  - `result: WON/LOST`
  - `monster_id: String`
  - `n_rounds: int`——理论击杀回合数（F1-C，无论胜负均填写）
  - `actual_rounds_played: int`——实际结算回合数（WIN 时 = n_rounds；LOSS 时 = 玩家死亡回合 K）
  - `total_damage_to_player: int`——WIN 时 = F1-B × (n_rounds−1)（F-C 公式）；LOSS 时 = F1-B × actual_rounds_played（实际受伤值）

- `forecast_combat(monster_hp: int, monster_atk: int, monster_def: int, player_atk: int, player_def: int, player_current_hp: int) -> CombatForecast`：纯函数预演，零状态修改（供 #10）。返回 WIN 路径理论值；若 `player_survives=false`，`total_damage_to_player` 为理论值，实际 LOSS 受伤 ≤ 该值。

- `generate_round_sequence(monster_hp: int, monster_atk: int, monster_def: int, player_atk: int, player_def: int, player_current_hp: int) -> Array[RoundEvent]`：纯函数，返回逐回合事件序列（WIN 路径长度 = n_rounds；LOSS 路径长度 = actual_rounds_played K）。`forecast_combat` 内部必须复用本函数取末态值，防止双路漂移。

- 信号：`combat_won(monster_id: String)`、`combat_lost(monster_id: String)`、`round_resolved(round_index: int, dmg_to_monster: int, monster_hp_remaining: int, dmg_to_player: int, player_hp_remaining: int)`

- **数据类型实现约定**（架构 ADR 须在实现开始前完成）：`CombatResult`/`CombatForecast`/`RoundEvent` 应以 GDScript `class_name` + `RefCounted` 子类实现（强类型，可被外部文件引用，无运行时键名错误）；禁止使用 `Dictionary`（违反强类型要求）。每次调用返回新实例，不复用共享引用，避免调用方缓存后被静默修改。

### 双向一致性

- **#3 已声明** 下游 #5 依赖其 F1-A/B 公式（game-tuning-config.md Dependencies 表 + 「#5 须引用 F1-A/F1-B 而非自行定义」），本 GDD 已遵守 ✅
- **#4 已声明** 与 #5 双向（`apply_damage` ← 调用；`ATK/DEF` → 只读；`player_died` 监听），本 GDD 已对齐 ✅
- **#1 已声明** 怪物数据被消费；本 GDD 引用值与注册表一致 ✅
- **缺失 GDD 注记**：#6/#8/#10/#11/#13 尚未设计，上述接口由本 GDD 单方面定义，设计这些系统时须在其 Dependencies 节反向声明对 #5 的依赖

## Tuning Knobs

本系统**不拥有独立调参旋钮**——所有影响战斗的数值参数均在 #3 调参配置中定义，本系统消费：

| 调参旋钮 | 权威来源 | 影响本系统的方式 | 安全范围（见 #3） |
|----------|----------|-----------------|------|
| 伤害公式 F1-A/F1-B 系数 | #3（规则 T2） | 决定每回合双方净伤 | `max(1,…)`/`max(0,…)` 非对称，结构性，改动须 ADR |
| `BATTLE_ROUND_DURATION` | #3 | 决定 F-D 动画总时长（0.3s/回合） | 0.15s–0.8s；<0.15s 闪烁难感知，>0.5s 节奏拖沓 |
| `N_max` | #3 | D1 保证 N_rounds ≤ 10，间接限定最长战斗时长 | 5–20 |
| 怪物 `HP/ATK/DEF` | #1 实体数据库 | 决定 N_rounds 与 total_damage | 受 #3 的 D1/D3 校验约束 |

**结构性设计决策（非运行时旋钮，变更须经架构 ADR）**：
- **回合模型 = 玩家先手 + 致命回合豁免**：这是本系统的核心结构决策，决定了 total_damage = `F1-B × (N−1)` 而非 `× N`，并使 #3 的 D3 预算成为安全上界。改为「同时结算」或「怪先手」会改变这一不等式关系，**须重跑 #3 全量 D1/D3 验证并出 ADR**，不可作为 JSON 调参。
- **逻辑/动画解耦**：逻辑同步结算、动画消费事件序列——属架构约束（影响 #10 预演与 #11 渲染），非数值旋钮。

**若需调整战斗手感**：改 #3 的 `BATTLE_ROUND_DURATION`（节奏）或 #1 的怪物数值（难度），而非修改本系统代码。本系统只编排，不持有可调数值。

> **运行时护栏**：`N_max`（#3 D1 保证 ≤ 10）同时作为本系统结算循环的硬性上限。若循环超过 `N_max` 回合，强制终止并记录警告日志（防止 WASM 环境主线程长时间阻塞）。此护栏不影响正常 MVP 战斗，仅防御异常参数组合（如 F-SC1d 未落实导致裸装撞 goblin）。

## Visual/Audio Requirements

本系统不直接渲染任何内容，但其信号是战斗视觉/音频反馈的权威触发源。#11 数值反馈视觉须对以下事件做出响应：

| 信号/事件 | 触发 | 须产生的视听响应（由 #11 实现） |
|------|------|----------------|
| `round_resolved` `dmg_to_monster>0` | 玩家攻击命中 | 怪物受击闪 + 伤害飘字（高饱和白/黄，art-bible 高对比原则）+ 攻击音 |
| `round_resolved` `dmg_to_player>0` | 怪物反击 | 玩家受击反馈 + 红色飘字「-N」+ 血条下降 + 受击音 |
| `round_resolved` `dmg_to_player==0`（致命回合或全格挡） | 怪被秒 / 盾完全格挡 | **不触发受伤动画**；全格挡可选「格挡」提示 + 格挡音（区别于受击） |
| `combat_won` | 怪物 HP 归零 | 怪物消亡动画 + 击杀音；掉落表现由 #8 驱动 |
| `combat_lost` | 玩家 HP 归零 | 死亡表现由 #13/#4 `player_died()` 驱动，本系统不单独处理 |

- **回合节奏**：#11 按 `BATTLE_ROUND_DURATION=0.3s/回合`（#3）逐回合播放 F-SEQ 事件序列；逻辑已同步算完，动画只是回放。#11 须支持跳过/加速模式（瞬时消费 F-SEQ），见 C7。
- **变强的双轨视觉证据（P1 双保险）**：
  - **粗粒度（回合压缩）**：同怪从 6 回合→4 回合，让 #11 渲染「这次更快打完」。
  - **细粒度（伤害数字增长）**：同怪每回合 dmg_to_monster 从 9→15（铁剑 vs 哥布林 → 精钢剑 vs 哥布林；F1-A=max(1,ATK-5)），#11 须渲染更大/更亮的伤害飘字——这是不依赖取整的成长信号，当回合数无变化时提供玩家感知变强的第二条路径。「字变大」须在视觉上明显区分，而非细微差异。
- **音频**：芯片音（art-bible Minimal 音频方向）——攻击/受击/格挡/击杀四类基础音效，具体规格由 sound-designer 在 `/asset-spec` 阶段定。

> 📌 **Asset Spec**：Visual/Audio 需求已定义。Art Bible 批准后运行 `/asset-spec system:combat-system` 生成受击闪、伤害飘字、怪物消亡、四类音效的资产规格。

## UI Requirements

本系统不拥有玩家界面，但其纯函数 `forecast_combat()` 是**战前伤害预演 UI** 的数据源：

| UI 元素 | 数据来源 | 渲染方 |
|------|------|------|
| 战前预演面板（预计回合数/掉血/胜负） | `forecast_combat() -> CombatForecast` | #10 战斗预演 + HUD |
| 战斗中血条（玩家/怪物） | `round_resolved` 的 hp_remaining | #11 / HUD |

- 本系统只保证 `forecast_combat` 返回数据正确且为纯函数（可被预演 UI 任意次调用无副作用）；预演面板的布局、触控交互由 #10 GDD 定义。
- HUD 不得轮询战斗内部状态，须经信号（`round_resolved`）驱动。

> 📌 **UX Flag — Combat System**：本系统的战前预演有 UI 需求（art-bible 已记「两步确认触控战斗预演」）。Pre-Production 阶段运行 `/ux-design` 为预演面板创建 UX Spec；故事文件涉及预演 UI 时应引用 `design/ux/combat-preview.md`，而非直接引用本 GDD。

## Acceptance Criteria

> **断言契约**：战斗逻辑封装为纯函数 `forecast_combat(...)` / `generate_round_sequence(...)`（headless 可测，不依赖场景树）与有状态接口 `resolve_combat(monster_id)`（修改 #4 HP，须 Integration 测试）。
>
> **测试框架**：**GDUnit4**（与 #3 game-tuning-config、#4 player-stats-growth 一致）。运行命令 `godot --headless --script tests/gdunit4_runner.gd`。⚠️ **框架 ADR 待 technical-director 闭环**——technical-preferences.md L44 当前仍写 GUT，全部信号断言 AC 依赖 GDUnit4 API（同 #3/#4 的外部 BLOCKER，**非本 GDD 新增**）。此项**不阻断 AC 文本落稿，阻断 qa-tester 开始运行测试**。
>
> **前置注入约定**：(1) #4 玩家属性经其公开 API 注入——`pickup_item(...)` 设 ATK/DEF、`apply_damage(...)` 设当前 HP，均在 `watch_signals` 连接**之前**完成；(2) 怪物经 mock #1 EntityDB 返回自定义 MonsterEntry（覆盖 MVP 真实怪无法触发的退化路径，如 HP=1）；(3) `resolve_combat` / `forecast_combat` 是 #5 公开 API，测试直接调用，无需经 #6 间接触发。
>
> **item_id → 属性快查**（完整映射见 #4 GDD）：`pickup_item("sword_iron")` → ATK=14；`pickup_item("shield_wood")` → DEF=8；`pickup_item("shield_iron")` → DEF=13；裸装基础值 ATK=6 / DEF=3。**怪物 mock 签名**：`mock_entity_db.add_monster(id: String, hp: int, atk: int, def: int)`，参数顺序 hp/atk/def，所有参数必须写全（禁止省略）。

### 核心规则覆盖（C1–C8）

- **AC-C1-TRIGGER（Integration）** — GIVEN 玩家 ATK=14/DEF=8/HP=100，mock #1 返回 slime(20/8/2)，WHEN 调用 `resolve_combat("slime")`，THEN 返回 `CombatResult.result == WON`；`monster_id == "slime"`；`n_rounds == 2`。

- **AC-C2-PLAYER-FIRST（Integration）** — GIVEN 玩家 ATK=14/DEF=13/HP=90，mock goblin(50/18/5)，`watch_signals` 已连接，WHEN `resolve_combat("goblin")`，THEN 共发出 6 次 `round_resolved`；**第 6 次（末回合）`dmg_to_player == 0`**（致命回合豁免）；`monster_hp_remaining` 末次为 0。

- **AC-C2-RETALIATE（Integration）** — GIVEN 玩家 `pickup_item("sword_iron")` ATK=14 / DEF=8 / HP=100，`mock_entity_db.add_monster("goblin", hp=50, atk=18, def=5)`，`watch_signals` 已连接，WHEN `resolve_combat("goblin")` 返回后（注：同步函数无中间状态，通过信号历史读取），THEN 第 1 次 `round_resolved` 信号的 `dmg_to_player == max(0,18-8) == 10`；#4.current_HP < 100（已因 `apply_damage` 下降）。

- **AC-C3-WIN（Integration）** — GIVEN 玩家 ATK=14/DEF=8/HP=100，`mock_entity_db.add_monster("slime", hp=20, atk=8, def=2)`，`watch_signals` 已连接，WHEN `resolve_combat("slime")`，THEN `assert_signal_emit_count(combat, "combat_won", 1)` 通过；参数 `["slime"]`；不发 `combat_lost`。（验证：N=ceil(20/max(1,14-2))=ceil(1.67)=2，玩家胜。）

- **AC-C3-LOSS（Integration）** — GIVEN 玩家 ATK=6/DEF=3/HP=10，`mock_entity_db.add_monster("goblin", hp=50, atk=18, def=5)`，`watch_signals` 已连接，WHEN `resolve_combat("goblin")`，THEN ① `player_died()` 信号先于 `combat_lost` 发出（顺序约束，二者同帧同步触发）；② `assert_signal_emit_count(combat, "combat_lost", 1)` 通过，参数 `["goblin"]`；③ 不发 `combat_won`。（F1-B=max(0,18-3)=15 > HP=10，第 1 回合怪物反击即致死。）

- **AC-C5-MONSTER-LOCAL（Integration）** — GIVEN 玩家 ATK=14/DEF=13/HP=90，`mock_entity_db.add_monster("goblin", hp=50, atk=18, def=5)`，WHEN 连续两次 `resolve_combat("goblin")`（两场均 WON），THEN 第二场第 1 次 `round_resolved` 的 `monster_hp_remaining == 50 - max(1,14-5) == 41`（怪物每场从满血 50 开始）；补充：`mock_entity_db.get_monster("goblin").hp == 50`（#1 未被写回）。

- **AC-C6-DETERMINISM（Logic，行为级）** — GIVEN 相同入参 `(50,18,5,14,13,90)`，WHEN 连续两次调用 `forecast_combat`，THEN 两次返回的 `n_rounds`/`total_damage_to_player`/`player_survives`/`predicted_hp_after` 完全相同（行为级确定性，独立于 AC-SCOPE-NORNG 的源码级 grep）。

- **AC-C8-NO-NEGATIVE-DAMAGE（Integration，参数化 @DataSet）** — GIVEN MVP 全玩家档（ATK∈{6,14,20}，通过 pickup_item 注入；DEF∈{3,8,13}）× 全怪（`mock_entity_db.add_monster("slime", 20, 8, 2)` 和 `mock_entity_db.add_monster("goblin", 50, 18, 5)`），通过 `round_resolved` 信号观测每次 `dmg_to_player`，WHEN 对每组合执行 `resolve_combat`，THEN 每次记录到的 `dmg_to_player` 恒 ≥ 0。（注：原版本测试数学恒真命题 `max(0,x)≥0` 对系统代码无断言价值；本版本通过实际执行验证调用方契约真正落地。）

### 公式覆盖（F-C / F-FC / F-SEQ / F-D）

- **AC-FC-VALUES（Logic）** — GIVEN 无，WHEN `forecast_combat(50, 18, 5, 14, 13, 90)`（6 参均 int），THEN 返回 `n_rounds == 6`；`total_damage_to_player == 25`；`player_survives == true`；`predicted_hp_after == 65`。

- **AC-FC-PURE（Logic）** — GIVEN #4 玩家 HP=90，WHEN 连续两次 `forecast_combat(...)`，THEN #4 的 `current_HP` 仍为 90（纯函数，零状态修改）。

- **AC-FC-SURVIVES-BOUNDARY（Logic）** — GIVEN `forecast_combat(50, 13, 5, 14, 3, 50)`（monster_hp=50/atk=13/def=5，player_atk=14/def=3/current_hp=50；验算：N=ceil(50/max(1,14-5))=ceil(5.6)=6，F1-B=max(0,13-3)=10，total=10×5=50，等于 current_hp），WHEN 调用，THEN `player_survives == false`（严格小于判定；total=50 不小于 current_hp=50）；`predicted_hp_after == 0`。

- **AC-SEQ-LETHAL-ZERO（Logic）** — GIVEN goblin(50/18/5)、玩家 ATK=14/DEF=13/HP=90，WHEN `generate_round_sequence(...)`，THEN 数组长度 == 6；末事件 `dmg_to_player == 0` 且 `monster_hp_remaining == 0`。

- **AC-SEQ-CONSISTENCY（Integration）** — GIVEN 同上入参，WHEN 分别执行 `generate_round_sequence`、`forecast_combat`、`resolve_combat`，THEN 三者末态玩家 HP 完全一致：F-SEQ 末事件 `player_hp_remaining == forecast.predicted_hp_after == resolve 后 #4.current_HP == 65`。

- **AC-FD-DURATION（Logic）** — GIVEN N_rounds=6，WHEN 计算 `battle_duration_seconds = 6 × 0.3`，THEN 结果 == 1.8（引用 #3 F1-D；BATTLE_ROUND_DURATION=0.3）。

### 边界条件覆盖

- **AC-EC-FULL-BLOCK（Integration）** — GIVEN 玩家 DEF=8、mock slime(ATK=8)，WHEN `resolve_combat("slime")`，THEN 每回合 `dmg_to_player == max(0,8-8) == 0`；`total_damage_to_player == 0`；#4.current_HP 全程不变；`combat_won` 发出。

- **AC-EC-ONE-ROUND（Logic，mock 低 HP 怪）** — GIVEN mock 怪 HP=1/ATK=18/DEF=0、玩家 ATK=6，WHEN `forecast_combat(1,18,0,6,3,100)`，THEN `n_rounds == 1`；`total_damage_to_player == max(0,18-3) × (1-1) == 0`（一击必杀，怪零反击）。**注**：MVP 真实怪无法触发 N=1（需 player_ATK − monster_DEF ≥ monster_HP），故用 mock 低 HP 怪覆盖此退化路径；VS 阶段引入更高 ATK 后补真实怪测试。

- **AC-EC-MID-COMBAT-DEATH（Integration）** — GIVEN 玩家 ATK=6/DEF=3/HP=10，`mock_entity_db.add_monster("goblin", hp=50, atk=18, def=5)`，`watch_signals` 已连接，WHEN `resolve_combat("goblin")`，THEN ① `player_died()` 先于 `combat_lost` 发出；② `assert_signal_emit_count(combat, "round_resolved") == 1`（F1-B=max(0,18-3)=15 > HP=10，第 1 回合即死）；③ `combat_lost("goblin")` 发出恰一次；④ `combat_won` 不发出；⑤ 回合循环不继续（无更多 `round_resolved`）。（LOSS 路径 F-SEQ 长度 = K=1。）

- **AC-EC-UNKNOWN-MONSTER（Logic）** — GIVEN mock #1 对某 monster_id 返回 null，WHEN `resolve_combat("unknown_id")`，THEN 报「未知怪物」错误（返回错误态或抛可捕获异常），不静默结算、不崩溃。

- **AC-EC-REENTRY（Integration）** — GIVEN 一场 `resolve_combat` 正在 Resolving，WHEN 在其结算未完成时再次调用 `resolve_combat`，THEN 第二次调用被拒（返回拒绝态或忽略），不并发结算。（注：MVP 同步结算下重入窗口极小，本 AC 主要防御异步/await 误改。）

- **AC-LOSS-SEQ-LENGTH（Integration）** — GIVEN 玩家 ATK=6/DEF=3/HP=10，`mock_entity_db.add_monster("goblin", hp=50, atk=18, def=5)`，WHEN `generate_round_sequence(50, 18, 5, 6, 3, 10)`（或通过 `resolve_combat` 收集 `round_resolved` 信号），THEN 序列长度 == 1（实际死亡回合 K=1）；末事件 `dmg_to_player == 15`（非 0，LOSS 路径无致命回合豁免）；`player_hp_remaining == 0`（钳制）；`monster_hp_remaining > 0`（怪物仍存活）。（与 AC-SEQ-LETHAL-ZERO 的 WIN 路径末回合 dmg_to_player=0 形成对比。）

### Anti-Pillar Scope-Gate（标记为 Complete 前须全部通过）

- **AC-C7-SYNC（grep/lint）** — GIVEN 本系统实现文件 `src/combat_system.gd`，WHEN CI lint 扫描，THEN `grep -n "await" src/combat_system.gd` 返回零匹配（逻辑结算同步完成，无 await；动画等待由 #11 实现，不得渗入本系统，见 C7）。

- **AC-SCOPE-NORNG（无随机数 — grep/lint）** — GIVEN 本系统实现文件（`src/combat_system.gd` 及其单元），WHEN CI lint 扫描，THEN `grep -nE "randf|randi|RandomNumberGenerator|seed\(" src/combat_system.gd` 返回零匹配。证明战斗结算无 RNG 入口（P2 确定性的源码层保证）。

- **AC-SCOPE-NOAD（广告隔离 — grep/lint）** — GIVEN 本系统实现文件，WHEN CI lint 扫描，THEN `grep -Ein "ad_manager|show_ad|request_ad|ad_sdk|激励广告|tt[._]show|tt[._]ad|ttVideoAd|RewardedVideoAd|createRewardedVideo|showInterstitial|interstitial|JavaScriptBridge\.eval|JavaScriptBridge\.get_interface|JavaScriptBridge\.create_callback|douyin_|rewarded_video" src/combat_system.gd` 返回零匹配（与 #4 AC-SCOPE-3 同一正则；广告仅由 #17 在玩家主动触发时调用，战斗系统不主动触发）。

- **AC-SCOPE-FORMULA-SOURCE（伤害公式来源 — grep + code review）** — GIVEN 本系统实现文件，WHEN code review + grep，THEN 战斗系统不重新定义伤害数学：每回合伤害经调用 #3 的 `TuningFormulas.damage_player/damage_monster`（或等效引用）获得；`combat_system.gd` 内若出现 `max(1,`/`max(0,` 字面量，须有注释标明「引用 #3 F1-A/F1-B 公式」。防止伤害公式在 #5 漂移出第二个权威源。

## Open Questions

- **🔗 [外部阻断] 测试框架 GUT vs GDUnit4** — 本 GDD 全部 AC 用 GDUnit4 API，但 technical-preferences.md L44 仍写 GUT。同 #3/#4 的跨项目外部 blocker，须 technical-director 出框架选型 ADR。**本 GDD 设计可 Complete，但 qa-tester 运行测试前须闭环。**（owner: technical-director）
- **数据类型定义（CombatResult / CombatForecast / RoundEvent）** — 由架构阶段 ADR 定义，与 #1/#3/#4 共用同一数据格式 ADR（#3 Open Q2 已记）。
- **TuningFormulas 函数归属** — #5 依赖 #3 的伤害公式落定为「可独立 headless 测试的静态函数」（#3 Open Q1 推荐方案 b）。若 #3 最终选择内联进战斗系统（方案 c），AC-SCOPE-FORMULA-SOURCE 与 F-C/F-FC 的「引用 #3」表述须重审。（owner: 架构 ADR）
- **战斗结算载体（Autoload vs 节点）** — resolve_combat 的宿主、与 #6 网格移动的调用边界属架构决策，不在本 GDD。（owner: 架构 ADR）
- **#6 撞怪触发契约细节** — 撞怪判定逻辑、战斗结束后怪物格的清除时机（WON 后由 #6 清格）、玩家停留位置，待 #6 网格移动 GDD 落定并与本 GDD 双向对齐。
- **#10 预演的展示粒度** — 本系统 `forecast_combat` 返回汇总（回合数/总伤/胜负）；若 #10 预演 UI 需展示逐回合明细，可改调 `generate_round_sequence`。具体由 #10 GDD 决定调用哪个接口。
- **N_rounds=1 真实怪测试（VS）** — MVP 属性档无法触发一击必杀（AC-EC-ONE-ROUND 用 mock 低 HP 怪覆盖）。VS 引入更高 ATK 或低 HP 怪后，补真实怪的 N=1 退化测试。
