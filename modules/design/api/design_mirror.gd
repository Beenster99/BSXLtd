class_name DesignMirror
extends RefCounted
## Symmetry mode (beenster, 19 Nov): whatever is drawn on one side of a mirror line is drawn
## on the other side too. The line runs through the design's origin:
##   ACROSS (1): the centre line along the ship (x = 0), mirroring port and starboard;
##   ALONG (2): the line across the ship (z = 0), mirroring fore and aft.
## twin(rec, op, axis) gives the mirrored op for an "add" op, or {} when there is none (the
## mirror would land on the original, or the room a part or door needs isn't there).

const OFF := 0
const ACROSS := 1
const ALONG := 2
const NAMES := ["OFF", "X", "Y"]


static func flip(p: Vector2, axis: int) -> Vector2:
	return Vector2(-p.x, p.y) if axis == ACROSS else Vector2(p.x, -p.y)


static func _pts(pts: Array, axis: int) -> Array:
	var out: Array = []
	for p: Variant in pts:
		var q := flip(Vector2(float(p[0]), float(p[1])), axis)
		out.append([q.x, q.y])
	return out


## The mirrored copy of an add op (add_room, add_door, add_component, add_wall, add_beam,
## add_run, add_mount; a batch of them), or {}.
static func twin(rec: DesignRecord, op: Dictionary, axis: int) -> Dictionary:
	if axis == OFF or rec == null:
		return {}
	match str(op.get("op", "")):
		"add_room":
			var r: Dictionary = (op.room as Dictionary).duplicate()
			r.erase("id")
			var x := float(r.x)
			var z := float(r.z)
			if axis == ACROSS:
				r.x = -(x + float(r.w))
			else:
				r.z = -(z + float(r.d))
			if r.get("outline") is Array:
				# A shaped room's corners mirrored inside its box.
				var pts: Array = []
				for p: Variant in r.outline:
					pts.append([float(r.w) - float(p[0]), float(p[1])] if axis == ACROSS else [float(p[0]), float(r.d) - float(p[1])])
				pts.reverse()
				r.outline = pts
			var a := Rect2(x, z, float(r.w), float(r.d))
			if a.intersection(Rect2(float(r.x), float(r.z), float(r.w), float(r.d))).get_area() > 0.01:
				return {}
			return {"op": "add_room", "room": r}
		"add_component":
			var c: Dictionary = (op.component as Dictionary).duplicate()
			c.erase("id")
			var room: Dictionary = rec.rooms.get(str(c.get("room", "")), {})
			var q := flip(Vector2(float(c.x), float(c.z)), axis)
			if q.distance_to(Vector2(float(c.x), float(c.z))) < 0.3 or room.is_empty():
				return {}
			var into := rec.room_at(int(room.deck), q)
			if into == "":
				return {}
			c.room = into
			c.x = q.x
			c.z = q.y
			var rot := int(c.get("rot", 0)) % 4
			# Facing across turns round mirrored port to starboard, facing along fore to aft.
			if axis == ACROSS and rot % 2 == 1 or axis == ALONG and rot % 2 == 0:
				rot = (rot + 2) % 4
			c.rot = rot
			return {"op": "add_component", "component": c}
		"add_door":
			var d: Dictionary = (op.door as Dictionary).duplicate()
			d.erase("id")
			var q := flip(Vector2(float(d.x), float(d.z)), axis)
			if q.distance_to(Vector2(float(d.x), float(d.z))) < 0.3:
				return {}
			d.x = q.x
			d.z = q.y
			var sides := DesignRules.door_sides(rec, d)
			var rooms: Array[String] = []
			for s in sides:
				if rec.rooms.has(s):
					rooms.append(s)
			if rooms.is_empty():
				return {}
			d.a = rooms[0]
			d.b = rooms[1] if rooms.size() > 1 else ""
			return {"op": "add_door", "door": d}
		"add_wall", "add_beam":
			var key := "wall" if op.op == "add_wall" else "beam"
			var e: Dictionary = (op[key] as Dictionary).duplicate(true)
			e.erase("id")
			var m := _pts([e.a, e.b], axis)
			if Vector2(float(m[0][0]), float(m[0][1])).distance_to(Vector2(float(e.a[0]), float(e.a[1]))) < 0.05 \
					and Vector2(float(m[1][0]), float(m[1][1])).distance_to(Vector2(float(e.b[0]), float(e.b[1]))) < 0.05:
				return {}
			e.a = m[0]
			e.b = m[1]
			return {"op": op.op, key: e}
		"add_run":
			var w: Dictionary = (op.run as Dictionary).duplicate(true)
			w.erase("id")
			var pts: Array = w.points
			var m := _pts(pts, axis)
			if m == pts:
				return {}
			w.points = m
			return {"op": "add_run", "run": w}
		"add_mount":
			var h: Dictionary = (op.mount as Dictionary).duplicate()
			h.erase("id")
			if DesignOutside.on_skin(h):
				return _skin_twin(h, axis)
			var q := flip(Vector2(float(h.x), float(h.z)), axis)
			if q.distance_to(Vector2(float(h.x), float(h.z))) < 0.3:
				return {}
			h.x = q.x
			h.z = q.y
			var n := flip(Vector2.from_angle(float(h.angle)), axis)
			h.angle = n.angle()
			return {"op": "add_mount", "mount": h}
	return {}


## A part on the skin (DesignOutside) mirrored: across, onto the matching edge the other side
## (the edges run round the section, so t runs the other way); along, to the other end.
static func _skin_twin(h: Dictionary, axis: int) -> Dictionary:
	var e := int(h.get("edge", 0))
	var q := flip(Vector2(float(h.get("x", 0.0)), float(h.get("z", 0.0))), axis)
	if q.distance_to(Vector2(float(h.get("x", 0.0)), float(h.get("z", 0.0)))) < 0.3:
		return {}
	h.x = q.x
	h.z = q.y
	h.spin = -float(h.get("spin", 0.0))
	if axis == ACROSS:
		if e >= 0:
			h.edge = (DesignFrame.SIDES - e) % DesignFrame.SIDES
			h.t = 1.0 - float(h.get("t", 0.5))
	elif e < 0:
		h.edge = DesignOutside.STERN if e == DesignOutside.NOSE else DesignOutside.NOSE
	if h.has("angle"):
		h.angle = flip(Vector2.from_angle(float(h.angle)), axis).angle()
	return {"op": "add_mount", "mount": h}


## `op` and, with symmetry on, its twin, as one op (a batch: one undo step).
static func with_twin(rec: DesignRecord, op: Dictionary, axis: int) -> Dictionary:
	var t := twin(rec, op, axis)
	return op if t.is_empty() else {"op": "batch", "ops": [op, t]}
