# Integration: the performance audit (Phase 16, TEST_PLAN §7).
extends Node

const _PORT = preload("res://scripts/player/movement_port.gd")
const _BENCH = preload("res://scripts/dev/perf_benchmark.gd")

var _DT: float = 1.0 / 60.0


func _boot(ctx: Variant) -> Node:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var scene: Node = packed.instantiate()
	var player = scene.find_child("Player", true, false)
	if player == null:
		ctx.check(false, "perf: player present")
		return null
	var mock: _PORT = _PORT.new(null,
			player.data.gravity, player.data.max_fall_speed)
	player.set_port(mock)
	add_child(scene)
	return scene


func _frame(scene: Node) -> void:
	var d: float = scene.hitstop.update(_DT)
	scene.player._physics_process(d)
	if d > 0.0:
		scene.director.update(d)
	scene.director.record_player_position(
			scene.player.get_port().get_position())


func run(ctx: Variant) -> void:
	# --- Scenario 1: the camp (idle hub) ---
	var camp: Node = _boot(ctx)
	if camp == null:
		return
	var c1: Dictionary = _BENCH._count(camp)
	ctx.check(true, "perf camp: nodes=%d bodies=%d fx=%d lights=%d"
			% [c1["nodes"], c1["bodies"], c1["fx"], c1["lights"]])
	ctx.check(int(c1["nodes"]) <= 2000,
			"perf camp: nodes within §12 (got %d)" % int(c1["nodes"]))
	ctx.check(int(c1["bodies"]) <= 40,
			"perf camp: bodies within §12 (got %d)" % int(c1["bodies"]))
	ctx.check(int(c1["fx"]) <= 200,
			"perf camp: fx within §12 (got %d)" % int(c1["fx"]))
	ctx.check(int(c1["lights"]) <= camp.quality.light_budget(),
			"perf camp: lights within the tier (got %d)"
			% int(c1["lights"]))
	# CPU per frame: the gameplay chain (player + director), 60
	# synchronous frames (the wall time is the device's job).
	var costs: Array = []
	for i in 60:
		var t0: int = Time.get_ticks_usec()
		_frame(camp)
		var t1: int = Time.get_ticks_usec()
		costs.append(float(t1 - t0) / 1000.0)
	costs.sort()
	ctx.check(true, "perf camp: frame CPU p50=%.2f p95=%.2f ms"
			% [costs[30], costs[57]])
	ctx.check(float(costs[57]) < 4.0,
			"perf camp: the gameplay chain is under the AI budget "
			+ "(p95 %.2f ms, wasm reference)" % float(costs[57]))
	camp.queue_free()
	await get_tree().process_frame

	# --- Scenario 2: a generated level with the spawn table ---
	var lvl: Node = _boot(ctx)
	if lvl == null:
		return
	lvl._enter_level(&"the_mine")
	await get_tree().process_frame
	for i in 600:
		_frame(lvl)
		await get_tree().process_frame
		if lvl.director.get_alive_enemies().size() >= 4:
			if i > 30:
				break
	var alive: int = lvl.director.get_alive_enemies().size()
	var c2: Dictionary = _BENCH._count(lvl)
	ctx.check(true, "perf mine: enemies=%d nodes=%d bodies=%d fx=%d lights=%d"
			% [alive, c2["nodes"], c2["bodies"], c2["fx"], c2["lights"]])
	ctx.check(alive >= 2,
			"perf mine: the spawn table is alive (got %d)" % alive)
	ctx.check(int(c2["nodes"]) <= 2000,
			"perf mine: nodes within §12 (got %d)" % int(c2["nodes"]))
	ctx.check(int(c2["bodies"]) <= 40,
			"perf mine: bodies within §12 (got %d)" % int(c2["bodies"]))
	ctx.check(int(c2["lights"]) <= lvl.quality.light_budget(),
			"perf mine: lights within the tier (got %d)"
			% int(c2["lights"]))
	var costs2: Array = []
	for i in 60:
		var u0: int = Time.get_ticks_usec()
		_frame(lvl)
		var u1: int = Time.get_ticks_usec()
		costs2.append(float(u1 - u0) / 1000.0)
	costs2.sort()
	ctx.check(true, "perf mine: frame CPU p50=%.2f p95=%.2f ms"
			% [costs2[30], costs2[57]])
	ctx.check(float(costs2[57]) < 4.0,
			"perf mine: the gameplay chain is under the AI budget "
			+ "(p95 %.2f ms, wasm reference)" % float(costs2[57]))
	lvl.queue_free()
	await get_tree().process_frame

	# --- Scenario 3: the boss arena (the heaviest composition) ---
	var boss: Node = _boot(ctx)
	if boss == null:
		return
	boss._enter_level(&"undercroft")
	await get_tree().process_frame
	for i in 120:
		_frame(boss)
		await get_tree().process_frame
	ctx.check(boss.boss != null, "perf arena: THE FIRST is present")
	var c3: Dictionary = _BENCH._count(boss)
	ctx.check(true, "perf arena: nodes=%d bodies=%d fx=%d lights=%d"
			% [c3["nodes"], c3["bodies"], c3["fx"], c3["lights"]])
	ctx.check(int(c3["nodes"]) <= 2000,
			"perf arena: nodes within §12 (got %d)" % int(c3["nodes"]))
	ctx.check(int(c3["bodies"]) <= 40,
			"perf arena: bodies within §12 (got %d)" % int(c3["bodies"]))
	ctx.check(int(c3["lights"]) <= boss.quality.light_budget(),
			"perf arena: lights within the tier (got %d)"
			% int(c3["lights"]))
	# The boss is the heaviest AI tick: it joins the measured chain.
	var costs3: Array = []
	for i in 60:
		var v0: int = Time.get_ticks_usec()
		var d3: float = boss.hitstop.update(_DT)
		boss.player._physics_process(d3)
		if d3 > 0.0:
			boss.director.update(d3)
			boss.boss._physics_process(d3)
		boss.director.record_player_position(
				boss.player.get_port().get_position())
		var v1: int = Time.get_ticks_usec()
		costs3.append(float(v1 - v0) / 1000.0)
	costs3.sort()
	ctx.check(true, ("perf arena: frame CPU (with boss) p50=%.2f "
			+ "p95=%.2f ms") % [costs3[30], costs3[57]])
	ctx.check(float(costs3[57]) < 4.0,
			"perf arena: the boss tick is under the AI budget "
			+ "(p95 %.2f ms, wasm reference)" % float(costs3[57]))
	boss.queue_free()
	await get_tree().process_frame

	# --- Save write time (debug measurement, §12: <= 50 ms) ---
	var s4: Node = _boot(ctx)
	if s4 == null:
		return
	var w: Dictionary = s4.progress.ws.to_dict()
	var st: Dictionary = {}
	if s4.audio != null:
		st["audio"] = s4.audio.get_settings()
	var s0: int = Time.get_ticks_usec()
	var ok: bool = s4.save_manager.save(w, st)
	var s1: int = Time.get_ticks_usec()
	ctx.check(ok, "perf save: write succeeds")
	var took: int = (s1 - s0) / 1000
	ctx.check(true, "perf save: write took %d ms" % took)
	ctx.check(took < 50,
			"perf save: within §12 (got %d ms, wasm reference)" % took)
	s4.queue_free()
	await get_tree().process_frame
