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
	for r: Dictionary in d.rooms.values():
		var rect := Rect2(r.x, r.z, r.w, r.d)
		var deck := int(r.deck)
		s.floor_area += rect.get_area()
		# The four sides, with the outward normal: start sides (-X, -Z) and end sides (+X, +Z).
		var sides := [
			[Vector2(rect.position.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Vector2(-1, 0), false],
			[Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.end.y), Vector2(1, 0), true],
			[Vector2(rect.position.x, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(0, -1), false],
			[Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.end.y), Vector2(0, 1), true],
		]
		for side: Array in sides:
			s._split_side(d, deck, r.id, side[0], side[1], side[2], side[3])
		# Floors with no room under them, roofs with none over: outer hull too.
		s.outer_area += _uncovered(d, rect, deck - 1) + _uncovered(d, rect, deck + 1)
	for e in s.outer_edges:
		s.outer_len += (e.a as Vector2).distance_to(e.b)
	for e in s.inner_edges:
		s.inner_len += (e.a as Vector2).distance_to(e.b)
	s.outer_area += s.outer_len * h
	s.inner_area = s.inner_len * h
	s.frame_m = s.outer_len * h / spacing + s.floor_area / spacing
	return s


## Splits one room side into stretches that face space (outer) and stretches against another
## room (inner; kept only from the end side, so each shared wall counts once).
func _split_side(d: DesignRecord, deck: int, room_id: String, a: Vector2, b: Vector2, normal: Vector2,
		end_side: bool) -> void:
	var length := a.distance_to(b)
	var steps := maxi(int(round(length / STEP)), 1)
	var dir := (b - a) / float(steps)
	var run_start := a
	var run_inner := false
	for i in steps + 1:
		var inner := false
		if i < steps:
			var mid := a + dir * (i + 0.5)
			var other := d.room_at(deck, mid + normal * 0.05)
			inner = other != "" and other != room_id
		if i == 0:
			run_inner = inner
			continue
		if i == steps or inner != run_inner:
			var p := a + dir * i
			if run_inner:
				if end_side:
					inner_edges.append({"deck": deck, "a": run_start, "b": p})
			else:
				outer_edges.append({"deck": deck, "a": run_start, "b": p})
			run_start = p
			run_inner = inner


static func _uncovered(d: DesignRecord, rect: Rect2, deck: int) -> float:
	var cell := 0.5
	var area := 0.0
	var x := rect.position.x + cell * 0.5
	while x < rect.end.x:
		var z := rect.position.y + cell * 0.5
		while z < rect.end.y:
			if d.room_at(deck, Vector2(x, z)) == "":
				area += cell * cell
			z += cell
		x += cell
	return area
