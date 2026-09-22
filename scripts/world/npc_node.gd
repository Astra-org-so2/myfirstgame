# NpcNode — one of the four trust NPCs of the camp (Phase 6).
#
# A primitive capsule (ADR-024: code-built visuals, per-NPC color) +
# a name label + the Interactable pattern (distance poll, held-edge,
# rig-safe). The NPC is KILLABLE (a combat target) — killing one is
# the permanent price: its Inheritance leaves the death-screen pool
# forever and the consequence becomes visible (the death line, the
# camp reaction wired by the main scene).
#
# Trust flow (PROGRESSION_DESIGN §4, the data says the thresholds):
#   talk (E): an interaction + a line for the current trust level;
#   when the NPC has met the trust-1 interactions WITHOUT the help,
#   the next (E) completes the scripted help (1 action per NPC).
# The logic is pure (NpcTrust, unit-tested); this node is the body.
class_name NpcNode
extends Node3D

# A talk happened (NPC_TALKED for the run recording; the scene
# bridges it — no cross-script Callables, ADR-022).
signal talked(npc_id: StringName)
# Phase 11: a mystery line was spoken (the scene reveals the stage).
signal mystery_line_spoken(line_id: StringName)

const _DATA = preload("res://scripts/gameplay/progression/npc_data.gd")
const _STATE = preload("res://scripts/gameplay/progression/progression_state.gd")
const _INTERACTABLE = preload("res://scripts/world/interactable.gd")
const _CT = preload("res://scripts/gameplay/combat/combat_target.gd")
const _DREQ = preload("res://scripts/gameplay/combat/damage_request.gd")
const _DLINES = preload("res://scripts/gameplay/mystery/dialogue_lines.gd")
const _DLN = preload("res://scripts/gameplay/mystery/dialogue_line.gd")
const _CV = preload("res://scripts/world/character_visual.gd")

const HP: float = 50.0

var _data: _DATA
var _state: _STATE
var _resolver: Node
var _ia: _INTERACTABLE
var _target: _CT
var _label: Label3D
var _line_left: float = 0.0
var _dead: bool = false
# The first-return line (B1) is once per run — the main scene resets
# this on respawn (reset_run_lines).
var _return_line_used: bool = false
# Phase 11: the mystery-line table (data/dialogue) + the used-up
# line ids (one-shot per session; the scene owns the table).
var mystery_lines: _DLINES = null
var _mystery_used: Dictionary = {}
# The main scene feeds the current run id (reset_run_lines + the
# start of the session).
var current_run_id: int = 1


# `custom_visual` (optional): a richer look to adopt (Mara keeps her
# Phase 3 model) instead of the generic capsule.
# The texture bank (the main scene sets it before setup();
# null = flat fallback in the tests).
var textures: Variant = null


func setup(data: _DATA, state: _STATE, resolver: Node, player: Node,
		custom_visual: Node = null) -> void:
	_data = data
	_state = state
	_resolver = resolver
	if custom_visual != null:
		add_child(custom_visual)  # reparent: keeps the global position
		if textures != null:
			_reskin_custom(custom_visual)
	else:
		_build_visual_body()
	_build_label()
	_ia = _INTERACTABLE.new()
	_ia.name = "IA_" + String(_data.npc_id)
	_ia.prompt = tr("Talk to %s (E)") % _data.display_name
	_ia.interact_radius = 2.4
	add_child(_ia)
	_ia.set_target(player)
	_ia.interacted.connect(_on_interacted)
	# The NPC is a combat target (killable — the price is permanent).
	_target = _CT.new(self, HP)
	_target.combat_id = &"npc_" + String(_data.npc_id)
	if resolver != null:
		resolver.register(self, _target)
		_target.killed.connect(_on_killed)


# The scene feeds the mystery-line table + the current run id
# (session start and every respawn).
func set_mystery_wiring(lines: _DLINES, run_id: int) -> void:
	mystery_lines = lines
	current_run_id = run_id


func get_data() -> _DATA:
	return _data


func is_dead() -> bool:
	return _dead


# The line currently shown (the NPC's name after the 3 s window).
# QA/test seam for the scripted beats (A8/B1).
func current_line() -> String:
	return _label.text


func get_trust() -> int:
	var e: Dictionary = _state.ws.npc_entry(_data.npc_id)
	return _state.trust.trust_level(e, _data, _state.stats)


func _build_visual_body() -> void:
	# Phase 13: the shared character language (CharacterVisual) —
	# the cloth is the data color, the accent is the character's
	# idea (Mara = ember, Orren = grey-blue, ...).
	var look: Dictionary = {
		"cloth": _data.visual_color,
		"accent": _data.accent_color,
		"hood": _data.has_hood,
		"scarf": true,
	}
	var v: Node3D = _CV.build(self, look, textures)
	add_child(v)


# The custom look (Mara's camp visual): the cloth on the coat/hood.
func _reskin_custom(v: Node) -> void:
	var coat: Color = Color(0.3, 0.26, 0.2)
	for part in ["Body", "Hood"]:
		# The custom visual is the MaraAnchor wrapper (the look is
		# one level down), so search, not path.
		var n: Node = v.find_child(part, true, false)
		if n == null or not (n is MeshInstance3D):
			continue
		var m: StandardMaterial3D = textures.material("cloth", coat, 0.9)
		if m != null:
			(n as MeshInstance3D).mesh.material = m


func _build_label() -> void:
	_label = Label3D.new()
	_label.text = _data.display_name
	_label.position = Vector3(0.0, 2.2, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 4
	_label.modulate = Color(0.95, 0.93, 0.88, 0.95)
	add_child(_label)


func _on_interacted(_ia_node: Node) -> void:
	var e: Dictionary = _state.ws.npc_entry(_data.npc_id)
	if not bool(e.alive):
		_show_line(_data.death_consequence)
		return
	# The scripted help: it opens once the interactions are in and the
	# help hasn't been given (the data says when).
	var needs_help: bool = not bool(e.help_done) \
			and int(e.interactions) >= _data.trust_1_interactions
	if needs_help:
		var level: int = _state.trust.complete_help(e, _data, _state.stats)
		_show_line(_help_line(level))
		talked.emit(_data.npc_id)
		return
	var level: int = _state.trust.interact(e, _data, _state.stats)
	_show_line(_line_for(level, e))
	talked.emit(_data.npc_id)


func _line_for(level: int, e: Dictionary) -> String:
	# Phase 11 (MYSTERY_REVEAL_MAP): the mystery-line layer — the
	# data table (DIALOGUE_DATA) is evaluated first (table order =
	# priority); a match replaces the trust line for this talk.
	var ml: _DLN = _mystery_line()
	if ml != null:
		return _speak_mystery_line(ml)
	# K7 (WORLD_STATE_DESIGN section 6): post-boss the world is
	# quieter — the NPC line changes (npc_calm).
	if _data.post_boss_line != "" and _state.ws.flag(
			&"boss_defeated"):
		return _data.post_boss_line
	# B1: the first talk of a run after the first death — the NPC
	# remembers the run that "didn't happen" (GDD §7).
	if not _return_line_used and _data.first_return_line != "" \
			and _state.ws.flag(&"first_death_done"):
		_return_line_used = true
		return _data.first_return_line
	# A8: the second talk at trust 0 (one extra beat before trust 1).
	if level == 0 and int(e.interactions) >= 2 \
			and _data.dialogue_0b != "":
		return _data.dialogue_0b
	return _data.dialogue_for(level)


# The main scene calls this on respawn (a new run begins).
func reset_run_lines() -> void:
	_return_line_used = false


func _mystery_line() -> _DLN:
	if mystery_lines == null or _state == null:
		return null
	return mystery_lines.for_char(_data.npc_id, _state.ws,
			current_run_id, _mystery_used)


func _speak_mystery_line(ml: _DLN) -> String:
	mystery_lines.mark_used(ml, _mystery_used)
	if ml.flag_set != &"":
		_state.ws.set_flag(ml.flag_set)
	mystery_line_spoken.emit(ml.id)
	return ml.text


func _help_line(new_level: int) -> String:
	# One line for the favor (dry, no exposition; the CHARACTER_BIBLE
	# owns the deep lines, these are the camp stubs for the MVP).
	match String(_data.npc_id):
		&"mara":
			return "The wood. There. ...Thank you. (the fire takes it easy)"
		&"orren":
			return "One watch, together. The trails will remember."
		&"nia":
			return "Any page. All pages. ...I read them with you."
		&"cartographer":
			return "The lie was a road I drew twice. Fixed."
		_:
			return _data.dialogue_for(new_level)


func _show_line(text: String) -> void:
	_label.text = text
	_line_left = 3.0


func _physics_process(delta: float) -> void:
	if _line_left > 0.0:
		_line_left -= delta
		if _line_left <= 0.0:
			_label.text = _data.display_name


func _on_killed() -> void:
	if _dead:
		return
	_dead = true
	# The PERMANENT price (GDD §9): trust resets and the Inheritance
	# leaves the pool forever (the pool reads this state on every
	# death screen).
	var e: Dictionary = _state.ws.npc_entry(_data.npc_id)
	_state.trust.kill(e)
	_state.ws.set_flag(_data.death_flag)
	_label.text = _data.death_consequence
	_line_left = 6.0
	var bus: Node = get_tree().root.get_node_or_null("EventBus")
	if bus != null and bus.has_signal("npc_died"):
		bus.npc_died.emit(_data.npc_id, global_position)
