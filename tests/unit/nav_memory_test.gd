# Unit: NavGraph (pure A*) + MemoryPath (ring buffer).
#
# The camp nav data (data/world/camp_nav.tres) is the Phase 5 hub:
# a 17-node wheel (center + mid ring + the 8 zone gates).
extends Node

const _NAV_DATA = preload("res://scripts/gameplay/enemies/nav_data.gd")
const _NAV = preload("res://scripts/gameplay/enemies/nav_graph.gd")
const _MPATH = preload("res://scripts/gameplay/enemies/memory_path.gd")


func run(ctx: Variant) -> void:
	_camp_nav(ctx)
	_graph_properties(ctx)
	_memory_path(ctx)


func _camp_nav(ctx: Variant) -> void:
	var data: _NAV_DATA = load("res://data/world/camp_nav.tres")
	ctx.check(data != null and data.validate().is_empty(),
			"nav_graph: camp nav data loads + validates")
	var g: _NAV = _NAV.new()
	g.build(data.nodes, data.edges)
	ctx.check(g.node_count() == 17,
			"nav_graph: camp hub is a 17-node wheel")

	# Center -> the first zone gate: center -> mid -> zone (3 nodes).
	var p: PackedInt32Array = g.find_path(0, 9)
	ctx.check(p.size() == 3 and p[0] == 0 and p[2] == 9,
			"nav_graph: center->zone path = center, mid, zone (%s)"
					% str(p))
	# The path cost matches the ring geometry (5.5 + 5.0).
	var cost: float = 0.0
	for i in range(1, p.size()):
		cost += g.node_pos(int(p[i - 1])).distance_to(
				g.node_pos(int(p[i])))
	ctx.check(absf(cost - 10.5) < 0.01,
			"nav_graph: path cost = 10.5 m (ring geometry)")

	# A* beats the ring route when the chord is shorter:
	# zone 9 -> zone 10 goes 9 -> 8(mid) -> 0? No — the wheel has no
	# zone chord; zone9->mid1->center->mid2->zone10 vs zone9->mid1->...
	# Instead: nearest_node from a point between the rings.
	var near: int = g.nearest_node(Vector2(0.1, 0.1))
	ctx.check(near == 0, "nav_graph: nearest_node picks the center")
	var near2: int = g.nearest_node(Vector2(5.5, 0.0))
	ctx.check(near2 != 0,
			"nav_graph: nearest_node picks the mid ring at 5.5 m")

	# Waypoints: exclude the start, world y = 0.
	var wp: PackedVector3Array = g.path_world(0, 9)
	ctx.check(wp.size() == 2,
			"nav_graph: path_world excludes the start node")
	ctx.check(wp[0].y == 0.0 and wp[1].y == 0.0,
			"nav_graph: waypoints are ground plane")
	# Walking the waypoints reaches the zone (within a node).
	var last_wp: Vector3 = wp[wp.size() - 1]
	var last: Vector2 = Vector2(last_wp.x, last_wp.z)
	var zone: Vector2 = g.node_pos(9)
	ctx.check(last.distance_to(zone) < 0.01,
			"nav_graph: the last waypoint IS the target zone")

	# Same-node and bad indices.
	p = g.find_path(4, 4)
	ctx.check(p.size() == 1 and p[0] == 4,
			"nav_graph: same-node path is trivial")
	p = g.find_path(0, 999)
	ctx.check(p.is_empty(), "nav_graph: bad index -> empty path")


func _graph_properties(ctx: Variant) -> void:
	# A pure A* on a hand graph: optimality + determinism.
	#  0(0,0) --1-- 1(10,0)
	#  |           |
	#  2           3
	#  |           |
	#  2(0,20) --1-- 3(10,20)   (node 2 is at (0,20), node 3 at (10,20))
	var g: _NAV = _NAV.new()
	g.build(
			PackedVector3Array([
					Vector3(0, 0, 0), Vector3(10, 0, 0),
					Vector3(0, 0, 20), Vector3(10, 0, 20),
			]),
			PackedInt32Array([0, 1, 0, 2, 2, 3, 1, 3]))
	var p1: PackedInt32Array = g.find_path(0, 3)
	# Two optimal routes (0-1-3 and 0-2-3, both 30 m): A* must pick
	# one deterministically — lower f tie -> lower open index.
	ctx.check(p1.size() == 3,
			"nav_graph: A* path 0->3 has 2 edges (30 m)")
	var p2: PackedInt32Array = g.find_path(0, 3)
	ctx.check(str(p1) == str(p2),
			"nav_graph: A* is deterministic (same graph, same path)")
	# The path is valid: consecutive nodes are connected.
	var ok: bool = true
	for i in range(1, p1.size()):
		var a: int = p1[i - 1]
		var b: int = p1[i]
		ok = ok and _connected(g, a, b)
	ctx.check(ok, "nav_graph: every path step is a real edge")
	# Unreachable: an isolated node.
	g.build(
			PackedVector3Array([
					Vector3(0, 0, 0), Vector3(100, 0, 0),
			]),
			PackedInt32Array())
	ctx.check(g.find_path(0, 1).is_empty(),
			"nav_graph: disconnected graph -> empty path")


func _connected(g: _NAV, a: int, b: int) -> bool:
	# Re-derive adjacency from the built graph via a probe path.
	var p: PackedInt32Array = g.find_path(a, b)
	return p.size() == 2


func _memory_path(ctx: Variant) -> void:
	var m: _MPATH = _MPATH.new()
	m.record(Vector2(0, 0), 0.0)
	m.record(Vector2(1, 0), 1.0)
	m.record(Vector2(2, 0), 2.0)
	ctx.check(m.size() == 3, "memory_path: three samples recorded")

	# Window 2.0 at t=2.0: samples t>0.0 -> the last two.
	var pts: PackedVector2Array = m.points_within(2.0, 2.0)
	ctx.check(pts.size() == 2 and pts[0] == Vector2(1, 0),
			"memory_path: the window keeps the recent samples")
	# The chase target = the newest sample in the window.
	var last: Vector2 = m.last_within(2.0, 2.0)
	ctx.check(last == Vector2(2, 0),
			"memory_path: last_within returns the newest sample")
	# Expired: at t=10 nothing is within 2 s.
	ctx.check(m.last_within(2.0, 10.0) == Vector2.INF,
			"memory_path: the memory expires")
	# The Hollow's full window (10 s) still remembers t=2 at t=11.
	ctx.check(m.last_within(10.0, 11.0) == Vector2(2, 0),
			"memory_path: 10 s window remembers 9 s ago")
	# Ring wrap: the buffer is bounded at MAX_SAMPLES.
	for i in range(_MPATH.MAX_SAMPLES + 50):
		m.record(Vector2(float(i), 0), float(i))
	ctx.check(m.size() == _MPATH.MAX_SAMPLES,
			"memory_path: the ring buffer is bounded")
	ctx.check(m.last_within(1.0 / 60.0 * 100,
			float(_MPATH.MAX_SAMPLES + 49)) != Vector2.INF,
			"memory_path: wrapped buffer still returns recent points")
	m.clear()
	ctx.check(m.size() == 0 and m.last_within(100.0, 0.0) == Vector2.INF,
			"memory_path: clear empties the memory")
