# NoteStand — a scripted note beat (Phase 8, FIRST_30_MINUTES A7/A12/
# A14/A16/A17).
#
# A small wooden stand (code-built, ADR-024) + the Interactable pattern:
# interact → the canonical line (up to 3 short lines, shown in
# sequence) + a one-shot `note_read` signal (the scene sets the world
# flag and records NOTE_WRITTEN/EVENT_COMPLETED). Reading is
# repeatable (the line re-shows); the flag fires once (world state).
class_name NoteStand
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")

# Seconds per line on the label (the read window).
const LINE_SECONDS: float = 3.0

# The beat's lines (data: FIRST_30_MINUTES canonical text).
var lines: PackedStringArray = PackedStringArray()
var prompt: String = "Read the note"
# The flag to set on first read ("" = no flag).
var flag_id: StringName = &""
# The EventBus-style beat id for the scene (A-anchor bookkeeping).
var beat: StringName = &""

signal note_read(stand: Node3D, first_time: bool)

var _ia: _INTERACTABLE
var _label: Label3D
var _line_left: float = 0.0
var _line_idx: int = 0
var _read: bool = false


func setup(target: Node) -> void:
	var post: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.08, 1.4, 0.08)
	post.mesh = box
	post.position = Vector3(-0.2, 0.7, 0.0)
	add_child(post)
	var post2: MeshInstance3D = MeshInstance3D.new()
	var box2: BoxMesh = BoxMesh.new()
	box2.size = Vector3(0.08, 1.4, 0.08)
	post2.mesh = box2
	post2.position = Vector3(0.2, 0.7, 0.0)
	add_child(post2)
	var board: MeshInstance3D = MeshInstance3D.new()
	var board_mesh: BoxMesh = BoxMesh.new()
	board_mesh.size = Vector3(0.7, 0.5, 0.04)
	board.mesh = board_mesh
	board.position = Vector3(0.0, 1.05, 0.0)
	var board_mat: StandardMaterial3D = StandardMaterial3D.new()
	board_mat.albedo_color = Color(0.75, 0.68, 0.55)
	board.material_override = board_mat
	add_child(board)
	_label = Label3D.new()
	_label.text = tr("note")
	_label.position = Vector3(0.0, 1.75, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.93, 0.88, 0.0)
	_label.visible = false
	add_child(_label)
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_note_" + String(beat)
	_ia.prompt = prompt
	_ia.interact_radius = 2.2
	_ia.set_target(target)
	add_child(_ia)
	_ia.interacted.connect(_on_interacted)


func _on_interacted(_node: Node) -> void:
	_line_idx = 0
	_line_left = LINE_SECONDS
	_label.visible = true
	_label.text = lines[0]
	_label.modulate.a = 0.95
	var first: bool = not _read
	_read = true
	note_read.emit(self, first)


func _physics_process(delta: float) -> void:
	if not _label.visible:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		if _line_idx + 1 < lines.size():
			_line_idx += 1
			_line_left = LINE_SECONDS
			_label.text = lines[_line_idx]
		else:
			_label.visible = false
			_label.modulate.a = 0.0
