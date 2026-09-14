# Integration: the camp hub scene in the headless rig (Phase 3).
#
# Verifies the data-driven build (CampWorld from CampLayout) and the
# interactable prompt stubs. Rig constraints (ADR-022): player on the
# MovementPort mock (set_port seam) + deterministic manual _physics_process
# ticks; Input.action_press/release for input.
extends Node

const _CAMP = preload("res://scripts/world/camp_world.gd")
const _LAYOUT = preload("res://scripts/world/camp_layout.gd")
const _PLAYER = preload("res://scripts/player/player_controller.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _IA = preload("res://scripts/world/interactable.gd")

const DT: float = 1.0 / 60.0


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "camp: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		ctx.check(false, "camp: scene instantiates")
		return

	# Headless seam: mock physics before the player enters the tree.
	var player: _PLAYER = scene.find_child("Player", true, false)
	ctx.check(player != null and player is _PLAYER,
			"camp: player present in scene")
	if player == null:
		return
	var mock: _PORT = _PORT.new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	add_child(scene)

	var camp: _CAMP = scene.find_child("CampWorld", true, false)
	ctx.check(camp != null and camp is _CAMP, "camp: CampWorld present")
	if camp == null:
		return
	var layout: _LAYOUT = camp.layout

	# --- Data-driven build ---
	ctx.check(camp.tree_count == layout.tree_slots.size() and camp.tree_count > 0,
			"camp: trees built from data (%d)" % camp.tree_count)
	ctx.check(camp.zone_markers.size() == 8,
			"camp: 8 zone gate silhouettes")
	ctx.check(camp.tent_count == 3, "camp: 3 tents placed")
	ctx.check(scene.find_child("FireLight", true, false) is OmniLight3D,
			"camp: bonfire warm light present")
	var spawn: Marker3D = scene.find_child("SpawnPoint", true, false)
	ctx.check(spawn != null
			and spawn.global_position.distance_to(layout.spawn_pos) < 0.01,
			"camp: spawn at the data position")
	# Zone gates sit at the data angles.
	if camp.zone_markers.size() == 8:
		var m0: Node3D = camp.zone_markers[0]
		var a0: float = layout.zone_angles[0]
		var expect: Vector3 = Vector3(sin(deg_to_rad(a0)) * 10.5, 0.0,
				cos(deg_to_rad(a0)) * 10.5)
		ctx.check(m0.global_position.distance_to(expect) < 0.05,
				"camp: first zone gate at the data angle")

	# --- Interactable prompt (note stand) ---
	var ia: _IA = scene.find_child("IA_NoteStand", true, false)
	ctx.check(ia != null and ia is _IA, "camp: note stand interactable")
	if ia == null:
		return
	ctx.check(ia.get_target() != null,
			"camp: interactable wired to the player")

	# Move the player near the note stand (mock port, manual ticks).
	var np: Vector3 = layout.note_stand_pos
	mock.set_position(Vector3(np.x, 0.0, np.z + 0.8))
	_tick(player, ia, 3)
	ctx.check(ia.is_prompt_visible(), "camp: prompt visible near the object")

	# Interact edge fires exactly once (held-edge, ADR-022).
	var fired: Array = []
	ia.interacted.connect(func(_obj: Node3D) -> void:
		fired.append(true)
	)
	Input.action_press("interact")
	_tick(player, ia, 2)
	Input.action_release("interact")
	_tick(player, ia, 2)
	ctx.check(fired.size() == 1,
			"camp: interact fires once on the edge (got %d)" % fired.size())

	# Walk away -> prompt hides.
	mock.set_position(layout.spawn_pos)
	_tick(player, ia, 3)
	ctx.check(not ia.is_prompt_visible(),
			"camp: prompt hidden when away")


func _tick(p: _PLAYER, ia: _IA, n: int) -> void:
	for i in n:
		p._physics_process(DT)
		ia._physics_process(DT)
