## MonsterEntry — 怪物静态数据类型（TR-entity-003）
## 存储单只怪物的全部静态属性，从 res://data/entities.json 的 monsters 数组反序列化构造。
## 只读访问由 EntityDB getter 通过 duplicate() 浅拷贝保证（ADR-0001）。
##
## 用法示例：
##   var entry: MonsterEntry = MonsterEntry.from_dict(data_dict, "slime")
##   if entry == null:
##       push_error("MonsterEntry 反序列化失败")
##       return
##   var hp: int = entry.hp  # 强类型访问
class_name MonsterEntry extends Resource

## entity_type 枚举值（ADR-0005 关键格式约定：enum 用 int，配字符串→int 映射表）
const ENTITY_TYPE_MONSTER := 0  # MONSTER
const ENTITY_TYPE_ITEM    := 1  # ITEM
const ENTITY_TYPE_KEY     := 2  # KEY

## entity_type 字符串→int 映射表（from_dict 反序列化用）
const ENTITY_TYPE_MAP := {
	"MONSTER": 0,
	"ITEM":    1,
	"KEY":     2,
}

## 类型判别字段（固定 MONSTER=0）
@export var entity_type: int = 0
## 唯一标识符（snake_case，如 "slime"）
@export var id: String = ""
## 游戏内显示名称
@export var display_name: String = ""
## 初始/最大生命值（≥1）
@export var hp: int = 0
## 攻击力（≥0）
@export var atk: int = 0
## 防御力（≥0）；注：GDScript 保留字 def 不可用作字段名（ADR-0005 B-1）
@export var defense: int = 0
## 击败时掉落的固定金币量（≥1）
@export var gold_drop: int = 0
## 是否为 Boss；决定稀有掉落资格（ADR-0001 GDD C3）
@export var is_boss: bool = false
## Boss 首次击败时额外掉落的 ItemEntry ID；"" 表示无稀有掉落
@export var rare_drop_item_id: String = ""
## 该怪物类型首次出现的楼层（1-based；MVP 手工关卡不消费，仅设计参考）
@export var floor_first_appears: int = 0
## 美术 Atlas 中的 Sprite 键名（不透明字符串，解析由渲染 ADR 负责）
@export var sprite_id: String = ""


## 从 Dictionary 构造 MonsterEntry。
## 所有必填字段（entity_type/id/display_name/hp/atk/defense/gold_drop/is_boss）缺失时 push_error 并返回 null。
## int 字段显式 int() 转型防 JSON float 化（ADR-0005 约束 2）。
## [param data] 来自 JSON 解析的 Dictionary（entities.json 的 monsters 数组单项）
## [param entry_id] 用于 push_error 定位，通常传 data["id"] 或占位串
## [return] MonsterEntry 实例，构造失败返回 null
static func from_dict(data: Dictionary, entry_id: String) -> MonsterEntry:
	# 必填字段检测（assert 在 Release 被剥离，须同时 push_error；ADR-0005 约束 5 / AC-09）
	# display_name 列入必填：story-001 code-review W-01/02/03 决策（2026-07-01）
	for field in ["entity_type", "id", "display_name", "hp", "atk", "defense", "gold_drop", "is_boss"]:
		if not data.has(field):
			push_error("MonsterEntry [%s]: 必填字段缺失 '%s'" % [entry_id, field])
			return null

	# entity_type 字符串→int 映射（未知字符串 → 哨兵 -1 → 报错）
	var entity_type_int: int = ENTITY_TYPE_MAP.get(str(data["entity_type"]), -1)
	if entity_type_int == -1:
		push_error("MonsterEntry [%s]: entity_type 未知值 '%s'" % [entry_id, str(data["entity_type"])])
		return null

	var entry := MonsterEntry.new()
	entry.entity_type = entity_type_int
	entry.id            = str(data["id"])
	entry.hp            = int(data["hp"])
	entry.atk           = int(data["atk"])
	entry.defense       = int(data["defense"])
	entry.gold_drop     = int(data["gold_drop"])
	entry.is_boss       = bool(data["is_boss"])
	# 可选字段：缺省为空串/0，不报错
	# F-13 null 防御：JSON 显式写 null 时 data.get 返回 null，str(null)="null" 非空 → 误报 DANGLING_REF
	var raw_rare = data.get("rare_drop_item_id", "")
	entry.rare_drop_item_id   = "" if raw_rare == null else str(raw_rare)
	entry.display_name        = str(data["display_name"])
	entry.floor_first_appears = int(data.get("floor_first_appears", 0))
	# sprite_id：GDD C3-C5 标非空必填，但 MVP 数据表(Tuning Knobs)无此列 → 暂可选，待美术 Atlas 规范定义后转必填
	# （tech debt，story-001 code-review W-01/02/03 决策：2026-07-01 display_name 必填/sprite_id 可选）
	entry.sprite_id           = str(data.get("sprite_id", ""))
	return entry
