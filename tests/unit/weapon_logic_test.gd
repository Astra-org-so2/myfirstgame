# Unit: WeaponLogic — melee combo + riposte timing (pure, deterministic).
# Driven with a manual clock (rig contract, ADR-022 item 11).
extends Node

const _DATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _LOGIC = preload("res://scripts/gameplay/combat/weapon_logic.gd")

const DT: float = 1.0 / 60.0
const EPS: float = 0.001


func run(ctx: Variant) -> void:
	var data: _DATA = load("res://data/weapons/blade.tres")
	ctx.check(data != null and data is _DATA,
			"weapon_logic: blade data loads")
	if data == null:
		return

	# 1. Swing phase timing: windup 0.25 -> active 0.15 -> recovery 0.8.
	var l: _LOGIC = _LOGIC.new(data)
	ctx.check(l.phase() == _LOGIC.Phase.IDLE, "weapon_logic: starts idle")
	ctx.check(l.request_attack() == 1, "weapon_logic: press starts U1")
	var ev: Array[String] = _tick(l, 16)  # >= 0.25 s
	ctx.check(l.phase() == _LOGIC.Phase.ACTIVE and l.is_active(),
			"weapon_logic: active after windup (0.25 s)")
	ctx.check(ev.is_empty(), "weapon_logic: no events in windup/active")
	ev = _tick(l, 10)  # >= 0.15 s
	ctx.check(l.phase() == _LOGIC.Phase.RECOVERY,
			"weapon_logic: recovery after active (0.4 s total)")
	ev = _tick(l, 50)  # >= 0.8 s
	ctx.check(l.phase() == _LOGIC.Phase.IDLE
			and ev.has(_LOGIC.EV_HIT_ENDED),
			"weapon_logic: swing ends after recovery (1.2 s total)")

	# 2. Buffered full combo: U1 -> U2 -> U3 (indices 0, 1, 2).
	l = _LOGIC.new(data)
	var started: Array[int] = []
	l.request_attack()
	started.append(l.hit_index())
	_tick(l, 10)  # mid windup
	ctx.check(l.request_attack() == 0, "weapon_logic: press buffers mid-swing")
	# U1 ends at 1.2 s -> U2 starts (buffered).
	var buf_ev: Array[String] = _tick(l, 64)
	started.append(l.hit_index())
	ctx.check(buf_ev.has(_LOGIC.EV_HIT_STARTED)
			and l.phase() == _LOGIC.Phase.WINDUP,
			"weapon_logic: buffered U2 starts at U1 end")
	_tick(l, 10)
	l.request_attack()  # buffer U3
	_tick(l, 64)  # U2 ends -> U3 starts
	started.append(l.hit_index())
	ctx.check(l.hit_index() == 2, "weapon_logic: U3 is the third swing")
	var done_ev: Array[String] = _tick(l, 90)  # U3 (1.5 s)
	ctx.check(l.phase() == _LOGIC.Phase.IDLE
			and started == [0, 1, 2],
			"weapon_logic: full combo U1->U2->U3 (started %s)" % str(started))
	ctx.check(done_ev.has(_LOGIC.EV_HIT_ENDED)
			and not done_ev.has(_LOGIC.EV_HIT_STARTED),
			"weapon_logic: combo ends without a fourth swing")

	# 3. Combo window: continue within 0.5 s, restart after.
	l = _LOGIC.new(data)
	l.request_attack()
	_tick(l, 74)  # U1 ends (1.2 s)
	_tick(l, 18)  # 0.3 s idle (inside the 0.5 s window)
	l.request_attack()
	ctx.check(l.hit_index() == 1,
			"weapon_logic: press in window continues at U2")
	_tick(l, 74 + 18)  # U2 ends, 0.3 s idle
	l.request_attack()
	ctx.check(l.hit_index() == 2,
			"weapon_logic: window chains U3")
	_tick(l, 92 + 32)  # U3 ends, 0.55 s idle (window expired)
	l.request_attack()
	ctx.check(l.hit_index() == 0,
			"weapon_logic: press after window restarts at U1")

	# 4. Riposte: window 0.5 s, cooldown 30 s, miss -> event.
	l = _LOGIC.new(data)
	ctx.check(l.request_special(), "weapon_logic: riposte from idle")
	ctx.check(l.phase() == _LOGIC.Phase.RIPOSTE
			and l.is_in_riposte_window(),
			"weapon_logic: riposte window open")
	ctx.check(l.request_attack() == -1,
			"weapon_logic: no swings during riposte window")
	var rip_ev: Array[String] = _tick(l, 31)  # >= 0.5 s
	ctx.check(l.phase() == _LOGIC.Phase.IDLE
			and rip_ev.has(_LOGIC.EV_RIPOSTE_MISSED),
			"weapon_logic: window closes with a miss at 0.5 s")
	ctx.check(l.request_special() == false
			and l.riposte_cd_remaining() > 29.0,
			"weapon_logic: cooldown running after miss (~30 s)")
	_tick(l, 1800)  # 30 s
	ctx.check(l.request_special(), "weapon_logic: riposte ready after CD")

	# 5. Successful counter ends the window early (no miss event).
	l = _LOGIC.new(data)
	l.request_special()
	l.end_riposte()
	ctx.check(l.phase() == _LOGIC.Phase.IDLE,
			"weapon_logic: successful counter ends the window")

	# 6. Riposte cancels a recovery; not allowed mid windup/active.
	l = _LOGIC.new(data)
	l.request_attack()
	_tick(l, 10)
	ctx.check(l.request_special() == false,
			"weapon_logic: no riposte during windup")
	_tick(l, 30)  # tick 40 = 0.67 s: inside U1 recovery (0.4..1.2 s)
	ctx.check(l.phase() == _LOGIC.Phase.RECOVERY,
			"weapon_logic: test is in recovery")
	ctx.check(l.request_special(),
			"weapon_logic: riposte cancels recovery")
	_tick(l, 31)  # window closes (>= 0.5 s)
	ctx.check(l.phase() == _LOGIC.Phase.IDLE,
			"weapon_logic: swing fully cancelled by riposte")

	# 7. cancel_hit (stamina abort): resets the combo.
	l = _LOGIC.new(data)
	l.request_attack()
	l.cancel_hit()
	ctx.check(l.phase() == _LOGIC.Phase.IDLE,
			"weapon_logic: cancel returns to idle")
	l.request_attack()
	_tick(l, 62)  # U1 ends
	l.request_attack()  # fresh press: no window (combo was cancelled)
	ctx.check(l.hit_index() == 0,
			"weapon_logic: cancelled combo does not chain")

	# 8. pending_stamina_cost: 10 on a fresh swing, 0 while swinging.
	l = _LOGIC.new(data)
	ctx.check(l.pending_stamina_cost() == 10,
			"weapon_logic: pending cost 10 before a swing")
	l.request_attack()
	ctx.check(l.pending_stamina_cost() == 0,
			"weapon_logic: pending cost 0 mid-swing")


func _tick(l: _LOGIC, n: int) -> Array[String]:
	var all: Array[String] = []
	for i in n:
		all.append_array(l.update(DT))
	return all
