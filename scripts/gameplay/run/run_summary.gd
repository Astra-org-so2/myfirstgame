# RunSummary — the compact form of a run once its full event log was
# dropped from runs.full[] (TECHNICAL_DESIGN §3, WORLD_STATE_DESIGN §1).
#
# Old runs become summaries when the runs section approaches the
# 5 MB save cap: the oldest full run is reduced to a RunSummary and the
# ghost can no longer replay it (it "stands where the log ends" — the
# summary keeps enough to say WHAT happened: seed, duration, kills,
# rooms visited, a few major events).
class_name RunSummary
extends RefCounted

const _EV = preload("res://scripts/gameplay/run/run_event.gd")


var run_id: int = 1
var seed: int = 0
var start_t: int = 0
var duration_ms: int = 0
var alive: bool = false
var death_cause: StringName = &""
var kills: int = 0
var fled: bool = false
var notes_written: int = 0
var items_picked: int = 0
var deaths: int = 0
# Rooms visited (room indices of the run's layout) — ≤ 64.
var rooms_visited: Array[int] = []
# A few major events (≤ 16): {t, type, room}.
var major_events: Array = []  # Array[Dictionary]


# Fills this summary from a RunRecord (construction is caller-side:
# `var s := _RS.new(); s.init_from_record(r)`).
func init_from_record(r) -> void:
	run_id = r.run_id
	seed = r.seed
	start_t = r.start_t
	duration_ms = r.playtime_ms
	alive = r.alive
	death_cause = r.death_cause
	kills = r.kills
	fled = r.fled
	notes_written = r.notes_written
	items_picked = r.items_picked
	deaths = r.deaths
	rooms_visited.clear()
	major_events.clear()
	var seen := {}
	for i in r.events.size():
		var e: Variant = r.events[i]
		if e.room != 0 and not seen.has(e.room):
			seen[e.room] = true
			rooms_visited.append(int(e.room))
		if major_events.size() < 16 and _is_major(int(e.type)):
			major_events.append({"t": e.t, "type": e.type, "room": e.room})


static func _is_major(t: int) -> bool:
	# The "major" set for summaries (TECHNICAL_DESIGN §3): deaths, kills,
	# choices, notes, items — not every step. Literal values (match
	# patterns must be constant expressions; a preload const chain is
	# not one in the rig compiler).
	# 3 ENEMY_KILLED, 4 CHEST_OPENED, 5 ITEM_PICKED, 7 NPC_TALKED,
	# 8 NPC_KILLED, 9 EVENT_COMPLETED, 10 CHOICE_MADE, 11 PLAYER_DIED,
	# 14 NOTE_WRITTEN, 15 ANCHOR_SET, 16 ECHO_TRIGGER.
	var major: Dictionary = {
		3: true, 4: true, 5: true, 7: true, 8: true, 9: true,
		10: true, 11: true, 14: true, 15: true, 16: true,
	}
	return major.has(t)


func to_dict() -> Dictionary:
	return {
		"run_id": run_id, "seed": seed, "start_t": start_t,
		"duration_ms": duration_ms, "alive": alive,
		"death_cause": String(death_cause), "kills": kills, "fled": fled,
		"notes_written": notes_written, "items_picked": items_picked,
		"deaths": deaths, "rooms_visited": rooms_visited,
		"major_events": major_events,
	}


func load_dict(d: Dictionary) -> void:
	run_id = int(d.get("run_id", 1))
	seed = int(d.get("seed", 0))
	start_t = int(d.get("start_t", 0))
	duration_ms = int(d.get("duration_ms", 0))
	alive = bool(d.get("alive", false))
	death_cause = StringName(str(d.get("death_cause", "")))
	kills = int(d.get("kills", 0))
	fled = bool(d.get("fled", false))
	notes_written = int(d.get("notes_written", 0))
	items_picked = int(d.get("items_picked", 0))
	deaths = int(d.get("deaths", 0))
	rooms_visited.clear()
	var rooms: Array = d.get("rooms_visited", [])
	for i in rooms.size():
		rooms_visited.append(int(rooms[i]))
	major_events.clear()
	var majors: Array = d.get("major_events", [])
	for i in majors.size():
		major_events.append(majors[i])
