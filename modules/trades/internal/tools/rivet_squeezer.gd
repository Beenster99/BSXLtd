class_name TradesRivetSqueezer
extends TradesTool
## Hand rivet squeezer: a C-yoke whose dies close on the rivet as you pull its handles
## together, with a gauge that reads the head as it forms. Solo work; a bucking bar for two
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
	var dark := dark()
	var body := body()
	var along := Vector3(PI * 0.5, 0, 0)
	# Dies and the C-yoke round the plate's edge.
	cylinder(0.005, 0.012, Vector3(0, 0.006, 0), Vector3.ZERO, steel, 12)
	cylinder(0.005, 0.012, Vector3(0, -0.022, 0), Vector3.ZERO, steel, 12)
	box(Vector3(0.024, 0.016, 0.1), Vector3(0, 0.02, 0.04), body)
	box(Vector3(0.024, 0.08, 0.016), Vector3(0, -0.012, 0.098), body)
	box(Vector3(0.024, 0.014, 0.1), Vector3(0, -0.035, 0.04), body)
	# Fixed handle, and the lever that swings up as it closes.
	cylinder(0.008, 0.2, Vector3(0, 0.03, 0.2), along, steel, 10)
	cylinder(0.011, 0.09, Vector3(0, 0.03, 0.27), along, dark, 10)
	_lever = Node3D.new()
	_lever.position = Vector3(0, 0.03, 0.1)
	add_child(_lever)
	cylinder(0.007, 0.2, Vector3(0, -0.02, 0.1), along, steel, 10, _lever)
	cylinder(0.01, 0.08, Vector3(0, -0.02, 0.16), along, dark, 10, _lever)
	add_screen(Vector3(0, 0.05, 0.05), Vector2(0.09, 0.04))


func _process(delta: float) -> void:
	_lever.rotation.x = deg_to_rad(-14.0) * (1.0 - closed)
	super(delta)


func readout_text() -> String:
	if head_mm < 0.0:
		return "HEAD  --.--\nDIA   --.--"
	return "HEAD %5.2f mm\nDIA  %5.2f mm" % [head_mm, dia_mm]
