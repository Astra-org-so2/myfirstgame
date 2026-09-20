# BossController — THE FIRST in the scene (BOSS_DESIGN §3-4):
# visuals + steering + the attack delivery + the seal (the core) +
# the Remnant minion + the death sequence (K6 -> K7). The DECISIONS
# live in BossLogic / PatternMemory (pure, unit-tested) — this node
# is the bridge to the scene: DamageResolver, the player's swings,
# the world flags, the visuals.
#
# Scene contract (the main scene composes it, ADR-001/023):
#   setup(data, player, resolver, ws, loadout, arena_origin, seal_offset)
#   start_fight() — line #1, the door is sealed by the main scene.
#   signals: defeated(), stage_reveal(stage_id) — the main scene
#   lands the world flags (boss_defeated, the mystery stages).
class_name BossController
extends Node3D

const _DATA = preload("res://scripts/gameplay/boss/boss_data.gd")
const _LOGIC = preload("res://scripts/gameplay/boss/boss_logic.gd")
const _SENSE = preload("res://scripts/gameplay/boss/boss_sense.gd")
const _PM = preload("res://scripts/gameplay/boss/pattern_memory.gd")
const _ATK = preload("res://scripts/gameplay/enemies/attack_data.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _ECTRL = preload("res://scripts/gameplay/enemies/enemy_controller.gd")
const _EDATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _WDATA = preload("res://scripts/gameplay/combat/weapon_data.gd")
const _CV = preload("res://scripts/world/character_visual.gd")

# CHARACTER_BIBLE §8 (the 10 lines, the canonical order).
const LINE_ENTRY: String = "You came back. Good. This time I'll be quick."
const LINE_LEARNED: String = \
		"Again? I've had this swing a hundred times."
const LINE_PHASE2: String = ("She keeps us all. You think that's mercy? "
		+ "It's a cellar. And we are in it.")
const LINE_LEFT_BLADE: String = \
		"You left it. (soft) ...he left it too. One of you will."
const LINE_CORE: String = \
		"— (gasps) ...you felt that. It's real. That's the only part of me that's real."
const LINE_DEATH: String = \
		"You reached the end. You always do. ...don't make me proud of it."
const LINE_FINAL: String = "Tell her I said: let them go."
const LINE_TOOK_BLADE: String = \
		"...that was mine. I left it for you. I didn't know which you."

signal defeated()
signal stage_reveal(stage_id: StringName)

var data: _DATA = null
var logic: _LOGIC = null
var _pm: _PM = null
var _player: Node = null
var _resolver: Node = null
var _ws: Variant = null
var _loadout: Node = null
var _director: Node = null

var _target: _CT = null
var _seal_mats: Array = []
var _label: Label3D = null
var _body_mat: StandardMaterial3D = null
var textures: Variant = null  # the TextureBank (optional)
var _dissolve_left: float = -1.0
var _line_left: float = 0.0
var _learn_cd: float = 0.0
var _minion: Node = null
var _minion_faded: bool = false
var _blade_line_done: bool = false
var _left_blade_line_done: bool = false
var _core_line_done: bool = false
var _defeated: bool = false
var _fight_started: bool = false
var _prev_state: int = _LOGIC.State.IDLE
var _swing_connected: Node = null
var _arena: Vector3 = Vector3.ZERO  # the room origin (level space)
var _seal_pos: Vector3 = Vector3.ZERO  # level space
var _home: Vector2 = Vector2.ZERO  # room space


func setup(p_data: _DATA, p_player: Node, p_resolver: Node,
		p_ws: Variant, p_loadout: Node, p_director: Node,
		p_arena: Vector3, p_seal_offset: Vector3) -> void:
	data = p_data
	_player = p_player
	_resolver = p_resolver
	_ws = p_ws
	_loadout = p_loadout
	_director = p_director
	_arena = p_arena
	_seal_pos = p_arena + p_seal_offset
	_home = Vector2(_seal_pos.x, _seal_pos.z)
	logic = _LOGIC.new()
	logic.setup(p_data)
	_pm = _PM.new()
	_pm.setup(p_data.pattern_length, p_data.pattern_threshold,
			p_data.break_steps)
	_target = _CT.new(self, float(p_data.health))
	_target.combat_id = &"boss_the_first"
	_resolver.register(self, _target)
	_resolver.damage_applied.connect(_on_damage_applied)
	_build_visual()
	_build_seal()
	_track_player_swing()


func start_fight() -> void:
	if _fight_started:
		return
	_fight_started = true
	_say(LINE_ENTRY)


# The player took the FIRST BLADE (the main scene + the pickup
# report it): line #5 now; line #7 comes at the last stand (30%).
func blade_taken_changed(taken: bool) -> void:
	if taken and not _blade_line_done and _fight_started:
		_blade_line_done = true
		_say(LINE_TOOK_BLADE)
	logic.set_blade(taken)


func _say(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	_label.visible = true
	_line_left = 3.0


func _track_player_swing() -> void:
	if _loadout == null:
		return
	var c: Node = _loadout.current()
	if c == null or c == _swing_connected:
		return
	if _swing_connected != null and is_instance_valid(_swing_connected) \
			and _swing_connected.has_signal("swing_started") \
			and _swing_connected.is_connected(
					&"swing_started", _on_player_swing):
		_swing_connected.swing_started.disconnect(_on_player_swing)
	_swing_connected = c
	if c != null and c.has_signal("swing_started"):
		c.swing_started.connect(_on_player_swing)


func _on_weapon_changed(_id: StringName) -> void:
	_track_player_swing()


# --- The player's swing: pattern memory + the parry + the core --------

func _on_player_swing() -> void:
	if _defeated:
		return
	_track_player_swing()
	var c: Node = _swing_connected
	if c == null:
		return
	var wdata: Resource = c.get_data()
	if wdata == null:
		return
	var step: String = String(wdata.id)
	if wdata.type == _WDATA.Type.MELEE:
		step += ":" + str(c.get_logic().hit_index())
	var ev: int = _pm.record(step)
	match ev:
		_PM.Event.LEARNED:
			logic.enter_look()
			if _learn_cd <= 0.0:
				_say(LINE_LEARNED)
				_learn_cd = data.learn_line_cooldown
		_PM.Event.PARRY_TRIGGER:
			logic.enter_parry()
			# The swing that TRIGGERED the parry is already in flight
			# this frame — seal the target before the resolver sees
			# the hit (the per-tick sync keeps it for the window).
			_target.invulnerable = true
		_PM.Event.BROKEN:
			logic.apply_break_stun()
	# The parry window: the player swung inside it -> the counter.
	if logic.parry_active():
		if logic.parry_swing():
			_parry_counter()
	# The core: a melee swing that reaches the seal DURING the window.
	if logic.core_window_active() and wdata.type == _WDATA.Type.MELEE:
		var range: float = 0.0
		if wdata.hits.size() > 0:
			range = float(wdata.hits[0].range)
		var d: float = _player.get_body_position().distance_to(_seal_pos)
		if d <= range + 0.5 and logic.core_hit():
			var amount: int = data.core_damage_plain
			if String(wdata.id) == "weapon_first_blade":
				amount = data.core_damage
			_hit_boss_core(float(amount), wdata.id)


func _parry_counter() -> void:
	# His counter: melee range, the parry damage.
	var d: float = global_position.distance_to(_player.get_body_position())
	if d <= data.melee.range:
		_hit_player(float(data.parry_damage))
	_say("— (clash)")


func _hit_boss_core(amount: float, _weapon_id: StringName) -> void:
	var req: _DREQ = _DREQ.new()
	req.source = _player
	req.target = self
	req.amount = amount
	req.type = _DREQ.Type.MELEE
	req.position = _seal_pos
	req.knockback_direction = Vector3.ZERO
	_resolver.resolve(req)
	logic.set_hp(_target.hp)
	if not _core_line_done and _target.hp > 0.0:
		_core_line_done = true
		_say(LINE_CORE)


# --- The physics tick ---------------------------------------------------

func _physics_process(delta: float) -> void:
	_learn_cd = maxf(0.0, _learn_cd - delta)
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0 and _label != null:
			_label.visible = false
	if _player == null or not is_instance_valid(_player) \
			or _player.is_dead():
		return  # the death screen: no swings at a corpse

	var s: _SENSE = _SENSE.new()
	s.player_present = true
	s.player_pos = Vector2(_player.get_body_position().x,
			_player.get_body_position().z)
	var events: Array = logic.tick(delta, s, _home)

	# The dissolve (3 s, "scatters, does not fall" — §4.1).
	if _dissolve_left > 0.0:
		_dissolve_left -= delta
		var k: float = clampf(_dissolve_left / data.dissolve_time, 0.0, 1.0)
		_body_mat.albedo_color.a = k
	if _defeated:
		return
	# Parry = invulnerable for the window (the resolver blocks the
	# player's hits; the counter comes from the swing hook).
	_target.invulnerable = logic.parry_active()

	# Steering: he holds the melee band around the seal (the arena
	# is open — direct pursuit, one obstacle pushed around).
	if logic.state == _LOGIC.State.IDLE:
		_steer(delta, s.player_pos)

	# The state transitions (the controller owns the scene beats).
	# Member-based: set_hp / enter_parry / core_hit change the state
	# BETWEEN ticks — a tick-local prev would miss those beats.
	if logic.state != _prev_state:
		_on_state(_prev_state, logic.state)
		_prev_state = logic.state

	# The attacks.
	for e in events:
		if e == "attack_melee":
			_swing_at_player(data.melee)
		elif e == "attack_slam":
			_swing_at_player(data.slam)
		elif e == "core_window_open":
			_seal_glow(true)
		elif e == "core_window_close":
			_seal_glow(false)


func _steer(delta: float, ppos: Vector2) -> void:
	var my: Vector2 = Vector2(global_position.x, global_position.z)
	var d: float = my.distance_to(ppos)
	var dir: Vector2 = Vector2.ZERO
	if d > 3.0:
		dir = (ppos - my).normalized()
	elif d < 1.5:
		dir = (my - ppos).normalized()
	if dir == Vector2.ZERO:
		return
	var speed: float = data.speed if logic.phase() == 1 \
			else data.speed_phase2
	var next: Vector2 = my + dir * (speed * delta)
	# The arena obstacle (the handcrafted room: one box at (0, -5),
	# 3 x 1.6): a simple push-out (no nav, ADR-002).
	var ox: float = _arena.x
	var oz: float = _arena.z
	if absf(next.x - ox) < 1.9 and absf(next.y - (oz - 5.0)) < 1.2:
		next.y = oz - 5.0 - 1.2  # stay on the arena side
	global_position = Vector3(next.x, global_position.y, next.y)
	# Face the player (the attacks are distance-based; the look is
	# the readable part).
	look_at_from(my, ppos)


func look_at_from(my: Vector2, ppos: Vector2) -> void:
	var a: float = atan2(ppos.x - my.x, ppos.y - my.y)
	rotation.y = a


func _swing_at_player(atk: _ATK) -> void:
	var d: float = global_position.distance_to(_player.get_body_position())
	if d <= atk.range:
		_hit_player(float(atk.damage))


func _hit_player(amount: float) -> void:
	var ptarget: Variant = _player.get_combat_target()
	if ptarget == null:
		return
	var req: _DREQ = _DREQ.new()
	req.source = self
	req.target = _player
	req.amount = amount
	req.type = _DREQ.Type.MELEE
	req.position = _player.get_body_position()
	var rel: Vector3 = _player.get_body_position() - global_position
	req.knockback_direction = (rel.normalized()
			if rel.length() > 0.01 else Vector3(0, 0, -1))
	_resolver.resolve(req)


func _on_state(_prev: int, cur: int) -> void:
	match cur:
		_LOGIC.State.PHASE_SHIFT:
			_on_phase2()
		_LOGIC.State.DEATH_DISSOLVE:
			_dissolve_left = data.dissolve_time
			_say(LINE_DEATH)
		_LOGIC.State.DEATH_FINAL:
			_say(LINE_FINAL)
		_LOGIC.State.DEFEATED:
			_on_defeated()


# --- Phase 2 (60%): the arena changes, the Remnant of the best run -----

func _on_phase2() -> void:
	_say(LINE_PHASE2)
	# M2.3 (MYSTERY_REVEAL_MAP): the line lands the stage (the main
	# scene resolves the gate).
	stage_reveal.emit(&"m2_first")
	# The arena "opens": the seal stays lit (the workshop).
	_seal_glow(true)
	_spawn_minion()


func _spawn_minion() -> void:
	if _minion != null or _ws == null:
		return
	var src: Resource = load("res://data/enemies/%s.tres"
			% String(data.minion_id))
	if src == null:
		push_error("Boss: the minion data is missing: "
				+ String(data.minion_id))
		return
	var md: _EDATA = src.duplicate(true)
	md.health = data.minion_health
	md.attack.damage = data.minion_damage
	# Not an encounter remnant: it fights, it does not "meet" (the
	# world-remnant flags stay untouched).
	md.first_encounter_leaves = false
	md.leave_fade = 1.5
	var m: Node = _ECTRL.new()
	m.name = "BossMinion"
	if _director == null:
		push_error("Boss: no enemy director for the minion")
		return
	m.setup(md, Vector3(_arena.x + 8.0, 0.0, _arena.z + 8.0),
			_player, _director)
	get_parent().add_child(m)
	m.global_position = Vector3(_arena.x + 8.0, 0.0, _arena.z + 8.0)
	_minion = m


# The minion "leaves" at half hp (BOSS_DESIGN §3.4: not a kill).
func _on_damage_applied(res: Variant) -> void:
	# The player's normal hits: the resolver owns the CombatTarget's
	# hp — the LOGIC must see it too (phase 2 + death are logic
	# states; the controller is the bridge).
	if res.target == self:
		logic.set_hp(res.target_hp)
		# The last stand (30%): the blade he left, one more time
		# (CHARACTER_BIBLE §8 #7 — only if the player left it).
		if not _left_blade_line_done and _target.hp > 0.0 \
				and _target.hp <= _target.max_hp * 0.3 \
				and not _ws.flag(&"first_blade_taken"):
			_left_blade_line_done = true
			_say(LINE_LEFT_BLADE)
		return
	if _minion == null or _minion_faded:
		return
	if res.target != _minion:
		return
	var min_hp: float = float(data.minion_health) * 0.5
	if res.target_hp <= min_hp:
		_minion_faded = true
		if _minion != null and is_instance_valid(_minion) \
				and _minion.has_method("gentle_leave"):
			_minion.gentle_leave()


# --- The death sequence (K6 -> K7) --------------------------------------

func _on_defeated() -> void:
	_defeated = true
	# The FIRST BLADE aftermath (BOSS_DESIGN §4.1) is silent here:
	# line #10 ("let them go") is the last word — the blade's own
	# lines were spoken at the take (#5) and the last stand (#7).
	if _minion != null and is_instance_valid(_minion) \
			and _minion.has_method("gentle_leave"):
		_minion.gentle_leave()
	defeated.emit()


func is_defeated() -> bool:
	return _defeated


# --- Visuals -------------------------------------------------------------

func _build_visual() -> void:
	# Reveal #7: he is ELI (the player's build) in a worn material —
	# "the tired you" (CHARACTER_BIBLE §8). The lantern is his.
	# Phase 13: the shared character language (CharacterVisual) —
	# the worn cloak (wear desaturates) + the hood + the rust.
	var _pal: Variant = load("res://data/visual/palette.tres")
	var v: Node3D = _CV.build(self, {
			"cloth": _pal.first_worn,
			"wear": 0.55,
			"hood": true,
			"scarf": true,
			"accent": _pal.rust,
		}, textures)
	var body: Node = v.get_node_or_null("Body")
	if body == null:
		push_error("BossController: the visual has no Body")
		return
	# The death dissolve mutates this material (keep the link).
	_body_mat = body.material_override
	_body_mat.transparency = 1  # TRANSPARENCY_ALPHA: the fade reads
	# His lantern (first_traces_seen: "the big footprints + his
	# lantern" — the same light the player saw in the mine).
	var stick: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.04, 0.7, 0.04)
	stick.mesh = bm
	stick.position = Vector3(0.45, 1.1, 0.0)
	var smat: StandardMaterial3D = _CV.rust_mat(textures)
	stick.material_override = smat
	add_child(stick)
	var lamp: MeshInstance3D = MeshInstance3D.new()
	var lm: SphereMesh = SphereMesh.new()
	lm.radius = 0.08
	lm.height = 0.16
	lamp.mesh = lm
	lamp.position = Vector3(0.45, 0.72, 0.0)
	var lmat: StandardMaterial3D = StandardMaterial3D.new()
	lmat.albedo_color = _pal.ember_amber.lerp(Color.WHITE, 0.25)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.8, 0.4)
	lmat.emission_energy_multiplier = 2.0
	lamp.material_override = lmat
	add_child(lamp)
	_label = Label3D.new()
	_label.position = Vector3(0.0, 2.5, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.92, 0.9, 0.86, 0.95)
	_label.visible = false
	add_child(_label)


func _build_seal() -> void:
	# The seal (the arena core): a stone ring at the center — the
	# "heart of the arena" (BOSS_DESIGN §1). It glows in the core
	# window (fairness: the core is visible, GDD §6.2).
	var parent: Node = get_parent()
	if parent == null:
		return
	var seal: Node3D = Node3D.new()
	seal.name = "ArenaSeal"
	seal.position = _seal_pos
	parent.add_child(seal)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 1.3
	tm.outer_radius = 1.5
	ring.mesh = tm
	ring.position = Vector3(0.0, 0.03, 0.0)
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.32, 0.32, 0.35)
	rmat.emission_enabled = true
	rmat.emission = Color(0.7, 0.85, 1.0)
	rmat.emission_energy_multiplier = 0.0
	ring.material_override = rmat
	seal.add_child(ring)
	_seal_mats.append(rmat)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var dm: CylinderMesh = CylinderMesh.new()
	dm.top_radius = 1.3
	dm.bottom_radius = 1.3
	dm.height = 0.04
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.02, 0.0)
	var dmat: StandardMaterial3D = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.2, 0.2, 0.23)
	disc.material_override = dmat
	seal.add_child(disc)


func _seal_glow(on: bool) -> void:
	for m in _seal_mats:
		if m != null and is_instance_valid(m):
			(m as StandardMaterial3D).emission_energy_multiplier = \
					2.5 if on else 0.0


