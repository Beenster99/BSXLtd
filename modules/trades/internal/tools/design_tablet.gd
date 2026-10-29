class_name TradesDesignTablet
extends TradesTool
## The design tablet (trades.beam_designer): a rugged slate in BSX orange with a blue
## hologram lens on its top edge that throws the beam design round the ship in the courtyard
## (TradesBeamDesigner does the drawing). Its screen says what you are doing and the section
## your next beam is in.
##
## Its own space: the lens at the origin, the slate back along +Y, its face toward -Z.

const GRIP := Vector3(0, 0.1, 0.01)

## For its screen (the designer sets them each frame).
var section := ""
var doing := ""
var count := 0
## trades.beam_versions: the version showing ("" with versions off) and the last test's
## verdict on it ("PASS", "FAIL", "" untested or changed since).
var version := ""
var test := ""


func _ready() -> void:
	name = "Tablet"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)), Vector3(0, -0.02, -0.02))
	var body := body()
	var rubber := rubber()
	box(Vector3(0.2, 0.15, 0.016), Vector3(0, 0.08, 0), body)
	for x: float in [-0.1, 0.1]:
		box(Vector3(0.012, 0.16, 0.022), Vector3(x, 0.08, 0), rubber)
	var lens := TradesLook.metal(Color(0.3, 0.7, 1.0), 0.2, 0.2)
	cylinder(0.012, 0.03, Vector3(0, 0.0, 0), Vector3(0, 0, PI * 0.5), lens, 12)
	add_screen(Vector3(0, 0.085, -0.0085), Vector3.FORWARD, Vector2(0.16, 0.11), 14, 4, Vector3.UP, Color(0.5, 0.85, 1.0))


func readout_text() -> String:
	var head := "BEAM DESIGN" if version == "" else "DESIGN %s%s" % [version, "  " + test if test != "" else ""]
	return "%s\n%s\n%s\n%d BEAMS" % [head, section.left(14).to_upper(), doing.left(14).to_upper(), count]


func panel_rows() -> Array:
	var rows := [["Next", section.get_slice(" ", 0) + " " + section.get_slice(" ", 1)], ["Beams", str(count)]]
	if version != "":
		rows.push_front(["Version", version + ("  " + test if test != "" else "")])
	return rows


func panel_state() -> String:
	return doing.to_upper() if doing != "" else "READY"
