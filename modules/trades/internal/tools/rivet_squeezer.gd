class_name TradesRivetSqueezer
extends TradesTool
## Hand rivet squeezer: a C-yoke whose dies close on the rivet as you pull its handles
## together, with a gauge pod on the yoke whose screen reads the head as it forms (height
## and diameter) and fills its bar as the handles close. Solo work; a bucking bar for two
## comes later.
##
## Its own space: the upper die's face at the origin over the rivet, the yoke reaching round
## the plate's edge toward +Z, the handles running back along +Z.

const GRIP := Vector3(0, 0.035, 0.27)

## Head height and diameter on the gauge (mm), -1 for no reading.
var head_mm := -1.0
var dia_mm := -1.0
## How far the handles are closed (0..1).
var closed := 0.0

var _lever: Node3D


func _ready() -> void:
	name = "RivetSqueezer"
	grip = GRIP
	hold = Transform3D(Basis(), Vector3(0, -0.035, 0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var along := Vector3(PI * 0.5, 0, 0)
	# Flat and cupped dies in their holders.
	cylinder(0.005, 0.01, Vector3(0, 0.005, 0), Vector3.ZERO, steel, 14)
	cylinder(0.008, 0.012, Vector3(0, 0.016, 0), Vector3.ZERO, dark, 14)
	cylinder(0.005, 0.01, Vector3(0, -0.019, 0), Vector3.ZERO, steel, 14)
	cylinder(0.008, 0.012, Vector3(0, -0.03, 0), Vector3.ZERO, dark, 14)
	# The C-yoke, orange with dark cheek plates and pivot bolts.
	box(Vector3(0.026, 0.018, 0.104), Vector3(0, 0.026, 0.042), body)
	box(Vector3(0.026, 0.09, 0.02), Vector3(0, -0.006, 0.1), body)
	box(Vector3(0.026, 0.016, 0.104), Vector3(0, -0.041, 0.042), body)
	for side: float in [-1.0, 1.0]:
		box(Vector3(0.003, 0.05, 0.05), Vector3(side * 0.0145, 0.02, 0.105), dark)
		cylinder(0.005, 0.034, Vector3(0, 0.03, 0.105), Vector3(0, 0, PI * 0.5), steel, 10)
	print_text("BSX", Vector3(0.0132, -0.041, 0.04), Vector3.RIGHT, Vector3.UP, 0.009)
	# The gauge pod on the yoke.
	box(Vector3(0.05, 0.012, 0.058), Vector3(0, 0.041, 0.046), dark)
	add_screen(Vector3(0, 0.0475, 0.046), Vector3(0, 1, 0.2), Vector2(0.038, 0.046), 6, 3, Vector3.FORWARD)
	# Fixed handle, and the lever that swings up as it closes, both in rubber sleeves; a
	# return spring between them.
	cylinder(0.0075, 0.2, Vector3(0, 0.03, 0.2), along, steel, 12)
	capsule(0.012, 0.1, Vector3(0, 0.03, 0.27), along, rubber)
	ribs(0.0128, Vector3(0, 0.03, 0.24), Vector3.BACK, 4, 0.02)
	_lever = Node3D.new()
	_lever.position = Vector3(0, 0.03, 0.105)
	add_child(_lever)
	cylinder(0.007, 0.2, Vector3(0, -0.02, 0.1), along, steel, 12, _lever)
	capsule(0.011, 0.09, Vector3(0, -0.02, 0.165), along, rubber, _lever)
	cylinder(0.003, 0.03, Vector3(0, -0.008, 0.035), Vector3.ZERO, steel, 8, _lever)


func _process(delta: float) -> void:
	_lever.rotation.x = deg_to_rad(-14.0) * (1.0 - closed)
	super(delta)


func readout_text() -> String:
	if head_mm < 0.0:
		return "H --.-\nD --.-\nmm"
	return "H %4.2f\nD %4.2f\nmm" % [head_mm, dia_mm]


func panel_rows() -> Array:
	if head_mm < 0.0:
		return [["HEAD", "-"], ["DIAMETER", "-"], ["CLOSED", "%d %%" % roundi(closed * 100.0)]]
	return [["HEAD", "%.2f mm" % head_mm], ["DIAMETER", "%.2f mm" % dia_mm], ["CLOSED", "%d %%" % roundi(closed * 100.0)]]


func panel_state() -> String:
	return "SQUEEZING" if closed > 0.02 else "READY"


func readout_fill() -> float:
	return closed


func readout_alert() -> bool:
	return closed > 0.02
