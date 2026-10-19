class_name TradesTorqueWrench
extends TradesTool
## Click-type torque wrench. Set to the joint's target; it gives one click when the pull
## reaches it. A powered one comes later.
##
## Its own space: the socket at the origin over the bolt, +Y out of the bolt, the handle
## running back along +Z.

## Where the hand holds it, in its own space.
const GRIP := Vector3(0, 0.03, 0.33)

var set_nm := 25.0
## The torque on the bolt right now (Nm), shown on the screen while pulling.
var applied_nm := 0.0

var _flash := 0.0


func _ready() -> void:
	name = "TorqueWrench"
	grip = GRIP
	hold = Transform3D(Basis(), Vector3(0, -0.03, 0))
	var steel := steel()
	var dark := dark()
	var body := body()
	var yellow := TradesLook.metal(Color(0.9, 0.75, 0.1), 0.2, 0.5)
	var along := Vector3(PI * 0.5, 0, 0)
	# Socket and drive on the bolt, the ratchet head with its reversing lever.
	cylinder(0.011, 0.026, Vector3(0, 0.006, 0), Vector3.ZERO, steel, 12)
	cylinder(0.019, 0.024, Vector3(0, 0.03, 0), Vector3.ZERO, steel, 16)
	box(Vector3(0.006, 0.006, 0.018), Vector3(0, 0.045, -0.006), dark)
	# Tube back to the handle: steel, the orange body over the click mechanism, a yellow
	# scale collar.
	cylinder(0.009, 0.3, Vector3(0, 0.03, 0.165), along, steel, 12)
	box(Vector3(0.028, 0.026, 0.13), Vector3(0, 0.03, 0.12), body)
	box(Vector3(0.03, 0.006, 0.012), Vector3(0, 0.03, 0.26), yellow)
	# Grip: dark, ribbed, with an end cap.
	cylinder(0.015, 0.1, Vector3(0, 0.03, 0.33), along, dark, 12)
	for z: float in [0.3, 0.33, 0.36]:
		cylinder(0.0165, 0.006, Vector3(0, 0.03, z), along, dark, 12)
	cylinder(0.013, 0.01, Vector3(0, 0.03, 0.385), along, steel, 12)
	add_screen(Vector3(0, 0.05, 0.12), Vector2(0.09, 0.04))


## The click: a flash on the screen (the station plays the sound and kicks the camera).
func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	super(delta)


func readout_text() -> String:
	var state := "CLICK" if _flash > 0.0 else ("%5.1f Nm" % applied_nm if applied_nm > 0.05 else "READY")
	return "SET %3d Nm\n%s" % [roundi(set_nm), state]
