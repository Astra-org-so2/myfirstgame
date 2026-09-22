# WorldBook — Nia's book (K4, MYSTERY_REVEAL_MAP M1.3/M1.4): the
# shelf object in the village. The page STATE is set by the scene
# (blank -> «Eli. Profession: —.» -> the filled page, RUN 05): the
# book shows what the world has written so far. Reading shows the
# page for a few seconds; the scene applies the flags + the reveal.
class_name WorldBook
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")

# How long the page stays open after «Look (E)».
const PAGE_SECONDS: float = 6.0

var page_text: String = ""

signal page_read()

var _ia: _INTERACTABLE
var _label: Label3D
var _page_left: float = 0.0


func setup(target: Node) -> void:
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_Book"
	_ia.prompt = tr("Look (E)")
	_ia.interact_radius = 2.2
	_ia.set_target(target)
	add_child(_ia)
	_ia.interacted.connect(_on_interacted)
	# A small table + the open book.
	var table: MeshInstance3D = MeshInstance3D.new()
	var tm: BoxMesh = BoxMesh.new()
	tm.size = Vector3(1.0, 0.7, 0.6)
	var tmat: StandardMaterial3D = StandardMaterial3D.new()
	tmat.albedo_color = Color(0.42, 0.34, 0.26)
	tm.material = tmat
	table.mesh = tm
	table.position = Vector3(0.0, 0.35, 0.0)
	add_child(table)
	var book: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.5, 0.04, 0.36)
	var bmat: StandardMaterial3D = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.85, 0.8, 0.68)
	bm.material = bmat
	book.mesh = bm
	book.position = Vector3(0.0, 0.72, 0.0)
	add_child(book)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.93, 0.88, 0.0)
	_label.visible = false
	_label.position = Vector3(0.0, 1.3, 0.0)
	add_child(_label)


# The scene sets the page state (the world «writes» it).
func set_page(text: String) -> void:
	page_text = text
	# Re-show a currently open page with the new state (the world can
	# fill the page while the player is looking).
	if _label != null and _page_left > 0.0:
		_label.text = text


func _on_interacted(_node: Node) -> void:
	_show_page()
	page_read.emit()


# The page opens: the text the world has written so far (the state,
# never more — the book is a door, not an answer).
func _show_page() -> void:
	if page_text == "" or _label == null:
		return
	_label.text = page_text
	_label.visible = true
	_label.modulate.a = 1.0
	_page_left = PAGE_SECONDS


func _physics_process(delta: float) -> void:
	if _page_left <= 0.0:
		return
	_page_left -= delta
	if _page_left <= 0.0:
		_label.visible = false
		_label.modulate.a = 0.0
