# Unit: AudioManager — buses, crossfade, ambient, stinger, settings
# (Phase 14). Headless: playback is a no-op in the rig, but the bus
# state, the fade math, and the stream wiring are real.
extends Node

const _AM = preload("res://scripts/audio/audio_manager.gd")
const _DIR = preload("res://scripts/audio/music_director.gd")


func run(ctx: Variant) -> void:
	var am: _AM = _AM.new()
	am.name = "AMTest"
	add_child(am)
	await get_tree().process_frame

	# The buses exist and send to Master.
	for bus in ["Music", "SFX", "Ambient"]:
		var i: int = AudioServer.get_bus_index(bus)
		ctx.check(i >= 0, "audio mgr: bus %s exists" % bus)
		ctx.check(AudioServer.get_bus_send(i) == "Master",
				"audio mgr: %s sends to Master" % bus)

	# The first variation starts without a fade.
	am.set_variation(_DIR.Variation.NORMAL)
	ctx.check(am.current_variation() == _DIR.Variation.NORMAL,
			"audio mgr: first set lands")
	ctx.check(am._active_music().playing, "audio mgr: the music plays")
	# Re-setting the same variation is a no-op (no re-trigger).
	var vol0: float = am._active_music().volume_db
	am.set_variation(_DIR.Variation.NORMAL)
	ctx.check(am._current_variation == _DIR.Variation.NORMAL,
			"audio mgr: same variation is free")

	# A switch crossfades: the old voice fades out over the time.
	am.set_variation(_DIR.Variation.MEMORY)
	var from: AudioStreamPlayer = am._fade_from
	var to: AudioStreamPlayer = am._fade_to
	ctx.check(from != null and to != null, "audio mgr: the fade starts")
	for i in 3:
		am._process(0.5)
		await get_tree().process_frame
	var vk: float = to.volume_db
	for i in 10:
		am._process(0.5)
		await get_tree().process_frame
	ctx.check(am.current_variation() == _DIR.Variation.MEMORY,
			"audio mgr: the fade lands")
	ctx.check(to.playing and not from.playing,
			"audio mgr: the old voice stops")
	ctx.check(absf(to.volume_db) < 1.0,
			"audio mgr: the new voice is at unity (got %.2f)" % to.volume_db)

	# update_music: the scene facts drive the variation (the direct
	# MEMORY above is a fade state, not a world fact — the facts win).
	am.update_music(&"camp", false, false, false)
	ctx.check(am.current_variation() == _DIR.Variation.NORMAL,
			"audio mgr: the world facts drive the music")
	am.update_music(&"undercroft", true, false, false)
	ctx.check(am.current_variation() == _DIR.Variation.ARCHIVIST,
			"audio mgr: the boss fight switches to ARCHIVIST")
	am.update_music(&"undercroft", false, true, true)
	ctx.check(am.current_variation() == _DIR.Variation.ENDING,
			"audio mgr: post-boss undercroft = ENDING")

	# The ambient bed.
	am.set_zone(&"camp")
	ctx.check(am.current_zone() == &"camp", "audio mgr: zone set")
	ctx.check(am._ambient.playing, "audio mgr: the bed plays")
	var bed1: AudioStreamWAV = am._ambient.stream
	am.set_zone(&"the_mine")
	ctx.check(am._ambient.stream != bed1, "audio mgr: the bed swaps")

	# The stinger: one-shot.
	ctx.check(not am.is_stinger_playing(), "audio mgr: stinger idle")
	am.play_stinger()
	ctx.check(am.is_stinger_playing(), "audio mgr: the stinger plays")
	am._stinger.stop()

	# The settings: levels land on the buses as dB.
	am.master = 0.5
	am.apply_settings()
	var midx: int = AudioServer.get_bus_index("Music")
	var mdb: float = AudioServer.get_bus_volume_db(midx)
	# 0 dB default + 20log10(0.5) = -6.02
	ctx.check(absf(mdb + 6.02) < 0.1,
			"audio mgr: master 0.5 -> -6 dB (got %.2f)" % mdb)
	am.music_level = 0.5
	am.apply_settings()
	mdb = AudioServer.get_bus_volume_db(midx)
	ctx.check(absf(mdb + 12.04) < 0.1,
			"audio mgr: music 0.5 under master 0.5 -> -12 dB (got %.2f)" % mdb)
	am.muted = true
	am.apply_settings()
	mdb = AudioServer.get_bus_volume_db(midx)
	ctx.check(mdb < -60.0, "audio mgr: mute -> the floor (got %.2f)" % mdb)
	am.muted = false
	am.apply_settings()

	# The settings round-trip (what P15 will save).
	var d: Dictionary = am.get_settings()
	d["music"] = 0.3
	d["muted"] = true
	am.settings_from_dict(d)
	ctx.check(absf(am.music_level - 0.3) < 0.001 and am.muted,
			"audio mgr: settings round-trip")
	am.muted = false
	am.apply_settings()

	# level_to_db edges.
	ctx.check(_AM.level_to_db(0.0) < -60.0, "audio mgr: 0 -> the floor")
	ctx.check(absf(_AM.level_to_db(1.0)) < 0.01, "audio mgr: 1 -> 0 dB")

	am.queue_free()
	await get_tree().process_frame
