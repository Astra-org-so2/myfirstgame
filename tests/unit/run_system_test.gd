# Unit: Phase 8 run system core (TECHNICAL_DESIGN §2/§3,
# WORLD_STATE_DESIGN §1): RunEvent roundtrip + clamps, RunRecorder
# (4096 cap, attack sampling ring, truncation, JSON), RunRecord/
# RunSummary/RunHistory (roundtrip, 5 MB cap → oldest full run becomes
# a summary), RunManager (derived per-run seed, state machine,
# "what changed" diff).
extends Node

const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _REC = preload("res://scripts/gameplay/run/run_recorder.gd")
const _RR = preload("res://scripts/gameplay/run/run_record.gd")
const _RS = preload("res://scripts/gameplay/run/run_summary.gd")
const _RH = preload("res://scripts/gameplay/run/run_history.gd")
const _RM = preload("res://scripts/gameplay/run/run_manager.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")

var _lines_holder: Dictionary = {}


func run(ctx: Variant) -> void:
	_event(ctx)
	_recorder(ctx)
	_record(ctx)
	_history(ctx)
	_manager(ctx)


# --- RunEvent ----------------------------------------------------------

func _event(ctx: Variant) -> void:
	var e := _EV.new()
	e.t = 1234
	e.type = 3
	e.room = 7
	e.x = -40000  # over the int16-cm bound → must clamp to -32700
	e.y = 5
	e.z = 40000   # over the bound → must clamp to 32700
	e.ry = 720
	e.target = 99999
	e.data = 300
	var a: Array = e.to_array()
	ctx.check(a.size() == 9, "event: JSON row has 9 fields")
	var back: Variant = _EV.new()
	ctx.check(back.load_array(a), "event: load_array accepts a 9-field row")
	ctx.check(back.t == 1234 and back.type == 3 and back.room == 7,
			"event: roundtrip scalar fields")
	ctx.check(back.x == -32700 and back.z == 32700,
			"event: coords clamped to int16 cm (±32700)")
	ctx.check(back.ry == 0 and back.target == 65535 and back.data == 255,
			"event: ry wrapped to 0..359, target/data clamped")
	var bad: Variant = _EV.new()
	ctx.check(not bad.load_array([1, 2, 3]),
			"event: malformed row rejected (flag, not crash)")
	var name: String = _EV.type_name(11)
	ctx.check(name == "PLAYER_DIED", "event: type_name resolves known types")
	ctx.check(_EV.clamp_deg(380) == 20, "event: clamp_deg wraps 380→20")
	ctx.check(_EV.clamp_deg(-90) == 270, "event: clamp_deg wraps -90→270")


# --- RunRecorder -------------------------------------------------------

func _recorder(ctx: Variant) -> void:
	# Basic recording.
	var r := _REC.new()
	var e1: Variant = r.record(10, 12, 0, Vector3(1.5, 0.0, -2.0), 45, 0)
	var e2: Variant = r.record(20, 0, 3, Vector3(0.1, 0.0, 0.2), 90, 0)
	ctx.check(e1 != null and e2 != null, "recorder: events kept under cap")
	ctx.check(r.events.size() == 2, "recorder: two events stored")
	ctx.check(r.events[0].x == 150 and r.events[0].z == -200,
			"recorder: meters → cm conversion")
	ctx.check(r.events[1].room == 3, "recorder: room index stored")

	# The 4096 cap with attacks → sampling ring.
	var s := _REC.new()
	var fill_types: Array = [0, 1, 3, 5]  # ENTER/ATTACK/KILLED/PICKED
	for i in _REC.MAX_EVENTS:
		s.record(i * 10, int(fill_types[i % 4]), 0,
				Vector3(1.0, 0.0, 1.0), 0, 0)
	ctx.check(s.events.size() == _REC.MAX_EVENTS,
			"recorder: exactly 4096 events kept")
	ctx.check(not s.sampling_attacks and s.attack_count() == 1024,
			"recorder: no sampling at the cap, 1024 attacks in base fill")
	# 100 plain events → ring overwrites (sampling mode from here).
	var plain: Variant = s.record(100000, 0, 0, Vector3(0.0, 0.0, 0.0), 0, 0)
	for i in 99:
		s.record(100000 + (i + 1) * 10, 0, 0,
				Vector3(0.0, 0.0, 0.0), 0, 0)
	ctx.check(plain != null, "recorder: plain event kept at the cap (ring)")
	ctx.check(s.sampling_attacks,
			"recorder: sampling flag set once the cap is passed w/ attacks")
	ctx.check(s.events.size() == _REC.MAX_EVENTS,
			"recorder: ring keeps size pinned at 4096")
	# 20 attacks: every 2nd of the overflow is sampled away (10 kept).
	for i in 20:
		s.record(200000 + i * 10, 1, 0, Vector3(0.0, 0.0, 0.0), 0, 0)
	ctx.check(s.events.size() == _REC.MAX_EVENTS,
			"recorder: size still pinned during attack sampling")
	ctx.check(s.dropped_count == 10,
			"recorder: 10 of 20 overflow attacks sampled away")
	# JSON order: oldest first. Oldest = base slot 110 (t = 1100, type 3
	# — KILLED), newest = the last kept overflow attack (t = 200180).
	var rows: Array = s.to_json_array()
	ctx.check(rows.size() == _REC.MAX_EVENTS,
			"recorder: JSON row count pinned at 4096")
	ctx.check(int(rows[0][0]) == 1100 and int(rows[0][1]) == 3,
			"recorder: JSON[0] is the oldest surviving event")
	ctx.check(int(rows.back()[0]) == 200180 and int(rows.back()[1]) == 1,
			"recorder: JSON last is the newest kept event")

	# Truncation path: no attacks at all → the log stops growing.
	var t := _REC.new()
	for i in _REC.MAX_EVENTS:
		t.record(i * 10, 0, 0, Vector3(0.0, 0.0, 0.0), 0, 0)
	var ev_extra: Variant = t.record(99999, 5, 0, Vector3(0.0, 0.0, 0.0), 0, 0)
	ctx.check(ev_extra == null and t.truncated,
			"recorder: overflow without attacks truncates (flag set)")
	var ev_next: Variant = t.record(100000, 0, 0, Vector3(0.0, 0.0, 0.0), 0, 0)
	ctx.check(ev_next == null and t.events.size() == _REC.MAX_EVENTS,
			"recorder: truncated log stays frozen at 4096")

	# JSON roundtrip (small recorder, no ring).
	var j: Array = r.to_json_array()
	var back := _REC.new()
	back.load_json_array(j)
	ctx.check(back.events.size() == r.events.size(),
			"recorder: JSON roundtrip event count")
	var same: bool = true
	for i in r.events.size():
		var a1: Array = r.events[i].to_array()
		var a2: Array = back.events[i].to_array()
		if a1 != a2:
			same = false
			break
	ctx.check(same, "recorder: JSON roundtrip field-identical")
	# JSON roundtrip of the full ring recorder: field-identical too.
	var sj: Array = s.to_json_array()
	var sback := _REC.new()
	sback.load_json_array(sj)
	ctx.check(sback.to_json_array() == sj,
			"recorder: full-ring JSON roundtrip identical")


# --- RunRecord ----------------------------------------------------------

func _record(ctx: Variant) -> void:
	var rec := _RR.new()
	rec.run_id = 3
	rec.seed = 987654321
	rec.start_t = 1000
	rec.fled = true
	var ev := _EV.new()
	ev.t = 5
	ev.type = 3
	ev.room = 2
	rec.events.append(ev)
	rec.add_kills(2)
	rec.add_items(1)
	rec.finish_run(false, 60000, &"hollow", Vector3(1.0, 0.5, -2.0))
	ctx.check(rec.deaths == 1 and rec.playtime_ms == 59000,
			"record: finish_run sets deaths + playtime")
	ctx.check(rec.last_death_pos == Vector3(1.0, 0.5, -2.0),
			"record: last_death_pos stored")
	var d: Dictionary = rec.to_dict()
	var back: Variant = _RR.new()
	back.load_dict(d)
	ctx.check(back.run_id == 3 and back.seed == 987654321,
			"record: dict roundtrip id/seed")
	ctx.check(back.events.size() == 1 and back.events[0].room == 2,
			"record: dict roundtrip events")
	ctx.check(back.kills == 2 and back.deaths == 1 and back.fled,
			"record: dict roundtrip summary counters")
	ctx.check(back.last_death_pos == rec.last_death_pos,
			"record: dict roundtrip death pos")
	ctx.check(back.death_cause == &"hollow", "record: dict roundtrip cause")


# --- RunSummary / RunHistory --------------------------------------------

func _big_run(id: int):
	# A full-cap run (~110 KB in JSON): 4096 events, big coords.
	var rec := _RR.new()
	rec.run_id = id
	rec.seed = 1000 + id
	rec.start_t = 0
	for k in _REC.MAX_EVENTS:
		var ev := _EV.new()
		ev.t = k
		ev.type = 3
		ev.room = 1
		ev.x = 12345
		ev.z = -12345
		rec.events.append(ev)
	rec.finish_run(false, 1000, &"hollow", Vector3.ZERO)
	return rec


func _history(ctx: Variant) -> void:
	var h := _RH.new()
	# Summary projection.
	var rec := _RR.new()
	rec.run_id = 1
	rec.seed = 42
	rec.start_t = 0
	var types: Array = [3, 5, 9, 11]  # killed, picked, completed, died
	for i in 40:
		var ev := _EV.new()
		ev.t = i * 10
		ev.type = int(types[i % 4])
		ev.room = (i % 5) + 1
		rec.events.append(ev)
	rec.finish_run(false, 400000, &"mimic", Vector3(3.0, 0.0, 4.0))
	var s: Variant = _RS.new()
	s.init_from_record(rec)
	ctx.check(s.run_id == 1 and s.seed == 42, "summary: id/seed copied")
	ctx.check(s.duration_ms == 400000, "summary: duration from playtime")
	ctx.check(s.rooms_visited.size() == 5,
			"summary: distinct rooms visited (5)")
	ctx.check(s.major_events.size() > 0 and s.major_events.size() <= 16,
			"summary: major events capped at 16, some kept")
	var only_major: bool = true
	for m in s.major_events:
		var mt: int = int(m["type"])
		if mt == 0 or mt == 1:
			only_major = false
	ctx.check(only_major, "summary: majors exclude ENTER/ATTACK noise")

	# History add + roundtrip.
	h.add_run(rec)
	var rec2 := _RR.new()
	rec2.run_id = 2
	rec2.seed = 43
	rec2.finish_run(true, 1000, &"", Vector3.ZERO)
	h.add_run(rec2)
	ctx.check(h.latest().run_id == 2, "history: latest() is newest")
	ctx.check(h.get_run(1) != null and h.get_run(99) == null,
			"history: get_run by id, null for unknown")
	var backh: Variant = _RH.new()
	ctx.check(backh.load_json(h.to_json()),
			"history: load_json accepts its own JSON")
	ctx.check(backh.to_dict() == h.to_dict(),
			"history: JSON roundtrip dict-identical")

	# 5 MB cap: full-cap runs are ~110 KB each, so ~46 blow the budget;
	# the history must reduce the OLDEST full run to a summary and stay
	# under the cap.
	var added: int = 0
	while h.summaries.is_empty() and added < 80:
		h.add_run(_big_run(10 + added))
		added += 1
	ctx.check(added < 80, "history: cap reduction fired before 80 runs")
	ctx.check(h.summaries.size() >= 1,
			"history: oldest full run reduced to a summary on cap")
	ctx.check(h.section_bytes() <= _RH.MAX_SECTION_BYTES,
			"history: section stays under the 5 MB cap")
	ctx.check(h.full.size() >= 1,
			"history: the newest full runs survive the reduction")
	# The first reduction is the oldest full run — rec (id 1).
	var sum_ids: Array = []
	for sm in h.summaries:
		sum_ids.append(sm.run_id)
	ctx.check(sum_ids.has(1),
			"history: the reduced summary keeps its run id (oldest)")


# --- RunManager ----------------------------------------------------------

func _on_changed(lines: Array) -> void:
	_lines_holder["lines"] = lines


func _manager(ctx: Variant) -> void:
	var ws := _WS.new()
	# Flags set BEFORE the session: part of the starting snapshot.
	ws.set_flag(&"pillar_seen")
	ws.set_flag(&"blade_found")
	var lines: Dictionary = {
		&"pillar_seen": "The pillar is warm to the touch.",
		&"blade_found": "Your hands remember the blade.",
		&"mine_note_read": "A note is pinned at the mine gate.",
	}
	# The lines table is composed BEFORE the session (production
	# order, main_scene._setup_zones): the starting flag snapshot is
	# taken against it.
	var rm: Variant = _RM.new()
	add_child(rm)
	rm.flag_lines = lines
	rm.init_session(20260917, ws)
	ctx.check(rm.run_id == 1, "manager: session starts at run 1")
	var seed1: int = rm.run_seed
	var seed2: int = _RM.derive_seed(20260917, 2)
	ctx.check(seed1 != seed2 and seed1 != 0,
			"manager: per-run seed differs per run, nonzero")
	ctx.check(seed1 == _RM.derive_seed(20260917, 1),
			"manager: seed derivation is deterministic")
	ctx.check(rm.state == _RM.State.PLAYING, "manager: starts PLAYING")
	ctx.check(rm.current_record != null
			and rm.current_record.run_id == 1,
			"manager: first run record exists")
	var spawn: Variant = rm.record_event(0, 0, Vector3.ZERO, 0, 0)
	ctx.check(spawn != null, "manager: events recorded while PLAYING")

	# "What changed": the pre-run flags are NOT in the diff.
	ctx.check(rm.changed_lines(lines).is_empty(),
			"manager: no changed lines when nothing changed mid-run")
	ws.set_flag(&"mine_note_read")
	var new_lines: Array = rm.changed_lines(lines)
	ctx.check(new_lines.size() == 1
			and new_lines[0] == "A note is pinned at the mine gate.",
			"manager: changed line appears for the new flag")

	# Death: state DEAD, door flag set, run in history, lines emitted.
	rm.changed_lines_ready.connect(_on_changed)
	rm.on_player_died(Vector3(5.0, 0.0, 5.0), &"hollow")
	ctx.check(rm.state == _RM.State.DEAD, "manager: death → DEAD")
	ctx.check(ws.flag(&"run_02_door_open"),
			"manager: first death sets run_02_door_open (A19)")
	ctx.check(ws.flag(&"first_death_done"),
			"manager: first_death_done set")
	var latest: Variant = ws.runs.latest()
	ctx.check(latest != null and latest.run_id == 1
			and latest.deaths == 1,
			"manager: finished run stored in world_state.runs")
	var died: Variant = rm.current_record.events.back()
	ctx.check(died.type == 11, "manager: PLAYER_DIED is the last event")
	ctx.check(rm.last_death_pos() == Vector3(5.0, 0.0, 5.0),
			"manager: last_death_pos exposed")

	# A second death must not double-count the run.
	var runs_before: int = ws.runs.full.size()
	rm.on_player_died(Vector3(1.0, 0.0, 1.0), &"mimic")
	ctx.check(ws.runs.full.size() == runs_before,
			"manager: double death ignored")

	# Respawn → run 2 with a new seed.
	var new_seed: int = rm.begin_next_run()
	ctx.check(rm.run_id == 2 and new_seed == _RM.derive_seed(20260917, 2),
			"manager: begin_next_run → run 2 with derived seed")
	# The "what changed" lines are emitted at the RESPAWN (design
	# §9.2), carrying the flag set during the run that ended.
	var out: Array = _lines_holder.get("lines", [])
	ctx.check(out.size() == 1
			and out[0] == "A note is pinned at the mine gate.",
			"manager: changed_lines_ready emitted at the respawn")
	ctx.check(rm.state == _RM.State.PLAYING,
			"manager: back to PLAYING after respawn")
	ctx.check(rm.current_record.run_id == 2,
			"manager: new run record for run 2")
	# Time advances only while PLAYING.
	rm.advance_time(1.5)
	ctx.check(rm.time_decis() == 15, "manager: deciseconds accumulate")
	rm.state = _RM.State.DEAD
	rm.advance_time(1.0)
	ctx.check(rm.time_decis() == 15, "manager: time frozen when not PLAYING")
	rm.queue_free()
