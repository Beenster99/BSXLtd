class_name TradesTemplateScribe
extends TradesTool
## The template scribe: a steel holder with a stick of white soapstone chalk at its tip and a
## tape reel on its side that counts the line out, held like a pen (TradesPlateTracer finds
## and saves the plate). Its screen names the plate you point at and whether it is saved.
##
## Its display is a summary of the plate you point at (beenster, 29 Oct: the whole sheet is on
## the right-hand panel), held further up and left of the tool than the others' so the scribe,
## pointing ahead, never shows through it.
##
## Its own space: the chalk's tip at the origin, the holder back along +Y.

const GRIP := Vector3(0, 0.08, 0.0)
## Its display, close up: left and up of the knuckle as the view sees it (metres).
const BESIDE_SCRIBE := Vector2(-0.17, 0.06)

## The plate pointed at and the config it is saved as ("" for none), for the screen.
var plate := ""
var saved := ""
## Its size across its face (m; zero for none), its state on the ship and its mass (kg; 0 unknown).
var size := Vector2.ZERO
var state := ""
var mass_kg := 0.0


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


func display_beside() -> Vector2:
	return BESIDE_SCRIBE


## The summary, three rows the screen fits: the plate, its size and its mass; the foot says
## whether it is saved.
func panel_rows() -> Array:
	if plate == "":
		return [["PLATE", "none"]]
	var rows: Array = [["PLATE", short_name(plate)]]
	if size != Vector2.ZERO:
		rows.append(["SIZE", "%.1fx%.1f m" % [maxf(size.x, size.y), minf(size.x, size.y)]])
	if mass_kg > 0.0:
		rows.append(["MASS", "%.1f t" % (mass_kg / 1000.0) if mass_kg >= 1000.0 else "%d kg" % roundi(mass_kg)])
	elif state != "":
		rows.append(["STATE", state])
	return rows


func panel_state() -> String:
	if plate == "":
		return "POINT AT A PLATE"
	return ("SAVED " + saved) if saved != "" else "CLICK TO SAVE"


## A plate's name short enough for the screen: "Hull plate (bulkhead, e2)" is "BULKHEAD E2".
static func short_name(name: String) -> String:
	var n := name
	var open := n.find("(")
	if open >= 0 and n.ends_with(")"):
		n = n.substr(open + 1, n.length() - open - 2)
	return n.replace(",", "").to_upper().left(11)


func readout_text() -> String:
	if plate == "":
		return "POINT AT\nA PLATE"
	return "%s\n%s" % [plate.left(10).to_upper(), "SAVED " + saved if saved != "" else "CLICK: SAVE"]
