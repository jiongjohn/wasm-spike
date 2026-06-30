# Interaction Pattern Library

> **Status**: In Design
> **Author**: lumen + ux-designer
> **Last Updated**: 2026-06-29
> **Template**: Interaction Pattern Library
> **Input**: 纯触控单指 tap/swipe（抖音小游戏，无手柄）— technical-preferences.md
> **Visual authority**: design/art/art-bible.md（触控热区/色盲/构件/动画时序）

---

## Overview

本库收录《像素魔塔·无尽塔》全局复用的触控交互模式，作为后续屏幕规格（#10 预演覆盖层、#12 HUD 等）与实现的统一引用源。所有模式针对**纯触控单指**输入（无手柄、无键盘游戏流程）。

**权威分层**：
- 交互**行为**以对应系统 GDD 为权威（#6 grid-movement、#10 combat-forecast）。
- 交互的**视觉表现**（触控热区、色盘、UI 构件、动画时序）以 `design/art/art-bible.md` 为权威。

后续 UX 规格引用模式时**按名引用**（如「采用 P2 两步确认」），不重新定义。两条硬基线贯穿所有模式：
1. **触控热区 ≥ 44×44px**（art-bible §3.3；视觉像素可更小，热区加透明缓冲）。
2. **色盲安全双信道**（颜色 + 非颜色冗余标识，art-bible §4.3 / #10 CF-3）。

> **dp/px 口径**：#6/#10 GDD 用「dp」指项目逻辑分辨率下的逻辑像素（对齐 #6 整体 scale 方案，非 Android DPR）；art-bible 用「px」。本库统一标注 `≥44×44px(逻辑)`，实机可达性以目标设备实测为准（#6 AC-VIS-5 基线）。

---

## Pattern Catalog

| ID | 模式 | 类别 | 用于 | 一句话 |
|----|------|------|------|--------|
| P1 | 点格移动 | Navigation/Input | #6 | tap EMPTY 格 → BFS 寻路即点即达，无确认弹窗 |
| P2 | 两步确认（无 CTA） | Modal/Input | #6, #10 | tap 怪 → 预演 → 再 tap 同格确认；× 取消（无「进攻」按钮） |
| P3 | 预演覆盖层 | Overlay/Feedback | #10 | 锚点翻转 + 色盲安全的 WIN/LOSE 信息卡 |
| P4 | `_input()` Rect2 触控拦截 | Input（技术） | #6, #10 | 屏幕空间 Rect2 命中分流（× / 吞事件 / fallthrough 格子） |
| P5 | × 纯取消手势 | Modal | #6, #10 | 零副作用取消，任何周边格型都安全 |
| P6 | 目标格脉冲高亮 | Feedback | #6, #10 | PREVIEWING 期间目标怪物格呼吸高亮，引导「再 tap」 |
| P7 | tap 拒绝反馈 | Feedback | #6 | 不可达格抖动/闪烁（必装，Pillar 3 自解释） |
| P8 | 输入锁定 | Input | #6 | MOVING/LOCKED 期间丢弃 tap，不缓存不延迟 |
| P9 | 数值跳涨反馈 | Feedback | #11, art-bible | 飘字 + 行高亮 + 弹跳（峰值 ≤128ms，消退 ≤200ms） |
| P10 | 色盲安全双信道 | 横切 | 全局 | 颜色 + 非颜色冗余标识（形状/文字/动画） |
| P11 | HUD 属性槽渐进解锁 | Data Display | #12 | 初始 4 槽，蓝钥匙/碎片解锁后弹入 |
| P12 | 多指仅取首指 | Input | #6 | 同时多指只评估首个触点，其余忽略 |

> **⚠️ art-bible §7.5 待更新**：art-bible「伤害预演两步确认」仍画含「进攻」CTA 按钮的旧方案；#10 GDD（2026-06-29，creative-director 裁决）已改为「无 CTA + 再 tap 确认」（AC-COMB-7 → RESOLVED-VOID）。本库 P2/P3 以 #10 GDD 为权威；art-bible §7.5 须由 art-director 同步更新（见 Open Questions）。

---

## Patterns

### P1 — 点格移动（Tap-to-Move / 寻路）

**Category**: Navigation / Input
**Used In**: #6 GridMovement（M1/M2/F-REACH）

**Description**: 玩家单指 tap 网格中任意可达 EMPTY 格，PlayerMarker 经 BFS 寻路即点即达。这是 Pillar 3「三秒上手」最底层的承诺——一根手指、一个点按、一格位移，无确认弹窗、无「想去左边却被带去右边」的挫败。

**Specification**:
- 仅 IDLE 状态接受 tap（其余状态见 P8）。
- BFS **4 方向**（无对角），仅穿越 EMPTY / 已清除 ENTITY / 已开 DOOR / PLAYER_START（F-REACH 表）。
- 路径存在：PlayerMarker 沿路径移动，每格 `T_cell`（默认 50ms，≤2 帧@30fps），链式 Tween（`Tween.chain()`，不逐格 await）；进入 MOVING；**每到达一格发 `player_moved(new_pos)`**（每格一次，非整路径一次）。
- `path_length = 0`（tap 自身格）：忽略，无任何效果。
- 路径不存在 / 不可达：忽略此 tap，**必触发 P7 拒绝反馈**。
- 联合约束 `T_cell × MAX_PATH_LENGTH ≤ 1500ms`。

**When to Use**: 网格内位移到空格。
**When NOT to Use**: 目标为非 EMPTY 格（MONSTER 走 P2；ITEM/KEY/DOOR/STAIR 直接分发 `GameState.on_*_cell_entered`，进 LOCKED）。

**Reference**: #6 grid-movement.md M1/M2/F-REACH；art-bible §3.4（楼梯出口 2px 高亮锚）。

---

### P2 — 两步确认（无 CTA）

**Category**: Modal / Input
**Used In**: #6 GridMovement（M4），#10 CombatForecast（CF-3/CF-6）

**Description**: 破坏性操作（攻击怪物）的「知情同意」手势——把「计算结果」变成「玩家决策依据」，是 P2「算得清的确定性」从机制层浮现到操作层的关口。预演不是增加摩擦，而是「决策辅助 + 取消通道」。

**Specification**:
- tap 可达 MONSTER 格 → 调 `CombatForecastService.forecast_combat(6 int)` **一次** → 调 `show_overlay(forecast, col, row)` 显示 P3 覆盖层 → 进入 PREVIEWING。
- **确认唯一手势 = 再次 tap 同一怪物格**（落在覆盖层 Rect2 外，由 P4 fallthrough 命中）→ 进 LOCKED，调 `GameState.on_combat_cell_entered` + `hide_overlay()`。确认时**不重复**调 forecast_combat（复用首次结果）。
- **无「进攻」CTA 按钮**（creative-director 裁决，#6 AC-COMB-7 → RESOLVED-VOID）。可发现性由 **P6 目标格脉冲高亮** + 覆盖层常驻 `hint_label`「再次点击怪物进攻」共同保证（缺一不可，CF-7 BLOCKING）。
- 取消/转向：× 按钮（P5 纯取消）；点 EMPTY（取消+移动，进 MOVING）；点其他可达 ITEM/KEY/DOOR/STAIR（取消+分发，进 LOCKED）；点另一怪（切目标，保持 PREVIEWING）；点 WALL/不可达（回 IDLE）。

**When to Use**: 有不可逆后果的破坏性操作（攻击 = 必然受伤/可能死亡）。
**When NOT to Use**: 可逆 / 低风险操作（道具拾取、开门、上楼梯均一步直接分发，不加预演）。

**Reference**: #10 combat-forecast.md CF-3/CF-6/CF-7；#6 grid-movement.md M4。

---

### P3 — 预演覆盖层（Forecast Overlay）

**Category**: Overlay / Feedback
**Used In**: #10 CombatForecast（CombatForecastOverlay）

**Description**: 两步确认第一步的视觉层——一块锚定在目标格附近的信息卡，让玩家在实际战斗前看到「会发生什么」。兑现「说到做到」：只展示与实际结算一致的数字。

**Specification**:
- 由 `show_overlay(forecast, col, row)` 显示，`hide_overlay()` 隐藏；本系统只做「int→展示字符串」格式化，不做任何计算。
- **锚点翻转**：默认目标格正上方；col ≥ 13 → 左锚定；col ≤ 2 → 右锚定；目标格在屏顶 → 改正下方（CF-7 遮蔽约束：目标格 ≥1/2 格须在覆盖层 Rect2 外，供 P6 高亮可见）。
- **WIN**（`player_survives=true`）：标准色主题，三行「N 回合 / 掉 N 血 / 剩 N 血」。
- **LOSE**（`player_survives=false`）：红/警告色主题 + `lose_indicator`「会死」+「0 血」；**不展示任何推算数字**（无回合数、无伤害、无「能撑 K 回合」——根因 A：会被实际结算证伪的数字比不展示更糟）。
- 遵守 **P10 色盲双信道**（CF-3 BLOCKING）。
- 渲染层级 z_index ≥ 100 或独立 CanvasLayer；宽 ≥ 116px(逻辑，容纳 hint_label)；字 ≥12pt（提示行小字 ≥10pt）；出现 ≤150ms（默认瞬现）。
- 布局**禁用 Container**，全手动定位 Label（CF-4，保证同帧 `get_global_rect()` 正确）。

**When to Use**: 破坏性操作前展示确定性结果预览。
**When NOT to Use**: 无确定性可预览结果的操作；或会展示与实际结算不符的可证伪数字（宁可不展示——可证伪的错误数字先建立信任再摔碎，比不展示更糟，#10 根因 A）。

**Reference**: #10 combat-forecast.md CF-3/F-RECT/Visual；art-bible §7.5（待更新为无 CTA）。

---

### P4 — `_input()` Rect2 触控拦截分流（技术模式）

**Category**: Input（技术实现模式）
**Used In**: #6 GridMovement（方案 B），#10 CombatForecast（CF-4 Rect2 缓存）

**Description**: 浮层显示期间，触控事件的精确分流——不依赖 Godot GUI 传播路径（`_gui_input`/`mouse_filter`），而在 `_input()` 入口用屏幕空间 Rect2 命中判断决定事件去向。解决「浮层挡格子」与「确认手势落在浮层外格子」的并存需求。

**Specification**:
- 覆盖层提供 `get_overlay_screen_rect() -> Rect2` 与 `get_x_button_screen_rect() -> Rect2`，**均返回屏幕空间坐标**（与 `InputEventScreenTouch.position` 同坐标系），**均在 `show_overlay()` 时缓存**（防同帧布局未完成返回零矩形）；`hide_overlay()` 后置零矩形。
- GridMovement `_input()` 在 `_state == PREVIEWING` 时分流：
  1. 触点在 × 按钮 Rect2 内 → 执行 P5 取消 + `get_viewport().set_input_as_handled()`，不分发。
  2. 触点在覆盖层 Rect2 内但非 × → `set_input_as_handled()` 吞事件（无 CTA 分支，纯吞）。
  3. 触点在覆盖层 Rect2 外 → fallthrough 进格子点击逻辑（P1/P2）——确认进攻落此分支。
- `MOUSE_FILTER_STOP`（覆盖层根 Control）仅防 `_unhandled_input()`，对 `_input()` 无拦截作用；× 按钮 `MOUSE_FILTER_IGNORE`。
- **坐标系前提**：`stretch/mode = canvas_items` + Overlay CanvasLayer `follow_viewport_enabled = true`（ADR-0008 F-RECT 方案 a）；实机偏移由 QQ-ADR8-01 实测兜底。
- **引擎注意**（godot-specialist）：`_input()` 不受 `mouse_filter` 拦截；勿误用 `_gui_input()` 做命中判断，否则坐标系假设失效。

**When to Use**: 浮层需精确触控分流、且浮层与底层网格共坐标系时。
**When NOT to Use**: 标准 GUI 控件可用 Godot 焦点/`_gui_input` 链处理时（本游戏触控命中统一走此技术模式）。

**Reference**: #6 grid-movement.md Visual/Audio（方案 B）；#10 combat-forecast.md CF-4/F-RECT；ADR-0008。

---

### P5 — × 纯取消手势

**Category**: Modal
**Used In**: #6 GridMovement（AC-SM-11/AC-COMB-6），#10 CombatForecast（CF-5）

**Description**: 覆盖层上的 × 关闭按钮，是「绝对安全退出」通道——无论周边格子是什么类型，点击 × 一定只取消、零副作用。让「不打」成为和「打」同样合法的选择。

**Specification**:
- 点击 × → `hide_overlay()` + 回 IDLE；**不分发任何 `GameState.on_*`**，**不重复**调 `forecast_combat()`。
- 位置规则：始终位于「离目标格最远的角」——默认右上锚定 → 右上角；左锚定（col ≥ 13）→ **左上角**；右锚定（col ≤ 2）→ 右上角。降低想取消时误触目标怪物格触发确认的概率。
- 尺寸 ≥ 40×40px(逻辑)，图标 ≥16pt；`MOUSE_FILTER_IGNORE`（命中由 P4 `_input()` 负责，不靠 GUI 传播）。
- × 须在覆盖层 Rect2 内部安全区，不与格子触控区重叠。

**When to Use**: 任何需要保证「无副作用退出」的浮层。
**When NOT to Use**: 让 × 承载确认或其他动作（× 只取消；确认走 P2 再 tap）。

**Reference**: #10 combat-forecast.md CF-5；#6 grid-movement.md AC-SM-11/AC-COMB-6。

---

### P6 — 目标格脉冲高亮（可发现性线索）

**Category**: Feedback
**Used In**: #6 GridMovement（渲染），#10 CombatForecast（CF-7 协调要求）

**Description**: 当确认手势是「再次 tap 目标怪物格」这一对新玩家不可见的隐藏 affordance 时，用**呈现层**线索把视线引向「可再次点击的目标」。这是「用呈现层补可发现性，不靠加按钮/改机制」原则的实例。

**Specification**:
- 进入 PREVIEWING 后，GridMovement 对**目标怪物格**施加低频脉冲/高亮（呼吸式 alpha 或描边），持续至离开 PREVIEWING。
- 建议旋钮 `PREVIEW_HIGHLIGHT_PERIOD`（默认 ~600ms 一个脉冲周期）。
- 与覆盖层常驻 `hint_label`「再次点击怪物进攻」**共同**保证可发现性（CF-7 BLOCKING，缺一不可）。
- 归 #6 网格渲染（#10 不跨域绘制格子）；由 ADR-0009 的池化覆盖节点承载（非 256 常驻 CellNode，禁 cell 级 `_process`，用 Tween/AnimationPlayer）。
- 覆盖层布局须保证目标格 ≥1/2 格在覆盖层 Rect2 外，高亮才可见（P3 锚点/遮蔽约束）。

**When to Use**: 隐藏 affordance（无显式控件的手势）需要可发现性补强。
**When NOT to Use**: 用它替代一个本应存在的明确控件去**改变机制**——呈现层只补可发现性，不新增 CTA 按钮。

**Reference**: #10 combat-forecast.md CF-7；#6 grid-movement.md Visual/Audio（PREVIEWING 目标格脉冲高亮）；ADR-0009。

---

### P7 — tap 拒绝反馈

**Category**: Feedback
**Used In**: #6 GridMovement（M1/TK-3/AC-VIS-2）

**Description**: 任何被忽略的 tap 都必须有可见反馈。静默无反馈让玩家无法区分「我的精度失误（没点准）」与「路径被阻塞（点准了但去不了）」——违反 Pillar 3「三秒上手」的自解释原则。

**Specification**:
- tap WALL / 不可达格 / 路径不存在 → 目标格轻抖或半透明闪烁。
- 时长 `REJECT_FEEDBACK_DURATION`（默认 150ms，安全范围 80–300ms）：< 80ms 玩家不确定是否点到；> 300ms 变错误惩罚感。
- **必装**（非可选，Pillar 3）。
- 须经**可注入接口**触发（如 `_play_reject_feedback(col,row)` 虚方法或可替换 AnimationPlayer），便于测试 mock animation driver（AC-VIS-2）；不在逻辑层直接 new Tween。
- 不构成状态变化（仍 IDLE）。

**When to Use**: 任何被丢弃 / 忽略的玩家 tap。
**When NOT to Use**: 合法成功操作（合法操作有其自身的成功反馈，如移动动画/预演出现）。

**Reference**: #6 grid-movement.md M1/TK-3/AC-VIS-2；art-bible §3.4（拒绝=非进入态，不留残影）。

---

### P8 — 输入锁定（Input Lock）

**Category**: Input
**Used In**: #6 GridMovement（M5）

**Description**: 系统处理事件或播放动画期间，丢弃所有 tap，防止战斗结算/移动期间的误触积压导致连续触发。

**Specification**:
- MOVING / LOCKED 状态下所有 tap **直接丢弃，不缓存、不延迟、零副作用**。
- LOCKED 经 `GameState.grid_unlock` 信号解除 → IDLE。
- PREVIEWING 防御性：`grid_unlock` 在 PREVIEWING 到达 → 关覆盖层回 IDLE（异常保守处理）。
- 可选 `LOCK_TIMEOUT_MS`（默认 5000，0=禁用，范围 0–10000）：超时未收 `grid_unlock` → 强制回 IDLE + `push_error`（不通知 GameState）。
- 计时器须依赖注入（禁硬编码 SceneTree Timer，AC-LOCK-5b），便于测试 `simulate_frames` 推进。

**When to Use**: 系统处理事件 / 播放不可打断动画期间。
**When NOT to Use**: IDLE 状态（IDLE 必须即时响应，否则违反 P1「即点即达」承诺）。

**Reference**: #6 grid-movement.md M5/AC-LOCK-1..6。

---

### P9 — 数值跳涨反馈

**Category**: Feedback
**Used In**: #11 NumberFeedback（待设计），art-bible §7.6 / §3.4
**Status**: ⚠️ Provisional — #11 NumberFeedback GDD 未写；基线取自 art-bible，#11 设计时以本模式为输入。

**Description**: 核心循环（P1「看得见的成长」）的即时正反馈——把抽象的属性变化变成「那个数变大了」的可感冲击。数字永远是第一等公民（对比度高于图标）。

**Specification**:
- **属性增加**：整行背景 B6 → M1 黄金（1 帧）→ 数字上移 2px 弹起（1–2 帧）→ 回位（3–4 帧）→ 背景渐褪回 B6（5–8 帧）。总时长 ~128ms。
- **HP 减少（受伤）**：整行背景 B6 → B4 亮红（1 帧）→ 数字下移 1px（压制感）→ 背景褪回。总时长 ~128ms。
- **升级**：全屏白色矩形帧 1–2 帧全覆盖后消失（FC「屏幕爆炸」，与塔外框同构）。
- **伤害飘字**：加粗等宽像素字 1.5–2×，向右上 45° 飘移 + 1px 暗描边（45° 在直角世界中异质 → 制造冲击）；浮在角色格正上方（接近律，因果免教学）。
- 动画峰值 ≤128ms，消退 ≤200ms（art-bible §7.8 QA）。
- 遵守 **P10**（升级亮黄飘字 vs 金钥匙靠动画+时间维度区分）。

**When to Use**: 核心成长数值（HP/ATK/DEF/MaxHP/金币）变化的即时反馈。
**When NOT to Use**: 非成长性数字（如楼层号变更用进程感呈现，不用爆炸反馈）。

**Reference**: art-bible §7.6（HUD 动画感）/ §3.4（成长反馈形状语言）；#11 NumberFeedback（待 GDD）。

---

### P10 — 色盲安全双信道（横切基线）

**Category**: 横切（Cross-cutting）
**Used In**: 全局（#10 CF-3 BLOCKING，art-bible §4.3，所有语义色编码）

**Description**: 任何用颜色编码语义的元素，必须叠加至少一个**非颜色冗余信道**，确保 ~8% 红绿色盲玩家无需分辨颜色即可判断。这是不可谈判的设计基线，不是可选增强。

**Specification**:
- 冗余信道可选：**形状 / 文字标签 / 图标 / 动画（时间维度）/ 边框形状**之一。
- 已知冲突对处置（art-bible §4.3）：
  - 红怪(M5) vs 绿药水(M8) → 形状不同（非人形剪影 vs 圆瓶形）。
  - ATK 橙(M9) vs HP 绿(M8) → 剑形 vs 瓶形。
  - 升级亮黄飘字(B2) vs 金钥匙(M1) → 飘字有上浮消隐动画，钥匙静态（时间信道）。
  - 蓝门(M3) vs DEF 装备(M10) → 门框形 vs 盾牌形。
- **LOSE 预演**：红/警告主题 + `lose_indicator`「会死」文字 Label（#10 CF-3 BLOCKING，AC-CF-8a）。
- **死亡预警**：红背景 + 0.5Hz 边框闪烁（颜色 + 时间双信道，art-bible §7.5/§7.8）。
- 对比度基线 WCAG AA ≥ 4.5:1。

**When to Use**: 任何承载语义的颜色编码（状态、阵营、胜负、资源类型）。
**When NOT to Use**: 纯装饰色（无语义负载则无需冗余信道）。

**Reference**: art-bible §4.3（色盲安全检查）/ §7.8（QA 清单）；#10 combat-forecast.md CF-3。

---

### P11 — HUD 属性槽渐进解锁

**Category**: Data Display
**Used In**: #12 HUD（待设计），art-bible §7.8
**Status**: ⚠️ Provisional — #12 HUD GDD 未写；基线取自 art-bible，#12 设计时以本模式为输入。

**Description**: HUD 初始只显示核心 4 槽，进阶资源在玩家首次获得时才弹入对应槽位——降低首屏认知负荷，服务 P3「三秒上手」。

**Specification**:
- 初始可见：HP / ATK / DEF / 楼层数（核心 4 槽，始终显示）。
- 后置弹入：蓝钥匙数、碎片数等在玩家**首次获得**时弹入对应槽（而非一开始就显空槽/0）。
- 弹入用轻量动画（与 P9 一致的弹跳/淡入，≤128ms 峰值）。
- DEF 首次战斗微教学：第一次战斗结算后高亮 DEF 旁显示「防御减少了 X 点伤害」一行，仅出现一次，永不重复（art-bible §7.6）。

**When to Use**: 尚未解锁 / 尚未获得的进阶资源的渐进披露。
**When NOT to Use**: 核心 4 属性（必须始终显示，不可隐藏）。

**Reference**: art-bible §7.8（属性槽逐步解锁）/ §7.6（DEF 微教学）；#12 HUD（待 GDD）。

---

### P12 — 多指仅取首指

**Category**: Input
**Used In**: #6 GridMovement（AC-LOCK-4 / AC-EC-1）

**Description**: 同时多指触屏时只评估第一个触点，防止低端机多点误触产生歧义行为。

**Specification**:
- 多指同时接触 → 只评估**第一个手指**的位置；后续手指在该手势生命周期内忽略。
- 结果等同于首指位置的单击（如首指 WALL + 二指 EMPTY → 只判 WALL → 忽略，二指 EMPTY 不触发移动）。

**When to Use**: 所有触控命中判断（贯穿 P1/P2/P4/P5）。
**When NOT to Use**: 若未来引入双指手势（缩放/旋转）——本游戏无此需求。

**Reference**: #6 grid-movement.md AC-LOCK-4 / AC-EC-1。

---

## Gaps & Patterns Needed

- **P9 数值跳涨反馈 / P11 HUD 属性槽渐进解锁为 Provisional**：源系统 #11 NumberFeedback、#12 HUD 尚未写 GDD（systems-index 标 Not Started）。当前基线取自 art-bible；待 #11/#12 GDD 完成后回填权威行为并去除 Provisional 标记。
- **未规格化的屏幕**：标题/主菜单、GameOver/通关结算、商店（#16 VS）、激励广告流程（#17 VS）、设置页均无 UX 规格。这些屏幕设计时应**引用本库现有模式**而非重定义；新出现的模式回填本库。
- **预判新模式：激励广告触发确认（VS）**：#17 激励广告须满足 Anti-Pillar「激励广告触发点均为玩家主动触发」——届时需要一个「玩家主动 opt-in 看广告」确认模式（与 P2 两步确认精神一致：知情同意，非强制弹窗）。LOSE 预演是全游戏最自然的广告触发点（#10 AC-CF-SCOPE-3 已门禁 #10 侧不主动触发），该模式的所有权属 #17。
- **模式一致性**：P5（× 纯取消）与 P8（输入锁定）都涉及「丢弃输入」，但语义不同（P5 是主动取消手势，P8 是状态性拦截），保持独立，不合并。

---

## Open Questions

1. **Player journey map 缺失** `[建议补]`：`design/player-journey.md` 不存在。模板见 `.claude/docs/templates/player-journey.md`。补齐后可为各模式补充「玩家在何种情绪/阶段触发该交互」的上下文。
2. **无障碍层级未正式定义** `[建议 WCAG-AA 基线]`：无 `design/ux/accessibility-requirements.md` 或 `design/accessibility-requirements.md`。art-bible §4.3（色盲安全）+ §7.8（QA 清单）提供事实基线（已被 P10 吸收），但缺一份正式的层级承诺文档。建议以 WCAG-AA（对比度 ≥4.5:1、色盲双信道、触控热区 ≥44px、字 ≥12pt）为基线另起草一份。`/gate-check` 可能因缺此文档阻断。
3. **art-bible §7.5 与 #10 无 CTA 决策冲突** `[待 art-director]`：art-bible §7.5 仍画含「进攻」CTA 按钮的旧两步确认方案；#10 GDD（2026-06-29，creative-director 裁决）已废止 CTA（AC-COMB-7 → RESOLVED-VOID）。本库 P2/P3 以 #10 为权威；art-bible §7.5 须由 art-director 走 `/propagate-design-change` 或手动同步更新（删除「进攻」按钮，改为「无 CTA + 再 tap + × 取消」+ P6 高亮 + hint_label）。
4. **触控尺寸口径 44px vs 40dp** `[实机校准]`：art-bible 用「≥44×44px」，#6/#10 GDD 用「40dp 目标」。本库已统一标注 `≥44×44px(逻辑)` 并说明 dp=逻辑像素口径，但 16 列密集网格下单格实际约 22dp（#6 AC-VIS-5），与孤立按钮 40/44 标准情境不同。最终可达性须在 360dp 竖屏低端机实机校验（#6 AC-VIS-5：≤10% 误触率基线）。

---

## Cross-Reference Check（2026-06-29）

- **GDD 覆盖**：#6/#10 的交互定义已全部映射到 P1-P8/P12；#11/#12 的 art-bible 基线映射到 P9/P11（Provisional）。无遗漏。
- **新增模式**：本库为首次建立，12 个模式均为从既有 GDD/art-bible 提取，无凭空新增。
- **导航一致性**：尚无其他 UX 规格可比对（design/ux/ 仅本文件）。
- **无障碍覆盖**：P10 吸收 art-bible 色盲基线；正式无障碍层级文档缺失（Open Q#2）。
- **冲突已记**：art-bible §7.5 CTA 冲突（Open Q#3）。
