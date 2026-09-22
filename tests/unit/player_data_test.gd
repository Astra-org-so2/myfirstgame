# Unit: PlayerData resource (Phase 2).
# Validates the resource itself: defaults, ranges, and the .tres file.
extends Node

const _DATA = preload("res://scripts/player/player_data.gd")

func run(ctx: Variant) -> void:
	# 1. .tres loads and is the right script.
	var res: Resource = load("res://data/player/player_data.tres")
	ctx.check(res != null, "player_data: .tres loads")
	ctx.check(
		res != null and res is _DATA,
		"player_data: .tres is a PlayerData resource"
	)
	if res == null:
		return
	ctx.check(res.validate().is_empty(), "player_data: .tres passes validate()")

	# 2. Defaults are sensible for a mobile 3D game (TECHNICAL_DESIGN §9:
	#    14-16 m/s top speed; 6.5 sprint / 9.0 dodge is well inside).
	var d: _DATA = _DATA.new()
	ctx.check(d.validate().is_empty(), "player_data: defaults pass validate()")
	ctx.check(d.walk_speed > 0.0 and d.walk_speed < d.sprint_speed,
			"player_data: 0 < walk < sprint speed")
	ctx.check(d.sprint_speed < d.dodge_speed,
			"player_data: sprint < dodge speed")
	ctx.check(d.stamina_max >= 100.0, "player_data: stamina_max = 100")
	ctx.check(d.sprint_min > 0.0 and d.sprint_min < d.stamina_max,
			"player_data: 0 < sprint_min < stamina_max")
	ctx.check(d.dodge_stamina_cost > 0.0, "player_data: dodge cost > 0")
	ctx.check(d.dodge_iframe_start < d.dodge_iframe_end,
			"player_data: i-frame start < end")
	ctx.check(d.dodge_iframe_end <= d.dodge_duration,
			"player_data: i-frame end <= dodge duration")
	ctx.check(d.dodge_cooldown > d.dodge_iframe_end,
			"player_data: cooldown covers the whole dodge")

	# 3. Out-of-range values are rejected (validate() must catch them).
	var bad: _DATA = _DATA.new()
	bad.walk_speed = -1.0
	ctx.check(not bad.validate().is_empty(),
			"player_data: negative walk_speed rejected")
	var bad2: _DATA = _DATA.new()
	bad2.dodge_iframe_start = 0.3
	bad2.dodge_iframe_end = 0.1
	ctx.check(not bad2.validate().is_empty(),
			"player_data: i-frame start > end rejected")
	var bad3: _DATA = _DATA.new()
	bad3.gravity = 0.0
	ctx.check(not bad3.validate().is_empty(),
			"player_data: zero gravity rejected")
	var bad4: _DATA = _DATA.new()
	bad4.sprint_drain_per_sec = 0.0
	ctx.check(not bad4.validate().is_empty(),
			"player_data: zero sprint drain rejected")
