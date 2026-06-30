# 玩家属性与成长系统 (Player Stats & Growth)

> **Status**: Approved (第 9 轮复评，2026-06-25；实现前置:GUT→GDUnit4 框架 ADR 待 technical-director)
> **Author**: lumen + agents
> **Last Updated**: 2026-06-25
> **Implements Pillar**: P1「看得见的成长」(stat jumps are the core feel) + P2「确定性+容错」(HP math is predictable)

## Overview

玩家属性与成长系统（Player Stats & Growth）是《像素魔塔·无尽塔》中所有玩家面向属性的**运行时数据层**：它追踪 `current_HP`、`MaxHP`、`ATK`、`DEF` 四条核心属性，接收道具拾取事件，按道具的叠加规则（武器/盾 HIGHEST_WINS；MaxHP 宝石 ADDITIVE；药水立即结算）修改属性，并向表现层和 HUD 发出 `stat_changed` 信号。战斗系统和战斗预演系统从本系统读取 `player_ATK` 与 `player_DEF`；`current_HP` 归零由本系统触发死亡事件，交由游戏状态管理处理。

对玩家而言，本系统**就是**「成长」本身：拾取铁剑时 ATK 从 6 跳到 14，拾取铁盾后哥布林每回合伤害归零，拾取生命宝石时 HP 上限扩张并立即补满——每一步数字变化都是本系统直接驱动的。成长逻辑遵循「装备决定战力」原则（来自 #3 调参配置）：游戏中**不存在独立的经验值或等级系统**，探索即成长。

## Player Fantasy

**成长的每一步，都摸得着。**

玩家进入第一层时孤身弱小，最大 HP 100、ATK 6——史莱姆一刀就能割掉两成血。拾取铁剑的那一刻，ATK 数字从 6 跳到 14，屏幕上有个东西「啪」地变大了，下一场战斗立刻能证明这件事：原来要打 4 回合的怪，现在 2 回合打完。

核心情感承诺：**每件道具都要让玩家在拿到后立刻感到「我变强了一大截」。** 不是「变强了一点点」，不是「好像有点影响」——是那种肉眼清晰的跳跃感。

三个必须交付的「成长爽感」瞬间：
- **武器升级**：ATK 数字在 HUD 上弹跳，下一场战斗几乎是 one-more-hit 差距（`sword_iron`: ATK 6→14；`sword_steel`: ATK 14→20）。
- **盾牌格挡归零**：捡到 `shield_wood` 后，**floor 1 史莱姆**（ATK=8）的每回合伤害变为 **0**（DEF=8 时 max(0, 8-8)=0）——零伤通关那一刻的支配感是本系统 floor 1 的情感高峰。注：floor 2+ 的哥布林（ATK=18）对任何 MVP 盾牌仍造成正伤害；DEF 的价值从 floor 2 起转型为「显著减伤」（持 shield_iron 时 max(0, 18-13)=5，减伤约 67%【基准：相对裸装 DEF=3 时受伤 15，15→5；若已持 shield_wood 则边际减伤为 50%，10→5】），而非「格挡归零」——这同样是可被数字证明的成长，关卡视觉反馈须相应调整。
- **生命宝石扩容**：`crystal_life` 令 MaxHP 从 100 扩到 150，当前 HP 立即补满——玩家看到 HP 条先扩展、再充满，这是「变得更耐打了」的最直接视觉证据。

本系统服务的是 **Pillar 1「看得见的成长」**。成败标准不是「数据上正确」，而是「拿到道具那一刻，玩家会不会对着屏幕说一声哦」。

> **MVP 承诺边界（3 层）**：上述三个「成长爽感」瞬间恰好分布在 MVP 的 3 层内（武器→floor 1、盾牌→floor 1-2、生命宝石→floor 3）。本系统的叠加规则在数学上限定 MVP 永久成长事件总数 = 5 次，对应 MVP 楼层数上限 = 3 层（推导见 Edge Cases「成长事件总数与 MVP 层数的硬性绑定」）。「每件道具变强一大截」的承诺在 MVP 3 层内全程成立；floor 4+ 的成长延展须在 VS 阶段引入新成长来源后方可兑现，不在 MVP 承诺范围内。HP_RESTORE（药水）提供的是「没死掉」的生存安全感而非成长跳跃感，不属于上述爽感瞬间，但与之并行不冲突——关卡须保证武器/盾/宝石密度足以维持成长节奏，不以药水填充成长空缺。

## Detailed Design

### Core Rules

**规则 P0 — 信号声明（Signal Signatures）**

本系统发出以下 Godot 信号：

```
signal stat_changed(stat_name: String, old_value: int, new_value: int)
signal item_pickup_no_change(stat_name: String, item_id: String)
signal player_died()
```

**stat_changed 发射策略**：`stat_changed` **始终发射**，包括 `old_value == new_value` 的情形（零伤格挡、满血拾药）。接收方必须容忍 `old == new` 信号，不得 assert(old != new)。原因：零伤格挡需触发视觉反馈（「格挡」提示），不发信号则视觉层无法感知此事件。

> **例外 — MAXHP_BOOST effect_value==0 路径不发 stat_changed**：F-P04 守卫（`if item_effect_value == 0: emit item_pickup_no_change("MaxHP", item_id); return`）触发时，仅发 `item_pickup_no_change`，不进入正常结算路径，**不发 stat_changed**。原因：ADDITIVE 路径无 HIGHEST_WINS 天然过滤，effect_value==0 时属配置错误，heal_actual=0 违反「≥1」声明，守卫拦截后属性不变，故跳过 stat_changed 发射（见 Edge Cases「effect_value=0」节）。实现者**不应**在此守卫路径的 return 前补插 stat_changed 发射。

**stat_name 合法值（精确匹配，区分大小写）**：`"ATK"`、`"DEF"`、`"HP"`、`"MaxHP"`。不允许其他字符串；接收方可以 assert 枚举有效性。

---

**规则 P1 — 属性模型（四条核心属性）**

| 属性 | 类型 | 初始值 | 来源 |
|------|------|--------|------|
| `current_HP` | int | = `base_MaxHP` = 100 | 调参配置 |
| `MaxHP` | int | `base_MaxHP + maxhp_bonus`（唯一权威公式；`maxhp_bonus` = Σ MAXHP_BOOST，ADDITIVE） | 调参配置 |
| `ATK` | int | `base_ATK + atk_boost_effective (HIGHEST_WINS)` | 调参配置 |
| `DEF` | int | `base_DEF + def_boost_effective (HIGHEST_WINS)` | 调参配置 |

所有基准值（`base_ATK=6`，`base_DEF=3`，`base_MaxHP=100`）从 #3 调参配置读取，**不在代码中硬编码**。

`player_ATK` 与 `player_DEF` 对外以**只读 getter**暴露（推荐实现为计算属性：`var player_ATK: int: get: return base_ATK + atk_boost_effective`），下游系统不得直接写入这两个字段。

**只读性的语言层防护边界（实现强制）**：GDScript **无编译期 `private` 访问修饰符**，「不得写入」无法在编译期强制。落地须用三重机制：(1) 计算属性**只声明 `get`、不声明 `set`**——直接 GDScript 代码赋值在**编译期**（parse-time）报错；通过 `Object.set()` 反射路径赋值则**静默失败**（无任何保护）。因此本条保护仅对编译期可见的直接赋值有效，反射路径须依赖 (2)(3) 机制兜底；(2) 权威状态字段用下划线前缀私有约定（`_atk_boost_effective` / `_def_boost_effective`），外部仅经 getter 访问——此约定也是反射路径的主要防线；(3) emit 端对信号 int 参数显式转型（`stat_changed.emit("ATK", int(old), int(new))`），因 Godot 4 信号 emit **只检查参数数量不检查类型**，base 值若从 Resource 读出为 float 会在接收端被截断（如 0.9 截断为 0，可能触发虚假死亡判定）。**注：(3) 仅对 float→int 截断有效**；若 Resource 中该字段为 null 或非数值类型（如 String），`int()` 静默归零（`int(null)=0`、`int("abc")=0`），会使 base_ATK 变 0 而无报错——此类配置类型错误须由 D1 校验器在初始化阶段以 `assert(base_ATK is int)` 等方式捕获，不依赖 emit 端转型防护。此防护边界与「String vs enum StatType」一并建议沉淀为 ADR（见下游 #11/#12 设计前）。

**规则 P2 — 起始状态**

游戏开始（新局）时：`current_HP = MaxHP = 100`，`ATK = 6`，`DEF = 3`，`atk_boost_effective = 0`，`def_boost_effective = 0`，`maxhp_bonus = 0`。

**规则 P3 — 道具拾取即时结算**

**公开接口**：`pickup_item(item_id: String) -> void`。由 #6 网格移动系统在玩家踏上道具格时调用；测试可直接调用此公开 API 注入前置状态（见 AC 节「前置状态注入约定」），无需通过 #6 间接触发。本系统内部从 #1 实体数据库查询 item_id 对应的 `effect_type`、`effect_value`，道具格消失由 #6 负责，按 `effect_type` 处理：

- **`ATK_BOOST` (HIGHEST_WINS)**：
  - 若 `effect_value > atk_boost_effective`：更新 `atk_boost_effective = effect_value`，`ATK` 重算，发出 `stat_changed("ATK", old, new)`
  - 否则（已有更好的武器）：发出 `item_pickup_no_change("ATK", item_id)`（供反馈层显示「已拥有更好装备」）；ATK 不变

- **`DEF_BOOST` (HIGHEST_WINS)**：规则与上同，作用于 `def_boost_effective` 和 `DEF`

- **`HP_RESTORE` (ADDITIVE，即时消耗)**：
  `current_HP = min(MaxHP, current_HP + effect_value)` → 发出 `stat_changed("HP", old, new)`

- **`MAXHP_BOOST` (ADDITIVE)**：
  按 F-P04 结算（见 Formulas 节，`maxhp_bonus += effect_value; MaxHP = base_MaxHP + maxhp_bonus`）；`current_HP` 立即补满至新 `MaxHP`；先发 `stat_changed("MaxHP", old, new)`，再发 `stat_changed("HP", old, new)`

**规则 P4 — 无溢出（No-overheal）**

`current_HP` 任何时候 ≤ `MaxHP`。所有修改 `current_HP` 的路径必须执行 `min(MaxHP, …)` 钳制。

**规则 P5 — 战斗伤害应用**

战斗系统每回合调用 `apply_damage(amount: int)`：
`current_HP = max(0, current_HP - amount)` → 发出 `stat_changed("HP", old, new)` → 若 `current_HP == 0`：发出 `player_died()` 信号。

**规则 P6 — 死亡事件**

`current_HP` 归零时本系统发出 `player_died()` 信号。本系统**不做流程控制**，只发信号；游戏状态管理系统（#13）接收并处理后续流程（死亡界面、复活选项等）。

**规则 P7 — 无库存，无装备槽**

本系统只维护两个整数：`atk_boost_effective`（已拾取武器中最高 ATK_BOOST 值）和 `def_boost_effective`（同理）。游戏内**不存在装备/卸下操作**，不存在武器列表。HIGHEST_WINS 是单向不可降的。

**规则 P8 — 临时属性补偿接口（预留 VS）**

VS 阶段容错机制（#15）和碎片经济（#14）将通过 `apply_temp_bonus(stat: String, amount: int)` 注入**一次性临时属性**。临时值独立追踪，**不写入 `atk_boost_effective` / `def_boost_effective`**，不触发 HIGHEST_WINS 历史比较。MVP 此接口留空即可。

---

### States and Transitions

| 状态 | 条件 | 备注 |
|------|------|------|
| **Alive** | `current_HP > 0` | 正常运作；属性可随道具拾取/战斗变化 |
| **Dead** | `current_HP == 0` | 触发：发出 `player_died()`；Dead 状态下不再接受任何 `apply_damage()` 调用 |

无其他状态。Alive → Dead 单向触发（由 `apply_damage` 驱动），Dead 状态的恢复由游戏状态管理系统决定（如广告复活后重置 HP，通过调用 `restore_from_snapshot()` 或 `apply_revival_bonus()` 实现）。

---

### Interactions with Other Systems

| 系统 | 方向 | 内容 |
|------|------|------|
| #3 调参配置 | ← 读取（初始化一次）| `base_ATK`、`base_DEF`、`base_MaxHP` |
| #1 实体数据库 | ← 读取（拾取时查询）| `effect_type`、`effect_value`、`stack_rule`；`pickup_item()` 内按 item_id 查询 |
| #6 网格移动与交互系统 | ← 调用 | 玩家踏上道具格时调用 `pickup_item(item_id: String)`（本系统公开 API）；道具格消失由 #6 负责 |
| #5 战斗系统 | ↔ 双向 | ← 调用 `apply_damage()`；→ 提供 `ATK`、`DEF`（只读） |
| #10 战斗预演 | → 只读 | 提供 `ATK`、`DEF`（预演不修改 HP） |
| #2 楼层关卡数据系统 | → 约束传递（非信号/接口）| 本系统成长曲线有效性依赖 #2 保证「每层 ≥1 次永久成长事件，Floor 1 不豁免」；此约束为**待 #2 落实的待决依赖**（当前 #2 仅以「参考指引」挂在 Tuning Knobs 节，尚未成为校验规则）；见 Open Questions 🚧 阻断记录 |
| #11 数值反馈视觉 | → 信号 | 监听 `stat_changed(stat, old, new)`、`item_pickup_no_change(stat, id)`；**须同步连接（禁 CONNECT_DEFERRED，见 F-P04）** |
| #12 HUD | → 信号 | 监听 `stat_changed` 刷新显示；**须同步连接（禁 CONNECT_DEFERRED，见 F-P04）** |
| #13 游戏状态管理 | → 信号 | 监听 `player_died()` 触发死亡流程 |
| #14 碎片经济(VS) | ← 调用 | `apply_temp_bonus(stat, amount)`（VS，预留） |
| #15 容错安全(VS) | ← 调用 | `apply_floor_guaranteed_hp(amount)`（VS，预留） |
| #18 存档(Alpha) | ↔ 双向 | 序列化/反序列化完整属性快照 |

## Formulas

> **范围边界**：本节仅定义本系统拥有的运行时结算逻辑（道具拾取应用 + 伤害接收）。玩家 ATK/DEF 的聚合公式和战斗伤害值公式的权威来源是 #3 调参配置（T1、F1-A、F1-B），本节直接引用，不重新定义。

---

### F-P01 — ATK_BOOST 拾取应用（HIGHEST_WINS）

```
if current_HP == 0: return              // Dead 守卫（本系统责任）：HP 为 0 时不结算、不发信号。F-P01 不读改 current_HP，故无需快照行——写法与 F-P03/F-P04/F-P05 不同，但守卫语义等价
atk_boost_effective_new = max(atk_boost_effective_old, item_effect_value)
player_ATK              = base_ATK + atk_boost_effective_new
value_changed           = (atk_boost_effective_new > atk_boost_effective_old)
// stat_changed("ATK", old_ATK, player_ATK) 始终发出（见 P0 信号约定）
// value_changed = false 时在同一调用帧内额外发出 item_pickup_no_change("ATK", item_id)
```

> **命名说明**：`value_changed` 是内部布尔变量（「属性数值是否实际改变」），与信号名 `stat_changed` 不同。`stat_changed` 信号**始终发射**（P0 约定），`value_changed` 仅控制是否在同一调用帧内额外发出 `item_pickup_no_change`。

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `atk_boost_effective_old` | int | 0–14（MVP）；游戏开始时为 **0** | 拾取前 ATK boost 历史最高值 |
| `item_effect_value` | int | 1–14（MVP：sword_iron=8, sword_steel=14） | 被拾取武器的 `effect_value`，来自实体数据库 |
| `atk_boost_effective_new` | int | 0–14（MVP） | 拾取后 ATK boost 历史最高值（单调不递减） |
| `base_ATK` | int | 固定 **6** | 裸装攻击力，来自 #3 调参配置 |
| `player_ATK` | int | **6–20**（MVP） | 重算后的攻击力 |
| `value_changed` | bool | {true, false} | false 时发 `item_pickup_no_change("ATK", item_id: String)` |

**输出范围**：`atk_boost_effective_new` 单调不递减。`player_ATK` 范围 6–20（MVP）。

**示例（升级）**：持 sword_iron（old=8），拾取 sword_steel（value=14）→ new=14，ATK=20，发 stat_changed("ATK", 14, 20)。
**示例（无变化）**：持 sword_steel（old=14），拾取 sword_iron（value=8）→ new=14，ATK不变，发 stat_changed("ATK", 20, 20) + item_pickup_no_change("ATK", "sword_iron")。

---

### F-P02 — DEF_BOOST 拾取应用（HIGHEST_WINS）

```
if current_HP == 0: return              // Dead 守卫（本系统责任）：HP 为 0 时不结算、不发信号。F-P02 不读改 current_HP，故无需快照行——写法与 F-P03/F-P04/F-P05 不同，但守卫语义等价
def_boost_effective_new = max(def_boost_effective_old, item_effect_value)
player_DEF              = base_DEF + def_boost_effective_new
value_changed           = (def_boost_effective_new > def_boost_effective_old)
// stat_changed("DEF", old_DEF, player_DEF) 始终发出（见 P0 信号约定，与 F-P01 命名规则一致）
// value_changed = false 时在同一调用帧内额外发出 item_pickup_no_change("DEF", item_id)
```

> **命名说明（与 F-P01 共用通则）**：`value_changed` 是内部布尔变量（「属性数值是否实际改变」），**严禁命名为 `stat_changed`**——后者是本类声明的信号名，同名局部变量在 GDScript 中会遮蔽信号并导致 `value.emit()` 运行时错误。`stat_changed` 信号始终发射（P0 约定）；`value_changed` 仅控制是否在同一调用帧内额外发出 `item_pickup_no_change`（此处「额外发出」意指时序上同帧，非 Godot 连接模式语义）。

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `def_boost_effective_old` | int | 0–10（MVP） | 拾取前 DEF boost 历史最高值；游戏开始时为 0 |
| `item_effect_value` | int | 1–10（MVP：shield_wood=5, shield_iron=10） | 被拾取盾牌的 `effect_value` |
| `def_boost_effective_new` | int | 0–10（MVP） | 拾取后 DEF boost 历史最高值（单调不递减） |
| `base_DEF` | int | 固定 **3** | 裸装防御力，来自 #3 调参配置 |
| `player_DEF` | int | **3–13**（MVP） | 重算后的防御力 |
| `value_changed` | bool | {true, false} | false 时发 `item_pickup_no_change("DEF", item_id: String)` |

**输出范围**：`player_DEF` 范围 3–13（MVP）。

**示例**：裸盾（old=0），拾取 shield_wood（value=5）→ new=5，DEF=8，发 stat_changed("DEF", 3, 8)。

---

### F-P03 — HP_RESTORE 拾取应用（ADDITIVE，立即消耗，上限钳制）

```
current_HP_old = current_HP         // 快照：必须先于所有修改捕获
if current_HP_old == 0: return     // Dead 守卫（与 F-P05 对称，本系统责任）：不结算、不发信号
current_HP_new = min(MaxHP, current_HP_old + item_effect_value)
heal_actual    = current_HP_new - current_HP_old
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `current_HP_old` | int | 1–MaxHP | 拾取前当前 HP |
| `item_effect_value` | int | 1–∞（MVP：potion_small=40, potion_large=80） | 药水回血量 |
| `MaxHP` | int | 100–150（MVP） | 当前最大 HP |
| `current_HP_new` | int | **1–MaxHP** | 回血后 HP，钳制不超 MaxHP |
| `heal_actual` | int | **0–(MaxHP − current_HP_old)** | 实际恢复量；满血时为 0 |

**输出范围**：`current_HP_new` ∈ [1, MaxHP]。满血拾药时 `heal_actual=0`（合法，发 stat_changed("HP", x, x)）。

**示例（正常回血）**：HP=60/100，拾取 potion_small（+40）→ new=100，heal_actual=40，发 stat_changed("HP", 60, 100)。
**示例（溢出钳制）**：HP=90/100，拾取 potion_large（+80）→ new=100，heal_actual=10，发 stat_changed("HP", 90, 100)。

---

### F-P04 — MAXHP_BOOST 拾取应用（ADDITIVE，立即补满）

```
current_HP_old = current_HP                 // 快照：必须先于所有修改捕获
if current_HP_old == 0: return              // Dead 守卫（与 F-P05 对称，本系统责任）：不结算、不发信号
if item_effect_value == 0: emit item_pickup_no_change("MaxHP", item_id); return  // 配置错误守卫（与 F-P01/F-P02 对称）：ADDITIVE 无 HIGHEST_WINS 天然过滤，须显式排除；否则满血时 heal_actual=0，违反「≥1」声明
HP_before      = current_HP_old             // 必须在赋值前保存，用于 heal_actual 计算
MaxHP_old      = MaxHP                       // 快照：必须在 maxhp_bonus 修改前捕获；是 stat_changed("MaxHP", MaxHP_old, MaxHP_new) 的 old 权威来源（不得用 0 或其它推断值）
maxhp_bonus   += item_effect_value          // 权威状态：累加整数（ADDITIVE），独立于 HIGHEST_WINS
MaxHP_new      = base_MaxHP + maxhp_bonus    // MaxHP 为计算属性（`var MaxHP: int: get: return base_MaxHP + maxhp_bonus`），无需显式赋值；此局部变量 MaxHP_new 供后续 emit 和 heal_actual 引用（见 P1 唯一权威公式）
current_HP_new = MaxHP_new                  // 立即补满至新上限（不是 current_HP + effect_value）
heal_actual    = current_HP_new - HP_before  // UI 治疗量显示的权威来源
// 先发 stat_changed("MaxHP", MaxHP_old, MaxHP_new)（同步，禁 CONNECT_DEFERRED）
// 再发 stat_changed("HP", HP_before, current_HP_new)（同步，禁 CONNECT_DEFERRED）
```

**字段写入顺序（严格）**：`maxhp_bonus` → `MaxHP` → `current_HP`。原因：任何中间时刻都必须满足 `current_HP ≤ MaxHP`（P4 不变量）；若先写 `current_HP` 再写 `MaxHP`，存档（#18）或预演（#10）的同步读取可能捕获到 `current_HP > MaxHP` 的非法瞬态。（注：MaxHP 为计算属性，「写入 MaxHP」指 maxhp_bonus 更新后 MaxHP 可观测值自动变为新值的时刻，非字段赋值操作；`current_HP` 才是需要显式赋值的字段。）

**两步信号顺序（严格）**：先发 stat_changed("MaxHP", MaxHP_old, MaxHP_new)，再发 stat_changed("HP", HP_before, current_HP_new)。顺序强制原因：HUD 须先知道新的 MaxHP 才能正确渲染 HP 条（否则会出现 HP 超过 MaxHP 的视觉错误状态）。**接收方必须使用默认同步连接，不得使用 `CONNECT_DEFERRED`**——deferred 连接会把两个回调推迟到帧末执行，破坏「MaxHP 先于 HP 被处理」的保证。**发送方约束**：`pickup_item()` 结算函数内禁止使用 `call_deferred`、`set_deferred` 或 `await` 推迟信号发射；所有 emit 须在同步调用栈内完成（AC-SCOPE-2 以 `assert_signal_emitted_with_parameters` 在同步返回后即可通过来验证此约束；AC-FP04-ORDER 以 SignalOrderSpy 记录顺序来验证）。

**中间态约束（接收方必读）**：本系统按严格写入顺序 `maxhp_bonus → MaxHP → current_HP` 更新字段，并在 `MaxHP` 写入后、`current_HP` 写入前**同步**发出 `stat_changed("MaxHP", …)`。这意味着在该回调执行期间，`MaxHP` 已是新值（150）但 `current_HP` 仍是旧值（如 30）——此刻 P4 不变量成立（`current_HP ≤ MaxHP`），但 `current_HP` 尚未补满。**因此 `stat_changed("MaxHP")` 的回调内禁止读取 `current_HP`**（会读到补满前的旧值，导致 HP 条以脏数据渲染一次、再被 `stat_changed("HP")` 重刷，产生单帧闪烁）。正确做法：MaxHP 回调只更新 HP 条的总宽度/最大刻度，当前填充量一律等到 `stat_changed("HP")` 回调再更新。存档系统（#18）若在两次 emit 之间采样，会得到合法但语义不完整的快照（HP 未补满）——须将 F-P04 的结果作为原子事务序列化，不得在 F-P04 执行中途读取（见 Open Questions）。

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `MaxHP_old` | int | 100–∞（MVP：100） | 拾取前最大 HP |
| `item_effect_value` | int | 1–∞（MVP：crystal_life=50） | MAXHP_BOOST 效果值 |
| `MaxHP_new` | int | **100–150**（MVP 上限 150） | 扩容后最大 HP；**派生值** = `base_MaxHP + maxhp_bonus`（非 `MaxHP_old + delta`，二者在多颗宝石时会漂移，故统一以权威公式重算） |
| `HP_before` | int | 1–MaxHP_old | 赋值前保存的 current_HP_old；用于 heal_actual 计算，**必须在 MaxHP_new 赋值前捕获** |
| `current_HP_old` | int | 1–MaxHP_old | 拾取前当前 HP（无论多少） |
| `current_HP_new` | int | = MaxHP_new | 立即补满，固定等于 MaxHP_new |
| `heal_actual` | int | **1–(MaxHP_new − 1)** | 实际净回血量（UI 治疗飘字的权威来源）；满血拾取时为 `MaxHP_new − MaxHP_old`（即 effect_value，≥1）；因 item_effect_value ≥1，heal_actual 最小值恒 ≥1，不可为 0 |
| `maxhp_bonus` | int | 0–∞ | **MaxHP 的权威状态字段**（ADDITIVE 累加整数）；MaxHP 始终由其重算，存档只需序列化此字段；MVP 最大值 50；VS 引入第二颗前须重新验证 D3 |

**输出范围**：`current_HP_new` 精确等于 `MaxHP_new`（满血保证）。MVP 唯一合法值：100→150。

**示例（濒死）**：HP=30/100，拾取 crystal_life（+50）→ HP_before=30，MaxHP=150，current_HP=150，heal_actual=120；先发 stat_changed("MaxHP", 100, 150)，再发 stat_changed("HP", 30, 150)。
**示例（满血）**：HP=100/100，拾取 crystal_life（+50）→ HP_before=100，MaxHP=150，current_HP=150，heal_actual=50；先发 stat_changed("MaxHP", 100, 150)，再发 stat_changed("HP", 100, 150)。

---

### F-P05 — apply_damage（战斗伤害接收，下限归零）

```
current_HP_old = current_HP        // 快照：必须先于守卫与所有修改捕获（与 F-P03/F-P04 对称；缺此行将使下方 current_HP_old 为未初始化 null，Dead 守卫失效）
assert(damage_amount >= 0)         // 调试期诊断：负值违反接口契约（#5 战斗系统 F1-B 保证输出 ≥0）；Release 构建中 assert 被剥除，由下行钳制兜底
damage_amount  = max(0, damage_amount)  // 生产期硬保证：负伤害归零，防止 HP 上溢违反 P4 不变量（Release 下 assert 被剥除后的最后防线）
if current_HP_old == 0: return     // Dead 防御性守卫（不发信号）
current_HP_new = max(0, current_HP_old - damage_amount)
is_dead        = (current_HP_new == 0)
```

| 变量 | 类型 | 范围 | 描述 |
|------|------|------|------|
| `current_HP_old` | int | 1–MaxHP | 调用前当前 HP；Dead 状态下调用将被守卫直接返回 |
| `damage_amount` | int | **≥0（调试期 assert + 生产期 `max(0,...)` 钳制兜底）** | 本回合怪物对玩家伤害量（来自 #5 战斗系统，F1-B 输出：max(0, monster_ATK−player_DEF)）；负值经钳制归零，不产生治疗效果，不违反 P4 不变量 |
| `current_HP_new` | int | **0–MaxHP** | 受伤后 HP；下限钳制为 0 |
| `is_dead` | bool | {true, false} | true 时发 `player_died()` 信号 |

**输出范围**：`current_HP_new` ∈ [0, MaxHP]。`damage_amount=0` 合法（零伤格挡）。过量伤害归零不负数。

**示例（普通）**：HP=60，damage=15 → HP=45，is_dead=false，发 stat_changed("HP", 60, 45)。
**示例（致死）**：HP=10，damage=30 → HP=0，is_dead=true，发 stat_changed("HP", 10, 0)，随即发 player_died()。
**示例（零伤）**：HP=80，damage=0 → HP=80，is_dead=false，发 stat_changed("HP", 80, 80)。

---

> **stat_changed(old == new) 约定**：F-P03 满血拾药和 F-P05 零伤格挡均产生 old==new 的 stat_changed 信号。接收方（#11 反馈视觉、#12 HUD）**须容忍此信号不崩溃**，处理方式由各系统自定（建议静默跳过或轻量提示）。

> **VS 预留 F-P06**：`apply_temp_bonus(stat, amount)` 的临时属性结算公式由 #15 容错安全 GDD 定义，本系统仅提供接口。

## Edge Cases

- **如果 Dead 状态下玩家踏上道具格（如死亡动画播放中）**：忽略拾取事件，道具格不消失，不结算任何效果。Dead 状态下本系统拒绝所有道具拾取和伤害输入，直到游戏状态管理系统重置状态。

- **如果 apply_damage() 在 current_HP == 0 时被调用**：F-P05 守卫直接返回（`if current_HP_old == 0: return`），不发任何信号，不修改任何状态。调用方（#5 战斗系统）在 player_died 信号后应停止调用，但此守卫提供最后防线，防止双重死亡事件。

- **如果 stat_changed 信号携带 old == new（零伤格挡或满血回血）**：信号正常发出，接收方（#11 反馈视觉、#12 HUD）须容忍此信号不崩溃，不得 assert(old != new)。HUD 静默刷新；反馈视觉层可选显示「已满血」提示或静默跳过——具体行为由各自 GDD 定义。

- **如果 effect_value = 0（任意 BOOST 道具）**：
  - **ATK_BOOST/DEF_BOOST（F-P01/F-P02）**：HIGHEST_WINS 逻辑天然处理（`max(old, 0) = old`），value_changed = false，发 `stat_changed("ATK"/"DEF", old, old)`（P0 约定）+ `item_pickup_no_change("ATK"/"DEF", item_id)`，道具格消失，属性不变。
  - **MAXHP_BOOST（F-P04）**：F-P04 补显式守卫 `if item_effect_value == 0: emit item_pickup_no_change("MaxHP", item_id); return`——ADDITIVE 路径无 HIGHEST_WINS 天然过滤，若不守卫则 maxhp_bonus+=0，MaxHP 不变，满血时 heal_actual=0，违反「heal_actual 恒 ≥1」声明。守卫行为：发 `item_pickup_no_change("MaxHP", item_id)`，**不发** `stat_changed`，道具格消失，属性不变。
  - **HP_RESTORE（F-P03）**：effect_value=0 时 heal_actual=0 合法（与满血拾药同理），无需守卫。
  - 以上均属实体数据库配置错误，应由 D1 校验器在开发阶段捕获，不在运行时崩溃。

- **如果 effect_value < 0（负值，任意 effect_type）**：F-P01/F-P02 的 HIGHEST_WINS `max()` 操作天然防护（`max(old, neg) = old`，等效无操作）；F-P03/F-P04 的 ADDITIVE 路径**无运行时钳制**，负值会产生「药水扣血」（F-P03）或「宝石缩减 MaxHP」（F-P04）等反直觉结果，heal_actual 可为负值，违反「恒 ≥1」声明。此属实体数据库配置错误，**须由 D1 校验器在初始化阶段强制捕获**（`assert(effect_value >= 0)` 或等价校验）——与 effect_value==0 同属「上游契约信任路径」，不在运行时兜底。

- **item_pickup_no_change 信号签名**：`item_pickup_no_change(stat: String, item_id: String)`，其中 `item_id` 为道具在实体数据库中的 `name` 字段（如 `"sword_iron"`）。接收方通过 `item_id` 查询 `display_name` 用于提示文本。

- **MaxHP_BOOST 多次累积（VS 风险）**：`maxhp_bonus` 是累加整数（ADDITIVE），MVP 只有一颗 crystal_life（最大 50），无问题。VS 引入第二颗之前，关卡设计师**必须**重新验证 D3 约束（entities.yaml 已有注记）：MaxHP 扩大后每只怪的 HP_BUDGET_RATIO 绝对值增大，需确认新怪物 ATK 设计仍满足 D3。

- **MaxHP 扩容（F-P04）后立即收到大量伤害**：F-P04 将 current_HP 补满至新 MaxHP，后续 F-P05 正常处理。无特殊交互，正常结算。

- **apply_temp_bonus 与常规道具拾取在同帧触发（VS 预留）**：MVP 不存在此情况。VS 实现时，临时属性与永久属性须在独立字段中追踪；合并值公式（`ATK_effective = base_ATK + atk_boost_effective + temp_atk_delta`）由 #15 容错安全 GDD 定义，本系统仅提供接口。

- **HIGHEST_WINS 成长枯竭点（P7 的数学推论，须向下游传递）**：

  **机制性枯竭（HIGHEST_WINS 强制，4 次上限）**：同类武器/盾中，玩家已有装备 ATK（或 DEF）最高值后，再拾取同类更弱道具一律走 `item_pickup_no_change`，属性永不降低，成长驱动力从机制层终止。MVP：ATK 2 档（sword_iron→sword_steel）、DEF 2 档（shield_wood→shield_iron）——合计 4 次不可超越的 HIGHEST_WINS 成长事件。

  **分布性枯竭（ADDITIVE，由关卡放置决定）**：MaxHP 使用 ADDITIVE 机制，理论上每颗 crystal_life 均有效，无机制枯竭上限。但 MVP 仅放置 1 颗，因此 MVP 合计恰好 5 次永久成长事件（4 次 HIGHEST_WINS + 1 次 ADDITIVE）。VS 阶段若增加 crystal_life 放置数量，成长次数随之增加，须重验 D3 约束。

  **注**：HP_RESTORE（potion_small / potion_large）每次拾取均有效（立即消耗，无枯竭统计），**不计入**上述 5 次永久成长事件。

  超过 HIGHEST_WINS 档数后，同类道具一律走 `item_pickup_no_change`，本系统不再产生该类数值成长驱动力，Player Fantasy「每件道具变强一大截」在枯竭后自动失效。这是本系统叠加规则的涌现属性，关卡设计无法自行推导。

  **成长事件总数与 MVP 层数的硬性绑定（本系统设计取舍，非可委派项）**：本系统的叠加规则在数学上限定了 MVP 永久成长事件总数 = **恰好 5 次**（4 次 HIGHEST_WINS 上限 + 1 颗 crystal_life）。此上限与「每层 ≥1 次永久成长事件、Floor 1 不豁免」的分布约束联立，推出一个硬性结论：**MVP 楼层数上限 = 3 层**（5 次事件可满足 3 层「每层 ≥1」，并留有 2 次余量供同层叠放；4 层及以上则至少 1 层无任何合法永久成长道具可放——#2 无法凭空创造道具池中不存在的成长道具，约束变为不可满足）。

  **据此，MVP 范围正式锁定为 3 层单塔**（原「3-5 层」表述收紧为 3 层）。floor 4-5 及以上的成长延展属 VS 阶段范畴，须先引入新的成长来源（多颗 crystal_life 并重验 D3、或新一级武器/盾 tier 如 sword_great）后方可解锁，不在 MVP 承诺内。Player Fantasy「每件道具变强一大截」在 MVP 3 层内全程可兑现（见 Player Fantasy 节）。

  **成长分布约束（本系统传递给 #2 楼层关卡数据系统的待决依赖）**：在上述 3 层上限内，本系统成长曲线的有效性**以下列条件为前提**：floor-layout 保证「MVP 3 层中每层 ≥1 次永久成长事件，Floor 1 不豁免」。若某层完全缺席永久成长事件，Player Fantasy 在该层失效，Pillar 1 局部断裂。**数据层可验证的代理指标**：该层 ENTITY 格中 `effect_type ∈ {ATK_BOOST, DEF_BOOST, MAXHP_BOOST}` 的条目数 ≥1（不含 HP_RESTORE）。注意这是必要非充分条件——HIGHEST_WINS 枯竭后运行时仍可能为 0 成长，数据层无法检测该运行时状态，故关卡设计须额外保证「永久成长事件分散于多层、单层成长事件数建议 ≤2」，且「同类更弱武器/盾在同层出现次数 ≤1，防止连续 `item_pickup_no_change` 负反馈」。**此约束当前为待决依赖**——须由 producer 推动 #2 在 Design Constraints 节落实（建议对标 #1 的 F-K1 格式新增 F-SC1 校验公式），方可从「设计意图」升格为「数据层可验证的硬规则」；在 #2 落实前，Pillar 1 的数据层可验证性处于真空（见 Open Questions 🚧 阻断记录）。成长节奏、枯竭点落在第几层、crystal_life 放置层（建议 Floor 2 或 Floor 3，**不建议 Floor 1**——Floor 1 玩家预期满血，heal_actual 仅等于 effect_value=50，MaxHP 扩容的「变得更耐打」生存感知最弱；放 Floor 3 则濒死拾取 heal_actual 可达 149，爽感最大但存活风险最高，由 #2 权衡。注：MVP=3 层下原「不晚于 Floor 3」表述无约束力，已收紧为本窗口）的具体方案由 #2 负责，本系统只传递约束边界。

## Dependencies

**Upstream（本系统依赖）**

| 系统 | 类型 | 依赖内容 |
|------|------|----------|
| #3 游戏调参配置 | 硬依赖（初始化必须）| `base_ATK=6`、`base_DEF=3`、`base_MaxHP=100`；本系统初始化时一次性读取 |
| #1 游戏实体数据库 | 硬依赖（道具拾取） | 道具的 `effect_type`、`effect_value`、`stack_rule`；`pickup_item()` 内按 item_id 查询 |

**Downstream（依赖本系统）**

| 系统 | 类型 | 期望接口 |
|------|------|----------|
| #2 楼层关卡数据系统 | 约束传递（非信号/接口）| 本系统成长曲线有效性依赖 #2 保证「每层 ≥1 次永久成长事件，Floor 1 不豁免」；此约束为**待 #2 落实的待决依赖**（当前 #2 仅以「参考指引」挂在 Tuning Knobs 节，尚未成为校验规则）；见 Open Questions 🚧 阻断记录 |
| #5 确定性回合战斗 | 硬依赖 | 读取 `player_ATK`、`player_DEF`（只读 getter）；调用 `apply_damage(amount: int)`（合同：amount ≥ 0） |
| #10 战斗预演 | 硬依赖 | 读取 `player_ATK`、`player_DEF`（只读，不调用 apply_damage） |
| #11 数值反馈视觉 | 软依赖（表现层）| 监听 `stat_changed(stat: String, old: int, new: int)`、`item_pickup_no_change(stat: String, item_id: String)`；**须同步连接（禁 CONNECT_DEFERRED），见 F-P04 信号顺序约束** |
| #12 HUD | 软依赖（表现层）| 监听 `stat_changed` 刷新显示；**须同步连接（禁 CONNECT_DEFERRED），见 F-P04 信号顺序约束** |
| #13 游戏状态管理 | 硬依赖 | 监听 `player_died()` 触发死亡流程 |
| #14 钥匙碎片经济（VS）| 软依赖 | 调用 `apply_temp_bonus(stat: String, amount: int)`（VS，预留接口）|
| #15 容错安全（VS）| 软依赖 | 调用 `apply_floor_guaranteed_hp(amount: int)` + 定义 apply_temp_bonus 公式（VS）|
| #18 存档（Alpha）| 硬依赖（持久化）| 读取完整属性快照序列化；写回反序列化恢复状态 |

**缺失 GDD 注记**：系统 #5、#6、#10、#11、#12、#13 均未设计 GDD。接口契约（信号名、参数类型）已在本 GDD 中单方面定义，设计这些系统时须与本 GDD 保持双向一致。

## Tuning Knobs

本系统本身不拥有独立的调参旋钮——所有平衡参数均在上游系统中定义，本系统消费：

| 调参旋钮 | 权威来源 | 影响本系统的方式 |
|----------|----------|-----------------|
| `base_ATK` = 6 | #3 游戏调参配置 | 决定玩家裸装攻击力起点；影响第 1 层无武器时的战斗能力 |
| `base_DEF` = 3 | #3 游戏调参配置 | 决定玩家裸装防御力起点；影响裸盾时的受伤量 |
| `base_MaxHP` = 100 | #3 游戏调参配置 | 决定玩家起始 HP；影响 D3 约束的绝对预算 |
| 道具 `effect_value`（武器/盾/药水/宝石）| #1 游戏实体数据库 | 决定每次成长跳跃的幅度 |

**本系统无可独立调整的旋钮**。若需调整成长曲线，应修改 #3 调参配置中的基准值或 #1 实体数据库中的道具数值，而非修改本系统代码。

**VS 阶段临时属性量级（预留）**：`apply_temp_bonus` 的 `amount` 由 #15 容错安全定义；本系统无法单独调整，须在 #15 GDD 中设置旋钮。

## Visual/Audio Requirements

本系统不直接渲染任何内容，但其信号是所有成长视觉反馈的权威触发源。#11 数值反馈视觉系统和 #12 HUD 系统必须对以下信号做出视觉响应：

| 信号 | 触发事件 | 必须产生的视觉响应（由 #11/#12 实现） |
|------|----------|--------------------------------------|
| `stat_changed("ATK", old, new)` new > old | 武器拾取升级 | ATK 数字在 HUD 上弹跳动画 + 飘字「ATK +Δ」（高饱和色） |
| `stat_changed("DEF", old, new)` new > old | 盾牌拾取升级 | DEF 数字在 HUD 上弹跳 + 飘字「DEF +Δ」 |
| `stat_changed("HP", old, new)` new > old | 药水/补满 | HP 条上升 + 绿色飘字「+heal_actual」 |
| `stat_changed("HP", old, new)` new < old | 战斗受伤 | HP 条下降 + 红色飘字「-damage_amount」（由 #5 战斗系统提供伤害值） |
| `stat_changed("MaxHP", old, new)` | 生命宝石 | HP 条宽度扩展（视觉上"长出"一段）→ 立即触发 HP fill 动画 |
| `stat_changed("HP", old, new)` old == new | 零伤格挡/满血回血 | 静默或轻量提示（「已满血」「完全格挡」）；**不触发受伤/回血动画** |
| `item_pickup_no_change("ATK"/"DEF", item_id)` | 拾取了更弱的武器/盾 | 轻量提示「已拥有更好的装备」；不触发属性弹跳动画 |
| `player_died()` | HP 归零 | 死亡画面由 #13 游戏状态管理驱动；#11 无需单独处理 |

**优先级**：ATK/DEF 升级的视觉强度 > HP 药水回血 > 战伤（升级弹跳需最强，遵循「成长反馈视觉必须比环境更亮、更跳」原则）。

> 📌 **Asset Spec**：Visual/Audio 需求定义完成。Art Bible 批准后，运行 `/asset-spec system:player-stats-growth` 生成飘字、升级动画、HP 条等资产规格。

## UI Requirements

本系统驱动 HUD（#12）显示的属性字段：

| 字段 | 来源属性 | 刷新时机 |
|------|----------|----------|
| 当前 HP / 最大 HP（如「70/100」）| `current_HP` / `MaxHP` | 任何 `stat_changed("HP")` 或 `stat_changed("MaxHP")` |
| ATK 值 | `player_ATK` | `stat_changed("ATK")` |
| DEF 值 | `player_DEF` | `stat_changed("DEF")` |

HUD 布局、字体、弹跳动画由 #12 HUD GDD 定义。本系统只保证信号格式正确；HUD 不得轮询属性，须通过信号驱动（解耦）。

> 📌 **UX Flag — Player Stats & Growth**：本系统有 UI 需求（HP/ATK/DEF 的 HUD 展示）。Pre-Production 阶段运行 `/ux-design` 为 HUD 界面创建 UX Spec；故事文件中涉及 HUD 的部分应引用 `design/ux/hud.md`，而非直接引用本 GDD。

## Acceptance Criteria

*(格式：GIVEN 初始状态，WHEN 动作或触发，THEN 可测量结果)*

> **前置状态注入约定（凡 GIVEN「玩家已持有某装备」或「GIVEN current_HP=0（Dead 状态）」的 AC 必读）**：**`pickup_item(item_id: String)` 是 PlayerStats 的公开 API**（见 P3 规则），测试直接调用即可注入前置状态，无需通过 #6 间接触发。非初始状态（如 `atk_boost_effective=14`）必须通过在 `watch_signals(player_stats)` 连接**之前**调用 `pickup_item(...)` 注入——GDUnit4 的 `watch_signals` 只记录连接点之后的发射，故连接前的前置拾取不会污染 `assert_signal_emit_count`，使其只统计 WHEN 触发后的发射。**禁止**通过直接写入 `_atk_boost_effective` 等私有字段注入（违反 P1 只读契约，且字段为下划线私有约定）。`assert_signal_emit_count(...)` 的计数语义 = 「watch_signals 连接后至断言时的发射次数」。
>
> **Dead 前置状态构造（凡 GIVEN「current_HP=0」的 AC 必读）**：在 `watch_signals(player_stats)` 连接**之前**调用 `apply_damage(100)`（或足量保证 HP 归零）来构造 Dead 前置状态；此过程中发射的 `stat_changed("HP", ...)` 和 `player_died()` 信号不计入后续 `assert_signal_emit_count`——与上方 pickup_item 前置注入约定对称（连接前的信号均不被 watch_signals 记录）。

**核心规则覆盖（P0–P8）**

- **AC-P0-SIGNAL-UPGRADE** — GIVEN `watch_signals(player_stats)` 已连接，且 `atk_boost_effective=8`（持 sword_iron，ATK=14），WHEN 踏上 sword_steel 格（effect_value=14），THEN `assert_signal_emitted_with_parameters(player_stats, "stat_changed", ["ATK", 14, 20])` 通过；`assert_signal_emit_count(player_stats, "stat_changed", 1)` 通过（恰好一次）；参数类型严格匹配签名（stat_name:String、old_value:int、new_value:int）。

- **AC-P0-SIGNAL-NOCHANGE** — GIVEN 在连接前经 `pickup_item("sword_steel")` 注入前置状态（atk_boost_effective=14，ATK=20，见上方注入约定），随后 `watch_signals(player_stats)` 连接，WHEN 踏上 sword_iron 格（effect_value=8），THEN `assert_signal_emitted_with_parameters(player_stats, "stat_changed", ["ATK", 20, 20])` 通过（old==new 合法，P0 约定）；`assert_signal_emit_count(player_stats, "stat_changed", 1)` 通过（仅统计 WHEN 之后的发射）；`assert_signal_emitted_with_parameters(player_stats, "item_pickup_no_change", ["ATK", "sword_iron"])` 通过恰好一次。被测对象用 `auto_free(player_stats)` 注册以在 teardown 回收（注：`auto_free` **仅注册清理、不检测也不断言孤儿数**；不要把它当孤儿断言用）。

- **AC-P1-INIT** — GIVEN 开始新局，WHEN 玩家系统初始化，THEN current_HP=100, MaxHP=100, ATK=6, DEF=3, atk_boost_effective=0, def_boost_effective=0, maxhp_bonus=0。

- **AC-P3-ATK-UPGRADE** — GIVEN 玩家持 sword_iron (ATK=14)，WHEN 踏上 sword_steel 格，THEN ATK 变为 20，stat_changed("ATK", 14, 20) 被发出。（道具格消失是 #6 网格移动系统的职责，不在本系统 AC 断言范围内。）

- **AC-P3-ATK-NOCHANGE** — GIVEN 玩家持 sword_steel（ATK=20，atk_boost_effective=14），WHEN 踏上 sword_iron 格（effect_value=8），THEN player_ATK 保持 20，**stat_changed("ATK", 20, 20) 被发出恰好一次**（P0 双信号约定），item_pickup_no_change("ATK", "sword_iron") 被发出恰好一次，sword_iron 格消失。

- **AC-P3-DEF** — GIVEN 玩家无盾 (DEF=3)，WHEN 踏上 shield_wood 格，THEN DEF 变为 8，stat_changed("DEF", 3, 8) 被发出。

- **AC-P3-HP** — GIVEN current_HP=60, MaxHP=100，WHEN 踏上 potion_small 格，THEN current_HP=100，stat_changed("HP", 60, 100) 被发出。

- **AC-P3-MAXHP** — GIVEN current_HP=70, MaxHP=100，WHEN 踏上 crystal_life 格，THEN MaxHP=150, current_HP=150，stat_changed("MaxHP", 100, 150) 先发出，stat_changed("HP", 70, 150) 后发出。

- **AC-P4-NOOVERHEAL** — GIVEN current_HP=90, MaxHP=100，WHEN 踏上 potion_large (+80) 格，THEN current_HP=100（非 170），stat_changed("HP", 90, 100) 被发出。

- **AC-P5-DAMAGE** — GIVEN current_HP=60，WHEN apply_damage(15) 被调用，THEN current_HP=45，stat_changed("HP", 60, 45) 被发出，player_died() 未发出。

- **AC-P6-DEATH** — GIVEN current_HP=10，WHEN apply_damage(30) 被调用，THEN current_HP=0，stat_changed("HP", 10, 0) 被发出，随即 player_died() 被发出（恰好一次）。

- **AC-P7-HIGHEST-WINS** — GIVEN 玩家已持 sword_steel（atk_boost_effective=14，ATK=20），WHEN 踏上 sword_iron 格（effect_value=8），THEN ATK 仍为 20（不降），atk_boost_effective 维持 14（注：此时 atk_boost_effective=14，与 AC-FP01 中 effective=8 无矛盾——两条 AC 描述的是不同游戏状态）。

- **AC-P8-MVP-STUB** — GIVEN MVP 阶段（记录 `var atk_before = player_ATK`），WHEN apply_temp_bonus("ATK", 5) 被调用，THEN 不崩溃（接口存在），`assert_eq(player_ATK, atk_before)` 通过（MVP 空实现，player_ATK 等于调用前的值）。

**公式覆盖（F-P01–F-P05）**

- **AC-FP01-BASE** — GIVEN 无武器（atk_boost_effective=0，ATK=6），WHEN 踏上 sword_iron（effect_value=8）格，THEN ATK=14, atk_boost_effective=8（从 0 首次升级到 sword_iron；与 AC-P7 场景不同，彼处 atk_boost_effective 起点为 14）。

- **AC-FP02-BASE** — GIVEN 无盾 (DEF=3)，WHEN 踏上 shield_wood (+5) 格，THEN DEF=8, def_boost_effective=5。

- **AC-FP02-NOCHANGE** — GIVEN 玩家持 shield_iron（DEF=13，def_boost_effective=10），WHEN 踏上 shield_wood 格（effect_value=5），THEN player_DEF 保持 13，def_boost_effective 维持 10，stat_changed("DEF", 13, 13) 被发出恰好一次（P0 双信号约定），item_pickup_no_change("DEF", "shield_wood") 被发出恰好一次。（道具格消失是 #6 网格移动系统的职责，不在本系统 AC 断言范围内。与 AC-P3-ATK-NOCHANGE 对称，覆盖 F-P02 降级分支）

- **AC-FP03-EXACT** — GIVEN current_HP=20, MaxHP=100，WHEN 踏上 potion_large (+80) 格，THEN current_HP=100（`current_HP + effect_value` 恰好 == MaxHP，钳制临界点：min() 不削减，全额生效），heal_actual=80（= effect_value），stat_changed("HP", 20, 100) 被发出。（覆盖钳制触发与不触发的边界等值点；与溢出钳制的 AC-P4-NOOVERHEAL 区分。原 AC-FP03-CLAMP 与 AC-P4-NOOVERHEAL 数值完全重复，已删除。）

- **AC-FP04-ORDER** — GIVEN current_HP=70, MaxHP=100，且测试连接一个 SignalOrderSpy（在每次收到 `stat_changed` 时把 `stat_name` 追加到内部数组 `spy.log`），WHEN crystal_life 被拾取，THEN `spy.log == ["MaxHP", "HP"]`（断言 `spy.log[0]=="MaxHP"`、`spy.log[1]=="HP"`、`len(spy.log)==2`）。
  > **测试实现注（必读）**：GDUnit4 无内置信号顺序断言。必须实现 SignalOrderSpy helper 并放入 `tests/helpers/signal_order_spy.gd`：
  > ```gdscript
  > # 文件路径：tests/helpers/signal_order_spy.gd
  > # 不含 class_name（避免 Godot 4 全局注册冲突）；在测试中用 preload 使用：
  > #   var spy = preload("res://tests/helpers/signal_order_spy.gd").new()
  > extends RefCounted
  > var log: Array[String] = []
  > func record(stat_name: String, _old: int, _new: int) -> void:
  >     log.append(stat_name)
  > ```
  > 连接：`player_stats.stat_changed.connect(spy.record)`（同步连接，禁 CONNECT_DEFERRED）。断言：`assert_eq(spy.log, ["MaxHP", "HP"])` 且 `assert_eq(spy.log.size(), 2)`。不可只断言「两条信号都发出」——无顺序信息。回调必须接受全部 3 个参数（Godot 4 静态检查强制执行），否则连接时报参数不匹配错误。

- **AC-FP04-FILL** — GIVEN MaxHP=100，分别以 `current_HP ∈ {1, 50, 100}` 三种前置值参数化执行（GDUnit4 DataProvider / `@DataSet([1], [50], [100])`），WHEN 每种情况下 crystal_life 被拾取，THEN 拾取后 `current_HP == MaxHP_new == 150`（满血保证，与起点无关）。

- **AC-FP04-FULL-START** — GIVEN current_HP=100, MaxHP=100（满血起始），WHEN crystal_life 被拾取，THEN MaxHP=150，current_HP=150，heal_actual=50（等于 effect_value），不发生 HP 溢出，stat_changed("MaxHP", 100, 150) 先发，stat_changed("HP", 100, 150) 后发。

- **AC-FP04-DYING** — GIVEN current_HP=1, MaxHP=100（濒死状态），WHEN crystal_life 被拾取，THEN MaxHP=150，current_HP=150，heal_actual=149（= 150 − 1），stat_changed("HP", 1, 150) 中 new_value = MaxHP_new = 150，不发生负值或溢出。

- **AC-FP05-OVERKILL** — GIVEN current_HP=1，WHEN apply_damage(999) 被调用，THEN current_HP=0（非负），player_died() 被发出。

- **AC-FP05-NEGATIVE-DAMAGE（非 GDUnit4 单元测试 — 验证方式：code review + grep + #5 集成测试）** — 契约：apply_damage 接收负值时，经 `damage_amount = max(0, damage_amount)` 钳制归零（生产期硬保证），current_HP 不变，不产生治疗效果，不违反 P4 不变量。`assert(damage_amount >= 0)` 作为调试期诊断工具（Release 构建中被剥除）。**实现/测试注（必读）**：GDScript `assert()` 失败在调试构建触发**引擎级脚本错误并中止当前测试函数**，GDUnit4 将其记为 ERROR 而非 PASS——**无法写成断言「assert 触发」的标准单元测试**。故本项验证方式为三路：(1) **code review** 确认 F-P05 存在 `assert` 行 + `damage_amount = max(0, damage_amount)` 钳制行；(2) **grep/CI lint** 确认两行均存在于 `src/player_stats.gd`（CI 命令：`grep -n "assert(damage_amount >= 0)\|max(0, damage_amount)" src/player_stats.gd` — 两行均应命中）；(3) **#5 战斗系统集成测试** 证明调用方在自身接口层永不传入负值（钳制为最后防线，正向契约由 #5 保证；**#5 GDD 待设计，该路集成测试 AC 编号待 #5 落地后反向引用本条；在此之前 F-P05 负值路径声明为「部分覆盖」——路径 (1)(2) 的钳制验证已完成，调用方契约验证 PENDING #5，见 Open Questions 跟踪。本 GDD 标 Complete 不阻断于此路径**）。release 构建中 assert 被剥除，但 max(0,...) 钳制永远生效（注：4.5 的 Script backtracing 不改变 assert 剥除行为，二者独立）。

**边界条件覆盖**

- **AC-EC-DEAD-ITEM** — GIVEN current_HP=0（Dead 状态），WHEN 玩家踏上道具格（须**分别测试全部 4 种 effect_type**：ATK_BOOST=`sword_iron`、DEF_BOOST=`shield_wood`、HP_RESTORE=`potion_small`、MAXHP_BOOST=`crystal_life`，逐一参数化），THEN 每种均：无拾取结算，道具格不消失，无任何 stat_changed 或 item_pickup_no_change 信号发出（本系统在 F-P01/F-P02/F-P03/F-P04 四处均设有 Dead 守卫，逐路径覆盖全部 effect_type，拦截层责任归属：**本系统**）。

- **AC-EC-DEAD-DAMAGE** — GIVEN current_HP=0（Dead 状态），WHEN apply_damage(100) 被调用，THEN current_HP 保持 0，无信号发出（包括不发出第二次 player_died()）。

- **AC-EC-ZERO-DAMAGE** — GIVEN current_HP=80，WHEN apply_damage(0) 被调用，THEN current_HP=80，stat_changed("HP", 80, 80) 被发出，player_died() 未发出。

- **AC-EC-FULL-HEAL** — GIVEN current_HP=MaxHP=100，WHEN potion_small 被拾取，THEN current_HP=100（不变），stat_changed("HP", 100, 100) 被发出（heal_actual=0）。

**Anti-Pillar Scope-Gate（本系统标记为 Complete 前须全部通过）**

- **AC-SCOPE-1（无随机数 — grep/lint 验证，与 AC-SCOPE-3 格式统一）** — GIVEN 本系统实现文件（`src/player_stats.gd` 及其单元），WHEN CI lint 规则扫描其源码，THEN `grep -nE "randf|randi|RandomNumberGenerator|seed\(" src/player_stats.gd` 返回零匹配即通过。**覆盖边界说明**：本 AC 证明「本系统无 RNG 调用入口」这一静态否定命题（确定性 Pillar 的源码层保证）；若未来经依赖注入接收外部随机源，须在本 AC 声明该路径为设计意图并由 #5 集成测试覆盖。（原「执行两次结果完全相同」的动态断言已删除——无确定性测试框架入口可机械执行「两次比较」，grep 静态检查语义更精确、可独立 pass/fail。）

- **AC-SCOPE-2（立即同步结算，无额外操作）** — GIVEN `watch_signals(player_stats)` 已连接（裸装初始状态），WHEN 调用 `pickup_item("sword_iron")`（该调用同步返回，未经过任何 `await`/yield/协程），THEN player_ATK == 14 已在同一调用帧内完成更新，`assert_signal_emitted_with_parameters(player_stats, "stat_changed", ["ATK", 6, 14])` 在函数返回后即可通过（无需 await，断言在同一调用帧内可验证）。（道具格消失是 #6 网格移动系统的职责，不在本系统 AC 断言范围内。）（实现注：若实现使用 await/协程导致结算跨帧，此 AC 失败，属 BLOCKING 设计违规——「立即结算、无额外操作步骤」由「同步完成」机器化证明。）

- **AC-SCOPE-3（广告隔离 — grep/lint 验证）** — GIVEN 本系统实现文件（`player_stats.gd` 及其单元），WHEN CI lint 规则扫描其源码，THEN 不得匹配任何广告相关标识符——CI 命令 `grep -Ein "ad_manager|show_ad|request_ad|ad_sdk|激励广告|tt[._]show|tt[._]ad|ttVideoAd|RewardedVideoAd|createRewardedVideo|showInterstitial|interstitial|JavaScriptBridge\.eval|JavaScriptBridge\.get_interface|JavaScriptBridge\.create_callback|douyin_|rewarded_video" src/player_stats.gd` 零匹配即通过（**必须用 `grep -E` 扩展正则**：`\.` 才匹配字面点；`tt[._]show` / `tt[._]ad` 同时覆盖 `tt.show` 与 `tt_show` 两种命名风格；`-i` 大小写不敏感）。**正则覆盖范围**：通用命名（ad_manager/show_ad 等）+ 抖音 JS Bridge 调用（tt.show*/tt_ad、ttVideoAd、RewardedVideoAd、createRewardedVideo、showInterstitial、interstitial）+ GDScript 调用 JS 的全部公开桥接入口（JavaScriptBridge.eval / get_interface / create_callback）+ GDScript 绑定前缀（douyin_、rewarded_video）。这从源码层证明「本系统不主动触发广告」这一否定命题（唯一目标平台：抖音小游戏）；广告仅由 #17 激励广告集成在玩家主动触发时调用。（覆盖边界随 #17 落地而扩充——见 Open Questions「AC-SCOPE-3 正则覆盖待 #17 扩充」待决项。）

## Open Questions

- **✅ [已解决 2026-06-25 / 第 9 轮] #2 floor-layout-data 已落实 Design Constraints 节** — #2 GDD 现已新增 Design Constraints 节（floor-layout-data.md L234）并落实 F-SC1a/b/c/d 强制校验规则（每层 ≥1 次永久成长事件、单层 ≤2、同类更弱装备同层 ≤1、Floor 2 盾牌拓扑顺序），执行层级与 #1 的 F-K1 等同——违反则不进入游戏。本 GDD「成长分布约束」（见 Edge Cases）的委派通道已落地，Pillar 1 数据层可验证性不再处于真空。**本 GDD 标 Complete 的此项前置条件已闭合。**
- **✅ [已解决 2026-06-25 / 第 9 轮] floor-layout-data.md 已锁定「3 层」** — #2 GDD L12 已更新为「MVP 阶段共定义 3 层（已锁定）」，原「3-5 层」表述已收紧，与本 GDD 锁定的 MVP=3 层一致，冲突消除。
- **AC-SCOPE-3 正则覆盖待 #17 扩充（非阻断）** — #17 激励广告集成 GDD 定义广告接口契约后，须核实其绑定层实际标识符并更新 AC-SCOPE-3 正则覆盖边界；届时可补路径 B（注入 AdManagerSpy mock，跑完整道具+伤害序列后断言 `show_ad_call_count == 0`）。此为 #17 设计时的待决项，不阻断本 GDD。
- **F-P05 负值路径完整覆盖待 #5（部分覆盖）** — AC-FP05-NEGATIVE-DAMAGE 路径 (1)(2)（钳制 + grep）已可验证；路径 (3)（#5 战斗系统集成测试证明调用方永不传负值）待 #5 GDD 落地后补集成测试并反向引用本条。在此之前 F-P05 负值路径声明为「部分覆盖」，不阻断本 GDD 标 Complete。
- **F-P04 存档原子性（Alpha）** — F-P04 在两次 emit（MaxHP / HP）之间存在 `current_HP` 未补满的合法但语义不完整窗口。#18 存档系统须将 F-P04 结果作为原子事务序列化，不得在 F-P04 执行中途采样（见 F-P04「中间态约束」）。
- **VS: apply_temp_bonus 作用域** — 临时属性是「本局生效」还是「本层生效」？由 #15 容错安全 GDD 决策，届时需反向补全本 GDD 的 P8 规则。
- **VS: 第二颗 crystal_life 的 D3 验证** — entities.yaml 已标注「VS 引入第二颗须重估 D3」。VS 阶段新增 crystal_life 前，关卡设计师须用新 MaxHP=200（如有第二颗）重跑 D3 表格。
- **存档格式（Alpha）** — 玩家属性快照的序列化字段列表需在 #18 存档系统 GDD 中正式声明，届时需与本 GDD 的属性模型（P1/P2）双向对齐。
