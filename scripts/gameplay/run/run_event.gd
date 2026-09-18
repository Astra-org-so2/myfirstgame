# RunEvent — one compact event of a run recording (TECHNICAL_DESIGN §2).
#
# Binary form (14 bytes): t int32 (deciseconds), type u8, room u8
# (RoomData index, 0 = outside rooms), x/y/z int16 (room-local cm,
# clamped to ±327 m), ry u8 (0..359), target u16, data u8. JSON form:
# the compact array [t, type, room, x, y, z, ry, target, data].
#
# Positions are in the run's OWN layout space: the layout regenerates
# every run, so a ghost of run N replays against the layout generated
# from run N's seed (the record carries it). `room` is the current
# level's entry-room index (0 = the entry room / outside rooms) — an
# MVP approximation the ghost phase refines.
class_name RunEvent
extends RefCounted

# TECHNICAL_DESIGN §2 event types (numeric values are stable for the
# save format).
enum Type {
	ENTER_ROOM = 0,
	ATTACK = 1,
	ATTACK_HIT = 2,
	ENEMY_KILLED = 3,
	CHEST_OPENED = 4,
	ITEM_PICKED = 5,
	ITEM_DROPPED = 6,
	NPC_TALKED = 7,
	NPC_KILLED = 8,
	EVENT_COMPLETED = 9,
	CHOICE_MADE = 10,
	PLAYER_DIED = 11,
	PLAYER_SPAWNED = 12,
	GHOST_WATCHED = 13,
	NOTE_WRITTEN = 14,
	ANCHOR_SET = 15,
	ECHO_TRIGGER = 16,
	ECHO_NOTE_READ = 17,
	MUMMY_EXAMINED = 18,
}

# int16 room-local cm bounds (±327 m).
const COORD_CLAMP_CM: int = 32700

var t: int = 0
var type: int = Type.ENTER_ROOM
var room: int = 0
var x: int = 0
var y: int = 0
var z: int = 0
var ry: int = 0
var target: int = 0
var data: int = 0


static func type_name(v: int) -> String:
	var names := {
		Type.ENTER_ROOM: "ENTER_ROOM", Type.ATTACK: "ATTACK",
		Type.ATTACK_HIT: "ATTACK_HIT", Type.ENEMY_KILLED: "ENEMY_KILLED",
		Type.CHEST_OPENED: "CHEST_OPENED", Type.ITEM_PICKED: "ITEM_PICKED",
		Type.ITEM_DROPPED: "ITEM_DROPPED", Type.NPC_TALKED: "NPC_TALKED",
		Type.NPC_KILLED: "NPC_KILLED", Type.EVENT_COMPLETED: "EVENT_COMPLETED",
		Type.CHOICE_MADE: "CHOICE_MADE", Type.PLAYER_DIED: "PLAYER_DIED",
		Type.PLAYER_SPAWNED: "PLAYER_SPAWNED", Type.GHOST_WATCHED: "GHOST_WATCHED",
		Type.NOTE_WRITTEN: "NOTE_WRITTEN", Type.ANCHOR_SET: "ANCHOR_SET",
		Type.ECHO_TRIGGER: "ECHO_TRIGGER", Type.ECHO_NOTE_READ: "ECHO_NOTE_READ",
		Type.MUMMY_EXAMINED: "MUMMY_EXAMINED",
	}
	return names.get(v, "UNKNOWN_%d" % v)


static func clamp_coord(cm: int) -> int:
	return clampi(cm, -COORD_CLAMP_CM, COORD_CLAMP_CM)


static func clamp_deg(deg: int) -> int:
	return ((deg % 360) + 360) % 360


func to_array() -> Array:
	# [t, type, room, x, y, z, ry, target, data] — compact JSON row.
	return [t, type, room, x, y, z, ry, target, data]


# Loads a 9-field row (returns false on malformed input — the caller
# keeps the empty event).
func load_array(a: Array) -> bool:
	if a.size() != 9:
		push_error("RunEvent.load_array: expected 9 fields, got %d" % a.size())
		return false
	# The loader normalizes (corrupt-save defense): out-of-range values
	# are clamped to the binary form's bounds, not trusted.
	t = maxi(0, int(a[0]))
	type = int(a[1])
	room = clampi(int(a[2]), 0, 255)
	x = clamp_coord(int(a[3]))
	y = clamp_coord(int(a[4]))
	z = clamp_coord(int(a[5]))
	ry = clamp_deg(int(a[6]))
	target = clampi(int(a[7]), 0, 65535)
	data = clampi(int(a[8]), 0, 255)
	return true
