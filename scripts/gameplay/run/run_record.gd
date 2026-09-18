# RunRecord — one run's entry in world_state.runs[] (WORLD_STATE_DESIGN §1,
# TECHNICAL_DESIGN §3: runs.full[]).
#
# Fields: run_id, start_t/end_t (game ms), alive, seed (the run's layout
# seed — room indices in events are answered against THIS layout),
# events (RunRecorder output), summary (compact counters — the death
# screen and "what changed" read these without walking events).
class_name RunRecord
extends RefCounted

const _EV = preload("res://scripts/gameplay/run/run_event.gd")


var run_id: int = 1
var start_t: int = 0
var end_t: int = 0
var alive: bool = false
var seed: int = 0
var events: Array = []  # Array[RunEvent]
var sampling_attacks: bool = false
var truncated: bool = false
# Summary (WORLD_STATE_DESIGN §1): the compact projection.
var kills: int = 0
var fled: bool = false
var notes_written: int = 0
var items_picked: int = 0
var deaths: int = 0
var playtime_ms: int = 0
var death_cause: StringName = &""
var last_death_pos: Vector3 = Vector3.ZERO


func add_kills(n: int) -> void:
	kills += maxi(0, n)


func add_items(n: int) -> void:
	items_picked += maxi(0, n)


func add_notes(n: int) -> void:
	notes_written += maxi(0, n)


func finish_run(alive_now: bool, end_ms: int, cause: StringName,
		death_pos: Vector3) -> void:
	alive = alive_now
	end_t = maxi(start_t, end_ms)
	playtime_ms = end_t - start_t
	if not alive_now:
		deaths += 1
		death_cause = cause
		last_death_pos = death_pos


# ---- JSON (runs.full entry) -----------------------------------------

func to_dict() -> Dictionary:
	var rows: Array = []
	rows.resize(events.size())
	for i in events.size():
		rows[i] = events[i].to_array()
	return {
		"run_id": run_id, "start_t": start_t, "end_t": end_t,
		"alive": alive, "seed": seed,
		"events": rows, "sampling": sampling_attacks,
		"truncated": truncated, "kills": kills, "fled": fled,
		"notes_written": notes_written, "items_picked": items_picked,
		"deaths": deaths, "playtime_ms": playtime_ms,
		"death_cause": String(death_cause),
		"last_death_pos": [last_death_pos.x, last_death_pos.y,
				last_death_pos.z],
	}


func load_dict(d: Dictionary) -> void:
	run_id = int(d.get("run_id", 1))
	start_t = int(d.get("start_t", 0))
	end_t = int(d.get("end_t", 0))
	alive = bool(d.get("alive", false))
	seed = int(d.get("seed", 0))
	sampling_attacks = bool(d.get("sampling", false))
	truncated = bool(d.get("truncated", false))
	kills = int(d.get("kills", 0))
	fled = bool(d.get("fled", false))
	notes_written = int(d.get("notes_written", 0))
	items_picked = int(d.get("items_picked", 0))
	deaths = int(d.get("deaths", 0))
	playtime_ms = int(d.get("playtime_ms", 0))
	death_cause = StringName(str(d.get("death_cause", "")))
	var p: Array = d.get("last_death_pos", [])
	if p.size() == 3:
		last_death_pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
	var rows: Array = d.get("events", [])
	events.clear()
	for i in rows.size():
		var ev := _EV.new()
		ev.load_array(rows[i])
		events.append(ev)
