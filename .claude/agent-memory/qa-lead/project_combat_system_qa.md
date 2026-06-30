---
name: project-combat-system-qa
description: QA adversarial AC review of Deterministic Turn-Based Combat GDD (System #5) — Round 2 (2026-06-25); 7/8 R1 BLOCKINGs CLOSED; 8 new BLOCKINGs; 4 WARNINGs; 3 RECOMMENDEDs
metadata:
  type: project
---

## Round 1 findings (2026-06-25)

First AC adversarial review of deterministic-combat-system GDD (System #5).
17 draft ACs provided by designer. 8 BLOCKINGs found, 14+ RECOMMENDEDs.

### Framework conflict verdict

GDUnit4 (not GUT) recommended for #5 to maintain consistency with #3/#4.
External BLOCKING (technical-director ADR) carried from #3/#4 — same blocker, not a new one.
Does NOT block AC text authoring; blocks qa-tester running tests.

### Open BLOCKINGs Round 1 (8 total)

R1-BLOCK-1 (BLOCKING): AC-C2-PLAYER-FIRST GIVEN lacks #4 state injection method declaration.
  Same pattern as #4 R4-BLOCK-2 (test fixture precondition injection gap).
  Must declare: inject via #4 equipment API, or mock #4 getter, or Integration scene.

R1-BLOCK-2 (BLOCKING): AC-FC-VALUES calls "forecast_combat(goblin, ATK14, DEF13, hp90)" —
  this does not match the GDD-defined 6-int-parameter signature:
  forecast_combat(monster_hp, monster_atk, monster_def, player_atk, player_def, player_current_hp).
  "goblin" is a string ID, not an int. qa-tester cannot write correct call from this AC.

R1-BLOCK-3 (BLOCKING): AC-SEQ-CONSISTENCY asserts 3-way consistency (forecast + F-SEQ + #4.HP)
  but does not declare: (a) test type is Integration, (b) how to read player_hp_remaining
  from round_resolved signal parameters.

R1-BLOCK-4 (BLOCKING): C1 trigger path (how #6 calls resolve_combat) has zero AC coverage.
  All 17 ACs start AFTER resolve_combat is already called. Missing AC-C1-TRIGGER.
  If #6 is not yet designed, must add Open Questions entry + "blocked on #6 GDD" note.

R1-BLOCK-5 (BLOCKING): No behavior-level determinism AC. AC-SCOPE-NORNG is source-code grep only.
  Missing AC-C6-DETERMINISM: same inputs → same CombatResult on two consecutive calls.
  Same pattern as #4 R7-REC-1 (AC-SCOPE-1 no execution path) — escalated to BLOCKING here
  because #5 is a Logic story type and determinism is its P2 core contract.

R1-BLOCK-6 (BLOCKING): F1-B=0 (full block: player_DEF >= monster_ATK) path has no AC.
  This is the max(0,...) zero branch — highest-risk boundary for the damage formula.
  Missing AC-EC-FULL-BLOCK covering slime (ATK=8) + DEF=8 scenario.

R1-BLOCK-7 (BLOCKING): N_rounds=1 (one-shot kill) degenerate path has no AC.
  (N-1)=0 multiplication is an off-by-one risk point. GDD Formulas note calls for "specialist test."
  MVP attribute set cannot trigger this — needs mock #1 returning HP=1 monster.
  Missing AC-EC-ONE-ROUND.

R1-BLOCK-8 (BLOCKING): Mid-combat death (player dies in non-lethal round) has no AC.
  GDD Edge Cases explicitly declares this scenario. Missing AC-EC-MID-COMBAT-DEATH.
  Scenario: player_HP=10, goblin F1-B=15 > 10; dies on first retaliation, not last round.

### Open RECOMMENDEDs Round 1 (14 total)

R1-REC-1: AC-C2-RETALIATE should declare Integration type + use indirect HP delta assertion
  instead of spy on apply_damage (avoids implementation-coupling).

R1-REC-2: AC-C3-WIN and AC-C3-LOSS both missing monster_id parameter value assertion in THEN.

R1-REC-3: AC-FC-PURE should be Integration HP check OR code review (function signature has no #4 ref).

R1-REC-4: AC-FC-SURVIVES-BOUNDARY missing concrete fixture numbers.

R1-REC-5: AC-SEQ-LETHAL-ZERO overlaps with AC-C2-PLAYER-FIRST THEN(2) — merge or deduplicate.

R1-REC-6: AC-FD-DURATION depends on CombatResult containing battle_duration_seconds field —
  this field is NOT in the current GDD Dependencies interface spec. Must confirm before writing AC.

R1-REC-7: AC-C5-MONSTER-LOCAL should verify #1.get_monster().HP unchanged, not just round count.

R1-REC-8: AC-C8-NO-NEGATIVE-DAMAGE must enumerate the 18 combinations explicitly
  (ATK∈{6,14,20} × DEF∈{3,8,13} × monster∈{slime,goblin}).

R1-REC-9: AC-EC-UNKNOWN-MONSTER must align with #1 "returns null, caller handles" contract;
  declare expected return value (null or error CombatResult), not just "no crash."

R1-REC-10: AC-EC-REENTRY must specify "nested call from signal callback" as the actual reentry
  scenario (single-threaded GDScript cannot be interrupted mid-function without signal yield).

R1-REC-11: AC-SCOPE-NORNG — improve grep command format, add noise/seed coverage.

R1-REC-12: AC-SCOPE-NOAD — extend regex with Douyin SDK real identifiers
  (same gap as #4 R7-REC-2: showRewardedVideoAd, RewardedVideoAd, createRewardedVideo, showInterstitial).

R1-REC-13: AC-SCOPE-FORMULA-SOURCE — convert to grep-verifiable form.

R1-REC-14: Missing AC-FC-HP-FLOOR (predicted_hp_after == 0 when survives=false, not negative).

### Cross-system patterns inherited from #3/#4 reviews

- R1-BLOCK-1 is the fixture injection gap pattern from #4 R4-BLOCK-2.
- R1-BLOCK-5 is the "determinism AC exists only as grep, not behavior test" pattern from #4 R7-REC-1.
- R1-REC-12 is the Douyin SDK regex gap from #4 R7-REC-2.
- AC-C8-NO-NEGATIVE-DAMAGE is the landing point for #4 AC-FP05-NEGATIVE-DAMAGE path(3) — these two ACs must cross-reference each other.

**Why:** These patterns repeat across systems. Each BLOCKING found in #3/#4 that was not
pre-applied to #5 AC drafting became a new BLOCKING in #5. The earlier the pattern is applied,
the fewer review rounds are needed.
**How to apply:** When starting AC review for any new system, pre-screen for all known cross-system
patterns from [[project-player-stats-qa]] and [[project-entity-db-qa]] before running full review.

### Numbers verified

- goblin + ATK14/DEF13: N=ceil(50/9)=6, F1-B=5, total=25, hp_after(from 90)=65 — ALL CORRECT.
- slime + ATK14/DEF8: N=ceil(20/12)=2, F1-B=max(0,8-8)=0, total=0 — full block path.
- N=1 trigger: needs player_ATK − monster_DEF ≥ monster_HP. MVP max: ATK=20, DEF=2 (slime) → net=18; slime HP=20 > 18. Cannot trigger with MVP monsters. Needs mock or VS-stage monsters.

---

## Round 2 findings (2026-06-25)

R1 closure: 7/8 R1 BLOCKINGs CLOSED. R1-BLOCK-1 partially closed → became R2-BLOCK-1.
New ACs added: AC-C1-TRIGGER, AC-C6-DETERMINISM, AC-EC-FULL-BLOCK, AC-EC-ONE-ROUND, AC-EC-MID-COMBAT-DEATH.
New issues found: 8 BLOCKINGs, 4 WARNINGs, 3 RECOMMENDEDs.

### R1 BLOCKING closure status

- R1-BLOCK-1: PARTIALLY CLOSED — preamble injection convention added, but item_id→attribute mapping not provided. Became R2-BLOCK-1.
- R1-BLOCK-2: CLOSED — AC-FC-VALUES now uses 6-int signature (50,18,5,14,13,90).
- R1-BLOCK-3: CLOSED — AC-SEQ-CONSISTENCY now declares Integration type.
- R1-BLOCK-4: CLOSED — AC-C1-TRIGGER added.
- R1-BLOCK-5: CLOSED — AC-C6-DETERMINISM added (behavior-level determinism AC).
- R1-BLOCK-6: CLOSED — AC-EC-FULL-BLOCK added.
- R1-BLOCK-7: CLOSED — AC-EC-ONE-ROUND added (uses mock low-HP monster).
- R1-BLOCK-8: CLOSED — AC-EC-MID-COMBAT-DEATH added.

### Open BLOCKINGs Round 2 (8 total)

R2-BLOCK-1 (BLOCKING): Preamble injection convention does not map item_id to ATK/DEF values.
  pickup_item() is declared but qa-tester cannot know which item_id sets ATK=14 vs ATK=20.
  Must add to preamble: pickup_item("sword_iron") → ATK=14; pickup_item("shield_wood") → DEF=8;
  pickup_item("shield_iron") → DEF=13; plus reference to #4 for full item_id table.
  Affects: AC-C1-TRIGGER, AC-C2-PLAYER-FIRST, AC-C2-RETALIATE, AC-EC-FULL-BLOCK, AC-EC-MID-COMBAT-DEATH.

R2-BLOCK-2 (BLOCKING): Mock monster input format inconsistency and undeclared interface order.
  Some ACs use "mock goblin(50/18/5)" (positional), others "mock goblin(ATK=18)" (named).
  Mock #1 EntityDB interface parameter order never declared in GDD.
  Must unify format and declare mock interface signature: mock_monster(id, hp, atk, def).

R2-BLOCK-3 (BLOCKING): AC-C3-LOSS does not constrain signal order (player_died vs combat_lost).
  GDD design implies player_died fires before combat_lost, but GDScript connect() mode (immediate
  vs deferred) determines whether they're in the same frame. Not declared anywhere.
  Must: (a) declare connect mode in GDD C3 or preamble; (b) add order assertion to AC-C3-LOSS THEN.

R2-BLOCK-4 (BLOCKING): generate_round_sequence function signature not in interface spec section.
  AC-SEQ-LETHAL-ZERO and AC-SEQ-CONSISTENCY call "generate_round_sequence(...)" but the signature
  is unknown (same 6-int as forecast_combat? or monster_id string?).
  Must: add to interface spec section with full signature, OR rewrite both ACs as signal-sequence
  assertions via round_resolved (changing type to Integration for both).

R2-BLOCK-5 (BLOCKING): AC-C2-RETALIATE WHEN describes mid-execution pause that doesn't exist.
  resolve_combat() is synchronous (C7) — no "pause after round 1" state.
  Also GIVEN missing goblin HP/DEF and player_ATK (needed to confirm goblin survives round 1).
  Must: rewrite WHEN as "after resolve_combat returns, inspect first round_resolved signal params";
  add complete GIVEN attributes.

R2-BLOCK-6 (BLOCKING): AC-FC-SURVIVES-BOUNDARY GIVEN has no executable 6-int fixture.
  "某组合使total=50, current_hp=50" gives result values, not input params.
  Must provide complete fixture: forecast_combat(50, 13, 5, 14, 3, 50) → verified: F1-B=10,
  N=6, total=50, survives=(50<50)=false, hp_after=0.

R2-BLOCK-7 (BLOCKING): AC-C8-NO-NEGATIVE-DAMAGE tests mathematical tautology, not system behavior.
  WHEN "对每组合计算max(0, monster_ATK − player_DEF)" tests the expression, not the SUT call.
  max(0, x) ≥ 0 is always true; this AC cannot fail even if implementation passes negative values.
  Must rewrite: spy on apply_damage calls OR monitor stat_changed HP deltas to assert actual
  apply_damage(amount) argument ≥ 0 during resolve_combat execution.

R2-BLOCK-8 (BLOCKING): AC-C3-WIN and AC-C5-MONSTER-LOCAL use vague GIVEN descriptors.
  "玩家足以击杀slime" and "玩家两场均能取胜" are outcome constraints, not fixture inputs.
  Must replace with specific ATK/DEF/HP numbers.

### Open WARNINGs Round 2 (4 total)

R2-WARN-1: AC-C3-LOSS and AC-EC-MID-COMBAT-DEATH both missing player_died vs combat_lost
  signal order assertion. This ordering matters for #13 death flow integration.

R2-WARN-2: AC-EC-MID-COMBAT-DEATH does not assert round_resolved emit count (should be K=1,
  not N=6). With ATK=6/DEF=3/HP=10 vs goblin: F1-A=1, F1-B=15>10, dies on round 1, K=1.
  Need: assert_signal_emit_count(combat, "round_resolved") == 1.

R2-WARN-3: C7 (logic/animation decoupling) has zero AC coverage. No test verifies that
  resolve_combat/forecast_combat complete synchronously (no yield/await). This is the
  technical precondition for #10 preview system. Suggest AC-C7-SYNC: grep for absence of
  await/yield in combat_system.gd, or verify synchronous return in unit test.

R2-WARN-4: forecast_combat behavior during Resolving state has no AC. GDD implies pure function
  is state-independent, but no AC guards this. #10 preview may call it mid-combat.
  Suggest: add NOTE or small AC that forecast_combat returns normally during Resolving state.

### Open RECOMMENDEDs Round 2 (3 total)

R2-REC-1 (carried R1-REC-13): AC-SCOPE-FORMULA-SOURCE must be split into:
  (a) AC-SCOPE-FORMULA-GREP (Config/Data, CI-automatable) — grep for TuningFormulas reference;
  (b) AC-SCOPE-FORMULA-REVIEW (Advisory, code review) — evidence archived to production/qa/evidence/.
  Same resolution pattern as #4 R4-BLOCK-4(b) for AC-FP05-NEGATIVE-DAMAGE.

R2-REC-2 (carried R1-REC-6): AC-FD-DURATION assumes battle_duration_seconds field exists in
  CombatResult. This field is NOT in the current interface spec section of GDD (current:
  {result, monster_id, n_rounds, total_damage_to_player}). Must either add field to spec,
  or change AC to test a standalone calculate_duration(n_rounds) → float helper.

R2-REC-3 (carried R1-REC-7): AC-C5-MONSTER-LOCAL THEN should assert #1.get_monster("goblin").HP==50
  (verifies #1 not written to), not only rely on round_resolved monster_hp_remaining reading
  (which only reflects internal local variable, not #1 state).

### Numbers verified Round 2

- AC-EC-ONE-ROUND: max(0,18-3)×(1-1) = 15×0 = 0 ✓
- AC-FC-SURVIVES-BOUNDARY proposed fixture: forecast_combat(50,13,5,14,3,50) → F1-B=max(0,13-3)=10,
  N=ceil(50/max(1,14-5))=ceil(50/9)=6, total=10×5=50, survives=(50<50)=false, hp_after=0 ✓
- AC-EC-MID-COMBAT-DEATH: ATK=6/DEF=3/HP=10 vs goblin(50/18/5): F1-A=max(1,6-5)=1, F1-B=max(0,18-3)=15
  Round 1: monster_hp=49, apply_damage(15), player_hp=10-15→0, player_died fires, K=1 ✓

**Why:** Round 2 closed 7/8 R1 BLOCKINGs but introduced 8 new BLOCKINGs from newly-added ACs.
The fixture injection gap (R2-BLOCK-1), mock interface ambiguity (R2-BLOCK-2), and signal order
gap (R2-BLOCK-3) are recurring patterns from #3/#4 reviews that were not pre-applied to new ACs.
**How to apply:** Before adding new ACs in any round, pre-screen against all known cross-system
patterns from [[project-player-stats-qa]] and [[project-entity-db-qa]]. See also:
re-review-symmetric-closure memory for gap-in-symmetric-fix pattern.
