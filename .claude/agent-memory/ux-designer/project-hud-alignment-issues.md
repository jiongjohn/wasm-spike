---
name: project-hud-alignment-issues
description: Known UX conflicts from Art Director Section 7 HUD draft — open issues and resolution status as of 2026-06-23
metadata:
  type: project
---

HUD alignment check performed 2026-06-23. Six Art Director decisions reviewed.

**Why:** Art Director submitted Section 7 HUD visual direction draft; UX alignment check requested before finalization.
**How to apply:** These issues must be resolved before `design/ux/hud.md` is authored and before ui-programmer receives implementation spec.

## P0 — BLOCKING (must resolve before Section 7 finalized)

**Hover-based damage preview trigger is not implementable on mobile touch.**
- AD decision: "触摸怪物格子 200ms 后浮层显示"
- Problem: No hover event on mobile. touch_down + 200ms timer = long-press, which conflicts with tap-to-attack. Finger occludes the popup at the moment it appears.
- Resolution options: (A) Two-step confirm: tap = show preview panel with confirm/cancel buttons (RECOMMENDED), (B) Long-press = preview, short-tap = attack
- Status: OPEN — needs AD + game-designer alignment

## P1 — High priority

**Death warning uses color as sole differentiator (B4 bright red background).**
- Violates accessibility: ~8% of male users have red-green color blindness.
- Fix: Red background + blinking border OR HP icon changes to warning icon. Color alone is not sufficient.
- Status: OPEN

**Initial HUD shows 6 attributes — cognitive overload for casual users.**
- Fix: Progressive disclosure — only show HP/ATK/DEF + yellow key at game start. Blue key slot appears on first encounter with blue door. Fragment slot appears on first fragment pickup.
- Status: OPEN — needs implementation spec in hud.md

## P2 — Medium priority

**ATK/DEF meaning is not self-evident to non-RPG players.**
- Fix: One contextual tooltip after first combat — highlight DEF number with "防御减少了X点伤害" micro-copy. Single occurrence only, never repeat.
- Status: OPEN

**Rapid tap causes number pop animation stacking (visual jitter).**
- Fix: New animation interrupts and resets previous (not additive). Implementation constraint for ui-programmer.
- Status: OPEN — flag when authoring ui-programmer spec

## P3 — Low priority

**Dual-color icons insufficient to distinguish player vs. enemy stats in preview overlay.**
- Fix: Use position/background zone (top = player, bottom = enemy) as primary differentiator, not icon color.
- Status: OPEN

## Width budget validated

393px - 16px margins = 377px usable. Proposed allocation:
HP: 66px | ATK: 60px | DEF: 60px | Yellow key: 52px | Blue key: 52px | Fragments: 59px = 349px (+28px buffer).
Number digit width at 8px×2× = 16px/digit; max 4 digits fits in 64px comfortably.
Red key: add as hidden slot, appear only when floor contains red door (no permanent layout slot needed in MVP/VS).
