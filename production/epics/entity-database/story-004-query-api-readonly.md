# Story 004: EntityDB 查询接口 + 只读副本

> **Epic**: 游戏实体数据库 (EntityDB)
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S（2h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/entity-database.md`
**Requirement**: `TR-entity-002`（只读访问模式，getter 返回 `duplicate()` 副本，下游写入不污染数据库）
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001（数据类型 + 只读副本）
**ADR Decision Summary**: EntityDB getter 返回 `.duplicate()` 副本（扁平结构浅拷贝足够——Monster/Item/Key 无嵌套 Resource 字段），下游对副本的写入只污染副本，不触权威数据。查询按类型分表：`get_monster`/`get_item`/`get_key` 各只返回对应 `entity_type`，错类型/不存在返 null（不抛异常）。

**Engine**: Godot 4.5.2 | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate()` 仅拷贝 `@export` 字段（001 已保证全 @export）；扁平结构浅拷贝即独立。查询不存在 ID 返 null，调用方负责处理。

**Control Manifest Rules (Foundation)**:
- Required: 只读数据源 getter 返回副本（扁平 `.duplicate()`）；查询按类型分表；不存在返 null
- Forbidden: getter 返回内部原始引用（污染权威数据）；untyped Dictionary 公共返回
- Guardrail: 扁平 duplicate() 开销极小（<1µs/次）

---

## Acceptance Criteria

*From GDD `design/gdd/entity-database.md`, scoped to this story:*

- [ ] `get_monster(id) -> MonsterEntry`（仅 entity_type=MONSTER）、`get_item(id) -> ItemEntry`（仅 ITEM，**不含 KEY**）、`get_key(id) -> KeyEntry`（仅 KEY）；均返回 `.duplicate()` 副本
- [ ] **AC-05**：`get_monster("slime")` 返回 `gold_drop==5`、`is_boss==false`、`rare_drop_item_id==""(null 语义)`、`entity_type==MONSTER`
- [ ] **AC-06**：查询取对象 A、对 `A.hp=999`、再查得 B → `B.hp` 保持原值（副本隔离，写 A 不污染库）
- [ ] **AC-11**：`get_monster("nonexistent_id_xyz")` → 返回 `null`，不抛异常、不写错误日志
- [ ] **AC-12**：`get_key("key_yellow")` 返回 `entity_type==KEY`/`effect_type==KEY`/`key_color==YELLOW`/`opens_door_color==YELLOW`；`get_monster("key_yellow")==null`；`get_item("key_yellow")==null`（get_item 不含 KEY）

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

- 查询接口置于 EntityDB（`src/entity/entity_db.gd`；Autoload 装配在 006，但查询方法 + 内部表本 story 定义，供 006 复用）。为 headless 可测，本 story 用**可注入表**的方式测试（如 `_inject_entries_for_test(monsters, items, keys)`，`assert(OS.is_debug_build())` 保护，参照 TuningConfig `_inject_config_for_test`），不依赖文件加载/Autoload。
- getter 模式（ADR-0001 Key Interfaces）：`var e = _monsters.get(id); return e.duplicate() if e else null`。
- 分表：三个字典 `_monsters/_items/_keys`；`get_item` 查 `_items` 不查 `_keys`（AC-12 断言 get_item("key_yellow")==null）。
- AC-06 副本隔离：因 001 保证全 `@export`，`duplicate()` 拷贝所有字段，A/B 独立。测试写 `A.hp=999` 后 `get_monster` 得 B，断言 `B.hp==原值`。
- rare_drop_item_id 空表示：GDD 用 null 语义；ADR-0001 用 `""` 空串（`@export var rare_drop_item_id: String`）。AC-05 断言"无稀有掉落"→ 断言 `rare_drop_item_id == ""`（记录此 null↔"" 映射）。

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 006：Autoload 装配 + 从 entities.json 加载真实数据填表（本 story 用注入表测试查询机制）
- Story 001：数据类型本身
- FloorDB 的 get_floor/get_cell（不同系统 #2，用 duplicate_deep）

---

## QA Test Cases

*Transcribed from GDD AC. 测试用 `_inject_entries_for_test` 注入已知实体（如 slime hp20/gold5、key_yellow），无需文件加载。*

- **AC-05**（查询正确性）
  - Given: 注入 slime(hp=20,gold_drop=5,is_boss=false,rare_drop_item_id="")
  - When: `get_monster("slime")`
  - Then: `gold_drop==5`、`is_boss==false`、`rare_drop_item_id==""`、`entity_type==MONSTER`
- **AC-06**（只读副本隔离——防污染）
  - Given: 注入 slime(hp=20)
  - When: A=get_monster("slime")；A.hp=999；B=get_monster("slime")
  - Then: `B.hp==20`
  - Edge cases: 连续两次 get 返回不同实例（`A != B` 引用不等）
- **AC-11**（不存在 ID）
  - Given: 已注入标准数据
  - When: `get_monster("nonexistent_id_xyz")`
  - Then: 返回 `null`；不抛异常
- **AC-12**（类型分表 + 错类型返 null）
  - Given: 注入 key_yellow(key_color=YELLOW,opens_door_color=YELLOW)
  - When: get_key/get_monster/get_item("key_yellow")
  - Then: get_key 返回 KEY 对象(entity_type==KEY,effect_type==KEY,key_color==YELLOW,opens_door_color==YELLOW)；get_monster==null；get_item==null

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/entity/entity_query_test.gd` — 须存在且通过（GDUnit4 headless）。

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（返回 MonsterEntry/ItemEntry/KeyEntry 类型的副本）
- Unlocks: Story 006（Autoload 加载真实数据后，查询接口对外服务下游 #4/#5/#6/#7/#8）
