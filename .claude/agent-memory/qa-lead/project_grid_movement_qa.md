---
name: project-grid-movement-qa
description: adversarial AC review of Grid Movement GDD (#6), Round 6 (2026-06-29); 8 new BLOCKINGs, 4 RECOMMENDEDs, 2 MINORs; R5 resolution status tracked
metadata:
  type: project
---

Adversarial QA review of `design/gdd/grid-movement.md`, Round 6 (2026-06-29).
GDD status post-R5: ~47 BLOCKING / 5 ADVISORY / 3 CI-Lint.

**Why:** Shift-left gate — ensuring all ACs are independently testable before implementation of System #6 begins.

**How to apply:** All R6 BLOCKINGs must be resolved before #6 is marked Ready for Implementation.

---

## Round 6 Open BLOCKINGs (8 new)

**R6-BLOCK-1** — AC-SIG-4b: 「immediately after signal」not operationalizable. GDUnit4 `simulate_frames` is a blocking call; cannot insert mid-run assertions. AC needs: (a) declare which path step signal is injected at; (b) use `simulate_frames(1)` + emit signal + assert state + `simulate_frames(remaining)` + assert IDLE pattern.

**R6-BLOCK-2** — AC-COMB-2a: 「identity check」unimplementable without declaring CombatForecast base class. GDUnit4 has no `assert_same_reference()` built-in; `==` calls `_equals()` if overridden. Must: (a) declare CombatForecast extends RefCounted (or Object + teardown note); (b) specify exact GDUnit4 assertion (`assert_that(x).is_same(y)`).

**R6-BLOCK-3** — AC-COMB-7: Skeleton test CI behavior undefined. Empty body = GDUnit4 false green (auto-PASS). Must specify `pending("TODO: AC-COMB-7 awaiting #10 GDD")` — causes CI to report pending, not pass.

**R6-BLOCK-4** — AC-LOCK-5a: 「LOCKED throughout」requires frame-by-frame assertion but `simulate_frames(10)` is a single blocking call. Must define: Option A (monitor state_changed signal, assert not emitted) or Option B (assert before + after, document limitation).

**R6-BLOCK-5** — AC-MOV-1a: elapsed time measurement method still ambiguous (R5-ISSUE-3 partial closure). Must specify loop-until-IDLE measurement pattern instead of pre-computed frame count N (which makes test self-fulfilling).

**R6-BLOCK-6** — Missing AC (new): × button anchor-flip position (col ≥ 13 → left-upper corner) has no AC. Rule is safety-critical (prevents accidental combat confirm on cancel). Delegated to #10 GDD but must be placeholder-AC'd in #6. Suggest AC-VIS-6 [ADVISORY — DELEGATED].

**R6-BLOCK-7** — Missing AC-SIG-7b (new): AC-SIG-7 asserts「no CellNode updated」for wrong floor_id, but does NOT assert `_passable` cache unpolluted. Bug: `_passable[idx] = true` before floor_id check → BFS treats wrong-floor door as passable. Suggest AC-SIG-7b [BLOCKING — Logic]: BFS after mismatched door_opened signal does not route through that cell.

**R6-BLOCK-8** — AC-EC-3b (escalated from R5-ISSUE-7 RECOMMENDED, carry >2 rounds): AC-EC-3 only tests no-op cell_cleared (B already EMPTY). Does not test ENTITY→EMPTY mid-MOVING. A buggy `_recompute_path()` call on non-idempotent cell_cleared passes AC-EC-3. New AC-EC-3b needed: ENTITY→EMPTY mid-MOVING, assert path not recomputed.

---

## Round 6 Open RECOMMENDEDs / WARNINGs (4)

**R6-WARN-1** — AC-SIG-5b: grep pattern `tween\.stop\(\)` misses `tween.kill()`. Both are forbidden (AC-SIG-5 rationale). Fix: `grep -rE 'tween\.(stop|kill)\(\)'`.

**R6-WARN-2** — AC-FLOOR-4b: GIVEN timing ambiguity (R5-BLOCK-2 not closed). Missing: (a) assert show_overlay was called before floor_changed; (b) assert no GameState.on_*_cell_entered dispatch during floor_changed handling.

**R6-WARN-3** — AC-LOCK-5b: `Engine.get_main_loop().create_timer()` escapes grep pattern. Fix: add `create_timer|SceneTreeTimer` to pattern.

**R6-WARN-4** — AC-VIS-4: no specific GDUnit4 API cited (carry round 3). Add: `assert_signal_emit_count(grid_movement, "player_moved", path_length)`; call `monitor_signals()` before tap.

---

## Round 6 Open MINORs (2)

**R6-MINOR-1** — AC-SIG-4b missing「Defensive path:」label (asymmetric with AC-SIG-4).

**R6-MINOR-2** — AC-MOV-3 upper bound (≤ T_cell = 50ms) contradicts AC-MOV-1b upper bound (≤ T_cell + 33ms = 83ms) for path_length = 1, T_cell = 50ms. MOV-3 is stricter but inconsistent. Fix: align MOV-3 upper bound to T_cell + 33ms or drop precise upper bound and only keep「not 0ms」guard.

---

## R5 Resolution Status

| R5 Issue | Status | Note |
|---|---|---|
| R5-ISSUE-1 (COMB-2 split) | CLOSED | AC-COMB-2a + 2b split confirmed |
| R5-ISSUE-2 (LOCK-5a 300→10 frames) | PARTIAL | Frames changed; R6-BLOCK-4 new issue |
| R5-ISSUE-3 (MOV-1a tolerance + measurement) | PARTIAL | Tolerance ±66ms done; R6-BLOCK-5 residual |
| R5-ISSUE-4 (VIS-2 DI point) | CLOSED | `_play_reject_feedback` virtual method declared |
| R5-ISSUE-5 (VIS-4 GDUnit4 API) | OPEN → R6-WARN-4 | Carry round 3 |
| R5-ISSUE-6 (MOVING+grid_unlock) | PARTIAL | AC-SIG-4b added; R6-BLOCK-1 new issue |
| R5-ISSUE-7 (EC-3b ENTITY→EMPTY) | ESCALATED → R6-BLOCK-8 | Carry >2 rounds → BLOCKING |
| R5-BLOCK-1 (CTA confirm AC-COMB-7) | PARTIAL | AC-COMB-7 placeholder added; R6-BLOCK-3 new issue |
| R5-BLOCK-2 (FLOOR-4b GIVEN timing) | OPEN → R6-WARN-2 | Not closed |
| R5-BLOCK-3 (SIG-5b CI-Lint) | PARTIAL | AC-SIG-5b added; R6-WARN-1 tween.kill() gap |
| R5-WARN-1 (CFG-1 clamp masking) | OPEN | Carry round 3 — not yet addressed |
| R5-WARN-2 (BFS-8 semantics) | CLOSED | AC-DISP-6 covers PlayerMarker no-reposition |

---

## Prior Round Context

Round 5 was the first recorded QA adversarial review round for this GDD.
GDD completed 4 design-review rounds before QA adversarial review began.
Related reviews: [[project-combat-system-qa]], [[project-player-stats-qa]], [[project-entity-db-qa]]
