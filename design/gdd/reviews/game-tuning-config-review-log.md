# Review Log: 游戏调参配置 (Game Tuning Config)

---

## Review — 2026-06-25（第 1 轮 / 首次评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: M
Specialists: game-designer、systems-designer、qa-lead、creative-director（综合裁决）
Blocking items: 5（整合自 10 条原始发现，全部即时应用）| Recommended: 6（未纳入本轮）
Prior verdict resolved: N/A — 首次评审

Summary: 骨架健康——D1/D3/F-MVP 校验链、HIGHEST_WINS 防击穿、启动顺序约束均扎实，数据驱动原则执行到位。5 条 BLOCKING：C1（AC-TC-01「5行」与 F-MVP「COUNT≠3」直接冲突，同一仓库内自相矛盾）、C2（断言契约写 GUT 而非 GDUnit4）、C3（shield_iron 拓扑顺序约束责任真空，跨 GDD 修复）、C4（5 条 AC 缺口）、C5（D3 极限余量最低安全值未在 Tuning Knobs 标注）。creative-director 裁定 NEEDS REVISION（非 MAJOR）：全部为补全缺失契约，无骨架重构。

**本轮即时修订（5 条独立修复项，全部应用）：**
1. C1 — floor 4-5 数据标注「VS 预规划」；AC-TC-01 改为 3 行；新增 AC-TC-01b（VS 5行场景）；F2-A 注释「MVP:1-5」改「MVP:1-3」；Tuning Knobs 表 floor 4/5 列标注 VS 预规划
2. C2 — 断言契约「GUT headless 可运行」改为「GDUnit4 headless 可运行」，补正确运行命令
3. C3（跨 GDD）— floor-layout-data 新增 F-SC1d（Floor 2 shield_iron 须在 goblin 可达路径之前，BFS 拓扑验证，code="SHIELD_BEFORE_GOBLIN_REQUIRED"）；floor-layout-data 参考指引「sword_iron 或 shield_wood」改「shield_iron（必需，见 F-SC1d）」；本 GDD T6 注释补「此约束已在 floor-layout-data F-SC1d 落实」交叉引用
4. C4 — 新增 AC-TC-15~19（BATTLE_ROUND_DURATION≤0 / base_ATK<1 / base_MaxHP≤0 / 空表 / floor_number 重复），补齐 5 条 Edge Cases 有描述但 AC 无覆盖的缺口
5. C5 — Tuning Knobs player_HP_expected 行补「⚠️ Floor 2 最低安全值=86，调低至 85 则游戏启动失败」告警

**未纳入（RECOMMENDED，留存）：**
- R1（game-designer）: Edge Cases「裸装入场」的 D1 拦截盲区措辞修正（「D1 阻止 1 伤死磨」→「D1 以中位预期属性校验，裸装进入高层仍可发生 1 伤死磨」）
- R2（game-designer）: Floor 2 Player Fantasy 说明（DEF 减伤体验路径区别于 ATK/HP 数字跳升；player_HP_expected=90 推导说明）
- R3（systems-designer+qa-lead）: 补 F1-C ceil() 非整除 AC（n_rounds(50,20,5)→4）
- R4（systems-designer）: F1-A「6-26」范围上界来源注释（VS sword_great 预留值或写错）
- R5（qa-lead）: AC-TC-13 补「cfg.base_ATK==999 写入确认」断言
- R6（systems-designer）: player_ATK_expected < 10 校验原因说明

## Review — 2026-06-25（第 2 轮复评）— Verdict: APPROVED

Scope signal: M
Specialists: lean 模式（单会话；首轮已召唤 game-designer, systems-designer, qa-lead, creative-director）
Blocking items: 0 | Recommended: 2（GDD Status 字段；F1-C 非整除 AC）
Summary: 6/6 最低通过标准全部验证通过。首轮 5 条修复项（AC-TC-01 改 3 行 + AC-TC-01b、GDUnit4 断言契约、floor-layout-data F-SC1d 跨 GDD 修复、AC-TC-15~19 补全、floor 2 最低安全值 HP=86 告警）均已落地。公式数值抽查全部正确（F1-A/B/C，HIGHEST_WINS，D3 floor 2 余量计算）。Foundation 层 #1/#2/#3 全部 Approved，可进入架构设计阶段。
Prior verdict resolved: Yes — 首轮 NEEDS REVISION 5 条修复项全部验证通过

---

**第 2 轮复审最低通过标准**（6 条）：
1. AC-TC-01 GIVEN 含「3 行」（不含「5 行」）；AC-TC-01b 存在且 GIVEN 含「5 行 VS 预规划」
2. 断言契约含「GDUnit4」且含运行命令
3. floor-layout-data GDD 中 F-SC1d 存在且含 `SHIELD_BEFORE_GOBLIN_REQUIRED`（Read 核实，非仅本文引用）；Floor 2 参考指引含「shield_iron（必需）」
4. AC-TC-15~19 五条均存在且各有独立 GIVEN/WHEN/THEN 结构
5. Tuning Knobs player_HP_expected 行含「最低安全值 = 86」或等价告警
6. T6 表 floor 4-5 行含「VS 预规划」标注；F2-A 注释含「MVP:1-3」
