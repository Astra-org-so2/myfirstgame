# NavData — hub navigation graph as data (nodes + undirected edges).
# The NavGraph pathfinder is pure code; the GRAPH is a Resource, so a
# new zone = a new .tres, no code (TECHNICAL_DESIGN §1).
class_name NavData
extends Resource

# World positions (y ignored — the graph is 2D on the ground plane).
@export var nodes: PackedVector3Array = PackedVector3Array()
# Pairs: [a, b, b, c, c, d, ...] — undirected edges.
@export var edges: PackedInt32Array = PackedInt32Array()


func validate() -> Array[String]:
	var problems: Array[String] = []
	if nodes.size() < 2:
		problems.append("need >= 2 nodes")
	if edges.size() % 2 != 0:
		problems.append("edges must be pairs")
		return problems
	for i in range(0, edges.size(), 2):
		var a: int = edges[i]
		var b: int = edges[i + 1]
		if a == b:
			problems.append("self-loop edge %d" % a)
		elif a < 0 or a >= nodes.size() or b < 0 or b >= nodes.size():
			problems.append("edge %d<->%d out of range" % [a, b])
	return problems
