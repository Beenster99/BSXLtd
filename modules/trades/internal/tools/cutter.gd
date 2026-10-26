class_name TradesCutter
extends TradesTool
## The cutter, a cordless angle grinder with a thin cutting disc (beenster, 0.3.7: "a cutter
## tool which allows a player to grind off rivets"): the disc spins up, grinds the rivet's
## head off flush in a shower of sparks, and the rivet's tail drops out.
##
## Its own space: the disc's edge at the origin on the rivet, the disc in the plane of Y and Z
## (its face toward ±X), the motor body running back along +Z with the side handle across it.

const GRIP := Vector3(0, 0.06, 0.2)
const RPM := 11000

## Spinning (0..1), turns the disc.
var spin := 0.0
## How far through the head it has ground (0..1).
var ground := 0.0
## The disc is in the work (trades.vs_tools): its rim heats while it bites and cools after.
var biting := false
## How hot the disc's rim is (0..1): a dull red glow at 1.
var heat := 0.0

## Seconds of biting to heat the rim through, and to cool it again.
const GLOW_S := 7.0
const COOL_S := 5.0

var _disc: Node3D
var _disc_mat: StandardMaterial3D


func _ready() -> void:
	name = "Cutter"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, -0.03, 0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var along := Vector3(PI * 0.5, 0, 0)
	var across := Vector3(0, 0, PI * 0.5)
	# The disc on its arbor, half behind the guard.
	_disc = Node3D.new()
	_disc.position = Vector3(0, 0.055, 0)
	add_child(_disc)
	_disc_mat = TradesLook.metal(Color(0.32, 0.3, 0.28), 0.4, 0.7) as StandardMaterial3D
	_disc_mat.emission = Color(1.0, 0.32, 0.06)
	cylinder(0.055, 0.0016, Vector3.ZERO, across, _disc_mat, 28, _disc)
	cylinder(0.012, 0.004, Vector3.ZERO, across, steel, 12, _disc)
	box(Vector3(0.003, 0.005, 0.03), Vector3(0.002, 0.0, 0.0), TradesLook.metal(Color(0.85, 0.2, 0.1), 0.2, 0.5), Vector3.ZERO, _disc)
	# The guard over the back half, the gear head, the orange motor body, the side handle.
	box(Vector3(0.012, 0.03, 0.065), Vector3(0.008, 0.1, 0.02), dark)
	cylinder(0.022, 0.03, Vector3(0.018, 0.055, 0.02), across, dark, 18)
	box(Vector3(0.045, 0.05, 0.05), Vector3(0.022, 0.06, 0.06), dark)
	capsule(0.026, 0.16, Vector3(0.022, 0.06, 0.15), along, body)
	ribs(0.0272, Vector3(0.022, 0.06, 0.1), Vector3.BACK, 3, 0.014)
	capsule(0.012, 0.08, Vector3(0.022, 0.11, 0.06), Vector3.ZERO, rubber)
	capsule(0.017, 0.07, Vector3(0.022, 0.06, 0.24), along, rubber)
	box(Vector3(0.06, 0.07, 0.05), Vector3(0.022, 0.06, 0.29), dark)
	print_text("BSX", Vector3(0.0485, 0.06, 0.15), Vector3.RIGHT, Vector3.UP, 0.012)
	add_screen(Vector3(0.022, 0.087, 0.17), Vector3.UP, Vector2(0.034, 0.026), 6, 3, Vector3.FORWARD)


func _process(delta: float) -> void:
	if _disc:
		_disc.rotation.x += delta * spin * 60.0
	heat = clampf(heat + delta / GLOW_S if biting else heat - delta / COOL_S, 0.0, 1.0)
	if _disc_mat:
		_disc_mat.emission_enabled = heat > 0.02
		_disc_mat.emission_energy_multiplier = 2.5 * heat * heat
	super(delta)


func readout_text() -> String:
	return "%5d\nRPM\n%s" % [roundi(RPM * spin), "%3d%%" % roundi(ground * 100.0) if ground > 0.0 else ""]


func panel_rows() -> Array:
	return [["DISC", "%d RPM" % roundi(RPM * spin) if spin > 0.01 else "-"],
			["GROUND", "%d %%" % roundi(ground * 100.0) if ground > 0.0 else "-"],
			["DISC TEMP", "%d C" % roundi(20.0 + heat * 560.0)]]


func panel_state() -> String:
	if biting or spin >= 0.999:
		return "GRINDING"
	return "SPINNING UP" if spin > 0.01 else "READY"


func readout_fill() -> float:
	return ground


func readout_alert() -> bool:
	return spin > 0.01
