# RunGenerator — the procedural layout generator (TECHNICAL_DESIGN §6).
#
# Pure + deterministic: (master seed, world state, the area pool) ->
# one RunLayout. Per attempt (seed+1 on failure, max 8):
#   1. pick 1-3 rooms per area (weighted, no room_id repeat),
#   2. chain them (entry first, exit last) and resolve every doorway
#      to a concrete neighbour (shared anchors, ADR-003),
#   3. lay the rooms out in level-local world coordinates,
#   4. copy + place the area's enemy spawns (encounter stream),
#   5. VALIDATE (LayoutValidator, mandatory).
# After 8 failed attempts: the REFERENCE layout (fallback, logged).
#
# The DAG: camp (hub) -> zones -> undercroft (the ONLY sink). The
# camp, the zone entries and the boss arena are handcrafted;
# procedurality = room variants + connections + spawns + loot.
#
# Doorway anchor convention (fixed, data must follow it):
#   "camp_exit"   entry room -> back to the camp (its gate)
#   "to_chain"    entry room -> the first chain room (or sealed)
#   "door_a"      modular room -> previous room (or camp at head)
#   "door_b"      modular room -> next room / forward area (or sealed)
#   "entry_<src>" boss arena -> back to the source's last room
class_name RunGenerator
extends RefCounted

const _AREA = preload("res://scripts/gameplay/areas/area_data.gd")
const _CONN = preload("res://scripts/gameplay/areas/area_connection.gd")
const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _DW = preload("res://scripts/gameplay/rooms/doorway_def.gd")
const _RNG = preload("res://scripts/gameplay/rooms/rng_streams.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")
const _VAL = preload("res://scripts/gameplay/rooms/layout_validator.gd")
const _SE = preload("res://scripts/gameplay/enemies/spawn_entry.gd")

const HUB_ID: StringName = &"camp"
const BOSS_ID: StringName = &"undercroft"
const MAX_ATTEMPTS: int = 8
const DOOR_GAP: float = 1.2  # the corridor between chained rooms

var areas: Dictionary = {}  # id -> AreaData
var hub: _AREA
var boss: _AREA


func set_pool(pool: Dictionary) -> void:
	areas = pool
	hub = pool.get(HUB_ID, null)
	boss = pool.get(BOSS_ID, null)


func area_ids_sorted() -> Array:
	var ids: Array = areas.keys()
	ids.sort()
	return ids


# The public entry: deterministic under (seed, world state).
func generate(seed: int, ws: Dictionary) -> _RL:
	for attempt in range(MAX_ATTEMPTS):
		var streams: _RNG = _RNG.new()
		streams.setup(seed)
		var layout: _RL = _attempt(streams, ws)
		var problems: Array[String] = _VAL.validate(layout, ws, areas)
		if problems.is_empty():
			return layout
		push_warning("RunGenerator: attempt %d (seed %d) failed: %s"
				% [attempt, seed, "; ".join(problems)])
	var fallback: _RL = _reference_layout()
	fallback.fallback_used = true
	push_warning("RunGenerator: %d attempts failed, using the reference "
			+ "layout (seed %d)" % [MAX_ATTEMPTS, seed])
	return fallback


# --- one attempt -----------------------------------------------------

func _attempt(streams: _RNG, ws: Dictionary) -> _RL:
	var layout: _RL = _RL.new()
	var ids: Array = area_ids_sorted()
	# All areas except the boss, then the boss (its doors point at
	# the sources' chains, which must exist first).
	for id in ids:
		if id == BOSS_ID:
			continue
		if id == HUB_ID:
			layout.areas[id] = _layout_hub(areas[id])
		else:
			layout.areas[id] = _layout_area(areas[id], streams, ws)
	if areas.has(BOSS_ID):
		layout.areas[BOSS_ID] = _layout_boss(areas[BOSS_ID], layout, ws)
	_layout_world(layout)
	_assign_spawns(layout, streams)
	return layout


# The hub: a single handcrafted room; its gate doors resolve to the
# connected zone's entry (via the camp's connections); a gate with
# no connection (gate_undercroft) stays sealed (ADR-016).
func _layout_hub(a: _AREA) -> _AP:
	var placement: _AP = _AP.new()
	placement.area = a
	var room: _ROOM = a.rooms[0]
	var rp: _RP = _RP.new()
	rp.room = room
	rp.index_in_chain = 0
	var by_door: Dictionary = {}
	for c in a.connections:
		var cc: _CONN = c
		by_door[cc.door] = cc
	for d in room.doorways:
		var dd: _DW = d
		var rd: _RD = _RD.new()
		rd.anchor = dd.anchor
		rd.local_pos = dd.local_pos
		rd.facing = dd.facing
		if by_door.has(dd.anchor):
			var cc: _CONN = by_door[dd.anchor]
			rd.to_area = cc.to
			rd.to_anchor = cc.target_door
		rp.doors.append(rd)
	placement.rooms.append(rp)
	return placement


# Pick the chain + resolve its doors (room-local; world later).
func _layout_area(a: _AREA, streams: _RNG, ws: Dictionary) -> _AP:
	var placement: _AP = _AP.new()
	placement.area = a
	var chain: Array = [a.rooms[0]]
	if not a.boss_arena:
		chain.append_array(_pick_chain_rooms(a, streams))
	var last_forward: _CONN = _first_open_connection(a, ws)
	for i in range(chain.size()):
		var room: _ROOM = chain[i]
		var rp: _RP = _RP.new()
		rp.room = room
		rp.index_in_chain = i
		for d in room.doorways:
			var dd: _DW = d
			var rd: _RD = _RD.new()
			rd.anchor = dd.anchor
			rd.local_pos = dd.local_pos
			rd.facing = dd.facing
			if dd.anchor == &"camp_exit":
				rd.to_area = HUB_ID
				rd.to_anchor = _gate_anchor(a.id)
			elif dd.anchor == &"to_chain" and i + 1 < chain.size():
				rd.to_room = chain[i + 1].id
				rd.to_anchor = &"door_a"
			elif dd.anchor == &"to_chain" and i == chain.size() - 1 \
					and last_forward != null:
				rd.to_area = last_forward.to
				rd.to_anchor = last_forward.target_door
			elif dd.anchor == &"door_a":
				if i > 0:
					rd.to_room = chain[i - 1].id
					rd.to_anchor = _exit_anchor(chain[i - 1])
				else:
					rd.to_area = HUB_ID
					rd.to_anchor = _gate_anchor(a.id)
			elif dd.anchor == &"door_b":
				if i + 1 < chain.size():
					rd.to_room = chain[i + 1].id
					rd.to_anchor = &"door_a"
				elif i == chain.size() - 1 and last_forward != null:
					rd.to_area = last_forward.to
					rd.to_anchor = last_forward.target_door
			# Anything else (a junction's third door) stays sealed.
			rp.doors.append(rd)
		placement.rooms.append(rp)
	return placement


# The boss arena: a handcrafted single room; each entry_<src> door
# points back at the source's last room (sealed when the source's
# edge is closed in the world state).
func _layout_boss(a: _AREA, layout: _RL, ws: Dictionary) -> _AP:
	var placement: _AP = _AP.new()
	placement.area = a
	var room: _ROOM = a.rooms[0]
	var rp: _RP = _RP.new()
	rp.room = room
	rp.index_in_chain = 0
	for d in room.doorways:
		var dd: _DW = d
		var rd: _RD = _RD.new()
		rd.anchor = dd.anchor
		rd.local_pos = dd.local_pos
		rd.facing = dd.facing
		# The boss has NO exit to camp (the seal holds — ADR-016).
		if String(dd.anchor).begins_with("entry_"):
			var src: _AREA = _source_for(a, dd.anchor, ws, layout)
			if src != null:
				var last: _RP = layout.get_area(src.id).rooms.back()
				rd.to_room = last.room.id
				rd.to_room_area = src.id
				rd.to_anchor = _exit_anchor(last.room)
		rp.doors.append(rd)
	placement.rooms.append(rp)
	return placement


func _source_for(b: _AREA, anchor: StringName, ws: Dictionary,
		layout: _RL) -> _AREA:
	# The source area whose connection targets this boss door and
	# whose edge is open in the current world state (data order).
	for id in area_ids_sorted():
		var a: _AREA = areas[id]
		for c in a.connections:
			var cc: _CONN = c
			if cc.to == b.id and cc.target_door == anchor \
					and _cond_open(cc.condition, ws) \
					and layout.has_area(a.id):
				return a
	return null


# Lay the chain out in level-local coordinates along -Z: the entry
# at the origin, centers spaced by (prev.depth/2 + gap + cur.depth/2)
# so the shared doorways (door_b <-> door_a) line up exactly.
func _layout_world(layout: _RL) -> void:
	for id in layout.areas:
		var a: _AP = layout.areas[id]
		var z: float = 0.0
		var prev_depth: float = 0.0
		for r in a.rooms:
			var rp: _RP = r
			if rp.index_in_chain > 0:
				z -= prev_depth * 0.5 + DOOR_GAP + rp.room.size.y * 0.5
			rp.origin = Vector3(0.0, 0.0, z)
			prev_depth = rp.room.size.y


# The world position of a doorway (scene + nav use it).
func door_world(layout: _RL, area_id: StringName, room_id: StringName,
		anchor: StringName) -> Vector3:
	var rp: _RP = layout.find_room(area_id, room_id)
	if rp == null:
		return Vector3.INF
	var d: _RD = rp.door(anchor)
	if d == null:
		return Vector3.INF
	return rp.origin + d.local_pos


static func _gate_anchor(zone_id: StringName) -> StringName:
	return StringName("gate_" + zone_id)


# The anchor of a room's door that leads OUT (toward the next room).
static func _exit_anchor(room: _ROOM) -> StringName:
	if _has_door(room, &"door_b"):
		return &"door_b"
	return &"to_chain"


static func _has_door(room: _ROOM, anchor: StringName) -> bool:
	for d in room.doorways:
		if (d as _DW).anchor == anchor:
			return true
	return false


func _weight(a: _AREA, idx: int) -> float:
	if a.room_weights.size() == a.rooms.size():
		return a.room_weights[idx]
	return 1.0


# Pick up to 2 chain rooms: group the pool by ROOM ID (its variants
# share the id, ADR-003), sample ids without repeat (weighted), then
# the variant of each picked id (world stream).
func _pick_chain_rooms(a: _AREA, streams: _RNG) -> Array:
	var group_order: Array = []
	var groups: Dictionary = {}
	for i in range(1, a.rooms.size()):
		var r: _ROOM = a.rooms[i]
		if not groups.has(r.id):
			groups[r.id] = {"rooms": [], "weight": 0.0}
			group_order.append(r.id)
		groups[r.id].rooms.append(r)
		groups[r.id].weight += _weight(a, i)
	var id_list: Array = []
	var id_weights: PackedFloat64Array = PackedFloat64Array()
	for gid in group_order:
		id_list.append(gid)
		id_weights.append(groups[gid].weight)
	var out: Array = []
	var picked: Array = _weighted_sample(id_list, id_weights,
			streams.world, 2)
	for gid in picked:
		var vars: Array = groups[gid].rooms
		out.append(vars[streams.world.randi_range(0, vars.size() - 1)])
	return out


# Weighted sample WITHOUT replacement (deterministic under the rng).
func _weighted_sample(pool: Array, weights: PackedFloat64Array,
		rng: RandomNumberGenerator, max_n: int) -> Array:
	var idxs: Array = []
	for i in range(pool.size()):
		idxs.append(i)
	var out: Array = []
	var want: int = mini(max_n, idxs.size())
	for k in range(want):
		if idxs.size() <= 1:
			out.append(pool[idxs[0]])
			idxs.clear()
			break
		var total: float = 0.0
		for i in idxs:
			total += weights[i]
		var roll: float = rng.randf() * total
		var acc: float = 0.0
		var chosen_pos: int = idxs.size() - 1
		for p in range(idxs.size()):
			acc += weights[idxs[p]]
			if roll < acc:
				chosen_pos = p
				break
		out.append(pool[idxs[chosen_pos]])
		idxs.remove_at(chosen_pos)
	return out


func _first_open_connection(a: _AREA, ws: Dictionary) -> _CONN:
	for c in a.connections:
		var cc: _CONN = c
		if _cond_open(cc.condition, ws) and areas.has(cc.to):
			return cc
	return null


static func _cond_open(cond: StringName, ws: Dictionary) -> bool:
	if cond == &"":
		return true
	return ws.get(cond, false) == true


# --- enemy spawns (encounter stream) ---------------------------------
# Copies of the area's table entries (the .tres resources stay
# immutable) placed onto the chain's enemy spots. The director
# re-evaluates conditions at start() — the generator only positions.
func _assign_spawns(layout: _RL, streams: _RNG) -> void:
	var encounter: RandomNumberGenerator = streams.encounter
	for id in area_ids_sorted():
		var a: _AP = layout.areas[id]
		if a.area.spawn_table == null:
			continue
		var spots_rooms: Array = []
		for r in a.rooms:
			if (r as _RP).room.enemy_spots.size() > 0:
				spots_rooms.append(r)
		if spots_rooms.is_empty():
			continue
		var si: int = 0
		for e in a.area.spawn_table.entries:
			var entry: _SE = e
			var c: _SE = entry.duplicate() as _SE
			var room: _RP = spots_rooms[si % spots_rooms.size()]
			si += 1
			var idx: int = encounter.randi_range(
					0, room.room.enemy_spots.size() - 1)
			c.position = room.origin + room.room.enemy_spots[idx]
			c.area = id
			layout.spawns.append(c)


# --- the fallback -----------------------------------------------------

# The reference layout (TECHNICAL_DESIGN §6): entry + the first
# modular room of the pool (as listed), forward doors open, no RNG.
# Deterministic and always valid — the log says it was used.
func _reference_layout() -> _RL:
	var ws: Dictionary = _all_open()
	var layout: _RL = _RL.new()
	var ids: Array = area_ids_sorted()
	for id in ids:
		if id == BOSS_ID:
			continue
		if id == HUB_ID:
			layout.areas[id] = _layout_hub(areas[id])
			continue
		var a: _AREA = areas[id]
		var placement: _AP = _AP.new()
		placement.area = a
		var chain: Array = [a.rooms[0]]
		if not a.boss_arena and a.rooms.size() > 1:
			chain.append(a.rooms[1])
		var last_forward: _CONN = _first_open_connection(a, ws)
		for i in range(chain.size()):
			var room: _ROOM = chain[i]
			var rp: _RP = _RP.new()
			rp.room = room
			rp.index_in_chain = i
			for d in room.doorways:
				var dd: _DW = d
				var rd: _RD = _RD.new()
				rd.anchor = dd.anchor
				rd.local_pos = dd.local_pos
				rd.facing = dd.facing
				if dd.anchor == &"camp_exit":
					rd.to_area = HUB_ID
					rd.to_anchor = _gate_anchor(a.id)
				elif dd.anchor == &"to_chain" and i + 1 < chain.size():
					rd.to_room = chain[i + 1].id
					rd.to_anchor = &"door_a"
				elif dd.anchor == &"to_chain" and i == chain.size() - 1 \
						and last_forward != null:
					rd.to_area = last_forward.to
					rd.to_anchor = last_forward.target_door
				elif dd.anchor == &"door_a":
					if i > 0:
						rd.to_room = chain[i - 1].id
						rd.to_anchor = _exit_anchor(chain[i - 1])
					else:
						rd.to_area = HUB_ID
						rd.to_anchor = _gate_anchor(a.id)
				elif dd.anchor == &"door_b":
					if i + 1 < chain.size():
						rd.to_room = chain[i + 1].id
						rd.to_anchor = &"door_a"
					elif i == chain.size() - 1 and last_forward != null:
						rd.to_area = last_forward.to
						rd.to_anchor = last_forward.target_door
				rp.doors.append(rd)
			placement.rooms.append(rp)
		layout.areas[id] = placement
	if areas.has(BOSS_ID):
		layout.areas[BOSS_ID] = _layout_boss(areas[BOSS_ID], layout, ws)
	_layout_world(layout)
	return layout


func _all_open() -> Dictionary:
	var ws: Dictionary = {}
	for c in areas.values():
		var a: _AREA = c
		for cc in a.connections:
			ws[(cc as _CONN).condition] = true
	return ws
