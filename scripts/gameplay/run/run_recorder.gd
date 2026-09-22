# RunRecorder — records one run's events (TECHNICAL_DESIGN §2).
#
# Pure (RefCounted, no scene): unit-testable in the rig. Rules:
#   * time is deciseconds since run start (int32 — ~68 h cap);
#   * hard cap: 4096 events per run (the log is exactly that long);
#   * at the cap, if the run has any ATTACK events → SAMPLING: attacks
#     are recorded every 2nd (the record's sampling flag is set); other
#     events keep coming into a ring (the log holds the newest 4096);
#   * at the cap with no attacks → TRUNCATION: the log stops growing
#     (the ghost plays to the end of the log, then stands still).
#
# Cross-file refs are preload-consts (ADR-022). The scene (RunManager)
# feeds record() and owns the time source (game-time accumulation), so
# the recorder itself is deterministic.
class_name RunRecorder
extends RefCounted

const _EV = preload("res://scripts/gameplay/run/run_event.gd")

const MAX_EVENTS: int = 4096

# 10 samples/second (deciseconds).
const DECS_PER_SECOND: int = 10

var events: Array = []  # Array[RunEvent]
# RunHeader flags (TECHNICAL_DESIGN §2/§3): sampling + truncated.
var sampling_attacks: bool = false
var truncated: bool = false
var dropped_count: int = 0
var _attack_counter: int = 0
var _cap_reached: bool = false
var _ring_pos: int = 0  # next overwrite slot (oldest when full)
var _last_dropped_log_at: int = 0


func reset() -> void:
	events.clear()
	sampling_attacks = false
	truncated = false
	dropped_count = 0
	_attack_counter = 0
	_cap_reached = false
	_ring_pos = 0
	_last_dropped_log_at = 0


func record(t_decis: int, type: int, room: int,
		pos: Vector3, ry_deg: int, target: int, data: int = 0):
	# Returns the kept event, null if it was dropped (cap/sampling).
	room = clampi(room, 0, 255)
	ry_deg = _EV.clamp_deg(ry_deg)
	var x: int = _EV.clamp_coord(int(pos.x * 100.0))
	var z: int = _EV.clamp_coord(int(pos.z * 100.0))
	var y: int = _EV.clamp_coord(int(pos.y * 100.0))
	var ev := _EV.new()
	ev.t = maxi(0, t_decis)
	ev.type = type
	ev.room = room
	ev.x = x
	ev.y = y
	ev.z = z
	ev.ry = ry_deg
	ev.target = clampi(target, 0, 65535)
	ev.data = clampi(data, 0, 255)

	if events.size() < MAX_EVENTS:
		events.append(ev)
		_count_attack(ev.type)
		return ev

	# --- at the 4096 cap (TECHNICAL_DESIGN §2) ----------------------
	if not _cap_reached:
		_cap_reached = true
		if _attack_counter > 0:
			# Sampling mode: attacks every 2nd, others ring.
			sampling_attacks = true
		else:
			# Truncation: the log is finished (ghost plays to its end).
			truncated = true
			dropped_count += 1
			_log_drop(t_decis)
			return null
	if truncated:
		dropped_count += 1
		_log_drop(t_decis)
		return null
	if ev.type == _EV.Type.ATTACK:
		_attack_counter += 1
		if _attack_counter % 2 == 0:
			# Sampled away (every 2nd attack of the overflow).
			dropped_count += 1
			_log_drop(t_decis)
			return null
	# Ring overwrite: the log stays exactly 4096, newest kept.
	events[_ring_pos] = ev
	_ring_pos = (_ring_pos + 1) % MAX_EVENTS
	return ev


func _count_attack(t: int) -> void:
	if t == _EV.Type.ATTACK:
		_attack_counter += 1


func _log_drop(t_decis: int) -> void:
	# One warning per ~10 s of game time (log spam guard).
	if t_decis - _last_dropped_log_at >= 100:
		_last_dropped_log_at = t_decis
		push_warning("RunRecorder: 4096-event cap reached — dropping "
				+ "(total dropped: %d)" % dropped_count)


# ---- JSON (save format: an array of 9-element rows, chronological) --

func to_json_array() -> Array:
	var out: Array = []
	if not _cap_reached:
		out.resize(events.size())
		for i in events.size():
			out[i] = events[i].to_array()
		return out
	# Full ring: the oldest is at _ring_pos.
	out.resize(MAX_EVENTS)
	for i in MAX_EVENTS:
		out[i] = events[(_ring_pos + i) % MAX_EVENTS].to_array()
	return out


func load_json_array(rows: Array) -> void:
	reset()
	for i in rows.size():
		var ev := _EV.new()
		ev.load_array(rows[i])
		events.append(ev)
		_count_attack(ev.type)
	if events.size() >= MAX_EVENTS:
		_cap_reached = true
		_ring_pos = 0
	# The sampling flag is re-stated by the caller (RunHeader field).


func attack_count() -> int:
	return _attack_counter
