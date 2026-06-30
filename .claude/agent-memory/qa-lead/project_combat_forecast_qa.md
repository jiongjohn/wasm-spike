---
name: project-combat-forecast-qa
description: Adversarial AC review of System #10 CombatForecast GDD, Round 3 (2026-06-29); all 6 R2 BLOCKINGs CLOSED; 6 new open BLOCKINGs: R3-BLOCK-1 (impossible fixture + wrong K formula in AC-CF-7c), R3-BLOCK-2 (AC-CF-11 regex counts private helpers), R3-BLOCK-3 (4-param vs 3-param show_overlay diverges from #6), R3-BLOCK-4 (AC-CF-7c inverts correct K answer), R3-BLOCK-5 (AC-CF-8a all-label sweep false failure), R3-BLOCK-6 (GDScript const not writable from test); NOT APPROVED
metadata:
  type: project
---

## Round 3 findings (2026-06-29)

Third AC adversarial review of combat-forecast.md (System #10 CombatForecast).
All 6 R2 BLOCKINGs were structurally addressed in the revision.
The rewrites introduced 6 new BLOCKINGs and 3 WARNINGs.

**Overall verdict: NOT APPROVED — 6 BLOCKINGs, 3 WARNINGs**

### R2 carry-forward: ALL CLOSED

- R2-BLOCK-1 (scene-tree fixture): AC-CF-1 now states add_child() to GDUnit4 scene tree — CLOSED
- R2-BLOCK-2 (OQ#2 node name): AC-CF-8a locked lose_indicator + "会死" text, OQ#2 closed 2026-06-29 — CLOSED
- R2-BLOCK-3 (AC-CF-4 inequality fragile): replaced with col_to_screen_x() direct position assertion — CLOSED
- R2-BLOCK-4 (AC-CF-10 zero tautology): now has explicit Path A (immediate) / Path B (advance time) split — CLOSED
- R2-BLOCK-5 (AC-CF-11 CI mechanism): exact grep command declared — CLOSED (but generates R3-BLOCK-2)
- R2-BLOCK-6 (AC-CF-9 boundary coverage): col=13/12/2/3 added — CLOSED (but generates R3-WARN-2)
- R2-COMPLIANCE-1 (Anti-Pillars absent): AC-CF-SCOPE-1/2/3 section 6 added — CLOSED

### Open BLOCKINGs Round 3 (6 total)

R3-BLOCK-1 (BLOCKING): AC-CF-7c fixture {n_rounds=5, total_damage_to_player=25} is physically
  impossible under F-C formula. F-C: total_dmg = monster_dmg × (n_rounds-1) = monster_dmg × 4.
  25/4 = 6.25 — not an integer. No valid integer monster_dmg × 4 = 25. The fixture cannot be
  produced by forecast_combat(). The test is asserting K for a CombatForecast value the
  system can never emit. Additionally, the K formula embedded in the AC
  (K = player_current_hp × n_rounds / total_damage_to_player) does not appear anywhere in
  #5 F-FC or F-SEQ. The correct K formula is K = ceil(player_current_hp / monster_dmg),
  derived from F-SEQ actual_rounds_played.
  Fix: replace fixture with valid goblin values {n_rounds=6, total_dmg=25 (monster_dmg=5)},
  use K = ceil(player_current_hp / monster_dmg), and verify K with both player_hp=10 (K=2)
  and player_hp=12 (K=3).

R3-BLOCK-2 (BLOCKING): AC-CF-11 layer 2 grep `^func [a-z]` counts non-underscore-prefixed
  private helpers as public functions, inflating count above 5. GDScript has no access
  modifiers; the only convention-based distinction is underscore prefix. Any helper named
  without `_` (e.g., `func clamp_col()`) increments the count. CI will false-fail.
  No project convention banning non-underscored private helpers is declared.
  Fix: use explicit name whitelist grep or declare encoding rule that all internal helpers
  use `_` prefix and enforce it in the same CI check.

R3-BLOCK-3 (BLOCKING): Interface contract divergence between #10 and #6.
  AC-CF-1, AC-CF-4 and all GIVEN clauses in AC-CF-7c / AC-CF-8a call
  show_overlay(forecast, col, row, player_current_hp) — 4 parameters.
  grid-movement.md lines 63, 132, 195, 227, 296 all call show_overlay(forecast, col, row)
  — 3 parameters. The player_current_hp parameter was added to #10 AC rewrites but never
  propagated to #6. If implementation follows #10 (4 params), every #6 call site breaks.
  If it follows #6 (3 params), LOSE K calculation has no player_current_hp available.
  Requires joint #6/#10 interface decision before any AC can be locked.
  Fix: update #6 grid-movement.md to match the 4-param signature, or re-source
  player_current_hp internally from #4 Autoload and revert to 3-param.

R3-BLOCK-4 (BLOCKING): AC-CF-7c second sub-assertion claims K=2 is correct and K=3 is wrong
  for player_current_hp=13, n_rounds=5, total_dmg=25. With correct formula K = ceil(13/5) = 3.
  The AC explicitly states "不是 3" — inverting correct and incorrect. A correct implementation
  returning K=3 fails the test; a buggy implementation using the wrong formula passes.
  Arithmetic proof: monster_dmg=5 (only valid monster_dmg for goblin), player_hp=13:
  round 1: 5 cumulative, round 2: 10, round 3: 15 ≥ 13 → K=3.
  Fix: same as R3-BLOCK-1, replace both sub-cases with valid fixtures and correct K formula.

R3-BLOCK-5 (BLOCKING): AC-CF-8a item (3) asserts "任何 Label 文本均不含 str(forecast.total_damage_to_player)".
  If total_damage_to_player=6 and n_rounds=6, the round Label "第6回合" contains "6".
  The sweep-all-labels assertion produces false failure when the damage value's digit appears
  coincidentally in an unrelated Label. Must scope the negative assertion to the specific
  damage display Label node (which requires declaring that node's name, analogous to lose_indicator).

R3-BLOCK-6 (BLOCKING): AC-CF-10 Path B mandates "测试内设置常量 OVERLAY_ANIM_DURATION = 0.1s".
  GDScript `const` is compile-time immutable — a test cannot write to it at runtime.
  The AC mechanism is mechanically impossible if OVERLAY_ANIM_DURATION is declared `const`.
  If it is `var`, the AC should say so explicitly. No GDUnit4 override mechanism is declared.
  Fix: declare OVERLAY_ANIM_DURATION as `var` (not `const`) and state this in the AC,
  or mark Path B as manual/advisory and restrict automated testing to Path A only.

### Open WARNINGs Round 3 (3 total)

R3-WARN-1: AC-CF-12 hint text node name undeclared — not mechanically testable.
  "覆盖层存在 CF-7 常驻提示文字节点" with no node path or name. Same issue class as R2-BLOCK-2
  before OQ#2 was resolved. qa-tester cannot write $hint_label.visible == true without
  the node name. Escalate to BLOCKING if not resolved in R4.

R3-WARN-2: AC-CF-9 col=2/3/12 are three identical right-default assertions. Meaningful
  boundary is col=12 vs col=13 (flip transition). col=2/3 add no new flip coverage.
  Left boundary at col=14 (just inside flip zone) untested — off-by-one risk at upper
  boundary of flip zone remains. Advisory: replace col=2 with col=14.

R3-WARN-3: AC-CF-2 classified [BLOCKING — Logic] but 40dp size assertion explicitly deferred
  to real-device. A BLOCKING Logic test that does not assert its stated requirement misleads
  the sprint gate. Reclassify to [ADVISORY — Visual/Feel] with declared real-device protocol,
  or extend the unit test with an explicit dp→pixel conversion assertion using the project
  scale factor. Carried from R2-WARN-3.

### Key arithmetic (Round 3)

- Impossible fixture confirmed: n_rounds=5, total_dmg=25 → monster_dmg=6.25 (non-integer, impossible under F-C)
- Wrong K formula: K=floor(player_hp×n/total_dmg) vs correct K=ceil(player_hp/monster_dmg)
- player_hp=13, monster_dmg=5: correct K=ceil(13/5)=3; AC formula gives floor(65/25)=2 — off by 1
- AC-CF-5 / AC-CF-5b fixtures verified CORRECT against F-FC (unchanged from R2)
- 4-param vs 3-param: show_overlay(forecast,col,row,player_current_hp) in #10 AC vs show_overlay(forecast,col,row) in #6 — 5 occurrences in grid-movement.md all use 3-param

**Why:** Round 3 closed all R2 design-level BLOCKINGs but the K-formula rewrite in AC-CF-7c
introduced the most dangerous class of QA error: a test that asserts a wrong formula as
correct and the correct answer as wrong. This pattern (fixing a display gap by hardcoding a
bad formula) is harder to catch than a missing test — the suite is green while the bug is frozen in.
**How to apply:** When reviewing formula-driven ACs, always independently derive the expected
value from the GDD's authoritative formula section (F-FC / F-SEQ) and compare digit-by-digit.
Never trust a K or hp_after value stated in an AC without deriving it from first principles.
The 4-param/3-param arity mismatch (R3-BLOCK-3) is a cross-system blocker that requires
coordinating with #6 before #10 can be approved — check grid-movement.md show_overlay
signature in every future #10 review round.
