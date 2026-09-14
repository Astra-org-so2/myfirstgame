# Unit: CampLayout data invariants (Phase 3, WORLD_BIBLE §4.1).
# Cross-file references via preload-consts (ADR-022).
extends Node

const _LAYOUT = preload("res://scripts/world/camp_layout.gd")


func run(ctx: Variant) -> void:
	# 1. .tres loads, is the right script, passes validate().
	var res: Resource = load("res://data/world/camp_layout.tres")
	ctx.check(res != null and res is _LAYOUT, "camp_layout: .tres loads")
	if res == null:
		return
	var layout: _LAYOUT = res
	var problems: Array[String] = layout.validate()
	ctx.check(problems.is_empty(),
			"camp_layout: .tres passes validate() (%s)"
			% ("; ".join(problems) if not problems.is_empty() else "ok"))

	# 2. Content counts (WORLD_BIBLE §4.1: 8-12 trees, 3 tents, 8 zones).
	ctx.check(layout.tree_slots.size() >= 8 and layout.tree_slots.size() <= 12,
			"camp_layout: 8..12 trees (got %d)" % layout.tree_slots.size())
	ctx.check(layout.tent_slots.size() == 3,
			"camp_layout: exactly 3 tents")
	ctx.check(layout.zone_names.size() == 8,
			"camp_layout: 8 zone gates")

	# 3. Narrative anchors (A2 pillar, Mara by the fire, the kettle beat).
	ctx.check(layout.mara_pos.distance_to(layout.bonfire_pos) < 2.5,
			"camp_layout: Mara stands by the fire")
	ctx.check(layout.kettle_pos.distance_to(layout.bonfire_pos) <= 2.0,
			"camp_layout: kettle at the fire edge (M2.1 beat)")
	var pillar: float = layout.pillar_pos.distance_to(layout.spawn_pos)
	var pillar_camp: float = layout.pillar_pos.distance_to(layout.bonfire_pos)
	ctx.check(pillar < 6.0 and pillar_camp > 4.0,
			"camp_layout: pillar (A2) on the approach, before camp")

	# 4. Negative paths: validate() must reject broken data.
	var empty: _LAYOUT = _LAYOUT.new()
	ctx.check(not empty.validate().is_empty(),
			"camp_layout: empty layout rejected")

	var no_trees: _LAYOUT = _copy(layout)
	no_trees.tree_slots = PackedVector3Array([
		Vector3(5.0, 1.0, 0.0),
		Vector3(-5.0, 1.0, 0.0),
		Vector3(0.0, 1.0, 5.0),
	])
	ctx.check(not no_trees.validate().is_empty(),
			"camp_layout: 3 trees rejected (min 8)")

	var dup_zone: _LAYOUT = _copy(layout)
	var names: PackedStringArray = dup_zone.zone_names
	names.append(&"ruined_village")  # duplicate
	dup_zone.zone_names = names
	ctx.check(not dup_zone.validate().is_empty(),
			"camp_layout: duplicated zone name rejected")

	var close_zones: _LAYOUT = _copy(layout)
	var angles: PackedFloat64Array = close_zones.zone_angles
	angles[1] = angles[0] + 10.0  # 10 deg apart
	close_zones.zone_angles = angles
	ctx.check(not close_zones.validate().is_empty(),
			"camp_layout: zone angles 10 deg apart rejected")

	var out_of_bounds: _LAYOUT = _copy(layout)
	out_of_bounds.spawn_pos = Vector3(20.0, 0.0, 0.0)
	ctx.check(not out_of_bounds.validate().is_empty(),
			"camp_layout: spawn outside the hub rejected")

	var far_kettle: _LAYOUT = _copy(layout)
	far_kettle.kettle_pos = Vector3(4.0, 0.0, 0.0)
	ctx.check(not far_kettle.validate().is_empty(),
			"camp_layout: kettle far from the fire rejected")

	var bad_path: _LAYOUT = _copy(layout)
	bad_path.path_waypoints = PackedVector3Array([Vector3(1.0, 0.0, 5.0)])
	ctx.check(not bad_path.validate().is_empty(),
			"camp_layout: single-waypoint path rejected")


func _copy(src: _LAYOUT) -> _LAYOUT:
	var d: _LAYOUT = _LAYOUT.new()
	d.tree_slots = src.tree_slots
	d.tent_slots = src.tent_slots
	d.bonfire_pos = src.bonfire_pos
	d.mara_pos = src.mara_pos
	d.kettle_pos = src.kettle_pos
	d.note_stand_pos = src.note_stand_pos
	d.table_pos = src.table_pos
	d.pillar_pos = src.pillar_pos
	d.path_waypoints = src.path_waypoints
	d.spawn_pos = src.spawn_pos
	d.zone_names = src.zone_names
	d.zone_angles = src.zone_angles
	d.watchtower_pos = src.watchtower_pos
	d.gate_pos = src.gate_pos
	return d
