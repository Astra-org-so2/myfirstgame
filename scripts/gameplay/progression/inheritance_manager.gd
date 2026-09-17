# InheritanceManager — the "1 of 3 on death" rules (PROGRESSION_DESIGN).
#
# Pure logic (no Node): the death screen (and the tests) drive it.
#
# Rules implemented:
# - POOL (unowned, per death): 8 basic + 4 NPC-gated (NPC alive AND
#   trust >= 1) + post-MVP (data-disabled for MVP; the behavior gate —
#   RUNNER: fled > 10 — is real and unit-tested).
# - OFFER (3 cards): up to 2 NEW from the pool, the rest — REPEATS
#   (upgrades of an owned Inheritance, max 2 each; Q-P2).
# - CHOICE: PERMANENT (WorldState.inheritances, never reset).
# - NPC gate = PRICE: a dead NPC's Inheritance leaves the pool forever
#   (the pool is recomputed from WorldState every death).
class_name InheritanceManager
extends RefCounted

const _WS = preload("res://scripts/gameplay/progression/world_state.gd")
const _DATA = preload("res://scripts/gameplay/progression/inheritance_data.gd")

const MAX_LEVEL: int = 3  # choice (1) + max 2 repeats
const OFFER_SIZE: int = 3
const NEW_PER_OFFER: int = 2


# The unowned candidates right now. `all` = the 15 InheritanceData
# (loaded from data/inheritances/ by the scene). `stats` = MemoryStats
# (behavior gates). Returns a copy.
func get_pool(ws: _WS, stats: Variant, all: Array) -> Array:
	var out: Array = []
	for d in all:
		var data: _DATA = d
		if ws.is_inheritance_owned(data.id):
			continue
		if not data.in_mvp_pool:
			continue
		match data.layer:
			_DATA.Layer.BASIC:
				out.append(data)
			_DATA.Layer.NPC_GATED:
				var e: Dictionary = ws.npc_entry(data.npc_id)
				if bool(e.alive) and int(e.trust) >= 1:
					out.append(data)
			_DATA.Layer.POST_MVP:
				if behavior_passed(stats, data):
					out.append(data)
	return out


# Behavior gate (RUNNER): the memory_stats stat crossed its threshold.
# (WORLD_STATE_DESIGN §3: hidden counters, visible consequences.)
func behavior_passed(stats: Variant, data: _DATA) -> bool:
	if data.behavior_stat == &"":
		return true
	if stats == null:
		return false
	return float(stats.get(String(data.behavior_stat))) \
			> data.behavior_threshold


# The 3 death-screen cards: up to 2 new, the rest repeats. Deterministic
# under the caller's rng (the game seeds it per death; tests own it).
func roll_offer(ws: _WS, stats: Variant, all: Array,
		rng: RandomNumberGenerator) -> Array:
	var pool: Array = get_pool(ws, stats, all)
	var new_cards: Array = []
	for d in pool:
		new_cards.append(d)
	rng.shuffle(new_cards)
	new_cards = new_cards.slice(0, NEW_PER_OFFER)

	var repeats: Array = []
	for d in all:
		var data: _DATA = d
		var level: int = ws.inheritance_level(data.id)
		if level >= 1 and level < MAX_LEVEL:
			repeats.append(data)
	rng.shuffle(repeats)

	var offer: Array = []
	for d in new_cards:
		offer.append(d)
	for d in repeats:
		if offer.size() >= OFFER_SIZE:
			break
		offer.append(d)
	return offer


# PERMANENT: +1 level (max 3). Returns the new level.
func apply_choice(ws: _WS, data: _DATA) -> int:
	return ws.add_inheritance(data.id, MAX_LEVEL)


# The level the choice will produce (1 for a new, +1 for a repeat).
func level_after_choice(ws: _WS, data: _DATA) -> int:
	return ws.inheritance_level(data.id) + 1


func is_repeat_card(ws: _WS, data: _DATA) -> bool:
	return ws.is_inheritance_owned(data.id)
