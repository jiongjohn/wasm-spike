# Story 003: validate_database — schema/引用/唯一性校验（两遍加载）

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: L（4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-001`（启动校验，schema 面）、`TR-entity-003`（entity_type×effect_type 联合校验，规则 C4）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005（数据合法性 + 两遍加载，主）；ADR-0002（校验流程，次）
**ADR Decision Summary**: 两遍加载——第一遍建表并**在建表过程中捕获重复 ID**（不可延至第二遍，否则后者静默覆盖前者），第二遍做跨引用与约束校验（避免「引用的 ItemEntry 尚未载入」误报）。校验失败结构化返回（不填默认、不降级）。

**Engine**: Godot 4.5.2 | **Risk**: MEDIUM
**Engine Notes**: 纯函数校验，headless 可测。重复 ID 检测须在写入表**之前**判断（`if table.has(id)` 再写），否则 Dictionary 覆盖后无法回溯。

**Control Manifest Rules (Foundation)**:
- Required: 两遍加载（pass1 建表+重复捕获，pass2 跨引用）；结构化 errors；entity_type×effect_type 联合校验
- Forbidden: 重复 ID 静默覆盖；填默认掩盖非法数据；只靠 assert
- Guardrail: 校验启动一次性执行

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md`, scoped to this story:*

- [ ] `validate_database` 实现两遍加载：pass1 按 `entity_type` 建表 + 捕获重复 ID；pass2 跨引用校验
- [ ] **AC-10**：重复 ID（同 entity_type 内两条 `id=test_dup` MONSTER）→ `is_valid==false`，errors 含 `code=="DUPLICATE_ID"`/`entry_id=="test_dup"`；后者不静默覆盖前者（覆盖前即捕获）
- [ ] **AC-08**：`test_boss`(is_boss=true, rare_drop_item_id="nonexistent_id")，items 表无该 ID → `code=="DANGLING_REF"`/`entry_id=="test_boss"`，message 含 `nonexistent_id`（pass2 跨引用）
- [ ] **AC-16**：`test_fakeboss`(is_boss=false, rare_drop_item_id="sword_iron") → `code=="NONBOSS_RARE_DROP"`（普通怪 rare_drop_item_id 必须为 null/""）
- [ ] **AC-13**：`test_badkey`(key_color=YELLOW, opens_door_color=BLUE) → `code=="KEY_COLOR_MISMATCH"`
- [ ] **AC-18**：`test_itemkey`(entity_type=ITEM, effect_type=KEY, effect_value=0) → `code=="ILLEGAL_TYPE_EFFECT_COMBO"`（逐字段合法但组合非法，规则 C4）
- [ ] **AC-14**：build_scope=="MVP" 下 `test_fragment`(effect_type=FRAGMENT) → `code=="FRAGMENT_OUT_OF_SCOPE"`（FRAGMENT 处理器在 VS）

---

## Implementation Notes

*Derived from GDD Edge Cases + 规则 C4/C6 + ADR-0005:*

- 在 002 的 `validate_database` 上扩展（同文件 `entity_db_validator.gd`）。
- **两遍**：
  - pass1：遍历 entries，按 `entity_type` 分别写入 `_monsters/_items/_keys` 临时表；写入前 `if table.has(id): 报 DUPLICATE_ID`（AC-10）。同时收集 item id 集合供 pass2。
  - pass2：对每 MonsterEntry，若 `rare_drop_item_id != ""` 检查是否在 item id 集合中（AC-08 `DANGLING_REF`）；`is_boss==false` 且 `rare_drop_item_id != ""` → `NONBOSS_RARE_DROP`（AC-16）。
- **KeyEntry**：`key_color != opens_door_color` → `KEY_COLOR_MISMATCH`（AC-13，规则 C5 1:1 映射）。
- **联合校验**（AC-18，规则 C4）：`entity_type==ITEM 且 effect_type==KEY` → `ILLEGAL_TYPE_EFFECT_COMBO`。逐字段都合法（ITEM 合法、effect_value 合法、KEY 在枚举内），组合语义非法。
- **build_scope 门**（AC-14）：`build_scope=="MVP" 且 effect_type==FRAGMENT` → `FRAGMENT_OUT_OF_SCOPE`。VS scope 下不报（此判据将来 VS 放开）。
- 跨 entity_type 同名 ID 技术上分表可工作（不报错），但 GDD 建议全局唯一——本 story **不**强制跨类型唯一（GDD 用「强烈建议」措辞，非 must）。
- error.field/code：snake_case field，UPPER_SNAKE code。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 002：D1/D3/DEF/HP/gold/effect_value 数值校验（已建 validate_database 骨架 + ValidationConfig/Result）
- Story 006：运行时以 build_scope 执行
- 跨 entity_type 全局唯一 ID 强制（GDD 为「建议」非强制，不实现）

---

## QA Test Cases

*Transcribed from GDD AC.*

- **AC-10**（重复 ID）
  - Given: 两条 entity_type=MONSTER、id="test_dup"
  - Then: `is_valid==false`；`code=="DUPLICATE_ID"`/`entry_id=="test_dup"`；断言捕获发生在覆盖前（可断言 errors 恰含一条 DUPLICATE_ID）
  - Edge cases: 三条中两条重复 vs 全不重复（负向对照，后者 is_valid 面不含 DUPLICATE_ID）
- **AC-08**（悬空引用，pass2）
  - Given: `test_boss`(is_boss=true, rare_drop_item_id="nonexistent_id")，items 无该 id
  - Then: `code=="DANGLING_REF"`/`entry_id=="test_boss"`，message 含 `nonexistent_id`
  - Edge cases: rare_drop_item_id 指向**存在**的 item → 不报 DANGLING_REF（负向对照）
- **AC-16**（普通怪稀有掉落）
  - Given: `test_fakeboss`(is_boss=false, rare_drop_item_id="sword_iron")
  - Then: `code=="NONBOSS_RARE_DROP"`
- **AC-13**（key 颜色不匹配）
  - Given: `test_badkey`(key_color=YELLOW, opens_door_color=BLUE)
  - Then: `code=="KEY_COLOR_MISMATCH"`
  - Edge cases: key_color==opens_door_color → 不报（负向）
- **AC-18**（非法组合）
  - Given: `test_itemkey`(entity_type=ITEM, effect_type=KEY, effect_value=0)
  - Then: `code=="ILLEGAL_TYPE_EFFECT_COMBO"`
- **AC-14**（FRAGMENT 越界）
  - Given: `test_fragment`(effect_type=FRAGMENT)；build_scope="MVP"
  - Then: `code=="FRAGMENT_OUT_OF_SCOPE"`
  - Edge cases: 同数据 build_scope="VS" → 不报 FRAGMENT_OUT_OF_SCOPE（负向对照）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/validate_database_schema_test.gd` — 须存在且通过（GDUnit4 headless）。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（类型）、Story 002（validate_database 骨架 + ValidationConfig/Result）
- Unlocks: Story 005（smoke 用完整校验器）、Story 006（运行时执行完整校验）

---

## Completion Notes
**Completed**: 2026-07-01
**Criteria**: 6/6 AC 通过（AC-08/10/13/14/16/18）+ 各负向对照 + 合法集回归（含 boss+有效 rare_drop happy-path）+ 3-重复边界 = 19 测试；entity 全目录 98/98 PASSED（numeric/types 无回归）
**Deviations**:
- [OUT OF SCOPE — 有效] F-13 跨 story 修复触及 `src/entity/monster_entry.gd`（story-001，已关闭）：`rare_drop_item_id = "" if raw == null else str(raw)`，防 JSON null → `str(null)` 非空串 → 误报 DANGLING_REF。审查发现的真实隐患，1 行防御，entity_types_test 56 仍全过。正当跨 story 修复。
- [ADVISORY] DUPLICATE_ID 对 n 条同 id 报 n-1 次（每次碰撞一报）——已加代码注释固定 + `test_validator_schema_three_all_same_id_reports_twice` 锁定行为
- [ADVISORY] DANGLING_REF/NONBOSS_RARE_DROP 双报已按根因优先消除（NONBOSS 时 elif 跳过 DANGLING）
- [F-06 加固] build_scope 加 `BUILD_SCOPE_MVP/VS` 常量 + `strip_edges().to_upper()` 标准化，防 "mvp" 大小写静默放行 FRAGMENT
- [F-03 加固] pass1 未知/null Entry 类型 `push_warning`（利于 story-006 发现 from_dict null 未过滤）
**Test Evidence**: Logic — `tests/unit/entity/validate_database_schema_test.gd`（19 test cases / 0 failures / PASSED，Godot 4.5.2 + GDUnit4；entity 全目录 98/98）
**Code Review**: Complete（godot-gdscript-specialist，7.5/10 → APPROVE WITH SUGGESTIONS；F-04/F-06/F-13/F-03/F-08/F-11/F-01/F-12 全修，重跑 98/98）
**Files**: src/entity/entity_db_validator.gd（扩展）+ tests/unit/entity/validate_database_schema_test.gd + src/entity/monster_entry.gd（F-13 跨 story）
