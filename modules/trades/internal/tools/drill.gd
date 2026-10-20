class_name TradesDrill
extends TradesTool
## Cordless drill with a 3.3 mm bit for rivet holes: a keyless chuck, an orange motor body
## with vent slots and a screen on its back end (bit size and speed), a rubber pistol grip
## with the trigger, and the battery with its charge lights under it.
##
## Its own space: the bit's tip at the origin, the bit up +Y, the grip running back along +Z.

const GRIP := Vector3(0, 0.15, 0.085)
const BIT_MM := 3.3
const MAX_RPM := 2400

## Spinning (0..1), turns the chuck.
var spin := 0.0

var _chuck: Node3D


func _ready() -> void:
	name = "Drill"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70.0)), Vector3(0, -0.02, 0.0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	_chuck = Node3D.new()
	add_child(_chuck)
	cylinder(0.00165, 0.045, Vector3(0, 0.022, 0), Vector3.ZERO, TradesLook.metal(Color(0.75, 0.6, 0.3), 0.9, 0.3), 8, _chuck)  # bit
	cylinder(0.006, 0.008, Vector3(0, 0.046, 0), Vector3.ZERO, steel, 12, _chuck, 0.009)  # jaws' nose
	cylinder(0.012, 0.022, Vector3(0, 0.061, 0), Vector3.ZERO, dark, 16, _chuck, 0.013)   # sleeve
	for i in 8:
		var a := i * TAU / 8.0
		box(Vector3(0.002, 0.016, 0.003), Vector3(cos(a) * 0.0128, 0.061, sin(a) * 0.0128), rubber,
				Vector3(0, -a, 0), _chuck)                                                    # sleeve grips
	cylinder(0.0155, 0.01, Vector3(0, 0.077, 0), Vector3.ZERO, steel, 18)                  # collar
	cylinder(0.024, 0.012, Vector3(0, 0.088, 0), Vector3.ZERO, dark, 20, self, 0.019)       # clutch ring
	for i in 12:
		var a := i * TAU / 12.0
		box(Vector3(0.002, 0.008, 0.003), Vector3(cos(a) * 0.022, 0.088, sin(a) * 0.022), steel, Vector3(0, -a, 0))
	cylinder(0.026, 0.09, Vector3(0, 0.139, 0), Vector3.ZERO, body, 20)                    # motor body
	for i in 6:
		var a := PI * 0.5 + (i - 2.5) * 0.32
		box(Vector3(0.0025, 0.026, 0.004), Vector3(cos(a) * 0.026, 0.158, sin(a) * 0.026), dark, Vector3(0, -a, 0))  # vents
	# The back end: a dark cap with the screen looking up out of it.
	box(Vector3(0.048, 0.014, 0.05), Vector3(0, 0.19, 0.006), dark)
	box(Vector3(0.042, 0.004, 0.044), Vector3(0, 0.198, 0.006), dark)
	add_screen(Vector3(0, 0.2006, 0.004), Vector3.UP, Vector2(0.034, 0.032), 6, 3, Vector3.FORWARD)
	# Pistol grip: an orange spine under rubber, the trigger and the direction switch.
	box(Vector3(0.026, 0.03, 0.105), Vector3(0, 0.152, 0.075), body, Vector3(0.25, 0, 0))
	capsule(0.0155, 0.09, Vector3(0, 0.146, 0.085), Vector3(PI * 0.5 + 0.25, 0, 0), rubber)
	box(Vector3(0.009, 0.018, 0.012), Vector3(0, 0.131, 0.036), dark)                     # trigger
	box(Vector3(0.03, 0.006, 0.008), Vector3(0, 0.16, 0.03), rubber)                      # direction
	print_text("BSX", Vector3(0.0262, 0.13, 0.0), Vector3.RIGHT, Vector3.UP, 0.01)
	print_text("BSX", Vector3(-0.0262, 0.13, 0.0), Vector3.LEFT, Vector3.UP, 0.01)
	# Battery: a dark shoe, the orange pack, three charge lights on its back.
	box(Vector3(0.04, 0.008, 0.05), Vector3(0, 0.143, 0.135), dark)
	box(Vector3(0.05, 0.03, 0.066), Vector3(0, 0.124, 0.137), body)
	box(Vector3(0.052, 0.006, 0.068), Vector3(0, 0.107, 0.137), rubber)
	var charge := TradesLook.glow(Color(0.4, 1.0, 0.45), 2.5)
	for i in 3:
		box(Vector3(0.006, 0.003, 0.002), Vector3(-0.009 + i * 0.009, 0.127, 0.1705), charge)


func _process(delta: float) -> void:
	_chuck.rotation.y += spin * 60.0 * delta
	super(delta)


func readout_text() -> String:
	var rpm := "%4d" % roundi(spin * MAX_RPM) if spin > 0.0 else "STOP"
	return "%3.1fmm\n%s\nRPM" % [BIT_MM, rpm]


func readout_fill() -> float:
	return spin


func readout_alert() -> bool:
	return spin > 0.0
