# 战斗预演系统 (CombatForecast) #10 — Review Log

## Review — 2026-06-29 — Verdict: MAJOR REVISION NEEDED → 已修订，待复评
Scope signal: M（实现体量 S，但被跨系统 #6 协调阻塞，排期按 M）
Specialists: game-designer, systems-designer, ux-designer, godot-specialist, qa-lead, creative-director（综合裁决）
Blocking items: 7 | Recommended: 7 | Nice-to-have: 3
Prior verdict resolved: 首次评审（无既往 log）

### 综合裁决（creative-director）
核心架构健康（纯代理 #5 + Rect2 缓存契约 + 两步确认骨架成立），但呈现层与跨系统同步有四个根因级破洞，需骨架级重写而非加约束。设计意图正确，执行层未达 Approved 标准。

### 7 个阻塞项（复评须逐项验证闭环）
1. **[game-designer + ux-designer] 确认手势不可见，违背 P3** → 已加 CF-7 可发现性强制 + AC-CF-12（覆盖层常驻提示文字）+ #6 PREVIEWING 目标格脉冲高亮。保留无 CTA 设计。**复评点**：CF-7 + AC-CF-12 是否真正可测、#6 高亮是否登记。
2. **[game-designer + systems-designer] LOSE 路径伤害数字失真，违背「说到做到」** → CF-3 改 LOSE 不展示具体伤害，仅「会死」+ 主题；AC-CF-8a 同步。**复评点**：是否全文无残留「LOSE 显示掉 N 血」。
3. **[game-designer + CD] 单方面 void #6 Approved AC-COMB-7** → 已正式落地 #6 正文（M4步骤3、Dependencies(b)、_input 注释、AC-COMB-7→RESOLVED-VOID、AC-COMB-2b 解锁、AC-VIS-6 标记、OQ#1 关闭）+ systems-index #6/#10 同步。**复评点**：读 grid-movement.md 核实 CTA 要求确实消失（勿只信本 log）。
4. **[systems-designer + godot-specialist] Rect2 同帧缓存缺三引擎前提** → CF-4 禁用 Container/全手动定位 + 原子更新顺序；F-RECT CanvasLayer 坐标系方案 + 实测校验；CF-5 根 Control MOUSE_FILTER_STOP。**复评点**：Visual 布局是否仍暗示 VBox（与禁用 Container 矛盾）。
5. **[ux-designer] 布局物理不可行 + dp 换算** → OVERLAY_MIN_WIDTH 改内容自适应；dp 口径对齐 #6 逻辑分辨率；AC-CF-2 去硬编码 80px；OQ#4 最小尺寸线框。
6. **[ux-designer] 色盲适配仅 Open Question** → CF-3 色盲强制 BLOCKING（非颜色冗余标识）+ AC-CF-8a 节点存在断言；OQ 降为仅定形式。
7. **[qa-lead] 多条 AC 不可测** → AC-CF-1/4/7/8/9/10/11 按 qa-lead 改写；新增 AC-CF-5b/5c。

### 推荐项（已一并落实）
N_max 入 Tuning Knobs + 输入校验责任声明 + Autoload assert + 第3节标题改回 "Detailed Rules" + 动画默认瞬现 + #11/#13 补入 Dependencies 表 + AC-CF-5 改双路对比。

### 关键设计决策（用户拍板 2026-06-29）
- 确认可发现性：提示文字 + 怪物格高亮（二者并用）
- 跨系统冲突：保留无 CTA，授权同步修订 #6
- 布局几何：覆盖层改内容自适应/屏幕相对

### 跨系统同步文件
- `design/gdd/grid-movement.md`（#6，已 Approved）— CTA 相关全部修订
- `design/gdd/systems-index.md` — #6/#10 状态登记

---

## Review — 2026-06-29 — Verdict: NEEDS REVISION（第二轮复评）
Scope signal: M（同首轮）
Specialists: game-designer, systems-designer, ux-designer, godot-specialist, qa-lead, creative-director（综合裁决）
Blocking items: 5 | Recommended: 4
Prior verdict resolved: 首轮 7 阻塞项全部落实（其中 2 项派生新阻塞）

### 综合裁决（creative-director）
首轮修订工作量扎实，核心骨架（无 CTA + 双线索可发现性 + Rect2 缓存 + 色盲强制）质量可靠。残余阻塞集中在布局验算缺失、引擎行为描述错误、AC 可测性，和合规 scope-gate 全缺——无需骨架重写，聚焦收尾。本轮修订已全部落地。

### 5 个阻塞项（已在本轮修订落实）
1. **BLOCK-1（布局像素验算缺失）** → 删除「3格」下限，补充 ~116dp/5格 估算；× 独占顶行方案锁定；OQ#4 线框约束更新。复评点：Tuning Knobs 和 Visual 节「3格」已清除 ✓
2. **BLOCK-2（CF-5 MOUSE_FILTER_STOP 引擎行为描述错误）** → 修正为「STOP 仅防 _unhandled_input()，防格子误触的主要机制是 #6 _input() 中的 Rect2 判断」。复评点：CF-5 段落纠正 ✓
3. **BLOCK-3（多条 AC 不可落地）** → AC-CF-1 加场景树夹具前提；AC-CF-4 改正向断言；AC-CF-7a 改精确匹配；新增 AC-CF-7c（LOSE K值验证）；AC-CF-8a 锁定 lose_indicator 节点；AC-CF-9 加 col=12/col=3 边界；AC-CF-10 改 GDUnit4 运行时断言；AC-CF-11 层2 指定 grep 命令
4. **BLOCK-4（Anti-Pillars scope-gate AC 全缺）** → 新增 AC-CF-SCOPE-1/2/3（随机数 + 操作步骤 + 广告触发门禁）
5. **BLOCK-5（CF-7 覆盖层遮蔽目标格无约束）** → 新增 CF-7 覆盖层遮蔽约束（目标格 ≥ 1/2 格尺寸可见）+ 覆盖层默认锚定在目标格正上方

### 推荐项（已一并落实）
- REC-1: LOSE 路径第1行改为「你能撑 K 回合」（K = player_hp × n_rounds / total_dmg，整数除法）；show_overlay 加 player_current_hp 参数
- REC-5: AC-CF-7a contains → 精确匹配
- OQ#2 关闭：lose_indicator 节点名锁定，形式=「会死」文字 Label
- OQ#3 临时立场：允许 LOSE 确认，广告由 #17 负责，本系统 AC-CF-SCOPE-3 门禁

### 关键设计决策（用户拍板 2026-06-29）
- LOSE 第1行：「你能撑 K 回合」（K 精确值，显示层内部计算）
- LOSE 非颜色标识：「会死」文字 Label，节点名 lose_indicator
- × 按钮布局：独占顶部一行（≥40dp高），文字区在下方

### 待处理工作项（本轮未修订）
- ADR-0003 澄清：Autoload 持有 UI Control 节点是否被允许（派 technical-director + systems-designer，独立任务）
- #5 CombatForecast 是否需同步：show_overlay 新增 player_current_hp 参数须通知 #6（#6 已 Approved，接口变更须通知实现者）
