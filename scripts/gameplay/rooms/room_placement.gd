# RoomPlacement — one picked room of one area, with its doors
# resolved and its level-local origin (TECHNICAL_DESIGN §6).
class_name RoomPlacement
extends RefCounted

const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")

var room: _ROOM
var index_in_chain: int = 0
# The room's center in level-local coordinates; doorway world
# position = origin + ResolvedDoor.local_pos.
var origin: Vector3 = Vector3.ZERO
var doors: Array = []  # Array[ResolvedDoor], same order as room.doorways


func door(anchor: StringName) -> _RD:
	for d in doors:
		var rd: _RD = d
		if rd.anchor == anchor:
			return rd
	return null
