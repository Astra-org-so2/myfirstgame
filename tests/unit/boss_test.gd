# Unit: Phase 12 boss — THE FIRST (BOSS_DESIGN §3): the data
# (schema + the design values), the pattern memory (learn / parry /
# break — the core mechanic), the boss FSM (telegraphs, the core
# window 2/4 s, the 60% phase shift, the death sequence K6), and the
# event-based boss door (ADR-019: the three conditions, once open
# always open).
extends Node

const _BD = preload("res://scripts/gameplay/boss/boss_data.gd")
const _PM = preload("res://scripts/gameplay/boss/pattern_memory.gd")
const _BL = preload("res://scripts/gameplay/boss/boss_logic.gd")
const _BS = preload("res://scripts/gameplay/boss/boss_sense.gd")
const _BG = preload("res://scripts/gameplay/boss/boss_gate.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")


func run(ctx: Variant) -> void:
	_test_data(ctx)
	_test_pattern_memory(ctx)
	_test_fsm(ctx)
	_test_core_window(ctx)
	_test_death(ctx)
	_test_gate(ctx)


func _data() -> _BD:
	return load("res://data/boss_the_first.tres")


# --- the data (the design values, the schema) ---------------------------

func _test_data(ctx: Variant) -> void:
	var d: _BD = _data()
	ctx.check(d != null, "boss: data/boss_the_first.tres loads")
	if d == null:
		return
	var problems: Array = d.validate()
	ctx.check(problems.is_empty(),
			"boss: the data validates (%s)" % str(problems))
	ctx.check(d.health == 600, "boss: hp 600 (Q-B1: 5-8 min)")
	ctx.check(d.melee != null and d.slam != null,
			"boss: two attacks (melee + slam)")
	ctx.check(d.melee.windup == 0.5 and d.slam.windup == 0.8,
			"boss: telegraphs 0.5/0.8 s (GDD §6.2 fairness)")
	ctx.check(d.melee.damage == 20 and d.slam.damage == 35,
			"boss: dmg 20/35")
	ctx.check(d.core_window == 2.0 and d.core_window_blade == 4.0,
			"boss: core window 2/4 s (FIRST BLADE extends)")
	ctx.check(d.core_damage == 50 and d.core_damage_plain == 30,
			"boss: core dmg 50 (blade) / 30 (plain)")
	ctx.check(d.pattern_length == 3 and d.pattern_threshold == 3,
			"boss: pattern memory 3/3")
	ctx.check(d.parry_window == 0.4 and d.parry_damage == 25,
			"boss: parry 0.4 s / 25 dmg")
	ctx.check(d.break_steps == 3 and d.break_stun == 1.5,
			"boss: break 3 steps / stun 1.5 s")
	ctx.check(d.phase2_threshold == 0.6,
			"boss: phase 2 at 60%")
	ctx.check(d.minion_health == 80 and d.minion_damage == 15
			and d.minion_fade_pct == 50.0,
			"boss: minion 80/15, leaves at 50%")
	ctx.check(d.dissolve_time == 3.0 and d.final_line_delay == 2.0,
			"boss: death sequence 3 s dissolve + 2 s silence")


# --- the pattern memory (the core mechanic) ------------------------------

func _pm() -> _PM:
	var pm: _PM = _PM.new()
	pm.setup(3, 3, 3)
	return pm


func _test_pattern_memory(ctx: Variant) -> void:
	# Learn: the SAME 3-step sequence, 3 back-to-back times.
	var pm: _PM = _pm()
	var ev: int = _PM.Event.NONE
	for r in 3:
		for st in ["a", "b", "c"]:
			ev = pm.record(st)
	ctx.check(ev == _PM.Event.LEARNED,
			"boss_pm: abc×3 is learned (the 3rd repetition)")
	ctx.check(pm.learned == PackedStringArray(["a", "b", "c"]),
			"boss_pm: the learned sequence is abc")
	ctx.check(pm.parry_armed, "boss_pm: the parry is armed after learn")
	# The next completion of the sequence = the PARRY.
	for st in ["a", "b", "c"]:
		ev = pm.record(st)
	ctx.check(ev == _PM.Event.PARRY_TRIGGER,
			"boss_pm: the 4th completion is parried")
	ctx.check(not pm.parry_armed, "boss_pm: the parry is consumed")
	# And it arms again on the next learn (the pattern keeps working).
	pm = _pm()
	var first: int = 0
	var parries: int = 0
	for r in 8:
		first = pm.record("a")
		first = pm.record("b")
		first = pm.record("c")
		if first == _PM.Event.PARRY_TRIGGER:
			parries += 1
	ctx.check(parries >= 1,
			"boss_pm: repeating forever gets parried (%d)" % parries)
	# The break: 3 "not his" steps -> he loses the rhythm.
	pm = _pm()
	for st in ["a", "b", "c", "a", "b", "c", "a", "b", "c"]:
		pm.record(st)  # learned
	var broken: int = _PM.Event.NONE
	for st in ["x", "y", "z"]:
		broken = pm.record(st)
	ctx.check(broken == _PM.Event.BROKEN,
			"boss_pm: 3 off-steps break the pattern")
	ctx.check(pm.learned.is_empty(),
			"boss_pm: after the break he has it no more")
	# Two off-steps + a pattern step = NOT broken (the design: 3).
	pm = _pm()
	for st in ["a", "b", "c", "a", "b", "c", "a", "b", "c"]:
		pm.record(st)
	broken = pm.record("x")
	broken = pm.record("y")
	broken = pm.record("a")  # starts the sequence again
	ctx.check(broken == _PM.Event.NONE and not pm.learned.is_empty(),
			"boss_pm: 2 off-steps + a pattern step keeps it")
	# A different sequence cannot be learned (only back-to-back
	# repeats count).
	pm = _pm()
	var learned_any: bool = false
	var ev2: int = 0
	for st in ["a", "b", "c", "a", "b", "d"]:
		ev2 = pm.record(st)
		learned_any = ev2 == _PM.Event.LEARNED
	ctx.check(not learned_any,
			"boss_pm: an interrupted sequence is not learned")


# --- the FSM (telegraphs, attacks, the phase shift) ----------------------

func _logic() -> _BL:
	var bl: _BL = _BL.new()
	bl.setup(_data())
	return bl


func _sense_at(d: float) -> _BS:
	var s: _BS = _BS.new()
	s.player_present = true
	s.player_pos = Vector2(d, 0.0)
	return s


func _tick_n(bl: _BL, n: int, s: _BS, home: Vector2) -> Array:
	var all: Array = []
	for i in n:
		for e in bl.tick(1.0 / 60.0, s, home):
			all.append(e)
	return all


func _test_fsm(ctx: Variant) -> void:
	var bl: _BL = _logic()
	var home: Vector2 = Vector2.ZERO
	# Melee: the player in range -> telegraph 0.5 s -> the swing.
	var evs: Array = _tick_n(bl, 31, _sense_at(2.0), home)
	ctx.check(evs.has("attack_melee"),
			"boss_fsm: the melee telegraph lands the swing")
	# After the recovery the cd holds the next melee (1.2 s floor).
	var after: int = 0
	for i in 30:
		after += 1
		if bl.state == _BL.State.TELE_MELEE:
			break
	ctx.check(after >= 20,
			"boss_fsm: the melee cd is not spam (waited %d ticks)"
					% after)
	# Slam: forced (the test seam) -> the 0.8 s telegraph.
	bl.force_next_slam(true)
	evs = []
	for i in 60:
		for e in bl.tick(1.0 / 60.0, _sense_at(3.0), home):
			evs.append(e)
		if bl.state == _BL.State.CORE_WINDOW:
			break
	ctx.check(evs.has("attack_slam"),
			"boss_fsm: the slam telegraph (0.8 s) lands")
	# The phase shift at 60%: hp 600 -> 360.
	bl = _logic()
	bl.set_hp(360.0)
	ctx.check(bl.state == _BL.State.PHASE_SHIFT,
			"boss_fsm: 60% hp enters the phase shift")
	evs = _tick_n(bl, 90, _sense_at(9.0), home)
	ctx.check(bl.phase() == 2,
			"boss_fsm: after the shift he is phase 2")
	# No attacks while the player is out of the arena band.
	bl = _logic()
	evs = _tick_n(bl, 120, _sense_at(12.0), home)
	ctx.check(not evs.has("attack_melee") and not evs.has("attack_slam"),
			"boss_fsm: no attacks out of range")
	# The break stun: vulnerable, no attacks.
	bl = _logic()
	bl.apply_break_stun()
	ctx.check(bl.stunned(), "boss_fsm: the break stuns him")
	evs = _tick_n(bl, 60, _sense_at(1.0), home)
	ctx.check(not evs.has("attack_melee") and not evs.has("attack_slam"),
			"boss_fsm: no attacks during the stun")
	# The parry window: active, then the counter once.
	bl = _logic()
	bl.enter_parry()
	ctx.check(bl.parry_active(), "boss_fsm: the parry is active")
	ctx.check(bl.parry_swing(), "boss_fsm: the swing inside triggers")
	ctx.check(not bl.parry_swing(),
			"boss_fsm: the counter lands only once")
	ctx.check(bl.state == _BL.State.PARRY and bl.parry_active(),
			"boss_fsm: the block holds through the window")
	_tick_n(bl, 30, _sense_at(9.0), home)  # 0.5 s > the 0.4 s window
	ctx.check(bl.state == _BL.State.IDLE,
			"boss_fsm: after the window he is free")


# --- the core window (2/4 s, one hit, the seal) ---------------------------

func _test_core_window(ctx: Variant) -> void:
	var home: Vector2 = Vector2.ZERO
	# Base window: 2 s.
	var bl: _BL = _logic()
	bl.force_next_slam(true)
	var in_window: int = 0
	var opened: bool = false
	for i in 240:
		for e in bl.tick(1.0 / 60.0, _sense_at(3.0), home):
			if e == "core_window_open":
				opened = true
		if bl.core_window_active():
			in_window += 1
		if i > 60 and not bl.core_window_active() and opened:
			break
	ctx.check(opened, "boss_core: the slam opens the window")
	ctx.check(in_window > 110 and in_window < 140,
			"boss_core: the base window is ~2 s (%d ticks)" % in_window)
	# The FIRST BLADE extends it to 4 s.
	bl = _logic()
	bl.set_blade(true)
	bl.force_next_slam(true)
	in_window = 0
	opened = false
	for i in 400:
		for e in bl.tick(1.0 / 60.0, _sense_at(3.0), home):
			if e == "core_window_open":
				opened = true
		if bl.core_window_active():
			in_window += 1
		if i > 60 and not bl.core_window_active() and opened:
			break
	ctx.check(in_window > 230 and in_window < 260,
			"boss_core: the blade extends the window to ~4 s (%d)"
					% in_window)
	# A core hit closes the window (one shot).
	bl = _logic()
	bl.force_next_slam(true)
	for i in 240:
		for _e in bl.tick(1.0 / 60.0, _sense_at(3.0), home):
			pass
		if bl.core_window_active():
			break
	ctx.check(bl.core_hit(), "boss_core: the hit lands in the window")
	ctx.check(not bl.core_hit(),
			"boss_core: the window is one-shot")


# --- the death sequence (K6: #9 -> dissolve -> #10 -> defeated) ----------

func _test_death(ctx: Variant) -> void:
	var bl: _BL = _logic()
	var home: Vector2 = Vector2.ZERO
	var s: _BS = _sense_at(9.0)
	var evs: Array = []
	bl.set_hp(0.0)
	ctx.check(bl.state == _BL.State.DEATH_DISSOLVE,
			"boss_death: hp 0 enters the dissolve")
	for i in 300:
		for e in bl.tick(1.0 / 60.0, s, home):
			evs.append(e)
		if bl.is_defeated_done():
			break
	ctx.check(evs.has("death_final"),
			"boss_death: the final line after the dissolve")
	ctx.check(evs.has("defeated"),
			"boss_death: the sequence ends with defeated")
	# No attacks after death (he is gone).
	evs = _tick_n(bl, 60, _sense_at(1.0), home)
	ctx.check(not evs.has("attack_melee") and not evs.has("attack_slam"),
			"boss_death: no attacks after the defeat")


# --- the boss door (ADR-019: the event-based condition) -------------------

func _test_gate(ctx: Variant) -> void:
	var gate: _BG = _BG.new()
	var ws: _WS = _WS.new()
	# Nothing: closed.
	ctx.check(not gate.should_open(ws, 0),
			"boss_gate: fresh world, the door is shut")
	# Two of three: still shut (each condition is load-bearing).
	ws.set_flag(_BG.MINE_EXPLORED)
	ws.set_flag(_BG.TRACES_SEEN)
	ctx.check(not gate.should_open(ws, 2),
			"boss_gate: 2 deaths < 3, shut")
	# All three: open (and the flag is the interface).
	ctx.check(gate.should_open(ws, 3),
			"boss_gate: mine3 + 3 deaths + traces = open")
	ws.set_flag(_BG.DOOR_OPEN)
	ws.set_flag(_BG.MINE_EXPLORED, false)  # the world remembers:
	# once open, the flag keeps it open.
	ctx.check(gate.should_open(ws, 0),
			"boss_gate: once open, always open (the flag)")
