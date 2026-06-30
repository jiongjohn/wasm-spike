# GDUnit4 v6 — 本脚本仅为兼容旧引用的重定向桩。
#
# GDUnit4 v6.0.0 自带官方 CLI 入口 `addons/gdUnit4/bin/GdUnitCmdTool.gd`，
# 旧版的自定义 runner（load GdUnitRunner.gd）在 v6 已失效。请改用官方入口：
#
#   # 1) 首次/CI 先建全局类缓存（否则 class_name 未注册）：
#   godot --headless --import
#   # 2) 跑测试：
#   godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode \
#         -a res://tests/unit -a res://tests/integration
#
# 已验证组合：Godot 4.5.2 + GDUnit4 v6.0.0（2026-06-30，story-003 8/8 PASSED）。
# 引用：ADR-0004 §3。
extends SceneTree

func _initialize() -> void:
	push_error("请改用官方入口：godot --headless -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit（先 godot --headless --import）。见本文件注释 / ADR-0004。")
	quit(2)
