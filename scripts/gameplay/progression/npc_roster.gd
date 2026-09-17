# NpcRoster — the data holder for the 4 trust NPCs (data/npcs/npc_state.tres).
# The fifth (The Child) is NOT here: invulnerable by design and a
# separate entity (CHARACTER_BIBLE §5, its system — Phase 8/10).
class_name NpcRoster
extends Resource

const _DATA = preload("res://scripts/gameplay/progression/npc_data.gd")

@export var npcs: Array = []  # Array[NpcData] (.tres resource-array form)


func npc(npc_id: StringName) -> _DATA:
	for d in npcs:
		if d.npc_id == npc_id:
			return d
	return null


func all() -> Array:
	return npcs
