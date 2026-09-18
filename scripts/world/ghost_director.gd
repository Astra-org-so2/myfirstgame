# GhostDirector — the echo orchestration of ONE run (ROADMAP Phase 9,
# TECHNICAL_DESIGN section 5, ECHO_SYSTEM_DESIGN sections 1/7/8,
# ADR-014). Scene-composed, NOT an autoload (ARCHITECTURE section 6).
#
# Per run (the main scene calls prepare_run at the respawn rebuild):
#   - the budget (data/echo/echo_budget.tres): RUN 1 = 0 echoes,
#     RUN 02/03 = 1 Passive + 1 Combat, RUN 04+ = +1 «special»;
#   - Passive Echo: the last FULL run record remapped into the new
#     layout (GhostTimeline) — replayed by a GhostController per
#     level (the ghost appears where its replay path is);
#   - Combat Echo: the budget slot is handed to the EnemyDirector
#     (1 remnant per run; the spawn tables gate it on
#     first_death_done, the position override puts it «where the
#     player was» — RUN 02: B4 «You're early.»);
#   - markers: up to 5 old death positions (full records only — the
#     5 MB cap compresses older runs to summaries without the
#     position; honest limitation, documented) — remapped, one
#     faint emissive marker each.
#
# Ticks: the main scene calls update(delta) (the ghost has no
# physics; O(1) per frame — budget section 5.6, measured in the
# exit criterion ≤ 0.5 ms/frame).
class_name GhostDirector
extends Node

const _TL = preload("res://scripts/gameplay/echo/ghost_timeline.gd")
const _BUDGET = preload("res://scripts/gameplay/echo/echo_budget_data.gd")
const _STATE = preload("res://scripts/gameplay/echo/echo_budget_state.gd")
const _PED = preload("res://scripts/gameplay/echo/passive_echo_data.gd")
const _GC = preload("res://scripts/world/ghost_controller.gd")
const _KF = preload("res://scripts/gameplay/echo/ghost_keyframe.gd")
const _TRANSFORM = preload("res://scripts/gameplay/progression/world_transform_data.gd")
const _TRANSFORM_DATA = preload(
		"res://data/world_transform_post_boss.tres")

# Phase 10 (K7, the trigger — the boss sets the flag in Phase 12):
# post-boss the echoes are «тише» (ECHO_SYSTEM_DESIGN section 8).
const BOSS_FLAG: StringName = &"boss_defeated"
const _EV = preload("res://scripts/gameplay/run/run_event.gd")

# 5 old-run markers (ECHO_SYSTEM_DESIGN section 5.6: a pool).
const MAX_MARKERS: int = 5

var budget_state: _STATE = _STATE.new()
var echo_budget: _BUDGET
var passive_data: _PED
var remnant_id: StringName = &"remnant_mirror"

var _timeline: _TL = null
var _ghost: _GC = null
var _markers: Array = []  # MeshInstance3D (the current level's)
var _player: Node = null
var _death_positions: Array = []  # remapped Vector3 (run space)
var _combat_placed: bool = false
var _layout: Variant = null  # the current run's layout (camp ring)
var _ws: Variant = null
var _level: Node = null


func setup(p_echo_budget: _BUDGET, p_passive_data: _PED,
		p_player: Node) -> void:
	echo_budget = p_echo_budget
	passive_data = p_passive_data
	_player = p_player


# The respawn rebuild hook (main, after the layout regen, BEFORE the
# first _enter_level): arm this run's echoes.
func prepare_run(run_id: int, ws: Variant, prev_record, old_layout,
		new_layout) -> void:
	clear()
	if ws == null or echo_budget == null:
		return
	var prev: int = echo_budget.passive(run_id)
	var comb: int = echo_budget.combat(run_id)
	var spec: int = echo_budget.special(run_id)
	# K7 (WORLD_STATE_DESIGN section 6): boss_defeated -> «тише» —
	# the transform table overrides the run budget.
	if ws.flag(BOSS_FLAG):
		prev = _TRANSFORM_DATA.echo_passive
		comb = _TRANSFORM_DATA.echo_combat
		spec = _TRANSFORM_DATA.echo_special
	budget_state.init_run(run_id, prev, comb, spec)
	_combat_placed = false
	_layout = new_layout
	_ws = ws
	_timeline = null
	_death_positions = []
	# Passive: the last FULL record (the ghost replays run N-1).
	if prev > 0 and prev_record != null \
			and (prev_record.events as Array).size() >= 2:
		_timeline = _TL.new()
		_timeline.build(prev_record, old_layout, new_layout)
	# Markers: the last ≤5 death positions of the full records,
	# remapped into the new layout (the camp ring is stable, zone
	# positions move with their room).
	var runs: Array = ws.runs.full
	for i in range(runs.size() - 1, -1, -1):
		var r: Variant = runs[i]
		if r.deaths > 0 and r.last_death_pos != Vector3.ZERO:
			var p: Vector3 = _TL._remap_pos(r.last_death_pos,
					old_layout, new_layout)
			if p != Vector3.INF:
				_death_positions.append(p)
		if _death_positions.size() >= MAX_MARKERS:
			break
	_death_positions.reverse()  # oldest first (stable display)
	# Combat: the «where the player was» override for the run's
	# FIRST remnant spawn (RUN 02: B4 — on the player's RUN 1 path).
	if comb > 0 and prev_record != null:
		var p: Vector3 = _combat_spawn_pos(prev_record, old_layout,
				new_layout)
		if p != Vector3.ZERO:
			_combat_pos = p


var _combat_pos: Vector3 = Vector3.ZERO


func combat_spawn_pos() -> Vector3:
	return _combat_pos


func has_passive() -> bool:
	return _timeline != null and not _timeline.is_empty()


# A level switch (main, after zone_world.enter): the ghost and the
# markers are per-level (the level node is rebuilt on every entry).
func on_level_entered(area_id: StringName, level: Node) -> void:
	_free_ghost()
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	if level == null:
		return
	# Markers of the runs that died IN this area.
	for p in _death_positions:
		if _inside_area(p, level):
			_markers.append(_build_marker(level, p))
	# The ghost: the remapped keyframes that live in this level.
	if not has_passive():
		return
	var local: _TL = _level_timeline(level, area_id)
	if local == null or local.is_empty():
		return
	_ghost = _GC.new()
	_ghost.name = "PassiveEcho"
	_ghost.setup(local, passive_data, _player)
	# The rewind skips of this stretch: one dissolve pulse at spawn
	# («не всё помнится», TECHNICAL_DESIGN section 5.2).
	if local.dropped > 0:
		_ghost.pulse()
	level.add_child(_ghost)
	_level = level

# The keyframes inside the given level (new-layout footprints).
func _level_timeline(level: Node, area_id: StringName) -> _TL:
	var out := _TL.new()
	for i in _timeline.keyframes.size():
		var k: _KF = _timeline.keyframes[i]
		if _inside_area(k.pos, level):
			out.keyframes.append(k)
	if out.keyframes.size() >= 2:
		out.start_t = (out.keyframes[0] as _KF).t
		out.duration = (out.keyframes.back() as _KF).t - out.start_t
		# The pulse count of this stretch: a long time gap between
		# surviving keyframes = a room the new layout lacks («не
		# всё помнится»).
		var stretch: int = 0
		for i in out.keyframes.size() - 1:
			var k0: _KF = out.keyframes[i]
			var k1: _KF = out.keyframes[i + 1]
			if k1.t - k0.t > 2.0:
				stretch += 1
		out.dropped = stretch
	return out


func _inside_area(p: Vector3, level: Node) -> bool:
	# The camp level node is empty (CampWorld is separate) — the
	# camp ring is answered against the layout's hub footprint
	# (handcrafted, stable across runs).
	if _layout != null:
		var camp: Variant = _layout.get_area(&"camp")
		if camp != null and camp.rooms.size() > 0:
			var rp: Variant = camp.rooms[0]
			var c: Vector2 = Vector2(rp.origin.x, rp.origin.z)
			var q: Vector2 = Vector2(p.x, p.z)
			var sz: Vector2 = (rp.room.size as Vector2) * 0.5
			if absf(q.x - c.x) <= sz.x + 2.5 and absf(q.y - c.y) \
					<= sz.y + 2.5:
				return true
	var rooms: Array = level.get_children()
	for n in rooms:
		var rn: Node = n
		var rp: Variant = rn.get("room")
		if rp == null:
			continue
		var c: Vector2 = Vector2(rp.origin.x, rp.origin.z)
		var q: Vector2 = Vector2(p.x, p.z)
		var sz: Vector2 = (rp.room.size as Vector2) * 0.5
		if absf(q.x - c.x) <= sz.x + 0.25 and absf(q.y - c.y) <= sz.y \
				+ 0.25:
			return true
	return false


func _build_marker(level: Node, p: Vector3) -> MeshInstance3D:
	var m: MeshInstance3D = MeshInstance3D.new()
	m.name = "RunMarker"
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(0.4, 0.4)
	var fm: StandardMaterial3D = StandardMaterial3D.new()
	fm.albedo_color = Color(0.62, 0.7, 0.78, 0.4)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(0.5, 0.65, 0.75)
	fm.emission_energy_multiplier = 0.6
	pm.material = fm
	m.mesh = pm
	m.position = Vector3(p.x, 0.04, p.z)
	level.add_child(m)
	return m


# The combat echo position: the LAST point of the previous run's
# path in the camp (B4: «on your path»). The camp is handcrafted
# (stable across runs) so the position needs no remap — kept as-is
# when the old layout's room is missing, the remap handles the rest.
func _combat_spawn_pos(prev_record, old_layout, new_layout) -> Vector3:
	var best: Vector3 = Vector3.ZERO
	var best_t: float = -1.0
	for ev in prev_record.events:
		var e: _EV = ev
		var p: Vector3 = Vector3(e.x / 100.0, 0.0, e.z / 100.0)
		if p.length() > 26.0:  # outside the camp ring: not camp
			continue
		if e.t / 10.0 > best_t:
			best_t = e.t / 10.0
			best = p
	return best


func update(delta: float) -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.update(delta)
		if _ghost.is_done():
			_leave_permanent_traces()
			_free_ghost()


# K7 (WORLD_STATE_DESIGN section 6): post-boss the traces «stay
# forever» — the faded ghost's footprints are left on the level
# instead of dying with it.
func _leave_permanent_traces() -> void:
	if _ws == null or _level == null:
		return
	if not _ws.flag(BOSS_FLAG):
		return
	if not _TRANSFORM_DATA.footprint_permanent:
		return
	if not is_instance_valid(_ghost):
		return
	for i in _ghost.footprint_nodes().size():
		var m: Node = _ghost.footprint_nodes()[i]
		if is_instance_valid(m):
			m.reparent(_level)


func _free_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func clear() -> void:
	_free_ghost()
	for m in _markers:
		if is_instance_valid(m):
			m.queue_free()
	_markers.clear()
	_timeline = null
	_death_positions = []
	_combat_pos = Vector3.ZERO
	_layout = null
