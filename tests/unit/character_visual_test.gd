# Unit: Phase 13 batch 2 — the shared character builder (final,
# generative): the cast's looks from the palette, the cloth texture
# when the bank is present, the flat fallback without it.
extends Node

const _CV = preload("res://scripts/world/character_visual.gd")
const _BANK = preload("res://scripts/world/texture_bank.gd")


func run(ctx: Variant) -> void:
	var root: Node3D = Node3D.new()
	add_child(root)
	var palette: Resource = load("res://data/visual/palette.tres")

	# Eli: cloak + scarf + hood + the cold visor.
	var eli: Node3D = _CV.build(root, {
			"cloth": palette.eli_cloak,
			"accent": palette.eli_scarf,
			"hood": true,
			"scarf": true,
			"visor": palette.eli_visor,
		}, null)
	ctx.check(eli.get_node_or_null("Body") != null
			and eli.get_node_or_null("Hood") != null
			and eli.get_node_or_null("Scarf") != null
			and eli.get_node_or_null("Visor") != null,
			"char: Eli has body/hood/scarf/visor")
	var body: MeshInstance3D = eli.get_node("Body")
	var mat: StandardMaterial3D = body.material_override
	ctx.check(mat.albedo_color == palette.eli_cloak,
			"char: the flat cloth is the palette cloak")
	var scarf: MeshInstance3D = eli.get_node("Scarf")
	ctx.check(scarf.material_override.albedo_color == palette.eli_scarf,
			"char: the scarf is the palette accent")
	var visor: MeshInstance3D = eli.get_node("Visor")
	var vmat: StandardMaterial3D = visor.material_override
	ctx.check(vmat.emission_enabled
			and vmat.emission == palette.eli_visor,
			"char: the visor glows the palette cold")

	# THE FIRST: the worn copy (wear desaturates the cloak).
	var boss: Node3D = _CV.build(root, {
			"cloth": palette.first_worn,
			"accent": palette.rust,
			"hood": true,
			"scarf": true,
			"wear": 0.55,
		}, null)
	var bmat: StandardMaterial3D = boss.get_node("Body").material_override
	var g: float = (palette.first_worn.r + palette.first_worn.g
			+ palette.first_worn.b) / 3.0
	var expect: Color = palette.first_worn.lerp(
			Color(g, g, g), 0.55 * 0.65)
	ctx.check(bmat.albedo_color.is_equal_approx(expect),
			"char: the boss wear desaturates toward the palette")

	# A bare look (no hood/scarf/visor) stays minimal.
	var bare: Node3D = _CV.build(root, {"cloth": Color(0.3, 0.3, 0.3)},
			null)
	ctx.check(bare.get_node_or_null("Hood") == null
			and bare.get_node_or_null("Scarf") == null
			and bare.get_node_or_null("Visor") == null,
			"char: the bare look has no details")

	# The textured path: the cloth texture lands on the body and the
	# tint maps to the palette target (TextureBank model).
	var bank: Node = _BANK.new()
	add_child(bank)
	bank.load_all()
	var eli_t: Node3D = _CV.build(root, {
			"cloth": palette.eli_cloak,
			"accent": palette.eli_scarf,
			"hood": true,
			"scarf": true,
		}, bank)
	var tmat: StandardMaterial3D = eli_t.get_node("Body").material_override
	ctx.check(tmat.albedo_texture != null,
			"char: the textured body has the cloth albedo")
	var eff_r: float = tmat.albedo_color.r * 70.0 / 255.0
	ctx.check(absf(eff_r - palette.eli_cloak.r) < 0.02,
			"char: the textured tint lands on the palette cloak")
	var scarf_t: MeshInstance3D = eli_t.get_node("Scarf")
	ctx.check(scarf_t.material_override.albedo_texture != null,
			"char: the textured scarf has the cloth albedo")

	# The rust material (the boss's lantern).
	var rust: StandardMaterial3D = _CV.rust_mat(bank)
	ctx.check(rust.albedo_texture != null,
			"char: rust_mat carries the rust texture")
	var rust_flat: StandardMaterial3D = _CV.rust_mat(null)
	ctx.check(rust_flat.albedo_texture == null,
			"char: rust_mat falls back flat without the bank")

	bank.queue_free()
	root.queue_free()
