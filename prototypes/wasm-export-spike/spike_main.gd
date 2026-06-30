# THROWAWAY spike harness — prototypes/wasm-export-spike.
# Validates ADR-0007 P3 platform APIs on the real Douyin WebGL2 runtime.
# NOT game code. Delete after the spike verdict is recorded in ADR-0007.
#
# Renders PASS/FAIL on-screen (visible in Douyin IDE) AND prints to console.
# Tap the screen to exercise InputEventScreenTouch (P3-6).
extends Control

# Inner types mirror ADR-0001's nested carrier (FloorEntry.grid).
# Carrier = Resource (ADR-0001 revised 2026-06-29: RefCounted has no duplicate*).
class SpikeCell extends Resource:
	@export var cell_type: String = ""   # @export REQUIRED: duplicate* only copies @export'd props

class SpikeFloor extends Resource:
	@export var floor_id: String = ""
	@export var grid: Array = []   # Array[Array[SpikeCell]] — @export REQUIRED for deep-copy

class SpikeEmitter extends Node:
	signal pinged
	func ping() -> void:
		pinged.emit()

var _label: RichTextLabel
var _touch_count: int = 0
var _lines: Array[String] = []

func _ready() -> void:
	_build_ui()
	_run_checks()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.add_theme_font_size_override("normal_font_size", 20)
	add_child(_label)

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	var mark := "[color=lime]PASS[/color]" if ok else "[color=red]FAIL[/color]"
	_lines.append("%s  %s  %s" % [mark, check_name, detail])
	print("[SPIKE] ", "PASS" if ok else "FAIL", "  ", check_name, "  ", detail)

func _run_checks() -> void:
	_lines.clear()

	# P3-1 — Autoload startup order (ADR-0002)
	var order_ok: bool = SpikeConfigB != null and SpikeConfigB.order_ok
	_check("P3-1 Autoload order (A before B)", order_ok)

	# P3-2 — FileAccess read res:// JSON (ADR-0005)
	var text := FileAccess.get_file_as_string("res://data/spike_data.json")
	_check("P3-2 FileAccess res:// JSON read", not text.is_empty(),
		"(%d bytes)" % text.length())

	# P3-3 — JSON.parse_string + int() cast of JSON number (ADR-0005 float bug)
	var parsed: Variant = JSON.parse_string(text)
	var parse_ok: bool = parsed != null and parsed is Dictionary
	_check("P3-3 JSON.parse_string -> Dictionary", parse_ok)
	if parse_ok:
		var m: Dictionary = (parsed as Dictionary).get("monster", {})
		var hp_raw: Variant = m.get("hp", null)
		var hp_int := int(hp_raw) if hp_raw != null else -1
		_check("P3-3b int() cast of JSON number == 20", hp_int == 20,
			"(parsed -> %d)" % hp_int)

	# P3-4 — Resource nested deep-copy (ADR-0001, carrier = Resource since 2026-06-29).
	# Desktop already confirmed Resource has duplicate()/duplicate_deep() (verify_dup.gd);
	# this run confirms duplicate_deep() ALSO works on the Douyin/WASM runtime — i.e.
	# the chosen carrier's read-only-copy contract holds on-platform. Expect PASS.
	var spike_floor := SpikeFloor.new()
	spike_floor.floor_id = "spike_001"
	var c0 := SpikeCell.new()
	c0.cell_type = "WALL"
	spike_floor.grid.append([c0])

	var has_dup: bool = spike_floor.has_method("duplicate")
	var has_dup_deep: bool = spike_floor.has_method("duplicate_deep")
	_check("P3-4a Resource has duplicate()", has_dup,
		"<- ADR-0001 returns duplicate() copies")
	_check("P3-4b Resource has duplicate_deep()", has_dup_deep,
		"<- ADR-0001/0005/0009 rely on this for FloorEntry (WASM check)")

	if has_dup_deep:
		# .call() avoids a compile-time error if the method is absent.
		var copy: Object = spike_floor.call("duplicate_deep")
		var deep_ok := false
		if copy != null:
			var copied_grid: Variant = copy.get("grid")
			if copied_grid is Array and (copied_grid as Array).size() > 0:
				var copied_cell: Object = copied_grid[0][0]
				copied_cell.set("cell_type", "EMPTY")
				deep_ok = (c0.cell_type == "WALL")  # original must be unchanged
		_check("P3-4c duplicate_deep independence (mutate copy != original)", deep_ok)
	else:
		_check("P3-4c duplicate_deep independence", false,
			"SKIPPED — duplicate_deep absent (see P3-4b — ADR-0001 follow-up)")

	# P3-5 — signal emit + Callable connect (Autoload -> Node pattern, ADR-0003)
	var sig := {"v": false}
	var emitter := SpikeEmitter.new()
	emitter.pinged.connect(func() -> void: sig["v"] = true)
	emitter.ping()
	_check("P3-5 signal emit + Callable connect", sig["v"])

	# P3-6 — touch input (tap screen; re-runs on each tap)
	_check("P3-6 InputEventScreenTouch (tap screen)", _touch_count > 0,
		"(taps=%d)" % _touch_count)

	_render()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_touch_count += 1
		_run_checks()

func _render() -> void:
	var ver: String = Engine.get_version_info().get("string", "?")
	var rmethod: Variant = ProjectSettings.get_setting(
		"rendering/renderer/rendering_method", "?")
	var header := "[b]WASM/Douyin Export Spike — ADR-0007 P3[/b]\nGodot %s | renderer=%s\n\n" % [
		ver, str(rmethod)]
	_label.text = header + "\n".join(_lines)
