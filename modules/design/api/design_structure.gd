class_name DesignStructure
extends RefCounted
## The hull built round a design's rooms (plan 2.2: frames, outer and inner walls). Worked out
## from the rooms, so moving a room moves its walls: every room side is outer hull where it
## faces space and an inner wall where it meets another room on the same deck. The frame
## stands on the outer walls and under the decks every `spacing` m. What it is built from is
## the design's `structure` (frame weight, spacing, hull plating, inner walls), each swappable
## with instant cost and mass.

## Each choice: id -> {name, cost (credits per m or m2), mass (kg per m or m2), hours (per m or m2)}.
const OPTIONS := {
	"frame": {
		"light": {"name": "Light frame", "cost": 45.0, "mass": 14.0, "hours": 0.15},
		"standard": {"name": "Standard frame", "cost": 75.0, "mass": 24.0, "hours": 0.2},
		"heavy": {"name": "Heavy frame", "cost": 130.0, "mass": 42.0, "hours": 0.3},
	},
	"hull": {
		"thin": {"name": "Thin hull plating", "cost": 110.0, "mass": 26.0, "hours": 0.25},
		"standard": {"name": "Standard hull plating", "cost": 190.0, "mass": 42.0, "hours": 0.35},
		"armoured": {"name": "Armoured hull plating", "cost": 420.0, "mass": 96.0, "hours": 0.6},
	},
	"inner": {
		"panel": {"name": "Panel inner walls", "cost": 55.0, "mass": 11.0, "hours": 0.12},
		"bulkhead": {"name": "Bulkhead inner walls", "cost": 140.0, "mass": 34.0, "hours": 0.25},
	},
}
## Frame spacings the designer can pick, m.
const SPACINGS: PackedFloat32Array = [1.0, 2.0, 3.0]
## Deck plating, per m2 of floor.
const DECK := {"name": "Deck plating", "cost": 80.0, "mass": 22.0, "hours": 0.2}
## Sampling step along walls and over floors, m.
const STEP := 0.25

## What measure() returns.
var outer_edges: Array[Dictionary] = []  # {deck, a: Vector2, b: Vector2}
var inner_edges: Array[Dictionary] = []  # each shared wall once
var outer_len := 0.0
var inner_len := 0.0
## Outer hull: the outer walls plus floors with nothing under them and roofs with nothing over.
var outer_area := 0.0
var inner_area := 0.0
var floor_area := 0.0
## Frame members, m: posts up the outer walls and beams under the decks, every `spacing`.
var frame_m := 0.0


static func option(kind: String, id: String) -> Dictionary:
	var opts: Dictionary = OPTIONS.get(kind, {})
	return opts.get(id, opts.values()[0] if not opts.is_empty() else {})


## Steps a structure choice to the next one: the next option id, or the next spacing.
static func next_choice(kind: String, current: Variant) -> Variant:
	if kind == "spacing":
		var i := Array(SPACINGS).find(float(current))
		return SPACINGS[(i + 1) % SPACINGS.size()]
	var ids: Array = (OPTIONS.get(kind, {}) as Dictionary).keys()
	return ids[(ids.find(str(current)) + 1) % ids.size()]


static func measure(d: DesignRecord) -> DesignStructure:
	var s := DesignStructure.new()
	var h := d.deck_height
	var spacing := maxf(float(d.structure.get("spacing", 2.0)), 0.5)
	# Decks with a drawn hull: its sides are the outer hull and the deck is plated out to them.
	for deck in s._hull_decks(d):
		var outline := d.hull_outline(deck)
		for i in outline.size():
			s.outer_edges.append({"deck": deck, "a": outline[i], "b": outline[(i + 1) % outline.size()]})
		s.floor_area += absf(_area(outline))
		var box := _bounds(outline)
		s.outer_area += _uncovered(d, box, deck, deck - 1) + _uncovered(d, box, deck, deck + 1)
	for r: Dictionary in d.rooms.values():
		var rect := Rect2(r.x, r.z, r.w, r.d)
		var deck := int(r.deck)
		var hulled := d.hull_outline(deck).size() >= 3
		if not hulled:
			s.floor_area += DesignRecord.room_area(r)
		# Its sides, each with the outward normal: start sides (-X, -Z) and end sides (+X, +Z),
		# a shaped room's every edge.
		var poly := DesignRecord.room_poly(r)
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			if a.distance_to(b) < 0.01:
				continue
			var dir := (b - a).normalized()
			var n := Vector2(-dir.y, dir.x)
			if DesignRecord.room_has(r, (a + b) * 0.5 + n * 0.05):
				n = -n
			# Listed from the low end, as the four sides of a box are.
			var lo := a if (a.x + a.y) <= (b.x + b.y) else b
			var hi := b if lo == a else a
			# A wall two rooms share is listed once, by the room on its far (+X, else +Z) side.
			s._split_side(d, deck, r.id, lo, hi, n, n.x > 0.001 or absf(n.x) <= 0.001 and n.y > 0.0)
		# Floors with no room under them, roofs with none over: outer hull too.
		if not hulled:
			s.outer_area += _uncovered(d, rect, deck, deck - 1) + _uncovered(d, rect, deck, deck + 1)
	# Inner walls drawn by hand.
	for w: Dictionary in d.walls.values():
		s.inner_edges.append({"deck": int(w.deck), "a": _v(w.a), "b": _v(w.b), "wall": w.id})
	for e in s.outer_edges:
		s.outer_len += (e.a as Vector2).distance_to(e.b)
	for e in s.inner_edges:
		s.inner_len += (e.a as Vector2).distance_to(e.b)
	s.outer_area += s.outer_len * h
	s.inner_area = s.inner_len * h
	var placed := 0.0
	for b: Dictionary in d.beams.values():
		placed += _v(b.a).distance_to(_v(b.b))
	s.frame_m = s.outer_len * h / spacing + s.floor_area / spacing + placed
	return s


## The nearest point on a deck's outer hull to `p`: {point, normal (outward), dist, angle (of
## the normal, radians from +X towards +Z)}, or {} if the deck has no outer hull.
static func nearest_hull(d: DesignRecord, deck: int, p: Vector2, st: DesignStructure = null) -> Dictionary:
	if st == null:
		st = measure(d)
	var best := {}
	for e: Dictionary in st.outer_edges:
		if int(e.deck) != deck:
			continue
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		if a.distance_to(b) < 0.01:
			continue
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var dist := q.distance_to(p)
		if best.is_empty() or dist < float(best.dist):
			var dir := (b - a).normalized()
			var n := Vector2(-dir.y, dir.x)
			var mid := (a + b) * 0.5
			if on_deck(d, deck, mid + n * 0.1):
				n = -n
			best = {"point": q, "normal": n, "dist": dist, "angle": n.angle()}
	return best


## Whether a point is on a deck's floor: inside its hull where it has one, else in a room.
static func on_deck(d: DesignRecord, deck: int, p: Vector2) -> bool:
	var outline := d.hull_outline(deck)
	if outline.size() >= 3:
		return Geometry2D.is_point_in_polygon(p, outline)
	return d.room_at(deck, p) != ""


func _hull_decks(d: DesignRecord) -> Array[int]:
	var out: Array[int] = []
	for dk: String in d.hull:
		if d.hull_outline(int(dk)).size() >= 3:
			out.append(int(dk))
	out.sort()
	return out


static func _v(p: Variant) -> Vector2:
	return Vector2(float(p[0]), float(p[1]))


## A polygon's signed area, m2.
static func _area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## Splits one room side into stretches that face space (outer) and stretches against another
## room (inner; kept only from the end side, so each shared wall counts once).
func _split_side(d: DesignRecord, deck: int, room_id: String, a: Vector2, b: Vector2, normal: Vector2,
		end_side: bool) -> void:
	var length := a.distance_to(b)
	var steps := maxi(int(round(length / STEP)), 1)
	var dir := (b - a) / float(steps)
	var hulled := d.hull_outline(deck).size() >= 3
	var run_start := a
	var run_kind := 0
	for i in steps + 1:
		# 0 outer hull, 1 against another room, 2 open deck inside the hull, 3 on the hull itself.
		var kind := 0
		if i < steps:
			var mid := a + dir * (i + 0.5)
			var at := mid + normal * 0.05
			var other := d.room_at(deck, at)
			if other == room_id:
				kind = 4  # its own floor round a shaped room's inside corner: no wall
			elif other != "":
				kind = 1
			elif hulled:
				kind = 2 if on_deck(d, deck, at) else 3
		if i == 0:
			run_kind = kind
			continue
		if i == steps or kind != run_kind:
			var p := a + dir * i
			if run_kind == 1:
				if end_side:
					inner_edges.append({"deck": deck, "a": run_start, "b": p})
			elif run_kind == 2:
				inner_edges.append({"deck": deck, "a": run_start, "b": p})
			elif run_kind == 0:
				outer_edges.append({"deck": deck, "a": run_start, "b": p})
			run_start = p
			run_kind = kind


## Floor of `deck` within rect with no floor of `other` beside it (over or under), m2.
static func _uncovered(d: DesignRecord, rect: Rect2, deck: int, other: int) -> float:
	var cell := 0.5
	var area := 0.0
	var x := rect.position.x + cell * 0.5
	while x < rect.end.x:
		var z := rect.position.y + cell * 0.5
		while z < rect.end.y:
			var p := Vector2(x, z)
			if on_deck(d, deck, p) and not on_deck(d, other, p):
				area += cell * cell
			z += cell
		x += cell
	return area
