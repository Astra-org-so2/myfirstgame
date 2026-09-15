# Unit: MemoryStats (dominant_style + aggression profile) and the
# director's pure spawn rules (ENEMY_DESIGN §7, WORLD_STATE_DESIGN §3).
extends Node

const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")
const _THR = preload("res://scripts/gameplay/memory_stats_thresholds.gd")
const _DIRECTOR = preload("res://scripts/gameplay/enemies/enemy_director.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")


func run(ctx: Variant) -> void:
	var t: _THR = load("res://data/memory_stats_thresholds.tres")

	# --- dominant_style (the Mimic's mirror source) ---
	var s: _STYLE = _STYLE.new()
	s.melee_hits = 4
	s.dodge_count = 3
	s.ranged_hits = 3
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_NONE,
			"memory_stats: no verb above 50% (4/10) -> no style")
	s = _STYLE.new()
	s.melee_hits = 10
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_MELEE,
			"memory_stats: 10 melee -> melee style")
	s = _STYLE.new()
	s.ranged_hits = 10
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_RANGED,
			"memory_stats: 10 ranged -> ranged style")
	s = _STYLE.new()
	s.dodge_count = 10
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_DODGE,
			"memory_stats: 10 dodges -> dodge style")
	s = _STYLE.new()
	s.melee_hits = 6
	s.ranged_hits = 4
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_MELEE,
			"memory_stats: 6/4 at 60% -> melee (dominance 50%)")
	s = _STYLE.new()
	s.melee_hits = 4
	s.ranged_hits = 4
	s.dodge_count = 4
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_NONE,
			"memory_stats: varied play (40%) -> no style")
	s = _STYLE.new()
	s.melee_hits = 5
	s.ranged_hits = 5
	# Exactly 50% IS committed (dominance >= pct); the tie resolves to
	# the first-best verb (melee is checked first).
	ctx.check(s.dominant_style(10, 50) == _STYLE.STYLE_MELEE,
			"memory_stats: 5/5 at exactly 50% -> committed (melee)")

	# --- aggression profile (the enemy side of memory) ---
	s = _STYLE.new()
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_NORMAL,
			"memory_stats: fresh player -> normal aggression")
	s.kills = 20
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_NORMAL,
			"memory_stats: exactly 20 kills is NOT a slayer (>)")
	s.kills = 21
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_SLAYER,
			"memory_stats: 21 kills -> slayer")
	s.fled = 11
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_SLAYER,
			"memory_stats: slayer outranks runner")
	s = _STYLE.new()
	s.fled = 11
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_RUNNER,
			"memory_stats: 11 fled -> runner")
	s = _STYLE.new()
	s.explored_pct = 60
	s.strange_actions = 6
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_EXPLORER,
			"memory_stats: 60% explored + 6 strange -> explorer")
	s.strange_actions = 5
	ctx.check(s.aggression_profile(t) == _STYLE.PROFILE_NORMAL,
			"memory_stats: exactly 5 strange is not enough (>)")

	# --- the director's spawn rules (pure) ---
	var d: _DIRECTOR = _DIRECTOR.new()
	d.setup(null, s, t, null)
	var table: _TABLE = _TABLE.new()
	# Build a minimal table in code (data tables test in enemy_data).
	table.entries = [_entry(d, "always"), _entry(d, "slayer"),
			_entry(d, "runner"), _entry(d, "explorer"),
			_entry(d, "style:dodge"), _entry(d, "style:melee"),
			_entry(d, "style:ranged"), _entry(d, "first_run"),
			_entry(d, "no_such_rule")]

	# A fresh player (normal profile, no style, first run): only
	# "always" and "first_run" spawn.
	s = _STYLE.new()
	d.setup(null, s, t, null)
	ctx.check(d.should_spawn(table.entries[0]),
			"spawn: 'always' spawns for anyone")
	ctx.check(not d.should_spawn(table.entries[1]),
			"spawn: slayer rule is quiet for a fresh player")
	ctx.check(not d.should_spawn(table.entries[4]),
			"spawn: style rules need a dominant style")
	ctx.check(d.should_spawn(table.entries[7]),
			"spawn: first_run spawns on run 0")

	# A slayer with a committed dodge style, run 3.
	s = _STYLE.new()
	s.kills = 21
	s.dodge_count = 10
	s.runs_completed = 3
	d.setup(null, s, t, null)
	ctx.check(d.should_spawn(table.entries[1]),
			"spawn: slayer rule fires at 21 kills")
	ctx.check(not d.should_spawn(table.entries[2]),
			"spawn: runner stays quiet for the slayer")
	ctx.check(d.should_spawn(table.entries[4]),
			"spawn: style:dodge fires for the dodge-heavy player")
	ctx.check(not d.should_spawn(table.entries[5]),
			"spawn: style:melee stays quiet for the dodger")
	ctx.check(not d.should_spawn(table.entries[7]),
			"spawn: first_run is over on run 3")

	# Unknown condition: fails closed (no spawn, push_error logged).
	ctx.check(not d.should_spawn(table.entries[8]),
			"spawn: unknown condition fails closed")

	# --- aggression application (the multipliers are real) ---
	d.setup(null, s, t, null)
	d.apply_aggression(_STYLE.PROFILE_SLAYER)
	ctx.check(absf(d.speed_mult - 1.10) < 0.001
			and absf(d.dmg_mult - 1.05) < 0.001,
			"spawn: slayer -> +10% speed / +5% damage")
	d.apply_aggression(_STYLE.PROFILE_RUNNER)
	ctx.check(absf(d.speed_mult - 0.90) < 0.001
			and d.follow_mult > 1.0,
			"spawn: runner -> -10% speed, harder Watcher follow")
	d.apply_aggression(_STYLE.PROFILE_EXPLORER)
	ctx.check(d.hear_muted,
			"spawn: explorer -> enemies mute to sound")
	d.apply_aggression(_STYLE.PROFILE_NORMAL)
	ctx.check(d.speed_mult == 1.0 and d.dmg_mult == 1.0
			and not d.hear_muted,
			"spawn: normal profile resets the multipliers")


func _entry(_d: _DIRECTOR, condition: String) -> Resource:
	# Minimal spawn entry (no enemy data: should_spawn never reads it).
	var entry_script: Script = load(
			"res://scripts/gameplay/enemies/spawn_entry.gd")
	var e: Resource = entry_script.new()
	e.condition = condition
	return e
