# RangedWeaponController — the Hand Cannon (WEAPON_DESIGN §2, Phase 6).
#
# The cannon's identity: ONE shot = ONE decision.
# - a slow windup (1.8 s) then a kinematic projectile (15 m, 3° spread);
# - LIMITED ammo: 5 per run, ONE reload (1.5 s) — then the cannon is
#   spent until respawn (WEAPON_DESIGN §2.3);
# - SPECIAL "Break": 2 shots into 1 target (120 dmg), 60 s CD
#   (SLOW BURN shortens it — the InheritanceEffects level decides).
#
# Like the blade controller: a child of the player, driven by the
# loadout each tick (the action clock freezes with the HitStop,
# ADR-023). Damage flows through the resolver only.
class_name RangedWeaponController
extends Node

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _PROJ = preload("res://scripts/gameplay/combat/projectile.gd")
const _FX = preload("res://scripts/gameplay/progression/inheritance_effects.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")

enum Phase { IDLE, WINDUP, RELOAD, BREAK }

const PROJECTILE_SPEED: float = 40.0
const BREAK_INTERVAL: float = 0.2  # between the two Break shots

var _player: Node = null
var _data: _DATA = null
var _resolver: Node = null
var _sfx: Node = null
var _effects: _FX = null
var _ws: _WS = null
var _projectile_root: Node = null

var _phase: int = Phase.IDLE
var _elapsed: float = 0.0
var _ammo: int = 0
var _reloads_left: int = 0
var _break_cd_left: float = 0.0
var _break_shots_left: int = 0
var _break_timer: float = 0.0
var _atk_held: bool = false
var _special_held: bool = false
var _spread_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Effective (Inheritance-bent) numbers; refreshed on bind/reset.
var _eff_break_cd: float = 60.0

# The muzzle fired (main marks the noise when loud, plays the cue).
signal fired(origin: Vector3, loud: bool)


func bind(player: Node, data: _DATA, resolver: Node,
		effects: _FX, ws: _WS) -> void:
	_player = player
	_data = data
	_resolver = resolver
	_effects = effects
	_ws = ws
	_ammo = data.ammo_max
	_reloads_left = data.ammo_reload_max
	refresh_effects()


func set_sfx(sfx: Node) -> void:
	_sfx = sfx


func set_projectile_root(root: Node) -> void:
	_projectile_root = root


# Re-read the effective stats (after a death-screen choice: the next
# respawn re-binds through the loadout; this is the direct path).
func refresh_effects() -> void:
	if _effects == null or _data == null:
		return
	var c: Dictionary = _effects.cannon(_data, _ws)
	_eff_break_cd = c["break_cd"]


func set_spread_seed(seed: int) -> void:
	_spread_rng.seed = seed


func get_ammo() -> int:
	return _ammo


func get_reloads_left() -> int:
	return _reloads_left


func is_break_ready() -> bool:
	return _break_cd_left <= 0.0


# Per-RUN reset (respawn): the full 5 ammo, the one reload, no CDs.
func reset() -> void:
	_phase = Phase.IDLE
	_elapsed = 0.0
	_ammo = _data.ammo_max if _data != null else 0
	_reloads_left = _data.ammo_reload_max if _data != null else 0
	_break_cd_left = 0.0
	_break_shots_left = 0.0
	_break_timer = 0.0
	_atk_held = false
	_special_held = false
	refresh_effects()


func update(delta: float) -> void:
	if _data == null or _player == null:
		return
	if _break_cd_left > 0.0:
		_break_cd_left = maxf(0.0, _break_cd_left - delta)
	var can: bool = _player.can_act()
	var atk: bool = Input.is_action_pressed("attack")
	if atk and not _atk_held and can:
		_on_attack_edge()
	_atk_held = atk
	var sp: bool = Input.is_action_pressed("special")
	if sp and not _special_held and can:
		_on_special_edge()
	_special_held = sp

	# A hit interrupts the windup (the committed Break still lands
	# its remaining shots — "one target, one decision").
	if not can and _phase == Phase.WINDUP:
		_phase = Phase.IDLE
		_elapsed = 0.0
		return
	match _phase:
		Phase.WINDUP:
			_elapsed += delta
			if _elapsed >= _data.hits[0].windup:
				_fire_shot()
				_phase = Phase.IDLE
				_elapsed = 0.0
		Phase.RELOAD:
			_elapsed += delta
			if _elapsed >= _data.reload_time:
				_ammo = _data.ammo_max
				_reloads_left -= 1
				_phase = Phase.IDLE
				_elapsed = 0.0
		Phase.BREAK:
			_break_timer -= delta
			if _break_timer <= 0.0:
				_fire_shot(true)
				_break_shots_left -= 1
				if _break_shots_left <= 0:
					_phase = Phase.IDLE
		_:
			pass


func _on_attack_edge() -> void:
	if _phase != Phase.IDLE:
		return
	if _ammo > 0:
		_phase = Phase.WINDUP
		_elapsed = 0.0
	elif _reloads_left > 0:
		_phase = Phase.RELOAD
		_elapsed = 0.0


func _on_special_edge() -> void:
	if _phase != Phase.IDLE:
		return
	if _break_cd_left > 0.0:
		return
	var target: Node = _first_target_in_front()
	if target == null:
		return
	_phase = Phase.BREAK
	_break_shots_left = 2
	_break_timer = 0.0  # the first shot is immediate
	_break_cd_left = _eff_break_cd


func _first_target_in_front() -> Node:
	if _resolver == null:
		return null
	var facing: Vector3 = _player.get_facing()
	var origin: Vector3 = _player.get_body_position()
	var best: Node = null
	var best_dist: float = _data.fire_range
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
		if angle > 30.0:
			continue
		best = n
		best_dist = dist
	return best


func _fire_shot(break_shot: bool = false) -> void:
	if _projectile_root == null and is_inside_tree():
		_projectile_root = get_tree().current_scene
	if _projectile_root == null:
		return  # no scene root (headless rig): the shot has nowhere to go
	var shot: _PROJ = _PROJ.new()
	_projectile_root.add_child(shot)
	var origin: Vector3 = _player.get_body_position()
	var dir: Vector3 = _player.get_facing()
	if not break_shot:
		dir = _jitter(dir)
		_ammo = maxi(0, _ammo - 1)
	shot.launch(origin, dir, PROJECTILE_SPEED, _data.fire_range,
			float(_data.hits[0].damage), _player, _resolver)
	var c: Dictionary = _effects.cannon(_data, _ws) if _effects != null \
			else {"noise": _data.noise_on_fire}
	fired.emit(origin, bool(c["noise"]))
	_sfx_play(&"shot")  # the cannon's fire cue (procedural, Phase 14 final)


func _jitter(dir: Vector3) -> Vector3:
	if _data.spread_deg <= 0.0:
		return dir
	var ang: float = deg_to_rad(
			_spread_rng.randf_range(-_data.spread_deg * 0.5,
					_data.spread_deg * 0.5))
	return dir.rotated(Vector3.UP, ang)


func _sfx_play(name: StringName) -> void:
	if _sfx != null and _sfx.has_method("play"):
		_sfx.play(name)
