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


static func check(d: DesignRecord, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_room_checks(d, cat, out)
	_door_checks(d, out)
	_route_checks(d, cat, out)
	_component_checks(d, cat, out)
	_ship_checks(d, cat, out)
	_service_checks(d, cat, out)
	_mount_checks(d, cat, out)
	return out


## A hull part must be one that fits on the hull, and sit on the hull's side.
static func _mount_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
	if d.mounts.is_empty():
		return
	var st := DesignStructure.measure(d)
	for m: Dictionary in d.mounts.values():
		var pt := cat.part(str(m.type))
		if pt == null:
			out.append(_problem("unknown_part", ERROR, "Unknown component %s" % m.type, [], [m.id]))
			continue
		if not pt.hull_mount:
			out.append(_problem("not_hull_part", ERROR, "%s goes inside, not on the hull" % pt.display_name, [], [m.id]))
		var near := DesignStructure.nearest_hull(d, int(m.deck), Vector2(m.x, m.z), st)
		if near.is_empty() or float(near.dist) > 0.3:
			out.append(_problem("off_hull", ERROR, "%s is not on the hull" % pt.display_name, [], [m.id]))


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
			var ra := Rect2(a.x, a.z, a.w, a.d)
			for j in range(i + 1, list.size()):
				var b: Dictionary = list[j]
				var rb := Rect2(b.x, b.z, b.w, b.d)
				if ra.intersection(rb).get_area() > 0.01:
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


static func _door_checks(d: DesignRecord, out: Array[Dictionary]) -> void:
	for door: Dictionary in d.doors.values():
		if not _door_fits(d, door):
			var what := str(DesignCatalog.door_kind(door).name).to_lower()
			out.append(_problem("door_off_wall", ERROR, "A %s is not on a wall between its rooms, or the wall is too short for it" % what,
					[door.a, door.b].filter(func(x): return str(x) != ""), [], [door.id]))


## A door sits on the wall the two rooms share (b = "": on an outer wall of a), with room
## for MIN_DOOR along it.
static func _door_fits(d: DesignRecord, door: Dictionary) -> bool:
	var p := Vector2(float(door.x), float(door.z))
	# The clear wall a door needs: its opening less the jambs' play (MIN_DOOR for a plain door).
	var dw := maxf(MIN_DOOR, DesignCatalog.door_w(door) - 0.2)
	if str(door.b) == "":
		var r := d.room_rect(str(door.a))
		if r.size == Vector2.ZERO:
			return false
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
			out.append(_problem("wrong_room", WARNING, "%s does not belong in %s" % [
					pt.display_name, _label(d, cat, r.id)], [r.id], [c.id]))
		if not room.grow(0.01).encloses(f):
			out.append(_problem("outside_room", ERROR, "%s sticks out of %s" % [
					pt.display_name, _label(d, cat, r.id)], [r.id], [c.id]))
		placed.append({"c": c, "pt": pt, "f": f, "room": room})
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
		var blocked: bool = not (a.room as Rect2).grow(0.01).encloses(zone)
		for b in placed:
			if b != a and b.c.room == a.c.room and zone.intersection(b.f).get_area() > 0.01:
				blocked = true
		if blocked:
			out.append(_problem("no_access", WARNING, "%s cannot be reached for fitting" % [
					a.pt.display_name], [a.c.room], [a.c.id]))


static func _ship_checks(d: DesignRecord, cat: DesignCatalog, out: Array[Dictionary]) -> void:
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
	var t := DesignTotals.compute(d, cat)
	if t.power_balance() < 0.0:
		out.append(_problem("power", ERROR, "Not enough power: %.0f kW made, %.0f kW used" % [
				t.power_made, t.power_used]))
	if t.thrust <= 0.0:
		out.append(_problem("no_engine", WARNING, "No engine or thrusters yet"))
