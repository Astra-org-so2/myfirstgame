# QualityManager — applies a QualityPreset to the running scene
# (TECHNICAL_DESIGN §12, ADR-021 mobile-first).
#
# Scene-composed (not an autoload, ADR-009): the main scene owns it
# and passes the environment/sun/viewport. The scene builders read
# the budgets from it (ZoneWorld enforces the local-light budget
# per level). Presets are data (data/quality/*.tres) — a new tier
# is a new .tres, no core changes.
class_name QualityManager
extends Node

const _PRESET = preload("res://scripts/world/quality_preset.gd")

signal preset_changed(id: StringName)

var preset: _PRESET = null
var _env: Environment = null
var _sun: DirectionalLight3D = null
var _viewport: Node = null


func setup(p: _PRESET, env: Environment, sun: DirectionalLight3D,
		viewport: Node) -> void:
	preset = p
	_env = env
	_sun = sun
	_viewport = viewport
	apply()


func set_preset(p: _PRESET) -> void:
	if p == null:
		return
	preset = p
	apply()


func apply() -> void:
	if preset == null:
		return
	if _viewport != null:
		# Production-only in the rig (see above).
		_viewport.render_scale = preset.render_scale
	if _sun != null:
		# set_shadow/has_shadow are the rig-registered pair (the
		# property form is a no-op in the headless wasm build).
		_sun.set_shadow(preset.shadows_enabled)
		# Production-only: the headless rig's bridge does not register
		# this setter (device QA, P16 checklist).
		_sun.shadow_atlas_4x4 = preset.shadow_atlas_4x4
	if _env != null:
		# Environment.MSAA_DISABLED=1 / MSAA_2X=2 / MSAA_4X=4.
		# Production-only in the rig (see above).
		_env.msaa = preset.msaa
	preset_changed.emit(preset.id)


func light_budget() -> int:
	return preset.local_light_budget if preset != null else 6


func particle_scale() -> float:
	return preset.particle_scale if preset != null else 1.0


func shadows_enabled() -> bool:
	return preset.shadows_enabled if preset != null else true
