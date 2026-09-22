# Integration: Player.tscn in the headless rig (Phase 2).
#
# The rig has no 3D physics (ADR-002), so the player runs on the
# MovementPort MOCK backend (body = null) through the set_port seam —
# exactly the path ARCHITECTURE §3.4 prescribes.
#
# Rig constraints (ADR-022) shape this suite:
# - engine frame timing is unreliable (test time can elapse during boot,
#   before the frame pump starts) -> the controller is driven with
#   deterministic manual _physics_process ticks (fixed DT);
# - Input.parse_input_event does not feed the action state in this build
#   -> Input.action_press/release is used instead (synchronous, verified).
# Cross-file references via preload-consts (ADR-022).
extends Node

const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _STATE = preload("res://scripts/player/player_state.gd")

const DT: float = 1.0 / 60.0


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/player/Player.tscn")
	ctx.check(packed != null, "player: scene loads")
	if packed == null:
		return
	var player: _PLAYER = packed.instantiate()
	ctx.check(player != null and player is _PLAYER,
			"player: controller attached")
	if player == null:
		return

	# Headless seam: mock physics (gravity, flat floor at y=0, no walls).
	var mock: _PORT = _PORT.new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	add_child(player)

	# --- W (move_up) moves the player forward (-Z) at ~walk speed ---
	Input.action_press("move_up")
	_tick(player, 30)  # 0.5 s
	var p1: Vector3 = mock.get_position()
	ctx.check(p1.z < -0.5, "player: W moves forward (z=%.3f)" % p1.z)
	ctx.check(mock.is_on_ground(), "player: stays on the floor")
	ctx.check(p1.z < -1.3 and p1.z > -2.4,
			"player: ~walk speed over 0.5s (z=%.3f)" % p1.z)

	# --- release W: the player stops (deceleration) ---
	Input.action_release("move_up")
	_tick(player, 12)  # 0.2 s braking (walk 4.0 / decel 50 = 0.08 s)
	var p3: Vector3 = mock.get_position()
	_tick(player, 18)  # 0.3 s: must be fully stopped
	var p4: Vector3 = mock.get_position()
	ctx.check(p4.distance_to(p3) < 0.01,
			"player: stopped after release (drift %.4f)" % p4.distance_to(p3))

	# --- dodge (edge-triggered) with i-frames, then recovery ---
	Input.action_press("dodge")
	_tick(player, 7)  # ~117 ms: inside the i-frame window [50, 250] ms
	var in_dodge: bool = player.get_state() == _STATE.State.DODGE
	var in_iframes: bool = player.is_invulnerable()
	Input.action_release("dodge")
	ctx.check(in_dodge, "player: dodge -> DODGE state")
	ctx.check(in_iframes, "player: i-frames active mid-dodge")
	_tick(player, 30)  # dodge (0.35 s) ends + margin
	ctx.check(player.get_state() != _STATE.State.DODGE,
			"player: dodge ends")

	# --- take_hit: HURT (hitstun) -> recovery ---
	player.take_hit(Vector3(0.0, 0.0, 1.0))
	ctx.check(player.get_state() == _STATE.State.HURT,
			"player: take_hit -> HURT")
	_tick(player, 36)  # 0.6 s > hurt duration 0.35 s
	ctx.check(player.get_state() == _STATE.State.IDLE,
			"player: recovers from HURT to IDLE")

	# --- respawn: position + stamina reset ---
	var pos_before: Vector3 = mock.get_position()
	ctx.check(pos_before.length() > 0.3,
			"player: has moved before respawn (len=%.3f)" % pos_before.length())
	player.respawn(Vector3.ZERO)
	ctx.check(mock.get_position() == Vector3.ZERO,
			"player: respawn resets position")
	ctx.check(player.get_stamina() >= player.data.stamina_max - 1.0,
			"player: respawn restores stamina")
	ctx.check(player.get_state() == _STATE.State.IDLE,
			"player: respawn resets state")


# Deterministic tick pump (ADR-022: no engine frames are relied on).
func _tick(p: _PLAYER, n: int) -> void:
	for i in n:
		p._physics_process(DT)
