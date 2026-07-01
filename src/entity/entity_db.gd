## EntityDB — 游戏实体数据库（查询接口 + 只读副本，story-004）
## 三张按类型分离的只读查询接口：getter 返回 duplicate() 副本，下游写副本不污染库（ADR-0001）。
##
## 注：本 story（004）只实现查询接口 + 测试注入钩子。
## Autoload 装配（_ready / _load_and_validate / 启动校验 / is_initialized / 错误屏）为 story-006 范围，
## 因 ADR-0002 的「class_name == autoload 名」模板在 Godot 4.5.2 报「Class hides an autoload singleton」，
## 该架构问题待 /architecture-decision 修订 ADR-0002/ADR-0008 E-1 后再落地（见 story-006 BLOCKED 记录）。
##
## 用法示例（其他系统消费，006 装配后）：
##   var entry: MonsterEntry = EntityDB.get_monster("slime")
##   if entry == null:
##       push_error("未找到怪物 slime")
##       return
##   var hp: int = entry.hp  # 副本可安全读写，不影响数据库
class_name EntityDB extends Node

## 怪物表：id（String）→ MonsterEntry（entity_type == MONSTER）
var _monsters: Dictionary = {}

## 道具表：id（String）→ ItemEntry（entity_type == ITEM，不含 KEY）
var _items: Dictionary = {}

## 钥匙表：id（String）→ KeyEntry（entity_type == KEY）
var _keys: Dictionary = {}


## 查询怪物条目，返回 MonsterEntry 的浅拷贝副本。
## 仅返回 entity_type == MONSTER 的条目；不存在的 id 返回 null，不抛异常。
## [param id] 怪物唯一标识符（snake_case，如 "slime"）
## [return] MonsterEntry 副本，未找到返回 null
func get_monster(id: String) -> MonsterEntry:
	var entry: Variant = _monsters.get(id)
	return entry.duplicate() if entry else null


## 查询道具条目，返回 ItemEntry 的浅拷贝副本。
## 仅返回 entity_type == ITEM 的条目，不含 entity_type == KEY 的钥匙条目（AC-12）。
## 不存在的 id 返回 null，不抛异常。
## [param id] 道具唯一标识符（snake_case，如 "potion_small"）
## [return] ItemEntry 副本，未找到返回 null
func get_item(id: String) -> ItemEntry:
	var entry: Variant = _items.get(id)
	return entry.duplicate() if entry else null


## 查询钥匙条目，返回 KeyEntry 的浅拷贝副本。
## 仅返回 entity_type == KEY 的条目；不存在的 id 返回 null，不抛异常。
## [param id] 钥匙唯一标识符（snake_case，如 "key_yellow"）
## [return] KeyEntry 副本，未找到返回 null
func get_key(id: String) -> KeyEntry:
	var entry: Variant = _keys.get(id)
	return entry.duplicate() if entry else null


## [仅测试使用] 注入预构造的实体数组，绕开文件加载，直接填充三张内部表。
## 警告：仅在 GDUnit4 headless 测试中调用，生产代码禁止直接调用。
## 注入前会清空三张表（保证测试幂等）。
## [param monsters] Array[MonsterEntry] — entity_type 须为 MONSTER
## [param items]   Array[ItemEntry]   — entity_type 须为 ITEM（不含 KEY）
## [param keys]    Array[KeyEntry]    — entity_type 须为 KEY
func _inject_entries_for_test(monsters: Array, items: Array, keys: Array) -> void:
	assert(OS.is_debug_build(), "_inject_entries_for_test 仅在调试构建中可用，禁止生产路径调用")
	if not OS.is_debug_build():
		push_error("EntityDB._inject_entries_for_test 在非调试构建中被调用——生产路径不应注入测试数据")
		return
	_monsters.clear()
	_items.clear()
	_keys.clear()
	for m: MonsterEntry in monsters:
		_monsters[m.id] = m
	for it: ItemEntry in items:
		_items[it.id] = it
	for k: KeyEntry in keys:
		_keys[k.id] = k
