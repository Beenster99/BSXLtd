class_name TradesTemplateScribe
extends TradesTool
## The template scribe: a steel holder with a stick of white soapstone chalk at its tip and a
## tape reel on its side that counts the line out, held like a pen (TradesPlateTracer does the
## tracing). Its screen shows how far round the plate the line has gone.
##
## Its own space: the chalk's tip at the origin, the holder back along +Y.

const GRIP := Vector3(0, 0.08, 0.0)

## How far round the plate (0..1) and which plate, for the screen.
var progress := 0.0
var plate := ""


func _ready() -> void:
	name = "Scribe"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-60.0)), Vector3(0, -0.01, 0.0))
	var steel := steel()
	var body := body()
	var rubber := rubber()
	var chalk := TradesLook.metal(Color(0.95, 0.95, 0.9), 0.0, 0.95)
	# The chalk stick, the collet that holds it, the knurled steel holder and a rubber grip.
	box(Vector3(0.006, 0.03, 0.012), Vector3(0, 0.015, 0), chalk)
	cylinder(0.008, 0.016, Vector3(0, 0.036, 0), Vector3.ZERO, steel, 12)
	cylinder(0.007, 0.08, Vector3(0, 0.08, 0), Vector3.ZERO, steel, 12)
	capsule(0.009, 0.06, Vector3(0, 0.1, 0), Vector3.ZERO, rubber)
	# The tape reel on its side in BSX orange, its tape running down to the tip.
	cylinder(0.022, 0.012, Vector3(0.018, 0.12, 0), Vector3(0, 0, PI * 0.5), body, 20)
	box(Vector3(0.002, 0.09, 0.006), Vector3(0.011, 0.075, 0), TradesLook.metal(Color(0.9, 0.8, 0.2), 0.3, 0.5))
	add_screen(Vector3(0.025, 0.12, 0), Vector3.RIGHT, Vector2(0.03, 0.02), 7, 2, Vector3.UP)


func readout_text() -> String:
	if plate == "":
		return "TRACE\nA PLATE"
	return "%s\n%d%%" % [plate.left(10).to_upper(), roundi(progress * 100.0)]
