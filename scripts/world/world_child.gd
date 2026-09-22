# WorldChild — The Child (CHARACTER_BIBLE section 5): the roaming
# entity, «the voice of the system». Scripted positions (not random,
# 1 per run window — the spawn table says the run + zone + position),
# ONE line per encounter (1 fact), INVULNERABLE (the final lock:
# the weapon passes through; an attempted swing at point-blank
# range answers with the one line + the `child_hit` soft penalty:
# the world «takes» the child — it stops appearing).
#
# Not a combat target (never registered with the DamageResolver —
# «weapon passes through» is structural, not an HP number).
class_name WorldChild
extends Node3D

const _INTERACTABLE = preload("res://scripts/world/interactable.gd")

# The attempted-hit answer (CHARACTER_BIBLE 5 — one line, once).
const LINE_HIT: String = \
		"It doesn't hurt anymore. I've been hit more times than that."
# A swing closer than this counts as an attempt (the weapon would
# have «passed through»).
const HIT_RADIUS: float = 1.8

signal spoke(line_index: int)
signal hit_attempted()

var encounter_lines: PackedStringArray = PackedStringArray()
var _encounter_idx: int = -1
var _hit_answered: bool = false

var textures: Variant = null  # the TextureBank (optional)
var _ia: _INTERACTABLE
var _label: Label3D
var _line_left: float = 0.0


func setup(target: Node) -> void:
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_Child"
	_ia.prompt = tr("Look (E)")
	_ia.interact_radius = 2.4
	_ia.set_target(target)
	add_child(_ia)
	_ia.interacted.connect(_on_interacted)
	# The look: a small silhouette (about 0.8 m), «dressed not for
	# the weather», «eyes too calm» — a desaturated cool capsule.
	var body: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.14
	cm.height = 0.6
	# Phase 13: the palette's pale presence through the cloth
	# texture (the bank is optional — flat fallback in tests).
	var _pal = load("res://data/visual/palette.tres")
	var bm: StandardMaterial3D
	if textures != null and textures.has("cloth"):
		bm = textures.material("cloth", _pal.child_pale, 0.85)
		if bm == null:
			bm = StandardMaterial3D.new()
			bm.albedo_color = _pal.child_pale
			bm.roughness = 0.85
	else:
		bm = StandardMaterial3D.new()
		bm.albedo_color = _pal.child_pale
		bm.roughness = 0.85
	cm.material = bm
	body.mesh = cm
	body.position = Vector3(0.0, 0.42, 0.0)
	add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.11
	sm.height = 0.22
	var hm: StandardMaterial3D = bm
	sm.material = hm
	head.mesh = sm
	head.position = Vector3(0.0, 0.84, 0.0)
	add_child(head)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.9, 0.92, 0.95, 0.0)
	_label.visible = false
	_label.position = Vector3(0.0, 1.35, 0.0)
	add_child(_label)


# The scene calls this when the player swings at point-blank range
# (the «attempted hit» — the weapon passes through).
func attempt_hit() -> void:
	if _hit_answered:
		return
	_hit_answered = true
	_show(LINE_HIT)
	hit_attempted.emit()


func _on_interacted(_node: Node) -> void:
	# One fact per encounter: the next line of the run's set
	# (the encounters reset with the run — the scene rebuilds us).
	_encounter_idx += 1
	if _encounter_idx >= encounter_lines.size():
		# No more facts: silence (the child «moves on»).
		return
	_show(encounter_lines[_encounter_idx])
	spoke.emit(_encounter_idx)


func _show(text: String) -> void:
	_label.text = text
	_label.visible = true
	_line_left = 4.0
	_label.modulate.a = 0.95


func _physics_process(delta: float) -> void:
	if not _label.visible:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		_label.visible = false
		_label.modulate.a = 0.0
