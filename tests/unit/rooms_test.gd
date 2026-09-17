# Unit: Phase 7 procedural rooms — the pure core (TECHNICAL_DESIGN §6).
# RngStreams, data integrity (ADR-003, no-filler), the generator
# (determinism A/B/A', the 100-seed exit criterion, world state,
# fallback) and the validator's negative paths.
extends Node

const _RNG = preload("res://scripts/gameplay/rooms/rng_streams.gd")
const _GEN = preload("res://scripts/gameplay/rooms/run_generator.gd")
const _VAL = preload("res://scripts/gameplay/rooms/layout_validator.gd")
const _RL = preload("res://scripts/gameplay/rooms/run_layout.gd")
const _AP = preload("res://scripts/gameplay/rooms/area_placement.gd")
const _RP = preload("res://scripts/gameplay/rooms/room_placement.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _DW = preload("res://scripts/gameplay/rooms/doorway_def.gd")
const _OB = preload("res://scripts/gameplay/rooms/obstacle_box.gd")
const _AREA = preload("res://scripts/gameplay/areas/area_data.gd")

const AREA_FILES := [
	"camp", "ruined_village", "watchtower", "the_mine", "old_shrine",
	"broken_bridge", "mysterious_lake", "ancient_gate", "undercroft",
]
const MODULAR_IDS := [
	&"corridor_forest", &"junction_cross", &"junction_t", &"room_combat",
	&"room_loot", &"room_mystery", &"room_note", &"room_shelter",
	&"corridor_stairs", &"corridor_bridge", &"room_echo", &"room_archive",
	&"room_boneyard",
]


func run(ctx: Variant) -> void:
	_rng_streams(ctx)
	_data_integrity(ctx)
	var pool: Dictionary = _pool()
	if pool.is_empty():
		ctx.check(false, "generator: area pool failed to load")
		return
	_generator(ctx, pool)


# --- RngStreams: deterministic + independent -------------------------

func _rng_streams(ctx: Variant) -> void:
	var a: _RNG = _RNG.new()
	a.setup(12345)
	var b: _RNG = _RNG.new()
	b.setup(12345)
	var c: _RNG = _RNG.new()
	c.setup(12346)
	var sa: int = 0
	var sb: int = 0
	var sc: int = 0
	for i in range(20):
		sa += a.world.randi()
		sb += b.world.randi()
		sc += c.world.randi()
	ctx.check(sa == sb, "rng: same seed -> same world stream")
	ctx.check(sa != sc, "rng: different seed -> different stream")
	# The four streams differ under the same seed.
	var d: _RNG = _RNG.new()
	d.setup(777)
	var e: _RNG = _RNG.new()
	e.setup(777)
	var v1: int = d.world.randi()
	var v2: int = d.encounter.randi()
	var v3: int = d.loot.randi()
	var v4: int = d.event.randi()
	var w1: int = e.world.randi()
	var w2: int = e.encounter.randi()
	var w3: int = e.loot.randi()
	var w4: int = e.event.randi()
	ctx.check(v1 == w1 and v2 == w2 and v3 == w3 and v4 == w4,
			"rng: deterministic across instances")
	ctx.check(v1 != v2 and v2 != v3 and v3 != v4,
			"rng: the four streams are independent")
	# Drawing from one stream must not disturb the others: the
	# encounter sequence is identical whether or not world draws
	# happened in between.
	var f: _RNG = _RNG.new()
	f.setup(42)
	var g: _RNG = _RNG.new()
	g.setup(42)
	var seq_f: Array = []
	var seq_g: Array = []
	for i in range(4):
		seq_f.append(f.encounter.randi())
		f.world.randi()  # interleaved draws
	for i in range(4):
		seq_g.append(g.encounter.randi())
	ctx.check(seq_f == seq_g,
			"rng: interleaved draws do not disturb other streams")


# --- data integrity ---------------------------------------------------

func _data_integrity(ctx: Variant) -> void:
	var room_files := [
		"camp_room", "village_entry", "watchtower_entry", "mine_entry",
		"shrine_entry", "bridge_entry", "lake_entry", "gate_approach",
		"undercroft_arena",
		"corridor_forest_v0", "corridor_forest_v1",
		"junction_cross_v0", "junction_cross_v1",
		"junction_t_v0", "junction_t_v1",
		"room_combat_v0", "room_combat_v1",
		"room_loot_v0", "room_loot_v1",
		"room_mystery_v0", "room_mystery_v1",
		"room_note_v0", "room_note_v1",
		"room_shelter_v0", "room_shelter_v1",
		"corridor_stairs_v0", "corridor_stairs_v1",
		"corridor_bridge_v0", "corridor_bridge_v1",
		"room_echo_v0", "room_echo_v1",
		"room_archive_v0", "room_archive_v1",
		"room_boneyard_v0", "room_boneyard_v1",
	]
	var bad: Array[String] = []
	var by_id: Dictionary = {}  # id -> [door signatures]
	var variants: Dictionary = {}  # id -> count
	for f in room_files:
		var res: Resource = load("res://data/rooms/%s.tres" % f)
		if res == null or not (res is _ROOM):
			bad.append("%s: failed to load" % f)
			continue
		var room: _ROOM = res
		var problems: Array[String] = room.validate()
		if not problems.is_empty():
			bad.append("%s: %s" % [f, "; ".join(problems)])
		var sig: String = ""
		for d in room.doorways:
			var dd: _DW = d
			sig += "%s@%s|%s; " % [dd.anchor, str(dd.local_pos),
					str(dd.facing)]
		if by_id.has(room.id):
			if by_id[room.id] != sig:
				bad.append("%s: doorway anchors differ from variant %d "
						+ "(ADR-003)" % [f, room.variant])
		else:
			by_id[room.id] = sig
		variants[room.id] = int(variants.get(room.id, 0)) + 1
	ctx.check(bad.is_empty(),
			"rooms: all 35 load and validate (%s)"
			% ("; ".join(bad) if not bad.is_empty() else "ok"))
	# Exactly the 13 modular ids, each with 2 variants (GDD §11).
	var modular_count: int = 0
	for gid in MODULAR_IDS:
		if int(variants.get(gid, 0)) == 2:
			modular_count += 1
	ctx.check(modular_count == 13,
			"rooms: 13 modular ids x 2 variants (got %d)" % modular_count)
	for f in AREA_FILES:
		var res: Resource = load("res://data/areas/%s.tres" % f)
		if res == null or not (res is _AREA):
			ctx.check(false, "areas: %s failed to load" % f)
			continue
		var a: _AREA = res
		var problems: Array[String] = a.validate()
		ctx.check(problems.is_empty(),
				"areas: %s validates (%s)" % [f, "; ".join(problems)])


# --- the generator ----------------------------------------------------

func _generator(ctx: Variant, pool: Dictionary) -> void:
	var gen: _GEN = _GEN.new()
	gen.set_pool(pool)
	var ws: Dictionary = {}

	# 1. A basic run is valid.
	var l0: _RL = gen.generate(1, ws)
	var problems: Array[String] = _VAL.validate(l0, ws, pool)
	ctx.check(problems.is_empty(),
			"generator: seed 1 layout validates (%s)"
			% ("; ".join(problems) if not problems.is_empty() else "ok"))
	ctx.check(not l0.fallback_used, "generator: seed 1 no fallback")
	ctx.check(l0.room_count() >= 9,
			"generator: at least one room per area (%d)" % l0.room_count())

	# 2. Determinism: A, B, A' -> A == A'.
	var la: _RL = gen.generate(1001, ws)
	var lb: _RL = gen.generate(2002, ws)
	var la2: _RL = gen.generate(1001, ws)
	var sa: String = _serialize(la)
	var sb: String = _serialize(lb)
	var sa2: String = _serialize(la2)
	ctx.check(sa == sa2, "generator: deterministic (A == A')")
	ctx.check(sa != sb, "generator: different seed -> different layout")

	# 3. The EXIT criterion: 100 seeds pass validation.
	var failed: int = 0
	var fell_back: int = 0
	var failed_seeds: Array = []
	for seed in range(1, 101):
		var l: _RL = gen.generate(seed, ws)
		if l.fallback_used:
			fell_back += 1
		var p: Array[String] = _VAL.validate(l, ws, pool)
		if not p.is_empty():
			failed += 1
			failed_seeds.append(seed)
	ctx.check(failed == 0,
			"generator: 100/100 seeds pass (failed: %s)"
			% (str(failed_seeds) if failed > 0 else "none"))
	ctx.check(fell_back == 0,
			"generator: 100/100 seeds without the fallback (%d used it)"
			% fell_back)

	# 4. World state: the boss edge closes -> the boss is unreachable
	#    but the layout stays valid (a sealed undercroft, ADR-016).
	#    (The current data has no conditions; the mechanism is proven
	#    with a synthetic pool below.)
	var ws_closed: Dictionary = {"mine_to_undercroft": false}
	var l1: _RL = gen.generate(5, ws_closed)
	var p1: Array[String] = _VAL.validate(l1, ws_closed, pool)
	ctx.check(p1.is_empty(),
			"generator: ws-closed layout validates (%s)"
			% ("; ".join(p1) if not p1.is_empty() else "ok"))

	# 5. Synthetic pool: a conditioned boss edge opens/closes with ws.
	var cond_pool: Dictionary = _cond_pool(pool)
	if cond_pool != null:
		var g2: _GEN = _GEN.new()
		g2.set_pool(cond_pool)
		var l_open: _RL = g2.generate(3, {"mine_to_undercroft": true})
		var p_open: Array[String] = _VAL.validate(l_open,
				{"mine_to_undercroft": true}, cond_pool)
		var l_closed: _RL = g2.generate(3, {"mine_to_undercroft": false})
		var p_closed: Array[String] = _VAL.validate(l_closed,
				{"mine_to_undercroft": false}, cond_pool)
		ctx.check(p_open.is_empty(),
				"validator: open boss edge validates (%s)"
				% "; ".join(p_open))
		ctx.check(p_closed.is_empty(),
				"validator: closed boss edge validates (%s)"
				% "; ".join(p_closed))
		ctx.check(_serialize(l_open) != _serialize(l_closed),
				"validator: ws changes the layout (open vs closed edge)")
		# The closed MINE edge: no MINE door leads to the undercroft
		# (the gate's unconditioned edge may stay open).
		ctx.check(_boss_incoming(l_closed, &"the_mine").is_empty()
				and _boss_incoming(l_open, &"the_mine").size() > 0,
				"validator: ws closes/opens the mine->boss edge")
	else:
		ctx.check(false, "validator: synthetic cond pool failed")

	# 6. Spawns: placed on room spots, copies (the .tres stay as is).
	if l0.spawns.size() > 0:
		var placed_ok: bool = true
		for s in l0.spawns:
			var placed: bool = false
			for aid in l0.areas:
				var ap: _AP = l0.areas[aid]
				for rp in ap.rooms:
					var rrp: _RP = rp
					var spot: Vector3 = s.position - rrp.origin
					for es in rrp.room.enemy_spots:
						if es.distance_to(spot) < 0.01:
							placed = true
			if not placed:
				placed_ok = false
		ctx.check(placed_ok, "generator: all spawns on a room enemy spot")
	# The source table positions are untouched (the generator copies).
	var src_table: Resource = load(
			"res://data/enemies/zone_spawn_table_mine.tres")
	if src_table != null:
		var e0: Resource = src_table.entries[0]
		ctx.check(e0.position == Vector3.ZERO,
				"generator: the .tres spawn table stays immutable")

	# 7. Negative paths: the validator must reject broken layouts.
	var broken: _RL = gen.generate(11, ws)
	var area: _AP = broken.get_area(&"the_mine")
	if area != null and area.rooms.size() > 0:
		var rp: _RP = area.rooms[0]
		for d in rp.doors:
			var rd: _RD = d
			rd.to_room = &"does_not_exist"
			rd.to_anchor = &"nope"
		var pb: Array[String] = _VAL.validate(broken, ws, pool)
		ctx.check(not pb.is_empty(),
				"validator: a broken doorway is rejected")
	# A room without the no-filler record is rejected.
	var nofiller: _ROOM = _ROOM.new()
	nofiller.id = &"test_room"
	nofiller.areas = PackedStringArray([&"test"])
	nofiller.size = Vector2(6.0, 6.0)
	nofiller.doorways = []
	var d1: _DW = _DW.new()
	d1.anchor = &"door_a"
	d1.local_pos = Vector3(0.0, 0.0, 3.0)
	d1.facing = Vector3(0.0, 0.0, -1.0)
	nofiller.doorways = [d1]
	ctx.check(not nofiller.validate().is_empty(),
			"rooms: no-filler record is enforced (GDD §9)")
	# A spawn inside an obstacle is rejected.
	var with_obst: _ROOM = _ROOM.new()
	with_obst.id = &"test_room2"
	with_obst.areas = PackedStringArray([&"test"])
	with_obst.size = Vector2(6.0, 6.0)
	with_obst.narrative = "x"
	var d2: _DW = _DW.new()
	d2.anchor = &"door_a"
	d2.local_pos = Vector3(0.0, 0.0, 3.0)
	d2.facing = Vector3(0.0, 0.0, -1.0)
	with_obst.doorways = [d2]
	var ob: _OB = _OB.new()
	ob.position = Vector3(0.0, 0.5, 0.0)
	ob.size = Vector3(2.0, 1.0, 2.0)
	with_obst.obstacles = [ob]
	with_obst.enemy_spots = PackedVector3Array([Vector3(0.0, 0.5, 0.0)])
	ctx.check(not with_obst.validate().is_empty(),
			"rooms: a spawn in an obstacle is rejected")


# --- helpers ----------------------------------------------------------

func _pool() -> Dictionary:
	var out: Dictionary = {}
	for f in AREA_FILES:
		var res: Resource = load("res://data/areas/%s.tres" % f)
		if res == null:
			return {}
		out[(res as _AREA).id] = res
	return out


# Serialize a layout to a stable string (the determinism A == A').
func _serialize(l: _RL) -> String:
	var s: String = ""
	var ids: Array = l.areas.keys()
	ids.sort()
	for id in ids:
		var a: _AP = l.areas[id]
		s += "[%s:" % id
		for r in a.rooms:
			var rp: _RP = r
			s += "%s@%s|" % [rp.room.id, _v3(rp.origin)]
			for d in rp.doors:
				var rd: _RD = d
				s += "%s->%s:%s:%s:%s;" % [rd.anchor, rd.to_room,
						rd.to_room_area, rd.to_area, rd.to_anchor]
		s += "] "
	for sp in l.spawns:
		s += "s:%s|" % _v3(sp.position)
	return s


func _v3(v: Vector3) -> String:
	return "%d.%03d|%.1f" % [int(v.x), int(v.x * 1000) % 1000, v.z]


# The incoming boss edges of a layout from one source (ws test).
func _boss_incoming(l: _RL, source: StringName) -> Array:
	var out: Array = []
	var a: _AP = l.areas.get(source, null)
	if a == null:
		return out
	for r in a.rooms:
		var rp: _RP = r
		for d in rp.doors:
			var rd: _RD = d
			if rd.to_area == _GEN.BOSS_ID:
				out.append([rp.room.id, rd.anchor])
	return out


# A copy of the pool where the mine->undercroft edge is CONDITIONED
# (the real data is unconditioned; this proves the ws mechanism).
func _cond_pool(pool: Dictionary):
	# Shallow copy: the area resources are shared (read-only here),
	# but the mine's connections are replaced with a conditioned one.
	var out: Dictionary = {}
	for id in pool:
		out[id] = pool[id]
	var mine: _AREA = pool.get(&"the_mine", null)
	if mine == null:
		return null
	var conn_script: GDScript = load(
		"res://scripts/gameplay/areas/area_connection.gd")
	var new_conns: Array = []
	for c in mine.connections:
		var cc: Resource = c.duplicate()
		cc.condition = &"mine_to_undercroft"
		new_conns.append(cc)
	var mine_copy: _AREA = mine.duplicate() as _AREA
	mine_copy.connections = new_conns
	out[&"the_mine"] = mine_copy
	return out
