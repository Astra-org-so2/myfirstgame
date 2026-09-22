# Unit: the quality presets against the §12 table (Phase 16).
extends Node

const _P = preload("res://scripts/world/quality_preset.gd")


func run(ctx: Variant) -> void:
	var low: _P = load("res://data/quality/low.tres")
	var med: _P = load("res://data/quality/medium.tres")
	var high: _P = load("res://data/quality/high.tres")
	var ultra: _P = load("res://data/quality/ultra.tres")
	ctx.check(low != null and med != null and high != null \
			and ultra != null, "preset: all four tiers load")

	# validate() is clean for every tier.
	for p in [low, med, high, ultra]:
		var probs: PackedStringArray = p.validate()
		ctx.check(probs.size() == 0,
				"preset %s: validate clean (%s)"
				% [p.id, str(probs)])

	# The §12 table, pinned (a drift here is a budget change).
	ctx.check(low.id == &"low" and not low.shadows_enabled \
			and low.local_light_budget == 3 and low.particle_scale == 0.5
			and low.msaa == 1 and low.texture_max_size == 512 \
			and low.render_scale == 0.75,
			"preset low: the §12 values")
	ctx.check(med.id == &"medium" and med.shadows_enabled \
			and not med.shadow_atlas_4x4 and not med.soft_shadows
			and med.local_light_budget == 4 and med.particle_scale == 0.75
			and med.msaa == 1 and med.texture_max_size == 1024 \
			and med.render_scale == 1.0,
			"preset medium: the §12 values")
	ctx.check(high.id == &"high" and high.shadows_enabled \
			and high.shadow_atlas_4x4 and not high.soft_shadows
			and high.local_light_budget == 6 and high.particle_scale == 1.0
			and high.msaa == 2 and high.texture_max_size == 2048 \
			and high.render_scale == 1.0,
			"preset high: the §12 values")
	# Ultra = High + soft shadows + VFX 125% (§12).
	ctx.check(ultra.id == &"ultra" and ultra.soft_shadows \
			and ultra.shadow_atlas_4x4 and ultra.local_light_budget == 6
			and ultra.particle_scale == 1.25 and ultra.msaa == 2
			and ultra.texture_max_size == 2048,
			"preset ultra: the §12 values")

	# The tier ordering (a higher tier never spends less on lights).
	ctx.check(low.local_light_budget <= med.local_light_budget
			and med.local_light_budget <= high.local_light_budget
			and high.local_light_budget <= ultra.local_light_budget,
			"preset: the light budgets are ordered")
