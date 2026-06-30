---
name: project-game-context
description: Core context for 像素魔塔·无尽塔 — platform, target user, game pillars, and UX constraints that inform every design decision
metadata:
  type: project
---

Game: 像素魔塔·无尽塔 (Pixel Tower / Rogue Tower)

**Platform**: 抖音小游戏, mobile portrait, 5–6 inch screen, touch-only input.
**Why:** All UX decisions must be validated against touch interaction patterns, not desktop hover/cursor patterns.
**How to apply:** Reject any interaction design that assumes hover, right-click, or mouse precision. Assume single-finger tap as primary input.

**Target user**: 抖音 casual player (18–40), fragmented sessions 1–5 min, NOT an RPG player. Reference games: casual mobile puzzle/idle games, NOT Hades or classic RPGs.
**Why:** "Three seconds to understand" (Pillar 3) is the hardest constraint. This user does not know what ATK/DEF means.
**How to apply:** Any HUD element that requires RPG prior knowledge needs a contextual disclosure path.

**Game Pillars (priority order):**
1. 看得见的成长 (Visible growth — North Star): every action must produce visible number/visual feedback
2. 确定性 + 容错 (Determinism + safety net): combat is predictable and pre-viewable; supports growth feel
3. 三秒上手 (3-second onboarding): zero tutorial, self-evident core loop
4. 每层都有新发现 (Discovery per floor)

**When pillars conflict**: Pillar 1 wins over Pillar 2; Pillar 3 constrains every new system added.

**Screen dimensions (design target)**: 393px wide (iPhone 14 logical width). Grid: 7–9 columns, cell ~40–44pt.

**HUD constraints confirmed (Art Director Section 7 draft)**:
- Top HUD, height ≤88px (16px multiples)
- Screen-space panel (not diegetic) — correct decision
- Numbers: 8×8px monospace pixel font @ 2× = 16px rendered
- Chinese text: ≥12px hard floor
- Icons: 8×8px @ 2× = 16px, dual-color fill
- Number pop animation: full-row highlight + 2px bounce, 128ms peak, 200ms fade
- Damage preview: positioned above enemy cell; death warning = B4 bright red full-row background
