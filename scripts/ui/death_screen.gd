# DeathScreen — the "1 of 3" choice (PROGRESSION_DESIGN §0, Phase 6).
#
# Death is a TRANSITION, not a penalty (GDD §8): the screen shows 3
# cards (name + the 1-line "what it does", no numbers, no mechanics
# exposition). The player picks ONE (permanent) — or the world picks
# for them after the 8 s window ("the world remembers your style";
# ambiguity, not punishment). UX budget: death -> respawn <= 2 s
# technically / <= 10 s with this screen (GDD §12).
#
# Code-built custom Controls (no Button dependency — the headless rig
# must instantiate it; ADR-002). Cards are plain Controls with a
# `press()` API (the integration test clicks them directly —
# deterministic, no input-event flakiness).
class_name DeathScreen
extends CanvasLayer

const TIMEOUT: float = 8.0
const FADE: float = 0.25

var _root: Control
var _cards: Array = []  # [{control, data, line, level}]
var _bar: ColorRect
var _pending: bool = false
var _left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

signal choice_made(data: Resource)


var _bar_max: float = 0.0


func _ready() -> void:
	layer = 20
	_root = Control.new()
	add_child(_root)
	visible = false


# Show the 3 cards. `levels[i]` = the level the pick would grant
# (0 = new, 2/3 = a repeat of level 1/2) — precomputed by the caller
# (no cross-script Callables — ADR-022). The choice goes out as a
# signal; the caller applies it PERMANENTLY and closes the run gap.
# Layout is absolute pixels at show time (mobile: no window resize
# mid-run; the CanvasLayer covers the whole viewport).
func show_offers(offers: Array, levels: Array, seed: int) -> void:
	if offers.size() == 0:
		return
	_rng.seed = seed
	_pending = true
	_left = TIMEOUT
	_cards.clear()
	for c in _root.get_children():
		c.queue_free()
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if screen.x < 1.0:
		screen = Vector2(360.0, 640.0)  # headless boot: a sane phone size
	var n: int = offers.size()
	var card_w: float = screen.x * 0.24
	var gap: float = screen.x * 0.04
	var total: float = card_w * n + gap * (n - 1) if n > 0 else 0.0
	var x: float = (screen.x - total) * 0.5
	var y: float = screen.y * 0.30
	var card_h: float = screen.y * 0.40
	for i in n:
		var d: Resource = offers[i]
		var level: int = int(levels[i]) if i < levels.size() else 0
		var card: Control = _make_card(d, level,
				Rect2(x, y, card_w, card_h))
		_root.add_child(card)
		_cards.append({"control": card, "data": d})
		x += card_w + gap
	# The countdown bar.
	_bar = ColorRect.new()
	_bar.color = _th().accent_warm
	_bar.color.a = 0.8
	_bar.position = Vector2(screen.x * 0.3, screen.y * 0.74)
	_bar_max = screen.x * 0.4
	_bar.size = Vector2(_bar_max, maxf(2.0, screen.y * 0.008))
	_root.add_child(_bar)
	visible = true


var _theme: Variant = null  # the UiTheme kit (lazy: data default)


func _th() -> Variant:
	if _theme == null:
		_theme = load("res://data/ui/ui_theme.tres")
	return _theme

func _make_card(d: Resource, level: int, rect: Rect2) -> Control:
	var card: Control = Control.new()
	card.position = rect.position
	card.size = rect.size
	var w: float = rect.size.x
	var h: float = rect.size.y
	var bg: ColorRect = ColorRect.new()
	bg.color = _th().panel_bg
	bg.position = Vector2.ZERO
	bg.size = rect.size
	card.add_child(bg)
	var title: Label = Label.new()
	title.text = d.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", _th().font_title)
	title.add_theme_color_override("font_color", _th().text_bright)
	title.position = Vector2(w * 0.08, h * 0.10)
	title.size = Vector2(w * 0.84, h * 0.16)
	card.add_child(title)
	var line: Label = Label.new()
	line.text = d.ui_line
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", _th().font_small)
	line.add_theme_color_override("font_color", _th().text_parchment)
	line.position = Vector2(w * 0.10, h * 0.30)
	line.size = Vector2(w * 0.80, h * 0.44)
	card.add_child(line)
	if level >= 2:
		var lv: Label = Label.new()
		lv.text = "(deeper: level %d)" % level
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lv.add_theme_font_size_override("font_size", _th().font_tiny)
		lv.add_theme_color_override("font_color", _th().text_moss)
		lv.position = Vector2(w * 0.08, h * 0.80)
		lv.size = Vector2(w * 0.84, h * 0.12)
		card.add_child(lv)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var idx: int = _cards.size()
	card.gui_input.connect(_on_card_input.bind(idx))
	return card


func _on_card_input(event: InputEvent, idx: int) -> void:
	# Touch is the primary input (mobile-first): a touch-down picks;
	# the mouse works too (dev convenience).
	var picked: bool = false
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		picked = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	else:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		picked = st != null and st.pressed
	if picked:
		press(idx)


# The programmatic click (tests) / the touch path.
func press(idx: int) -> void:
	if not _pending or idx < 0 or idx >= _cards.size():
		return
	var d: Resource = _cards[idx]["data"]
	_close()
	choice_made.emit(d)


func _close() -> void:
	_pending = false
	visible = false


func _process(delta: float) -> void:
	if not _pending:
		return
	_left -= delta
	if _bar != null:
		_bar.size.x = _bar_max * clampf(_left / TIMEOUT, 0.0, 1.0)
	if _left <= 0.0:
		# The world chooses (deterministic under the scene seed).
		var idx: int = _rng.randi_range(0, maxi(0, _cards.size() - 1))
		press(idx)
