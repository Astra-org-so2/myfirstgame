# EchoStep — the ECHO STEP Inheritance (PROGRESSION_DESIGN: layer A #7).
#
# "The world watches your trail": a dodge leaves an afterimage (0.5 s
# ghost) and enemies that were LOOKING at it hesitate (a timed stun —
# the level sets the duration: 0.5/0.75/1.0 s). The effect value is
# read from InheritanceEffects at trigger time (a death-screen choice
# is live from the next run).
#
# A thin Node: it listens to the player's `dodge_started` signal
# (signal connect is rig-safe, ADR-022) and calls the enemies' pure
# logic (apply_stun). The ghost is a code-built capsule (ADR-024).
class_name EchoStep
extends Node

const _STATE = preload("res://scripts/gameplay/progression/progression_state.gd")

const GHOST_LIFE: float = 0.5
const STUN_RADIUS: float = 3.0
const LOOK_DOT: float = 0.5  # "looking" = facing within 60°

var _player: Node = null
var _director: Node = null
var _state: _STATE = null
var _ghosts: Array = []


func setup(player: Node, director: Node, state: _STATE) -> void:
	_player = player
	_director = director
	_state = state
	_player.dodge_started.connect(_on_dodge_started)


func _on_dodge_started() -> void:
	if _state == null or _player == null:
		return
	var start_pos: Vector3 = _player.get_body_position()
	var p: Dictionary = _state.effects.player(_state.ws)
	var stun: float = float(p["afterimage_stun"])
	if stun <= 0.0:
		return
	_spawn_ghost(start_pos)
	if _director == null:
		return
	for e in _director.get_alive_enemies():
		if e == null or not is_instance_valid(e):
			continue
		var to: Vector3 = start_pos - e.global_position
		var dist: float = to.length()
		if dist > STUN_RADIUS or dist < 0.01:
			continue
		var fwd: Vector3 = e.global_transform.basis.x
		fwd.y = 0.0
		var logic: Variant = e.logic()
		if logic == null or not logic.has_method("apply_stun"):
			continue
		if fwd.normalized().dot(to.normalized()) >= LOOK_DOT:
			logic.apply_stun(stun)


func _spawn_ghost(pos: Vector3) -> void:
	var ghost: Node3D = Node3D.new()
	ghost.name = "Afterimage"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.6
	mi.mesh = cm
	mi.position = Vector3(0.0, 0.8, 0.0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.7, 0.8, 1.0, 0.25)
	mi.material_override = mat
	ghost.add_child(mi)
	ghost.position = pos
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_parent()
	root.add_child(ghost)
	_ghosts.append(ghost)
	var t: SceneTreeTimer = get_tree().create_timer(GHOST_LIFE)
	t.timeout.connect(func() -> void:
		_ghosts.erase(ghost)
		if is_instance_valid(ghost):
			ghost.queue_free())


func reset_run() -> void:
	for g in _ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
