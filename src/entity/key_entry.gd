## KeyEntry — 钥匙静态数据类型（TR-entity-003，GDD 规则 C5）
## 存储单把钥匙的全部静态属性，从 res://data/entities.json 的 keys 数组反序列化构造。
## 只读访问由 EntityDB getter 通过 duplicate() 浅拷贝保证（ADR-0001）。
## effect_type 固定为 KEY；effect_value 缺省按 0 处理，不报缺失（GDD 规则 C5）。
##
## 用法示例：
##   var entry: KeyEntry = KeyEntry.from_dict(data_dict, "key_yellow")
##   if entry == null:
##       push_error("KeyEntry 反序列化失败")
##       return
##   var color: int = entry.key_color  # YELLOW=0 / BLUE=1
class_name KeyEntry extends Resource

## entity_type 枚举值
const ENTITY_TYPE_MONSTER := 0
const ENTITY_TYPE_ITEM    := 1
const ENTITY_TYPE_KEY     := 2

## entity_type 字符串→int 映射表
const ENTITY_TYPE_MAP := {
	"MONSTER": 0,
	"ITEM":    1,
	"KEY":     2,
}

## effect_type 枚举值（与 ItemEntry 共享语义；KeyEntry 固定 KEY=5）
const EFFECT_TYPE_HP_RESTORE  := 0
const EFFECT_TYPE_ATK_BOOST   := 1
const EFFECT_TYPE_DEF_BOOST   := 2
const EFFECT_TYPE_MAXHP_BOOST := 3
const EFFECT_TYPE_FRAGMENT    := 4
const EFFECT_TYPE_KEY         := 5

## effect_type 字符串→int 映射表
const EFFECT_TYPE_MAP := {
	"HP_RESTORE":  0,
	"ATK_BOOST":   1,
	"DEF_BOOST":   2,
	"MAXHP_BOOST": 3,
	"FRAGMENT":    4,
	"KEY":         5,
}

## key_color 枚举值（GDD 规则 C5）
const KEY_COLOR_YELLOW := 0
const KEY_COLOR_BLUE   := 1

## key_color 字符串→int 映射表
const KEY_COLOR_MAP := {
	"YELLOW": 0,
	"BLUE":   1,
}

## 类型判别字段（固定 KEY=2）
@export var entity_type: int = 2
## 唯一标识符（如 "key_yellow"）
@export var id: String = ""
## 游戏内显示名称
@export var display_name: String = ""
## 效果类型（固定 KEY=5；entity_type=KEY 的条目 effect_type 强制为 KEY）
@export var effect_type: int = 5
## 效果数值（固定 0；钥匙不使用；缺省按 0 处理，不报缺失；GDD 规则 C5）
@export var effect_value: int = 0
## 钥匙颜色（YELLOW=0 / BLUE=1）
@export var key_color: int = 0
## 对应可开的门颜色（YELLOW=0 / BLUE=1）；校验时须等于 key_color（GDD Edge Cases）
@export var opens_door_color: int = 0
## 美术 Atlas 中的 Sprite 键名
@export var sprite_id: String = ""


## 从 Dictionary 构造 KeyEntry。
## 必填字段（entity_type/id/display_name/key_color/opens_door_color）缺失时 push_error 并返回 null。
## effect_value 缺省为 0，不报缺失（GDD 规则 C5）。
## effect_type 固定为 KEY（5），JSON 中若存在则做映射校验且必须等于 KEY，否则 push_error + null（GDD 规则 C5 W-04）。
## [param data] 来自 JSON 解析的 Dictionary（entities.json 的 keys 数组单项）
## [param entry_id] 用于 push_error 定位
## [return] KeyEntry 实例，构造失败返回 null
static func from_dict(data: Dictionary, entry_id: String) -> KeyEntry:
	# 必填字段检测（assert 在 Release 被剥离，须同时 push_error；ADR-0005 约束 5 / AC-09）
	# display_name 列入必填：story-001 code-review W-01/02/03 决策（2026-07-01）
	for field in ["entity_type", "id", "display_name", "key_color", "opens_door_color"]:
		if not data.has(field):
			push_error("KeyEntry [%s]: 必填字段缺失 '%s'" % [entry_id, field])
			return null

	# entity_type 字符串→int 映射
	var entity_type_int: int = ENTITY_TYPE_MAP.get(str(data["entity_type"]), -1)
	if entity_type_int == -1:
		push_error("KeyEntry [%s]: entity_type 未知值 '%s'" % [entry_id, str(data["entity_type"])])
		return null

	# key_color 字符串→int 映射
	var key_color_int: int = KEY_COLOR_MAP.get(str(data["key_color"]), -1)
	if key_color_int == -1:
		push_error("KeyEntry [%s]: key_color 未知值 '%s'" % [entry_id, str(data["key_color"])])
		return null

	# opens_door_color 字符串→int 映射
	var opens_door_color_int: int = KEY_COLOR_MAP.get(str(data["opens_door_color"]), -1)
	if opens_door_color_int == -1:
		push_error("KeyEntry [%s]: opens_door_color 未知值 '%s'" % [entry_id, str(data["opens_door_color"])])
		return null

	# effect_type：JSON 中若存在则做映射校验，且必须等于 KEY（GDD 规则 C5 W-04）；不存在则固定 KEY
	var effect_type_int: int = EFFECT_TYPE_KEY
	if data.has("effect_type"):
		effect_type_int = EFFECT_TYPE_MAP.get(str(data["effect_type"]), -1)
		if effect_type_int == -1:
			push_error("KeyEntry [%s]: effect_type 未知值 '%s'" % [entry_id, str(data["effect_type"])])
			return null
		if effect_type_int != EFFECT_TYPE_KEY:
			push_error("KeyEntry [%s]: effect_type 必须为 KEY，实际为 '%s'" % [entry_id, str(data["effect_type"])])
			return null

	var entry := KeyEntry.new()
	entry.entity_type      = entity_type_int
	entry.id               = str(data["id"])
	entry.display_name     = str(data["display_name"])
	entry.effect_type      = effect_type_int
	# effect_value 缺省按 0，不报缺失（GDD 规则 C5）
	entry.effect_value     = int(data.get("effect_value", 0))
	entry.key_color        = key_color_int
	entry.opens_door_color = opens_door_color_int
	# sprite_id：GDD C3-C5 标非空必填，但 MVP 数据表(Tuning Knobs)无此列 → 暂可选，待美术 Atlas 规范定义后转必填
	# （tech debt，story-001 code-review W-01/02/03 决策：2026-07-01 display_name 必填/sprite_id 可选）
	entry.sprite_id        = str(data.get("sprite_id", ""))
	return entry
