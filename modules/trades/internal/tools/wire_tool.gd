class_name TradesWireTool
extends TradesTool
## Strip-and-crimp pliers: stripping blades at the tip, a ferrule die behind them, red
## grips and a ratchet that clicks when the crimp is fully closed. Its screen reads the
## strip length or how far the crimp has closed.
##
## Its own space: the jaws at the origin on the wire end, the handles back along +Z.

const GRIP := Vector3(0, 0.012, 0.15)

## What the screen shows: "" idle, "strip" or "crimp".
var mode := ""
var value := 0.0
## How far the handles are closed (0..1).
var closed := 0.0

var _upper: Node3D
var _flash := 0.0


func _ready() -> void:
	name = "WireTool"
	grip = GRIP
	hold = Transform3D(Basis(), Vector3(0, -0.012, 0))
	var steel := steel()
	var dark := dark()
	var red := TradesLook.metal(Color(0.75, 0.12, 0.1), 0.1, 0.7)
	var along := Vector3(PI * 0.5, 0, 0)
	box(Vector3(0.016, 0.006, 0.05), Vector3(0, 0.0, 0.02), steel)                        # lower jaw
	box(Vector3(0.02, 0.012, 0.016), Vector3(0, 0.004, 0.05), dark)                       # crimp die
	cylinder(0.006, 0.02, Vector3(0, 0.006, 0.06), Vector3(0, 0, PI * 0.5), steel, 10)    # pivot
	box(Vector3(0.012, 0.008, 0.12), Vector3(0, -0.004, 0.12), steel)                     # lower handle
	cylinder(0.009, 0.09, Vector3(0, -0.006, 0.15), along, red, 10)
	_upper = Node3D.new()
	_upper.position = Vector3(0, 0.006, 0.06)
	add_child(_upper)
	box(Vector3(0.016, 0.006, 0.05), Vector3(0, 0.002, -0.04), steel, Vector3.ZERO, _upper)
	box(Vector3(0.012, 0.008, 0.12), Vector3(0, 0.014, 0.06), steel, Vector3(-0.15, 0, 0), _upper)
	cylinder(0.009, 0.09, Vector3(0, 0.022, 0.09), Vector3(PI * 0.5 - 0.15, 0, 0), red, 10, _upper)
	add_screen(Vector3(0, 0.045, 0.08), Vector2(0.09, 0.04))


func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_upper.rotation.x = deg_to_rad(16.0) * (1.0 - closed)
	super(delta)


func readout_text() -> String:
	if _flash > 0.0:
		return "CRIMP\nCLICK"
	match mode:
		"strip":
			return "STRIP\n%4.1f mm" % value
		"crimp":
			return "CRIMP\n%3d %%" % roundi(value * 100.0)
	return "STRIP/\nCRIMP"
