# GhostTimeline — the Passive Echo replay path (TECHNICAL_DESIGN
# section 5), pure data (unit-tested, no Nodes):
#
#   1. TIMELINE: the last run's RunRecord events -> keyframes
#      K[i] = (t, pos, ry, action). Every recorded event carries the
#      player position at that moment, so the keyframes ARE the
#      player's path (P8: positions in the run's own layout space).
#   2. REMAP INTO THE CURRENT WORLD: the layout regenerates every
#      run. A keyframe's room (found by the footprint that contains
#      it) is answered against the NEW layout by room id — same id
#      = same design (ADR-003: doorway anchors identical between
#      variants), so the position translates by the origin delta.
#      No matching room in the new layout -> the keyframe is dropped
#      and the ghost «rewinds» to the next compatible key (design:
#      «не всё помнится» — the dissolve pulse marks it).
#   3. INTERPOLATION: Catmull-Rom over positions (angle-wrapped lerp
#      over ry). The controller chases the sampled point at
#      max_speed (the speed cap lives on the mover, not the curve).
class_name GhostTimeline
extends RefCounted

const _EV = preload("res://scripts/gameplay/run/run_event.gd")
const _KF = preload("res://scripts/gameplay/echo/ghost_keyframe.gd")

# keyframes: Array[GhostKeyframe]
var keyframes: Array = []
# Rewind skips (rooms the new layout does not have) — the director
# pulses the dissolve for each.
var dropped: int = 0
var start_t: float = 0.0
var duration: float = 0.0


func keyframe_count() -> int:
	return keyframes.size()


func is_empty() -> bool:
	return keyframes.size() < 2


# Pure (unit-tested): fill this timeline with the remapped replay of
# `record` against `new_layout` (callers use their preload constant
# to instantiate — ADR-022: the rig resolves no class_names). Either
# layout null -> the events' positions are taken at face value
# (same-layout replay, the camp case).
func build(record, old_layout, new_layout) -> void:
	if record == null:
		return
	var evs: Array = record.events.duplicate()
	evs.sort_custom(func(a, b):
		return (a as _EV).t < (b as _EV).t)
	for i in evs.size():
		var ev: _EV = evs[i]
		var pos: Vector3 = Vector3(ev.x / 100.0, ev.y / 100.0,
				ev.z / 100.0)
		pos = _remap_pos(pos, old_layout, new_layout)
		if pos == Vector3.INF:
			dropped += 1
			continue
		var kf := _KF.new()
		kf.t = ev.t / 10.0
		kf.pos = pos
		kf.ry = float(ev.ry)
		kf.action = ev.type
		keyframes.append(kf)
	if keyframes.size() >= 2:
		start_t = (keyframes[0] as _KF).t
		duration = (keyframes.back() as _KF).t - start_t


# The room of the old layout that contains `pos` (footprint, 2D).
static func _room_at(pos: Vector3, layout):
	if layout == null:
		return null
	for a in layout.areas:
		var ap: Variant = layout.areas[a]
		for r in ap.rooms:
			var rp: Variant = r
			var c: Vector2 = Vector2(rp.origin.x, rp.origin.z)
			var q: Vector2 = Vector2(pos.x, pos.z)
			var s: Vector2 = (rp.room.size as Vector2) * 0.5
			if absf(q.x - c.x) <= s.x + 0.25 and absf(q.y - c.y) <= s.y \
					+ 0.25:
				return rp
	return null


static func _remap_pos(pos: Vector3, old_layout, new_layout) -> Vector3:
	if old_layout == null or new_layout == null:
		return pos
	var old_rp: Variant = _room_at(pos, old_layout)
	if old_rp == null:
		# Outside any room (the camp ring / transitions): the camp
		# layout is handcrafted and stable — keep the position.
		return pos
	var new_rp: Variant = _find_room_by_id(new_layout,
			(old_rp.room.id as StringName))
	if new_rp == null:
		return Vector3.INF  # the room is gone: rewind
	var d: Vector3 = (new_rp.origin as Vector3) \
			- (old_rp.origin as Vector3)
	return pos + d


static func _find_room_by_id(layout, room_id: StringName):
	for a in layout.areas:
		var ap: Variant = layout.areas[a]
		for r in ap.rooms:
			var rp: Variant = r
			if (rp.room.id as StringName) == room_id:
				return rp
	return null


# The replay position at time `t` (seconds, timeline-local: t=0 is
# the first keyframe). Catmull-Rom, clamped at both ends.
func sample(t: float) -> Vector3:
	if keyframes.is_empty():
		return Vector3.ZERO
	if is_empty():
		return (keyframes[0] as _KF).pos
	var lt: float = clampf(t, start_t, start_t + duration)
	for i in keyframes.size() - 1:
		var k0: _KF = keyframes[i]
		var k1: _KF = keyframes[i + 1]
		if lt <= k1.t:
			var t0: float = k0.t
			var t1: float = k1.t
			var u: float = 0.0 if t1 <= t0 else (lt - t0) / (t1 - t0)
			return _catmull_rom(_pt(keyframes, i - 1), k0.pos,
					k1.pos, _pt(keyframes, i + 2), u)
	return (keyframes.back() as _KF).pos


# The facing at `t` (deg) — angle-wrapped lerp between keyframes.
func sample_ry(t: float) -> float:
	if keyframes.is_empty():
		return 0.0
	if is_empty():
		return (keyframes[0] as _KF).ry
	var lt: float = clampf(t, start_t, start_t + duration)
	for i in keyframes.size() - 1:
		var k0: _KF = keyframes[i]
		var k1: _KF = keyframes[i + 1]
		if lt <= k1.t:
			var t0: float = k0.t
			var t1: float = k1.t
			var u: float = 0.0 if t1 <= t0 else (lt - t0) / (t1 - t0)
			var d: float = k1.ry - k0.ry
			while d > 180.0:
				d -= 360.0
			while d < -180.0:
				d += 360.0
			return fmod(k0.ry + d * u + 360.0, 360.0)
	return (keyframes.back() as _KF).ry


# The action at `t` (the type of the last keyframe at/before t) —
# the controller shows it briefly on the ghost (a swing without
# damage, section 5.4).
func action_at(t: float) -> int:
	if keyframes.is_empty():
		return -1
	var lt: float = clampf(t, start_t, start_t + duration)
	var out: int = (keyframes[0] as _KF).action
	for i in keyframes.size():
		var k: _KF = keyframes[i]
		if k.t <= lt:
			out = k.action
		else:
			break
	return out


func _pt(evs: Array, i: int) -> Vector3:
	if i < 0:
		i = 0
	if i >= evs.size():
		i = evs.size() - 1
	return (evs[i] as _KF).pos


# Uniform Catmull-Rom (the standard 0.5 form), endpoints clamped.
static func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3,
		p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t \
			+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 \
			+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
