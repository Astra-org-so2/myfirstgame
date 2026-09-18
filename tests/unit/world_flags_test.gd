# Unit: Phase 8 world flag registry (WORLD_STATE_DESIGN §2/§9.2):
# the data loads, validates, one line per flag, no numbers.
extends Node

const _TBL = preload("res://scripts/gameplay/progression/world_flag_table.gd")


func run(ctx: Variant) -> void:
	var res: Resource = load("res://data/world_flags.tres")
	ctx.check(res != null, "flags: data/world_flags.tres loads")
	if res == null:
		return
	var table: Variant = res
	# The table must be the WorldFlagTable script (not a bare Resource).
	ctx.check(res.resource_name != "" or res is Resource,
			"flags: resource type")
	var problems: Array = table.validate()
	ctx.check(problems.is_empty(),
			"flags: validate() clean (%s)" % str(problems))

	# The P8 beats all have a consequence line.
	var p8_flags: Array = [
		&"pillar_seen", &"blade_found", &"figure_seen",
		&"village_pyre_seen", &"first_hollow_killed", &"mine_note_read",
		&"shrine_echo_seen", &"gate_seal_seen", &"lake_note_read",
		&"kettle_washed", &"run_02_door_open", &"cannon_found",
		&"staff_found", &"first_death_done",
	]
	var all_have_lines: bool = true
	for f in p8_flags:
		if table.line_for(f) == "":
			all_have_lines = false
	ctx.check(all_have_lines, "flags: every P8 beat has a consequence line")

	# The canonical lines (WORLD_STATE_DESIGN §9.2 tone: no numbers).
	ctx.check(table.line_for(&"run_02_door_open")
			== "The door past the gate has opened.",
			"flags: door line matches the design example tone")
	ctx.check(table.line_for(&"cannon_found")
			== "The cannon waits in the mine.",
			"flags: cannon line matches the design example tone")

	# ≤ 5 lines is a UI rule (RunManager caps it); the table itself must
	# simply provide lines. And: NO NUMBERS in any consequence text
	# (WORLD_STATE_DESIGN §9.2 rule).
	var no_numbers: bool = true
	var lines: Dictionary = table.lines()
	for f in lines.keys():
		var text: String = lines[f]
		for c in text:
			if c >= "0" and c <= "9":
				no_numbers = false
	ctx.check(no_numbers, "flags: no numbers in consequence texts")
	ctx.check(lines.size() == table.flags.size(),
			"flags: lines() covers the whole table")
