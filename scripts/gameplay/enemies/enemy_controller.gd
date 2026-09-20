# EnemyController — the scene-side enemy: visuals, senses, steering,
# attack execution. One Node3D per enemy, composed in code (no .tscn —
# ADR-024: prototype visuals from primitives; the art pipeline lands
# with the model pipeline).
#
# The BEHAVIOR is EnemyLogic (pure, unit-tested). This class:
#   - builds the per-archetype prototype visual (code-built);
#   - computes the EnemySense snapshot (geometric see: range + fov;
#     LOS seam — Phase 7 rooms, ADR-024);
#   - steers along the director's NavGraph (path_update_hz budget);
#   - executes EV_ATTACK_HIT as a sector sample (ADR-023, the combat
#     twin of the player weapon) through the DamageResolver;
#   - owns the CombatTarget (resolver-registered) and maps damage
#     back into the logic (hitstun / death);
#   - plays the telegraph "!" during WINDUP and the speech bubbles
#     (Remnant first encounter, Mimic spawn line, Forgotten whisper).
class_name EnemyController
extends Node3D

const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _LOGIC = preload("res://scripts/gameplay/enemies/enemy_logic.gd")
const _SENSE = preload("res://scripts/gameplay/enemies/enemy_sense.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _PSTATE = preload("res://scripts/player/player_state.gd")

# Telegraph readability: shown from WINDUP start (ENEMY_DESIGN §0.2).
const PATH_REACH: float = 0.35  # waypoint reached
const SEPARATION_DIST: float = 1.1  # m between enemies
const SPEECH_TIME: float = 3.0  # s a speech bubble stays

var _data: _DATA
var _logic: _LOGIC
var _sense: _SENSE
var _target: _CT
var _player: Node = null
var _director: Node = null
var _home: Vector2 = Vector2.ZERO
func _hub() -> float:
	return _director.hub_radius() if _director != null else 24.0

var _mesh: MeshInstance3D
var _accent: MeshInstance3D
var _tele: Label3D
var _speech: Label3D
var _speech_timer: float = 0.0
var _hit_flash: float = 0.0
var _base_color: Color

# Path following (the NavGraph is the director's).
var _path: PackedVector3Array = PackedVector3Array()
var _path_idx: int = 0
var _next_path_update: float = 0.0

# Run-scoped bookkeeping (the director reads these).
var death_drop: String = ""
var _gone: bool = false

# AI budget telemetry (the Phase 16 device measurement reuses this).
var ticks_run: int = 0


func data() -> _DATA:
	return _data


# The boss minion: it LEAVES (fades) — not a kill.
func gentle_leave() -> void:
	_logic.gentle_leave()


func logic() -> _LOGIC:
	return _logic


func is_gone() -> bool:
	return _gone


func is_speaking() -> bool:
	return _speech != null and _speech.visible


func speech_text() -> String:
	return _speech.text if _speech != null else ""


# Called by the director right after add_child.
# The #6 beat (WORLD_STATE_DESIGN section 4): the Remnant reads the
# player's note and adds a line to its first-encounter sequence.
func add_encounter_line(text: String) -> void:
	if _logic != null:
		_logic.extra_lines.append(text)


func setup(p_data: _DATA, pos: Vector3, player: Node, director: Node) -> void:
	_data = p_data
	_player = player
	_director = director
	_home = Vector2(pos.x, pos.z)
	_sense = _SENSE.new()
	_rng_seed()
	global_position = pos
	_logic = _LOGIC.new(_data, _seed)
	# First-encounter / style wiring (director run-scoped state).
	_logic.first_encounter = _is_first_remnant()
	if _data.spawn_line != "":
		_show_speech(_data.spawn_line)
	_build_visual()
	_register_combat()


func _rng_seed() -> void:
	# Deterministic per enemy id (reproducible wandering/speech picks).
	_seed = int(abs(hash(String(_id_placeholder()))))


func _id_placeholder() -> String:
	return _data.id if _data != null else "enemy"


# The enemy's data id (death-cause mapping, run recording).
func get_data_id() -> StringName:
	return _data.id if _data != null else &"unknown"


var _seed: int = 0


func _is_first_remnant() -> bool:
	if _data.archetype != _DATA.Archetype.REMNANT:
		return false
	if not _data.first_encounter_leaves:
		return false
	return _director != null and not _director.remnant_met


# WEAPON_DESIGN §4.1: the First Blade — the Echoes "respect" it
# (a remnant does not attack first while the player carries the
# blade; one real hit ends the respect).
func _respect_allowed() -> bool:
	if _data.archetype != _DATA.Archetype.REMNANT or _respect_broken:
		return false
	return _director != null and _director.respects_first_blade()


func _respect_line() -> void:
	if _blade_line_done or _data.archetype != _DATA.Archetype.REMNANT:
		return
	if _director == null or not _director.respects_first_blade():
		return
	var d: float = global_position.distance_to(_player.global_position)
	if d <= 3.0:
		_blade_line_done = true
		_show_speech("...that was mine.")


# #6 (P9, M3 stage 2): the note-reading encounter — once per
# session, AFTER the first meeting, when the player has written a
# note. Evaluated at sight time: the note can be written mid-run,
# after the remnant spawned. The run gate (RUN 03+) is in
# FirstRunDirector._on_echo_triggered.
func _note_encounter_allowed() -> bool:
	if _data.archetype != _DATA.Archetype.REMNANT \
			or not _data.first_encounter_leaves:
		return false
	if _director == null or not _director.remnant_met \
			or _director.remnant_note_met:
		return false
	var ws: Variant = _director.world_state()
	if ws == null:
		return false
	return not (ws.last_note() as Dictionary).is_empty()


func _build_visual() -> void:
	# Prototype silhouettes (ENEMY_DESIGN §1.3/§2.3/§3.3/§4.3/§5.3):
	# same primitive language as the camp (ADR-022: no .tscn pipeline).
	_mesh = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	match _data.archetype:
		_DATA.Archetype.WATCHER:
			cap.height = 2.2
			cap.radius = 0.22
			_base_color = Color(0.10, 0.10, 0.14)
		_DATA.Archetype.FORGOTTEN:
			cap.height = 1.6
			cap.radius = 0.30
			_base_color = Color(0.92, 0.92, 0.90)  # bleached
		_DATA.Archetype.MIMIC:
			cap.height = 1.7
			cap.radius = 0.35
			_base_color = Color(0.45, 0.45, 0.48)  # echo: desaturated
		_:
			cap.height = 1.7
			cap.radius = 0.35
			if _data.archetype == _DATA.Archetype.REMNANT:
				_base_color = Color(0.78, 0.78, 0.80)  # Eli's white
			else:
				_base_color = Color(0.16, 0.18, 0.22)  # hollow: dark
	_mesh.mesh = cap
	_mesh.position.y = cap.height * 0.5
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = _base_color
	_mesh.material_override = mat
	add_child(_mesh)

	# The "accent": what the eye catches (core / eye / blade).
	_accent = MeshInstance3D.new()
	var acc: SphereMesh = SphereMesh.new()
	match _data.archetype:
		_DATA.Archetype.WATCHER:
			# Single eye, at the top (ENEMY_DESIGN §3.3).
			acc.radius = 0.09
			acc.height = 0.18
			_accent.position = Vector3(0.0, cap.height - 0.15, 0.0)
			mat = _accent_mat(Color(0.60, 0.80, 1.00), 2.0)
		_DATA.Archetype.HOLLOW:
			# A faint red core in the chest (ENEMY_DESIGN §1.3).
			acc.radius = 0.07
			acc.height = 0.14
			_accent.position = Vector3(0.0, 1.25, 0.18)
			mat = _accent_mat(Color(0.90, 0.25, 0.20), 1.6)
		_DATA.Archetype.FORGOTTEN:
			# No eyes (ENEMY_DESIGN §5.3): a dark hollow where a face
			# would be — the "not there" mark.
			acc.radius = 0.06
			acc.height = 0.12
			_accent.position = Vector3(0.0, 1.45, 0.18)
			mat = _accent_mat(Color(0.05, 0.05, 0.05), 0.0)
		_DATA.Archetype.MIMIC:
			# Echo rim: an emissive band (the "mirror" read).
			acc.radius = 0.10
			acc.height = 0.20
			_accent.position = Vector3(0.0, 1.1, 0.0)
			mat = _accent_mat(Color(1.0, 1.0, 1.0), 2.5)
		_DATA.Archetype.REMNANT:
			# A blade at the side (uses the player's weapon — §2.2).
			acc.radius = 0.03
			acc.height = 0.06
			_accent.position = Vector3(0.45, 1.0, 0.1)
			mat = _accent_mat(Color(0.80, 0.82, 0.85), 0.4)
	_accent.mesh = acc
	_accent.material_override = mat
	add_child(_accent)

	# Telegraph "!" (ENEMY_DESIGN §0.2: 0.4–0.8 s, always readable).
	_tele = Label3D.new()
	_tele.text = "!"
	_tele.position = Vector3(0.0, cap.height + 0.5, 0.0)
	_tele.font_size = 48
	_tele.modulate = Color(1.0, 0.55, 0.15)
	_tele.visible = false
	add_child(_tele)

	# Speech bubble (Remnant/Mimic/Forgotten lines).
	_speech = Label3D.new()
	_speech.position = Vector3(0.0, cap.height + 1.0, 0.0)
	_speech.font_size = 14
	_speech.modulate = Color(0.90, 0.95, 1.00)
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.outline_size = 4
	_speech.visible = false
	add_child(_speech)


func _accent_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.emissive_enabled = energy > 0.0
	m.emissive_color = color
	m.emissive_energy = energy
	return m


func _register_combat() -> void:
	_target = _CT.new(self, float(_data.health))
	_target.combat_id = _data.id
	# Watcher (MVP): invulnerable at the combat layer — the resolver
	# blocks every hit (ENEMY_DESIGN §3, Q-E1: design, not a bug).
	_target.invulnerable = _data.unkillable
	var resolver: Node = _director.resolver
	if resolver == null:
		push_error("EnemyController: director has no resolver")
		return
	resolver.register(self, _target)
	_target.damaged.connect(_on_damaged)
	_target.killed.connect(_on_killed)


func _unregister_combat() -> void:
	var resolver: Node = _director.resolver if _director != null else null
	if resolver != null:
		resolver.unregister(self)


# One budgeted tick (driven by the director at data.update_hz).
# Returns the event list for the director.
func tick(delta: float) -> Array[String]:
	if _gone or _logic == null:
		return []
	ticks_run += 1
	var events: Array[String] = []
	_target.update(delta)

	var sense: _SENSE = _build_sense()
	_logic.note_encounter = _note_encounter_allowed()
	_logic.respect = _respect_allowed()
	_respect_line()
	_logic.set_position(global_position.x, global_position.z)
	events = _logic.update(delta, sense, _home)

	for ev in events:
		match ev:
			_LOGIC.EV_ATTACK_HIT:
				_try_attack()
			_LOGIC.EV_SPEECH:
				_show_speech(_logic.last_speech)
				_report_echo()
			_LOGIC.EV_TELEPORT:
				_vanish_reposition()
			_:
				pass

	_steer(delta, sense)
	_update_fx(delta)
	return events


# --- Senses (geometric; LOS seam — Phase 7 rooms, ADR-024) ---

func _build_sense() -> _SENSE:
	var s: _SENSE = _SENSE.new()
	if _player == null or _player.is_dead():
		return s
	var ppos: Vector3 = _player.get_body_position()
	s.player_position = ppos
	var rel: Vector3 = Vector3(ppos.x - global_position.x, 0.0,
			ppos.z - global_position.z)
	var dist: float = rel.length()

	# See: range + fov (no LOS raycast in the rig — ADR-024 seam).
	if dist <= _data.sight_range:
		var fwd: Vector3 = Vector3(global_transform.basis.x.x, 0.0,
				global_transform.basis.x.z).normalized()
		var to: Vector3 = rel.normalized()
		var angle: float = rad_to_deg(acos(
				clampf(fwd.dot(to), -1.0, 1.0)))
		s.player_seen = angle <= _data.fov * 0.5

	# Noise (explorer profile mutes it — director).
	if _director != null and not _director.hear_muted:
		s.player_noise = _director.player_making_noise()

	# Mutual eye-line (Watcher): the player faces this enemy.
	if dist <= 15.0:
		var pfacing: Vector3 = Vector3(_player.get_facing().x, 0.0,
				_player.get_facing().z)
		if pfacing.length() > 0.01:
			var back: Vector3 = -rel.normalized()
			var a: float = rad_to_deg(acos(clampf(
					pfacing.normalized().dot(back), -1.0, 1.0)))
			s.eye_line = a <= 30.0

	# Player weapon state (Mimic punish patterns).
	if _player.weapon != null:
		s.player_weapon_phase = _player.weapon.get_logic().phase()
		s.player_combo_index = _player.weapon.get_logic().hit_index()
	s.player_dodging = _player.get_state() == _PSTATE.State.DODGE
	return s


# --- Attack execution (sector sample, ADR-023) ---

func _try_attack() -> void:
	var atk = _data.attack
	if atk == null:
		return
	var ppos: Vector3 = _player.get_body_position()
	var rel: Vector3 = Vector3(ppos.x - global_position.x, 0.0,
			ppos.z - global_position.z)
	var dist: float = rel.length()
	if dist > atk.range:
		return
	if dist > 0.01:
		var fwd: Vector3 = Vector3(global_transform.basis.x.x, 0.0,
				global_transform.basis.x.z).normalized()
		var angle: float = rad_to_deg(acos(clampf(
				fwd.dot(rel.normalized()), -1.0, 1.0)))
		if angle > atk.arc * 0.5:
			return
	var req: _DREQ = _DREQ.new()
	req.source = self
	req.target = _player
	req.amount = float(atk.damage) * _director.dmg_mult
	req.type = _DREQ.Type.MELEE
	req.position = ppos
	req.knockback_direction = (
			rel.normalized() if dist > 0.01 else Vector3(0, 0, -1))
	req.weapon = _data
	var resolver: Node = _director.resolver
	resolver.resolve(req)


# --- Damage back into the logic ---

func _on_damaged(_req: Variant) -> void:
	# The resolver only emits `damaged` on APPLIED hits — blocked
	# damage (dodge i-frames, the unkillable Watcher) never reaches
	# here, so an interrupt is always a real hit.
	if _logic.interrupt_hurt():
		_hit_flash = 0.15
	# The First Blade respect ends with a real hit ("you hit him").
	_respect_broken = true


func _on_killed() -> void:
	_logic.die()
	_tele.visible = false


# --- Steering ---

func _steer(delta: float, sense: _SENSE) -> void:
	var state: int = _logic.state()
	if _logic.is_dead():
		# Dissolve in place (the visual fades in _update_fx).
		return
	var speed: float = _data.speed * _director.speed_mult
	var target: Vector2 = Vector2.INF
	var moving: bool = false

	match state:
		_ST.State.CHASE:
			target = _chase_target(sense)
			speed *= _logic.speed_pressure()
			if target != Vector2.INF:
				moving = _follow_target(target, delta, speed)
		_ST.State.FOLLOW:
			target = Vector2(sense.player_position.x,
					sense.player_position.z)
			speed *= _data.follow_speed_mult * _director.follow_mult
			moving = _follow_target(target, delta, speed)
		_ST.State.WANDER:
			target = _logic.wander_target()
			speed *= 0.5  # the wanderer drifts (ENEMY_DESIGN §5.2)
			moving = _follow_target(target, delta, speed)
		_ST.State.RETREAT:
			target = _home
			moving = _follow_target(target, delta, speed)
		_ST.State.IDLE:
			if Vector2(global_position.x, global_position.z
					).distance_to(_home) > 0.5:
				moving = _follow_target(_home, delta, speed * 0.5)
			# Head tracking: face the player when seen (cheap read).
			if sense.player_seen:
				_face_player(sense.player_position)
		_:
			pass  # HURT/SPEAK/LEAVE/VANISH/OBSERVING/attack states

	if moving:
		_separate()
	# Telegraph visibility (readability: full WINDUP, ADR-024).
	_tele.visible = state == _ST.State.WINDUP


func _chase_target(sense: _SENSE) -> Vector2:
	var ppos: Vector2 = Vector2(sense.player_position.x,
			sense.player_position.z)
	# Mimic (dodge-heavy): sidestep while the player telegraphs.
	if _logic.is_evasive() \
			and sense.player_weapon_phase == 1:
		var pfacing: Vector3 = _player.get_facing()
		var side: Vector2 = Vector2(-pfacing.z, pfacing.x)
		return ppos + side * 1.0
	# Remnant (ranged style): back off to the kiting band.
	if _data.archetype == _DATA.Archetype.REMNANT \
			and _data.mirror_style == _STYLE.STYLE_RANGED:
		var me: Vector2 = Vector2(global_position.x, global_position.z)
		var d: float = me.distance_to(ppos)
		if d <= _LOGIC.KITE_FAR:
			var away: Vector2 = (me - ppos).normalized()
			return ppos + away * _LOGIC.KITE_FAR
	# Hollow: out of sight -> the last remembered position (memory).
	if not sense.player_seen \
			and _data.archetype == _DATA.Archetype.HOLLOW:
		var m: Vector2 = _director.memory_last(_data.memory_window)
		if m != Vector2.INF:
			return m
	return ppos


# Move toward a world target (NavGraph when available, direct in the
# open hub). Returns true when actually moving.
func _follow_target(target: Vector2, delta: float,
		speed: float) -> bool:
	var me: Vector2 = Vector2(global_position.x, global_position.z)
	var d: float = me.distance_to(target)
	if d < 0.15:
		return false
	# Path refresh on the path budget (not every tick — TECHNICAL).
	if _director.time >= _next_path_update:
		_next_path_update = _director.time \
				+ 1.0 / _data.path_update_hz
		_refresh_path(target)
	var wp: Vector2
	if _path_idx < _path.size():
		var p: Vector3 = _path[_path_idx]
		wp = Vector2(p.x, p.z)
		if me.distance_to(wp) < PATH_REACH:
			_path_idx += 1
	else:
		_path_idx = 0
		wp = target
	var dir: Vector2 = (wp - me).normalized()
	# The Mimic's ranged pressure is already in the speed; the
	# slayer/runner aggression multiplies are in the director.
	_move_by(dir, speed * delta)
	_face(dir)
	return true


func _refresh_path(target: Vector2) -> void:
	if _director == null or _director.nav == null:
		_path = PackedVector3Array()
		return
	var me: Vector2 = Vector2(global_position.x, global_position.z)
	var from: int = _director.nav.nearest_node(me)
	var to: int = _director.nav.nearest_node(target)
	_path = _director.nav.path_world(from, to)
	_path_idx = 0


func _move_by(dir: Vector2, amount: float) -> void:
	var me: Vector2 = Vector2(global_position.x, global_position.z)
	var np: Vector2 = me + dir * amount
	# Hub boundary (the camp ring + pad; zones — Phase 7/8).
	if np.length() > _hub():
		np = np.normalized() * _hub()
	global_position = Vector3(np.x, global_position.y, np.y)


func _separate() -> void:
	if _director == null:
		return
	var me: Vector2 = Vector2(global_position.x, global_position.z)
	for e in _director.get_alive_enemies():
		if e == self:
			continue
		var ep: Vector2 = Vector2(e.global_position.x, e.global_position.z)
		var d: float = me.distance_to(ep)
		if d < SEPARATION_DIST and d > 0.001:
			var push: Vector2 = (me - ep).normalized() \
					* (SEPARATION_DIST - d) * 0.5
			_move_by(push.normalized(), push.length())


# The enemy's forward is local +X (the capsule's "front"): rotation
# y = atan2(-dz, dx) makes local +X point at `dir`.
func _face(dir: Vector2) -> void:
	if dir.length() < 0.001:
		return
	rotation.y = atan2(-dir.y, dir.x)


func _face_player(ppos: Vector3) -> void:
	var rel: Vector2 = Vector2(ppos.x - global_position.x,
			ppos.z - global_position.z)
	_face(rel)


# Watcher vanish: teleport vanish_distance away from the player
# (ENEMY_DESIGN §3.2: reappears where you least expect).
func _vanish_reposition() -> void:
	var ppos: Vector2 = Vector2(_player.get_body_position().x,
			_player.get_body_position().z)
	var away: Vector2 = (Vector2(global_position.x, global_position.z)
			- ppos).normalized()
	if away.length() < 0.01:
		away = Vector2(0.0, -1.0)
	var np: Vector2 = ppos + away * _data.vanish_distance
	if np.length() > _hub():
		np = np.normalized() * _hub()
	global_position = Vector3(np.x, global_position.y, np.y)
	_path = PackedVector3Array()
	_path_idx = 0


# --- FX ---

func _update_fx(delta: float) -> void:
	if _speech_timer > 0.0:
		_speech_timer -= delta
		if _speech_timer <= 0.0:
			_speech.visible = false
	if _hit_flash > 0.0:
		_hit_flash -= delta
		_mesh.material_override.albedo_color = _base_color.lerp(
				Color.WHITE, 0.6 * (_hit_flash / 0.15))
	if _logic.is_dead():
		# Dissolve: fade to nothing over data.dissolve_time
		# (Forgotten: the slow 3 s dissolve).
		var d: float = maxf(_data.dissolve_time, 0.05)
		var t: float = _logic.state_elapsed() / d
		var a: float = clampf(1.0 - t, 0.0, 1.0)
		_mesh.material_override.albedo_color.a = a
		if _accent != null:
			_accent.material_override.albedo_color.a = a


func _show_speech(text: String) -> void:
	if text == "":
		return
	_speech.text = text
	_speech.visible = true
	_speech_timer = SPEECH_TIME


# Phase 9: the canonical first encounter (#1) is a recorded moment
# (ECHO_TRIGGER in the run log — once per encounter, not per line).
func _report_echo() -> void:
	if not (_logic.first_encounter or _logic.note_encounter):
		return
	_echo_reported = true
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	if bus != null and bus.has_signal("echo_triggered"):
		bus.echo_triggered.emit(&"combat", global_position)


var _echo_reported: bool = false
var _respect_broken: bool = false
var _blade_line_done: bool = false


func _exit_tree() -> void:
	_gone = true
	_unregister_combat()
