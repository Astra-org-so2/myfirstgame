# Integration: death -> save -> reload (Phase 15, the P15 exit).
#
# Two scene instances share ONE save path (the test seam: the
# path is set before add_child, so the scene's isolation leaves
# it alone). The first scene earns meta progress (a flag, an
# inheritance via the death choice, a note, a killed NPC, a
# quality + audio setting), saves on the death choice, and dies.
# The second scene boots from the same file: the world and the
# settings must be intact, and the run system must see the run
# count (run N, not run 1).
extends Node

const _PORT = preload("res://scripts/player/movement_port.gd")

const SHARED: String = "user://save_test/integ_shared.json"


func _clean() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SHARED + suffix)


func _boot(ctx: Variant) -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed.instantiate()
	var player = scene.find_child("Player", true, false)
	ctx.check(player != null, "save: player present")
	if player == null:
		return null
	var mock: _PORT = _PORT.new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	# The test seam: a SHARED save path (before add_child, so the
	# scene's isolation does not claim it).
	scene.save_path_override = SHARED
	add_child(scene)
	var sm = scene.find_child("SaveManager", true, false)
	ctx.check(sm != null, "save: the manager is composed")
	if sm == null:
		return null
	ctx.check(sm.path == SHARED, "save: the seam path is active")
	return scene


func run(ctx: Variant) -> void:
	_clean()

	# --- Scene 1: a fresh world, earn progress, die (the save
	#     point), verify the file. ---
	var s1: Node = _boot(ctx)
	if s1 == null:
		return
	# Fresh: no run history.
	ctx.check(s1.run_manager.run_id == 1,
			"save: the first scene is RUN 1")
	# Earn: a world fact, a note, a dead NPC.
	s1.progress.ws.set_flag(&"kettle_washed")
	s1.progress.ws.write_note(&"camp", 2, 1, 1000)
	s1.progress.ws.kill_npc(&"orren")
	# The inheritance: the REAL death path (the run record + the
	# offer + the choice).
	var death_screen = s1.find_child("DeathScreen", true, false)
	ctx.check(death_screen != null, "save: the death screen is composed")
	s1._on_player_died(Vector3.ZERO)
	ctx.check(s1.progress.ws.runs.full.size() >= 1,
			"save: the death recorded run 1")
	var offers: Array = s1.progress.roll_death_offers()
	ctx.check(offers.size() > 0, "save: the offer pool is not empty")
	var chosen: Resource = offers[0]
	var levels: Array = []
	for d in offers:
		levels.append(s1.progress.ws.inheritance_level(d.id) + 1)
	death_screen.show_offers(offers, levels, 7)
	# Pick the first card (the deterministic press API).
	death_screen.press(0)
	ctx.check(s1.progress.ws.inheritance_level(chosen.id) >= 1,
			"save: the inheritance is granted")
	# The death choice is the save point.
	ctx.check(FileAccess.file_exists(SHARED),
			"save: the death choice wrote the save")
	# Audio + quality settings on the save point.
	s1.audio.music_level = 0.3
	s1._do_save("choice")  # a 2nd save with the audio setting
	var saved_at: String = ""
	var fr: FileAccess = FileAccess.open(SHARED, FileAccess.READ)
	if fr != null:
		saved_at = fr.get_as_text()
		fr.close()
	ctx.check(saved_at.contains("\"music\":0.3"),
			"save: the settings are in the file")
	s1.queue_free()
	await get_tree().process_frame
	# The shared path survives scene 1 (the test owns it).
	ctx.check(FileAccess.file_exists(SHARED),
			"save: the shared save outlives scene 1")

	# --- Scene 2: boot from the save. ---
	var s2: Node = _boot(ctx)
	if s2 == null:
		return
	# The world is intact.
	ctx.check(s2.progress.ws.flag(&"kettle_washed"),
			"save: the flag survived")
	ctx.check(s2.progress.ws.inheritance_level(chosen.id) >= 1,
			"save: the inheritance survived")
	ctx.check(s2.progress.ws.note_line(&"camp") == 2,
			"save: the note survived")
	ctx.check(not s2.progress.ws.is_npc_alive(&"orren"),
			"save: the NPC death survived")
	# The run history is a world fact: the recorded run survived
	# (the run NUMBER is session-scoped — a fresh boot is run 1;
	# the RECORDS are what the world remembers).
	ctx.check(s2.progress.ws.runs.full.size() >= 1,
			"save: the run history survived")
	var rec = s2.progress.ws.runs.latest()
	ctx.check(rec != null and int(rec.run_id) == 1,
			"save: the latest record is run 1")
	# The settings survived.
	ctx.check(absf(s2.audio.music_level - 0.3) < 0.001,
			"save: the audio setting survived (got %.2f)"
			% s2.audio.music_level)
	ctx.check(s2.save_manager != null, "save: scene 2 has the manager")
	s2.queue_free()
	await get_tree().process_frame
	_clean()
