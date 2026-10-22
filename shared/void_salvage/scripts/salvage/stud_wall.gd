class_name StudWall
extends RefCounted
## A wall across a ship built as a stud frame (docs/SHIP_FRAME_PLAN.md 4.4), as parts and
## joints into a FrameTarget: a sill rail along its foot (welded to the deck plates under it),
## head rails along its top edges (bolted up to whatever `anchor` finds there: the linings),
## studs between them every `spacing` and at every opening's edges (a doorway's jambs), a
## lintel over each opening (and a sill under one that starts above the floor) with short
## studs above and below it, and a panel on each face per stud bay, bolted to every member it
## lies over with the frame builds' flush bolts on the room side. The panels meet edge to edge
## over the studs' centre lines; the cavity between the two faces is the wall's (a service
## lane in F5). A `pocket` is where a sliding door's leaf runs inside the wall: its studs and
## sill are split to the two faces, leaving the middle clear for the leaf, and the lintel over
## the doorway runs on over it (the leaf's track).
##
## Wall space: it stands across the ship at z = `z`, `thickness` thick; x across, y up (ship
## space). `outline` is the cross-section it fills (convex, x and y; the caller keeps it the
## gap off the linings round it), cut off at `floor_y` (the deck's top).
##
## Paths (4.7), "wall:<name>/...": sill (sill/0 per piece; a split piece's two halves sill/1/f
## and sill/1/b, the fore and aft face), head/0.., stud/3 (split stud/3/f and stud/3/b; a
## stud an opening interrupts stud/3/s1 for its second piece), stud/b0.. (studs added behind a
## fitting later, `stud_behind`), lintel/0, opening_sill/0, panel/<face name>/2 (its stud bay;
## /s1 a strip an opening cuts); joints add weld:<what>, bolt:<what>/k. Joints are stamped
## "wall".

var target: FrameTarget
var name: String = "wall"
var z: float = 0.0
var thickness: float = 0.3
var outline := PackedVector2Array()
var floor_y: float = 0.0
## Doorways and windows through it (x, y).
var openings: Array[Rect2] = []
## Where a sliding leaf runs inside the wall (x, y): studs and sill split to the faces there.
var pockets: Array[Rect2] = []
## The clear middle a pocket keeps for its leaf, metres.
var pocket_clear: float = 0.1
## The faces' names in the paths: [the -z face, the +z face] (the rooms they face).
var faces: Array[String] = ["fore", "aft"]
var panel: float = 0.02
## Studs and rails: width across the wall (x for a stud, y for a rail), metres; their depth
## fills the wall between the panels.
var stud_width: float = 0.08
var rail_height: float = 0.06
var spacing: float = 0.6
## A doorway's jamb studs stand this far clear of its edges (the leaf's own edge), metres.
var jamb_clear: float = 0.03
var bolt_pitch: float = 1.0
## Inside the wall: between a panel and the frame behind it, metres.
var gap: float = 0.01
var panel_mat: Material
var frame_mat: Material
var bolt_head: int = FrameStyle.SUBTLE
var bead: int = FrameStyle.MACHINE
var groove: float = 0.0
## Optional `floor(x, z) -> PartData`: the deck plate under a point of the sill (welded to it).
var floor := Callable()
## Optional `anchor(p: Vector3) -> PartData`: what the head rails and the end studs bolt to
## (the linings round the wall).
var anchor := Callable()

## What was built.
var sills: Array[PartData] = []
var heads: Array[PartData] = []
var studs: Array[PartData] = []
var lintels: Array[PartData] = []
var panels: Array[PartData] = []
var welds: Array[ConnectionData] = []
var bolts: Array[ConnectionData] = []
## Every member a panel may be bolted to: {part, a, b (x, y: its centre line), key}.
var _members: Array[Dictionary] = []
## Horizontal rails a stud stops at: {lo, hi (y), x0, x1, part, key}.
var _rails: Array[Dictionary] = []
## The stud x's made (centre lines), for the panels' bays and `stud_behind`.
var _stud_x: Array[float] = []
var _added: int = 0


func _init(into: FrameTarget, wall_name: String, at: float, thick: float, fill: PackedVector2Array,
		panels_in: Material, members_in: Material) -> void:
	target = into
	name = wall_name
	z = at
	thickness = thick
	outline = fill
	panel_mat = panels_in
	frame_mat = members_in


func _path(rest: String) -> String:
	return "wall:%s/%s" % [name, rest]


## The depth of a full stud (between the panels), metres.
func depth() -> float:
	return thickness - 2.0 * (panel + gap)


## Builds the wall (the recipe given: its line, outline, openings and pockets, the sections).
func build() -> void:
	_built_seq = target.begin_builder("wall:%s" % name)
	_build_now()
	target.end_builder()


## What this wall is built from (docs/SHIP_FORMAT_PLAN.md, the 2.0 `walls` block): its name and
## line across the ship (z, thickness, the outline it fills from its floor), the openings and
## pockets, the faces' names, the members' and panels' sizes and pitches, the materials. What its
## sill welds to and its head bolts to are the design's (`floor`, `anchor`): the derived joints say.
func recipe() -> Dictionary:
	return {"name": name, "seq": _built_seq, "z": z, "thickness": thickness, "outline": outline, "floor_y": floor_y,
			"openings": openings, "pockets": pockets, "pocket_clear": pocket_clear, "faces": faces, "panel": panel,
			"stud_width": stud_width, "rail_height": rail_height, "spacing": spacing, "jamb_clear": jamb_clear,
			"bolt_pitch": bolt_pitch, "gap": gap, "bolt_head": bolt_head, "bead": bead, "groove": groove,
			"panel_mat": panel_mat, "frame_mat": frame_mat}


var _built_seq: int = 0


func _build_now() -> void:
	var phase_was := target.phase
	var head_was := target.parts_model().head_style
	target.phase = "wall"
	target.parts_model().head_style = bead
	outline = _clip_floor(outline)
	_sill()
	_heads()
	_openings()
	_all_studs()
	_tie_lintels()
	target.parts_model().head_style = bolt_head
	for f in 2:
		_panels(f)
	target.parts_model().head_style = head_was
	target.phase = phase_was


func _clip_floor(poly: PackedVector2Array) -> PackedVector2Array:
	var cut := Geometry2D.intersect_polygons(poly, PackedVector2Array([Vector2(-100, floor_y), Vector2(100, floor_y),
			Vector2(100, 100), Vector2(-100, 100)]))
	return cut[0] if not cut.is_empty() else poly


func _x_range() -> Vector2:
	var lo := INF
	var hi := -INF
	for p in outline:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	return Vector2(lo, hi)


## The outline's top at x (the lowest over x +- half).
func _top_at(poly: PackedVector2Array, x: float, half: float = 0.0) -> float:
	var lo := INF
	var hi := -INF
	for p in poly:
		lo = minf(lo, p.x)
		hi = maxf(hi, p.x)
	var top := INF
	for xx: float in [x - half, x, x + half]:
		top = minf(top, _span_y(poly, clampf(xx, lo + 0.001, hi - 0.001)).y)
	return top


## Where a vertical line at `x` crosses a convex polygon ([min y, max y]).
static func _span_y(poly: PackedVector2Array, x: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		if absf(a.x - b.x) < 1e-6:
			if absf(a.x - x) < 1e-6:
				lo = minf(lo, minf(a.y, b.y))
				hi = maxf(hi, maxf(a.y, b.y))
			continue
		if (a.x - x) * (b.x - x) > 0.0:
			continue
		var y := lerpf(a.y, b.y, (x - a.x) / (b.x - a.x))
		lo = minf(lo, y)
		hi = maxf(hi, y)
	return Vector2(lo, hi)


func _bar(part_name: String, path: String, lo: Vector3, hi: Vector3) -> PartData:
	var size := hi - lo
	return target.part(part_name, PartData.Kind.FRAME, PartShapes.box(size), Transform3D(Basis(), (lo + hi) * 0.5), frame_mat,
			"", 0.5, null, path)


## The z spans a member takes: the full depth, or (in a pocket) the two face halves.
func _depths(split: bool) -> Array:
	var d0 := z - thickness * 0.5 + panel + gap
	var d1 := z + thickness * 0.5 - panel - gap
	if not split:
		return [[d0, d1, ""]]
	var half := (depth() - pocket_clear) * 0.5
	return [[d0, d0 + half, "/f"], [d1 - half, d1, "/b"]]


func _in_pocket(x0: float, x1: float, y: float) -> bool:
	for p in pockets:
		if x1 > p.position.x - 0.001 and x0 < p.end.x + 0.001 and y >= p.position.y - 0.001 and y <= p.end.y + 0.001:
			return true
	return false


func _sill() -> void:
	var r := _x_range()
	var a := r.x + gap
	var b := r.y - gap
	# Pieces between the floor-level openings, split again at the pockets' ends.
	var cuts: Array[float] = [a, b]
	for o in openings:
		if o.position.y <= floor_y + 0.01:
			cuts.append(o.position.x)
			cuts.append(o.end.x)
	for p in pockets:
		cuts.append(clampf(p.position.x, a, b))
		cuts.append(clampf(p.end.x, a, b))
	cuts.sort()
	var k := 0
	for i in cuts.size() - 1:
		var x0 := cuts[i] + (gap if i > 0 else 0.0)
		var x1 := cuts[i + 1] - (gap if i < cuts.size() - 2 else 0.0)
		if x1 - x0 < 0.05:
			continue
		var mid := (x0 + x1) * 0.5
		var in_door := false
		for o in openings:
			in_door = in_door or (o.position.y <= floor_y + 0.01 and mid > o.position.x and mid < o.end.x)
		if in_door:
			continue
		var split := _in_pocket(x0 + 0.01, x1 - 0.01, floor_y + 0.01)
		for d: Array in _depths(split):
			var path := _path("sill/%d%s" % [k, d[2]])
			var p := _bar("StudSill", path, Vector3(x0, floor_y, d[0]), Vector3(x1, floor_y + rail_height, d[1]))
			sills.append(p)
			_members.append({"part": p, "a": Vector2(x0, floor_y + rail_height * 0.5), "b": Vector2(x1, floor_y + rail_height * 0.5),
					"key": "sill:%d%s" % [k, d[2]]})
			_rails.append({"lo": floor_y, "hi": floor_y + rail_height, "x0": x0, "x1": x1, "part": p, "key": "sill",
					"face": d[2]})
			_weld_to_floor(p, x0, x1, (float(d[0]) + float(d[1])) * 0.5)
		k += 1


## Welds a sill piece to every deck plate under it: one bead per plate along their contact.
func _weld_to_floor(p: PartData, x0: float, x1: float, at_z: float) -> void:
	if not floor.is_valid():
		return
	var runs: Array = []
	var x := x0
	while x <= x1 + 0.0001:
		var under: PartData = floor.call(x, at_z)
		if under:
			if runs.is_empty() or runs[-1][0] != under:
				runs.append([under, x, x])
			else:
				runs[-1][2] = x
		x += 0.05
	for run: Array in runs:
		var under: PartData = run[0]
		var mid := (float(run[1]) + float(run[2])) * 0.5
		welds.append(target.join(p, under, ConnectionData.Kind.WELD, Vector3(mid, floor_y, at_z), Vector3.UP, Vector3.RIGHT,
				Vector2(maxf(float(run[2]) - float(run[1]), 0.05), 0.0), "%s/weld:%s" % [p.path, under.path]))


## Head rails along the outline's top edges (not its sides, not the floor), welded to each
## other at the corners and bolted up to the anchor.
func _heads() -> void:
	var n := outline.size()
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= float(n)
	var made: Array[Array] = []
	for e in n:
		var a := outline[e]
		var b := outline[(e + 1) % n]
		var d := b - a
		var nrm := Vector2(d.y, -d.x).normalized()
		if nrm.dot((a + b) * 0.5 - centre) < 0.0:
			nrm = -nrm
		if nrm.y < 0.3:
			continue   # a side or the floor
		var inward := -nrm
		var length := d.length()
		var u := d / length
		# Pulled in from both ends so neighbouring rails at a corner keep the gap.
		var trim := rail_height + gap
		var p0 := a + u * trim + inward * (rail_height * 0.5 + gap * 0.5)
		var p1 := b - u * trim + inward * (rail_height * 0.5 + gap * 0.5)
		if p0.distance_to(p1) < 0.1:
			continue
		var made_rail := _rail_between(p0, p1, inward, _path("head/%d" % heads.size()))
		heads.append(made_rail)
		made.append([made_rail, p0, p1, inward])
		_members.append({"part": made_rail, "a": p0, "b": p1, "key": "head:%d" % (heads.size() - 1)})
		# A flat (or nearly flat) head is a rail studs stop under.
		_rails.append({"lo": minf(p0.y, p1.y) - rail_height * 0.5, "hi": maxf(p0.y, p1.y) + rail_height * 0.5,
				"x0": minf(p0.x, p1.x), "x1": maxf(p0.x, p1.x), "part": made_rail, "key": "head:%d" % (heads.size() - 1),
				"head": true})
		if anchor.is_valid():
			var k := 0
			for t: float in [0.15, 0.5, 0.85]:
				var at2 := p0.lerp(p1, t) - inward * (rail_height * 0.5)
				var holder: PartData = anchor.call(Vector3(at2.x, at2.y, z))
				if holder:
					bolts.append(target.join(made_rail, holder, ConnectionData.Kind.BOLT, Vector3(at2.x, at2.y, z),
							Vector3(-inward.x, -inward.y, 0.0), Vector3.ZERO, Vector2.ZERO,
							"%s/bolt:%s/%d" % [made_rail.path, holder.path, k]))
					k += 1
	# Corners: each rail welded to the next.
	for i in made.size() - 1:
		var a: Array = made[i]
		var b: Array = made[i + 1]
		var at2 := ((a[2] as Vector2) + (b[1] as Vector2)) * 0.5
		var along := ((b[1] as Vector2) - (a[2] as Vector2)).normalized()
		welds.append(target.join(b[0], a[0], ConnectionData.Kind.WELD, Vector3(at2.x, at2.y, z), Vector3(along.x, along.y, 0.0),
				Vector3.BACK, Vector2(depth(), rail_height), "%s/weld:%s" % [(b[0] as PartData).path,
				(a[0] as PartData).path.trim_prefix("wall:%s/" % name)]))


## A rail of the wall's depth from p0 to p1 (x, y), its height facing `up` (x, y).
func _rail_between(p0: Vector2, p1: Vector2, up: Vector2, path: String) -> PartData:
	var a := Vector3(p0.x, p0.y, z)
	var b := Vector3(p1.x, p1.y, z)
	var xf := FrameParts.along(a, b, Vector3(up.x, up.y, 0.0))
	var length := a.distance_to(b)
	var shape := PartShapes.box(Vector3(length, rail_height, depth()))
	var p := target.part("StudHead", PartData.Kind.FRAME, shape, xf, frame_mat, "", 0.5, null, path)
	return p


## Lintels over the openings (running on over a pocket beside one) and sills under those that
## start above the floor.
func _openings() -> void:
	for i in openings.size():
		var o := openings[i]
		var x0 := o.position.x - jamb_clear
		var x1 := o.end.x + jamb_clear
		for p in pockets:
			if p.position.x < o.end.x and p.end.x > o.position.x - 0.5:
				x0 = minf(x0, p.position.x)
				x1 = maxf(x1, minf(p.end.x, x1))
		var lintel := _bar("StudLintel", _path("lintel/%d" % i), Vector3(x0, o.end.y, z - depth() * 0.5),
				Vector3(x1, o.end.y + rail_height, z + depth() * 0.5))
		lintels.append(lintel)
		_members.append({"part": lintel, "a": Vector2(x0, o.end.y + rail_height * 0.5), "b": Vector2(x1, o.end.y + rail_height * 0.5),
				"key": "lintel:%d" % i})
		_rails.append({"lo": o.end.y, "hi": o.end.y + rail_height, "x0": x0, "x1": x1, "part": lintel, "key": "lintel:%d" % i})
		if o.position.y > floor_y + 0.01:
			var sill := _bar("StudSill", _path("opening_sill/%d" % i), Vector3(o.position.x - jamb_clear, o.position.y - rail_height, z - depth() * 0.5),
					Vector3(o.end.x + jamb_clear, o.position.y, z + depth() * 0.5))
			lintels.append(sill)
			_members.append({"part": sill, "a": Vector2(o.position.x, o.position.y - rail_height * 0.5),
					"b": Vector2(o.end.x, o.position.y - rail_height * 0.5), "key": "opening_sill:%d" % i})
			_rails.append({"lo": o.position.y - rail_height, "hi": o.position.y, "x0": o.position.x - jamb_clear,
					"x1": o.end.x + jamb_clear, "part": sill, "key": "opening_sill:%d" % i})


## The studs: one at each end, at each opening's jambs, then every `spacing` where none is
## near; each split round the rails and openings it meets.
func _all_studs() -> void:
	var r := _x_range()
	var w := stud_width
	var xs: Array[float] = [r.x + gap + w * 0.5, r.y - gap - w * 0.5]
	for o in openings:
		xs.append(o.position.x - jamb_clear - w * 0.5)
		xs.append(o.end.x + jamb_clear + w * 0.5)
	var x := r.x + spacing
	while x < r.y - w:
		var clear := true
		for other in xs:
			clear = clear and absf(other - x) >= w + 0.15
		if clear:
			xs.append(x)
		x += spacing
	xs.sort()
	for i in xs.size():
		_stud(xs[i], "stud/%d" % i)


## One stud at x: its pieces between the rails and openings it meets, each welded to the rail
## at either end; split in a pocket. Returns the pieces.
func _stud(x: float, key: String) -> Array[PartData]:
	var w := stud_width
	var made: Array[PartData] = []
	var x0 := x - w * 0.5
	var x1 := x + w * 0.5
	# What it may not cross, as y intervals with what bounds it there.
	var blocks: Array = []
	for rail: Dictionary in _rails:
		if x1 > float(rail["x0"]) and x0 < float(rail["x1"]) and not rail.get("head", false):
			blocks.append([float(rail["lo"]), float(rail["hi"]), rail])
	for o in openings:
		if x1 > o.position.x - 0.001 and x0 < o.end.x + 0.001:
			blocks.append([o.position.y, o.end.y, null])
	var top := _top_at(_head_line(), x, w * 0.5) - gap
	var bottom := floor_y
	blocks.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var spans: Array = []
	var cursor := bottom
	var below: Variant = null
	for b: Array in blocks:
		if float(b[1]) <= cursor:
			if b[2] != null:
				below = b[2]
			continue
		if float(b[0]) > cursor:
			spans.append([cursor, float(b[0]), below, b[2]])
		cursor = maxf(cursor, float(b[1]))
		below = b[2]
	if top > cursor:
		spans.append([cursor, top, below, "head"])
	var piece := 0
	for s: Array in spans:
		var y0: float = float(s[0]) + gap
		var y1: float = float(s[1]) - gap
		if y1 - y0 < 0.08:
			continue
		var split := _in_pocket(x0, x1, (y0 + y1) * 0.5)
		for d: Array in _depths(split):
			var path := _path("%s%s%s" % [key, "" if piece == 0 else "/s%d" % piece, d[2]])
			var p := _bar("Stud", path, Vector3(x0, y0, d[0]), Vector3(x1, y1, d[1]))
			studs.append(p)
			made.append(p)
			_members.append({"part": p, "a": Vector2(x, y0), "b": Vector2(x, y1), "key": path.trim_prefix("wall:%s/" % name)})
			var mid_z := (float(d[0]) + float(d[1])) * 0.5
			for end in 2:
				var holder: Variant = s[2 + end]
				var at := Vector3(x, y0 - gap * 0.5 if end == 0 else y1 + gap * 0.5, mid_z)
				var rail_part: PartData = null
				var role := ""
				if holder is Dictionary:
					var rail: Dictionary = _same_face(holder, d[2])
					rail_part = rail["part"]
					role = rail["key"]
				elif holder is String:
					rail_part = _head_over(x)
					role = "head"
				if rail_part:
					welds.append(target.join(p, rail_part, ConnectionData.Kind.WELD, at, Vector3.UP, Vector3.RIGHT,
							Vector2(w, float(d[1]) - float(d[0])), "%s/weld:%s" % [path, role]))
		piece += 1
	_stud_x.append(x)
	# An end stud is bolted to what stands beside it (the lining).
	if anchor.is_valid() and not made.is_empty():
		var r := _x_range()
		var side := -1.0 if absf(x - r.x) < w else (1.0 if absf(x - r.y) < w else 0.0)
		if side != 0.0:
			var p: PartData = made[0]
			var k := 0
			for t: float in [0.3, 0.7]:
				var y := lerpf(floor_y, top, t)
				var at := Vector3(x + side * w * 0.5, y, z)
				var holder: PartData = anchor.call(at + Vector3(side * 0.05, 0.0, 0.0))
				if holder:
					bolts.append(target.join(p, holder, ConnectionData.Kind.BOLT, at, Vector3(side, 0.0, 0.0), Vector3.ZERO,
							Vector2.ZERO, "%s/bolt:%s/%d" % [p.path, holder.path, k]))
					k += 1
	return made


## A lintel (or an opening's sill) that fewer than two studs weld to (no cripple stud fits over a
## narrow doorway) is welded at its ends to the jamb studs beside it.
func _tie_lintels() -> void:
	for lintel in lintels:
		var held := 0
		for c in welds:
			if c and (c.part_a == lintel.id or c.part_b == lintel.id):
				held += 1
		if held >= 2:
			continue
		var box := lintel.local_transform * target.parts_model().part_visual(lintel.id).get_aabb()
		var y := box.get_center().y
		for end in 2:
			var x := box.position.x if end == 0 else box.end.x
			for mem: Dictionary in _members:
				if not String(mem["key"]).begins_with("stud"):
					continue
				var a: Vector2 = mem["a"]
				var b: Vector2 = mem["b"]
				if absf(a.x - x) > stud_width * 0.5 + gap + 0.02 or y < minf(a.y, b.y) or y > maxf(a.y, b.y):
					continue
				var stud: PartData = mem["part"]
				var sb := stud.local_transform * target.parts_model().part_visual(stud.id).get_aabb()
				welds.append(target.join(lintel, stud, ConnectionData.Kind.WELD, Vector3(x, y, sb.get_center().z),
						Vector3(-1.0 if end == 0 else 1.0, 0.0, 0.0), Vector3.UP, Vector2(rail_height, sb.size.z),
						"%s/weld:%s" % [lintel.path, mem["key"]]))
				break


## The half of a split rail on face `face` ("/f", "/b"; "" for a full one): a split stud welds
## to the sill half on its own side.
func _same_face(rail: Dictionary, face: String) -> Dictionary:
	if String(rail.get("face", "")) == "" or rail["face"] == face:
		return rail
	for other: Dictionary in _rails:
		if other["face" if other.has("face") else "key"] == face and is_equal_approx(float(other["x0"]), float(rail["x0"])) \
				and is_equal_approx(float(other["lo"]), float(rail["lo"])):
			return other
	return rail


## The line studs stop under: the outline brought down by the head rails.
func _head_line() -> PackedVector2Array:
	return FrameParts.inset(outline, rail_height + gap)


## The head rail over x.
func _head_over(x: float) -> PartData:
	var best: PartData = null
	var best_d := INF
	for m: Dictionary in _members:
		if not String(m["key"]).begins_with("head:"):
			continue
		var a: Vector2 = m["a"]
		var b: Vector2 = m["b"]
		var d := 0.0 if x >= minf(a.x, b.x) and x <= maxf(a.x, b.x) else minf(absf(x - a.x), absf(x - b.x))
		if d < best_d:
			best_d = d
			best = m["part"]
	return best


## The panels of face `f` (0: the -z face, 1: the +z face): one per stud bay, cut round the
## openings, bolted to every member under it.
func _panels(f: int) -> void:
	var r := _x_range()
	var cols: Array[float] = [r.x]
	var sorted := _stud_x.duplicate()
	sorted.sort()
	for x in sorted:
		if x > r.x + 0.05 and x < r.y - 0.05:
			cols.append(x)
	cols.append(r.y)
	var face_z := z - thickness * 0.5 if f == 0 else z + thickness * 0.5
	var normal := Vector3.FORWARD if f == 0 else Vector3.BACK
	for i in cols.size() - 1:
		var strips := _strips(cols[i], cols[i + 1])
		for k in strips.size():
			var poly: PackedVector2Array = strips[k]
			var path := _path("panel/%s/%d%s" % [faces[f], i, "" if strips.size() == 1 else "/s%d" % k])
			_panel(poly, face_z, normal, path)


## A stud bay's column of the outline, less the openings, as convex strips (x, y).
func _strips(a: float, b: float) -> Array:
	var cuts: Array[float] = [a, b]
	for o in openings:
		if o.end.x > a and o.position.x < b:
			cuts.append(clampf(o.position.x, a, b))
			cuts.append(clampf(o.end.x, a, b))
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		var c0 := cuts[i]
		var c1 := cuts[i + 1]
		if c1 - c0 < 0.02:
			continue
		var spans: Array = [[-100.0, 100.0]]
		for o in openings:
			if (c0 + c1) * 0.5 <= o.position.x or (c0 + c1) * 0.5 >= o.end.x:
				continue
			var next: Array = []
			for s: Array in spans:
				if o.end.y <= s[0] or o.position.y >= s[1]:
					next.append(s)
					continue
				if o.position.y > s[0]:
					next.append([s[0], o.position.y])
				if o.end.y < s[1]:
					next.append([o.end.y, s[1]])
			spans = next
		for s: Array in spans:
			var box := PackedVector2Array([Vector2(c0, s[0]), Vector2(c1, s[0]), Vector2(c1, s[1]), Vector2(c0, s[1])])
			var cut := Geometry2D.intersect_polygons(outline, box)
			if not cut.is_empty() and absf(_area(cut[0])) > 0.001:
				out.append(cut[0])
	return out


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## One panel over `poly` (x, y) on the face at `face_z` facing `normal`: its look the strip, its
## collision the strip held back by half the inner gap, bolted along every member under it.
func _panel(poly: PackedVector2Array, face_z: float, normal: Vector3, path: String) -> void:
	var down := normal.z > 0.0   # the +z face: the plate's local z runs down y
	var basis := Basis(Vector3.RIGHT, normal, Vector3.UP if not down else Vector3.DOWN)
	var local := PackedVector2Array()
	for p in poly:
		local.append(Vector2(p.x, -p.y if down else p.y))
	if _area(local) < 0.0:
		local.reverse()
	var look := FrameParts.plate(local, panel, groove, 0.0)
	var held := FrameParts.plate(FrameParts.inset(local, gap * 0.5), panel, 0.0, 0.0)
	var xform := Transform3D(basis, Vector3(0.0, 0.0, face_z))
	var p := target.part("WallPanel", PartData.Kind.HULL, DeckFrame._looks_held(look, held), xform, panel_mat, "", 1.0, null, path)
	panels.append(p)
	var lo := Vector2(INF, INF)
	var hi := -lo
	for q in poly:
		lo = lo.min(q)
		hi = hi.max(q)
	var m := 0.01
	var mid := (lo + hi) * 0.5
	for mem: Dictionary in _members:
		var a: Vector2 = mem["a"]
		var b: Vector2 = mem["b"]
		# The stretch of the member's centre line under this panel, a margin in from its edges; a
		# stud under the panel's edge (the seam over its middle) is bolted a little in from it.
		var seg := DeckFrame.clip_segment(a, b, poly, m)
		if seg.is_empty() and absf(a.x - b.x) < 0.001:
			var shift := Vector2(signf(mid.x - a.x) * stud_width * 0.25, 0.0)
			seg = DeckFrame.clip_segment(a + shift, b + shift, poly, m)
		if seg.is_empty():
			continue
		var length := (seg[0] as Vector2).distance_to(seg[1])
		var n := maxi(1, int(ceil(length / bolt_pitch)))
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var at2 := (seg[0] as Vector2).lerp(seg[1], t)
			var holder: PartData = mem["part"]
			# A split member: bolt to its half on this face.
			bolts.append(target.join(p, holder, ConnectionData.Kind.BOLT, Vector3(at2.x, at2.y, face_z), normal,
					Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s/%d" % [path, mem["key"], k]))


## A stud behind a fitting fixed to this wall at x, y0..y1 (ship space): one already within
## reach, or a new one (stud/b<k>) put in the bay there if it fits between its neighbours, else
## the nearest. What a fitting's spot welds through the panel are taken by.
func stud_behind(x: float, y: float) -> PartData:
	target.begin_builder("wall:%s" % name)
	var stud := _stud_behind(x, y)
	target.end_builder()
	return stud


func _stud_behind(x: float, y: float) -> PartData:
	var best: PartData = null
	var best_d := INF
	for mem: Dictionary in _members:
		if not String(mem["key"]).begins_with("stud"):
			continue
		var a: Vector2 = mem["a"]
		var b: Vector2 = mem["b"]
		if y < minf(a.y, b.y) - 0.05 or y > maxf(a.y, b.y) + 0.05:
			continue
		var d := absf(a.x - x)
		if d < best_d:
			best_d = d
			best = mem["part"]
	if best_d <= stud_width:
		return best
	var room := true
	for other in _stud_x:
		room = room and absf(other - x) >= stud_width + 2.0 * gap
	if room:
		var phase_was := target.phase
		var head_was := target.parts_model().head_style
		target.phase = "wall"
		target.parts_model().head_style = bead
		var made := _stud(x, "stud/b%d" % _added)
		_added += 1
		target.parts_model().head_style = head_was
		target.phase = phase_was
		for p in made:
			for mem: Dictionary in _members:
				if mem["part"] == p:
					var a: Vector2 = mem["a"]
					var b: Vector2 = mem["b"]
					if y >= minf(a.y, b.y) - 0.05 and y <= maxf(a.y, b.y) + 0.05:
						return p
		if not made.is_empty():
			return made[0]
	return best


# --- Services (docs/SHIP_FRAME_PLAN.md 4.5) -----------------------------------------------

## Adds the wall's cavity to `graph` ("stud" lanes): up both sides of every stud, and along the
## top of every sill, lintel and opening sill between the studs standing on it, with a step
## through each such stud (a hole drilled in it); lanes meeting at a rail step onto each other.
## A stud's top steps out through its head rail and the lining over it (`anchor`) onto the
## hull's lanes there, its foot down through its sill and the deck plates onto the lanes under
## the deck; a stud stopping at a lintel or an opening's sill steps through it onto the studs
## beyond. In a pocket the lanes run up the split studs in each face's half, clear of the leaf
## between them. Call after `build` and the hull's and deck's `add_lanes`.
func add_lanes(graph: FrameGraph) -> void:
	var off := FrameGraph.OFF_FACE
	var model := target.parts_model()
	var boxes: Dictionary = {}
	for st in studs:
		boxes[st] = st.local_transform * model.part_visual(st.id).get_aabb()
	var ends: Array = []   # [point, stud, top?]
	for st: PartData in boxes:
		var b: AABB = boxes[st]
		var zc := b.get_center().z
		for side: float in [-1.0, 1.0]:
			var x := b.position.x - off if side < 0.0 else b.end.x + off
			var lo := Vector3(x, b.position.y, zc)
			var hi := Vector3(x, b.end.y, zc)
			graph.add_lane("stud", lo, hi, Vector3(side, 0.0, 0.0), Vector3.BACK, st)
			ends.append([lo, st, false])
			ends.append([hi, st, true])
	for rail: Dictionary in _rails:
		var part: PartData = rail["part"]
		if rail.get("head", false):
			continue
		var rb := part.local_transform * model.part_visual(part.id).get_aabb()
		var y := rb.end.y + off
		var zc := rb.get_center().z
		var on: Array = []   # [x from, x to, stud]
		for st: PartData in boxes:
			var b: AABB = boxes[st]
			if absf(b.position.y - rb.end.y) < 0.03 and b.end.x > rb.position.x and b.position.x < rb.end.x \
					and b.end.z > rb.position.z and b.position.z < rb.end.z:
				on.append([b.position.x - off, b.end.x + off, st])
		on.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
		var xs: Array[float] = [rb.position.x]
		for o: Array in on:
			xs.append(float(o[0]))
			xs.append(float(o[1]))
		xs.append(rb.end.x)
		for k in range(0, xs.size() - 1, 2):
			if xs[k + 1] - xs[k] > 0.03:
				graph.add_lane("stud", Vector3(xs[k], y, zc), Vector3(xs[k + 1], y, zc), Vector3.UP, Vector3.BACK, part)
		for o: Array in on:
			var exempt: Array[int] = [(o[2] as PartData).id]
			graph.add_step(Vector3(o[0], y, zc), Vector3(o[1], y, zc), false, exempt)
	var rails: Array = []   # [box, part]
	for rail: Dictionary in _rails:
		if not rail.get("head", false):
			var rp: PartData = rail["part"]
			rails.append([rp.local_transform * model.part_visual(rp.id).get_aabb(), rp])
	for e: Array in ends:
		var p: Vector3 = e[0]
		graph.link_nearest(p, ["stud"], [], false, 2, 0.06)
		# Stopping at a lintel or an opening's sill: through it onto the studs beyond.
		var stop: PartData = null
		for rb: Array in rails:
			var box: AABB = rb[0]
			var gap_to := box.position.y - p.y if e[2] else p.y - box.end.y
			if gap_to > -0.005 and gap_to < 0.04 and p.x > box.position.x - 0.05 and p.x < box.end.x + 0.05 \
					and p.z > box.position.z - 0.01 and p.z < box.end.z + 0.01 and box.position.y > floor_y + 0.01:
				stop = rb[1]
		if stop:
			var past: Array[int] = [stop.id]
			graph.link_nearest(p, ["stud"], past, false, 2, 0.15)
			continue
		if e[2]:
			# Out of the top: through the head rail and the linings over the wall and either side.
			var through: Array[int] = []
			var head := _head_over(p.x)
			if head:
				through.append(head.id)
				# The linings it is bolted up to.
				for c in bolts:
					if c.part_a == head.id and not through.has(c.part_b):
						through.append(c.part_b)
			if anchor.is_valid():
				for probe: Vector3 in [Vector3(0.0, 0.12, 0.0), Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.12, -0.15),
						Vector3(0.0, 0.12, 0.15)]:
					var over: PartData = anchor.call(p + probe)
					if over and not through.has(over.id):
						through.append(over.id)
			graph.link_nearest(p, ["ring", "stringer", "loom"], through, true, 2)
		elif absf(p.y - floor_y - rail_height - gap) < 0.03:
			# Out of the foot: through the sill and the deck under it.
			var through: Array[int] = []
			for sill in sills:
				var sb := sill.local_transform * model.part_visual(sill.id).get_aabb()
				if p.x >= sb.position.x - 0.1 and p.x <= sb.end.x + 0.1:
					through.append(sill.id)
			graph.link_nearest(p, ["deck"], through, true, 2)
