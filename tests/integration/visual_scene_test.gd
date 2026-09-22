# Integration: Phase 13 visual pass in the live scene.
#
# Scene-composed visual systems (ADR-009): the QualityManager is
# wired to the environment/sun with the medium default (the
# mid-range Android base, TECH_DESIGN §12), the texture set lands
# on the camp surfaces and the room structure, and the light budget
# actually caps the RoomLights per level.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _ZONE = preload("res://scripts/world/zone_world.gd")
const _GEN = preload("res://scripts/gameplay/rooms/run_generator.gd")
const _AREA = preload("res://scripts/gameplay/areas/area_data.gd")


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "visual: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	var main: Node = scene
	var player_node: Node = scene.find_child("Player", true, false)
	var mock: _PORT = _PORT.new(null, 0.0, 0.0)
	player_node.set_port(mock)
	add_child(scene)
	main.set_physics_process(false)

	_test_quality_composed(ctx, main)
	_test_camp_surfaces(ctx, main)
	_test_room_materials(ctx)


func _test_quality_composed(ctx: Variant, main: Node) -> void:
	var quality: Node = main.get("quality")
	ctx.check(quality != null, "visual: the QualityManager is composed")
	if quality == null:
		return
	# Medium is the default (the mid-range base, §12).
	ctx.check(quality.preset != null
			and quality.preset.id == &"medium",
			"visual: medium preset by default")
	ctx.check(quality.light_budget() == 4,
			"visual: medium light budget = 4")
	ctx.check(quality.shadows_enabled(),
			"visual: medium keeps the sun shadows")
	# The sun in the scene really has shadows on (apply() ran; the
	# rig-observable getter is has_shadow).
	var sun: DirectionalLight3D = main.get_node_or_null("Sun")
	ctx.check(sun != null and sun.has_shadow(),
			"visual: the scene sun has shadows (medium)")


func _test_camp_surfaces(ctx: Variant, main: Node) -> void:
	var camp: Node = main.get_node_or_null("CampWorld")
	ctx.check(camp != null, "visual: CampWorld present")
	if camp == null:
		return
	# The tent shells: cloth texture tinted to the tent color.
	var tents: Node = camp.find_child("Tent", true, false)
	ctx.check(tents != null, "visual: a tent is built")
	# The rig no-ops MeshInstance3D.material, so the applied material
	# is verified through the camp's reskin registry (the production
	# reskin hook, [node, color, tex_id, material]).
	var entry: Variant = camp._reskin[0] if camp._reskin.size() > 0 else null
	var cloth_ok: bool = false
	for t in camp._reskin:
		if t[2] == "cloth":
			var m: StandardMaterial3D = t[3]
			cloth_ok = m != null and m.albedo_texture != null
	ctx.check(cloth_ok, "visual: the tent shell has the cloth texture")
	# The path: the ground texture.
	var path: Node = camp.get_node_or_null("Path")
	ctx.check(path != null and path.get_child_count() > 0,
			"visual: the path is built")
	if path != null and path.get_child_count() > 0:
		var ground_ok: bool = false
		for t in camp._reskin:
			if t[2] == "ground":
				var m: StandardMaterial3D = t[3]
				ground_ok = m != null and m.albedo_texture != null
		ctx.check(ground_ok, "visual: the path has the ground texture")
	# The zone gates' monoliths: the stone texture.
	var gate: Node = camp.get_node_or_null("ZoneGates")
	ctx.check(gate != null and gate.get_child_count() > 0,
			"visual: the zone gates are built")
	if gate != null and gate.get_child_count() > 0:
		var stone_ok: bool = false
		for t in camp._reskin:
			if t[2] == "stone":
				var m: StandardMaterial3D = t[3]
				stone_ok = m != null and m.albedo_texture != null
		ctx.check(stone_ok, "visual: the gate monolith has the stone texture")


# A standalone ZoneWorld (no run system): the room structure must
# carry the palette-tinted textures, and the light budget must cap
# the RoomLights deterministically.
func _test_room_materials(ctx: Variant) -> void:
	var gen: Variant = _GEN.new()
	var pool: Dictionary = {}
	for f in ["ancient_gate", "broken_bridge", "camp", "mysterious_lake",
			"old_shrine", "ruined_village", "the_mine", "undercroft",
			"watchtower"]:
		var res: Resource = load("res://data/areas/%s.tres" % f)
		if res != null:
			pool[(res as _AREA).id] = res
	gen.set_pool(pool)
	var layout: Variant = gen.generate(20260917, {})
	ctx.check(layout != null, "visual: the layout generates")
	if layout == null:
		return
	var ids: Array = layout.areas.keys()
	ctx.check(ids.size() > 0, "visual: the layout has areas")
	var bank: Node = main_bank(ctx)
	var zone: Node = _ZONE.new()
	add_child(zone)
	zone.textures = bank
	zone.setup(layout)
	zone.enter(ids[0])

	var rn: Node = zone.level.get_child(0)
	ctx.check(rn.floor_material != null
			and rn.floor_material.albedo_texture != null,
			"visual: the room floor has the ground texture")
	ctx.check(rn.wall_material != null
			and rn.wall_material.albedo_texture != null,
			"visual: the room walls have the stone texture")

	# The light budget: the rooms beyond it have NO light node
	# (the real GPU saving); raising the budget recreates them from
	# the room data.
	var rooms_n: int = zone.level.get_child_count()
	zone.set_light_budget(2)
	var lights: int = _count_lights(zone)
	ctx.check(lights == mini(rooms_n, 2),
			"visual: budget 2 -> %d light nodes (rooms=%d)"
			% [lights, rooms_n])
	zone.set_light_budget(6)
	lights = _count_lights(zone)
	ctx.check(lights == mini(rooms_n, 6),
			"visual: budget 6 lifts the cap (%d lights)" % rooms_n)
	# A recreated light carries the room's data energy.
	var idx: int = mini(rooms_n, 2) - 1
	if idx < 0:
		idx = 0
	var rn2: Node = zone.level.get_child(idx)
	var l2: Node = rn2.find_child("RoomLight", true, false)
	ctx.check(l2 != null and l2.light_energy > 0.0,
			"visual: the recreated light has its data energy")
	zone.queue_free()


func main_bank(ctx: Variant) -> Node:
	# A fresh bank (the main scene's is scene-internal; the room test
	# needs a bank attached to THIS node tree for the texture cache).
	var _B = preload("res://scripts/world/texture_bank.gd")
	var bank: Node = _B.new()
	add_child(bank)
	var n: int = bank.load_all()
	ctx.check(n == 7, "visual: the room-test bank loads (got %d)" % n)
	return bank


func _count_lights(zone: Node) -> int:
	var n: int = 0
	for c in zone.level.get_children():
		if c.find_child("RoomLight", true, false) != null:
			n += 1
	return n
