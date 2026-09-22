# StaffController — the Echo Staff (WEAPON_DESIGN §3, Phase 6).
#
# The staff is NOT "damage" — it is "memory": 4 actions, each with its
# own CD, one cast time (1.5 s).
#   Shatter (ATK): 40 dmg into one target in front — the "strike".
#   Read    (SPC): marks every target inside the Read range (5 s
#       markers at their positions). In Phase 9 the same markers
#       extend to Echoes (the ECHO of the action — ECHO_SYSTEM_DESIGN).
#   Soothe  (V): the nearest target "sleeps" (EnemyLogic.SOOOTHED,
#       3 s base; GENTLE HAND extends it) — calm, not kill.
#   Disrupt (B): dissolves Echo targets. The Echo system is Phase 9,
#       so in Phase 6 the cast honestly resolves ZERO targets (the CD
#       is spent, nothing happens — no fake glow).
#
# Driven by the loadout each tick (HitStop clock, ADR-023). Damage
# flows through the resolver only.
class_name StaffController
extends Node

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _FX = preload("res://scripts/gameplay/progression/inheritance_effects.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")

enum Phase { IDLE, CASTING }

const ARC_HALF_DEG: float = 25.0  # "in front of the staff"

var _player: Node = null
var _data: _DATA = null
var _resolver: Node = null
var _sfx: Node = null
var _effects: _FX = null
var _ws: _WS = null

var _phase: int = Phase.IDLE
var _cast_left: float = 0.0
var _pending_action: StringName = &""
var _cds: Dictionary = {}  # action -> seconds left
var _atk_held: bool = false
var _spc_held: bool = false
var _soothe_held: bool = false
var _disrupt_held: bool = false
# Effective (Inheritance-bent) numbers; refreshed on bind/reset.
var _eff_read_range: float = 8.0
var _eff_soothe: float = 3.0
var _eff_disrupt_count: int = 1

# Read marked positions (the scene draws the markers).
signal marked(positions: PackedVector3Array)
# Soothe woke nothing / soothed a target (scene: the cue).
signal soothed(target: Node)
# Disrupt resolved N echo targets (0 in Phase 6 — Phase 9 fills it).
signal disrupted(count: int)


func bind(player: Node, data: _DATA, resolver: Node,
		effects: _FX, ws: _WS) -> void:
	_player = player
	_data = data
	_resolver = resolver
	_effects = effects
	_ws = ws
	_cds = {"shatter": 0.0, "read": 0.0, "soothe": 0.0, "disrupt": 0.0}
	refresh_effects()


func set_sfx(sfx: Node) -> void:
	_sfx = sfx


func refresh_effects() -> void:
	if _effects == null or _data == null:
		return
	var s: Dictionary = _effects.staff(_data, _ws)
	_eff_read_range = s["read_range"]
	_eff_soothe = s["soothe_duration"]
	_eff_disrupt_count = int(s["disrupt_count"])


func is_action_ready(action: StringName) -> bool:
	return float(_cds.get(action, 0.0)) <= 0.0


# Per-RUN reset (respawn): no CDs, no cast in flight.
func reset() -> void:
	_phase = Phase.IDLE
	_cast_left = 0.0
	_pending_action = &""
	_cds = {"shatter": 0.0, "read": 0.0, "soothe": 0.0, "disrupt": 0.0}
	_atk_held = false
	_spc_held = false
	_soothe_held = false
	_disrupt_held = false
	refresh_effects()


func update(delta: float) -> void:
	if _data == null or _player == null:
		return
	for a in _cds:
		if float(_cds[a]) > 0.0:
			_cds[a] = maxf(0.0, float(_cds[a]) - delta)
	var can: bool = _player.can_act()
	var atk: bool = Input.is_action_pressed("attack")
	if atk and not _atk_held and can:
		_try_cast("shatter")
	_atk_held = atk
	var spc: bool = Input.is_action_pressed("special")
	if spc and not _spc_held and can:
		_try_cast("read")
	_spc_held = spc
	var so: bool = Input.is_action_pressed("staff_soothe")
	if so and not _soothe_held and can:
		_try_cast("soothe")
	_soothe_held = so
	var di: bool = Input.is_action_pressed("staff_disrupt")
	if di and not _disrupt_held and can:
		_try_cast("disrupt")
	_disrupt_held = di

	if _phase == Phase.CASTING:
		# A hit cancels the cast (the staff is a "talking" weapon —
		# you don't keep chanting through hitstun).
		if not can:
			_phase = Phase.IDLE
		else:
			_cast_left -= delta
			if _cast_left <= 0.0:
				_resolve_cast()
				_phase = Phase.IDLE


func _try_cast(action: StringName) -> void:
	if _phase != Phase.IDLE or not is_action_ready(action):
		return
	_pending_action = action
	_phase = Phase.CASTING
	_cast_left = _data.staff_cast_time


func _resolve_cast() -> void:
	var origin: Vector3 = _player.get_body_position()
	var facing: Vector3 = _player.get_facing()
	match _pending_action:
		&"shatter":
			var t: Node = _target_in_front()
			if t != null:
				_hit(t)
			_cds["shatter"] = _data.staff_shatter_cd
		&"read":
			var positions: PackedVector3Array = PackedVector3Array()
			for n in _resolver.get_target_nodes():
				if n == null or not is_instance_valid(n) or n == _player:
					continue
				var ct: _CT = _resolver.get_combat_target(n)
				if ct == null or ct.is_dead():
					continue
				var to: Vector3 = n.global_position - origin
				if to.length() <= _eff_read_range:
					positions.append(n.global_position)
			if positions.size() > 0:
				marked.emit(positions)
			_cds["read"] = _data.staff_read_cd
		&"soothe":
			var n: Node = _nearest_target(_data.staff_range)
			if n != null and n.has_method("logic"):
				var logic: Variant = n.logic()
				if logic != null and logic.has_method("apply_soothe"):
					logic.apply_soothe(_eff_soothe)
					soothed.emit(n)
			_cds["soothe"] = _data.staff_soothe_cd
		&"disrupt":
			# Phase 6: there are no Echo entities in the scene yet
			# (Phase 9). The cast resolves an honest zero.
			disrupted.emit(0)
			_cds["disrupt"] = _data.staff_disrupt_cd
		_:
			pass
	_pending_action = &""


func _target_in_front() -> Node:
	var best: Node = null
	var best_dist: float = _data.staff_range
	var origin: Vector3 = _player.get_body_position()
	var facing: Vector3 = _player.get_facing()
	for n in _resolver.get_target_nodes():
		if n == null or not is_instance_valid(n) or n == _player:
			continue
		var ct: _CT = _resolver.get_combat_target(n)
		if ct == null or ct.is_dead():
			continue
		var to: Vector3 = n.global_position - origin
		var dist: float = to.length()
		if dist > best_dist:
			continue
		var angle: float = rad_to_deg(acos(
				clampf(facing.dot(to.normalized()), -1.0, 1.0)))
		if angle > ARC_HALF_DEG:
			continue
		best = n
		best_dist = dist
	return best


func _nearest_target(max_dist: float) -> Node:
	var best: Node = null
	var best_dist: float = max_dist
	var origin: Vector3 = _player.get_body_position()
	for n in _resolver.get_target_nodes():
		if n == null or not is_instance_valid(n) or n == _player:
			continue
		var ct: _CT = _resolver.get_combat_target(n)
		if ct == null or ct.is_dead():
			continue
		var dist: float = n.global_position.distance_to(origin)
		if dist <= best_dist:
			best = n
			best_dist = dist
	return best


func _hit(t: Node) -> void:
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = t
	req.amount = float(_data.staff_shatter_damage)
	req.type = _DREQ.Type.STAFF
	req.position = t.global_position
	req.knockback_direction = t.global_position \
			- _player.get_body_position()
	_resolver.resolve(req)
	_sfx_play(&"hit")


func _sfx_play(name: StringName) -> void:
	if _sfx != null and _sfx.has_method("play"):
		_sfx.play(name)
