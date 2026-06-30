---
name: project-player-stats-qa
description: QA adversarial review of Player Stats & Growth GDD (System #4) — Round 8 (2026-06-25); 0 open BLOCKINGs; 2 open RECOMMENDEDs carried 2+ rounds (AC-SCOPE-1 no execution path; AC-SCOPE-3 regex missing Douyin SDK names); escalate both to BLOCKING in R9 if still unresolved
metadata:
  type: project
---

## Round 1 findings (2026-06-24, first AC draft)

Adversarial QA review of Player Stats & Growth system (System #4) completed 2026-06-24.
25 ACs produced (AC-01 to AC-24). 5 BLOCKING gaps found before test authoring can begin.

### Open BLOCKINGs from Round 1 (status after Round 2 review)

GAP-1 (BLOCKING — still open): stat_changed 在 old==new 时是否必然发出？Round 2 AC list answered case-by-case (AC-EC-ZERO-DAMAGE and AC-EC-FULL-HEAL both say "emit"; AC-EC-DEAD-DAMAGE says "no emit") but never declared a unified rule. Three ACs give three different data points with no single rule to unify them.

GAP-2 (BLOCKING — still open): stat_changed 信号签名未定义。All Round 2 ACs assert stat_changed("HP", 60, 45) style calls but no AC or GDD section declares the signal's parameter names, types, and order.

GAP-3 (BLOCKING — partially addressed, new gap found): MAXHP_BOOST 满血时的行为. Round 2 added AC-FP04-FILL (current_HP=1–100 range) but still no AC for current_HP==MaxHP==100 when picking up crystal_life. Also no AC for second consecutive MAXHP_BOOST pick-up (cumulative stacking, 100→150→200?).

GAP-4 (BLOCKING — resolved): apply_damage(amount=0) now covered by AC-EC-ZERO-DAMAGE (THEN: stat_changed("HP", 80, 80) emitted, player_died not emitted). Rule is now testable.

GAP-5 (BLOCKING — resolved): item_pickup_no_change boundary now covered by AC-P3-ATK-NOCHANGE (THEN: signal emitted when new item is weaker than current).

### Open BLOCKINGs Round 2 (4 total)

BLOCK-1 (BLOCKING): AC-P7-HIGHEST-WINS asserts atk_boost_effective=14 but AC-FP01 defines atk_boost_effective=8 for sword_iron. Internal contradiction — at least one AC will always fail. Must unify the definition of atk_boost_effective (current weapon effect_value vs total ATK accumulation).

BLOCK-2 (BLOCKING): Same as GAP-2 — stat_changed signal signature not declared anywhere in GDD or AC list. 15+ ACs depend on this signal and cannot be written as executable GUT tests.

BLOCK-3 (BLOCKING): Same as GAP-1 — old==new emit rule not unified. AC-EC-ZERO-DAMAGE, AC-EC-FULL-HEAL both say emit; AC-EC-DEAD-DAMAGE says no emit. Without a single unified rule AC, testers cannot reason about edge cases not explicitly listed.

BLOCK-4 (BLOCKING): MAXHP_BOOST full-HP start (current_HP=100/MaxHP=100) and cumulative second-pick-up (MaxHP=150→200) have no ACs. This is the highest-risk code path for HP overflow bugs.

### Open ADVISORYs Round 2 (7 total)

ADVISORY-1: AC-P3-ATK-NOCHANGE and AC-P7-HIGHEST-WINS should be merged (identical GIVEN-WHEN, redundant fixtures).
ADVISORY-2: AC-FP03-CLAMP and AC-P4-NOOVERHEAL are exact duplicates (same numbers, same conclusion).
ADVISORY-3: AC-P3-MAXHP + AC-FP04-ORDER + AC-FP04-FILL should be merged into one AC (same fixture, three overlapping assertions).
ADVISORY-4: apply_damage with negative input (e.g., -5) has no AC and no "out of scope" declaration.
ADVISORY-5: AC-SCOPE-3 (no ad SDK calls) needs specified verification method (GUT spy mock or manual audit), not just "THEN no ad request".
ADVISORY-6 (carried GAP-6): effect_value < 0 / = 0 legality still undefined.
ADVISORY-7 (carried GAP-7): ACs hardcode base ATK=6, DEF=3; if config-driven, should reference constants.

### Pattern match to entity-database review

BLOCK-1 (atk_boost_effective contradiction) is a new pattern not seen in entity-database review — internal AC number conflict within same document. BLOCK-2+3 are this system's GAP-1+2 equivalents of entity-database BUG-1+3.

**Why:** BLOCK-1 will cause one of two ACs to always fail if written as-is. BLOCK-2 prevents 15+ ACs from becoming executable GUT tests. BLOCK-3 leaves testers with no rule for reasoning about unlisted edge cases. BLOCK-4 leaves the highest-risk formula path untested.
**How to apply:** Block GUT test authoring handoff until all 4 BLOCKINGs are resolved. Merge the 3 advisory duplicate pairs before handing off to qa-tester to avoid duplicate test fixtures. See [[project-entity-db-qa]] for cross-system signal signature patterns.

---

## Round 3 findings (2026-06-24)

B5 partial verification — 2 of 6 AC rewrites VERIFIED, 2 BLOCKING, 2 WARNING.

### B5 rewrite status

- AC-P3-ATK-NOCHANGE: VERIFIED — "exactly once" constraint covers double-emit bug; symmetric with AC-FP02-NOCHANGE.
- AC-FP02-NOCHANGE: VERIFIED — symmetry with AC-P3-ATK-NOCHANGE complete and correct.
- AC-P0-SIGNAL-EMITTED: ISSUE (R3-BLOCK-1) — `assert_no_new_orphans()` is not a GUT API (will cause test-code crash, not SUT assertion failure); two scenarios merged into one AC will cause signal count interference; "SignalSpy" name is ambiguous (GUT uses watch_signals(), not a class named SignalSpy).
- AC-FP04-ORDER: ISSUE (R3-BLOCK-2) — SignalOrderSpy helper interface spec missing; GDScript param count mismatch is a likely implementation error; GDD must provide minimum interface (class + `record(stat_name, _old, _new)` method signature).
- AC-SCOPE-2: WARNING — indirect verification (same-frame SignalSpy check) is correct for sync impl, but deferred-call edge case behavior not declared.
- AC-SCOPE-3: WARNING — "CI lint rule" implies CI infrastructure exists; no CI config in repo; must declare manual grep fallback path explicitly.

### Open BLOCKINGs Round 3 (2 total)

R3-BLOCK-1 (BLOCKING): AC-P0 references `assert_no_new_orphans()` which does not exist in GUT. Also merges two independent test scenarios into one AC, causing signal count cross-contamination. Must: (a) replace API name with GUT-valid equivalent or remove assertion, (b) split into two independent test functions / two ACs.

R3-BLOCK-2 (BLOCKING): AC-FP04-ORDER mandates a SignalOrderSpy helper but provides no interface spec. The helper must accept a 3-param callback matching stat_changed's signature. Without spec, qa-tester will likely implement wrong parameter signature causing Godot 4 static type error at connection time. Must supply minimum interface inline or in a referenced spec file.

### Open WARNINGs Round 3

R3-WARN-1 (WARNING): apply_damage(-1) has no AC and no Edge Case declaration. F-P05 formula `max(0, HP - (-1))` = HP+1, violating P4 (HP > MaxHP). Silent data corruption, no crash. Must add either a defensive guard in F-P05 or an explicit AC declaring out-of-contract behavior.

R3-WARN-2 (WARNING): AC-EC-DEAD-ITEM does not specify which effect_type is tested. ATK_BOOST/DEF_BOOST Dead guard is only in prose (P3 text), not in pseudocode like F-P03/F-P04. Single-scenario AC may leave three effect_type paths untested.

R3-INFO-2 (WARNING-level risk): No AC for "reset after mid-game state" — maxhp_bonus not guaranteed to zero on new-game reset; common bug pattern. GDD should declare whether reset is this system's responsibility or #13's.

### Pattern: AC references nonexistent framework API

R3-BLOCK-1 introduces a new pattern: AC text can reference test framework method names that do not exist, causing the test itself (not the SUT) to crash. Future reviews should explicitly verify that any named assert/spy/helper method exists in the project's pinned GUT version.

**Why:** If the test code crashes, it produces a false "test infrastructure error" that wastes triage time and can be misread as a passing test (crash before assertion = no assertion failure recorded).
**How to apply:** When reviewing ACs that name specific GUT/framework methods, verify against GUT docs for the pinned version before signing off. See [[project-entity-db-qa]] for cross-system signal spec patterns.

---

## Round 4 findings (2026-06-24)

R3's 2 BLOCKINGs CLOSED: AC-P0 correctly split into SIGNAL-UPGRADE/SIGNAL-NOCHANGE with real GDUnit4 API; SignalOrderSpy 3-param callback spec provided.

### Open BLOCKINGs Round 4 (4 total)

R4-BLOCK-1 (BLOCKING): AC-P0-SIGNAL-NOCHANGE states "auto_free 自动检测孤儿" — this is false. auto_free(obj) registers the object for cleanup on test teardown; it does not detect or assert orphan count. The orphan detection claim must be removed. Also auto_free call site (before_each vs test body) is unspecified, which affects lifecycle scope.

R4-BLOCK-2 (BLOCKING): AC-P3-ATK-NOCHANGE, AC-FP02-NOCHANGE, AC-P7-HIGHEST-WINS all require GIVEN "player already holds sword_steel (atk_boost_effective=14)" but do not specify how to inject this precondition. Path A (call pickup_item twice) contaminates watch_signals history making assert_signal_emit_count(1) fail (will see 2). Path B (direct field set) requires field to be public or test-only getter to exist. Must declare one path in AC and align with GDD P7 field visibility rules.

R4-BLOCK-3 (BLOCKING): AC-P4-NOOVERHEAL and AC-FP03-CLAMP are exact duplicates (same numbers, same assertion). Duplicate ACs hide the true coverage gap: the boundary case where current_HP + effect_value == MaxHP exactly (no overflow) has no AC. Must delete one duplicate and add AC-FP03-EXACT for the boundary-equal case.

R4-BLOCK-4 (BLOCKING): Two sub-issues:
  (a) AC-EC-DEAD-ITEM covers only 2/4 Dead guard paths (sword_iron/potion_small). DEF_BOOST (shield_wood) and MAXHP_BOOST (crystal_life) Dead guards have no AC coverage.
  (b) AC-FP05-NEGATIVE-DAMAGE claims GDScript assert() is machine-verifiable in GDUnit4 — it is not. GDScript assert() in debug build causes ENGINE-level script error that halts the test function; GDUnit4 records this as ERROR not PASS. Cannot write a standard unit test for this. Must reclassify as "verified by code review + grep + caller (#5) integration test" instead of a GDUnit4 unit AC.

### Open RECOMMENDEDs Round 4 (5 total)

R4-REC-1: AC-SCOPE-2 calls a helper "SignalSpy" which is not defined anywhere (only SignalOrderSpy is defined). Must clarify: either rename to watch_signals, or define SignalSpy as a separate helper.
R4-REC-2: AC-SCOPE-3 regex missing: rewarded_ad, reward_ad, rewardedVideo, tt_show_rewarded, interstitial, 广告管理. Also grep -i flag must be explicit in the shell command format (regex /i flag alone is insufficient for shell grep).
R4-REC-3: SignalOrderSpy uses class_name which pollutes Godot 4.x global namespace. Prefer no class_name + load() reference pattern to avoid naming conflicts.
R4-REC-4: AC-P1-INIT asserts internal fields (atk_boost_effective, def_boost_effective, maxhp_bonus) but GDD has not declared these fields as publicly accessible. Must declare test-only visibility contract.
R4-REC-5: AC-P8-MVP-STUB says "ATK 不变" without a reference value. Must say "player_ATK equals player_ATK value before the call" (relative, not absolute).

### Pattern: test fixture precondition injection gap
R4-BLOCK-2 introduces a new cross-system pattern: ACs that require a non-initial state (GIVEN player already has X) must specify the injection method — either sequential pickups (invalidating signal count) or direct field set (requiring visibility declaration). Neither is a default. Future AC reviews should flag any GIVEN that requires non-zero state without specifying how to reach it.

**Why:** Ambiguous fixture setup causes qa-tester to pick the wrong path, producing tests that either always fail (path A) or require implementation changes (path B).
**How to apply:** Flag any GIVEN describing "player already has [equipment/state]" without a matching setup instruction. See [[project-entity-db-qa]] for similar injection patterns in entity-database review.

---

## Round 5 findings (2026-06-25)

All R4 BLOCKINGs CLOSED. 4 new BLOCKINGs identified.

### R4 BLOCKING closure status
- R4-BLOCK-1: CLOSED — auto_free clarification note added to AC-P0-SIGNAL-NOCHANGE; orphan-detection claim removed.
- R4-BLOCK-2: CLOSED — Preamble now mandates pickup_item() before watch_signals(); private-field injection prohibited.
- R4-BLOCK-3: CLOSED — AC-FP03-CLAMP removed; AC-FP03-EXACT added with distinct fixture numbers.
- R4-BLOCK-4(a): CLOSED — AC-EC-DEAD-ITEM now explicitly lists all 4 effect_type paths.
- R4-BLOCK-4(b): CLOSED — AC-FP05-NEGATIVE-DAMAGE reclassified as non-GDUnit4 with code review + grep + integration test verification path.

### Open BLOCKINGs Round 5 (4 total)

R5-BLOCK-1 (BLOCKING): Preamble mandates pickup_item() for pre-injection but never declares pickup_item()'s parameter signature or grid dependency. If pickup_item() requires a live GridTile object (Signature B), all ACs using it for pre-injection are integration tests, not unit tests. Story type classification is ambiguous for the entire AC set.

R5-BLOCK-2 (BLOCKING): AC-P3-ATK-UPGRADE asserts "sword_steel 格消失" — this is a System #6 (Grid/Map) assertion, not a System #4 (Stats) assertion. Cannot be verified in a PlayerStats unit test without a live grid scene. Either remove from AC-P3-ATK-UPGRADE, or reclassify the story as Integration type.

R5-BLOCK-3 (BLOCKING): AC-FP04-FILL GIVEN "current_HP=任意值（1–100）" is not executable in GDUnit4. No enumerated test value set, no @GdUnitDataProvider parameterization strategy declared. Must replace with explicit values (e.g., [1, 50, 99]) referencing boundary coverage from AC-FP04-DYING and AC-FP04-FULL-START.

R5-BLOCK-4 (BLOCKING, escalated from R4-REC-3): AC-FP04-ORDER code block declares `class_name SignalOrderSpy extends RefCounted`. In Godot 4.x, class_name is eagerly registered project-wide. If any other test helper file uses class_name, this causes a class registry conflict at project load time — breaking all tests, not just the one using SignalOrderSpy. Must remove class_name and use load()/preload() reference instead.

### Open RECOMMENDEDs Round 5

R5-REC-1: AC-SCOPE-1 "两次执行结果完全相同" has no concrete GDUnit4 assertion pattern. Either specify the pattern (run → read state → reset → run again → compare) or reclassify as "verified by design: no RNG source in system."
R5-REC-2: AC-FP04-ORDER signal-order test does not prove field-write order (maxhp_bonus → MaxHP → current_HP). Add a note distinguishing signal order (testable) from field-write order (code review only).
R4-REC-4 (carried): AC-P1-INIT asserts internal fields without declaring test-only visibility contract.
R4-REC-5 (carried): AC-P8-MVP-STUB "ATK 不变" lacks reference value — should say "equals value before call."

### Open OBSERVATIONs Round 5

R5-OBS-1: AC-P7-HIGHEST-WINS and AC-P3-ATK-NOCHANGE share identical fixture — test-function cardinality undeclared. Should note they merge into one test function.
R5-OBS-2: AC-EC-DEAD-DAMAGE covers pre-Dead state but not double-apply_damage in same frame before deferred signal handler runs. Defensive vs trust-based Dead guard contract not declared.

### Pattern: cross-system assertion in unit AC
R5-BLOCK-2 introduces a new pattern: ACs for a stats/logic system can accidentally include assertions that belong to a different system (grid, scene layer, UI). These cross-system assertions make the test an integration test without declaring it as one. Future AC reviews should check every THEN clause for assertions that require a subsystem other than the SUT to be instantiated.

**Why:** Cross-system THEN clauses either silently fail (grid not present) or force integration test scaffolding on what was designed as a unit test, inflating setup complexity.
**How to apply:** For every THEN, ask: "Which system owns this state?" If the answer is not the SUT, flag it.

---

## Round 6 findings (2026-06-25)

Reviewed 7 targeted questions. 2 new BLOCKINGs; 2 R5 BLOCKINGs confirmed as still open (carried); 2 RECOMMENDEDs; 2 OBSERVATIONs.

### R5 BLOCKING closure status (partial)
- R5-BLOCK-1: OPEN (carried) — pickup_item() signature still undeclared in Round 6 AC text.
- R5-BLOCK-2: PARTIALLY ADDRESSED — AC-P3-ATK-UPGRADE tile-disappear assertion removed, but AC-SCOPE-2 contains the same pattern ("道具格 item_id==null") and was not fixed. New issue R6-BLOCK-1 filed for the missed symmetric fix.
- R5-BLOCK-3: OPEN (carried) — AC-FP04-FILL still says "任意（1–100）" with no explicit value array.
- R5-BLOCK-4: Status not confirmed in Round 6 scope; assumed addressed unless re-observed.

### Open BLOCKINGs Round 6 (2 new + 2 carried)

R6-BLOCK-1 (BLOCKING — new): AC-SCOPE-2 THEN clause asserts "道具格 item_id==null" — System #6 (Grid/Map) state, not System #4 (Stats) state. Cannot be verified in a PlayerStats unit test without a live Grid instance. R5-BLOCK-2 fix addressed AC-P3-ATK-UPGRADE but missed the symmetric occurrence in AC-SCOPE-2. Must remove the grid assertion from AC-SCOPE-2 or reclassify as Integration type.

R6-BLOCK-2 (BLOCKING — new): AC-FP05-NEGATIVE-DAMAGE verification chain references "code review + grep + #5 集成测试" but (a) code review is a one-time event that fails under regression, (b) integration test #5 has no file path or AC number — the reference is untraceable. Must: provide explicit path for integration test #5 (e.g., tests/integration/player_stats/test_damage_contract.gd) and add a corresponding AC; replace "code review" with "code review record archived in production/qa/evidence/" so it is retrievable.

R5-BLOCK-1 (carried): pickup_item() parameter signature (Signature A: string-only vs Signature B: string + GridTile) undeclared. All pre-injection usages are ambiguous as unit vs. integration tests.

R5-BLOCK-3 (carried): AC-FP04-FILL "任意（1–100）" not replaced with explicit GdUnitDataProvider value array.

### Open RECOMMENDEDs Round 6

R6-REC-1: AC-EC-DEAD-ITEM should explicitly declare "4 independent @Test functions (not a for-loop)" for each effect_type. For-loop assertion is an anti-pattern in GDUnit4 — failure precision is lost. Also specify target file path (tests/unit/player_stats/test_player_stats_dead_guard.gd).

R6-REC-2: AC-FP04-ORDER is missing a GIVEN (precondition state). Without it, qa-tester may select any fixture, potentially duplicating AC-P3-MAXHP or using an inconsistent initial state. Either declare the fixture explicitly or annotate "this AC is an additional assertion on the AC-P3-MAXHP fixture using SignalOrderSpy rather than GUT watch_signals."

### Open OBSERVATIONs Round 6

R6-OBS-1: Preamble prohibition "禁止直写私有字段" cannot be enforced at the GDScript runtime or GDUnit4 level — GDScript has no true private fields, only naming convention. The prohibition is enforced by code review only. AC text should explicitly state this execution mechanism and add a PR checklist entry.

R6-OBS-2: AC-SCOPE-3 grep verification cannot detect fully dynamic indirect references (e.g., method name constructed at runtime). AC should declare its coverage boundary: "verifies absence of direct identifier references; fully dynamic call paths are out of scope and covered by integration test + code review."

### Pattern: symmetric-closure gap in cross-system fix
R6-BLOCK-1 demonstrates that when a pattern fix is applied to one AC, all ACs containing the same pattern must be identified and fixed in the same pass. R5-BLOCK-2 fixed AC-P3-ATK-UPGRADE but missed AC-SCOPE-2. Cross-system assertion fixes require a full-document grep of the offending pattern, not a targeted single-AC fix.

**Why:** Partial fixes create a false sense of closure — the next round re-opens the same category of issue.
**How to apply:** When closing a cross-system assertion BLOCKING, grep the full AC list for the same assertion type before declaring the round closed. See [[project-entity-db-qa]] re-review symmetric closure memory.

---

## Round 7 findings (2026-06-25)

R6 BLOCKING closure status:
- R6-BLOCK-1: CLOSED — AC-SCOPE-2 grid assertion ("道具格 item_id==null") removed.
- R5-BLOCK-1: CLOSED — pickup_item(item_id: String) single-param Signature A confirmed in P3 and preamble.
- R5-BLOCK-3: CLOSED — AC-FP04-FILL now has explicit array {1, 50, 100} with @DataSet.
- R5-BLOCK-4: OPEN (misidentified as closed in R6 memory) — class_name SignalOrderSpy still present in AC-FP04-ORDER code block. Becomes R7-BLOCK-4.
- R6-BLOCK-2: OPEN (carried) — FP05-NEGATIVE-DAMAGE integration test path still untraceable. Becomes R7-BLOCK-1.

### Open BLOCKINGs Round 7 (4 total)

R7-BLOCK-1 (BLOCKING, carried from R6-BLOCK-2): AC-FP05-NEGATIVE-DAMAGE verification chain paths (1) code review and (3) integration test are still hollow references. No file path, no AC number, no evidence archive path. Must: provide explicit path (tests/integration/player_stats/test_damage_contract.gd) + function name, OR declare "#5 GDD TBD" as Open Question and block Complete on it.

R7-BLOCK-2 (BLOCKING, new): AC-SCOPE-2 references "SignalSpy" which is not defined anywhere in GDD or helpers. The only defined helper is SignalOrderSpy (for ordering). SignalSpy for sync-detection is different. Must: replace with watch_signals()/assert_signal_emitted GDUnit4 standard pattern, or define SignalSpy explicitly in tests/helpers/ and provide path.

R7-BLOCK-3 (BLOCKING, new): AC-EC-DEAD-ITEM requires GIVEN current_HP=0 but GDD's injection convention only covers pickup_item() and prohibits direct private-field writes. current_HP=0 cannot be reached via pickup_item(). Only path is apply_damage(). The resulting player_died() signal emitted during setup is not addressed by convention. Must: declare Dead-state construction path in preamble — recommend "call apply_damage(current_HP) before watch_signals() connection" (symmetric with pickup_item() convention).

R7-BLOCK-4 (BLOCKING, R5-BLOCK-4 reopened): AC-FP04-ORDER code block still has "class_name SignalOrderSpy extends RefCounted". In Godot 4.x this registers globally at project load. Must remove class_name; use preload("res://tests/helpers/signal_order_spy.gd").new() pattern.

### Open RECOMMENDEDs Round 7

R7-REC-1 (carried R5-REC-1): AC-SCOPE-1 has no concrete GDUnit4 execution path or by-design grep alternative. Recommend: replace with grep-based verification pattern (no RNG calls in player_stats.gd) to match AC-SCOPE-3 format.

R7-REC-2 (new): AC-SCOPE-3 regex missing Douyin SDK identifiers (tt.showRewardedVideoAd, RewardedVideoAd, createRewardedVideo, showInterstitial). Current regex can produce false-positive pass even with direct SDK calls present. Extend regex and declare coverage boundary.

R7-REC-4 (carried R6-REC-1): AC-EC-DEAD-ITEM "逐一参数化" not specified as @DataSet or 4 independent @Test functions. Target file path (tests/unit/player_stats/test_player_stats_dead_guard.gd) not declared.

### Open OBSERVATIONs Round 7

R7-OBS-1: AC-P3-ATK-NOCHANGE and AC-FP02-NOCHANGE still contain "格消失" cross-system assertions (R5-BLOCK-2 fix symmetric gap, same as R6-OBS on AC-SCOPE-2 pattern). Should be removed in same pass as any future cross-system cleanup.

R7-OBS-2: AC-SCOPE-2 GIVEN "裸装" is the initial state — no pre-injection needed. The relationship between this AC and the injection convention should be clarified to avoid double-connection confusion.

---

## Round 8 findings (2026-06-25)

All 4 R7 BLOCKINGs CLOSED. 0 new BLOCKINGs. 2 RECOMMENDEDs carried forward (both 2+ rounds old).

### R7 BLOCKING closure status
- R7-BLOCK-1: CLOSED — AC-FP05-NEGATIVE-DAMAGE path (2) has explicit grep command; path (3) has TBD placeholder referencing Open Questions.
- R7-BLOCK-2: CLOSED — AC-SCOPE-2 no longer contains "SignalSpy"; uses assert_signal_emitted_with_parameters directly.
- R7-BLOCK-3: CLOSED — Dead-state construction preamble paragraph present with apply_damage(100) injection pattern.
- R7-BLOCK-4: CLOSED — AC-FP04-ORDER code block has no class_name; preload path "res://tests/helpers/signal_order_spy.gd" is commented inline.

### Open BLOCKINGs Round 8
None.

### Open RECOMMENDEDs Round 8 (both carried)

R7-REC-1 (3rd carry): AC-SCOPE-1 THEN "两次结束时属性值完全相同" has no concrete GDUnit4 execution path or grep verification pattern. No RNG-source grep (randf/randi/RandomNumberGenerator) declared. Recommend adding grep pattern matching AC-SCOPE-3 format. **Escalate to BLOCKING in R9 if still unresolved.**

R7-REC-2 (2nd carry): AC-SCOPE-3 regex `/ad_manager|show_ad|request_ad|ad_sdk|激励广告/` missing Douyin SDK real identifiers: showRewardedVideoAd, RewardedVideoAd, createRewardedVideo, showInterstitial. False-positive pass risk remains. Recommend extending regex and declaring coverage boundary. **Escalate to BLOCKING in R9 if still unresolved.**

### Open OBSERVATIONs Round 8

R8-OBS-1 (carried R7-REC-4, 3rd carry): AC-EC-DEAD-ITEM "逐一参数化" still not specified as @DataSet 4 independent @Test functions vs for-loop. Target file path tests/unit/player_stats/test_player_stats_dead_guard.gd not declared. Low priority but should be closed before test authoring begins.
