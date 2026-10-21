class_name TradesRivetGun
extends TradesTool
## Powered rivet gun (beenster, 0.3.7): you set how far out the rivet's head should stand on
## its display (mouse wheel), hold the trigger, the air pressure builds with a rising hiss,
## then it punches the rivet home with a bang and a jolt. The wrong setting shows up in the
## quality survey.
##
## Its own space: the nozzle at the origin on the rivet, the barrel up +Y, the pistol grip and
## the air fitting back along +Z.

const GRIP := Vector3(0, 0.17, 0.08)
## Steps of the wheel on its setting (mm), and the range it can be set to.
const SET_STEP_MM := 0.1
const SET_RANGE_MM := Vector2(0.5, 5.0)

## Head height setting (mm).
var set_mm := 1.5
## Air pressure building toward the punch (0..1).
var pressure := 0.0

var _flash := 0.0
var _piston: Node3D


func _ready() -> void:
	name = "RivetGun"
	grip = GRIP
	hold = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)), Vector3(0, -0.02, 0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var along := Vector3(PI * 0.5, 0, 0)
	# The rivet set (the cupped die) on its piston, sliding in the nose.
	_piston = Node3D.new()
	add_child(_piston)
	cylinder(0.006, 0.02, Vector3(0, 0.01, 0), Vector3.ZERO, steel, 14, _piston)
	cylinder(0.009, 0.006, Vector3(0, 0.022, 0), Vector3.ZERO, dark, 14, _piston)
	# Nose with its retaining spring, then the long barrel in BSX orange with grip bands.
	cylinder(0.014, 0.03, Vector3(0, 0.038, 0), Vector3.ZERO, dark, 18)
	ribs(0.0148, Vector3(0, 0.03, 0), Vector3.UP, 4, 0.005)
	cylinder(0.024, 0.14, Vector3(0, 0.12, 0), Vector3.ZERO, body, 20)
	for y: float in [0.07, 0.17]:
		cylinder(0.0255, 0.012, Vector3(0, y, 0), Vector3.ZERO, dark, 20)
	cylinder(0.022, 0.012, Vector3(0, 0.196, 0), Vector3.ZERO, steel, 20)
	print_text("BSX", Vector3(0.0248, 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.011)
	print_text("BSX", Vector3(-0.0248, 0.12, 0), Vector3.LEFT, Vector3.UP, 0.011)
	# The grip, the trigger, and the air hose fitting at its foot.
	box(Vector3(0.028, 0.04, 0.03), Vector3(0, 0.16, 0.028), body)
	capsule(0.016, 0.1, GRIP + Vector3(0, 0, 0.01), along, rubber)
	ribs(0.017, Vector3(0, 0.17, 0.055), Vector3.BACK, 4, 0.016)
	box(Vector3(0.01, 0.018, 0.016), Vector3(0, 0.142, 0.042), dark)
	cylinder(0.008, 0.03, Vector3(0, 0.17, 0.145), along, TradesLook.metal(Color(0.8, 0.66, 0.35), 0.9, 0.3), 12)
	cylinder(0.006, 0.08, Vector3(0, 0.17, 0.2), along, rubber, 10)
	add_screen(Vector3(0, 0.203, 0), Vector3.UP, Vector2(0.036, 0.028), 6, 3, Vector3.FORWARD)


## Wheel: the setting up (+1) or down (-1).
func step_setting(step: int) -> void:
	set_mm = clampf(snappedf(set_mm + step * SET_STEP_MM, SET_STEP_MM), SET_RANGE_MM.x, SET_RANGE_MM.y)


## The punch: the piston slams down (the station plays the bang and jolts the view).
func punch() -> void:
	_flash = 0.5
	pressure = 0.0


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	if _piston:
		_piston.position.y = -0.006 * _flash * 2.0 + 0.003 * pressure
	super(delta)


func readout_text() -> String:
	return "HEAD %.1f\n%s\nmm" % [set_mm, "PUNCH" if _flash > 0.0 else ("%3d%%" % roundi(pressure * 100.0) if pressure > 0.01 else "READY")]


func panel_rows() -> Array:
	return [["HEAD", "%.1f mm" % set_mm], ["AIR", "%d %%" % roundi(pressure * 100.0) if pressure > 0.01 else "-"]]


func panel_state() -> String:
	if _flash > 0.0:
		return "PUNCHED"
	return "PRESSURE" if pressure > 0.01 else "READY"


func readout_fill() -> float:
	return pressure


func readout_alert() -> bool:
	return pressure > 0.01 or _flash > 0.0
