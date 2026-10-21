class_name TradesTractorTool
extends TradesTool
## The hand tractor projector, a sibling of Void Salvage's grabber: three emitter prongs round
## a lens, a body wound with three lit field coils, a screen on its back end (the load, how
## far out it is, how well it lines up), a rubber pistol grip and a big battery pack.
##
## Its own space: the lens at the origin, the beam out along +Y, the grip back along +Z
## (held like the drill).

const GRIP := Vector3(0, 0.2, 0.11)
const BEAM_COLOR := Color(0.35, 0.85, 1.0)
const ALIGNED_COLOR := Color(0.45, 1.0, 0.55)

## The beam is on (lights the coils and the lens).
var on := false
## What the screen shows while the beam holds something.
var load_kg := 0.0
var distance_m := 0.0
## 0..1, how close the held part is to lining up with its mount (1 = in line).
var align := -1.0

var _coils: Array[MeshInstance3D] = []
var _lens: MeshInstance3D
var _coil_off: Material
var _coil_on: Material
var _coil_aligned: Material
var _spin := 0.0
var _prongs: Node3D


func _ready() -> void:
	name = "Tractor"
	grip = GRIP
	hold = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-70.0)), Vector3(0, -0.02, 0.0))
	var steel := steel()
	var dark := anodised()
	var body := body()
	var rubber := rubber()
	_coil_off = TradesLook.metal(Color(0.1, 0.22, 0.28), 0.6, 0.35)
	_coil_on = TradesLook.glow(BEAM_COLOR, 3.0)
	_coil_aligned = TradesLook.glow(ALIGNED_COLOR, 3.0)
	# The emitter head: a dish with the lens in it and three prongs round it.
	cylinder(0.034, 0.012, Vector3(0, -0.004, 0), Vector3.ZERO, dark, 24, self, 0.026)       # dish
	_lens = cylinder(0.018, 0.004, Vector3(0, 0.003, 0), Vector3.ZERO, _coil_off, 20)
	_prongs = Node3D.new()
	add_child(_prongs)
	for i in 3:
		var a := i * TAU / 3.0
		var at := Vector3(cos(a), 0, sin(a)) * 0.03
		box(Vector3(0.008, 0.04, 0.008), at + Vector3(0, 0.012, 0), steel, Vector3(0, -a, 0.0), _prongs)
		box(Vector3(0.011, 0.008, 0.011), at + Vector3(0, 0.033, 0), dark, Vector3(0, -a, 0.0), _prongs)
	# The body: a collar, three field coils with dark spacers, and a cap.
	cylinder(0.028, 0.012, Vector3(0, -0.016, 0), Vector3.ZERO, steel, 20)
	for i in 3:
		var y := -0.032 - i * 0.026
		_coils.append(cylinder(0.031, 0.012, Vector3(0, y, 0), Vector3.ZERO, _coil_off, 24))
		cylinder(0.026, 0.014, Vector3(0, y - 0.013, 0), Vector3.ZERO, dark, 20)
	cylinder(0.03, 0.05, Vector3(0, -0.13, 0), Vector3.ZERO, body, 20)                      # motor body
	for i in 5:
		var a := PI * 0.5 + (i - 2.0) * 0.36
		box(Vector3(0.0025, 0.03, 0.004), Vector3(cos(a) * 0.03, -0.13, sin(a) * 0.03), dark, Vector3(0, -a, 0))
	print_text("BSX", Vector3(0.0302, -0.13, 0.0), Vector3.RIGHT, Vector3.UP, 0.012)
	print_text("BSX", Vector3(-0.0302, -0.13, 0.0), Vector3.LEFT, Vector3.UP, 0.012)
	# The back end, with the screen looking back at the holder.
	box(Vector3(0.058, 0.04, 0.03), Vector3(0, -0.17, 0.0), dark)
	if Flags.is_on("trades.tool_display"):
		# The display's arm on the coils' left side: the back end is too near the eye in hand.
		add_screen(Vector3(-0.031, -0.058, 0), Vector3.LEFT, Vector2(0.05, 0.034), 9, 3, Vector3.UP)
	else:
		add_screen(Vector3(0, -0.1702, 0.0151), Vector3.BACK, Vector2(0.05, 0.034), 9, 3, Vector3.UP)
	# Pistol grip, trigger, and the battery pack under it.
	box(Vector3(0.028, 0.034, 0.11), Vector3(0, -0.15, 0.07), body, Vector3(0.25, 0, 0))
	capsule(0.017, 0.1, Vector3(0, -0.156, 0.08), Vector3(PI * 0.5 + 0.25, 0, 0), rubber)
	box(Vector3(0.01, 0.02, 0.014), Vector3(0, -0.172, 0.03), dark)                        # trigger
	box(Vector3(0.056, 0.036, 0.075), Vector3(0, -0.188, 0.135), body)                     # battery
	box(Vector3(0.058, 0.007, 0.077), Vector3(0, -0.208, 0.135), rubber)
	var charge := TradesLook.glow(Color(0.4, 1.0, 0.45), 2.5)
	for i in 4:
		box(Vector3(0.006, 0.003, 0.002), Vector3(-0.0135 + i * 0.009, -0.185, 0.1728), charge)


func _process(delta: float) -> void:
	_spin += (6.0 if on else 0.0) * delta
	_prongs.rotation.y = _spin
	var mat := _coil_off
	if on:
		mat = _coil_aligned if align >= 1.0 else _coil_on
	for c in _coils:
		c.material_override = mat
	_lens.material_override = mat
	super(delta)


## The way the beam leaves the lens, world space.
func beam_dir() -> Vector3:
	return global_basis.y.normalized()


func beam_from() -> Vector3:
	return global_position + beam_dir() * 0.01


func readout_text() -> String:
	if not on:
		return "TRACTOR\nREADY"
	var t := "%4.0fkg" % load_kg if load_kg < 1000.0 else "%4.1ft" % (load_kg / 1000.0)
	var line3 := "IN LINE" if align >= 1.0 else ("LINE %3d%%" % roundi(align * 100.0) if align >= 0.0 else "")
	return "LOAD%s\nOUT %4.1fm\n%s" % [t, distance_m, line3]


func panel_rows() -> Array:
	if not on:
		return [["LOAD", "-"], ["OUT", "-"]]
	var weight := "%d kg" % roundi(load_kg) if load_kg < 1000.0 else "%.1f t" % (load_kg / 1000.0)
	var rows := [["LOAD", weight], ["OUT", "%.1f m" % distance_m]]
	if align >= 0.0:
		rows.append(["LINE", "IN LINE" if align >= 1.0 else "%d %%" % roundi(align * 100.0)])
	return rows


func panel_state() -> String:
	if not on:
		return "READY"
	return "IN LINE" if align >= 1.0 else "HOLDING"


func readout_fill() -> float:
	return align if on else -1.0


func readout_alert() -> bool:
	return on
