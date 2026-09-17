# RoomData — one modular room (GDD §11, ENV_STORYTELLING §3,
# TECHNICAL_DESIGN §1).
#
# A room = floor + walls + doorways (anchors IDENTICAL across its
# variants, ADR-003) + interior (obstacles, spawn/loot/event spots)
# + ambience (fog/light) + the NO-FILLER record: at least ONE of
# the five fields (gameplay/visual/narrative/discovery/interaction)
# is non-null — «нет → комната не создаётся» (GDD §9). The five
# fields are one-liners in the data (the beat), not code: the scene
# renders the interior from the geometry and the role, the line is
# the design record the no-filler checklist checks.
#
# `variant` is the variant index of THIS room (all variants share
# id/area/doorways; the generator picks one per layout).
class_name RoomData
extends Resource

enum Role {
	CORRIDOR,   # a passage between spaces
	JUNCTION,   # a meeting point (2+ exits)
	COMBAT,     # a fight happens here
	LOOT,       # a find happens here
	MYSTERY,    # a mystery beat happens here
	SHELTER,    # a rest/quiet room
}

const _DW = preload("res://scripts/gameplay/rooms/doorway_def.gd")
const _OB = preload("res://scripts/gameplay/rooms/obstacle_box.gd")

@export var id: StringName = &""
# The areas this room can appear in (a modular room lists its
# suitable areas; a handcrafted one lists its own).
@export var areas: PackedStringArray = PackedStringArray()
@export var variant: int = 0
# Handcrafted rooms (camp hub, zone entries, boss arena) keep their
# own geometry: the doorway border check is skipped for them (the
# camp's gates sit on a circle, the handcrafted set, ADR-003).
@export var handcrafted: bool = false
@export var role: int = Role.CORRIDOR
# Logical size (m), the floor footprint.
@export var size: Vector2 = Vector2(8.0, 8.0)
@export var doorways: Array = []  # Array[DoorwayDef]
# Enemy spawn points (room-local; the encounter table fills them).
@export var enemy_spots: PackedVector3Array = PackedVector3Array()
# The find spots (weapon/loot — room-local).
@export var loot_spots: PackedVector3Array = PackedVector3Array()
# The scripted/mystery object spots (room-local).
@export var event_spots: PackedVector3Array = PackedVector3Array()
# Interior obstacles (room-local AABBs, center+size). The headless
# rig has no physics server (ADR-002), so the spawn probe is
# GEOMETRIC against these boxes (TECHNICAL_DESIGN §6 item 2); the
# scene builds the same boxes as the room's collision/volume mesh.
@export var obstacles: Array = []  # Array[ObstacleBox]
@export var ambient_fog: float = 0.0  # 0..1 (the zone's fog density)
@export var light_color: Color = Color(0.55, 0.6, 0.55)
@export var light_energy: float = 0.6
# Fixed find ("" = none; otherwise a weapon id — the production
# weapon placement, WEAPON_DESIGN §5).
@export var fixed_loot: StringName = &""

# --- NO-FILLER record (ENV_STORYTELLING §3): >= 1 non-null ---
@export var gameplay: String = ""
@export var visual: String = ""
@export var narrative: String = ""
@export var discovery: String = ""
@export var interaction: String = ""


func no_filler_count() -> int:
	var n: int = 0
	if gameplay != "":
		n += 1
	if visual != "":
		n += 1
	if narrative != "":
		n += 1
	if discovery != "":
		n += 1
	if interaction != "":
		n += 1
	return n


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("room id must be set")
	if areas.size() < 1:
		problems.append("room must list >= 1 area")
	if size.x <= 1.0 or size.y <= 1.0:
		problems.append("room size must be > 1 m per side")
	if no_filler_count() < 1:
		problems.append("no-filler: at least one of gameplay/visual/"
				+ "narrative/discovery/interaction must be set (GDD §9)")
	if doorways.size() < 1:
		problems.append("a room needs >= 1 doorway")
	var anchors: Array = []
	for d in doorways:
		var dd: _DW = d
		problems.append_array(dd.validate())
		if anchors.has(dd.anchor):
			problems.append("duplicate doorway anchor: %s" % dd.anchor)
		anchors.append(dd.anchor)
		if handcrafted:
			continue
		# A doorway sits ON a wall edge (on the footprint border).
		var p: Vector3 = dd.local_pos
		var on_border: bool = absf(p.x) > size.x * 0.5 - 0.55 \
				or absf(p.z) > size.y * 0.5 - 0.55
		if not on_border:
			problems.append("doorway %s is not on a wall" % dd.anchor)
	for s in enemy_spots:
		problems.append_array(_probe_point(s, "enemy spot"))
	for s in loot_spots:
		problems.append_array(_probe_point(s, "loot spot"))
	for s in event_spots:
		problems.append_array(_probe_point(s, "event spot"))
	return problems


# A spawn/find point: inside the footprint, not in an obstacle, not
# inside a doorway mouth (the headless geometry probe; see class doc).
func _probe_point(p: Vector3, what: String) -> Array[String]:
	var problems: Array[String] = []
	if p.x < -size.x * 0.5 + 0.3 or p.x > size.x * 0.5 - 0.3 \
			or p.z < -size.y * 0.5 + 0.3 or p.z > size.y * 0.5 - 0.3:
		problems.append("%s is outside the room" % what)
		return problems
	for o in obstacles:
		var box: _OB = o
		if box.contains_point(p):
			problems.append("%s is inside an obstacle" % what)
			return problems
	for d in doorways:
		var dd: _DW = d
		if p.distance_to(dd.local_pos) < 0.9:
			problems.append("%s blocks a doorway" % what)
	return problems
