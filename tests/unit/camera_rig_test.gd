# Unit: CameraRig — pure orbit math (Phase 2). No physics/render needed:
# offset/FOV/input mapping are static/plain functions (wall-collision path
# is verified by device QA, see qa_phase2_movement.md).
# Cross-file references via preload-consts (ADR-022).
extends Node

const _RIG = preload("res://scripts/player/camera_rig.gd")


func run(ctx: Variant) -> void:
	var EPS: float = 0.001

	# --- input_to_world: yaw = 0 (facing -Z) ---
	var rig: Node3D = _make_rig()
	var cr: _RIG = rig
	cr.yaw = 0.0
	ctx.check(cr.input_to_world(Vector2(0.0, 1.0)).is_equal_approx(
			Vector3(0.0, 0.0, -1.0)), "camera: yaw=0 forward = -Z")
	ctx.check(cr.input_to_world(Vector2(1.0, 0.0)).is_equal_approx(
			Vector3(1.0, 0.0, 0.0)), "camera: yaw=0 right = +X")
	ctx.check(cr.input_to_world(Vector2.ZERO) == Vector3.ZERO,
			"camera: zero input = zero dir")

	# --- yaw = 90 deg (facing -X) ---
	cr.yaw = PI / 2.0
	ctx.check(cr.input_to_world(Vector2(0.0, 1.0)).is_equal_approx(
			Vector3(-1.0, 0.0, 0.0)), "camera: yaw=90 forward = -X")
	ctx.check(cr.input_to_world(Vector2(1.0, 0.0)).is_equal_approx(
			Vector3(0.0, 0.0, -1.0)), "camera: yaw=90 right = -Z")

	# --- orbit offset ---
	var off: Vector3 = _RIG.compute_offset(0.0, 0.0, 4.5)
	ctx.check(off.is_equal_approx(Vector3(0.0, 0.0, 4.5)),
			"camera: offset(yaw=0, pitch=0) = +Z (behind player)")
	off = _RIG.compute_offset(PI / 2.0, 0.0, 4.5)
	ctx.check(off.is_equal_approx(Vector3(4.5, 0.0, 0.0)),
			"camera: offset(yaw=90) = +X")
	off = _RIG.compute_offset(0.0, PI / 2.0, 4.5)
	ctx.check(absf(off.y - 4.5) < EPS and absf(off.z) < EPS,
			"camera: offset(pitch=90) = straight up")

	# --- pitch clamp via rotate() (screen y-down: negative dy = drag up) ---
	cr.yaw = 0.0
	cr.pitch = 0.0
	cr.orbit(Vector2(0.0, -100000.0))  # drag up -> pitch to max
	ctx.check(absf(cr.pitch - cr.pitch_max) < EPS,
			"camera: pitch clamped at max")
	cr.orbit(Vector2(0.0, 100000.0))  # drag down -> pitch to min
	ctx.check(absf(cr.pitch - cr.pitch_min) < EPS,
			"camera: pitch clamped at min")

	# --- drag direction: drag right orbits right (yaw decreases) ---
	var yaw0: float = cr.yaw
	cr.orbit(Vector2(100.0, 0.0))
	ctx.check(cr.yaw < yaw0, "camera: drag right -> yaw decreases")

	# --- FOV compensation on collision ---
	ctx.check(absf(_RIG.compute_fov(4.5, 4.5) - 60.0) < EPS,
			"camera: no collision -> base FOV")
	var fov_close: float = _RIG.compute_fov(4.5, 2.25)
	ctx.check(fov_close > 60.0,
			"camera: closer -> wider FOV (got %.1f)" % fov_close)
	var fov_floor: float = _RIG.compute_fov(4.5, 0.1)
	ctx.check(fov_floor <= _RIG.compute_fov(4.5, 0.75) + EPS,
			"camera: FOV bounded at min distance")

	rig.free()


func _make_rig() -> Node3D:
	var packed: PackedScene = load("res://scenes/player/CameraRig.tscn")
	var node: Node = packed.instantiate()
	add_child(node)
	return node
