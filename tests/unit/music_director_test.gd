# Unit: MusicDirector — the variation priority chain (Phase 14).
extends Node

const _DIR = preload("res://scripts/audio/music_director.gd")


func run(ctx: Variant) -> void:
	# The base: the camp, no boss, no echo, no memory.
	ctx.check(_DIR.pick(&"camp", false, false, false)
			== _DIR.Variation.NORMAL, "director: camp = NORMAL")
	for area in ["ruined_village", "watchtower", "the_mine", "old_shrine",
			"broken_bridge", "mysterious_lake", "ancient_gate"]:
		ctx.check(_DIR.pick(area, false, false, false)
				== _DIR.Variation.NORMAL, "director: %s = NORMAL" % area)

	# The boss fight: the Archivist (the monochrome arena).
	ctx.check(_DIR.pick(&"undercroft", true, false, false)
			== _DIR.Variation.ARCHIVIST, "director: boss fight = ARCHIVIST")
	# The Echo outruns the base.
	ctx.check(_DIR.pick(&"the_mine", false, false, true)
			== _DIR.Variation.ECHO, "director: echo active = ECHO")
	# But the boss fight outruns the Echo.
	ctx.check(_DIR.pick(&"undercroft", true, false, true)
			== _DIR.Variation.ARCHIVIST, "director: boss > echo")
	# The world remembers (post-boss, outside the Undercroft).
	ctx.check(_DIR.pick(&"ancient_gate", false, true, false)
			== _DIR.Variation.MEMORY, "director: post-boss = MEMORY")
	ctx.check(_DIR.pick(&"camp", false, true, true)
			== _DIR.Variation.ECHO, "director: echo > memory")
	# The final scene: the boss is gone, the player is in the
	# Undercroft — the Ending, above everything.
	ctx.check(_DIR.pick(&"undercroft", true, true, true)
			== _DIR.Variation.ENDING, "director: undercroft+gone = ENDING")
	ctx.check(_DIR.pick(&"undercroft", false, true, true)
			== _DIR.Variation.ENDING, "director: ENDING outruns the echo")

	# The stream-name map and the switch guard.
	ctx.check(_DIR.stream_name(_DIR.Variation.NORMAL) == &"normal",
			"director: the name map")
	ctx.check(_DIR.needs_switch(0, 1) and not _DIR.needs_switch(1, 1),
			"director: the switch guard")
	ctx.check(absf(_DIR.CROSSFADE_SECONDS - 1.5) < 0.001,
			"director: the crossfade constant")
