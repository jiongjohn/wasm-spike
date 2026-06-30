# Design Review Log: 网格移动与交互系统 (grid-movement.md)

## Review — 2026-06-29 (Round 6) — Verdict: APPROVED

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 4（根因）| Recommended: 9
Summary: 第6轮复评。4条真实 Blocking 根因（经 creative-director 综合裁决）：(B-1) 触控拦截架构错误——GDD 声称「× 按钮 `_gui_input()` 的 `accept_event()` 能阻止 GridMovement `_input()` 收到事件」，此为错误（Godot 4 事件传播顺序为 `_input()` → GUI → `_unhandled_input()`，`accept_event()` 无法逆向阻止已触发的 `_input()`）；已全面改写为「方案B：全部在 `_input()` 内分流」，新增 `get_x_button_screen_rect()` 接口，双 Rect2 子区域检测；(B-2) OQ#2 PlayerStats 接入方式实为虚假 Blocking，ADR-0003 已明确答案，已关闭；(B-3/B-4) 多项 AC 可测性与精确性缺陷修正（11条AC修订或新增：AC-LOCK-5a 改为 state_changed 信号监控、AC-MOV-3 上界修正 50ms→83ms、AC-SIG-5b grep 补 tween.kill、AC-FLOOR-4b 补全4个 GameState.on_* 无调用断言、AC-SIG-4b 改为分段 simulate_frames、AC-COMB-2a 补 is_same() API 说明、AC-COMB-7 补 pending() 骨架要求、AC-MOV-1a 补测试计时方法、新增 AC-SIG-7b/_passable 污染测试、新增 AC-EC-3b 路径外 ENTITY→EMPTY、新增 AC-VIS-6 委派给 #10 GDD）。修订后净计约 50 BLOCKING / 5 ADVISORY / 3 CI-Lint。
Prior verdict resolved: 是（Round 5 的 2条 Blocking 根因全部已闭合）

## Review — 2026-06-26 (Round 5) — Verdict: NEEDS REVISION (修订已应用，待复评)

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 2（根因）| Recommended: 10
Summary: 第5轮复评，前4轮 25+ 条 Blocking 全部闭合。Round 5 发现 2 个真实根因（经 creative-director 综合裁决，21 条专家 BLOCKING 收敛）：(A) Rule M6 `door_opened` 后未更新 `cell_type → EMPTY`，导致 M1 对已开启门格误触 `on_door_cell_entered`（运行时 bug）；(B) Visual Requirements 中触控拦截直接访问 CombatForecast 内部节点，违反 ADR-0003，已改为通过 `get_overlay_screen_rect()` 接口（DELEGATE 给 #10）并补充 × 按钮事件消费边界说明。推荐修订 10 项：path_length 4方向BFS声明、AC-LOCK-5a 帧数 300→10、AC-MOV-1a 容限 ±33ms→±66ms、AC-VIS-2 DI 接口注记、新增 AC-SIG-4b/AC-COMB-7/AC-SIG-5b、AC-COMB-2 拆分为 2a/2b、M7 对象池 Advisory 注记、M2 player_moved 信号规则补充。PREVIEWING+WALL/ITEM 行为争议经 CD 裁定维持现状（已锁定设计权衡，× 按钮已提供明确取消路径）。本轮修订已应用，AC 净计 ~47 BLOCKING / 5 ADVISORY / 3 CI-Lint。
Prior verdict resolved: 是（Round 4 的 13 条 Blocking 全部已闭合）

## Review — 2026-06-26 (Round 4) — Verdict: NEEDS REVISION (修订已应用，待复评)

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 13 | Recommended: 9
Summary: 本轮为第4轮复评，累计 25 条历史 Blocking 已全部闭合，Round 4 新增 13 条 Blocking，已在同次会话全部修订完毕。主要发现：(1) 触控事件拦截架构错误（P0）——MOUSE_FILTER_STOP 对 Node2D `_input()` 中的 InputEventScreenTouch 无效，唯一正确实现为 Rect2 手动检测 + `set_input_as_handled()`；(2) 覆盖层 UI 节点归属歧义——明确归 #10 CombatForecast 持有，GridMovement 仅调用 show_overlay / hide_overlay；(3) Tuning Knobs 安全范围错误——MAX_PATH_LENGTH 改为公式 `floor(1500/T_cell)`，新增 AC-CFG-1 启动断言；(4) Tap 拒绝反馈从可选升级为必须实装（AC-VIS-2 升级为 BLOCKING）；(5) AC-BFS-9 与 AC-EC-3 GIVEN 条件逻辑矛盾（BFS 路径不含未清除 ENTITY 格），合并并修正；(6) AC-FLOOR-4 缺失 PREVIEWING 态，新增 AC-FLOOR-4b；(7) AC-LOCK-5 拆分为行为测试（5a）+ CI-Lint（5b）；(8) AC-COMB-2 标记 BLOCKED 待 #10 字段名；(9) Open Question #2（PlayerStats 接入方式）升级为 BLOCKING 实现前置条件。修订后净计数约 45 BLOCKING / 5 ADVISORY / 2 CI-Lint。
Prior verdict resolved: 是（第3轮 4 条 Blocking 全部已闭合）

## Review — 2026-06-26 (Round 3) — Verdict: NEEDS REVISION (修订已应用，待复评)

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 4 | Recommended: 9
Summary: GDD 骨架健康，前两轮 21 条 Blocking 全部已闭合。Round 3 新发现 4 条 Blocking，全为文本层修订，已在同次会话应用完毕：(B1) 网格列数自相矛盾（正文 16×16 vs Visual 节提 ≤9 列备选）→ 锁定 16×16 + 整体缩放方案，弃用 ≤9 列选项；(B2) AC-MOV-1a 容差注释"per step"与公式固定 ±33ms 矛盾 → 改为"total for entire path"并明确链式 Tween 实现前提；(B3) AC-LOCK-5 引用不存在的"GDUnit4 clock simulation" → 改为 simulate_frames(300, 0.033) + 依赖注入计时器约束；(B4) 覆盖层 × 按钮触控穿透/z-order/锚点翻转阈值未定义 → 补充 z_index≥100、触控事件拦截约束、col≥13/≤2 翻转阈值。同批修订：entities.yaml t_cell 安全范围 100ms→67ms（跨文档对齐）；Tuning Knobs 表格加联合约束警示；AC-SIG-5 加 Flag 模式实现约束；Open Questions #5（DOOR 无钥匙反馈责任委派给 #7）；Tween 描述从"按帧步进"修正为"按 delta 时间步进"。creative-director 裁定：无钥匙开门反馈归 #7 范围（DELEGATE），覆盖层确认 CTA 归 #10 范围（RECOMMENDED），AC-COMB-2 字段占位符维持 BLOCKING（正确的"设计先行、实现待依赖"）。
Prior verdict resolved: 是（第2轮 13 条 Blocking 全部已闭合）

## Review — 2026-06-26 (Round 2) — Verdict: NEEDS REVISION (修订已应用，待复评)

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 13 (5类) | Recommended: 11
Summary: 本轮 13 条 Blocking 全部属于文本层修复，已于同次会话修订完毕：(A) F-MOV 联合约束 `T_cell × MAX_PATH_LENGTH ≤ 1500ms` 补入 Tuning Knobs，T_cell 规格改写为帧规格（≤2帧/≤66.7ms@30fps），TK-1 安全范围从 100ms 降至 67ms，TK-2 上界从 40 降至 30；(B) PREVIEWING + 点自身格（path_length=0）M4 vs M2 冲突，Edge Cases 补充 M2 优先规则；(C) Section 10 标题重复，编号修复（Scope-Gate→10，视觉与音频→11）；(D) 四对重复 AC 合并（SM-9≡SIG-3、SIG-5↔EC-4、SM-7↔EC-2、SIG-4≡EC-11）；(E) 五条 AC 可测性改写（LOCK-5 测试方法、SCOPE-1→CI-Lint、SCOPE-2→ADVISORY、SCOPE-3→ADVISORY 待 ADR-0007、MOV-1b 90% 来源说明）。用户决策：AC-COMB-2 升级为 BLOCKING（字段名待 #10 补充）；PREVIEWING 纯取消手势加覆盖层 × 按钮（Rule M4 + 新 AC-SM-11 + AC-COMB-6）；40dp 约束表述加强（HUD #12 必须以此为前提）；两步确认维持现状。
Prior verdict resolved: 是（第1轮 8 条 Blocking 全部已在 Round 1 修订中解决）

## Review — 2026-06-26 — Verdict: NEEDS REVISION (修订已应用)

Scope signal: M
Specialists: game-designer, systems-designer, ux-designer, qa-lead, godot-specialist, creative-director
Blocking items: 8 | Recommended: 9
Summary: GDD 骨架健康，状态机完整，规则精确。8 条 Blocking 问题已在同一次会话内修订完毕：F-PREV 参数顺序与 AC-COMB-1 统一（monster-first）；Player Fantasy「零摩擦响应」与两步确认的散文矛盾已重写（区分 EMPTY 格 vs MONSTER 格体验）；PREVIEWING + tap DOOR/ITEM/KEY/STAIR 状态机缺口已补全（Rule M4 + AC-SM-10）；Anti-Pillars 三项 scope-gate AC 已新增（AC-SCOPE-1/2/3）；触控目标尺寸规格（40×40dp）已写入 Visual Requirements 和 Tuning Knobs；AC-VIS-4 升级为 BLOCKING — Integration；AC-MOV-1 数学拆分为 AC-MOV-1a/1b；LOCKED 超时机制（LOCK_TIMEOUT_MS 旋钮 + AC-LOCK-5/6）已新增。修订后 AC 总数：44 BLOCKING / 5 ADVISORY。
Prior verdict resolved: 首次评审（无历史记录）
