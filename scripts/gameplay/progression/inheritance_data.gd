# InheritanceData — one of the 15 Inheritances (PROGRESSION_DESIGN §1).
#
# An Inheritance is a PERMANENT gameplay change earned on the death
# screen (1 of 3, PROGRESSION_DESIGN §0). Rule: it changes GAMEPLAY,
# not "+5%" (GDD §14) — the data describes WHICH stat of WHICH system
# it bends, per level (choice = level 1, "repeat" = upgrade, max 2 →
# 3 levels; PROGRESSION_DESIGN §0/Q-P2).
#
# Pool membership is data-driven:
# - BASIC layer: always in the pool (MVP pool: 8);
# - NPC_GATED: only while the NPC is alive AND trust >= 1 — the NPC's
#   death removes it from the pool FOREVER (the permanent price, GDD §9);
# - POST_MVP: architecture-ready (incl. the behavior gate, RUNNER),
#   data-disabled for MVP (`in_mvp_pool = false`).
#
# New Inheritance = new .tres. No core rewrite (PROGRESSION_DESIGN §5/7).
class_name InheritanceData
extends Resource

enum Layer { BASIC, NPC_GATED, POST_MVP }
# Which system the effect stat belongs to (the effects resolver maps
# stat -> concrete change; ADR-025).
enum Target { BLADE, CANNON, STAFF, PLAYER, WORLD }

@export var id: StringName = &""
@export var display_name: String = ""
# The ONE line the death-screen card shows — "what it does", no numbers,
# no mechanics exposition (PROGRESSION_DESIGN §0).
@export var ui_line: String = ""
@export var layer: int = Layer.BASIC
@export_group("Gates")
# NPC gate (NPC_GATED): the npc whose life carries this Inheritance.
@export var npc_id: StringName = &""
# Behavior gate (RUNNER): memory_stats stat > threshold.
@export var behavior_stat: StringName = &""
@export var behavior_threshold: float = 0.0
# MVP pool membership (12 = 8 basic + 4 NPC-gated). Post-MVP entries
# are false (architecture-ready, data-disabled).
@export var in_mvp_pool: bool = true
@export_group("Effect (per level 1..3)")
@export var effect_target: int = Target.BLADE
@export var effect_stat: StringName = &""
@export var effect_value_1: float = 0.0
@export var effect_value_2: float = 0.0
@export var effect_value_3: float = 0.0


func effect_value(level: int) -> float:
	match level:
		1:
			return effect_value_1
		2:
			return effect_value_2
		_:
			return effect_value_3


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id == &"":
		problems.append("id must be set")
	if display_name == "" or ui_line == "":
		problems.append("display_name and the 1-line ui_line are required")
	if layer == Layer.NPC_GATED and npc_id == &"":
		problems.append("NPC-gated Inheritance needs an npc_id")
	if layer == Layer.POST_MVP and behavior_stat == &"" \
			and id != &"breaker" and id != &"paradox":
		problems.append("behavior-gated Inheritance needs behavior_stat")
	if effect_stat == &"":
		problems.append("effect_stat must be set")
	return problems
