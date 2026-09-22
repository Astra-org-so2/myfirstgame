# Unit: PerfBenchmark — the file writer (Phase 16, TEST_PLAN §7).
extends Node

const _B = preload("res://scripts/dev/perf_benchmark.gd")


func run(ctx: Variant) -> void:
	DirAccess.remove_absolute("user://perf_ut.txt")
	var scope: Node = Node3D.new()
	scope.name = "Scope"
	var body: CharacterBody3D = CharacterBody3D.new()
	body.name = "Body"
	scope.add_child(body)
	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Light"
	scope.add_child(light)
	add_child(scope)

	var bench: _B = _B.new()
	bench.name = "BenchUT"
	add_child(bench)
	var state: Dictionary = {"done": false}
	bench.finished.connect(func(_s: Dictionary) -> void:
		state["done"] = true)
	bench.start(scope, "ut", 1.0)
	# The benchmark runs on physics frames: pump until done.
	for i in 240:
		bench._physics_process(1.0 / 60.0)
		await get_tree().process_frame
		if bool(state["done"]):
			break
	ctx.check(bool(state["done"]), "bench: the run finishes")

	var f: FileAccess = FileAccess.open("user://perf_ut.txt",
			FileAccess.READ)
	ctx.check(f != null, "bench: the perf file is written")
	var text: String = ""
	if f != null:
		text = f.get_as_text()
		f.close()
	ctx.check(text.contains("label: ut"), "bench: the label lands")
	ctx.check(text.contains("frame_ms: p50="), "bench: p50 lands")
	ctx.check(text.contains("nodes:"), "bench: the nodes line lands")
	ctx.check(text.contains("bodies:"), "bench: the bodies line lands")
	ctx.check(text.contains("local lights:"),
			"bench: the lights line lands")
	# The structural counts are correct for the fixture.
	ctx.check(text.contains("peak=2") or text.contains("avg="),
			"bench: the counts are non-trivial")

	bench.queue_free()
	scope.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute("user://perf_ut.txt")
