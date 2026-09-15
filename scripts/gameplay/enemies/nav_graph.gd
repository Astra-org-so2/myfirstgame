# NavGraph — pure A* over a 2D hub graph (TECHNICAL_DESIGN: the
# pathfinder in pure code; the navmesh-source is an engine seam).
#
# The camp hub (Phase 5) uses a hand-authored 17-node wheel graph
# (data/world/camp_nav.tres). Zones get their own graphs (Phases 7/8).
# A* = the same determinism contract as the combat logic: no Node,
# no engine types beyond Vector2, stable tie-break (lower open entry
# index wins ties).
class_name NavGraph
extends RefCounted

var _nodes: PackedVector2Array
var _neighbors: Array  # Array of Array[int]
var _edge_cost: Array  # Array of Array[float]


func build(nodes: PackedVector3Array, edges: PackedInt32Array) -> void:
	_nodes.clear()
	_neighbors.clear()
	_edge_cost.clear()
	for p in nodes:
		_nodes.append(Vector2(p.x, p.z))
	for i in range(_nodes.size()):
		_neighbors.append([])
		_edge_cost.append([])
	for i in range(0, edges.size() - 1, 2):
		add_edge(edges[i], edges[i + 1])


func add_edge(a: int, b: int) -> void:
	if _nodes.is_empty() \
			or a < 0 or a >= _nodes.size() or b < 0 or b >= _nodes.size() \
			or a == b:
		push_error("NavGraph: bad edge %d<->%d" % [a, b])
		return
	_neighbors[a].append(b)
	_neighbors[b].append(a)
	_edge_cost[a].append(_nodes[a].distance_to(_nodes[b]))
	_edge_cost[b].append(_nodes[a].distance_to(_nodes[b]))


func node_count() -> int:
	return _nodes.size()


func node_pos(idx: int) -> Vector2:
	return _nodes[idx]


func nearest_node(pos: Vector2) -> int:
	var best: int = 0
	var best_d: float = INF
	for i in range(_nodes.size()):
		var d: float = _nodes[i].distance_to(pos)
		if d < best_d:
			best_d = d
			best = i
	return best


# A* from node `from` to node `to`. Returns node indices INCLUDING
# both endpoints (or empty when unreachable). Deterministic: the open
# list keeps insertion order on equal f.
func find_path(from: int, to: int) -> PackedInt32Array:
	var result: PackedInt32Array = []
	if from < 0 or from >= _nodes.size() \
			or to < 0 or to >= _nodes.size():
		return result
	if from == to:
		result.append(from)
		return result
	var n: int = _nodes.size()
	var g: PackedFloat64Array = PackedFloat64Array()
	g.resize(n)
	for i in range(n):
		g[i] = INF
	var came: PackedInt32Array = PackedInt32Array()
	came.resize(n)
	for i in range(n):
		came[i] = -1
	g[from] = 0.0
	var closed: PackedByteArray = PackedByteArray()
	closed.resize(n)
	# Open list entries: [f, g, node].
	var open: Array = [[0.0, 0.0, from]]
	while not open.is_empty():
		var bi: int = 0
		for i in range(1, open.size()):
			if (open[i] as Array)[0] < (open[bi] as Array)[0]:
				bi = i
		var cur: Array = open[bi]
		open.remove_at(bi)
		var u: int = int((cur as Array)[2])
		if u == to:
			break
		if closed[u] == 1:
			continue
		closed[u] = 1
		for k in range((_neighbors[u] as Array).size()):
			var m: int = (_neighbors[u] as Array)[k]
			if closed[m] == 1:
				continue
			var ng: float = g[u] + (_edge_cost[u] as Array)[k]
			if ng < g[m]:
				g[m] = ng
				came[m] = u
				open.append([ng + _heuristic(m, to), ng, m])
	if g[to] == INF:
		return result
	var v: int = to
	while v != -1:
		result.append(v)
		v = int(came[v])
	result.reverse()
	return result


# World waypoints (y = 0), excluding the start node.
func path_world(from: int, to: int) -> PackedVector3Array:
	var p: PackedInt32Array = find_path(from, to)
	var out: PackedVector3Array = []
	for i in range(1, p.size()):
		var wp: Vector2 = node_pos(int(p[i]))
		out.append(Vector3(wp.x, 0.0, wp.y))
	return out


func _heuristic(a: int, b: int) -> float:
	return _nodes[a].distance_to(_nodes[b])
