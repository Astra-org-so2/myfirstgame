# DebugOverlay — the F1 performance HUD (TEST_PLAN §7, Phase 16).
#
# The visual measurement: fps, frame P50/P95 (rolling window), and
# the structural budgets (nodes, bodies, fx, local lights) live on
# screen — on a device the render metrics join the list (draw
# calls, RAM) when the engine exposes them; in the headless rig
# they read n/a (the honest split, ADR-035). Debug builds only
# (the same rule as F1–F8: release-off).
class_name DebugOverlay
extends CanvasLayer

const _PerfBenchmark = preload("res://scripts/dev/perf_benchmark.gd")

const _WINDOW: int = 90  # the rolling P50/P95 window (~1.5 s)
const _REFRESH: float = 0.25  # the label refresh (4 Hz)


var _label: Label = null
var _scope: Node = null
var _samples: PackedFloat32Array = PackedFloat32Array()
var _last_t: int = 0
var _left: float = 0.0


func _ready() -> void:
	layer = 90
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override(
			"font_color", Color(0.7, 0.9, 0.7, 0.9))
	_label.position = Vector2(8.0, 8.0)
	add_child(_label)
	visible = false


# Observe the scene's scope (the game, not the harness).
func setup(scope: Node) -> void:
	_scope = scope
	_last_t = Time.get_ticks_msec()


func _process(delta: float) -> void:
	if not visible or _scope == null or not is_instance_valid(_scope):
		return
	var now: int = Time.get_ticks_msec()
	var dt: float = float(now - _last_t)
	_last_t = now
	if dt > 0.0 and dt < 1000.0:
		_samples.append(dt)
		if _samples.size() > _WINDOW:
			_samples.remove_at(0)
	_left -= delta
	if _left > 0.0:
		return
	_left = _REFRESH
	_refresh()


func _refresh() -> void:
	var l: String = "AFTER YOU — F1 debug (debug build)\n"
	var fps: int = 0
	if DisplayServer.has_method("get_fps"):
		fps = int(DisplayServer.call("get_fps"))
	l += "fps: %d\n" % (fps if fps > 0 else -1)
	if _samples.size() > 4:
		var s: PackedFloat32Array = _samples.duplicate()
		s.sort()
		var p50: float = s[s.size() / 2]
		var p95: float = s[int(float(s.size()) * 0.95)]
		l += "frame_ms: p50=%.1f p95=%.1f\n" % [p50, p95]
	var c: Dictionary = _PerfBenchmark._count(_scope)
	l += "nodes: %d / 2000\n" % int(c["nodes"])
	l += "bodies: %d / 40\n" % int(c["bodies"])
	l += "fx: %d / 200\n" % int(c["fx"])
	l += "local lights: %d / 6\n" % int(c["lights"])
	# The render metrics: device-only (guarded; the rig has no GPU
	# bridge for these).
	if RenderingServer.has_method("get_render_info"):
		var di: Variant = RenderingServer.call("get_render_info", 1)
		if typeof(di) == TYPE_INT:
			l += "draw_calls: %d / 150\n" % int(di)
	var mem: int = int(OS.call("get_used_memory_bytes"))
	if mem > 0:
		l += "ram_mb: %d / 1200\n" % (mem / 1024 / 1024)
	_label.text = l
