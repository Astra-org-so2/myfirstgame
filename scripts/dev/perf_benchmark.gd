# PerfBenchmark — the §7 measurement (TEST_PLAN §7, Phase 16).
#
# Runs a scene for N seconds, samples every frame: the frame time
# (P50/P95/peak) and the structural budgets (nodes, physics bodies,
# live VFX/particles, local lights) — then writes
# user://perf_<label>.txt (the `--benchmark` file the owner pulls
# with `adb pull` into PERF_REPORT.md — numbers, not «на глаз»).
#
# Honest scope: in the headless rig the frame time is the wasm CPU
# time (no GPU), and the render metrics (draw calls, texture
# memory, process RAM) are n/a — the device run reports them when
# the engine exposes them (guarded). In the game it is a debug tool
# (F6), never in a release build.
class_name PerfBenchmark
extends Node

const _PATH_FMT: String = "user://perf_%s.txt"

signal finished(stats: Dictionary)

var _scope: Node = null
var _label: String = ""
var _left: float = 0.0
var _total: float = 0.0
var _samples: PackedFloat32Array = PackedFloat32Array()
var _nodes: Array = []
var _bodies: Array = []
var _fx: Array = []
var _lights: Array = []
var _last_t: int = 0


# Start sampling the scene's scope. The benchmark counts the
# SCOPE's descendants (the scene), not the whole tree (the debug
# overlay, the harness, ... are not the game).
func start(scope: Node, label: String, seconds: float = 10.0) -> void:
	if _scope != null:
		stop()
	_scope = scope
	_label = label
	_total = seconds
	_left = seconds
	_samples.clear()
	_nodes.clear()
	_bodies.clear()
	_fx.clear()
	_lights.clear()
	_last_t = Time.get_ticks_msec()
	set_physics_process(true)


func stop() -> void:
	if _scope == null:
		return
	set_physics_process(false)
	_finish()


func _physics_process(_delta: float) -> void:
	if _scope == null or not is_instance_valid(_scope):
		_scope = null
		_finish()
		return
	var now: int = Time.get_ticks_msec()
	var dt: float = float(now - _last_t)
	_last_t = now
	if dt > 0.0 and dt < 1000.0:  # a scheduler hiccup is not a frame
		_samples.append(dt)
	# The structural counts every 2nd frame (the counts move on
	# node spawn/despawn, not per frame).
	if _samples.size() % 2 == 0:
		var c: Dictionary = _count(_scope)
		_nodes.append(int(c.nodes))
		_bodies.append(int(c.bodies))
		_fx.append(int(c.fx))
		_lights.append(int(c.lights))
	_left -= _delta
	if _left <= 0.0:
		stop()


func _finish() -> void:
	if _scope == null:
		return
	var scope: Node = _scope
	_scope = null
	var stats: Dictionary = _stats()
	_write_file(stats)
	finished.emit(stats)
	# Keep the scope (the scene is the caller's; we only observed).
	var _s: Node = scope


func _stats() -> Dictionary:
	var s: PackedFloat32Array = _samples.duplicate()
	s.sort()
	var n: int = s.size()
	var p50: float = s[n / 2] if n > 0 else 0.0
	var p95: float = s[int(float(n) * 0.95)] if n > 0 else 0.0
	var peak: float = s[n - 1] if n > 0 else 0.0
	return {
		"label": _label,
		"seconds": _total,
		"samples": n,
		"frame_ms_p50": p50,
		"frame_ms_p95": p95,
		"frame_ms_peak": peak,
		"nodes_avg": _avg(_nodes),
		"nodes_peak": _peak(_nodes),
		"bodies_avg": _avg(_bodies),
		"bodies_peak": _peak(_bodies),
		"fx_avg": _avg(_fx),
		"fx_peak": _peak(_fx),
		"lights_avg": _avg(_lights),
		"lights_peak": _peak(_lights),
	}


func _write_file(stats: Dictionary) -> void:
	var path: String = _PATH_FMT % _label
	DirAccess.make_dir_recursive_absolute("user://")
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("PerfBenchmark: cannot write %s" % path)
		return
	var l: String = "AFTER YOU — perf benchmark (debug build)\n"
	l += "label: %s\n" % str(stats.label)
	l += "duration: %.1f s (%d frame samples)\n" % [
			float(stats.seconds), int(stats.samples)]
	l += "frame_ms: p50=%.1f p95=%.1f peak=%.1f\n" % [
			float(stats.frame_ms_p50), float(stats.frame_ms_p95),
			float(stats.frame_ms_peak)]
	l += "nodes: avg=%.0f peak=%.0f (budget <= 2000)\n" % [
			float(stats.nodes_avg), float(stats.nodes_peak)]
	l += "bodies: avg=%.0f peak=%.0f (budget <= 40)\n" % [
			float(stats.bodies_avg), float(stats.bodies_peak)]
	l += "fx/particles: avg=%.0f peak=%.0f (budget <= 200)\n" % [
			float(stats.fx_avg), float(stats.fx_peak)]
	l += "local lights: avg=%.0f peak=%.0f (budget <= 6)\n" % [
			float(stats.lights_avg), float(stats.lights_peak)]
	# The render metrics: the device reports them when the engine
	# exposes them; the rig cannot (no GPU).
	if RenderingServer.has_method("get_render_info"):
		var di: Variant = RenderingServer.call(
				"get_render_info", 1)  # INFO_DRAW_CALLS
		if typeof(di) == TYPE_INT:
			l += "draw_calls: %d (budget <= 150)\n" % int(di)
	var mem: int = int(OS.call("get_used_memory_bytes"))
	if mem > 0:
		l += "process_ram_kb: %d (budget <= 1228800)\n" % (mem / 1024)
	f.store_string(l)
	f.close()
	push_warning("PerfBenchmark: wrote %s" % path)


# The structural counts for a scope (the scene).
static func _count(scope: Node) -> Dictionary:
	var acc: Dictionary = {"nodes": 0, "bodies": 0, "fx": 0, "lights": 0}
	_count_node(scope, acc)
	return acc


static func _count_node(n: Node, acc: Dictionary) -> void:
	acc["nodes"] = int(acc["nodes"]) + 1
	var cls: String = n.get_class()
	if cls == "CharacterBody3D" or cls == "RigidBody3D" \
			or cls == "StaticBody3D":
		acc["bodies"] = int(acc["bodies"]) + 1
	elif cls == "GPUParticles3D" or cls == "CPUParticles3D":
		acc["fx"] = int(acc["fx"]) + 1
	elif cls == "MeshInstance3D" and n.get_parent() != null \
			and n.get_parent().name == "VfxPool":
		# The VFX is mesh-pooled (VfxPool, 8 slots) — the world
		# meshes are NOT counted as fx (they are the env budget).
		acc["fx"] = int(acc["fx"]) + 1
	elif cls == "OmniLight3D" or cls == "SpotLight3D":
		acc["lights"] = int(acc["lights"]) + 1
	for ch in n.get_children():
		_count_node(ch, acc)


static func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s: int = 0
	for v in a:
		s += int(v)
	return float(s) / float(a.size())


static func _peak(a: Array) -> int:
	var m: int = 0
	for v in a:
		m = maxi(m, int(v))
	return m
