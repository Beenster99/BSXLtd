class_name YardGrabber
extends YardTool
## Magnetic grab claw: holds whatever you grip at a set distance in front of you.
##
## The hold is a stiff, well-damped spring between the claw and the gripped point, pushing
## on both ends equally. A light plate gets pulled to you; the 139 t hull doesn't budge, so
## grabbing it pulls YOU instead, and holds you in place: a handy anchor while working.
## On anything much heavier than you the claw is only an anchor: its pull is capped low, so
## thrusting while gripping the hull drags you off it rather than towing or spinning the
## ship. A heavy piece cut loose (not the wreck, under `push_off_mass`) carries you the same,
## but the claw still pulls it at its full grip and calms its spin: your jets can stop it and
## tow it, slowly (a 4 t reactor at about 0.3 m/s^2 on boost).
##
## It does no damage to joints. The physics lives in ToolController; this is the look and
## the numbers.

@export_group("Grip")
## How hard the grip pulls toward the hold point, per metre of stretch (1/s^2). Higher feels
## stiffer.
@export var stiffness: float = 25.0
## How quickly wobble dies out (1/s). Around 2 x sqrt(stiffness) feels firm with no bounce.
@export var damping: float = 10.0
## Strongest pull the claw can make, in newtons. Caps how fast heavy things accelerate.
@export var max_force: float = 2500.0
## Pull cap when gripping something far heavier than you (the hull), in newtons. Holds you
## against normal thrust (500 N); boosting (1250 N) drags you off, so you can't tow a ship.
@export var anchor_max_force: float = 600.0
## A body this many times your mass or more counts as an anchor, not a load.
@export var anchor_mass_ratio: float = 10.0
## How firmly the claw keeps a held part turned the way you hold it (1/s^2). Light parts only.
@export var turn_stiffness: float = 12.0
## How strongly the claw stops a held part spinning relative to you (1/s). Around
## 2 x sqrt(turn_stiffness) turns it with no wobble. Light parts only.
@export var spin_damping: float = 7.0
## Holding R: how far the held part turns per pixel of mouse movement, radians.
@export var turn_sensitivity: float = 0.006
## Strongest twist the claw can apply, in newton-metres.
@export var max_torque: float = 1500.0
## With the exo frame (AVATAR_PLAN.md 9.7): `max_force` and `max_torque` times this. The
## anchor's cap stays (you still can't tow a ship by hand).
@export var exo_grip_factor: float = 1.5
## Planted (standing on a ship's deck or in gravity boots) your stance takes the claw's
## reaction, so the claw pulls a load at up to this (N, Mk I; the mark and the exo frame
## scale it) without dragging you onto it. Nothing under `push_off_mass` is an anchor to a
## planted claw, except what you stand on. A 1.3 t thruster comes at you at about 1.9 m/s^2
## on Mk I, 3.8 on Mk III.
@export var planted_force: float = 2500.0
## The grip lets go if the held point is dragged this far from the hold point, in metres.
@export var break_distance: float = 4.0
## Closest and furthest you can hold something with the mouse wheel, in metres.
@export var min_hold: float = 1.3
@export var max_hold: float = 5.0
## How much one wheel notch moves the hold point, in metres.
@export var wheel_step: float = 0.25

@export_group("Throw")
## Right click while holding: how fast the claw shoves the part away from you, in m/s.
@export var throw_speed: float = 7.2
## Biggest shove, in newton-seconds (a 2 t section still goes at 7.2 m/s; heavier, slower:
## 5 t at 2.9 m/s, 10 t at 1.4 m/s).
@export var max_throw_impulse: float = 14400.0
## Share of the shove that pushes you back when planted, 0..1. 0 = the suit braces and you
## stay put.
@export var throw_recoil: float = 0.0
## Floating (nothing under your boots, not on a deck), the biggest shove, in newton-seconds:
## a 400 kg panel still goes at 7.2 m/s, a 1.9 t plate at 1.6 m/s (SF10, decision 4).
@export var float_throw_impulse: float = 3000.0
## Floating, the share of the shove that pushes you back, 0..1: the 3,000 N s throw sends a
## 110 kg rig back at 1.4 m/s. You feel it (the exo frame softens it).
@export var float_recoil: float = 0.05
## Throws on one body this close together, in seconds, are a team throw: their shoves add, each
## measured from how the body moved before the first, the lot up to `throw_speed`.
@export var team_throw_window: float = 0.5
## Anything heavier than this (the wreck itself) can't be thrown: right click pushes you
## off it instead, in kilograms.
@export var push_off_mass: float = 20000.0

@export_group("Rip")
## (SF2, docs/review/07_SALVAGE_FEEL.md 2.4) Gripping a skin plate or pane still on the wreck,
## Shift held and the claw stretched back past `rip_stretch` for `rip_delay`: its joints take
## this many points a second between them, weakest first, and break FORCED.
@export var rip_points: float = 200.0
## Seconds the stretch and Shift must hold before anything breaks (a tap or a push-off never rips).
@export var rip_delay: float = 0.5
## How far the claw must be stretched back from the grip, toward you, to rip (m).
@export var rip_stretch: float = 0.3
## While ripping, the claw holds the wreck at this (N) instead of `anchor_max_force`, so your
## boost or your stance keeps the line taut rather than tearing the grip off.
@export var rip_hold_force: float = 2000.0
## How deep the ripped plate is bent at the grip, pulled along the rip (m).
@export var rip_dent: float = 0.06
## Over this a plate won't rip (kg).
@export var rip_max_kg: float = 4000.0
## How hard each kind of joint is to rip, times its health (a weld four times a rivet).
@export var rip_resistance: Dictionary = {
	ConnectionData.Kind.RIVET: 1.0, ConnectionData.Kind.SPOT: 1.0, ConnectionData.Kind.CONNECTOR: 0.5,
	ConnectionData.Kind.BOLT: 2.0, ConnectionData.Kind.WELD: 4.0,
}
## How long the claw's screen says RIPPED after one (s).
@export var ripped_seconds: float = 3.0

var _prongs: Array[MeshInstance3D] = []
## For the readout (SF2): how far the rip under way has gone (0..1; -1 none), and after one
## the ripped piece's line ("HULL PLATE  1.9 t  FORCED  620 cr") for `ripped_seconds`.
var rip_share: float = -1.0
var ripped_line: String = ""
var ripped_left: float = 0.0
var _gripping := false
var _closed: float = 0.0  # 0 = claw open, 1 = closed
## For the readout: how far out the hold point is and what is held (ToolController).
var hold_range: float = 0.0
var held_mass: float = 0.0
## For the readout: the claw is planted (your stance takes the pull: ToolController).
var planted := false
## For the readout: the claw caught the piece it holds as it came free (TW6), and the held
## body is an anchor to it (heavy enough to carry you off: RIDING, not CAUGHT).
var caught := false
var anchored := false
## The claw turns what it holds (a load, or a loose piece that carries you, not the wreck, a ship
## or the skip): R and the mouse may turn it (`ToolController.turning_held`). Set each step.
var turns := false
## For the readout: how many claws (yours and your crewmates') hold the same body (SF10). Over
## one, the readout says TEAM n.
var team: int = 0
## The hand that hears what the claw grips (AU21: a tank's knock, a loom's hum).
var _coil: StandardMaterial3D


## Mk II and III grip harder: their mark's rate scales the grip, planted, anchor and twist caps.
func _apply_mark(row: Dictionary) -> void:
	if not _base.has("max_force"):
		_base["max_force"] = max_force
		_base["anchor_max_force"] = anchor_max_force
		_base["planted_force"] = planted_force
		_base["max_torque"] = max_torque
	max_force = float(_base["max_force"]) * float(row["rate"])
	anchor_max_force = float(_base["anchor_max_force"]) * float(row["rate"])
	planted_force = float(_base["planted_force"]) * float(row["rate"])
	max_torque = float(_base["max_torque"]) * float(row["rate"])


## The strongest pull on a load, N: `max_force`, times `exo_grip_factor` with the frame.
func grip_force(exo: bool) -> float:
	return max_force * (exo_grip_factor if exo else 1.0)


## The strongest pull on a load from a planted claw, N: `planted_force`, times
## `exo_grip_factor` with the frame.
func planted_grip(exo: bool) -> float:
	return planted_force * (exo_grip_factor if exo else 1.0)


## The strongest twist on a load, N m: `max_torque`, times `exo_grip_factor` with the frame.
func grip_torque(exo: bool) -> float:
	return max_torque * (exo_grip_factor if exo else 1.0)


func _init() -> void:
	tool_name = "GRABBER"
	tool_id = "grabber"
	rivet_rate = 0.0
	bolt_rate = 0.0
	weld_rate = 0.0
	connector_rate = 0.0
	reach = 4.0
	grip = Vector3(0.0, -0.1, 0.07)
	push_force = 0.0
	heat_rate = 0.0
	spark_color = Color(0.4, 0.85, 1.0)
	light_color = Color(0.4, 0.85, 1.0)


func _ready() -> void:
	name = "YardGrabber"
	var blue := metal(Color(0.2, 0.45, 0.6), 0.6, 0.4)
	var steel := metal(Color(0.75, 0.76, 0.78), 0.9, 0.3)
	var dark := metal(Color(0.14, 0.15, 0.17), 0.5, 0.5)
	var along := Vector3(deg_to_rad(90.0), 0.0, 0.0)
	# Body, a dark collar, and the emitter ring the prongs hinge on.
	cylinder(0.06, 0.22, Vector3(0.0, 0.0, -0.03), along, blue, 20, 0.05)
	cylinder(0.055, 0.04, Vector3(0.0, 0.0, 0.1), along, dark, 20)
	cylinder(0.075, 0.035, Vector3(0.0, 0.0, -0.16), along, steel, 20)
	# A pistol grip under the tail.
	box(Vector3(0.045, 0.12, 0.06), Vector3(0.0, -0.1, 0.07), dark, Vector3(0.3, 0.0, 0.0))
	# The magnetic coil in the middle glows while gripping.
	_coil = StandardMaterial3D.new()
	_coil.albedo_color = Color(0.05, 0.08, 0.1)
	_coil.emission_enabled = true
	_coil.emission = Color(0.4, 0.85, 1.0)
	_coil.emission_energy_multiplier = 0.4
	cylinder(0.025, 0.06, Vector3(0.0, 0.0, -0.19), along, _coil, 12)
	# Three claw prongs around the front; they close while gripping.
	for i in 3:
		var prong := MeshInstance3D.new()
		var prong_mesh := BoxMesh.new()
		prong_mesh.size = Vector3(0.02, 0.02, 0.17)
		prong.mesh = prong_mesh
		prong.material_override = steel
		add_child(prong)
		_prongs.append(prong)
	_place_prongs(0.0)
	readout(Vector3(0.0, 0.075, 0.03), Vector2(0.12, 0.05))
	add_voice("grabber")


func set_gripping(on: bool) -> void:
	_gripping = on


func _process(delta: float) -> void:
	_place_prongs(1.0 if _gripping else 0.0, delta)
	ripped_left = maxf(0.0, ripped_left - delta)
	_coil.emission_energy_multiplier = lerpf(0.4, 3.5, _closed)


func readout_text() -> String:
	if rip_share >= 0.0:
		return "RIP %d%%\nLEAN BACK" % roundi(rip_share * 100.0)
	if _gripping and ripped_left > 0.0 and ripped_line != "":
		return "RIPPED\n%s" % ripped_line
	if _gripping:
		var t := held_mass / 1000.0
		var crew := "  TEAM %d" % team if team > 1 else ""
		if caught:
			return "GRIP LOCKED\n%s %.1f t%s" % ["RIDING" if anchored else "CAUGHT", t, crew]
		return "GRIP LOCKED
%s" % (("LOAD %.1f t%s%s" % [t, "  PLANTED" if planted else "", crew]) if t < 100.0 else "ANCHORED")
	return "GRIP OPEN
HOLD %.1f m" % hold_range


## The HUD's words for how the claw holds (SF10): "TEAM 2", "PLANTED", "RIDING", or "".
func stance_words() -> String:
	var words: Array[String] = []
	if team > 1:
		words.append("TEAM %d" % team)
	if planted:
		words.append("PLANTED")
	elif anchored and caught:
		words.append("RIDING")
	return "  ·  ".join(words)


func _place_prongs(target: float, delta: float = 1.0) -> void:
	_closed = move_toward(_closed, target, delta * 6.0)
	var spread := lerpf(0.075, 0.03, _closed)
	var tilt := lerpf(0.5, 0.05, _closed)
	for i in _prongs.size():
		var a := TAU * i / _prongs.size()
		var out := Vector3(cos(a), sin(a), 0.0)
		var prong := _prongs[i]
		prong.position = out * spread + Vector3(0.0, 0.0, -0.26)
		# Splay outward when open, close to a point when gripping.
		prong.basis = Basis(out.cross(Vector3.FORWARD).normalized(), -tilt)
