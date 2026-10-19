class_name BoltingTuning
extends Resource
## The feel of bolting. Pass marks are not here: Quality owns those. Edit bolting.tres to
## tune without touching code.

const VERSION := 1

@export var version := VERSION

@export_group("Bracket")
## The bracket snaps into place when let go this close to its seat...
@export var snap_distance_mm := 25.0
## ...and this square to it.
@export var snap_angle_deg := 8.0
## Snapping pulls most of the offset out; this share of it is left as misalignment.
@export var snap_residual := 0.25

@export_group("Hands")
## How far a hand reaches from the shoulder before it starts to stretch, in metres...
@export var hand_reach_m := 0.9
## ...and how much further the elastic arm stretches before it lets go.
@export var hand_stretch_m := 0.9
## Aiming this far from a hole's centre when a bolt goes in tilts it by tilt_deg_per_mm.
@export var tilt_deg_per_mm := 0.6
## A bolt started at more tilt than this cross-threads.
@export var cross_thread_tilt_deg := 6.0
@export var hand_turns_per_second := 3.0
## Turns by hand before the thread has caught...
@export var hand_start_turns := 2.0
## ...and then to run it down finger tight.
@export var run_down_turns := 6.0
## A cross-threaded bolt jams by hand after this many turns.
@export var cross_bind_turns := 0.75
## Torque left on a bolt run down by hand, as a share of the target.
@export var snug_share := 0.2

@export_group("Torque wrench")
## Torque per pixel of mouse pulled back while the wrench is on a bolt.
@export var nm_per_px := 0.1
## A pull that ends below this share of the target does not count as final torque.
@export var min_pull_share := 0.5
## Camera kick when the wrench clicks, in metres.
@export var click_kick := 0.012
