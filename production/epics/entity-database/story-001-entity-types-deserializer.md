# Story 001: EntityDB 数据类型 + JSON 反序列化器

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M（2-4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-07-01

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-003`（entity_type 判别字段，所有条目必须携带）、`TR-entity-004`（stack_rule 字段承载 HIGHEST_WINS/ADDITIVE）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001（数据类型实现，主）；ADR-0005（数据文件组织，次）
**ADR Decision Summary**: 8 个跨模块数据类型统一 `class_name + Resource` 子类，**全数据字段 `@export`**（`duplicate()/duplicate_deep()` 只拷贝 STORAGE 属性，plain `var` 副本被重置）；JSON 反序列化显式 `int()` 转型、enum 用字符串名 + 映射表、`def`→`defense`、缺字段 `push_error`+返回 null（不填默认、不降级）。

**Engine**: Godot 4.5.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate()`/`duplicate_deep()` 为 4.5+ 且仅 `Resource` 有（`RefCounted` 无，已 spike 实证）。`JSON.parse_string()` 可能把整数解析为 float → int 字段须显式 `int()`。GDScript 每文件仅一个 `class_name`（3 个类型 → 3 个文件）。

**Control Manifest Rules (Foundation)**:
- Required: 数据类型 `class_name + Resource` + 每字段 `@export var`；JSON int 字段显式 `int()`；enum 字符串→int 映射表；缺字段 `push_error`+null
- Forbidden: 裸 `RefCounted` 载体；plain `var`（非 @export）数据字段；`def` 作字段名；untyped `Dictionary` 作公共接口
- Guardrail: 反序列化在启动一次性执行，无运行期 JSON 访问

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md`, scoped to this story:*

- [ ] MonsterEntry/ItemEntry/KeyEntry 均为 `class_name + Resource` 子类，每个数据字段 `@export var`，字段与类型符合 GDD 规则 C3/C4/C5（MonsterEntry 防御字段名为 `defense` 非 `def`）
- [ ] 每类型提供 `from_dict(data: Dictionary, entry_id: String) -> [Type]` 静态工厂：所有 int 字段显式 `int()` 转型；enum 字段经字符串→int 映射表（未知字符串 → `push_error`+null）；`entity_type` 判别字段正确赋值
- [ ] **AC-09**：MonsterEntry 缺必填字段（如 `atk`）→ `from_dict` 走缺字段检测路径，`push_error` 且**返回 null，不填默认值、不降级**；校验层可据此报 `field=="atk"`/`code=="MISSING_FIELD"`
- [ ] KeyEntry 的 `effect_value` 缺省按 0 处理，不报「字段缺失」（GDD 规则 C5）

---

## Implementation Notes

*Derived from ADR-0001 + ADR-0005 Implementation Guidelines:*

- 三个文件：`src/entity/monster_entry.gd` / `item_entry.gd` / `key_entry.gd`（每文件一个 `class_name`）。
- 字段全 `@export var`（ADR-0001 决策细则 5）——包括标量与 String。**不得**有裸 `var` 数据字段（CI lint 会 grep）。
- enum 用 int 常量 + 字符串→int 映射（如 `ENTITY_TYPE_MAP`、`EFFECT_TYPE_MAP`、`STACK_RULE_MAP`、`KEY_COLOR_MAP`）；映射查不到用 `.get(key, -1)` 哨兵，-1 → `push_error`+null（参照 ADR-0005 CellEntry.from_dict 模式）。
- `from_dict` 必填字段检测：`for field in [...]: if not data.has(field): push_error(...); return null`（assert 在 release 被剥离，不能作唯一手段）。
- int 转型：`entry.hp = int(data["hp"])`；String：`str(data["id"])`；bool：`bool(data["is_boss"])`；可选字段：`str(data.get("rare_drop_item_id", ""))`（"" 表示无）。
- `effect_type` 枚举含 `KEY`（GDD 规则 C4）；`entity_type=KEY` 的 KeyEntry 的 `effect_type` 固定 KEY。
- **本 story 只做类型 + 反序列化**，不做语义校验（D1/D3/引用/唯一性 → 002/003），不做查询/Autoload（→ 004/006）。缺字段检测（AC-09 的 from_dict 层）在此，但 AC-09 的 `validate_database` 断言面在 003（须与实现方约定：缺字段检测既可在 from_dict，也可在 validate 的 dict 层——参照 TuningConfig 的 validate_dict 模式，二者取一，记录于 002/003）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002/003：`validate_database` 语义校验（D1/D3/引用/唯一性/组合）
- Story 004：查询接口 + 只读副本
- Story 005：entities.json 数据内容
- Story 006：Autoload 装配 + 启动加载

---

## QA Test Cases

*Transcribed from GDD Acceptance Criteria. 实现方按此测，勿另造。*

- **类型/字段构造**（AC 基座）
  - Given: 一份合法 MonsterEntry dict（含全字段）
  - When: `MonsterEntry.from_dict(data, "slime")`
  - Then: 返回非 null，`entity_type==MONSTER`、`hp/atk/defense/gold_drop` 为 int（非 float）、`is_boss` 为 bool、`defense` 字段存在（非 `def`）
  - Edge cases: JSON 传入 `"hp": 20`（整数）与 `"hp": 20.0` 两种，`from_dict` 后 `hp` 均为 int 20；`typeof(entry.hp)==TYPE_INT`

- **AC-09 必填字段缺失**
  - Given: MonsterEntry dict 缺 `atk`
  - When: `MonsterEntry.from_dict(data, "test_missing_atk")`
  - Then: `push_error` 触发；返回 `null`；**不产生填了默认值的对象**
  - Edge cases: 逐个必填字段（id/hp/atk/defense/gold_drop/is_boss）各缺一次，每次返回 null

- **KeyEntry effect_value 缺省**
  - Given: KeyEntry dict 无 `effect_value` 字段
  - When: `KeyEntry.from_dict(data, "key_yellow")`
  - Then: 返回非 null；`effect_value==0`；不报缺失
  - Edge cases: `key_color`/`opens_door_color` 字符串正确映射为 int

- **enum 未知字符串**
  - Given: ItemEntry dict 的 `effect_type` 为拼写错误字符串（如 `"HP_RESTOER"`）
  - When: `ItemEntry.from_dict(data, "x")`
  - Then: `push_error`；返回 `null`（哨兵 -1 路径）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/entity_types_test.gd` — 须存在且通过（GDUnit4 headless，Godot 4.5.2）。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（Foundation 层首个 EntityDB story；类型独立，不依赖 TuningConfig）
- Unlocks: Story 002/003（校验器操作这些类型）、Story 004（查询返回这些类型的副本）

---

## Completion Notes
**Completed**: 2026-07-01
**Criteria**: 4/4 通过（三类型+@export+defense / from_dict enum+int()+映射 / AC-09 逐字段缺失→null / KeyEntry effect_value 缺省 0）；GDUnit4 56/56 PASSED（Godot 4.5.2，report_12 + story-done 重跑）
**Deviations**:
- [ADVISORY / tech debt] `sprite_id` 必填性延后：GDD 规则 C3-C5 标 sprite_id 非空必填，但 MVP 数据表（Tuning Knobs）无 sprite_id 列 → 本 story 保持 sprite_id 可选（空串默认）+ 代码 tech debt 注释，待美术 Atlas 规范定义后转必填。用户决策 A（2026-07-01）：display_name 设必填、sprite_id 保持可选。已记入 docs/tech-debt-register.md。
- [过程] AC-09 缺字段检测落在 `from_dict` 层（push_error+null）；validate dict 层归属留 002/003。
- [code-review 纠偏] engine-programmer 初版把 display_name/sprite_id 都降为可选（违反 GDD C3-C5 非空）+ KeyEntry.from_dict 允许非 KEY 的 effect_type 静默通过（W-04，违反 C5 联合校验）。均已修：display_name 转必填、KeyEntry effect_type≠KEY→null、Item/Key 补对称测试（AC-09 逐字段 + duplicate 独立性）。
**Test Evidence**: Logic — `tests/unit/entity/entity_types_test.gd`（56 test cases / 0 failures / PASSED ~1.9s，Godot 4.5.2 + GDUnit4）
**Code Review**: Complete（godot-gdscript-specialist，score 88 → APPROVE WITH SUGGESTIONS；W-04/W-01-03/W-05-06 全修，重跑 56/56）
**Files**: src/entity/{monster_entry,item_entry,key_entry}.gd + tests/unit/entity/entity_types_test.gd
