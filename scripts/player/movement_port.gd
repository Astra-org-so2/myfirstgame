# MovementPort — the seam between PlayerController logic and the physics
# world (ARCHITECTURE §3.4, ADR-002).
#
# One class, two backends (no cross-file inheritance is possible in the
# headless wasm rig — see ADR-022):
# - body != null: ENGINE mode — real CharacterBody3D calls (production);
# - body == null: MOCK mode — pure-math model (gravity, flat floor at
#   floor_y, AABB walls) used by headless tests (the wasm rig has no 3D
#   physics, so movement logic is tested through mock mode).
class_name MovementPort
extends RefCounted

const EPS: float = 0.001

var _body: CharacterBody3D
var _gravity: float
var _max_fall: float

# Mock-mode state.
var _pos: Vector3
var _vel: Vector3
var floor_y: float = 0.0
var walls: Array[AABB] = []
var _on_ground: bool = false
var _on_wall: bool = false


func _init(body: CharacterBody3D = null, gravity: float = 24.0,
		max_fall_speed: float = 20.0) -> void:
	_body = body
	_gravity = gravity
	_max_fall = max_fall_speed
	if body == null:
		_pos = Vector3.ZERO
		_on_ground = true


func is_mock() -> bool:
	return _body == null


# Mock mode only: register an AABB wall (resolved on integrate).
func add_wall(box: AABB) -> void:
	walls.append(box)


func apply_gravity(delta: float) -> void:
	if _body != null:
		_body.velocity.y = maxf(_body.velocity.y - _gravity * delta, -_max_fall)
	else:
		_vel.y = maxf(_vel.y - _gravity * delta, -_max_fall)


func move(velocity: Vector3) -> void:
	if _body != null:
		_body.velocity = velocity
		_body.move_and_slide()
	else:
		_vel = velocity


func integrate(delta: float) -> void:
	if _body != null:
		return  # the engine integrates inside move_and_slide
	# Mock integration: explicit position stepping + floor/wall resolution.
	_pos += _vel * delta
	_on_wall = false
	if _pos.y <= floor_y:
		_pos.y = floor_y
		if _vel.y < 0.0:
			_vel.y = 0.0
	_on_ground = _pos.y <= floor_y + EPS
	for box in walls:
		var p: Vector3 = _pos
		if p.x > box.position.x and p.x < box.end.x \
				and p.y > box.position.y and p.y < box.end.y \
				and p.z > box.position.z and p.z < box.end.z:
			var dx_min: float = minf(p.x - box.position.x, box.end.x - p.x)
			var dy_min: float = minf(p.y - box.position.y, box.end.y - p.y)
			var dz_min: float = minf(p.z - box.position.z, box.end.z - p.z)
			var center: Vector3 = box.get_center()
			if dx_min <= dy_min and dx_min <= dz_min:
				_pos.x = box.position.x if p.x < center.x else box.end.x
				_vel.x = 0.0
				_on_wall = true
			elif dy_min <= dz_min:
				_pos.y = box.position.y if p.y < center.y else box.end.y
				_vel.y = 0.0
			else:
				_pos.z = box.position.z if p.z < center.z else box.end.z
				_vel.z = 0.0
				_on_wall = true


func get_velocity() -> Vector3:
	return _body.velocity if _body != null else _vel


func is_on_ground() -> bool:
	return _body.is_on_floor() if _body != null else _on_ground


func is_on_wall() -> bool:
	return _body.is_on_wall() if _body != null else _on_wall


func get_position() -> Vector3:
	return _body.global_position if _body != null else _pos


func set_position(pos: Vector3) -> void:
	if _body != null:
		_body.global_position = pos
	else:
		_pos = pos
		_on_ground = _pos.y <= floor_y + EPS
