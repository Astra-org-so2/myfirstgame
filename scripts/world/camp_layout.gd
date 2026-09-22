# CampLayout — data for the camp hub (Phase 3, WORLD_BIBLE §4.1).
#
# The camp is handcrafted (ADR: 9 handcrafted zones, not procedural);
# this resource is its single source of truth for PLACEMENT: CampWorld
# builds the scene from these values, so moving an object = editing one
# .tres (no scene surgery). Visual style (meshes/materials) lives in the
# template scenes under scenes/world/.
#
# Units: meters. Y = up; ground at y=0. Hub is a square, walls at ±12.
class_name CampLayout
extends Resource

const MIN_TREES: int = 8
const MAX_TREES: int = 12
const HUB_RADIUS: float = 11.5  # keep data inside the walls (±12)
const CAMP_RADIUS: float = 6.0  # camp core (fire/tents/props) area
const ZONE_COUNT: int = 8  # non-camp zones (WORLD_BIBLE §2)

# Trees: PackedVector3Array of (x, scale, z); scale in 0.6..1.6.
@export var tree_slots: PackedVector3Array = PackedVector3Array()
# Three tents, in order: [mara, empty, "not human"] (WORLD_BIBLE §4.1).
@export var tent_slots: PackedVector3Array = PackedVector3Array()
# Camp core props (Vector3 positions, y ignored on placement).
@export var bonfire_pos: Vector3 = Vector3.ZERO
@export var mara_pos: Vector3 = Vector3(1.6, 0.0, 0.9)
@export var kettle_pos: Vector3 = Vector3(0.9, 0.0, -1.1)
@export var note_stand_pos: Vector3 = Vector3(3.2, 0.0, 2.4)
@export var table_pos: Vector3 = Vector3(-2.4, 0.0, 2.8)
@export var pillar_pos: Vector3 = Vector3(1.2, 0.0, 5.5)  # A2 (K3)
# Path waypoints (spawn -> camp), y ignored.
@export var path_waypoints: PackedVector3Array = PackedVector3Array()
@export var spawn_pos: Vector3 = Vector3(0.0, 0.0, 9.5)
# Zone gate silhouettes: names (stable ids) + outward angle in degrees
# (0 = +Z / spawn side, 90 = +X). Paired by index; validated.
@export var zone_names: PackedStringArray = PackedStringArray()
@export var zone_angles: PackedFloat64Array = PackedFloat64Array()
# Distant landmarks (landmark-rule, WORLD_BIBLE §3.2): silhouettes seen
# through the fog from the camp.
@export var watchtower_pos: Vector3 = Vector3(0.0, 0.0, -40.0)
@export var gate_pos: Vector3 = Vector3(38.0, 0.0, 20.0)


func validate() -> Array[String]:
	var problems: Array[String] = []

	# --- Trees: count, bounds, scale, spacing, camp clearing ---
	if tree_slots.size() < MIN_TREES or tree_slots.size() > MAX_TREES:
		problems.append(
			"trees: expected %d..%d, got %d"
			% [MIN_TREES, MAX_TREES, tree_slots.size()])
	for slot in tree_slots:
		if not _in_hub(Vector3(slot.x, 0.0, slot.z)):
			problems.append("tree out of hub bounds: %s" % slot)
		if slot.y < 0.6 or slot.y > 1.6:
			problems.append("tree scale out of 0.6..1.6: %s" % slot)
	for i in tree_slots.size():
		for j in range(i + 1, tree_slots.size()):
			var a: Vector3 = Vector3(tree_slots[i].x, 0.0, tree_slots[i].z)
			var b: Vector3 = Vector3(tree_slots[j].x, 0.0, tree_slots[j].z)
			if a.distance_to(b) < 2.5:
				problems.append("trees too close: %s / %s" % [a, b])
		var tpos: Vector3 = Vector3(
				tree_slots[i].x, 0.0, tree_slots[i].z)
		if tpos.distance_to(_xz(bonfire_pos)) < 4.0:
			problems.append("tree blocks the camp clearing: %s" % tpos)

	# --- Tents: exactly 3, near the fire, spaced ---
	if tent_slots.size() != 3:
		problems.append("tents: expected 3, got %d" % tent_slots.size())
	for slot in tent_slots:
		var p: Vector3 = Vector3(slot.x, 0.0, slot.z)
		if p.distance_to(_xz(bonfire_pos)) > 8.0:
			problems.append("tent far from the bonfire: %s" % p)
	for i in tent_slots.size():
		for j in range(i + 1, tent_slots.size()):
			var a: Vector3 = Vector3(tent_slots[i].x, 0.0, tent_slots[i].z)
			var b: Vector3 = Vector3(tent_slots[j].x, 0.0, tent_slots[j].z)
			if a.distance_to(b) < 3.0:
				problems.append("tents overlap: %s / %s" % [a, b])

	# --- Camp props: near the fire, not overlapping each other ---
	var props: Array[Vector3] = [
			mara_pos, note_stand_pos, table_pos,
	]
	for p in props:
		if p.distance_to(_xz(bonfire_pos)) > 8.0:
			problems.append("camp prop far from the bonfire: %s" % p)
		if not _in_hub(p):
			problems.append("camp prop out of hub bounds: %s" % p)
		for q in props:
			if q != p and p.distance_to(q) < 1.5:
				problems.append("camp props overlap: %s / %s" % [p, q])
	# Kettle: at the fire edge (the M2.1 beat), but not inside the fire.
	var kettle: Vector3 = _xz(kettle_pos)
	var fire: Vector3 = _xz(bonfire_pos)
	if kettle.distance_to(fire) < 0.8 or kettle.distance_to(fire) > 2.0:
		problems.append("kettle: expected 0.8..2.0 m from the bonfire")
	# Pillar (A2): on the approach path, before the camp.
	if not _in_hub(_xz(pillar_pos)):
		problems.append("pillar out of hub bounds")
	if _xz(pillar_pos).distance_to(fire) < 4.0:
		problems.append("pillar should sit on the approach, not in camp")

	# --- Spawn: inside the hub, outside the camp core ---
	if not _in_hub(_xz(spawn_pos)):
		problems.append("spawn out of hub bounds")
	if _xz(spawn_pos).distance_to(_xz(bonfire_pos)) < 5.0:
		problems.append("spawn too close to the camp core")

	# --- Path: spawn -> camp, inside the hub ---
	if path_waypoints.size() < 2:
		problems.append("path: expected >= 2 waypoints")
	elif path_waypoints[0].x != spawn_pos.x \
			or path_waypoints[0].z != spawn_pos.z:
		problems.append("path: first waypoint must be the spawn point")
	for wpt in path_waypoints:
		if wpt.y != 0.0:
			problems.append("path: waypoints must have y = 0")
		if not _in_hub(Vector3(wpt.x, 0.0, wpt.z)):
			problems.append("path waypoint out of hub bounds: %s" % wpt)

	# --- Zone gates: 8 unique names, paired angles, spread ---
	if zone_names.size() != ZONE_COUNT:
		problems.append("zones: expected %d, got %d" % [ZONE_COUNT, zone_names.size()])
	if zone_angles.size() != zone_names.size():
		problems.append("zones: %d names vs %d angles"
				% [zone_names.size(), zone_angles.size()])
	var seen: Array[StringName] = []
	for i in zone_names.size():
		var n: StringName = zone_names[i]
		if seen.has(n):
			problems.append("zone name duplicated: " + String(n))
		seen.append(n)
		if i < zone_angles.size():
			var a: float = zone_angles[i]
			if a < 0.0 or a >= 360.0:
				problems.append("zone angle out of 0..360: %s" % n)
	for i in zone_angles.size():
		for j in range(i + 1, zone_angles.size()):
			var d: float = absf(zone_angles[i] - zone_angles[j])
			d = minf(d, 360.0 - d)
			if d < 20.0:
				problems.append("zones too close: %s / %s (%.0f deg)"
						% [zone_names[i], zone_names[j], d])

	return problems


func _xz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _in_hub(p: Vector3) -> bool:
	return p.x >= -HUB_RADIUS and p.x <= HUB_RADIUS \
			and p.z >= -HUB_RADIUS and p.z <= HUB_RADIUS
