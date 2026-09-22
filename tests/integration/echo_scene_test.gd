# Integration: Phase 9 Ghost/Echo (ROADMAP exit: «the ghost runs the
# hub path, reads as the past me; #1 (B4) is reproducible»).
#
# One scene, the full loop: RUN 1 (camp path: pillar, swings, the
# first Hollow, the death — echo-free per the ADR-014 budget) ->
# death/choice -> RUN 02: the Passive Echo replays the RUN 1 camp
# path (replaying, fading at the end), the Combat Echo (the remnant,
# B4) spawns «where the player was» (the last RUN 1 camp point),
# speaks the canonical two lines and fades out, the ECHO_TRIGGER is
# recorded, the old death marker stands at the RUN 1 death point,
# and the budget is consumed (one combat echo per run).
extends Node

const _MAIN = preload("res://scripts/world/main_scene.gd")
const _PORT = preload("res://scripts/player/movement_port.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")

const DT: float = 1.0 / 60.0

var _main: _MAIN
var _player: Node
var _mock: _PORT
var _ticks: Array = []


func run(ctx: Variant) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	ctx.check(packed != null, "echo: main scene loads")
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	_main = scene
	_player = scene.find_child("Player", true, false)
	_mock = _PORT.new(null, _player.data.gravity,
			_player.data.max_fall_speed)
	_player.set_port(_mock)
	add_child(scene)
	_main.set_physics_process(false)  # the test owns the clock
	_test_run1_echo_free(ctx)
	_test_death(ctx)
	_test_run2_echoes(ctx)
	_main.queue_free()


func _tick(n: int) -> void:
	for i in n:
		_main._physics_process(DT)
		var zw: Node = _main.zone_world
		if zw != null and is_instance_valid(zw):
			zw._physics_process(DT)
		var fr: Node = _main.first_run
		if fr != null and is_instance_valid(fr):
			fr._physics_process(DT)
		for t in _ticks:
			if is_instance_valid(t):
				t._physics_process(DT)


func _walk(pos: Vector3, n: int) -> void:
	_mock.set_position(Vector3(pos.x, 0.0, pos.z))
	_tick(n)


# --- RUN 1: the camp path, echo-free (ADR-014: RUN 1 = 0) ----------------

func _test_run1_echo_free(ctx: Variant) -> void:
	var g: Node = _main.ghost_director
	ctx.check(g != null, "echo: the GhostDirector is composed")
	ctx.check(g.budget_state.passive_remaining() == 0
			and g.budget_state.combat_remaining() == 0,
			"echo: RUN 1 has an empty budget")
	# The camp has the 4 non-echo enemies (no remnant).
	var remnant: Node = _enemy(&"remnant_mirror")
	ctx.check(remnant == null, "echo: no remnant in RUN 1")
	ctx.check(_find("PassiveEcho") == null,
			"echo: no passive ghost in RUN 1")
	# The RUN 1 camp path (the ghost's future replay): spawn ->
	# pillar -> swings -> the first Hollow -> stay (the death point).
	var layout: Variant = _main.find_child("CampWorld", true, false).layout
	var ia_pillar: Node = _find("IA_Pillar")
	_ticks = [ia_pillar]
	_walk(layout.pillar_pos, 10)
	_mock.set_position(Vector3(layout.pillar_pos.x, 0.0,
			layout.pillar_pos.z + 0.8))
	_tick(2)
	Input.action_press("interact")
	_tick(3)
	Input.action_release("interact")
	_tick(5)
	ctx.check(_main.progress.ws.flag(&"pillar_seen"),
			"echo: RUN 1 the pillar beat")
	for s in 2:
		Input.action_press("attack")
		_tick(45)
		Input.action_release("attack")
		_tick(5)
	var hollow: Node = _enemy(&"hollow_base")
	ctx.check(hollow != null, "echo: a Hollow is alive in the camp")
	if hollow != null:
		var req: _DREQ = _DREQ.new()
		req.source = _player
		req.target = hollow
		req.amount = 99.0
		req.type = _DREQ.Type.MELEE
		req.position = hollow.global_position
		req.knockback_direction = Vector3(1.0, 0.0, 0.0)
		_main.resolver.resolve(req)
		var waited: int = 0
		while waited < 120 and not _main.progress.ws.flag(
				&"first_hollow_killed"):
			_tick(1)
			waited += 1
		ctx.check(_main.progress.ws.flag(&"first_hollow_killed"),
				"echo: RUN 1 the first Hollow falls")
		# The death point: where the player stands when they die.
		_mock.set_position(Vector3(layout.pillar_pos.x, 0.0,
				layout.pillar_pos.z))
		_tick(10)
	# The RUN 1 record is the ghost's future source.
	var rec: Variant = _main.run_manager.current_record
	ctx.check(rec != null and rec.events.size() >= 4,
			"echo: RUN 1 recorded a path (>=4 events, got %d)"
					% rec.events.size())


# --- the death (A19) -> RUN 02 --------------------------------------------

func _test_death(ctx: Variant) -> void:
	var killer: Node = _enemy(&"watcher_base")
	var enemies: Array = _main.director.get_alive_enemies()
	if killer == null and enemies.size() > 0:
		killer = enemies[0]
	ctx.check(killer != null, "echo: a camp enemy ends the run")
	var req: _DREQ = _DREQ.new()
	req.source = killer
	req.target = _player
	req.amount = 500.0
	req.type = _DREQ.Type.MELEE
	req.position = _mock.get_position()
	req.knockback_direction = Vector3(1.0, 0.0, 0.0)
	_main.resolver.resolve(req)
	_tick(2)
	ctx.check(_player.is_dead(), "echo: the player died")
	var screen: Node = _main.get_node_or_null("DeathScreen")
	ctx.check(screen != null, "echo: the death screen offers 1 of 3")
	screen.press(0)
	_tick(3)
	ctx.check(not _player.is_dead() and _main.zone_world.is_camp(),
			"echo: the respawn is at the camp (RUN 02)")
	ctx.check(_main.run_manager.run_id == 2,
			"echo: the respawn began RUN 02")


# --- RUN 02: the Passive replay + the B4 remnant + the marker --------------

func _test_run2_echoes(ctx: Variant) -> void:
	var g: Node = _main.ghost_director
	ctx.check(g.budget_state.passive_remaining() >= 0
			and g.has_method("has_passive"), "echo: the director is armed")
	ctx.check(g.has_passive(), "echo: RUN 02 the passive replay is armed")
	# The marker of the RUN 1 death (the camp is stable: it remaps).
	var marker: Node = _find("RunMarker")
	ctx.check(marker != null, "echo: RUN 02 the death marker stands")
	if marker != null:
		var rec: Variant = _main.progress.ws.runs.get_run(1)
		ctx.check(rec != null
				and marker.global_position.distance_to(rec.last_death_pos)
				< 0.1,
				"echo: the marker is at the RUN 1 death point")
	# B4: the remnant (the combat echo) — «where the player was».
	var remnant: Node = _enemy(&"remnant_mirror")
	ctx.check(remnant != null, "echo: RUN 02 the remnant is present")
	if remnant != null:
		var rec1: Variant = _main.progress.ws.runs.get_run(1)
		var last_camp: Vector3 = Vector3.ZERO
		for ev in rec1.events:
			var e: _EV = ev
			var p: Vector3 = Vector3(e.x / 100.0, 0.0, e.z / 100.0)
			if p.length() <= 26.0:
				last_camp = p
		ctx.check(remnant.global_position.distance_to(last_camp) < 0.1,
				"echo: the remnant is on the player's RUN 1 path")
	# The Passive Echo body: in the camp, replaying (it moves).
	var ghost: Node = _find("PassiveEcho")
	ctx.check(ghost != null, "echo: RUN 02 the passive ghost is in the camp")
	if ghost != null:
		var p0: Vector3 = ghost.global_position
		_tick(40)
		var p1: Vector3 = ghost.global_position
		ctx.check(not p0.is_equal_approx(p1),
				"echo: the ghost replays (its position advances)")
	# B4: walk to the remnant — it speaks the canonical two lines,
	# then fades out (a dissolve, not a hard despawn).
	remnant = _enemy(&"remnant_mirror")
	if remnant == null:
		ctx.check(false, "echo: the remnant left before the encounter")
		return
	_walk(remnant.global_position + Vector3(2.0, 0.0, 0.5), 5)
	var line1: Array = []
	var line2: Array = []
	var seen: Array = []
	var budget: int = 0
	while budget < 900:
		_tick(1)
		budget += 1
		var e: Node = _enemy(&"remnant_mirror")
		if e == null:
			break  # it faded out and left
		var txt: String = e.speech_text()
		if e.is_speaking() and txt != "" and not seen.has(txt):
			seen.append(txt)
		if seen.size() >= 2 and e.state() == _ST.State.LEAVE:
			break  # the fade is running; the despawn comes next
	ctx.check(seen.size() == 2,
			"echo: B4 the full sequence was spoken (%s)" % str(seen))
	if seen.size() == 2:
		ctx.check(seen[0] == "You're early.",
				"echo: B4 the first line is canonical: %s" % seen[0])
		ctx.check(seen[1] == "You usually take longer.",
				"echo: B4 the second line follows: %s" % seen[1])
	ctx.check(_enemy(&"remnant_mirror") == null,
			"echo: B4 the remnant faded out and left")
	ctx.check(g.budget_state.combat_remaining() == 0,
			"echo: the combat slot is consumed (1 per run)")
	# The encounter is in the run record (ECHO_TRIGGER, combat = 1).
	var rec2: Variant = _main.run_manager.current_record
	var trig: bool = false
	var trig_data: int = -1
	for ev in rec2.events:
		var e2: _EV = ev
		if e2.type == _EV.Type.ECHO_TRIGGER:
			trig = true
			trig_data = e2.data
	ctx.check(trig, "echo: ECHO_TRIGGER is recorded in RUN 02")
	ctx.check(trig_data == 1, "echo: the trigger is the combat echo")
	# The passive replay ends -> the ghost fades and finishes.
	ghost = _find("PassiveEcho")
	if ghost == null:
		ctx.check(false, "echo: the ghost faded before the finish check")
		return
	var done: int = 0
	var finished: bool = false
	while done < 1500:
		if not is_instance_valid(ghost):
			finished = true
			break
		if ghost.is_done():
			finished = true
			break
		_tick(1)
		done += 1
	ctx.check(finished,
			"echo: the replay ends in a dissolve (fade-out)")


# --- helpers ----------------------------------------------------------------

func _enemy(id: StringName) -> Node:
	for e in _main.director.get_alive_enemies():
		if e.data().id == id:
			return e
	return null


func _find(name: String) -> Node:
	return _main.find_child(name, true, false)
