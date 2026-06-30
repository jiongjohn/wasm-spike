# 游戏调参配置 (Game Tuning Config)

> **Status**: Approved（第2轮复评 2026-06-25；实现前置：架构 ADR 须确定 TuningConfig/FloorTuningRow 类型 + TuningFormulas 函数归属）
> **Author**: lumen + agents
> **Last Updated**: 2026-06-24
> **Implements Pillar**: P1「看得见的成长」（曲线形状决定玩家感受滚雪球的节奏）+ P2 确定性（曲线决定 D1/D3 约束是否可满足）

## Overview

游戏调参配置（Game Tuning Config）是《像素魔塔·无尽塔》中所有**平衡参数的集中权威来源**。它定义三类数据：(1) 玩家起始属性（HP/ATK/DEF 初始值）；(2) 各楼层玩家预期中位属性曲线（`player_ATK_expected`、`player_HP_expected`、`player_DEF_expected` 逐层表），供实体数据库 D1/D3 校验和关卡设计参考；(3) 全局战斗参数（伤害公式系数、战斗节奏、D1/D3 约束系数）。

本系统是纯配置层，不含任何逻辑。数据以 JSON 格式存储，游戏启动时一次性加载并校验，运行期间只读。所有需要平衡参考值的系统——实体数据库的 D1/D3 校验、玩家属性系统的初始化、战斗系统的伤害计算——均从本文件读取，不得在代码中硬编码这些数值。

做好本系统，调整平衡不需要改代码，只改 JSON。这是「数据驱动」原则的执行点。

## Player Fantasy

玩家永远不会打开「配置文件」。但他们感受得到它的存在：每件道具的加成都有明确的、立竿见影的数字反馈——捡到铁剑，攻击数字从 6 跳到 14；捡到生命宝石，上限数字从 100 跳到 150 并立即回满。这种「数字可见、增量清晰」的感受，是 P1「看得见的成长」的直接载体。

调参配置做得好，每次捡到道具玩家都会感到「明显变强了」——而非「变强了一点点」或「变强的幅度不清楚」。做得不好（曲线过缓或过陡），玩家要么感受不到成长，要么在两层内就碾压全场，失去继续爬的动力。

> **可证伪判据（供 QA / 玩测验证）：** 在 3 层试玩中，玩家能够主动说出「找到那把剑之后明显变强了」或「找到那颗宝石 HP 跳了好多」。若玩家对成长无感知，视为本配置未交付其隐性 Fantasy。

## Detailed Design

### Core Rules

**规则 T1 — 战力模型：装备决定战力**
- `player_ATK = base_ATK + atk_boost_effective`（`atk_boost_effective` = 已拾取武器中 ATK_BOOST 的最大值，HIGHEST_WINS；未拾取任何武器时为 0）
- `player_DEF = base_DEF + def_boost_effective`（同上，最优盾的 DEF_BOOST）
- `player_MaxHP = base_MaxHP + Σ(所有已拾取 MAXHP_BOOST 道具的 effect_value，ADDITIVE)`
- `player_current_HP`：实时值，上限为 `player_MaxHP`；不存在溢出治疗（no overheal）

玩家没有独立的「战斗经验升级」系统——成长完全来自拾取道具。这是「装备决定战力」的设计边界，与 #4 玩家属性系统的接口契约。

**规则 T2 — 伤害公式（全局双方适用，prototype 已验证）**

```
player_damage_to_monster = max(1, player_ATK - monster_DEF)   // 最小1伤害，玩家永远能伤害怪物
monster_damage_to_player = max(0, monster_ATK - player_DEF)   // 最小0，防御可完全抵消
```

非对称设计意图：`max(1, …)` 确保玩家永远有希望击败任何怪物；`max(0, …)` 允许盾完全吸收伤害，创造「无伤」的满足感（如 shield_wood 对史莱姆：max(0, 8-8)=0）。

**规则 T3 — 战斗节奏**
- `BATTLE_ROUND_DURATION = 0.3s`（单回合攻击动画+结算总时长，prototype 已确认）
- 战斗结算**纯确定性**：给定双方属性，总回合数和总伤害完全可在战斗前预演

**规则 T4 — 玩家起始属性**

| 参数 | 值 | 说明 |
|---|---|---|
| `base_ATK` | **6** | 游戏开始时裸 ATK（无任何装备） |
| `base_DEF` | **3** | 游戏开始时裸 DEF（无任何装备） |
| `base_MaxHP` | **100** | 游戏开始时最大 HP |
| `game_start_HP` | **100**（= base_MaxHP） | 入场满血 |

**规则 T5 — 全局约束常量（供 D1/D3 校验 + #5 战斗系统使用）**

| 常量 | 值 | 安全范围 | 用途 |
|---|---|---|---|
| `N_max` | **10** | 5–20 | D1 怪物可被击杀的最大回合数 |
| `HP_BUDGET_RATIO` | **0.35** | 0.05–1.0 | D3 单只怪允许消耗玩家 HP 的上限占比 |

> **与 entity-database.md 的关系**：N_max 和 HP_BUDGET_RATIO 已在 entity-database.md Tuning Knobs 中声明，并注册于 entities.yaml。**本系统是这两个常量的权威数值来源**；entity-database.md 消费这些值，不得在代码中另行硬编码。

**规则 T6 — 各楼层玩家预期属性中位表（D1/D3 ValidationConfig 的正式来源）**

> 本表是本系统最关键的输出。`validate_database(entries, ValidationConfig{player_atk_expected, player_def_expected, player_hp_expected, n_max, hp_budget_ratio})` 中的 player 参数按当前 `floor_number` 从本表读取。关卡设计师须确保各层道具放置能使玩家达到或超过本表中位值。

| floor_number | player_ATK_expected | player_DEF_expected | player_HP_expected | 装备假设（关卡须提供的道具） |
|---|---|---|---|---|
| **1** | **14** | **8** | **100** | 本层可拾取 sword_iron(ATK+8) + shield_wood(DEF+5)；入层满血 |
| **2** | **14** | **13** | **90** | 本层可拾取 shield_iron(DEF+10)；已使用 potion_small 补血 |
| **3** | **20** | **13** | **135** | 本层可拾取 sword_steel(ATK+14) + crystal_life(MaxHP+50=150)；使用药水后 |
| **4** *(VS 预规划)* | **20** | **13** | **115** | 无新装备；potion_large 已使用；floor 3 goblin 战斗消耗。**MVP 无此层，数据仅供 VS 阶段 D1/D3 设计层验证参考。** |
| **5** *(VS 预规划)* | **20** | **13** | **110** | 无新装备；floor 4 goblin 战斗消耗。**MVP 无此层，同上。** |

**D1/D3 全量验证（MVP 所有怪物，以本表为输入）：**

| 怪物 | 楼层 | player_ATK | player_DEF | player_HP | D1 净伤/要求 | D3 总伤/预算 | 结果 |
|---|---|---|---|---|---|---|---|
| slime | 1 | 14 | 8 | 100 | 12 / 2 | 0 / 35 | ✅ |
| goblin | 2 | 14 | 13 | 90 | 9 / 5 | 30 / **31** | ✅（余量仅 1 点，极限）|
| goblin | 3 | 20 | 13 | 135 | 15 / 5 | 20 / 47 | ✅ |
| goblin | 4 | 20 | 13 | 115 | 15 / 5 | 20 / 40 | ✅ |
| goblin | 5 | 20 | 13 | 110 | 15 / 5 | 20 / 38 | ✅ |

> **注：D3 预算 = int(HP_BUDGET_RATIO × player_HP_expected)，向下取整为整数。故 floor 2 的预算 = int(0.35 × 90) = int(31.5) = 31，不是 31.5。**

> **floor 2 goblin 极限注意**：D3 预算 31 vs 伤害 30，余量 **仅 1 点**（约 1.1%）。**关卡设计硬约束：shield_iron 必须放置在 floor 2 第一只 goblin 可到达之前的位置，且不得被门阻隔（或门钥匙同样在 goblin 之前可拾取）**。如违反，玩家仅有 shield_wood（DEF=8）时，每回合受伤 10，6 回合总伤 60，超出预算 94%，出现死墙。**此约束已在 floor-layout-data Design Constraints 节落实为 F-SC1d（shield_iron 须在 goblin 可达路径之前，含 BFS 拓扑验证）。** VS 阶段容错机制（#15）落地后此余量将自动放宽。

---

### States and Transitions

本系统无运行时状态变化。加载流程：
1. 游戏启动 → 从 `res://data/tuning_config.json` 加载配置
2. 校验所有字段存在且值在合法范围内（见 Edge Cases）
3. 全部通过 → 数据就绪，供下游系统只读查询
4. 任一失败 → 显示错误屏，不进入游戏（WASM 下纯代码内联构建，不依赖 quit()）

---

### Interactions with Other Systems

| 下游系统 | 读取内容 | 接口方向 |
|---|---|---|
| #1 游戏实体数据库（D1/D3 校验） | 按 `floor_number` 读取 `player_ATK_expected`、`player_DEF_expected`、`player_HP_expected`；读取 `N_max`、`HP_BUDGET_RATIO` | 读取 TuningConfig |
| #4 玩家属性与成长 | `base_ATK`、`base_DEF`、`base_MaxHP`（玩家初始化） | 读取 TuningConfig |
| #5 确定性回合战斗 | 伤害公式系数（`BATTLE_ROUND_DURATION`；damage = max(1, ATK-DEF) 的公式约定） | 读取 TuningConfig |

## Formulas

> 本节包含两类公式：(1) 运行时战斗结算公式（#5 战斗系统消费）；(2) 平衡工具公式（D1/D3 校验、关卡设计工具消费）。所有公式均使用整数运算，`ceil()` 结果存为 int。

---

### F1-A — 玩家对怪物净伤害

```
damage_player_to_monster = max(1, player_ATK - monster_DEF)
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `player_ATK` | int | 6–26（MVP：6 裸装–20 精钢剑） | 玩家当前攻击力（见 F3-A） |
| `monster_DEF` | int | 0–（D1 约束，MVP max=5） | 怪物防御力，来自 MonsterEntry |
| `damage_player_to_monster` | int | **≥1**（max 无上限） | 每回合玩家对怪物造成的伤害 |

**输出范围**：下限钳制为 1——玩家永远能伤害怪物（P2 确定性保证：任何怪物都有解）。上限无钳制。
**示例**（floor 1，slime，sword_iron）：max(1, 14-2) = **12**

---

### F1-B — 怪物对玩家净伤害

```
damage_monster_to_player = max(0, monster_ATK - player_DEF)
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `monster_ATK` | int | 0–（MVP max=18，goblin） | 怪物攻击力，来自 MonsterEntry |
| `player_DEF` | int | 3–13（MVP：3 裸装–13 shield_iron） | 玩家当前防御力（见 F3-B） |
| `damage_monster_to_player` | int | **≥0**（max 无上限） | 每回合怪物对玩家造成的伤害 |

**输出范围**：下限钳制为 0——盾可完全抵消伤害（无伤通关的满足感）。与 F1-A 的非对称设计：`max(0, …)` vs `max(1, …)`。
**示例**（floor 1，slime，shield_wood）：max(0, 8-8) = **0**（完美格挡）

---

### F1-C — 击杀怪物总回合数

```
N_rounds_to_kill = ceil(monster_HP / max(1, player_ATK - monster_DEF))
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `monster_HP` | int | ≥1（MVP：slime=20, goblin=50） | 怪物最大 HP |
| `player_ATK` | int | 6–26 | 玩家攻击力 |
| `monster_DEF` | int | ≥0 | 怪物防御力 |
| `N_rounds_to_kill` | int | **1–N_max（D1 保证）** | 击杀所需回合数 |

**输出范围**：D1 保证 ≤ N_max=10；最小值 1（one-shot 场景）。
**示例**（floor 3，goblin，sword_steel）：ceil(50/max(1,20-5)) = ceil(50/15) = ceil(3.33) = **4 回合**

---

### F1-D — 单场战斗总时长（秒）

```
battle_duration_seconds = N_rounds_to_kill × BATTLE_ROUND_DURATION
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `N_rounds_to_kill` | int | 1–10（D1 保证） | 击杀回合数（F1-C） |
| `BATTLE_ROUND_DURATION` | float | 固定 **0.3s** | 单回合动画+结算时长（prototype 确认） |
| `battle_duration_seconds` | float | **0.3s–3.0s** | 单场战斗总时长 |

**输出范围**：0.3s（一击必杀）到 3.0s（N_max=10 回合，最长合法战斗）。手游场景下 3s 内结束所有战斗是核心节奏要求。
**示例**：floor 1 slime 2 回合 × 0.3s = **0.6s**；floor 3 goblin 4 回合 = **1.2s**

---

### F2-A — 各楼层预期属性查询（表驱动）

```
(player_ATK_expected[f], player_DEF_expected[f], player_HP_expected[f])
    = TUNING_TABLE.lookup(floor_number = f)
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `f` | int | 1–max_floor（MVP：1–3；floor 4-5 为 VS 预规划行，D1/D3 为设计层验证） | 目标楼层编号（1-based） |
| `player_ATK_expected[f]` | int | ≥6 | 楼层 f 的玩家 ATK 中位预期（见规则 T6） |
| `player_DEF_expected[f]` | int | ≥3 | 楼层 f 的玩家 DEF 中位预期 |
| `player_HP_expected[f]` | int | ≥1 | 楼层 f 的玩家 HP 中位预期 |

**输出范围**：按表返回整数。查询 `f > max_floor` 为未定义——D1/D3 校验遇到无记录的楼层须报「楼层无预期数据」错误，不得用越界值。
**VS 扩展约定**：扩展层数时先向 TUNING_TABLE 补行，再运行 D1/D3 全量验证；不得外推，不得跳过验证。
**策略说明**：本游戏的属性成长完全由「道具拾取路径」决定，不存在数学可导的平滑曲线——强行外推只会制造数字幻觉而使 D1/D3 失效。纯表驱动是正确选择。

---

### F3-A — 玩家攻击力计算

```
atk_boost_effective = max({w.effect_value : w ∈ held_weapons}, default=0)
player_ATK = base_ATK + atk_boost_effective
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `base_ATK` | int | 固定 **6** | 裸装攻击力（T4） |
| `held_weapons` | 集合 | MVP：{sword_iron=8, sword_steel=14} | 玩家已拾取的全部 ATK_BOOST 道具 |
| `atk_boost_effective` | int | 0–20（MVP） | 已拾取武器中最大的 effect_value（HIGHEST_WINS） |
| `player_ATK` | int | **6–20**（MVP） | 玩家当前攻击力 |

**MVP 所有可能的 player_ATK 值**：裸装 6 → sword_iron 14 → sword_steel 20（HIGHEST_WINS 防止多把剑累加击穿 D1 假设）

---

### F3-B — 玩家防御力计算

```
def_boost_effective = max({s.effect_value : s ∈ held_shields}, default=0)
player_DEF = base_DEF + def_boost_effective
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `base_DEF` | int | 固定 **3** | 裸装防御力（T4） |
| `held_shields` | 集合 | MVP：{shield_wood=5, shield_iron=10} | 玩家已拾取的全部 DEF_BOOST 道具 |
| `def_boost_effective` | int | 0–10（MVP） | 已拾取盾牌中最大的 effect_value |
| `player_DEF` | int | **3–13**（MVP） | 玩家当前防御力 |

**MVP 所有可能的 player_DEF 值**：裸装 3 → shield_wood 8 → shield_iron 13

---

### F3-C — 玩家最大 HP 计算

```
player_MaxHP = base_MaxHP + Σ(item.effect_value for item in held_maxhp_items)
player_HP_after_restore = min(player_current_HP + potion.effect_value, player_MaxHP)
```

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `base_MaxHP` | int | 固定 **100** | 起始最大 HP（T4） |
| `held_maxhp_items` | 列表 | MVP：最多一颗 crystal_life(=50) | MAXHP_BOOST 道具，ADDITIVE 叠加 |
| `player_MaxHP` | int | **100 或 150**（MVP） | 当前最大 HP |
| `player_HP_after_restore` | int | ≤ player_MaxHP | 药水回血后的 HP（no overheal） |

**VS 注意**：ADDITIVE 无上限，VS 引入第二颗 crystal_life 时 MaxHP → 200，导致 player_HP_expected 偏离 D3 假设，须重跑 D3 全量验证。

---

### F4-A — 单层总伤害消耗预测（关卡设计工具，离线用）

```
damage_taken_i = F1-B(monster_ATK_i, player_DEF_expected[f]) × F1-C(monster_HP_i, player_ATK_expected[f], monster_DEF_i)

total_floor_damage = Σ(damage_taken_i  for i in floor_monsters)
available_heals    = Σ(potion.effect_value  for potion in floor_potions)
net_floor_damage   = total_floor_damage - available_heals

floor_damage_ratio = total_floor_damage / player_HP_expected[f]  // 0.0–unbounded，设计参考
```

| 变量 | 类型 | 描述 |
|---|---|---|
| `floor_monsters` | 列表 | 该层全部怪物的 MonsterEntry |
| `floor_potions` | 列表 | 该层全部即时回血道具 |
| `net_floor_damage` | int | 净消耗（可为负：药水充足） |
| `floor_damage_ratio` | float | 总消耗占玩家 HP 的比例（设计目标 ≤ 0.6–0.8） |

**注意**：仅供离线关卡设计工具调用；公式假设线性遭遇顺序，不建模路径选择。`floor_damage_ratio > 1.0` 时为警告（非强制报错），设计师须核查布局。
**示例**（floor 2，1 只 goblin + 1 瓶小药水）：
- damage = max(0, 18-13) × ceil(50/9) = 5 × 6 = 30
- heals = 40
- net = 30 - 40 = **-10**（净增益，安全）

---

### 边界值分析

**B1 — player_DEF ≥ monster_ATK（0 伤格挡）**

`max(0, monster_ATK - player_DEF) = 0`：每回合怪物造成 0 伤害，玩家战斗零消耗。

MVP 实例：floor 1 slime(ATK=8) + shield_wood(DEF=8)。
- **正面体验**：明确的「装备有用」信号，Pillar 1 的感知强化点
- **风险**：若整层全为 0 伤怪，战斗退化为「无意义点击」。关卡设计须保证每层至少 1 只非 0 伤怪维持策略张力（D3 不约束最小消耗，需人工保证）

**B2 — player_ATK - monster_DEF = 0（1 伤死磨）**

`max(1, player_ATK - monster_DEF) = 1`：每回合玩家造成 1 伤害，击杀回合数 = monster_HP。

- slime(HP=20)：需 20 回合 × 0.3s = 6s；goblin(HP=50)：需 50 回合 = 15s（体验灾难）
- **D1 DEF 独立上限校验**（`monster_DEF < player_ATK_expected`）从数据层阻止此情形进入游戏
- **N_max=10 时间边界**：D1 保证最长战斗 10 回合 × 0.3s = 3.0s，满足手游节奏要求

**B3 — floor 2 goblin D3 极限余量（1 点）**

`hp_budget = int(0.35 × 90) = 31`；goblin 实际消耗 = 30；余量 = 1 点（1.1%）。

分析详见 Detailed Design T6 注释。核心结论：**余量不足时不应调高 HP_BUDGET_RATIO**（调参无法替代布局保证）；应在关卡约束中硬性要求 shield_iron 在第一只 goblin 之前可拾取。VS 阶段容错机制（#15）落地后此余量将自动放宽。

## Edge Cases

**数据合法性（启动校验，违反则不进入游戏）：**

- **必填字段缺失**：`base_ATK`、`base_DEF`、`base_MaxHP`、`N_max`、`HP_BUDGET_RATIO`、`BATTLE_ROUND_DURATION`、`floor_tuning_table` 任一缺失，报缺失字段错误，**不降级、不填默认值**，不进入游戏
- **`base_ATK < 1`**：非正值报错（F3-A 需 base_ATK ≥ 1 以保证玩家 ATK ≥ 1）
- **`base_DEF < 0`**：负值报错
- **`base_MaxHP < 1`**：非正值报错
- **`N_max` 不在 5–20**：报根因错误（D1 约束失效，整个怪物校验无意义），不逐怪报 D1 违反
- **`HP_BUDGET_RATIO < 0.05`**：报根因错误（此值导致所有有伤怪物违反 D3，游戏无法启动）
- **`HP_BUDGET_RATIO > 1.0`**：报根因错误（无意义的预算上限）
- **`BATTLE_ROUND_DURATION ≤ 0`**：非正值报错（F1-D 产生非正时长）
- **`floor_tuning_table` 为空（0 行）**：报「空曲线表」错误
- **`floor_tuning_table` 任意行缺少必填字段**（`floor_number` / `player_ATK_expected` / `player_DEF_expected` / `player_HP_expected`）：报缺失字段 + 行号
- **`player_ATK_expected < 10`**：entity-database D1 的启动硬约束，违反报根因错误（不得进入 D1 逐怪验证）
- **`player_HP_expected < 1`**：D3 使用，违反报错
- **`player_DEF_expected < 0`**：违反报错
- **`floor_tuning_table` 中 `floor_number` 重复**：报「重复楼层号」错误
- **`floor_tuning_table` 中 `floor_number` 非正整数**：报错
- **JSON 格式损坏或无法解析**：报「配置文件解析失败」；WASM 下显示可见错误屏节点（纯代码内联，不依赖 `quit()`），同 entity-database.md 的 WASM 错误屏规则

**运行时语义（非数据校验）：**

- **裸装入场（atk_boost_effective=0）**：合法。player_ATK=6，对 floor 1 slime 净伤 4，需 5 回合，受伤 max(0, 8-3)×5=25。总伤 25 < D3 预算 35（基础 HP=100），可通关。属设计学习曲线，不报错。
- **玩家 HP 降至 0**：死亡状态由 #13 游戏状态管理处理，本系统不定义死亡后的行为
- **药水回血超过 MaxHP**：钳制到 MaxHP（no overheal），见 F3-C
- **`floor_tuning_table` 查询不存在的 floor_number**：返回 null；调用方（entity-database D1/D3 校验器）须报「楼层无预期数据」错误而非静默使用越界值
- **`BATTLE_ROUND_DURATION` 调高到 0.5s+**：合法，但单场战斗最长 5s，手游体感偏慢，需 playtest 验证再上线
- **WASM / 抖音平台**：配置文件须打包进 `res://`（不得放 `user://`，理由同 entity-database.md）

## Dependencies

### 上游依赖

**无。** 本系统是 Foundation 层，无上游 GDD 依赖。所有数据由关卡设计师手工填写。

### 下游依赖（依赖本系统的）

| 系统 | 依赖性质 | 读取内容 |
|---|---|---|
| **#1 游戏实体数据库** | 硬依赖（D1/D3 校验须消费本系统） | `N_max`、`HP_BUDGET_RATIO`；按 `floor_number` 读 `player_ATK/DEF/HP_expected` 构建 ValidationConfig |
| **#4 玩家属性与成长** | 硬依赖（玩家初始化） | `base_ATK`、`base_DEF`、`base_MaxHP` |
| **#5 确定性回合战斗** | 硬依赖（伤害公式） | `BATTLE_ROUND_DURATION`；F1-A/B 伤害公式约定（max(1,…)/max(0,…) 非对称规则） |

> **双向性提醒**：以上下游系统 GDD 编写时，须在其 Dependencies 节反向声明对本系统的依赖；#5 战斗 GDD 须引用 F1-A/F1-B 而非自行定义伤害公式。

### 接口约定

- `get_tuning_config() -> TuningConfig`：返回全量配置对象（只读）
- `get_floor_tuning(floor_number: int) -> FloorTuningRow?`：返回指定楼层的 `{player_ATK_expected, player_DEF_expected, player_HP_expected}`；不存在返回 null，调用方须处理 null
- 具体数据类型（TuningConfig / FloorTuningRow）由架构阶段 ADR 确定，与 entity-database.md、floor-layout-data.md 共用同一数据格式 ADR

## Tuning Knobs

所有调参值在 `res://data/tuning_config.json` 中直接修改，无需改代码。

### 全局参数

| 参数 | 当前值 | 安全范围 | 影响 | 极端值行为 |
|---|---|---|---|---|
| `base_ATK` | **6** | 2–15 | 裸装战斗感受；影响装备加成的感知幅度 | <2：裸装时几乎打不过怪；>10：装备加成感知弱 |
| `base_DEF` | **3** | 0–8 | 裸装受伤感受；影响盾牌的感知价值 | =0：裸装承受全部伤害；>8：slime 直接 0 伤（跳过学习弧） |
| `base_MaxHP` | **100** | 50–200 | 容错带宽、药水价值感、D3 预算基础 | <50：轻用户过度紧张；>200：药水感知弱 |
| `N_max` | **10** | 5–20 | D1 严格程度；单场战斗最长时间上限 | <5：DEF 设计空间极小；>20：最长战斗 6s，节奏拖沓 |
| `HP_BUDGET_RATIO` | **0.35** | 0.05–1.0 | D3 严格程度；单只怪的威胁感 | <0.1：几乎所有有伤怪物违反 D3；>0.7：单怪几乎可杀死玩家 |
| `BATTLE_ROUND_DURATION` | **0.3s** | 0.15s–0.8s | 战斗节奏体感；用于 F1-D 总时长计算 | <0.15s：视觉闪烁难感知；>0.5s：节奏拖沓，轻用户流失 |

### 各楼层预期属性曲线（`floor_tuning_table`）

| 参数 | floor 1 | floor 2 | floor 3 | floor 4 | floor 5 | 调参原则 |
|---|---|---|---|---|---|---|
| `player_ATK_expected` | 14 | 14 | 20 | 20 | 20 | 与该层可拾取武器效果绑定；变更须同步更新关卡布局 |
| `player_DEF_expected` | 8 | 13 | 13 | 13 | 13 | 与该层可拾取盾牌效果绑定；同上 |
| `player_HP_expected` | 100 | 90 | 135 | 115（VS 预规划）| 110（VS 预规划）| 受药水使用量和战斗消耗共同影响；最难准确估计的参数。⚠️ **floor 2 最低安全值 = 86**（int(0.35×86)=30 = goblin 伤害；调低至 85 则 D3 预算 29 < goblin 伤害 30，游戏启动失败，优先核查）|

> **调参联动约束**：曲线表中任何值变更后，**必须**重跑 D1/D3 全量验证，确认所有 MVP 怪物仍通过。`player_HP_expected` 调低时 D3 预算收紧，floor 2 goblin 的极限余量（当前仅 1 点）尤其脆弱，须优先核查。

## Visual/Audio Requirements

N/A — 本系统为无界面纯配置层，自身无视觉/音频产出。`BATTLE_ROUND_DURATION` 影响战斗动画时序，具体动画表现由 #5 确定性回合战斗和 #11 数值反馈视觉系统实现，本系统仅提供参数值。

## UI Requirements

N/A — 本系统无玩家界面。调参值的可视化调试面板（如有）属于开发工具范畴，由 tools-programmer 另行实现，不属于玩家面向的 UI。

## Acceptance Criteria

> **断言契约**：校验逻辑封装为 `validate_tuning_config(config: TuningConfig) -> ValidationResult`，其中 `ValidationResult` 含 `is_valid: bool`、`errors: Array`（每条含 `field`、`code`、`message`）。所有 AC 断言此返回对象，不断言「游戏是否进入主界面」。全部为 **Logic** 类型，**GDUnit4** headless 可运行（运行命令：`godot --headless --script tests/gdunit4_runner.gd`）。
>
> 公式类 AC 假设存在静态工具类 `TuningFormulas`（或等效模块），提供 `damage_player(atk, def)`、`damage_monster(atk, def)`、`n_rounds(hp, atk, def)` 等纯函数，不依赖场景树。具体函数签名由 ADR 锁定（见 Open Questions）。

### AC-TC-01 — 合法完整 MVP 配置通过校验（Logic）
**GIVEN** 构造一个 TuningConfig，字段全部合法：base_ATK=6, base_DEF=3, base_MaxHP=100, N_max=10, HP_BUDGET_RATIO=0.35, BATTLE_ROUND_DURATION=0.3，**floor_tuning_table 含 floor1–floor3 完整 3 行**（MVP 标准层数），所有 player_ATK_expected ≥ 10，其余值均在规范范围内,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == true`；`errors` 数组长度为 0。

### AC-TC-01b — VS 预规划 5 行配置合法通过校验（Logic）
**GIVEN** 构造一个 TuningConfig，同 AC-TC-01，但 **floor_tuning_table 含 floor1–floor5 共 5 行**（VS 预规划场景，floor 4-5 数据合法），所有 player_ATK_expected ≥ 10，其余值均在规范范围内,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == true`；`errors` 数组长度为 0。（注：floor_tuning_table 校验器不限制行数上限，VS 预规划行合法共存；F-MVP 的 3 层约束由 floor-layout-data 校验，不在本校验器执行。）

### AC-TC-02 — player_ATK_expected < 10 触发启动错误（Logic）
**GIVEN** 构造一个 TuningConfig，仅将某行 `player_ATK_expected` 设为 9，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "player_ATK_expected"`、`code == "ATK_EXPECTED_TOO_LOW"` 的记录。

### AC-TC-03 — HP_BUDGET_RATIO < 0.05 触发启动错误（Logic）
**GIVEN** 构造一个 TuningConfig，仅将 `HP_BUDGET_RATIO` 设为 0.04，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "HP_BUDGET_RATIO"`、`code == "HP_RATIO_TOO_LOW"` 的记录。

### AC-TC-04 — N_max 下界越界（N_max=4）触发启动错误（Logic）
**GIVEN** 构造一个 TuningConfig，仅将 `N_max` 设为 4，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "N_max"`、`code == "N_MAX_OUT_OF_RANGE"` 的记录。

### AC-TC-05 — N_max 上界越界（N_max=21）触发启动错误（Logic）
**GIVEN** 构造一个 TuningConfig，仅将 `N_max` 设为 21，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "N_max"`、`code == "N_MAX_OUT_OF_RANGE"` 的记录（同 AC-TC-04，覆盖上下两侧越界）。

### AC-TC-06 — 缺失必填字段触发校验失败（Logic）
**GIVEN** 构造一个 TuningConfig，故意省略 `base_MaxHP` 字段（不赋值或设为 null），其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "base_MaxHP"`、`code == "MISSING_REQUIRED_FIELD"` 的记录；**不填默认值、不降级**。

### AC-TC-07 — F1-A 玩家伤害公式正确性（Logic）
**GIVEN** player_ATK=14, monster_DEF=8,
**WHEN** 调用 `TuningFormulas.damage_player(14, 8)`,
**THEN** 返回值 == 6（即 max(1, 14-8) = 6）。

### AC-TC-08 — F1-A 玩家伤害公式下限保护（ATK ≤ DEF 时最小伤害=1）（Logic）
**GIVEN** player_ATK=5, monster_DEF=10,
**WHEN** 调用 `TuningFormulas.damage_player(5, 10)`,
**THEN** 返回值 == 1（即 max(1, 5-10) = 1；下限保证玩家永远能伤害怪物）。

### AC-TC-09 — F1-B 怪物伤害公式下限保护（ATK ≤ DEF 时伤害=0）（Logic）
**GIVEN** monster_ATK=5, player_DEF=8,
**WHEN** 调用 `TuningFormulas.damage_monster(5, 8)`,
**THEN** 返回值 == 0（即 max(0, 5-8) = 0；盾完全格挡的合法场景）。

### AC-TC-10 — F1-C 战斗回合数公式正确性（Logic）
**GIVEN** monster_HP=30, player_ATK=14, monster_DEF=8（净伤=6）,
**WHEN** 调用 `TuningFormulas.n_rounds(30, 14, 8)`,
**THEN** 返回值 == 5（即 ceil(30/6) = 5）。

### AC-TC-11 — get_floor_tuning 返回已定义楼层的正确数据（Logic）
**GIVEN** 系统已使用合法的 5 层 TuningConfig 初始化（floor3: ATK=20, DEF=13, HP=135）,
**WHEN** 调用 `get_floor_tuning(3)`,
**THEN** 返回值不为 null；`FloorTuningRow.player_ATK_expected == 20`；`FloorTuningRow.player_DEF_expected == 13`；`FloorTuningRow.player_HP_expected == 135`。

### AC-TC-12 — get_floor_tuning 查询不存在楼层返回 null（Logic）
**GIVEN** 系统已使用仅含 floor1–floor5 的合法 TuningConfig 初始化,
**WHEN** 调用 `get_floor_tuning(99)`,
**THEN** 返回值 == null；不抛出异常，不崩溃，不返回默认值。

### AC-TC-13 — get_tuning_config 返回只读副本（写入不影响内部状态）（Logic）
**GIVEN** 系统已使用 base_ATK=6 的合法 TuningConfig 初始化；调用 `get_tuning_config()` 得到对象 `cfg`，
**WHEN** 对 `cfg` 执行 `cfg.base_ATK = 999`（模拟下游误写），随后再次调用 `get_tuning_config()` 得到 `cfg2`,
**THEN** `cfg2.base_ATK == 6`（内部状态未被修改；副本实现或守卫实现均应满足此断言）。

### AC-TC-14 — F3-A 玩家 ATK 计算取最高武器效果（Logic）
**GIVEN** 玩家已拾取两件武器：weaponA.effect_value=5，weaponB.effect_value=8；base_ATK=6,
**WHEN** 调用 `TuningFormulas.calc_player_ATK(base_ATK=6, weapon_effect_values=[5, 8])`,
**THEN** 返回值 == 14（即 6 + max(5, 8) = 14；HIGHEST_WINS 取最大值）。

### AC-TC-15 — BATTLE_ROUND_DURATION ≤ 0 触发校验失败（Logic）【补充缺口】
**GIVEN** 构造一个 TuningConfig，仅将 `BATTLE_ROUND_DURATION` 设为 0（边界值，非正），其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "BATTLE_ROUND_DURATION"`、`code == "ROUND_DURATION_NON_POSITIVE"` 的记录。

### AC-TC-16 — base_ATK < 1 触发校验失败（Logic）【补充缺口】
**GIVEN** 构造一个 TuningConfig，仅将 `base_ATK` 设为 0，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "base_ATK"`、`code == "BASE_ATK_TOO_LOW"` 的记录。（与 AC-TC-06 的「缺失」不同，此处 base_ATK 字段存在但值非法。）

### AC-TC-17 — base_MaxHP ≤ 0 触发校验失败（Logic）【补充缺口】
**GIVEN** 构造一个 TuningConfig，仅将 `base_MaxHP` 设为 0，其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "base_MaxHP"`、`code == "BASE_MAX_HP_TOO_LOW"` 的记录。（与 AC-TC-06 的 null 路径独立：存在但值为 0 属于不同的错误分支。）

### AC-TC-18 — floor_tuning_table 为空（0 行）触发校验失败（Logic）【补充缺口】
**GIVEN** 构造一个 TuningConfig，其中 `floor_tuning_table` 为空数组（长度=0），其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "floor_tuning_table"`、`code == "EMPTY_TUNING_TABLE"` 的记录。

### AC-TC-19 — floor_tuning_table 中 floor_number 重复触发校验失败（Logic）【补充缺口】
**GIVEN** 构造一个 TuningConfig，floor_tuning_table 中包含两行 floor_number 均为 1 的记录（重复），其余字段合法,
**WHEN** 调用 `validate_tuning_config(config)`,
**THEN** 返回 `is_valid == false`；`errors` 含一条 `field == "floor_number"`、`code == "DUPLICATE_FLOOR_NUMBER"` 的记录（含重复的 floor_number 值）。

## Open Questions

1. **公式函数归属（接口设计决策，影响 AC-TC-07~10、14）**
   AC 假设存在静态工具类 `TuningFormulas`。实际上公式可以：(a) 作为 TuningConfig 对象实例方法；(b) 作为独立静态函数；(c) 内联在 #5 战斗系统中。选择 (c) 会使公式无法独立测试。
   *解决方式：在架构 ADR 中锁定；推荐 (b) 独立静态函数，与 TuningConfig 数据解耦，可 headless 独立测试。*

2. **`get_tuning_config()` 返回副本 vs 守卫（只读强制方式，影响 AC-TC-13）**
   同 entity-database.md Open Q2 的模式：副本方案（`duplicate_deep()`）vs 守卫方案（set() 守卫）。
   *解决方式：与 entity-database.md、floor-layout-data.md 合并到同一架构 ADR（数据格式 + Entry 构造 + 只读强制）。*

3. **`floor_tuning_table` 的楼层覆盖范围校验**
   当前校验只检查「表内字段是否合法」，不检查「已定义的 MVP 楼层是否全部有条目」。若 floor3 没有条目，D1/D3 校验器查询返回 null 会报根因错误（已定义）——但这是被动发现，不是主动拒绝。
   *解决方式：可在 Edge Cases 增加「表必须覆盖 floor 1 到 max_floor 的全部行」的主动校验；或保持现状（D1/D3 校验器被动触发报错）。推荐主动校验，避免配置遗漏被延迟发现。*

4. **floor 2 goblin D3 余量 1 点的长期跟踪**
   当前余量极薄（1 点），强依赖关卡布局约束（shield_iron 在第一只 goblin 之前可拾取）。MVP 阶段靠人工保证；VS 容错机制（#15）落地后自动放宽。
   *追踪 owner：关卡设计师（#2 楼层关卡数据系统设计时显式标注此约束）+ #15 容错安全机制（VS 阶段实现后此约束可松弛）。*
