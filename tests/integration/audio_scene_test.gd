# Integration: the audio in the main scene (Phase 14, GDD §7).
#
# The composed stack (AudioManager + the SfxBus pool + the settings
# panel) in the real main scene: the buses exist and route to
# Master, the pool rides the SFX bus, the zone bed + the music
# variation follow the world, and the settings (the P14 exit)
# change the buses live.
extends Node

const _PORT = preload("res://scripts/player/movement_port.gd")
const _DIR = preload("res://scripts/audio/music_director.gd")


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "audio: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	var player = scene.find_child("Player", true, false)
	ctx.check(player != null, "audio: player present")
	if player == null:
		return
	var mock: _PORT = _PORT.new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	add_child(scene)

	# --- The buses (created by the AudioManager, first in the tree) ---
	for bus in ["Music", "SFX", "Ambient"]:
		ctx.check(AudioServer.get_bus_index(bus) >= 0,
				"audio: the %s bus exists" % bus)
		ctx.check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus))
				== "Master", "audio: %s sends to Master" % bus)

	var audio = scene.find_child("AudioManager", true, false)
	ctx.check(audio != null, "audio: the manager is composed")
	var sfx = scene.find_child("SfxBus", true, false)
	ctx.check(sfx != null, "audio: the pool is composed")
	if audio == null or sfx == null:
		scene.queue_free()
		return

	# --- The pool rides the SFX bus (the manager created it first) ---
	for p in sfx._players:
		ctx.check(p.bus == "SFX", "audio: the pool is on the SFX bus")

	# --- The camp: the zone bed + the NORMAL variation ---
	ctx.check(audio.current_zone() == &"camp",
			"audio: the camp bed is on")
	ctx.check(audio._ambient.playing, "audio: the bed plays")
	ctx.check(audio.current_variation() == _DIR.Variation.NORMAL,
			"audio: the camp plays NORMAL")
	var bed1: AudioStreamWAV = audio._ambient.stream

	# --- The zone switch swaps the bed ---
	scene._enter_level(&"the_mine")
	await get_tree().process_frame
	ctx.check(audio.current_zone() == &"the_mine",
			"audio: the mine bed is on")
	ctx.check(audio._ambient.stream != bed1, "audio: the bed swapped")

	# --- The music follows the facts (the scene's _update_audio) ---
	audio.update_music(&"the_mine", false, false, false)
	ctx.check(audio.current_variation() == _DIR.Variation.NORMAL,
			"audio: the mine without facts = NORMAL")
	audio.update_music(&"the_mine", false, false, true)
	ctx.check(audio.current_variation() == _DIR.Variation.ECHO,
			"audio: the Echo fact switches to ECHO")
	audio.update_music(&"the_mine", false, false, false)
	ctx.check(audio.current_variation() == _DIR.Variation.NORMAL,
			"audio: the fact cleared switches back")

	# --- The SFX: the new world's-voice cues play ---
	for cue in ["door", "seal", "death", "note", "ui", "echo",
			"swing", "hit", "riposte", "hurt", "shot", "pickup"]:
		ctx.check(sfx.play(cue), "audio: the cue '%s' plays" % cue)
	ctx.check(not sfx.play(&"nope"), "audio: an unknown cue fails")

	# --- The stinger (one-shot, over the music) ---
	ctx.check(not audio.is_stinger_playing(), "audio: stinger idle")
	audio.play_stinger()
	ctx.check(audio.is_stinger_playing(), "audio: the stinger plays")

	# --- The settings (the P14 exit): live on the buses ---
	var panel = scene.find_child("SettingsPanel", true, false)
	ctx.check(panel != null, "audio: the settings panel is composed")
	panel.show_panel(audio)
	await get_tree().process_frame
	ctx.check(panel.visible, "audio: the panel shows")
	# Music 0.25 under master 1.0: 0 dB + 20log10(0.25) = -12.04.
	panel.set_slider(1, 0.25)
	var midx: int = AudioServer.get_bus_index("Music")
	var mdb: float = AudioServer.get_bus_volume_db(midx)
	ctx.check(absf(mdb + 12.04) < 0.15,
			"audio: the music slider lands on the bus (got %.2f)" % mdb)
	# Mute: every bus at the floor.
	panel.toggle_mute()
	for bus in ["Music", "SFX", "Ambient"]:
		var db: float = AudioServer.get_bus_volume_db(
				AudioServer.get_bus_index(bus))
		ctx.check(db < -60.0, "audio: mute mutes %s (got %.1f)" % [bus, db])
	panel.toggle_mute()
	mdb = AudioServer.get_bus_volume_db(midx)
	ctx.check(absf(mdb + 12.04) < 0.15,
			"audio: unmute restores the slider (got %.2f)" % mdb)
	# The dict round-trip is what P15 will persist.
	var d: Dictionary = audio.get_settings()
	ctx.check(absf(float(d["music"]) - 0.25) < 0.001,
			"audio: the settings dict carries the slider")
	panel.close()
	await get_tree().process_frame
	ctx.check(not panel.visible, "audio: the panel closes")

	scene.queue_free()
	await get_tree().process_frame
