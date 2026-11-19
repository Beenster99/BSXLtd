extends RefCounted
## Delivery ships in their freight lines' own designs (19 Nov: "improve the artwork on the
## delivery ships from different companies ... small, medium and large delivery ships", from
## beenster's construction-freighter sheets): a command module at the bow with its canopy,
## sensor mast and docking collar, open cargo frames in the line's colour holding the loads,
## an engine module of propellant tanks, radiators and a cluster of bells. Three sizes: the
## small express courier (two loads), the medium hauler (six) and the large bulk freighter (her
## side door, in YardFreighterLook's frame). Each line builds them its own way (STYLES): the
## section of its hulls and frames, its nose, bracing, tanks and engines. Built in code with
## YardToolMesh, once per line and size (the livery is the material).
##
## Courier and hauler space: bow (-X) to the station, the loads' deck at y = DECK_Y, each load
## across the ship (its long side along z) in one row down the frames; the frames' lids open
## upward so bots draw the loads straight up. Freighter space: YardFreighterLook's (her door in
## the -X face, her bow to -Z, her hold floor's top at y = 0).

const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")
const FreighterLook := preload("res://modules/yard/internal/yard_freighter_look.gd")

const SMALL := "small"
const MEDIUM := "medium"
const LARGE := "large"
const SIZES := [SMALL, MEDIUM, LARGE]

## The loads' deck (ship space, m) and the spacing of loads down the frames (m).
const DECK_Y := -2.8
const PITCH := 3.1
## Loads a courier and a hauler carry.
const CAPACITY := {"small": 2, "medium": 6}

## Each line's design language. section: its modules' cross-section ("chamfer", "box",
## "round", "hex"), ch: how deep a chamfer cuts (of the smaller half size); frame: its cargo
## frames' shape; taper: how much the nose narrows (1 none); brace: the frames' side bracing
## ("x", "k", "v", "straps"); engines: the bells' layout; tanks: "sphere" or "drum";
## canopy: its bridge's height (1 a cockpit, 2 a raised bridge); mark: the badge's letter;
## models: what the line calls its courier, hauler and freighter.
const STYLES := {
	"torvale": {"section": "chamfer", "ch": 0.3, "frame": "chamfer", "taper": 0.72, "brace": "x",
			"engines": "tri", "tanks": "sphere", "canopy": 1.0, "mark": "T", "models": ["TF-100", "TF-300", "TF-1000"]},
	"halden": {"section": "round", "ch": 0.42, "frame": "round", "taper": 0.5, "brace": "straps",
			"engines": "twin", "tanks": "drum", "canopy": 1.0, "mark": "H", "models": ["SKIFF H2", "DRAY H6", "BULKER H40"]},
	"orbis": {"section": "hex", "ch": 0.36, "frame": "hex", "taper": 0.32, "brace": "v",
			"engines": "lead", "tanks": "drum", "canopy": 0.8, "mark": "O", "models": ["DART", "RELAY", "CONTINENT"]},
	"vantor": {"section": "box", "ch": 0.1, "frame": "box", "taper": 0.9, "brace": "k",
			"engines": "quad", "tanks": "sphere", "canopy": 1.2, "mark": "V", "models": ["V-1 RUNNER", "V-5 MULE", "V-30 OX"]},
	"meridian": {"section": "chamfer", "ch": 0.22, "frame": "chamfer", "taper": 0.62, "brace": "x",
			"engines": "row", "tanks": "drum", "canopy": 2.0, "mark": "M", "models": ["MS PACKET", "MS TENDER", "MS CARAVEL"]},
}

## The courier's and the hauler's measures (ship space, m): the docking collar's tip, the
## nose (tip to shoulder), the command module's body, its half beam and height and middle,
## the cargo frames (x of each), their half beam, height and middle, the engine module,
## its half beam and height, the bells' size, the canopy.
const SPEC := {
	"small": {"collar": -12.0, "nose": [-11.2, -7.6], "body": [-7.6, -3.2], "w": 3.0, "h": 2.4, "cy": -0.7,
			"frames": [-1.55, 1.55, 4.65], "fw": 3.4, "fh": 2.25, "fcy": -1.05, "eng": [5.2, 8.6], "ew": 2.5,
			"eh": 2.2, "r": 1.05, "canopy": [-10.0, -6.6], "bar": 0.34},
	"medium": {"collar": -16.8, "nose": [-15.6, -10.8], "body": [-10.8, -6.2], "w": 3.9, "h": 3.0, "cy": -0.5,
			"frames": [-5.15, 1.05, 7.25, 13.45], "fw": 3.75, "fh": 2.55, "fcy": -0.95, "eng": [14.4, 19.8],
			"ew": 3.1, "eh": 2.7, "r": 1.2, "canopy": [-14.4, -10.0], "bar": 0.42},
}

static var _meshes: Dictionary = {}


## A brand's style (YardBotLook.BRANDS ids; an unknown line builds like Torvale).
static func style(brand: Dictionary) -> Dictionary:
	return STYLES.get(String(brand.id), STYLES.torvale)


## The size of delivery that brings `loads` loads: a courier for one or two, else a hauler
## (the freighter is called for big orders by the traffic itself).
static func size_for(loads: int) -> String:
	return SMALL if loads <= int(CAPACITY.small) else MEDIUM


## Where load `k` stands on a courier's or hauler's deck (ship space).
static func hold_spot(size: String, k: int) -> Vector3:
	var first := 0.0 if size == SMALL else -3.6
	return Vector3(first + float(k) * PITCH, DECK_Y, 0.0)


## How high over the ship's origin bots hover to draw a load up out of its frame: over the
## command module, so they carry it to goods in clear of her canopy (ship space, m).
static func clear_y(size: String) -> float:
	return 3.4 if size == SMALL else 5.0


## Where a delivery's own bot `k` rides (ship space): on the command module's back.
static func crew_park(size: String, k: int) -> Vector3:
	var p: Dictionary = SPEC[size]
	var body: Array = p.body
	return Vector3(lerpf(float(body[0]), float(body[1]), 0.35 + 0.4 * float(k % 2)), float(p.cy) + float(p.h) + 0.55, -1.2 + 2.4 * float(k % 2))


## Where a delivery's own bot waits while others work its frames (ship space): over them.
static func wait_spot(size: String, k: int) -> Vector3:
	var p: Dictionary = SPEC[size]
	var frames: Array = p.frames
	return Vector3(float(frames[frames.size() - 1]) + 1.0, float(p.fcy) + float(p.fh) + 3.5 + float(k % 2) * 1.5, -2.0 + 4.0 * float(k % 2))


## A whole delivery ship in `brand`'s livery. Courier and hauler: "Hull" and the lids on
## hinges ("Lid<bay><L|R>", opened by set_open). Freighter: "Hull" and her door's leaves
## "DoorTop" and "DoorBottom" (opened by the traffic). Her line's name and badge on her sides.
static func make(brand: Dictionary, size: String) -> Node3D:
	var s := style(brand)
	var ms := meshes(String(brand.id), size)
	var livery := BotLook.livery(brand)
	var n := Node3D.new()
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = ms.hull
	hull.material_override = livery
	n.add_child(hull)
	var model: String = (s.models as Array)[SIZES.find(size)]
	if size == LARGE:
		for leaf: String in ["door_top", "door_bottom"]:
			var door := Node3D.new()
			door.name = "DoorTop" if leaf == "door_top" else "DoorBottom"
			n.add_child(door)
			var dm := MeshInstance3D.new()
			dm.mesh = ms[leaf]
			dm.material_override = livery
			door.add_child(dm)
		for lz: float in [-20.0, 0.0, 20.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(-2.0, 11.0, lz)
			light.omni_range = 22.0
			light.light_energy = 1.4
			light.light_color = Color(1.0, 0.94, 0.84)
			n.add_child(light)
		var hx := FreighterLook.HALF.x
		_badge(n, brand, s, model, Vector3(-hx - 0.36, 17.6, -4.0), -PI * 0.5, 2.2)
		_badge(n, brand, s, model, Vector3(-_half_width(String(s.section), hx * 0.92, 17.0 * 0.82, -1.0, float(s.ch)) - 0.36, 7.5, -42.0), -PI * 0.5, 1.0)
		_badge(n, brand, s, model, Vector3(_half_width(String(s.section), hx * 0.92, 17.0 * 0.82, -1.0, float(s.ch)) + 0.36, 7.5, -42.0), PI * 0.5, 1.0)
	else:
		var p: Dictionary = SPEC[size]
		var frames: Array = p.frames
		var lids: Array = []
		var top := _lid_line(s, p)
		for i in frames.size() - 1:
			for side: float in [-1.0, 1.0]:
				var hinge := Node3D.new()
				hinge.name = "Lid%d%s" % [i, "R" if side > 0.0 else "L"]
				hinge.position = Vector3((float(frames[i]) + float(frames[i + 1])) * 0.5, top.x, side * top.y)
				hinge.set_meta("side", side)
				n.add_child(hinge)
				var lm := MeshInstance3D.new()
				lm.mesh = ms["lid_r" if side > 0.0 else "lid_l"]
				lm.material_override = livery
				hinge.add_child(lm)
				lids.append(hinge)
		n.set_meta("lids", lids)
		var light := OmniLight3D.new()
		light.position = Vector3((float(frames[0]) + float(frames[frames.size() - 1])) * 0.5, float(p.fcy) + float(p.fh) - 0.6, 0)
		light.omni_range = 9.0 if size == SMALL else 14.0
		light.light_energy = 1.1
		light.light_color = Color(1.0, 0.92, 0.8)
		n.add_child(light)
		var body: Array = p.body
		var mid := (float(body[0]) + float(body[1])) * 0.5
		var scale := 0.55 if size == SMALL else 0.75
		for side: float in [-1.0, 1.0]:
			_badge(n, brand, s, model, Vector3(mid, float(p.cy) + 0.15, side * (_half_width(String(s.section), float(p.w), float(p.h), 0.15, float(s.ch)) + 0.1)), 0.0 if side > 0.0 else PI, scale)
	n.set_meta("brand", brand.id)
	n.set_meta("size", size)
	return n


## Opens a courier's or hauler's lids, `t` 0 (shut over the loads) to 1 (stood up).
static func set_open(node: Node3D, t: float) -> void:
	for hinge: Node3D in node.get_meta("lids", []):
		hinge.rotation.x = float(hinge.get_meta("side")) * clampf(t, 0.0, 1.0) * 1.95


## How far open a courier's or hauler's lids are (0..1).
static func open_of(node: Node3D) -> float:
	var lids: Array = node.get_meta("lids", [])
	if lids.is_empty():
		return 0.0
	return absf((lids[0] as Node3D).rotation.x) / 1.95


## The line's badge, name and model on a flat board at `at`, facing out by `turn` (rad about y).
static func _badge(n: Node3D, brand: Dictionary, s: Dictionary, model: String, at: Vector3, turn: float, scale: float) -> void:
	var b := Basis(Vector3.UP, turn)
	# The name in the trim colour, or the accent's where the trim would not show on the plates.
	var ink: Color = brand.trim
	if absf((brand.trim as Color).get_luminance() - (brand.plates as Color).get_luminance()) < 0.3:
		ink = brand.accent
	var mark := Label3D.new()
	mark.name = "Mark"
	mark.text = String(s.mark)
	mark.font_size = 160
	mark.pixel_size = 0.012 * scale
	mark.modulate = brand.accent
	mark.outline_size = 0
	mark.double_sided = false
	mark.position = at + b * Vector3(-1.7 * scale, 0, 0)
	mark.rotation.y = turn
	n.add_child(mark)
	var line := Label3D.new()
	line.name = "Line"
	line.text = String(brand.name)
	line.font_size = 96
	line.pixel_size = 0.0075 * scale
	line.modulate = ink
	line.outline_size = 0
	line.double_sided = false
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.position = at + b * Vector3(-0.9 * scale, 0.28 * scale, 0)
	line.rotation.y = turn
	n.add_child(line)
	var mod := line.duplicate() as Label3D
	mod.name = "Model"
	mod.text = model
	mod.font_size = 72
	mod.position = at + b * Vector3(-0.9 * scale, -0.42 * scale, 0)
	n.add_child(mod)


## The meshes of a line's `size`, built once: "hull"; "lid_r", "lid_l" (courier, hauler);
## "door_top", "door_bottom" (freighter).
static func meshes(brand_id: String, size: String) -> Dictionary:
	var key := brand_id + ":" + size
	if not _meshes.has(key):
		var s: Dictionary = STYLES.get(brand_id, STYLES.torvale)
		var m := YardToolMesh.new()
		if size == LARGE:
			_freighter(m, s)
		else:
			_small_ship(m, s, SPEC[size], size)
		_meshes[key] = m.meshes()
	return _meshes[key]


# --- Shapes ---------------------------------------------------------------------------------

## A cross-section's corners (u across, v up), going round.
static func _sec(kind: String, w: float, h: float, ch: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	match kind:
		"round":
			for i in 20:
				var a := TAU * (float(i) + 0.5) / 20.0
				out.append(Vector2(cos(a) * w, sin(a) * h))
		"hex":
			for p: Vector2 in [Vector2(1, 0), Vector2(0.55, 1), Vector2(-0.55, 1), Vector2(-1, 0), Vector2(-0.55, -1), Vector2(0.55, -1)]:
				out.append(Vector2(p.x * w, p.y * h))
		_:
			var c := ch * minf(w, h)
			for p: Vector2 in [Vector2(w, -h + c), Vector2(w, h - c), Vector2(w - c, h), Vector2(-w + c, h),
					Vector2(-w, h - c), Vector2(-w, -h + c), Vector2(-w + c, -h), Vector2(w - c, -h)]:
				out.append(p)
	return out


## A section's half width at height `y` over its middle.
static func _half_width(kind: String, w: float, h: float, y: float, ch: float) -> float:
	var t := clampf(absf(y) / h, 0.0, 1.0)
	match kind:
		"round":
			return w * sqrt(1.0 - t * t)
		"hex":
			return w * (1.0 - 0.45 * t)
		_:
			var c := ch * minf(w, h)
			var over := absf(y) - (h - c)
			return w - maxf(over, 0.0)


## A quad (or triangle when two corners meet), facing `out`.
static func _face(m: YardToolMesh, k: String, stock: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	var n := (b - a).cross(c - a) + (c - a).cross(d - a)
	if n.dot(out) < 0.0:
		m._tri(k, stock, a, c, b)
		m._tri(k, stock, a, d, c)
	else:
		m._tri(k, stock, a, b, c)
		m._tri(k, stock, a, c, d)


## A hull lofted from section `sa` at `a` to `sb` at `b` (both round the line a-b, u across,
## up up), flat faced, capped where asked; `skip` leaves those faces out (a door's side).
static func _prism(m: YardToolMesh, k: String, stock: String, a: Vector3, b: Vector3, sa: PackedVector2Array, sb: PackedVector2Array, u: Vector3, cap_a := true, cap_b := true, skip: Array = []) -> void:
	var along := (b - a).normalized()
	var n := sa.size()
	var pa := func(i: int) -> Vector3: return a + u * sa[i].x + Vector3.UP * sa[i].y
	var pb := func(i: int) -> Vector3: return b + u * sb[i].x + Vector3.UP * sb[i].y
	var mid := (a + b) * 0.5
	for i in n:
		if skip.has(i):
			continue
		var j := (i + 1) % n
		var p0: Vector3 = pa.call(i)
		var p1: Vector3 = pa.call(j)
		var q1: Vector3 = pb.call(j)
		var q0: Vector3 = pb.call(i)
		var o := (p0 + p1 + q0 + q1) * 0.25 - mid
		o -= along * o.dot(along)
		_face(m, k, stock, p0, p1, q1, q0, o)
	for end in 2:
		if (end == 0 and not cap_a) or (end == 1 and not cap_b):
			continue
		var c := a if end == 0 else b
		var pts: Callable = pa if end == 0 else pb
		var sec := sa if end == 0 else sb
		var centre := Vector2.ZERO
		for v in sec:
			centre += v
		var cc := c + u * (centre.x / n) + Vector3.UP * (centre.y / n)
		for i in n:
			var p0: Vector3 = pts.call(i)
			var p1: Vector3 = pts.call((i + 1) % n)
			_face(m, k, stock, cc, p0, p1, p1, -along if end == 0 else along)


## A frame round section `sec` at `at` (u across, up up): a bar on each side of it, out by
## its thickness, `depth` along `along`; `skip` leaves sides out.
static func _loop(m: YardToolMesh, k: String, stock: String, at: Vector3, along: Vector3, u: Vector3, sec: PackedVector2Array, bar: float, depth: float, skip: Array = []) -> void:
	var n := sec.size()
	for i in n:
		if skip.has(i):
			continue
		var p0 := at + u * sec[i].x + Vector3.UP * sec[i].y
		var p1 := at + u * sec[(i + 1) % n].x + Vector3.UP * sec[(i + 1) % n].y
		var dir := p1 - p0
		var len := dir.length()
		if len < 0.01:
			continue
		dir /= len
		var o := (p0 + p1) * 0.5 - at
		o -= along * o.dot(along)
		o = (o - dir * dir.dot(o)).normalized()
		m.box(k, stock, (p0 + p1) * 0.5 + o * bar * 0.5, Vector3(len + bar * 0.75, bar, depth), minf(bar * 0.18, 0.12), Basis(dir, o, dir.cross(o)))


## A square bar from `a` to `b`, `t` thick (`t2` the other way).
static func _beam(m: YardToolMesh, k: String, stock: String, a: Vector3, b: Vector3, t: float, t2 := -1.0) -> void:
	var dir := b - a
	var len := dir.length()
	if len < 0.001:
		return
	var x := dir / len
	var y := Vector3.UP if absf(x.y) < 0.95 else Vector3.RIGHT
	var z := x.cross(y).normalized()
	y = z.cross(x)
	m.box(k, stock, (a + b) * 0.5, Vector3(len, t, t2 if t2 > 0.0 else t), minf(t * 0.2, 0.06), Basis(x, y, z))


## A tube's sides only (a bell), facing out or in.
static func _tube(m: YardToolMesh, k: String, stock: String, a: Vector3, b: Vector3, r: float, r2: float, sides: int, inward := false) -> void:
	var along := (b - a).normalized()
	var x := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := along.cross(x).normalized()
	var slope := (r - r2) / maxf(a.distance_to(b), 0.0001)
	var f := -1.0 if inward else 1.0
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := x * cos(a0) + y * sin(a0)
		var d1 := x * cos(a1) + y * sin(a1)
		var n0 := (d0 + along * slope).normalized() * f
		var n1 := (d1 + along * slope).normalized() * f
		if inward:
			m._tri(k, stock, a + d0 * r, b + d1 * r2, a + d1 * r, n0, n1, n1)
			m._tri(k, stock, a + d0 * r, b + d0 * r2, b + d1 * r2, n0, n0, n1)
		else:
			m._tri(k, stock, a + d0 * r, a + d1 * r, b + d1 * r2, n0, n1, n1)
			m._tri(k, stock, a + d0 * r, b + d1 * r2, b + d0 * r2, n0, n1, n0)


## A ball (a propellant tank), its poles along `axis`.
static func _sphere(m: YardToolMesh, k: String, stock: String, c: Vector3, r: float, axis := Vector3.UP, bands := 12) -> void:
	var x := axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.BACK).normalized()
	var y := axis.cross(x)
	var sides := 24
	var pt := func(j: int, i: int) -> Vector3:
		var t := PI * float(j) / bands
		var a := TAU * float(i) / sides
		return -axis * cos(t) + (x * cos(a) + y * sin(a)) * sin(t)
	for j in bands:
		for i in sides:
			var d00: Vector3 = pt.call(j, i)
			var d01: Vector3 = pt.call(j, i + 1)
			var d10: Vector3 = pt.call(j + 1, i)
			var d11: Vector3 = pt.call(j + 1, i + 1)
			var n := ((d00 + d01 + d10 + d11) * 0.25).normalized()
			if (d01 - d00).cross(d11 - d00).dot(n) >= 0.0:
				m._tri(k, stock, c + d00 * r, c + d01 * r, c + d11 * r, d00, d01, d11)
				m._tri(k, stock, c + d00 * r, c + d11 * r, c + d10 * r, d00, d11, d10)
			else:
				m._tri(k, stock, c + d00 * r, c + d11 * r, c + d01 * r, d00, d11, d01)
				m._tri(k, stock, c + d00 * r, c + d10 * r, c + d11 * r, d00, d10, d11)


## An engine: its housing in the line's band, gimbal rams, the bell (dark outside, its
## throat lit), pointing `dir` from `at`, `r` its housing's radius.
static func _bell(m: YardToolMesh, k: String, at: Vector3, dir: Vector3, r: float) -> void:
	m.rod(k, "gunmetal", at - dir * r * 0.2, at + dir * r * 0.75, r * 0.82, r * 0.72, 28)
	m.ring(k, "accent", at + dir * r * 0.25, r * 0.83, r * 0.09, dir, 28, 6)
	m.ring(k, "dark", at + dir * r * 0.55, r * 0.77, r * 0.04, dir, 28, 5)
	m.rod(k, "dark", at + dir * r * 0.75, at + dir * r * 1.1, r * 0.5, r * 0.44, 24)
	_tube(m, k, "dark", at + dir * r * 1.05, at + dir * r * 2.7, r * 0.46, r * 1.02, 32)
	_tube(m, k, "gunmetal", at + dir * r * 1.07, at + dir * r * 2.68, r * 0.42, r * 0.97, 32, true)
	m.ring(k, "steel", at + dir * r * 2.7, r * 1.0, r * 0.045, dir, 32, 5)
	m.ring(k, "accent", at + dir * r * 1.9, r * 0.79, r * 0.05, dir, 32, 5)
	m.rod(k, "cyan", at + dir * r * 1.08, at + dir * r * 1.12, r * 0.42, r * 0.42, 24)
	var x := dir.cross(Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := dir.cross(x)
	for d: Vector3 in [x, -x, y, -y]:
		m.rod(k, "steel", at + dir * r * 0.7 + d * r * 0.62, at + dir * r * 1.6 + d * r * 0.66, r * 0.06, -1.0, 8)


## The bells' places across the stern (u across, up), for `r` sized bells.
static func _engine_layout(kind: String, r: float) -> Array:
	match kind:
		"twin":
			return [[Vector2(-1.25, 0), 1.2], [Vector2(1.25, 0), 1.2]]
		"quad":
			return [[Vector2(-0.95, -0.9), 0.9], [Vector2(0.95, -0.9), 0.9], [Vector2(-0.95, 0.9), 0.9], [Vector2(0.95, 0.9), 0.9]]
		"row":
			return [[Vector2(-2.1, 0), 0.75], [Vector2(-0.7, 0), 0.75], [Vector2(0.7, 0), 0.75], [Vector2(2.1, 0), 0.75]]
		"lead":
			return [[Vector2(0, 0.1), 1.35], [Vector2(-1.9, -0.5), 0.65], [Vector2(1.9, -0.5), 0.65]]
	return [[Vector2(0, 1.0), 0.95], [Vector2(-1.1, -0.65), 0.95], [Vector2(1.1, -0.65), 0.95]]


## A thruster quad: a block and nozzles out three ways.
static func _rcs(m: YardToolMesh, k: String, at: Vector3, outs: Array, s: float) -> void:
	m.box(k, "gunmetal", at, Vector3(0.6, 0.6, 0.6) * s, 0.06 * s)
	m.box(k, "accent", at + Vector3(0, 0.31 * s, 0), Vector3(0.62, 0.06, 0.62) * s, 0.02)
	for d: Vector3 in outs:
		m.rod(k, "dark", at + d * 0.28 * s, at + d * 0.55 * s, 0.09 * s, 0.15 * s, 12)


# --- The courier and the hauler ---------------------------------------------------------------

## Where the lids' hinges run: (y, z) of the hinge line over each side.
static func _lid_line(s: Dictionary, p: Dictionary) -> Vector2:
	var fh: float = p.fh
	var y := fh * 0.86
	return Vector2(float(p.fcy) + y, _half_width(String(s.frame), float(p.fw), fh, y, float(s.ch)) - 0.12)


static func _small_ship(m: YardToolMesh, s: Dictionary, p: Dictionary, size: String) -> void:
	var k := "hull"
	var small := size == SMALL
	var sk: String = s.section
	var ch: float = s.ch
	var w: float = p.w
	var h: float = p.h
	var cy: float = p.cy
	var nose: Array = p.nose
	var body: Array = p.body
	var taper: float = s.taper
	var bar: float = p.bar
	var sb := _sec(sk, w, h, ch)
	var sn := _sec(sk, w * taper, h * lerpf(1.0, taper, 0.6), ch)
	var n0 := float(nose[0])
	var n1 := float(nose[1])
	var b1 := float(body[1])
	var u := Vector3.BACK
	var nose_cy := cy - h * (1.0 - lerpf(1.0, taper, 0.6)) * 0.35
	# The command module: a tapered nose, the body, the line's bands round both.
	_prism(m, k, "plates", Vector3(n0, nose_cy, 0), Vector3(n1, cy, 0), sn, sb, u, true, false)
	_prism(m, k, "plates", Vector3(n1, cy, 0), Vector3(b1, cy, 0), sb, sb, u, false, true)
	for x: float in [n1, b1 - 0.4]:
		_loop(m, k, "accent", Vector3(x, cy, 0), Vector3.RIGHT, u, _sec(sk, w, h, ch), 0.16, 0.5)
	_loop(m, k, "trim", Vector3(n0 + 0.25, nose_cy, 0), Vector3.RIGHT, u, _sec(sk, w * taper * 0.98, h * lerpf(1.0, taper, 0.6) * 0.98, ch), 0.12, 0.4)
	# Panel seams down the body and an armour plate over its lower sides.
	for x: float in [lerpf(n1, b1, 0.33), lerpf(n1, b1, 0.66)]:
		_loop(m, k, "dark", Vector3(x, cy, 0), Vector3.RIGHT, u, _sec(sk, w, h, ch), 0.02, 0.06)
	# The docking collar and its lamps, headlamps either side of it.
	var cr := 0.75 if small else 1.05
	var collar: float = p.collar
	m.rod(k, "gunmetal", Vector3(n0 + 0.1, nose_cy, 0), Vector3(collar + 0.3, nose_cy, 0), cr, cr * 0.95, 24)
	m.ring(k, "accent", Vector3(collar + 0.3, nose_cy, 0), cr * 1.02, 0.08, Vector3.RIGHT, 24, 6)
	m.rod(k, "dark", Vector3(collar + 0.3, nose_cy, 0), Vector3(collar, nose_cy, 0), cr * 0.85, cr * 0.8, 24)
	m.rod(k, "cyan", Vector3(collar + 0.01, nose_cy, 0), Vector3(collar - 0.02, nose_cy, 0), cr * 0.5, cr * 0.5, 20)
	for a in 4:
		var d := Vector3(0, sin(TAU * a / 4.0 + PI * 0.25), cos(TAU * a / 4.0 + PI * 0.25))
		m.box(k, "lamp", Vector3(collar + 0.25, nose_cy, 0) + d * cr * 0.95, Vector3(0.12, 0.14, 0.14), 0.02)
	var front_w := _half_width(sk, w * taper, h * lerpf(1.0, taper, 0.6), -h * 0.3, ch)
	for side: float in [-1.0, 1.0]:
		m.box(k, "dark", Vector3(n0 - 0.02, nose_cy - h * 0.25, side * front_w * 0.62), Vector3(0.12, 0.35, 0.6), 0.04)
		m.box(k, "lamp", Vector3(n0 - 0.08, nose_cy - h * 0.25, side * front_w * 0.62), Vector3(0.04, 0.25, 0.5), 0.02)
	# The canopy: a raised bridge, its front glazed, side windows, a sensor blister.
	var cn: Array = p.canopy
	var lift: float = s.canopy
	var cw := w * (0.42 if sk != "hex" else 0.36)
	var chh := (0.5 if small else 0.62) * lift
	var top_at := func(x: float) -> float:
		var t := clampf((x - n0) / (n1 - n0), 0.0, 1.0)
		var yc := lerpf(nose_cy, cy, t)
		var hh := lerpf(h * lerpf(1.0, taper, 0.6), h, t)
		return yc + hh * (0.9 if sk == "round" else 0.97)
	var c0 := float(cn[0])
	var c1 := float(cn[1])
	var cg := lerpf(c0, c1, 0.32)
	var csf := _sec("chamfer", cw * 0.8, chh * 0.7, 0.45)
	var csb := _sec("chamfer", cw, chh, 0.45)
	var y0: float = top_at.call(c0) + chh * 0.55
	var yg: float = top_at.call(cg) + chh * 0.8
	var y1: float = top_at.call(c1) + chh * 0.85
	_prism(m, k, "glass", Vector3(c0, y0, 0), Vector3(cg, yg, 0), csf, _sec("chamfer", cw * 0.93, chh * 0.93, 0.45), u, true, false)
	_prism(m, k, "plates", Vector3(cg, yg, 0), Vector3(c1, y1, 0), _sec("chamfer", cw * 0.93, chh * 0.93, 0.45), csb, u, false, true)
	_loop(m, k, "trim", Vector3(cg, yg, 0), Vector3.RIGHT, u, _sec("chamfer", cw * 0.93, chh * 0.93, 0.45), 0.08, 0.16)
	_loop(m, k, "accent", Vector3(c1 - 0.15, y1, 0), Vector3.RIGHT, u, csb, 0.1, 0.25)
	for side: float in [-1.0, 1.0]:
		var wx := lerpf(cg, c1, 0.45)
		m.box(k, "glass", Vector3(wx, lerpf(yg, y1, 0.45) + chh * 0.15, side * (cw + 0.01)), Vector3((c1 - cg) * 0.55, chh * 0.42, 0.05), 0.03)
		for f in 3:
			m.box(k, "trim", Vector3(wx + ((c1 - cg) * 0.55) * (float(f) / 2.0 - 0.5), lerpf(yg, y1, 0.45) + chh * 0.15, side * (cw + 0.03)), Vector3(0.06, chh * 0.46, 0.04), 0.01)
	# The sensor mast and dish on the body's back, a beacon, an antenna.
	var mx := lerpf(n1, b1, 0.7)
	var top_y := cy + h * (0.88 if sk == "round" else 0.97)
	m.box(k, "gunmetal", Vector3(mx, top_y + 0.15, -w * 0.3), Vector3(1.0, 0.35, 0.8), 0.06)
	m.rod(k, "gunmetal", Vector3(mx, top_y + 0.3, -w * 0.3), Vector3(mx, top_y + 0.9, -w * 0.3), 0.08, -1.0, 10)
	m.rod(k, "plates", Vector3(mx, top_y + 0.9, -w * 0.3), Vector3(mx - 0.15, top_y + 1.1, -w * 0.3), 0.06, 0.55, 28)
	m.ring(k, "trim", Vector3(mx - 0.15, top_y + 1.1, -w * 0.3), 0.55, 0.03, Vector3(-0.6, 0.8, 0).normalized(), 28, 5)
	m.rod(k, "dark", Vector3(mx + 0.8, top_y, w * 0.35), Vector3(mx + 0.8, top_y + 1.8, w * 0.35), 0.03, 0.015, 8)
	m.rod(k, "red_lamp", Vector3(mx + 0.8, top_y + 1.8, w * 0.35), Vector3(mx + 0.8, top_y + 1.92, w * 0.35), 0.06, -1.0, 10)
	# Body sides: the name board, vents behind it, a hatch, an RCS quad at each corner.
	for side: float in [-1.0, 1.0]:
		var zw := _half_width(sk, w, h, 0.15, ch)
		var board := Vector3((n1 + b1) * 0.5, cy + 0.15, side * (zw - 0.2))
		m.box(k, "plates", board, Vector3((b1 - n1) * 0.86, h * 0.62, 0.52), 0.05)
		m.box(k, "accent", board + Vector3(-(b1 - n1) * 0.33, 0, side * 0.27), Vector3(h * 0.5, h * 0.5, 0.05), 0.04)
		var zl := _half_width(sk, w, h, -h * 0.55, ch)
		for v in 6:
			m.box(k, "dark", Vector3(lerpf(n1, b1, 0.55) + v * 0.22, cy - h * 0.55, side * (zl + 0.0)), Vector3(0.1, h * 0.18, 0.08), 0.01)
		for cx: float in [n1 + 0.5, b1 - 0.6]:
			var ry := cy + h * 0.55
			_rcs(m, k, Vector3(cx, ry, side * (_half_width(sk, w, h, h * 0.55, ch) + 0.15)), [Vector3.UP, Vector3(0, 0, side), Vector3(signf(cx - (n1 + b1) * 0.5), 0, 0)], 0.8 if small else 1.0)
	# The neck to the cargo frames.
	var frames: Array = p.frames
	var f0 := float(frames[0])
	var fl := float(frames[frames.size() - 1])
	var fw: float = p.fw
	var fh: float = p.fh
	var fcy: float = p.fcy
	var fk: String = s.frame
	var sneck := _sec(sk, w * 0.7, h * 0.72, ch)
	_prism(m, k, "gunmetal", Vector3(b1 - 0.2, cy - 0.2, 0), Vector3(f0 - bar * 0.5, cy - 0.2, 0), sneck, sneck, u, false, false)
	for c in 4:
		var a := TAU * (float(c) + 0.5) / 4.0
		var off := Vector3(0, sin(a) * h * 0.5, cos(a) * w * 0.5)
		m.rod(k, "copper" if c % 2 == 0 else "steel", Vector3(b1 - 0.3, cy - 0.2, 0) + off, Vector3(f0, cy - 0.2, 0) + off, 0.07, -1.0, 8)
	# The deck the loads sit on, the keel under it with its pipe runs and running lights.
	m.box(k, "dark", Vector3((f0 + fl) * 0.5, DECK_Y - 0.2, 0), Vector3(fl - f0, 0.4, fw * 1.8), 0.05)
	for side: float in [-1.0, 1.0]:
		m.box(k, "accent", Vector3((f0 + fl) * 0.5, DECK_Y - 0.02, side * fw * 0.86), Vector3(fl - f0 - 0.2, 0.04, 0.16), 0.01)
		m.rod(k, "copper", Vector3(f0, DECK_Y - 0.75, side * 1.1), Vector3(fl, DECK_Y - 0.75, side * 1.1), 0.1, -1.0, 10)
		m.rod(k, "steel", Vector3(f0, DECK_Y - 1.0, side * 0.75), Vector3(fl, DECK_Y - 1.0, side * 0.75), 0.13, -1.0, 10)
	m.box(k, "gunmetal", Vector3((f0 + fl) * 0.5, DECK_Y - 1.05, 0), Vector3(fl - f0 + 1.2, 1.1, 1.3), 0.08)
	m.box(k, "accent_light", Vector3((f0 + fl) * 0.5, DECK_Y - 1.61, 0), Vector3(fl - f0 - 1.0, 0.04, 0.2), 0.01)
	# The cargo frames: a loop in the line's colour at each, rails along them, bracing.
	var fs := _sec(fk, fw, fh, ch)
	var fc := Vector3(0, fcy, 0)
	for fx: float in frames:
		_loop(m, k, "accent", fc + Vector3(fx, 0, 0), Vector3.RIGHT, u, fs, bar, bar * 1.6)
		_loop(m, k, "gunmetal", fc + Vector3(fx, 0, 0), Vector3.RIGHT, u, _sec(fk, fw - 0.06, fh - 0.06, ch), 0.1, bar * 2.2)
		_loop(m, k, "dark", fc + Vector3(fx, 0, 0), Vector3.RIGHT, u, _sec(fk, fw + bar, fh + bar, ch), 0.05, bar * 0.4)
		# Corner castings with lifting eyes where the frame's sides meet.
		var cstep := maxi(1, fs.size() / 8)
		for i in range(0, fs.size(), cstep):
			var cpt := fc + Vector3(fx, 0, 0) + u * fs[i].x + Vector3.UP * fs[i].y
			var out := (cpt - Vector3(fx, fcy, 0)).normalized()
			m.box(k, "plates", cpt + out * bar * 0.5, Vector3(bar * 2.3, bar * 1.7, bar * 1.7), bar * 0.25)
			if fs[i].y > fh * 0.5:
				m.ring(k, "steel", cpt + out * bar * 1.4, bar * 0.35, bar * 0.09, Vector3.RIGHT, 12, 5)
		# Floodlights under the frame's head, down into the bays.
		for side: float in [-1.0, 1.0]:
			var lz := side * fw * 0.45
			m.box(k, "dark", Vector3(fx, fcy + fh * 0.78, lz), Vector3(0.5, 0.25, 0.5), 0.04)
			m.box(k, "lamp", Vector3(fx, fcy + fh * 0.78 - 0.13, lz), Vector3(0.4, 0.02, 0.4), 0.01)
	var step := maxi(1, fs.size() / 8)
	for i in range(0, fs.size(), step):
		var c := fc + u * fs[i].x + Vector3.UP * fs[i].y
		_beam(m, k, "trim", c + Vector3(f0, 0, 0), c + Vector3(fl, 0, 0), 0.22)
	var by := fh * 0.6
	for i in frames.size() - 1:
		var x0 := float(frames[i]) + bar * 0.8
		var x1 := float(frames[i + 1]) - bar * 0.8
		for side: float in [-1.0, 1.0]:
			var z := side * (_half_width(fk, fw, fh, by, ch) - 0.05)
			var lo := Vector3(0, fcy - by, z)
			var hi := Vector3(0, fcy + by * 0.5, z)
			_brace(m, k, String(s.brace), x0, x1, lo, hi)
	# The engine module: tanks, radiators, an RCS quad at each corner, the bells.
	var eng: Array = p.eng
	var e0 := float(eng[0])
	var e1 := float(eng[1])
	var ew: float = p.ew
	var eh: float = p.eh
	var se := _sec(sk, ew, eh, ch)
	var ecy := cy - 0.1
	_prism(m, k, "gunmetal", Vector3(fl + bar * 0.5, ecy, 0), Vector3(e0, ecy, 0), _sec(sk, ew * 0.75, eh * 0.75, ch), _sec(sk, ew * 0.75, eh * 0.75, ch), u, false, false)
	_prism(m, k, "plates", Vector3(e0, ecy, 0), Vector3(e1, ecy, 0), se, se, u, true, true)
	_loop(m, k, "accent", Vector3(e0 + 0.2, ecy, 0), Vector3.RIGHT, u, se, 0.18, 0.5)
	_loop(m, k, "trim", Vector3(e1 - 0.2, ecy, 0), Vector3.RIGHT, u, se, 0.14, 0.4)
	_loop(m, k, "dark", Vector3((e0 + e1) * 0.5, ecy, 0), Vector3.RIGHT, u, se, 0.02, 0.06)
	var thrust := _sec(sk, ew * 0.88, eh * 0.88, ch)
	_prism(m, k, "gunmetal", Vector3(e1, ecy, 0), Vector3(e1 + 0.35, ecy, 0), thrust, thrust, u, false, true)
	var em := (e0 + e1) * 0.5
	if String(s.tanks) == "sphere":
		var tr := eh * 0.46
		for side: float in [-1.0, 1.0]:
			var tc := Vector3(em, ecy, side * (ew + tr * 0.62))
			_sphere(m, k, "plates", tc, tr)
			m.ring(k, "accent", tc, tr * 1.01, 0.06, Vector3.UP, 28, 5)
			for dy: float in [-0.5, 0.5]:
				_beam(m, k, "gunmetal", tc + Vector3(0, dy * tr, 0), Vector3(em, ecy + dy * tr, side * ew * 0.9), 0.16)
	else:
		var tr := eh * 0.3
		for side: float in [-1.0, 1.0]:
			for dy: float in [-0.48, 0.48]:
				var a := Vector3(e0 + 0.3, ecy + dy * eh * 1.05, side * (ew + tr * 0.4))
				var b := Vector3(e1 - 0.3, a.y, a.z)
				m.rod(k, "plates", a, b, tr, -1.0, 20)
				m.rod(k, "trim", a, a - Vector3(0.25, 0, 0), tr, tr * 0.6, 20)
				m.rod(k, "trim", b, b + Vector3(0.25, 0, 0), tr, tr * 0.6, 20)
				for t in [0.25, 0.75]:
					m.ring(k, "accent", a.lerp(b, float(t)), tr * 1.02, 0.05, Vector3.RIGHT, 20, 5)
	var etop := ecy + eh * (0.88 if sk == "round" else 0.97)
	for side: float in [-1.0, 1.0]:
		var rb := Basis(Vector3.RIGHT, side * 0.6)
		var rc := Vector3(em, etop + 0.2, side * ew * 0.35) + rb * Vector3(0, 0, side * 1.1)
		m.box(k, "gunmetal", rc, Vector3((e1 - e0) * 0.8, 0.12, 2.3), 0.03, rb)
		for f in int((e1 - e0) * 0.8 / 0.35):
			m.box(k, "steel", rc + rb * Vector3(-(e1 - e0) * 0.4 + 0.2 + f * 0.35, 0.1, 0), Vector3(0.05, 0.12, 2.2), 0.01, rb)
		m.rod(k, "gunmetal", Vector3(em - 1.0, etop, side * ew * 0.3), rc + rb * Vector3(-1.0, 0, -side * 1.0), 0.06, -1.0, 8)
		for cx: float in [e0 + 0.5, e1 - 0.6]:
			for vy: float in [-1.0, 1.0]:
				_rcs(m, k, Vector3(cx, ecy + vy * eh * 0.6, side * (_half_width(sk, ew, eh, eh * 0.6, ch) + 0.15)), [Vector3(0, vy, 0), Vector3(0, 0, side), Vector3(signf(cx - em), 0, 0)], 0.8 if small else 1.0)
		m.rod(k, "red_lamp" if side < 0.0 else "lamp", Vector3(e1 - 0.3, etop, side * ew * 0.6), Vector3(e1 - 0.3, etop + 0.18, side * ew * 0.6), 0.07, -1.0, 10)
	var r: float = p.r
	for e: Array in _engine_layout(String(s.engines), r):
		var o: Vector2 = e[0]
		_bell(m, k, Vector3(e1 + 0.35, ecy + o.y * r, o.x * r), Vector3.RIGHT, r * float(e[1]))
	# The lids, built for the right side (+z, closing over towards -z) and mirrored.
	var bay := float(frames[1]) - float(frames[0]) - bar * 1.6
	var line := _lid_line(s, p)
	_lid(m, "lid_r", bay, line.y, 1.0)
	_lid(m, "lid_l", bay, line.y, -1.0)


## Side bracing over a bay's side, from `lo` to `hi` (y, z) between x0 and x1.
static func _brace(m: YardToolMesh, k: String, kind: String, x0: float, x1: float, lo: Vector3, hi: Vector3) -> void:
	var a := Vector3(x0, lo.y, lo.z)
	var b := Vector3(x1, lo.y, lo.z)
	var c := Vector3(x1, hi.y, hi.z)
	var d := Vector3(x0, hi.y, hi.z)
	match kind:
		"straps":
			var n := maxi(2, int((x1 - x0) / 1.4))
			for i in n + 1:
				var x := lerpf(x0, x1, float(i) / n)
				_beam(m, k, "accent", Vector3(x, lo.y, lo.z), Vector3(x, hi.y, hi.z), 0.16, 0.1)
			_beam(m, k, "trim", (a + d) * 0.5, (b + c) * 0.5, 0.14)
		"k":
			var mid := (a + d) * 0.5
			_beam(m, k, "trim", mid, b, 0.18)
			_beam(m, k, "trim", mid, c, 0.18)
			var mid2 := (b + c) * 0.5
			_beam(m, k, "trim", mid2, a, 0.18)
			_beam(m, k, "trim", mid2, d, 0.18)
		"v":
			var top := (c + d) * 0.5
			_beam(m, k, "trim", a, top, 0.18)
			_beam(m, k, "trim", b, top, 0.18)
			_beam(m, k, "trim", a, b, 0.14)
		_:
			_beam(m, k, "trim", a, c, 0.18)
			_beam(m, k, "trim", b, d, 0.18)


## One lid of a bay: a frame in the line's colour round a grid, its hinge barrel; hinge space
## (the hinge along x at the origin), reaching `reach` across towards -side.
static func _lid(m: YardToolMesh, k: String, length: float, reach: float, side: float) -> void:
	var r := reach - 0.08
	var mid := Vector3(0, 0, -side * r * 0.5)
	m.rod(k, "steel", Vector3(-length * 0.5, 0, 0), Vector3(length * 0.5, 0, 0), 0.12, -1.0, 12)
	for x: float in [-length * 0.5 + 0.1, length * 0.5 - 0.1]:
		m.box(k, "accent", Vector3(x, 0, -side * r * 0.5), Vector3(0.2, 0.2, r), 0.04)
	m.box(k, "accent", Vector3(0, 0, -side * (r - 0.1)), Vector3(length, 0.2, 0.2), 0.04)
	var n := maxi(2, int(length / 0.9))
	for i in range(1, n):
		m.box(k, "gunmetal", Vector3(-length * 0.5 + length * float(i) / n, -0.02, -side * r * 0.5), Vector3(0.08, 0.1, r - 0.2), 0.01)
	for j in 3:
		m.box(k, "gunmetal", mid + Vector3(0, -0.02, side * (float(j) - 1.0) * r * 0.28), Vector3(length - 0.2, 0.1, 0.08), 0.01)
	m.box(k, "red_lamp", Vector3(0, 0.12, -side * (r - 0.1)), Vector3(0.3, 0.06, 0.1), 0.01)


# --- The freighter ----------------------------------------------------------------------------

## The bulk freighter in YardFreighterLook's frame: her hold and side door as before, round
## them a hull of the line's section in segments between frames in its colour, cargo racks
## and radiators along her back, a command module at the bow, an engine module aft.
static func _freighter(m: YardToolMesh, s: Dictionary) -> void:
	var k := "hull"
	var hx := FreighterLook.HALF.x
	var hz := FreighterLook.HALF.z
	var door := FreighterLook.DOOR
	var dx := FreighterLook.DOOR_X
	var top := 25.0
	var keel := -9.0
	var cy := (top + keel) * 0.5
	var hh := (top - keel) * 0.5
	var ch := clampf(float(s.ch), 0.12, 0.4) * 0.8
	var sk: String = s.section
	var u := Vector3.RIGHT
	var hull := _sec("chamfer", hx, hh, ch)
	var c := ch * minf(hx, hh)
	var near_lo := cy - hh + c
	var near_hi := cy + hh - c
	# The hull: every face but her door's side, which is built round the door.
	_prism(m, k, "plates", Vector3(0, cy, -hz), Vector3(0, cy, hz), hull, hull, u, true, true, [4])
	m.box(k, "plates", Vector3(dx + 0.3, (near_lo - 0.4) * 0.5, 0), Vector3(0.6, -0.4 - near_lo, hz * 2.0), 0.1)
	m.box(k, "plates", Vector3(dx + 0.3, (14.6 + near_hi) * 0.5, 0), Vector3(0.6, near_hi - 14.6, hz * 2.0), 0.1)
	for side: float in [-1.0, 1.0]:
		var zc := side * (door.x * 0.5 + (hz - door.x * 0.5) * 0.5)
		m.box(k, "plates", Vector3(dx + 0.3, cy, zc), Vector3(0.6, near_hi - near_lo, hz - door.x * 0.5), 0.1)
		# The hold's end walls.
		m.box(k, "gunmetal", Vector3(-1.0, 7.2, side * (door.x * 0.5 + 0.2)), Vector3(28.0, 14.4, 0.4), 0.05)
	# The hold: tread floor with lanes, a ribbed back wall, ceiling beams and lamp strips.
	m.box(k, "dark", Vector3(-1.0, -0.2, 0), Vector3(27.0, 0.4, door.x), 0.05)
	for lz in range(-27, 28, 9):
		m.box(k, "accent", Vector3(-1.0, 0.01, float(lz)), Vector3(26.0, 0.012, 0.2), 0.002)
	m.box(k, "gunmetal", Vector3(hx - 2.1, 7.0, 0), Vector3(0.2, 14.0, door.x), 0.04)
	for rz in range(-28, 29, 4):
		m.box(k, "trim", Vector3(hx - 2.3, 7.0, float(rz)), Vector3(0.3, 14.0, 0.35), 0.05)
	m.box(k, "gunmetal", Vector3(-1.0, 14.4, 0), Vector3(27.0, 0.4, door.x), 0.05)
	for bx in range(-12, 13, 6):
		m.box(k, "trim", Vector3(float(bx), 13.9, 0), Vector3(0.5, 0.7, door.x), 0.08)
		m.box(k, "lamp", Vector3(float(bx) + 2.6, 14.17, 0), Vector3(0.4, 0.06, door.x - 4.0), 0.02)
	for lz in range(-27, 28, 6):
		m.box(k, "dark", Vector3(dx - 0.1, 14.1, float(lz)), Vector3(0.6, 0.5, 1.2), 0.06)
		m.box(k, "lamp", Vector3(dx - 0.42, 14.1, float(lz)), Vector3(0.04, 0.35, 1.0), 0.02)
	m.box(k, "accent_light", Vector3(dx - 0.05, -0.15, 0), Vector3(0.3, 0.1, door.x - 0.5), 0.02)
	# The line's band over the door, hazard edges, the frames in its colour: full round her
	# ends and either side of the door, broken over the door between.
	m.box(k, "accent", Vector3(dx - 0.08, 15.6, 0), Vector3(0.2, 1.2, hz * 2.0 - 1.0), 0.05)
	m.box(k, "trim", Vector3(dx - 0.08, 14.8, 0), Vector3(0.2, 0.3, hz * 2.0 - 1.0), 0.04)
	var big := _sec("chamfer", hx, hh, ch)
	var rings := [-hz + 0.7, -(door.x * 0.5 + 0.7), -door.x / 6.0, door.x / 6.0, door.x * 0.5 + 0.7, hz - 0.7]
	for rz: float in rings:
		var open := absf(rz) < door.x * 0.5
		_loop(m, k, "accent", Vector3(0, cy, rz), Vector3.BACK, u, big, 1.2, 1.4, [4] if open else [])
		if open:
			for span: Vector2 in [Vector2(near_lo, -0.4), Vector2(14.6, near_hi)]:
				m.box(k, "accent", Vector3(dx - 0.6, (span.x + span.y) * 0.5, rz), Vector3(1.2, span.y - span.x, 1.4), 0.1)
	# Panels between the frames on her far side and back: proud plates, seams, vents, hatches.
	for i in rings.size() - 1:
		var z0: float = rings[i]
		var z1: float = rings[i + 1]
		var zm := (z0 + z1) * 0.5
		var span := z1 - z0 - 2.0
		if span < 2.0:
			continue
		if span > 10.0:
			_side_rack(m, k, hx, near_lo + 1.0, near_hi - 1.0, z0 + 1.2, z1 - 1.2, i)
		else:
			m.box(k, "plates", Vector3(hx + 0.12, cy - 3.0, zm), Vector3(0.3, hh * 1.1, span * 0.9), 0.1)
			for v in int(span / 0.8):
				m.box(k, "dark", Vector3(hx + 0.3, cy - 9.5, zm - span * 0.4 + v * 0.8), Vector3(0.1, 2.0, 0.3), 0.02)
		# Habitat windows along the near side over the door.
		for v in int(span / 1.6):
			m.box(k, "lamp", Vector3(dx - 0.04, near_hi - 1.6, z0 + 1.6 + v * 1.6), Vector3(0.06, 0.5, 0.8), 0.02)
		m.box(k, "dark", Vector3(-1.0, cy - hh - 0.05, zm), Vector3(hx * 1.2, 0.1, 0.08), 0.01)
	# Along her back: cargo racks (open frames of stock) forward, radiators aft, unless the
	# line puts a raised bridge there.
	var tower := float(s.canopy) >= 1.8
	var racks := [Vector2(-door.x * 0.5 + 0.8, -door.x / 6.0 - 0.8), Vector2(-door.x / 6.0 + 0.8, door.x / 6.0 - 0.8), Vector2(door.x / 6.0 + 0.8, door.x * 0.5 - 0.8)]
	for i in racks.size():
		var r: Vector2 = racks[i]
		if tower and i == 2:
			continue
		_rack(m, k, Vector3(0.0, top, (r.x + r.y) * 0.5), Vector3((hx - c) * 2.0 - 1.0, 6.0, r.y - r.x), i)
	if tower:
		var tz := door.x * 0.5 - 8.0
		m.box(k, "plates", Vector3(0, top + 4.5, tz), Vector3(16.0, 9.0, 11.0), 0.5)
		m.box(k, "accent", Vector3(0, top + 8.3, tz), Vector3(16.2, 0.8, 11.2), 0.2)
		m.box(k, "glass", Vector3(0, top + 6.0, tz - 5.55), Vector3(14.0, 1.8, 0.2), 0.1)
		m.box(k, "glass", Vector3(-8.05, top + 6.0, tz), Vector3(0.2, 1.8, 9.0), 0.1)
		for gx in range(-6, 7, 3):
			m.box(k, "trim", Vector3(float(gx), top + 6.0, tz - 5.65), Vector3(0.25, 2.0, 0.3), 0.05)
	for side: float in [-1.0, 1.0]:
		# Radiator wings off her far shoulder.
		if side > 0.0:
			for rz: float in [-18.0, 8.0]:
				var rb := Basis(Vector3.BACK, -0.35)
				var rc := Vector3(hx + 6.0, top - 2.0, rz)
				m.box(k, "gunmetal", rc, Vector3(11.0, 0.4, 20.0), 0.08, rb)
				for f in 18:
					m.box(k, "steel", rc + rb * Vector3(0, 0.3, -9.0 + f * 1.05), Vector3(10.6, 0.3, 0.12), 0.02, rb)
				_beam(m, k, "gunmetal", Vector3(hx - 1.0, top - 2.0, rz), rc + rb * Vector3(-5.0, 0, 0), 0.6)
	# The command module at her bow: body, tapered nose, glazed bridge, docking collar.
	var bw := hx * 0.92
	var bh := hh * 0.82
	var bcy := cy + 0.5
	var sb := _sec(sk, bw, bh, float(s.ch))
	var taper: float = s.taper
	var sn := _sec(sk, bw * taper, bh * lerpf(1.0, taper, 0.6), float(s.ch))
	var bz0 := -hz
	var bz1 := -hz - 12.0
	var bz2 := -hz - 22.0
	_prism(m, k, "plates", Vector3(0, bcy, bz0), Vector3(0, bcy, bz1), sb, sb, u, false, false)
	_prism(m, k, "plates", Vector3(0, bcy, bz1), Vector3(0, bcy - 1.0, bz2), sb, sn, u, false, true)
	for z: float in [bz0 - 0.5, bz1]:
		_loop(m, k, "accent", Vector3(0, bcy, z), Vector3.BACK, u, sb, 0.5, 1.0)
	_loop(m, k, "trim", Vector3(0, bcy - 1.0, bz2 + 0.4), Vector3.BACK, u, sn, 0.35, 0.8)
	var gy := bcy + bh * 0.62
	var gw := _half_width(sk, bw, bh, bh * 0.62, float(s.ch))
	m.box(k, "glass", Vector3(0, gy, bz1 - 0.3), Vector3(gw * 1.7, 1.6, 0.3), 0.1)
	for side: float in [-1.0, 1.0]:
		m.box(k, "glass", Vector3(side * (gw + 0.02), gy, (bz0 + bz1) * 0.5 - 0.5), Vector3(0.2, 1.6, 5.0), 0.1)
		for f in 4:
			m.box(k, "trim", Vector3(side * (gw + 0.1), gy, bz1 + 0.5 + f * 1.5), Vector3(0.2, 1.8, 0.2), 0.04)
		# Her name boards either side.
		var zw := _half_width(sk, bw, bh, 0.0, float(s.ch))
		m.box(k, "plates", Vector3(side * (zw - 0.15), bcy - 1.0, -hz - 6.0), Vector3(0.5, 4.6, 9.0), 0.1)
		m.box(k, "accent", Vector3(side * (zw + 0.1), bcy - 1.0, -hz - 8.4), Vector3(0.05, 2.6, 2.6), 0.05)
		for row in 2:
			for v in 7:
				m.box(k, "lamp", Vector3(side * (_half_width(sk, bw, bh, bh * 0.25 + row * 1.6, float(s.ch)) + 0.02), bcy + bh * 0.25 + row * 1.6, -hz - 1.2 - v * 1.5), Vector3(0.06, 0.5, 0.8), 0.02)
		for v in 10:
			m.box(k, "dark", Vector3(side * (_half_width(sk, bw, bh, -bh * 0.6, float(s.ch)) + 0.02), bcy - bh * 0.6, -hz - 1.5 - v * 0.9), Vector3(0.08, 1.6, 0.35), 0.02)
		_rcs(m, k, Vector3(side * (zw + 0.4), bcy + bh * 0.5, bz1 + 1.0), [Vector3.UP, Vector3(side, 0, 0), Vector3.FORWARD], 2.5)
		m.rod(k, "red_lamp" if side < 0.0 else "lamp", Vector3(side * (hx - 1.0), top, -hz + 0.5), Vector3(side * (hx - 1.0), top + 0.6, -hz + 0.5), 0.4, -1.0, 12)
		m.rod(k, "lamp", Vector3(side * (hx - 1.0), top, hz - 0.5), Vector3(side * (hx - 1.0), top + 0.6, hz - 0.5), 0.4, -1.0, 12)
	var cz := bz2 - 0.1
	m.rod(k, "gunmetal", Vector3(0, bcy - 1.0, cz), Vector3(0, bcy - 1.0, cz - 2.2), 3.0, 2.8, 32)
	m.ring(k, "accent", Vector3(0, bcy - 1.0, cz - 2.2), 2.85, 0.22, Vector3.BACK, 32, 6)
	m.rod(k, "dark", Vector3(0, bcy - 1.0, cz - 2.2), Vector3(0, bcy - 1.0, cz - 2.9), 2.4, 2.3, 32)
	for a in 6:
		var d := Vector3(cos(TAU * a / 6.0), sin(TAU * a / 6.0), 0)
		m.box(k, "lamp", Vector3(0, bcy - 1.0, cz - 2.0) + d * 3.05, Vector3(0.4, 0.4, 0.3), 0.05)
	# Sensors on the command module's back: a mast, a dish.
	var sy := bcy + bh * (0.88 if sk == "round" else 0.97)
	m.rod(k, "gunmetal", Vector3(4.0, sy, bz0 - 3.0), Vector3(4.0, sy + 5.0, bz0 - 3.0), 0.25, 0.12, 12)
	m.rod(k, "red_lamp", Vector3(4.0, sy + 5.0, bz0 - 3.0), Vector3(4.0, sy + 5.5, bz0 - 3.0), 0.3, -1.0, 12)
	m.rod(k, "gunmetal", Vector3(-4.0, sy, bz0 - 4.0), Vector3(-4.0, sy + 2.0, bz0 - 4.0), 0.3, -1.0, 12)
	m.rod(k, "plates", Vector3(-4.0, sy + 2.0, bz0 - 4.0), Vector3(-4.6, sy + 3.4, bz0 - 4.0), 0.2, 2.6, 40)
	m.ring(k, "trim", Vector3(-4.6, sy + 3.4, bz0 - 4.0), 2.55, 0.12, Vector3(-0.4, 0.9, 0).normalized(), 40, 6)
	# The engine module aft: tanks round a truss, the thrust plate, the bells.
	var ew := hx * 0.7
	var eh := hh * 0.7
	var se := _sec(sk, ew, eh, float(s.ch))
	var ez0 := hz
	var ez1 := hz + 12.0
	_prism(m, k, "gunmetal", Vector3(0, cy, ez0), Vector3(0, cy, ez0 + 3.0), _sec(sk, ew * 0.8, eh * 0.8, float(s.ch)), _sec(sk, ew * 0.8, eh * 0.8, float(s.ch)), u, false, false)
	_prism(m, k, "plates", Vector3(0, cy, ez0 + 3.0), Vector3(0, cy, ez1), se, se, u, true, true)
	_loop(m, k, "accent", Vector3(0, cy, ez0 + 3.4), Vector3.BACK, u, se, 0.5, 1.0)
	_loop(m, k, "trim", Vector3(0, cy, ez1 - 0.5), Vector3.BACK, u, se, 0.4, 0.8)
	var thrust := _sec(sk, ew * 0.9, eh * 0.9, float(s.ch))
	_prism(m, k, "gunmetal", Vector3(0, cy, ez1), Vector3(0, cy, ez1 + 0.8), thrust, thrust, u, false, true)
	var em := (ez0 + 3.0 + ez1) * 0.5
	if String(s.tanks) == "sphere":
		var tr := 4.2
		for t: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var tc := Vector3(t.x * (ew + 1.4), cy + t.y * eh * 0.55, em)
			_sphere(m, k, "plates", tc, tr)
			m.ring(k, "accent", tc, tr * 1.01, 0.18, Vector3.UP, 32, 5)
			_beam(m, k, "gunmetal", tc, Vector3(t.x * ew * 0.8, cy + t.y * eh * 0.55, em), 0.7)
	else:
		for t: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var a := Vector3(t.x * (ew + 1.6), cy + t.y * eh * 0.6, ez0 + 3.5)
			var b := Vector3(a.x, a.y, ez1 - 0.5)
			m.rod(k, "plates", a, b, 2.4, -1.0, 24)
			m.rod(k, "trim", a, a - Vector3(0, 0, 0.8), 2.4, 1.4, 24)
			m.rod(k, "trim", b, b + Vector3(0, 0, 0.8), 2.4, 1.4, 24)
			for f in [0.3, 0.7]:
				m.ring(k, "accent", a.lerp(b, float(f)), 2.45, 0.15, Vector3.BACK, 24, 5)
	for e: Array in _engine_layout(String(s.engines), 3.4):
		var o: Vector2 = e[0]
		_bell(m, k, Vector3(o.x * 3.4, cy + o.y * 3.4, ez1 + 0.8), Vector3.BACK, 3.4 * float(e[1]))
	for side: float in [-1.0, 1.0]:
		for vy: float in [-1.0, 1.0]:
			_rcs(m, k, Vector3(side * (_half_width(sk, ew, eh, eh * 0.6, float(s.ch)) + 0.6), cy + vy * eh * 0.6, ez1 - 1.5), [Vector3(0, vy, 0), Vector3(side, 0, 0), Vector3.BACK], 2.5)
	# The door: two leaves just inside her side, ribbed, a band in the line's colour where
	# they meet; the top leaf slides up into her hull over the hold, the bottom one down.
	var half := door.y * 0.5
	for leaf: String in ["door_top", "door_bottom"]:
		var y0 := half if leaf == "door_top" else 0.0
		m.box(leaf, "plates", Vector3(dx + 0.5, y0 + half * 0.5, 0), Vector3(0.5, half, door.x), 0.08)
		for ry in [1.4, 3.5, 5.6]:
			m.box(leaf, "trim", Vector3(dx + 0.2, y0 + float(ry), 0), Vector3(0.2, 0.4, door.x - 0.6), 0.05)
		for vz in range(-25, 26, 10):
			m.box(leaf, "dark", Vector3(dx + 0.22, y0 + half * 0.5, float(vz)), Vector3(0.1, half - 0.6, 0.12), 0.02)
		var seam_y := y0 + (0.35 if leaf == "door_top" else half - 0.35)
		m.box(leaf, "accent", Vector3(dx + 0.2, seam_y, 0), Vector3(0.16, 0.7, door.x - 0.6), 0.03)


## An open cargo rack along her back at `at` (its foot's middle), `size` across, high, long:
## a frame in the line's colour round stock of kind `kind` (pipe bundles, plate stacks,
## containers).
static func _rack(m: YardToolMesh, k: String, at: Vector3, size: Vector3, kind: int) -> void:
	var hw := size.x * 0.5
	var hl := size.z * 0.5
	var y1 := at.y + size.y
	for z: float in [at.z - hl, at.z + hl]:
		_beam(m, k, "accent", Vector3(at.x - hw, at.y, z), Vector3(at.x - hw, y1, z), 0.6)
		_beam(m, k, "accent", Vector3(at.x + hw, at.y, z), Vector3(at.x + hw, y1, z), 0.6)
		_beam(m, k, "accent", Vector3(at.x - hw, y1, z), Vector3(at.x + hw, y1, z), 0.6)
	for x: float in [at.x - hw, at.x + hw]:
		_beam(m, k, "trim", Vector3(x, y1, at.z - hl), Vector3(x, y1, at.z + hl), 0.4)
		_beam(m, k, "trim", Vector3(x, at.y + 0.3, at.z - hl), Vector3(x, at.y + 0.3, at.z + hl), 0.4)
		_beam(m, k, "trim", Vector3(x, at.y + 0.3, at.z - hl), Vector3(x, y1, at.z), 0.25)
		_beam(m, k, "trim", Vector3(x, at.y + 0.3, at.z + hl), Vector3(x, y1, at.z), 0.25)
	m.box(k, "gunmetal", Vector3(at.x, at.y + 0.1, at.z), Vector3(size.x, 0.2, size.z), 0.05)
	match kind % 3:
		0:
			for row in 3:
				for col in 7:
					var p := Vector3(at.x - hw + 1.3 + col * ((size.x - 2.6) / 6.0), at.y + 0.9 + row * 1.25, 0)
					m.rod(k, "steel" if (row + col) % 3 else "copper", Vector3(p.x, p.y, at.z - hl + 0.6), Vector3(p.x, p.y, at.z + hl - 0.6), 0.55, -1.0, 14)
		1:
			for col in 3:
				for row in 7:
					m.box(k, "gunmetal" if row % 2 else "steel", Vector3(at.x - hw * 0.66 + col * hw * 0.66, at.y + 0.45 + row * 0.62, at.z), Vector3(size.x / 3.0 - 0.8, 0.5, size.z - 2.0), 0.03)
		_:
			for col in 3:
				for row in 2:
					var c := Vector3(at.x - hw * 0.66 + col * hw * 0.66, at.y + 0.3 + 1.3 + row * 2.55, at.z)
					m.box(k, "plates" if (col + row) % 2 else "trim", c, Vector3(size.x / 3.0 - 0.9, 2.4, size.z - 2.2), 0.08)
					for rz in 5:
						m.box(k, "dark", c + Vector3(0, 0, -size.z * 0.4 + rz * size.z * 0.2), Vector3(size.x / 3.0 - 0.8, 2.45, 0.12), 0.02)
					m.box(k, "accent", c + Vector3(0, 0.9, 0), Vector3(size.x / 3.0 - 0.85, 0.3, size.z - 2.15), 0.02)


## An open cargo rack on her far side (+X face at `x`): frames in the line's colour standing
## out from the hull, holding stock along her length (kind as _rack's).
static func _side_rack(m: YardToolMesh, k: String, x: float, y0: float, y1: float, z0: float, z1: float, kind: int) -> void:
	var out := 4.2
	for z: float in [z0, z1]:
		_beam(m, k, "accent", Vector3(x + out, y0, z), Vector3(x + out, y1, z), 0.7)
		for y: float in [y0, y1, (y0 + y1) * 0.5]:
			_beam(m, k, "accent", Vector3(x, y, z), Vector3(x + out, y, z), 0.6)
	for y: float in [y0, y1]:
		_beam(m, k, "trim", Vector3(x + out, y, z0), Vector3(x + out, y, z1), 0.45)
	_beam(m, k, "trim", Vector3(x + out, y0, z0), Vector3(x + out, (y0 + y1) * 0.5, z1), 0.3)
	_beam(m, k, "trim", Vector3(x + out, (y0 + y1) * 0.5, z1), Vector3(x + out, y1, z0), 0.3)
	var len := z1 - z0
	match kind % 3:
		0:
			for row in int((y1 - y0 - 1.0) / 1.15):
				for col in 3:
					var p := Vector3(x + 0.9 + col * 1.2, y0 + 0.9 + row * 1.15, 0)
					m.rod(k, "steel" if (row + col) % 4 else "copper", Vector3(p.x, p.y, z0 + 0.6), Vector3(p.x, p.y, z1 - 0.6), 0.52, -1.0, 14)
		1:
			for row in int((y1 - y0 - 1.0) / 2.1):
				var c := Vector3(x + out * 0.5, y0 + 1.4 + row * 2.1, (z0 + z1) * 0.5)
				m.box(k, "gunmetal", c, Vector3(out - 0.9, 0.25, len - 1.4), 0.03)
				for b in 3:
					m.box(k, "steel", c + Vector3(-out * 0.3 + b * out * 0.3, 0.55, 0), Vector3(0.35, 0.85, len - 1.6), 0.03)
					m.box(k, "steel", c + Vector3(-out * 0.3 + b * out * 0.3, 0.55, 0), Vector3(0.9, 0.12, len - 1.6), 0.02)
		_:
			for row in int((y1 - y0 - 0.6) / 2.7):
				for col in 2:
					var c := Vector3(x + out * 0.5, y0 + 1.6 + row * 2.7, z0 + len * (0.27 + col * 0.46))
					m.box(k, "plates" if (row + col) % 2 else "trim", c, Vector3(out - 0.9, 2.4, len * 0.42), 0.08)
					for rz in 4:
						m.box(k, "dark", c + Vector3(0, 0, -len * 0.18 + rz * len * 0.12), Vector3(out - 0.8, 2.45, 0.12), 0.02)
					m.box(k, "accent", c + Vector3(0, 0.9, 0), Vector3(out - 0.85, 0.3, len * 0.42 + 0.05), 0.02)
