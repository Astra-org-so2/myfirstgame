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
