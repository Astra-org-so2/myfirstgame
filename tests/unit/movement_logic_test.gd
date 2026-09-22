# Unit: PlayerMovementLogic — pure movement state machine (Phase 2).
# Deterministic: fixed delta stepping, no physics, no Input.
# Cross-file references via preload-consts (ADR-022).
extends Node

const _DATA = preload("res://scripts/player/player_data.gd")
const _LOGIC = preload("res://scripts/player/player_movement_logic.gd")
const _STATE = preload("res://scripts/player/player_state.gd")

const DT: float = 1.0 / 60.0


func run(ctx: Variant) -> void:
	var data: _DATA = load("res://data/player/player_data.tres")
	var l: _LOGIC = _LOGIC.new(data)
	var F: Vector3 = Vector3(0.0, 0.0, -1.0)

	# --- States: idle / walk / run ---
	l.update(DT, Vector3.ZERO, false, true)
	ctx.check(l.state == _STATE.State.IDLE, "logic: no input = IDLE")
	l.update(DT, F, false, true)
	ctx.check(l.state == _STATE.State.WALK, "logic: input = WALK")
	for i in 10:
		l.update(DT, F, true, true)
	ctx.check(l.state == _STATE.State.RUN,
			"logic: input + sprint = RUN")

	# --- Walk speed converges to walk_speed ---
	l.reset()
	var v: Vector3 = Vector3.ZERO
	for i in 120:
		v = l.update(DT, F, false, true)
	ctx.check(absf(v.length() - data.walk_speed) < 0.01,
			"logic: walk speed = walk_speed (got %.3f)" % v.length())

	# --- Sprint drains stamina; exhaustion stops sprint ---
	l.reset()
	var s0: float = l.stamina
	for i in 240:  # 4 s of sprinting drains 100 stamina
		l.update(DT, F, true, true)
	ctx.check(l.stamina < s0, "logic: sprint drains stamina")
	for i in 10:  # inside the regen delay window (0.8 s)
		l.update(DT, F, true, true)
	ctx.check(l.stamina < data.sprint_min
			and l.state == _STATE.State.WALK,
			"logic: exhausted sprinter falls back to WALK")

	# --- Stamina regenerates only after the post-use delay ---
	l.reset()
	l.update(DT, F, true, true)  # one sprint tick sets the regen delay
	l.stamina = 0.0
	l.update(DT, Vector3.ZERO, false, true)
	ctx.check(l.stamina <= 0.001, "logic: no regen during the post-use delay")
	for i in int(data.stamina_regen_delay / DT) + 10:
		l.update(DT, Vector3.ZERO, false, true)
	ctx.check(l.stamina > 1.0, "logic: regen after the delay")

	# --- Dodge: i-frame window [start, end] of the dodge duration ---
	l.reset()
	ctx.check(l.start_dodge(F), "logic: dodge starts")
	ctx.check(l.state == _STATE.State.DODGE, "logic: state = DODGE")
	l.update(DT, Vector3.ZERO, false, true)  # t ≈ 17 ms
	ctx.check(not l.is_invulnerable(), "logic: t=17ms — outside i-frames")
	l.update(DT, Vector3.ZERO, false, true)  # t ≈ 33 ms
	ctx.check(not l.is_invulnerable(), "logic: t=33ms — outside i-frames")
	l.update(DT, Vector3.ZERO, false, true)  # t ≈ 50 ms
	l.update(DT, Vector3.ZERO, false, true)  # t ≈ 67 ms
	ctx.check(l.is_invulnerable(), "logic: t=67ms — inside i-frames")
	for i in int((0.23 - 0.067) / DT):  # t ≈ 233 ms (< 250 end)
		l.update(DT, Vector3.ZERO, false, true)
	ctx.check(l.is_invulnerable(), "logic: t≈233ms — still in i-frames")
	for i in 3:  # t > 283 ms (> 250 end)
		l.update(DT, Vector3.ZERO, false, true)
	ctx.check(not l.is_invulnerable(), "logic: after iframe end — vulnerable")
	var vd: Vector3 = l.update(DT, Vector3.ZERO, false, true)
	ctx.check(absf(vd.length() - data.dodge_speed) < 0.01
			and vd.normalized().is_equal_approx(F),
			"logic: dodge speed/direction locked")

	# --- Dodge ends; cooldown blocks an immediate re-dodge ---
	var ticks: int = 0
	while l.state == _STATE.State.DODGE and ticks < 60:
		l.update(DT, Vector3.ZERO, false, true)
		ticks += 1
	ctx.check(l.state == _STATE.State.IDLE,
			"logic: dodge ends -> IDLE")
	ctx.check(not l.start_dodge(F), "logic: re-dodge blocked by cooldown")
	for i in 30:  # 0.5 s > 0.4 s cooldown
		l.update(DT, Vector3.ZERO, false, true)
	var s2: float = l.stamina
	ctx.check(l.start_dodge(F), "logic: dodge allowed after cooldown")
	ctx.check(absf(l.stamina - (s2 - data.dodge_stamina_cost)) < 0.01,
			"logic: dodge cost applied")

	# --- Dodge from ~zero input uses facing ---
	l.reset()
	l.facing = Vector3(1.0, 0.0, 0.0)
	l.start_dodge(Vector3.ZERO)
	var vf: Vector3 = l.update(DT, Vector3.ZERO, false, true)
	ctx.check(vf.normalized().is_equal_approx(Vector3(1.0, 0.0, 0.0)),
			"logic: zero-input dodge goes along facing")

	# --- Dodge blocked without stamina ---
	l.reset()
	l.stamina = 1.0
	ctx.check(not l.start_dodge(F), "logic: no dodge below the cost")

	# --- Hurt: hitstun, knockback decay, no control, recovery ---
	l.reset()
	l.apply_hurt(Vector3(0.0, 0.0, 1.0))
	ctx.check(l.state == _STATE.State.HURT, "logic: hurt state")
	var vk: Vector3 = l.update(DT, F, true, true)
	ctx.check(vk.z > 4.0 and vk.y > 2.5,
			"logic: knockback velocity during hurt (%s)" % vk)
	ctx.check(not l.start_dodge(F), "logic: no dodge while hurt")
	var v1: float = l.update(DT, Vector3.ZERO, false, true).length()
	var v2: float = l.update(DT, Vector3.ZERO, false, true).length()
	ctx.check(v2 <= v1 + 0.001, "logic: knockback decays")
	for i in int(data.hurt_duration / DT) + 5:
		l.update(DT, Vector3.ZERO, false, true)
	ctx.check(l.state != _STATE.State.HURT,
			"logic: recovers after hurt duration")
	var after: Vector3 = l.update(DT, F, false, true)
	ctx.check(after.length() < data.walk_speed,
			"logic: no leftover speed after hurt (accel from 0)")

	# --- Facing turns toward input ---
	l.reset()
	l.facing = Vector3(0.0, 0.0, -1.0)
	for i in 60:
		l.update(DT, Vector3(1.0, 0.0, 0.0), false, true)
	ctx.check(l.facing.x > 0.9,
			"logic: facing turns toward input (x=%.3f)" % l.facing.x)
