# GhostController — the Passive Echo body (TECHNICAL_DESIGN section
# 5, ECHO_SYSTEM_DESIGN section 1.2): a code-built player silhouette
# (ADR-022: primitives, no .tscn pipeline) that REPLAYS the last run
# through a GhostTimeline.
#
#   - no physics: layer 9, mask 0 (it «просвечивает» — no collision,
#     no interaction, no damage);
#   - movement: chase the sampled timeline point at max_speed (the
#     speed cap, section 5.3 — no teleport artifacts);
#   - actions: the keyframe action plays as a body pulse/swing
#     (a swing WITHOUT damage — the ghost never mutates the world,
#     section 5.4);
#   - dissolve pulse: a rewind skip (a room the new layout lacks —
#     «не всё помнится») flashes the ghost;
#   - fade out: replay end or the player outran it (dist > fade_dist)
#     -> dissolve over fade_time (3 s) -> done signal.
#
# Cost (section 5.6): 1 silhouette (2 meshes) + 1 material + O(1)
# interpolation per frame. The final dissolve/rim SHADER is the
# Phase 13 polish pass (mobile budget ADR-021); this is the honest
# prototype material (transparency + tint + faint emissive).
class_name GhostController
extends Node3D

const _TL = preload("res://scripts/gameplay/echo/ghost_timeline.gd")
const _KF = preload("res://scripts/gameplay/echo/ghost_keyframe.gd")
const _PED = preload("res://scripts/gameplay/echo/passive_echo_data.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

signal finished(ghost: Node)

var timeline: _TL
var data: _PED
var player: Node = null

var _body: MeshInstance3D
var _visor: MeshInstance3D
var _mat: StandardMaterial3D
var _vis_mat: StandardMaterial3D
var _t: float = 0.0
var _fading: float = -1.0  # <0 = not fading, else seconds left
var _pulse: float = 0.0
var _swing: float = 0.0
var _last_action: int = -1
var _done: bool = false
var _footprint_nodes: Array = []


func setup(p_tl: _TL, p_data: _PED, p_player: Node) -> void:
	timeline = p_tl
	data = p_data
	player = p_player
	_build_visual()
	if timeline != null:
		var k0: _KF = timeline.keyframes[0]
		global_position = k0.pos
		rotation.y = deg_to_rad(k0.ry)
		_build_footprints()


func footprint_nodes() -> Array:
	return _footprint_nodes


# Called by the director for each rewind skip of the current level:
# a brief brighten («the memory skips»).
func pulse() -> void:
	_pulse = 0.35


func start_fade(seconds: float = -1.0) -> void:
	if _fading < 0.0:
		_fading = data.fade_time if seconds < 0.0 else seconds


func is_done() -> bool:
	return _done


func update(delta: float) -> void:
	if _done or timeline == null or timeline.is_empty():
		return
	_t += delta
	var t: float = _t
	var at_end: bool = t >= timeline.start_t + timeline.duration
	if at_end:
		t = timeline.start_t + timeline.duration
	# «Рассеивается» (section 1.2): the replay finished, or the
	# player outran it (dist > fade_dist) — fade over fade_time.
	if _fading < 0.0 and (at_end or _player_dist() > data.fade_dist):
		start_fade()
	var target: Vector3 = timeline.sample(t)
	target.y = 0.0
	# The speed cap (section 5.3): chase, never teleport.
	var step: float = data.max_speed * delta
	var dist: float = global_position.distance_to(target)
	if dist > 1e-4:
		global_position = global_position.move_toward(target, step)
		rotation.y = lerp_angle(rotation.y,
				deg_to_rad(timeline.sample_ry(t)),
				minf(1.0, 8.0 * delta))
	# The action pulse (a swing without damage).
	var act: int = timeline.action_at(t)
	if act != _last_action and act != _EV.Type.ENTER_ROOM:
		_swing = 0.25
	_last_action = act
	_update_fx(delta)


func _player_dist() -> float:
	if player == null:
		return 0.0
	return global_position.distance_to(player.get_body_position())


func _build_visual() -> void:
	# The ghost is a pure visual Node3D — no physics object at all
	# (design section 5.5: «no physics»; the echo layer 9 is the
	# renderer's concern once it has collision).
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(data.tint.r, data.tint.g, data.tint.b,
			data.opacity)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = data.tint
	_mat.emission_energy_multiplier = 0.25
	_mat.roughness = 0.9
	_body = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.size = Vector2(0.35, 1.0)
	cm.material = _mat
	_body.mesh = cm
	_body.position = Vector3(0.0, 0.85, 0.0)
	add_child(_body)
	_vis_mat = StandardMaterial3D.new()
	_vis_mat.albedo_color = Color(0.5, 0.8, 0.9, data.opacity)
	_vis_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_vis_mat.emission_enabled = true
	_vis_mat.emission = Color(0.4, 0.7, 0.85)
	_vis_mat.emission_energy_multiplier = 0.8
	_visor = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.18, 0.07, 0.1)
	bm.material = _vis_mat
	_visor.mesh = bm
	_visor.position = Vector3(0.0, 1.42, -0.28)
	add_child(_visor)


# «Footprints» (section 1.2): the walked trail, small flat markers
# along the path (the A10 figure's pattern).
func _build_footprints() -> void:
	var n: int = mini(data.footprints, timeline.keyframe_count())
	if n < 2:
		return
	for i in n:
		var u: float = float(i) / float(n - 1)
		var p: Vector3 = timeline.sample(
				timeline.start_t + u * timeline.duration)
		var m: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(0.22, 0.22)
		var fm: StandardMaterial3D = StandardMaterial3D.new()
		fm.albedo_color = Color(data.tint.r, data.tint.g, data.tint.b,
				0.25 * (1.0 - u) + 0.05)
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.material = fm
		m.mesh = pm
		m.position = Vector3(p.x, 0.03, p.z)
		add_child(m)
		_footprint_nodes.append(m)


func _update_fx(delta: float) -> void:
	if _pulse > 0.0:
		_pulse -= delta
	if _swing > 0.0:
		_swing -= delta
	var base_a: float = data.opacity
	if _fading >= 0.0:
		_fading -= delta
		if _fading <= 0.0:
			_fade_finish()
			return
		base_a *= clampf(_fading / data.fade_time, 0.0, 1.0)
	var k: float = 1.0
	if _pulse > 0.0:
		k = 1.0 + 0.5 * (_pulse / 0.35)
	if _swing > 0.0:
		# The swing: a brief body lean (the prototype for the Phase
		# 13 animation; the ghost hits nothing).
		_body.rotation.x = -0.4 * (_swing / 0.25)
	else:
		_body.rotation.x = 0.0
	_mat.emission_energy_multiplier = 0.25 * k
	_vis_mat.emission_energy_multiplier = 0.8 * k
	_mat.albedo_color.a = base_a
	_vis_mat.albedo_color.a = base_a


func _fade_finish() -> void:
	_done = true
	_finished_emit()


func _finished_emit() -> void:
	finished.emit(self)
