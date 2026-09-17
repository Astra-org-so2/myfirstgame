# AreaData — one location (TECHNICAL_DESIGN §1): the room set +
# weights + the graph edges (area connections).
#
# The DAG (TECHNICAL_DESIGN §6): camp (hub) -> zones -> boss arena
# (the ONLY sink). `connections` are the FORWARD edges (an exit back
# to camp is implicit: every zone can return home — that is
# navigation, not layout: the validator checks the forward DAG).
# A connection's `condition` is a WorldState flag name ("" = always)
# — world-state can open a new edge (a shortcut) without a new graph
# (TECHNICAL_DESIGN §6 item 1).
class_name AreaData
extends Resource

const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _CONN = preload("res://scripts/gameplay/areas/area_connection.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")

@export var id: StringName = &""
@export var name: String = ""
@export var theme: String = ""  # the zone's one theme (ENV §1.3)
# The room pool (1-3 are picked per layout, weighted, no room_id
# repeat inside the area — ADR-003 / TECHNICAL_DESIGN §6).
# rooms[0] is the handcrafted entry (always in the chain).
@export var rooms: Array = []  # Array[RoomData]
@export var room_weights: PackedFloat64Array = PackedFloat64Array()
# Forward edges (see class doc).
@export var connections: Array = []  # Array[AreaConnection]
# The enemy spawn table (positions are filled by the generator; the
# director evaluates the conditions at start).
@export var spawn_table: _TABLE
@export var boss_arena: bool = false
@export var entry_anchor: StringName = &"entry"
# The fog/light default for the area's rooms (a room may override).
@export var fog_density: float = 0.8
@export var light_color: Color = Color(0.55, 0.6, 0.55)


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("area id must be set")
	if name == "":
		problems.append("area name must be set")
	if rooms.size() < 1:
		problems.append("an area needs >= 1 room")
	if room_weights.size() != 0 and room_weights.size() != rooms.size():
		problems.append("room_weights must be empty or match rooms")
	# NOTE: the pool lists a room's variants as several entries with
	# the SAME id (that is the variant pool, ADR-003) — the no-repeat
	# rule applies to the SELECTED chain (generator), not the pool.
	for r in rooms:
		var d: _ROOM = r
		problems.append_array(d.validate())
		if not d.areas.has(id):
			problems.append("room %s does not fit area %s" % [d.id, id])
	for c in connections:
		var cc: _CONN = c
		problems.append_array(cc.validate())
	return problems
