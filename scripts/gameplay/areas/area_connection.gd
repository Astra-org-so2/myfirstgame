# AreaConnection — one forward edge of the area DAG.
#
# `door` = the doorway ANCHOR in the source area's ENTRY room that
# leads here; `condition` = a WorldState flag name ("" = always open)
# — a world change can open a new edge without a new graph.
class_name AreaConnection
extends Resource

@export var to: StringName = &""
@export var door: StringName = &""
# The doorway anchor on the TARGET side (default "entry"; the boss
# arena has one per source: "entry_mine", "entry_gate").
@export var target_door: StringName = &"entry"
@export var condition: StringName = &""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if to == &"":
		problems.append("connection target must be set")
	if door == &"":
		problems.append("connection door anchor must be set")
	return problems
