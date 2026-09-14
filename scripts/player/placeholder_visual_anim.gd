# PlaceholderVisualAnim — procedural animation for the primitive placeholder
# character (ADR-005: prototype art by code, intentional).
#
# A pure function of (state, progress, delta): idle/walk bob, run lean,
# dodge lurch, hurt flash (albedo lerp on the primitive materials).
# Replaced by rig + AnimationPlayer in Phase 13 when the final character
# asset lands (ASSET_GUIDE §4).
#
# Rig note: no sinf/cosf (missing globals in the wasm rig — ADR-022);
# Node3D has no `modulate` (CanvasItem-only), so the hurt flash lerps the
# mesh materials' albedo (scene-local sub-resources — safe to mutate).
class_name PlaceholderVisualAnim
extends Node3D

const _STATE = preload("res://scripts/player/player_state.gd")

const HURT_FLASH := Color(1.0, 0.35, 0.3, 1.0)

var _time: float = 0.0
var _hurt_time: float = 0.0
var _body_mat: StandardMaterial3D
var _visor_mat: StandardMaterial3D
var _body_mat_base: Color
var _visor_mat_base: Color


func _ready() -> void:
	var bm: MeshInstance3D = get_node_or_null("Body/BodyMesh")
	var vm: MeshInstance3D = get_node_or_null("Body/Visor")
	if bm == null or vm == null:
		push_error("PlaceholderVisualAnim: missing Body/BodyMesh or Body/Visor")
		return
	_body_mat = bm.material
	_visor_mat = vm.material
	if _body_mat is StandardMaterial3D:
		_body_mat_base = _body_mat.albedo_color
	if _visor_mat is StandardMaterial3D:
		_visor_mat_base = _visor_mat.albedo_color


func update(state: int, delta: float,
		dodge_progress: float, hurt_progress: float) -> void:
	_time += delta
	if state == _STATE.State.HURT:
		_hurt_time += delta

	var body: Node3D = get_node_or_null("Body")
	if body == null:
		push_error("PlaceholderVisualAnim: missing Body child")
		return
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE

	# Hurt flash on the whole visual (0..1, decays over ~0.35 s).
	var flash: float = clampf(1.0 - _hurt_time / 0.35, 0.0, 1.0)
	if _body_mat != null:
		_body_mat.albedo_color = _body_mat_base.lerp(HURT_FLASH, flash)
	if _visor_mat != null:
		_visor_mat.albedo_color = _visor_mat_base.lerp(HURT_FLASH, flash)

	match state:
		_STATE.State.IDLE:
			body.position.y = 0.02 * sin(_time * 2.0)
		_STATE.State.WALK:
			body.position.y = 0.04 * abs(sin(_time * 7.0))
		_STATE.State.RUN:
			body.position.y = 0.06 * abs(sin(_time * 9.5))
			body.rotation.x = -0.07
		_STATE.State.DODGE:
			# Lurch + squash, strongest mid-dodge.
			var mid: float = 1.0 - abs(dodge_progress * 2.0 - 1.0)
			body.position.y = 0.05
			body.rotation.x = -0.35 * mid
			body.scale = Vector3(1.0 + 0.15 * mid, 1.0 - 0.18 * mid,
					1.0 + 0.15 * mid)
		_STATE.State.HURT:
			var p: float = clampf(hurt_progress, 0.0, 1.0)
			body.rotation.x = -0.2 * sin(p * PI)
			body.rotation.z = 0.18 * sin(p * PI)
			body.position.y = -0.05 * sin(p * PI)
		_:
			pass
