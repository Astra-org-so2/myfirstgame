# HurtVignette — the "hit by something" screen feedback (GDD §6.1:
# "Урон по игроку: hit-stop, shake, vignette, knockback").
#
# Prototype: a full-screen red tint that fades exponentially (0.35 s).
# A real vignette texture/shader is Phase 13 art; the trigger/fade logic
# is real and unit-testable.
class_name HurtVignette
extends CanvasLayer

const FADE_RATE: float = 6.0  # 1/s exponential
const MAX_ALPHA: float = 0.45

var _rect: ColorRect
var _alpha: float = 0.0


func _ready() -> void:
	layer = 10
	_rect = ColorRect.new()
	_rect.name = "Tint"
	_rect.color = Color(0.55, 0.05, 0.05, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func flash(intensity: float) -> void:
	_alpha = MAX_ALPHA * clampf(intensity, 0.0, 1.0)


func get_alpha() -> float:
	return _alpha


func _process(delta: float) -> void:
	if _alpha > 0.0:
		_alpha = maxf(0.0, _alpha * exp(-FADE_RATE * delta))
	_rect.color.a = _alpha
