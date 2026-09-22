# LayoutValidator — the mandatory pre-run validation (TECHNICAL_DESIGN
# §6). Pure: (layout, world state, area pool) -> problems (empty = OK).
#
# Checks:
#   1. the hub and the boss exist; the boss is the ONLY sink
#      (no forward edges out of it),
#   2. every doorway resolves to an existing room/anchor (or is a
#      deliberately sealed door — valid, the ghost maps it),
#   3. reachability: BFS from the camp over OPEN doors — every
#      non-boss area is reachable; the boss is reachable IFF its
#      source edge is open (a sealed undercroft is a valid state,
#      ADR-016; it is the ONE exempt area),
#   4. no isolated areas (the boss is exempt, see 3),
#   5. geometry: every room's spawn/loot/event spots inside its
#      footprint, not in an obstacle, not blocking a doorway
#      (the headless GEOMETRIC probe — no physics server in the rig,
#      ADR-002; the real engine checks the same points against the
#      collision mesh),
#   6. difficulty monotonicity: the boss's only incoming edges come
#      from reachable areas (no boss shortcut from the hub),
#   7. no-filler defense in depth: every placed room has >= 1 of the
#      five fields set (GDD §9).
class_name LayoutValidator
extends RefCounted

const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _OB = preload("res://scripts/gameplay/rooms/obstacle_box.gd")
const _DW = preload("res://scripts/gameplay/rooms/doorway_def.gd")
const _GEN = preload("res://scripts/gameplay/rooms/run_generator.gd")


static func validate(layout: _RL, ws: Dictionary,
		areas: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	if layout == null:
		problems.append("layout is null")
		return problems
	if not layout.has_area(_GEN.HUB_ID):
		problems.append("the hub (camp) is missing")
		return problems
	if not layout.has_area(_GEN.BOSS_ID):
		problems.append("the boss arena (undercroft) is missing")

	# --- 2. every doorway resolves ---------------------------------
	for id in layout.areas:
		var a: _AP = layout.areas[id]
		for r in a.rooms:
			var rp: _RP = r
			for d in rp.doors:
				var rd: _RD = d
				if rd.is_sealed():
					continue
				if rd.to_room != &"":
					var in_area: StringName = \
							rd.to_room_area if rd.to_room_area != &"" else id
					var tr: _RP = layout.find_room(in_area, rd.to_room)
					if tr == null:
						problems.append(
								"door %s in %s: target room %s not placed"
								% [rd.anchor, rp.room.id, rd.to_room])
					elif tr.door(rd.to_anchor) == null:
						problems.append(
								"door %s in %s: target %s has no anchor %s"
								% [rd.anchor, rp.room.id, rd.to_room,
										rd.to_anchor])
				elif rd.to_area != &"":
					if not layout.has_area(rd.to_area):
						problems.append(
								"door %s in %s: target area %s not in the "
								+ "layout" % [rd.anchor, rp.room.id, rd.to_area])
					else:
						var t: _AP = layout.areas[rd.to_area]
						if t.rooms.is_empty():
							problems.append(
									"door %s: target area %s has no rooms"
									% [rd.anchor, rd.to_area])
						else:
							var entry: _RP = t.rooms[0]
							if entry.door(rd.to_anchor) == null:
								problems.append(
										"door %s in %s: area %s entry has no "
										+ "anchor %s"
										% [rd.anchor, rp.room.id, rd.to_area,
												rd.to_anchor])

	# --- 3. reachability (BFS over open doors) ----------------------
	var open_map: Dictionary = _open_doors(layout)
	var visited: Dictionary = {}
	var queue: Array = [_GEN.HUB_ID]
	visited[_GEN.HUB_ID] = true
	while queue.size() > 0:
		var cur: StringName = queue[queue.size() - 1]
		queue.pop_back()
		var a: _AP = layout.areas[cur]
		for r in a.rooms:
			var rp: _RP = r
			for d in rp.doors:
				var rd: _RD = d
				if rd.to_area == &"" or rd.to_area == cur:
					continue
				if not _door_open(open_map, cur, rp, rd):
					continue
				if not visited.has(rd.to_area):
					visited[rd.to_area] = true
					queue.append(rd.to_area)
	# Every non-boss area must be reachable from the hub.
	for id in layout.areas:
		if id == _GEN.BOSS_ID:
			continue
		if not visited.has(id):
			problems.append("area %s is unreachable from the camp" % id)
	# The boss: reachable IFF a source edge is open.
	var boss_expected: bool = false
	for id in layout.areas:
		var a2: _AP = layout.areas[id]
		for r2 in a2.rooms:
			var rp2: _RP = r2
			for d2 in rp2.doors:
				var rd2: _RD = d2
				if rd2.to_area == _GEN.BOSS_ID \
						and _door_open(open_map, id, rp2, rd2):
					boss_expected = true
	if boss_expected and not visited.has(_GEN.BOSS_ID):
		problems.append("the boss arena is not reachable via an open edge")

	# --- 4. no isolates (the boss is exempt) ------------------------
	for id in layout.areas:
		if id == _GEN.BOSS_ID:
			continue
		var a3: _AP = layout.areas[id]
		var any_open: bool = false
		for r3 in a3.rooms:
			var rp3: _RP = r3
			for d3 in rp3.doors:
				if _door_open(open_map, id, rp3, d3):
					any_open = true
					break
			if any_open:
				break
		if not any_open:
			problems.append("area %s has no open doorway" % id)

	# --- 5. geometry (the headless geometric spawn probe) -----------
	for id in layout.areas:
		var a4: _AP = layout.areas[id]
		for r4 in a4.rooms:
			problems.append_array(_probe_room(r4 as _RP))

	# --- 6. difficulty monotonicity ---------------------------------
	var boss: _AP = layout.areas.get(_GEN.BOSS_ID, null)
	if boss != null:
		for r5 in boss.rooms:
			var rp5: _RP = r5
			for d5 in rp5.doors:
				var rd5: _RD = d5
				# The boss has NO forward edge (it is the only sink).
				if rd5.to_area != &"":
					problems.append("the boss arena has an exit edge "
							+ "(it must be the only sink)")
	var incoming: Dictionary = {}
	for id in layout.areas:
		var a5: _AP = layout.areas[id]
		for r6 in a5.rooms:
			var rp6: _RP = r6
			for d6 in rp6.doors:
				var rd6: _RD = d6
				if rd6.to_area == _GEN.BOSS_ID and id != _GEN.BOSS_ID:
					incoming[id] = true
	if incoming.has(_GEN.HUB_ID):
		problems.append("the boss arena is reachable directly from the "
				+ "camp (difficulty shortcut)")
	for src in incoming:
		if not visited.has(src):
			problems.append("boss source %s is itself unreachable" % src)

	# --- 7. no-filler defense in depth ------------------------------
	for id in layout.areas:
		var a6: _AP = layout.areas[id]
		for r7 in a6.rooms:
			if (r7 as _RP).room.no_filler_count() < 1:
				problems.append("room %s fails the no-filler checklist"
						% (r7 as _RP).room.id)
	return problems


# --- helpers ---------------------------------------------------------

static func _door_open(open_map: Dictionary, area_id: StringName,
		rp: _RP, rd: _RD) -> bool:
	var key: String = "%s|%s|%s" % [area_id, rp.room.id, rd.anchor]
	return open_map.get(key, false)


# A door is open when its target exists in the layout (the world
# state already shaped WHICH edges the generator resolved open —
# sealed doors have no target).
static func _open_doors(layout: _RL) -> Dictionary:
	var out: Dictionary = {}
	for id in layout.areas:
		var a: _AP = layout.areas[id]
		for r in a.rooms:
			var rp: _RP = r
			for d in rp.doors:
				var rd: _RD = d
				var key: String = "%s|%s|%s" % [id, rp.room.id, rd.anchor]
				var open: bool = false
				if rd.to_room != "":
					var in_area: StringName = rd.to_room_area \
							if rd.to_room_area != "" else id
					var tr: _RP = layout.find_room(in_area, rd.to_room)
					open = tr != null and tr.door(rd.to_anchor) != null
				elif rd.to_area != "":
					if layout.has_area(rd.to_area):
						var t: _AP = layout.areas[rd.to_area]
						if not t.rooms.is_empty():
							open = (t.rooms[0] as _RP).door(rd.to_anchor) \
									!= null
				out[key] = open
	return out


static func _probe_room(rp: _RP) -> Array[String]:
	var problems: Array[String] = []
	var room: _ROOM = rp.room
	var half_x: float = room.size.x * 0.5
	var half_z: float = room.size.y * 0.5
	for s in room.enemy_spots:
		if not _inside(room, s, half_x, half_z):
			problems.append("%s: enemy spot %s outside/in obstacle"
					% [room.id, str(s)])
	for s in room.loot_spots:
		if not _inside(room, s, half_x, half_z):
			problems.append("%s: loot spot %s outside/in obstacle"
					% [room.id, str(s)])
	for s in room.event_spots:
		if not _inside(room, s, half_x, half_z):
			problems.append("%s: event spot %s outside/in obstacle"
					% [room.id, str(s)])
	return problems


static func _inside(room: _ROOM, p: Vector3,
		half_x: float, half_z: float) -> bool:
	if p.x < -half_x + 0.25 or p.x > half_x - 0.25 \
			or p.z < -half_z + 0.25 or p.z > half_z - 0.25:
		return false
	for o in room.obstacles:
		if (o as _OB).contains_point(p):
			return false
	for d in room.doorways:
		if p.distance_to((d as _DW).local_pos) < 0.85:
			return false
	return true
