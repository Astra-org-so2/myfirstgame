# QualityPreset — the mobile rendering tiers (TECHNICAL_DESIGN §12).
#
# data-driven (data/quality/{low,medium,high}.tres): the same world,
# three budgets. The reference hardware is a mid-range Android
# (ADR-021); Low is the low-end floor. The QualityManager applies a
# preset at runtime and exposes the budgets the scene builders read
# (the local-light budget is enforced per level by ZoneWorld).
class_name QualityPreset
extends Resource

@export var id: StringName = &"medium"
@export var display_name: String = "Medium"
# Viewport render scale (0.75 = the performance mode, §12).
@export var render_scale: float = 1.0
# The sun's shadows (Low: off — the biggest single mobile cost).
@export var shadows_enabled: bool = true
# The directional shadow atlas (4x4 splits, High).
@export var shadow_atlas_4x4: bool = false
# Soft shadow filter (Ultra, §12 "High + soft shadows + VFX 125%").
@export var soft_shadows: bool = false
# Active LOCAL lights per level (Low 3 / Medium 4 / High 6, §12).
@export var local_light_budget: int = 4
# VFX emission scaling (particles arrive with P14; the knob is here).
@export var particle_scale: float = 0.75
# MSAA: 1 = off, 2 = 2x (High only).
@export var msaa: int = 1
# ASTC texture size cap (import-time, for the owner's asset pass).
@export var texture_max_size: int = 1024


func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if render_scale < 0.5 or render_scale > 1.0:
		problems.append("render_scale must be 0.5..1.0")
	if local_light_budget < 1 or local_light_budget > 6:
		problems.append("local_light_budget must be 1..6 (§12)")
	if particle_scale < 0.25 or particle_scale > 1.25:
		problems.append("particle_scale must be 0.25..1.25")
	if msaa not in [1, 2, 4]:
		problems.append("msaa must be 1/2/4")
	if texture_max_size not in [256, 512, 1024, 2048]:
		problems.append("texture_max_size must be a power of two, 256..2048")
	return problems
