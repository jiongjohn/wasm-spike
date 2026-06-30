# 游戏实体数据库 (Entity Database)

> **Status**: Approved（四轮评审后修订完成，2026-06-24；首次审批已在 systems-index 确认）
> **Author**: lumen + agents
> **Last Updated**: 2026-06-24
> **Implements Pillar**: P2「算得清的确定性」— 每个实体的属性都精确已知,战斗结果完全可预演

## Overview

游戏实体数据库是《像素魔塔·无尽塔》中所有**静态游戏对象属性的唯一权威来源**。它定义了三类实体的数据结构:怪物(Monsters)、道具(Items)、钥匙(Keys)。所有需要访问「某个怪物的ATK是多少」「某件道具能恢复多少HP」「这把钥匙能开哪种门」这类问题的系统——包括确定性回合战斗、玩家属性成长、网格移动交互、钥匙门系统和掉落奖励系统——都从本数据库读取数据,自身不维护副本。

本系统是纯数据层,不包含任何游戏逻辑。数据由关卡设计师手动填写,在游戏启动时一次性加载进内存,运行期间只读。它没有可见的玩家界面,但支撑了 MVP 中 6 个系统的所有运算。

## Player Fantasy

玩家永远不会看到「数据库」的存在。但他们能感受到它的效果:走进战斗之前,伤害预演数字是精确的。钥匙开的门不会出错。药水的效果和图标描述完全一致。这种**可信赖的一致性**是「算得清的确定性」支柱的物理基础——玩家下意识地信任这个世界的规则,从而专注于策略决策而不是猜测。

换言之:这个系统做得好,玩家感受不到它的存在。做得不好(数据错误、属性不一致),玩家会立刻失去对游戏的信任。

> **可证伪的体验判据(供 QA / 玩测验证):**
> 在一次完整的 3 层试玩中,玩家**零次**遇到「图标/描述与实际效果不符」「钥匙开错门或开不了对应门」「伤害预演数字与实际结算不一致」的情况。任一出现即视为本系统未交付其 Player Fantasy。

## Detailed Design

### Core Rules

**规则 C1 — 单一权威来源**
所有实体属性只在本数据库中定义一次。其他系统通过只读接口查询,不得维护副本,不得在运行时修改任何属性值。

**规则 C2 — 三个实体类型 + 显式类型判别字段(扁平 schema)**

本数据库采用**扁平 schema**:三类实体不使用类继承(避免 GDScript 枚举无法被子类扩展的问题),而是每条 Entry 都带一个显式的 `entity_type` 判别字段,供反序列化与下游系统分发使用。

| `entity_type` | 结构 | 描述 |
|---|---|---|
| `MONSTER` | `MonsterEntry` | 出现在楼层格子上的可战斗单元 |
| `ITEM` | `ItemEntry` | 出现在楼层格子上的可拾取对象 |
| `KEY` | `KeyEntry` | 拾取后进入玩家钥匙库存,用于开门 |

> **设计决策(design-review)**:放弃「KeyEntry 是 ItemEntry 子类」的继承模型。原模型在 GDScript 中不可实现(枚举不可由子类扩展,且 `effect_value` 对钥匙无意义)。改为扁平结构 + `entity_type` 判别字段。

**规则 C3 — MonsterEntry 字段**

| 字段 | 类型 | 范围/约束 | 描述 |
|---|---|---|---|
| `entity_type` | Enum | 固定 `MONSTER` | 类型判别字段 |
| `id` | String | 唯一,snake_case | 唯一标识符(如 `slime`) |
| `display_name` | String | 非空 | 游戏内显示名称 |
| `hp` | int | **≥1** | 最大/初始生命值 |
| `atk` | int | **≥0** | 攻击力(0 为合法但须注释,见 Edge Cases) |
| `def` | int | **≥0** | 防御力 |
| `gold_drop` | int | **≥1** | 击败时掉落的固定金币量(确定性) |
| `is_boss` | bool | — | 是否为 Boss;决定金币基准(D2)与稀有掉落资格。**取代**原「`rare_drop_item_id != null` 推断 Boss」的脆弱写法 |
| `rare_drop_item_id` | String? | 仅 `is_boss=true` 时允许非 null | 首次击败时一次性掉落的 ItemEntry ID;`null` 表示无稀有掉落 |
| `floor_first_appears` | int | ≥1,**Alpha+ 才被消费** | 该怪物类型首次出现的楼层(1-based)。**MVP/VS 手工关卡不读取此字段**(楼层放置由 #2 楼层关卡数据决定);仅作为内容设计参考与未来随机生成(#20)的种子数据。运行时无消费者 |
| `sprite_id` | String | 非空 | 美术 Atlas 中的 Sprite 键名(由美术规范定义;解析机制由渲染/Atlas ADR 定义,本库视为不透明字符串) |

**规则 C4 — ItemEntry 字段**

| 字段 | 类型 | 范围/约束 | 描述 |
|---|---|---|---|
| `entity_type` | Enum | 固定 `ITEM` | 类型判别字段 |
| `id` | String | 唯一 | 唯一标识符 |
| `display_name` | String | 非空 | 游戏内显示名称 |
| `effect_type` | Enum | 见下 | 效果类型 |
| `effect_value` | int | **≥0** | 效果数值(HP 回复量 / 属性加成量 / 碎片数量) |
| `stack_rule` | Enum | `ADDITIVE` / `HIGHEST_WINS` | 同类道具叠加规则,见规则 C8 |
| `sprite_id` | String | 非空 | Atlas 中的 Sprite 键名 |

`effect_type` 枚举(**KEY 已纳入正式枚举**):
`HP_RESTORE` / `ATK_BOOST` / `DEF_BOOST` / `MAXHP_BOOST` / `FRAGMENT` / `KEY`

> `FRAGMENT` 与 `KEY` 的处理:见规则 C9(分发与跨系统拦截)。

> **跨字段联合校验(强制,堵 schema 漏洞)**:`effect_type=KEY` **仅允许**出现在 `entity_type=KEY` 的 Entry 上。`entity_type=ITEM` 且 `effect_type=KEY` 是**非法组合**——逐字段看三个值都合法(ITEM 合法、effect_value 合法、KEY 在枚举内),但组合语义非法,且会被 C9 的 `entity_type` 路由误送进 #4 玩家属性系统产生未定义行为。启动校验**必须**做此联合校验并报错(见 Edge Cases)。

**规则 C5 — KeyEntry 字段**

| 字段 | 类型 | 范围/约束 | 描述 |
|---|---|---|---|
| `entity_type` | Enum | 固定 `KEY` | 类型判别字段 |
| `id` | String | 唯一 | `key_yellow` / `key_blue` |
| `display_name` | String | 非空 | 游戏内显示名称 |
| `effect_type` | Enum | 固定 `KEY` | — |
| `effect_value` | int | 固定 `0`(未使用) | 钥匙不使用 effect_value;验证时若缺省按 0 处理,不报「字段缺失」错误 |
| `key_color` | Enum | `YELLOW` / `BLUE` | 钥匙颜色 |
| `opens_door_color` | Enum | `YELLOW` / `BLUE` | 对应可开的门颜色 |
| `sprite_id` | String | 非空 | — |

> **校验约束**:`key_color` 必须等于 `opens_door_color`(1:1 映射)。不相等的 KeyEntry 为非法数据,启动时报错(见 Edge Cases)。

**规则 C6 — 掉落规则(全确定性)**
- 击败任何怪物:立即给予 `gold_drop` 金币(**≥1**),无随机性。
- 普通怪物(`is_boss=false`)无稀有装备掉落,`rare_drop_item_id` 必须为 `null`。
- Boss(`is_boss=true`)首次击败时额外给予 `rare_drop_item_id` 道具(见下方「Boss 首次击败语义」)。
- **MVP 范围**:MVP（**3 层，固定**）**不含 Boss**。Boss 掉落规则属于 VS 范围,详见 Tuning Knobs 的「VS 数据追加」节。

> **Boss 首次击败语义属 VS 范围**:MVP 无 Boss,相关语义(整局同 `id` 只授予一次、状态由 #9 维护)不在 MVP 实现范围内,完整定义见 Tuning Knobs 的「VS 数据追加」节。MVP 实现者无需阅读或实现该逻辑。

**规则 C7 — 只读原则及其强制机制**
所有 Entry 在运行时不可修改。所有对玩家属性的改变都通过读取 Entry 数据计算后写入玩家状态,不修改 Entry 本身。

> **强制机制(交由 ADR 锁定,但本 GDD 给出硬要求)**:`@export` **不能**使字段只读——查询接口**必须**选用以下两种方案之一:
> - **副本方案**:返回深拷贝。Entry 为 `Resource` 子类时用 `duplicate_deep()`(Godot 4.5+ API);Entry 为自定义 GDScript class 或 `Dictionary` 时用 `Dictionary.duplicate(true)` 或等价的手动深拷贝。
> - **守卫方案**:所有字段配自定义 `set()` 守卫拒绝写入。**须**在 DEBUG 模式(非 Release 导出)下于守卫内调用 `push_error()` 使静默写入可见,防止 WASM Release 下数据污染完全不可观测。
>
> 二选一由数据格式 ADR 决定。原文「`@export` 只读资源」的表述作废。
> **性能要求**:`get_monster()` 等查询被战斗/预演系统高频调用(玩家每格移动可能触发)。副本方案每次分配会在 WASM 低端设备上累积帧时间压力,因此**高频查询路径应优先守卫方案**(零分配)。详见 Open Q2 ③。

**规则 C8 — 道具叠加规则(`stack_rule`)**
- `ADDITIVE`:多次拾取效果累加(如生命宝石、碎片;药水为即时消耗,不存在「持有多份」,其 `stack_rule` 字段对实现无实际约束,取 `ADDITIVE` 仅为占位,实现者不得据此为药水构建背包/叠加逻辑)。
- `HIGHEST_WINS`(原名 `ONCE`,已作废——`ONCE` 易被误读为「只能拾取一次」;隐含语义:**弱/等值装备强制从地图消失**,仅取更高值生效):装备类(剑、盾)采用**取当前已生效值与新值的最高者**,而非累加。MVP 中玩家持有一把「当前武器」与一面「当前盾」。
  - **拾取更强装备**:替换当前生效值为新值(地图道具消失)。
  - **拾取更弱或等值装备**(权威定义,供 #4 实现):道具**仍被拾取并从地图消失**,但**不改变**当前生效属性(无效果)。**不得**留在格子上形成「僵尸格子」,**不得**拒绝玩家踩入。本库向调用方返回 `effect_result=NO_EFFECT`;调用方(#4 + UX)**必须**触发玩家可感知的轻量反馈事件(具体表现由 #4 GDD 定义),**不允许**静默无反馈——轻用户的「踩格无变化」体验会与 bug 混淆。
  > 这防止 iron+steel+great 三剑叠加出 +42 ATK,从而击穿 D1 对单一 `player_ATK_expected` 的假设。`HIGHEST_WINS` — 弱/等值装备消失但只取更高值生效,返回 `NO_EFFECT`。「装备槽如何呈现替换反馈(UI 提示)」属 #4 玩家属性系统 + UX,本库仅声明 `stack_rule` 字段语义及上述拾取分支契约。

**规则 C9 — 跨系统分发与拦截(KEY / FRAGMENT)**
- 拾取分发**必须先按 `entity_type` / `effect_type` 路由**,再交给消费系统:
  - `entity_type=KEY`:由 #7 钥匙门系统处理(增加对应颜色钥匙计数),**绝不**进入 #4 玩家属性系统的 effect 分支。
  - `effect_type=FRAGMENT`:由 #14 碎片经济系统(VS)处理。**MVP 不实现 FRAGMENT 处理器**,因此 MVP 数据集与 MVP 关卡**不得包含 FRAGMENT 道具**(见 Tuning Knobs 拆表);启动校验在 MVP 构建下遇到 FRAGMENT Entry 视为越界并报错。
  - 其余 `effect_type`(HP_RESTORE/ATK_BOOST/DEF_BOOST/MAXHP_BOOST):由 #4 玩家属性系统处理。

**规则 C10 — 道具效果语义(交给 #4 实现的权威契约)**
- `MAXHP_BOOST`:**同时**抬高最大 HP 上限**并**把当前 HP 恢复到新上限(即顺带回满)。服务 Pillar 1「看得见的成长」——拾取生命宝石应立刻有可见正反馈。
  > **`stack_rule=ADDITIVE` 的失控边界(注)**:`crystal_life` 是 ADDITIVE,每拾取一颗 MaxHP +50 且回满。MVP 数据集**仅含一颗生命宝石**(放置由 #2 控制),不触发堆叠失控。但 ADDITIVE 意味着上限增长完全由关卡放置密度驱动,且玩家实际 HP 会偏离 D3 假设的 `player_HP_expected` 中位值。**VS 引入第二颗及以上时,须重估 D3 的中位假设是否仍成立**(玩家 HP 超标会让 D3 对怪物 ATK 的约束变得过松)。
- `HP_RESTORE`:回复量**封顶于最大 HP**,不允许溢出(no overheal)。`min(current_hp + effect_value, max_hp)`。
- `ATK_BOOST` / `DEF_BOOST`:按 `stack_rule` 应用(`HIGHEST_WINS`:取当前生效值与新值的最高者,见规则 C8)。

---

### States and Transitions

本系统无运行时状态变化。所有数据在**游戏启动时加载一次**,此后为只读常量。

加载流程:
1. 游戏启动 → 读取数据文件(格式见 Open Questions,交由 ADR)
2. **两遍加载**:
   - **第一遍**:载入全部 Entry 进表,同时检测**重复 ID**(AC-10)——必须在建表过程中捕获,不可延至第二遍(否则后者静默覆盖前者后第二遍永远看不到重复)。
   - **第二遍**:做跨引用与约束校验(见 Edge Cases)。两遍是为避免「MonsterEntry 引用的 ItemEntry 尚未载入」导致的误报。
3. 校验全部通过 → 数据库就绪,供所有系统查询
4. 校验失败 → 不进入游戏(见 Edge Cases 的失败处理)

---

### Interactions with Other Systems

| 下游系统 | 查询内容 | 接口方向 |
|---|---|---|
| #4 玩家属性与成长 | 道具 `effect_type`、`effect_value`、`stack_rule` | 读取 `ItemEntry` |
| #5 确定性回合战斗 | 怪物 `hp`、`atk`、`def` | 读取 `MonsterEntry` |
| #6 网格移动与交互 | `entity_type` 判别格子类型 | 读取 Entry `entity_type` |
| #7 钥匙与门 | `KeyEntry.opens_door_color` | 读取 `KeyEntry` |
| #8 掉落奖励 | 怪物 `gold_drop`、`is_boss`、`rare_drop_item_id` | 读取 `MonsterEntry` |
| #14 碎片经济(VS) | `effect_type=FRAGMENT` 道具的 `effect_value` | 读取 `ItemEntry` |
| #16 商店(VS) | 道具的全部字段(商品列表) | 读取 `ItemEntry` |

## Formulas

> 本节包含**数据合法性约束公式**,供关卡设计师在设定怪物属性时验证。D1/D3 是启动校验强制规则;D2 是非强制参考工具。

---

### 公式 D1 — DEF 上限约束(怪物不可不死磨)

`min_damage_required = ceil(monster_HP / N_max)`

**约束条件:** `max(1, player_ATK_expected - monster_DEF) ≥ min_damage_required`

确保玩家能在 ≤ `N_max` 回合内击杀任意怪物,防止「1 伤死磨」退化。

**变量表:**

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `player_ATK_expected` | int | **≥10**(启动前须校验) | 对应楼层玩家 ATK 中位预期(由 #3 调参配置提供) |
| `monster_DEF` | int | ≥0 | 待验证的 `def` |
| `monster_HP` | int | ≥1 | 待验证的 `hp` |
| `N_max` | int | **5–20(启动须校验落在此范围)** | 击杀最大回合数上限,当前值 10 |

**已知边界(design-review 补充,均需校验覆盖):**
- **HP=1 漏洞**:`ceil(1/N_max)=1`,`max(1,…)≥1` 恒真 → HP=1 怪物无论 DEF 多大都通过 D1。因此对 `monster_DEF` 增设独立上限校验:`monster_DEF < player_ATK_expected`(否则净伤被钳到 1,DEF 形同虚设),与 D1 同时检查。
- **N_max 越界**:若 N_max 不在 5–20,启动校验直接报「N_max 越界」单条错误,**不要**逐怪报 D1 违反(避免误导根因)。
- **player_ATK_expected 越界**:D1 运行前先校验 `player_ATK_expected ≥ 10`;否则报「玩家 ATK 预期越界」而非逐怪 D1 违反。

**示例验证(MVP 怪物,N_max=10):**

| 怪物 | 楼层 | 玩家预期ATK | HP | DEF | 净伤 | 最低要求 | 结果 |
|---|---|---|---|---|---|---|---|
| 史莱姆 | 1–2层 | 10 | 20 | 2 | 8 | 2 | ✅ 通过 |
| 哥布林 | 2–3层（MVP；VS+ 延至更高层）| 20 | 50 | 5 | 15 | 5 | ✅ 通过（此行以 floor3 player_ATK=20 验证；floor2 goblin 另行见 game-tuning-config T6 D1/D3 全量表）|

**约束违反时的调整策略(按副作用由小到大):** 降 DEF → 降 HP → 提该楼层玩家 ATK 预期。不推荐改 N_max 规避单怪违反。

---

### 公式 D3 — 怪物 ATK 上限约束(玩家不被秒杀,防「死墙」)【新增】

> design-review 识别:D1 只保证「打得死怪」,不保证「扛得住怪」。纯确定性 + MVP 无容错机制(#15 容错安全在 VS)下,过高的怪物 ATK 是「死墙」的直接成因,违背概念文档对轻用户的承诺。新增 D3 约束怪物对玩家的单局伤害。

`player_damage_taken_per_round = max(0, monster_ATK - player_DEF_expected)`

`total_damage_to_kill = player_damage_taken_per_round × N_rounds_to_kill`

其中 `N_rounds_to_kill = ceil(monster_HP / max(1, player_ATK_expected - monster_DEF))`

**约束条件:** `total_damage_to_kill ≤ HP_BUDGET_RATIO × player_HP_expected(floor)`

即:在推荐战力下击杀该怪所受总伤,不得超过玩家该楼层预期 HP 的一个安全比例。

**变量表:**

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `monster_ATK` | int | ≥0 | 待验证的 `atk` |
| `player_DEF_expected` | int | ≥0 | 对应楼层玩家 DEF 中位预期(#3 提供) |
| `player_HP_expected` | int | **≥1**(启动前校验) | 对应楼层玩家 HP 中位预期(#3 提供) |
| `HP_BUDGET_RATIO` | float | **0.05–1.0**,**默认 0.35** | 单只怪允许消耗的玩家血量上限占比(调参旋钮)。下界 0.05 为强制约束（< 0.05 报根因错误，见 game-tuning-config Edge Cases） |
| `N_rounds_to_kill` | int | ≥1 | 击杀所需回合数(复用 D1 的净伤) |

**输出:** 布尔(通过/违反)。违反时报错并附 `total_damage_to_kill` 与预算上限。

> 注:`HP_BUDGET_RATIO`、`player_*_expected` 的正式值待 #3 调参配置确定;在此之前 D3 用估算值跑校验,#3 落地后须重跑(见 Open Questions)。

> **重要边界 — 「过 D3 ≠ 层安全」**:D3 是**逐怪**约束,只保证「单只怪不会吃掉超过 `HP_BUDGET_RATIO` 的血」。它**不**建模同层多怪的累积消耗——若一层放置 3 只各消耗 35% HP 的怪,玩家在推荐战力下打到第 3 只就会耗尽血量(105%)。因此:**关卡设计师不得把「全部怪物通过 D3」当作「该层可通关」的充分条件**。MVP 阶段由「逐怪 D3 + 关卡设计师人工核验单层累积伤害」共同承担层安全;完整的层并发约束(`MAX_CONCURRENT_THREAT` 之类)随 **#2 楼层关卡数据系统**落地后定义,届时 D3 仅作为其输入之一。
>
> **设计取向裁定(creative-director)**:D3 保留为 **Foundation 层的死墙兜底**——服务抖音轻用户 + MVP 无容错机制。死墙防护是数据层的职责,不外推给「战斗预演 UI 劝退玩家」。对「一击必杀/高风险-高回报」怪物的豁免机制(如 `is_optional_encounter` 标记免受 D3 约束)**留待 VS 阶段**评估,MVP 不引入。

---

### 公式 D2 — 金币价值参考公式(非强制)

`difficulty_score = (monster_HP / player_HP_expected) + (monster_ATK / player_ATK_expected) + (monster_DEF / player_ATK_expected)`

`gold_drop_suggested = max(1, round(gold_base × difficulty_score))`

**输入保护(design-review 补充):**
- D2 调用前必须保证 `player_HP_expected ≥ 1` 且 `player_ATK_expected ≥ 1`,否则除零。两者由 #3 提供;若取到 0 或负,D2 不执行并报「D2 输入越界」。
- **下限钳制顺序**:GDScript `round(0.4)=0`,故 `max(1, …)` 必须**套在 `round()` 外层**(先 round 再钳 1),不可先钳。
- D2 仅供**离线/编辑期**关卡设计工具调用,**不在运行时执行**;若未来需运行时(如商店动态定价),须重新评估除零风险。

**变量表:**

| 变量 | 类型 | 范围 | 描述 |
|---|---|---|---|
| `player_HP_expected` | int | ≥1 | 玩家该楼层 HP 中位预期 |
| `player_ATK_expected` | int | ≥1 | 玩家该楼层 ATK 中位预期 |
| `gold_base` | int | 普通怪=10,Boss=25(由 `is_boss` 选择) | 调参基准 |

**奖励溢价系数参考:** `reward_premium = actual_gold_drop / gold_drop_suggested` — 普通怪目标 0.5–0.8,Boss 目标 1.3–2.0。

## Edge Cases

**数据合法性(启动校验,违反则不进入游戏并报 Entry ID + 字段):**
- **`monster_HP ≤ 0`(含 0 与负数)**:非法,报错。
- **`monster_DEF ≥ player_ATK_expected`**:净伤被钳到 1,触发 D1/DEF 上限违反,报错(不允许上线)。
- **`gold_drop < 1`**:非法,报错。(原「gold_drop=0 合法陷阱怪」边界**已移除**——MVP 无消费者,设计决策统一为 ≥1。)
- **`monster_ATK = 0`**:合法(如诱饵/装饰型),但数据文件须有注释说明;无注释的 0 ATK 触发警告。
- **`effect_value < 0`**:非法(负回血/负加成无定义语义),报错。
- **`rare_drop_item_id` 指向不存在的 ItemEntry**:非法,报引用完整性错误(两遍加载,第二遍校验)。
- **`is_boss=false` 却设了 `rare_drop_item_id`**:非法(普通怪不得有稀有掉落),报错。
- **`key_color ≠ opens_door_color`**:非法,报错。
- **重复 `id`(同 `entity_type` 内)**:非法,报「重复 ID」错误,不允许后者静默覆盖前者。**跨 `entity_type` 的同名 ID**(如一个 MONSTER 和一个 ITEM 同名)技术上因查询按类型分表可正常工作,但**强烈建议**全局唯一——人工维护时难以区分,未来非类型化查询路径会产生歧义。
- **MVP 构建中出现 `effect_type=FRAGMENT`**:越界,报错(FRAGMENT 处理器在 VS)。
- **`entity_type=ITEM` 且 `effect_type=KEY`**:非法组合(KEY 效果只能挂在 `entity_type=KEY` 上),报「entity_type×effect_type 非法组合」错误,含 Entry ID 与两个字段值。逐字段校验通过但联合非法,见规则 C4 联合校验。
- **`N_max` 不在 5–20 / `player_ATK_expected < 10` / `player_HP_expected < 1`**:校验输入越界,报单条根因错误。
- **数据文件格式损坏或必填字段缺失**:报缺失字段 + Entry ID,**不降级、不填默认值**,不进入游戏。

**运行时语义(非数据校验):**
- **`effect_value = 0`**:合法但无效果(道具可拾取、什么都不发生)。不推荐设计此类道具。
- **HP_RESTORE 溢出**:回复封顶于最大 HP(规则 C10),不溢出。
- **MAXHP_BOOST**:抬上限并回满当前 HP(规则 C10)。
- **查询不存在的 ID**:返回 `null`(若实体类型为引用类型/Resource);调用方负责处理 null,不抛异常。

**WASM / 抖音平台(godot-specialist 补充):**
- 数据文件**必须打包进 `res://`**(随 PCK),**不得**放 `user://`——WASM 上 `user://` 映射 IndexedDB,首次启动可能返回空,导致校验「无 Entry → 无错误」的灾难性假通过。
- 校验失败的「不进入游戏」在 WASM/小游戏容器内**不能依赖 `get_tree().quit()`**(可能静默冻结无反馈),须显示一个可见的错误屏节点。

## Dependencies

### 上游依赖
**无。** 本系统是 Foundation 层。唯一外部依赖是运行平台(Godot 资源加载),属技术实现,不属游戏设计依赖。

### 下游依赖(依赖本系统的)

| 系统 | 依赖性质 | 读取字段 |
|---|---|---|
| #2 楼层关卡数据系统 | 硬依赖 | F6 ENTITY 引用完整性、F-K1 钥匙门颜色平衡、F-T1 tier 兼容校验均需 EntityDB 可查（启动顺序：EntityDB 先于 FloorDB）|
| #4 玩家属性与成长 | 硬依赖 | `ItemEntry.effect_type`, `effect_value`, `stack_rule` |
| #5 确定性回合战斗 | 硬依赖 | `MonsterEntry.hp`, `atk`, `def` |
| #6 网格移动与交互 | 硬依赖 | Entry `entity_type` |
| #7 钥匙与门 | 硬依赖 | `KeyEntry.opens_door_color`, `key_color` |
| #8 掉落奖励 | 硬依赖 | `MonsterEntry.gold_drop`, `is_boss`, `rare_drop_item_id` |
| #9 楼层进程/游戏状态 | 协作 | 持有 Boss「已授予稀有掉落」状态(`boss_id → bool`);本库定义语义,#9 存状态 |
| #14 碎片经济(VS) | 硬依赖 | `effect_type=FRAGMENT` 道具的 `effect_value` |
| #16 商店(VS) | 硬依赖 | `ItemEntry` 全部字段 |

> **双向性提醒**:按设计文档规范,上述每个下游系统的 GDD 须在其 Dependencies 节反向声明对本库的依赖。目前下游 GDD 均未编写;它们成文时须补上反向引用。

### 接口约定
- 所有查询为只读;返回数据副本或带 `set()` 守卫(规则 C7)。
- **三个按类型查询函数**(ID 为 String 参数,不存在的 ID 返回 `null`,调用方负责处理,不抛异常):
  - `EntityDB.get_monster(id: String) -> MonsterEntry?`——仅返回 `entity_type=MONSTER` 的条目
  - `EntityDB.get_item(id: String) -> ItemEntry?`——仅返回 `entity_type=ITEM` 的条目,**不含** `entity_type=KEY`
  - `EntityDB.get_key(id: String) -> KeyEntry?`——仅返回 `entity_type=KEY` 的条目
- 用 ID 字符串查询时,传入错误类型的函数将返回 `null`(如 `get_monster("key_yellow")` → null、`get_item("key_yellow")` → null、`get_key("slime")` → null)。
- 具体函数签名 / 数据格式 / 只读强制方式由 Architecture 阶段 ADR 确定。

## Tuning Knobs

所有调参值在数据文件中直接修改,无需改代码。

### 全局参数

| 参数 | 当前值 | 安全范围 | 影响 | 极端值行为 |
|---|---|---|---|---|
| `N_max` | **10** | 5–20 | D1 严格程度 | <5:DEF 设计空间极小; >20:磨局风险上升 |
| `HP_BUDGET_RATIO` | **0.35** | 0.0–1.0 | D3 单怪血量预算 | 过高:死墙风险; 过低:战斗无威胁 |
| `gold_base_normal` | **10** | 5–20 | 普通怪金币基准 | — |
| `gold_base_boss` | **25** | 15–50 | Boss 金币基准 | — |

### MVP 怪物数据表（3 层固定，**无 Boss**）

> **设计取向注**:MVP 仅含 2 种怪物为**最小核心循环验证集**——目标是验证「确定性战斗 + 数值成长反馈的核心循环」,减少变量以获得干净的玩测信号。P4「每层都有新发现」属 VS 阶段目标,届时随 VS 数据追加节同步扩充怪物种类。
> 已通过 D1 验证(N_max=10)。D3 待 #3 调参曲线确定后重跑。

| entity_type | id | 名称 | hp | atk | def | gold_drop | is_boss | rare_drop_item_id | floor_first_appears |
|---|---|---|---|---|---|---|---|---|---|
| MONSTER | `slime` | 史莱姆 | 20 | 8 | 2 | 5 | false | null | 1 |
| MONSTER | `goblin` | 哥布林 | 50 | 18 | 5 | 10 | false | null | 2 |

### MVP 道具数据表(**无 FRAGMENT**)

| entity_type | id | 名称 | effect_type | effect_value | stack_rule |
|---|---|---|---|---|---|
| ITEM | `potion_small` | 小回血药 | HP_RESTORE | 40 | ADDITIVE |
| ITEM | `potion_large` | 大回血药 | HP_RESTORE | 80 | ADDITIVE |
| ITEM | `sword_iron` | 铁剑 | ATK_BOOST | 8 | HIGHEST_WINS |
| ITEM | `sword_steel` | 精钢剑 | ATK_BOOST | 14 | HIGHEST_WINS |
| ITEM | `shield_wood` | 木盾 | DEF_BOOST | 5 | HIGHEST_WINS |
| ITEM | `shield_iron` | 铁盾 | DEF_BOOST | 10 | HIGHEST_WINS |
| ITEM | `crystal_life` | 生命宝石 | MAXHP_BOOST | 50 | ADDITIVE |
| KEY | `key_yellow` | 黄钥匙 | KEY | 0 | — |
| KEY | `key_blue` | 蓝钥匙 | KEY | 0 | — |

### VS 数据追加(Vertical Slice 阶段引入,**不在 MVP**)

> 以下实体及其关联逻辑(Boss 首次击败、稀有掉落、碎片经济)在 VS 阶段才启用。在此之前不得进入 MVP 数据集或 MVP 关卡。引入时须用 #3 的正式玩家曲线重跑 D1/D3。

**Boss 首次击败语义(权威定义,VS 范围)**
- 「首次击败」的判定范围为**整局游戏的同一 `id`**:同一 boss `id` 在整局内只授予一次 `rare_drop_item_id`,无论该 boss 出现在一层还是多层、一个实例还是多个实例。
- **「多实例同 Boss」假设须在 VS 设计时复审**:经典魔塔式游戏中 Boss 通常每层唯一。若本游戏最终不存在「同一 Boss 多层/多实例」的场景,本条可简化为「每个 boss `id` 击败即授予一次」。VS 阶段定 Boss 出现规则时一并确认。
- 「已授予稀有掉落」状态由 **#9 楼层进程/游戏状态系统**以「`boss_id → bool` 已掉落标记」的形式维护(本数据库不持有运行时状态)。本 GDD 仅定义授予次数语义;状态存储接口由 #9 GDD 约定。

| entity_type | id | 名称 | hp | atk | def | gold_drop | is_boss | rare_drop_item_id | floor |
|---|---|---|---|---|---|---|---|---|---|
| MONSTER | `skeleton` | 骷髅兵 | 90 | 28 | 10 | 20 | false | null | 9 |
| MONSTER | `beast_king` | Boss 兽王 | 180 | 42 | 15 | 100 | true | `sword_great` | 15 |

| entity_type | id | 名称 | effect_type | effect_value | stack_rule | 备注 |
|---|---|---|---|---|---|---|
| ITEM | `sword_great` | 巨剑 | ATK_BOOST | 20 | HIGHEST_WINS | Boss 稀有掉落。**注意**:+20 相对 iron+steel 取最高(+14)是一次显著跃迁;VS 阶段须验证它符合「滚雪球」而非「断层式」成长(Pillar 1) |
| ITEM | `fragment` | 钥匙碎片 | FRAGMENT | 1 | ADDITIVE | 由 #14 碎片经济处理 |

## Visual/Audio Requirements

N/A — 本系统为无界面纯数据层,自身无视觉/音频产出。各实体的 `sprite_id` 指向美术资产,其解析由渲染/Atlas ADR 与美术规范负责,不属本系统。

## UI Requirements

N/A — 本系统无玩家界面。下游 HUD(#12)、商店(#16)等消费本库数据并负责各自 UI。

## Acceptance Criteria

> **断言契约(强制,解决「不进入主界面」不可断言问题)**:校验逻辑**必须**封装为一个进程内可调用、返回结构化结果的函数,签名为:
>
> ```
> validate_database(entries: Array, config: ValidationConfig, build_scope: String = "MVP") -> ValidationResult
> ```
>
> `ValidationConfig` 携带 D1/D3 所需全部 player 期望值(**依赖注入**,使测试可精确控制,无需依赖全局 Autoload):
> - `player_atk_expected: int`(D1 + D3;单独校验 `≥ 10`,否则报根因错误而非逐怪 D1 违反)
> - `player_hp_expected: int`(D3;单独校验 `≥ 1`)
> - `player_def_expected: int`(D3;`≥ 0`)
> - `n_max: int`(D1;单独校验落在 5–20,当前值 10)
> - `hp_budget_ratio: float`(D3;安全范围 **0.05–1.0**,默认 0.35;`< 0.05` 视为配置错误报根因警告)
>
> **标准测试配置(`std_config`)**:不触发 D1/D3 误报的通用测试入参;适用于测试其他校验规则(HP ≤ 0、缺失字段、重复 ID 等)的 AC:`player_atk_expected=20, player_hp_expected=100, player_def_expected=5, n_max=10, hp_budget_ratio=0.35`
>
> `ValidationResult` 至少含:
> - `is_valid: bool`
> - `errors: Array`(每条 error 含 `entry_id`、`field`、`code`、`message`)
> - `computed: Dictionary`(按 `entry_id` 存储校验中产生的关键中间值,如 D1 的 `damage_per_round`/`min_damage_required`,D3 的 `total_damage_to_kill`/`hp_budget`;通过的 entry 同样记录,供 AC-02 断言算法精度)**所有伤害/预算类中间值在存入 `computed` 前须 `int()` 化**(D3 的 `hp_budget = int(hp_budget_ratio * player_hp_expected)`,向下取整),避免浮点比较歧义。
>
> 所有 AC **断言这个返回对象**(`is_valid==false`、`errors` 含特定 code/entry_id,或 `computed[entry_id]` 含特定整数值),**绝不**断言「游戏是否进入主界面」这类渲染/场景树副作用——后者在 GUT/headless/WASM 下不可断言(quit() 被禁、错误屏是 headless 不渲染的 Control 节点)。「校验失败 → 不进入游戏 + 显示错误屏」是**运行时装配契约**,由 Integration 测试在有场景树时验证一次即可,不作为每条数据校验 AC 的断言目标。
>
> 故事类型标注:多数为 **Logic**(直接调 `validate_database(entries, config, build_scope)` 或查询接口,无需场景树);标 *(Integration)* 者验证「校验失败导致运行时不进入游戏」的装配,需要场景树夹具。

> **Anti-Pillars scope-gate 豁免(creative-director 裁定)**:systems-index 要求每个 GDD 的 AC 含三项 scope-gate 检查(战斗无随机数 / 不增主循环步数 / 广告玩家主动触发)。这三项属**系统级跨 GDD 校验**,对纯数据层(本库不含任何战斗结算、循环步骤或广告触发逻辑)trivially true。经创意总监裁定:**本 Foundation 数据库 GDD 豁免这三项 AC**,由 systems-index 或后续合规/集成 GDD 统一承载。此豁免在本节显式标注,避免未来 audit 反复触发。

### AC-01 数据加载成功(Logic)
**GIVEN** 数据文件包含完整、合法的 MVP MonsterEntry / ItemEntry / KeyEntry 记录,
**WHEN** 游戏启动并执行数据库初始化,
**THEN** 初始化函数返回的校验状态为 PASS;`EntityDB.get_monster("slime")` 返回非 null MonsterEntry,其 `hp==20`、`gold_drop==5`、`is_boss==false`;初始化期间引擎错误日志通道(severity ≥ ERROR)写入 **0** 条记录。

### AC-02 D1 校验通过——返回可观测结果(Logic)
**GIVEN** 测试 MonsterEntry `test_skeleton_valid`(hp=90, def=10),
**WHEN** 调用 `validate_database([test_skeleton_valid_entry], config, "MVP")`,其中 `config.player_atk_expected=35, config.n_max=10`(其余 config 字段使用 std_config 默认值),
**THEN** 返回 `is_valid==true`(整体通过);`errors` 中不含 `entry_id=="test_skeleton_valid"` 的记录;`computed["test_skeleton_valid"]["damage_per_round"]==25` 且 `computed["test_skeleton_valid"]["min_damage_required"]==9`(整数相等断言,`25 ≥ 9` 验证通过);引擎错误日志无 D1 相关 WARNING 及以上。

### AC-03 D1 校验违反——非法怪物数据(Logic)
**GIVEN** 测试 MonsterEntry `test_tank`(hp=90, def=34),
**WHEN** 调用 `validate_database([test_tank_entry], config)`,其中 `config.player_atk_expected=35, config.n_max=10`(其余字段使用 std_config 默认值),
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_tank"`、`code=="D1_VIOLATION"` 的记录,其 `message` 含计算结果(`damage_per_round=1 < min_damage_required=9`)。

### AC-04 怪物 ATK 上限(D3)违反报错(Logic)【新增】
**GIVEN** 测试 MonsterEntry `test_glasscannon`(hp=50, atk=200, def=0),
**WHEN** 调用 `validate_database([test_glasscannon_entry], config, "MVP")`,其中 `config.player_atk_expected=20, config.player_hp_expected=100, config.player_def_expected=0, config.n_max=10, config.hp_budget_ratio=0.35`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_glasscannon"`、`code=="D3_VIOLATION"` 的记录;`computed["test_glasscannon"]["total_damage_to_kill"]==600` 且 `computed["test_glasscannon"]["hp_budget"]==35`(整数相等断言,`600 > 35` 验证违反)。

### AC-05 实体数据查询正确性(Logic)
**GIVEN** 数据库已加载标准 MVP 数据,
**WHEN** 调用 `EntityDB.get_monster("slime")`,
**THEN** 返回 MonsterEntry 的 `gold_drop==5`、`is_boss==false`、`rare_drop_item_id==null`、`entity_type==MONSTER`。

### AC-06 只读原则——防数据库污染(Logic)
**GIVEN** 数据库已加载,史莱姆 `hp` 初始值 20,
**WHEN** 第一次查询取得对象 A = `EntityDB.get_monster("slime")`,**尝试**对其写入 `A.hp = 999`(模拟下游误写),随后发起一次**全新**查询取得对象 B = `EntityDB.get_monster("slime")`,
**THEN** `B.hp == 20`。
> **为何能区分有/无保护**:若实现无保护(查询返回内部存储的共享可变引用),则 `A.hp=999` 会污染存储,B 读到 999,断言失败——测试**捕获**无保护情形。若实现为副本(A 是独立副本)或 set() 守卫(写入被拒/忽略),B 仍为 20,断言通过。本 AC 对两种合法实现均成立,且对「无保护」必失败。
> **补充(守卫实现专属)**:若 ADR 选 set() 守卫方案,须额外断言 `A.hp` 在尝试写入后仍 `== 20`(写入被守卫拒绝/忽略);此子断言在副本实现下不适用,由实现方案确定后在测试中分支。

### AC-07 monster_HP ≤ 0 报错(含 0 与负数)(Logic)
**GIVEN** 测试数据含 MonsterEntry `test_zero_hp`(hp=0)与 `test_neg_hp`(hp=-1),
**WHEN** 调用 `validate_database([test_zero_hp_entry, test_neg_hp_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含两条记录,`entry_id` 分别为 `test_zero_hp`/`test_neg_hp`,二者 `field=="hp"`、`code=="HP_NONPOSITIVE"`。

### AC-08 rare_drop_item_id 引用不存在道具(Logic)
**GIVEN** 测试 MonsterEntry `test_boss`(is_boss=true, rare_drop_item_id="nonexistent_id"),ItemEntry 表中无该 ID,
**WHEN** 调用 `validate_database([test_boss_entry], std_config)`(执行两遍加载的第二遍跨引用校验),
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_boss"`、`code=="DANGLING_REF"` 的记录,其 `message` 含无效引用 `nonexistent_id`。

### AC-09 必填字段缺失报错(Logic)
**GIVEN** 数据文件格式为 JSON(见 Open Q2 硬约束),测试 MonsterEntry `test_missing_atk` 缺少必填字段 `atk`,
**WHEN** 调用 `validate_database([test_missing_atk_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_missing_atk"`、`field=="atk"`、`code=="MISSING_FIELD"` 的记录;**不填默认值、不降级**。
> **格式约束依赖**:本 AC 要求「字段缺失」可被检测。`.tres` 格式在反序列化时会对缺失 `@export` 字段静默填入默认值,无法区分「缺失」与「值=默认」,**故本 AC 在 .tres 下不可满足**。数据格式必须为 JSON(或其他能区分字段缺失的格式),见 Open Q2。

### AC-10 重复 ID 报错(Logic)【新增】
**GIVEN** 测试数据含两条 `entity_type=MONSTER` 且 `id=test_dup` 的记录,
**WHEN** 调用 `validate_database([dup_entry_1, dup_entry_2], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `code=="DUPLICATE_ID"`、`entry_id=="test_dup"` 的记录;后者不静默覆盖前者(校验在覆盖前即捕获)。

### AC-11 查询不存在 ID 返回 null(Logic)【新增】
**GIVEN** 数据库已加载标准数据,
**WHEN** 调用 `EntityDB.get_monster("nonexistent_id_xyz")`,
**THEN** 返回 `null`;不抛异常、不写错误日志。

### AC-12 KeyEntry 类型与字段正确(Logic)【新增】
**GIVEN** 标准数据含 `key_yellow`(key_color=YELLOW, opens_door_color=YELLOW),
**WHEN** 调用 `EntityDB.get_key("key_yellow")`,
**THEN** 返回对象 `entity_type==KEY`、`effect_type==KEY`、`key_color==YELLOW`、`opens_door_color==YELLOW`;调用 `EntityDB.get_monster("key_yellow")` 返回 null;调用 `EntityDB.get_item("key_yellow")` 返回 null(get_item 仅返回 entity_type=ITEM 的条目,不含 KEY)。

### AC-13 key_color ≠ opens_door_color 报错(Logic)【新增】
**GIVEN** 测试 KeyEntry `test_badkey`(key_color=YELLOW, opens_door_color=BLUE),
**WHEN** 调用 `validate_database([test_badkey_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_badkey"`、`code=="KEY_COLOR_MISMATCH"` 的记录。

### AC-14 MVP 构建拒绝 FRAGMENT 实体(Logic)【新增】
**GIVEN** 数据集含一条 `effect_type=FRAGMENT` 的 ItemEntry `test_fragment`,
**WHEN** 调用 `validate_database([test_fragment_entry], std_config, "MVP")`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_fragment"`、`code=="FRAGMENT_OUT_OF_SCOPE"` 的记录(FRAGMENT 处理器在 VS)。

### AC-15 DEF 独立上限校验(Logic)【新增 / BUG-4】
**GIVEN** 测试 MonsterEntry `test_highdef`(hp=20, def=12, atk=5),
**WHEN** 调用 `validate_database([test_highdef_entry], config)`,其中 `config.player_atk_expected=10, config.n_max=10`(其余字段使用 std_config 默认值;故 `monster_DEF=12 ≥ player_atk_expected=10`,净伤被钳到 1),
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_highdef"`、`field=="def"`、`code=="DEF_EXCEEDS_ATK"` 的记录。此校验独立于 D1 回合数校验(见 Formulas D1「HP=1 漏洞」补充)。

### AC-16 普通怪不得有稀有掉落(Logic)【新增 / BUG-5】
**GIVEN** 测试 MonsterEntry `test_fakeboss`(is_boss=false, rare_drop_item_id="sword_iron"),
**WHEN** 调用 `validate_database([test_fakeboss_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_fakeboss"`、`code=="NONBOSS_RARE_DROP"` 的记录(普通怪 `rare_drop_item_id` 必须为 null)。

### AC-17 effect_value < 0 报错(Logic)【新增 / BUG-6】
**GIVEN** 测试 ItemEntry `test_negval`(effect_type=HP_RESTORE, effect_value=-10),
**WHEN** 调用 `validate_database([test_negval_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_negval"`、`field=="effect_value"`、`code=="NEGATIVE_EFFECT_VALUE"` 的记录。

### AC-18 entity_type×effect_type 非法组合(Logic)【新增 / schema 漏洞】
**GIVEN** 测试 ItemEntry `test_itemkey`(entity_type=ITEM, effect_type=KEY, effect_value=0),
**WHEN** 调用 `validate_database([test_itemkey_entry], std_config)`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_itemkey"`、`code=="ILLEGAL_TYPE_EFFECT_COMBO"` 的记录(逐字段合法但组合非法,见规则 C4 联合校验)。

### AC-19 校验失败→运行时不进入游戏(Integration)【装配契约】
**GIVEN** 一份含至少一条非法 Entry 的数据集,使 `validate_database(entries, std_config)` 返回 `is_valid==false`,
**WHEN** 游戏运行时初始化序列消费该结果,
**THEN** 不切换到主游戏场景;且(WASM/小游戏目标下)向场景树添加可见错误屏节点(纯代码内联构建,见 Edge Cases WASM 节),不依赖 `get_tree().quit()`。
> 本 AC 是**唯一**断言「不进入游戏」装配的测试,需场景树夹具;数据层校验逻辑的正确性由 AC-03/04/07~10/13~18/20 在无场景树下覆盖。

### AC-20 gold_drop < 1 报错(Logic)【新增】
**GIVEN** 测试 MonsterEntry `test_zerogold`(gold_drop=0),
**WHEN** 调用 `validate_database([test_zerogold_entry], std_config, "MVP")`,
**THEN** 返回 `is_valid==false`;`errors` 含一条 `entry_id=="test_zerogold"`、`field=="gold_drop"`、`code=="INVALID_GOLD_DROP"` 的记录。

## Open Questions

1. **玩家成长曲线待定 → D1/D3 验证需重跑**
   当前怪物验证使用估算的玩家预期值。待 #3 游戏调参配置确定楼层 ATK/DEF/HP 中位曲线及 `HP_BUDGET_RATIO` 后,须对照 D1 与 **D3** 逐一重跑全部 MonsterEntry。
   *解决方式:#3 设计时同步提供「玩家各楼层预期 ATK/DEF/HP 中位表」。*

2. **数据文件格式 + Entry 构造 + 只读强制 + WASM 加载(单一 ADR)**
   本 GDD 仅定义数据结构与语义。以下技术决策**耦合**,须在一个 ADR 内一并锁定。其中已有两条被 design-review 升级为**硬约束**(ADR 不得违反),其余为 ADR 选择项:
   - ① **(硬约束)数据格式必须为 JSON**(或其他能区分「字段缺失」与「字段=默认值」的格式):`.tres` 反序列化会对缺失 `@export` 字段静默填默认值,**使 AC-09 不可满足**,故**禁止 .tres** 作为 Entry 数据文件格式。
   - ② Entry 构造方式(Resource 子类 / 内部 class / Dictionary)为 ADR 选择项。**注意:本 GDD 采用扁平 schema,放弃继承(规则 C2)——因此 `@abstract` 基类(必然引入子类继承)不适用于数据 Entry 类。** 若 ADR 想用 `@abstract`,仅可用于「查询接口层」(如 `EntityDB` 服务的抽象),与数据 Entry 类无关。原「建议用 @abstract 组织实体类型」的表述作废。
   - ③ **(硬约束)只读强制方式须考虑性能**:高频查询路径应优先守卫方案(零分配),见规则 C7。Entry 类型(Resource 子类 / 自定义 class / Dictionary)决定深拷贝 API:Resource 用 `duplicate_deep()`(Godot 4.5+ API);Dictionary/class 用 `Dictionary.duplicate(true)` 或等价方法。必须在 ADR 中明确 Entry 类型与深拷贝方案的对应关系。
   - ④ WASM 上数据放 `res://`(随 PCK);校验失败的错误屏须**纯代码内联构建**(不依赖任何 `.tscn` 或数据文件,避免「错误屏自身加载失败」的循环依赖)。错误屏机制在 Douyin 适配器(基线 ~4.5,4.6.3 待实测)上**待验证**。
   - ⑤ **(注意)JSON 整数字段 float 化**:Godot 4.x 的 `JSON.parse_string()` 在某些情况下会将整数 JSON 值(如 `"hp": 20`)解析为 `float`(20.0)。Entry 字段赋值须显式 `int()` 转换,防止强类型赋值时出现类型不匹配错误。4.6.3 具体行为待实测确认。
   *解决方式:架构阶段(/create-architecture 后)写一条覆盖以上五点的 ADR;ADR 须显式记录「要求 Godot 4.5+」(`duplicate_deep`、`@abstract` 均为 4.5+ 特性)。*

3. **Alpha 以后的新怪物/道具扩展流程 + schema 版本兼容**
   随层数增加(Alpha+)如何系统性新增内容并维护 D1/D3 一致性;以及「启动即崩、不降级」策略与未来存档(#18)的兼容——schema 变更不得锁死已有玩家本地数据,需要前向兼容姿态。
   *解决方式:Alpha 设计随机事件系统(#20)时一并设计内容添加工作流、自动化验证脚本与 schema 版本策略。*
