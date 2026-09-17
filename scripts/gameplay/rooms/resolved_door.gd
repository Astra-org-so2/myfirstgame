# ResolvedDoor — one doorway of a placed room, resolved to a
# concrete neighbour (TECHNICAL_DESIGN §6). Pure data (RefCounted):
# the RunLayout holds these; the scene builds transitions from them.
class_name ResolvedDoor
extends RefCounted

var anchor: StringName = &""
var local_pos: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3(0.0, 0.0, -1.0)
# The destination: same run (to_room != "") or the entry room of
# another area (to_area != ""). Both "" = sealed door (a design
# choice — valid, the ghost maps it, ADR-003).
var to_room: StringName = &""
# Which area the target ROOM lives in (cross-area: the boss arena's
# entry doors point at the source's last room; default = same area).
var to_room_area: StringName = &""
var to_anchor: StringName = &""
# Another AREA's entry room ("" = the destination is a room, above).
var to_area: StringName = &""


func is_sealed() -> bool:
	return to_room == &"" and to_area == &""
