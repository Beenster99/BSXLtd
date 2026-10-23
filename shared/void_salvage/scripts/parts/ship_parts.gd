class_name ShipParts
extends RefCounted
## The company's own fittings: the parts player ships are fitted out with (seats, consoles,
## bunks, lockers, galley, table, racks, lamps, hold nets, name boards...). One livery:
## warm white shells, a teal-blue trim, dark fittings and a thin cyan lit edge on
## everything, so a player ship never looks like the wrecks it strips. Wrecks never use
## these (they have WreckParts); player ships never use WreckParts.
##
## Each function places one fitting into a ShipKit (meshes and collision on the ship's body)
## and returns its bounds in ship space ({name, box: AABB}), so a design can list its
## fittings and the ship test can check they don't run into each other. Functions take a
## `frame` (ship space): unless said otherwise its origin sits on the floor, against the
## wall the fitting stands on, X pointing out of that wall into the room, Y up, and Z
## along the wall. Units are metres.

## The livery (also used by the ship designs for their trim).
const SHELL := Color(0.86, 0.85, 0.82)     # warm white
const TRIM := Color(0.12, 0.34, 0.44)      # teal-blue: the company colour
const DARK := Color(0.15, 0.16, 0.18)      # fittings, frames
const SOFT := Color(0.24, 0.29, 0.36)      # cushions, mattresses
const TOP := Color(0.7, 0.71, 0.7)         # counter and table tops
const EDGE := Color(0.4, 0.86, 1.0)        # the lit edge strip
const SCREEN := Color(0.45, 0.95, 1.0)     # screen text

## Every livery's colours. "company" is the one above (the Kestrel, the Claim); a ship class
## can wear its own, keeping the family's shapes and lit edges. "belly" is a hull's
## underside, "lining" the inner wall panels.
const LIVERIES: Dictionary = {
	"company": {"shell": SHELL, "trim": TRIM, "dark": DARK, "soft": SOFT, "top": TOP, "edge": EDGE, "screen_ink": SCREEN,
			"belly": SHELL, "lining": Color(0.74, 0.74, 0.72)},
	# The Manta: counter-shaded like the ray, deep slate-blue over a pale belly, signal
	# orange trim, rust leather and amber lit edges.
	"manta": {"shell": Color(0.27, 0.35, 0.47), "trim": Color(0.96, 0.5, 0.12), "dark": Color(0.09, 0.1, 0.12),
			"soft": Color(0.34, 0.19, 0.12), "top": Color(0.64, 0.62, 0.58), "edge": Color(1.0, 0.64, 0.24),
			"screen_ink": Color(1.0, 0.76, 0.42), "belly": Color(0.8, 0.81, 0.78), "lining": Color(0.66, 0.66, 0.64)},
}

## The livery fittings are built in. A design sets it at the start of its build and puts
## "company" back at the end (ships build in one go, so nothing else sees it).
static var livery: String = "company"
## Whether the fittings' real pipes are laid (a frame build's PipeRouter, F5b): then they leave
## out the stubs that stood in for their plumbing. A design sets it while it builds and puts
## it back, as `livery`.
static var plumbed: bool = false
static var _mats: Dictionary = {}


## One colour of the current livery ("shell", "trim", "dark", "soft", "top", "edge",
## "screen_ink", "belly", "lining").
static func colour(which: String) -> Color:
	var l: Dictionary = LIVERIES.get(livery, LIVERIES["company"])
	return l.get(which, Color.MAGENTA)


## A shared material of the current livery: "shell", "trim", "dark", "soft", "top", "belly",
## "lining", "steel", "edge" (lit), "screen" (dark glass, faintly lit), "warm" (a warm lamp
## lens), "cold" (a white one).
static func mat(which: String) -> Material:
	var key := livery + ":" + which
	if _mats.has(key):
		return _mats[key]
	var m: Material
	match which:
		"shell":
			m = ShipKit.paint(colour("shell"), 0.25, 0.42)
		"trim":
			m = ShipKit.paint(colour("trim"), 0.35, 0.4)
		"dark":
			m = ShipKit.paint(colour("dark"), 0.55, 0.5)
		"soft":
			m = ShipKit.paint(colour("soft"), 0.0, 0.9)
		"top":
			m = ShipKit.paint(colour("top"), 0.3, 0.3)
		"belly":
			m = ShipKit.paint(colour("belly"), 0.3, 0.45)
		"lining":
			m = ShipKit.paint(colour("lining"), 0.1, 0.65)
		"steel":
			m = ShipKit.paint(Color(0.6, 0.62, 0.64), 0.8, 0.3)
		"edge":
			m = ShipKit.glow(colour("edge"), 1.6)
		"screen":
			m = ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0)
		"warm":
			m = ShipKit.glow(Color(1.0, 0.78, 0.5), 2.2)
		"cold":
			m = ShipKit.glow(Color(0.9, 0.95, 1.0), 3.0)
		_:
			m = ShipKit.paint(Color.MAGENTA)
	_mats[key] = m
	return m


## The ship systems' own paints (the bowsers, panels, doors, lift and screens: S3), the same in
## every livery: [colour, metallic, roughness]. BaseShip's materials of these names are these
## (`base`), so a ship file names them as before.
const BASE: Dictionary = {
	"hull_dark": [Color(0.26, 0.28, 0.3), 0.6, 0.45],
	"hazard": [Color(0.95, 0.55, 0.1), 0.2, 0.55],
	"floor_mat": [Color(0.22, 0.23, 0.24), 0.6, 0.6],
	"white": [Color(0.9, 0.9, 0.88), 0.1, 0.35],
	"steel_lever": [Color(0.7, 0.72, 0.74), 0.8, 0.3],
}


## One of the systems' shared paints (`BASE`).
static func base(which: String) -> Material:
	var key := "base:" + which
	if not _mats.has(key):
		var d: Array = BASE.get(which, [Color.MAGENTA, 0.4, 0.55])
		_mats[key] = ShipKit.paint(d[0], d[1], d[2])
	return _mats[key]


# --- Seating and consoles -------------------------------------------------------------------

## A cockpit seat facing -Z, its base at `at` (ship space). The cushion and back carry `tag`
## (sit with F). A shell on a dark pedestal, trim-coloured headrest, lit edges on the arms.
static func seat(kit: ShipKit, at: Vector3, tag: String) -> Dictionary:
	kit.begin_fitting("seat", null, [at, tag])
	var f := Transform3D(Basis(), at)
	_box(kit, f, Vector3(0, 0.17, 0.02), Vector3(0.22, 0.34, 0.3), mat("dark"), true)
	_box(kit, f, Vector3(0, 0.05, 0.02), Vector3(0.5, 0.1, 0.5), mat("dark"), false)
	_box(kit, f, Vector3(0, 0.4, 0), Vector3(0.62, 0.1, 0.62), mat("shell"), false)
	kit.add(PartShapes.chamfer_box(Vector3(0.56, 0.12, 0.56), 0.04), f * Transform3D(Basis(), Vector3(0, 0.5, -0.02)),
			mat("soft"), tag)
	kit.add(PartShapes.slope(Vector3(0.56, 0.8, 0.12), 0.8), f * Transform3D(Basis(), Vector3(0, 0.95, 0.31)), mat("dark"), tag)
	kit.add(PartShapes.slope(Vector3(0.5, 0.72, 0.06), 0.8), f * Transform3D(Basis(), Vector3(0, 0.95, 0.22)), mat("soft"), "", null, false)
	_box(kit, f, Vector3(0, 0.95, 0.372), Vector3(0.36, 0.5, 0.01), mat("shell"), false)
	_box(kit, f, Vector3(0, 1.22, 0.374), Vector3(0.2, 0.012, 0.01), mat("edge"), false)
	_box(kit, f, Vector3(0, 1.45, 0.31), Vector3(0.34, 0.2, 0.1), mat("trim"), true)
	_box(kit, f, Vector3(0, 1.45, 0.255), Vector3(0.3, 0.16, 0.02), mat("soft"), false)
	for sx: float in [-0.33, 0.33]:
		_box(kit, f, Vector3(sx, 0.66, -0.02), Vector3(0.08, 0.06, 0.48), mat("shell"), true)
		_box(kit, f, Vector3(sx, 0.56, 0.12), Vector3(0.06, 0.16, 0.06), mat("dark"), false)
		_box(kit, f, Vector3(sx + signf(sx) * 0.041, 0.66, -0.02), Vector3(0.004, 0.012, 0.44), mat("edge"), false)
	return kit.end_fitting(_fitting("seat", f, Vector3(-0.38, 0, -0.32), Vector3(0.38, 1.6, 0.42)))


## A sloped console `width` wide: a dark desk with a shell fascia, the operator on its +Z
## side. `frame` origin on the floor at the middle of the desk's front foot.
static func console(kit: ShipKit, frame: Transform3D, width: float, depth: float = 0.55, height: float = 0.78) -> Dictionary:
	kit.begin_fitting("console", frame, [width, depth, height])
	var face := Basis(Vector3.UP, PI)   # the slope's high side away from the operator
	kit.add(PartShapes.slope(Vector3(width, height, depth), 0.62), frame * Transform3D(face, Vector3(0, height * 0.5, -depth * 0.5)),
			mat("dark"))
	# The shell panel stands 0.6 mm proud of the slope's tall face: flush, the two faces
	# flicker on renderers with less depth precision than ours (BSX's yard, Compatibility).
	_box(kit, frame, Vector3(0, height * 0.31, -0.0194), Vector3(width - 0.1, height * 0.6, 0.04), mat("shell"), false)
	_box(kit, frame, Vector3(0, height * 0.62 + 0.005, 0.0), Vector3(width, 0.01, 0.02), mat("edge"), false)
	_box(kit, frame, Vector3(0, 0.04, -0.03), Vector3(width - 0.2, 0.08, 0.02), mat("trim"), false)
	return kit.end_fitting(_fitting("console", frame, Vector3(-width * 0.5, 0, -depth), Vector3(width * 0.5, height, 0.02)))


# --- Crew -----------------------------------------------------------------------------------

## Two fold-down bunks, one over the other, `length` long along the wall: frames hinged to
## the wall on struts, mattresses, pillows at the -Z end, a reading lamp over each and a
## trim-coloured privacy rail along the top.
static func bunks(kit: ShipKit, frame: Transform3D, length: float = 1.95, depth: float = 0.82) -> Dictionary:
	kit.begin_fitting("bunks", frame, [length, depth])
	var top := 2.1
	_box(kit, frame, Vector3(0.015, top * 0.5, 0), Vector3(0.03, top, length + 0.06), mat("shell"), false)
	for level: float in [0.42, 1.42]:
		_box(kit, frame, Vector3(depth * 0.5, level, 0), Vector3(depth, 0.08, length), mat("dark"), true)
		_box(kit, frame, Vector3(depth - 0.02, level + 0.06, 0), Vector3(0.04, 0.05, length), mat("trim"), false)
		kit.add(PartShapes.chamfer_box(Vector3(depth - 0.1, 0.12, length - 0.08), 0.03),
				frame * Transform3D(Basis(), Vector3(depth * 0.5 - 0.02, level + 0.1, 0)), mat("soft"), "", null, false)
		kit.add(PartShapes.chamfer_box(Vector3(depth - 0.3, 0.09, 0.32), 0.03),
				frame * Transform3D(Basis(), Vector3(depth * 0.5 - 0.04, level + 0.2, -length * 0.5 + 0.24)), mat("shell"), "", null, false)
		# The fold-down struts from the wall to the outer corners.
		for z: float in [-length * 0.5 + 0.06, length * 0.5 - 0.06]:
			var a := frame * Vector3(0.03, level + 0.55, z)
			var b := frame * Vector3(depth - 0.05, level + 0.02, z)
			var made := FrameParts.girder_between(a, b, 0.025, 0.025)
			kit.add(made[0], made[1], mat("steel"), "", null, false)
		# The reading lamp: a small warm lens on the wall at the pillow end.
		_box(kit, frame, Vector3(0.04, level + 0.62, -length * 0.5 + 0.3), Vector3(0.05, 0.05, 0.16), mat("warm"), false)
		_box(kit, frame, Vector3(0.035, level - 0.07, 0), Vector3(0.012, 0.01, length - 0.1), mat("edge"), false)
	_box(kit, frame, Vector3(depth - 0.03, top - 0.02, 0), Vector3(0.04, 0.04, length + 0.04), mat("trim"), false)
	return kit.end_fitting(_fitting("bunks", frame, Vector3(0, 0, -length * 0.5 - 0.03), Vector3(depth, top, length * 0.5 + 0.03)))


## A tall locker 0.4 m wide: a shell door with vent slots, a lit edge down its handle side
## and a name plate over the door. Returns {name, box, label}: the plate's text, which the
## ship fills with a crew member's name (the loadout made visible; tools come later). With
## `tag`, its body is a usable piece (the ship's crew locker: F refills the tow limpets).
static func locker(kit: ShipKit, frame: Transform3D, width: float = 0.4, depth: float = 0.42, tag: String = "") -> Dictionary:
	kit.begin_fitting("locker", frame, [width, depth] if tag == "" else [width, depth, tag])
	var h := 2.0
	_box(kit, frame, Vector3(depth * 0.5, h * 0.5, 0), Vector3(depth, h, width), mat("dark"), true, tag)
	_box(kit, frame, Vector3(depth + 0.01, h * 0.47, 0), Vector3(0.02, h * 0.86, width - 0.05), mat("shell"), false)
	for k in 4:
		_box(kit, frame, Vector3(depth + 0.021, 1.55 + float(k) * 0.05, 0), Vector3(0.004, 0.018, width - 0.16), mat("dark"), false)
	_box(kit, frame, Vector3(depth + 0.025, 1.0, width * 0.5 - 0.05), Vector3(0.012, 0.6, 0.012), mat("edge"), false)
	_box(kit, frame, Vector3(depth + 0.012, h - 0.12, 0), Vector3(0.012, 0.1, width - 0.06), mat("trim"), false)
	var label := Label3D.new()
	label.font = ShipKit.mono_font()
	label.font_size = 26
	label.pixel_size = 0.0012
	label.modulate = Color(0.85, 0.95, 1.0)
	label.outline_size = 0
	label.text = "-"
	label.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(depth + 0.02, h - 0.12, 0))
	kit.body.add_child(label)
	var out := _fitting("locker", frame, Vector3(0, 0, -width * 0.5), Vector3(depth + 0.03, h, width * 0.5))
	out["label"] = label
	return kit.end_fitting(out)


## A galley strip `length` long: base cupboards under a counter top with a sink and a hob,
## and (with `cupboards`) wall cupboards over it; a warm light strip over the counter.
static func galley(kit: ShipKit, frame: Transform3D, length: float, depth: float = 0.6, cupboards: bool = true) -> Dictionary:
	kit.begin_fitting("galley", frame, [length, depth, cupboards])
	var top := 0.92
	_box(kit, frame, Vector3(depth * 0.5 - 0.02, top * 0.5 - 0.02, 0), Vector3(depth - 0.04, top - 0.04, length), mat("shell"), true)
	_box(kit, frame, Vector3(depth * 0.5, top - 0.02, 0), Vector3(depth, 0.04, length + 0.02), mat("top"), true)
	_box(kit, frame, Vector3(depth - 0.03, 0.05, 0), Vector3(0.02, 0.1, length - 0.02), mat("dark"), false)
	var doors := maxi(1, int(length / 0.5))
	for i in doors:
		var z := -length * 0.5 + (float(i) + 0.5) * length / float(doors)
		_box(kit, frame, Vector3(depth - 0.015, 0.5, z), Vector3(0.01, 0.62, length / float(doors) - 0.04), mat("shell"), false)
		_box(kit, frame, Vector3(depth - 0.005, 0.74, z), Vector3(0.012, 0.012, 0.18), mat("steel"), false)
	# Sink and hob, set into the top.
	_box(kit, frame, Vector3(depth * 0.5, top + 0.002, -length * 0.25), Vector3(0.36, 0.006, 0.42), mat("steel"), false)
	_box(kit, frame, Vector3(0.08, top + 0.15, -length * 0.25), Vector3(0.03, 0.26, 0.03), mat("steel"), false)
	_box(kit, frame, Vector3(depth * 0.5, top + 0.002, length * 0.25), Vector3(0.4, 0.006, 0.4), mat("dark"), false)
	for k in 2:
		_box(kit, frame, Vector3(depth * 0.5 - 0.09 + float(k) * 0.18, top + 0.006, length * 0.25), Vector3(0.12, 0.004, 0.12),
				ShipKit.glow(Color(1.0, 0.35, 0.1), 0.6), false)
	# Wall cupboards, or just a splashback rail with the light under it.
	var high := 1.55 if cupboards else 1.12
	if cupboards:
		_box(kit, frame, Vector3(0.18, high + 0.3, 0), Vector3(0.36, 0.6, length), mat("shell"), true)
		_box(kit, frame, Vector3(0.36, high + 0.3, 0), Vector3(0.012, 0.56, length - 0.04), mat("trim"), false)
	else:
		_box(kit, frame, Vector3(0.05, high + 0.01, 0), Vector3(0.1, 0.03, length), mat("trim"), false)
	_box(kit, frame, Vector3(0.3 if cupboards else 0.08, high - 0.01, 0), Vector3(0.05, 0.012, length - 0.1), mat("warm"), false)
	_box(kit, frame, Vector3(depth + 0.001, top - 0.02, 0), Vector3(0.004, 0.012, length), mat("edge"), false)
	return kit.end_fitting(_fitting("galley", frame, Vector3(0, 0, -length * 0.5 - 0.01), Vector3(depth, high + (0.6 if cupboards else 0.05), length * 0.5 + 0.01)))


## A table against the wall, `size` (x out from the wall, z along it), on one pedestal, with a
## screen inlaid in its top (the contract board). Returns {name, box, label}: the screen's
## text, lying flat and read from the room side.
static func table(kit: ShipKit, frame: Transform3D, size: Vector2) -> Dictionary:
	kit.begin_fitting("table", frame, [size])
	var top := 0.74
	_box(kit, frame, Vector3(size.x * 0.5, top - 0.03, 0), Vector3(size.x, 0.05, size.y), mat("top"), true)
	_box(kit, frame, Vector3(size.x * 0.5, top - 0.065, 0), Vector3(size.x - 0.04, 0.02, size.y - 0.04), mat("trim"), false)
	_box(kit, frame, Vector3(size.x * 0.55, top * 0.5 - 0.03, 0), Vector3(0.1, top - 0.06, 0.1), mat("dark"), true)
	_box(kit, frame, Vector3(size.x * 0.55, 0.02, 0), Vector3(0.5, 0.04, 0.5), mat("dark"), false)
	_box(kit, frame, Vector3(0.04, top - 0.08, 0), Vector3(0.08, 0.06, size.y * 0.6), mat("dark"), false)   # wall bracket
	var screen := Vector2(size.x - 0.24, size.y - 0.3)
	_box(kit, frame, Vector3(size.x * 0.5, top - 0.004, 0), Vector3(screen.x + 0.04, 0.004, screen.y + 0.04), mat("dark"), false)
	_box(kit, frame, Vector3(size.x * 0.5, top - 0.001, 0), Vector3(screen.x, 0.004, screen.y), mat("screen"), false)
	_box(kit, frame, Vector3(size.x + 0.001, top - 0.03, 0), Vector3(0.004, 0.012, size.y), mat("edge"), false)
	var label := Label3D.new()
	label.font = ShipKit.mono_font()
	label.font_size = 30
	label.pixel_size = 0.0011
	label.line_spacing = -3.0
	label.modulate = colour("screen_ink")
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = screen.y / label.pixel_size
	# Flat on the table, read standing in the room: the text's top toward the wall (-X), its
	# lines running along -Z, facing up.
	var flat := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	label.transform = frame * Transform3D(flat, Vector3(0.12 + 0.02, top + 0.002, screen.y * 0.5 - 0.02))
	kit.body.add_child(label)
	var out := _fitting("table", frame, Vector3(0, 0, -size.y * 0.5), Vector3(size.x, top, size.y * 0.5))
	out["label"] = label
	return kit.end_fitting(out)


## A bench seat along the wall, `length` long, a cushion on a dark box. With `tags`, the
## cushion is that many seat cushions side by side (from -Z to +Z), each carrying its tag
## (sit with F).
static func bench(kit: ShipKit, frame: Transform3D, length: float, depth: float = 0.45,
		tags: PackedStringArray = PackedStringArray()) -> Dictionary:
	kit.begin_fitting("bench", frame, [length, depth, tags])
	_box(kit, frame, Vector3(depth * 0.5, 0.2, 0), Vector3(depth, 0.4, length), mat("dark"), true)
	if tags.is_empty():
		kit.add(PartShapes.chamfer_box(Vector3(depth - 0.02, 0.1, length - 0.02), 0.03),
				frame * Transform3D(Basis(), Vector3(depth * 0.5, 0.45, 0)), mat("soft"), "", null, false)
	var place := length / float(maxi(tags.size(), 1))
	for i in tags.size():
		kit.add(PartShapes.chamfer_box(Vector3(depth - 0.02, 0.1, place - 0.03), 0.03),
				frame * Transform3D(Basis(), Vector3(depth * 0.5, 0.45, -length * 0.5 + place * (float(i) + 0.5))), mat("soft"), tags[i])
	kit.add(PartShapes.chamfer_box(Vector3(0.1, 0.45, length - 0.04), 0.03),
			frame * Transform3D(Basis(), Vector3(0.06, 0.78, 0)), mat("soft"), "", null, false)
	_box(kit, frame, Vector3(depth + 0.001, 0.36, 0), Vector3(0.004, 0.012, length), mat("edge"), false)
	return kit.end_fitting(_fitting("bench", frame, Vector3(0, 0, -length * 0.5), Vector3(depth, 1.0, length * 0.5)))


## The suit stand by the airlock: a dark back plate with a suit cradle, helmet shelf, a tool
## hook rail and the charge lamp.
static func suit_stand(kit: ShipKit, frame: Transform3D, width: float = 0.6) -> Dictionary:
	kit.begin_fitting("suit_stand", frame, [width])
	_box(kit, frame, Vector3(0.02, 1.05, 0), Vector3(0.04, 2.0, width), mat("dark"), true)
	_box(kit, frame, Vector3(0.1, 0.06, 0), Vector3(0.2, 0.12, width), mat("dark"), true)
	_box(kit, frame, Vector3(0.12, 1.25, 0), Vector3(0.2, 0.7, 0.26), mat("shell"), false)     # the cradle
	_box(kit, frame, Vector3(0.18, 1.78, 0), Vector3(0.3, 0.03, width - 0.06), mat("shell"), true)   # helmet shelf
	kit.add(PartShapes.dome(0.14, 0.16, 12, 3), frame * Transform3D(Basis(), Vector3(0.18, 1.795, 0)), mat("trim"), "", null, false)
	_box(kit, frame, Vector3(0.07, 0.85, 0), Vector3(0.06, 0.03, width - 0.08), mat("steel"), false)
	_box(kit, frame, Vector3(0.045, 1.6, width * 0.5 - 0.06), Vector3(0.012, 0.05, 0.05), ShipKit.glow(Color(0.3, 1.0, 0.45), 1.5), false)
	_box(kit, frame, Vector3(0.045, 0.2, 0), Vector3(0.012, 0.012, width - 0.04), mat("edge"), false)
	return kit.end_fitting(_fitting("suit stand", frame, Vector3(0, 0, -width * 0.5), Vector3(0.33, 2.05, width * 0.5)))


## A small shelf on a wall at height `y` for one kept trophy part, lit from under its lip.
static func trophy_shelf(kit: ShipKit, frame: Transform3D, y: float, width: float = 0.7) -> Dictionary:
	kit.begin_fitting("trophy_shelf", frame, [y, width])
	_box(kit, frame, Vector3(0.14, y, 0), Vector3(0.28, 0.04, width), mat("top"), true)
	_box(kit, frame, Vector3(0.27, y - 0.025, 0), Vector3(0.02, 0.01, width - 0.04), mat("edge"), false)
	for z: float in [-width * 0.4, width * 0.4]:
		_box(kit, frame, Vector3(0.06, y - 0.08, z), Vector3(0.12, 0.12, 0.02), mat("dark"), false)
	_box(kit, frame, Vector3(0.02, y + 0.26, 0), Vector3(0.012, 0.36, width), mat("trim"), false)
	return kit.end_fitting(_fitting("trophy shelf", frame, Vector3(0, y - 0.15, -width * 0.5), Vector3(0.29, y + 0.45, width * 0.5)))


# --- Ship systems ---------------------------------------------------------------------------

## The breaker and power panel: a cabinet on the wall (centre at height `y`) with a row of
## breaker toggles and a lit status strip. Decor for now: the ship itself has no grid.
static func breaker_panel(kit: ShipKit, frame: Transform3D, y: float = 1.45) -> Dictionary:
	kit.begin_fitting("breaker_panel", frame, [y])
	_box(kit, frame, Vector3(0.04, y, 0), Vector3(0.08, 0.7, 0.5), mat("dark"), true)
	_box(kit, frame, Vector3(0.081, y + 0.31, 0), Vector3(0.004, 0.04, 0.5), mat("trim"), false)
	for i in 6:
		var z := -0.19 + float(i) * 0.076
		_box(kit, frame, Vector3(0.085, y + 0.05, z), Vector3(0.012, 0.16, 0.05), mat("shell"), false)
		_box(kit, frame, Vector3(0.1, y + 0.09, z), Vector3(0.02, 0.05, 0.025), mat("steel"), false)
		_box(kit, frame, Vector3(0.083, y - 0.1, z), Vector3(0.006, 0.02, 0.03),
				ShipKit.glow(Color(0.3, 1.0, 0.45) if i != 5 else Color(1.0, 0.6, 0.2), 1.6), false)
	_box(kit, frame, Vector3(0.083, y - 0.24, 0), Vector3(0.006, 0.1, 0.4), mat("screen"), false)
	return kit.end_fitting(_fitting("breaker panel", frame, Vector3(0, y - 0.36, -0.26), Vector3(0.12, y + 0.36, 0.26)))


## The reactor cabinet in a back wall: a tall dark box with a slot window on its glowing core,
## pipe stubs into the wall and a hazard band. `width` along the wall.
static func reactor_cabinet(kit: ShipKit, frame: Transform3D, width: float, depth: float = 0.4, height: float = 2.2) -> Dictionary:
	kit.begin_fitting("reactor_cabinet", frame, [width, depth, height])
	_box(kit, frame, Vector3(depth * 0.5, height * 0.5, 0), Vector3(depth, height, width), mat("dark"), true)
	_box(kit, frame, Vector3(depth + 0.01, height * 0.55, 0), Vector3(0.02, height * 0.7, width - 0.12), mat("shell"), false)
	_box(kit, frame, Vector3(depth + 0.022, height * 0.55, 0), Vector3(0.006, 0.9, 0.12), mat("dark"), false)
	_box(kit, frame, Vector3(depth + 0.026, height * 0.55, 0), Vector3(0.004, 0.84, 0.06), ShipKit.glow(Color(0.3, 0.8, 1.0), 3.0), false)
	_box(kit, frame, Vector3(depth + 0.012, 0.18, 0), Vector3(0.024, 0.1, width), ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55), false)
	_box(kit, frame, Vector3(depth + 0.021, height - 0.16, 0), Vector3(0.004, 0.012, width - 0.04), mat("edge"), false)
	# Stand-in pipe stubs, unless its coolant loop is laid for real.
	if not plumbed:
		for k in 3:
			var y := height * 0.25 + float(k) * 0.12
			_box(kit, frame, Vector3(depth + 0.03, y, -width * 0.5 + 0.08), Vector3(0.06, 0.05, 0.05), mat("steel"), false)
	return kit.end_fitting(_fitting("reactor cabinet", frame, Vector3(0, 0, -width * 0.5), Vector3(depth + 0.04, height, width * 0.5)))


## A wall rack for components, `length` along the wall and `height` tall: uprights, two
## padded rails and sliding clamp jaws, a trim strip along the top.
static func wall_rack(kit: ShipKit, frame: Transform3D, length: float, height: float = 1.5, depth: float = 0.32) -> Dictionary:
	kit.begin_fitting("wall_rack", frame, [length, height, depth])
	var posts := maxi(2, int(length / 0.7) + 1)
	for i in posts:
		var z := lerpf(-length * 0.5 + 0.04, length * 0.5 - 0.04, float(i) / float(posts - 1))
		_box(kit, frame, Vector3(depth * 0.5, height * 0.5, z), Vector3(depth, height, 0.06), mat("dark"), true)
	for y: float in [height * 0.32, height * 0.8]:
		_box(kit, frame, Vector3(depth - 0.04, y, 0), Vector3(0.06, 0.08, length), mat("steel"), true)
		_box(kit, frame, Vector3(depth - 0.005, y, 0), Vector3(0.012, 0.05, length - 0.02), mat("soft"), false)
		for i in posts - 1:
			var z := lerpf(-length * 0.5, length * 0.5, (float(i) + 0.5) / float(posts - 1))
			_box(kit, frame, Vector3(depth + 0.03, y + 0.07, z), Vector3(0.06, 0.06, 0.1), mat("trim"), false)
	_box(kit, frame, Vector3(0.03, height - 0.02, 0), Vector3(0.06, 0.04, length), mat("trim"), false)
	_box(kit, frame, Vector3(depth + 0.001, height * 0.32 - 0.05, 0), Vector3(0.004, 0.012, length - 0.04), mat("edge"), false)
	return kit.end_fitting(_fitting("wall rack", frame, Vector3(0, 0, -length * 0.5), Vector3(depth + 0.06, height, length * 0.5)))


## A catch net slung under a ceiling at height `y`, over the rectangle `rect` (x, z, ship
## space): a frame of straps and a diamond mesh between them. Looks only.
static func hold_net(kit: ShipKit, y: float, rect: Rect2) -> Dictionary:
	kit.begin_fitting("hold_net", null, [y, rect])
	var strap := ShipKit.paint(Color(0.85, 0.55, 0.15), 0.0, 0.85)
	var cell := 0.45
	var x0 := rect.position.x
	var z0 := rect.position.y
	var nx := maxi(1, int(rect.size.x / cell))
	var nz := maxi(1, int(rect.size.y / cell))
	for i in nx + 1:
		var x := x0 + rect.size.x * float(i) / float(nx)
		_box(kit, Transform3D(), Vector3(x, y, rect.get_center().y), Vector3(0.025, 0.012, rect.size.y), strap, false)
	for j in nz + 1:
		var z := z0 + rect.size.y * float(j) / float(nz)
		_box(kit, Transform3D(), Vector3(rect.get_center().x, y - 0.006, z), Vector3(rect.size.x, 0.012, 0.025), strap, false)
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		_box(kit, Transform3D(), Vector3(corner.x, y + 0.1, corner.y), Vector3(0.06, 0.2, 0.06), mat("dark"), false)
	return kit.end_fitting({"name": "hold net", "box": AABB(Vector3(x0, y - 0.02, z0), Vector3(rect.size.x, 0.24, rect.size.y))})


## A ceiling lamp at `at` (the lens's middle, ship space) `length` long along `along` (X or
## Z): a housing, a lens of `lens` ("warm" or "cold"), lit edges, and its light.
static func lamp(kit: ShipKit, at: Vector3, length: float, along: Vector3, lens: String, energy: float, reach: float,
		shadows: bool = false) -> OmniLight3D:
	kit.begin_fitting("lamp", null, [at, length, along, lens, energy, reach, shadows])
	var b := Basis() if absf(along.x) > 0.5 else Basis(Vector3.UP, PI * 0.5)
	var f := Transform3D(b, at)
	_box(kit, f, Vector3(0, 0.04, 0), Vector3(length + 0.08, 0.06, 0.22), mat("dark"), false)
	_box(kit, f, Vector3(0, 0.0, 0), Vector3(length, 0.025, 0.12), mat(lens), false)
	for side: float in [-1.0, 1.0]:
		_box(kit, f, Vector3(0, 0.012, side * 0.105), Vector3(length + 0.06, 0.008, 0.008), mat("edge"), false)
	var light := kit.light(at + Vector3(0, -0.25, 0), Color(1.0, 0.84, 0.66) if lens == "warm" else Color(0.92, 0.96, 1.0),
			energy, reach, shadows)
	kit.end_fitting(_fitting("lamp", f, Vector3(-length * 0.5 - 0.04, -0.02, -0.11), Vector3(length * 0.5 + 0.04, 0.07, 0.11)))
	return light


## A name board: a dark plate with the name in lit letters and a trim band under it.
## `frame` sits on the surface at the board's middle, X out of it, Y up.
static func name_board(kit: ShipKit, frame: Transform3D, text: String, width: float, height: float = 0.32) -> Dictionary:
	kit.begin_fitting("name_board", frame, [text, width, height])
	_box(kit, frame, Vector3(0.015, 0, 0), Vector3(0.03, height, width), mat("dark"), false)
	_box(kit, frame, Vector3(0.02, -height * 0.5 - 0.03, 0), Vector3(0.02, 0.04, width), mat("trim"), false)
	var label := Label3D.new()
	label.font = ShipKit.mono_font()
	label.font_size = 64
	label.pixel_size = height * 0.7 / 64.0
	label.modulate = colour("edge") * 1.4
	label.outline_size = 0
	label.text = text
	label.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.032, 0, 0))
	kit.body.add_child(label)
	return kit.end_fitting(_fitting("name board", frame, Vector3(0, -height * 0.5 - 0.05, -width * 0.5), Vector3(0.04, height * 0.5, width * 0.5)))


## A lounge armchair, free-standing: its origin on the floor at the chair's middle, the
## sitter facing the frame's -Z. A plinth, a deep cushion and a leaning back (both carry
## `tag`: sit with F), broad arms with lit edges and a trim band round the base.
static func armchair(kit: ShipKit, frame: Transform3D, tag: String) -> Dictionary:
	kit.begin_fitting("armchair", frame, [tag])
	_box(kit, frame, Vector3(0, 0.1, 0.02), Vector3(0.7, 0.2, 0.66), mat("dark"), true)
	_box(kit, frame, Vector3(0, 0.05, 0.02), Vector3(0.72, 0.03, 0.68), mat("trim"), false)
	kit.add(PartShapes.chamfer_box(Vector3(0.6, 0.24, 0.6), 0.06), frame * Transform3D(Basis(), Vector3(0, 0.34, -0.02)),
			mat("soft"), tag)
	kit.add(PartShapes.slope(Vector3(0.66, 0.78, 0.2), 0.75), frame * Transform3D(Basis(), Vector3(0, 0.72, 0.3)),
			mat("soft"), tag)
	_box(kit, frame, Vector3(0, 0.7, 0.385), Vector3(0.68, 0.6, 0.04), mat("shell"), false)
	for sx: float in [-0.33, 0.33]:
		kit.add(PartShapes.chamfer_box(Vector3(0.13, 0.42, 0.64), 0.04), frame * Transform3D(Basis(), Vector3(sx + signf(sx) * 0.02, 0.4, 0.02)),
				mat("shell"), "", null, true)
		_box(kit, frame, Vector3(sx + signf(sx) * 0.02, 0.615, 0.02), Vector3(0.1, 0.012, 0.58), mat("edge"), false)
	return kit.end_fitting(_fitting("armchair", frame, Vector3(-0.44, 0, -0.32), Vector3(0.44, 1.1, 0.42)))


## A fold-down jump seat on a wall, the sitter facing out of it (+X): a back plate with a
## harness, the seat pan on two arms (both carry `tag`: sit with F), a grab handle and a
## lit edge.
static func jump_seat(kit: ShipKit, frame: Transform3D, tag: String) -> Dictionary:
	kit.begin_fitting("jump_seat", frame, [tag])
	_box(kit, frame, Vector3(0.025, 1.0, 0), Vector3(0.05, 1.3, 0.56), mat("dark"), true)
	kit.add(PartShapes.chamfer_box(Vector3(0.08, 0.7, 0.44), 0.025), frame * Transform3D(Basis(), Vector3(0.09, 1.0, 0)), mat("soft"), tag)
	kit.add(PartShapes.chamfer_box(Vector3(0.44, 0.08, 0.48), 0.025), frame * Transform3D(Basis(), Vector3(0.3, 0.46, 0)), mat("soft"), tag)
	_box(kit, frame, Vector3(0.3, 0.4, 0), Vector3(0.42, 0.04, 0.5), mat("shell"), false)
	for z: float in [-0.24, 0.24]:
		var made := FrameParts.girder_between(frame * Vector3(0.05, 0.18, z), frame * Vector3(0.48, 0.4, z), 0.035, 0.035)
		kit.add(made[0], made[1], mat("steel"), "", null, false)
		_box(kit, frame, Vector3(0.135, 1.05, z * 0.55), Vector3(0.012, 0.62, 0.05), mat("trim"), false)   # the harness
	_box(kit, frame, Vector3(0.135, 0.98, 0), Vector3(0.016, 0.1, 0.1), mat("steel"), false)              # its buckle
	_box(kit, frame, Vector3(0.07, 1.72, 0), Vector3(0.05, 0.04, 0.36), mat("steel"), false)              # grab handle
	_box(kit, frame, Vector3(0.052, 0.33, 0), Vector3(0.004, 0.012, 0.5), mat("edge"), false)
	return kit.end_fitting(_fitting("jump seat", frame, Vector3(0, 0, -0.29), Vector3(0.53, 1.75, 0.29)))


## A railing from `a` to `b` (its feet, ship space; the two may differ in height for a stair),
## `height` tall: posts about every metre, a top rail with a lit strip under it, a mid rail.
## Posts collide (you can lean on it); returns {name, box}.
static func railing(kit: ShipKit, a: Vector3, b: Vector3, height: float = 1.0) -> Dictionary:
	kit.begin_fitting("railing", null, [a, b, height])
	var n := maxi(1, ceili(a.distance_to(b) / 1.1))
	for i in n + 1:
		var foot := a.lerp(b, float(i) / float(n))
		_box(kit, Transform3D(), foot + Vector3(0, height * 0.5, 0), Vector3(0.05, height, 0.05), mat("dark"), true)
	for rail: Array in [[height, 0.05, "shell"], [height * 0.5, 0.03, "steel"]]:
		var made := FrameParts.girder_between(a + Vector3(0, rail[0], 0), b + Vector3(0, rail[0], 0), rail[1], rail[1])
		kit.add(made[0], made[1], mat(rail[2]), "", null, rail[0] == height)
	var lit := FrameParts.girder_between(a + Vector3(0, height - 0.035, 0), b + Vector3(0, height - 0.035, 0), 0.012, 0.012)
	kit.add(lit[0], lit[1], mat("edge"), "", null, false)
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z)) - Vector3(0.03, 0, 0.03)
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y) + height, maxf(a.z, b.z)) + Vector3(0.03, 0.03, 0.03)
	return kit.end_fitting({"name": "railing", "box": AABB(lo, hi - lo)})


## A flight of stairs `width` wide climbing `rise` over `run` toward the frame's -Z: its
## origin on the lower floor at the middle of the bottom step's front. Steps with lit
## nosings between two stringers, and one smooth ramp under them to walk on (collision
## only, so feet never catch on a step edge).
static func stair_flight(kit: ShipKit, frame: Transform3D, width: float, rise: float, run: float) -> Dictionary:
	kit.begin_fitting("stair_flight", frame, [width, rise, run])
	var n := maxi(2, roundi(rise / 0.22))
	var tread := run / float(n)
	for i in n:
		var top := rise * float(i + 1) / float(n)
		var z := -tread * (float(i) + 0.5)
		_box(kit, frame, Vector3(0, top - 0.04, z), Vector3(width - 0.1, 0.08, tread + 0.01), mat("dark"), false)
		_box(kit, frame, Vector3(0, top - 0.11, z + tread * 0.5 - 0.02), Vector3(width - 0.12, 0.14, 0.03), mat("shell"), false)
		_box(kit, frame, Vector3(0, top + 0.001, z + tread * 0.5 - 0.03), Vector3(width - 0.16, 0.006, 0.03), mat("edge"), false)
	for sx: float in [-width * 0.5 + 0.03, width * 0.5 - 0.03]:
		var made := FrameParts.girder_between(frame * Vector3(sx, 0.1, 0.0), frame * Vector3(sx, rise - 0.1, -run), 0.06, 0.3,
				frame.basis * Vector3.UP)
		kit.add(made[0], made[1], mat("trim"), "", null, false)
	kit.collider(PartShapes.wedge(Vector3(width, rise, run)), frame * Transform3D(Basis(), Vector3(0, rise * 0.5, -run * 0.5)))
	return kit.end_fitting(_fitting("stairs", frame, Vector3(-width * 0.5, 0, -run), Vector3(width * 0.5, rise, 0)))


## A workbench `length` along the wall: cabinets under a steel-edged top at 0.95 m, a vice
## at one end, a pegboard of tools over it lit by a strip, a parts bin.
static func workbench(kit: ShipKit, frame: Transform3D, length: float, depth: float = 0.7) -> Dictionary:
	kit.begin_fitting("workbench", frame, [length, depth])
	var top := 0.95
	_box(kit, frame, Vector3(depth * 0.5, top * 0.5 - 0.03, 0), Vector3(depth - 0.02, top - 0.06, length - 0.04), mat("dark"), true)
	_box(kit, frame, Vector3(depth * 0.5, top - 0.03, 0), Vector3(depth, 0.06, length), mat("top"), true)
	_box(kit, frame, Vector3(depth - 0.005, top - 0.03, 0), Vector3(0.012, 0.064, length + 0.004), mat("steel"), false)
	var drawers := maxi(1, int(length / 0.6))
	for i in drawers:
		var z := -length * 0.5 + (float(i) + 0.5) * length / float(drawers)
		for k in 3:
			_box(kit, frame, Vector3(depth - 0.005, 0.2 + float(k) * 0.24, z), Vector3(0.01, 0.2, length / float(drawers) - 0.05), mat("shell"), false)
			_box(kit, frame, Vector3(depth + 0.004, 0.26 + float(k) * 0.24, z), Vector3(0.012, 0.014, 0.16), mat("trim"), false)
	# The vice, at the +Z end.
	var vz := length * 0.5 - 0.25
	_box(kit, frame, Vector3(depth - 0.12, top + 0.06, vz), Vector3(0.14, 0.12, 0.2), mat("steel"), false)
	_box(kit, frame, Vector3(depth + 0.03, top + 0.06, vz), Vector3(0.06, 0.12, 0.18), mat("trim"), false)
	# The pegboard with tool shapes, a light strip under its foot, a parts bin.
	_box(kit, frame, Vector3(0.02, top + 0.7, 0), Vector3(0.03, 0.9, length - 0.1), mat("shell"), false)
	for i in int(length / 0.3):
		var z := -length * 0.5 + 0.25 + float(i) * 0.3
		var h := 0.18 + float(i % 3) * 0.08
		_box(kit, frame, Vector3(0.045, top + 0.75, z), Vector3(0.02, h, 0.05 + float(i % 2) * 0.05), mat("dark"), false)
	_box(kit, frame, Vector3(0.06, top + 0.24, 0), Vector3(0.05, 0.012, length - 0.2), mat("warm"), false)
	_box(kit, frame, Vector3(0.2, top + 0.08, -length * 0.5 + 0.3), Vector3(0.3, 0.16, 0.36), mat("trim"), false)
	return kit.end_fitting(_fitting("workbench", frame, Vector3(0, 0, -length * 0.5), Vector3(depth + 0.07, top + 1.16, length * 0.5)))


## The reactor core standing in an engine room: a glowing column in a cage of four posts on
## a dark plinth, a cap with pipes up to the ceiling, banded rings and a hazard ring on the
## floor. `frame` origin on the floor at the core's centre; `height` floor to ceiling.
static func reactor_core(kit: ShipKit, frame: Transform3D, radius: float, height: float) -> Dictionary:
	kit.begin_fitting("reactor_core", frame, [radius, height])
	var core := ShipKit.glow(Color(0.3, 0.8, 1.0), 2.6)
	var hazard := ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55)
	kit.add(PartShapes.prism(16, radius + 0.25, 0.3), frame * Transform3D(Basis(), Vector3(0, 0.15, 0)), mat("dark"))
	kit.add(PartShapes.ring(radius + 0.3, radius + 0.42, 0.02, 24), frame * Transform3D(Basis(), Vector3(0, 0.01, 0)), hazard, "", null, false)
	kit.add(PartShapes.prism(16, radius * 0.62, height - 0.9), frame * Transform3D(Basis(), Vector3(0, 0.3 + (height - 0.9) * 0.5, 0)), core)
	for k in 4:
		var y := 0.65 + float(k) * (height - 1.5) / 3.0
		kit.add(PartShapes.ring(radius * 0.62, radius, 0.1, 24), frame * Transform3D(Basis(), Vector3(0, y, 0)), mat("steel"), "", null, false)
	kit.add(PartShapes.prism(16, radius + 0.15, 0.4), frame * Transform3D(Basis(), Vector3(0, height - 0.6 + 0.2, 0)), mat("dark"))
	kit.add(PartShapes.prism(16, radius + 0.16, 0.06), frame * Transform3D(Basis(), Vector3(0, height - 0.45, 0)), mat("trim"), "", null, false)
	for c: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var at := Vector3(c.x, 0, c.y) * (radius * 0.78)
		_box(kit, frame, at + Vector3(0, height * 0.5, 0), Vector3(0.1, height - 0.2, 0.1), mat("shell"), true)
		_box(kit, frame, at + Vector3(0, height * 0.5, 0) + Vector3(c.x, 0, c.y).normalized() * 0.052, Vector3(0.012, height - 0.4, 0.012),
				mat("edge"), false)
	# Stand-in pipes up to the ceiling, unless its coolant loop is laid for real (from its plinth).
	if not plumbed:
		for x: float in [-radius * 0.35, radius * 0.35]:
			kit.add(PartShapes.prism(10, 0.09, 0.22), frame * Transform3D(Basis(), Vector3(x, height - 0.11, 0)), mat("steel"), "", null, false)
	else:
		for port: Dictionary in ports("reactor_core", [radius, height]):
			if port["fluid"] != "":
				_boss(kit, frame, port)
	kit.light(frame * Vector3(0, height * 0.5, radius + 0.6), Color(0.4, 0.8, 1.0), 1.2, 6.0)
	var r := radius + 0.42
	return kit.end_fitting(_fitting("reactor core", frame, Vector3(-r, 0, -r), Vector3(r, height, r)))


# --- Services (docs/SHIP_FRAME_PLAN.md 4.5) -------------------------------------------------

## A junction box in a cavity: a dark steel box with a bolted lid and a trim band, where a
## loom ends and leads plug in. `frame` sits on the surface it is fixed to at the box's
## middle, Y out of that surface, Z along the loom; `size` (x across, y out, z along).
static func junction_box(kit: ShipKit, frame: Transform3D, size: Vector3) -> Dictionary:
	kit.begin_fitting("junction_box", frame, [size])
	_box(kit, frame, Vector3(0, size.y * 0.5, 0), size, mat("dark"), true)
	_box(kit, frame, Vector3(0, size.y + 0.004, 0), Vector3(size.x - 0.03, 0.008, size.z - 0.03), mat("steel"), false)
	_box(kit, frame, Vector3(0, size.y * 0.5, 0), Vector3(size.x + 0.004, 0.02, size.z + 0.004), mat("trim"), false)
	return kit.end_fitting(_fitting("junction box", frame, Vector3(-size.x * 0.5, 0, -size.z * 0.5),
			Vector3(size.x * 0.5, size.y + 0.008, size.z * 0.5)))


## A lamp's driver: a small box above the lamp it feeds (on the panel the lamp hangs under),
## with a green power LED. `frame` on that surface at its middle, Y out of it.
static func lamp_driver(kit: ShipKit, frame: Transform3D) -> Dictionary:
	kit.begin_fitting("lamp_driver", frame, [])
	_box(kit, frame, Vector3(0, 0.025, 0), Vector3(0.16, 0.05, 0.1), mat("steel"), true)
	_box(kit, frame, Vector3(0.06, 0.052, 0.03), Vector3(0.012, 0.004, 0.012), ShipKit.glow(Color(0.3, 1.0, 0.45), 1.5), false)
	return kit.end_fitting(_fitting("lamp driver", frame, Vector3(-0.08, 0, -0.05), Vector3(0.08, 0.056, 0.05)))


## The ship's jump tank (F5b): a long rounded steel tank hung under a deck between its
## girders, banded, with a fill spigot at one end and a cross-feed on its inboard side.
## `frame` sits at the middle of its top face, Y up (it hangs below), Z along it; `size`
## (across, deep, long); `inboard` +1 or -1, the side (frame X) its cross-feed faces.
static func jump_tank(kit: ShipKit, frame: Transform3D, size: Vector3, inboard: float) -> Dictionary:
	kit.begin_fitting("jump_tank", frame, [size, inboard])
	var tank := ShipKit.paint(Color(0.42, 0.44, 0.46), 0.75, 0.35)
	kit.add(PartShapes.chamfer_box(size, minf(0.06, size.y * 0.25)), frame * Transform3D(Basis(), Vector3(0, -size.y * 0.5, 0)), tank)
	for z: float in [-size.z * 0.3, size.z * 0.3]:
		_box(kit, frame, Vector3(0, -size.y * 0.5, z), Vector3(size.x + 0.01, size.y + 0.01, 0.05), mat("dark"), false)
	_box(kit, frame, Vector3(0, -size.y - 0.004, 0), Vector3(size.x * 0.5, 0.006, size.z * 0.5),
			ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55), false)
	for port: Dictionary in ports("jump_tank", [size, inboard]):
		_boss(kit, frame, port)
	return kit.end_fitting(_fitting("jump tank", frame, Vector3(-size.x * 0.5, -size.y, -size.z * 0.5), Vector3(size.x * 0.5, 0, size.z * 0.5)))


## The reactor's heat exchanger (F5b): a flat finned box on the belly skin, the hull its cold
## side, with the coolant loop's two spigots on its aft face. `frame` on the skin at its
## middle, Y up, Z along the ship; `size` (across, tall, long).
static func heat_exchanger(kit: ShipKit, frame: Transform3D, size: Vector3) -> Dictionary:
	kit.begin_fitting("heat_exchanger", frame, [size])
	_box(kit, frame, Vector3(0, size.y * 0.3, 0), Vector3(size.x, size.y * 0.6, size.z), mat("dark"), true)
	var fins := maxi(3, int(size.x / 0.05))
	for k in fins:
		var x := lerpf(-size.x * 0.5 + 0.02, size.x * 0.5 - 0.02, float(k) / float(fins - 1))
		_box(kit, frame, Vector3(x, size.y * 0.8, 0), Vector3(0.006, size.y * 0.4, size.z - 0.04), mat("steel"), false)
	_box(kit, frame, Vector3(0, size.y * 0.61, size.z * 0.5 - 0.02), Vector3(size.x, 0.012, 0.03),
			ShipKit.paint(Color(0.22, 0.52, 0.66), 0.35, 0.5), false)
	for port: Dictionary in ports("heat_exchanger", [size]):
		_boss(kit, frame, port)
	return kit.end_fitting(_fitting("heat exchanger", frame, Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(size.x * 0.5, size.y, size.z * 0.5)))


## A spigot's boss on a fitting: a short collar where its pipe bolts on (looks only).
static func _boss(kit: ShipKit, frame: Transform3D, port: Dictionary) -> void:
	var r: float = port["radius"]
	var dir: Vector3 = port["direction"]
	var y := dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.9 else Vector3.RIGHT).normalized()
	var at: Vector3 = (port["position"] as Vector3) - y * 0.01
	kit.add(PartShapes.prism(10, r * 1.45, 0.02), frame * Transform3D(Basis(x, y, x.cross(y)), at), mat("steel"), "", null, false)


## Where a fitting or ship system meets the services (docs/SHIP_FRAME_PLAN.md 4.5; the ship
## file writes them for BSX, which matches a module's ports by them): each {name, fluid ("" for
## power), radius (m), position, direction (unit: the way the lead or pipe leaves)} in the frame
## its builder took, for `kind` (the fitting's or system's name) built with `args`. Power (F5)
## and the pipes' spigots (F5b: the fuel port's feed, the manifold's inlet and jump-tank feed,
## the jump tanks', the reactor's coolant loop and its heat exchanger's). [] for anything with
## no services.
static func ports(kind: String, args: Array) -> Array[Dictionary]:
	var lead := 0.008
	match kind:
		"console":
			return [_port("power", "", lead, Vector3(0, 0, -float(args[1]) * 0.5), Vector3.DOWN)]
		"breaker_panel":
			var y: float = args[0] if not args.is_empty() else 1.45
			return [_port("in", "", lead, Vector3(0, y - 0.2, 0.15), Vector3.LEFT),
					_port("out", "", lead, Vector3(0, y - 0.2, -0.15), Vector3.LEFT)]
		"reactor_cabinet":
			var depth := float(args[1])
			var width := float(args[0])
			return [_port("power", "", lead, Vector3(depth * 0.5, 0, width * 0.35), Vector3.DOWN),
					# The coolant loop leaves low on its front (a frame behind its back wall leaves no
					# room under it) and drops through the floor.
					_port("coolant_out", "coolant", PIPE_COOLANT, Vector3(depth, 0.09, -width * 0.36), Vector3.RIGHT),
					_port("coolant_in", "coolant", PIPE_COOLANT, Vector3(depth, 0.09, -width * 0.08), Vector3.RIGHT)]
		"reactor_core":
			# Power down through the floor under its plinth; the coolant loop out of the plinth's
			# aft face, either side of the middle, and down through the floor.
			var radius := float(args[0])
			var face := (radius + 0.25) * cos(PI / 16.0)
			return [_port("power", "", lead, Vector3(radius * 0.7, 0, radius * 0.7), Vector3.DOWN),
					_port("coolant_out", "coolant", PIPE_COOLANT, Vector3(-0.3, 0.15, face), Vector3.BACK),
					_port("coolant_in", "coolant", PIPE_COOLANT, Vector3(0.3, 0.15, face), Vector3.BACK)]
		"fuel_port":
			# The coupling's back, at the hull's outer face: the feed runs in through the skin.
			return [_port("feed", "fuel", PIPE_FUEL, Vector3.ZERO, Vector3.LEFT)]
		"jump_tank":
			var size: Vector3 = args[0]
			var inboard := float(args[1])
			return [_port("fill", "fuel", PIPE_JUMP, Vector3(0, -size.y * 0.25, size.z * 0.5), Vector3.BACK),
					_port("cross", "fuel", PIPE_JUMP, Vector3(inboard * size.x * 0.5, -size.y * 0.65, -size.z * 0.3),
							Vector3(inboard, 0, 0))]
		"heat_exchanger":
			var size: Vector3 = args[0]
			return [_port("in", "coolant", PIPE_COOLANT, Vector3(-size.x * 0.25, size.y * 0.3, size.z * 0.5), Vector3.BACK),
					_port("out", "coolant", PIPE_COOLANT, Vector3(size.x * 0.25, size.y * 0.3, size.z * 0.5), Vector3.BACK)]
		"junction_box":
			var size: Vector3 = args[0]
			return [_port("a", "", 0.035, Vector3(0, size.y * 0.5, -size.z * 0.5), Vector3.FORWARD),
					_port("b", "", 0.035, Vector3(0, size.y * 0.5, size.z * 0.5), Vector3.BACK),
					_port("tap", "", lead, Vector3(size.x * 0.5, size.y * 0.5, 0), Vector3.RIGHT)]
		"lamp_driver":
			return [_port("power", "", lead, Vector3(-0.08, 0.025, 0), Vector3.LEFT),
					_port("lamp", "", 0.004, Vector3(0, 0, 0), Vector3.DOWN)]
		"lamp":
			return [_port("power", "", 0.004, Vector3(0, 0.07, 0), Vector3.UP)]
		"door_panel", "control_panel":
			return [_port("power", "", lead, Vector3.ZERO, Vector3.LEFT)]
		"monitor":
			return [_port("power", "", lead, Vector3(0, -0.075, 0), Vector3.LEFT)]
		"bowsers":
			# The manifold: the feed in through its back, the jump tanks' feed out of its foot.
			return [_port("power", "", lead, Vector3(0, 0.42, 0), Vector3.LEFT),
					_port("in", "fuel", PIPE_FUEL, Vector3(0.02, 0.3, 0.0), Vector3.LEFT),
					_port("jump", "fuel", PIPE_JUMP, Vector3(0.14, 0.21, 0.04), Vector3.DOWN)]
		"map_screen":
			return [_port("power", "", lead, Vector3(0, 0, -0.015), Vector3.FORWARD)]
	return []


static func _port(port_name: String, fluid: String, radius: float, at: Vector3, dir: Vector3) -> Dictionary:
	return {"name": port_name, "fluid": fluid, "radius": radius, "position": at, "direction": dir}


# --- Pipes (F5b: PipeRouter lays them) -------------------------------------------------------

## The ship's pipe radii, metres: the fuel lines, the coolant loop, air, the jump tanks' feed
## (docs/SHIP_FRAME_PLAN.md 4.5).
const PIPE_FUEL: float = 0.02
const PIPE_COOLANT: float = 0.03
const PIPE_AIR: float = 0.015
const PIPE_JUMP: float = 0.04
## A union's flanges, in pipe radii.
const UNION_FLARE: float = 1.45
const PIPE_SIDES: int = 10


## A straight pipe span along Y, `length` long, centred: a plain steel tube with a collar
## either side of each panel it passes (`collars`, its Y there). Its collision covers only
## `solid` ([y0, y1] each: clear of the panels it passes and the parts at its ends).
static func pipe_shape(radius: float, length: float, solid: Array = [], collars: Array[float] = []) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(radius, -h), Vector2(radius, h), Vector2(0.0, h)]), PIPE_SIDES)
	k.color = Color(0.55, 0.56, 0.58)
	for y in collars:
		k.lathe(PackedVector2Array([Vector2(radius, y - 0.012), Vector2(radius * 1.5, y - 0.012), Vector2(radius * 1.5, y + 0.012),
				Vector2(radius, y + 0.012)]), PIPE_SIDES)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * radius * radius * 0.36 * length
	# A piece under 2 mm long is a speck (a span wholly in what it passes keeps only that).
	var pieces: Array = solid if not solid.is_empty() else [[-0.0005, 0.0005]]
	for i in pieces.size():
		var y0 := float(pieces[i][0])
		var y1 := float(pieces[i][1])
		var col := _tube_hull(radius if y1 - y0 > 0.002 else 0.001, y0, y1)
		if i == 0:
			shape.collision = col
		else:
			shape.extra_collision.append(col)
	return PartShapes.stamp(shape, "pipe", [radius, length, solid, collars])


## A 90 degree elbow: from its origin heading +Y, bending toward +Z round a centre `bend` along
## +Z, ending at (0, bend, bend) heading +Z. Its collision is the middle of the bend.
static func pipe_elbow_shape(radius: float, bend: float) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var steps := 6
	var rings: Array[PackedVector3Array] = []
	var mid := PackedVector3Array()
	for i in steps + 1:
		var a := PI * 0.5 * float(i) / float(steps)
		var c := Vector3(0.0, sin(a) * bend, bend - cos(a) * bend)
		var t := Vector3(0.0, cos(a), sin(a))
		var u := Vector3.RIGHT
		var v := t.cross(u)
		var ring := PackedVector3Array()
		for j in PIPE_SIDES:
			var b := TAU * float(j) / float(PIPE_SIDES)
			ring.append(c + (u * cos(b) + v * sin(b)) * radius)
			if i >= 2 and i <= steps - 2:
				mid.append(c + (u * cos(b) + v * sin(b)) * radius * 0.85)
		rings.append(ring)
	for i in steps:
		k.loft(rings[i], rings[i + 1], false)
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.mesh.set_meta("bend", bend)
	shape.volume = PI * radius * radius * 0.36 * bend * PI * 0.5
	var hull := ConvexPolygonShape3D.new()
	hull.points = mid
	shape.collision = hull
	return PartShapes.stamp(shape, "pipe_elbow", [radius, bend])


## A flanged union along Y, `length` long, centred: a sleeve between two bolted flanges.
static func pipe_union_shape(radius: float, length: float) -> PartShapes.PartShape:
	var k := MeshKit.new()
	var h := length * 0.5
	var fr := radius * UNION_FLARE
	var ft := minf(0.012, length * 0.2)
	k.color = Color(0.72, 0.72, 0.7)
	k.lathe(PackedVector2Array([Vector2(0.0, -h), Vector2(fr, -h), Vector2(fr, -h + ft), Vector2(radius * 1.2, -h + ft),
			Vector2(radius * 1.2, h - ft), Vector2(fr, h - ft), Vector2(fr, h), Vector2(0.0, h)]), PIPE_SIDES)
	k.color = Color(0.3, 0.31, 0.33)
	var bs := maxf(radius * 0.22, 0.006)
	for y: float in [-h + ft + bs * 0.5, h - ft - bs * 0.5]:
		for j in 4:
			var a := TAU * (float(j) + 0.5) / 4.0
			k.box(Vector3(bs, bs, bs), Vector3(cos(a) * (radius * 1.2 + fr) * 0.5, y, sin(a) * (radius * 1.2 + fr) * 0.5))
	var shape := PartShapes.PartShape.new()
	shape.mesh = k.finish()
	shape.volume = PI * fr * fr * ft * 2.0 + PI * radius * radius * 0.5 * length
	shape.collision = _tube_hull(fr, -h + 0.006, h - 0.006)
	return PartShapes.stamp(shape, "pipe_union", [radius, length])


## A pipe clip's look: a band round the pipe (its Y) and a stem out along +Z, `stem` long, to
## a foot on what holds it.
static func pipe_clip_mesh(radius: float, stem: float) -> ArrayMesh:
	var k := MeshKit.new()
	k.color = Color(0.6, 0.62, 0.64)
	k.lathe(PackedVector2Array([Vector2(radius, -0.01), Vector2(radius + 0.004, -0.01), Vector2(radius + 0.004, 0.01),
			Vector2(radius, 0.01)]), PIPE_SIDES)
	if stem > 0.003:
		k.box(Vector3(0.012, 0.016, stem), Vector3(0.0, 0.0, radius + stem * 0.5))
		k.box(Vector3(0.03, 0.03, 0.004), Vector3(0.0, 0.0, radius + stem - 0.002))
	return k.finish()


## A tube's convex collision along Y from y0 to y1.
static func _tube_hull(radius: float, y0: float, y1: float) -> ConvexPolygonShape3D:
	var pts := PackedVector3Array()
	for y: float in [y0, y1]:
		for j in 8:
			var a := TAU * float(j) / 8.0
			pts.append(Vector3(cos(a) * radius, y, sin(a) * radius))
	var hull := ConvexPolygonShape3D.new()
	hull.points = pts
	return hull


# --- Helpers -------------------------------------------------------------------------------

static func _box(kit: ShipKit, frame: Transform3D, at: Vector3, size: Vector3, m: Material, solid: bool, tag: String = "") -> void:
	kit.add(PartShapes.box(size), frame * Transform3D(Basis(), at), m, tag, null, solid)


## A fitting's record: its name and its bounds in ship space (the frame-space box lo..hi).
static func _fitting(fitting_name: String, frame: Transform3D, lo: Vector3, hi: Vector3) -> Dictionary:
	return {"name": fitting_name, "box": frame * AABB(lo, hi - lo)}


# --- Systems (S3, docs/SHIP_FORMAT_PLAN.md) --------------------------------------------------
# The ship's own working parts: the control and door panels, the lift, the bowsers and fuel
# port, the hose rack, the monitors and screens. Each opens its system record with exactly the
# arguments its look uses, so a ship file's record ({system, frame, args, key}) rebuilds the same
# picture through `system`. The behaviour (what a button does, the gauges' levels, the screens'
# contents) is the game's: each returns the handles it needs (lamp materials, labels, the
# screens' glass quads, the lift's legs). Labels, quads and legs are nodes on the kit's body.

## The pump buttons' light while the pump is off (the game turns it red while it runs).
const PUMP_IDLE := Color(0.35, 1.0, 0.6)
## The hold monitor's soft keys under the screen, left to right: [tag, action, legend].
const MONITOR_KEYS: Array = [["monitor_prev", "monitor:prev", "◀"], ["monitor_next", "monitor:next", "▶"],
		["monitor_up", "monitor:up", "▲"], ["monitor_down", "monitor:down", "▼"],
		["monitor_mark", "monitor:mark", "MARK"], ["monitor_open", "monitor:open", "OPEN"],
		["monitor_focus", "monitor:focus", "F"]]
## The systems `system` builds, by record name.
const SYSTEMS: Array[String] = ["control_panel", "lift", "bowsers", "fuel_port", "hose_rack", "monitor", "cockpit_monitor",
		"double_door", "door_panel", "cockpit_screen", "nav_display", "map_screen"]


## Builds a system from its ship-file record ({system, frame, args, key}), as read from the file
## (a frame {o, b}, vectors, rects and colours as arrays, numbers as floats) or with engine
## values. Returns what that function returns; {} for an unknown one.
static func system(kit: ShipKit, record: Dictionary) -> Dictionary:
	var frame := _xform(record.get("frame", Transform3D()))
	var a: Array = record.get("args", [])
	var key: String = record.get("key", "")
	match String(record.get("system", "")):
		"control_panel":
			var buttons: Array = []
			for b: Array in a[1]:
				buttons.append([String(b[0]), String(b[1]), _colour(b[2])])
			return control_panel(kit, frame, a[0], buttons)
		"lift":
			return lift(kit, _rect(a[0]), float(a[1]))
		"bowsers":
			return bowsers(kit, frame, bool(a[0]))
		"fuel_port":
			return fuel_port(kit, frame)
		"hose_rack":
			return hose_rack(kit, frame)
		"monitor":
			return monitor(kit, frame, _vec2(a[0]))
		"cockpit_monitor":
			return cockpit_monitor(kit, frame.origin, float(a[0]))
		"double_door":
			return double_door(kit, float(a[0]), float(a[1]), float(a[2]), int(a[3]))
		"door_panel":
			return door_panel(kit, frame, key, int(a[0]))
		"cockpit_screen":
			return cockpit_screen(kit, frame.origin, float(a[0]), _colour(a[1]))
		"nav_display":
			return nav_display(kit, frame.origin, float(a[0]), float(a[1]), float(a[2]))
		"map_screen":
			return map_screen(kit, frame, float(a[0]), float(a[1]))
	return {}


## A record's values as the engine's: from the file's form (vsship 4.1) or as they are.
static func _xform(v: Variant) -> Transform3D:
	if v is Transform3D:
		return v
	var d: Dictionary = v if v is Dictionary else {}
	var o: Array = d.get("o", [0, 0, 0])
	var t := Transform3D(Basis(), Vector3(o[0], o[1], o[2]))
	if d.has("b"):
		var b: Array = d["b"]   # rows
		t.basis = Basis(Vector3(b[0], b[3], b[6]), Vector3(b[1], b[4], b[7]), Vector3(b[2], b[5], b[8]))
	return t


static func _vec2(v: Variant) -> Vector2:
	return v if v is Vector2 else Vector2(v[0], v[1])


static func _rect(v: Variant) -> Rect2:
	return v if v is Rect2 else Rect2(v[0], v[1], v[2], v[3])


static func _colour(v: Variant) -> Color:
	if v is Color:
		return v
	return Color(v[0], v[1], v[2], v[3] if (v as Array).size() > 3 else 1.0)


## Text printed on a surface: `at` in the frame's space, facing along its X.
static func panel_label(kit: ShipKit, text: String, frame: Transform3D, at: Vector3, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = ShipKit.mono_font()
	label.font_size = size
	label.pixel_size = 0.0016
	label.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), at)
	label.modulate = color
	label.outline_size = 0
	kit.body.add_child(label)
	return label


## A screen with a bezel on a surface: `at` is its middle in the frame's space (X out of the
## surface). Returns its text, top left aligned.
static func screen(kit: ShipKit, frame: Transform3D, at: Vector3, size: Vector2, font_size: int) -> Label3D:
	var bezel := ShipKit.paint(Color(0.32, 0.34, 0.36), 0.7, 0.35)
	_box(kit, frame, at + Vector3(0.015, 0.0, 0.0), Vector3(0.03, size.y + 0.05, size.x + 0.05), bezel, false)
	_box(kit, frame, at + Vector3(0.032, 0.0, 0.0), Vector3(0.004, size.y, size.x), ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0), false)
	var label := panel_label(kit, "", frame, at + Vector3(0.036, size.y * 0.5 - 0.015, size.x * 0.5 - 0.02), font_size,
			Color(0.45, 0.95, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return label


## A screen's glass: a quad `size` metres facing its +Z at `at`, dark until the game draws on it
## (it sets the material to its view's texture).
static func glass_quad(kit: ShipKit, at: Transform3D, size: Vector2) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	quad.mesh = qm
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.01, 0.03, 0.04)
	quad.material_override = dark
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.transform = at
	kit.body.add_child(quad)
	return quad


## The control panel: square buttons in a row, each with its name printed under it and a lamp
## over it (lit by the game while that thing is on). `buttons` are [label, action, colour];
## a button is tagged "button_<action>". `frame` sits on the wall surface behind the panel's
## centre: X out into the room, Y up. Returns {lamps: {action: [lamp material, colour]}}.
static func control_panel(kit: ShipKit, frame: Transform3D, title: String, buttons: Array) -> Dictionary:
	kit.begin_system("control_panel", frame, [title, buttons], "")
	var count := buttons.size()
	var length := 0.36 * float(count) + 0.15
	_box(kit, frame, Vector3(0.03, 0, 0), Vector3(0.06, 0.78, length), base("hull_dark"), true)
	_box(kit, frame, Vector3(0.04, 0.44, 0), Vector3(0.02, 0.1, length), base("hazard"), false)
	panel_label(kit, title, frame, Vector3(0.063, 0.295, 0), 30, Color(0.95, 0.75, 0.3))
	var lamps := {}
	for i in count:
		var b: Array = buttons[i]
		var bz := (float(count - 1) * 0.5 - float(i)) * 0.36   # left to right as you face it
		_box(kit, frame, Vector3(0.0675, 0.03, bz), Vector3(0.015, 0.22, 0.22), ShipKit.paint(Color(0.1, 0.1, 0.11), 0.6, 0.4), false)
		_box(kit, frame, Vector3(0.08, 0.03, bz), Vector3(0.04, 0.16, 0.16), ShipKit.glow(b[2], 1.2), true, "button_%s" % b[1])
		var lamp := ShipKit.glow(Color(0.05, 0.05, 0.05), 0.0)
		_box(kit, frame, Vector3(0.066, 0.19, bz), Vector3(0.012, 0.035, 0.12), lamp, false)
		lamps[b[1]] = [lamp, b[2]]
		panel_label(kit, b[0], frame, Vector3(0.063, -0.14, bz), 24, Color(0.85, 0.92, 1.0))
	kit.end_system()
	return {"lamps": lamps}


## A cargo lift in the deck opening `rect` (x, z): hazard lining round the shaft, the platform
## (tag "lift", a leaf of its own on a frame build) and telescopic legs (hidden until the game
## stretches them down to the lowered platform). `deck_bottom` is the underside of the deck
## slab. Returns {legs: [[sleeve, leg, top centre]]}.
static func lift(kit: ShipKit, rect: Rect2, deck_bottom: float) -> Dictionary:
	kit.begin_system("lift", null, [rect, deck_bottom], "lift")
	var hazard := base("hazard")
	var hull_dark := base("hull_dark")
	var lz := rect.get_center().y
	var lx := rect.get_center().x
	var hx := rect.size.x * 0.5
	var hz := rect.size.y * 0.5
	for e: Array in [[rect.position.x, true], [rect.end.x, true], [rect.position.y, false], [rect.end.y, false]]:
		if e[1]:
			kit.block(Vector3(e[0] - 0.03, deck_bottom, rect.position.y), Vector3(e[0] + 0.03, -0.01, rect.end.y), hazard)
		else:
			kit.block(Vector3(rect.position.x + 0.03, deck_bottom, e[0] - 0.03), Vector3(rect.end.x - 0.03, -0.01, e[0] + 0.03), hazard)
	# The platform: on a frame build a part of its own that rides its legs (the shaft round it is
	# the lift's part).
	kit.begin_unit("leaf", "platform", "lift")
	kit.add(PartShapes.box(Vector3(rect.size.x - 0.1, 0.15, rect.size.y - 0.1)), Transform3D(Basis(), Vector3(lx, -0.08, lz)),
			base("floor_mat"), "lift")
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		kit.add(PartShapes.box(Vector3(0.18, 0.02, 0.18)), Transform3D(Basis(),
				Vector3(lx + c.x * (hx - 0.2), 0.005, lz + c.y * (hz - 0.2))), hazard, "lift", null, false)
	var steel := ShipKit.paint(Color(0.55, 0.57, 0.58), 0.8, 0.3)
	# Legs just outside the platform's sides, hanging from under the deck; ears on the
	# platform's sides catch their feet.
	var legs: Array = []
	for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector3(lx + c.x * (hx + 0.06), 0.0, lz + c.y * (hz - 0.35))
		kit.add(PartShapes.box(Vector3(0.22, 0.08, 0.16)), Transform3D(Basis(), Vector3(lx + c.x * (hx + 0.02), -0.08, at.z)),
				hull_dark, "lift", null, false)
		var sleeve := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.11, 1.0, 0.11)
		sleeve.mesh = sm
		sleeve.material_override = hull_dark
		sleeve.visible = false
		kit.body.add_child(sleeve)
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.07, 1.0, 0.07)
		leg.mesh = lm
		leg.material_override = steel
		leg.visible = false
		kit.body.add_child(leg)
		legs.append([sleeve, leg, at])
	kit.end_unit()
	kit.end_system()
	return {"legs": legs}


## The bowsers: a manifold where the fuel port's feed comes in and splits two ways, and two
## upright tanks, fuel then coolant, each with a level gauge on its front. `frame` sits on the
## floor at the wall where the feed arrives (at the manifold), X out into the room, Z along the
## wall toward the tanks. The manifold has PUMP ("bowser_pump") and TANK ("tank_fill") buttons
## and a status screen. `plumbed`: the real feed is laid (no stand-in pipe behind the manifold).
## Returns {text (the screen's), gauges: [{fluid, bar, label, frame, at (the bar's bottom),
## height}]} (the bars are unit-tall boxes the game scales to the level).
static func bowsers(kit: ShipKit, frame: Transform3D, plumbed: bool) -> Dictionary:
	kit.begin_system("bowsers", frame, [plumbed], "pump")
	var steel := ShipKit.paint(Color(0.55, 0.57, 0.6), 0.7, 0.4)
	var dark := ShipKit.paint(Color(0.18, 0.19, 0.21), 0.5, 0.6)
	var along_z := Basis(Vector3.RIGHT, PI * 0.5)   # a cylinder's Y -> the frame's Z
	var out_x := Basis(Vector3.BACK, -PI * 0.5)     # a cylinder's Y -> the frame's X
	# The manifold: a block on the wall, the feed in from behind, two outlets toward the tanks.
	kit.add(PartShapes.chamfer_box(Vector3(0.24, 0.42, 0.42), 0.03), frame * Transform3D(Basis(), Vector3(0.14, 0.42, 0.0)), steel)
	# A stand-in for the feed coming in from behind, unless the real feed is laid (F5b).
	if not plumbed:
		kit.add(PartShapes.prism(10, 0.06, 0.12), frame * Transform3D(along_z, Vector3(0.1, 0.32, -0.26)), dark, "", null, false)
	# Two buttons of one size side by side, centred on the block's face: PUMP, and TANK (moves
	# bowser fuel into the quantum drive's jump tank).
	_box(kit, frame, Vector3(0.27, 0.48, 0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(PUMP_IDLE, 0.6), true, "bowser_pump")
	panel_label(kit, "PUMP", frame, Vector3(0.262, 0.58, 0.075), 18, Color(0.85, 0.92, 1.0))
	_box(kit, frame, Vector3(0.27, 0.48, -0.075), Vector3(0.04, 0.11, 0.11), ShipKit.glow(Color(1.0, 0.65, 0.15), 0.6), true, "tank_fill")
	panel_label(kit, "TANK", frame, Vector3(0.262, 0.58, -0.075), 18, Color(1.0, 0.8, 0.45))
	panel_label(kit, "MANIFOLD", frame, Vector3(0.262, 0.27, 0.0), 16, Color(0.85, 0.92, 1.0))
	var text := screen(kit, frame, Vector3(0.0, 1.05, 0.0), Vector2(0.5, 0.24), 16)
	var tanks: Array = [["fuel", 1.05, base("hazard"), Color(1.0, 0.65, 0.15), 0.25],
			["coolant", 2.25, ShipKit.paint(Color(0.22, 0.52, 0.66), 0.35, 0.5), Color(0.35, 0.85, 1.0), 0.55]]
	var gauges: Array = []
	for t: Array in tanks:
		var z: float = t[1]
		var pipe_y: float = t[4]
		var at := Vector3(0.72, 0.0, z)
		# The tank: an upright drum on a footing, a dome on top, a band round it.
		kit.add(PartShapes.prism(20, 0.56, 0.14), frame * Transform3D(Basis(), at + Vector3(0, 0.07, 0)), dark)
		kit.add(PartShapes.prism(20, 0.5, 2.2), frame * Transform3D(Basis(), at + Vector3(0, 1.24, 0)), t[2])
		kit.add(PartShapes.dome(0.5, 0.22, 20, 4), frame * Transform3D(Basis(), at + Vector3(0, 2.34, 0)), t[2], "", null, false)
		kit.add(PartShapes.ring(0.5, 0.52, 0.08), frame * Transform3D(Basis(), at + Vector3(0, 2.05, 0)), dark, "", null, false)
		# Its pipe from the manifold, along the wall and into the tank's back near the bottom,
		# with a band of its colour.
		var run := z - 0.2
		kit.add(PartShapes.prism(10, 0.045, run), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.2 + run * 0.5)), steel, "", null, false)
		kit.add(PartShapes.prism(10, 0.045, 0.18), frame * Transform3D(out_x, Vector3(0.14, pipe_y, z)), steel, "", null, false)
		kit.add(PartShapes.prism(10, 0.05, 0.06), frame * Transform3D(along_z, Vector3(0.07, pipe_y, 0.32)),
				ShipKit.glow(t[3], 0.8), "", null, false)
		# The level gauge on the front: a slot with ticks, a bar that rises with the level.
		var face := 0.72 + 0.5
		var low := 0.45
		var high := 2.0
		_box(kit, frame, Vector3(face, (low + high) * 0.5, z), Vector3(0.04, high - low + 0.12, 0.17), dark, false)
		_box(kit, frame, Vector3(face + 0.021, (low + high) * 0.5, z), Vector3(0.004, high - low, 0.08),
				ShipKit.glow(Color(0.02, 0.03, 0.04), 1.0), false)
		for k in 5:
			var y := lerpf(low, high, float(k) / 4.0)
			_box(kit, frame, Vector3(face + 0.023, y, z + 0.065), Vector3(0.003, 0.008, 0.035 if k % 2 == 0 else 0.022),
					base("white"), false)
		var bar := MeshInstance3D.new()
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.006, 1.0, 0.06)
		bar.mesh = bar_mesh
		bar.material_override = ShipKit.glow(t[3], 0.8)
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		kit.body.add_child(bar)
		var name_label := panel_label(kit, (t[0] as String).to_upper(), frame, Vector3(face + 0.022, high + 0.17, z), 40, t[3])
		name_label.outline_size = 0
		var litres := panel_label(kit, "", frame, Vector3(face + 0.022, low - 0.16, z), 26, Color(0.85, 0.92, 1.0))
		gauges.append({"fluid": t[0], "bar": bar, "label": litres, "frame": frame,
				"at": Vector3(face + 0.025, low, z), "height": high - low})
	kit.end_system()
	return {"text": text, "gauges": gauges}


## The fuel port on the hull, where the hose plugs in: a recessed panel (tag "fuel_port": the
## whole panel takes the plug) with a brass coupling, a work light over it, and to its left a
## status screen over the PUMP button ("bowser_pump") and the IN/OUT switch ("pump_dir"; its
## lever "pump_dir_lever" swings down about `pivot` round `axis` for OUT). `frame` sits on the
## hull's outer surface at the coupling, X out of the hull, Y up (+Z is on your left as you face
## it). Returns {text, pivot, axis (ship space), plug (where the hose's plug sits: its tip into
## the hull)}.
static func fuel_port(kit: ShipKit, frame: Transform3D) -> Dictionary:
	kit.begin_system("fuel_port", frame, [], "pump_out")
	var hazard := base("hazard")
	var dark := ShipKit.paint(Color(0.12, 0.13, 0.14), 0.6, 0.5)
	var brass := ShipKit.paint(Color(0.75, 0.55, 0.28), 0.9, 0.3)
	var face := Basis(Vector3.BACK, -PI * 0.5)   # a cylinder's Y -> the frame's X
	_box(kit, frame, Vector3(0.03, 0.0, 0.3), Vector3(0.06, 0.95, 1.25), dark, true, "fuel_port")
	_box(kit, frame, Vector3(0.065, 0.45, 0.3), Vector3(0.01, 0.04, 1.25), hazard, false)
	# The coupling, with a slim amber ring round it.
	kit.add(PartShapes.ring(0.065, 0.1, 0.12), frame * Transform3D(face, Vector3(0.1, 0.0, 0.0)), brass, "fuel_port")
	kit.add(PartShapes.prism(16, 0.065, 0.02), frame * Transform3D(face, Vector3(0.06, 0.0, 0.0)), dark, "", null, false)
	kit.add(PartShapes.ring(0.105, 0.118, 0.02), frame * Transform3D(face, Vector3(0.065, 0.0, 0.0)),
			ShipKit.glow(Color(1.0, 0.7, 0.25), 2.0), "", null, false)
	panel_label(kit, "FUEL", frame, Vector3(0.063, 0.16, 0.0), 24, Color(1.0, 0.75, 0.3))
	# A work light over the panel: easy to find on a dark hull.
	kit.light(frame * Vector3(0.9, 0.75, 0.3), Color(1.0, 0.88, 0.7), 1.2, 4.5)
	# Left of the coupling: the status screen, and under it the pump button and the switch.
	var text := screen(kit, frame, Vector3(0.06, 0.17, 0.6), Vector2(0.5, 0.24), 16)
	_box(kit, frame, Vector3(0.08, -0.2, 0.74), Vector3(0.04, 0.12, 0.12), ShipKit.glow(PUMP_IDLE, 0.6), true, "bowser_pump")
	panel_label(kit, "PUMP", frame, Vector3(0.063, -0.31, 0.74), 18, Color(0.85, 0.92, 1.0))
	var pivot := Vector3(0.075, -0.2, 0.47)
	_box(kit, frame, Vector3(0.068, -0.2, 0.47), Vector3(0.016, 0.16, 0.09), base("hull_dark"), true, "pump_dir")
	# The switch's lever, up for IN; it swings down for OUT.
	var up := Basis(Vector3.BACK, 0.6)
	kit.add(PartShapes.box(Vector3(0.11, 0.022, 0.022)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.055, 0, 0)),
			base("steel_lever"), "pump_dir_lever")
	kit.add(PartShapes.box(Vector3(0.035, 0.035, 0.035)), frame * Transform3D(up, pivot) * Transform3D(Basis(), Vector3(0.115, 0, 0)),
			hazard, "pump_dir_lever", null, false)
	panel_label(kit, "IN", frame, Vector3(0.063, -0.065, 0.47), 18, Color(0.85, 0.92, 1.0))
	panel_label(kit, "OUT", frame, Vector3(0.063, -0.335, 0.47), 18, Color(0.85, 0.92, 1.0))
	kit.end_system()
	return {"text": text, "pivot": frame * pivot, "axis": frame.basis * Vector3.BACK,
			"plug": frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.24, 0.0, 0.0))}


## A wall rack the hose coil hangs on (two hooks and a strap; tag "hose_rack"). `frame` sits on
## the wall surface at the coil's middle, X out into the room, Y up.
static func hose_rack(kit: ShipKit, frame: Transform3D) -> Dictionary:
	kit.begin_system("hose_rack", frame, [], "")
	var dark := ShipKit.paint(Color(0.2, 0.21, 0.23), 0.6, 0.5)
	_box(kit, frame, Vector3(0.015, 0.0, 0.0), Vector3(0.03, 0.9, 0.9), base("hull_dark"), true, "hose_rack")
	for z: float in [-0.22, 0.22]:
		_box(kit, frame, Vector3(0.17, 0.34, z), Vector3(0.3, 0.05, 0.05), dark, true, "hose_rack")
		_box(kit, frame, Vector3(0.3, 0.38, z), Vector3(0.04, 0.1, 0.05), dark, false, "hose_rack")
	_box(kit, frame, Vector3(0.035, -0.3, 0.0), Vector3(0.012, 0.08, 0.9), base("hazard"), false)
	panel_label(kit, "FUEL HOSE", frame, Vector3(0.033, -0.38, 0.0), 20, Color(1.0, 0.75, 0.3))
	kit.end_system()
	return {}


## The hold monitor on a wall: a bezel, the screen (`screen`, width x height in metres, 16:9;
## its face tagged "monitor_screen") and the soft keys under it (`MONITOR_KEYS`, tagged by their
## first entry). `frame` sits on the wall surface at the screen's middle: X out into the room, Y
## up, Z along the wall (+Z on your left as you face it). Returns {glass (the quad the game draws
## the monitor on), at (the screen's middle, ship space), keys (the legends' labels)}.
static func monitor(kit: ShipKit, frame: Transform3D, screen_size: Vector2) -> Dictionary:
	kit.begin_system("monitor", frame, [screen_size], "")
	var keys_y := -screen_size.y * 0.5 - 0.1
	var bezel_h := screen_size.y + 0.3
	_box(kit, frame, Vector3(0.04, -0.075, 0.0), Vector3(0.08, bezel_h, screen_size.x + 0.08), base("hull_dark"), true)
	# The screen's face: a thin box in front of the bezel.
	_box(kit, frame, Vector3(0.085, 0.0, 0.0), Vector3(0.01, screen_size.y, screen_size.x), ShipKit.glow(Color(0.01, 0.04, 0.06), 0.4),
			true, "monitor_screen")
	_box(kit, frame, Vector3(0.082, screen_size.y * 0.5 + 0.012, 0.0), Vector3(0.006, 0.006, screen_size.x),
			ShipKit.glow(EDGE, 1.2), false)
	var glass := glass_quad(kit, frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0915, 0.0, 0.0)), screen_size)
	# The soft keys: the four page/scroll keys left, MARK, OPEN, then FOCUS apart on the right.
	var spacing := minf(0.2, screen_size.x / 8.0)
	var keys: Array = []
	for i in MONITOR_KEYS.size():
		var k: Array = MONITOR_KEYS[i]
		var z := screen_size.x * 0.5 - 0.12 - float(i) * spacing - (spacing * 0.6 if i == MONITOR_KEYS.size() - 1 else 0.0)
		if i == MONITOR_KEYS.size() - 1:
			z = -screen_size.x * 0.5 + 0.12
		_box(kit, frame, Vector3(0.095, keys_y, z), Vector3(0.03, 0.07, 0.13), ShipKit.glow(Color(0.08, 0.32, 0.4), 0.6), true, k[0])
		keys.append(panel_label(kit, k[2], frame, Vector3(0.112, keys_y, z), 22 if (k[2] as String).length() < 3 else 16, SCREEN))
	kit.end_system()
	return {"glass": glass, "at": frame * Vector3(0.1, 0.0, 0.0), "keys": keys}


## The cockpit's compact monitor: a dark board at `at` tilted back `tilt_deg`, its glass on
## the front. Returns {glass}.
static func cockpit_monitor(kit: ShipKit, at: Vector3, tilt_deg: float) -> Dictionary:
	kit.begin_system("cockpit_monitor", Transform3D(Basis(), at), [tilt_deg], "")
	var screen_basis := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	kit.add(PartShapes.box(Vector3(0.7, 0.46, 0.03)), Transform3D(screen_basis, at), base("hull_dark"), "", null, false)
	var glass := glass_quad(kit, Transform3D(screen_basis, at + screen_basis * Vector3(0, 0, 0.017)), Vector2(0.66, 0.4125))
	kit.end_system()
	return {"glass": glass}


## Double sliding doors in a cross wall at `wall_z` (leaves tagged door_aft_l / door_aft_r, key
## "door_aft"), the leaves on `side` (+1 = +z) of it, with a door panel each side of the wall;
## `leaf_side_x` places the panel on the leaves' side clear of where they slide open. `first`
## numbers the panels' button tags (`door_panel`'s `n`). Returns {panels: [the two panels]}.
static func double_door(kit: ShipKit, wall_z: float, side: float, leaf_side_x: float, first: int) -> Dictionary:
	kit.begin_system("double_door", null, [wall_z, side, leaf_side_x, first], "door_aft")
	for lr: float in [-1.0, 1.0]:
		var tag := "door_aft_%s" % ("l" if lr < 0.0 else "r")
		kit.add(PartShapes.box(Vector3(1.18, 2.38, 0.08)), Transform3D(Basis(), Vector3(lr * 0.6, 1.2, wall_z + side * 0.14)),
				base("hull_dark"), tag)
		kit.add(PartShapes.box(Vector3(0.9, 0.12, 0.01)), Transform3D(Basis(), Vector3(lr * 0.6, 1.3, wall_z + side * 0.185)),
				base("hazard"), tag, null, false)
	# A door panel each side of the wall. The leaves slide over the wall on `side`, so that
	# side's panel sits beyond where they open to.
	var half := 0.06   # both designs use 0.12 m partition walls
	var panels: Array = []
	panels.append(door_panel(kit, Transform3D(Basis(Vector3.UP, -PI * 0.5 * side), Vector3(leaf_side_x, 1.3, wall_z + side * half)),
			"door_aft", first))
	panels.append(door_panel(kit, Transform3D(Basis(Vector3.UP, PI * 0.5 * side), Vector3(1.6, 1.3, wall_z - side * half)),
			"door_aft", first + 1))
	kit.end_system()
	return {"panels": panels}


## A small door panel on a wall: OPEN (green) over CLOSE (red) for the door `key`, with a lamp
## the game lights with the door's state. `frame` sits on the wall surface, X out into the room.
## `n` numbers its buttons' tags ("doorbtn_<key>_open_<n>", "..._close_<n>"). Returns {lamp,
## buttons: {tag: action}}.
static func door_panel(kit: ShipKit, frame: Transform3D, key: String, n: int) -> Dictionary:
	kit.begin_system("door_panel", frame, [n], key)
	_box(kit, frame, Vector3(0.02, 0, 0), Vector3(0.04, 0.5, 0.26), base("hull_dark"), true)
	_box(kit, frame, Vector3(0.027, 0.27, 0), Vector3(0.02, 0.04, 0.26), base("hazard"), false)
	var lamp := ShipKit.glow(Color(0.05, 0.05, 0.05), 0.0)
	_box(kit, frame, Vector3(0.042, 0.2, 0), Vector3(0.008, 0.03, 0.12), lamp, false)
	var buttons := {}
	for b: Array in [["OPEN", "open", Color(0.3, 1.0, 0.45), 0.08], ["CLOSE", "close", Color(1.0, 0.3, 0.2), -0.12]]:
		var tag := "doorbtn_%s_%s_%d" % [key, b[1], n]
		_box(kit, frame, Vector3(0.05, b[3], 0), Vector3(0.025, 0.1, 0.1), ShipKit.glow(b[2], 1.2), true, tag)
		buttons[tag] = "%s:%s" % [key, b[1]]
		panel_label(kit, b[0], frame, Vector3(0.042, b[3] - 0.075, 0), 18, Color(0.85, 0.92, 1.0))
	kit.end_system()
	return {"lamp": lamp, "buttons": buttons}


## A cockpit screen: dark glass at `at` tilted back `tilt_deg`, its text in `accent`. Returns
## {text} (the game fills it in).
static func cockpit_screen(kit: ShipKit, at: Vector3, tilt_deg: float, accent: Color) -> Dictionary:
	kit.begin_system("cockpit_screen", Transform3D(Basis(), at), [tilt_deg, accent], "")
	var screen_basis := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	kit.add(PartShapes.box(Vector3(0.7, 0.42, 0.03)), Transform3D(screen_basis, at),
			ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0), "", null, false)
	var text := Label3D.new()
	text.font = ShipKit.mono_font()
	text.font_size = 22
	text.pixel_size = 0.0015
	text.line_spacing = -3.0
	text.modulate = accent
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	text.transform = Transform3D(screen_basis, at + screen_basis * Vector3(-0.32, 0.19, 0.02))
	kit.body.add_child(text)
	kit.end_system()
	return {"text": text}


## The graphic nav display on a console: a screen `width` x `height` metres at `at`, tilted back
## `tilt_deg`, in a dark frame. Returns {glass, pixels (the view's size the game draws at)}.
static func nav_display(kit: ShipKit, at: Vector3, tilt_deg: float, width: float, height: float) -> Dictionary:
	kit.begin_system("nav_display", Transform3D(Basis(), at), [tilt_deg, width, height], "")
	var screen_basis := Basis(Vector3.RIGHT, deg_to_rad(-tilt_deg))
	kit.add(PartShapes.box(Vector3(width + 0.06, height + 0.06, 0.03)), Transform3D(screen_basis, at),
			base("hull_dark"), "", null, false)
	var glass := glass_quad(kit, Transform3D(screen_basis, at + screen_basis * Vector3(0, 0, 0.017)), Vector2(width, height))
	kit.end_system()
	return {"glass": glass, "pixels": Vector2i(int(width * 700.0), int(height * 700.0))}


## The system map on a console screen: `frame` puts the screen's centre at its origin facing
## its +Z, `width` x `height` m, in a dark frame. Returns {glass, pixels}.
static func map_screen(kit: ShipKit, frame: Transform3D, width: float, height: float) -> Dictionary:
	kit.begin_system("map_screen", frame, [width, height], "")
	kit.add(PartShapes.box(Vector3(width + 0.06, height + 0.06, 0.03)), frame, base("hull_dark"), "", null, false)
	var glass := glass_quad(kit, frame * Transform3D(Basis(), Vector3(0, 0, 0.017)), Vector2(width, height))
	kit.end_system()
	return {"glass": glass, "pixels": Vector2i(int(width * 700.0), int(height * 700.0))}
