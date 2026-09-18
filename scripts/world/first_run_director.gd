# FirstRunDirector — the scripted beats of the first 30 minutes
# (FIRST_30_MINUTES A1–A19, B1–B2): event-triggered, NOT timers.
#
# Every beat fires from a real player moment (a swing, a kill, a zone
# entry, a proximity) and is guarded by a world-state flag, so it can
# fire exactly once per save (flags persist; the layout regenerates).
# The director owns the one-off PROPS (the figure, the pyre, the note
# stands, the trace) and feeds the RunRecorder (EVENT_COMPLETED /
# NOTE_WRITTEN). The "what changed" lines are data (WorldFlagTable).
#
# A1 (the 2 s black fade) lives in the main scene (it owns the UI
# layer); B1 (Mara's return line) lives in the NpcData (talk flow).
class_name FirstRunDirector
extends Node3D

const _NOTE = preload("res://scripts/world/note_stand.gd")
const _BOOK = preload("res://scripts/world/world_book.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

# Canonical lines (FIRST_30_MINUTES — English MVP).
const LINE_A2: String = "YOU HAVE BEEN HERE BEFORE."
const LINE_A3: String = "I don't remember learning this."
const LINE_A7: String = ("If you find this, don't trust the version "
		+ "of me that comes after.")
const LINE_A15: String = "Nothing should ever truly disappear."
const LINE_A16: String = "YOU WILL OPEN THIS AFTER YOU DIE."
const LINE_A16_NOTE: String = "I was here. I didn't open it."
const LINE_A16_NOTE2: String = "I was here. I came back for it."
const LINE_A16_NOTE3: String = "I was here. It is still waiting."
const LINE_A14: String = "It's heavy. Use it once. — E."
const LINE_A17: String = "Don't go to the lake before the mine. — E."
const LINE_A12_NOTE: String = "what burned?"
const LINE_B2: String = "That wasn't there."
const LINE_A19: String = "Again?"
const LINE_KETTLE: String = "The kettle is cold."
const LINE_KETTLE_WASHED: String = "It's clean. Warm, even."
# #6 (RUN 03 D2): the Remnant reads the player's note (section 4).
const LINE_D6: String = "\u2026I forgot that."
# The Archivist whispers (DIALOGUE_GUIDELINES 2.7, MVP 5 lines).
const LINE_ARCHIVIST_KEPT: String = "He is kept. He is counted."
const LINE_ARCHIVIST_LAKE: String = \
		"You call it death because you cannot remember."
const LINE_ARCHIVIST_GATE: String = \
		"Welcome back, two-one-seven. I saved your seat."
const LINE_ARCHIVIST_NPC: String = "Remembered. Kept. Always."
# K5: the reflection lasts this long (NARRATIVE_STRUCTURE: 2 s).
const LAKE_REFLECTION_SECONDS: float = 2.0
# K4: the page states (M1.3 blank name -> M1.4 the world «writes» it).
const PAGE_K4: String = \
		"Eli. Profession: \u2014. Home: \u2014. First seen: \u2014."
const PAGE_M1_4: String = ("Eli. Profession: the one who forgets. "
		+ "Home: the forest. First seen: \u2014.")
const PAGE_BLANK: String = "\u2014 (a page, not written yet) \u2014"

# The figure's animation timing (A10: head turn, then a 1 s fade).
const FIGURE_TURN_SECONDS: float = 0.6
const FIGURE_FADE_SECONDS: float = 1.0
const FIGURE_DISTANCE: float = 30.0

signal beat_fired(beat: StringName)

var _main: Node = null
var _zone_world: Node = null
var _player: Node = null
var _ws: Node = null
var _rm: Node = null
# Phase 11: the reveal gate (MysteryDirector, scene-owned).
var _mystery: Variant = null

# A10 figure state (one animation per session, RUN 1 only).
var _figure: Node3D = null
var _figure_head: Node3D = null
var _figure_stage: int = 0  # 1 turning, 2 fading, 3 done
var _figure_t: float = 0.0
var _figure_meshes: Array = []
var _pyre_pos: Vector3 = Vector3.INF
var _b2_shown: bool = false
var _again_shown: bool = false
var _a3_done: bool = false
var _d6_done: bool = false
var _lake_reflection_done: bool = false
var _lake_reflection: Node3D = null
var _lake_reflection_t: float = 0.0


func setup(m: Node, zw: Node, p: Node, ws_ref: Variant, rm: Node,
		mystery_ref: Variant = null) -> void:
	_main = m
	_zone_world = zw
	_player = p
	_ws = ws_ref
	_rm = rm
	_mystery = mystery_ref
	# Camp beats (CampWorld persists for the session): the pillar,
	# the note stand and the kettle are existing interactables.
	# Hooked in setup (not _ready): _ready runs before main has
	# composed the scene, so _main is still null there.
	_hook_camp_interactable("IA_Pillar", _beat_pillar)
	_hook_camp_interactable("IA_NoteStand", _beat_camp_note)
	_hook_camp_interactable("IA_Kettle", _beat_kettle)
	# A3: the player's first swing (the blade is adopted at start).
	_bind_swing()


func _ready() -> void:
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	if bus != null:
		bus.enemy_killed.connect(_on_enemy_killed)
		bus.echo_triggered.connect(_on_echo_triggered)


# #6 (RUN 03, section 4): the player left a note — the Remnant
# reads it on its first-encounter sequence (a third line).
# MVP limit: the line beat, not the "interrupts combat to walk over"
# choreography (documented in the phase QA).
func _on_echo_triggered(echo_type: StringName, _pos: Vector3) -> void:
	if _rm == null or _ws == null:
		return
	# Archivist whisper #2 (DIALOGUE_GUIDELINES 2.7): at the first
	# Echo — once per session.
	if not _ws.flag(&"he_is_counted_whisper"):
		_ws.set_flag(&"he_is_counted_whisper")
		_toast(LINE_ARCHIVIST_KEPT, 4.0)
	if echo_type != &"combat":
		return
	# #1 (M3 stage 1): the Remnant speaks for the first time.
	if not _ws.flag(&"first_echo_seen"):
		_ws.set_flag(&"first_echo_seen")
		_mystery_reveal(&"m3_first_echo")
	# #6 (M3 stage 2, RUN 03 + a note): the note line.
	if _d6_done or int(_rm.run_id) < 3:
		return
	if (_ws.last_note() as Dictionary).is_empty():
		return
	_d6_done = true
	_mystery_reveal(&"m3_note")
	var d: Node = _main.get("director") if _main != null else null
	if d == null:
		return
	for e in d.get_alive_enemies():
		var ctrl: Node = e
		var data: Node = ctrl.data()
		if data != null and data.id == &"remnant_mirror" \
				and ctrl.has_method("add_encounter_line"):
			ctrl.add_encounter_line(LINE_D6)
			break


func _bind_swing() -> void:
	if _player == null:
		return
	var w: Node = _player.get("weapon")
	if w != null and w.has_signal("swing_started") \
			and not w.is_connected(&"swing_started", _on_first_swing):
		w.swing_started.connect(_on_first_swing)


func _hook_camp_interactable(ia_name: String, cb: Callable) -> void:
	if _main == null:
		return
	var camp: Node = _main.find_child("CampWorld", true, false)
	if camp == null:
		return
	var ia: Node = camp.find_child(ia_name, true, false)
	if ia != null and ia.has_signal("interacted"):
		ia.interacted.connect(cb)


# The main scene calls this for every level switch (incl. respawns).
func on_level_entered(area_id: StringName) -> void:
	if _rm == null or _ws == null:
		return
	# ENTER_ROOM for the run record (the entry room of the level).
	_record_event(_EV.Type.ENTER_ROOM, 0)
	match String(area_id):
		&"ruined_village":
			_build_pyre()
			_place_note(area_id, "village_note",
					PackedStringArray([LINE_A12_NOTE]), &"",
					0, 2.5)
			_place_book(area_id)
		&"mysterious_lake":
			_build_ice_circle()
			_place_note(area_id, "lake_note",
					PackedStringArray([LINE_A17]), &"lake_note_read",
					1, 3.0)
			# K5 (M3 stage 3, RUN 05+): the reflection in the water.
			_beat_lake_reflection()
		&"ancient_gate":
			# A16 (RUN 1) / B2 (RUN 02+): the seal, then the open door
			# (M2 stage 2, the world answers).
			_beat_gate()
			# The footnotes stand on every entry (the level is
			# rebuilt per entry; the stand itself is idempotent).
			_place_gate_footnotes()
			# Whisper #4 (post-boss only; the flag is Phase 12).
			_beat_gate_welcome()
		&"the_mine":
			# A14: RUN 1 the cannon box carries the NOTE, not the
			# weapon (main._place_weapons gates the pickup and calls
			# this for the note stand).
			pass
		&"old_shrine":
			_beat_shrine_whisper()
	# A10: the figure on the FIRST zone entry of RUN 1.
	if _rm.run_id == 1 and not _ws.flag(&"figure_seen") \
			and area_id != &"camp":
		_spawn_figure(area_id)


# The main scene calls this when a level is rebuilt for a new run.
func on_run_started(run_id: int) -> void:
	if _ws == null:
		return
	if run_id == 1:
		_build_distant_hollow()
	# RUN 2+: the trace of the first kill (A5) + the "Again?" line
	# (A19, once per session).
	if run_id >= 2:
		_build_first_kill_trace()
		if not _again_shown:
			_again_shown = true
			_toast(LINE_A19, 2.5)
	_place_veyra_map()


# M4.3 consequence (the map board in the camp): the Cartographer drew
# the city (the line sets veyra_city_told) — from the next run on the
# board stands in the camp (the camp is persistent, so the board
# stays). The label «VEYRA B»: a second forest (the burned one, M4.3).
func _place_veyra_map() -> void:
	if _ws == null or not _ws.flag(&"veyra_city_told"):
		return
	if _main == null:
		return
	var camp: Node = _main.find_child("CampWorld", true, false)
	if camp == null or camp.find_child("VeyraMap", true, false) != null:
		return
	var root: Node3D = Node3D.new()
	root.name = "VeyraMap"
	# By the Cartographer (camp position -3.6/0.6).
	root.position = Vector3(-4.6, 0.0, 0.0)
	var frame: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(0.9, 1.2, 0.06)
	var fmat: StandardMaterial3D = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.5, 0.42, 0.32)
	fm.material = fmat
	frame.mesh = fm
	frame.position = Vector3(0.0, 1.1, 0.0)
	root.add_child(frame)
	var paper: MeshInstance3D = MeshInstance3D.new()
	var pm: BoxMesh = BoxMesh.new()
	pm.size = Vector3(0.8, 1.0, 0.02)
	var pmat: StandardMaterial3D = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.8, 0.74, 0.6)
	pm.material = pmat
	paper.mesh = pm
	paper.position = Vector3(0.0, 1.1, 0.04)
	root.add_child(paper)
	var label: Label3D = Label3D.new()
	label.text = "VEYRA B"
	label.position = Vector3(0.0, 1.1, 0.07)
	label.outline_size = 2
	label.modulate = Color(0.35, 0.28, 0.2)
	root.add_child(label)
	camp.add_child(root)


# --- A2 — the pillar ----------------------------------------------------

func _beat_pillar(_ia: Node) -> void:
	if _ws == null or _ws.flag(&"pillar_seen"):
		return
	_ws.set_flag(&"pillar_seen")
	_toast(LINE_A2, 3.0)
	_record_event(_EV.Type.EVENT_COMPLETED, 2)
	beat_fired.emit(&"a2_pillar")


# --- A3 — the first swing ------------------------------------------------

func _on_first_swing() -> void:
	# The beat is the player's FIRST swing of the session (A3).
	# blade_found cannot gate it: the flag is already set when the
	# run starts (the blade is adopted), before any swing happens.
	if _a3_done:
		return
	_a3_done = true
	if _ws != null:
		_ws.set_flag(&"blade_found")
	_toast(LINE_A3, 3.0)
	_record_event(_EV.Type.EVENT_COMPLETED, 3)
	_mystery_reveal(&"m1_k1")  # M1 stage 1 (K1)
	beat_fired.emit(&"a3_first_swing")


# --- A5 — the first Hollow kill (the trace, visible in RUN 02) ----------

func _on_enemy_killed(enemy_id: StringName, pos: Vector3) -> void:
	if _ws == null or _ws.flag(&"first_hollow_killed"):
		return
	if not String(enemy_id).begins_with("hollow"):
		return
	_ws.set_flag(&"first_hollow_killed")
	# The trace position (data, not a flag value display): a pos3 the
	# RUN 02+ camp rebuild places a scorch mark at.
	_ws.set_flag(&"first_kill_pos", pos)
	_record_event(_EV.Type.EVENT_COMPLETED, 5)
	_mystery_reveal(&"m2_trace")  # M2 stage 1 (the trace, A5)
	beat_fired.emit(&"a5_first_kill")


# --- A4 — the distant Hollow (atmosphere, RUN 1 camp) -------------------

func _build_distant_hollow() -> void:
	if _main == null:
		return
	var layer: Node = _main.find_child("CampLayer", true, false)
	if layer == null or layer.find_child("A4_Hollow", true, false) != null:
		return
	var fig: Node3D = Node3D.new()
	fig.name = "A4_Hollow"
	# 20 m out, past the mine gate's bearing (the fog edge).
	fig.position = Vector3(0.0, 0.0, -20.0)
	layer.add_child(fig)
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	body.mesh = cm
	body.position = Vector3(0.0, 0.9, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.33, 0.35, 0.5)  # 50% opacity
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fig.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	head.mesh = sm
	head.position = Vector3(0.0, 2.05, 0.0)
	head.material_override = mat
	fig.add_child(head)


# --- A7 — the camp note (#2, own handwriting) ---------------------------

func _beat_camp_note(_ia: Node) -> void:
	_toast(LINE_A7, 5.0)
	_record_event(_EV.Type.EVENT_COMPLETED, 7)
	beat_fired.emit(&"a7_camp_note")


# --- the kettle (B1 seed: the visible consequence of the first death) ---

func _beat_kettle(_ia: Node) -> void:
	if _ws != null and _ws.flag(&"kettle_washed"):
		_toast(LINE_KETTLE_WASHED, 3.0)
	else:
		_toast(LINE_KETTLE, 2.5)


# --- A10 — the figure (pred-echo: not the Watcher) ----------------------

func _spawn_figure(area_id: StringName) -> void:
	if _figure != null:
		return
	var a: Node = _zone_world.layout.get_area(area_id)
	if a == null:
		return
	# Stand 30 m out along the chain (from room 1 toward room 0).
	var rooms: Array = a.rooms
	var from: Vector3
	var to: Vector3
	if rooms.size() >= 2:
		from = Vector3(rooms[1].origin.x, 0.0, rooms[1].origin.z)
		to = Vector3(rooms[0].origin.x, 0.0, rooms[0].origin.z)
	else:
		from = Vector3(rooms[0].origin.x + 10.0, 0.0,
				rooms[0].origin.z)
		to = Vector3(rooms[0].origin.x, 0.0, rooms[0].origin.z)
	var dir: Vector3 = (to - from)
	if dir.length() < 0.5:
		dir = Vector3(1.0, 0.0, 0.0)
	dir = dir.normalized()
	var pos: Vector3 = to - dir * FIGURE_DISTANCE
	var fig := _build_el_figure()
	fig.name = "EliFigure"
	fig.position = pos
	_zone_world.level.add_child(fig)
	_figure = fig
	_figure_head = fig.find_child("Head", true, false)
	_figure_stage = 1
	_figure_t = 0.0
	_build_footprints(pos, dir)
	_ws.set_flag(&"figure_seen")
	_record_event(_EV.Type.EVENT_COMPLETED, 10)
	beat_fired.emit(&"a10_figure")


func _build_el_figure() -> Node3D:
	# Eli's silhouette: the player's build, 100% opacity, no "worn"
	# material (a FRESH copy — GDD §8).
	var fig: Node3D = Node3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.8, 0.76)
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.7
	body.mesh = cm
	body.position = Vector3(0.0, 0.85, 0.0)
	body.material_override = mat
	body.name = "Body"
	fig.add_child(body)
	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.95, 0.0)
	fig.add_child(head)
	var hm: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	hm.mesh = sm
	hm.material_override = mat
	head.add_child(hm)
	_figure_meshes.clear()
	_figure_meshes.append(body)
	_figure_meshes.append(hm)
	return fig


func _build_footprints(pos: Vector3, dir: Vector3) -> void:
	# Footprints lead AWAY from the figure (toward the player's next
	# step — on the scripted path that is the village).
	for i in 10:
		var fp: MeshInstance3D = MeshInstance3D.new()
		var pm: PlaneMesh = PlaneMesh.new()
		pm.size = Vector2(0.18, 0.3)
		fp.mesh = pm
		var p: Vector3 = pos + dir * (0.8 + float(i) * 0.7)
		fp.position = Vector3(p.x, 0.02, p.z)
		fp.rotation.y = atan2(dir.x, dir.z)
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.14, 0.13, 0.55)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fp.material_override = mat
		_zone_world.level.add_child(fp)


func _tick_figure(delta: float) -> void:
	if _figure == null:
		return
	_figure_t += delta
	if _figure_stage == 1:
		# Head turn (0.6 s to 90°).
		var k: float = clampf(_figure_t / FIGURE_TURN_SECONDS, 0.0, 1.0)
		_figure_head.rotation.y = deg_to_rad(90.0 * k)
		if k >= 1.0:
			_figure_stage = 2
			_figure_t = 0.0
	elif _figure_stage == 2:
		var k: float = clampf(_figure_t / FIGURE_FADE_SECONDS, 0.0, 1.0)
		var a: float = 1.0 - k
		for m in _figure_meshes:
			if is_instance_valid(m):
				m.modulate.a = a
		if k >= 1.0:
			_figure_stage = 3
			var f: Node = _figure
			_figure = null
			f.queue_free()


# --- A12 — the village pyre + note stand ---------------------------------

func _build_pyre() -> void:
	var a: Node = _zone_world.layout.get_area(&"ruined_village")
	if a == null:
		return
	var rooms: Array = a.rooms
	var base: Vector3
	if rooms.size() >= 2:
		base = Vector3(rooms[1].origin.x, 0.0, rooms[1].origin.z)
	else:
		base = Vector3(rooms[0].origin.x, 0.0, rooms[0].origin.z)
	_pyre_pos = base + Vector3(2.5, 0.0, 2.5)
	var level: Node = _zone_world.level
	# One hut of five: burnt (the ash, the char, the embers).
	var hut: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.9, 1.6, 1.9)
	hut.mesh = bm
	hut.position = _pyre_pos + Vector3(0.0, 0.8, 0.0)
	var char: StandardMaterial3D = StandardMaterial3D.new()
	char.albedo_color = Color(0.12, 0.09, 0.07)
	hut.material_override = char
	level.add_child(hut)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(1.4, 1.4)
	glow.mesh = pm
	glow.position = _pyre_pos + Vector3(0.0, 0.03, 0.0)
	var gm: StandardMaterial3D = StandardMaterial3D.new()
	gm.albedo_color = Color(0.9, 0.4, 0.15)
	gm.emission_enabled = true
	gm.emission = Color(0.9, 0.35, 0.1)
	gm.emission_energy_multiplier = 0.8
	glow.material_override = gm
	level.add_child(glow)


func _tick_pyre(delta: float) -> void:
	if _ws == null or _ws.flag(&"village_pyre_seen"):
		return
	if _pyre_pos == Vector3.INF or _player == null:
		return
	var ppos: Vector3 = _player.get_body_position()
	if ppos.distance_to(_pyre_pos) < 5.0:
		_ws.set_flag(&"village_pyre_seen")
		_record_event(_EV.Type.EVENT_COMPLETED, 12)
		beat_fired.emit(&"a12_pyre")


# --- A15 — the shrine whisper --------------------------------------------

func _beat_shrine_whisper() -> void:
	if _ws == null or _ws.flag(&"shrine_echo_seen"):
		return
	_ws.set_flag(&"shrine_echo_seen")
	_toast(LINE_A15, 4.0)
	_record_event(_EV.Type.EVENT_COMPLETED, 15)
	beat_fired.emit(&"a15_shrine")


# --- A16/B2 — the gate ----------------------------------------------------

func _beat_gate() -> void:
	if _ws == null:
		return
	if _rm.run_id == 1 and not _ws.flag(&"gate_seal_seen"):
		_ws.set_flag(&"gate_seal_seen")
		_toast(LINE_A16, 4.0)
		_place_gate_footnotes()
		_record_event(_EV.Type.EVENT_COMPLETED, 16)
		beat_fired.emit(&"a16_gate")
	elif _rm.run_id >= 2 and not _b2_shown and _ws.flag(&"gate_seal_seen"):
		# B2: the first time the open door is seen (after the seal was
		# seen) — Eli's own thought. M2 stage 2 (the world «answers»).
		_b2_shown = true
		_toast(LINE_B2, 3.0)
		_mystery_reveal(&"m2_gate")
		beat_fired.emit(&"b2_gate_open")


func _place_gate_footnotes() -> void:
	if _zone_world == null or _zone_world.level == null:
		return
	if _zone_world.level.find_child("NoteStand_gate_footnotes", true, false) != null:
		return
	# Three notes of "previous versions" at the base (M4 seed) — the
	# stand carries all three lines (shown in sequence).
	var a: Node = _zone_world.layout.get_area(&"ancient_gate")
	if a == null:
		return
	var rooms: Array = a.rooms
	var last: Node = rooms.back()
	_place_note_at(&"ancient_gate", "gate_footnotes", PackedStringArray([
			LINE_A16_NOTE, LINE_A16_NOTE2, LINE_A16_NOTE3]),
			&"gate_note_read", last.origin + Vector3(0.0, 0.0, 2.0))


# --- A17 — the lake -------------------------------------------------------

func _build_ice_circle() -> void:
	var a: Node = _zone_world.layout.get_area(&"mysterious_lake")
	if a == null:
		return
	var rp: Node = a.rooms[0]
	var ice: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(6.0, 6.0)
	ice.mesh = pm
	ice.position = Vector3(rp.origin.x, 0.02, rp.origin.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.85, 0.9, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.material_override = mat
	_zone_world.level.add_child(ice)


# --- the A14 mine note (RUN 1: the weapon is NOT taken) -------------------

func place_gated_weapon_note(area_id: StringName, weapon_id: StringName,
		pos: Vector3, line: String) -> void:
	# The RUN 1 box carries the weapon's NOTE (E.'s handwriting), not
	# the weapon (A14/A15: "the world gives the weapon after the first
	# death"). The line is the weapon's own note (WEAPON_LINES data).
	var flag: StringName = &"mine_note_read"
	if weapon_id == &"weapon_staff":
		flag = &"shrine_note_read"
	_place_note_at(area_id, "box_note_" + String(weapon_id),
			PackedStringArray([line]), flag, pos)


# --- A5 trace (RUN 02+): the mark where the first Hollow fell ------------

func _build_first_kill_trace() -> void:
	if _main == null:
		return
	var layer: Node = _main.find_child("CampLayer", true, false)
	if layer == null or layer.find_child("A5_Trace", true, false) != null:
		return
	var raw: Variant = _ws.get_flag(&"first_kill_pos", null)
	if typeof(raw) != TYPE_VECTOR3:
		return
	var mark: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 0.02
	mark.mesh = cm
	mark.position = Vector3(raw.x, 0.02, raw.z)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.09, 0.08, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mark.material_override = mat
	mark.name = "A5_Trace"
	layer.add_child(mark)


# --- helpers ---------------------------------------------------------------

func _place_note(area_id: StringName, beat: StringName,
		lines: PackedStringArray, flag: StringName, room_idx: int,
		offset_z: float) -> void:
	var a: Node = _zone_world.layout.get_area(area_id)
	if a == null or a.rooms.size() <= room_idx:
		return
	var rp: Node = a.rooms[room_idx]
	_place_note_at(area_id, beat, lines, flag,
			Vector3(rp.origin.x, 0.0, rp.origin.z)
			+ Vector3(0.0, 0.0, offset_z))


func _place_note_at(area_id: StringName, beat: StringName,
		lines: PackedStringArray, flag: StringName, pos: Vector3) -> void:
	if _zone_world == null or _zone_world.level == null:
		return
	var stand: _NOTE = _NOTE.new()
	stand.name = "NoteStand_" + String(beat)
	stand.lines = lines
	stand.flag_id = flag
	stand.beat = beat
	stand.position = pos
	stand.setup(_player)
	stand.note_read.connect(_on_note_read.bind(flag))
	_zone_world.level.add_child(stand)


func _on_note_read(_stand: Node, first_time: bool, flag: StringName) -> void:
	if not first_time:
		return
	if flag != &"":
		_ws.set_flag(flag)
	# M4 stage 1 (M4.1): the three «previous versions» at the gate
	# (the handwritings differ — «not all of us are one»).
	if flag == &"gate_note_read":
		_mystery_reveal(&"m4_gate")
	# A note left/read is a NOTE_WRITTEN moment for the record
	# (the player's own handwriting — GDD §8).
	_record_event(_EV.Type.NOTE_WRITTEN, 0)


func _mystery_reveal(stage_id: StringName) -> void:
	if _mystery == null or _rm == null or _ws == null:
		return
	_mystery.reveal(stage_id, _ws, _rm.run_id)


func _record_event(type: int, data: int) -> void:
	if _rm == null or _player == null:
		return
	var pos: Vector3 = _player.get_body_position()
	_rm.record_event(type, 0, pos, 0, 0, data)


func _toast(text: String, seconds: float) -> void:
	if _main == null:
		return
	var t: Node = _main.get("toast")
	if t != null and t.has_method("show_text"):
		t.show_text(text, seconds)


func _physics_process(delta: float) -> void:
	_tick_figure(delta)
	_tick_pyre(delta)
	_tick_lake_reflection(delta)


# --- K4 — Nia's book (M1 stages 3-4) ------------------------------------
#
# RUN 03+: the book stands by Nia's table (village). The page state
# follows the world: blank (Nia's trust < 1) -> the name page
# (M1.3) -> the filled page (M1.4, RUN 05+: the world «writes»).
func _place_book(area_id: StringName) -> void:
	if _rm == null or _rm.run_id < 3 or _zone_world == null \
			or _zone_world.level == null:
		return
	var a: Node = _zone_world.layout.get_area(&"ruined_village")
	if a == null or a.rooms.is_empty():
		return
	var rp: Node = a.rooms[0]
	var book: _BOOK = _BOOK.new()
	book.name = "NiaBook"
	# By Nia (she stands at origin + 2.5/2.0; the book is at her table).
	book.position = Vector3(rp.origin.x + 3.4, 0.0, rp.origin.z + 2.6)
	var e: Dictionary = _ws.npc_entry(&"nia")
	var trust: int = int(e.trust)
	var filled: bool = _ws.flag(&"nia_name_seen")
	if filled:
		book.set_page(PAGE_M1_4)
	elif trust >= 1:
		book.set_page(PAGE_K4)
	else:
		book.set_page(PAGE_BLANK)
	book.setup(_player)
	book.page_read.connect(_on_book_page_read)
	_zone_world.level.add_child(book)


func _on_book_page_read() -> void:
	if _ws == null:
		return
	if not _ws.flag(&"nia_name_seen"):
		# M1 stage 3 (K4): the name is in the book («the life before»
		# is empty — a door, not an answer).
		_mystery_reveal(&"m1_book")
		return
	# M1 stage 4 (M1.4): the page is filled (RUN 05+).
	_mystery_reveal(&"m1_page")


# --- K5 — the lake reflection (M3 stage 3, RUN 05+) ---------------------
#
# In the lake is NOT the reflection: the Archivist (2 s,
# NARRATIVE_STRUCTURE K5) + the whisper. Once (lake_reflection_seen);
# NPC lines change after (the dialogue table reads the flag).
func _beat_lake_reflection() -> void:
	if _lake_reflection_done or _ws == null:
		return
	if _ws.flag(&"lake_reflection_seen"):
		_lake_reflection_done = true
		return
	if _rm == null or int(_rm.run_id) < 5:
		return
	if not _mystery.can_reveal(&"m3_lake", _ws, _rm.run_id):
		return
	var a: Node = _zone_world.layout.get_area(&"mysterious_lake")
	if a == null or a.rooms.is_empty():
		return
	var rp: Node = a.rooms[0]
	var fig: Node3D = _build_reflection_figure()
	fig.name = "LakeReflection"
	fig.position = Vector3(rp.origin.x, 0.0, rp.origin.z + 1.0)
	_zone_world.level.add_child(fig)
	_lake_reflection = fig
	_lake_reflection_t = LAKE_REFLECTION_SECONDS
	_toast(LINE_ARCHIVIST_LAKE, 4.0)
	_lake_reflection_done = true
	_mystery_reveal(&"m3_lake")
	beat_fired.emit(&"k5_lake_reflection")


func _build_reflection_figure() -> Node3D:
	# The Archivist in the MVP: a white monochrome silhouette
	# (monochrome + accent — WORLD_BIBLE 1.1), standing in the water.
	var root: Node3D = Node3D.new()
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.22
	cm.height = 1.2
	var bm: StandardMaterial3D = StandardMaterial3D.new()
	bm.albedo_color = Color(0.9, 0.9, 0.92)
	cm.material = bm
	body.mesh = cm
	body.position = Vector3(0.0, 0.85, 0.0)
	root.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.albedo_color = Color(0.92, 0.92, 0.94)
	sm.material = hm
	head.mesh = sm
	head.position = Vector3(0.0, 1.62, 0.0)
	root.add_child(head)
	return root


func _tick_lake_reflection(delta: float) -> void:
	if _lake_reflection_t <= 0.0 or _lake_reflection == null:
		return
	_lake_reflection_t -= delta
	# The 2 s presence: a slow fade (the reflection is not a door).
	var k: float = clampf(_lake_reflection_t / LAKE_REFLECTION_SECONDS,
			0.0, 1.0)
	for c in _lake_reflection.get_children():
		var mi: MeshInstance3D = c as MeshInstance3D
		if mi != null and mi.mesh != null:
			var me: Material = mi.mesh.material
			if me is StandardMaterial3D:
				(me as StandardMaterial3D).albedo_color.a = k
	if _lake_reflection_t <= 0.0 and is_instance_valid(_lake_reflection):
		_lake_reflection.queue_free()
	_lake_reflection = null if _lake_reflection_t <= 0.0 \
			else _lake_reflection


# --- The Archivist behind the gate (post-boss whisper #4) --------------
func _beat_gate_welcome() -> void:
	if _ws == null:
		return
	if not _ws.flag(&"boss_defeated"):
		return
	if _ws.flag(&"gate_welcome_whisper"):
		return
	_ws.set_flag(&"gate_welcome_whisper")
	_toast(LINE_ARCHIVIST_GATE, 4.5)
