## ValidationConfig — D1/D3 校验器输入参数载体（TR-entity-001）
## 通过依赖注入向 EntityDBValidator.validate_database() 传递楼层玩家预期值。
## 使校验器无需访问全局 Autoload（TuningConfig），可在 headless 测试中精确控制参数。
##
## ADR-0002 决定：测试不依赖 Autoload；ValidationConfig 依赖注入。
##
## 用法示例：
##   var cfg := ValidationConfig.new()
##   cfg.player_atk_expected = 20
##   cfg.player_hp_expected  = 100
##   cfg.player_def_expected = 5
##   cfg.n_max               = 10
##   cfg.hp_budget_ratio     = 0.35
##   var result := EntityDBValidator.validate_database(entries, cfg, "MVP")
class_name ValidationConfig extends RefCounted

## 玩家 ATK 中位预期值（D1 + D3 输入；须 ≥ 10，否则报根因错误而非逐怪 D1 违反）
var player_atk_expected: int = 20

## 玩家 HP 中位预期值（D3 输入；须 ≥ 1，否则报根因错误）
var player_hp_expected: int = 100

## 玩家 DEF 中位预期值（D3 输入；须 ≥ 0）
var player_def_expected: int = 5

## 击杀最大回合数上限（D1 输入；须在 [5, 20] 范围内，否则报根因错误）
var n_max: int = 10

## 单只怪允许消耗的玩家血量上限占比（D3 输入；须 ≥ 0.05，否则报根因错误）
## 当前默认值 0.35（GDD D3 标准值）
var hp_budget_ratio: float = 0.35
