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

static var _mats: Dictionary = {}


## A shared material of the livery: "shell", "trim", "dark", "soft", "top", "steel", "edge"
## (lit), "screen" (dark glass, faintly lit), "warm" (a warm lamp lens), "cold" (a white one).
static func mat(which: String) -> Material:
	if _mats.has(which):
		return _mats[which]
	var m: Material
	match which:
		"shell":
			m = ShipKit.paint(SHELL, 0.25, 0.42)
		"trim":
			m = ShipKit.paint(TRIM, 0.35, 0.4)
		"dark":
			m = ShipKit.paint(DARK, 0.55, 0.5)
		"soft":
			m = ShipKit.paint(SOFT, 0.0, 0.9)
		"top":
			m = ShipKit.paint(TOP, 0.3, 0.3)
		"steel":
			m = ShipKit.paint(Color(0.6, 0.62, 0.64), 0.8, 0.3)
		"edge":
			m = ShipKit.glow(EDGE, 1.6)
		"screen":
			m = ShipKit.glow(Color(0.02, 0.07, 0.1), 1.0)
		"warm":
			m = ShipKit.glow(Color(1.0, 0.78, 0.5), 2.2)
		"cold":
			m = ShipKit.glow(Color(0.9, 0.95, 1.0), 3.0)
		_:
			m = ShipKit.paint(Color.MAGENTA)
	_mats[which] = m
	return m


# --- Seating and consoles -------------------------------------------------------------------

## A cockpit seat facing -Z, its base at `at` (ship space). The cushion and back carry `tag`
## (sit with F). A shell on a dark pedestal, trim-coloured headrest, lit edges on the arms.
static func seat(kit: ShipKit, at: Vector3, tag: String) -> Dictionary:
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
	return _fitting("seat", f, Vector3(-0.38, 0, -0.32), Vector3(0.38, 1.6, 0.42))


## A sloped console `width` wide: a dark desk with a shell fascia, the operator on its +Z
## side. `frame` origin on the floor at the middle of the desk's front foot.
static func console(kit: ShipKit, frame: Transform3D, width: float, depth: float = 0.55, height: float = 0.78) -> Dictionary:
	var face := Basis(Vector3.UP, PI)   # the slope's high side away from the operator
	kit.add(PartShapes.slope(Vector3(width, height, depth), 0.62), frame * Transform3D(face, Vector3(0, height * 0.5, -depth * 0.5)),
			mat("dark"))
	_box(kit, frame, Vector3(0, height * 0.31, -0.02), Vector3(width - 0.1, height * 0.6, 0.04), mat("shell"), false)
	_box(kit, frame, Vector3(0, height * 0.62 + 0.005, 0.0), Vector3(width, 0.01, 0.02), mat("edge"), false)
	_box(kit, frame, Vector3(0, 0.04, -0.03), Vector3(width - 0.2, 0.08, 0.02), mat("trim"), false)
	return _fitting("console", frame, Vector3(-width * 0.5, 0, -depth), Vector3(width * 0.5, height, 0.02))


# --- Crew -----------------------------------------------------------------------------------

## Two fold-down bunks, one over the other, `length` long along the wall: frames hinged to
## the wall on struts, mattresses, pillows at the -Z end, a reading lamp over each and a
## trim-coloured privacy rail along the top.
static func bunks(kit: ShipKit, frame: Transform3D, length: float = 1.95, depth: float = 0.82) -> Dictionary:
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
	return _fitting("bunks", frame, Vector3(0, 0, -length * 0.5 - 0.03), Vector3(depth, top, length * 0.5 + 0.03))


## A tall locker 0.4 m wide: a shell door with vent slots, a lit edge down its handle side
## and a name plate over the door. Returns {name, box, label}: the plate's text, which the
## ship fills with a crew member's name (the loadout made visible; tools come later).
static func locker(kit: ShipKit, frame: Transform3D, width: float = 0.4, depth: float = 0.42) -> Dictionary:
	var h := 2.0
	_box(kit, frame, Vector3(depth * 0.5, h * 0.5, 0), Vector3(depth, h, width), mat("dark"), true)
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
	return out


## A galley strip `length` long: base cupboards under a counter top with a sink and a hob,
## and (with `cupboards`) wall cupboards over it; a warm light strip over the counter.
static func galley(kit: ShipKit, frame: Transform3D, length: float, depth: float = 0.6, cupboards: bool = true) -> Dictionary:
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
	return _fitting("galley", frame, Vector3(0, 0, -length * 0.5 - 0.01), Vector3(depth, high + (0.6 if cupboards else 0.05), length * 0.5 + 0.01))


## A table against the wall, `size` (x out from the wall, z along it), on one pedestal, with a
## screen inlaid in its top (the contract board). Returns {name, box, label}: the screen's
## text, lying flat and read from the room side.
static func table(kit: ShipKit, frame: Transform3D, size: Vector2) -> Dictionary:
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
	label.modulate = SCREEN
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
	return out


## A bench seat along the wall, `length` long, a cushion on a dark box.
static func bench(kit: ShipKit, frame: Transform3D, length: float, depth: float = 0.45) -> Dictionary:
	_box(kit, frame, Vector3(depth * 0.5, 0.2, 0), Vector3(depth, 0.4, length), mat("dark"), true)
	kit.add(PartShapes.chamfer_box(Vector3(depth - 0.02, 0.1, length - 0.02), 0.03),
			frame * Transform3D(Basis(), Vector3(depth * 0.5, 0.45, 0)), mat("soft"), "", null, false)
	kit.add(PartShapes.chamfer_box(Vector3(0.1, 0.45, length - 0.04), 0.03),
			frame * Transform3D(Basis(), Vector3(0.06, 0.78, 0)), mat("soft"), "", null, false)
	_box(kit, frame, Vector3(depth + 0.001, 0.36, 0), Vector3(0.004, 0.012, length), mat("edge"), false)
	return _fitting("bench", frame, Vector3(0, 0, -length * 0.5), Vector3(depth, 1.0, length * 0.5))


## The suit stand by the airlock: a dark back plate with a suit cradle, helmet shelf, a tool
## hook rail and the charge lamp.
static func suit_stand(kit: ShipKit, frame: Transform3D, width: float = 0.6) -> Dictionary:
	_box(kit, frame, Vector3(0.02, 1.05, 0), Vector3(0.04, 2.0, width), mat("dark"), true)
	_box(kit, frame, Vector3(0.1, 0.06, 0), Vector3(0.2, 0.12, width), mat("dark"), true)
	_box(kit, frame, Vector3(0.12, 1.25, 0), Vector3(0.2, 0.7, 0.26), mat("shell"), false)     # the cradle
	_box(kit, frame, Vector3(0.18, 1.78, 0), Vector3(0.3, 0.03, width - 0.06), mat("shell"), true)   # helmet shelf
	kit.add(PartShapes.dome(0.14, 0.16, 12, 3), frame * Transform3D(Basis(), Vector3(0.18, 1.795, 0)), mat("trim"), "", null, false)
	_box(kit, frame, Vector3(0.07, 0.85, 0), Vector3(0.06, 0.03, width - 0.08), mat("steel"), false)
	_box(kit, frame, Vector3(0.045, 1.6, width * 0.5 - 0.06), Vector3(0.012, 0.05, 0.05), ShipKit.glow(Color(0.3, 1.0, 0.45), 1.5), false)
	_box(kit, frame, Vector3(0.045, 0.2, 0), Vector3(0.012, 0.012, width - 0.04), mat("edge"), false)
	return _fitting("suit stand", frame, Vector3(0, 0, -width * 0.5), Vector3(0.33, 2.05, width * 0.5))


## A small shelf on a wall at height `y` for one kept trophy part, lit from under its lip.
static func trophy_shelf(kit: ShipKit, frame: Transform3D, y: float, width: float = 0.7) -> Dictionary:
	_box(kit, frame, Vector3(0.14, y, 0), Vector3(0.28, 0.04, width), mat("top"), true)
	_box(kit, frame, Vector3(0.27, y - 0.025, 0), Vector3(0.02, 0.01, width - 0.04), mat("edge"), false)
	for z: float in [-width * 0.4, width * 0.4]:
		_box(kit, frame, Vector3(0.06, y - 0.08, z), Vector3(0.12, 0.12, 0.02), mat("dark"), false)
	_box(kit, frame, Vector3(0.02, y + 0.26, 0), Vector3(0.012, 0.36, width), mat("trim"), false)
	return _fitting("trophy shelf", frame, Vector3(0, y - 0.15, -width * 0.5), Vector3(0.29, y + 0.45, width * 0.5))


# --- Ship systems ---------------------------------------------------------------------------

## The breaker and power panel: a cabinet on the wall (centre at height `y`) with a row of
## breaker toggles and a lit status strip. Decor for now: the ship itself has no grid.
static func breaker_panel(kit: ShipKit, frame: Transform3D, y: float = 1.45) -> Dictionary:
	_box(kit, frame, Vector3(0.04, y, 0), Vector3(0.08, 0.7, 0.5), mat("dark"), true)
	_box(kit, frame, Vector3(0.081, y + 0.31, 0), Vector3(0.004, 0.04, 0.5), mat("trim"), false)
	for i in 6:
		var z := -0.19 + float(i) * 0.076
		_box(kit, frame, Vector3(0.085, y + 0.05, z), Vector3(0.012, 0.16, 0.05), mat("shell"), false)
		_box(kit, frame, Vector3(0.1, y + 0.09, z), Vector3(0.02, 0.05, 0.025), mat("steel"), false)
		_box(kit, frame, Vector3(0.083, y - 0.1, z), Vector3(0.006, 0.02, 0.03),
				ShipKit.glow(Color(0.3, 1.0, 0.45) if i != 5 else Color(1.0, 0.6, 0.2), 1.6), false)
	_box(kit, frame, Vector3(0.083, y - 0.24, 0), Vector3(0.006, 0.1, 0.4), mat("screen"), false)
	return _fitting("breaker panel", frame, Vector3(0, y - 0.36, -0.26), Vector3(0.12, y + 0.36, 0.26))


## The reactor cabinet in a back wall: a tall dark box with a slot window on its glowing core,
## pipe stubs into the wall and a hazard band. `width` along the wall.
static func reactor_cabinet(kit: ShipKit, frame: Transform3D, width: float, depth: float = 0.4, height: float = 2.2) -> Dictionary:
	_box(kit, frame, Vector3(depth * 0.5, height * 0.5, 0), Vector3(depth, height, width), mat("dark"), true)
	_box(kit, frame, Vector3(depth + 0.01, height * 0.55, 0), Vector3(0.02, height * 0.7, width - 0.12), mat("shell"), false)
	_box(kit, frame, Vector3(depth + 0.022, height * 0.55, 0), Vector3(0.006, 0.9, 0.12), mat("dark"), false)
	_box(kit, frame, Vector3(depth + 0.026, height * 0.55, 0), Vector3(0.004, 0.84, 0.06), ShipKit.glow(Color(0.3, 0.8, 1.0), 3.0), false)
	_box(kit, frame, Vector3(depth + 0.012, 0.18, 0), Vector3(0.024, 0.1, width), ShipKit.paint(Color(0.95, 0.55, 0.1), 0.2, 0.55), false)
	_box(kit, frame, Vector3(depth + 0.021, height - 0.16, 0), Vector3(0.004, 0.012, width - 0.04), mat("edge"), false)
	for k in 3:
		var y := height * 0.25 + float(k) * 0.12
		_box(kit, frame, Vector3(depth + 0.03, y, -width * 0.5 + 0.08), Vector3(0.06, 0.05, 0.05), mat("steel"), false)
	return _fitting("reactor cabinet", frame, Vector3(0, 0, -width * 0.5), Vector3(depth + 0.04, height, width * 0.5))


## A wall rack for components, `length` along the wall and `height` tall: uprights, two
## padded rails and sliding clamp jaws, a trim strip along the top.
static func wall_rack(kit: ShipKit, frame: Transform3D, length: float, height: float = 1.5, depth: float = 0.32) -> Dictionary:
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
	return _fitting("wall rack", frame, Vector3(0, 0, -length * 0.5), Vector3(depth + 0.06, height, length * 0.5))


## A catch net slung under a ceiling at height `y`, over the rectangle `rect` (x, z, ship
## space): a frame of straps and a diamond mesh between them. Looks only.
static func hold_net(kit: ShipKit, y: float, rect: Rect2) -> Dictionary:
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
	return {"name": "hold net", "box": AABB(Vector3(x0, y - 0.02, z0), Vector3(rect.size.x, 0.24, rect.size.y))}


## A ceiling lamp at `at` (the lens's middle, ship space) `length` long along `along` (X or
## Z): a housing, a lens of `lens` ("warm" or "cold"), lit edges, and its light.
static func lamp(kit: ShipKit, at: Vector3, length: float, along: Vector3, lens: String, energy: float, reach: float,
		shadows: bool = false) -> OmniLight3D:
	var b := Basis() if absf(along.x) > 0.5 else Basis(Vector3.UP, PI * 0.5)
	var f := Transform3D(b, at)
	_box(kit, f, Vector3(0, 0.04, 0), Vector3(length + 0.08, 0.06, 0.22), mat("dark"), false)
	_box(kit, f, Vector3(0, 0.0, 0), Vector3(length, 0.025, 0.12), mat(lens), false)
	for side: float in [-1.0, 1.0]:
		_box(kit, f, Vector3(0, 0.012, side * 0.105), Vector3(length + 0.06, 0.008, 0.008), mat("edge"), false)
	return kit.light(at + Vector3(0, -0.25, 0), Color(1.0, 0.84, 0.66) if lens == "warm" else Color(0.92, 0.96, 1.0),
			energy, reach, shadows)


## A name board: a dark plate with the name in lit letters and a trim band under it.
## `frame` sits on the surface at the board's middle, X out of it, Y up.
static func name_board(kit: ShipKit, frame: Transform3D, text: String, width: float, height: float = 0.32) -> Dictionary:
	_box(kit, frame, Vector3(0.015, 0, 0), Vector3(0.03, height, width), mat("dark"), false)
	_box(kit, frame, Vector3(0.02, -height * 0.5 - 0.03, 0), Vector3(0.02, 0.04, width), mat("trim"), false)
	var label := Label3D.new()
	label.font = ShipKit.mono_font()
	label.font_size = 64
	label.pixel_size = height * 0.7 / 64.0
	label.modulate = EDGE * 1.4
	label.outline_size = 0
	label.text = text
	label.transform = frame * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.032, 0, 0))
	kit.body.add_child(label)
	return _fitting("name board", frame, Vector3(0, -height * 0.5 - 0.05, -width * 0.5), Vector3(0.04, height * 0.5, width * 0.5))


# --- Helpers -------------------------------------------------------------------------------

static func _box(kit: ShipKit, frame: Transform3D, at: Vector3, size: Vector3, m: Material, solid: bool, tag: String = "") -> void:
	kit.add(PartShapes.box(size), frame * Transform3D(Basis(), at), m, tag, null, solid)


## A fitting's record: its name and its bounds in ship space (the frame-space box lo..hi).
static func _fitting(fitting_name: String, frame: Transform3D, lo: Vector3, hi: Vector3) -> Dictionary:
	return {"name": fitting_name, "box": frame * AABB(lo, hi - lo)}
