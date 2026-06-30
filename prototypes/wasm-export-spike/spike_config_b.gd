# THROWAWAY spike Autoload B — depends on A (ADR-0002 order guarantee).
# Listed SECOND; at its _ready(), A must already be initialized.
extends Node

var is_initialized: bool:
	get: return _initialized
var _initialized: bool = false
var order_ok: bool = false

func _ready() -> void:
	# SpikeConfigA is the global Autoload name; resolves to A's node instance.
	order_ok = SpikeConfigA != null and SpikeConfigA.is_initialized
	_initialized = true
