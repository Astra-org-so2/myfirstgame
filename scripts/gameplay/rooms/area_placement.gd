# AreaPlacement — one area of the run: the picked rooms in chain
# order (entry first, exit last) with every doorway resolved.
class_name AreaPlacement
extends RefCounted

const _AREA = preload("res://scripts/gameplay/areas/area_data.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")

var area: _AREA
var rooms: Array = []  # Array[RoomPlacement], chain order


func room_at(idx: int) -> _RP:
	if idx < 0 or idx >= rooms.size():
		return null
	return rooms[idx]


func find(room_id: StringName) -> _RP:
	for r in rooms:
		var rp: _RP = r
		if rp.room.id == room_id:
			return rp
	return null
