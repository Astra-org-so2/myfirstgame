# Toast — one fading line of world text (Phase 6).
#
# The "no exposition dump" surface (GDD §13): NPC dialogue lines,
# pickup notes, the camp fire's verdict. One line at a time, ~3 s,
# then gone. Code-built Control (ADR-024) — the same explicit
# position/size pattern as the touch buttons (the headless rig has
# no theme/UI server quirks to fight; ADR-002).
class_name Toast
extends CanvasLayer

const LIFE: float = 3.0

var _label: Label
var _left: float = 0.0
var _placed: bool = false


var _theme: Variant = null  # the UiTheme kit (lazy: data default)


func _th() -> Variant:
	if _theme == null:
		_theme = load("res://data/ui/ui_theme.tres")
	return _theme


func _ready() -> void:
	layer = 10
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", _th().font_toast)
	_label.add_theme_color_override("font_color", _th().text_parchment)
	_label.add_theme_color_override("font_shadow_color", _th().text_shadow)
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_label)
	visible = false


# Show (or replace) the line. `life` (optional): the read window —
# the default 3 s suits short lines; the note beats (A7/A15/A16) get
# a longer window (FIRST_30_MINUTES read times).
func show_text(text: String, life: float = LIFE) -> void:
	_ensure_placed()
	_label.text = text
	_left = life
	visible = true


func is_visible_now() -> bool:
	return visible and _left > 0.0


# The line currently shown ("" when hidden). QA/test seam for the
# scripted beats (A2/A15/A16/A19, B2).
func current_text() -> String:
	if not is_visible_now():
		return ""
	return _label.text


func _ensure_placed() -> void:
	if _placed:
		return
	_placed = true
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var rect: Rect2 = vp.get_visible_rect()
	if rect.size.x <= 1.0:
		return  # no viewport size yet (headless boot): skip the layout
	var w: float = _label.get_minimum_size().x
	_label.position = Vector2(maxf(16.0, (rect.size.x - w) * 0.5), rect.size.y * 0.12)
	_label.size = Vector2(minf(w + 32.0, rect.size.x - 32.0), 40.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_left -= delta
	if _left <= 0.0:
		visible = false
	else:
		_label.modulate.a = clampf(_left / (LIFE * 0.5), 0.0, 1.0)
