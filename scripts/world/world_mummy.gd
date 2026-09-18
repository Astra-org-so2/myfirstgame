# WorldMummy — the world's memory of the death (#5, RUN 03 D2):
# «тут мумия Эли — мир „сохранил" её» (a mummy, not a corpse —
# the world preserved her). Appears from RUN 03 (run_id >= 3) at the
# player's previous run's last_death_pos (remapped to the current
# layout by the WorldDirector; if the death room is gone, it is
# skipped — the world keeps what the layout still has).
#
# Examine (1 s hold-free E) shows the line; the note in her hand is
# the player's LAST written note (WORLD_STATE_DESIGN section 4:
# «в руках — последняя записка игрока»). Sets `corpse_seen` (the
# scene applies the flag + MUMMY_EXAMINED once).
#
# Code-built (ADR-022/024): a lying capsule + head + the note.
class_name WorldMummy
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")

# The examine line (scene constant, FIRST_3_RUNS #5 — the world
# keeps what it keeps).
const LINE_EXAMINE: String = \
		"You died here. The world kept you."

var has_note: bool = false
var note_text: String = ""

signal examined(stand: Node3D)

var _ia: _INTERACTABLE
var _label: Label3D
var _line_left: float = 0.0
var _examined: bool = false


func setup(target: Node) -> void:
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_mummy"
	_ia.prompt = "Look (E)"
	_ia.interact_radius = 2.4
	_ia.set_target(target)
	add_child(_ia)
	_ia.interacted.connect(_on_interacted)
	# The body: a lying capsule (desaturated — «сохранил», not
	# rotting) + the head sphere.
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.18
	cm.height = 0.9
	var bm: StandardMaterial3D = StandardMaterial3D.new()
	bm.albedo_color = Color(0.62, 0.58, 0.5)
	cm.material = bm
	body.mesh = cm
	body.position = Vector3(-0.35, 0.22, 0.0)
	body.rotation.z = deg_to_rad(90.0)
	add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	var hm: StandardMaterial3D = StandardMaterial3D.new()
	hm.albedo_color = Color(0.58, 0.54, 0.47)
	sm.material = hm
	head.mesh = sm
	head.position = Vector3(0.25, 0.24, 0.0)
	add_child(head)
	# The note in her hand (a small board near the «hand» end) —
	# only if the player left a note (the LAST one, section 4).
	if has_note:
		var note: MeshInstance3D = MeshInstance3D.new()
		var nm: BoxMesh = BoxMesh.new()
		nm.size = Vector3(0.22, 0.02, 0.3)
		var nmat: StandardMaterial3D = StandardMaterial3D.new()
		nmat.albedo_color = Color(0.9, 0.87, 0.78)
		nm.material = nmat
		note.mesh = nm
		note.position = Vector3(0.45, 0.12, 0.1)
		add_child(note)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.93, 0.88, 0.0)
	_label.visible = false
	_label.position = Vector3(0.0, 1.1, 0.0)
	add_child(_label)


func _on_interacted(_node: Node) -> void:
	_label.text = LINE_EXAMINE
	if has_note:
		_label.text += "\n\"%s\"" % note_text
	_label.visible = true
	_line_left = 3.0
	_label.modulate.a = 0.95
	if not _examined:
		_examined = true
		examined.emit(self)


func _physics_process(delta: float) -> void:
	if not _label.visible:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_label.visible = false
		_label.modulate.a = 0.0
