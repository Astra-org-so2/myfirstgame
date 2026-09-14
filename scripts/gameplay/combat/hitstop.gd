# HitStop — global micro-freeze on impact (GDD §6.2 feel).
#
# Implemented as a delta scaler, NOT SceneTree time scaling: the scene
# root feeds gameplay nodes with `hitstop.update(real_delta)` (0.0 while
# frozen). Works identically in the headless rig (manual clock) and the
# engine, and never touches the harness pump (ADR-022: rig time is not
# trusted for game logic).
class_name HitStop
extends RefCounted

var _remaining: float = 0.0


func freeze(duration: float) -> void:
	if duration > 0.0:
		_remaining = maxf(_remaining, duration)


func is_frozen() -> bool:
	return _remaining > 0.0


# Returns the delta gameplay nodes should consume this tick.
func update(delta: float) -> float:
	if _remaining > 0.0:
		_remaining = maxf(0.0, _remaining - delta)
		return 0.0
	return delta
