class_name TradesDrill
extends TradesTool
## Cordless drill with a 3.3 mm bit for rivet holes: an orange body over the chuck, a dark
## pistol grip with the battery under it.
##
## Its own space: the bit's tip at the origin, the bit up +Y, the grip running back along +Z.

const GRIP := Vector3(0, 0.15, 0.085)

## Spinning (0..1), turns the chuck.
var spin := 0.0

var _chuck: Node3D


func _ready() -> void:
	name = "Drill"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70.0)), Vector3(0, -0.02, 0.0))
	var steel := steel()
	var dark := dark()
	var body := body()
	_chuck = Node3D.new()
	add_child(_chuck)
	cylinder(0.0016, 0.045, Vector3(0, 0.022, 0), Vector3.ZERO, steel, 8, _chuck)          # bit
	cylinder(0.011, 0.03, Vector3(0, 0.058, 0), Vector3.ZERO, dark, 12, _chuck, 0.014)    # chuck
	box(Vector3(0.004, 0.026, 0.024), Vector3(0, 0.058, 0), steel, Vector3.ZERO, _chuck)   # chuck jaws
	cylinder(0.026, 0.11, Vector3(0, 0.125, 0), Vector3.ZERO, body, 16)                   # motor body
	cylinder(0.027, 0.012, Vector3(0, 0.084, 0), Vector3.ZERO, dark, 16)                  # clutch ring
	for i in 4:
		box(Vector3(0.004, 0.03, 0.002), Vector3(0, 0.15, 0).rotated(Vector3.UP, i * PI * 0.5) + \
				Vector3(0.026, 0, 0).rotated(Vector3.UP, i * PI * 0.5 + PI * 0.25), dark)  # vents
	box(Vector3(0.03, 0.035, 0.11), Vector3(0, 0.155, 0.075), dark, Vector3(0.25, 0, 0))  # grip
	box(Vector3(0.008, 0.016, 0.01), Vector3(0, 0.138, 0.032), body)                      # trigger
	box(Vector3(0.05, 0.03, 0.06), Vector3(0, 0.13, 0.135), body)                         # battery
	box(Vector3(0.052, 0.006, 0.062), Vector3(0, 0.113, 0.135), dark)


func _process(delta: float) -> void:
	_chuck.rotation.y += spin * 60.0 * delta
	super(delta)
