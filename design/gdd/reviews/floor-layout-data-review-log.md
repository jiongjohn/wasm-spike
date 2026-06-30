# Review Log: 楼层关卡数据系统 (Floor Layout Data)

---

## Review — 2026-06-25（第 1 轮 / 首次评审）— Verdict: NEEDS REVISION（修订已即时应用）

Scope signal: L
Specialists: game-designer、level-designer、systems-designer、qa-lead、creative-director（综合裁决）
Blocking items: 7（整合自 14 条原始发现，全部即时应用）| Recommended: 4（未纳入本轮）
Prior verdict resolved: N/A — 首次评审

Summary: GDD 骨架健康，校验公式体系（F-G1~F-T1）结构完整，AC 19 条覆盖主要路径。但作为 player-stats-growth 的外部阻断前置条件（#4 经 8 轮确认），本 GDD 缺少 Design Constraints 节（F-SC1）导致 P1「看得见的成长」可静默失效，多处「3-5层」与 MVP=3 产生文字冲突并在校验器层面无法拦截 5 层布局，F-T1 存在 EntityDB 空 DB 假阳性通过路径，AC 层有 4 条对称缺口（F-G2/F-G3/floor_number边界/STAIR_DOWN）。creative-director 裁定 NEEDS REVISION（非 MAJOR）：全部为既有契约补全，无核心数据模型重设计。可解性/拓扑死锁裁定为「QA playtest 兜底 + Accepted Risk 明文化」，不引入 BFS 校验。

**本轮即时修订（7 条独立修复项，全部应用）：**
1. C1 — 新增 Design Constraints 节，含 F-SC1a（每层 ≥1 永久成长事件）、F-SC1b（单层 ≤2）、F-SC1c（同类 ≤1）三条强制校验公式；Tuning Knobs 注记升级指向 F-SC1
2. C2 — F9/Overview/Player Fantasy/Tuning Knobs 全部改为「3层（MVP 固定）」；新增 F-MVP 楼层数约束（COUNT≠3 报 INVALID_FLOOR_COUNT_FOR_MVP）；L297「不做校验」更新
3. C3 — Edge Cases 新增「已知可解性局限（Accepted Risk）」：拓扑死锁/连通性缺口由关卡设计师走通 + QA playtest 人工兜底，Alpha+ 随机楼层时须升级为 BFS 校验
4. C4 — F-T1 补 EntityDB 未就绪防护：null 返回视为 MISSING_ENTITY_TIER 报错，不静默通过
5. C5 — Visual/Audio Requirements 删除悬空 sprite_id 引用，改为「#6/#11 自行维护，本数据库不持有 sprite_id」
6. C6 — 新增 AC-FL-20（F-G2 非法 cell_type）、AC-FL-21（F-G3 DOOR 缺 door_color）、AC-FL-22（floor_number<1）、AC-FL-23（STAIR_DOWN 方向对称），补齐4条缺口
7. C7 — ValidationResult.errors 补 detail: Dictionary 字段；AC-FL-04 改用 detail.key_count/door_count 断言；AC-FL-13 补浅拷贝注意事项

**未纳入（RECOMMENDED，留存）：**
- R1（game-designer）: F-K1 单层封闭 vs 跨层携带钥匙的教学层语义——是否设计特性，须 #9 楼层进程 GDD 设计时联合确认
- R2（level-designer）: Edge Cases 补 WALL 封堵说明（已合并入 C3 Accepted Risk）
- R3（level-designer）: Tuning Knobs Floor 1 参考行补「门数量建议 ≤2」
- R4（systems-designer）: Edge Cases 或 F4 补 floor_number 连续性约束（FLOOR_NUMBER_GAP）

**外部关联（player-stats-growth 方向）：** C1+C2 落实后，player-stats-growth.md L498-499 的两条 🚧 阻断记录（缺 Design Constraints 节 + 仍写「3-5层」）已在本 GDD 闭合，producer 可通知 player-stats-growth 作者确认阻断解除。

---

## Review — 2026-06-25（第 2 轮复评）— Verdict: APPROVED

Scope signal: L
Specialists: lean 模式（单会话；首轮已召唤 game-designer, level-designer, systems-designer, qa-lead, creative-director）
Blocking items: 0 | Recommended: 3（F-G1/F-G2 错误码补充到公式节；F-SC1a 最低 AC；GDD Status 字段）
Summary: 6/6 最低通过标准全部验证通过。首轮 7 条修复项（Design Constraints/F-SC1a/b/c、F-MVP 楼层数约束、Accepted Risk 明文化、F-T1 null 防护、Visual/Audio sprite_id 清除、AC-FL-20/21/22/23 补充、ValidationResult.detail 字段）均已落地。残留缺口（F-SC1 AC 系列待补、F-G1/F-G2 错误码未在公式节定义）均已在 GDD 内明文记录并给出解决方向，不阻断架构阶段启动。
Prior verdict resolved: Yes — 首轮 NEEDS REVISION 7 条修复项全部验证通过

**第 2 轮复审最低通过标准**（6 条，逐条验证）：
1. Design Constraints 节存在；含 F-SC1a/b/c 三条公式且各有独立错误码（MISSING_GROWTH_EVENT / EXCESS_GROWTH_EVENTS / DUPLICATE_EFFECT_TYPE）
2. 全文无独立的「3–5 层」表述（仅允许 Overview L12 保留「原「3-5层」已收紧」历史说明）；F9 含「3个楼层（固定）」；F-MVP 公式存在
3. F-T1 含「null → MISSING_ENTITY_TIER，不静默通过」防护说明
4. AC-FL-20/21/22/23 均存在且各有 GIVEN/WHEN/THEN 结构
5. AC-FL-04 使用 `detail.key_count / detail.door_count` 断言；AC-FL-13 含浅拷贝注意事项
6. Visual/Audio Requirements 节无 `sprite_id` 字样；含「本数据库不持有 sprite_id」说明
