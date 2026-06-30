## TuningConfigData — 游戏调参配置数据容器（TR-tuning-001）
## 从 res://data/tuning_config.json 反序列化构造，通过 TuningConfig Autoload 提供只读访问。
## 所有字段必须 @export：Resource.duplicate(true) 只拷贝 @export 属性（ADR-0001 决策细则 5）。
class_name TuningConfigData extends Resource

## 玩家基础攻击力（裸装）
@export var base_atk: int = 0
## 玩家基础防御力（裸装）
@export var base_def: int = 0
## 玩家基础最大生命值
@export var base_max_hp: int = 0
## D1 最大战斗回合数上限
@export var n_max: int = 0
## D3 单怪 HP 预算比率
@export var hp_budget_ratio: float = 0.0
## 单回合战斗动画时长（秒）
@export var battle_round_duration: float = 0.0
## 楼层调参表（每层一行 FloorTuningRow；@export 确保 duplicate(true) 递归拷贝每行）
@export var floor_tuning_table: Array[FloorTuningRow] = []
