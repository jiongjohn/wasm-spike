## TuningFormulas — 调参公式静态工具类
##
## 本类封装 game-tuning-config.md 中定义的所有运行时战斗公式。
## 纯静态函数，无实例状态，无场景树依赖，headless 可直接断言。
##
## 用法示例：
##   var dmg: int = TuningFormulas.damage_player(14, 8)  # => 6
##   var rounds: int = TuningFormulas.n_rounds(30, 14, 8)  # => 5
##
## 下游消费者：
##   #5 CombatSystem.generate_round_sequence — 调用 damage_player / damage_monster
##   #4 PlayerStats — 调用 calc_player_atk
class_name TuningFormulas


## F1-A — 玩家对怪物每回合净伤害
## 公式：max(1, player_atk - monster_def)
## 下限 1：玩家永远能伤害怪物（P2 确定性保证任何怪物都有解）。
static func damage_player(player_atk: int, monster_def: int) -> int:
	return maxi(1, player_atk - monster_def)


## F1-B — 怪物对玩家每回合净伤害
## 公式：max(0, monster_atk - player_def)
## 下限 0：盾可完全抵消伤害（与 F1-A 非对称——玩家 max(1) vs 怪物 max(0)）。
static func damage_monster(monster_atk: int, player_def: int) -> int:
	return maxi(0, monster_atk - player_def)


## F1-C — 击杀怪物所需总回合数
## 公式：ceil(monster_hp / max(1, player_atk - monster_def))
## 先转 float 再除法再 ceil，避免 GDScript 整数除法提前截断。
## maxi(1, ...) 防除零（atk <= def 时净伤钳制为 1）。
static func n_rounds(monster_hp: int, player_atk: int, monster_def: int) -> int:
	return int(ceil(float(monster_hp) / float(maxi(1, player_atk - monster_def))))


## F3-A — 玩家当前攻击力（HIGHEST_WINS 策略）
## 公式：base_atk + max(weapon_effect_values)，空集时 +0
## HIGHEST_WINS：多件武器只取效果值最大的一件，防止多把剑累加击穿 D1 平衡假设。
## 注：GDD F3-A 属性写作 player_ATK，此处函数名统一 snake_case。
static func calc_player_atk(base_atk: int, weapon_effect_values: Array[int]) -> int:
	return base_atk + (weapon_effect_values.max() if not weapon_effect_values.is_empty() else 0)
