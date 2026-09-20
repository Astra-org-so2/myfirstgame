# PatternMemory — THE FIRST learning your attacks (BOSS_DESIGN §3.2,
# the core mechanic). Pure logic (RefCounted, no scene): data-driven
# thresholds, unit-testable.
#
# The design: if the player repeats a SEQUENCE of `length` attack
# steps `threshold` times, he has "learned" it and PARRIES the next
# occurrence (the parry blocks your swing + his counter deals
# `parry_damage`). `break_steps` consecutive "not his" steps make him
# "lose the rhythm" (a stun). Symmetry (GDD §6.2): "he learns — you
# learn".
#
# A "step" is any string token (the scene feeds "<weapon>:<hit>",
# e.g. "weapon_blade:u1" / "weapon_cannon:fire"). The logic does not
# know weapons — only sequences.
class_name PatternMemory
extends RefCounted

enum Event { NONE, LEARNED, PARRY_TRIGGER, BROKEN }

const HISTORY_CAP: int = 64

var _length: int = 3
var _threshold: int = 3
var _break_steps: int = 3

# The learned sequence (empty = nothing learned yet).
var learned: PackedStringArray = PackedStringArray()
# The parry is armed after the learn; it fires on the NEXT
# completion of the sequence.
var parry_armed: bool = false
# Where we are inside the learned sequence (0 = not mid-sequence).
var _pos: int = 0
# Consecutive steps that do not continue the learned sequence.
var _off_steps: int = 0

var _history: Array = []


func setup(length: int, threshold: int, p_break_steps: int) -> void:
	_length = maxi(length, 2)
	_threshold = maxi(threshold, 2)
	_break_steps = maxi(p_break_steps, 1)
	reset()


func reset() -> void:
	learned.clear()
	parry_armed = false
	_pos = 0
	_off_steps = 0
	_history.clear()


func reset_threshold(threshold: int) -> void:
	# Phase 2: the memory sharpens (a new pattern learns faster; the
	# learned one keeps counting).
	_threshold = maxi(threshold, 2)


# Feed one player attack step. Returns the event (the scene shows the
# "look" + line on LEARNED, the parry on PARRY_TRIGGER, the stun on
# BROKEN).
func record(step: String) -> int:
	if step == "":
		return Event.NONE
	_history.append(step)
	if _history.size() > HISTORY_CAP:
		_history.remove_at(0)
	if learned.is_empty():
		return _record_learning()
	return _record_known(step)


# Unlearned: the last `length * threshold` steps are `threshold`
# back-to-back copies of the same `length`-step sequence -> learned
# (the repetitions count from the first full sequence, so the third
# repetition is the learn).
func _record_learning() -> int:
	var need: int = _length * _threshold
	if _history.size() < need:
		return Event.NONE
	var start: int = _history.size() - need
	var cand: PackedStringArray = PackedStringArray()
	for i in _length:
		cand.append(_history[start + i])
	for r in _threshold:
		for i in _length:
			if _history[start + r * _length + i] != cand[i]:
				return Event.NONE
	learned = cand
	parry_armed = true
	_pos = 0
	_off_steps = 0
	return Event.LEARNED


# Learned: walk the sequence. A full completion again = the PARRY.
# A step that does not continue it counts toward the break.
func _record_known(step: String) -> int:
	var expected: String = learned[_pos]
	if step == expected:
		_off_steps = 0
		_pos += 1
		if _pos >= _length:
			_pos = 0
			if parry_armed:
				parry_armed = false
				return Event.PARRY_TRIGGER
			return Event.NONE
		return Event.NONE
	# Not his step: the break counter grows. The step may still START
	# a fresh repetition (it equals step 0).
	_off_steps += 1
	if step == learned[0]:
		_pos = 1
	else:
		_pos = 0
	if _off_steps >= _break_steps:
		# He "loses the rhythm": the pattern is broken, re-learning
		# starts from scratch.
		learned.clear()
		parry_armed = false
		_pos = 0
		_off_steps = 0
		return Event.BROKEN
	return Event.NONE
