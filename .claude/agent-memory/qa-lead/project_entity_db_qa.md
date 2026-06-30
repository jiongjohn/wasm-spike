---
name: project-entity-db-qa
description: QA adversarial review of entity-database GDD — known gaps and missing ACs, four review rounds completed (latest: Round 4: 2026-06-24); 6 open BLOCKINGs after Round 4
metadata:
  type: project
---

## Round 1 findings (2026-06-23, original version)

Adversarial QA review of `design/gdd/entity-database.md` completed 2026-06-23.

Key findings that survived the review and are load-bearing for future test authoring:

- AC-04 "100 次掉落" clause is untestable at the data-layer unit level — the 100-query loop belongs in the drop system test, not the entity DB test.
- AC-05 scope is same-floor only; cross-floor same-boss_id scenario (boss reappears on a different floor) is not covered.
- No AC for MAXHP_BOOST behavior: does it raise ceiling only, or also restore current HP to new max?
- No AC for FRAGMENT pickup behavior (effect_type not in standard ItemEntry enum path).
- No AC for KeyEntry type safety / inheritance correctness.
- No AC for effect_value=0 pickup behavior (GDD says it's legal but "does nothing").
- gold_drop=0 contradicts field spec (≥1) — contradiction not resolved, no AC tests the 0-gold path.
- AC-02 THEN clause is ambiguous: "校验结果为 PASS" is not independently machine-readable.
- AC-09 GIVEN is underspecified: which Entry ID is missing the field? Test is non-deterministic without it.
- Missing: monster_HP < 0 (negative HP) has no AC despite Edge Cases calling it "illegal".
- Missing: duplicate ID validation (two MonsterEntries with same id).
- Missing: ItemEntry enum validation (sprite_id field present/correct type check).
- Missing: get_monster() returns null for unknown ID, and caller behavior.
- Missing: D1 constraint for Boss beast_king with its actual ATK=40 (GDD table uses 40, but AC-02 only tests skeleton).

## Round 2 findings (2026-06-23, revised version, AC-01 to AC-14)

**Resolved from Round 1** (confirmed closed):
- Duplicate ID → AC-10 added, CLOSED
- get_monster() null return → AC-11 added, CLOSED
- KeyEntry type safety → AC-12 added, CLOSED
- monster_HP ≤ 0 → AC-07 added, CLOSED

**Still open from Round 1** (carried into Round 2):
- `is_boss=false` + `rare_drop_item_id!=null` no AC → BUG-5, BLOCKING
- `effect_value < 0` no AC → BUG-6, BLOCKING
- monster_ATK=0 WARNING no AC → BUG-7, ADVISORY
- AC-02 THEN interface still partially ambiguous → BUG-3, ADVISORY

**New blocking findings from Round 2:**

BUG-1 (BLOCKING): "游戏不进入主界面" is not assertable by GUT. Affects AC-03/04/07/08/09/10/13/14. Under WASM/headless, quit() is forbidden (Edge Cases note); error screen is a Control node not rendered headless. All Integration ACs need a machine-assertable proxy (e.g., validation function returns is_valid=false, or signal emitted). Without this, test authors cannot write passing/failing GUT assertions.

BUG-2 (BLOCKING): AC-06 read-only test does not verify "guard rejects write". Under duplicate() implementation: entry.hp = X modifies only caller's copy — database unchanged trivially, not because of any protection. Under set() guard: guard may silently ignore write. Either way AC-06 passes even if no protection exists. Need to assert: attempted write triggers expected protection mechanism (copy independence OR guard call evidence).

BUG-4 (BLOCKING): DEF independent upper bound (monster_DEF < player_ATK_expected) has no AC. This is a separate code path from D1 round-count check. AC-03 (test_tank) tests the D1 round-count violation, not the DEF ceiling violation. Both are declared in Formulas section as required checks.

BUG-8 (BLOCKING): Three Anti-Pillars scope-gate checks (no random in combat, no extra loop steps, ad triggers player-initiated) all missing from AC-01–14. systems-index.md Design Constraints says "必须包含" (mandatory). Until explicit exemption syntax is approved by design lead + tech director, this is blocking.

BUG-9 (ADVISORY, potentially BLOCKING): AC-02 uses VS-tier skeleton data (hp=90, def=10, ATK_exp=35) to validate D1 PASS path, not MVP data (slime, goblin). Tuning Knobs notes MVP monsters passed D1 but D3 validation is pending #3 tuning config. No AC verifies MVP data set passes D3 — if D3 fails on slime/goblin after #3 is finalized, MVP data is illegal but no test catches it.

BUG-10 (ADVISORY): AC-03/04 "startup validation runs" depends on game init sequence that may not exist when MVP main scene is unimplemented. Recommend AC note: "testable by calling validate() directly without main scene."

**Total Round 2 BLOCKINGs: 6 (BUG-1/2/4/5/6/8)**

**Why:** All of these represent gaps where the implementation could be wrong and no automated test would catch it.
**How to apply:** When the entity-database implementation story is created, require unit test coverage for every bullet above before marking Logic stories Done. BUG-1 is highest priority — fix first as it unblocks assertability of 8 ACs. BUG-8 needs design/tech-director ruling on scope-gate exemption policy.

## Round 3 findings (2026-06-24, version with AC-01 to AC-19)

**Resolved from Round 2** (confirmed by GDD text):
- BUG-1: "游戏不进入主界面"不可断言 → 断言契约已加入 GDD (validate_database() → ValidationResult), CLOSED
- BUG-4: DEF 独立上限无 AC → AC-15 added, CLOSED
- BUG-5: is_boss=false + rare_drop_item_id!=null → AC-16 added, CLOSED
- BUG-6: effect_value<0 → AC-17 added, CLOSED
- BUG-8: Anti-Pillars scope-gate → creative-director exemption documented in GDD AC preamble, CLOSED

**Still open from Round 2:**
- BUG-2: AC-06 set() 守卫实现的子断言与副本实现不兼容，等 ADR 锁定 → STILL BLOCKING
- BUG-3: AC-02 damage_per_round/min_damage_required 不在 ValidationResult schema → STILL BLOCKING
- BUG-9: MVP 数据集未验证 D3 — still pending #3 tuning config → STILL ADVISORY
- BUG-10: AC-03/04 depends on main scene init — mitigated by validate_database() proxy → ADVISORY, downgraded

**New blocking findings from Round 3:**

Q2-BLOCK (BLOCKING): AC-14 MVP 构建标志传入方式未定义。GDD 断言契约签名为 validate_database(entries)，但 AC-14 要求"在 MVP 构建标志下调用"。GDScript 无条件编译，构建标志必须是运行时参数或全局配置——两者都未在 GDD 或 ADR 中定义。测试作者无法编写 AC-14 的 GUT 测试用例。Needs: ADR or AC text amendment to specify signature.

BUG-A (BLOCKING): get_item() 查询接口字段正确性无 AC。AC-05 只测 get_monster("slime")。get_item("potion_small") 返回 effect_type/effect_value/stack_rule 的正确性无任何覆盖。Critical path to #4 player attribute system.

BUG-B (BLOCKING): gold_drop < 1 报错路径无 AC。Edge Cases 明确声明非法，但无对应 AC（与 AC-07 hp≤0 的对称缺失）。

**New advisory/recommended findings from Round 3:**

AC-01-LOG: "0 条 ERROR 日志"在 headless GUT 下无内置断言机制。建议改为断言 ValidationResult.errors 为空。RECOMMENDED.

AC-12-IFACE: get_item("key_yellow") 的行为在接口语义上有歧义——get_item() 是否返回 entity_type=KEY 的条目？GDD 接口约定节未定义。RECOMMENDED fix before implementation.

AC-15-OVERLAP: test_highdef 数据同时违反 DEF_EXCEEDS_ATK 和 D1，两条错误可能互相干扰测试。建议用 hp=1,def=12,ATK=10 替代（D1 因 HP=1 漏洞通过，DEF_EXCEEDS_ATK 独立触发）。RECOMMENDED.

BUG-C: N_max越界/player_ATK_expected越界 专属报错路径（GDD Formulas D1节有明确要求）无 AC。RECOMMENDED.
BUG-D: effect_value=0 合法 case 无 is_valid==true 断言，可能被错误实现为 NEGATIVE_EFFECT_VALUE 假阳性。RECOMMENDED.
BUG-E: 空数据集 validate_database([]) 行为未定义、无 AC。WASM 首次启动文件读取失败的真实场景。RECOMMENDED.
BUG-F: monster_ATK=0 警告路径无 AC，警告的结构（ValidationResult 内 vs push_warning）未定义。MINOR.
BUG-G: KeyEntry effect_value 字段缺省不报错（规则 C5）无 AC 验证，与 AC-09 MonsterEntry 必填字段报错语义差异没有对应测试。MINOR.
BUG-H: 跨 entity_type 重复 ID 合法 case 无 AC，可能导致实现者做全局唯一性校验误判合法数据。MINOR.

AC-19-PARTIAL: AC-19 "可见错误屏节点"在 headless 下只能断言 has_node() + visible属性，无法验证实际显示。节点名称和主游戏场景名称未定义，has_node() 断言无法编写。如不补充定义，升级为 BLOCKING。ADVISORY→潜在 BLOCKING.

AC-03/04-MSG: message 字段内容断言脆弱（中英文/格式差异导致 false negative）。建议固定 message 模板或只断言 code+entry_id。RECOMMENDED.

**Total Round 3 new BLOCKINGs: 3 (Q2-BLOCK, BUG-A, BUG-B)**
**Total cumulative open BLOCKINGs after Round 3: 5 (BUG-2, BUG-3, Q2-BLOCK, BUG-A, BUG-B)**

**Why:** Round 3 focused on interface-level gaps (get_item(), build flag signature) and headless assertability of the new ACs. The ValidationResult schema gap (BUG-3) remains the most structurally dangerous — it means D1 formula accuracy is currently untested even with all ACs passing.
**How to apply:** Block implementation story start until Q2-BLOCK (AC-14 signature) and BUG-A (get_item AC) are resolved. BUG-3 requires either ValidationResult schema extension or a separate formula unit test. AC-15 test data should be replaced with hp=1 variant to isolate DEF_EXCEEDS_ATK from D1 overlap.

## Round 4 findings (2026-06-24, version with AC-01 to AC-20, new signature with build_scope default)

**Resolved from Round 3:**
- Q2-BLOCK: AC-14 build_scope传参——新签名 validate_database(entries, build_scope: String = "MVP") 已将 build_scope 纳入默认参数，CLOSED
- BUG-B: gold_drop<1 无 AC → AC-20 added, CLOSED（建议补充 gold_drop=-1 变体）
- BUG-A: 降级合并入 R4-BLOCK-4（get_item语义边界问题）

**Still open from Round 3:**
- BUG-2: AC-06 set()守卫断言分支互斥，等 ADR 锁定 → STILL BLOCKING
- BUG-3: AC-02 computed 字段不在 ValidationResult schema → STILL BLOCKING
- BUG-9: MVP 数据集未验证 D3，pending tuning config → STILL ADVISORY

**New blocking findings from Round 4:**

R4-BLOCK-1 (BLOCKING): AC-03/07/08/09/10/13/15/16/17/18 调用 validate_database() 无参，但 entries 是必填参数无默认值。GDScript 运行时报 "Too few arguments"，10 个 Logic AC 测试无法运行（非测试失败，是执行失败）。两种补救方式（补传 entries vs 加默认值 =[]）语义不同，AC 文档必须消歧。

R4-BLOCK-2 (BLOCKING): AC-02 中 player_ATK_expected=35 是 D1 公式必要输入，但 validate_database 签名无此参数。注入接缝（全局配置 vs entries context）未定义，测试作者无法在 GUT setup() 中控制这个值，computed["damage_per_round"]==25 断言无法确定性复现。

R4-BLOCK-3 (BLOCKING): validate_database([]) 空数据集行为未定义（从 Round 3 BUG-E 升格）。WASM 文件读取失败的真实降级路径；空 entries 时 is_valid 为 true 还是 false 直接影响 AC-19 Integration 触发条件。

R4-BLOCK-4 (BLOCKING): get_item() 语义边界 + AC-19 节点名称（从 Round 3 AC-12-IFACE + AC-19-PARTIAL 升格）。get_item() 是否返回 entity_type=KEY 条目未定义（直接决定 AC-12 通过与否）；AC-19 错误屏节点名称未定义（has_node() 断言无法编写）。

**New recommended findings from Round 4:**

AC-20-NEG: gold_drop=-1 未测试（AC-20 只测 0），建议补 gold_drop=-1 变体或确认 INVALID_GOLD_DROP 覆盖所有 <1 值。RECOMMENDED.

6a-BOSS-NULL: is_boss=true, rare_drop=null 合法场景无 is_valid==true 断言。实现者若误写"Boss必须有rare_drop"，无测试捕捉。RECOMMENDED.

6d-VS-SCOPE: validate_database([fragment], build_scope="VS") → is_valid==true 无 AC。若实现者全局拒绝 FRAGMENT，VS 构建数据无法加载，且 AC-14 仍通过。RECOMMENDED.

AC-15-OVERLAP: 仍未修复（Round 3 已标注，Round 4 AC 文本未更新）。test_highdef 数据同时违反 DEF_EXCEEDS_ATK 和 D1，可能导致 D1_VIOLATION 短路，DEF_EXCEEDS_ATK 检查从未执行，测试假过。RECOMMENDED.

AC-09-FORMAT: "数据格式硬约束为JSON"的架构理由不应写在功能 AC 中，应移入 ADR。RECOMMENDED.

**Total Round 4 new BLOCKINGs: 4 (R4-BLOCK-1/2/3/4)**
**Total cumulative open BLOCKINGs after Round 4: 6 (BUG-2, BUG-3, R4-BLOCK-1, R4-BLOCK-2, R4-BLOCK-3, R4-BLOCK-4)**

**Why:** Round 4 revealed that the new explicit signature (entries required, build_scope optional) created a mass-failure scenario where 10 ACs reference an invalid call form. player_ATK_expected injection is the most architecturally load-bearing gap — it may require a ValidationContext parameter or a separate BalanceConfig autoload.
**How to apply:** R4-BLOCK-1 (call signature fix across 10 ACs) is fastest to fix and should be done first — it is a pure text change. R4-BLOCK-2 (player context injection) requires an ADR. R4-BLOCK-3 and R4-BLOCK-4 require AC additions. Do not start GUT test authoring until all 4 are resolved.
