# TextureBank — loads the generated texture set (tools/utils/
# gen_textures.py, ASSET_GUIDE §7) and builds tinted materials from
# it. Scene-composed (ADR-009): the main scene owns the bank and
# hands it to the world builders; a null bank means the flat-color
# fallback (the tests run without assets).
#
# Tint model: the PNGs are neutral (base luminance = the generator's
# "base" value); the material's albedo_color scales that base to the
# palette target, so the texture's variation survives the tint.
class_name TextureBank
extends Node

# base luminance of each generated texture (the generator's base
# value / 255) — the tint is normalized against it.
const _BASE: Dictionary = {
	"stone": 96.0 / 255.0,
	"stone_dark": 58.0 / 255.0,
	"ground": 46.0 / 255.0,
	"wood": 122.0 / 255.0,
	"wood_dark": 78.0 / 255.0,
	"cloth": 70.0 / 255.0,
	"rust": 120.0 / 255.0,
}
const _PATH = "res://assets/textures/%s.png"
const _IDS: Array = [
	"stone", "stone_dark", "ground", "wood", "wood_dark",
	"cloth", "rust",
]

var _tex: Dictionary = {}


# Loads the set; returns how many textures are ready (test hook).
func load_all() -> int:
	for id in _IDS:
		# load_from_file dispatches to the PNG loader (the headless
		# wasm rig registers it under this name, not load_png).
		var img: Image = Image.load_from_file(_PATH % id)
		if img == null:
			push_error("TextureBank: cannot load %s" % (_PATH % id))
			continue
		_tex[id] = ImageTexture.create_from_image(img)
	return _tex.size()


func has(id: String) -> bool:
	return _tex.has(id)


func texture(id: String) -> ImageTexture:
	return _tex.get(id, null)


# A material for `id`: albedo = the texture, albedo_color = the tint
# that maps the texture's base luminance to `target` (the palette
# color), plus the roughness (the world is matte — WORLD_BIBLE §1).
func material(id: String, target: Color, roughness: float = 0.85) \
		-> StandardMaterial3D:
	var t: ImageTexture = texture(id)
	if t == null:
		return null
	var base: float = _BASE[id]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = t
	var tint: Color = Color(target.r / base, target.g / base,
			target.b / base)
	m.albedo_color = Color(minf(tint.r, 4.0), minf(tint.g, 4.0),
			minf(tint.b, 4.0))
	m.roughness = roughness
	m.metallic = 0.0
	return m
