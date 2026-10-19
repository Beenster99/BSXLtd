class_name BoltingTuning
extends Resource
## The feel of bolting. Pass marks are not here: Quality owns those. Edit bolting.tres to
## tune without touching code.

const VERSION := 1

@export var version := VERSION

@export_group("Bracket")
## The bracket snaps into place when let go this close to its seat...
@export var snap_distance_mm := 12.0
## ...and this square to it.
@export var snap_angle_deg := 6.0
## Snapping pulls most of the offset out; this share of it is left as misalignment.
@export var snap_residual := 0.25

@export_group("Starting by hand")
## Cursor distance from the hole centre turns into bolt tilt at this rate.
@export var tilt_deg_per_mm := 1.5
## A bolt started at more tilt than this cross-threads.
@export var cross_thread_tilt_deg := 6.0
@export var hand_turns_per_notch := 0.25
@export var hand_start_turns := 2.0
## A cross-threaded bolt binds after this many turns by hand.
@export var cross_bind_turns := 0.75

@export_group("Ratchet")
@export var ratchet_turns_per_notch := 1.0
@export var run_down_turns := 6.0
## Torque left on a bolt run down by the ratchet, as a share of the target.
@export var snug_share := 0.3

@export_group("Torque wrench")
## Torque per pixel of downward drag on the wrench handle.
@export var nm_per_px := 0.12
## A pull that ends below this share of the target does not count as final torque.
@export var min_pull_share := 0.5
@export var click_kick := 0.012
