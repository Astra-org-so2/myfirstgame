# EnemyDirector — hub-level enemy orchestration (scene-composed, NOT
# an autoload — ARCHITECTURE §6).
#
# Owns: the NavGraph (pure A* pathfinder), the spawn table evaluation,
# the staggered update budget (each enemy ticks at its own update_hz;
# slots are phase-shifted so ticks don't stack on one frame —
# TECHNICAL_DESIGN AI budget), the Watcher anchor store (<=2/run,
# WORLD_STATE_DESIGN §3), the run-scoped Remnant "met" flag, and the
# player MemoryPath (Hollow memory; run data — Phase 8/10).
#
# EnemyController ticks are driven here — the director is the only
# place that knows the budget.
class_name EnemyDirector
extends Node

const _DATA = preload("res://scripts/gameplay/enemies/enemy_data.gd")
const _NAV_DATA = preload("res://scripts/gameplay/enemies/nav_data.gd")
const _NAV = preload("res://scripts/gameplay/enemies/nav_graph.gd")
const _MPATH = preload("res://scripts/gameplay/enemies/memory_path.gd")
const _TABLE = preload("res://scripts/gameplay/enemies/spawn_table.gd")
const _ENTRY = preload("res://scripts/gameplay/enemies/spawn_entry.gd")
const _CTRL = preload("res://scripts/gameplay/enemies/enemy_controller.gd")
const _LOGIC = preload("res://scripts/gameplay/enemies/enemy_logic.gd")
const _ST = preload("res://scripts/gameplay/enemies/enemy_state.gd")
const _STYLE = preload("res://scripts/gameplay/memory_stats.gd")
const _THR = preload("res://scripts/gameplay/memory_stats_thresholds.gd")
const _ANCHOR = preload("res://scripts/gameplay/enemies/anchor_data.gd")

var nav: _NAV
var memory_path: _MPATH
var anchors: Array = []  # Array[AnchorData]
var time: float = 0.0

# Aggression (ENEMY_DESIGN §7), applied at spawn.
var speed_mult: float = 1.0
var dmg_mult: float = 1.0
var hear_muted: bool = false  # explorer: enemies don't react to sound
var follow_mult: float = 1.0  # runner: the Watcher follows harder

# Run-scoped flags.
var remnant_met: bool = false

var _slots: Array = []  # Array of {ctrl, phase, count, last}

var resolver: Node = null  # the scene-composed DamageResolver
var _player: Node = null
var _stats: _STYLE = null
var _thresholds: _THR
var _spawn_noise: float = -10.0  # time of the last player noise
var _hub_radius: float = 24.0

# The controller asks: is the player making noise right now?
const NOISE_DURATION: float = 0.5
const HUB_PAD: float = 2.0  # boundary pad beyond the nav ring


func setup(player: Node, stats: _STYLE, thresholds: _THR,
		p_resolver: Node) -> void:
	_player = player
	_stats = stats
	_thresholds = thresholds
	resolver = p_resolver
	memory_path = _MPATH.new()


# Movement boundary for enemies (camp ring + pad; zones — 7/8).
func hub_radius() -> float:
	return _hub_radius


# The loaded nav's node count (level identity: the camp's handcrafted
# ring and a generated zone chain have different graphs — the level
# reload seam tests use this).
func nav_node_count() -> int:
	if nav == null:
		return 0
	return nav.node_count()


func load_nav(data: _NAV_DATA) -> void:
	nav = _NAV.new()
	nav.build(data.nodes, data.edges)
	var max_r: float = 0.0
	for i in range(nav.node_count()):
		max_r = maxf(max_r, nav.node_pos(i).length())
	_hub_radius = max_r + HUB_PAD


# Evaluate + spawn the table (one call per run start).
func start(table: _TABLE) -> void:
	for i in range(table.entries.size()):
		var entry: _ENTRY = table.entries[i]
		if not should_spawn(entry):
			continue
		var ctrl: _CTRL = _CTRL.new()
		ctrl.name = "Enemy_" + String(entry.enemy.id)
		add_child(ctrl)
		ctrl.setup(entry.enemy, entry.position, _player, self)
		# Stagger: slot i starts i slots early in the budget — ticks
		# spread across frames instead of stacking (TECHNICAL_DESIGN).
		var phase: float = float(i) / float(maxi(1, table.entries.size())) \
				/ entry.enemy.update_hz
		_slots.append({"ctrl": ctrl, "phase": phase, "count": 0, "last": 0.0})


# Free all spawned enemies (level changes, Phase 7). The run-level
# anchor store survives (it records the run, not the level).
func clear() -> void:
	for slot in _slots:
		var ctrl: _CTRL = slot["ctrl"]
		if ctrl != null and is_instance_valid(ctrl):
			ctrl.queue_free()
	_slots.clear()


# Pure rule (unit-tested): does this entry spawn for this run?
func should_spawn(entry: _ENTRY) -> bool:
	var c: String = entry.condition.strip_edges()
	match c:
		"", "always":
			return true
		"slayer":
			return _profile() == _STYLE.PROFILE_SLAYER
		"runner":
			return _profile() == _STYLE.PROFILE_RUNNER
		"explorer":
			return _profile() == _STYLE.PROFILE_EXPLORER
		"style:melee":
			return _style() == _STYLE.STYLE_MELEE
		"style:ranged":
			return _style() == _STYLE.STYLE_RANGED
		"style:dodge":
			return _style() == _STYLE.STYLE_DODGE
		"first_run":
			return _stats != null and _stats.runs_completed == 0
		_:
			push_error("EnemyDirector: unknown spawn condition: " + c)
			return false


func apply_aggression(profile: int) -> void:
	speed_mult = 1.0
	dmg_mult = 1.0
	hear_muted = false
	follow_mult = 1.0
	match profile:
		_STYLE.PROFILE_SLAYER:
			speed_mult = 1.10  # «злее»: +10% speed
			dmg_mult = 1.05  # +5% damage
		_STYLE.PROFILE_RUNNER:
			speed_mult = 0.90  # «не догоняют»
			follow_mult = 1.25  # but the Watcher follows harder
		_STYLE.PROFILE_EXPLORER:
			hear_muted = true  # «молчаливее»: no sound reaction
		_:
			pass


func update(delta: float) -> void:
	time += delta
	for slot in _slots:
		var ctrl: _CTRL = slot["ctrl"]
		if ctrl == null or not is_instance_valid(ctrl):
			continue
		# Each enemy ticks at its own update_hz and advances its logic
		# by the GAME TIME that actually elapsed (staggered budget:
		# the cost is spread, the speed is full — TECHNICAL_DESIGN).
		# The schedule is anchored to count*period (no drift: a naive
		# next += period accumulates the frame quantization and runs
		# the AI slower than the data says).
		var period: float = 1.0 / ctrl.data().update_hz
		var ideal: float = slot["phase"] + float(slot["count"]) * period
		if time < ideal - 1e-6:
			continue
		var step: float = time - slot["last"]
		var events: Array[String] = ctrl.tick(step)
		slot["last"] = time
		slot["count"] += 1
		for ev in events:
			_on_event(ctrl, ev)


# Player noise (dodge/attack): enemies within hear_range wake up.
func mark_player_noise() -> void:
	_spawn_noise = time


func player_making_noise() -> bool:
	return time - _spawn_noise < NOISE_DURATION


func record_player_position(pos: Vector3) -> void:
	memory_path.record(Vector2(pos.x, pos.z), time)


# --- Enemy events ---

func _on_event(ctrl: _CTRL, ev: String) -> void:
	match ev:
		_LOGIC.EV_DEATH:
			_log_death(ctrl)
			_emit_bus_killed(ctrl)  # the tracker counts the kill
			_free_slot(ctrl)
		_LOGIC.EV_LEAVE:
			_remnant_left(ctrl)
			_free_slot(ctrl)
		_LOGIC.EV_ANCHOR:
			_add_anchor(ctrl)
		_LOGIC.EV_STATE_CHANGED:
			# The player fled a Hollow -> MemoryStats.fled
			# (ENEMY_DESIGN §7: the runner profile is built on it).
			if _stats != null \
					and ctrl.logic().state() == _ST.State.RETREAT:
				_stats.fled += 1
		_:
			pass


func _free_slot(ctrl: Node) -> void:
	for i in range(_slots.size() - 1, -1, -1):
		if _slots[i]["ctrl"] == ctrl:
			_slots.remove_at(i)
	# The controller may still be dissolving: it frees itself.
	ctrl.queue_free()


func _add_anchor(ctrl: _CTRL) -> void:
	# The run cap is per Watcher data (<=2/run, WORLD_STATE_DESIGN §3):
	# all Watchers in the hub share the run store.
	if anchors.size() >= ctrl.data().anchors_per_run:
		return
	var a: _ANCHOR = _ANCHOR.new()
	a.position = ctrl.logic().anchor_position
	a.created_at = time
	anchors.append(a)


func _log_death(ctrl: _CTRL) -> void:
	# Drops (footprint/note/fragment) are World State (Phase 10): the
	# run-scoped log keeps them until World memory consumes them.
	var d: _DATA = ctrl.data()
	var drop: String = ""
	if d.leaves_footprint:
		drop = "footprint"
	elif d.note_on_death:
		drop = "note"
	elif d.fragment_on_death:
		drop = "fragment"
	if drop != "":
		ctrl.death_drop = drop


func _remnant_left(ctrl: _CTRL) -> void:
	if ctrl.data().archetype == _DATA.Archetype.REMNANT:
		remnant_met = true


func _emit_bus_killed(ctrl: _CTRL) -> void:
	var bus: Node = get_node_or_null("/root/EventBus")
	if bus == null or not bus.has_signal("enemy_killed"):
		return
	bus.enemy_killed.emit(ctrl.data().id, ctrl.global_position)


func get_alive_enemies() -> Array:
	var out: Array = []
	for slot in _slots:
		var ctrl: _CTRL = slot["ctrl"]
		if ctrl != null and is_instance_valid(ctrl) \
				and not ctrl.is_gone():
			out.append(ctrl)
	return out


# The player path within the Hollow's memory window (chase target
# when the player is out of sight — ENEMY_DESIGN §1.2).
func memory_last(window: float) -> Vector2:
	return memory_path.last_within(window, time)


# --- Internals ---

func _profile() -> int:
	if _stats == null or _thresholds == null:
		return _STYLE.PROFILE_NORMAL
	return _stats.aggression_profile(_thresholds)


func _style() -> int:
	if _stats == null or _thresholds == null:
		return _STYLE.STYLE_NONE
	return _stats.dominant_style(_thresholds.style_min_actions,
			_thresholds.style_dominance_pct)
