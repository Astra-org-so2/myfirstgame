# VfxPool — preallocated impact-effect pool (TECHNICAL_DESIGN §12:
# "VFX умеренно: juice without visual noise").
#
# Prototype VFX = an emissive flash sphere (scale-up + fade, 0.25 s).
# GPU particles would blow the mobile budget and are untestable in the
# headless rig; the pool logic (fixed size, reuse, lifetime) is real and
# unit-tested — final particle VFX is Phase 13 art pass.
class_name VfxPool
extends Node3D

const POOL_SIZE: int = 8
const LIFETIME: float = 0.25

const KIND_HIT: int = 0
const KIND_RIPOSTE: int = 1
const KIND_HURT: int = 2

const _COLORS: Array[Color] = [
		Color(1.0, 0.62, 0.25),  # hit: warm
		Color(0.55, 0.9, 1.0),   # riposte: cold counter
		Color(0.85, 0.2, 0.15),  # hurt: red
]

var spawn_calls: int = 0

var _pool: Array = []  # MeshInstance3D
var _ages: Array[float] = []  # >= LIFETIME means inactive


func _ready() -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.14
	mesh.height = 0.28
	for i in POOL_SIZE:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Flash%d" % i
		mi.mesh = mesh
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = 1  # BASE_TRANSPARENCY (int: enum consts
		mat.albedo_color = Color(1.0, 0.6, 0.25, 0.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.25, 1.0)
		mat.emission_energy_multiplier = 3.0
		mi.material = mat
		mi.visible = false
		add_child(mi)
		_pool.append(mi)
		_ages.append(LIFETIME)


func spawn(pos: Vector3, kind: int) -> void:
	if _pool.is_empty():
		push_error("VfxPool.spawn before _ready")
		return
	spawn_calls += 1
	var idx: int = -1
	for i in _pool.size():
		if not _pool[i].visible:
			idx = i
			break
	if idx < 0:
		# Pool exhausted: reuse the oldest active effect (no growth).
		var oldest_age: float = -1.0
		for i in _pool.size():
			if _ages[i] > oldest_age:
				oldest_age = _ages[i]
				idx = i
	var mi: MeshInstance3D = _pool[idx]
	var c: Color = _COLORS[clampi(kind, 0, _COLORS.size() - 1)]
	var mat: StandardMaterial3D = mi.material
	mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mat.emission = c
	mi.position = pos + Vector3(0.0, 0.9, 0.0)  # chest height anchor
	mi.scale = Vector3.ONE
	mi.visible = true
	_ages[idx] = 0.0


func active_count() -> int:
	var n: int = 0
	for i in _pool.size():
		if _pool[i].visible:
			n += 1
	return n


func _physics_process(delta: float) -> void:
	for i in _pool.size():
		var mi: MeshInstance3D = _pool[i]
		if not mi.visible:
			continue
		_ages[i] += delta
		var t: float = _ages[i] / LIFETIME
		if t >= 1.0:
			mi.visible = false
			_ages[i] = LIFETIME
			continue
		mi.scale = Vector3.ONE * (1.0 + 3.0 * t)
		var mat: StandardMaterial3D = mi.material
		mat.albedo_color.a = 0.9 * (1.0 - t)
