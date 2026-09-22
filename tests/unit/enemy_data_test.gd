# Unit: enemy data — all 11 variants + attacks load, validate clean,
# and carry the ENEMY_DESIGN §6 numbers (the design IS the data).
extends Node

const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _ATTACK = preload("res://scripts/gameplay/enemies/attack_data.gd")
const _THR = preload("res://scripts/gameplay/memory_stats_thresholds.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")

const VARIANTS: Array[String] = [
	"hollow_base", "hollow_fast", "hollow_big",
	"remnant_mirror", "remnant_false",
	"watcher_base",
	"mimic_dodge", "mimic_range", "mimic_combo",
	"forgotten_wanderer", "forgotten_guard",
]


func run(ctx: Variant) -> void:
	# 1. All 11 variants load and validate clean (ENEMY_DESIGN §6).
	var ok: bool = true
	for v in VARIANTS:
		var d: _DATA = load("res://data/enemies/%s.tres" % v)
		if d == null or not (d is _DATA):
			ctx.check(false, "enemy_data: %s loads" % v)
			ok = false
			continue
		var problems: Array[String] = d.validate()
		ctx.check(problems.is_empty(),
				"enemy_data: %s validates (%s)" % [
						v, "; ".join(problems)])
		if d.attack == null:
			ctx.check(false, "enemy_data: %s has attack data" % v)
			ok = false
	ctx.check(ok, "enemy_data: all 11 variants present")

	# 2. Attack cooldowns = windup + active + recovery (design §6 cd).
	ctx.check(_cd(ctx, "hollow_base", 2.0))
	ctx.check(_cd(ctx, "hollow_fast", 1.5))
	ctx.check(_cd(ctx, "hollow_big", 2.5))
	ctx.check(_cd(ctx, "remnant_mirror", 1.8))
	ctx.check(_cd(ctx, "remnant_false", 2.2))
	ctx.check(_cd(ctx, "mimic_dodge", 1.5))
	ctx.check(_cd(ctx, "forgotten_wanderer", 3.0))
	ctx.check(_cd(ctx, "forgotten_guard", 2.5))

	# 3. Hollow (base) spot numbers.
	var h: _DATA = load("res://data/enemies/hollow_base.tres")
	ctx.check(h.health == 30 and h.attack.damage == 15,
			"enemy_data: hollow base hp 30 / dmg 15")
	ctx.check(h.speed == 1.8 and h.fov == 120.0 and h.hear_range == 5.0,
			"enemy_data: hollow base speed/fov/hear")
	var hf: _DATA = load("res://data/enemies/hollow_fast.tres")
	var hb: _DATA = load("res://data/enemies/hollow_big.tres")
	ctx.check(hf.speed == 2.4 and hb.speed == 1.5,
			"enemy_data: hollow fast 2.4 / big 1.5")
	ctx.check(hb.health == 45 and hb.attack.damage == 25,
			"enemy_data: hollow big hp 45 / dmg 25")
	ctx.check(h.leaves_footprint and hf.leaves_footprint
			and hb.leaves_footprint,
			"enemy_data: hollows leave footprints (K2 seed)")

	# 4. Watcher: unkillable, no damage, 360 fov, <=2 anchors/run.
	var w: _DATA = load("res://data/enemies/watcher_base.tres")
	ctx.check(w.unkillable and w.health == 999,
			"enemy_data: watcher unkillable (hp 999)")
	ctx.check(w.attack.damage == 0, "enemy_data: watcher does no damage")
	ctx.check(w.fov == 360.0, "enemy_data: watcher sees 360")
	ctx.check(w.observe_time == 2.0 and w.anchors_per_run == 2,
			"enemy_data: watcher observe 2.0 s, <= 2 anchors/run")

	# 5. Mimic: 3 variants = 3 dominant styles (ENEMY_DESIGN §4.4).
	var md: _DATA = load("res://data/enemies/mimic_dodge.tres")
	var mr: _DATA = load("res://data/enemies/mimic_range.tres")
	var mc: _DATA = load("res://data/enemies/mimic_combo.tres")
	ctx.check(md.mirror_style == 3 and mr.mirror_style == 2
			and mc.mirror_style == 1,
			"enemy_data: mimic variants map to dodge/ranged/melee")
	ctx.check(md.punish_window == 0.5 and mr.punish_window == 0.4,
			"enemy_data: mimic punish windows (design §4.6)")
	ctx.check(md.spawn_line != "" and mr.spawn_line != ""
			and mc.spawn_line != "",
			"enemy_data: mimic spawn line set")

	# 6. Remnant: speech + first encounter + note (mirror only).
	var rm: _DATA = load("res://data/enemies/remnant_mirror.tres")
	var rf: _DATA = load("res://data/enemies/remnant_false.tres")
	ctx.check(rm.first_encounter_lines.size() == 2,
			"enemy_data: remnant first-encounter speech (1-3 lines)")
	ctx.check(rm.note_on_death and not rf.note_on_death,
			"enemy_data: note on death — mirror only")
	ctx.check(rm.health == 60 and rm.attack.damage == 20,
			"enemy_data: remnant mirror hp 60 / dmg 20")

	# 7. Forgotten: the slow 3 s dissolve, guard stands (no wander).
	var fw: _DATA = load("res://data/enemies/forgotten_wanderer.tres")
	var fg: _DATA = load("res://data/enemies/forgotten_guard.tres")
	ctx.check(fw.dissolve_time == 3.0 and fg.dissolve_time == 3.0,
			"enemy_data: forgotten dissolve 3 s")
	ctx.check(fw.wander_radius == 15.0 and fg.wander_radius == 0.0,
			"enemy_data: wanderer wanders 15 m / guard stands")
	ctx.check(not fw.whisper_pool.is_empty() and fw.spawn_line != "",
			"enemy_data: forgotten whisper pool + spawn line")
	ctx.check(fw.fragment_on_death and fg.fragment_on_death,
			"enemy_data: forgotten drops a fragment")

	# 8. Memory stats thresholds (WORLD_STATE_DESIGN §3 / §7).
	var t: _THR = load("res://data/memory_stats_thresholds.tres")
	ctx.check(t != null and t.validate().is_empty(),
			"enemy_data: thresholds load + validate")
	ctx.check(t.slayer_kills == 20 and t.runner_fled == 10,
			"enemy_data: thresholds slayer > 20 kills / runner > 10 fled")
	ctx.check(t.explorer_explored_pct == 50
			and t.explorer_strange_actions == 5,
			"enemy_data: thresholds explorer 50% + 5 strange")

	# 9. The camp spawn table: 5 entries, one per archetype.
	var st: _TABLE = load("res://data/enemies/camp_spawn_table.tres")
	ctx.check(st != null and st.validate().is_empty(),
			"enemy_data: camp spawn table loads + validates")
	if st != null:
		var archetypes: Array = []
		var ids: Array = []
		for e in st.entries:
			archetypes.append(e.enemy.archetype)
			ids.append(e.enemy.id)
		ctx.check(st.entries.size() == 5,
				"enemy_data: demo table spawns 5 enemies")
		ctx.check(archetypes.has(0) and archetypes.has(1)
				and archetypes.has(2) and archetypes.has(3)
				and archetypes.has(4),
				"enemy_data: one of each archetype (5 behaviors)")
		ctx.check(_unique(ids),
				"enemy_data: spawn table enemy ids unique")


func _cd(ctx: Variant, v: String, expected: float) -> bool:
	var d: _DATA = load("res://data/enemies/%s.tres" % v)
	var a: _ATTACK = d.attack
	var cd: float = a.windup + a.active + a.recovery
	var ok: bool = absf(cd - expected) < 0.001
	ctx.check(ok, "enemy_data: %s attack cd = %.1f s (got %.2f)"
			% [v, expected, cd])
	return ok


func _unique(arr: Array) -> bool:
	var seen: Dictionary = {}
	for v in arr:
		if seen.has(v):
			return false
		seen[v] = true
	return true
