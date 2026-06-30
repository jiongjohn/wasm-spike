# Story 001: TuningConfig 数据类型 + 加载 + 只读访问

> **Epic**: 游戏调参配置 (TuningConfig)
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M（2-4h）
> **Manifest Version**: 2026-06-29
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/game-tuning-config.md`
**Requirement**: `TR-tuning-001`（纯配置层，get_tuning_config 返回只读副本）+ `TR-tuning-003`（楼层调参表按 floor_number 查询，null if not found）

**ADR Governing Implementation**: ADR-0001（主）；ADR-0002、ADR-0005（次）
**ADR Decision Summary**: 数据类型用 `class_name + Resource` 子类且**所有字段 @export**（RefCounted 无 duplicate*，且 plain var 不被 duplicate 拷贝——spike 实证）；getter 返回 `.duplicate()` 副本防污染。Autoload 为列表 [1] 首个，`is_initialized` 标志 + 同步 `_load_and_validate()`（禁 await）。数据自 `res://data/tuning_config.json` 经 FileAccess + JSON.parse_string 加载，int 字段显式 `int()` 转型。

**Engine**: Godot 4.5.2 | **Risk**: HIGH
**Engine Notes**: `Resource.duplicate()`/`duplicate_deep()` 为 4.5+；**仅拷贝 @export 属性**（plain var 副本为空，已实证 verify_dup2/3）。`JSON.parse_string()` 把整数解析为 float → int 字段须 `int()` 转型。WASM 行为待 QQ-01 spike（桌面已验证 duplicate_deep 独立性）。

**Control Manifest Rules (Foundation)**:
- Required: 数据类型 = `class_name + Resource`，**全字段 @export**；getter 返回 `duplicate()` 副本；JSON int 字段 `int()` 转型；Autoload `is_initialized` 标志 + 同步加载
- Forbidden: 裸 RefCounted 载体；plain var 数据字段；返回 DB 内部引用；`_load_and_validate()` 内 await；user:// 路径
- Guardrail: 启动校验失败禁 OS.quit()（WASM）→ 内联错误屏

---

## Acceptance Criteria

*From GDD `design/gdd/game-tuning-config.md`, scoped to this story:*

- [ ] AC-TC-11：`get_floor_tuning(3)` 返回非 null，字段 ATK_expected=20/DEF_expected=13/HP_expected=135
- [ ] AC-TC-12：`get_floor_tuning(99)`（不存在楼层）返回 null，不抛异常/不崩溃/不返默认值
- [ ] AC-TC-13：`get_tuning_config()` 返回只读副本——对返回对象写 `base_ATK=999` 后再次 `get_tuning_config().base_ATK == 6`（内部状态未被污染）

---

## Implementation Notes

*Derived from ADR-0001 / ADR-0002 / ADR-0005:*

- `TuningConfigData` 与 `FloorTuningRow` 均 `class_name + extends Resource`，**每个数据字段加 `@export`**（base_ATK/base_DEF/base_MaxHP/N_max/HP_BUDGET_RATIO/BATTLE_ROUND_DURATION/floor_tuning_table；FloorTuningRow 的 floor_number/player_ATK_expected/player_DEF_expected/player_HP_expected）。**漏 @export 会导致 duplicate() 副本字段为空——AC-TC-13 会失败**。
- `TuningConfig extends Node`（Autoload，列表 [1]）：`_ready()` 同步调用 `_load_and_validate()`（禁 await），末尾置 `_initialized = true`；暴露 `is_initialized: bool` 只读 getter。
- 加载：`FileAccess.get_file_as_string("res://data/tuning_config.json")` → null/空检查 → `JSON.parse_string` → null + `is Dictionary` 检查 → 逐 int 字段 `int()` 转型构造 Resource。
- `get_tuning_config() -> TuningConfigData`：返回 `_config.duplicate()`（浅拷贝足够，TuningConfigData 扁平；若 floor_tuning_table 含嵌套 Resource 行则用 `duplicate_deep()`）。
- `get_floor_tuning(floor_number: int) -> FloorTuningRow`：表中查找，命中返回副本，未命中返回 `null`。
- AC-TC-13 的只读保证：副本方案（duplicate）即可满足；不要返回内部 `_config` 引用。

---

## Out of Scope

*由相邻 story 处理，勿在此实现:*

- Story 002：`validate_tuning_config()` 校验器（字段/范围/表校验）
- Story 003：`TuningFormulas` 静态公式类（damage/n_rounds）

---

## QA Test Cases

*由 GDD AC 直接转写（已是 Given/When/Then）。实现按这些用例,勿另造。*

- **AC-TC-11**：get_floor_tuning 返回已定义楼层正确数据
  - Given: 系统用合法 5 层 TuningConfig 初始化（floor3: ATK=20,DEF=13,HP=135）
  - When: `get_floor_tuning(3)`
  - Then: 非 null；`player_ATK_expected==20` && `player_DEF_expected==13` && `player_HP_expected==135`
  - Edge cases: floor1（首行）、floor5（末行，VS 预规划行）

- **AC-TC-12**：查询不存在楼层返回 null
  - Given: 系统用仅含 floor1–5 的合法 TuningConfig 初始化
  - When: `get_floor_tuning(99)`
  - Then: `== null`；不抛异常、不崩溃、不返默认值
  - Edge cases: floor_number=0、负数、6（紧邻越界）

- **AC-TC-13**：get_tuning_config 返回只读副本
  - Given: 用 base_ATK=6 合法 config 初始化；`cfg = get_tuning_config()`
  - When: `cfg.base_ATK = 999`，再 `cfg2 = get_tuning_config()`
  - Then: `cfg2.base_ATK == 6`（内部未被污染）
  - Edge cases: 写 floor_tuning_table 内某行字段后，再查内部表未变（验证嵌套深拷贝——若 floor_tuning_table 为 Resource 行须 duplicate_deep）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tuning_config/config_type_and_loader_test.gd` — 须存在且通过（GDUnit4 headless：`godot --headless --script tests/gdunit4_runner.gd`）

**Status**: [x] Complete 2026-06-30 — GDUnit4 6/6 PASSED（Godot 4.5.2）

---

## Dependencies

- Depends on: None（Foundation 首个；可作为整个项目首个落地的实现 story）
- Unlocks: Story 002（校验器需本 story 的 TuningConfigData 类型）；下游 #1 EntityDB / #4 PlayerStats / #5 战斗 的初始化

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 3/3 通过（AC-TC-11/12/13 + 边界2 + code-review 补的嵌套行隔离 = 6 测试函数）
**Deviations**: None（TR-tuning-001/003 满足；GDScript 每文件一 class_name → FloorTuningRow 拆独立文件 floor_tuning_row.gd）
**Test Evidence**: Logic — `tests/unit/tuning_config/config_type_and_loader_test.gd`（6 test cases / 0 failures / PASSED 215ms，Godot 4.5.2 + GDUnit4 v6.0.0）
**Code Review**: Complete（score 83 → W1 duplicate_deep+补嵌套测试 / W2 _initialized fail-fast / I1 doc / I2 assert debug 全修，重测 6/6）
**Files**: src/tuning_config/{floor_tuning_row,tuning_config_data,tuning_config}.gd + data/tuning_config.json + 测试
**Unlocks**: story-002（校验器，依赖 TuningConfigData 类型）；下游 #1 EntityDB / #4 PlayerStats / #5 战斗 初始化
