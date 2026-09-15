# Enemy states (shared by logic, controller, director, tests).
#
# A separate dependency-free file (the headless rig has no global
# class_name registry — ADR-022): all cross-file references use
# preload-consts.
#
# Common core (ARCHITECTURE §3.3) + archetype states (ENEMY_DESIGN §0):
# IDLE/CHASE/WINDUP/ACTIVE/RECOVERY/HURT/DEATH + OBSERVING/FOLLOW/
# VANISH (Watcher), WANDER (Forgotten), RETREAT (Hollow), SPEAK/
# LEAVE (Remnant first encounter).
class_name EnemyState
extends RefCounted

enum State {
	IDLE,
	CHASE,
	WINDUP,  # telegraph (0.4–1.0 s, readable)
	ACTIVE,  # hit frame(s)
	RECOVERY,
	HURT,  # hitstun (returns to the interrupted state)
	# Archetype states:
	OBSERVING,  # Watcher: mutual eye-line (2 s -> memory anchor)
	FOLLOW,  # Watcher: slow tracking (40% speed, no attack)
	VANISH,  # Watcher: 1 s fade, then teleport 10 m
	WANDER,  # Forgotten: random path, wander_radius
	RETREAT,  # Hollow: player fled (not chasing > 5 s)
	SPEAK,  # Remnant: encounter speech
	LEAVE,  # Remnant: first encounter ends — it leaves
	DEATH,  # dissolve (0.3 s; Forgotten 3 s)
}
