# UiTheme — the shared UI kit (P13: "не Godot-дефолт", one source for
# every screen). The palette is the "kept place" of WORLD_BIBLE §1:
# dark matte panels, warm parchment text, the campfire as the only
# warm accent — the screens read like the world, not like a menu.
#
# Data (data/ui/ui_theme.tres): a retint is a data edit, not a code
# change. The panels get the theme from the main scene (ADR-009
# composition) and fall back to the data default in the tests.
class_name UiTheme
extends Resource

# --- Surfaces -----------------------------------------------------------
# The main panel (death cards, the note sheet, the inventory).
@export var panel_bg: Color = Color(0.10, 0.11, 0.13, 0.92)
# The quiet row/cell (inventory slots, the note rows).
@export var cell_bg: Color = Color(0.12, 0.13, 0.15, 0.90)
# The highlighted row (the existing note line).
@export var cell_bg_hi: Color = Color(0.20, 0.22, 0.26, 0.90)
# The hairline border (barely there — matte, no chrome).
@export var border: Color = Color(0.35, 0.33, 0.28, 0.60)

# --- Text (warm parchment on dark) ---------------------------------------
@export var text_bright: Color = Color(0.95, 0.92, 0.85, 1.0)  # titles
@export var text_parchment: Color = Color(0.90, 0.87, 0.80, 1.0)  # body
@export var text_dim: Color = Color(0.78, 0.77, 0.72, 1.0)  # secondary
@export var text_moss: Color = Color(0.60, 0.70, 0.60, 1.0)  # the "deeper" mark
@export var text_shadow: Color = Color(0.0, 0.0, 0.0, 0.90)

# --- Accents -------------------------------------------------------------
# The campfire (countdowns, the warm mark) — the only warm accent.
@export var accent_warm: Color = Color(0.70, 0.55, 0.40, 1.0)
# The memory (cold, for future screens).
@export var accent_cold: Color = Color(0.62, 0.66, 0.72, 1.0)
# Pain (the death bar's end, errors).
@export var danger: Color = Color(0.72, 0.30, 0.25, 1.0)

# --- Shape ---------------------------------------------------------------
@export var radius: int = 8
@export var content_margin: int = 16
@export var font_title: int = 18
@export var font_body: int = 16
@export var font_small: int = 14
@export var font_tiny: int = 12
@export var font_toast: int = 22


func panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = panel_bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(content_margin)
	return sb


func cell_style(highlight: bool = false) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = cell_bg_hi if highlight else cell_bg
	sb.set_corner_radius_all(radius / 2)
	return sb


func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if accent_warm.b >= accent_warm.r * 0.7:
		problems.append("accent_warm must be warm (the campfire rule)")
	if accent_cold.r > accent_cold.b:
		problems.append("accent_cold must be cool (the memory rule)")
	if radius < 0 or content_margin < 0:
		problems.append("shape values must be >= 0")
	return problems
