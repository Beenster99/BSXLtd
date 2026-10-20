class_name TradesWireTool
extends TradesTool
## Strip-and-crimp pliers: stripping blades with a length stop at the tip, a ferrule die
## behind them, red rubber grips and a ratchet that clicks when the crimp is fully closed.
## A gauge on a side arm reads the strip length or how far the crimp has closed.
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
	var dark := anodised()
	var red := TradesLook.metal(Color(0.75, 0.12, 0.1), 0.05, 0.75)
	var along := Vector3(PI * 0.5, 0, 0)
	box(Vector3(0.016, 0.006, 0.05), Vector3(0, 0.0, 0.02), steel)                        # lower jaw
	for i in 4:
		box(Vector3(0.017, 0.002, 0.002), Vector3(0, 0.0035, 0.004 + i * 0.008), dark)    # strip notches
	box(Vector3(0.004, 0.012, 0.004), Vector3(0.009, 0.004, -0.004), TradesLook.metal(TradesLook.TRIM, 0.3, 0.5))  # length stop
	box(Vector3(0.022, 0.014, 0.018), Vector3(0, 0.004, 0.05), dark)                      # crimp die
	cylinder(0.0065, 0.026, Vector3(0, 0.006, 0.06), Vector3(0, 0, PI * 0.5), steel, 12)  # pivot
	box(Vector3(0.006, 0.01, 0.024), Vector3(0, 0.012, 0.078), dark)                      # ratchet
	box(Vector3(0.012, 0.008, 0.12), Vector3(0, -0.004, 0.12), steel)                     # lower handle
	capsule(0.0095, 0.095, Vector3(0, -0.006, 0.155), along, red)
	# The gauge on a short arm out to the left of the head, looking up past the hand.
	box(Vector3(0.024, 0.005, 0.008), Vector3(-0.016, -0.004, 0.03), dark)
	box(Vector3(0.042, 0.01, 0.044), Vector3(-0.044, -0.004, 0.03), dark)
	add_screen(Vector3(-0.044, 0.0015, 0.03), Vector3.UP, Vector2(0.034, 0.036), 6, 3, Vector3.FORWARD)
	print_text("BSX", Vector3(0.0062, -0.004, 0.1), Vector3.RIGHT, Vector3.UP, 0.007)
	_upper = Node3D.new()
	_upper.position = Vector3(0, 0.006, 0.06)
	add_child(_upper)
	box(Vector3(0.016, 0.006, 0.05), Vector3(0, 0.002, -0.04), steel, Vector3.ZERO, _upper)
	box(Vector3(0.012, 0.008, 0.12), Vector3(0, 0.014, 0.06), steel, Vector3(-0.15, 0, 0), _upper)
	capsule(0.0095, 0.09, Vector3(0, 0.022, 0.09), Vector3(PI * 0.5 - 0.15, 0, 0), red, _upper)


func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_upper.rotation.x = deg_to_rad(16.0) * (1.0 - closed)
	super(delta)


func readout_text() -> String:
	if _flash > 0.0:
		return "CRIMP\nCLICK\nOK"
	match mode:
		"strip":
			return "STRIP\n%4.1f\nmm" % value
		"crimp":
			return "CRIMP\n%3d\n%%" % roundi(value * 100.0)
	return "STRIP\nCRIMP\nREADY"


func panel_rows() -> Array:
	match mode:
		"strip":
			return [["MODE", "STRIP"], ["STRIPPED", "%.1f mm" % value]]
		"crimp":
			return [["MODE", "CRIMP"], ["CRIMPED", "%d %%" % roundi(value * 100.0)]]
	return [["MODE", "STRIP / CRIMP"]]


func panel_state() -> String:
	return "CRIMP OK" if _flash > 0.0 else ("WORKING" if mode != "" else "READY")


func readout_fill() -> float:
	match mode:
		"strip":
			return value / 12.0
		"crimp":
			return value
	return 0.0


func readout_alert() -> bool:
	return _flash > 0.0
