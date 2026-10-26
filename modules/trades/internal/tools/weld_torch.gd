class_name TradesWeldTorch
extends TradesTool
## MIG torch on its hose: a copper gas nozzle round a brass contact tip, an insulated swan
## neck, an orange handle in rubber with the trigger, a screen pod on the hose collar (the
## welder's amps and the arc length while it burns) and a strain-relief spring on the hose.
##
## Its own space: the nozzle's tip at the origin pointing down -Y, the neck straight up +Y,
## then the handle rising back at 45 degrees toward +Z.

const GRIP := Vector3(0, 0.1245, 0.0495)
const AMPS_MAX := 200.0
## Cutting a weld out runs the arc hot (amps).
const CUT_AMPS := 180.0

## The arc is lit (the wire tip glows).
var lit := false
## The welder's setting, and the arc length while lit (mm); the welding station sets them.
var amps := 110.0
var arc_mm := 0.0
## Cutting a weld out (unweld) rather than laying one: the arc gouges the bead away.
var cutting := false
## Switched to unweld (X, beenster 0.3.7): left click cuts welds out instead of laying them.
var unweld := false
## How far through the cut is (0..1), while cutting.
var cut := 0.0
## Heating a rivet out rather than working a seam: no shield needed (beenster, 2026-10-22).
var on_rivet := false
## How fast the arc is travelling along the seam (mm/s; trades.weld_skill), < 0 when not.
var speed_mm_s := -1.0

var _tip: MeshInstance3D
var _wire: Material
var _hot: Material


func _ready() -> void:
	name = "WeldTorch"
	grip = GRIP
	# Carried like a pistol, the nozzle forward and a little down and the handle in your fist,
	# low in the view rather than stood up in the middle of it (beenster, 0.3.15: "when in
	# hand the welder tool obscures the screen"). Flag trades.welder_clear.
	if Flags.is_on("trades.welder_clear"):
		hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(70.0)), Vector3(0, -0.035, 0.02))
	else:
		hold = Transform3D(Basis(Vector3.RIGHT, -PI * 0.25), Vector3(0, -0.02, 0))
	var copper := TradesLook.metal(Color(0.78, 0.45, 0.28), 0.9, 0.3)
	var brass := TradesLook.metal(Color(0.8, 0.66, 0.35), 0.9, 0.3)
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	var steel := steel()
	_wire = steel
	_hot = TradesLook.glow(Color(1.0, 0.85, 0.6), 6.0)
	_tip = cylinder(0.0008, 0.008, Vector3(0, 0.002, 0), Vector3.ZERO, _wire, 6)        # wire stick-out
	var up45 := Vector3(PI * 0.25, 0, 0)
	var bend := Vector3(0, 0.075, 0)
	var along := Vector3(0, 0.7071, 0.7071)
	var over := Vector3(0, 0.7071, -0.7071)
	cylinder(0.0025, 0.01, Vector3(0, 0.008, 0), Vector3.ZERO, brass, 10)                  # contact tip
	cylinder(0.0075, 0.032, Vector3(0, 0.02, 0), Vector3.ZERO, copper, 18, self, 0.0105)   # gas nozzle
	cylinder(0.011, 0.006, Vector3(0, 0.038, 0), Vector3.ZERO, rubber, 18)                 # insulator
	cylinder(0.0085, 0.036, Vector3(0, 0.058, 0), Vector3.ZERO, dark, 14)                  # swan neck
	cylinder(0.0085, 0.024, bend + along * 0.008, up45, dark, 14)
	cylinder(0.0105, 0.01, bend + along * 0.022, up45, steel, 16)                          # neck nut
	capsule(0.0165, 0.115, bend + along * 0.075, up45, body)                               # handle
	ribs(0.0172, bend + along * 0.075, along, 4, 0.012)
	box(Vector3(0.009, 0.022, 0.016), bend + along * 0.055 - over * 0.017, dark, up45)    # trigger
	print_text("BSX", bend + along * 0.11 + Vector3(0.0166, 0, 0), Vector3.RIGHT, along, 0.009)
	# The hose collar carries the screen pod, looking up past the gloved hand.
	cylinder(0.0125, 0.05, bend + along * 0.155, up45, dark, 14)
	var pod := bend + along * 0.16 + over * 0.017
	box(Vector3(0.042, 0.012, 0.046), pod, dark)
	add_screen(pod + Vector3(0, 0.0065, 0), Vector3.UP, Vector2(0.034, 0.038), 6, 3, Vector3.FORWARD,
			Color(1.0, 0.72, 0.35))
	# Strain-relief spring and the hose.
	for i in 6:
		cylinder(0.0115, 0.003, bend + along * (0.186 + i * 0.008), up45, dark, 12)
	cylinder(0.009, 0.12, bend + along * 0.24, up45, rubber, 12)


func _process(delta: float) -> void:
	_tip.material_override = _hot if lit else _wire
	super(delta)


## Under the shield its display would stand in the middle of the glass, over the seam: it
## folds away while the arc burns (trades.welder_clear).
func display_hidden() -> bool:
	return lit and not on_rivet and Flags.is_on("trades.welder_clear")


func readout_text() -> String:
	if lit and cutting:
		return "%3d A\nCUT\n%3d%%" % [roundi(CUT_AMPS), roundi(cut * 100.0)]
	if lit and speed_mm_s >= 0.0:
		return "%3d A\nSPEED\n%3dmm/s" % [roundi(amps), roundi(speed_mm_s)]
	if lit:
		return "%3d A\nARC\n%3.1fmm" % [roundi(amps), arc_mm]
	return "%3d A\n%s\nREADY" % [roundi(amps), "UNWELD" if unweld else "WIRE"]


func readout_fill() -> float:
	return cut if lit and cutting else amps / AMPS_MAX


func panel_rows() -> Array:
	if lit and cutting:
		return [["MODE", "UNWELD"], ["CURRENT", "%d A" % roundi(CUT_AMPS)], ["CUT", "%d %%" % roundi(cut * 100.0)]]
	var rows := [["MODE", "UNWELD" if unweld else "WELD"], ["CURRENT", "%d A" % roundi(amps)]]
	rows.append(["ARC", "%.1f mm" % arc_mm if lit else "-"])
	if lit and speed_mm_s >= 0.0:
		rows.append(["SPEED", "%d mm/s" % roundi(speed_mm_s)])
	return rows


func panel_state() -> String:
	if lit:
		return "CUTTING" if cutting else "ARC ON"
	return "READY"


func readout_alert() -> bool:
	return lit
