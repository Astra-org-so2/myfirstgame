# AnchorData — one Watcher memory anchor (WORLD_STATE_DESIGN §3:
# «mirror» — the moment you were watched; <=2/run, consumed by the
# next run's Memory Echo — Phase 10).
class_name AnchorData
extends RefCounted

var position: Vector3 = Vector3.ZERO
var created_at: float = 0.0
