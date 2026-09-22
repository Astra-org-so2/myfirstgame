# RunLayout — the generated layout of ONE run (TECHNICAL_DESIGN §6).
#
# Pure data (no Nodes): per area — the picked rooms (chain order:
# entry first, exit last) with every doorway RESOLVED to a concrete
# neighbour. The scene builds from this; the ghost maps room_id ->
# variant later (Phase 9, ADR-003). Deterministic under
# (master seed, world state).
class_name RunLayout
extends RefCounted

const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _SE = preload("res://scripts/gameplay/enemies/spawn_entry.gd")

var areas: Dictionary = {}  # area id -> AreaPlacement
# Enemy spawns of the run (COPIES of the area tables' entries with
# positions filled by the generator; the .tres data stays immutable).
var spawns: Array = []  # Array[SpawnEntry]
var fallback_used: bool = false


func has_area(area_id: StringName) -> bool:
	return areas.has(area_id)


func get_area(area_id: StringName) -> _AP:
	return areas.get(area_id, null)


func room_count() -> int:
	var n: int = 0
	for id in areas:
		n += (areas[id] as _AP).rooms.size()
	return n


# The chain (entry -> exit) room ids of an area.
func chain_of(area_id: StringName) -> Array:
	var out: Array = []
	var a: _AP = areas.get(area_id, null)
	if a == null:
		return out
	for r in a.rooms:
		out.append((r as _RP).room.id)
	return out


func find_room(area_id: StringName, room_id: StringName) -> _RP:
	var a: _AP = areas.get(area_id, null)
	if a == null:
		return null
	return a.find(room_id)
