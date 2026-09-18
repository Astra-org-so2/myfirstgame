# Unit: Phase 9 echo system — the budget (ADR-014) and the ghost
# replay core (TECHNICAL_DESIGN §5): timeline build, the old-layout
# -> new-layout remap (room id match, origin delta, the missing-room
# rewind), Catmull-Rom interpolation + the facing wrap, the action
# lookup.
extends Node

const _TL = preload("res://scripts/gameplay/echo/ghost_timeline.gd")
const _KF = preload("res://scripts/gameplay/echo/ghost_keyframe.gd")
const _BUDGET = preload("res://scripts/gameplay/echo/echo_budget_data.gd")
const _BSTATE = preload("res://scripts/gameplay/echo/echo_budget_state.gd")
const _REC = preload("res://scripts/gameplay/run/run_record.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")


func run(ctx: Variant) -> void:
	_budget(ctx)
	_budget_state(ctx)
	_timeline_build(ctx)
	_timeline_remap(ctx)
	_timeline_sample(ctx)
	_timeline_action(ctx)


# --- EchoBudgetData -------------------------------------------------------

func _budget(ctx: Variant) -> void:
	var b: _BUDGET = load("res://data/echo/echo_budget.tres")
	ctx.check(b != null, "echo: the budget data loads")
	if b == null:
		return
	# RUN 1: 0 echoes («нет прошлого»).
	ctx.check(b.passive(1) == 0 and b.combat(1) == 0
			and b.special(1) == 0,
			"echo: RUN 1 has no echoes (budget)")
	# RUN 02/03: 1 Passive + 1 Combat.
	ctx.check(b.passive(2) == 1 and b.combat(2) == 1
			and b.special(2) == 0, "echo: RUN 02 = 1 Passive + 1 Combat")
	ctx.check(b.passive(3) == 1 and b.combat(3) == 1,
			"echo: RUN 03 keeps the 2-echo budget")
	# RUN 04+: the full MVP budget (3).
	ctx.check(b.passive(4) == 1 and b.combat(4) == 1
			and b.special(4) == 1,
			"echo: RUN 04+ = 1 + 1 + 1 «special»")
	# Far-future runs stay on the last row (the pre-boss arc).
	ctx.check(b.passive(40) == 1 and b.special(40) == 1,
			"echo: the budget plateaus on the last pre-boss row")


func _budget_state(ctx: Variant) -> void:
	var s: _BSTATE = _BSTATE.new()
	s.init_run(2, 1, 1, 0)
	ctx.check(s.combat_remaining() == 1, "budget_state: combat armed")
	s.use_combat()
	ctx.check(s.combat_remaining() == 0, "budget_state: the slot is used")
	s.use_combat()
	ctx.check(s.combat_remaining() == 0,
			"budget_state: the budget never goes negative")
	s.init_run(1, 0, 0, 0)
	ctx.check(s.combat_remaining() == 0 and s.passive_remaining() == 0,
			"budget_state: RUN 1 is echo-free")


# --- a small two-room layout pair (the remap fixture) ----------------------

func _mk_layout(area_id: StringName, entries: Array) -> _RL:
	# entries: [[room .tres path, Vector3 origin], ...]
	var ap: _AP = _AP.new()
	ap.area = null
	for e in entries:
		var rp: _RP = _RP.new()
		rp.room = load(e[0])
		rp.origin = e[1]
		ap.rooms.append(rp)
	var rl: _RL = _RL.new()
	rl.areas = {area_id: ap}
	return rl


func _events(t_list: Array, x_list: Array) -> Array:
	# [t deciseconds, x meters] rows (RunEvent.t is deciseconds).
	var evs: Array = []
	for i in t_list.size():
		var ev: _EV = _EV.new()
		ev.t = int(t_list[i])
		ev.type = _EV.Type.ENTER_ROOM
		ev.x = int(x_list[i] * 100.0)
		evs.append(ev)
	return evs


func _record(evs: Array) -> _REC:
	var r: _REC = _REC.new()
	r.run_id = 1
	r.events = evs
	return r


# --- GhostTimeline.build ----------------------------------------------------

func _timeline_build(ctx: Variant) -> void:
	var tl: _TL = _TL.new()
	tl.build(null, null, null)
	ctx.check(tl.is_empty(), "timeline: a null record is an empty replay")

	var evs: Array = _events([5, 1, 3], [0.0, 1.0, 2.0])
	tl = _TL.new()
	tl.build(_record(evs), null, null)
	ctx.check(tl.keyframe_count() == 3,
			"timeline: one keyframe per recorded event")
	ctx.check(tl.start_t == 0.1 and absf(tl.duration - 0.4) < 1e-6,
			"timeline: deciseconds -> seconds (start/duration)")
	ctx.check(tl.keyframes[0].pos.x == 1.0,
			"timeline: the keyframes are sorted by time")

	# The same position twice (same decisecond burst) is legal.
	tl = _TL.new()
	tl.build(_record(_events([1, 1, 2], [0.0, 0.0, 1.0])),
			null, null)
	ctx.check(tl.keyframe_count() == 3 and absf(tl.duration - 0.1) < 1e-6,
			"timeline: duplicate timestamps do not break the timeline")


# --- the remap (old layout -> new layout) ----------------------------------

func _timeline_remap(ctx: Variant) -> void:
	var corridor: String = "res://data/rooms/corridor_forest_v0.tres"
	var stairs: String = "res://data/rooms/corridor_stairs_v0.tres"
	var old_lay: _RL = _mk_layout(&"the_mine", [
		[corridor, Vector3(0.0, 0.0, 0.0)],
		[stairs, Vector3(0.0, 0.0, -12.0)],
	])
	# The new run: the corridor moved by (+5, 0, +3); the stairs room
	# is GONE (a different variant was picked).
	var new_lay: _RL = _mk_layout(&"the_mine", [
		[corridor, Vector3(5.0, 0.0, 3.0)],
	])
	# The player walked: the corridor (0 -> 3 m), a point outside any
	# room (the camp ring case: kept as-is), the stairs room (gone).
	var evs: Array = _events([100, 200, 300, 400],
			[0.0, 1.5, 30.0, 0.0])
	# the last one is in the stairs room (x=0 is inside its footprint)
	evs[3].z = int(-12.0 * 100.0)
	var tl: _TL = _TL.new()
	tl.build(_record(evs), old_lay, new_lay)
	ctx.check(tl.dropped == 1,
			"timeline: the missing room drops its keyframes (rewind)")
	var k0: _KF = tl.keyframes[0]
	var k1: _KF = tl.keyframes[1]
	var k2: _KF = tl.keyframes[2]
	ctx.check(k0.pos.is_equal_approx(Vector3(5.0, 0.0, 3.0)),
			"timeline: the corridor point translates by the origin delta")
	ctx.check(k1.pos.is_equal_approx(Vector3(6.5, 0.0, 3.0)),
			"timeline: every point in the room moves with the room")
	ctx.check(k2.pos.is_equal_approx(Vector3(30.0, 0.0, 0.0)),
			"timeline: an outside-room point (camp ring) is kept")
	# The same layout on both sides = identity.
	tl = _TL.new()
	tl.build(_record(_events([100, 200], [1.0, 2.0])), old_lay, old_lay)
	ctx.check(tl.keyframes[0].pos.is_equal_approx(Vector3(1.0, 0.0, 0.0)),
			"timeline: same-layout remap is the identity")


# --- interpolation -----------------------------------------------------------

func _timeline_sample(ctx: Variant) -> void:
	# Collinear keyframes: Catmull-Rom on a straight line is the line.
	var tl := _mk_line([0.0, 1.0, 2.0, 3.0])
	ctx.check(tl.sample(0.0).is_equal_approx(Vector3(0.0, 0.0, 0.0)),
			"timeline: sample clamps to the first keyframe")
	ctx.check(tl.sample(3.0).is_equal_approx(Vector3(3.0, 0.0, 0.0)),
			"timeline: sample clamps to the last keyframe")
	# An interior segment of collinear points is exactly the line.
	ctx.check(absf(tl.sample(1.5).x - 1.5) < 1e-4,
			"timeline: mid-point of a collinear stretch")
	# Endpoint segments use the clamped control point — near-linear.
	ctx.check(tl.sample(0.5).x > 0.3 and tl.sample(0.5).x < 0.7,
			"timeline: the first segment stays on the path")
	# Beyond the duration: stays at the end (no extrapolation).
	ctx.check(tl.sample(10.0).is_equal_approx(Vector3(3.0, 0.0, 0.0)),
			"timeline: past the end the ghost holds the last pose")
	# The facing wraps through 0 deg.
	var tl2: _TL = _TL.new()
	var a: _KF = _KF.new(); a.t = 0.0; a.ry = 350.0
	var b: _KF = _KF.new(); b.t = 1.0; b.ry = 10.0
	tl2.keyframes = [a, b]
	tl2.start_t = 0.0
	tl2.duration = 1.0
	ctx.check(absf(tl2.sample_ry(0.5) - 0.0) < 1.0,
			"timeline: the facing wraps through 0 (350 -> 10)")


func _mk_line(x_list: Array) -> _TL:
	var tl: _TL = _TL.new()
	for i in x_list.size():
		var kf := _KF.new()
		kf.t = float(i)
		kf.pos = Vector3(float(x_list[i]), 0.0, 0.0)
		kf.action = _EV.Type.ENTER_ROOM
		tl.keyframes.append(kf)
	tl.start_t = 0.0
	tl.duration = float(x_list.size() - 1)
	return tl


# --- the action at t (the replayed gesture) ---------------------------------

func _timeline_action(ctx: Variant) -> void:
	var tl: _TL = _TL.new()
	var k1 := _KF.new(); k1.t = 0.0; k1.action = _EV.Type.ENTER_ROOM
	var k2 := _KF.new(); k2.t = 1.0; k2.action = _EV.Type.ATTACK
	var k3 := _KF.new(); k3.t = 2.0; k3.action = _EV.Type.ITEM_PICKED
	tl.keyframes = [k1, k2, k3]
	tl.start_t = 0.0
	tl.duration = 2.0
	ctx.check(tl.action_at(0.5) == _EV.Type.ENTER_ROOM,
			"timeline: the action before the first keyframe")
	ctx.check(tl.action_at(1.5) == _EV.Type.ATTACK,
			"timeline: the replayed swing lands at its moment")
	ctx.check(tl.action_at(5.0) == _EV.Type.ITEM_PICKED,
			"timeline: past the end the last action holds")
