# 战斗预演系统 (CombatForecast)

> **Status**: In Revision（首轮 MAJOR REVISION → 第二轮 NEEDS REVISION → 第三轮 2026-06-29 MAJOR REVISION：根因 A「LOSE K 公式数学错误」+ B「show_overlay 接口未同步」已修订；根因 D「ADR-0003 宿主裁决」方向已定（拆 Service+Overlay），ADR 正式落地待 technical-director，第4轮复评前须完成）
> **Author**: lumen + agents
> **Last Updated**: 2026-06-29
> **Implements**: P2「确定性+容错」 / **Enables**: P2「两步确认」

## Overview

战斗预演系统（CombatForecast）是《像素魔塔·无尽塔》**两步确认战斗机制的第一步视觉层**：当玩家在 PREVIEWING 状态点击怪物格，本系统立即展示「如果现在打这只怪，会发生什么」——回合数、血量变化、胜负判断——让玩家在**实际战斗开始前看到结果**。数据来源是 #5 确定性回合战斗系统的 `forecast_combat()` 纯函数（同一套公式，零随机数），本系统不运行任何独立计算，只负责**把结算结果翻译成一块覆盖层 UI**。

玩家与本系统的交互路径：tap 怪物格 → #6 进入 PREVIEWING → 调用 `CombatForecastService.forecast_combat()` 获取 `CombatForecast` 对象 → `CombatForecastOverlay.show_overlay(forecast, col, row)` 展示预演卡片 → 玩家看到数字 → 再次 tap 同一怪物格确认进攻，或点 ×取消。两步确认的目的不是增加摩擦，而是把「计算结果」变成「玩家决策依据」——这是 P2「算得清的确定性」从机制层浮现到体验层的关口。

> **宿主拆分（2026-06-29 第三轮裁决，根因 D）**：本系统拆为两个对象——**`CombatForecastService`（Autoload，纯无状态代理 #5 `forecast_combat()`）** + **`CombatForecastOverlay`（Scene Node，持有覆盖层 UI Control 子树、缓存 Rect2）**。理由：ADR-0003 禁止 Autoload 持有具体 Scene Node 引用，原「单一 Autoload 持有 UI」判定与该规则冲突。**ADR-0003 的正式修订（含 Overlay 的挂载点与 #6 对 Overlay 4 个 UI 接口的访问方式）须由 technical-director 走 `/architecture-decision` 落地，本 GDD 仅在设计层记录拆分方向**——5 个接口的语义不变，仅宿主对象名变化（见接口契约）。

本系统还提供两个屏幕空间 Rect2 接口（`get_overlay_screen_rect()` / `get_x_button_screen_rect()`），供 #6 在 `_input()` 中做触控事件拦截（方案B，ADR-0003 模式，全局名调用，不直接访问 Control 内部节点）。两个 Rect2 均在 `show_overlay()` 时缓存，防止 CanvasLayer 布局延迟返回零矩形。

## Player Fantasy

**「我算得准，所以我敢打。」**

预演覆盖层是「P2 确定性」的触觉证明——它把抽象的「无随机数战斗」变成玩家可以亲手指着说「看，这里写着 4 回合、掉 20 血、胜」的具体事物。玩家在预演出现的瞬间，已经做完了决策：血够多就 tap 确认，血不够就按 × 找别的路。这份掌控感不来自实力，而来自**信息对等**——玩家和游戏知道的是同一套数字。

**三个必须兑现的情感时刻：**
- **「一看就懂」**：数字出现不超过 150ms，格式简单，不需要玩家推算——「4 回合」「掉 20 血」「胜」，三个词看完决策就做好了。**且确认手势必须可发现**：覆盖层不仅要让玩家看懂数字，还要让玩家**看懂如何执行决定**（见 CF-7 可发现性要求）——「能看懂数字」但「找不到怎么打」不满足 P3「三秒上手」。
- **「说到做到」**：实际战斗结算的结果与预演分毫不差。第一次验证后玩家就会信任预演，以后直接用它做判断而不是焦虑等待。**因此预演只展示与实际结算一致的数字**——WIN 路径展示精确受伤量；LOSE 路径**不展示任何数字**（既不展示总伤害理论值，也不展示「能撑几回合」），改为纯定性的**「会死」警告**（红色主题 + 非颜色冗余标识，见 CF-3）。**设计依据（第三轮裁决，根因 A）**：任何 LOSE 数字都需要 `monster_dmg`/逐回合序列才能精确推出，而该数据不在 `CombatForecast` 字段内——展示层自行推算必然失真（已证明 `K = hp × n_rounds / total_dmg` 误差方向不定）。一个**可证伪的错误数字比不展示数字更糟**：它会先建立信任再摔碎。定性「会死」结构上永远不可证伪，恒守「说到做到」；且避免让轻用户为「能撑几回合」做心算（服从 P3「三秒上手」）。
- **「可以不打」**：× 按钮明显且可达（≥40dp 目标），不打是一个和打同样合法的选择——预演不是「警告再次确认」，而是「决策辅助 + 取消通道」。预演出现时玩家感受到的不是摩擦，而是控制权在手。

*服务支柱*：P2「算得清的确定性」——本系统是 P2 从公式层浮现到感知层的界面。P3「三秒上手」要求覆盖层呈现零学习成本（能看懂、且能上手就能用），UI 设计必须服从这一原则。

## Detailed Rules

### Core Rules

**CF-1 — 调用触发（由 #6 驱动，本系统被动）**
本系统不主动监测玩家动作。#6 进入 PREVIEWING 状态后调用 `show_overlay(forecast, col, row)`；#6 退出 PREVIEWING 时调用 `hide_overlay()`。本系统不访问 #6 内部状态，也不订阅 #6 信号——接口方向是 #6 → 本系统（主动调用），不是信号驱动。

**CF-2 — forecast_combat 转调（单次触发，非轮询）**
#6 在每次 PREVIEWING 进入时自行调用 `forecast_combat(…)` 并将结果传给 `show_overlay()`。本系统的 `forecast_combat()` 是对 #5 同名纯函数的**直接转调**（Autoload 代理接口），不自行实现任何战斗数学。`forecast_combat()` 每次 PREVIEWING 进入时调用**一次**，不在 `_process()` 轮询——ADR-0006 风险缓解约束。

**输入合法性责任声明**：本系统代理层**不执行任何输入校验**，6 个 int 参数的合法性前置责任在调用方 #6（由 #1 EntityDB / #4 PlayerStats 的确定性只读查询保证）。若 #6 传入违反 #5 设计约束的极值（如 `player_atk ≤ monster_def` 致 `net_dmg` 退化、或 `n_rounds` 超出 #3 的 `N_max`），本系统**原样展示 #5 的返回值，不做 clamp、不拦截、不报错**——防御在调用方，不在被调用方（与 Edge Cases 末条一致）。

**CF-3 — 覆盖层内容（信息展示 + × 取消，无 CTA 确认按钮）**
覆盖层是**纯信息展示 + 取消通道**，不包含「确认进攻」按钮。确认进攻的唯一手势是**再次 tap 同一怪物格**（在覆盖层 Rect2 外，由 #6 `_input()` 正常接收）；该手势的可发现性由 CF-7 保证。覆盖层内的可交互元素**只有 × 关闭按钮**（取消，回 IDLE）。

展示字段（来自 `CombatForecast`，见 #5 F-FC）。**本系统对所有字段只做「int → 展示字符串」格式化，不做任何计算、取整或推导**（恢复 Overview / Formulas 节声明的范围边界）：
- `n_rounds`：**仅 WIN 路径**展示「需要 N 回合」（N 的上界由 #3 `N_max` 决定，见 Tuning Knobs）。**LOSE 路径不展示回合数**——见下「LOSE 不展示任何数字」。
- `total_damage_to_player`：**仅 WIN 路径**展示「会掉 N 血」。LOSE 路径**完全不读取、不展示**该字段——#5 F-FC 明确该字段在 LOSE 下为理论值（打满 N 轮，与实际不符），任何形式的展示或二次推算都会破坏「说到做到」。
- `player_survives`：驱动 WIN/LOSE 颜色主题与非颜色冗余标识（不直接展示文字）。
- `predicted_hp_after`：WIN 路径展示「打完剩 N 血」；LOSE 路径该字段恒为 0，展示「0 血」（不附带任何伤害/回合数字）。

**LOSE 不展示任何数字（第三轮裁决，根因 A）**：当 `player_survives = false`，覆盖层**不展示任何由 `CombatForecast` 推算的数字**（无回合数、无伤害量、无「能撑几回合」），仅展示：
1. 红色/警告色主题（驱动自 `player_survives`）；
2. 非颜色冗余标识 `lose_indicator`（「会死」文字 Label，OQ#2 已锁定）；
3. `predicted_hp_after = 0` → 「0 血」。

**为何不展示「能撑 K 回合」**：真实死亡回合 = `ceil(player_current_hp / monster_dmg)`，需要 `monster_dmg`（= `max(0, monster_atk − player_def)`）；该值**不是 `CombatForecast` 的字段**，本系统无法在不重新实现 #5 战斗数学的前提下正确算出（自算公式已证明误差方向不定、系统性失真）。展示一个会被实际结算证伪的数字，比不展示更严重。如未来确需向玩家传达 LOSE 差距，须由 #5 在 `CombatForecast` 中输出权威字段（如 `rounds_survived`，#5 `generate_round_sequence` 已计算），再由本系统忠实展示——该方向交 #5 走 `/propagate-design-change`，**不在本系统内自算**。

**WIN / LOSE 视觉主题（已锁定）**：
- `player_survives = true`（WIN）：覆盖层使用标准颜色方案（白底/亮色文字）。
- `player_survives = false`（LOSE）：覆盖层整体或数字区域切换为**红色/警告色主题**（具体色值见 Visual/Audio Requirements），**并且必须叠加至少一个不依赖颜色的冗余 LOSE 标识**（图标 / 文字标签 / 边框形状之一，见下条 CF-3 色盲约束），确保玩家无需分辨红绿即可判断危险。

**CF-3 色盲适配约束（BLOCKING 强制，非可选）**：LOSE 状态**不可仅依赖红色/警告色区分**。覆盖层必须在 LOSE 路径包含**至少一个非颜色冗余标识**——可选形式（骷髅图标 / 「会死」文字标签 / 「！」前缀 / 边框形状变化）由艺术指导在此约束内选定（见 Open Questions #1/#2），但「存在非颜色 LOSE 标识」本身是不可谈判的设计基线，纳入 AC-CF-8 验证。

**CF-4 — 屏幕空间 Rect2 缓存（#6 触控拦截前提）**
`show_overlay()` 调用时立即在同一帧内将覆盖层 Control 的屏幕空间 Rect2 和 × 按钮 Rect2 缓存到私有变量：
```
_cached_overlay_rect: Rect2   # 覆盖层整体，供 get_overlay_screen_rect()
_cached_x_btn_rect: Rect2     # × 按钮子区域，供 get_x_button_screen_rect()
```
缓存时机：`show_overlay()` 函数体内、在任何 `await` 或信号延迟之前。禁止在 `_process()` 或其他帧动态更新——覆盖层位置在 `show_overlay()` 调用后固定（锚点翻转由 `show_overlay(col, row)` 参数一次性计算）。

**布局节点约束（保证同帧 `get_global_rect()` 正确，BLOCKING 实现前提）**：覆盖层 Control 树中**不得有任何 Container 祖先节点**（VBoxContainer / HBoxContainer / GridContainer / CenterContainer 等），也不得依赖 `anchors_preset` 自动布局。原因：Godot 4.x 的 Container 通过 `NOTIFICATION_SORT_CHILDREN` **延迟到帧末**排布子节点，在 `show_overlay()` 同帧内调用 `get_global_rect()` 会返回排布前的旧坐标。三行文字内容须用**手动 `position`/`size` 定位的 Label 节点**实现（不用 VBoxContainer 堆叠）。

**原子更新顺序约束**：`show_overlay()` 内部更新顺序须为「(1) 设置内容文字 →(2) 设置 Control position/size →**(2a) 强制同帧刷新 transform**：直接赋值 `position`/`size`（无 Container）后，须确保 global transform 已在同帧同步再读 `get_global_rect()`——禁用 Container 是必要但不充分条件，因 Control 的 global transform 与 minimum-size 缓存在 Godot 4.x 中可能懒求值/延迟一帧。实现须显式触发同步（如赋值 `size` 后 `reset_size()` 或验证 `get_global_rect()` 已反映新 size 的等效机制），并以 AC-CF-1 黑盒断言兜底 →(3) 相邻两次赋值更新 `_cached_overlay_rect` 与 `_cached_x_btn_rect`，中间不发任何信号 →(4) 返回」。两个缓存变量的赋值必须相邻，避免信号重入读到「一个已更新、另一个未更新」的不一致中间态。

Getter 直接返回缓存值：
- `get_overlay_screen_rect() -> Rect2`：返回 `_cached_overlay_rect`（屏幕空间坐标，与 `InputEventScreenTouch.position` 同坐标系）
- `get_x_button_screen_rect() -> Rect2`：返回 `_cached_x_btn_rect`（同上）

`hide_overlay()` 调用时将两个缓存置为 `Rect2()` 零矩形，防止覆盖层隐藏后仍被 #6 命中判断误用。

**CF-5 — × 按钮与 mouse_filter 定义（≥40dp 目标，位置规则继承 #6）**
- **× 按钮** `MouseFilter = MOUSE_FILTER_IGNORE`（不干扰 #6 `_input()` 对触控的统一处理）。尺寸 ≥ 40×40dp 目标（实际下限受覆盖层几何约束，见 Tuning Knobs `OVERLAY_MIN_WIDTH` 与布局说明），字号 ≥ 16pt。位置规则（来自 #6，已锁定）：始终位于「离目标格最远的角」——默认右上锚定 → 覆盖层右上角；左锚定（col ≥ 13）→ 覆盖层**左上角**；右锚定（col ≤ 2）→ 右上角。
- **覆盖层根 Control** `MouseFilter = MOUSE_FILTER_STOP`：防止覆盖层内的触控事件到达 `_unhandled_input()`（Godot 4 中 `MOUSE_FILTER_STOP` 对 `_input()` 无拦截作用）。**防止格子意外触发的主要机制是 #6 `_input()` 中对 `get_overlay_screen_rect()` 的 Rect2 命中判断**——#6 在 `_input()` 中先检查触点是否在覆盖层 Rect2 内，再决定是否 fallthrough 到格子点击路径；`MOUSE_FILTER_STOP` 是面向其他 `_unhandled_input()` 路径的防御性配置。

**CF-6 — CTA 区域声明（无；与 #6 已同步对齐）**
本系统**不定义覆盖层内的 CTA 确认区域**。`get_overlay_screen_rect()` 返回覆盖层整体 Rect2，不划分子区域。确认进攻的唯一手势是再次 tap 怪物格（覆盖层 Rect2 外）。

> **跨系统同步状态（2026-06-29 评审）**：#6《网格移动》原 AC-COMB-7 及 Dependencies 曾硬性要求 #10 定义显式 CTA 确认区域作为主要确认路径。本次评审经 creative-director 裁决**采用「无 CTA + 再 tap 确认」设计**，并**已同步修订 #6 正文**（删除 CTA 确认分支、AC-COMB-7 改为 RESOLVED-VOID、回退 systems-index 登记）。本条不再是单方面声明——接收方文档 #6 已实际落地该变更。

**CF-7 — 确认手势可发现性（BLOCKING 强制）**
由于不存在显式「进攻」按钮，「再次 tap 怪物格确认」是一个对新玩家不可见的手势。为兑现 P3「三秒上手」，覆盖层显示期间**必须同时提供两个可发现性线索**：
1. **覆盖层内常驻提示文字**（`hint_label`，归本系统 #10）：覆盖层内常驻一行小字指令，如「再次点击怪物进攻」。该文字是覆盖层布局的固定组成部分（计入布局几何，见 Visual/Audio Requirements），不随胜负主题消失。**视觉优先级增强（呈现层，game-designer 第三轮建议）**：`hint_label` 位于覆盖层底部 + 10pt 小字，在「读数字→找按钮」的注意力高峰易被忽略——建议首次显示时给 `hint_label` 轻微强调（短暂下划线出现动画或一次性闪烁，≤150ms，不引入 CTA 按钮、不改机制），把视线引导到确认入口。此为呈现层调优，不改 AC-CF-12 的「存在且 visible」基线。
2. **目标怪物格脉冲高亮**（归 #6 网格渲染）：#6 在 PREVIEWING 状态期间对目标怪物格施加低频脉冲/高亮，把玩家视线引向「可再次点击」的目标。本系统不跨域绘制 #6 的格子——此线索登记为对 #6 的接口/协调要求（已写入 #6 Visual Requirements）。

**CF-7 覆盖层遮蔽约束（BLOCKING 强制）**：覆盖层布局须保证**目标怪物格的至少一个可见像素区域（建议 ≥ 1/2 格尺寸，约 11dp）在覆盖层 Rect2 之外**，确保脉冲高亮在覆盖层存在时仍可被玩家感知。实现约束：
- 覆盖层默认锚定在目标格**正上方**（y 方向不延伸到目标格中心），而非直接覆盖目标格
- 若目标格位于屏幕顶部边界致使覆盖层无法在上方展示，则改为**正下方**锚定
- OQ#4 最小尺寸线框图须明确验证：在最小内容（中间列）场景下目标格不被完全遮蔽

> 设计原则：可发现性用**呈现层**（提示文字 + 高亮）解决，不通过引入 CTA 按钮改变机制——保持「无 CTA」的简洁与「两步确认」的克制。

### States and Transitions

| 状态 | 进入条件 | 行为 |
|------|----------|------|
| **Hidden** | 初始 / `hide_overlay()` 调用后 | 覆盖层不可见；两个 Rect2 缓存为零矩形；不接受触控 |
| **Visible** | `show_overlay(forecast, col, row)` 调用 | 覆盖层可见；两个 Rect2 已缓存；提示文字 + × 按钮可达；等待 #6 决策 |

转换：Hidden → Visible（`show_overlay()` 调用）；Visible → Hidden（`hide_overlay()` 调用）。`show_overlay()` 在 Visible 状态再次调用时（#6 切换目标怪物）：按 CF-4 原子更新顺序更新内容、位置与两个 Rect2 缓存，不经过 Hidden 中间态，避免单帧 Rect2 = 零矩形的竞争条件。

### Interactions with Other Systems

| 系统 | 方向 | 内容 |
|------|------|------|
| #5 确定性回合战斗 | ← 转调 | `forecast_combat(6 int params) -> CombatForecast`（代理 #5 同名纯函数，不重复实现战斗数学） |
| #6 网格移动与交互 | ← 被调用 / → 协调 | 接收 `show_overlay()`、`hide_overlay()`；提供 `forecast_combat()`（代理）、`get_overlay_screen_rect()`、`get_x_button_screen_rect()`。**→ 协调**：CF-7 目标怪物格脉冲高亮归 #6 渲染（#6 Visual Requirements 已登记） |
| #1 实体数据库 | (间接) | 通过 #6 传参，本系统不直接读 #1 |
| #4 玩家属性与成长 | (间接) | `player_current_hp` 通过 #6 传参，本系统不直接读 #4 |

**本系统对外接口（完整契约，按宿主拆分 — 根因 D）**：5 个接口的签名与语义不变，仅分属两个宿主对象。`show_overlay` **退回 3 参**（不再传 `player_current_hp`，因 LOSE 不再自算 K — 根因 A/B）。

```gdscript
# ── CombatForecastService（Autoload，纯代理）──
# 转调 #5 forecast_combat（每次 PREVIEWING 进入单次调用，非轮询；代理层不校验输入）
func forecast_combat(monster_hp: int, monster_atk: int, monster_def: int,
                     player_atk: int, player_def: int, player_current_hp: int) -> CombatForecast

# ── CombatForecastOverlay（Scene Node，持有 UI + Rect2 缓存）──
# 显示预演覆盖层（原子操作：内容 + 位置 + Rect2 缓存同帧完成，更新顺序见 CF-4）
func show_overlay(forecast: CombatForecast, col: int, row: int) -> void

# 隐藏覆盖层（清空 Rect2 缓存为零矩形）
func hide_overlay() -> void

# 返回覆盖层屏幕空间 Rect2（show_overlay() 时缓存；hide_overlay() 后为 Rect2()）
func get_overlay_screen_rect() -> Rect2

# 返回 × 按钮屏幕空间 Rect2（show_overlay() 时缓存；hide_overlay() 后为 Rect2()）
func get_x_button_screen_rect() -> Rect2
```

> **注**：`forecast_combat` 的 `player_current_hp` 参数保留不变（那是 #5 的纯函数签名，用于计算 `player_survives`/`predicted_hp_after`）。本次去掉的是 **`show_overlay` 的** `player_current_hp`——它原本只为 LOSE 自算 K 而加，现 LOSE 不展示数字，不再需要，故 `show_overlay` 与 #6 现有的 3 参调用一致（#6 无需改动该签名）。

**Autoload 启动顺序约束（ADR-0002 / ADR-0003）**：`CombatForecastService`（Autoload，原列表 [9]）转调 #5（CombatSystem，列表 [5]）。其 `_ready()` 须包含 `assert(CombatSystem != null)`（并在 CombatSystem 提供初始化标志时追加 `assert(CombatSystem.is_initialized)`），作为启动顺序错误的早期失败点。`CombatForecastOverlay` 为 Scene Node，不参与 Autoload 启动顺序；其 `_ready()` 不依赖 Service 初始化（仅在 `show_overlay()` 接收数据时被动渲染）。Overlay 的具体挂载点与 #6 对其 4 个 UI 接口的访问方式待 ADR-0003 修订（technical-director）确认。

## Formulas

> **范围边界**：本系统不定义任何战斗数学公式。所有预演数值均来自 #5 `forecast_combat()` 纯函数（权威来源）。本节仅声明代理接口关系和 Rect2 计算实现约束。

### F-CF — forecast_combat 代理接口

本系统代理 #5 的 `forecast_combat()` 纯函数，接口签名与返回类型与 #5 F-FC 完全一致：

```
forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp)
  → CombatForecast { n_rounds, total_damage_to_player, player_survives, predicted_hp_after }
```

| 参数 | 来源 | 传入方 |
|------|------|--------|
| `monster_hp`, `monster_atk`, `monster_def` | #1 实体数据库 | #6 读取后传入 |
| `player_atk`, `player_def` | #4 玩家属性（只读） | #6 读取后传入 |
| `player_current_hp` | #4 实时当前 HP | #6 读取后传入（须为实时值，非最大 HP）|

完整公式、输出范围与边界值见 #5 设计文档 F-FC 节。本系统不可与 #5 数学产生任何偏差：转调**不做任何二次计算、clamp、取整或字段变换**——`show_overlay()` 接收的 `CombatForecast` 字段值须原样用于渲染（仅做「int → 展示字符串」的格式化，不改变数值）。

### F-RECT — Rect2 缓存计算约束

`show_overlay(forecast, col, row)` 内部，屏幕空间 Rect2 的计算：

```
_cached_overlay_rect = overlay_control.get_global_rect()
_cached_x_btn_rect   = x_button_control.get_global_rect()
```

**实现约束**：`get_global_rect()` 须在 Control 节点 `position`/`size` 设置完成后**同步调用**（同帧内，无 `await`）。禁止在 `_ready()` 或 `_process()` 预计算——Rect2 由 `col`/`row` 参数动态决定，每次 `show_overlay()` 调用后可能不同。**该同步保证成立的前提是 CF-4 的「禁用 Container、全手动定位」约束**（Container 排布延迟会使同帧 `get_global_rect()` 返回旧值）。

**坐标系约束（BLOCKING 实现前提）**：两个 Getter 返回值须与 `InputEventScreenTouch.position`（视口物理像素坐标，原点左上角）**同坐标系**。`CombatForecastOverlay` 既已定为 Scene Node（根因 D 裁决），其默认挂载方式为：
- **方案 a（设计默认）**：Overlay 置于与 #6 网格相同的坐标空间（game.tscn 同一 CanvasLayer / 同一缩放变换下），使 `get_global_rect()` 自然与触控坐标一致。Scene Node 化后此方案自然成立（不再像 Autoload 那样挂在 root 下脱离游戏场景坐标空间）。
- **方案 b（备选）**：若 Overlay 置于独立 CanvasLayer，则该 CanvasLayer 须 `follow_viewport_enabled = true`、`offset = Vector2.ZERO`、`scale = Vector2.ONE`。

> **⚠️ 待 technical-director 裁决（根因 D 衍生，BLOCKING 实现前提）**：方案 a/b 的成立性依赖**项目整体 Viewport / SubViewport 架构**——若抖音适配采用 SubViewport 缩放，则 `InputEventScreenTouch.position` 与 Overlay 的 `get_global_rect()` 可能分属不同坐标空间，正确做法须改为用 `get_viewport().canvas_transform.affine_inverse()` 转换触点后再做命中判断。该整体渲染/缩放架构当前在 GDD/ADR 中**未定义**，与导出 spike（QQ-01）耦合，须随 ADR-0003 修订一并由 technical-director 确认。本节先记录设计默认（方案 a），实现前以 ADR 结论为准。

实现时**必须实测校验**：在目标分辨率与 #6 的整体 scale 配置下，断言 `get_global_rect()` 与构造的 `InputEventScreenTouch.position` 命中判断一致（纳入 AC-CF-1）。禁止返回 Control 局部坐标，否则 #6 的命中判断系统性偏移。

## Edge Cases

- **如果 `show_overlay()` 在 Visible 状态（已有覆盖层显示）再次调用**：按 CF-4 原子更新顺序更新内容、位置与两个 Rect2 缓存，不经过 Hidden 中间态。旧内容不保留，新内容和新 Rect2 同帧生效。× 按钮位置按新 `col` 重新计算。

- **如果 `hide_overlay()` 在 Hidden 状态调用**：幂等操作，无副作用，两个 Rect2 缓存保持 `Rect2()` 零矩形，不报错。

- **如果 `get_overlay_screen_rect()` 或 `get_x_button_screen_rect()` 在 Hidden 状态调用**：返回 `Rect2()`（零矩形）。调用方（#6）须处理零矩形情况——零矩形任何触点都不命中，等效于「无覆盖层」，#6 的触控逻辑自然 fallthrough 到格子点击路径，行为正确。

- **如果 `player_survives = false`（LOSE 路径）**：覆盖层切换红色/警告色主题并叠加非颜色冗余标识 `lose_indicator`「会死」（CF-3）；**不展示任何由 `CombatForecast` 推算的数字**（无回合数、无伤害量、无「能撑几回合」）；仅 `predicted_hp_after = 0` → 「0 血」。覆盖层仍然正常显示——LOSE 预演的设计意图是告知「会死」，不拦截不隐藏。玩家可选择按 × 取消或接受 LOSE 风险确认进攻。

- **如果 `player_current_hp = 1`（最小合法当前 HP，LOSE 极值）**：只要 `monster_atk > player_def`（每回合净伤 > 0），`total_dmg ≥ 1` 不严格小于 1，`player_survives = false`，走 LOSE 通路——同上：展示「会死」+ 警告主题 + 非颜色标识，不展示具体伤害（此极值下理论值与实际受伤差异最大，更印证 LOSE 不显示数字的正确性）。无特殊处理，但作为边界值显式声明。

- **如果 `n_rounds` 超出 #3 `N_max` 保证范围（违反 #5 D1 约束的极值入参）**：本系统**原样展示** #5 返回的 `n_rounds`，不 clamp、不隐藏、不报错（输入合法性前置在 #6，见 CF-2）。三行布局的「N 回合」Label 须能容纳至少两位数字（`N_max` 安全范围上界 = 20，见 Tuning Knobs）。

- **如果 `col` 在边界区（col ≥ 13 或 col ≤ 2）**：锚点翻转规则按 CF-5 执行，× 按钮位置同步更新，`_cached_x_btn_rect` 反映翻转后的实际屏幕坐标。

- **如果 `forecast_combat()` 被轮询调用（违反 ADR-0006 约束）**：本系统不主动防止，但 ADR-0006 约束「每次 PREVIEWING 进入调用一次」在 #6 侧强制执行，本系统不增加防御性计数器（防御在调用方，不在被调用方）。代理层对多次调用须健壮（纯转调，幂等无副作用，见 AC-CF-6）。

- **如果 CanvasLayer / 布局在同帧内未完成导致 `get_global_rect()` 返回旧值**：`show_overlay()` 实现须满足 CF-4（禁用 Container、全手动设置 position/size）+ F-RECT（坐标系方案），先同步设置 Control `position`/`size`，再立即调用 `get_global_rect()` 完成缓存，禁止依赖 `NOTIFICATION_RESIZED` / `NOTIFICATION_SORT_CHILDREN` 或下一帧 `_process()` 回调延迟缓存——否则 #6 首帧内调用 Getter 得到旧值，触控拦截失效。

## Dependencies

| 系统 | 方向 | 性质 | 说明 |
|------|------|------|------|
| #5 确定性回合战斗 | 上游（硬依赖） | `forecast_combat()` 数学实现来源 | #10 不可脱离 #5 独立运行；代理接口须与 #5 F-FC 完全一致 |
| #6 网格移动与交互 | 下游（被依赖）+ 协调 | 调用本系统全部 5 个公开接口；CF-7 高亮归 #6 渲染 | #6 实现的直接前置依赖；#6 GDD Interactions 表已完整声明接口，并登记目标格脉冲高亮 |
| #11 数值反馈视觉 | 旁系（非硬依赖） | 战斗结算音效/数值反馈归 #11 | 本系统无独立音效；GDD 未存在，仅在 Visual/Audio 节引用，不阻塞 #10 实现 |
| #13 游戏状态管理 | 下游（非硬依赖） | LOSE「确认送死」→ `player_died()` 流向 #13 | GDD 未存在；LOSE 确认进攻的死亡流程交 #13 设计，#10 仅忠实展示并允许确认（见 Open Questions #3） |

**双向一致性验证**：
- #5 GDD Interactions 表：「#10 战斗预演 → 只读调用 `forecast_combat()`」✓
- #6 GDD Interactions 表：CombatForecast 完整 5 接口 + 屏幕空间坐标约束 ✓；CTA 要求已删除、AC-COMB-7 改 RESOLVED-VOID ✓（2026-06-29 同步）；目标格脉冲高亮已登记 ✓
- **`show_overlay` 签名一致性**：本系统第三轮将 `show_overlay` 退回 3 参 `(forecast, col, row)`，与 #6 现有 5 处调用（grid-movement.md:63/132/195/227/296）**完全一致** ✓ —— 故根因 B 的「接口未同步」无需修改 #6。

> **⚠️ 待 #6 同步（根因 D 衍生，非阻塞本设计但阻塞实现）**：宿主拆分后，`forecast_combat` 归 `CombatForecastService`（Autoload 全局名，#6 调用方式不变），但 `show_overlay`/`hide_overlay`/`get_overlay_screen_rect`/`get_x_button_screen_rect` 4 个 UI 接口归 `CombatForecastOverlay`（Scene Node），#6 不能再以 Autoload 全局名调用这 4 个接口。**已由 ADR-0008 裁定**：#6 通过 `@export var forecast_overlay: CombatForecastOverlay` 在 game.tscn 中连线引用调用这 4 个接口（两者均为单 game.tscn 持久 Scene Node，无失效风险）。注：ADR-0003 的引用禁令 `autoload_holds_scene_node_reference` **仅约束 Autoload**——#6 是 Scene Node，Scene Node 间 @export 引用是 Godot 惯用模式，不受该禁令约束。#6 Interactions 表与 `_input()` 注释的调用名同步随 ADR-0008 Accepted 后处理；本 GDD 不单方面改 #6。

## Tuning Knobs

| 旋钮 | 默认值 | 安全范围 | 影响 |
|------|--------|----------|------|
| `OVERLAY_ANIM_DURATION` | 0ms（瞬现） | 0ms–150ms | **0 = 瞬现**（最服务「立即可读」，见 Visual/Audio 动画节）；上界 150ms 违反 #6 硬约束。淡入动画非强制，若用须 ≤150ms |
| LOSE 路径警告色 | 红色（具体值由艺术指导定） | 高对比度（WCAG AA ≥ 4.5:1） | 影响可读性与情绪传达强度；**不可作为唯一 LOSE 区分手段**（CF-3 色盲约束） |
| `X_BTN_MIN_DP` | 40dp（目标） | 受 `OVERLAY_MIN_WIDTH` 几何约束（见下） | 触控精度与可达性目标；密集网格下实际值见布局说明 |
| `OVERLAY_MIN_WIDTH` | 内容自适应（保守估算约 110–120dp / 5 格） | ≥ 提示行文字宽度 + 左右内边距（实测确认） | 宽度下限由提示行「再次点击怪物进攻」（9 汉字，12pt ≈ 108dp）+ 内边距（8dp）决定，约 116dp（≈ 5.2 格）。**不再使用「3 格」作为下限**（67.5dp 不足以容纳提示文字，已删除）。× 按钮独占顶行（见 Visual/Audio 布局），不占用宽度。OQ#4 线框图须在此估算基础上确认最终值 |
| `N_max`（继承 #3，只读） | 10 | 5–20（#3 旋钮，#10 不可调） | 决定 `n_rounds` 展示上界；「N 回合」Label 须能容纳两位数字。**#10 层只读，不重定义** |
| 字体最小尺寸 | 12pt | 12pt–18pt | 低于 12pt 在低端手机触屏上不可读（#6 约束锁定下限） |

## Visual/Audio Requirements

> **📌 Asset Spec** — 本节定义视觉需求。艺术风格指导（Art Bible）批准后，运行 `/asset-spec system:combat-forecast` 生成每项资产的尺寸描述与生成提示。

### 覆盖层布局

- **最小尺寸**：**内容自适应**，宽度下限约 110–120dp（≈5 格），由提示行文字宽度决定（见 Tuning Knobs `OVERLAY_MIN_WIDTH`）。**不使用「3 格」作为下限**。高度：× 顶行（≥40dp）+ 3 内容行（各 ~20dp）+ 提示行（可换行，≥20dp）+ 上下内边距（各 4dp），约 108dp（不换行）或 128dp（提示行换行）。
- **dp → 像素换算口径**：本 GDD 的 dp 一律指**项目逻辑分辨率下的逻辑像素**，对齐 #6 已建立的整体 `scale` 布局方案，**不采用 Android 原生 DPR 换算**。所有 dp 尺寸在实机以目标设备实测可达性为准（见 AC-CF-2 与 #6 AC-VIS-5 基线）。
- **字体最小尺寸**：12pt（低端触屏可读性底线，#6 约束锁定）；提示行小字可降至 10pt（与正文形成视觉层次），10pt 下限
- **层级**：`z_index ≥ 100` 或置于满足 F-RECT 坐标系约束的 CanvasLayer，确保渲染在格子精灵层之上
- **覆盖层锚定位置**：默认锚定在目标格正上方（CF-7 遮蔽约束：目标格须有 ≥1/2 格尺寸在覆盖层 Rect2 外）；目标格位于屏幕顶部边界时改为正下方锚定
- **布局结构（× 独占顶行，文字区在下）**：
  ```
  ┌─────────────────────────────┐
  │  ×（独占顶行，≥40dp 高）    │
  ├─────────────────────────────┤
  │  （WIN）N 回合                          │
  │  （LOSE）lose_indicator Label「会死」   │  ← LOSE 唯一主信息，非颜色冗余标识
  ├─────────────────────────────┤
  │  （WIN）掉 N 血                         │
  │  （LOSE）—（此行不展示，无伤害数字）    │
  ├─────────────────────────────┤
  │  （WIN）剩余 N 血 / （LOSE）0 血        │  ← predicted_hp_after，LOSE 恒为 0
  ├─────────────────────────────┤
  │  再次点击怪物进攻（hint_label，提示行，小字，可换行） │
  └─────────────────────────────┘
  ```
  - 全部使用手动定位的 Label 节点（CF-4：禁用 Container）；关键节点名锁定：`lose_indicator`（LOSE 标识）、`hint_label`（确认提示行）、`damage_label`（WIN 伤害行；LOSE 下为空/隐藏，AC-CF-8a 据此限定负断言范围）
  - **LOSE 路径不展示任何数字**（根因 A）：第1行为 `lose_indicator`「会死」，伤害行整行不展示，第3行仅「0 血」。WIN 路径正常三行（回合/掉血/剩血）。
  - × 按钮宽度 = 覆盖层完整宽度，不占文字区横向空间（位置规则继承 #6：离目标格最远的角，x 轴对齐）
  - **最小尺寸线框约束**（OQ#4）：实现/资产阶段须产出「中间列 + 最小内容」场景的像素级线框，验证在 360dp 竖屏低端机上无截断、无重叠、目标格不被完全遮蔽

### 颜色主题

| 状态 | 背景 | 主要文字 | 数值 | 约束 |
|------|------|----------|------|------|
| WIN（`player_survives=true`）| 半透明深色（#333333 at 80%） | 白色 `#FFFFFF` | 亮绿 `#66FF99` 或白 | WCAG AA ≥ 4.5:1 |
| LOSE（`player_survives=false`）| 半透明深红（#660000 at 80%）或警告边框 | 白色 `#FFFFFF` | 红 `#CC3333` 或亮红 | WCAG AA ≥ 4.5:1；**必须叠加非颜色冗余标识（图标/文字/形状），不可仅依赖红绿区分**（CF-3 色盲约束，BLOCKING） |

*具体色值与非颜色标识形式须由艺术指导结合像素风调色板最终确认（见 Open Questions #1/#2）。*

### 动画

- **出现**：默认**瞬现**（`OVERLAY_ANIM_DURATION = 0`）——最服务「数字出现瞬间决策已做好」的体验；若启用淡入（alpha 0→1）须 ≤ `OVERLAY_ANIM_DURATION` 上界 150ms。可选 scale 0.9→1.0 轻弹（≤50ms）提供空间反馈而不牺牲可读速度。
- **消失**：与出现对称（瞬隐或 ≤150ms 淡出）。
- **WIN/LOSE 主题切换**：无动画（`show_overlay()` 调用时直接设置）。

### × 关闭按钮

- **尺寸**：≥ 40×40dp 目标，图标 ≥ 16pt（实际受覆盖层几何约束，见布局说明）
- **MouseFilter**：`MOUSE_FILTER_IGNORE`（触控拦截完全由 #6 `_input()` 负责；覆盖层根 Control 为 `MOUSE_FILTER_STOP`，见 CF-5）
- **位置**：离目标格最远的角（col ≥ 13 → 左上；col ≤ 2 → 右上；默认右上）
- **颜色**：与背景高对比，WIN/LOSE 两种主题均须清晰可见

### 音频

无独立音效（战斗预演为无音效操作；战斗结算音效由 #11 数值反馈视觉负责）。

## Acceptance Criteria

### 1. 接口契约

**AC-CF-1** [BLOCKING — Logic] **GIVEN** `CombatForecastOverlay` 场景（含 overlay Control 子节点）已通过 `add_child()` 加入 GDUnit4 测试场景树（SceneTree 活跃），**AND** `show_overlay(forecast, col, row)` called with valid `CombatForecast`, **WHEN** call returns（无 `await`、调用与断言之间无 `simulate_frames`）, **THEN** `get_overlay_screen_rect().has_area() == true`，且 `get_overlay_screen_rect().size.x ≥ 项目最小宽度参考值（约 116dp 对应逻辑像素）`。"同帧无延迟"由 CF-4/F-RECT 实现约束保证，AC 以黑盒方式断言可观测效果（不访问内部 ctrl 节点）。**注**：headless GDUnit4 的帧步进与实机不同，本 AC 通过不代表实机首帧 Rect2 对齐——实机/编辑器下 `get_global_rect()` 与触控坐标对齐的校验纳入导出 spike（QQ-01）验收清单。Test location: `tests/unit/combat_forecast/`.

**AC-CF-2** [BLOCKING — Logic] GIVEN `show_overlay()` called, WHEN `get_x_button_screen_rect()` called, THEN 返回 Rect2 完全包含在 `get_overlay_screen_rect()` 内（× 按钮是覆盖层子区域），且 `has_area() == true`。**× 按钮像素尺寸须 ≥ 项目逻辑分辨率下 40dp 目标对应的逻辑像素值**（具体换算对齐 #6 scale 方案；实机可达性由 #6 AC-VIS-5 风格的实测基线验证，不在本单元测试硬编码物理像素）。

**AC-CF-3** [BLOCKING — Logic] GIVEN `hide_overlay()` called from any state (Hidden or Visible), THEN `get_overlay_screen_rect()` = `Rect2()`，`get_x_button_screen_rect()` = `Rect2()`。幂等测试：连续两次调用 `hide_overlay()` 结果不变，无 `push_error`。

**AC-CF-4** [BLOCKING — Integration] GIVEN overlay is Visible with (col=5,row=5), WHEN `show_overlay(new_forecast, col=10, row=8)` called again（无 `hide_overlay` 间隔）, WHEN call returns, THEN `get_overlay_screen_rect().has_area() == true` 且 `get_x_button_screen_rect().has_area() == true`；覆盖层 `position.x` 落在 col=10 对应的期望屏幕区间内（辅助函数 `col_to_screen_x(col)` 提供换算，允许 ±2dp 容差），x_btn rect 仍包含于 overlay rect。**注**：「无中间帧零矩形」是 CF-4 原子更新顺序的实现约束，由 code review 验证，不作为运行时断言。

### 2. forecast_combat 代理

**AC-CF-5** [BLOCKING — Logic] GIVEN `CombatForecast.forecast_combat(50, 18, 5, 14, 13, 90)`, THEN returns `{ n_rounds=6, total_damage_to_player=25, player_survives=true, predicted_hp_after=65 }`——须与 `CombatSystem.forecast_combat(50,18,5,14,13,90)` 的返回值**逐字段相等**（确定性代理验证；断言对象与 #5 同入参一致，而非仅比对硬编码常量，保证 #5 调参后本 AC 仍测「代理一致性」）。Test location: `tests/unit/combat_forecast/`.

**AC-CF-5b** [BLOCKING — Logic] GIVEN `forecast_combat(50, 18, 5, 14, 13, 5)`（同怪，player_current_hp=5，LOSE 场景）, THEN `player_survives == false`、`predicted_hp_after == 0`，且与 `CombatSystem.forecast_combat()` 同入参逐字段相等（LOSE 路径代理验证）。

**AC-CF-5c** [BLOCKING — Logic] GIVEN overlay is Hidden（`hide_overlay()` 已调用）, WHEN `forecast_combat(50, 18, 5, 14, 13, 90)` called, THEN 返回结果与 Visible 状态下相同（代理函数为纯转调，与覆盖层可见状态无关）。

**AC-CF-6** [ADVISORY — Architecture] GIVEN `forecast_combat()` 以合法参数连续调用 5 次, THEN 无 crash、无 `push_error`，每次返回结果相同（代理层多次调用健壮性 + 幂等性）。Test location: `tests/unit/combat_forecast/`. 注：ADR-0006「每次 PREVIEWING 单次调用」合规性由 #6 侧 AC 验证；本 AC 仅覆盖本系统内部多次调用健壮性。

### 3. 展示内容

**AC-CF-7a** [BLOCKING — Integration] **WIN 路径展示一致性**：GIVEN `show_overlay(forecast_with_survives=true, col, row)` called, THEN 覆盖层各 Label 文本与 `CombatForecast` 字段值**精确一致**（不使用 contains，防止额外数字污染）：
- 回合 Label.text == `str(forecast.n_rounds)` + 固定文案后缀（如「回合」），且不含其他数字
- 伤害 Label.text == `str(forecast.total_damage_to_player)` + 固定文案（如「掉N血」），且不含其他数字
- 剩余 HP Label.text == `str(forecast.predicted_hp_after)` + 固定文案，且不含其他数字
Test location: `tests/integration/combat_forecast/`.

**AC-CF-7c** [BLOCKING — Integration] **LOSE 路径不展示任何推算数字**（替代原 K 值测试 — 根因 A：K 公式已废弃，LOSE 不展示数字）：GIVEN `show_overlay(forecast_with_survives=false, col, row)` with valid LOSE `CombatForecast`（例如合法 goblin 夹具 `forecast_combat(50,18,5,14,13,5)` → `{n_rounds=6, total_damage_to_player=25, player_survives=false, predicted_hp_after=0}`）, THEN：(1) 回合行（WIN 专用）`visible == false` 或文本不含 `str(forecast.n_rounds)`；(2) 伤害行 `damage_label` `visible == false` 或文本不含 `str(forecast.total_damage_to_player)`；(3) 覆盖层任何 Label 文本**均不含固定子串「能撑」**（固定字符串断言，无数字巧合风险——验证「能撑 K 回合」表达已彻底移除）。即 LOSE 主信息仅 `lose_indicator`「会死」+「0 血」。Test location: `tests/integration/combat_forecast/`.

**AC-CF-7b** [ADVISORY — Visual/Feel] WIN 路径覆盖层为标准颜色主题（非警告色）。Manual verification: screenshot in `production/qa/evidence/`；lead sign-off。

**AC-CF-8a** [BLOCKING — Integration] GIVEN `show_overlay(forecast_with_survives=false, col, row)` called（forecast.predicted_hp_after=0）, THEN：
(1) 覆盖层切换 LOSE 主题（断言 StyleBox / `modulate` 与 WIN 状态值不同）；
(2) **节点 `lose_indicator`（固定节点名，为 Label 类型）存在于覆盖层场景树中，且 `lose_indicator.visible == true`、`lose_indicator.text == "会死"`**（OQ#2 已关闭，2026-06-29 锁定为「会死」文字 Label，节点名 `lose_indicator`）；
(3) 覆盖层**不展示** `total_damage_to_player` 的具体数值：断言**限定于伤害区域节点 `damage_label`**（固定节点名，见 Visual 布局）——`damage_label.visible == false` 或 `damage_label.text` 不包含 `str(forecast.total_damage_to_player)`。**不再对「任何 Label」做全局负断言**（避免伤害值与回合数/HP 数字巧合时假失败 — qa-lead R3-BLOCK-5）。
Test location: `tests/integration/combat_forecast/`.

**AC-CF-8b** [ADVISORY — Visual/Feel] LOSE 路径警告色主题 + 色盲友好（`lose_indicator` 「会死」文字在灰度截图下仍可辨，与 WIN 路径视觉明显区分）。Manual verification: screenshot in `production/qa/evidence/`；lead sign-off。

**AC-CF-9** [BLOCKING — Integration] 锚点翻转边界覆盖（4 个关键 col 测试）：
- **col=13（左翻转触发下界）**：`abs(get_x_button_screen_rect().position.x - get_overlay_screen_rect().position.x) ≤ 2.0`（× 在左上角），且 `has_area() == true`
- **col=14（左翻转区内，验证 ≥13 而非 ==13）**：同 col=13 断言（× 在左上角），防止上界 off-by-one（误把翻转写成 `col == 13`）— 替换原冗余的 col=2（qa-lead R3-WARN-2）
- **col=12（翻转边界外，默认右上）**：`abs((x_btn.position.x + x_btn.size.x) - (overlay.position.x + overlay.size.x)) ≤ 2.0`（× 在右上角，与 col=13 方向相反）
- **col=3（默认右上边界，紧邻 col≤2 右锚定区）**：同 col=12 断言，防止 off-by-one（≤2 vs <3）
- 所有场景均断言 `get_x_button_screen_rect().has_area() == true`（翻转逻辑不得使 size 归零）

### 4. 动画时序

**AC-CF-10** [BLOCKING — Logic] 两条路径：
- **路径 A（OVERLAY_ANIM_DURATION == 0，默认瞬现）**：GIVEN `show_overlay()` called, WHEN call returns, THEN `overlay.modulate.a == 1.0`（不推进帧，立即断言）；GIVEN `hide_overlay()` called, WHEN call returns, THEN `overlay.visible == false` 或 `modulate.a == 0.0`（立即断言）
- **路径 B（OVERLAY_ANIM_DURATION > 0，若启用动画）**：`OVERLAY_ANIM_DURATION` 须声明为 **`var`（导出变量 `@export`，非 `const`）**，以便测试可写（GDScript `const` 编译期不可变，测试无法覆写 — qa-lead R3-BLOCK-6）。GIVEN 测试将 `CombatForecastOverlay.OVERLAY_ANIM_DURATION` 设为 `0.1` 后 `show_overlay()` called, WHEN 通过 `simulate_frames(ceil(0.1/delta)+1)` 推进时间 ≥ 0.1s + 1 帧, THEN `overlay.modulate.a == 1.0`
- **上界守卫**（GDUnit4 运行时断言）：因 `OVERLAY_ANIM_DURATION` 为 `var`，上界改用运行时断言验证默认值与设定值：`assert(CombatForecastOverlay.OVERLAY_ANIM_DURATION <= 0.150, "OVERLAY_ANIM_DURATION 超出 150ms 上界")`，纳入 `tests/unit/combat_forecast/` 同测试文件，CI 通过 `godot --headless --script tests/gdunit4_runner.gd` 覆盖。
Test location: `tests/unit/combat_forecast/`.

### 5. CTA 不存在 / 可发现性 / AC-COMB-7 闭合

**AC-CF-11** [CI-Lint] [Resolves #6 AC-COMB-7 → RESOLVED-VOID] 两层验证：
- **层1（负断言）**：`grep -rE 'cta|confirm_area|confirm_button|confirm_rect|attack_confirm' src/combat_forecast/` 返回空集（限定 `src/combat_forecast/`，避免扫到 #6 注释中的 RESOLVED-VOID 字样产生误报），确认本系统无 CTA 确认区域接口。CI 命令：`! grep -rE 'cta|confirm_area|confirm_button|confirm_rect|attack_confirm' src/combat_forecast/ && echo PASS || echo FAIL`
- **层2（正断言，接口白名单）**：因宿主拆分（根因 D），5 个公开接口分属两文件——`forecast_combat` 归 `CombatForecastService`，其余 4 个归 `CombatForecastOverlay`。改用**显式白名单 grep（不再用 `^func [a-z]` 计数，避免数到无下划线的私有辅助函数 — qa-lead R3-BLOCK-2）**：
  ```
  grep -rcE '^func (show_overlay|hide_overlay|get_overlay_screen_rect|get_x_button_screen_rect)\b' src/combat_forecast/   # 期望合计 4
  grep -rcE '^func forecast_combat\b' src/combat_forecast/                                                              # 期望 1
  ```
  且编码规范约束：`src/combat_forecast/` 下所有非公开函数 **MUST 以 `_` 前缀命名**（辅以 `grep -rcE '^func [^_]' src/combat_forecast/` 合计 == 5 兜底）。任一计数不符则 CI 失败。
#6 AC-COMB-7 场景（「tap 覆盖层内专用 CTA 区域」）设计为不存在，标注 RESOLVED-VOID。

**AC-CF-12** [BLOCKING — Integration] GIVEN `show_overlay()` called（WIN 或 LOSE）, THEN 覆盖层存在 CF-7 常驻提示文字节点 **`hint_label`（固定节点名，Label 类型）** 且 `hint_label.visible == true`、`hint_label.text` 非空（如「再次点击怪物进攻」），验证确认手势可发现性线索之一始终在场。注：目标格脉冲高亮线索归 #6 渲染，由 #6 侧 AC 验证。

### 6. Scope-Gate 检查（Anti-Pillars，与 #4/#5/#6 对齐）

**AC-CF-SCOPE-1** [CI-Lint] 本系统不引入随机数到战斗结算或展示逻辑。CI 命令：`! grep -rE 'randi|randf|RandomNumberGenerator|noise' src/combat_forecast/ && echo PASS || echo FAIL`。覆盖层展示的所有数字均来自 #5 确定性 `forecast_combat()`，不允许在代理层或展示层添加任何随机扰动。

**AC-CF-SCOPE-2** [Advisory — Design] 本系统不增加主游戏循环的玩家操作步骤超过现有上限。两步确认（tap 怪物→预演→再 tap 确认）是系统设计的核心机制，已纳入主循环步骤计数，不新增额外强制步骤。Manual review: 确认 `show_overlay()` 调用路径不在现有两步之外插入任何强制弹窗或等待。

**AC-CF-SCOPE-3** [CI-Lint] **本系统不主动触发激励广告事件**（LOSE 覆盖层是全游戏最自然的广告触发点，须明确门禁）。CI 命令：`! grep -rE 'AdService|AdManager|激励广告|rewarded_ad|show_ad|ad_sdk' src/combat_forecast/ && echo PASS || echo FAIL`。LOSE 路径允许玩家确认进攻，但广告触发由 #17 激励广告集成负责，#10 侧不得主动调用任何广告 SDK 接口。

## Open Questions

1. **LOSE 路径警告色精确色值** `[艺术指导决策]`：红色主题的具体 hex 色值须由艺术指导结合像素风调色板确认（本 GDD 用 `#CC3333` 作占位符）。**约束已锁定**（不再是 OQ 的一部分）：色盲适配为 BLOCKING 强制（CF-3），LOSE 必须有非颜色冗余标识；本 OQ 仅决定颜色的具体值。

2. ~~**「会死」标识的具体形式**~~ `[已关闭 — 2026-06-29 复评锁定]`：LOSE 路径非颜色冗余标识已确定为**「会死」文字 Label，节点名 `lose_indicator`**。AC-CF-8a 第(2)项已据此锁定测试路径。OQ 关闭。

3. **LOSE「确认送死」的下游流程** `[临时立场已定 — 待 #13 设计]`：玩家在 LOSE 预演下可确认进攻 → 触发 `player_died()` → #13 死亡流程。**临时立场（2026-06-29）**：本系统仅忠实展示并允许确认，不主动触发广告（AC-CF-SCOPE-3 门禁），不增加额外确认弹窗；「故意送死」路径作为预期支持的游戏行为，死亡流程语义（动画、重开、惩罚、复活广告）交 #13/#17 设计。#13 设计时须回头确认「故意送死」触发复活广告的伦理立场。

4. **最小尺寸线框图** `[实现/艺术阶段]`：保守估算已明确（宽 ~116dp / 5 格，高 ~108–128dp，× 独占顶行）。须产出「中间列 + 最小内容」场景的像素级线框，验证在 360dp 竖屏低端机上：信息行 + 提示行无截断、无重叠，目标格 ≥ 1/2 格尺寸在覆盖层 Rect2 外（CF-7 遮蔽约束）。**注**：LOSE 路径自第三轮起仅 2 行（`lose_indicator`「会死」+「0 血」），比 WIN 的 3 行更矮，线框须同时验证 WIN（3 行）与 LOSE（2 行）两种高度。

5. ~~**ADR-0003 宿主拆分的正式落地 + 整体 Viewport 架构**~~ `[已由 ADR-0008 裁定 — 2026-06-29]`：拆 `CombatForecastService`(Autoload) + `CombatForecastOverlay`(Scene Node) 已由 **ADR-0008**（`docs/architecture/adr-0008-combat-forecast-hosting-split.md`，Status: Proposed）正式裁定：
   - (a) Overlay 挂载点 = **game.tscn 子节点 `CanvasLayer > Control`**（与 HUD 同构）✓
   - (b) #6 通过 **`@export var forecast_overlay`** 连线引用调用 4 UI 接口（不触发 ADR-0003 Autoload 禁令）✓；#6 调用名同步随 ADR-0008 Accepted 后处理
   - (c) 整体 **`stretch/mode = canvas_items`、无 SubViewport、CanvasLayer `follow_viewport_enabled=true`** → F-RECT 方案 a 成立 ✓
   **剩余实现前置**：ADR-0008 须从 Proposed → Accepted（否则引用本 ADR 的 #10 story 自动 blocked）；CF-4/F-RECT 的实机正确性（含 `follow_viewport_enabled` 偏移、同帧 `get_global_rect()`、Dual-focus 触控传播）由 ADR-0008 实测清单 QQ-ADR8-01..06（并入 QQ-01 导出 spike）兜底。
