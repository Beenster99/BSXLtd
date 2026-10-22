class_name DeckFrame
extends RefCounted
## A deck on a FrameHull's frame (docs/SHIP_FRAME_PLAN.md 4.4), built as parts and joints into
## the hull's FrameTarget: at every station inside the deck a beam across the ship just under
## the plates, its ends welded to the ring members it butts against (replacing the wrecks'
## single belly joist); deck girders along the ship between the beams at `girder_x`, welded to
## the beams' sides; deck plates over them, one per bay per lane between the girders (cut round
## the `openings`), tacked with spot welds wherever a beam or a girder lies under them, every
## `spot_pitch`. An opening that a beam would cross splits the beam at the girders either side
## of it, and a trimmer across between those girders frames the opening's ends where no beam
## does. The plates meet edge to edge (their looks run to the seam lines over the members'
## centre lines), their collisions keep the gaps. Nothing here knows a game class, so BSX can
## build the same deck from the same recipe.
##
## Paths (4.7), under the hull's name (and the deck's `level`, if any: "body/deck:upper/st:..."):
## "hull/st:hold/beam" (split: "beam/0", "beam/1" from -X),
## "hull/bay:hold/girder/1", "hull/bay:hold/trimmer/0", "hull/bay:hold/deck/1" (lane 1; "/s2" for
## the third strip of a lane an opening cuts); joints "hull/st:hold/beam/weld:e5",
## "hull/st:hold/beam/0/weld:girder:0", "hull/bay:hold/girder/1/weld:fore",
## "hull/bay:hold/deck/1/spot:girder:1/3", "hull/bay:hold/deck/1/spot:aft/0" (a beam under
## the plate at its bay's own stations is fore or aft, as FrameHull's rows are; any other by
## its station, st:<label>). Every joint is stamped "deck".

var target: FrameTarget
var hull: FrameHull
var plate_mat: Material
var frame_mat: Material
## The deck surface, metres up (ship space y).
var top: float = 0.0
## Plate thickness, metres.
var plate: float = 0.04
## Beams across the ship and girders along it: (width, depth), metres.
var beam := Vector2(0.1, 0.14)
var girder := Vector2(0.08, 0.14)
## The girders' x (ship space), from -X to +X; the lanes run between them. A girder that would
## run through an opening (inside its width, along its length) is left out of that bay (its
## row holds null there), and so is the lane edge it would make.
var girder_x: Array[float] = []
## Where the deck starts and ends along the ship (z, front to back).
var z0: float = -INF
var z1: float = INF
## Holes through the deck (x, z: Rect2(x, z, width, length)): a hatch, a lift.
var openings: Array[Rect2] = []
## Spot welds along a member under a plate, metres apart.
var spot_pitch: float = 0.5
## How far a trimmer stands off an opening's end, metres (room for its well's lining).
var trimmer_clear: float = 0.06
## Optional `half_width(z) -> float`: the deck's half width at z when narrower than the
## hull allows (a cockpit floor).
var half_width := Callable()
## Plate bevel where neighbours meet (0: edge to edge).
var groove: float = 0.0
## A second deck on the same hull names itself in its paths ("body/deck:upper/st:holds/beam");
## "" for the hull's main deck ("body/st:holds/beam").
var level: String = ""

## What was built: beams per station index ([] where none), girders[bay][i] (null where one is
## left out round an opening), trimmers, the plates (every strip), and every weld and spot.
var beams: Dictionary = {}
var girders: Dictionary = {}
var trimmers: Array[PartData] = []
var plates: Array[PartData] = []
var welds: Array[ConnectionData] = []
var spots: Array[ConnectionData] = []
## Members a plate rests on: {part, a, b (ship space, its top's centre line), name}.
var _under: Array[Dictionary] = []
var _named: Dictionary = {}


func _init(on: FrameHull, plates_in: Material, members_in: Material) -> void:
	hull = on
	target = on.target
	plate_mat = plates_in
	frame_mat = members_in


## Builds the deck (the recipe given: its level, the members' sizes and lines, the openings).
func build() -> void:
	_built_seq = target.begin_builder(who())
	_build_now()
	target.end_builder()
	# The half width it followed (a design's callable), at every station along it and its ends,
	# for the recipe (straight between them, as the designs' are).
	_half_built.clear()
	if half_width.is_valid():
		var zs: Array[float] = [z0]
		for i in hull.stations.size():
			var z := hull.ring_z(i)
			if z > z0 and z < z1:
				zs.append(z)
		zs.append(z1)
		for z in zs:
			_half_built.append([z, half_width.call(z)])


## This deck's builder name: "deck:<the hull's name>/<level>" ("main" for the first level).
func who() -> String:
	return "deck:%s/%s" % [hull.name, level if level != "" else "main"]


## What this deck is built from (docs/SHIP_FORMAT_PLAN.md, the 2.0 `decks` block): the hull it
## stands in, its level, top and plate, its members' sections and lines, its run along the ship,
## the openings through it, its spot pitch, the half width it follows (if a design gave one, as
## [z, half] points, straight between). Engine values and materials as they are.
func recipe() -> Dictionary:
	return {"name": who(), "hull": hull.name, "level": level if level != "" else "main", "seq": _built_seq, "top": top,
			"plate": plate, "beam": beam, "girder": girder, "girder_x": girder_x, "z0": z0, "z1": z1,
			"openings": openings, "spot_pitch": spot_pitch, "trimmer_clear": trimmer_clear, "groove": groove,
			"plate_mat": plate_mat, "frame_mat": frame_mat, "half_width": _half_built if not _half_built.is_empty() else null}


var _built_seq: int = 0
var _half_built: Array = []


func _build_now() -> void:
	var phase_was := target.phase
	target.phase = "deck"
	var y1 := top - plate - FrameHull.GAP   # the members' tops
	var y0 := y1 - beam.y
	var stations_in: Array[int] = []
	for i in hull.stations.size():
		var z := hull.ring_z(i)
		if z > z0 + beam.x * 0.5 and z < z1 - beam.x * 0.5:
			stations_in.append(i)
	for i in stations_in:
		_beam(i, y0, y1)
	for k in stations_in.size() - 1:
		_girders(stations_in[k], stations_in[k + 1], y0, y1)
	_trimmers(y0, y1)
	for seg in hull.stations.size() - 1:
		_plates(seg)
	target.phase = phase_was


## The frame's inner line at station `s` (where a beam there must stop): its ring members'
## inner faces (deeper where the skin tapers past the station), less the gap.
func inner(s: int) -> PackedVector2Array:
	return FrameParts.inset(hull.centre_line(hull.frame_profile(s), s), hull.depth * 0.5 + FrameHull.GAP)


## How far the deck may reach either side at heights y0..y1 at station `s` ([-x, +x]).
func reach(s: int, y0: float, y1: float) -> Vector2:
	var poly := inner(s)
	var lo := -INF
	var hi := INF
	for y: float in [y0, y1]:
		var span := _span(poly, y)
		lo = maxf(lo, span.x)
		hi = minf(hi, span.y)
	return Vector2(lo, hi)


## Where a horizontal line at `y` crosses a convex polygon ([min x, max x]).
static func _span(poly: PackedVector2Array, y: float) -> Vector2:
	var lo := INF
	var hi := -INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		if (a.y - y) * (b.y - y) > 0.0 or absf(a.y - b.y) < 1e-6:
			if absf(a.y - y) < 1e-6:
				lo = minf(lo, a.x)
				hi = maxf(hi, a.x)
			continue
		var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
		lo = minf(lo, x)
		hi = maxf(hi, x)
	return Vector2(lo, hi)


## Paths: a station's and a bay's, under the deck's level if it has one.
func _st(i: int) -> String:
	return hull._st(i) if level == "" else "%s/deck:%s/st:%s" % [hull.name, level, hull.label(i)]


func _bay(i: int) -> String:
	return hull._bay(i) if level == "" else "%s/deck:%s/bay:%s" % [hull.name, level, hull.label(i)]


func _unique(path: String) -> String:
	var n: int = _named.get(path, 0)
	_named[path] = n + 1
	return path if n == 0 else "%s/%d" % [path, n]


## The opening a beam at `z` would cross, between which girders: [left girder, right girder]
## indices, or [] if none.
func _split_at(z: float) -> Array:
	for o in openings:
		if z > o.position.y - beam.x * 0.5 - FrameHull.GAP and z < o.end.y + beam.x * 0.5 + FrameHull.GAP:
			var left := -1
			var right := -1
			for g in girder_x.size():
				if girder_x[g] <= o.position.x:
					left = g
				if girder_x[g] >= o.end.x and right < 0:
					right = g
			if left >= 0 and right >= 0:
				return [left, right]
	return []


func _beam(i: int, y0: float, y1: float) -> void:
	var z := hull.ring_z(i)
	var span := reach(i, y0, y1)
	var lo := span.x + FrameHull.GAP
	var hi := span.y - FrameHull.GAP
	var pieces: Array = [[lo, hi, -1, -1]]
	var split := _split_at(z)
	if not split.is_empty():
		var gl: float = girder_x[split[0]]
		var gr: float = girder_x[split[1]]
		pieces = [[lo, gl - girder.x * 0.5 - FrameHull.GAP, -1, split[0]], [gr + girder.x * 0.5 + FrameHull.GAP, hi, split[1], -1]]
	var path := "%s/beam" % _st(i)
	var made: Array[PartData] = []
	var y := (y0 + y1) * 0.5
	for k in pieces.size():
		var a: float = pieces[k][0]
		var b: float = pieces[k][1]
		if b - a < 0.1:
			continue
		var name := path if pieces.size() == 1 else "%s/%d" % [path, k]
		var size := Vector3(b - a, beam.y, beam.x)
		var p := target.part("DeckBeam", PartData.Kind.FRAME, PartShapes.box(size), Transform3D(Basis(), Vector3((a + b) * 0.5, y, z)),
				frame_mat, "", 0.5, null, name)
		made.append(p)
		_under.append({"part": p, "a": Vector3(a, y1, z), "b": Vector3(b, y1, z), "name": "st:%s" % hull.label(i), "station": i})
		# Its ends: welded to the ring member it butts against, or to the girder it stops at.
		for end in 2:
			var x := a if end == 0 else b
			var g: int = pieces[k][2 + end] if pieces.size() > 1 else -1
			var at := Vector3(x + (-1.0 if end == 0 else 1.0) * FrameHull.GAP * 0.5, y, z)
			var seam := Vector2(beam.y, beam.x)
			if g >= 0:
				continue   # welded once its girder exists (`_girders`)
			var ring := hull.ring_near(i, at)
			if ring:
				welds.append(target.join(p, ring, ConnectionData.Kind.WELD, at, Vector3.RIGHT, Vector3.UP, seam,
						"%s/weld:%s" % [name, ring.path.get_slice("/", ring.path.get_slice_count("/") - 1)]))
	beams[i] = made


func _girders(s0: int, s1: int, y0: float, y1: float) -> void:
	var za := hull.ring_z(s0) + beam.x * 0.5 + FrameHull.GAP
	var zb := hull.ring_z(s1) - beam.x * 0.5 - FrameHull.GAP
	var split_a := not _split_at(hull.ring_z(s0)).is_empty()
	var split_b := not _split_at(hull.ring_z(s1)).is_empty()
	var row: Array[PartData] = []
	var y := (y0 + y1) * 0.5
	for g in girder_x.size():
		var x := girder_x[g]
		var a := za
		var b := zb
		if _through_opening(x, za, zb):
			row.append(null)
			continue
		# Through a split station the girders run on and meet end to end over it.
		if split_a and _girder_crosses(g, hull.ring_z(s0)):
			a = hull.ring_z(s0) + FrameHull.GAP * 0.5
		if split_b and _girder_crosses(g, hull.ring_z(s1)):
			b = hull.ring_z(s1) - FrameHull.GAP * 0.5
		var size := Vector3(girder.x, girder.y, b - a)
		var p := target.part("DeckGirder", PartData.Kind.FRAME, PartShapes.box(size), Transform3D(Basis(), Vector3(x, y, (a + b) * 0.5)),
				frame_mat, "", 0.5, null, "%s/girder/%d" % [_bay(s0), g])
		row.append(p)
		_under.append({"part": p, "a": Vector3(x, y1, a), "b": Vector3(x, y1, b), "name": "girder:%d" % g})
		var seam := Vector2(girder.y, girder.x)
		for end in 2:
			var s := s0 if end == 0 else s1
			var z := a if end == 0 else b
			var at := Vector3(x, y, z - (1.0 if end == 0 else -1.0) * FrameHull.GAP * 0.5)
			var role := "fore" if end == 0 else "aft"
			if (split_a if end == 0 else split_b) and _girder_crosses(g, hull.ring_z(s)):
				# Meets the next bay's girder over the split station: the aft one welds to it.
				if end == 0:
					var before: Array = girders.get(_bay_before(s0), [])
					if g < before.size() and before[g] != null:
						welds.append(target.join(p, before[g], ConnectionData.Kind.WELD, at, Vector3.BACK, Vector3.UP, seam,
								"%s/weld:%s" % [p.path, role]))
				continue
			var holder := _beam_at(s, x)
			if holder:
				welds.append(target.join(p, holder, ConnectionData.Kind.WELD, at, Vector3.BACK, Vector3.UP, seam,
						"%s/weld:%s" % [p.path, role]))
	girders[s0] = row
	# A split station's stubs end at these girders: weld them on.
	for s: int in [s0]:
		if not split_a:
			continue
		var stubs: Array = beams.get(s, [])
		var split := _split_at(hull.ring_z(s))
		for k in stubs.size():
			var stub: PartData = stubs[k]
			var g: int = split[k] if k < split.size() else -1
			if g < 0 or g >= row.size() or row[g] == null:
				continue
			var gx := girder_x[g] + (-1.0 if k == 0 else 1.0) * (girder.x * 0.5 + FrameHull.GAP * 0.5)
			welds.append(target.join(stub, row[g], ConnectionData.Kind.WELD, Vector3(gx, y, hull.ring_z(s)), Vector3.RIGHT,
					Vector3.UP, Vector2(beam.y, beam.x), "%s/weld:girder:%d" % [stub.path, g]))


## The bay index before station `s` that has girders (the girders' row keys are their bays).
func _bay_before(s: int) -> int:
	var best := -1
	for key: int in girders:
		if key < s:
			best = maxi(best, key)
	return best


## Whether a girder at `x` from za to zb would run through an opening (inside its width and
## along its length): it is left out of that bay.
func _through_opening(x: float, za: float, zb: float) -> bool:
	var half := girder.x * 0.5 + FrameHull.GAP
	for o in openings:
		if x + half > o.position.x and x - half < o.end.x and za < o.end.y + trimmer_clear and zb > o.position.y - trimmer_clear:
			return true
	return false


## Whether girder `g` runs through the opening a beam at `z` would cross (it frames it).
func _girder_crosses(g: int, z: float) -> bool:
	var split := _split_at(z)
	return not split.is_empty() and (g == split[0] or g == split[1])


## The beam (or the stub of a split one) under `x` at station `s`.
func _beam_at(s: int, x: float) -> PartData:
	for p: PartData in beams.get(s, []):
		var hit := false
		for u: Dictionary in _under:
			if u["part"] == p:
				hit = x >= (u["a"] as Vector3).x - 0.01 and x <= (u["b"] as Vector3).x + 0.01
		if hit:
			return p
	return null


## A trimmer across each opening's end where no beam frames it, welded to the girders either
## side.
func _trimmers(y0: float, y1: float) -> void:
	var y := (y0 + y1) * 0.5
	for o in openings:
		for end in 2:
			var z := o.position.y - trimmer_clear - beam.x * 0.5 if end == 0 else o.end.y + trimmer_clear + beam.x * 0.5
			var near := false
			for i: int in beams:
				near = near or absf(hull.ring_z(i) - z) < beam.x + FrameHull.GAP
			if near or z < z0 or z > z1:
				continue
			var gl := -1
			var gr := -1
			for g in girder_x.size():
				if girder_x[g] <= o.position.x:
					gl = g
				if girder_x[g] >= o.end.x and gr < 0:
					gr = g
			if gl < 0 or gr < 0:
				continue
			var seg := _seg_at(z)
			var row: Array = girders.get(seg, [])
			if row.size() <= gr or row[gl] == null or row[gr] == null:
				continue
			var a := girder_x[gl] + girder.x * 0.5 + FrameHull.GAP
			var b := girder_x[gr] - girder.x * 0.5 - FrameHull.GAP
			var p := target.part("DeckTrimmer", PartData.Kind.FRAME, PartShapes.box(Vector3(b - a, beam.y, beam.x)),
					Transform3D(Basis(), Vector3((a + b) * 0.5, y, z)), frame_mat, "", 0.5, null, _unique("%s/trimmer" % _bay(seg)))
			trimmers.append(p)
			_under.append({"part": p, "a": Vector3(a, y1, z), "b": Vector3(b, y1, z), "name": "trimmer:%d" % end})
			var seam := Vector2(beam.y, beam.x)
			welds.append(target.join(p, row[gl], ConnectionData.Kind.WELD, Vector3(a - FrameHull.GAP * 0.5, y, z), Vector3.RIGHT,
					Vector3.UP, seam, "%s/weld:girder:%d" % [p.path, gl]))
			welds.append(target.join(p, row[gr], ConnectionData.Kind.WELD, Vector3(b + FrameHull.GAP * 0.5, y, z), Vector3.RIGHT,
					Vector3.UP, seam, "%s/weld:girder:%d" % [p.path, gr]))


## The bay (segment) whose span holds z.
func _seg_at(z: float) -> int:
	for seg in hull.stations.size() - 1:
		if z >= hull.ring_z(seg) and z < hull.ring_z(seg + 1):
			return seg
	return 0 if z < hull.ring_z(0) else hull.stations.size() - 2


## The plates of bay `seg`: a row from its station's beam to the next (from the deck's ends at
## the first and last bays), one plate per lane between the girders, its outer edges following
## the hull's taper, cut round the openings.
func _plates(seg: int) -> void:
	var last := hull.stations.size() - 2
	var za := z0 if seg == 0 else hull.ring_z(seg)
	var zb := z1 if seg == last else hull.ring_z(seg + 1)
	za = maxf(za, z0)
	zb = minf(zb, z1)
	if zb - za < 0.1:
		return
	var y0 := top - plate
	var ra := reach_at(za, y0, top)
	var rb := reach_at(zb, y0, top)
	var inner_x: Array[float] = []
	for x in girder_x:
		if x > maxf(ra.x, rb.x) + 0.1 and x < minf(ra.y, rb.y) - 0.1 and not _through_opening(x, za, zb):
			inner_x.append(x)
	var lanes := inner_x.size() + 1
	for lane in lanes:
		var l0 := ra.x if lane == 0 else inner_x[lane - 1]
		var l1 := rb.x if lane == 0 else inner_x[lane - 1]
		var r0 := ra.y if lane == lanes - 1 else inner_x[lane]
		var r1 := rb.y if lane == lanes - 1 else inner_x[lane]
		var outline := PackedVector2Array([Vector2(l0, za), Vector2(r0, za), Vector2(r1, zb), Vector2(l1, zb)])
		var pieces := _cut(outline)
		var base := "%s/deck/%d" % [_bay(seg), lane]
		for k in pieces.size():
			_plate(pieces[k], base if pieces.size() == 1 else "%s/s%d" % [base, k], seg)


## How far the deck may reach either side at z, heights y0..y1 ([-x, +x]): the hull's outline
## there (between its stations') brought in to the frame's inner line, and `half_width`.
func reach_at(z: float, y0: float, y1: float) -> Vector2:
	var n := hull.stations.size()
	var seg := 0
	while seg < n - 2 and z > float(hull.stations[seg + 1]["z"]):
		seg += 1
	var za: float = hull.stations[seg]["z"]
	var zb: float = hull.stations[seg + 1]["z"]
	var t := clampf((z - za) / maxf(zb - za, 0.001), 0.0, 1.0)
	var pa: PackedVector2Array = hull.stations[seg]["profile"]
	var pb: PackedVector2Array = hull.stations[seg + 1]["profile"]
	var profile := PackedVector2Array()
	for k in pa.size():
		profile.append(pa[k].lerp(pb[k], t))
	var poly := FrameParts.inset(profile, hull.skin + FrameHull.GAP + hull.depth + FrameHull.GAP)
	var lo := -INF
	var hi := INF
	for y: float in [y0, y1]:
		var span := _span(poly, y)
		lo = maxf(lo, span.x)
		hi = minf(hi, span.y)
	if half_width.is_valid():
		var hw: float = half_width.call(z)
		lo = maxf(lo, -hw)
		hi = minf(hi, hw)
	return Vector2(lo, hi)


## A lane's outline (x, z) less the openings, as convex pieces (cut in strips across the
## openings' x, then rows).
func _cut(outline: PackedVector2Array) -> Array:
	var lo := Vector2(INF, INF)
	var hi := -lo
	for p in outline:
		lo = lo.min(p)
		hi = hi.max(p)
	var hit := false
	for o in openings:
		hit = hit or o.intersects(Rect2(lo, hi - lo))
	if not hit:
		return [outline]
	var cuts: Array[float] = [lo.x - 1.0, hi.x + 1.0]
	for o in openings:
		cuts.append(o.position.x)
		cuts.append(o.end.x)
	cuts.sort()
	var out: Array = []
	for i in cuts.size() - 1:
		var a := cuts[i]
		var b := cuts[i + 1]
		if b - a < 0.02:
			continue
		var spans: Array = [[lo.y - 1.0, hi.y + 1.0]]
		for o in openings:
			if (a + b) * 0.5 <= o.position.x or (a + b) * 0.5 >= o.end.x:
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
			var box := PackedVector2Array([Vector2(a, s[0]), Vector2(b, s[0]), Vector2(b, s[1]), Vector2(a, s[1])])
			var got := Geometry2D.intersect_polygons(outline, box)
			if not got.is_empty() and absf(_area(got[0])) > 0.002:
				out.append(got[0])
	return out


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## One plate over `outline` (x, z): its look the outline (edge to edge with its neighbours), its
## collision held back half the gap all round; spot welded to every member under it.
func _plate(outline: PackedVector2Array, path: String, bay: int) -> void:
	var c := Vector2.ZERO
	for p in outline:
		c += p
	c /= float(outline.size())
	var local := PackedVector2Array()
	for p in outline:
		local.append(p - c)
	var look := FrameParts.plate(local, plate, groove, 0.0)
	var held := FrameParts.plate(FrameParts.inset(local, FrameHull.GAP * 0.5), plate, 0.0, 0.0)
	var p := target.part("DeckPlate", PartData.Kind.HULL, _looks_held(look, held), Transform3D(Basis(), Vector3(c.x, top, c.y)),
			plate_mat, "", 1.0, null, path)
	plates.append(p)
	# Spots along every member under it, on its top face, a margin in from its edges.
	for u: Dictionary in _under:
		var a3: Vector3 = u["a"]
		var b3: Vector3 = u["b"]
		var a2 := Vector2(a3.x, a3.z)
		var b2 := Vector2(b3.x, b3.z)
		var seg := clip_segment(a2, b2, outline, 0.04)
		if seg.is_empty():
			# A member under the plate's edge (the seam over its middle): its row a little in on
			# this plate's side.
			var across := (b2 - a2).orthogonal().normalized()
			var w := (beam.x if absf(across.y) > absf(across.x) else girder.x) * 0.25
			var shift := across * w * signf(across.dot(c - (a2 + b2) * 0.5))
			seg = clip_segment(a2 + shift, b2 + shift, outline, 0.01)
		if seg.is_empty():
			continue
		var s0: Vector2 = seg[0]
		var s1: Vector2 = seg[1]
		# A beam at the bay's own stations is its fore or aft (a station inserted behind it
		# renames nothing here).
		var under: String = u["name"]
		if u.has("station"):
			under = "fore" if int(u["station"]) == bay else ("aft" if int(u["station"]) == bay + 1 else under)
		var n := maxi(1, int(ceil(s0.distance_to(s1) / spot_pitch))) + 1
		for k in n:
			var at := s0.lerp(s1, float(k) / float(n - 1)) if n > 1 else (s0 + s1) * 0.5
			spots.append(target.join(p, u["part"], ConnectionData.Kind.SPOT, Vector3(at.x, top, at.y), Vector3.UP, Vector3.ZERO,
					Vector2.ZERO, "%s/spot:%s/%d" % [path, under, k]))


## The part of segment a..b inside convex `poly` brought in by `m`, as [from, to], or [] if none
## (or a sliver under 2 cm).
static func clip_segment(a: Vector2, b: Vector2, poly: PackedVector2Array, m: float) -> Array:
	var inner := FrameParts.inset(poly, m)
	var t0 := 0.0
	var t1 := 1.0
	var n := inner.size()
	var centre := Vector2.ZERO
	for p in inner:
		centre += p
	centre /= float(n)
	for i in n:
		var p := inner[i]
		var q := inner[(i + 1) % n]
		var e := q - p
		var nrm := Vector2(e.y, -e.x)
		if nrm.dot(centre - p) < 0.0:
			nrm = -nrm   # pointing inside
		var da := nrm.dot(a - p)
		var db := nrm.dot(b - p)
		if da < 0.0 and db < 0.0:
			return []
		if da < 0.0:
			t0 = maxf(t0, da / (da - db))
		elif db < 0.0:
			t1 = minf(t1, da / (da - db))
	if t1 - t0 < 0.001 or a.lerp(b, t0).distance_to(a.lerp(b, t1)) < 0.02:
		return []
	return [a.lerp(b, t0), a.lerp(b, t1)]


## A shape drawn as `look` (its recipe, for the ship file) with the collision `held` keeps.
static func _looks_held(look: PartShapes.PartShape, held: PartShapes.PartShape) -> PartShapes.PartShape:
	var shape := PartShapes.PartShape.new()
	shape.mesh = look.mesh
	shape.recipe = look.recipe
	shape.collision = held.collision
	shape.volume = held.volume
	return shape


# --- Services (docs/SHIP_FRAME_PLAN.md 4.5) -----------------------------------------------

## Adds the cavity under this deck to `graph` ("deck" lanes): along both faces of every beam
## and trimmer across the ship and both sides of every girder along it, at the members'
## mid-depth; a lane on a beam's face is cut where a girder meets it, with a step through the
## girder's web there, and steps through the beam's web join its two faces at each cut and at
## its ends (cables through the lightening holes); a beam's ends step onto the hull's ring
## lanes beside them, and the girders' ends onto the beams' faces. Call after `build` and the
## hull's `add_lanes`.
func add_lanes(graph: FrameGraph) -> void:
	var off := FrameGraph.OFF_FACE
	var across: Array[PartData] = []
	for i: int in beams:
		for b: PartData in beams[i]:
			across.append(b)
	across.append_array(trimmers)
	var along: Array[PartData] = []
	for seg: int in girders:
		for g: PartData in girders[seg]:
			if g:
				along.append(g)
	for m in across:
		var box := _box_of(m)
		var y := box.get_center().y
		var cuts: Array = []   # [x from, x to, girder]
		for g in along:
			var gb := _box_of(g)
			if gb.end.x < box.position.x or gb.position.x > box.end.x:
				continue
			if gb.position.z > box.end.z + 0.06 or gb.end.z < box.position.z - 0.06:
				continue
			cuts.append([gb.position.x - off, gb.end.x + off, g])
		cuts.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
		var xs: Array[float] = [box.position.x]
		for c: Array in cuts:
			xs.append(float(c[0]))
			xs.append(float(c[1]))
		xs.append(box.end.x)
		for side: float in [-1.0, 1.0]:
			var z := box.position.z - off if side < 0.0 else box.end.z + off
			for k in range(0, xs.size() - 1, 2):
				if xs[k + 1] - xs[k] > 0.03:
					graph.add_lane("deck", Vector3(xs[k], y, z), Vector3(xs[k + 1], y, z), Vector3(0.0, 0.0, side), Vector3.DOWN, m)
			for c: Array in cuts:
				var exempt: Array[int] = [(c[2] as PartData).id]
				graph.add_step(Vector3(c[0], y, z), Vector3(c[1], y, z), false, exempt)
		var through: Array[int] = [m.id]
		for x in xs:
			graph.add_step(Vector3(x, y, box.position.z - off), Vector3(x, y, box.end.z + off), false, through)
		for x: float in [box.position.x, box.end.x]:
			for z: float in [box.position.z - off, box.end.z + off]:
				graph.link_nearest(Vector3(x, y, z), ["ring"], through, true, 2)
	for g in along:
		var gb := _box_of(g)
		var y := gb.get_center().y
		for side: float in [-1.0, 1.0]:
			var x := gb.position.x - off if side < 0.0 else gb.end.x + off
			var a := Vector3(x, y, gb.position.z)
			var b := Vector3(x, y, gb.end.z)
			graph.add_lane("deck", a, b, Vector3(side, 0.0, 0.0), Vector3.DOWN, g)
			for end: Vector3 in [a, b]:
				graph.link_nearest(end, ["deck"], [], false, 2, 0.06)


## Feeds for kit standing on this deck between its beams: for each point (ship space, on the
## deck), a lane under the plate there ("deck") along the ship from under the point to the
## nearest beam (or trimmer) face in its bay, stepping down onto that face's lane. Call after
## `add_lanes`.
func add_feeds(graph: FrameGraph, points: Array) -> void:
	var off := FrameGraph.OFF_FACE
	var under := top - plate - off
	var across: Array[PartData] = []
	for i: int in beams:
		for b: PartData in beams[i]:
			across.append(b)
	across.append_array(trimmers)
	for at: Vector3 in points:
		if absf(at.y - top) > 0.05 or at.z < z0 - 0.05 or at.z > z1 + 0.05:
			continue
		var best := INF
		var face := 0.0
		var by: PartData = null
		for m in across:
			var box := _box_of(m)
			if at.x < box.position.x or at.x > box.end.x:
				continue
			for z: float in [box.position.z - off, box.end.z + off]:
				if absf(z - at.z) < best:
					best = absf(z - at.z)
					face = z
					by = m
		if by == null or best < 0.01:
			continue
		var plate_over: PartData = null
		for p in plates:
			var pb := _box_of(p)
			if at.x >= pb.position.x and at.x <= pb.end.x and at.z >= pb.position.z and at.z <= pb.end.z:
				plate_over = p
		var a := Vector3(at.x, under, at.z)
		var b := Vector3(at.x, under, face)
		graph.add_lane("deck", a, b, Vector3.DOWN, Vector3.RIGHT, plate_over)
		graph.link_nearest(b, ["deck"], [], false, 2, 0.12)


## A member's box (ship space).
func _box_of(p: PartData) -> AABB:
	return p.local_transform * target.parts_model().part_visual(p.id).get_aabb()
