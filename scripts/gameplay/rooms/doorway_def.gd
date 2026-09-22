# DoorwayDef — one doorway of a room (TECHNICAL_DESIGN §1, ADR-003).
#
# The doorway ANCHORS (anchor/local_pos/facing) are IDENTICAL across
# all variants of a room — the geometry is stable, only the interior
# changes (ghost-replay consistency, ADR-003). `target_area` +
# `target_anchor` name the edge: this doorway leads to that area's
# room whose ENTRY anchor matches (the generator resolves the pair).
class_name DoorwayDef
extends Resource

@export var anchor: StringName = &""
@export var local_pos: Vector3 = Vector3.ZERO
@export var facing: Vector3 = Vector3(0.0, 0.0, -1.0)
# "" = no destination (a sealed/one-way doorway).
@export var target_area: StringName = &""
@export var target_anchor: StringName = &""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if anchor == &"":
		problems.append("doorway anchor must be set")
	if facing.length_squared() < 0.5 or facing.length_squared() > 1.5:
		problems.append("doorway facing must be ~normalized")
	if (target_area == &"" and target_anchor != &"") \
			or (target_area != &"" and target_anchor == &""):
		problems.append("target_area and target_anchor are a pair")
	return problems
