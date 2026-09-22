# CharacterVisual — the shared code-built character (ADR-005):
# capsule body + optional hood + scarf/collar accent + optional
# emissive visor. One builder for Eli, the NPCs, the Child, the
# enemies and THE FIRST, so the cast keeps one visual language.
#
# Materials come from the TextureBank (the cloth texture, tinted to
# the character's palette color) when the bank is available; a null
# bank means flat colors (the headless tests run without assets).
class_name CharacterVisual
extends RefCounted

const _PALETTE = preload("res://data/visual/palette.tres")

# look = Dictionary:
#   height: float (1.7)        — the capsule height
#   radius: float (0.35)       — the capsule radius
#   cloth: Color               — the body color (palette)
#   accent: Color              — the scarf/collar color (palette)
#   hood: bool                 — the squashed-sphere hood
#   scarf: bool                — the collar ring
#   visor: Color (alpha 0)     — the emissive visor (alpha 0 = none)
#   wear: float (0..1)         — desaturates the cloth ("worn")
#   emissive_accent: bool      — the accent glows (memory layers,
#                                WORLD_BIBLE §1.1)
static func build(root: Node3D, look: Dictionary, bank: Variant) -> Node3D:
	var v: Node3D = Node3D.new()
	v.name = "CharVisual"
	var h: float = look.get("height", 1.7)
	var r: float = look.get("radius", 0.35)
	var cloth: Color = look.get("cloth", Color(0.4, 0.4, 0.38))
	var accent: Color = look.get("accent", Color(0.4, 0.35, 0.3))
	# Wear: the cloth fades toward its own luminance (the boss is
	# "the tired you" — CHARACTER_BIBLE §8).
	var wear: float = clampf(look.get("wear", 0.0), 0.0, 1.0)
	if wear > 0.0:
		var g: float = (cloth.r + cloth.g + cloth.b) / 3.0
		cloth = cloth.lerp(Color(g, g, g), wear * 0.65)

	var body_mat: StandardMaterial3D = _cloth(cloth, bank)
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = "Body"
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	mi.mesh = cm
	mi.position = Vector3(0.0, h * 0.5, 0.0)
	mi.material_override = body_mat
	v.add_child(mi)

	if look.get("hood", false):
		var hood: MeshInstance3D = MeshInstance3D.new()
		hood.name = "Hood"
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = r * 0.92
		sm.height = r * 1.7
		hood.mesh = sm
		hood.position = Vector3(0.0, h + r * 0.28, 0.0)
		hood.scale = Vector3(1.0, 0.82, 1.06)
		hood.material_override = body_mat
		v.add_child(hood)

	if look.get("scarf", false):
		var scarf: MeshInstance3D = MeshInstance3D.new()
		scarf.name = "Scarf"
		var cym: CylinderMesh = CylinderMesh.new()
		cym.top_radius = r * 1.18
		cym.bottom_radius = r * 1.26
		cym.height = 0.14
		scarf.mesh = cym
		scarf.position = Vector3(0.0, h - 0.18, 0.0)
		var amat: StandardMaterial3D = accent_mat(accent,
				bool(look.get("emissive_accent", false)), bank)
		scarf.material_override = amat
		v.add_child(scarf)

	var visor: Color = look.get("visor", Color(0.0, 0.0, 0.0, 0.0))
	if visor.a > 0.0:
		var vis: MeshInstance3D = MeshInstance3D.new()
		vis.name = "Visor"
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(r * 0.9, 0.07, 0.09)
		vis.mesh = bm
		vis.position = Vector3(0.0, h + r * 0.3, r * 0.72)
		var vmat: StandardMaterial3D = StandardMaterial3D.new()
		vmat.albedo_color = visor
		vmat.emission_enabled = true
		vmat.emission = visor
		vmat.emission_energy_multiplier = 1.5
		vis.material_override = vmat
		v.add_child(vis)
	return v


# The cloth material: the generated cloth texture tinted to the
# character's color, or a flat matte material (no bank).
static func _cloth(color: Color, bank: Variant) -> StandardMaterial3D:
	if bank != null and bank.has("cloth"):
		var m: StandardMaterial3D = bank.material("cloth", color, 0.8)
		if m != null:
			return m
	var f: StandardMaterial3D = StandardMaterial3D.new()
	f.albedo_color = color
	f.roughness = 0.8
	return f


# The rust material (pain-memory stains — THE FIRST's lantern):
# the generated rust texture, or the palette rust when flat.
static func rust_mat(bank: Variant) -> StandardMaterial3D:
	if bank != null and bank.has("rust"):
		var m: StandardMaterial3D = bank.material("rust", _PALETTE.rust, 0.9)
		if m != null:
			return m
	var f: StandardMaterial3D = StandardMaterial3D.new()
	f.albedo_color = _PALETTE.rust.lerp(Color(0.3, 0.26, 0.2), 0.5)
	f.roughness = 0.9
	return f


# The accent material (public for the Eli details): cloth texture
# tinted to the accent; the emissive flag is the memory-layer look
# (WORLD_BIBLE §1.1).
static func accent_mat(color: Color, emissive: bool, bank: Variant) \
		-> StandardMaterial3D:
	var m: StandardMaterial3D = null
	if bank != null and bank.has("cloth"):
		m = bank.material("cloth", color, 0.7)
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.7
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.8
	return m
