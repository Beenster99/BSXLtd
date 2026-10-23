class_name TradesPowerWrench
extends TradesTorqueWrench
## Powered torque wrench, the cordless pistol kind in real garages (beenster, 0.3.7): the bolt
## goes in by itself, you set the torque on its display (mouse wheel) and hold the trigger.
## The motor runs the bolt up to the setting, then its clutch slips; keep the trigger down
## past that and the thread strips. A reverse switch puts it in undo mode (bolts out). Now
## and then it stalls and wants the trigger let go and pulled again.
##
## Its own space: the socket at the origin over the bolt, the barrel up +Y out of the bolt,
## the pistol grip and battery hanging back along +Z.

## Where the hand closes on the grip, in its own space.
const POWER_GRIP := Vector3(0, 0.155, 0.085)
## Steps of the wheel on its setting (N m), and the range it can be set to.
const SET_STEP_NM := 1.0
const SET_RANGE_NM := Vector2(5.0, 250.0)
## A wheel notch without Ctrl (N m) when the setting is the player's (trades.torque_kept).
const COARSE_STEP_NM := 5.0
## The last setting the player chose (N m), kept across the session's wrenches; < 0 for none.
static var kept_nm := -1.0

enum State { READY, RUNNING, CLUTCH, STALLED, STRIPPED }

## Reverse: undo mode, takes bolts out.
var undo := false
var state := State.READY
## Turns of the socket so far (radians), for the spinning anvil.
var turned := 0.0

var _socket: Node3D


func _ready() -> void:
	name = "PowerWrench"
	if kept_nm > 0.0 and Flags.is_on("trades.torque_kept"):
		set_nm = kept_nm
	grip = POWER_GRIP
	# In a relaxed hand: the barrel points along the fingers, the grip down through the palm.
	hold = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)), Vector3(0, -0.02, 0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var along := Vector3(PI * 0.5, 0, 0)
	# Impact socket and anvil, spinning together.
	_socket = Node3D.new()
	add_child(_socket)
	cylinder(0.0125, 0.03, Vector3(0, 0.015, 0), Vector3.ZERO, steel, 6, _socket)
	cylinder(0.0075, 0.012, Vector3(0, 0.036, 0), Vector3.ZERO, steel, 8, _socket)
	box(Vector3(0.004, 0.006, 0.026), Vector3(0, 0.029, 0), dark, Vector3.ZERO, _socket)
	# The hammer case, the orange motor housing with its vent ribs, and the dark end cap.
	cylinder(0.024, 0.036, Vector3(0, 0.058, 0), Vector3.ZERO, dark, 20)
	cylinder(0.02, 0.006, Vector3(0, 0.079, 0), Vector3.ZERO, steel, 20)
	cylinder(0.031, 0.1, Vector3(0, 0.13, 0), Vector3.ZERO, body, 22)
	ribs(0.0322, Vector3(0, 0.15, 0), Vector3.UP, 4, 0.01)
	cylinder(0.029, 0.016, Vector3(0, 0.188, 0), Vector3.ZERO, dark, 22)
	print_text("BSX", Vector3(0.0318, 0.12, 0), Vector3.RIGHT, Vector3.UP, 0.012)
	print_text("BSX", Vector3(-0.0318, 0.12, 0), Vector3.LEFT, Vector3.UP, 0.012)
	# Pistol grip in rubber, the trigger and the forward/reverse switch, the battery pack.
	box(Vector3(0.03, 0.05, 0.03), Vector3(0, 0.14, 0.03), body)
	capsule(0.017, 0.1, POWER_GRIP + Vector3(0, 0, 0.005), along, rubber)
	ribs(0.018, Vector3(0, 0.155, 0.06), Vector3.BACK, 4, 0.016)
	box(Vector3(0.012, 0.016, 0.02), Vector3(0, 0.128, 0.045), dark)
	cylinder(0.005, 0.044, Vector3(0, 0.168, 0.038), Vector3(0, 0, PI * 0.5), steel, 10)
	box(Vector3(0.062, 0.082, 0.05), Vector3(0, 0.158, 0.155), dark)
	box(Vector3(0.064, 0.012, 0.052), Vector3(0, 0.205, 0.155), body)
	# The display on the end cap, facing back up the barrel at you.
	add_screen(Vector3(0, 0.197, 0), Vector3.UP, Vector2(0.04, 0.03), 6, 3, Vector3.FORWARD)


func _process(delta: float) -> void:
	if _socket:
		_socket.rotation.y = turned
	super(delta)


## Wheel: the setting up (+1) or down (-1).
func step_setting(step: int) -> void:
	set_nm = clampf(set_nm + step * SET_STEP_NM, SET_RANGE_NM.x, SET_RANGE_NM.y)


func readout_text() -> String:
	var now := "%5.1f" % applied_nm if applied_nm > 0.05 else _state_word()
	return "%s %d\n%s\nNm" % ["UNDO" if undo else "SET", roundi(set_nm), now]


func panel_rows() -> Array:
	return [["MODE", "UNDO" if undo else "FASTEN"], ["SET", "%d N m" % roundi(set_nm)],
			["TORQUE", "%.1f N m" % applied_nm if applied_nm > 0.05 else "-"]]


func panel_state() -> String:
	return _state_word()


func readout_fill() -> float:
	return applied_nm / maxf(set_nm, 1.0)


func readout_alert() -> bool:
	return state != State.READY


func _state_word() -> String:
	match state:
		State.RUNNING:
			return "UNDOING" if undo else "RUNNING"
		State.CLUTCH:
			return "CLUTCH: LET GO"
		State.STALLED:
			return "STALLED"
		State.STRIPPED:
			return "THREAD STRIPPED"
	return "READY"
