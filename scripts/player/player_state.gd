# Player movement states (shared by logic, controller, visual, tests).
#
# A separate dependency-free file: the headless rig (ADR-002, build
# limitation: no global class_name registry) cannot resolve cross-file
# class_name references, so all cross-file references use preload-consts.
class_name PlayerState
extends RefCounted

enum State { IDLE, WALK, RUN, DODGE, HURT }
