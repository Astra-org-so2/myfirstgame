# WeaponController — the player's weapon (Phase 4: BLADE).
#
# A child of PlayerController, driven by the player each tick
# (`update(delta)`), so the whole action clock (movement + combat)
# freezes together under the scene HitStop (ADR-023).
#
# Composition:
# - WeaponLogic: pure combo/special state machine (unit-tested);
# - DamageResolver: hit registration + damage application (injected by
#   the main scene — the controller never touches hp directly);
# - SfxBus: swing + riposte cues (impact/hurt cues — main scene wiring).
#
# Hitbox: sector sampling during active frames (pure math, no Area3D —
# deterministic and rig-testable; ADR-023). A target is hit once per
# swing (per-swing hit set).
#
# Not auto-processing: it has no _physics_process on purpose.
class_name WeaponController
extends Node

const _LOGIC = preload("res://scripts/gameplay/combat/weapon_logic.gd")
const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _HIT = preload("res://scripts/gameplay/combat/weapon_hit.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _DRES = preload("res://scripts/gameplay/combat/damage_result.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")

var _player: Node = null
var _data: _DATA = null
var _logic: _LOGIC = null
var _resolver: Node = null
var _sfx: Node = null
var _cam_rig: Node = null

var _atk_held: bool = false
var _special_held: bool = false
var _swing_hit: Array = []  # targets already hit by the current swing
# Landed (unblocked) hits this session — MemoryStats.dominant_style
# (melee verb). Reset with the weapon on respawn.
var hits_landed: int = 0


func bind(player: Node, data: _DATA, resolver: Node) -> void:
	_player = player
	_data = data
	_resolver = resolver
	_logic = _LOGIC.new(data)
	# Riposte resolution: watch the player's own damage (cross-script
	# signal connect is safe; cross-script Callable.call() is not —
	# ADR-022).
	var ct: Variant = player.get_combat_target()
	if ct != null and ct.has_signal("damaged"):
		ct.damaged.connect(_on_player_damaged)


func set_sfx(sfx: Node) -> void:
	_sfx = sfx


func set_camera_rig(rig: Node) -> void:
	_cam_rig = rig


func get_logic() -> _LOGIC:
	return _logic


# Full state reset (player respawn: no combo/CD leaks across deaths).
func reset() -> void:
	if _logic != null:
		_logic.reset()
	_atk_held = false
	_special_held = false
	_swing_hit = []
	hits_landed = 0


# One player tick (the player drives this; see class doc).
func update(delta: float) -> void:
	if _logic == null or _player == null:
		return
	var can: bool = _player.can_act()
	var atk: bool = Input.is_action_pressed("attack")
	if atk and not _atk_held and can:
		_try_attack()
	_atk_held = atk
	var sp: bool = Input.is_action_pressed("special")
	if sp and not _special_held and can:
		if _logic.request_special():
			_sfx_play(&"riposte")  # arm cue; the parry ping is scene-wired
	_special_held = sp

	var events: Array[String] = _logic.update(delta)
	for ev in events:
		if ev == _LOGIC.EV_HIT_STARTED:
			_on_swing_started()
	if _logic.is_active():
		_sample_hitbox()
	# An enemy hit that stuns the player breaks the swing in windup —
	# the Mimic's melee punish (ENEMY_DESIGN §4) and the general
	# "stagger stops you mid-swing" rule.
	if not can and (_logic.phase() == _LOGIC.Phase.WINDUP
			or _logic.phase() == _LOGIC.Phase.ACTIVE):
		_logic.cancel_hit()


# --- Internals ---

func _try_attack() -> void:
	var ret: int
	if _logic.phase() == _LOGIC.Phase.IDLE:
		# Pre-check stamina for a fresh swing; a buffered chain re-checks
		# when the swing actually starts (stamina may have regenerated).
		if _player.get_stamina() < _logic.pending_stamina_cost():
			return
		ret = _logic.request_attack()
	else:
		ret = _logic.request_attack()  # buffer: chains at swing end
	if ret == 1:
		_on_swing_started()


func _on_swing_started() -> void:
	var hit: _HIT = _logic.current_hit()
	if hit == null:
		return
	if not _player.spend_stamina(float(hit.stamina_cost)):
		_logic.cancel_hit()
		return
	_swing_hit = []
	_sfx_play(&"swing")


func _sample_hitbox() -> void:
	var hit: _HIT = _logic.current_hit()
	if hit == null or _resolver == null:
		return
	var origin: Vector3 = _player.get_body_position()
	var facing: Vector3 = Vector3(
			_player.get_facing().x, 0.0, _player.get_facing().z)
	if facing.length() < 0.01:
		facing = Vector3(0.0, 0.0, -1.0)
	facing = facing.normalized()
	var targets: Array = _resolver.get_target_nodes()
	for t in targets:
		if t == _player or _swing_hit.has(t):
			continue
		var tpos: Vector3 = t.global_position
		var rel: Vector3 = Vector3(tpos.x - origin.x, 0.0, tpos.z - origin.z)
		var dist: float = rel.length()
		if dist > hit.range:
			continue
		if dist > 0.01:
			var angle: float = rad_to_deg(acos(
					clampf(facing.dot(rel.normalized()), -1.0, 1.0)))
			if angle > hit.arc * 0.5:
				continue
		_swing_hit.append(t)
		_hit_target(t, hit, rel, facing)


func _hit_target(t: Node, hit: _HIT, rel: Vector3, facing: Vector3) -> void:
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = t
	req.amount = float(hit.damage)
	req.type = _DREQ.Type.MELEE
	req.position = t.global_position
	req.knockback_direction = (
			rel.normalized() if rel.length() > 0.01 else facing)
	req.weapon = _data
	var res: _DRES = _resolver.resolve(req)
	if not res.blocked:
		hits_landed += 1


# Riposte counter: damage lands on the player inside the window.
func _on_player_damaged(req: Variant) -> void:
	if _logic == null or not _logic.is_in_riposte_window():
		return
	var r: _DREQ = req
	if r.blocked or r.source == null or r.source == _player:
		return
	_logic.end_riposte()
	# Stun the attacker (WEAPON_DESIGN §1.3: 1.5 s) + counter damage.
	var st: _CT = _resolver.get_combat_target(r.source)
	if st != null:
		st.apply_stun(_data.special_stun_duration)
	var creq: _DREQ = _DREQ.new()
	creq.source = _player
	creq.target = r.source
	creq.amount = float(_data.special_damage)
	creq.type = _DREQ.Type.SPECIAL
	creq.flags = _DREQ.FLAG_RIPOSTE
	creq.position = r.source.global_position
	var ppos: Vector3 = _player.get_body_position()
	var dir: Vector3 = Vector3(
			ppos.x - r.source.global_position.x, 0.0,
			ppos.z - r.source.global_position.z)
	creq.knockback_direction = (
			dir.normalized() if dir.length() > 0.01 else Vector3.ZERO)
	creq.weapon = _data
	_resolver.resolve(creq)


func _sfx_play(cue: StringName) -> void:
	if _sfx != null:
		_sfx.play(cue)
