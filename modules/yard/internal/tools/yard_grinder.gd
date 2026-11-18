class_name YardGrinder
extends YardTool
## Angle grinder: chews through rivet and bolt heads fast, struggles with welds.
## A fan of sparks off the rim the way the disc spins and a high whine that drops in pitch
## when it bites; the disc's rim heats up over a long grind, dull red to orange, and cools
## off when you let go (YardToolEffects throws the sparks).
##
## Look: an angle grinder. An orange motor body you hold round, a black vented tail and a
## paddle switch under it; the gear head with a big steel cutting disc on its left over a
## guard plate rides out on a telescoping boom; a readout on top (speed, load).

## Disc spin, in radians per second, when running free.
@export var disc_speed: float = 60.0
## Seconds of biting mild steel that take the disc from cold to glowing orange (harder stock
## heats it faster, a better mark slower).
@export var glow_time: float = 7.0
## Seconds it takes to cool from glowing to cold off the work.
@export var cool_time: float = 5.0
@export_group("Load and glaze (SF3)")
## The disc glazes on stock a tier too hard for it from this share of its heat (0..1): its bite
## falls from full at `glaze_from` to `glazed_rate` at full heat. On stock it is made for
## nothing changes, at any heat.
@export var glaze_from: float = 0.75
## The share of its cool rate a fully glazed disc works over-tier stock at (0..1).
@export var glazed_rate: float = 0.6
## LOAD's readout (percent of the motor's rating): biting, `load_base` + `load_per_resistance` x
## the joint's resistance (RESISTANCE by kind), + `load_over_tier` on stock a tier too hard,
## + `load_glazed` x the glaze; skating over plate with no joint, `skim_load`; 0 off the work.
@export var load_base: float = 35.0
@export var load_per_resistance: float = 45.0
@export var load_over_tier: float = 30.0
@export var load_glazed: float = 20.0
@export var skim_load: float = 15.0
## How much the disc slows with its load: at 100% load it turns at 1 - this of its free speed.
@export var load_slowdown: float = 0.4

## How hard each joint kind is to grind through, for LOAD (0..1).
const RESISTANCE := {
	ConnectionData.Kind.WELD: 1.0,
	ConnectionData.Kind.RIVET: 0.5,
	ConnectionData.Kind.BOLT: 0.6,
	ConnectionData.Kind.SPOT: 0.4,
	ConnectionData.Kind.CONNECTOR: 0.3,
}

## How hot the disc is, 0 (cold) .. 1 (glowing orange at the rim).
var disc_heat: float = 0.0

var _disc: MeshInstance3D
var _spin: float = 0.0
var _disc_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D


func _init() -> void:
	tool_name = "GRINDER"
	tool_id = "grinder"
	rivet_rate = 20.0   # a 40-point rivet takes 2 s
	bolt_rate = 0.0     # bolts only come out with the socket
	weld_rate = 5.0     # a 120-point weld takes 24 s: use the cutter
	connector_rate = 12.0  # a 30-point loom connector takes 2.5 s
	spot_rate = 30.0       # a 30-point spot weld takes 1 s
	follow_speed = 0.4     # (FS2) a 3.2 m plate's seam ground off in 8 s, followed along
	push_force = 45.0
	bite_point = Vector3(-0.065, 0.0, -0.27)   # the front of the disc's rim
	grip = Vector3(0.0, 0.055, 0.05)   # the palm on top of the motor body
	boom = 0.5
	boom_kind = BoomKind.TELESCOPE
	heat_rate = 1.4
	spark_color = Color(1.0, 0.5, 0.12)
	light_color = Color(1.0, 0.55, 0.2)
	# Grinding rivets once glared too bright with the light on the plate; now it hangs out in
	# the spray (YardToolEffects) and lights the room as the shower does, a welder's in the dark.
	light_strength = 0.6
	spark_strength = 0.8
	spark_amount = 0.5


func _ready() -> void:
	name = "YardGrinder"
	var orange := metal(Color(0.85, 0.32, 0.04), 0.3, 0.6)
	var rubber := metal(Color(0.1, 0.1, 0.11), 0.05, 0.9)
	var dark := metal(Color(0.2, 0.21, 0.23), 0.6, 0.5)
	var along := Vector3(deg_to_rad(90.0), 0.0, 0.0)
	var across := Vector3(0.0, 0.0, deg_to_rad(90.0))
	# The motor body you hold, a black tail cap with vents, the paddle switch under it.
	cylinder(0.04, 0.24, Vector3(0.0, 0.0, 0.0), along, orange, 20, 0.043)
	cylinder(0.042, 0.05, Vector3(0.0, 0.0, 0.145), along, rubber, 20, 0.036)
	for i in 4:
		for sx in [-1.0, 1.0]:
			box(Vector3(0.008, 0.026, 0.008), Vector3(sx * 0.041, 0.0, 0.07 + 0.016 * float(i)), rubber)
	box(Vector3(0.03, 0.012, 0.13), Vector3(0.0, -0.045, 0.03), rubber)
	box(Vector3(0.05, 0.03, 0.04), Vector3(0.0, 0.03, -0.1), orange)   # switch housing
	# On the boom: the gear head, a big cutting disc on its left (towards your eye) and the
	# guard behind it.
	begin_head(Vector3(0.0, 0.0, -0.12))
	box(Vector3(0.075, 0.07, 0.075), Vector3(0.0, 0.0, -0.16), dark)
	cylinder(0.022, 0.03, Vector3(-0.045, 0.0, -0.17), across, dark, 12)
	_disc_mat = metal(Color(0.78, 0.79, 0.8), 0.7, 0.42)
	_disc_mat.emission_enabled = true
	_disc_mat.emission = Color.BLACK
	_disc = cylinder(0.1, 0.007, Vector3(-0.065, 0.0, -0.17), across, _disc_mat, 32)
	# The rim, where the heat builds: a thin ring round the disc's edge that glows first.
	_rim_mat = metal(Color(0.6, 0.6, 0.62), 0.7, 0.5)
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color.BLACK
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.09
	rim_mesh.outer_radius = 0.101
	rim_mesh.rings = 32
	rim_mesh.ring_segments = 6
	rim.mesh = rim_mesh
	rim.material_override = _rim_mat
	_disc.add_child(rim)
	var nut := MeshInstance3D.new()
	var nut_mesh := CylinderMesh.new()
	nut_mesh.top_radius = 0.022
	nut_mesh.bottom_radius = 0.022
	nut_mesh.height = 0.012
	nut_mesh.radial_segments = 6
	nut.mesh = nut_mesh
	nut.material_override = dark
	nut.position = Vector3(0.0, -0.006, 0.0)
	_disc.add_child(nut)
	var notch := MeshInstance3D.new()
	var notch_mesh := BoxMesh.new()
	notch_mesh.size = Vector3(0.02, 0.009, 0.07)
	notch.mesh = notch_mesh
	notch.material_override = dark
	notch.position = Vector3(0.0, 0.0, 0.05)
	_disc.add_child(notch)
	# The guard: a dark plate behind the disc, a little bigger, its rim showing round it.
	cylinder(0.11, 0.006, Vector3(-0.054, 0.0, -0.17), across, dark, 32)
	end_head()
	readout(Vector3(0.0, 0.065, 0.03), Vector2(0.11, 0.05), Color(1.0, 0.75, 0.3))
	add_voice("grinder")


func _process(delta: float) -> void:
	var target := disc_speed if working else 0.0
	if working and in_contact:
		target *= 1.0 - load_slowdown * minf(load_now() / 100.0, 1.6)  # bogs down with its load
	_spin = move_toward(_spin, target, delta * 120.0)
	_disc.rotate_object_local(Vector3.UP, _spin * delta)
	_heat(delta)


## Heats the disc while it grinds (fastest biting stock too hard for it, slowest skating
## over plate) and cools it off the work; the rim glows dull red, then orange, the face
## behind it a little.
func _heat(delta: float) -> void:
	if working and in_contact:
		var rate := 0.25
		if biting:
			var over := maxi(Materials.tier(work_material) - hardness, 0) if work_material != "" else 0
			rate = 1.0 + 0.8 * float(over)
		rate *= float(MARKS[mark - 1]["heat"])
		disc_heat = minf(disc_heat + delta * rate / glow_time, 1.0)
	else:
		disc_heat = maxf(disc_heat - delta / cool_time, 0.0)
	var glow := smoothstep(0.25, 1.0, disc_heat)
	var colour := Color(0.85, 0.1, 0.02).lerp(Color(1.0, 0.48, 0.1), smoothstep(0.6, 1.0, disc_heat))
	_rim_mat.emission = colour
	_rim_mat.emission_energy_multiplier = glow * 4.0
	_disc_mat.emission = colour
	_disc_mat.emission_energy_multiplier = glow * glow * 0.35


## The way the disc's rim is moving where it bites (world): the way its sparks fly. The disc
## turns about the head's -X, so its front edge sweeps down the head's -Y.
func rim_direction() -> Vector3:
	var b := (head if head else self as Node3D).global_basis
	return (-b.y if _spin >= 0.0 else b.y).normalized()


## Is it biting stock a tier (or more) too hard for its mark? (The joint's harder part, as
## ToolController sets `work_material` on every machine.)
func over_tier() -> bool:
	return biting and work_material != "" and Materials.tier(work_material) > hardness


## How glazed the disc is now (0..1): 0 on stock it is made for, or under `glaze_from` of its
## heat; rising to 1 at full heat on over-tier stock.
func glaze() -> float:
	if not over_tier() or disc_heat <= glaze_from:
		return 0.0
	return clampf((disc_heat - glaze_from) / maxf(1.0 - glaze_from, 0.001), 0.0, 1.0)


## The motor's load from the work (percent; SF3): 0 off it, a little skating over plate, by the
## joint's resistance biting one, more on stock too hard for it and more again glazed. The same
## on every machine from what ToolController sets; AU reads it.
func load_now() -> float:
	if not (working and in_contact):
		return 0.0
	if not biting:
		return skim_load
	var load := load_base + load_per_resistance * float(RESISTANCE.get(work_kind, 1.0))
	if over_tier():
		load += load_over_tier
	return load + load_glazed * glaze()


## The host's bite: a glazed disc works over-tier stock slower, down to `glazed_rate` at full
## heat; stock it is made for at full rate whatever its heat.
func rate_factor() -> float:
	return lerpf(1.0, glazed_rate, glaze())


func readout_text() -> String:
	var rpm := int(_spin / disc_speed * 11000.0)
	var hot := ""
	if glaze() > 0.0:
		hot = "\nDISC HOT: GLAZING"
	elif disc_heat > 0.7:
		hot = "\nDISC HOT"
	return "RPM %5d\nLOAD %3d%%%s" % [rpm, roundi(load_now()), hot]
