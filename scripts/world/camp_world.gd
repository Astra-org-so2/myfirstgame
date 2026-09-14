# CampWorld — builds the camp hub (Phase 3) from CampLayout data.
#
# The camp is handcrafted (WORLD_BIBLE §4.1); placement lives in
# data/world/camp_layout.tres, visual style in the template scenes under
# scenes/world/. This node assembles: trees (MultiMesh, budget-friendly),
# the camp core (bonfire/tents/props), 8 zone gate silhouettes (Phase 7
# replaces them with real zone geometry), distant landmarks
# (landmark-rule, WORLD_BIBLE §3.2), and the approach path.
#
# Budget (TECHNICAL_DESIGN §12, env <= 90 draw calls):
# trees = 3 multimesh calls, camp core ~30, zones 8x2, landmarks ~6,
# path ~3, ground 1 => ~60 draw calls (measured in Phase 16).
# Cross-file references via preload-consts (ADR-022).
class_name CampWorld
extends Node3D

const _LAYOUT = preload("res://scripts/world/camp_layout.gd")
const _INTERACTABLE = preload("res://scripts/world/interactable.gd")
const _BONFIRE = preload("res://scenes/world/Bonfire.tscn")
const _TENT = preload("res://scenes/world/Tent.tscn")
const _NOTE_STAND = preload("res://scenes/world/NoteStand.tscn")
const _TABLE_CUPS = preload("res://scenes/world/TableCups.tscn")
const _KETTLE = preload("res://scenes/world/Kettle.tscn")
const _PILLAR = preload("res://scenes/world/Pillar.tscn")
const _MARA = preload("res://scenes/world/Mara.tscn")
const _ZONE_MARKER = preload("res://scenes/world/ZoneMarker.tscn")
const _WATCHTOWER = preload("res://scenes/world/Watchtower.tscn")
const _GATE_SIL = preload("res://scenes/world/GateSilhouette.tscn")

# WORLD_BIBLE §1 palette: muted green-gray forest, gray-blue fog,
# warm amber only at the camp (warm = home/life).
const C_GROUND: Color = Color(0.16, 0.185, 0.145)
const C_PATH: Color = Color(0.14, 0.125, 0.105)
const C_TRUNK: Color = Color(0.21, 0.165, 0.125)
const C_LEAF_LOW: Color = Color(0.135, 0.2, 0.135)
const C_LEAF_HIGH: Color = Color(0.115, 0.175, 0.12)
const C_STONE: Color = Color(0.33, 0.345, 0.37)
const C_WOOD: Color = Color(0.27, 0.215, 0.155)
const C_PILLAR: Color = Color(0.29, 0.3, 0.32)
const C_SILHOUETTE: Color = Color(0.1, 0.11, 0.13)
const C_ZONE_MARKER: Color = Color(0.16, 0.17, 0.19)
# Tent order matches CampLayout.tent_slots: [mara, empty, not human].
const TENT_COLORS: Array[Color] = [
		Color(0.3, 0.28, 0.23), Color(0.24, 0.25, 0.23),
		Color(0.19, 0.17, 0.2),
]

const FLAT_SHADING: int = 1024  # StandardMaterial3D.SHADING_MODE_FLAT
const ZONE_GATE_RADIUS: float = 10.5

var layout: _LAYOUT
var tree_count: int = 0
var tent_count: int = 0
var zone_markers: Array = []
var interactables: Array = []


func _ready() -> void:
	if layout == null:
		layout = load("res://data/world/camp_layout.tres")
	if layout == null:
		push_error("CampWorld: CampLayout missing (data/world/camp_layout.tres)")
		return
	var problems: Array[String] = layout.validate()
	if not problems.is_empty():
		push_error("CampWorld: invalid CampLayout: " + ", ".join(problems))
	_build_path()
	_build_trees()
	_build_camp_core()
	_build_zone_gates()
	_build_landmarks()


# --- Trees (MultiMesh: 3 draw calls for the whole grove) ---

func _build_trees() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Trees"
	add_child(root)

	tree_count = layout.tree_slots.size()
	var trunks: MultiMesh = _trunk_multimesh()
	var leaf_low: MultiMesh = _cone_multimesh(1.7, 2.6, C_LEAF_LOW)
	var leaf_high: MultiMesh = _cone_multimesh(1.15, 2.2, C_LEAF_HIGH)

	for i in tree_count:
		var slot: Vector3 = layout.tree_slots[i]
		var s: float = slot.y
		# Diagonal scale basis via axis constructor (the wasm rig only
		# registers the axes constructor for Basis, ADR-022).
		var b: Basis = Basis(Vector3(s, 0.0, 0.0),
				Vector3(0.0, s, 0.0), Vector3(0.0, 0.0, s))
		trunks.set_instance_transform(i, Transform3D(b,
				Vector3(slot.x, 2.0 * s, slot.z)))
		leaf_low.set_instance_transform(i, Transform3D(b,
				Vector3(slot.x, 3.2 * s, slot.z)))
		leaf_high.set_instance_transform(i, Transform3D(b,
				Vector3(slot.x, 4.6 * s, slot.z)))

	for mm in [trunks, leaf_low, leaf_high]:
		var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
		mi.multimesh = mm
		root.add_child(mi)


func _trunk_multimesh() -> MultiMesh:
	var mm: MultiMesh = _multi_mesh_3d()
	mm.instance_count = tree_count
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.22
	mesh.bottom_radius = 0.34
	mesh.height = 4.0
	mm.mesh = mesh
	mm.material = _mat(C_TRUNK)
	return mm


func _cone_multimesh(radius: float, height: float, color: Color) -> MultiMesh:
	# ConeMesh is not registered in the headless wasm rig (ADR-022);
	# a 3-radial cylinder with a tiny top radius is visually a cone.
	var mm: MultiMesh = _multi_mesh_3d()
	mm.instance_count = tree_count
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.06
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 3
	mm.mesh = mesh
	mm.material = _mat(color)
	return mm


# --- Approach path (flat segments spawn -> camp) ---

func _build_path() -> void:
	var wp: PackedVector3Array = layout.path_waypoints
	var root: Node3D = Node3D.new()
	root.name = "Path"
	add_child(root)
	for i in wp.size() - 1:
		var a: Vector3 = Vector3(wp[i].x, 0.0, wp[i].z)
		var b: Vector3 = Vector3(wp[i + 1].x, 0.0, wp[i + 1].z)
		var d: Vector3 = b - a
		var seg: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.7, 0.04, d.length())
		seg.mesh = bm
		seg.material = _mat(C_PATH)
		seg.position = Vector3((a.x + b.x) * 0.5, 0.02, (a.z + b.z) * 0.5)
		seg.rotation.y = atan2(d.x, d.z)
		root.add_child(seg)


# --- Camp core: bonfire, tents, props, interactables ---

func _build_camp_core() -> void:
	var root: Node3D = Node3D.new()
	root.name = "CampCore"
	add_child(root)

	_place(_BONFIRE, layout.bonfire_pos, root)

	# Tents face the fire.
	tent_count = layout.tent_slots.size()
	for i in layout.tent_slots.size():
		var slot: Vector3 = layout.tent_slots[i]
		var p: Vector3 = Vector3(slot.x, 0.0, slot.z)
		var tent: Node3D = _place(_TENT, p, root)
		var dir: Vector3 = (_xz(layout.bonfire_pos) - p).normalized()
		tent.rotation.y = atan2(dir.x, dir.z)
		var shell: MeshInstance3D = tent.get_node_or_null("Shell")
		if shell != null:
			shell.material = _mat(TENT_COLORS[i])

	# Interactable props (prompt stubs; effect content — Phase 4/10/11).
	_add_interactable(root, _PILLAR, layout.pillar_pos,
			"Examine the pillar (E)")
	_add_interactable(root, _NOTE_STAND, layout.note_stand_pos,
			"Look at the note (E)")
	_add_interactable(root, _MARA, layout.mara_pos,
			"Talk to Mara (E)")
	_add_interactable(root, _KETTLE, layout.kettle_pos,
			"The kettle (E)", 1.6)

	# Passive beat (no interaction): the table with two cups
	# (ENV_STORYTELLING: repeating "home" motif).
	_place(_TABLE_CUPS, layout.table_pos, root)


func _add_interactable(root: Node3D, template: PackedScene,
		pos: Vector3, prompt: String, radius: float = 2.4) -> void:
	var ia: _INTERACTABLE = _INTERACTABLE.new()
	ia.name = "IA_" + template.resource_path.get_file().get_basename()
	ia.position = Vector3(pos.x, 0.0, pos.z)
	ia.prompt = prompt
	ia.interact_radius = radius
	root.add_child(ia)
	ia.add_child(template.instantiate())
	interactables.append(ia)


# --- 8 zone gate silhouettes (replaced by real zones in Phase 7) ---

func _build_zone_gates() -> void:
	var root: Node3D = Node3D.new()
	root.name = "ZoneGates"
	add_child(root)
	for i in layout.zone_names.size():
		var a: float = deg_to_rad(layout.zone_angles[i])
		var marker: Node3D = _ZONE_MARKER.instantiate()
		marker.name = "ZoneGate_" + String(layout.zone_names[i])
		marker.position = Vector3(
				sin(a) * ZONE_GATE_RADIUS, 0.0, cos(a) * ZONE_GATE_RADIUS)
		marker.rotation.y = a + PI  # face the camp
		var mat_node: Node3D = marker.get_node_or_null("Monolith")
		if mat_node != null and mat_node is MeshInstance3D:
			(mat_node as MeshInstance3D).material = _mat(C_ZONE_MARKER)
		root.add_child(marker)
		zone_markers.append(marker)


# --- Distant landmarks (seen through the fog, WORLD_BIBLE §3.2) ---

func _build_landmarks() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Landmarks"
	add_child(root)
	_place(_WATCHTOWER, layout.watchtower_pos, root)
	_place(_GATE_SIL, layout.gate_pos, root)


# --- helpers ---

func _multi_mesh_3d() -> MultiMesh:
	var mm: MultiMesh = MultiMesh.new()
	# MultiMesh defaults to TRANSFORM_2D; 3D transforms need TRANSFORM_3D (=1).
	mm.transform_format = 1
	return mm


func _place(template: PackedScene, pos: Vector3,
		parent: Node = null) -> Node:
	var n: Node = template.instantiate()
	var p: Node = parent if parent != null else self
	p.add_child(n)
	n.position = Vector3(pos.x, 0.0, pos.z)
	return n


func _xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _mat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	m.shading_mode = FLAT_SHADING
	return m
