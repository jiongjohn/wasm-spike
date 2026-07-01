## ItemEntry — 道具静态数据类型（TR-entity-003, TR-entity-004）
## 存储单件道具的全部静态属性，从 res://data/entities.json 的 items 数组反序列化构造。
## 只读访问由 EntityDB getter 通过 duplicate() 浅拷贝保证（ADR-0001）。
##
## 用法示例：
##   var entry: ItemEntry = ItemEntry.from_dict(data_dict, "potion_small")
##   if entry == null:
##       push_error("ItemEntry 反序列化失败")
##       return
##   var val: int = entry.effect_value
class_name ItemEntry extends Resource

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

## effect_type 枚举值（GDD 规则 C4；KEY 已纳入正式枚举）
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

## stack_rule 枚举值（GDD 规则 C8；TR-entity-004）
const STACK_RULE_ADDITIVE     := 0
const STACK_RULE_HIGHEST_WINS := 1

## stack_rule 字符串→int 映射表
const STACK_RULE_MAP := {
	"ADDITIVE":     0,
	"HIGHEST_WINS": 1,
}

## 类型判别字段（固定 ITEM=1）
@export var entity_type: int = 1
## 唯一标识符（snake_case，如 "potion_small"）
@export var id: String = ""
## 游戏内显示名称
@export var display_name: String = ""
## 效果类型（HP_RESTORE/ATK_BOOST/DEF_BOOST/MAXHP_BOOST/FRAGMENT/KEY）
@export var effect_type: int = 0
## 效果数值（HP 回复量 / 属性加成量 / 碎片数量；≥0）
@export var effect_value: int = 0
## 同类道具叠加规则（ADDITIVE=0 / HIGHEST_WINS=1；TR-entity-004）
@export var stack_rule: int = 0
## 美术 Atlas 中的 Sprite 键名
@export var sprite_id: String = ""


## 从 Dictionary 构造 ItemEntry。
## 所有必填字段（entity_type/id/display_name/effect_type/effect_value/stack_rule）缺失时 push_error 并返回 null。
## enum 字段字符串→int 映射：未知字符串 → 哨兵 -1 → push_error + null（ADR-0005 A-3）。
## [param data] 来自 JSON 解析的 Dictionary（entities.json 的 items 数组单项）
## [param entry_id] 用于 push_error 定位
## [return] ItemEntry 实例，构造失败返回 null
static func from_dict(data: Dictionary, entry_id: String) -> ItemEntry:
	# 必填字段检测（assert 在 Release 被剥离，须同时 push_error；ADR-0005 约束 5 / AC-09）
	# display_name 列入必填：story-001 code-review W-01/02/03 决策（2026-07-01）
	for field in ["entity_type", "id", "display_name", "effect_type", "effect_value", "stack_rule"]:
		if not data.has(field):
			push_error("ItemEntry [%s]: 必填字段缺失 '%s'" % [entry_id, field])
			return null

	# entity_type 字符串→int 映射
	var entity_type_int: int = ENTITY_TYPE_MAP.get(str(data["entity_type"]), -1)
	if entity_type_int == -1:
		push_error("ItemEntry [%s]: entity_type 未知值 '%s'" % [entry_id, str(data["entity_type"])])
		return null

	# effect_type 字符串→int 映射
	var effect_type_int: int = EFFECT_TYPE_MAP.get(str(data["effect_type"]), -1)
	if effect_type_int == -1:
		push_error("ItemEntry [%s]: effect_type 未知值 '%s'" % [entry_id, str(data["effect_type"])])
		return null

	# stack_rule 字符串→int 映射
	var stack_rule_int: int = STACK_RULE_MAP.get(str(data["stack_rule"]), -1)
	if stack_rule_int == -1:
		push_error("ItemEntry [%s]: stack_rule 未知值 '%s'" % [entry_id, str(data["stack_rule"])])
		return null

	var entry := ItemEntry.new()
	entry.entity_type  = entity_type_int
	entry.id           = str(data["id"])
	entry.display_name = str(data["display_name"])
	entry.effect_type  = effect_type_int
	entry.effect_value = int(data["effect_value"])
	entry.stack_rule   = stack_rule_int
	# sprite_id：GDD C3-C5 标非空必填，但 MVP 数据表(Tuning Knobs)无此列 → 暂可选，待美术 Atlas 规范定义后转必填
	# （tech debt，story-001 code-review W-01/02/03 决策：2026-07-01 display_name 必填/sprite_id 可选）
	entry.sprite_id    = str(data.get("sprite_id", ""))
	return entry
