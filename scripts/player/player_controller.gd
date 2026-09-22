# PlayerController — the player's root controller (Phase 2).
#
# Composition (ARCHITECTURE §8: one root controller + part-nodes):
# - PlayerMovementLogic: pure state machine (tested headless);
# - MovementPort: the physics seam — engine mode in game, mock mode in
#   headless tests (ADR-002/ADR-022);
# - CameraRig: orbit camera (child scene);
# - PlaceholderVisualAnim: ADR-005 prototype visual (Phase 13: rig).
#
# Player knows nothing about CharacterBody3D physics directly (§3.4).
# Cross-file references use preload-consts (headless rig has no global
# class_name registry — ADR-022).
class_name PlayerController
extends CharacterBody3D

const _DATA = preload("res://scripts/player/player_data.gd")
const _STATE = preload("res://scripts/player/player_state.gd")
const _LOGIC = preload("res://scripts/player/player_movement_logic.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _VISUAL = preload("res://scripts/player/placeholder_visual_anim.gd")
const _JOY = preload("res://scripts/utilities/joystick_provider.gd")
const _CAM_RIG = preload("res://scripts/player/camera_rig.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _WEAPON = preload("res://scripts/gameplay/combat/weapon_controller.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")

signal state_changed(new_state: int)
signal dodge_started()
signal dodge_ended()
signal stamina_changed(value: float, max_value: float)

const _LOADOUT = preload("res://scripts/gameplay/combat/weapon_loadout.gd")

var data: _DATA
var camera_rig: _CAM_RIG
var weapon: _WEAPON
# Phase 6: the found weapons + the equipped one (the blade is adopted
# into it; the cannon/staff controllers join on pickup).
var loadout: _LOADOUT

# Combat (Phase 4): hp/i-frames/stun live in the CombatTarget; damage is
# applied ONLY through the DamageResolver (ARCHITECTURE §3.2).
var combat: _CT

var _logic: _LOGIC
var _port: _PORT
var _visual: _VISUAL
var _joy: _JOY
var _prev_state: int = _STATE.State.IDLE
var _last_stamina_emit: float = -1.0
# Dodge edge state (pressed this tick vs last tick; see _physics_process).
var _dodge_held: bool = false
var _dead: bool = false
var _respawn_timer: float = 0.0
var _respawn_pos: Vector3 = Vector3.ZERO
# Phase 6: the death screen is waiting for the 1-of-3 choice (the
# respawn countdown pauses; main clears it + calls request_respawn).
var death_choice_pending: bool = false
var _has_respawn_pos: bool = false


func _ready() -> void:
	if data == null:
		data = load("res://data/player/player_data.tres")
	if data == null:
		push_error("PlayerController: PlayerData missing (data/player/player_data.tres)")
		return
	var problems: Array[String] = data.validate()
	if not problems.is_empty():
		push_error("PlayerController: invalid PlayerData: " + ", ".join(problems))
	if camera_rig == null:
		camera_rig = $CameraRig
	_logic = _LOGIC.new(data)
	if _port == null:
		_port = _PORT.new(self, data.gravity, data.max_fall_speed)
	_visual = $Visual
	if weapon == null:
		weapon = $Weapon
	combat = _CT.new(self, float(data.health_max))
	combat.combat_id = &"player"
	combat.damaged.connect(_on_combat_damaged)
	combat.killed.connect(_on_combat_killed)
	combat.guarded.connect(_on_combat_guarded)


# The camera's sprint kick (P13 polish): the rig reads the run flag.
func _camera_sprint_sync(state: int) -> void:
	if camera_rig != null:
		camera_rig.set_sprinting(state == _STATE.State.RUN)


func _physics_process(delta: float) -> void:
	# Combat target tick (stun decay). The i-frame state is pushed
	# AFTER the logic update below — the dodge state can end inside the
	# update, and a pre-update push would leave the resolver one tick
	# stale at the i-frame boundary.
	combat.update(delta)

	# Death: countdown to auto-respawn (RunManager owns the flow from
	# Phase 8; this is the Phase 4 MVP behavior). Phase 6: while the
	# death screen waits for the 1-of-3 choice, the countdown pauses
	# (its 8 s window keeps the death->respawn UX inside 10 s).
	if _dead:
		# No control, no physics: the body stands still until respawn.
		if not death_choice_pending:
			_respawn_timer -= delta
			if _respawn_timer <= 0.0:
				_do_respawn()
		return

	_port.apply_gravity(delta)

	var can: bool = can_act()

	# Dodge input (edge-triggered). Held-edge (pressed this tick, not on the
	# previous one) instead of is_action_just_pressed: identical semantics in
	# the engine, plus it survives frames skipped over the press and works in
	# the headless rig, whose just-pressed state is only cleared by real
	# frame boundaries (ADR-022).
	var dodge_pressed: bool = can and Input.is_action_pressed("dodge")
	if dodge_pressed and not _dodge_held:
		var dir: Vector3 = _world_input_dir()
		if dir == Vector3.ZERO:
			dir = _logic.facing
		if _logic.start_dodge(dir):
			dodge_started.emit()
	_dodge_held = dodge_pressed

	# Stunned = no control: feed zero (deceleration skids the body to a
	# stop in the logic, no special state needed).
	var input_dir: Vector3 = _world_input_dir() if can else Vector3.ZERO
	var want_sprint: bool = can and Input.is_action_pressed("sprint")

	var desired: Vector3 = _logic.update(
			delta, input_dir, want_sprint, _port.is_on_ground())
	# Push the dodge i-frame state (the resolver reads it; the value
	# reflects this tick's state transitions).
	combat.invulnerable = _logic.is_invulnerable()

	var velocity: Vector3
	if _logic.is_hurt():
		velocity = desired  # logic owns the full velocity (knockback)
	else:
		velocity = Vector3(desired.x, _port.get_velocity().y, desired.z)
	_port.move(velocity)
	_port.integrate(delta)

	# Combat weapon (same clock: freezes under the scene HitStop with
	# movement; ADR-023). Phase 6: the loadout drives the EQUIPPED
	# weapon (the blade is adopted; cannon/staff join on pickup).
	if loadout != null:
		loadout.update_switch_input()
		loadout.update_active(delta)
	elif weapon != null:
		weapon.update(delta)

	# State + visual.
	var state: int = _logic.state
	_camera_sprint_sync(state)
	if state != _prev_state:
		if _prev_state == _STATE.State.DODGE:
			dodge_ended.emit()
		_prev_state = state
		state_changed.emit(state)
	var progress: float = 0.0
	if state == _STATE.State.DODGE:
		progress = clampf(
				1.0 - _logic.get_dodge_remaining() / data.dodge_duration, 0.0, 1.0)
	elif state == _STATE.State.HURT:
		progress = _logic.get_hurt_progress()
	_visual.update(state, delta, progress, progress)

	# Per-frame signals are a mobile budget leak (ADR-021): emit only on
	# meaningful change.
	if absf(_logic.stamina - _last_stamina_emit) > 0.5:
		_last_stamina_emit = _logic.stamina
		stamina_changed.emit(_logic.stamina, data.stamina_max)


# --- Input ---

func _read_input_2d() -> Vector2:
	# Argument order: (negative_x, positive_x, negative_y, positive_y).
	var v: Vector2 = Input.get_vector(
			"move_left", "move_right", "move_down", "move_up")
	if _joy != null:
		var tv: Vector2 = _joy.get_joystick_vector()
		if tv.length() > 0.1:
			v = tv
	return v


func _world_input_dir() -> Vector3:
	var v: Vector2 = _read_input_2d()
	if v.length() < 0.01 or camera_rig == null:
		return Vector3.ZERO
	return camera_rig.input_to_world(v)


# --- Composition / test seams ---

func set_port(port: _PORT) -> void:
	_port = port


func get_port() -> _PORT:
	return _port


func set_touch_provider(provider: _JOY) -> void:
	_joy = provider


# --- Public API (used by combat/run systems from Phase 4+) ---

# Hitstun-only entry (e.g. scripted/Phase-2-compat): applies the hurt
# state + knockback WITHOUT damage. Damage itself flows through the
# DamageResolver -> CombatTarget.damaged -> _on_combat_damaged.
func take_hit(direction: Vector3) -> void:
	# §6 (P17): a corpse cannot enter hitstun — a scripted hit that
	# lands after the death event (double-death window) is dropped.
	if _dead:
		return
	if _logic.state != _STATE.State.HURT:
		_logic.apply_hurt(direction)


func is_invulnerable() -> bool:
	return _logic.is_invulnerable()


func get_state() -> int:
	return _logic.state


func get_stamina() -> float:
	return _logic.stamina


# --- Combat (Phase 4) ---

# Can the player act (attack/interact)? False when dead, stunned, or in
# hitstun.
func can_act() -> bool:
	return not _dead \
			and not combat.is_stunned() \
			and _logic.state != _STATE.State.HURT


func get_facing() -> Vector3:
	return _logic.facing


func spend_stamina(amount: float) -> bool:
	return _logic.spend_stamina(amount)


func get_combat_target() -> _CT:
	return combat


# Phase 6: healing (the camp item, the EMBER camp fire). Not damage —
# it never flows through the resolver (one damage point, one way).
func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before: float = combat.hp
	combat.hp = minf(combat.max_hp, combat.hp + amount)
	return combat.hp - before


# Phase 6: the death-screen choice is made — respawn now (the UX
# budget: death -> respawn <= 10 s with the screen, GDD §12).
func request_respawn() -> void:
	if _dead:
		_respawn_timer = 0.0


func is_dead() -> bool:
	return _dead


func set_respawn_position(pos: Vector3) -> void:
	_respawn_pos = pos
	_has_respawn_pos = true


# --- Combat event handlers (resolver-driven) ---

func _on_combat_damaged(req: Variant) -> void:
	if _dead:
		return
	var r: _DREQ = req
	if not r.blocked:
		if _logic.state != _STATE.State.HURT:
			_logic.apply_hurt(r.knockback_direction)


# Phase 6: the SECOND CHANCE guard caught a lethal hit (hp = 1) —
# the world gives a FREE dodge with the wide 0.5 s i-frame window.
func _on_combat_guarded(_req: Variant) -> void:
	if _logic.state == _STATE.State.DODGE \
			or _logic.state == _STATE.State.HURT:
		return
	_logic.set_iframe_end_override(0.5)
	_logic.start_dodge(_logic.facing, true)


func _on_combat_killed() -> void:
	if _dead:
		return
	_dead = true
	_respawn_timer = 2.0  # MVP flow; RunManager takes over in Phase 8
	_logic.reset()
	_dodge_held = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.player_died.emit(get_body_position())


func _do_respawn() -> void:
	if not _has_respawn_pos:
		push_error("PlayerController: respawn requested without a spawn position")
		return
	respawn(_respawn_pos)
	combat.reset()
	# Per-RUN weapon state (ammo/CDs) back to the run start; the
	# effective Inheritance stats re-read (a death-screen choice may
	# have changed them).
	if loadout != null:
		loadout.reset_all()
	elif weapon != null:
		weapon.reset()
	_dead = false
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus != null:
		bus.player_spawned.emit(_respawn_pos)


# World position from the movement port (node position in engine mode,
# mock position in headless tests). Named get_body_position (not
# get_position) to avoid shadowing the Node3D built-in — cross-script
# calls to shadowed built-ins crash the headless rig (ADR-022).
func get_body_position() -> Vector3:
	return _port.get_position()


# Respawn (Phase 2 integration target; RunManager drives it from Phase 8).
func respawn(pos: Vector3) -> void:
	_port.set_position(pos)
	_port.move(Vector3.ZERO)
	_logic.reset()
	_prev_state = _STATE.State.IDLE
	_dodge_held = false
	state_changed.emit(_logic.state)
