class_name TradesTorqueWrench
extends TradesTool
## Digital click-type torque wrench. Set to the joint's target; it gives one click when the
## pull reaches it. The screen in its pod reads the setting and the torque on the bolt as you
## pull, the bar fills toward the setting and the light flashes on the click. A powered one
## comes later.
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
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var along := Vector3(PI * 0.5, 0, 0)
	# Hex socket on the bolt, the square drive, and the ratchet head with its reversing lever.
	cylinder(0.0115, 0.026, Vector3(0, 0.006, 0), Vector3.ZERO, steel, 6)
	cylinder(0.009, 0.006, Vector3(0, 0.021, 0), Vector3.ZERO, steel, 12)
	cylinder(0.02, 0.022, Vector3(0, 0.032, 0), Vector3.ZERO, dark, 20)
	cylinder(0.016, 0.003, Vector3(0, 0.0445, 0), Vector3.ZERO, steel, 20)
	box(Vector3(0.026, 0.02, 0.04), Vector3(0, 0.032, 0.026), dark)
	box(Vector3(0.007, 0.004, 0.016), Vector3(0, 0.046, -0.002), steel, Vector3(0, 0.4, 0))
	# The beam, then the electronics pod in BSX orange with the screen and two set buttons.
	cylinder(0.009, 0.32, Vector3(0, 0.03, 0.18), along, steel, 14)
	box(Vector3(0.05, 0.024, 0.12), Vector3(0, 0.032, 0.125), body)
	box(Vector3(0.044, 0.006, 0.112), Vector3(0, 0.046, 0.125), body)
	box(Vector3(0.052, 0.004, 0.122), Vector3(0, 0.0205, 0.125), dark)
	add_screen(Vector3(0, 0.0495, 0.115), Vector3(0, 1, 0.25), Vector2(0.036, 0.05), 6, 3, Vector3.FORWARD)
	for i in 2:
		cylinder(0.0035, 0.004, Vector3(0, 0.049, 0.163 + i * 0.012), Vector3.ZERO, rubber, 10)
	print_text("BSX", Vector3(0.0252, 0.032, 0.125), Vector3.RIGHT, Vector3.UP, 0.009)
	print_text("BSX", Vector3(-0.0252, 0.032, 0.125), Vector3.LEFT, Vector3.UP, 0.009)
	# Scale collar, then the rubber grip with ribs and an orange end cap.
	cylinder(0.0105, 0.012, Vector3(0, 0.03, 0.2), along, TradesLook.metal(Color(0.9, 0.75, 0.1), 0.3, 0.45), 14)
	capsule(0.0145, 0.12, Vector3(0, 0.03, 0.33), along, rubber)
	ribs(0.0158, Vector3(0, 0.03, 0.29), Vector3.BACK, 5, 0.018)
	cylinder(0.0135, 0.012, Vector3(0, 0.03, 0.392), along, body, 14)


## The click: a flash on the screen (the station plays the sound and kicks the camera).
func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	super(delta)


func readout_text() -> String:
	var state := "CLICK" if _flash > 0.0 else ("%5.1f" % applied_nm if applied_nm > 0.05 else "READY")
	return "SET %2d\n%s\nNm" % [roundi(set_nm), state]


func panel_rows() -> Array:
	return [["SET", "%d N m" % roundi(set_nm)], ["APPLIED", "%.1f N m" % applied_nm if applied_nm > 0.05 else "-"]]


func panel_state() -> String:
	if _flash > 0.0:
		return "CLICK: TORQUED"
	return "PULLING" if applied_nm > 0.05 else "READY"


func readout_fill() -> float:
	return applied_nm / maxf(set_nm, 1.0)


func readout_alert() -> bool:
	return _flash > 0.0
