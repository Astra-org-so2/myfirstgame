# RoomNode — one room's visuals, built from RoomData (code-built
# primitives, ADR-005 text-first: no asset spam, mobile budget).
#
# The room's origin is the floor center (y = 0). Floor + 4 walls
# (a gap + a monolith frame at each doorway, the camp's ZoneMarker
# language), the obstacles as boxes, one role prop, one PointLight
# (shadows OFF — the mobile light budget, ADR-021).
class_name RoomNode
extends Node3D

const _ROOM = preload("res://scripts/gameplay/rooms/room_data.gd")
const _OB = preload("res://scripts/gameplay/rooms/obstacle_box.gd")
const _DW = preload("res://scripts/gameplay/rooms/doorway_def.gd")
const _RD = preload("res://scripts/gameplay/rooms/resolved_door.gd")
# Phase 13: the structural colors come from the canonical
# palette (WORLD_BIBLE §1) — one source for the whole world.
const _PALETTE = preload("res://data/visual/palette.tres")

const WALL_H: float = 3.0
const WALL_T: float = 0.4
const DOOR_GAP: float = 1.7  # the doorway mouth (matches the data)
const DOOR_H: float = 2.4

var room: _ROOM
# The placed room's RESOLVED doors (the layout knows which doorways
# are sealed in the current run; the visuals follow the data — the
# sealed door must look sealed, A16 legibility).
var resolved: Array = []  # Array[ResolvedDoor]
var _light: OmniLight3D = null
# The materials this node USES (the rig no-ops the mesh material
# setter; the members are the reskin/grading hook AND the test
# handle for the palette->material wiring).
var floor_material: StandardMaterial3D = null
var wall_material: StandardMaterial3D = null
# The texture bank (the main scene hands it down; null = the
# flat-color fallback, e.g. in the headless tests).
var textures: Variant = null


func _ready() -> void:
	if room != null:
		name = "Room_%s" % room.id
		_build()


func _build() -> void:
	var w: float = room.size.x
	var d: float = room.size.y
	# Floor.
	floor_material = _mat_pal(_PALETTE.ground, "ground")
	var floor: MeshInstance3D = _box(Vector3(w, 0.2, d),
			Vector3(0.0, -0.1, 0.0), floor_material)
	floor.name = "Floor"
	add_child(floor)
	# Walls with doorway gaps (sealed doors get a solid wall + seal).
	var sealed: Dictionary = _sealed_anchors()
	var doors_by_side: Dictionary = {"n": [], "s": [], "w": [], "e": []}
	for dw in room.doorways:
		var dd: _DW = dw
		if sealed.has(dd.anchor):
			continue
		var p: Vector3 = dd.local_pos
		if absf(p.z) > absf(p.x):
			if p.z < 0.0:
				doors_by_side["n"].append(p.x)
			else:
				doors_by_side["s"].append(p.x)
		else:
			if p.x < 0.0:
				doors_by_side["w"].append(p.z)
			else:
				doors_by_side["e"].append(p.z)
	var walls: Node3D = Node3D.new()
	walls.name = "Walls"
	add_child(walls)
	_wall(walls, "n", w, -d * 0.5, doors_by_side["n"], 0.0)
	_wall(walls, "s", w, d * 0.5, doors_by_side["s"], 0.0)
	_wall(walls, "e", d, w * 0.5, doors_by_side["e"], 1.0)
	_wall(walls, "w", d, -w * 0.5, doors_by_side["w"], 1.0)
	# Doorway frames (the monolith pair + lintel, the camp language);
	# sealed doorways get the seal (A16) instead.
	for dw in room.doorways:
		var dd: _DW = dw
		if sealed.has(dd.anchor):
			_seal(walls, dd.local_pos)
		else:
			_doorframe(walls, dd.local_pos)
	# Obstacles (the same boxes the spawn probe uses — ADR-002).
	var oi: int = 0
	for o in room.obstacles:
		var ob: _OB = o
		var box: MeshInstance3D = _box(ob.size,
				Vector3(ob.position.x, ob.size.y * 0.5, ob.position.z),
				_mat_pal(_PALETTE.stone_dark, "stone_dark"))
		box.name = "Obstacle_%d" % oi
		oi += 1
		add_child(box)
	# The role prop (one idea per room, the no-filler line made
	# visible — ENV_STORYTELLING §3).
	_prop()
	# The room's light (data color/energy; shadows off, mobile).
	# Lifecycled by the ZoneWorld's light budget (quality preset,
	# §12): rooms beyond the budget have no light node at all.
	var light: OmniLight3D = _make_light(w, d)
	add_child(light)
	_light = light


func _wall(parent: Node3D, _side: String, len: float, at: float,
		gaps: Array, axis: float) -> void:
	wall_material = _mat_pal(_PALETTE.stone, "stone")
	# axis 0 = wall runs along X at z = at; axis 1 = along Z at x = at.
	# gaps: centers of the doorway mouths along the wall.
	var segs: Array = []  # [start, end] in wall coordinates
	var sorted: Array = gaps.duplicate()
	sorted.sort()
	var cursor: float = -len * 0.5
	for g in sorted:
		var gs: float = maxf(g - DOOR_GAP * 0.5, -len * 0.5)
		if gs > cursor + 0.05:
			segs.append([cursor, gs])
		cursor = minf(g + DOOR_GAP * 0.5, len * 0.5)
	if cursor < len * 0.5 - 0.05:
		segs.append([cursor, len * 0.5])
	for s in segs:
		var a: float = s[0]
		var b: float = s[1]
		var seg_len: float = b - a
		if seg_len < 0.05:
			continue
		var c: float = (a + b) * 0.5
		if axis == 0.0:
			var m: MeshInstance3D = _box(Vector3(seg_len, WALL_H, WALL_T),
					Vector3(c, WALL_H * 0.5, at), wall_material)
			parent.add_child(m)
		else:
			var m2: MeshInstance3D = _box(Vector3(WALL_T, WALL_H, seg_len),
					Vector3(at, WALL_H * 0.5, c), wall_material)
			parent.add_child(m2)
	# The lintel above each gap (the door is open, the frame remains).
	for g in gaps:
		var lintel: MeshInstance3D
		if axis == 0.0:
			lintel = _box(Vector3(DOOR_GAP + 0.6, WALL_H - DOOR_H, WALL_T),
					Vector3(g, DOOR_H + (WALL_H - DOOR_H) * 0.5, at),
					_mat_pal(_PALETTE.stone, "stone"))
		else:
			lintel = _box(Vector3(WALL_T, WALL_H - DOOR_H, DOOR_GAP + 0.6),
					Vector3(at, DOOR_H + (WALL_H - DOOR_H) * 0.5, g),
					_mat_pal(_PALETTE.stone, "stone"))
		parent.add_child(lintel)


func _sealed_anchors() -> Dictionary:
	var out := {}
	for rd in resolved:
		var d: _RD = rd
		if d != null and d.is_sealed():
			out[d.anchor] = true
	return out


# A16: the sealed doorway — the wall continues across the mouth
# (no gap) and the seal (a dark ring, three notches) says: this door
# is a decision, not a path.
func _seal(parent: Node3D, p: Vector3) -> void:
	var axis_x: bool = absf(p.x) >= absf(p.z)  # wall runs along Z
	var slab: MeshInstance3D
	if axis_x:
		slab = _box(Vector3(WALL_T, WALL_H, DOOR_GAP + 0.2),
				p, _mat_pal(_PALETTE.stone, "stone"))
	else:
		slab = _box(Vector3(DOOR_GAP + 0.2, WALL_H, WALL_T),
				p, _mat_pal(_PALETTE.stone, "stone"))
	parent.add_child(slab)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 1.25
	cm.bottom_radius = 1.25
	cm.height = 0.14
	ring.mesh = cm
	ring.position = p + Vector3(0.0, 1.5, 0.0)
	if axis_x:
		ring.rotation.x = deg_to_rad(90.0)
	else:
		ring.rotation.z = deg_to_rad(90.0)
	var rm: StandardMaterial3D = _mat_pal(_PALETTE.seal_ring, "seal_ring")
	rm.emission_enabled = true
	rm.emission = _PALETTE.seal_glow
	rm.emission_energy_multiplier = 0.7
	ring.material = rm
	parent.add_child(ring)
	# The three notches (the "3 впадины" of the gate's seal).
	for k in 3:
		var ang: float = deg_to_rad(90.0 + float(k) * 120.0)
		var off: Vector3 = Vector3(cos(ang), 0.0, sin(ang)) * 1.25
		var notch: MeshInstance3D
		if axis_x:
			notch = _box(Vector3(0.14, 0.3, 0.2),
					p + Vector3(0.0, 1.5, 0.0)
					+ Vector3(0.0, off.x, off.y),
			_mat_pal(_PALETTE.seal_notch, "seal_notch"))
		else:
			notch = _box(Vector3(0.2, 0.3, 0.14),
					p + Vector3(0.0, 1.5, 0.0)
					+ Vector3(off.x, off.y, 0.0),
			_mat_pal(_PALETTE.seal_notch, "seal_notch"))
		parent.add_child(notch)


func _doorframe(parent: Node3D, p: Vector3) -> void:
	# Two monoliths at the mouth edges (the camp's ZoneMarker look).
	var off: Vector3
	if absf(p.z) > absf(p.x):
		off = Vector3(DOOR_GAP * 0.5 + 0.25, 0.0, 0.0)
	else:
		off = Vector3(0.0, 0.0, DOOR_GAP * 0.5 + 0.25)
	for sgn in [-1.0, 1.0]:
		var post: MeshInstance3D = _box(
				Vector3(0.5, DOOR_H + 0.4, 0.5),
				p + off * sgn, _mat_pal(_PALETTE.stone, "stone"))
		parent.add_child(post)


# One prop per role (the room's idea, visible at a glance).
func _prop() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Prop"
	add_child(root)
	match room.role:
		_ROOM.Role.JUNCTION:
			var disc: MeshInstance3D = MeshInstance3D.new()
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 1.6
			cm.bottom_radius = 1.6
			cm.height = 0.08
			disc.mesh = cm
			disc.position = Vector3(0.0, 0.04, 0.0)
			disc.material = _mat_pal(_PALETTE.stone, "stone")
			root.add_child(disc)
		_ROOM.Role.MYSTERY:
			var beam: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.35, 3.4, 0.35)
			beam.mesh = bm
			beam.position = Vector3(0.0, 1.7, 0.0)
			var em: StandardMaterial3D = _mat_pal(
					_PALETTE.mystery_beam, "mystery_beam")
			em.emission_enabled = true
			em.emission = _PALETTE.mystery_glow
			em.emission_energy_multiplier = 1.6
			beam.material = em
			root.add_child(beam)
		_ROOM.Role.SHELTER:
			var table: MeshInstance3D = _box(Vector3(1.6, 0.7, 1.0),
					Vector3(-room.size.x * 0.25, 0.35, 0.0),
					_mat_pal(_PALETTE.wood_dark, "wood_dark"))
			root.add_child(table)
		_ROOM.Role.COMBAT:
			var slab: MeshInstance3D = _box(Vector3(2.4, 0.18, 1.2),
					Vector3(0.0, 0.09, 0.0), _mat_pal(_PALETTE.stone_dark, "stone_dark"))
			root.add_child(slab)
		_ROOM.Role.LOOT:
			var crate: MeshInstance3D = _box(Vector3(0.7, 0.7, 0.7),
					Vector3(room.size.x * 0.2, 0.35, 0.0),
					_mat_pal(_PALETTE.wood_dark, "wood_dark"))
			root.add_child(crate)
		_:
			pass  # CORRIDOR: the obstacles ARE the props


func _box(sz: Vector3, pos: Vector3, material: StandardMaterial3D) \
		-> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material = material
	return mi


# --- The light's lifecycle (the ZoneWorld budget calls these) ---

func _make_light(w: float, d: float) -> OmniLight3D:
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "RoomLight"
	light.position = Vector3(0.0, WALL_H - 0.6, 0.0)
	light.light_color = room.light_color
	light.light_energy = room.light_energy * 2.2
	light.omni_range = maxf(w, d) * 1.1
	light.shadow = false
	return light


func ensure_light() -> void:
	# Budget raised (e.g. the F8 cycle): recreate the light from the
	# room data.
	if _light != null:
		return
	var l: OmniLight3D = _make_light(room.size.x, room.size.y)
	_light = l
	add_child(l)


func drop_light() -> void:
	if _light == null:
		return
	var l: OmniLight3D = _light
	_light = null
	l.free()  # immediate: the budget change must not outlive the call


func _pmat(c: Color) -> StandardMaterial3D:
	return _mat(c.r, c.g, c.b)

# The palette color through the texture bank when available (the
# texture variation survives the tint, TextureBank model).
func _mat_pal(c: Color, id: String) -> StandardMaterial3D:
	if textures != null and textures.has(id):
		var m: StandardMaterial3D = textures.material(id, c)
		if m != null:
			return m
	return _pmat(c)


func _mat(r: float, g: float, b: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(r, g, b)
	m.roughness = 0.9
	m.metallic = 0.0
	return m
