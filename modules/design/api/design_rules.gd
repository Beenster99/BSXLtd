class_name DesignRules
extends RefCounted
## What will not work in a design (plan 2.6). check() returns a list of problems, each
##   {code, severity ("error" | "warning"), text, rooms: [ids], components: [ids], doors: [ids]}
## so a view can light up what a problem names. Errors stop a design being sent to a client;
## warnings are advice.
##
## Components sit at their centre (x, z), turned `rot` quarter turns; their front, where the
## fitter stands, is FRONTS[rot].

const ERROR := "error"
const WARNING := "warning"
## Which way a component faces, by quarter turn: (x, z).
const FRONTS: Array[Vector2] = [Vector2(0, -1), Vector2(-1, 0), Vector2(0, 1), Vector2(1, 0)]
## The narrowest door or walkway a fitter gets through, m.
const MIN_DOOR := 1.0


## `totals`: the design's DesignTotals when already worked out (the bus passes its own).
static func check(d: DesignRecord, cat: DesignCatalog, totals: DesignTotals = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_room_checks(d, cat, out)
	_stair_checks(d, out)
	_door_checks(d, out)
	_route_checks(d, cat, out)
	_component_checks(d, cat, out)
	_ship_checks(d, cat, out, totals)
	_service_checks(d, cat, out)
	_mount_checks(d, cat, out)
	return out


## A hull part must be one that fits on the hull, and sit on the hull (a side's outline, or the
## skin anywhere); parts on the outside must not run into each other, cover an outer door, hang
## past an edge of the hull or face into it.
static func _mount_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	if d.mounts.is_empty():
		return
	var st := DesignStructure.measure(d)
	var skin := false
	for m: Dictionary in d.mounts.values():
		skin = skin or DesignOutside.on_skin(m)
	var plan := DesignOutside.plan_for(d) if skin else {}
	var boxes: Array = []
	for m: Dictionary in d.mounts.values():
		var pt := cat.part(str(m.type))
		if pt == null:
			out.append(_problem("unknown_part", ERROR, "Unknown component %s" % m.type, [], [m.id]))
			continue
		if not pt.hull_mount:
			out.append(_problem("not_hull_part", ERROR, "%s goes inside, not on the hull" % pt.display_name, [], [m.id]))
		if DesignOutside.on_skin(m):
			if not DesignOutside.on_hull(plan, m):
				out.append(_problem("off_hull", ERROR, "%s is not on the hull" % pt.display_name, [], [m.id]))
				continue
		else:
			var near := DesignStructure.nearest_hull(d, int(m.deck), Vector2(m.x, m.z), st)
			if near.is_empty() or float(near.dist) > 0.3:
				out.append(_problem("off_hull", ERROR, "%s is not on the hull" % pt.display_name, [], [m.id]))
				continue
		var xf := mount_transform(d, m, pt, plan)
		boxes.append({"m": m, "pt": pt, "xf": xf, "box": DesignOutside.box_of(xf, pt)})
		if DesignOutside.on_skin(m):
			if DesignOutside.overhang(plan, m, xf, pt) > 0:
				out.append(_problem("mount_overhang", WARNING, "%s hangs past the edge of the %s" % [
						pt.display_name, DesignOutside.face_name(m)], [], [m.id]))
			if DesignOutside.front_blocked(plan, m, xf, pt):
				out.append(_problem("mount_blocked", WARNING, "%s faces into the hull" % pt.display_name, [], [m.id]))
			for o: Dictionary in plan.get("openings", []):
				if _over_opening(plan, o, xf, pt):
					out.append(_problem("mount_over_door", ERROR, "%s is over an outer door" % pt.display_name, [], [m.id]))
					break
	for i in boxes.size():
		var a: Dictionary = boxes[i]
		var ab: Array = a.box
		for j in range(i + 1, boxes.size()):
			var b: Dictionary = boxes[j]
			var bb: Array = b.box
			if DesignOutside.boxes_overlap(ab[0], ab[1], bb[0], bb[1], 0.02):
				out.append(_problem("mount_clash", ERROR, "%s and %s on the hull run into each other" % [
						a.pt.display_name, b.pt.display_name], [], [a.m.id, b.m.id]))
				continue
			# The clear space in front of each (an engine's plume) must be clear of the other.
			for pair: Array in [[a, b], [b, a]]:
				var p0: Dictionary = pair[0]
				var p1: Dictionary = pair[1]
				var fb := DesignOutside.clear_box(plan, p0.m, p0.xf, p0.pt)
				if fb.is_empty():
					continue
				var ob: Array = p1.box
				if DesignOutside.boxes_overlap(fb[0], fb[1], ob[0], ob[1], 0.02):
					out.append(_problem("mount_in_front", WARNING, "%s is in front of %s" % [
							p1.pt.display_name, p0.pt.display_name], [], [p0.m.id, p1.m.id]))


## Whether a part fitted to the skin covers an outer door's opening (DesignFrame's openings: a
## box through a side, a hole in an end plate).
static func _over_opening(plan: Dictionary, o: Dictionary, xf: Transform3D, pt: DesignPartType) -> bool:
	var bx := DesignOutside.box_of(xf, pt)
	if o.has("box"):
		var box: AABB = o.box
		var c := Transform3D(Basis.IDENTITY, box.get_center())
		return DesignOutside.boxes_overlap(bx[0], bx[1], c, box.size, 0.02)
	var st: Array = plan.stations
	var z := float(st[0 if int(o.get("cap", 0)) == 0 else st.size() - 1].z)
	var hole: Rect2 = o.hole
	var c2 := Transform3D(Basis.IDENTITY, Vector3(hole.get_center().x, hole.get_center().y, z))
	return DesignOutside.boxes_overlap(bx[0], bx[1], c2, Vector3(hole.size.x, hole.size.y, 0.6), 0.02)


## Parts that need power with no wire to a source, engines with no fuel line to a pump. Only
## once the design has any wiring (or piping): a layout with none yet is just not wired.
static func _service_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	for kind: String in ["wire", "fuel"]:
		var any := false
		for w: Dictionary in d.runs.values():
			any = any or str(w.kind) == kind
		if not any:
			continue
		var cut := DesignServices.cut_off(d, cat, kind)
		if cut.is_empty():
			continue
		var names: Array = []
		for cid: String in cut:
			var pt := cat.part(str(d.components[cid].type))
			names.append(pt.display_name if pt else cid)
		if kind == "wire":
			out.append(_problem("unpowered", WARNING, "No wire to a power source: %s" % ", ".join(names), [], cut))
		else:
			out.append(_problem("no_fuel", WARNING, "No fuel line to a pump: %s" % ", ".join(names), [], cut))


static func errors(problems: Array[Dictionary]) -> int:
	return problems.filter(func(p): return p.severity == ERROR).size()


## A component's footprint on its deck, m.
static func footprint(c: Dictionary, pt: DesignPartType) -> Rect2:
	var w := pt.size.x
	var dd := pt.size.z
	if int(c.get("rot", 0)) % 2 == 1:
		var s := w
		w = dd
		dd = s
	return Rect2(float(c.x) - w * 0.5, float(c.z) - dd * 0.5, w, dd)


## The clear floor a fitter needs in front of a component, m.
static func access_zone(c: Dictionary, pt: DesignPartType) -> Rect2:
	var f := footprint(c, pt)
	var front := FRONTS[int(c.get("rot", 0)) % 4]
	var a := pt.access
	if front.y < 0:
		return Rect2(f.position.x, f.position.y - a, f.size.x, a)
	if front.y > 0:
		return Rect2(f.position.x, f.end.y, f.size.x, a)
	if front.x < 0:
		return Rect2(f.position.x - a, f.position.y, a, f.size.y)
	return Rect2(f.end.x, f.position.y, a, f.size.y)


## How a hull part is fitted, as walk-inside builds it (and the holotable and the motion module
## read it): its own space (origin on its foot in the middle, front -Z along the hull's outward
## normal). Most stand against the plating halfway up their deck's wall; a landing leg
## (DesignPartType.under_hull) hangs under the hull's edge from the lowest deck's belly.
const MOUNT_WALL := 0.14
const MOUNT_LINING := 0.025
const MOUNT_FLOOR := 0.1
## The belly under the lowest deck's floor, m (deck plate, frame and skin).
const BELLY := 0.4


## A part fitted to the skin anywhere (DesignOutside, the outside designer) sits on the
## proposed frame's skin: `plan` is that frame when the caller has it.
static func mount_transform(d: DesignRecord, m: Dictionary, pt: DesignPartType, plan: Dictionary = {}) -> Transform3D:
	if DesignOutside.on_skin(m):
		return DesignOutside.transform(plan if not plan.is_empty() else DesignOutside.plan_for(d), m, pt)
	var n := Vector2.from_angle(float(m.get("angle", 0.0)))
	var basis := Basis(Vector3.UP, atan2(-n.x, -n.y))
	var p := Vector2(float(m.x), float(m.z))
	if pt.under_hull():
		var decks := d.decks()
		var low := float(decks[0]) if not decks.is_empty() else float(m.deck)
		var under := p - n * (pt.size.z * 0.5 + 0.1)
		return Transform3D(basis, Vector3(under.x, low * d.deck_height - BELLY - pt.size.y, under.y))
	var at := p + n * (MOUNT_WALL * 0.5 + MOUNT_LINING + pt.size.z * 0.5)
	var y := float(m.deck) * d.deck_height + (d.deck_height - MOUNT_FLOOR - pt.size.y) * 0.5
	return Transform3D(basis, Vector3(at.x, y, at.y))


static func _problem(code: String, severity: String, text: String, rooms: Array = [],
		components: Array = [], doors: Array = []) -> Dictionary:
	return {"code": code, "severity": severity, "text": text, "rooms": rooms,
			"components": components, "doors": doors}


static func _label(d: DesignRecord, cat: DesignCatalog, room_id: String) -> String:
	var r: Dictionary = d.rooms.get(room_id, {})
	if r.is_empty():
		return room_id
	if str(r.get("name", "")) != "":
		return str(r.name)
	var rt := cat.room(str(r.type))
	return rt.display_name if rt else str(r.type)


static func _room_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	for deck in d.decks():
		var list := d.rooms_on(deck)
		for i in list.size():
			var a: Dictionary = list[i]
			for j in range(i + 1, list.size()):
				var b: Dictionary = list[j]
				if DesignRecord.rooms_overlap(a, b):
					out.append(_problem("overlap", ERROR, "%s and %s overlap" % [
							_label(d, cat, a.id), _label(d, cat, b.id)], [a.id, b.id]))
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		if rt == null:
			out.append(_problem("unknown_room", ERROR, "Unknown room type %s" % r.type, [r.id]))
			continue
		if not d.room_in_hull(r.id):
			out.append(_problem("outside_hull", ERROR, "%s sticks out of the hull" % _label(d, cat, r.id), [r.id]))
		var w := float(r.w) + 0.01
		var dd := float(r.d) + 0.01
		var fits := (w >= rt.min_size.x and dd >= rt.min_size.y) or (w >= rt.min_size.y and dd >= rt.min_size.x)
		if not fits:
			out.append(_problem("too_small", WARNING, "%s is smaller than %d x %d m" % [
					_label(d, cat, r.id), rt.min_size.x, rt.min_size.y], [r.id]))


## A stairwell with another over it needs room for its flight and a landing at each end
## (DesignStairs), and the room above must have the landing at its head.
static func _stair_checks(d: DesignRecord, out: Array[Dictionary]) -> void:
	var h := d.deck_height
	for r: Dictionary in d.rooms.values():
		if str(r.type) != "stairs":
			continue
		var upper: Dictionary = {}
		for u: Dictionary in d.rooms_on(int(r.deck) + 1):
			if str(u.type) == "stairs" and Rect2(r.x, r.z, r.w, r.d).intersection(Rect2(u.x, u.z, u.w, u.d)).get_area() >= 1.0:
				upper = u
				break
		if upper.is_empty():
			continue
		var f := DesignStairs.flight(r, h)
		var long_side := maxf(float(r.w), float(r.d))
		if not bool(f.fits):
			out.append(_problem("stairs_short", ERROR,
					"Stairwell %s is too short for its stairs: %s m between decks needs %s m (a %s m flight and %s m to step on and off at each end), it is %s m"
					% [DesignRecord.tag(str(r.id)), _m(h), _m(DesignStairs.needs(h)), _m(DesignStairs.run_for(h)),
					_m(DesignStairs.LANDING), _m(long_side)], [r.id]))
		elif not Rect2(upper.x, upper.z, upper.w, upper.d).grow(0.01).encloses(f.head):
			out.append(_problem("stairs_no_head", ERROR,
					"The stairs in %s come up outside the stairwell above: no landing at the top (move or flip the stairs)"
					% DesignRecord.tag(str(r.id)), [r.id, upper.id]))


static func _m(v: float) -> String:
	return ("%d" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


static func _door_checks(d: DesignRecord, out: Array[Dictionary]) -> void:
	for door: Dictionary in d.doors.values():
		if not _door_fits(d, door):
			var what := str(DesignCatalog.door_kind(door).name).to_lower()
			out.append(_problem("door_off_wall", ERROR, "A %s is not on a wall between its rooms, or the wall is too short for it" % what,
					[door.a, door.b].filter(func(x): return str(x) != ""), [], [door.id]))


## An outer door on a shaped room: on one of its edges, with dw of it clear, nothing beyond.
static func _door_on_outline(d: DesignRecord, door: Dictionary, room: Dictionary, p: Vector2, dw: float) -> bool:
	var poly := DesignRecord.room_poly(room)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var length := a.distance_to(b)
		if length < dw:
			continue
		var along := (b - a) / length
		var t := (p - a).dot(along)
		if (a + along * t).distance_to(p) > 0.05 or t < dw * 0.5 - 0.01 or t > length - dw * 0.5 + 0.01:
			continue
		var n := Vector2(-along.y, along.x)
		if DesignRecord.room_has(room, p + n * 0.1):
			n = -n
		return d.room_at(int(door.deck), p + n * 0.1) == ""
	return false


## A door sits on the wall the two rooms share (b = "": on an outer wall of a), with room
## for MIN_DOOR along it.
static func _door_fits(d: DesignRecord, door: Dictionary) -> bool:
	var p := Vector2(float(door.x), float(door.z))
	# The clear wall a door needs: its opening less the jambs' play (MIN_DOOR for a plain door).
	var dw := maxf(MIN_DOOR, DesignCatalog.door_w(door) - 0.2)
	if str(door.b) == "":
		var room: Dictionary = d.rooms.get(str(door.a), {})
		if room.is_empty():
			return false
		if DesignRecord.is_shaped(room):
			return _door_on_outline(d, door, room, p, dw)
		var r := d.room_rect(str(door.a))
		var on_x := (absf(p.x - r.position.x) < 0.05 or absf(p.x - r.end.x) < 0.05) \
				and p.y - dw * 0.5 >= r.position.y - 0.01 and p.y + dw * 0.5 <= r.end.y + 0.01
		var on_z := (absf(p.y - r.position.y) < 0.05 or absf(p.y - r.end.y) < 0.05) \
				and p.x - dw * 0.5 >= r.position.x - 0.01 and p.x + dw * 0.5 <= r.end.x + 0.01
		if not (on_x or on_z):
			return false
		# Outer wall: nothing else on the far side.
		var outward := Vector2.ZERO
		if on_x:
			outward = Vector2(-0.1 if absf(p.x - r.position.x) < 0.05 else 0.1, 0)
		else:
			outward = Vector2(0, -0.1 if absf(p.y - r.position.y) < 0.05 else 0.1)
		return d.room_at(int(door.deck), p + outward) == ""
	var wall := d.shared_wall(str(door.a), str(door.b), dw)
	if wall.is_empty():
		return false
	var along := (wall[1] - wall[0]).normalized()
	var t := (p - wall[0]).dot(along)
	var off := (p - wall[0] - along * t).length()
	var length := wall[0].distance_to(wall[1])
	return off < 0.05 and t >= dw * 0.5 - 0.01 and t <= length - dw * 0.5 + 0.01


## Which rooms can be walked to: from any airlock, through doors and stairwells. Worked out
## the way walk-inside builds the ship (beenster, 19 Nov: the check said no way to the bridge
## where he could walk there): a door is a gap in whatever wall it stands on, so it joins the
## spaces either side of where it stands, whichever rooms it was drawn between; and inside a
## drawn hull, the deck round the rooms is floor too, so doors out onto it join up there.
static func reachable(d: DesignRecord, cat: DesignCatalog) -> Dictionary:
	var links := {}
	for r: String in d.rooms:
		links[r] = []
	for door: Dictionary in d.doors.values():
		var sides := door_sides(d, door)
		if sides.size() < 2 or sides[0] == "" or sides[1] == "":
			continue
		for k in 2:
			if not links.has(sides[k]):
				links[sides[k]] = []
		links[sides[0]].append(sides[1])
		links[sides[1]].append(sides[0])
	# Stairwells join where one stands over another on the next deck.
	var stairs: Array[Dictionary] = []
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		if rt and rt.links_decks:
			stairs.append(r)
	for a in stairs:
		for b in stairs:
			if int(b.deck) == int(a.deck) + 1 and Rect2(a.x, a.z, a.w, a.d).intersection(
					Rect2(b.x, b.z, b.w, b.d)).get_area() >= 1.0:
				links[a.id].append(b.id)
				links[b.id].append(a.id)
	var seen := {}
	var queue: Array = []
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		if rt and rt.is_airlock:
			seen[r.id] = true
			queue.append(r.id)
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for nxt: String in links.get(cur, []):
			if not seen.has(nxt):
				seen[nxt] = true
				queue.append(nxt)
	for k: String in seen.keys():
		if not d.rooms.has(k):
			seen.erase(k)
	return seen


## What a door opens between: the two spaces either side of where it stands, each a room id,
## "deck:<n>" (the open deck inside that deck's hull) or "" (outside the ship). Empty when it
## stands on no wall (the same space both sides).
static func door_sides(d: DesignRecord, door: Dictionary) -> PackedStringArray:
	var deck := int(door.deck)
	var p := Vector2(float(door.x), float(door.z))
	for off: Vector2 in [Vector2(0.15, 0), Vector2(0, 0.15)]:
		var a := _space_at(d, deck, p + off)
		var b := _space_at(d, deck, p - off)
		if a != b:
			return PackedStringArray([a, b])
	return PackedStringArray()


static func _space_at(d: DesignRecord, deck: int, p: Vector2) -> String:
	var r := d.room_at(deck, p)
	if r != "":
		return r
	var outline := d.hull_outline(deck)
	if outline.size() >= 3 and Geometry2D.is_point_in_polygon(p, outline):
		return "deck:%d" % deck
	return ""


static func _route_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	var seen := reachable(d, cat)
	if seen.is_empty():
		return  # no airlock: _ship_checks says so
	var outside := false
	for door: Dictionary in d.doors.values():
		var sides := door_sides(d, door)
		if sides.size() == 2 and "" in sides:
			var room := sides[0] if sides[1] == "" else sides[1]
			var rt := cat.room(str(d.rooms.get(room, {}).get("type", "")))
			outside = outside or (rt != null and rt.is_airlock)
	if not outside:
		out.append(_problem("no_way_out", ERROR, "No airlock has an outer door"))
	for r: Dictionary in d.rooms.values():
		var rt := cat.room(str(r.type))
		if rt and rt.needs_access and not seen.has(r.id):
			out.append(_problem("no_route", ERROR, "No way to walk to %s" % _label(d, cat, r.id), [r.id]))


static func _component_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	var placed: Array[Dictionary] = []
	for c: Dictionary in d.components.values():
		var pt := cat.part(str(c.type))
		var r: Dictionary = d.rooms.get(str(c.room), {})
		if pt == null or r.is_empty():
			out.append(_problem("unknown_part", ERROR, "Unknown component %s" % c.type, [], [c.id]))
			continue
		var room := Rect2(r.x, r.z, r.w, r.d)
		var f := footprint(c, pt)
		if not pt.rooms.is_empty() and not str(r.type) in pt.rooms:
			# Say where it does go (beenster, 20 Nov: told where it can't, never where it can).
			var goes: Array = []
			for k: String in pt.rooms:
				var kt := cat.room(k)
				goes.append(kt.display_name if kt else k.capitalize())
			var where: String = str(goes[0]) if goes.size() == 1 else ", ".join(goes.slice(0, goes.size() - 1)) + " or " + str(goes[-1])
			out.append(_problem("wrong_room", WARNING, "%s does not belong in %s: it goes in %s" % [
					pt.display_name, _label(d, cat, r.id), where], [r.id], [c.id]))
		if not DesignRecord.room_encloses(r, f):
			out.append(_problem("outside_room", ERROR, "%s sticks out of %s" % [
					pt.display_name, _label(d, cat, r.id)], [r.id], [c.id]))
		placed.append({"c": c, "pt": pt, "f": f, "room": room, "r": r})
	for i in placed.size():
		var a: Dictionary = placed[i]
		for j in range(i + 1, placed.size()):
			var b: Dictionary = placed[j]
			if a.c.room == b.c.room and (a.f as Rect2).intersection(b.f).get_area() > 0.01:
				out.append(_problem("parts_overlap", ERROR, "%s and %s overlap" % [
						a.pt.display_name, b.pt.display_name], [a.c.room], [a.c.id, b.c.id]))
	# Room to fit and service each one: clear floor in front, inside the room.
	for a in placed:
		var zone := access_zone(a.c, a.pt)
		var blocked: bool = not DesignRecord.room_encloses(a.r, zone)
		for b in placed:
			if b != a and b.c.room == a.c.room and zone.intersection(b.f).get_area() > 0.01:
				blocked = true
		if blocked:
			out.append(_problem("no_access", WARNING, "%s cannot be reached for fitting" % [
					a.pt.display_name], [a.c.room], [a.c.id]))


static func _ship_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary], totals: DesignTotals = null) -> void:
	if d.rooms.is_empty():
		out.append(_problem("empty", WARNING, "Place a room to start"))
		return
	for rt: DesignRoomType in cat.room_list():
		if not rt.required:
			continue
		var found := false
		for r: Dictionary in d.rooms.values():
			found = found or str(r.type) == rt.id
		if not found:
			out.append(_problem("missing_" + rt.id, ERROR, "The ship needs a %s" % rt.display_name.to_lower()))
	var t := totals if totals else DesignTotals.compute(d, cat)
	if t.power_balance() < 0.0:
		out.append(_problem("power", ERROR, "Not enough power: %.0f kW made, %.0f kW used" % [
				t.power_made, t.power_used]))
	if not t.solar_rides_shadow():
		out.append(_problem("solar_shadow", WARNING, "Solar with too little battery for shadow: %.0f kWh stored, %.0f kWh needed (%s)" % [
				t.store_kwh, maxf(0.0, t.power_used - t.fuelled_kw) * DesignPower.shadow_hours(t.region),
				str(DesignPower.REGION_NAMES.get(t.region, t.region)).to_lower()]))
	if t.thrust <= 0.0:
		out.append(_problem("no_engine", WARNING, "No engine or thrusters yet"))
