# Unit: Phase 13 visual foundation — the palette (WORLD_BIBLE §1),
# the quality presets (TECH_DESIGN §12), the QualityManager apply,
# and the TextureBank (ASSET_GUIDE §7: generated, deterministic set).
extends Node

const _PRESET = preload("res://scripts/world/quality_preset.gd")
const _MANAGER = preload("res://scripts/world/quality_manager.gd")
const _BANK = preload("res://scripts/world/texture_bank.gd")


func run(ctx: Variant) -> void:
	_test_palette(ctx)
	_test_presets(ctx)
	_test_manager(ctx)
	_test_bank(ctx)


func _test_palette(ctx: Variant) -> void:
	var res: Resource = load("res://data/visual/palette.tres")
	ctx.check(res != null, "palette: data/visual/palette.tres loads")
	if res == null:
		return
	var problems: Array = res.validate()
	ctx.check(problems.is_empty(),
			"palette: validate() clean (%s)" % str(problems))
	# The warm/cold rule (WORLD_BIBLE §1): the ember is the only warm
	# source before the boss, the fog is cold.
	var ember: Color = res.ember_amber
	var fog: Color = res.fog_blue
	ctx.check(ember.r > ember.b + 0.2, "palette: the ember is warm")
	ctx.check(fog.b > fog.r, "palette: the fog is cold")
	# The cold-white of the Archivist must be near-neutral and bright.
	var cw: Color = res.cold_white
	ctx.check(cw.r > 0.7 and cw.b > 0.7 and absf(cw.r - cw.b) < 0.15,
			"palette: the cold white is near-neutral")


func _test_presets(ctx: Variant) -> void:
	var low: Resource = load("res://data/quality/low.tres")
	var med: Resource = load("res://data/quality/medium.tres")
	var high: Resource = load("res://data/quality/high.tres")
	ctx.check(low != null and med != null and high != null,
			"presets: all three tiers load")
	if low == null or med == null or high == null:
		return
	var ok: bool = true
	for p in [low, med, high]:
		var probs: Array = p.validate()
		if not probs.is_empty():
			ok = false
	ctx.check(ok, "presets: validate() clean on all tiers")
	# The tiers order (TECH_DESIGN §12: 3 / 4 / 6 local lights).
	ctx.check(low.local_light_budget == 3 and med.local_light_budget == 4
			and high.local_light_budget == 6,
			"presets: the §12 light budgets 3/4/6")
	ctx.check(not low.shadows_enabled and med.shadows_enabled
			and high.shadows_enabled,
			"presets: shadows off on low, on on medium/high")
	ctx.check(low.render_scale < med.render_scale,
			"presets: low renders below medium scale")
	ctx.check(low.particle_scale <= med.particle_scale
			and med.particle_scale <= high.particle_scale,
			"presets: particle scale monotone up the tiers")
	# No heavy post on any tier (TECH_DESIGN §12).
	ctx.check(low.msaa <= 2 and med.msaa <= 2 and high.msaa <= 4,
			"presets: no post beyond MSAA 4x")


func _test_manager(ctx: Variant) -> void:
	var low: Resource = load("res://data/quality/low.tres")
	var high: Resource = load("res://data/quality/high.tres")
	var env: Environment = Environment.new()
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow = true
	var mgr: Node = _MANAGER.new()
	mgr.setup(low, env, sun, null)
	# The sun shadow is rig-observable (set_shadow/has_shadow). The
	# atlas/MSAA/render_scale setters are not registered in the
	# headless wasm bridge — those are production-only controls,
	# verified on device (P16 checklist, qa_phase13_visual.md).
	ctx.check(sun.has_shadow() == false,
			"manager: low turns the sun shadows off")
	ctx.check(mgr.light_budget() == 3, "manager: low budget = 3")
	mgr.set_preset(high)
	ctx.check(sun.has_shadow() == true, "manager: high turns the shadows on")
	ctx.check(mgr.light_budget() == 6, "manager: high budget = 6")
	ctx.check(mgr.shadows_enabled(),
			"manager: the preset state reads back")
	mgr.free()


func _test_bank(ctx: Variant) -> void:
	var bank: Node = _BANK.new()
	var n: int = bank.load_all()
	ctx.check(n == 7, "bank: all 7 material textures load (got %d)" % n)
	if n < 7:
		bank.free()
		return
	var all: bool = true
	for id in ["stone", "stone_dark", "ground", "wood", "wood_dark",
			"cloth", "rust"]:
		if not bank.has(id) or bank.texture(id) == null:
			all = false
	ctx.check(all, "bank: every id resolves to a texture")
	ctx.check(not bank.has("fog_soft"),
			"bank: fog_soft is reserved for the P14 particles")
	var palette: Resource = load("res://data/visual/palette.tres")
	var m: StandardMaterial3D = bank.material("stone", palette.stone)
	ctx.check(m != null, "bank: material() builds")
	if m != null:
		ctx.check(m.albedo_texture != null, "bank: material has the albedo")
		# The tint maps the texture base to the palette target: the
		# base stone (0.38 luminance) tinted by ~0.69 lands on the
		# palette stone — check the effective albedo per channel.
		var eff_r: float = m.albedo_color.r * 96.0 / 255.0
		ctx.check(absf(eff_r - palette.stone.r) < 0.02,
				"bank: the tint lands on the palette target")
		ctx.check(m.roughness > 0.5, "bank: the world is matte")
	ctx.check(bank.material("nope", Color.WHITE) == null,
			"bank: unknown id -> null (flat fallback)")
	bank.free()
