# WorldDirector — the persistent-world layer (ROADMAP Phase 10,
# WORLD_STATE_DESIGN, TECHNICAL_DESIGN §4): per run it prepares and
# per level it places the world objects that PERSIST across runs:
#
#   - the 4 player note stands (WORLD_STATE_DESIGN §4: camp, village,
#     shrine, undercroft; 1 note per stand, read NEXT run);
#   - the mummy (#5, RUN 03+): the previous run's last_death_pos
#     remapped into the current layout (the world «сохранил» her);
#     if the death room is gone from the new layout — skipped
#     (the world keeps what the layout still has — an honest limit);
#   - the K7 post-boss visuals (WORLD_STATE_DESIGN §6, the trigger
#     flag `boss_defeated` is set by the boss in Phase 12): the gate
#     glow + the city silhouette behind it;
#   - the «memorial» shimmer: one 1 s emissive pulse on first
#     approach per run (WORLD_STATE_DESIGN §9.2: the player notices
#     «что изменилось»).
#
# Scene-composed (NOT an autoload): main calls prepare_run at the
# respawn rebuild, on_level_entered after zone_world.enter, and
# update(delta) in the physics loop. O(1) per frame (≤ 5 shimmer
# targets; distance checks only).
class_name WorldDirector
extends Node

const _TL = preload("res://scripts/gameplay/echo/ghost_timeline.gd")
const _PNS = preload("res://scripts/world/player_note_stand.gd")
const _MUMMY = preload("res://scripts/world/world_mummy.gd")

# The mummy appears from this run on (#5: RUN 03 D2 «тут мумия Эли»).
const MUMMY_RUN_MIN: int = 3
# The shimmer: one 1 s pulse on first approach per run (§9.2).
const SHIMMER_RADIUS: float = 3.0
const SHIMMER_SECONDS: float = 1.0
# The K7 gate glow / city silhouette (WORLD_STATE_DESIGN §6).
const BOSS_FLAG: StringName = &"boss_defeated"
const CITY_DISTANCE: float = 16.0

var note_lines: Variant = null  # NoteLinesData
var stands_data: Variant = null  # PlayerNoteStandsData
var transform: Variant = null  # WorldTransformData

var _ws: Variant = null
var _player: Node = null
var _camp_world: Node3D = null
var _run_id: int = 1
var _layout: Variant = null  # the current run's layout
var _mummy_pos: Vector3 = Vector3.INF  # remapped ("" run space)
var _stand: Variant = null  # the current level's stand (if any)
var _mummy: Variant = null  # the current level's mummy (if any)
var _k7_nodes: Array = []  # the current level's K7 visuals
var _shimmers: Array = []  # {root, mat, base, t, done}
var _last_note: Dictionary = {}


func setup(p_ws: Variant, p_note_lines: Variant, p_stands: Variant,
		p_transform: Variant, p_camp_world: Node3D, p_player: Node) -> void:
	_ws = p_ws
	note_lines = p_note_lines
	stands_data = p_stands
	transform = p_transform
	_camp_world = p_camp_world
	_player = p_player


# The respawn-rebuild hook (main, after the layout regen, BEFORE the
# first _enter_level): arm this run's persistent objects.
func prepare_run(run_id: int, prev_record, old_layout, new_layout) -> void:
	clear()
	if _ws == null:
		return
	_run_id = run_id
	_layout = new_layout
	_mummy_pos = Vector3.INF
	# #5: RUN 03+ at the previous run's last_death_pos (remapped).
	if run_id >= MUMMY_RUN_MIN and prev_record != null \
			and int(prev_record.get("deaths", 0)) > 0 \
			and prev_record.get("last_death_pos",
					Vector3.ZERO) != Vector3.ZERO:
		var p: Vector3 = _TL._remap_pos(
				prev_record.last_death_pos, old_layout, new_layout)
		if p != Vector3.INF:
			_mummy_pos = p
		else:
			# The death room is gone from the new layout — the
			# mummy is skipped (honest limit, documented).
			push_warning("WorldDirector: the death room is gone from "
					+ "the new layout; the mummy is skipped")
	_last_note = _ws.last_note()


# A level switch (main, after zone_world.enter): place the objects
# that live in THIS level (the level node is rebuilt on every entry,
# so they are rebuilt too; their STATE comes from WorldState).
func on_level_entered(area_id: StringName, level: Node) -> void:
	clear()
	if _ws == null or level == null:
		return
	_place_stand(area_id, level)
	_place_mummy(level, area_id)
	if _ws.flag(BOSS_FLAG):
		_place_k7(area_id, level)


func current_stand() -> Node:
	return _stand


func current_mummy() -> Node:
	return _mummy


# One 1 s pulse per object per run on first approach (§9.2).
func update(delta: float) -> void:
	if _player == null or _shimmers.is_empty():
		return
	var p: Vector3 = _player.get_body_position()
	for i in _shimmers.size():
		var s: Dictionary = _shimmers[i]
		var root: Node = s.root
		if not is_instance_valid(root):
			continue
		if not s.done and root.global_position.distance_to(p) \
				< SHIMMER_RADIUS:
			s.done = true
			s.t = SHIMMER_SECONDS
		if s.t > 0.0:
			s.t = maxf(0.0, s.t - delta)
			var k: float = s.t / SHIMMER_SECONDS
			s.mat.emission_energy_multiplier = s.base * (1.0 + 2.0 * k)


func clear() -> void:
	if is_instance_valid(_stand):
		_stand.queue_free()
	_stand = null
	if is_instance_valid(_mummy):
		_mummy.queue_free()
	_mummy = null
	for n in _k7_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_k7_nodes.clear()
	_shimmers.clear()


# --- placement -------------------------------------------------------

func _place_stand(area_id: StringName, level: Node) -> void:
	if stands_data == null or note_lines == null:
		return
	var entry: Variant = stands_data.entry_in_area(area_id)
	if entry == null:
		return
	var stand: _PNS = _PNS.new()
	stand.stand_id = entry.stand_id
	var note: Dictionary = _ws.get_note(entry.stand_id)
	var readable: bool = not note.is_empty() \
			and int(note.get("run_id", 0)) < _run_id
	var line: String = ""
	if readable:
		var li: int = clampi(int(note.get("line_id", 0)), 0,
				note_lines.lines.size() - 1)
		line = note_lines.lines[li]
	stand.setup(_player)
	stand.refresh(line, readable)
	var pos: Vector3
	var parent: Node
	if area_id == &"camp":
		pos = entry.camp_pos
		parent = _camp_world
	else:
		pos = _stand_pos(entry, level)
		if pos == Vector3.INF:
			return
		parent = level
	stand.name = "PlayerNoteStand_" + String(entry.stand_id)
	stand.position = pos
	parent.add_child(stand)
	_stand = stand
	_shimmer_target(stand, 0.9)
	# The stand's own state (write/read) is wired by the main scene
	# (it owns WorldState + the NotePanel).


func _stand_pos(entry: Variant, level: Node) -> Vector3:
	var rp: Variant = _room_for(entry, level)
	if rp == null:
		return Vector3.INF
	return Vector3(rp.origin.x + entry.offset.x, 0.0,
			rp.origin.z + entry.offset.z)


# The room the stand lives in: the LAYOUT placement (the level node
# is built 1:1 from it; the layout is the source of truth).
func _room_for(entry: Variant, level: Node) -> Variant:
	if _layout != null and _layout.has_area(entry.area_id):
		var area: Variant = _layout.get_area(entry.area_id)
		var rp: Variant = area.room_at(entry.room_idx)
		if rp != null:
			return rp
	# Fallback: the level's rooms (1:1 chain order).
	var i: int = entry.room_idx
	for n in level.get_children():
		var rn: Node = n
		var r: Variant = rn.get("room")
		if r != null:
			if i == 0:
				return r
			i -= 1
	return null


func _place_mummy(level: Node, area_id: StringName) -> void:
	if _mummy_pos == Vector3.INF \
			or not _inside_area(_mummy_pos, level, area_id):
		return
	var mummy: _MUMMY = _MUMMY.new()
	mummy.has_note = not _last_note.is_empty()
	if mummy.has_note:
		mummy.note_text = _note_line_text(int(_last_note.get(
				"line_id", 0)))
	mummy.setup(_player)
	mummy.name = "WorldMummy"
	mummy.position = Vector3(_mummy_pos.x, 0.0, _mummy_pos.z)
	level.add_child(mummy)
	_mummy = mummy
	_shimmer_target(mummy, 1.2)


func _note_line_text(line_id: int) -> String:
	if note_lines == null or line_id < 0 \
			or line_id >= note_lines.lines.size():
		return ""
	return note_lines.lines[line_id]


# K7 (WORLD_STATE_DESIGN §6): the gate glows, the city silhouette
# is visible behind it. The gate door = the entry door of the gate
# area's first room (to_area != ""); the city is BEYOND it.
func _place_k7(area_id: StringName, level: Node) -> void:
	if area_id != &"ancient_gate" or _layout == null \
			or transform == null:
		return
	var door: Variant = _gate_door()
	if door == null:
		return
	var area: Variant = _layout.get_area(&"ancient_gate")
	var rp: Variant = area.room_at(0)
	var at: Vector3 = Vector3(rp.origin.x + door.local_pos.x, 0.0,
			rp.origin.z + door.local_pos.z)
	var beyond: Vector3 = Vector3(rp.origin.x + door.local_pos.x
			- door.facing.x * CITY_DISTANCE, 0.0,
			rp.origin.z + door.local_pos.z
			- door.facing.z * CITY_DISTANCE)
	if transform.gate_glow:
		_k7_nodes.append(_build_glow(level, at))
	if transform.city_visible:
		_k7_nodes.append(_build_city(level, beyond))


func _gate_door() -> Variant:
	var area: Variant = _layout.get_area(&"ancient_gate")
	if area == null or area.rooms.is_empty():
		return null
	var first: Variant = area.room_at(0)
	for d in first.doors:
		var rd: Variant = d
		if String(rd.to_area) != "":
			return rd
	return null


func _build_glow(level: Node, at: Vector3) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = "GateGlow"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(3.0, 3.0)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.85, 0.55, 0.35)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.45)
	fm.emission_energy_multiplier = 1.6
	pm.material = fm
	m.mesh = pm
	m.position = Vector3(at.x, 1.5, at.z)
	m.rotation.x = deg_to_rad(-90.0)
	level.add_child(m)
	return m


func _build_city(level: Node, at: Vector3) -> Node3D:
	# The silhouette: a dark flat box in the distance (a city, not a
	# wall — several boxes of different heights).
	var root: Node3D = Node3D.new()
	root.name = "CitySilhouette"
	root.position = Vector3(at.x, 0.0, at.z)
	for i in 5:
		var b: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(3.0 + float(i) * 0.4, 6.0 + float(i % 3) * 3.0,
				2.0)
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.07)
		bm.material = m
		b.mesh = bm
		b.position = Vector3(float(i - 2) * 3.4, 0.0, 0.0)
		root.add_child(b)
	level.add_child(root)
	return root


func _shimmer_target(root: Node, base_energy: float) -> void:
	# The pulse target: the first MeshInstance3D child with a
	# StandardMaterial3D (the object's main body).
	var mat: StandardMaterial3D = null
	var m: MeshInstance3D = null
	for c in root.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var me: Material = mi.mesh.material
		if me is StandardMaterial3D:
			mat = me
			m = mi
			break
	if mat == null:
		return
	mat.emission_enabled = true
	if mat.emission == Color.BLACK:
		mat.emission = Color(0.8, 0.72, 0.55)  # «memorial» warm pulse
	if mat.emission_energy_multiplier < base_energy:
		mat.emission_energy_multiplier = base_energy
	_shimmers.append({"root": m, "mat": mat,
			"base": base_energy, "t": 0.0, "done": false})


func _inside_area(p: Vector3, level: Node, area_id: StringName) -> bool:
	# The camp ring (the mummy can die in the camp hub too) — only the
	# camp level is answered against it (a zone level's rooms live in
	# run space, near the hub, and must not claim the camp deaths).
	if area_id == &"camp" and _layout != null:
		var camp: Variant = _layout.get_area(&"camp")
		if camp != null and camp.rooms.size() > 0:
			var rp: Variant = camp.rooms[0]
			var c: Vector2 = Vector2(rp.origin.x, rp.origin.z)
			var q: Vector2 = Vector2(p.x, p.z)
			var sz: Vector2 = (rp.room.size as Vector2) * 0.5
			if absf(q.x - c.x) <= sz.x + 2.5 and absf(q.y - c.y) \
					<= sz.y + 2.5:
				return true
	var rooms: Array = level.get_children()
	for n in rooms:
		var rn: Node = n
		var rp: Variant = rn.get("room")
		if rp == null:
			continue
		var c: Vector2 = Vector2(rp.origin.x, rp.origin.z)
		var q: Vector2 = Vector2(p.x, p.z)
		var sz: Vector2 = (rp.room.size as Vector2) * 0.5
		if absf(q.x - c.x) <= sz.x + 0.25 and absf(q.y - c.y) \
				<= sz.y + 0.25:
			return true
	return false
