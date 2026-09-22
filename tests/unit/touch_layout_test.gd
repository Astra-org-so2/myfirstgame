# Unit: TouchLayout data invariants (Phase 2, ADR-021 layout rules).
# Cross-file references via preload-consts (ADR-022).
extends Node

const _LAYOUT = preload("res://scripts/ui/touch_layout.gd")


func run(ctx: Variant) -> void:
	var layout: _LAYOUT = load("res://data/ui/touch_layout.tres")
	ctx.check(layout != null and layout is _LAYOUT,
			"touch_layout: resource loads")
	if layout == null:
		return
	var problems: Array[String] = layout.validate()
	ctx.check(problems.is_empty(),
			"touch_layout: invariants hold (%s)"
			% ("; ".join(problems) if not problems.is_empty() else "ok"))
	# Camera zone is a sane rect in normalized space.
	ctx.check(layout.camera_zone.size.x > 0.0 and layout.camera_zone.size.y > 0.0,
			"touch_layout: camera zone has positive size")
	ctx.check(layout.joystick_radius > 0.0 and layout.button_radius > 0.0,
			"touch_layout: radii positive")
