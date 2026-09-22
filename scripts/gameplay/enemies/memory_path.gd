# MemoryPath — a fixed-size ring buffer of (position, time) samples:
# the player's recent path, consumed by enemies with memory (Hollow
# chases the last remembered position — ENEMY_DESIGN §1.2) and by the
# Run data (Phase 8/10). Pure and bounded (no unbounded growth).
class_name MemoryPath
extends RefCounted

const MAX_SAMPLES: int = 128

var _pos: PackedVector2Array
var _time: PackedFloat64Array
var _head: int = 0  # next write slot
var _size: int = 0


func record(pos: Vector2, time: float) -> void:
	if _pos.size() < MAX_SAMPLES:
		_pos.append(pos)
		_time.append(time)
		_size += 1
	else:
		# Wrap: overwrite the oldest slot.
		_pos[_head] = pos
		_time[_head] = time
	_head = (_head + 1) % MAX_SAMPLES


# Samples within `time - window .. time`, oldest first.
func points_within(window: float, time: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	var start: int = (_head - _size + MAX_SAMPLES) % MAX_SAMPLES
	for i in range(_size):
		var idx: int = (start + i) % MAX_SAMPLES
		if _time[idx] > time - window:
			out.append(_pos[idx])
	return out


# The most recent sample within the window (the chase target), or
# Vector2.INF when the memory is empty/expired.
func last_within(window: float, time: float) -> Vector2:
	var pts: PackedVector2Array = points_within(window, time)
	return Vector2.INF if pts.is_empty() else pts[pts.size() - 1]


func clear() -> void:
	_pos.clear()
	_time.clear()
	_head = 0
	_size = 0


func size() -> int:
	return _size
