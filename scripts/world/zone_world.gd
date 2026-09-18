# ZoneWorld — the level layer over the generated layout (Phase 7).
#
# Builds the current AREA's room chain from its AreaPlacement
# (RoomNode per room, the same data the validator probed), provides
# the level's NavData (room centers + doorway points — the director
# walks the chain), and detects WALK-THROUGH door crossings: the
# player physically passes the doorway gap and the trigger fires
# (distance + cooldown, no physics server in the rig — ADR-002).
#
# The camp is special: its visuals are CampWorld (Phase 3), so
# entering the camp level frees the zone visuals; the camp's gate
# doorways (layout) drive the SAME trigger path.
class_name ZoneWorld
extends Node3D

const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
const _ROOM_NODE = preload("res://scripts/world/room_node.gd")
const _NAV = preload("res://scripts/gameplay/enemies/nav_data.gd")

const CAMP_ID: StringName = &"camp"
const TRIGGER_RADIUS: float = 1.05
const SWITCH_COOLDOWN: float = 1.0

signal door_crossed(area_id: StringName, room_id: StringName,
		anchor: StringName)
# Emitted BEFORE the level's children are freed (Phase 8: the village
# NPC lives in the level and must be moved out, not deleted).
signal level_freed

var layout: _RL
var current: StringName = &""
var player: Node = null
var nav: _NAV = null
var level: Node3D
var _cooldown: float = SWITCH_COOLDOWN


func setup(run_layout: _RL) -> void:
	layout = run_layout
	level = Node3D.new()
	level.name = "Level"
	add_child(level)


func set_player(p: Node) -> void:
	player = p


# Switch the level to one area (builds visuals + nav). The camp
# level has no zone visuals (CampWorld is the camp's world).
func enter(area_id: StringName) -> void:
	_free_level()
	current = area_id
	nav = null
	if area_id == CAMP_ID:
		return
	var a: _AP = layout.get_area(area_id)
	if a == null:
		push_error("ZoneWorld: area %s not in the layout" % area_id)
		return
	for r in a.rooms:
		var rp: _RP = r
		var rn = _ROOM_NODE.new()
		rn.room = rp.room
		rn.resolved = rp.doors
		rn.position = rp.origin
		level.add_child(rn)  # _ready builds the visuals
	nav = _build_nav(a)
	_cooldown = SWITCH_COOLDOWN


func is_camp() -> bool:
	return current == CAMP_ID


func rooms() -> Array:
	var a: _AP = layout.get_area(current)
	if a == null:
		return []
	return a.rooms


func door_world(room_id: StringName, anchor: StringName) -> Vector3:
	for r in rooms():
		var rp: _RP = r
		if rp.room.id != room_id:
			continue
		var d: _RD = rp.door(anchor)
		if d != null:
			return rp.origin + d.local_pos
	return Vector3.INF


func _free_level() -> void:
	if level == null:
		return
	level_freed.emit()
	# Immediate free (not queue_free): a level switch must leave no
	# node behind — the old level's pickups must be gone the moment
	# the new level is in.
	for c in level.get_children():
		c.free()
	nav = null


func _build_nav(a: _AP) -> _NAV:
	var nodes: PackedVector3Array = PackedVector3Array()
	var edges: PackedInt32Array = PackedInt32Array()
	var center_idx: Dictionary = {}
	for r in a.rooms:
		var rp: _RP = r
		var ci: int = nodes.size()
		nodes.append(Vector3(rp.origin.x, 0.0, rp.origin.z))
		center_idx[rp.room.id] = ci
		for d in rp.doors:
			var rd: _RD = d
			if rd.is_sealed():
				continue
			var pi: int = nodes.size()
			nodes.append(Vector3(rp.origin.x + rd.local_pos.x, 0.0,
					rp.origin.z + rd.local_pos.z))
			edges.append(ci)
			edges.append(pi)
	var data: _NAV = _NAV.new()
	data.nodes = nodes
	data.edges = edges
	return data


func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if layout == null or player == null or current == &"":
		return
	if _cooldown > 0.0:
		return
	var a: _AP = layout.get_area(current)
	if a == null:
		return
	var ppos: Vector3 = player.get_body_position()
	for r in a.rooms:
		var rp: _RP = r
		for d in rp.doors:
			var rd: _RD = d
			if rd.is_sealed():
				continue
			var wp: Vector3 = rp.origin + rd.local_pos
			if ppos.distance_to(wp) < TRIGGER_RADIUS:
				_cooldown = SWITCH_COOLDOWN
				door_crossed.emit(current, rp.room.id, rd.anchor)
				return
