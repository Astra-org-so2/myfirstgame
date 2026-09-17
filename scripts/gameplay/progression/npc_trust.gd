# NpcTrust — the 0–2 trust rules (PROGRESSION_DESIGN §4).
#
# Pure logic over the WorldState npc_entry (the scene/NPC node calls in;
# the entry is the only state touched):
#   trust 1 = interactions >= trust_1 AND the scripted help done;
#   trust 2 = trust 1 AND interactions >= trust_2 AND the NPC-specific
#             memory_stat above its threshold;
#   death   = trust reset + the NPC-gated Inheritance leaves the pool
#             forever (WorldState.kill_npc).
class_name NpcTrust
extends RefCounted

const _DATA = preload("res://scripts/gameplay/progression/npc_data.gd")


func trust_level(entry: Dictionary, data: _DATA, stats: Variant) -> int:
	if not bool(entry.alive):
		return 0  # dead: "doesn't trust" — "no"
	var interactions: int = int(entry.interactions)
	var help_done: bool = bool(entry.help_done)
	if interactions >= data.trust_1_interactions and help_done:
		var t2: bool = interactions >= data.trust_2_interactions \
				and stat_passed(stats, data)
		if t2:
			return 2
		return 1
	return 0


func stat_passed(stats: Variant, data: _DATA) -> bool:
	if data.trust_2_stat == &"":
		return true
	if stats == null:
		return false
	return float(stats.get(String(data.trust_2_stat))) \
			> data.trust_2_threshold


# One interaction (dialogue). Returns the NEW trust level.
func interact(entry: Dictionary, data: _DATA, stats: Variant) -> int:
	entry.interactions = int(entry.interactions) + 1
	var level: int = trust_level(entry, data, stats)
	entry.trust = level
	return level


# The scripted help (1 action per NPC, e.g. Mara: "bring the wood").
# Returns the NEW trust level (help alone doesn't grant trust 1 —
# it still needs the 2 interactions).
func complete_help(entry: Dictionary, data: _DATA, stats: Variant) -> int:
	entry.help_done = true
	var level: int = trust_level(entry, data, stats)
	entry.trust = level
	return level


func kill(entry: Dictionary) -> void:
	entry.alive = false
	entry.trust = 0


func dialog_line(data: _DATA, trust: int) -> String:
	return data.dialogue_for(trust)
