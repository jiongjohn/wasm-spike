# Review Log: 玩家属性与成长系统 (Player Stats & Growth)

---

## Review — 2026-06-25（第 9 轮 / 再评审）— Verdict: APPROVED（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, economy-designer, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 5（本 GDD 责任，全部即时应用）| Recommended: 多条（部分即时应用）| 外部 Blocking: 1（GUT→GDUnit4，technical-director 责任）
Prior verdict resolved: 是 — 第 8 轮设定的「第 9 轮通过标准」5 条内部项全部 grep 验证闭环；长期外部阻断 #2 floor-layout-data 实地核验已闭环（L234 新增 Design Constraints + F-SC1a/b/c/d；L12 锁 3 层）。

Summary: 骨架与前几轮修复全部确认有效，systems-designer 连续第 3 轮（第 7/8/9）公式数学完全自洽。creative-director 裁定 NEEDS REVISION→收口型：5 条本 GDD BLOCKING 均为确定性文本编辑，无骨架重构。本轮 creative-director 独立核验出专家组都漏掉的关键事实——本 GDD Open Questions 仍声称被 #2「🚧 阻断」，而 #2 其实早已闭环（陈旧自阻断陈述）。两大分歧裁决：(1) GUT vs GDUnit4 阻断全项目实现但不阻断本 GDD 标 Complete（外部 TD 项）；(2) game-designer 的 Player Fantasy DEF 情感断裂裁为 RECOMMENDED（prose 修复，非改机制）。

**本轮即时修订（5 条 BLOCKING + 多条 RECOMMENDED，全部应用 + grep 验证闭环）：**
1. B1 — AC-SCOPE-1 「执行两次结果完全相同」动态断言改为正式 `grep -nE "randf|randi|RandomNumberGenerator|seed\("` 静态断言 + 覆盖边界说明（与 AC-SCOPE-3 格式统一）
2. B2 — AC-SCOPE-3 CI 命令改 `grep -Ein`（修 `\.` 字面点语义），补 `interstitial`、`tt[._]show/ad`、`JavaScriptBridge.get_interface/create_callback`
3. B5 — AC-P3-ATK-UPGRADE / AC-FP02-NOCHANGE 删除「格消失」跨系统断言（属 #6 职责）
4. game-designer B2 — AC-SCOPE-3 内嵌「待 #17 更新正则」TODO 移至 Open Questions
5. creative-director 独立发现 — Open Questions 两条陈旧 🚧 阻断改为 ✅ 已解决（#2 已闭环）
6. RECOMMENDED（即时应用）— AC-FP05-NEGATIVE-DAMAGE 第三路诚实改「部分覆盖」+ Open Questions 跟踪；crystal_life「不晚于 Floor 3」收紧为「Floor 2-3，不建议 Floor 1」；AC-P8-MVP-STUB 改相对断言

**未纳入（留存 RECOMMENDED）**：B1 Player Fantasy DEF 情感转型 prose 重写（需设计取舍）、String vs StringName ADR 跟踪、systems-designer heal_actual 上界注明 + F-P04 中间态 P4 不变量 AC、qa REC-1（AC-EC-DEAD-ITEM 4 独立 @Test）、qa REC-2（AC-P1-INIT 字段可见性）。

**外部 BLOCKING（technical-director 责任，非本 GDD 文本）**：technical-preferences.md L44 `Framework: GUT` → GDUnit4 + ADR。本 GDD 全部 AC 依赖 GDUnit4 API；此为本 GDD 进入测试编写阶段的前置条件，但不阻断设计 Approved。

裁决：**APPROVED**（实现前置:GUT→GDUnit4 框架 ADR 待 technical-director；设计层无 BLOCKING 残留）。

---

## Review — 2026-06-24 — Verdict: NEEDS REVISION

Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director（综合裁决）
Blocking items: 4 | Recommended: 3 | Delegated (not this GDD): 3
Prior verdict resolved: No — First review

Summary: GDD 骨架健康（技术规范 8/10），真正的病在契约层——最贵的漏洞是「stat_changed 发出条件在公式（F-P01）与信号约定文字之间自相矛盾」，对一个把确定性列为核心 Pillar 的游戏是致命的。第二重要的问题是 F-P04 缺少 HP_before/heal_actual 定义导致程序员无法正确实现治疗量 UI。creative-director 裁定经济层发现（ATK 边际感知递减、crystal_life 放置时机、floor 4-5 成长空白）属于关卡/平衡设计职责，不作为本 GDD 修订项。

**本次已修复（4 项阻塞，全部完成）：**
1. F-P01 `stat_changed` 变量改名 `value_changed`，与信号名解耦，信号约定收敛：信号始终发出
2. P0 补充 stat_name 合法值（"ATK"/"DEF"/"HP"/"MaxHP"），F-P04 增加 HP_before + heal_actual 定义
3. AC-P7 / AC-FP01 补充场景上下文消除歧义，补充 AC-FP04-FULL-START + AC-FP04-DYING 两条边界 AC
4. Player Fantasy「shield_wood 后哥布林零伤」改为史莱姆，并补充 floor 2+ DEF 价值说明

**委派给关卡/经济设计的问题（下游 GDD 须跟进）：**
- floor 4-5 成长空白（40% 内容无成长事件），需在 floor-layout-data GDD 建立约束
- crystal_life 放置时机决定难度，需在 floor-layout-data GDD 建立放置约束规则
- floor 1 裸装期成长空窗，需作为关卡设计硬约束显式化

**建议复审**：/clear 后运行 /design-review design/gdd/player-stats-growth.md 验证 4 个阻塞项闭环。

---

## Review — 2026-06-24（第 2 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 6 | Recommended: 4 | Delegated（维持下放）: 5
Prior verdict resolved: 部分 — 上轮 blocker ②③④ 已闭环；**blocker ① 仅修 F-P01、漏修 F-P02 第168行（同根缺陷未对称闭环）**，本轮已补修。

Summary: 上轮 4 项中 3 项确认闭环。本轮最贵的发现是 blocker ① 的**不对称残留**——`stat_changed` 变量遮蔽信号名的致命缺陷在 F-P01 已修，但 F-P02（DEF 公式）第168行仍存在，被 systems-designer / godot-gdscript / economy-designer 三方独立发现。creative-director 裁定 verdict 为 NEEDS REVISION（非 MAJOR）：全部 BLOCKING 均为「补全已声明的契约」，无核心重设计。game-designer 的 floor 2 空窗 / sword_steel 边际感知维持 DELEGATED（判据：只改 floor-layout 即可解决）；economy 的「枯竭点存在性」升级为本 GDD 必须声明（P7 涌现属性，关卡无法自行推导）；godot 的 String→enum 裁为 RECOMMENDED + ADR（波及全文、跨未设计 GDD、不改行为，不应让再评审变骨架级改写）。

**本轮即时修订（6 项 BLOCKING，全部应用 + 已 grep 验证对称闭环）：**
1. B1 — F-P02 L168 `stat_changed`→`value_changed`，补双信号注释 + 命名通则 + 变量表行；同步修 Edge Case L281 同根残留（grep 确认全文 0 处变量误用）
2. B2 — MaxHP 双轨收敛为唯一权威 `MaxHP = base_MaxHP + maxhp_bonus`（用户拍板 maxhp_bonus 为权威）；F-P04 改派生式重算；P1/变量表同步
3. B3 — F-P04 新增字段写入顺序规则（maxhp_bonus→MaxHP→current_HP，守 P4）+ 明文禁止 CONNECT_DEFERRED
4. B4 — F-P03/F-P04 补 Dead 守卫 `if current_HP_old == 0: return`（与 F-P05 对称，grep 确认三处齐全）
5. B5 — 重写 AC-P0 / AC-P3-ATK-NOCHANGE / AC-FP04-ORDER（补 SignalOrderSpy）/ AC-SCOPE-2 / AC-SCOPE-3（路径A grep/lint，用户拍板）；新增 AC-FP02-NOCHANGE（DEF 降级对称覆盖）
6. B6 — Edge Cases 新增 HIGHEST_WINS 成长枯竭点约束声明（MVP 最多 5 次成长，向 #2 floor-layout 传递）

**未纳入（RECOMMENDED，待办）**：String→enum StatType（建议 ADR，#11/#12 设计前敲定）；restore_from_snapshot/apply_revival_bonus 签名补全（VS）；player_ATK/DEF 访问接口建议计算属性；Player Fantasy 边界声明。

**维持 DELEGATED → floor-layout-data**：floor 2 成长空窗、sword_steel 边际感知、crystal_life 双重价值/无 sink、crystal_life 放置时机、floor 4-5 空白。

**下轮复审标准**：B1–B6 全部**对称**闭环（不再出现 ATK 修了 DEF 没修）。复审请逐条点名「B1 在第几行如何修、B4 在 F-P03/F-P04 加了什么守卫」，而非只报「已修复」。

---

## Review — 2026-06-24（第 3 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 6 | Recommended: 7（大部分已即时应用）| Delegated（维持下放）: 3
Prior verdict resolved: 部分 — **B1 完全闭环**；B2/B3/B4/B5/B6 均存在精确残留缺口，本轮全部修复。

Summary: 骨架健康，修复有效——B1 三处 grep 验证通过，信号命名契约已稳固。本轮暴露的是「骨架修好后才看得清的下一层精确问题」：B2 残留（P3 L78 旁路写法与 F-P04 权威公式并存）、heal_actual 范围声明自相矛盾（[0,…] 与注脚 effect_value=50 互证下界非 0）、F-P05 缺少负值防护（HP 超过 MaxHP 违反 P4）、AC-P0 使用 GDUnit4 不存在的 API + 两情形合并导致断言必然失败、成长分布约束只声明枯竭存在而未传递「每层 ≥1 次成长事件」硬性约束。creative-director 裁定均为补肉级修复（非骨架重构）。

**本轮即时修订（6 项 BLOCKING + 7 项 RECOMMENDED，全部应用）：**
1. B2残留 — 删除 P3（L78）`MaxHP += effect_value` 旁路写法，统一改为「按 F-P04 结算」引用；全文 MaxHP 唯一权威源：`MaxHP = base_MaxHP + maxhp_bonus`
2. SD-N1 — F-P04 heal_actual 范围 `[0, MaxHP_new-1]` → `[1, MaxHP_new-1]`（item_effect_value ≥1 保证下界 ≥1；变量表注脚自证）
3. SD-N2 — F-P05 入口补 `assert(damage_amount >= 0)` 输入端断言；更新变量表描述；新增 AC-FP05-NEGATIVE-DAMAGE
4. B4残留 — F-P01/F-P02 补 Dead 守卫 `if current_HP == 0: return`（本系统责任，用户拍板）；AC-EC-DEAD-ITEM 区分两种 effect_type + 注明拦截层归属；F-P03/F-P04 伪码补 `current_HP_old = current_HP` 捕获语句
5. B5残留 — AC-P0 拆分为 AC-P0-SIGNAL-UPGRADE + AC-P0-SIGNAL-NOCHANGE，换用真实 GDUnit4 API（`watch_signals`、`assert_signal_emitted_with_parameters`、`assert_signal_emit_count`）；AC-FP04-ORDER 补 SignalOrderSpy 最小接口定义（3参回调签名必须匹配）
6. B6残留 — Edge Cases 成长枯竭点重写：拆分「机制性枯竭（HIGHEST_WINS 4次）」与「分布性枯竭（ADDITIVE，关卡放置决定）」；补 potion 排除说明；补「成长分布约束」硬性条款（每层 ≥1 次成长事件，Floor 1 不豁免）→ Interactions 表 + Dependencies 表同步增加 #2 约束传递行
7. B3传播 — 依赖表 #11/#12 行补注「须同步连接，禁 CONNECT_DEFERRED，见 F-P04」；Interactions 表同步
8. GS-W1 — P1 属性模型补 player_ATK/DEF 只读 getter 接口声明（推荐计算属性）
9. GS-B4 — F-P03/F-P04 伪码第一行补显式快照捕获行（见条目4合并）

**维持 DELEGATED → floor-layout-data**：floor 2 成长空窗、sword_steel 边际感知、crystal_life 放置时机、DEF 价值重定义玩家教学（属 UX/表现层）。

**DEFER → VS 阶段**：apply_revival_bonus 接口完整声明、apply_temp_bonus 作用域语义。

**第4轮复审最低通过标准**（6条，逐条验证）：
1. 全文无 `MaxHP += effect_value` 赋值（grep 验证）
2. F-P04 heal_actual 范围为 `[1, MaxHP_new-1]`
3. F-P05 代码块有 `assert(damage_amount >= 0)` 且 AC-FP05-NEGATIVE-DAMAGE 存在
4. F-P01/F-P02 代码块有 `if current_HP == 0: return` Dead 守卫；AC-EC-DEAD-ITEM 注明「本系统」为拦截层
5. AC-P0 已拆分为两条独立 WHEN，使用 GDUnit4 真实 API；AC-FP04-ORDER 有 SignalOrderSpy 3参回调签名
6. Edge Cases 有「成长分布约束」段落，Dependencies 下游表有 #2 约束传递行


---

## Review — 2026-06-25（第 4 轮 / 再评审）— Verdict: MAJOR REVISION NEEDED（修订已即时应用）

Scope signal: L
Specialists: systems-designer, game-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 7 | Recommended: 8（未纳入本轮）| Delegated（精度提升后维持）: 哪层放哪把剑
Prior verdict resolved: 是 — 第3轮 6 项通过标准全部 grep 验证对称闭环（无 MaxHP+= / 无信号遮蔽 / Dead 守卫五处 / assert 到位 / heal_actual 范围 / 成长分布约束声明）；上游数值与 #1/#3 交叉一致。

Summary: 骨架与第3轮修复确认有效。creative-director **推翻前 3 轮「均为契约补全→NEEDS REVISION」先例，升级为 MAJOR REVISION**，两个决定性依据：(1) 成长枯竭是 HIGHEST_WINS 设计与 MVP 层数的**数学不兼容**，需设计取舍而非填空；(2) 两条「前轮误判已解决、实际未解决」的根因——F-P05 Dead 守卫缺快照行（同根缺陷又一次非对称残留）+ 成长分布委派通道断裂（#2 无 Design Constraints 节，DELEGATE 全部落空）。关键分歧（成长枯竭能否继续 DELEGATE）裁定为劈分：约束「可满足性」+「委派落地」= BLOCKING 本 GDD；「哪层放哪把剑」维持 DELEGATED。

**用户设计决策**：BLOCKING #1 采「**锁定 MVP = 3 层**」（原 3-5 层收紧；floor 4+ 成长延展属 VS，须先引入新成长来源）。

**本轮即时修订（7 项 BLOCKING，全部应用 + grep 验证对称闭环）：**
1. B1 — 锁定 MVP=3 层：Player Fantasy L29 补承诺边界；Edge Cases L317-321 补「成长事件总数=5↔层数上限=3」数学推导 + 数据层代理指标（effect_type∈{ATK/DEF/MAXHP_BOOST} ≥1）+ 单层≤2 / 同类更弱装备同层≤1 负反馈约束
2. B2 — Open Questions L480 新增 🚧 阻断记录：#2 floor-layout-data 缺 Design Constraints 节，委派未落地，须 producer 在 #2 评审前闭合（建议 F-SC1 对标 #1 F-K1）
3. B3 — F-P05 L263 补 `current_HP_old = current_HP` 首行（同根缺陷对称闭环：F-P03/F-P04/F-P05 三处快照行齐全，grep 确认）；缺此行 GDScript 未初始化 null 使 Dead 守卫失效
4. B4 — F-P04 L229 补 `MaxHP_old = MaxHP` 快照，明确 stat_changed("MaxHP", old, new) 的 old 权威来源（非 0 / 非推断）
5. B5 — F-P04 补「中间态约束」：MaxHP 回调内禁读 current_HP（补满前旧值→HUD 单帧闪烁）；Open Questions 补 #18 存档原子性
6. B6 — 4 项 AC：(R4-1) AC-P0-SIGNAL-NOCHANGE 删 auto_free「自动检测孤儿」误述；(R4-2) AC 节顶新增「前置状态注入约定」（watch_signals 连接前 pickup 注入，禁直写私有字段）；(R4-3) 删重复 AC-FP03-CLAMP，补 AC-FP03-EXACT（恰好==MaxHP 边界）；(R4-4a) AC-EC-DEAD-ITEM 扩全 4 effect_type；(R4-4b) AC-FP05-NEGATIVE-DAMAGE 改判定为 code review+grep+#5 集成测试（GDScript assert 在 GDUnit4 记 ERROR 非 PASS，不可单元测试）
7. B7 — P1 L60 补计算属性只读防护三重机制（get-only + `_`私有约定 + emit int 转型），建议 ADR（与 String→enum 一并）

**未纳入（RECOMMENDED，待办）**：effect_value<0 覆盖、sword_steel 跳跃感数值约束传 #1（ceil(HP/ATK_iron)−ceil(HP/ATK_steel)≥1）、floor 2 DEF 减伤战斗反馈机制、emit StringName 比较、crystal_life 经济后果量化、AC-SCOPE-3 正则补全、String→enum ADR。

**DEFER → VS**：sword_great(=20) 进入后 player_ATK 范围上界 + D3 表更新、apply_temp_bonus 作用域、第二颗 crystal_life D3 重验。

**第 5 轮复审最低通过标准**（7 条，逐条点名验证）：
1. F-P05 代码块首行有 `current_HP_old = current_HP`（grep；与 F-P03/F-P04 对称）
2. F-P04 代码块有 `MaxHP_old = MaxHP` 快照；两步信号用 MaxHP_old 作 old
3. F-P04 有「中间态约束：MaxHP 回调内禁读 current_HP」段落
4. AC 节有「前置状态注入约定」；AC-P0-SIGNAL-NOCHANGE 无「自动检测孤儿」字样
5. 无 AC-FP03-CLAMP；有 AC-FP03-EXACT；AC-EC-DEAD-ITEM 列全 4 effect_type；AC-FP05-NEGATIVE-DAMAGE 标注「非 GDUnit4 单元测试」
6. Edge Cases 有「成长事件总数与 MVP 层数硬性绑定」+ MVP 锁定 3 层；Open Questions 有 #2 缺 Design Constraints 节的 🚧 阻断记录
7. P1 有计算属性只读三重防护声明

---

## Review — 2026-06-25（第 6 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 3（本 GDD 责任，全部即时应用）| Recommended: 7（部分即时应用）| 外部 Blocking: 1（#2 floor-layout-data 未更新，producer 责任）
Prior verdict resolved: 是 — 第 5 轮 6 条通过标准全部 grep 验证对称闭环。

Summary: 骨架与第 5 轮修复全部确认有效，无核心架构问题。creative-director 裁定 NEEDS REVISION（非 MAJOR）：3 条本 GDD BLOCKING 均为「补全已触及但未落地的契约」——AC-SCOPE-2「道具格 item_id==null」是同根缺陷非对称残留第 5 次复现（本轮 BLOCKING #1）；pickup_item() 被 AC 反复引用但从未定义 API 性质（R5-BLOCK-1 遗留，本轮确认公开 API，BLOCKING #2）；AC-FP04-FILL「任意值」参数化 R5-BLOCK-3 遗留（BLOCKING #3）。外部 BLOCKING：#2 floor-layout-data 两条 🚧 经济师实测仍未闭环，须 producer 推动。

**本轮即时修订（3 条 BLOCKING + 7 条 RECOMMENDED，全部应用 + grep 验证闭环）：**
1. B1 — AC-SCOPE-2 移除「道具格 item_id==null」越界断言（改为「道具格消失是 #6 的职责」），确立本系统断言边界
2. B2 — P3 新增公开接口声明 `pickup_item(item_id: String) -> void`；AC 前置注入约定补「pickup_item 是公开 API」说明；Interactions 表 #1 行和 #6 行同步更新；Dependencies 表 #1 行同步更新
3. B3 — AC-FP04-FILL 参数化：「任意值（1–100）」替换为 DataProvider `{1, 50, 100}`
4. R1 — P0 补例外注记：MAXHP_BOOST effect_value==0 路径不发 stat_changed（见 Edge Cases）
5. R2 — Player Fantasy shield_iron 减伤 73% → 约 67%（相对裸装 DEF=3；补边际减伤 50% 说明）
6. R3 — F-P01/F-P02 注释「同步发出」→「在同一调用帧内额外发出」；F-P02 命名说明同步修正（消除与 F-P04 CONNECT_DEFERRED「同步」的语义歧义）
7. R4 — F-P04 MaxHP 计算属性注释：MaxHP_new 行注明「MaxHP 为计算属性，无需显式赋值」；L239 写入顺序注明「指可观测值变更序」
8. R5 — F-P04 补发送方约束：pickup_item() 结算函数内禁用 call_deferred/await 推迟信号发射
9. R6 — Edge Cases 新增 effect_value<0 条目：F-P03/F-P04 ADDITIVE 路径无运行时钳制，须由 D1 开发期捕获（契约信任，与 ==0 同路径）
10. R7 — P1 int() 转型边界补注：仅对 float→int 有效，null/String 静默归零属 D1 责任

**未纳入（留存 RECOMMENDED，待后续处理）**：pickup_item() 返回型声明（void 已隐含）、AC-EC-DEAD-ITEM 测试结构形式、AC-FP04-ORDER GIVEN 前置状态、String vs StringName P0 约束、「推荐」→「须」措辞统一（计算属性）、gold 系统 sink 占位注记、apply_temp_bonus 量级原则。

**外部 BLOCKING（producer 责任，非本 GDD 文本改动）**：#2 floor-layout-data 须更新「3-5 层」→「3 层」并新增 Design Constraints 节含 F-SC1。本 GDD 标 Complete 的前置条件（Open Questions L488）未变，producer 须在 #2 评审前闭合。

**第 7 轮复审最低通过标准**（7 条，逐条验证）：
1. AC-SCOPE-2 无「item_id == null」字样（grep 验证）
2. P3 有 `pickup_item(item_id: String) -> void` 公开接口声明；AC 注入约定有「公开 API」说明；Interactions 表有 #6 行
3. AC-FP04-FILL 无「任意值」字样；含 DataProvider `{1, 50, 100}`
4. P0「始终发射」段落有「例外」交叉引用（MAXHP_BOOST effect_value==0）
5. Player Fantasy 无「73%」；含「约 67%」且有基准说明
6. F-P01/F-P02 注释无「同步发出 item_pickup_no_change」；含「在同一调用帧内额外发出」
7. #2 floor-layout-data（外部）：全文无「3–5 层」，有 Design Constraints 节，L297 无「不做校验」（producer 核验）

---

## Review — 2026-06-25（第 5 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 6 | Recommended: 7（未纳入本轮）| Delegated（维持下放）: 1
Prior verdict resolved: 是 — 第 4 轮 7 条通过标准全部 grep 验证对称闭环（F-P05 快照 / F-P04 MaxHP_old / 中间态约束 / 前置注入约定 / AC-FP03-EXACT / 3 层锁定 / P1 三重防护）。

Summary: 骨架与第 4 轮修复确认有效。creative-director 维持 NEEDS REVISION（非 MAJOR）：全部 6 项 BLOCKING 均为「确定性契约在边界值/生产构建/措辞上的最后真空」及「危险误导措辞修正」，无核心重设计。最重要发现：(1) F-P04 heal_actual ≥1 声明被 effect_value=0 打破（ADDITIVE 无守卫，同根缺陷非对称残留模式）；(2) assert() Release 被剥除，负伤害静默变治疗，P4 不变量真空；(3) F-P01/F-P02 Dead 守卫虚假「对称」注释误导实现者；(4) 只读属性「运行时错误」描述不准确（反射路径静默失败无保护）；(5) F-P04 伪码无 emit 注释锚点。game-designer 的「成长枯竭期体验空白」降级为 OBSERVATION（3 层内枯竭不发生，Pillar 1 承诺有兑现窗口）；GS-4(编辑器连接)/GS-5(SignalOrderSpy disconnect) 降级为 RECOMMENDED（测试卫生属 QA 规范责任，GDD 不应微管理到此层）。

**本轮即时修订（6 项 BLOCKING，全部应用 + grep 验证闭环）：**
1. B1 — F-P04 补 `if item_effect_value == 0: emit item_pickup_no_change("MaxHP", item_id); return` 守卫（与 F-P01/F-P02 对称）；Edge Cases effect_value=0 条目扩展为涵盖全部 BOOST 类型（MAXHP_BOOST/ATK_BOOST/DEF_BOOST/HP_RESTORE 四路并列，消除 heal_actual ≥1 的自相矛盾）
2. B2 — F-P01/F-P02 Dead 守卫注释删除虚假「对称」声明，改为「F-P0x 不读改 current_HP，故无需快照行——写法与 F-P03/F-P04/F-P05 不同，但守卫语义等价」
3. B3 — F-P04 伪码块末补两行 emit 注释（先 MaxHP 后 HP，同步禁 DEFERRED），与 F-P01/F-P02 风格一致
4. B4 — P1 L64 只读防护描述修正：直接赋值=编译期报错；反射赋值=静默失败无保护；明确 (2)(3) 是反射路径唯一防线；int() 转型理由改为「float 截断产生语义错误数值」
5. B5 — F-P05 伪码补 `damage_amount = max(0, damage_amount)` 生产期钳制行（assert 保留为调试诊断）；变量表描述 + AC-FP05-NEGATIVE-DAMAGE 同步更新，声明 Release 构建中负伤害归零不产生治疗效果
6. B6 — L128/L329/L344 的「硬性约束」措辞降级为「待决依赖」；Open Questions 第一条 🚧 精确化（交付物=F-SC1，是本 GDD 标 Complete 前置条件，不可再搪塞为「#2 评审时处理」）；新增第二条 🚧——floor-layout-data 当前仍写「3-5 层」与 MVP=3 直接冲突

**未纳入（RECOMMENDED，待办）**：floor 1→2 零伤转减伤的表现层设计指引（#11 责任，本 GDD 建议给方向）、heal_actual 两描述分行说明、HP_before=current_HP_old 显式引用、F-P04 中间态对 #18 原子化的更详细约束、SignalOrderSpy disconnect 测试卫生说明、pickup_item watch_signals 时序显式说明。

**DEFER → VS**：apply_temp_bonus 作用域、第二颗 crystal_life D3 重验。

**第 6 轮复审最低通过标准**（6 条，逐条验证）：
1. F-P04 伪码有 `if item_effect_value == 0: emit item_pickup_no_change(...)` 守卫；Edge Cases effect_value=0 条目涵盖 MAXHP_BOOST
2. F-P01/F-P02 Dead 守卫注释不含「对称」字样；含「无需快照行——写法与 F-P03/F-P04/F-P05 不同」说明
3. F-P04 伪码块内有「先发 stat_changed("MaxHP",...)」「再发 stat_changed("HP",...)」两行注释
4. P1 L64 含「编译期（parse-time）报错」+「反射路径静默失败」两路描述
5. F-P05 伪码有 `damage_amount = max(0, damage_amount)` 行；AC-FP05-NEGATIVE-DAMAGE 含「生产期硬保证」字样
6. Open Questions 有两条 🚧 阻断（缺 Design Constraints 节 + 标 Complete 前置条件；3-5 层与 MVP=3 冲突）；L128/L329/L344 含「待决依赖」措辞

---

## Review — 2026-06-25（第 8 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer、systems-designer、qa-lead、godot-gdscript-specialist、creative-director（综合裁决）
Blocking items: 1（本 GDD 责任，已即时应用）| Recommended: 4（R-03 已纳入，其余留存）| 外部 Blocking: 2（#2 floor-layout-data，producer 责任）
Prior verdict resolved: 是 — 第 7 轮 4 条通过标准全部 grep 验证对称闭环。

Summary: 骨架与第7轮修复全部确认有效，systems-designer 0条 BLOCKING，公式数学第二轮连续完全自洽。creative-director 裁定 NEEDS REVISION：仅1条新 BLOCKING（AC-SCOPE-3 正则覆盖漏洞，godot-gdscript-specialist 发现），但裁定依据是「GDD 声称能从源码层证明不主动触发广告，而现有正则无法在唯一目标平台抖音小游戏上完成该证明」——规格层 false claim，非 lint 质量问题。qa-lead vs godot-gdscript-specialist 分歧（RECOMMENDED vs BLOCKING）由 creative-director 裁定为 BLOCKING。

**本轮即时修订（1 条 BLOCKING + 1 条 RECOMMENDED，已应用）：**
1. B1 — AC-SCOPE-3 正则扩充：新增抖音 SDK 真实命名面（tt\.show*、ttVideoAd、RewardedVideoAd、createRewardedVideo、showInterstitial、JavaScriptBridge\.eval、douyin_、rewarded_video），补覆盖边界说明（#17 设计时须核实实际标识符并更新正则）
2. R-03（同根，一次修齐）— AC-SCOPE-1 补具体 grep 验证路径（`randf\|randi\|RandomNumberGenerator` 零匹配），与 AC-SCOPE-3 格式对称

**未纳入（RECOMMENDED，留存）：**
- R-01（game-designer）: Player Fantasy / Visual/Audio Requirements 节补 floor 3 末段枯竭期玩家预期说明
- R-02（game-designer）: Visual/Audio Requirements 节补药水回血 vs 武器升级视觉强度量化对比指引
- R-04（creative-director）: Tuning Knobs 节补叠加规则（HIGHEST_WINS/ADDITIVE）是结构性设计决策、须通过 ADR 变更的注记

**外部 BLOCKING（producer 责任）：** (1) #2 floor-layout-data 须更新「3-5层」→「3层」；(2) #2 须新增 Design Constraints 节落实 F-SC1。本 GDD 标 Complete 的前置条件（Open Questions L498-499）未变。

**第 9 轮复审最低通过标准**（5 条）：
1. AC-SCOPE-3 含 `ttVideoAd` + `JavaScriptBridge\.eval` + `douyin_` + `rewarded_video` 等抖音 SDK 标识符（grep 验证）
2. AC-SCOPE-1 含 `grep -n "randf\|randi\|RandomNumberGenerator"` 验证路径
3. 上述修改未引入新的逻辑矛盾或信号约定破坏（回归验证）
4. （外部）#2 floor-layout-data：全文无「3-5层」；有 Design Constraints 节；L297 无「不做校验」
5. （外部）technical-preferences.md 确认测试框架为 GDUnit4（GUT vs GDUnit4 冲突 ADR，technical-director 责任）

---

## Review — 2026-06-25（第 7 轮 / 再评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director（综合裁决）
Blocking items: 4（本 GDD 责任，全部即时应用）| Recommended: 15+ | 外部 Blocking: 2（GUT→GDUnit4 框架冲突 + #2 floor-layout-data，producer 责任）
Prior verdict resolved: 是 — 第 6 轮 7 条通过标准全部 grep 验证对称闭环。

Summary: 骨架与第6轮修复全部确认有效，systems-designer 0条 BLOCKING，公式数学完全自洽。本轮暴露了「AC 实现层的命名/路径精确度」这一层：AC-SCOPE-2 引用了未定义的 SignalSpy 类（应用 GDUnit4 标准 API）；AC-FP04-ORDER 代码块保留 class_name SignalOrderSpy 导致 Godot 全局注册冲突（R5-BLOCK-4 遗留）；AC-FP05-NEGATIVE-DAMAGE 验证路径无具体 grep 命令；AC-EC-DEAD-ITEM 的 Dead 状态构造时序未说明。game-designer 的 B1-B3（sword_steel 体感论证、Floor 3 枯竭期、药水非成长声明）由 creative-director 降级为 RECOMMENDED——验证手段住在未设计的下游系统或属已被接受的设计取舍。GUT vs GDUnit4 框架冲突是全项目问题，委托 technical-director 修 technical-preferences.md + ADR，不阻断本 GDD Complete。

**本轮即时修订（4 条 BLOCKING，全部应用 + grep 验证闭环）：**
1. B2(R7-BLOCK-2) — AC-SCOPE-2 「SignalSpy」→ `assert_signal_emitted_with_parameters(player_stats, "stat_changed", ["ATK", 6, 14])`；L244 描述性引用同步改为 SignalOrderSpy/assert_signal_emitted_with_parameters
2. B4(R7-BLOCK-4) — AC-FP04-ORDER 代码块移除 `class_name SignalOrderSpy`，改为注释说明文件路径 + preload 用法
3. B1(R7-BLOCK-1) — AC-FP05-NEGATIVE-DAMAGE 路径 (2) 补具体 grep 命令；路径 (3) 补「#5 GDD 待设计，AC 编号 TBD，标 Complete 前须补填」占位
4. B3(R7-BLOCK-3) — 前置状态注入约定新增「Dead 前置状态构造」段落（apply_damage(100) 在 watch_signals 连接前归零，信号不计入断言计数）

**未纳入（RECOMMENDED，待后续）**：F-P01 atk_boost_effective_old 备注误读风险、heal_actual 下界「1」不精确（实为 effect_value）、F-P04 写入顺序标题歧义、中间态约束补 apply_damage() 禁用说明、D1 校验器 typeof() vs is int、#6 禁用 call_deferred、base_ATK 禁 @export、私有字段 CI grep lint 保护、AC-SCOPE-3 正则扩充抖音 SDK 方法名、sword_steel 体感论证、Floor 3 枯竭期替代性满足声明、药水「非成长空缺」经验性 AC

**外部 BLOCKING（producer 责任，非本 GDD 文本改动）**：(1) technical-preferences.md 将 GUT 改为 GDUnit4 + ADR（technical-director）；(2) #2 floor-layout-data 须更新「3-5 层」→「3 层」并新增 Design Constraints 节（F-SC1）。本 GDD 标 Complete 的前置条件（Open Questions L493-494）未变。

**第 8 轮复审最低通过标准**（5 条，逐条验证）：
1. AC-SCOPE-2 无「SignalSpy」字样（grep 验证）；含 `assert_signal_emitted_with_parameters`
2. AC-FP04-ORDER 代码块无 `class_name SignalOrderSpy`；含 preload 路径注释
3. AC-FP05-NEGATIVE-DAMAGE 路径 (2) 含具体 grep 命令；路径 (3) 含「TBD」占位
4. 前置状态注入约定有「Dead 前置状态构造」段落，含 `apply_damage(100)` 构造方式
5. #2 floor-layout-data（外部）：同第7轮标准7，producer 核验
