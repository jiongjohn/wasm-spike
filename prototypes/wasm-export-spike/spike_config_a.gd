# THROWAWAY spike Autoload A — validates ADR-0002 Autoload startup order in WASM.
# Listed FIRST in project.godot [autoload]; its _ready() must run before B's.
extends Node

var is_initialized: bool:
	get: return _initialized
var _initialized: bool = false

func _ready() -> void:
	_initialized = true
