# Integration: Phase 13 batch 2 — the cast in the live scene.
#
# The characters receive the texture bank from the main scene (ADR-009
# composition) and build their final looks: Eli (hood/scarf/visor +
# cloth texture), the camp NPCs (hood/scarf from the data accents,
# Mara keeps her camp look with the hood + cloth), the enemies
# (archetype cloth + the echo tint), THE FIRST (the worn copy + the
# rust lantern).
#
# Materials: the code-built characters use material_override, the
# tscn ones (Eli's body, Mara) keep the material on the mesh — the
# checks read whichever slot is set.
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "cast: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	var main: Node = scene
	var player_node: Node = scene.find_child("Player", true, false)
	var mock: _PORT = _PORT.new(null, 0.0, 0.0)
	player_node.set_port(mock)
	add_child(scene)
	main.set_physics_process(false)

	_test_eli(ctx, main, player_node)
	_test_camp_npcs(ctx, main)


func _mesh_material(n: Node) -> StandardMaterial3D:
	var mi: MeshInstance3D = n
	if mi.material_override != null:
		return mi.material_override
	if mi.mesh != null:
		return mi.mesh.material
	return null


func _test_eli(ctx: Variant, main: Node, player_node: Node) -> void:
	var visual: Node = player_node.get_node_or_null("Visual")
	ctx.check(visual != null, "cast: the player visual exists")
	if visual == null:
		return
	var body: Node = visual.find_child("BodyMesh", true, false)
	var hood: Node = visual.find_child("Hood", true, false)
	var scarf: Node = visual.find_child("Scarf", true, false)
	ctx.check(body != null and hood != null and scarf != null,
			"cast: Eli has the body + hood + scarf")
	if body == null:
		return
	var mat: StandardMaterial3D = _mesh_material(body)
	ctx.check(mat != null and mat.albedo_texture != null,
			"cast: the Eli body carries the cloth texture")
	# The canonical cloak color (the tscn prototype blue is retired).
	var _pal: Resource = load("res://data/visual/palette.tres")
	if mat != null:
		var eff_r: float = mat.albedo_color.r * 70.0 / 255.0
		ctx.check(absf(eff_r - _pal.eli_cloak.r) < 0.02,
				"cast: the Eli tint is the palette cloak")


# The trust NPCs: each carries the hood + the scarf and the cloth
# texture (Mara through her camp look, the others through the shared
# builder with the data accents).
func _test_camp_npcs(ctx: Variant, main: Node) -> void:
	var npcs: Array = []
	for c in _collect(main, 0):
		if c.name.begins_with("NPC_"):
			npcs.append(c)
	ctx.check(npcs.size() == 4,
			"cast: the trust NPCs are built (got %d)" % npcs.size())
	var detailed: int = 0
	var textured: int = 0
	for npc in npcs:
		var n: Node = npc
		var hood: Node = n.find_child("Hood", true, false)
		var scarf: Node = n.find_child("Scarf", true, false)
		if hood != null and scarf != null:
			detailed += 1
		var body: Node = n.find_child("Body", true, false)
		if body != null and body is MeshInstance3D:
			var mat: StandardMaterial3D = _mesh_material(body)
			if mat != null and mat.albedo_texture != null:
				textured += 1
	ctx.check(detailed == npcs.size(),
			"cast: every NPC has the hood + scarf (%d/%d)"
			% [detailed, npcs.size()])
	ctx.check(textured == npcs.size(),
			"cast: every NPC body carries the cloth texture (%d/%d)"
			% [textured, npcs.size()])


func _collect(n: Node, depth: int) -> Array:
	var out: Array = [n]
	if depth > 8:
		return out
	for c in n.get_children():
		out.append_array(_collect(c, depth + 1))
	return out
