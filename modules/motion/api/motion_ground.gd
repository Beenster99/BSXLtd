class_name MotionGround
extends RefCounted
## "Set her down": the design stood on a landing pad on its deployed legs (plan 3.9). For a
## flat pad and a rough one, empty and with a full hold, it finds how she sits (level, or how
## far off when the oleos can't take up the ground), each foot's load against its rating, the
## clearance under her belly, and how far she is from tipping. Masses are the design's own
## (DesignTotals: dry, fuel, occupancy and cargo max when it has them), placed where they are:
## each part where it stands, the hull spread over the rooms, fuel in the tanks, people in
## the bunks, cargo in the racks and holds.
##
## check(rec, cat, totals) -> {legs: n, feet: [{id, name, at: Vector3, rated}], cases: [case],
##   problems: [DesignRules problems]}; a case: {pad, load ("empty" | "full"), mass, cog:
##   Vector3, level (bool), tilt_deg, loads: [kg per foot], clearance (m), tip_deg (slope she
##   tips at; negative: she tips over), ramps: [{id, name, reach_short (m), slope_deg}]}

const PADS: PackedStringArray = ["flat", "rough"]
const PAD_NAMES := {"flat": "Flat pad", "rough": "Rough ground"}
## A rough pad: a cross slope, degrees, and bumps, m.
const ROUGH_SLOPE := 3.0
const ROUGH_BUMPS := 0.18
## How much each leg's oleo can take up, up or down, as a share of its reach.
const STROKE := 0.25
## The hull's belly under the lowest deck's floor, m (deck plate, frame and skin).
const BELLY := 0.4
## The least clearance under her belly, m.
const MIN_CLEARANCE := 0.3
## She should stand a slope or gust of at least this before she tips, degrees.
const MIN_TIP := 12.0
## A ramp steeper than this is a climb, not a walk, degrees.
const MAX_RAMP := 30.0


## The pad's height under (x, z), m.
static func ground(pad: String, x: float, z: float) -> float:
	if pad == "rough":
		return tan(deg_to_rad(ROUGH_SLOPE)) * x + ROUGH_BUMPS * sin(1.3 * x + 0.4) * cos(0.9 * z + 0.2)
	return 0.0


## The legs: every mover that is a leg.
static func legs(movers: Array[Dictionary]) -> Array[Dictionary]:
	return movers.filter(func(mv: Dictionary) -> bool: return str(mv.spec.kind) == "leg")


## Where her mass is: [{at: Vector3, kg}], `full` with her hold loaded to its rating.
static func masses(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals, full: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed := 0.0
	var tanks: Array[Dictionary] = []
	var bunks: Array[Dictionary] = []
	var racks: Array[Dictionary] = []
	for c: Dictionary in rec.components.values():
		var pt := cat.part(str(c.type))
		var r: Dictionary = rec.rooms.get(str(c.room), {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var at := Vector3(f.get_center().x, float(r.deck) * rec.deck_height + minf(pt.size.y, rec.deck_height) * 0.5, f.get_center().y)
		out.append({"at": at, "kg": pt.mass})
		placed += pt.mass
		if pt.tank > 0.0:
			tanks.append({"at": at, "w": pt.tank})
		if pt.crew > 0:
			bunks.append({"at": at, "w": float(pt.crew)})
		if pt.cargo > 0.0:
			racks.append({"at": at, "w": pt.cargo})
	for m: Dictionary in rec.mounts.values():
		var pt := cat.part(str(m.type))
		if pt == null:
			continue
		out.append({"at": MotionMovers.mount_base(rec, m, pt) * Vector3(0, pt.size.y * 0.5, 0), "kg": pt.mass})
		placed += pt.mass
	# The hull, rooms, doors and services: spread over the rooms by floor area.
	var rooms: Array[Dictionary] = []
	var holds: Array[Dictionary] = []
	var fuel_rooms: Array[Dictionary] = []
	for r: Dictionary in rec.rooms.values():
		var c2 := Rect2(float(r.x), float(r.z), float(r.w), float(r.d)).get_center()
		var at := Vector3(c2.x, float(r.deck) * rec.deck_height + rec.deck_height * 0.5, c2.y)
		var area := DesignRecord.room_area(r)
		rooms.append({"at": at, "w": area})
		if str(r.type) == "cargo":
			holds.append({"at": at, "w": area})
		if str(r.type) == "fuel":
			fuel_rooms.append({"at": at, "w": area})
	var total := totals.mass if totals else placed
	_spread(out, rooms, maxf(total - placed, 0.0))
	var fuel := _num(totals, "fuel_mass", 0.0)
	_spread(out, tanks if not tanks.is_empty() else (fuel_rooms if not fuel_rooms.is_empty() else rooms), fuel)
	var people := _num(totals, "occupancy_mass", float(totals.crew) * 100.0 if totals else 0.0)
	_spread(out, bunks if not bunks.is_empty() else rooms, people)
	if full:
		var cargo := _num(totals, "cargo_max", (totals.cargo_m3 if totals else 0.0) * 400.0)
		_spread(out, racks if not racks.is_empty() else (holds if not holds.is_empty() else rooms), cargo)
	return out


static func _num(o: Object, prop: String, fallback: float) -> float:
	if o == null:
		return fallback
	var v: Variant = o.get(prop)
	return float(v) if v != null else fallback


static func _spread(out: Array[Dictionary], over: Array[Dictionary], kg: float) -> void:
	if kg <= 0.0 or over.is_empty():
		return
	var sum := 0.0
	for o in over:
		sum += float(o.w)
	for o in over:
		out.append({"at": o.at, "kg": kg * (float(o.w) / maxf(sum, 0.0001))})


static func check(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals, movers: Array[Dictionary] = []) -> Dictionary:
	var out := {"legs": 0, "feet": [], "cases": [], "problems": []}
	if rec == null or rec.rooms.is_empty():
		return out
	if movers.is_empty():
		movers = MotionMovers.list(rec, cat)
	var lg := legs(movers)
	out.legs = lg.size()
	var ramps := movers.filter(func(mv: Dictionary) -> bool: return str(mv.spec.kind) == "hinge_out" and mv.kind == "mount")
	var problems: Array[Dictionary] = []
	if lg.is_empty():
		if not ramps.is_empty():
			problems.append(_problem(DesignRules.WARNING, "She has a ramp but no landing gear to set her down on", []))
		out.problems = problems
		return out
	var feet: Array[Dictionary] = []
	for mv in lg:
		feet.append({"id": mv.id, "name": mv.name, "at": MotionMovers.foot_point(mv), "rated": float(mv.spec.get("load_kg", 0.0)),
				"stroke": MotionMovers.leg_reach(mv) * STROKE})
	out.feet = feet
	if feet.size() < 3 or _in_a_line(feet):
		problems.append(_problem(DesignRules.ERROR, "She needs at least three landing legs, not all in one line, to stand: she has %d" % feet.size(),
				_ids(lg)))
		out.problems = problems
		return out
	var belly := float(rec.decks()[0]) * rec.deck_height - BELLY
	var cases: Array[Dictionary] = []
	for pad in PADS:
		for load in ["empty", "full"]:
			cases.append(_case(rec, cat, totals, feet, ramps, belly, pad, load == "full"))
	out.cases = cases
	# What goes on WILL IT WORK: the worst of each.
	var worst := {}
	for c: Dictionary in cases:
		var where := "%s, %s" % [str(PAD_NAMES[c.pad]).to_lower(), "hold full" if c.load == "full" else "hold empty"]
		for i in feet.size():
			var kg := float(c.loads[i])
			var rated := float(feet[i].rated)
			if rated > 0.0 and kg > rated and not worst.has("over" + str(i)):
				worst["over" + str(i)] = _problem(DesignRules.ERROR, "%s carries %s t, rated %s t (%s)" % [
						feet[i].name, _t(kg), _t(rated), where], [feet[i].id])
		if float(c.tip_deg) < 0.0 and not worst.has("tip"):
			worst["tip"] = _problem(DesignRules.ERROR, "She tips over on her legs (%s): her weight is outside her feet" % where, _ids(lg))
		elif float(c.tip_deg) < MIN_TIP and not worst.has("tip") and not worst.has("tipwarn"):
			worst["tipwarn"] = _problem(DesignRules.WARNING, "She would tip on a %d° slope or a hard gust (%s): spread her legs" % [
					int(c.tip_deg), where], _ids(lg))
		if float(c.clearance) < MIN_CLEARANCE and not worst.has("clear"):
			worst["clear"] = _problem(DesignRules.ERROR if float(c.clearance) < 0.0 else DesignRules.WARNING,
					"Only %s m under her belly (%s): her legs need more reach" % [_m(c.clearance), where], _ids(lg))
		if not bool(c.level) and not worst.has("level"):
			worst["level"] = _problem(DesignRules.WARNING, "She sits %s° off level (%s): her legs can't take up the ground" % [
					_m(c.tilt_deg), where], _ids(lg))
		for r: Dictionary in c.ramps:
			if float(r.reach_short) > 0.05 and not worst.has("ramp" + str(r.id)):
				worst["ramp" + str(r.id)] = _problem(DesignRules.ERROR, "%s stops %s m short of the ground (%s)" % [
						r.name, _m(r.reach_short), where], [r.id])
			elif float(r.slope_deg) > MAX_RAMP and not worst.has("ramp" + str(r.id)):
				worst["ramp" + str(r.id)] = _problem(DesignRules.WARNING, "%s is steep, %d° (%s)" % [r.name, int(r.slope_deg), where], [r.id])
	for k: String in worst:
		problems.append(worst[k])
	out.problems = problems
	return out


static func _case(rec: DesignRecord, cat: DesignCatalog, totals: DesignTotals, feet: Array[Dictionary], ramps: Array,
		belly: float, pad: String, full: bool) -> Dictionary:
	# The height she sits at (her design space's y = 0 on the pad's y = H): as level as her oleos
	# allow, each taking up the ground under its own foot.
	var lo := -INF
	var hi := INF
	for f in feet:
		var need := ground(pad, f.at.x, f.at.z) - float(f.at.y)
		lo = maxf(lo, need - float(f.stroke))
		hi = minf(hi, need + float(f.stroke))
	var level := lo <= hi + 0.001
	var H := (lo + hi) * 0.5 if level else 0.0
	var tilt := 0.0
	if not level:
		# The ground beats the oleos: she leans across the feet by what they can't take up.
		var spread := lo - hi
		var span := 0.0
		for a in feet:
			for b in feet:
				span = maxf(span, Vector2(a.at.x, a.at.z).distance_to(Vector2(b.at.x, b.at.z)))
		tilt = rad_to_deg(atan(spread / maxf(span, 0.1)))
		H = (lo + hi) * 0.5
	# Mass and its middle.
	var mass := 0.0
	var cog := Vector3.ZERO
	for m: Dictionary in masses(rec, cat, totals, full):
		mass += float(m.kg)
		cog += (m.at as Vector3) * float(m.kg)
	cog = cog / maxf(mass, 0.001)
	# Each foot's share: a plane through the loads (feet on equal springs).
	var n := feet.size()
	var mx := 0.0
	var mz := 0.0
	for f in feet:
		mx += f.at.x
		mz += f.at.z
	mx /= n
	mz /= n
	var suu := 0.0
	var svv := 0.0
	var suv := 0.0
	for f in feet:
		var u := float(f.at.x) - mx
		var v := float(f.at.z) - mz
		suu += u * u
		svv += v * v
		suv += u * v
	var det := suu * svv - suv * suv
	var rx := mass * (cog.x - mx)
	var rz := mass * (cog.z - mz)
	var b := (rx * svv - rz * suv) / det if absf(det) > 1e-6 else 0.0
	var c := (rz * suu - rx * suv) / det if absf(det) > 1e-6 else 0.0
	var loads: Array = []
	for f in feet:
		loads.append(mass / n + b * (float(f.at.x) - mx) + c * (float(f.at.z) - mz))
	# How far her weight is inside the feet, and the slope she would tip at.
	var hull_pts := PackedVector2Array()
	for f in feet:
		hull_pts.append(Vector2(f.at.x, f.at.z))
	var support := Geometry2D.convex_hull(hull_pts)
	var g2 := Vector2(cog.x, cog.z)
	var inside := Geometry2D.is_point_in_polygon(g2, support)
	var edge := INF
	for i in support.size() - 1:
		edge = minf(edge, Geometry2D.get_closest_point_to_segment(g2, support[i], support[i + 1]).distance_to(g2))
	var high := maxf(cog.y + H - ground(pad, cog.x, cog.z), 0.1)
	var tip := rad_to_deg(atan(edge / high)) * (1.0 if inside else -1.0)
	# Clearance: the belly over the highest ground under her.
	var box := rec.bounds()
	var top_ground := -INF
	var step := 1.0
	var x := box.position.x
	while x <= box.end.x + 0.001:
		var z := box.position.y
		while z <= box.end.y + 0.001:
			top_ground = maxf(top_ground, ground(pad, x, z))
			z += step
		x += step
	var clearance := belly + H - top_ground
	# Ramps: from the sill down to the ground.
	var ramp_out: Array = []
	for mv: Dictionary in ramps:
		var hinge: Vector3 = (mv.base as Transform3D).origin
		var length := float(mv.size.y)
		var drop := hinge.y + H - ground(pad, hinge.x, hinge.z)
		ramp_out.append({"id": mv.id, "name": mv.name, "reach_short": maxf(drop - length, 0.0),
				"slope_deg": rad_to_deg(asin(clampf(drop / maxf(length, 0.01), -1.0, 1.0)))})
	return {"pad": pad, "load": "full" if full else "empty", "mass": mass, "cog": cog, "height": H, "level": level,
			"tilt_deg": tilt, "loads": loads, "clearance": clearance, "tip_deg": tip, "ramps": ramp_out}


static func _in_a_line(feet: Array[Dictionary]) -> bool:
	var pts := PackedVector2Array()
	for f in feet:
		pts.append(Vector2(f.at.x, f.at.z))
	var hull := Geometry2D.convex_hull(pts)
	var area := 0.0
	for i in hull.size() - 1:
		area += hull[i].cross(hull[i + 1])
	return absf(area) * 0.5 < 0.5


static func _ids(movers: Array) -> Array:
	return movers.map(func(mv: Dictionary) -> String: return str(mv.id))


static func _problem(sev: String, text: String, movers: Array) -> Dictionary:
	var comps: Array = []
	for m in movers:
		if str(m).begins_with("component:"):
			comps.append(str(m).get_slice(":", 1))
	return {"code": "motion.ground", "severity": sev, "text": text, "rooms": [], "components": comps, "doors": [],
			"movers": movers}


static func _t(kg: float) -> String:
	return str(snappedf(kg / 1000.0, 0.1))


static func _m(v: float) -> String:
	return str(snappedf(v, 0.01))
