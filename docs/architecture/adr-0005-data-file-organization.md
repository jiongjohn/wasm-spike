# ADR-0005: 数据文件组织方案

## Status
Accepted

## Date
2026-06-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.5.2（2026-06-30 re-pinned from 4.6.3） |
| **Domain** | Core / Data（JSON 文件加载 + 反序列化） |
| **Knowledge Risk** | MEDIUM — `JSON.parse_string()` 的 float/int 行为以及 WASM 中 `DirAccess.get_files_at("res://…")` 的支持情况须验证 |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`、`docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None（JSON.parse_string()、FileAccess.get_file_as_string()、DirAccess.get_files_at() 均为 4.0 稳定 API） |
| **Verification Required** | (1) `DirAccess.get_files_at("res://data/floors/")` 在 Douyin WASM 虚拟 VFS 中正确返回 PCK 内文件列表（导出 spike QQ-01）；(2) `JSON.parse_string()` 对整数 JSON 值（如 `"hp": 20`）是否返回 float——若是则所有 int 字段须显式 `int()` 转型（entity-database.md 注释已提示，本 ADR 将其列为强制约束）|

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001（class_name + RefCounted 数据类型——本 ADR 的反序列化器构造这些类型） |
| **Enables** | EntityDB（#1）、FloorDB（#2）、TuningConfig（#3）的实现；本 ADR 定义它们读取数据的位置和格式 |
| **Blocks** | Foundation 层三个系统的具体实现 epic（文件格式未定则无法编写反序列化器） |
| **Ordering Note** | 须在 Foundation 系统实现 story 开始前完成 |

## Context

### Problem Statement
三个 Foundation GDD 均将数据文件格式、路径组织、反序列化策略推迟到架构 ADR：
- entity-database.md Open Q2：「使用 Resource 子类、内部 GDScript class，还是 Dictionary？数据文件用 .tres 还是 JSON？」（ADR-0001 已解决类型载体；本 ADR 解决文件格式）
- floor-layout-data.md Open Q：「`res://data/floors/` 是一个 JSON 包含所有楼层，还是每层独立文件？」
- floor-layout-data.md Open Q3：「cell_type 的 JSON 编码方式：完整对象（`{"cell_type": "ENTITY", "entity_id": "slime"}`）还是紧凑编码？」

未解决的具体问题：① 每个数据源的 `res://` 路径；② JSON 键名约定；③ enum 在 JSON 中用字符串还是整数；④ Godot JSON 解析器对整数的 float 返回问题；⑤ 楼层发现机制（目录扫描 vs 清单文件）。

### Constraints
- **数据格式必须为 JSON**：entity-database.md AC-09（字段缺失可被检测）在 `.tres` 格式下不可满足（.tres 对缺失 `@export` 字段静默填默认值），故强制 JSON
- **必须打包进 `res://`（随 PCK）**：不得放 `user://`——WASM 上 `user://` 映射 IndexedDB，首次启动可能返回空
- **MVP 数据量极小**：约 10 怪物 + 10 道具 + 5 钥匙 + 3×16×16=768 格子 < 10KB 总量，无需优化文件大小
- **关卡设计师可读性**：floor JSON 须让非程序员（关卡设计师）直接编辑，不得使用位掩码或魔法整数
- **int() 转型约束**：Godot 4.x `JSON.parse_string()` 可能将整数 JSON 值解析为 float；所有 int 类型字段的反序列化器须显式 `int()` 转型
- **`def` 保留字约束**：`def` 是 GDScript 保留字（引擎词法器），不可用作字段名；MonsterEntry 的防御值字段须命名为 `defense`，JSON 键名同步为 `"defense"`（B-1，专家评审 blocking fix）
- **Release 安全校验约束**：`assert()` 在 Release 导出模板中被裁剪，不能作为唯一的字段缺失检测手段（AC-09 要求）；反序列化器须同时使用 `push_error()` 报错并返回 `null`（B-2 / A-1，专家评审 fix）
- **JSON.parse_string() null 检查约束**：每处 `JSON.parse_string()` 调用的返回值须在使用前检查是否为 `null` 且类型为 `Dictionary`；`FileAccess.get_file_as_string()` 在文件缺失时返回 `""`，`parse_string("")` 返回 `null`，直接索引 null 将崩溃（B-2，专家评审 blocking fix）

### Requirements
- TuningConfig/EntityDB/FloorDB 的文件路径明确固定（不由代码动态生成）
- cell_type 等 enum 字段使用人类可读的字符串（关卡设计师可直接编辑 floor JSON）
- 添加新楼层无需修改 GDScript 代码（只需增加 JSON 文件 + 更新清单）
- 所有文件路径可在 GDUnit4 headless 测试中用 `FileAccess.open()` 访问（`res://` 路径在编辑器 headless 模式下可访问）

## Decision

### 文件路径结构

```
res://data/
├── tuning_config.json       ← TuningConfig (#3)
├── entities.json            ← EntityDB (#1)，包含 monsters/items/keys 三个数组
└── floors/
    ├── manifest.json        ← 楼层发现清单（FloorDB 读取）
    ├── floor_001.json       ← 第 1 层
    ├── floor_002.json       ← 第 2 层
    └── floor_003.json       ← 第 3 层（MVP 上限）
```

### 各文件 JSON Schema

**`tuning_config.json`**（平铺结构，单层对象）:
```json
{
  "base_ATK": 6,
  "base_DEF": 3,
  "base_MaxHP": 100,
  "N_max": 10,
  "HP_BUDGET_RATIO": 0.35,
  "floor_tuning": [
    { "floor_id": "floor_001", "player_ATK_expected": 6,  "player_DEF_expected": 3,  "player_HP_expected": 100 },
    { "floor_id": "floor_002", "player_ATK_expected": 10, "player_DEF_expected": 6,  "player_HP_expected": 86  },
    { "floor_id": "floor_003", "player_ATK_expected": 15, "player_DEF_expected": 10, "player_HP_expected": 135 }
  ]
}
```

**`entities.json`**（三个数组，键名与 class_name 字段名精确一致）:
```json
{
  "monsters": [
    { "entity_type": "MONSTER", "id": "slime",  "hp": 20, "atk": 3,  "defense": 0, "gold_drop": 5, "is_boss": false, "rare_drop_item_id": "" },
    { "entity_type": "MONSTER", "id": "goblin", "hp": 30, "atk": 5,  "defense": 0, "gold_drop": 8, "is_boss": false, "rare_drop_item_id": "" },
    { "entity_type": "MONSTER", "id": "boss_1", "hp": 80, "atk": 10, "defense": 2, "gold_drop": 30, "is_boss": true,  "rare_drop_item_id": "sword_basic" }
  ],
  "items": [
    { "entity_type": "ITEM", "id": "potion_small", "effect_type": "HP_RESTORE",  "effect_value": 50,  "stack_rule": "ADDITIVE" },
    { "entity_type": "ITEM", "id": "sword_basic",  "effect_type": "ATK_BOOST",   "effect_value": 3,   "stack_rule": "HIGHEST_WINS" },
    { "entity_type": "ITEM", "id": "shield_basic", "effect_type": "DEF_BOOST",   "effect_value": 2,   "stack_rule": "HIGHEST_WINS" }
  ],
  "keys": [
    { "entity_type": "KEY", "id": "key_yellow", "key_color": "YELLOW", "opens_door_color": "YELLOW" },
    { "entity_type": "KEY", "id": "key_blue",   "key_color": "BLUE",   "opens_door_color": "BLUE"   }
  ]
}
```

**`floors/manifest.json`**（楼层 ID 列表，FloorDB 据此加载）:
```json
{
  "floor_ids": ["floor_001", "floor_002", "floor_003"]
}
```
> FloorDB 加载逻辑：读取 manifest.json → 按顺序加载 `res://data/floors/[floor_id].json`。这避免了 WASM VFS 中 `DirAccess.get_files_at()` 可能失效的风险（见 Risks），同时保持「添加楼层只需增加文件 + 更新清单」的工作流。

**`floors/floor_NNN.json`**（完整对象编码，16×16 网格）:
```json
{
  "floor_id": "floor_001",
  "floor_number": 1,
  "grid": [
    [
      { "cell_type": "WALL" },
      { "cell_type": "WALL" },
      { "cell_type": "EMPTY" },
      { "cell_type": "ENTITY", "entity_id": "slime" },
      { "cell_type": "DOOR",   "door_color": "YELLOW" },
      { "cell_type": "STAIR_UP", "target_floor_id": "floor_002" },
      ...
    ],
    ...
  ]
}
```
> `grid` 为 16 行 × 16 列的二维数组，row 优先（`grid[row][col]`）。

### 关键格式约定

1. **enum 字段使用字符串名称**（`"YELLOW"`, `"MONSTER"`, `"HP_RESTORE"` 等），不使用整数。反序列化器维护一个字符串→整数的映射表。理由：关卡设计师直接编辑 JSON，字符串防止「用错整数」；同时避免 JSON float 问题（字符串字段不会被 parse 为 float）。

2. **所有数值字段（int 类型）反序列化时显式 `int()` 转型**：
   ```gdscript
   entry.hp = int(data["hp"])  # 防止 JSON.parse_string() 返回 float
   entry.atk = int(data["atk"])
   ```
   字符串和布尔字段无需转型（`bool` 和 `String` 不受此 bug 影响）。

3. **JSON 键名与 GDScript 字段名严格一致**（snake_case）：`"entity_type"`, `"hp"`, `"gold_drop"`, `"is_boss"` 等与 ADR-0001 的 class 字段名相同，无别名映射。

4. **楼层文件命名**：`floor_[zero_padded_3digit_number].json`（`floor_001.json`, `floor_002.json`），与 `floor_id` 字段值一致。

5. **字段缺失 = 报错，禁止填默认值**：反序列化器须用 `data.has("key")` 检查所有必填字段；缺失字段报 Entry ID + 字段名错误，不进入游戏（entity-database.md AC-09 约束）。

### Architecture Diagram

```
res://data/
    │
    ├── tuning_config.json
    │       ↓ FileAccess.get_file_as_string()
    │   TuningConfig._ready() → JSON.parse_string() → 逐字段 int() 转型 → TuningConfigData
    │
    ├── entities.json
    │       ↓ FileAccess.get_file_as_string()
    │   EntityDB._ready() → JSON.parse_string() → monsters[] → MonsterEntry.from_dict()
    │                                            → items[]    → ItemEntry.from_dict()
    │                                            → keys[]     → KeyEntry.from_dict()
    │
    └── floors/
        ├── manifest.json
        │       ↓ JSON.parse_string() → floor_ids: ["floor_001", ...]
        │
        └── floor_NNN.json  ×N
                ↓ FileAccess.get_file_as_string() (按 manifest 顺序)
            FloorDB._ready() → JSON.parse_string()
                             → grid[][] → CellEntry.from_dict()
                             → FloorEntry
```

### Key Interfaces

```gdscript
# ── 反序列化器模式（每个 class_name 类提供静态工厂方法）──

class_name MonsterEntry extends Resource:
    # ... 字段：全部 @export var（ADR-0001 决策细则 5——duplicate*/duplicate_deep 只拷贝 @export 属性，
    #     plain var 字段在 getter 返回的副本中会被重置为默认值；2026-06-29 spike 实证）...
    static func from_dict(data: Dictionary, entry_id: String) -> MonsterEntry:
        # assert() 在 Release 构建中被裁剪——必填字段校验同时使用 push_error（AC-09）
        for field in ["id", "hp", "atk", "defense", "gold_drop", "is_boss"]:
            if not data.has(field):
                push_error("MonsterEntry %s: missing field '%s'" % [entry_id, field])
                return null
        var entry := MonsterEntry.new()
        entry.id = str(data["id"])
        entry.hp = int(data["hp"])          # 显式 int() 转型
        entry.atk = int(data["atk"])
        entry.defense = int(data["defense"])  # B-1: "def" 是 GDScript 保留字，改为 "defense"
        entry.gold_drop = int(data["gold_drop"])
        entry.is_boss = bool(data["is_boss"])
        entry.rare_drop_item_id = str(data.get("rare_drop_item_id", ""))
        return entry

class_name CellEntry extends Resource:
    # enum 字符串→整数映射表
    const CELL_TYPE_MAP := {
        "EMPTY": 0, "WALL": 1, "ENTITY": 2, "DOOR": 3,
        "STAIR_UP": 4, "STAIR_DOWN": 5, "PLAYER_START": 6
    }
    static func from_dict(data: Dictionary) -> CellEntry:
        var entry := CellEntry.new()
        # A-3: 用 .get() + -1 哨兵替代直接索引——防止未知字符串（拼写错误）崩溃
        var cell_type_int: int = CELL_TYPE_MAP.get(str(data.get("cell_type", "")), -1)
        if cell_type_int == -1:
            push_error("CellEntry: unknown cell_type '%s'" % data.get("cell_type", "<missing>"))
            return null
        entry.cell_type = cell_type_int
        entry.entity_id = str(data.get("entity_id", ""))
        entry.door_color = DoorColorMap.get(str(data.get("door_color", "")), 0)
        entry.target_floor_id = str(data.get("target_floor_id", ""))
        return entry

# ── FloorDB 楼层发现（基于清单，不依赖 DirAccess）──
func _load_floors() -> void:
    # B-2: get_file_as_string() 在文件缺失时返回 ""；parse_string("") 返回 null；
    # null["floor_ids"] 崩溃——须在 Dictionary 访问前做 null 检查
    var manifest_text := FileAccess.get_file_as_string("res://data/floors/manifest.json")
    if manifest_text.is_empty():
        push_error("FloorDB: manifest.json missing or empty at res://data/floors/manifest.json")
        return
    var parsed_manifest := JSON.parse_string(manifest_text)
    if parsed_manifest == null or not parsed_manifest is Dictionary:
        push_error("FloorDB: manifest.json is not valid JSON")
        return
    var manifest: Dictionary = parsed_manifest
    for floor_id in manifest["floor_ids"]:
        var path := "res://data/floors/%s.json" % floor_id
        var floor_text := FileAccess.get_file_as_string(path)
        if floor_text.is_empty():
            push_error("FloorDB: floor file missing: %s" % path)
            continue
        var parsed_floor := JSON.parse_string(floor_text)
        if parsed_floor == null or not parsed_floor is Dictionary:
            push_error("FloorDB: invalid JSON in %s" % path)
            continue
        _floors[floor_id] = FloorEntry.from_dict(parsed_floor)
```

## Alternatives Considered

### Alternative 1: 楼层全部合并为单一 `floors.json`
- **Description**: 所有楼层数据存放在一个 JSON 文件（`res://data/floors.json`），键为 floor_id。
- **Pros**: 单次 IO 加载所有楼层；更简单的 FloorDB 加载逻辑（无需清单或目录扫描）。
- **Cons**: 添加新楼层须修改同一个大文件（合并冲突风险）；未来 Alpha+ 楼层数量增多时文件膨胀；单文件对关卡设计师的并行编辑更不友好。
- **Rejection Reason**: 一楼层一文件对内容生产更友好（独立 PR、独立校验）；清单文件方案兼顾 WASM 兼容性，工程成本无增加。

### Alternative 2: cell_type 使用紧凑整数/数组编码
- **Description**: grid 中每格用整数数组 `[cell_type_int, entity_id, door_color_int, target_floor_id]` 或单整数位掩码表示。
- **Pros**: JSON 文件体积约减小 50%（约 7KB → 3.5KB/层）；JSON 解析略快。
- **Cons**: 关卡设计师须查表才能理解每格内容，手工编辑几乎不可行；cell_type 整数含义未来可能随枚举重排而漂移；调试时无法直接阅读 JSON。
- **Rejection Reason**: MVP 数据量下 3.5KB vs 7KB 的差异无实质影响（远低于 50MB WASM 限制）；可读性优先，关卡设计师直接编辑是核心需求。

### Alternative 3: 使用 DirAccess 动态扫描楼层目录（无清单）
- **Description**: FloorDB 在 _ready() 中调用 `DirAccess.get_files_at("res://data/floors/")` 自动发现所有 floor JSON 文件。
- **Pros**: 添加楼层无需更新任何非 floor 文件；完全自动发现。
- **Cons**: `DirAccess.get_files_at("res://")` 在 WASM PCK 虚拟文件系统中的行为未验证（Douyin 适配器 ~4.5，4.6.3 未实测）；若 WASM VFS 不支持目录枚举，则楼层加载静默失败（得到空楼层列表，不报错）。
- **Rejection Reason**: WASM VFS 兼容性未验证；清单方案在添加楼层时只多一步"更新 manifest.json"，成本可接受，而获得的确定性（文件列表明确可控、可版本化、可静态分析）更有价值。

## Consequences

### Positive
- 关闭了所有三个 Foundation GDD 的 Open Questions（entity-database.md OQ2、floor-layout-data.md OQ1/OQ3）
- 人类可读的字符串 enum 编码，关卡设计师可直接手工编辑 floor JSON
- 清单文件方案避免 WASM DirAccess 兼容性风险
- JSON 键名与 GDScript 字段名一致，反序列化器无需映射表，维护简单
- 一楼层一文件支持并行编辑和独立 PR

### Negative
- manifest.json 须与 floor 文件列表保持同步（添加楼层须同时更新两处）
- enum 字符串→整数映射表须在反序列化器中维护（每个 enum 类型一个 Dictionary 常量）
- 所有 int 字段须显式 `int()` 转型，增加少量样板代码

### Risks
- **风险（MEDIUM）**：`DirAccess.get_files_at("res://data/floors/")` 在 WASM 中即使有清单方案也未被使用——但若有开发者误用 DirAccess 代替清单，会产生静默失败。
  - **缓解**：forbidden_pattern 注册禁止在 Foundation Autoload 中使用 DirAccess 动态发现数据文件；FloorDB 实现须通过 ADR 引用的 `_load_floors()` 模式，不得用目录扫描替代。
- **风险**：`JSON.parse_string()` 确实将整数解析为 float（entity-database.md 已提示）。若反序列化器遗漏 `int()` 转型，field 值为 float 导致 GDScript 强类型字段赋值报类型错误或截断。
  - **缓解**：本 ADR 将所有 int 字段显式 `int()` 转型列为强制约束；code review 须 grep 确认无裸 `data["hp"]` 直接赋值；单测包含「非整数 JSON 值→ int 字段」的负向测试。
- **风险**：manifest.json 与实际 floor 文件列表不同步（遗漏新增楼层 ID 或 ID 拼写错误）。
  - **缓解**：FloorDB 启动校验对 manifest 中每个 floor_id 执行 `FileAccess.file_exists("res://data/floors/%s.json" % id)` 检查；缺失文件报错不进入游戏。

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| entity-database.md | Open Q2：数据文件格式 + 路径交由架构 ADR 决定 | `res://data/entities.json`，JSON 格式，键名对应 class 字段，显式 int() 转型 |
| entity-database.md | AC-09：字段缺失可被检测（.tres 不可满足） | JSON 格式（缺失字段可用 has() 检测）；反序列化器 assert 必填字段存在 |
| floor-layout-data.md | Open Q1：一文件 vs 每层独立文件 | 每层独立文件 + manifest.json 清单 |
| floor-layout-data.md | Open Q3：cell_type JSON 编码方式 | 完整命名字段对象（`{"cell_type": "ENTITY", "entity_id": "slime"}`） |
| floor-layout-data.md | 启动顺序：EntityDB 先于 FloorDB 加载 | entities.json 在 floor_NNN.json 之前加载（ADR-0002 的 Autoload 顺序保证） |
| game-tuning-config.md | 从 `res://data/tuning_config.json` 加载配置 | 正式确立此路径 |

## Performance Implications
- **CPU**: `JSON.parse_string()` 对 < 10KB 数据极快（< 1ms）；int() 转型开销可忽略；无运行期 JSON 访问
- **Memory**: 解析后数据存为 Resource 对象（ADR-0001，载体 2026-06-29 由 RefCounted 修订为 Resource），JSON 字符串随即释放；总内存开销 < 100KB
- **Load Time**: 3 个文件（+ 3 层 floor JSON + manifest）= 6 次 FileAccess.get_file_as_string()；全同步；总时长估计 < 10ms
- **WASM Bundle**: JSON 文件打包进 PCK，< 10KB；对 50MB 限制无影响

## Migration Plan
无现有数据文件。本 ADR 定义初始文件结构，可直接按此创建。

> **注**：ADR-0001 §Related Decisions 中标记为「ADR-0004（数据文件组织）」的引用须更新为「ADR-0005」（ADR-0004 已用于测试框架选型）。

## Validation Criteria
1. `res://data/entities.json`、`res://data/tuning_config.json`、`res://data/floors/manifest.json`、`res://data/floors/floor_001.json` 均存在，可被 `FileAccess.get_file_as_string()` 读取
2. EntityDB 启动校验通过，所有字段为正确类型（int 非 float，string 非 null）
3. FloorDB 按 manifest.json 加载，`DirAccess` 不出现在 FloorDB.gd 中（`grep DirAccess src/` 返回空）
4. GDUnit4 测试：反序列化器对缺少必填字段的 JSON 报错，不崩溃、不填默认值
5. 导出 spike（QQ-01）：WASM/Douyin 中所有 JSON 文件可被 `FileAccess.get_file_as_string("res://data/...")` 正常读取

## Related Decisions
- ADR-0001（数据类型）— 本 ADR 的反序列化器构造 ADR-0001 定义的 Resource 类型（载体于 2026-06-29 由 RefCounted 修订为 Resource：RefCounted 无 duplicate/duplicate_deep）
- ADR-0002（Autoload 启动顺序）— entities.json 先于 floor JSON 加载（EntityDB 在 FloorDB 之前初始化）
- design/gdd/entity-database.md Open Q2（数据文件格式约定）
- design/gdd/floor-layout-data.md Open Q1（楼层文件组织）、Open Q3（cell 编码方式）
- design/gdd/game-tuning-config.md（tuning_config.json 路径来源）
