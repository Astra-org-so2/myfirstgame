# SpawnTable — the enemy roster of a hub (data-driven).
#
# Phase 5 demo: one of each archetype in the camp hub,
# so a 15-minute QA session can meet all five behaviors. Production
# zone rosters (conditions per zone) land with the zones (Phase 7/8)
# — the `condition` field is already evaluated by the director.
class_name SpawnTable
extends Resource

const _ENTRY = preload("res://scripts/gameplay/enemies/spawn_entry.gd")

@export var entries: Array = []  # Array[SpawnEntry]


func validate() -> Array[String]:
	var problems: Array[String] = []
	if entries.is_empty():
		problems.append("a spawn table needs at least one entry")
	for e in entries:
		var entry: _ENTRY = e
		if entry == null:
			problems.append("null spawn entry")
			continue
		problems.append_array(entry.validate())
	return problems
