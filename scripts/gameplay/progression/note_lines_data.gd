# NoteLinesData — the 5-line pool of the player notes (WORLD_STATE_
# DESIGN section 4, ADR-018: «no free text» — every line is a
# «door» (a riddle), not lore. Data-driven: new lines without code.
class_name NoteLinesData
extends Resource

# Exactly 5 (the design pool; the note panel shows all of them).
@export var lines: PackedStringArray = PackedStringArray()
