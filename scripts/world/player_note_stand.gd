# PlayerNoteStand — one of the 4 writable note stands
# (WORLD_STATE_DESIGN section 4): the player writes a note (1 of the
# 5-line pool, no free text), the world stores it (WorldState), it
# is READABLE NEXT RUN. One note per stand, «перезапись» replaces.
#
# Code-built (ADR-022/024): the stand look (post + board) is the
# NoteStand pattern; the write/read behavior is here. The scene
# (WorldDirector/main) owns the WorldState write and the NotePanel.
class_name PlayerNoteStand
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")

# The note the player left (run_id < the current run = readable).
var stand_id: StringName = &""
var readable_line: String = ""  # "" = nothing to read yet
var has_readable: bool = false

signal write_requested(stand_id: StringName)
signal note_read(stand_id: StringName, first_time: bool)

var _ia: _INTERACTABLE
var _label: Label3D
var _label_left: float = 0.0
var _read_done: bool = false


func setup(target: Node) -> void:
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_write_" + String(stand_id)
	_ia.prompt = "Write a note (E)"
	_ia.interact_radius = 2.2
	_ia.set_target(target)
	add_child(_ia)
	_ia.interacted.connect(_on_interacted)
	# The stand: two posts + a board (the NoteStand look, a bit
	# smaller — it is the player's own desk in the world).
	for side in [-0.18, 0.18]:
		var post: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.06, 1.1, 0.06)
		var pm: StandardMaterial3D = StandardMaterial3D.new()
		pm.albedo_color = Color(0.55, 0.48, 0.38)
		box.material = pm
		post.mesh = box
		post.position = Vector3(side, 0.55, 0.0)
		add_child(post)
	var board: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 0.03)
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.7, 0.64, 0.5)
	bm.material = bmat
	board.mesh = bm
	board.position = Vector3(0.0, 0.95, 0.0)
	add_child(board)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.93, 0.88, 0.0)
	_label.visible = false
	_label.position = Vector3(0.0, 1.5, 0.0)
	add_child(_label)


# The WorldDirector calls this every level entry: the note is
# readable from the NEXT run on (run_id < current run).
func refresh(readable: String, is_readable: bool) -> void:
	has_readable = is_readable
	readable_line = readable
	_ia.prompt = "Read your note (E)" if is_readable \
			else "Write a note (E)"
	if not is_readable:
		_label.visible = false
		_label.modulate.a = 0.0


func _on_interacted(_node: Node) -> void:
	if has_readable:
		_label.text = readable_line
		_label.visible = true
		_label_left = 4.0
		_label.modulate.a = 0.95
		var first: bool = not _read_done
		_read_done = true
		note_read.emit(stand_id, first)
		return
	_ia.prompt = "Write a note (E)"
	write_requested.emit(stand_id)


func _physics_process(delta: float) -> void:
	if not _label.visible:
		return
	_label_left -= delta
	if _label_left <= 0.0:
		_label.visible = false
		_label.modulate.a = 0.0
