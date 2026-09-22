#!/usr/bin/env python3
"""Phase 7 data generator (one-shot, re-runnable).

Writes:
  data/rooms/*.tres   9 handcrafted (hub, 8 zone entries, boss arena)
                      + 13 modular rooms x 2 variants = 35 RoomData
  data/areas/*.tres   9 AreaData (the DAG pool)
  data/enemies/zone_spawn_table_*.tres  7 spawn tables

The doorway anchors are IDENTICAL across variants (ADR-003);
variants differ in obstacles/ambient/interior only.
"""
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROOMS = os.path.join(ROOT, "data", "rooms")
AREAS = os.path.join(ROOT, "data", "areas")
ENEMIES = os.path.join(ROOT, "data", "enemies")
os.makedirs(ROOMS, exist_ok=True)
os.makedirs(AREAS, exist_ok=True)

ROOM_GD = "res://scripts/gameplay/rooms/room_data.gd"
DW_GD = "res://scripts/gameplay/rooms/doorway_def.gd"
OB_GD = "res://scripts/gameplay/rooms/obstacle_box.gd"
AREA_GD = "res://scripts/gameplay/areas/area_data.gd"
CONN_GD = "res://scripts/gameplay/areas/area_connection.gd"
TBL_GD = "res://scripts/gameplay/enemies/spawn_table.gd"
ENT_GD = "res://scripts/gameplay/enemies/spawn_entry.gd"

ROLE = {"CORRIDOR": 0, "JUNCTION": 1, "COMBAT": 2, "LOOT": 3,
        "MYSTERY": 4, "SHELTER": 5}


def fnum(x):
    """A .tres float literal must keep its decimal point."""
    t = "%g" % x
    if "." not in t and "e" not in t.lower() and "inf" not in t.lower() \
            and "nan" not in t.lower():
        t += ".0"
    return t


def v3(x, y, z):
    return "Vector3(%s, %s, %s)" % (fnum(x), fnum(y), fnum(z))


def flat3(sps):
    """PackedVector3Array .tres form: flat floats (3 per point)."""
    vals = []
    for sp in sps:
        vals += [fnum(c) for c in sp]
    return ", ".join(vals)


def doorway(anchor, x, y, z, fx, fy, fz):
    return (
        '[sub_resource type="Resource" id="%s"]\n'
        'script = ExtResource("2_dw")\n'
        "anchor = &\"%s\"\n"
        "local_pos = %s\n"
        "facing = %s\n" % (anchor, anchor, v3(x, y, z), v3(fx, fy, fz))
    )


def obstacle(ix, pos, size):
    return (
        '[sub_resource type="Resource" id="ob_%d"]\n'
        'script = ExtResource("3_ob")\n'
        "position = %s\n"
        "size = %s\n" % (ix, v3(*pos), v3(*size))
    )


def room_tres(name, rid, areas, variant, role, size, doors,
              obstacles, enemy_spots, loot_spots, event_spots,
              fog, light_color, light_energy, handcrafted,
              nofiller, fixed_loot=""):
    """One RoomData .tres.

    doors: list of (anchor_id, x, y, z, fx, fy, fz)
    obstacles: list of ((ix, pos_tuple), size_tuple)
    spots: list of Vector3 tuples
    nofiller: dict role_field -> line
    """
    exts = []
    exts.append('[ext_resource type="Script" path="%s" id="1_rd"]' % ROOM_GD)
    exts.append('[ext_resource type="Script" path="%s" id="2_dw"]' % DW_GD)
    exts.append('[ext_resource type="Script" path="%s" id="3_ob"]' % OB_GD)

    subs = []
    dw_refs = []
    for (aid, x, y, z, fx, fy, fz) in doors:
        subs.append(doorway(aid, x, y, z, fx, fy, fz))
        dw_refs.append('SubResource("%s")' % aid)
    ob_refs = []
    for (ix, pos), ob_size in obstacles:
        subs.append(obstacle(ix, pos, ob_size))
        ob_refs.append('SubResource("ob_%d")' % ix)

    body = [
        "id = &\"%s\"" % rid,
        # PackedStringArray in .tres text takes plain strings (the
        # StringName literal &"..." is not a valid .tres token).
        'areas = PackedStringArray(%s)'
        % ", ".join("\"%s\"" % a for a in areas),
        "variant = %d" % variant,
        "handcrafted = %s" % ("true" if handcrafted else "false"),
        "role = %d" % ROLE[role],
        "size = Vector2(%s, %s)" % (fnum(size[0]), fnum(size[1])),
        "doorways = Array[DoorwayDef](%s)" % ("[%s]" % ", ".join(dw_refs)) if dw_refs else "doorways = Array[DoorwayDef]([])",
        "enemy_spots = PackedVector3Array(%s)" % flat3(enemy_spots),
        "loot_spots = PackedVector3Array(%s)" % flat3(loot_spots),
        "event_spots = PackedVector3Array(%s)" % flat3(event_spots),
        "obstacles = Array[ObstacleBox](%s)"
        % ("[%s]" % ", ".join(ob_refs)) if ob_refs else "obstacles = Array[ObstacleBox]([])",
        "ambient_fog = %s" % fnum(fog),
        "light_color = Color(%s, %s, %s, %s)" % (fnum(light_color[0]), fnum(light_color[1]), fnum(light_color[2]), fnum(1.0)),
        "light_energy = %s" % fnum(light_energy),
        "fixed_loot = &\"%s\"" % fixed_loot,
        "gameplay = \"%s\"" % nofiller.get("gameplay", ""),
        "visual = \"%s\"" % nofiller.get("visual", ""),
        "narrative = \"%s\"" % nofiller.get("narrative", ""),
        "discovery = \"%s\"" % nofiller.get("discovery", ""),
        "interaction = \"%s\"" % nofiller.get("interaction", ""),
    ]
    header = '[gd_resource type="Resource" script_class="RoomData" ' \
        'load_steps=%d format=3]' % (len(exts) + len(subs) + 1)
    parts = [header, ""]
    parts += exts
    if subs:
        parts += [""] + subs
    parts += ["", "[resource]", "script = ExtResource(\"1_rd\")", ""]
    parts += body
    path = os.path.join(ROOMS, name + ".tres")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(parts) + "\n")
    return name


def modular(rid, areas, w, d, role, doors_extra=(),
            obstacles_a=(), obstacles_b=(), enemy_spots=(),
            loot_spots=(), event_spots=(),
            fog_a=0.8, fog_b=0.9, light_a=(0.55, 0.6, 0.55),
            light_b=(0.5, 0.55, 0.55), energy_a=0.6, energy_b=0.45,
            nf_a=None, nf_b=None, x_off_a=0.0, x_off_b=0.0):
    """Two variants of one modular room (identical doorways)."""
    doors = [
        ("door_a", x_off_a, 0.0, d / 2.0, 0.0, 0.0, -1.0),
        ("door_b", x_off_a, 0.0, -d / 2.0, 0.0, 0.0, 1.0),
    ]
    doors_b = [
        ("door_a", x_off_b, 0.0, d / 2.0, 0.0, 0.0, -1.0),
        ("door_b", x_off_b, 0.0, -d / 2.0, 0.0, 0.0, 1.0),
    ]
    doors += list(doors_extra)
    doors_b += [(a, x, y, z, fx, fy, fz) for (a, x, y, z, fx, fy, fz) in doors_extra]
    room_tres("%s_v0" % rid, rid, areas, 0, role, (w, d), doors,
              obstacles_a, enemy_spots, loot_spots, event_spots,
              fog_a, light_a, energy_a, False, nf_a or {})
    room_tres("%s_v1" % rid, rid, areas, 1, role, (w, d), doors_b,
              obstacles_b, enemy_spots, loot_spots, event_spots,
              fog_b, light_b, energy_b, False, nf_b or {})


# ------------------------------------------------------------------
# The 13 MODULAR rooms (GDD §11) — corridors/rooms/junctions
# between the zones. Each: 2 variants, identical doorway anchors.
# ------------------------------------------------------------------

# 1. corridor_forest — a passage between the trunks (forest zones)
modular(
    "corridor_forest",
    ["watchtower", "mysterious_lake"],
    4.0, 10.0, "CORRIDOR",
    obstacles_a=[((0, (-1.2, 0.4, 1.5)), (1.4, 0.8, 2.4))],
    obstacles_b=[((0, (1.0, 0.5, -2.0)), (1.6, 1.0, 3.0))],
    fog_a=0.85, fog_b=0.95,
    nf_a={"gameplay": "Narrow: one ambush at a time, no flank.",
          "visual": "Old trunks lean in; the light thins along the path.",
          "narrative": "Moss covers the steps — someone walked here."},
    nf_b={"gameplay": "Narrow: one ambush at a time, no flank.",
          "visual": "A fallen trunk spans the passage; you go around.",
          "narrative": "Moss covers the steps — someone walked here."},
)

# 2. junction_cross — the crossroads (4 exits; the third is sealed)
modular(
    "junction_cross",
    ["watchtower", "ancient_gate"],
    10.0, 10.0, "JUNCTION",
    doors_extra=[("door_c", 5.0, 0.0, 0.0, -1.0, 0.0, 0.0)],
    obstacles_a=[((0, (0.0, 0.75, 0.0)), (1.2, 1.5, 1.2))],
    obstacles_b=[((0, (0.0, 0.75, 0.0)), (1.2, 1.5, 1.2)),
                 ((1, (-3.5, 0.4, 3.5)), (1.2, 0.8, 1.2))],
    nf_a={"gameplay": "Four paths, one center: the decision point.",
          "visual": "A standing stone in the middle, worn by hands.",
          "interaction": "The stone can be examined."},
    nf_b={"gameplay": "Four paths, one center: the decision point.",
          "visual": "A standing stone in the middle, worn by hands.",
          "narrative": "A fresh scratch on the stone — recent."},
)

# 3. junction_t — the fork
modular(
    "junction_t",
    ["ruined_village"],
    10.0, 10.0, "JUNCTION",
    doors_extra=[("door_c", 5.0, 0.0, 0.0, -1.0, 0.0, 0.0)],
    obstacles_a=[((0, (2.5, 0.5, 0.0)), (1.4, 1.0, 1.4))],
    obstacles_b=[((0, (-2.5, 0.5, 0.0)), (1.4, 1.0, 1.4))],
    nf_a={"visual": "A fork: one path continues, one falls away.",
          "narrative": "The fork is fresh — made recently. This run? The last?"},
    nf_b={"visual": "A fork: one path continues, one falls away.",
          "narrative": "The fork is fresh — made recently. This run? The last?"},
)

# 4. room_combat — the fight room
modular(
    "room_combat",
    ["the_mine", "broken_bridge"],
    12.0, 10.0, "COMBAT",
    enemy_spots=[(-3.5, 0.0, -2.5), (3.5, 0.0, -2.5), (0.0, 0.0, 1.5)],
    obstacles_a=[((0, (-4.0, 0.5, 2.5)), (1.6, 1.0, 1.6))],
    obstacles_b=[((0, (4.0, 0.5, 2.5)), (1.6, 1.0, 1.6)),
                 ((1, (0.0, 0.4, -3.5)), (2.0, 0.8, 1.0))],
    nf_a={"gameplay": "The fight: 2-3 enemies from the spots.",
          "visual": "Rusted lines on the walls — someone was here before."},
    nf_b={"gameplay": "The fight: 2-3 enemies from the spots.",
          "narrative": "A broken camp — the fight was here before."},
)

# 5. room_loot — the left-behind room
modular(
    "room_loot",
    ["ruined_village", "broken_bridge"],
    10.0, 10.0, "LOOT",
    loot_spots=[(-3.0, 0.0, -2.5), (3.0, 0.0, 2.5)],
    obstacles_a=[((0, (0.0, 0.5, -3.5)), (2.4, 1.0, 1.0))],
    obstacles_b=[((0, (0.0, 0.5, 3.5)), (2.4, 1.0, 1.0))],
    nf_a={"discovery": "Find spots (loot, or the weapon in a production room).",
          "visual": "A pile of things left in a hurry."},
    nf_b={"discovery": "Find spots (loot, or the weapon in a production room).",
          "visual": "A pile of things left in a hurry."},
)

# 6. room_mystery — the mystery beat room
modular(
    "room_mystery",
    ["the_mine", "old_shrine"],
    10.0, 12.0, "MYSTERY",
    event_spots=[(0.0, 0.0, -3.0)],
    obstacles_a=[((0, (-3.5, 0.5, 3.0)), (1.4, 1.0, 1.4))],
    obstacles_b=[((0, (3.5, 0.5, 3.0)), (1.4, 1.0, 1.4)),
                 ((1, (0.0, 0.3, 0.5)), (1.6, 0.6, 1.6))],
    fog_a=0.9, fog_b=1.0,
    nf_a={"narrative": "The scripted mystery beat (M1-M4, the zone's beat map).",
          "visual": "The light is wrong here — a memory layer."},
    nf_b={"narrative": "The scripted mystery beat (M1-M4, the zone's beat map).",
          "visual": "The light is wrong here — a memory layer."},
)

# 7. room_note — the note room (home away from home)
modular(
    "room_note",
    ["ruined_village", "watchtower", "broken_bridge", "ancient_gate"],
    8.0, 8.0, "SHELTER",
    event_spots=[(2.5, 0.0, 2.5)],
    obstacles_a=[((0, (-2.5, 0.45, -2.5)), (1.8, 0.9, 1.8))],
    obstacles_b=[((0, (-2.5, 0.45, 2.5)), (1.8, 0.9, 1.8))],
    fog_a=0.6, fog_b=0.7,
    light_a=(0.7, 0.62, 0.5), light_b=(0.65, 0.6, 0.5),
    energy_a=0.9, energy_b=0.8,
    nf_a={"interaction": "The note stand: your note (next run) and the world's note.",
          "narrative": "Home away from home: a table, a cup, the lamp."},
    nf_b={"interaction": "The note stand: your note (next run) and the world's note.",
          "narrative": "Home away from home: a table, a cup, the lamp."},
)

# 8. room_shelter — the quiet room
modular(
    "room_shelter",
    ["old_shrine", "mysterious_lake"],
    8.0, 10.0, "SHELTER",
    obstacles_a=[((0, (2.0, 0.4, -3.0)), (1.6, 0.8, 1.6))],
    obstacles_b=[((0, (-2.0, 0.4, 3.0)), (1.6, 0.8, 1.6))],
    fog_a=0.5, fog_b=0.6,
    light_a=(0.7, 0.65, 0.5), light_b=(0.65, 0.62, 0.5),
    energy_a=1.0, energy_b=0.85,
    nf_a={"gameplay": "A quiet rest: no enemies spawn here.",
          "visual": "A warm light — the only amber in the zone."},
    nf_b={"gameplay": "A quiet rest: no enemies spawn here.",
          "visual": "A warm light — the only amber in the zone."},
)

# 9. corridor_stairs — down, the light dies
modular(
    "corridor_stairs",
    ["the_mine"],
    6.0, 12.0, "CORRIDOR",
    enemy_spots=[(0.0, 0.0, -2.0)],
    obstacles_a=[((0, (-2.0, 0.4, 2.0)), (1.2, 0.8, 1.2))],
    obstacles_b=[((0, (2.0, 0.4, -2.0)), (1.2, 0.8, 1.2))],
    fog_a=0.75, fog_b=0.9,
    energy_a=0.55, energy_b=0.3,
    nf_a={"visual": "Going down, the light goes out (lighting ritual).",
          "narrative": "The deeper, the closer to the memory.",
          "discovery": "A lantern niche — the First's light (The Mine)."},
    nf_b={"visual": "Going down, the light goes out (lighting ritual).",
          "narrative": "The deeper, the closer to the memory.",
          "discovery": "A lantern niche — the First's light (The Mine)."},
)

# 10. corridor_bridge — the plank bridge over the gap
modular(
    "corridor_bridge",
    ["broken_bridge"],
    4.0, 14.0, "CORRIDOR",
    enemy_spots=[(0.0, 0.0, 2.5)],
    obstacles_a=[((0, (0.0, 0.3, -3.0)), (3.6, 0.6, 0.4))],
    obstacles_b=[((0, (0.0, 0.3, 3.0)), (3.6, 0.6, 0.4))],
    nf_a={"visual": "A gap in the middle: the view to the lake through it.",
          "gameplay": "Narrow: you cannot dodge sideways."},
    nf_b={"visual": "A gap in the middle: the view to the lake through it.",
          "gameplay": "Narrow: you cannot dodge sideways."},
)

# 11. room_echo — the echo room (a memory mirror)
modular(
    "room_echo",
    ["old_shrine", "mysterious_lake", "ancient_gate"],
    10.0, 10.0, "MYSTERY",
    event_spots=[(0.0, 0.0, -2.5)],
    obstacles_a=[((0, (-3.5, 0.4, 0.0)), (1.2, 0.8, 1.2))],
    obstacles_b=[((0, (3.5, 0.4, 0.0)), (1.2, 0.8, 1.2))],
    fog_a=0.85, fog_b=0.95,
    light_a=(0.5, 0.55, 0.7), light_b=(0.45, 0.5, 0.7),
    nf_a={"narrative": "A Passive Echo plays here (a memory, scripted).",
          "visual": "Desaturated + emissive — the echo layer."},
    nf_b={"narrative": "A Passive Echo plays here (a memory, scripted).",
          "visual": "Desaturated + emissive — the echo layer."},
)

# 12. room_archive — the shelves (Nia's theme)
modular(
    "room_archive",
    ["ruined_village"],
    10.0, 10.0, "LOOT",
    loot_spots=[(-3.5, 0.0, -3.0)],
    event_spots=[(3.5, 0.0, 3.0)],
    obstacles_a=[((0, (-3.5, 0.9, -3.8)), (2.6, 1.8, 0.8)),
                 ((1, (3.5, 0.9, 3.8)), (2.6, 1.8, 0.8))],
    obstacles_b=[((0, (3.5, 0.9, -3.8)), (2.6, 1.8, 0.8)),
                 ((1, (-3.5, 0.9, 3.8)), (2.6, 1.8, 0.8))],
    nf_a={"visual": "Shelves — an archive in miniature (Nia).",
          "discovery": "A page: a note for the next run.",
          "narrative": "Someone kept the books."},
    nf_b={"visual": "Shelves — an archive in miniature (Nia).",
          "discovery": "A page: a note for the next run.",
          "narrative": "Someone kept the books."},
)

# 13. room_boneyard — the pile of bones
modular(
    "room_boneyard",
    ["ruined_village"],
    10.0, 10.0, "MYSTERY",
    enemy_spots=[(0.0, 0.0, -2.5)],
    obstacles_a=[((0, (0.0, 0.35, 2.5)), (3.0, 0.7, 2.0))],
    obstacles_b=[((0, (0.0, 0.35, -3.8)), (3.0, 0.7, 2.0))],
    fog_a=0.9, fog_b=0.95,
    nf_a={"visual": "A pile of bones, arranged — not scattered.",
          "narrative": "They were sorted. By whom? (the village beat)"},
    nf_b={"visual": "A pile of bones, arranged — not scattered.",
          "narrative": "They were sorted. By whom? (the village beat)"},
)

# ------------------------------------------------------------------
# The handcrafted rooms (WORLD_BIBLE §2: camp, zone entries, the
# Undercroft are NOT procedural).
# ------------------------------------------------------------------

# The camp hub: 8 gate doorways on a circle (match CampWorld's
# ZoneGate markers: pos (sin a * 10.5, 0, cos a * 10.5), facing out).
CAMP_ZONES = ["ruined_village", "watchtower", "the_mine", "old_shrine",
              "broken_bridge", "mysterious_lake", "ancient_gate",
              "undercroft"]
CAMP_ANGLES = [22, 182, 247, 151, 340, 59, 112, 292]
camp_doors = []
for zn, ang in zip(CAMP_ZONES, CAMP_ANGLES):
    a = math.radians(ang)
    camp_doors.append((
        "gate_" + zn,
        round(math.sin(a) * 10.5, 3), 0.0, round(math.cos(a) * 10.5, 3),
        round(math.sin(a), 3), 0.0, round(math.cos(a), 3),
    ))
room_tres(
    "camp_room", "camp_room", ["camp"], 0, "SHELTER", (21.0, 21.0),
    camp_doors, [], [], [], [],
    0.85, (0.55, 0.6, 0.55), 0.5, True,
    {"narrative": "The camp: home, the roster, the map. (the hub)"},
)


def entry_room(name, rid, areas, w, d, obstacles, enemy_spots=(),
               loot_spots=(), event_spots=(), fog=0.85,
               light=(0.55, 0.6, 0.55), energy=0.55, nf=None,
               fixed_loot=""):
    doors = [
        ("camp_exit", 0.0, 0.0, d / 2.0, 0.0, 0.0, -1.0),
        ("to_chain", 0.0, 0.0, -d / 2.0, 0.0, 0.0, 1.0),
    ]
    room_tres(name, rid, areas, 0, "JUNCTION", (w, d), doors, obstacles,
              list(enemy_spots), list(loot_spots), list(event_spots),
              fog, light, energy, True, nf or {}, fixed_loot)


entry_room(
    "village_entry", "village_entry", ["ruined_village"], 12.0, 12.0,
    obstacles=[((0, (-3.5, 0.9, -3.0)), (2.4, 1.8, 2.4)),
               ((1, (3.8, 0.9, 2.8)), (2.4, 1.8, 2.4))],
    event_spots=[(0.0, 0.0, 1.0)],
    nf={"visual": "Burned houses, an archive shelf intact.",
        "narrative": "The village burned — the books did not. (Nia)"},
)
entry_room(
    "watchtower_entry", "watchtower_entry", ["watchtower"], 10.0, 10.0,
    obstacles=[((0, (0.0, 1.25, -2.0)), (4.0, 2.5, 4.0))],
    enemy_spots=[(3.0, 0.0, 2.0)],
    nf={"visual": "The tower stairs: the count board (312 days).",
        "discovery": "The count board — someone counted the days.",
        "narrative": "The watch ended. Nobody says why."},
)
entry_room(
    "mine_entry", "mine_entry", ["the_mine"], 10.0, 12.0,
    obstacles=[((0, (0.0, 1.0, -4.0)), (5.0, 2.0, 2.0))],
    enemy_spots=[(3.5, 0.0, 2.0)],
    loot_spots=[(-3.0, 0.0, 2.0)],
    nf={"visual": "The mine mouth, a lantern hook (cold).",
        "discovery": "The HAND CANNON (production weapon, WEAPON_DESIGN §5).",
        "narrative": "The mine stopped mid-shift. The lantern is cold."},
    fixed_loot="weapon_cannon",
)
entry_room(
    "shrine_entry", "shrine_entry", ["old_shrine"], 10.0, 10.0,
    obstacles=[((0, (-3.5, 0.9, -2.5)), (1.0, 1.8, 1.0)),
               ((1, (0.0, 1.1, -3.6)), (1.0, 2.2, 1.0)),
               ((2, (3.5, 0.9, -2.5)), (1.0, 1.8, 1.0))],
    loot_spots=[(0.0, 0.0, 1.5)],
    nf={"visual": "A semicircle of standing stones, one broken.",
        "discovery": "The ECHO STAFF (production weapon, WEAPON_DESIGN §5).",
        "narrative": "The shrine answered before the village burned."},
    fixed_loot="weapon_staff",
)
entry_room(
    "bridge_entry", "bridge_entry", ["broken_bridge"], 10.0, 10.0,
    obstacles=[((0, (0.0, 0.4, -3.0)), (8.0, 0.8, 2.4))],
    enemy_spots=[(-3.0, 0.0, 2.5)],
    nf={"visual": "The broken bridge: the gap, the lake below.",
        "discovery": "A map of the routes (the bridge beat).",
        "narrative": "The bridge broke on the day the watch ended."},
)
entry_room(
    "lake_entry", "lake_entry", ["mysterious_lake"], 12.0, 12.0,
    obstacles=[((0, (2.5, 0.5, -3.5)), (2.0, 1.0, 2.0))],
    enemy_spots=[(-3.5, 0.0, 2.0)],
    nf={"visual": "The shore: still water, no reflection. (the lake)",
        "narrative": "The lake keeps what falls in. (the mystery beat)"},
)
entry_room(
    "gate_approach", "gate_approach", ["ancient_gate"], 12.0, 12.0,
    obstacles=[((0, (0.0, 1.5, -4.5)), (4.0, 3.0, 2.0))],
    enemy_spots=[(3.5, 0.0, 2.5), (-3.5, 0.0, 2.5)],
    nf={"visual": "The Gate: a circle with three notches. (form = question)",
        "narrative": "The seal. Three notches. Nobody left a mark. (K7)",
        "mystery_note": None},
)
# The boss arena: handcrafted, the ONLY sink.
room_tres(
    "undercroft_arena", "undercroft_arena", ["undercroft"], 0, "MYSTERY",
    (18.0, 18.0),
    [
        ("entry_mine", 0.0, 0.0, 9.0, 0.0, 0.0, -1.0),
        ("entry_gate", 0.0, 0.0, -9.0, 0.0, 0.0, 1.0),
        ("camp_exit", -9.0, 0.0, 0.0, 1.0, 0.0, 0.0),
    ],
    obstacles=[((0, (0.0, 0.9, -5.0)), (3.0, 1.8, 1.6))],
    enemy_spots=[],
    loot_spots=[(6.0, 0.0, 6.0)],
    event_spots=[(0.0, 0.0, -3.0)],
    fog=0.95, light_color=(0.5, 0.55, 0.6), light_energy=0.35,
    handcrafted=True,
    nofiller={"visual": "The First's workshop: a workbench, the dark beyond.",
              "narrative": "The Undercroft — the memory of the beginning. (boss)"},
)

# ------------------------------------------------------------------
# The spawn tables (7 zones; the undercroft = boss, no spawns).
# ------------------------------------------------------------------

ENEMY_FILES = {
    "hollow_base": "hollow_base.tres",
    "hollow_fast": "hollow_fast.tres",
    "hollow_big": "hollow_big.tres",
    "watcher_base": "watcher_base.tres",
    "remnant_mirror": "remnant_mirror.tres",
    "remnant_false": "remnant_false.tres",
    "mimic_combo": "mimic_combo.tres",
    "forgotten_wanderer": "forgotten_wanderer.tres",
    "forgotten_guard": "forgotten_guard.tres",
}


def spawn_table(name, zone, entries):
    exts = [
        '[ext_resource type="Script" path="%s" id="1_tbl"]' % TBL_GD,
        '[ext_resource type="Script" path="%s" id="2_ent"]' % ENT_GD,
    ]
    subs = []
    refs = []
    for i, (eid, cond) in enumerate(entries):
        exts.append('[ext_resource type="Resource" '
                    'path="res://data/enemies/%s" id="e%d"]'
                    % (ENEMY_FILES[eid], i + 3))
        subs.append(
            '[sub_resource type="Resource" id="se%d"]\n'
            'script = ExtResource("2_ent")\n'
            'enemy = ExtResource("e%d")\n'
            'position = Vector3(0, 0, 0)\n'
            'condition = "%s"' % (i, i + 3, cond)
        )
        refs.append('SubResource("se%d")' % i)
    header = ("[gd_resource type=\"Resource\" script_class=\"SpawnTable\" "
              "load_steps=%d format=3]" % (len(exts) + len(subs) + 1))
    body = header + "\n\n" + "\n".join(exts) + "\n\n" \
        + "\n\n".join(subs) + "\n\n[resource]\n" \
        + "script = ExtResource(\"1_tbl\")\n" \
        + "entries = Array[SpawnEntry](%s)" % ("[%s]" % ", ".join(refs))
    with open(os.path.join(ENEMIES, "zone_spawn_table_%s.tres" % zone),
              "w", encoding="utf-8") as f:
        f.write(body + "\n")


spawn_table("village", "village",
            [("hollow_base", "always"), ("forgotten_wanderer", "explorer")])
spawn_table("watchtower", "watchtower",
            [("watcher_base", "always"), ("hollow_fast", "runner")])
spawn_table("mine", "mine",
            [("hollow_base", "always"), ("hollow_fast", "always"),
             ("hollow_big", "slayer")])
spawn_table("shrine", "shrine",
            [("remnant_mirror", "always")])
spawn_table("bridge", "bridge",
            [("hollow_base", "always"), ("mimic_combo", "explorer")])
spawn_table("lake", "lake",
            [("remnant_false", "always")])
spawn_table("gate", "gate",
            [("watcher_base", "always"), ("forgotten_guard", "runner")])

# ------------------------------------------------------------------
# The areas (the DAG pool).
# ------------------------------------------------------------------

AREAS_GD = AREA_GD
CONN_GD = "res://scripts/gameplay/areas/area_connection.gd"


def area_tres(name, aid, aname, theme, room_files, weights,
              connections, boss=False, entry_anchor="entry",
              fog=0.85, light=(0.55, 0.6, 0.55), spawn_table_name=None):
    exts = ['[ext_resource type="Script" path="%s" id="1_ad"]' % AREAS_GD,
            '[ext_resource type="Script" path="%s" id="2_ac"]' % CONN_GD]
    for i, rf in enumerate(room_files):
        exts.append('[ext_resource type="Resource" '
                    'path="res://data/rooms/%s.tres" id="r%d"]' % (rf, i + 3))
    ext_idx = 3 + len(room_files)
    spawn_ext = None
    if spawn_table_name:
        spawn_ext = 'st%d' % ext_idx
        exts.append('[ext_resource type="Resource" '
                    'path="res://data/enemies/zone_spawn_table_%s.tres" '
                    'id="%s"]' % (spawn_table_name, spawn_ext))
    conn_subs = []
    conn_refs = []
    for i, (to, door, cond, tdoor) in enumerate(connections):
        conn_subs.append(
            '[sub_resource type="Resource" id="ac%d"]\n'
            'script = ExtResource("2_ac")\n'
            'to = &"%s"\n'
            'door = &"%s"\n'
            'condition = &"%s"\n'
            'target_door = &"%s"' % (i, to, door, cond, tdoor)
        )
        conn_refs.append('SubResource("ac%d")' % i)
    subs = conn_subs
    room_refs = ", ".join('ExtResource("r%d")' % (i + 3)
                          for i in range(len(room_files)))
    weights_str = "PackedFloat64Array(%s)" % \
        ", ".join(fnum(w) for w in weights) if weights else "PackedFloat64Array()"
    body = [
        "id = &\"%s\"" % aid,
        "name = \"%s\"" % aname,
        "theme = \"%s\"" % theme,
        "rooms = Array[RoomData](%s)" % ("[%s]" % room_refs),
        "room_weights = %s" % weights_str,
        "connections = Array[AreaConnection](%s)" % \
            ("[%s]" % ", ".join(conn_refs) if conn_refs else "[]"),
        "boss_arena = %s" % ("true" if boss else "false"),
        'entry_anchor = &"%s"' % entry_anchor,
        "fog_density = %s" % fnum(fog),
        "light_color = Color(%s, %s, %s, %s)" % (fnum(light[0]), fnum(light[1]), fnum(light[2]), fnum(1.0)),
    ]
    if spawn_ext:
        body.append("spawn_table = ExtResource(\"%s\")" % spawn_ext)
    header = '[gd_resource type="Resource" script_class="AreaData" ' \
        'load_steps=%d format=3]' % (len(exts) + len(subs) + 1)
    parts = [header, ""] + exts
    if subs:
        parts += [""] + subs
    parts += ["", "[resource]", "script = ExtResource(\"1_ad\")", ""] + body
    with open(os.path.join(AREAS, name + ".tres"), "w", encoding="utf-8") as f:
        f.write("\n".join(parts) + "\n")


area_tres("camp", "camp", "The Camp", "home",
          ["camp_room"], [1.0],
          [("ruined_village", "gate_ruined_village", "", "camp_exit"),
           ("watchtower", "gate_watchtower", "", "camp_exit"),
           ("the_mine", "gate_the_mine", "", "camp_exit"),
           ("old_shrine", "gate_old_shrine", "", "camp_exit"),
           ("broken_bridge", "gate_broken_bridge", "", "camp_exit"),
           ("mysterious_lake", "gate_mysterious_lake", "", "camp_exit"),
           ("ancient_gate", "gate_ancient_gate", "", "camp_exit")],
          fog=0.85, light=(0.55, 0.6, 0.55))

area_tres("ruined_village", "ruined_village", "The Ruined Village",
          "the archive that burned",
          ["village_entry", "room_archive_v0", "room_archive_v1",
           "room_boneyard_v0", "room_boneyard_v1", "room_note_v0",
           "room_note_v1", "room_loot_v0", "room_loot_v1"],
          [1.0, 2.0, 2.0, 1.5, 1.5, 1.0, 1.0, 1.0, 1.0],
          [], fog=0.85, light=(0.6, 0.55, 0.5),
          spawn_table_name="village")

area_tres("watchtower", "watchtower", "The Watchtower",
          "the count that ended",
          ["watchtower_entry", "corridor_forest_v0", "corridor_forest_v1",
           "junction_cross_v0", "junction_cross_v1", "room_note_v0",
           "room_note_v1"],
          [1.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0],
          [], fog=0.8, light=(0.55, 0.6, 0.55),
          spawn_table_name="watchtower")

area_tres("the_mine", "the_mine", "The Mine",
          "the light that went out",
          ["mine_entry", "corridor_stairs_v0", "corridor_stairs_v1",
           "room_combat_v0", "room_combat_v1"],
          [1.0, 2.0, 2.0, 2.0, 2.0],
          [("undercroft", "door_b", "", "entry_mine")],
          fog=0.9, light=(0.5, 0.55, 0.5),
          spawn_table_name="mine")

area_tres("old_shrine", "old_shrine", "The Old Shrine",
          "the answer before the burning",
          ["shrine_entry", "room_echo_v0", "room_echo_v1",
           "room_mystery_v0", "room_mystery_v1", "room_shelter_v0",
           "room_shelter_v1"],
          [1.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0],
          [], fog=0.85, light=(0.5, 0.55, 0.7),
          spawn_table_name="shrine")

area_tres("broken_bridge", "broken_bridge", "The Broken Bridge",
          "the map of the routes",
          ["bridge_entry", "corridor_bridge_v0", "corridor_bridge_v1",
           "room_note_v0", "room_note_v1", "room_combat_v0",
           "room_combat_v1"],
          [1.0, 2.0, 2.0, 1.0, 1.0, 1.5, 1.5],
          [], fog=0.8, light=(0.55, 0.6, 0.55),
          spawn_table_name="bridge")

area_tres("mysterious_lake", "mysterious_lake", "The Mysterious Lake",
          "what the water keeps",
          ["lake_entry", "room_echo_v0", "room_echo_v1",
           "room_shelter_v0", "room_shelter_v1", "corridor_forest_v0",
           "corridor_forest_v1"],
          [1.0, 2.0, 2.0, 1.0, 1.0, 1.0, 1.0],
          [], fog=0.9, light=(0.5, 0.55, 0.7),
          spawn_table_name="lake")

area_tres("ancient_gate", "ancient_gate", "The Ancient Gate",
          "the seal with three notches",
          ["gate_approach", "junction_cross_v0", "junction_cross_v1",
           "room_note_v0", "room_note_v1", "room_echo_v0",
           "room_echo_v1"],
          [1.0, 2.0, 2.0, 1.0, 1.0, 1.5, 1.5],
          [("undercroft", "door_b", "", "entry_gate")],
          fog=0.95, light=(0.5, 0.55, 0.6),
          spawn_table_name="gate")

area_tres("undercroft", "undercroft", "The Undercroft",
          "the memory of the beginning",
          ["undercroft_arena"], [1.0],
          [], boss=True, fog=0.95, light=(0.5, 0.55, 0.6))

print("Phase 7 data written: %d rooms, 9 areas, 7 spawn tables"
      % len(os.listdir(ROOMS)))
