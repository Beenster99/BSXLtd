extends RefCounted
## The Kestrel's ship systems as Void Salvage draws them. The ship file carries each system
## (the bowsers, the hose rack, the fuel port, the cargo control panel, the door panels, the
## hold monitor, the cockpit's screens) only as a box and a plain part, because Void Salvage
## builds their looks in code that isn't shared; likewise the leads' wires are only routes and
## the floodlights only points. This dresses them from the file: every system on the frame
## its part's transform gives (the frames Void Salvage's BaseShip builds them on), the wires
## along `derived.routes`, the floodlights from `layout.floodlights`.
##
## Looks only, but for the bowsers' drums, which are solid: the file's parts keep their
## collision and joints, and the screens show a parked ship's standby text (no ship systems
## in the yard). Lit pieces glow, so the model's
## power switch darkens them with the rest.

## Where each system's part sits on its frame (Void Salvage's builders), frame space.
const PART_OFFSET := {
	"bowsers": Vector3(0.14, 0.42, 0.0),
	"hose_rack": Vector3(0.015, 0.0, 0.0),
	"fuel_port": Vector3(0.03, 0.0, 0.3),
	"control_panel": Vector3(0.03, 0.0, 0.0),
	"door_panel": Vector3(0.02, 0.0, 0.0),
	"monitor": Vector3(0.04, -0.075, 0.0),
}
## The hold monitor's soft keys, left to right as you face it (FOCUS apart on the right).
const MONITOR_KEYS := ["<", ">", "^", "v", "MARK", "FOCUS"]
const SCREEN_TEXT := Color(0.45, 0.95, 1.0)
const LABEL := Color(0.85, 0.92, 1.0)
const PUMP_IDLE := Color(0.35, 1.0, 0.6)
## How full the bowsers' gauges read (0..1): a ship in for work, part drained.
const BOWSER_LEVELS := {"fuel": 0.62, "coolant": 0.38}
## Wire sheath (m) and how many sides its tube has.
const WIRE_RADIUS := 0.009
const WIRE_SIDES := 6

var body: Node3D
var file: Dictionary
var hull_dark: Material
var hazard: Material
var steel: Material
var dark: Material
## Door key -> the lamp materials on its panels (lit green while the door is open).
var door_lamps: Dictionary = {}
var spots: Array[SpotLight3D] = []


func _init(target: Node3D, f: Dictionary) -> void:
	body = target
	file = f
	hull_dark = ShipSurface.of(ShipKit.paint(Color(0.2, 0.21, 0.23), 0.6, 0.5))
	hazard = ShipSurface.of(ShipKit.paint(Color(0.95, 0.62, 0.12), 0.3, 0.55))
	steel = ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.7, 0.4))
	dark = ShipSurface.of(ShipKit.paint(Color(0.12, 0.13, 0.14), 0.6, 0.5))


## Builds every system's look. `parts`: the file's part records by path.
func build(parts: Dictionary) -> void:
	for path: String in parts:
		var rec: Dictionary = parts[path]
		var xf := VsShipImport.xform(rec.get("xform", {}))
		var kind := str(rec.get("name", ""))
		if not PART_OFFSET.has(kind):
			continue
		var frame := xf * Transform3D(Basis(), -(PART_OFFSET[kind] as Vector3))
		match kind:
			"bowsers": _bowsers(frame)
			"hose_rack": _hose_rack(frame)
			"fuel_port": _fuel_port(frame)
			"control_panel": _control_panel(frame, "CARGO CONTROL")
			"door_panel": _door_panel(frame, path.trim_prefix("system:").get_slice("/", 0))
			"monitor": _monitor(frame, Vector2(1.52, 0.855))
	for s: Dictionary in file.get("systems", []):
		var box: Dictionary = s.get("box", {})
		var centre := VsShipImport.vec3(box.get("pos", [0, 0, 0])) + VsShipImport.vec3(box.get("size", [0, 0, 0])) * 0.5
		var args: Array = s.get("args", [])
		match str(s.get("system", "")):
			"cockpit_screen": _cockpit_screen(centre, float(args[0]) if args.size() > 0 else 30.0,
					["FLIGHT", "SHORE POWER", "DRIVE  SAFED", "HELM   LOCKED"])
			"cockpit_monitor": _cockpit_screen(centre, float(args[0]) if args.size() > 0 else 30.0,
					["HOLD", "0 / 2,400 KG", "NETS  STOWED", "BAY   CLOSED"])
			"nav_display": _nav_display(centre, float(args[0]) if args.size() > 0 else 30.0,
					float(args[1]) if args.size() > 1 else 0.62, float(args[2]) if args.size() > 2 else 0.38)
			"map_screen": _map_screen(centre, float(args[0]) if args.size() > 0 else 0.62, float(args[1]) if args.size() > 1 else 0.44)
	_floodlights()
	_nav_lamps()
	_wires()


# --- systems ---------------------------------------------------------------------------------

## Two upright drums, fuel and coolant, piped from a manifold block on the wall with PUMP and
## TANK buttons, each with a level gauge. `frame`: on the wall, X into the hold, Y up.
func _bowsers(frame: Transform3D) -> void:
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)
	var out_x := Basis(Vector3.BACK, -PI * 0.5)
	_add(PartShapes.prism(10, 0.06, 0.12), frame * Transform3D(along_z, Vector3(0.1, 0.32, -0.26)), dark)
	_box(frame, Vector3(0.27, 0.48, 0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(PUMP_IDLE, 0.6))
	_label("PUMP", frame, Vector3(0.262, 0.58, 0.075), 18, LABEL)
	_box(frame, Vector3(0.27, 0.48, -0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(Color(1.0, 0.65, 0.15), 0.6))
	_label("TANK", frame, Vector3(0.262, 0.58, -0.075), 18, Color(1.0, 0.8, 0.45))
	_label("MANIFOLD", frame, Vector3(0.262, 0.27, 0.0), 16, LABEL)
	_screen(frame, Vector3(0.0, 1.05, 0.0), Vector2(0.5, 0.24), 16, "BOWSERS\nFUEL  %d%%\nCOOL  %d%%" % [
			roundi(BOWSER_LEVELS["fuel"] * 100.0), roundi(BOWSER_LEVELS["coolant"] * 100.0)])
	var coolant := ShipSurface.of(ShipKit.paint(Color(0.22, 0.52, 0.66), 0.35, 0.5))
	for t: Array in [["fuel", 1.05, hazard, Color(1.0, 0.65, 0.15), 0.25], ["coolant", 2.25, coolant, Color(0.35, 0.85, 1.0), 0.55]]:
		var z: float = t[1]
		var pipe_y: float = t[4]
		var at := Vector3(0.72, 0.0, z)
		_add(PartShapes.prism(20, 0.56, 0.14), frame * Transform3D(Basis(), at + Vector3(0, 0.07, 0)), dark)
		_add(PartShapes.prism(20, 0.5, 2.2), frame * Transform3D(Basis(), at + Vector3(0, 1.24, 0)), t[2])
		_add(PartShapes.dome(0.5, 0.22, 20, 4), frame * Transform3D(Basis(), at + Vector3(0, 2.34, 0)), t[2])
		_add(PartShapes.ring(0.5, 0.52, 0.08), frame * Transform3D(Basis(), at + Vector3(0, 2.05, 0)), dark)
		# Solid, so crew walk round the drums (the file's part is only the manifold block).
		var drum := CollisionShape3D.new()
		drum.name = "Bowser_" + str(t[0])
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.5
		cyl.height = 2.45
		drum.shape = cyl
		drum.transform = frame * Transform3D(Basis(), at + Vector3(0, 1.235, 0))
		body.add_child(drum)
		var run := z - 0.2
		_add(PartShapes.prism(10, 0.045, run), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.2 + run * 0.5)), steel)
		_add(PartShapes.prism(10, 0.045, 0.18), frame * Transform3D(out_x, Vector3(0.14, pipe_y, z)), steel)
		_add(PartShapes.prism(10, 0.05, 0.06), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.32)), ShipKit.glow(t[3], 0.8))
		# The level gauge on the front: a slot with ticks and a lit bar up to the level.
		var face := 0.72 + 0.5
		var low := 0.45
		var high := 2.0
		_box(frame, Vector3(face, (low + high) * 0.5, z), Vector3(0.04, high - low + 0.12, 0.17), dark)
		_box(frame, Vector3(face + 0.021, (low + high) * 0.5, z), Vector3(0.004, high - low, 0.08), ShipKit.glow(Color(0.02, 0.03, 0.04), 1.0))
		for k in 5:
			var y := lerpf(low, high, float(k) / 4.0)
			_box(frame, Vector3(face + 0.023, y, z + 0.065), Vector3(0.003, 0.008, 0.035 if k % 2 == 0 else 0.022), ShipKit.glow(Color.WHITE, 0.5))
		var level: float = BOWSER_LEVELS[t[0]]
		var bar_h := (high - low) * level
		_box(frame, Vector3(face + 0.025, low + bar_h * 0.5, z), Vector3(0.006, bar_h, 0.06), ShipKit.glow(t[3], 0.8))
		_label((t[0] as String).to_upper(), frame, Vector3(face + 0.022, high + 0.17, z), 40, t[3])
		_label("%d L" % roundi(level * 400.0), frame, Vector3(face + 0.022, low - 0.16, z), 26, LABEL)


## The wall rack the fuel hose hangs on: a backing board, two hooks, a hazard strap, and
## the hose coiled over the hooks with its nozzle hanging. `frame`: X out of the wall.
func _hose_rack(frame: Transform3D) -> void:
	var rack := ShipSurface.of(ShipKit.paint(Color(0.2, 0.21, 0.23), 0.6, 0.5))
	for z: float in [-0.22, 0.22]:
		_box(frame, Vector3(0.17, 0.34, z), Vector3(0.3, 0.05, 0.05), rack)
		_box(frame, Vector3(0.3, 0.38, z), Vector3(0.04, 0.1, 0.05), rack)
	_box(frame, Vector3(0.035, -0.3, 0.0), Vector3(0.012, 0.08, 0.9), hazard)
	_label("FUEL HOSE", frame, Vector3(0.033, -0.38, 0.0), 20, Color(1.0, 0.75, 0.3))
	# The coil: turns of hose side by side, flat against the wall, hung on the hooks.
	var hose := ShipSurface.of(ShipKit.paint(Color(0.08, 0.08, 0.09), 0.1, 0.75))
	var face := Basis(Vector3.BACK, -PI * 0.5)   # a ring's axis (Y) out of the wall (X)
	for i in 5:
		var r := 0.3 - float(i) * 0.012
		_add(PartShapes.ring(r - 0.034, r, 0.034, 28), frame * Transform3D(face, Vector3(0.09 + float(i) * 0.036, 0.06, 0.0)), hose)
	# The nozzle on its tail, hanging down the front of the coil.
	var brass := ShipSurface.of(ShipKit.paint(Color(0.75, 0.55, 0.28), 0.9, 0.3))
	_add(PartShapes.prism(10, 0.017, 0.3), frame * Transform3D(Basis(), Vector3(0.29, -0.12, -0.3)), hose)
	_add(PartShapes.prism(12, 0.035, 0.16), frame * Transform3D(Basis(), Vector3(0.29, -0.34, -0.3)), brass)
	_add(PartShapes.frustum(0.03, 0.018, 0.08, 12), frame * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0.29, -0.46, -0.3)), steel)


## The fuel port on the hull: a brass coupling with a lit ring, a FUEL plate, a status screen,
## the PUMP button and the IN/OUT switch, and a work light. `frame`: on the hull, X out.
func _fuel_port(frame: Transform3D) -> void:
	var brass := ShipSurface.of(ShipKit.paint(Color(0.75, 0.55, 0.28), 0.9, 0.3))
	var face := Basis(Vector3.BACK, -PI * 0.5)
	_box(frame, Vector3(0.065, 0.45, 0.3), Vector3(0.01, 0.04, 1.25), hazard)
	_add(PartShapes.ring(0.065, 0.1, 0.12), frame * Transform3D(face, Vector3(0.1, 0.0, 0.0)), brass)
	_add(PartShapes.prism(16, 0.065, 0.02), frame * Transform3D(face, Vector3(0.06, 0.0, 0.0)), dark)
	_add(PartShapes.ring(0.105, 0.118, 0.02), frame * Transform3D(face, Vector3(0.065, 0.0, 0.0)), ShipKit.glow(Color(1.0, 0.7, 0.25), 2.0))
	_label("FUEL", frame, Vector3(0.063, 0.16, 0.0), 24, Color(1.0, 0.75, 0.3))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.88, 0.7)
	lamp.light_energy = 1.2
	lamp.omni_range = 4.5
	lamp.position = frame * Vector3(0.9, 0.75, 0.3)
	body.add_child(lamp)
	_screen(frame, Vector3(0.06, 0.17, 0.6), Vector2(0.5, 0.24), 16, "PORT  CAPPED\nPUMP  OFF\nFLOW  IN")
	_box(frame, Vector3(0.08, -0.2, 0.74), Vector3(0.04, 0.12, 0.12), ShipKit.glow(PUMP_IDLE, 0.6))
	_label("PUMP", frame, Vector3(0.063, -0.31, 0.74), 18, LABEL)
	var pivot := Vector3(0.075, -0.2, 0.47)
	_box(frame, Vector3(0.068, -0.2, 0.47), Vector3(0.016, 0.16, 0.09), hull_dark)
	var up := Basis(Vector3.BACK, 0.6)
	var lever := ShipSurface.of(ShipKit.paint(Color(0.7, 0.72, 0.74), 0.8, 0.3))
	_add(PartShapes.box(Vector3(0.11, 0.022, 0.022)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.055, 0, 0)), lever)
	_add(PartShapes.box(Vector3(0.035, 0.035, 0.035)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.115, 0, 0)), hazard)
	_label("IN", frame, Vector3(0.063, -0.065, 0.47), 18, LABEL)
	_label("OUT", frame, Vector3(0.063, -0.335, 0.47), 18, LABEL)


## The cargo control panel: a hazard band, its title, and a lit button with a lamp and a
## label for each of the file's `layout.panel_buttons`. `frame`: on the wall, X out.
func _control_panel(frame: Transform3D, title: String) -> void:
	var buttons: Array = file.get("layout", {}).get("panel_buttons", [])
	var count := buttons.size()
	var length := 0.36 * float(count) + 0.15
	_box(frame, Vector3(0.04, 0.44, 0), Vector3(0.02, 0.1, length), hazard)
	_label(title, frame, Vector3(0.063, 0.295, 0), 30, Color(0.95, 0.75, 0.3))
	for i in count:
		var b: Array = buttons[i]
		var bz := (float(count - 1) * 0.5 - float(i)) * 0.36
		_box(frame, Vector3(0.0675, 0.03, bz), Vector3(0.015, 0.22, 0.22), ShipSurface.of(ShipKit.paint(Color(0.1, 0.1, 0.11), 0.6, 0.4)))
		_box(frame, Vector3(0.08, 0.03, bz), Vector3(0.04, 0.16, 0.16), ShipKit.glow(VsShipImport.color(b[2]), 1.2))
		_box(frame, Vector3(0.066, 0.19, bz), Vector3(0.012, 0.035, 0.12), ShipKit.glow(Color(0.05, 0.05, 0.05), 0.2))
		_label(str(b[0]), frame, Vector3(0.063, -0.14, bz), 24, LABEL)


## A door panel: a hazard strip, a lamp that shows the door's state, and OPEN (green) over
## CLOSE (red). `frame`: on the wall, X out.
func _door_panel(frame: Transform3D, key: String) -> void:
	_box(frame, Vector3(0.027, 0.27, 0), Vector3(0.02, 0.04, 0.26), hazard)
	var lamp := ShipKit.glow(Color(0.6, 0.08, 0.05), 1.0)
	_box(frame, Vector3(0.042, 0.2, 0), Vector3(0.008, 0.03, 0.12), lamp)
	if not door_lamps.has(key):
		door_lamps[key] = []
	(door_lamps[key] as Array).append(lamp)
	for b: Array in [["OPEN", Color(0.3, 1.0, 0.45), 0.08], ["CLOSE", Color(1.0, 0.3, 0.2), -0.12]]:
		_box(frame, Vector3(0.05, b[2], 0), Vector3(0.025, 0.1, 0.1), ShipKit.glow(b[1], 1.2))
		_label(b[0], frame, Vector3(0.042, b[2] - 0.075, 0), 18, LABEL)


## Lights a door's panel lamps green while it's open, red while shut.
func show_door(key: String, open: bool) -> void:
	for lamp: StandardMaterial3D in door_lamps.get(key, []):
		lamp.emission = Color(0.3, 1.0, 0.45) if open else Color(0.6, 0.08, 0.05)


## The hold monitor on the bulkhead: a lit edge, a dark screen with the HOLD page's standby
## text, and the soft keys under it. `frame`: on the wall, X out.
func _monitor(frame: Transform3D, screen: Vector2) -> void:
	_box(frame, Vector3(0.085, 0.0, 0.0), Vector3(0.01, screen.y, screen.x), ShipKit.glow(Color(0.01, 0.04, 0.06), 0.4))
	_box(frame, Vector3(0.082, screen.y * 0.5 + 0.012, 0.0), Vector3(0.006, 0.006, screen.x), ShipKit.glow(ShipParts.EDGE, 1.2))
	var text := _label("HOLD MONITOR                 KESTREL\n\nHOLD      0 KG OF 2,400\nNETS      STOWED\nBAY DOOR  SHUT\n\nIN DOCK: SHIP SYSTEMS ON SHORE POWER",
			frame, Vector3(0.092, screen.y * 0.5 - 0.05, screen.x * 0.5 - 0.06), 26, SCREEN_TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var keys_y := -screen.y * 0.5 - 0.1
	var spacing := minf(0.2, screen.x / 7.0)
	for i in MONITOR_KEYS.size():
		var z := screen.x * 0.5 - 0.12 - float(i) * spacing
		if i == MONITOR_KEYS.size() - 1:
			z = -screen.x * 0.5 + 0.12
		_box(frame, Vector3(0.095, keys_y, z), Vector3(0.03, 0.07, 0.13), ShipKit.glow(Color(0.08, 0.32, 0.4), 0.6))
		_label(MONITOR_KEYS[i], frame, Vector3(0.112, keys_y, z), 22 if (MONITOR_KEYS[i] as String).length() < 3 else 16, SCREEN_TEXT)


## A cockpit screen on the console at `at`, tilted back `tilt_deg`: dark glass with a bezel
## and standby text.
func _cockpit_screen(at: Vector3, tilt_deg: float, lines: Array) -> void:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	_add(PartShapes.box(Vector3(0.74, 0.46, 0.025)), Transform3D(tilt, at - tilt * Vector3(0, 0, 0.012)), hull_dark)
	_add(PartShapes.box(Vector3(0.7, 0.42, 0.01)), Transform3D(tilt, at + tilt * Vector3(0, 0, 0.004)), ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0))
	var text := Label3D.new()
	text.text = "\n".join(lines)
	text.font = ShipKit.mono_font()
	text.font_size = 24
	text.pixel_size = 0.0015
	text.modulate = SCREEN_TEXT
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.transform = Transform3D(tilt, at + tilt * Vector3(-0.31, 0.18, 0.012))
	body.add_child(text)


## The nav display: a bezel, a dark screen with range rings and a cross, the ship's mark in
## the middle.
func _nav_display(at: Vector3, tilt_deg: float, width: float, height: float) -> void:
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	_add(PartShapes.box(Vector3(width + 0.06, height + 0.06, 0.025)), Transform3D(tilt, at - tilt * Vector3(0, 0, 0.012)), hull_dark)
	_add(PartShapes.box(Vector3(width, height, 0.01)), Transform3D(tilt, at + tilt * Vector3(0, 0, 0.004)), ShipKit.glow(Color(0.01, 0.05, 0.05), 1.0))
	var lines := ShipKit.glow(Color(0.2, 0.75, 0.6), 0.9)
	var flat := tilt * Basis(Vector3.RIGHT, PI * 0.5)   # a ring's axis (Y) out of the screen
	for r: float in [0.06, 0.12, 0.175]:
		_add(PartShapes.ring(r - 0.003, r, 0.002, 40), Transform3D(flat, at + tilt * Vector3(0, 0, 0.0105)), lines)
	_add(PartShapes.box(Vector3(width - 0.04, 0.003, 0.002)), Transform3D(tilt, at + tilt * Vector3(0, 0, 0.0105)), lines)
	_add(PartShapes.box(Vector3(0.003, height - 0.04, 0.002)), Transform3D(tilt, at + tilt * Vector3(0, 0, 0.0105)), lines)
	_add(PartShapes.box(Vector3(0.02, 0.02, 0.003)), Transform3D(tilt, at + tilt * Vector3(0, 0, 0.011)), ShipKit.glow(Color(1.0, 0.8, 0.3), 1.4))
	var text := Label3D.new()
	text.text = "NAV  DOCKED"
	text.font = ShipKit.mono_font()
	text.font_size = 18
	text.pixel_size = 0.0015
	text.modulate = Color(0.45, 1.0, 0.8)
	text.outline_size = 0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.transform = Transform3D(tilt, at + tilt * Vector3(-width * 0.5 + 0.02, height * 0.5 - 0.025, 0.012))
	body.add_child(text)


## The system map screen on its post by the cockpit, turned to the pilot's seat.
func _map_screen(centre: Vector3, width: float, height: float) -> void:
	var seats: Array = file.get("layout", {}).get("seats", [])
	var eye := VsShipImport.vec3(seats[0].get("at", [0, 1, 0])) + Vector3(0, 0.6, 0) if not seats.is_empty() else Vector3(0, 1.4, -3.0)
	var at := centre + Vector3(0, 0.08, 0)
	var flat_eye := Vector3(eye.x, at.y, eye.z)
	var b := Basis.looking_at(at - flat_eye, Vector3.UP)   # +Z toward the pilot
	_add(PartShapes.box(Vector3(width + 0.06, height + 0.06, 0.03)), Transform3D(b, at), hull_dark)
	_add(PartShapes.box(Vector3(width, height, 0.01)), Transform3D(b, at + b * Vector3(0, 0, 0.017)), ShipKit.glow(Color(0.02, 0.03, 0.08), 1.0))
	var orbit := ShipKit.glow(Color(0.35, 0.45, 0.8), 0.7)
	var flat := b * Basis(Vector3.RIGHT, PI * 0.5)
	for r: float in [0.05, 0.1, 0.15, 0.2]:
		_add(PartShapes.ring(r - 0.002, r, 0.002, 40), Transform3D(flat, at + b * Vector3(0, -0.02, 0.023)), orbit)
	_add(PartShapes.prism(12, 0.018, 0.003), Transform3D(flat, at + b * Vector3(0, -0.02, 0.024)), ShipKit.glow(Color(1.0, 0.85, 0.4), 2.0))
	var text := Label3D.new()
	text.text = "SYSTEM MAP"
	text.font = ShipKit.mono_font()
	text.font_size = 18
	text.pixel_size = 0.0015
	text.modulate = SCREEN_TEXT
	text.outline_size = 0
	text.transform = Transform3D(b, at + b * Vector3(0, height * 0.5 - 0.03, 0.024))
	body.add_child(text)


## The floodlights from `layout.floodlights`: a housing with a lit lens and a spotlight each.
func _floodlights() -> void:
	for f: Dictionary in file.get("layout", {}).get("floodlights", []):
		var at := VsShipImport.vec3(f.get("at", [0, 0, 0]))
		var dir := VsShipImport.vec3(f.get("aim", [0, 0, -1])).normalized()
		var aim := _toward(dir)
		_add(PartShapes.frustum(0.22, 0.3, 0.32, 12), Transform3D(aim, at - dir * 0.16), hull_dark)
		_add(PartShapes.prism(12, 0.26, 0.03), Transform3D(aim, at + dir * 0.005), ShipKit.glow(Color(1.0, 0.97, 0.9), 4.0))
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.96, 0.88)
		spot.light_energy = 4.0
		spot.spot_range = 30.0
		spot.spot_angle = 24.0
		spot.spot_angle_attenuation = 0.9
		spot.shadow_enabled = false
		spot.transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.BACK), at + dir * 0.1)
		body.add_child(spot)
		spots.append(spot)


## The navigation lamps where the file's exterior lights are: a small dark base and a lit
## dome in the light's colour.
func _nav_lamps() -> void:
	for l: Dictionary in file.get("lights", []):
		if str(l.get("group", "")) != "exterior":
			continue
		var at := VsShipImport.vec3(l.get("at", [0, 0, 0]))
		var c := VsShipImport.color(l.get("color", [1, 1, 1]))
		var out := Vector3(signf(at.x), 0, 0) if absf(at.x) > 0.5 else Vector3.UP
		var aim := _toward(out)
		_add(PartShapes.prism(10, 0.07, 0.04), Transform3D(aim, at - out * 0.05), hull_dark)
		_add(PartShapes.dome(0.05, 0.05, 12, 3), Transform3D(aim, at - out * 0.03), ShipKit.glow(c, 3.0))


## The leads' wires along `derived.routes` (every "lead:" route): one tube mesh for all.
func _wires() -> void:
	var routes: Dictionary = file.get("derived", {}).get("routes", {})
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for key: String in routes:
		if not key.begins_with("lead:"):
			continue
		var pts: Array = routes[key]
		for i in pts.size() - 1:
			var a := VsShipImport.vec3(pts[i])
			var b := VsShipImport.vec3(pts[i + 1])
			if a.distance_to(b) < 0.001:
				continue
			_tube(st, a, b)
			any = true
	if not any:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Wires"
	mi.mesh = st.commit()
	mi.material_override = ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.08), 0.1, 0.7))
	body.add_child(mi)


func _tube(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(d)
	for k in WIRE_SIDES:
		var t0 := TAU * float(k) / float(WIRE_SIDES)
		var t1 := TAU * float(k + 1) / float(WIRE_SIDES)
		var o0 := (side * cos(t0) + up * sin(t0)) * WIRE_RADIUS
		var o1 := (side * cos(t1) + up * sin(t1)) * WIRE_RADIUS
		for v: Vector3 in [a + o0, b + o0, b + o1, a + o0, b + o1, a + o1]:
			st.add_vertex(v)


# --- helpers ---------------------------------------------------------------------------------

## A basis whose +Y points along `dir`.
static func _toward(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


func _add(shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.transform = xform
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(mi)
	return mi


func _box(frame: Transform3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	return _add(PartShapes.box(size), frame * Transform3D(Basis(), at), mat)


## Text printed on a surface: `at` in the frame's space, facing along its X.
func _label(text: String, frame: Transform3D, at: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ShipKit.mono_font()
	label.font_size = size
	label.pixel_size = 0.0016
	label.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), at)
	label.modulate = color
	label.outline_size = 0
	body.add_child(label)
	return label


## A screen with a bezel: `at` its middle in frame space (X out of the surface), with text.
func _screen(frame: Transform3D, at: Vector3, size: Vector2, font_size: int, text: String) -> void:
	_box(frame, at + Vector3(0.015, 0.0, 0.0), Vector3(0.03, size.y + 0.05, size.x + 0.05), ShipSurface.of(ShipKit.paint(Color(0.32, 0.34, 0.36), 0.7, 0.35)))
	_box(frame, at + Vector3(0.032, 0.0, 0.0), Vector3(0.004, size.y, size.x), ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0))
	var label := _label(text, frame, at + Vector3(0.036, size.y * 0.5 - 0.015, size.x * 0.5 - 0.02), font_size, SCREEN_TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
