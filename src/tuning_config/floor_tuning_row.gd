## FloorTuningRow — 单层楼层期望属性行（TR-tuning-003）
## 存储特定楼层的玩家期望属性基准值，用于 D1/D3 校验与战斗调参。
## 所有字段必须 @export：Resource.duplicate(true) 只拷贝 @export 属性（ADR-0001 决策细则 5）。
class_name FloorTuningRow extends Resource

## 楼层编号（1-based）
@export var floor_number: int = 0
## 该层玩家期望 ATK（D1/D3 校验用）
@export var player_atk_expected: int = 0
## 该层玩家期望 DEF（D1/D3 校验用）
@export var player_def_expected: int = 0
## 该层玩家期望 HP（D1/D3 校验用）
@export var player_hp_expected: int = 0
