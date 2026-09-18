# RunManager — the run lifecycle (TECHNICAL_DESIGN §2/§3,
# WORLD_STATE_DESIGN §1): run id, per-run seed, recorder time, death →
# new run, last_death_pos, and the "what changed" diff.
#
# States: PLAYING -> DEAD (death screen, 1-of-3 choice) -> RESPAWNING
# (fade + level rebuild) -> PLAYING (run N+1 at camp).
#
# The per-run seed is DERIVED, not random: seed(run) =
# splitmix64-finalizer(session_seed ^ RUN_MIX * run_id). The layout
# therefore changes on every run, is reproducible from the save (the
# session seed is in world_state), and the room indices inside a run's
# events are answered against THAT run's layout (the record stores the
# seed).
#
# A plain Node (not an autoload): the scene owns exactly one, feeds it
# from EventBus, and lets it drive the respawn rebuild. Deterministic
# under the rig (time comes from the scene's game-time accumulation).
class_name RunManager
extends Node

const _REC = preload("res://scripts/gameplay/run/run_recorder.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _RR = preload("res://scripts/gameplay/run/run_record.gd")
const _WS = preload("res://scripts/gameplay/progression/world_state.gd")

# splitmix64 constants (signed-decimal form — hex literals > INT64
# max do not parse; ADR-022 family rule).
const RUN_MIX: int = -7046029254386353131     # 0x9E3779B97F4A7C15
const _SM_A: int = -4658895280553007687       # 0xBF58476D1CE4E5B9
const _SM_B: int = -7723592293110705685       # 0x94D049BB133111EB

# Run states.
enum State { PLAYING, DEAD, RESPAWNING }

# The flag that unlocks the sealed door after the first death (A19).
const DOOR_OPEN_FLAG: StringName = &"run_02_door_open"

signal run_started(run_id: int, seed: int)
signal run_ended(run_record)
# "What changed" lines for the death screen (WORLD_STATE_DESIGN §9.2).
signal changed_lines_ready(lines: Array)

var state: int = State.PLAYING
var run_id: int = 1
var session_seed: int = 0
# The current run's layout seed.
var run_seed: int = 0
var recorder: Variant = null  # RunRecorder
var current_record: Variant = null  # RunRecord
# The shared history (world_state.runs — set in init_session).
var history: Variant = null  # RunHistory
# The flag → consequence text table (data/world_flags.tres). The scene
# sets this before the first possible death.
var flag_lines: Dictionary = {}
# Game-time bookkeeping (deciseconds since run start).
var _time_decis: int = 0
# The flag set at run start (for the "what changed" diff at death).
var _flags_at_start: Dictionary = {}
var _run_started: bool = false
var _ws: Variant = null  # WorldState
# "What changed" lines computed at death, emitted at respawn
# (WORLD_STATE_DESIGN §9.2: shown ON RESPAWN, 3 s window).
var _pending_changed: Array = []


func _ready() -> void:
	if recorder == null:
		recorder = _REC.new()


func init_session(seed: int, world_state) -> void:
	session_seed = seed
	_ws = world_state
	history = world_state.runs
	if not _run_started:
		begun_run(1)


# The scene wires the live event sources (EventBus, the player's
# weapon swing, the damage resolver) into the recorder. Positions are
# in the current run's layout space (the record carries the seed; the
# ghost replays against that layout). `room` = the level's entry-room
# index (0 = the entry room).
func bind(bus: Node, pl: Node, resolver: Node) -> void:
	_player = pl
	if bus != null:
		if bus.has_signal("enemy_killed"):
			bus.enemy_killed.connect(_on_enemy_killed)
		if bus.has_signal("weapon_found"):
			bus.weapon_found.connect(_on_weapon_found)
	if pl != null:
		# ATTACK events follow the EQUIPPED weapon (a pickup swaps
		# it, and the old node stops swinging).
		var lo: Node = pl.get("loadout")
		if lo != null and lo.has_signal("weapon_changed") \
				and not lo.is_connected(&"weapon_changed", _on_weapon_changed):
			lo.weapon_changed.connect(_on_weapon_changed)
		_bind_swing()
	if resolver != null and resolver.has_signal("damage_applied"):
		resolver.damage_applied.connect(_on_damage)


var _swing_weapon: Node = null


func _current_weapon() -> Node:
	if _player == null:
		return null
	var lo: Node = _player.get("loadout")
	if lo != null:
		return lo.current()
	return _player.get("weapon")


func _on_weapon_changed(_id: StringName) -> void:
	_bind_swing()


func _bind_swing() -> void:
	var w: Node = _current_weapon()
	if _swing_weapon != null and is_instance_valid(_swing_weapon) \
			and _swing_weapon != w \
			and _swing_weapon.is_connected(&"swing_started", _on_swing):
		_swing_weapon.disconnect(&"swing_started", _on_swing)
	if w == null or not w.has_signal("swing_started"):
		_swing_weapon = null
		return
	if not w.is_connected(&"swing_started", _on_swing):
		w.swing_started.connect(_on_swing)
	_swing_weapon = w


func record_npc_talked(npc_id: StringName) -> void:
	record_event(_EV.Type.NPC_TALKED, 0, _local_pos(), _ry_deg(),
			_npc_index(npc_id))


var _player: Node = null


func _local_pos() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	return _player.get_body_position()


func _ry_deg() -> int:
	if _player == null:
		return 0
	return int(rad_to_deg(float(_player.get("rotation").y)))


func _on_swing() -> void:
	record_event(_EV.Type.ATTACK, 0, _local_pos(), _ry_deg(), 0)


func _on_enemy_killed(enemy_id: StringName, pos: Vector3) -> void:
	record_event(_EV.Type.ENEMY_KILLED, 0, pos, 0, _enemy_index(enemy_id))


func _on_weapon_found(weapon_id: StringName, pos: Vector3) -> void:
	record_event(_EV.Type.ITEM_PICKED, 0, pos, 0, _weapon_index(weapon_id))


func _on_damage(res: Variant) -> void:
	# A landed player swing (the hit itself — not the kill, which is
	# enemy_killed).
	if res == null or res.source != _player:
		return
	if res.target == _player or res.blocked:
		return
	record_event(_EV.Type.ATTACK_HIT, 0, res.position, 0,
			_enemy_index_of_node(res.target))


# Compact target ids (RunEvent.target is u16): stable tables, not
# hashes — the ghost system maps them back by the same table.
const _ENEMY_IDS: Array = [&"hollow_base", &"hollow_fast",
		&"hollow_big", &"mimic_combo", &"mimic_dodge", &"mimic_range",
		&"watcher_base", &"forgotten_wanderer", &"forgotten_guard",
		&"remnant_mirror", &"remnant_false"]
const _WEAPON_IDS: Array = [&"weapon_blade", &"weapon_cannon",
		&"weapon_staff"]
const _NPC_IDS: Array = [&"mara", &"orren", &"nia", &"cartographer"]


func _enemy_index(id: StringName) -> int:
	var i: int = _ENEMY_IDS.find(id)
	return i + 1 if i >= 0 else 0


func _enemy_index_of_node(n: Node) -> int:
	if n == null:
		return 0
	if n.has_method("get_data_id"):
		return _enemy_index(n.get_data_id())
	return 0


func _weapon_index(id: StringName) -> int:
	var i: int = _WEAPON_IDS.find(id)
	return 100 + i if i >= 0 else 100


func _npc_index(id: StringName) -> int:
	var i: int = _NPC_IDS.find(id)
	return 200 + i if i >= 0 else 200


func begun_run(id: int) -> void:
	if recorder == null:
		recorder = _REC.new()
	run_id = maxi(1, id)
	run_seed = derive_seed(session_seed, run_id)
	recorder.reset()
	_time_decis = 0
	var rec := _RR.new()
	current_record = rec
	rec.run_id = run_id
	rec.seed = run_seed
	rec.start_t = 0
	_flags_at_start = _flag_snapshot()
	state = State.PLAYING
	_run_started = true
	record_event(_EV.Type.PLAYER_SPAWNED, 0, Vector3.ZERO, 0, 0)
	run_started.emit(run_id, run_seed)
	if run_id > 1 and not _pending_changed.is_empty():
		var lines: Array = _pending_changed
		_pending_changed = []
		changed_lines_ready.emit(lines)


static func derive_seed(session_seed: int, run_id: int) -> int:
	# RUN 1 is the canonical layout: the session seed itself (the
	# A-beats of FIRST_30_MINUTES were designed against it). Run N>1
	# derives a new one, so every respawn changes the world.
	if run_id <= 1:
		return session_seed
	# splitmix64 finalizer (the RngStreams family): stable across runs,
	# different per (session, run) pair. (GDScript shifts are
	# arithmetic; the mix is still deterministic and well-distributed.)
	var x: int = session_seed ^ (run_id * RUN_MIX)
	x = x ^ (x >> 30)
	x = x * _SM_A
	x = x ^ (x >> 27)
	x = x * _SM_B
	return x ^ (x >> 31)


func advance_time(delta_seconds: float) -> void:
	if state != State.PLAYING:
		return
	var before: int = _time_decis
	_time_decis += int(round(delta_seconds * _REC.DECS_PER_SECOND))
	if _time_decis < before or _time_decis > 2000000000:
		# int32 territory (~68 h): clamp, keep counting runs.
		_time_decis = 2000000000


func time_decis() -> int:
	return _time_decis


func time_ms() -> int:
	return _time_decis * 100


# The scene feeds every gameplay moment worth recording. Returns the
# kept event (null if dropped by the 4096 cap / attack sampling).
func record_event(type: int, room_index: int, pos: Vector3,
		ry_deg: int, target: int, data: int = 0):
	if current_record == null:
		return null
	if state != State.PLAYING:
		# Death is recorded even though the run is already DEAD.
		if not (state == State.DEAD
				and type == _EV.Type.PLAYER_DIED):
			return null
	var ev: Variant = recorder.record(_time_decis, type, room_index,
			pos, ry_deg, target, data)
	if ev != null:
		current_record.events.append(ev)
		_update_summary(type)
		current_record.sampling_attacks = recorder.sampling_attacks
		current_record.truncated = recorder.truncated
	return ev


func _update_summary(t: int) -> void:
	# Literal values (match patterns must be constant expressions):
	# 3 = ENEMY_KILLED, 5 = ITEM_PICKED, 14 = NOTE_WRITTEN.
	match t:
		3:
			current_record.add_kills(1)
		5:
			current_record.add_items(1)
		14:
			current_record.add_notes(1)


func _flag_snapshot() -> Dictionary:
	# Flags live on WorldState; the history is only run storage.
	# The known set is the LINES table (data): a flag without a
	# consequence line can never appear in the summary.
	var snap := {}
	for f in flag_lines.keys():
		if ws_flag(f):
			snap[f] = true
	return snap


func ws_flag(id: StringName) -> bool:
	if _ws == null:
		return false
	return _ws.flag(id)


func ws_set_flag(id: StringName, value: Variant = true) -> void:
	if _ws != null:
		_ws.set_flag(id, value)


# The flags P8 tracks for "what changed" (WORLD_STATE_DESIGN §2).
# Death flow: the scene calls this on EventBus.player_died.
func on_player_died(pos: Vector3, cause: StringName) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	record_event(_EV.Type.PLAYER_DIED, 0, pos, 0, 0,
			_clamped_cause_index(cause))
	ws_set_flag(DOOR_OPEN_FLAG)
	ws_set_flag(&"first_death_done")
	current_record.finish_run(false, time_ms(), cause, pos)
	if history != null:
		history.add_run(current_record)
	# The lines are shown at the RESPAWN (design §9.2), not on the
	# death screen — stored now, emitted in begin_run of the next run.
	_pending_changed = changed_lines(flag_lines)
	run_ended.emit(current_record)


# "What changed" (WORLD_STATE_DESIGN §9.2): flags set since run start,
# one consequence line each, ≤ 5, no numbers.
func changed_lines(flag_lines_table: Dictionary) -> Array:
	# Newest first: the summary is about the world changes of the
	# moment (the design example: door, weapons, kettle) — the old
	# memory flags of the run must not crowd them out.
	var lines: Array = []
	var now: Dictionary = _flag_snapshot()
	var keys: Array = now.keys()
	keys.reverse()
	for f in keys:
		if not _flags_at_start.get(f, false):
			var text: String = flag_lines_table.get(f, "")
			if text != "":
				lines.append(text)
			if lines.size() >= 5:
				break
	return lines


# Respawn: the scene calls this when the player spawns after a death.
# Returns the new run's seed (the scene rebuilds the layout with it).
func begin_next_run() -> int:
	if state != State.DEAD:
		return run_seed
	state = State.RESPAWNING
	begun_run(run_id + 1)
	state = State.PLAYING
	return run_seed


func last_death_pos() -> Vector3:
	if current_record != null:
		return current_record.last_death_pos
	if history != null and history.latest() != null:
		return history.latest().last_death_pos
	return Vector3.ZERO


func _clamped_cause_index(cause: StringName) -> int:
	# Cause → compact data byte (the name is also in the record).
	var known: Array = [&"hollow", &"mimic", &"watcher", &"forgotten",
			&"echo", &"envy", &"fall", &"fire", &"drown", &"spike",
			&"starve", &"unknown"]
	var i: int = known.find(cause)
	return maxi(0, i)
