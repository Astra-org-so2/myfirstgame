# ProgressionState — the scene-side composition of the Phase 6 systems.
#
# A thin Node that OWNS the live WorldState (WORLD_STATE_DESIGN: the
# single memory layer; save/load wraps this store in Phase 15) and the
# pure logic (InheritanceManager / InheritanceEffects / NpcTrust) plus
# the loaded data (15 Inheritances, the NPC roster). The systems stay
# pure and unit-tested; this node only wires and holds.
class_name ProgressionState
extends Node

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _MGR = preload("res://scripts/gameplay/progression/inheritance_manager.gd")
const _FX = preload("res://scripts/gameplay/progression/inheritance_effects.gd")
const _TRUST = preload("res://scripts/gameplay/progression/npc_trust.gd")
const _DATA = preload("res://scripts/gameplay/progression/inheritance_data.gd")

const INHERITANCE_FILES: Array[String] = [
	"sharp", "flow", "slow_burn", "quiet_step", "deep_sight",
	"gentle_hand", "echo_step", "second_chance", "ember", "the_track",
	"the_page", "the_compass", "breaker", "paradox", "runner",
]

var ws: _WS
var manager: _MGR
var effects: _FX
var trust: _TRUST
var roster: Resource
var all_inheritances: Array = []
# MemoryStats (the tracker's stats) — behavior gates + trust-2 rules.
var stats: Variant = null
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_stats: Variant, seed: int) -> void:
	stats = p_stats
	rng.seed = seed
	ws = _WS.new()
	all_inheritances = []
	for f in INHERITANCE_FILES:
		var d: _DATA = load("res://data/inheritances/%s.tres" % f)
		if d == null:
			push_error("ProgressionState: Inheritance missing: %s" % f)
		all_inheritances.append(d)
	manager = _MGR.new()
	effects = _FX.new(all_inheritances)
	trust = _TRUST.new()
	roster = load("res://data/npcs/npc_state.tres")
	# The blade is found at RUN 1 (WEAPON_DESIGN §1.4, K1: "the hand
	# knows") — the player starts with it (Phase 4 bound it).
	ws.set_weapon_found(&"weapon_blade")
	ws.set_flag(&"blade_found")


func npc_data(npc_id: StringName) -> Resource:
	if roster == null:
		return null
	return roster.npc(npc_id)


func roll_death_offers() -> Array:
	return manager.roll_offer(ws, stats, all_inheritances, rng)


# PERMANENT choice (death screen). Returns the new level.
func apply_choice(data: _DATA) -> int:
	return manager.apply_choice(ws, data)


# The death-screen flow, one call: roll + apply (the random-timeout
# path and the player's pick both end here).
func resolve_death_choice(data: _DATA) -> int:
	return apply_choice(data)
