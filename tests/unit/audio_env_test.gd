# audio_env_test — the headless rig's audio contract (probe).
#
# Phase 14 builds on what the wasm rig really supports for audio
# (AudioServer buses, AudioStreamPlayer routing) — the same
# "document the limits" pattern as ADR-032 #9 for rendering.
extends Node

const _LIB = preload("res://scripts/audio/sfx_library.gd")


func run(ctx: Variant) -> void:
	# Master bus.
	ctx.check(AudioServer.get_bus_index("Master") >= 0,
			"audio: Master bus exists")
	ctx.check(AudioServer.get_bus_count() >= 1,
			"audio: bus count >= 1 (got %d)" % AudioServer.get_bus_count())

	# Bus creation (add_bus appends after the last when from >= count).
	var before: int = AudioServer.get_bus_count()
	AudioServer.add_bus(before)
	var after: int = AudioServer.get_bus_count()
	ctx.check(after == before + 1,
			"audio: add_bus grows the count (%d -> %d)" % [before, after])
	var idx: int = before
	AudioServer.set_bus_name(idx, "__probe_bus__")
	ctx.check(AudioServer.get_bus_index("__probe_bus__") == idx,
			"audio: the new bus is named + findable (idx %d)" % idx)

	# Bus volume/mute round-trip.
	AudioServer.set_bus_volume_db(idx, -10.0)
	var v: float = AudioServer.get_bus_volume_db(idx)
	ctx.check(absf(v + 10.0) < 0.5,
			"audio: bus volume round-trip (got %.2f)" % v)
	AudioServer.set_bus_mute(idx, true)
	ctx.check(AudioServer.is_bus_mute(idx),
			"audio: bus mute round-trip")
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_send(idx, "Master")
	var snd: StringName = AudioServer.get_bus_send(idx)
	ctx.check(snd == "Master",
			"audio: bus send set+read (got '%s')" % str(snd))

	# Player routing + playback.
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = "ProbePlayer"
	add_child(p)
	p.set_bus("Master")
	ctx.check(p.bus == "Master", "audio: player bus readable")
	p.stream = _LIB.generate_hit()
	p.play()
	await get_tree().process_frame
	ctx.check(p.playing, "audio: the player plays (headless)")
	p.stop()
	p.queue_free()
	await get_tree().process_frame
	# The probe bus stays (no remove_bus by name in Godot 4) — it
	# sends to Master at -inf? No: leave it, it is silent (no
	# players). Documented here and in ADR-033.
	AudioServer.set_bus_volume_db(idx, -60.0)
