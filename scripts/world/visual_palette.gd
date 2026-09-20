# VisualPalette — the world's colors (WORLD_BIBLE §1, text-first).
#
# One named palette, one source of truth: rooms, props, characters,
# the UI kit and the generated textures all reference these colors.
# The rule (WORLD_BIBLE §1): warm = home/life, cold = memory/keeping.
# Before the boss there is exactly ONE warm source (the campfire);
# after the boss the world "warms" (K7, WORLD_STATE_DESIGN §6).
#
# Layer tints (§1.1) are multipliers applied on top of a material's
# albedo (they are not palette entries — they are operations).
class_name VisualPalette
extends Resource

# --- Base (muted) -------------------------------------------------------
@export var forest: Color = Color(0.36, 0.40, 0.33)      # muted green-grey
@export var stone: Color = Color(0.40, 0.42, 0.46)       # arena / ruins
@export var wood_dark: Color = Color(0.28, 0.21, 0.15)   # ancient timber
@export var ground: Color = Color(0.30, 0.32, 0.28)      # paths / camp dirt
@export var fog_blue: Color = Color(0.32, 0.34, 0.38)    # the grey-blue fog

# --- Accents -------------------------------------------------------------
# The ONLY warm light before the boss (WORLD_BIBLE §1).
@export var ember_amber: Color = Color(1.0, 0.62, 0.28)
# Archivist / shrine / echo: the cold white.
@export var cold_white: Color = Color(0.88, 0.92, 0.98)
# Pain-memory: rust lines and stains (not pools).
@export var rust: Color = Color(0.45, 0.16, 0.13)
# Post-boss: the city's far light (K7).
@export var city_glow: Color = Color(0.75, 0.80, 0.95)

# --- Characters -----------------------------------------------------------
# Eli (the player) and the First (his worn copy).
@export var eli_cloak: Color = Color(0.42, 0.40, 0.36)
@export var eli_scarf: Color = Color(0.55, 0.44, 0.32)
# Eli's visor: the cold light he keeps up (his identity).
@export var eli_visor: Color = Color(0.50, 0.90, 0.95)
# THE FIGURE (the gate's silhouette): a FRESH copy of Eli
# (GDD §8 — no "worn" material; the "who came first" question).
@export var eli_fresh: Color = Color(0.82, 0.80, 0.76)
@export var first_worn: Color = Color(0.55, 0.53, 0.50)
# The Child: a pale presence (invulnerable, WORLD_BIBLE §4).
@export var child_pale: Color = Color(0.80, 0.84, 0.82)

# --- Layer tints (multipliers, §1.1) --------------------------------------
# Echo: desaturated + emissive (the emitter is a separate material).
@export var echo_tint: Color = Color(0.62, 0.66, 0.72)
# Corruption: the unnatural shift (Forgotten).
@export var corruption_tint: Color = Color(0.72, 0.44, 0.62)
# Memory: the pale glow (a 1 s shimmer, WORLD_STATE_DESIGN §6.7).
@export var memory_glow: Color = Color(0.85, 0.90, 0.95)


func validate() -> PackedStringArray:
	var problems: PackedStringArray = []
	if ember_amber.b >= ember_amber.r * 0.5:
		problems.append("ember_amber must be warm (r > 0.5*b)")
	if city_glow.r > city_glow.b:
		problems.append("city_glow must be cool (b >= r)")
	if cold_white.r >= cold_white.b:
		problems.append("cold_white must be cool (b > r)")
	if forest.b > forest.g:
		problems.append("forest must be green-grey (g >= b)")
	if fog_blue.b <= fog_blue.r:
		problems.append("fog_blue must be blue-grey (b > r)")
	return problems
