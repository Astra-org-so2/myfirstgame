# WorldState — the single memory layer of the world (WORLD_STATE_DESIGN).
#
# Phase 6 builds the LIVE in-memory store: everything that survives a
# run (flags, inheritances, weapons, NPC state). Save/load (user://
# worldstate.json, CRC32, atomic write, migrations) is Phase 15 and will
# wrap THIS SAME class — no data-model change at that point.
#
# Pure RefCounted (not a Node): unit-testable without a scene, owned by
# main_scene (scene composition, not an autoload — ADR-023/ARCHITECTURE
# §6; Phase 15 introduces the autoload with the file I/O).
class_name WorldState
extends RefCounted

# The runs section (WORLD_STATE_DESIGN §1, TECHNICAL_DESIGN §3):
# recent full runs + summaries. Serialized separately from flags
# (the 5 MB cap applies to this section alone).
const _RH = preload("res://scripts/gameplay/run/run_history.gd")

var flags: Dictionary = {}
var inheritances: Dictionary = {}
var weapons: Dictionary = {}
var npcs: Dictionary = {}
var runs: Variant = null  # RunHistory
# Player notes (section 4: 4 stands, 5-line pool, no free text;
# 1 note per stand, «перезапись» replaces). Entry:
# { line_id: int (index in the pool), run_id: int, t: int (ms) }.
var notes: Dictionary = {}


# 4 player notes max (one per stand, section 4: notes_max).
const NOTES_MAX: int = 4


# The player writes (or re-writes) a note at a stand. Returns false
# on an unknown stand (the caller must not invent stands).
func write_note(stand_id: StringName, line_id: int, run_id: int,
		t_ms: int) -> bool:
	if not _known_stand(stand_id):
		return false
	notes[stand_id] = {"line_id": line_id, "run_id": run_id, "t": t_ms}
	return true


func _known_stand(stand_id: StringName) -> bool:
	return [&"camp", &"village", &"shrine", &"undercroft"].has(stand_id)


func get_note(stand_id: StringName) -> Dictionary:
	return notes.get(stand_id, {})


func note_line(stand_id: StringName) -> int:
	return int(get_note(stand_id).get("line_id", -1))


# The player's LAST written note (the mummy's hand, #5): the most
# recent by t, or {} (none yet).
func last_note() -> Dictionary:
	var best: Dictionary = {}
	var best_t: int = -1
	for stand in notes:
		var e: Dictionary = notes[stand]
		if int(e.get("t", -1)) > best_t:
			best_t = int(e.get("t", -1))
			best = e
	return best


func _init() -> void:
	if runs == null:
		runs = _RH.new()

# --- Flags (persistent booleans; 1 flag = 1 visible consequence) ---

func set_flag(id: StringName, value: Variant = true) -> void:
	flags[id] = value


# Boolean view (the design docs' "flag" — true if set).
func flag(id: StringName) -> bool:
	return bool(get_flag(id, false))


func runs_dict() -> Dictionary:
	return runs.to_dict()


func load_runs(d: Dictionary) -> void:
	runs.from_dict(d)


func get_flag(id: StringName, default: Variant = false) -> Variant:
	return flags.get(id, default)


# --- Inheritances (permanent; level 1..3: choice + 2 repeats) ---

func inheritance_level(id: StringName) -> int:
	return int(inheritances.get(id, 0))


func is_inheritance_owned(id: StringName) -> bool:
	return inheritance_level(id) >= 1


# +1 level (max MAX_LEVEL via the manager). Returns the new level.
func add_inheritance(id: StringName, max_level: int) -> int:
	var level: int = inheritance_level(id) + 1
	inheritances[id] = mini(level, max_level)
	return int(inheritances[id])


func owned_inheritances() -> Array:
	var out: Array = []
	for id in inheritances:
		if int(inheritances[id]) > 0:
			out.append(id)
	return out


# --- Weapons (permanent: found once, forever) ---

func set_weapon_found(id: StringName) -> void:
	weapons[id] = true


func is_weapon_found(id: StringName) -> bool:
	return bool(weapons.get(id, false))


func found_weapons() -> Array:
	var out: Array = []
	for id in weapons:
		if bool(weapons[id]):
			out.append(id)
	return out


# --- NPCs (per-NPC runtime: trust, interactions, death) ---
#
# Entry: { alive: bool, trust: int, interactions: int,
#          help_done: bool, gifts_given: bool }

func npc_entry(id: StringName) -> Dictionary:
	if not npcs.has(id):
		npcs[id] = {"alive": true, "trust": 0, "interactions": 0,
				"help_done": false, "gifts_given": false}
	return npcs[id]


func is_npc_alive(id: StringName) -> bool:
	return bool(npc_entry(id).alive)


# Death is a PERMANENT meta price (GDD §9): alive=false and trust
# resets — the NPC-gated Inheritance leaves the pool forever (the pool
# is computed from this state on every death screen).
func kill_npc(id: StringName) -> void:
	var e: Dictionary = npc_entry(id)
	e.alive = false
	e.trust = 0


# --- Persist (TECHNICAL_DESIGN section 3: the save «world» section) ---
#
# Phase 15's SaveManager serializes to_dict() to user://save with
# CRC32 + migrations; this is the pure data roundtrip (unit-tested).

const VERSION: int = 1


func to_dict() -> Dictionary:
	var f: Dictionary = {}
	for id in flags:
		f[id] = flags[id]
	var i: Dictionary = {}
	for id in inheritances:
		i[id] = int(inheritances[id])
	var w: Dictionary = {}
	for id in weapons:
		w[id] = bool(weapons[id])
	var n: Dictionary = {}
	for id in npcs:
		var e: Dictionary = npcs[id]
		n[id] = {"alive": bool(e.alive), "trust": int(e.trust),
				"interactions": int(e.interactions),
				"help_done": bool(e.help_done),
				"gifts_given": bool(e.gifts_given)}
	var nt: Dictionary = {}
	for id in notes:
		var ne: Dictionary = notes[id]
		nt[id] = {"line_id": int(ne.line_id), "run_id": int(ne.run_id),
				"t": int(ne.t)}
	return {"version": VERSION, "flags": f, "inheritances": i,
			"weapons": w, "npcs": n, "notes": nt,
			"runs": runs.to_dict()}


# Load with safe defaults (corrupt-save defense, GDD save policy):
# unknown sections/keys are skipped, bad values fall back to
# defaults — never a crash, never a partial wipe.
func load_dict(d: Dictionary) -> void:
	flags.clear()
	for id in d.get("flags", {}):
		flags[id] = d["flags"][id]
	inheritances.clear()
	for id in d.get("inheritances", {}):
		inheritances[id] = maxi(0, int(d["inheritances"][id]))
	weapons.clear()
	for id in d.get("weapons", {}):
		if bool(d["weapons"][id]):
			weapons[id] = true
	npcs.clear()
	for id in d.get("npcs", {}):
		var e: Dictionary = npc_entry(id)
		var raw: Dictionary = d["npcs"][id]
		e.alive = bool(raw.get("alive", true))
		e.trust = clampi(int(raw.get("trust", 0)), 0, 2)
		e.interactions = maxi(0, int(raw.get("interactions", 0)))
		e.help_done = bool(raw.get("help_done", false))
		e.gifts_given = bool(raw.get("gifts_given", false))
	notes.clear()
	for id in d.get("notes", {}):
		if _known_stand(StringName(id)):
			var raw: Dictionary = d["notes"][id]
			notes[id] = {"line_id": clampi(int(raw.get("line_id", 0)),
						0, 4),
					"run_id": maxi(0, int(raw.get("run_id", 1))),
					"t": maxi(0, int(raw.get("t", 0)))}
	runs.load_dict(d.get("runs", {"full": [], "summaries": []}))
