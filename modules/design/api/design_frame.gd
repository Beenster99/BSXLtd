class_name DesignFrame
extends RefCounted
## The ship's structure, proposed from its rooms and hull for the designers to change: a beam
## skeleton of frame rings at stations along the ship (box girders, their ends mitred to meet
## at the corners and welded there), stringers along every corner butted onto the rings,
## every member welded at its ends, and an outer shell of metal and glass plates cut to the faces and riveted to the
## members. It is built with Void Salvage's own frame kit (FrameHull, the shared files), the
## code its Kestrel and Manta are built with, so a design's structure is real parts and joints:
## every joint is a weld, rivet or bolt someone will make in the yard.
##
## `propose` works the structure out; the rooms only set its shape: each station's
## cross-section (an eight-sided ring, `SIDES`) is drawn round everything on every deck near
## it (rooms and the drawn hull) with room for the frame between the rooms and the skin
## (`clearance`), a belly under the lowest deck for the services and a roof over the top one.
## The design's `structure` choices pick the frame (light, standard, heavy: a FrameStyle) and
## the station spacing. Outer doors are cut through the skin as framed openings; a bridge gets
## glass over it.
##
## Ship space: metres, +X starboard, -Z forward, y up, deck 0's floor at y = 0.

## Frame weight (DesignStructure.OPTIONS.frame) -> the FrameStyle it is built in.
const STYLES := {"light": "kestrel", "standard": "channel", "heavy": "bowhead"}
## Points round a cross-section. Edges: 0 roof, 1 starboard shoulder, 2 starboard side,
## 3 starboard chine, 4 belly, 5 port chine, 6 port side, 7 port shoulder.
const SIDES := 8
const ROOF_EDGE := 0
const STARBOARD := 2
const BELLY_EDGE := 4
const PORT := 6
## Under the lowest deck's floor for the services, and over the top deck's ceiling, metres.
const BELLY := 0.6
const ROOF := 0.35
## The corners' chamfer, metres (at most a quarter of the section's smaller side).
const CHAMFER := 0.7
## An outer door's opening, metres.
const DOOR_W := 1.2
const DOOR_H := 2.2
## What a joint costs to make in the yard: credits, kg, hours each.
const WELD := {"name": "Welded joints", "cost": 12.0, "mass": 0.2, "hours": 0.08}
const RIVET := {"name": "Rivets", "cost": 1.5, "mass": 0.05, "hours": 0.01}
const BOLT := {"name": "Bolts", "cost": 2.0, "mass": 0.08, "hours": 0.015}
## Inside the hull: an inner wall's thickness (the walk's wall and its linings), the gap under a
## deck's ceiling, how far a wall stops short of the wall it meets, metres; the deck girders'
## lanes, metres apart; stud spacing, metres.
const INNER_WALL := 0.19
const CEILING := 0.1
const WALL_END := 0.1
const LANE := 1.5
const STUD := 0.6
## Room types that link decks: an opening through the deck over them.
const LINKS := ["stairs", "lift", "hatch"]
## The frame kit's part names, as the designers call them.
const PART_NAMES := {"FrameNode": "Node block", "FrameRing": "Frame ring", "Stringer": "Stringer",
		"HullPlate": "Hull plate", "ArmourPlate": "Armour plate", "CapPlate": "End plate", "WindowPane": "Glass panel", "FramePost": "Door post",
		"FrameRail": "Door rail", "FrameSplice": "Splice", "DeckBeam": "Deck beam", "DeckGirder": "Deck girder",
		"DeckTrimmer": "Deck trimmer", "DeckPlate": "Deck plate", "Stud": "Wall stud", "StudSill": "Wall sill",
		"StudHead": "Wall head rail", "StudLintel": "Door lintel", "StudFoot": "Wall foot rail", "WallPanel": "Wall panel"}
const EDGE_NAMES := ["roof", "starboard shoulder", "starboard side", "starboard chine", "belly", "port chine",
		"port side", "port shoulder"]
const JOINT_NAMES := {ConnectionData.Kind.WELD: "Weld", ConnectionData.Kind.RIVET: "Rivets",
		ConnectionData.Kind.BOLT: "Bolts"}
## Room types a glazed roof goes over.
const GLAZED := ["bridge"]


## The proposed structure, {} for an empty design: {style, spacing, clearance, stations:
## [{z, label, profile}], glass: {"<bay>:<edge>": true}, openings: [{name, edge, box}],
## caps: [front pieces, back pieces] (outlines, x y), cap_glass: [bool, bool]}.
static func propose(d: DesignRecord) -> Dictionary:
	var spacing := maxf(float(d.structure.get("spacing", 2.0)), 0.5)
	var weight := str(d.structure.get("frame", "standard"))
	var style_id: String = STYLES.get(weight, "channel")
	var clear := clearance(style_id)
	var content := _content(d)
	if content.is_empty():
		return {}
	var zmin := INF
	var zmax := -INF
	for c: Dictionary in content:
		zmin = minf(zmin, float(c.z0))
		zmax = maxf(zmax, float(c.z1))
	var z0 := zmin - clear
	var z1 := zmax + clear
	var n := maxi(1, roundi((z1 - z0) / spacing))
	var zs: Array[float] = []
	for i in n + 1:
		zs.append(lerpf(z0, z1, float(i) / n))
	zs = _hand_rings(d, zs)
	var stations: Array = []
	var last := {}
	for i in zs.size():
		# Everything in the bays either side of the station, so the skin between two stations
		# (a straight line from one ring to the next) passes outside it all.
		var span := _span(content, zs[maxi(i - 1, 0)], zs[mini(i + 1, zs.size() - 1)])
		if span.is_empty():
			span = last
		last = span
		# Out by the frame's room each side, under by the belly, over by the roof, then out by half
		# the chamfer so the cut corners still clear the rooms' corners by the frame's room.
		var h := d.deck_height
		var g := CHAMFER * 0.5
		var top := maxf(ROOF, clear)
		var rect := Rect2(float(span.x0) - clear - g, int(span.lo) * h - BELLY - g,
				float(span.x1) - float(span.x0) + (clear + g) * 2.0, (int(span.hi) - int(span.lo) + 1) * h + BELLY + top + g * 2.0)
		stations.append({"z": zs[i], "label": "f%d" % i, "rect": rect, "profile": section(rect)})
	var out := {"style": style_id, "weight": weight, "spacing": spacing, "clearance": clear,
			"stations": stations, "glass": {}, "openings": [], "skip": {}, "armour": {}, "open": {},
			"no_stringer": {}, "hand_skip": {}, "paint": {}, "livery": d.livery.duplicate(true)}
	_grow(d, stations)
	# Her nose and stern drawn out of the body (DesignShape), then her wings, fins and pods.
	DesignShape.extend(d, out, _end_doors(d, stations, clear))
	_glaze(d, out)
	_panels(d, out)
	_members(d, out)
	_openings(d, out)
	_inside(d, out)
	out["limbs"] = DesignShape.limbs(d, out)
	return out


## Inside the hull: a deck frame under each deck's rooms (beams across at the stations, girders
## along, plates over, holes where stairs, lifts and hatches go up through it) and the inner
## walls as stud walls (studs, rails, a lintel over each door, a panel each side, bolted).
static func _inside(d: DesignRecord, p: Dictionary) -> void:
	var h := d.deck_height
	var decks: Array = []
	for dk in d.decks():
		var z0 := INF
		var z1 := -INF
		var holes: Array = []
		for r: Dictionary in d.rooms_on(dk):
			z0 = minf(z0, float(r.z))
			z1 = maxf(z1, float(r.z) + float(r.d))
			if dk > 0 and str(r.type) in LINKS:
				for lo: Dictionary in d.rooms_on(dk - 1):
					var both := Rect2(r.x, r.z, r.w, r.d).intersection(Rect2(lo.x, lo.z, lo.w, lo.d))
					if str(lo.type) == str(r.type) and both.has_area():
						holes.append(both)
		if z1 > z0:
			decks.append({"deck": dk, "top": dk * h, "z0": z0, "z1": z1, "openings": holes})
	var walls: Array = []
	for e: Dictionary in DesignStructure.measure(d).inner_edges:
		var a: Vector2 = e.a
		var b: Vector2 = e.b
		var across := absf(a.y - b.y) < 0.01
		if not across and absf(a.x - b.x) > 0.01:
			continue  # an angled wall: built by hand for now
		var t0 := minf(a.x, b.x) if across else minf(a.y, b.y)
		var t1 := maxf(a.x, b.x) if across else maxf(a.y, b.y)
		var at := a.y if across else a.x
		var y0 := int(e.deck) * h
		var doors: Array = []
		for g: Dictionary in d.doors.values():
			if int(g.deck) != int(e.deck) or str(g.get("a", "")) == "" or str(g.get("b", "")) == "":
				continue
			var gt := float(g.x) if across else float(g.z)
			var ga := float(g.z) if across else float(g.x)
			if absf(ga - at) < 0.05 and gt > t0 + 0.01 and gt < t1 - 0.01:
				doors.append([gt, DesignCatalog.door_w(g), DesignCatalog.door_h(g)])
		if t1 - t0 > WALL_END * 2.0 + 0.2:
			walls.append({"deck": int(e.deck), "across": across, "at": at, "t0": t0 + WALL_END, "t1": t1 - WALL_END,
					"y0": y0, "y1": y0 + h - CEILING, "doors": doors})
	p["decks"] = decks
	p["walls"] = walls


## The key a designer's change to the section nearest z is stored under (DesignRecord.frame_edits).
static func section_key(z: float) -> String:
	return "section:%.1f" % z


## The key a designer's change to the panel over `edge` of the bay round z is stored under.
static func panel_key(z: float, edge: int) -> String:
	return "panel:%.1f:%d" % [z, edge]


## The bay (from station k to k + 1) that holds z, -1 if none.
static func bay_at(p: Dictionary, z: float) -> int:
	var st: Array = p.get("stations", [])
	for k in st.size() - 1:
		if z >= float(st[k].z) - 0.001 and z < float(st[k + 1].z) + 0.001:
			return k
	return -1


## The station nearest z, -1 if none.
static func station_at(p: Dictionary, z: float) -> int:
	var st: Array = p.get("stations", [])
	var best := -1
	for i in st.size():
		if best < 0 or absf(float(st[i].z) - z) < absf(float(st[best].z) - z):
			best = i
	return best


## Which sides of a section a point on it is on: [port, starboard, roof, belly] as 0 or 1, the
## ones the point is near (a chamfer is two).
static func sides_at(rect: Rect2, x: float, y: float) -> Array:
	var c := rect.get_center()
	var dx := (x - c.x) / maxf(rect.size.x * 0.5, 0.01)
	var dy := (y - c.y) / maxf(rect.size.y * 0.5, 0.01)
	var s := [1 if dx < -0.6 else 0, 1 if dx > 0.6 else 0, 1 if dy > 0.6 else 0, 1 if dy < -0.6 else 0]
	if s.max() == 0:
		if absf(dx) > absf(dy):
			s[0 if dx < 0.0 else 1] = 1
		else:
			s[3 if dy < 0.0 else 2] = 1
	return s


## The designers' pushed-out sections: each moves its nearest station's sides out, never in
## past the proposal (the rooms and the frame's room round them).
static func _grow(d: DesignRecord, st: Array) -> void:
	for key: String in d.frame_edits:
		if not key.begins_with("section:"):
			continue
		var g: Array = (d.frame_edits[key] as Dictionary).get("grow", [])
		if g.size() < 4 or st.is_empty():
			continue
		var i := station_at({"stations": st}, float(key.get_slice(":", 1)))
		var r: Rect2 = st[i].rect
		var port := maxf(float(g[0]), 0.0)
		var stbd := maxf(float(g[1]), 0.0)
		var roof := maxf(float(g[2]), 0.0)
		var belly := maxf(float(g[3]), 0.0)
		r = Rect2(r.position - Vector2(port, belly), r.size + Vector2(port + stbd, roof + belly))
		st[i].rect = r
		st[i].profile = section(r)


## The designers' panels: glass or metal over the proposal's (glass over the bridge), armour,
## or left off (open): "panel:<z>:<edge>" -> {kind: "metal" | "armour" | "glass" | "open"}
## (older saves: {glass: bool}).
static func _panels(d: DesignRecord, p: Dictionary) -> void:
	var glass: Dictionary = p.glass
	for key: String in d.frame_edits:
		if not key.begins_with("panel:"):
			continue
		var k := bay_at(p, float(key.get_slice(":", 1)))
		if k < 0:
			continue
		var gk := "%d:%d" % [k, int(key.get_slice(":", 2))]
		var edit: Dictionary = d.frame_edits[key]
		if str(edit.get("paint", "")) != "":
			p.paint[gk] = str(edit.paint)
		if not edit.has("kind") and not edit.has("glass"):
			continue
		var kind := panel_kind(edit)
		glass.erase(gk)
		(p.armour as Dictionary).erase(gk)
		(p.open as Dictionary).erase(gk)
		match kind:
			"glass":
				glass[gk] = true
			"armour":
				p.armour[gk] = true
			"open":
				p.open[gk] = true


## What a panel edit asks for (PANEL_KINDS).
static func panel_kind(edit: Dictionary) -> String:
	if edit.has("kind"):
		return str(edit.kind)
	return "glass" if bool(edit.get("glass", false)) else "metal"


## What a skin panel can be, as the designers pick it (the outside designer, stage 1).
const PANEL_KINDS := ["metal", "armour", "glass", "open"]
const PANEL_NAMES := {"metal": "Hull plate", "armour": "Armour plate", "glass": "Glass panel", "open": "Left open"}
## Armour plating over the plain skin, per m2: what it costs, weighs and takes to fit on top.
const ARMOUR := {"name": "Armour plating", "cost": 220.0, "mass": 95.0, "hours": 0.6}
## The longest bay a plate spans before it wants another frame, m.
const MAX_BAY := 3.5


## What a panel is in the proposal: "metal", "armour", "glass" or "open" (bay `k`, edge `e`).
static func panel_at(p: Dictionary, k: int, e: int) -> String:
	var gk := "%d:%d" % [k, e]
	if (p.get("open", {}) as Dictionary).has(gk):
		return "open"
	if (p.get("armour", {}) as Dictionary).has(gk):
		return "armour"
	if (p.get("glass", {}) as Dictionary).has(gk):
		return "glass"
	return "metal"


## The frame rings the designers added or took out ("ring:<z>" -> {add: true} or {remove: true}):
## an added ring goes in where there is room (not within RING_GAP of another), a removed one is
## the proposed ring nearest it (never the end ones: they carry the end plates).
const RING_GAP := 0.4


static func ring_key(z: float) -> String:
	return "ring:%.1f" % z


static func _hand_rings(d: DesignRecord, zs: Array[float]) -> Array[float]:
	var adds: Array[float] = []
	var removes: Array[float] = []
	for key: String in d.frame_edits:
		if not key.begins_with("ring:"):
			continue
		var z := float(key.get_slice(":", 1))
		var e: Dictionary = d.frame_edits[key]
		if bool(e.get("remove", false)):
			removes.append(z)
		elif bool(e.get("add", false)):
			adds.append(z)
	if adds.is_empty() and removes.is_empty():
		return zs
	var out := zs.duplicate()
	for z in removes:
		var best := -1
		for i in range(1, out.size() - 1):
			if absf(out[i] - z) < RING_GAP and (best < 0 or absf(out[i] - z) < absf(out[best] - z)):
				best = i
		if best > 0:
			out.remove_at(best)
	for z in adds:
		if z <= out[0] + RING_GAP or z >= out[out.size() - 1] - RING_GAP:
			continue
		var clear := true
		for o in out:
			clear = clear and absf(o - z) >= RING_GAP
		if clear:
			out.append(z)
	out.sort()
	return out


## Single members the designers took out: a ring's girder along one edge
## ("member:<z>:<edge>" -> {remove: true}, the ring nearest z) and a stringer along one corner of
## a bay ("stringer:<z>:<corner>" -> {remove: true}, the bay holding z).
static func member_key(z: float, edge: int) -> String:
	return "member:%.1f:%d" % [z, edge]


static func stringer_key(z: float, corner: int) -> String:
	return "stringer:%.1f:%d" % [z, corner]


static func _members(d: DesignRecord, p: Dictionary) -> void:
	for key: String in d.frame_edits:
		if not bool((d.frame_edits[key] as Dictionary).get("remove", false)):
			continue
		var z := float(key.get_slice(":", 1))
		var e := int(key.get_slice(":", 2))
		if key.begins_with("member:"):
			var i := station_at(p, z)
			if i >= 0:
				p.skip["%d:%d" % [i, e]] = true
				p.hand_skip["%d:%d" % [i, e]] = true
		elif key.begins_with("stringer:"):
			var k := bay_at(p, z)
			if k >= 0:
				p.no_stringer["%d:%d" % [k, e]] = true


## What holds a plate up: the ring girders at its two ends and the stringers at its two sides
## still in (a plate with neither pair is unsupported).
static func plate_support(p: Dictionary, k: int, e: int) -> Dictionary:
	var hs: Dictionary = p.get("hand_skip", {})
	var ns: Dictionary = p.get("no_stringer", {})
	var ends := int(not hs.has("%d:%d" % [k, e])) + int(not hs.has("%d:%d" % [k + 1, e]))
	var sides := int(not ns.has("%d:%d" % [k, e])) + int(not ns.has("%d:%d" % [k, (e + 1) % SIDES]))
	return {"ends": ends, "sides": sides}


## Room the frame takes between the rooms' walls and the skin's outer face: the plate, the
## member's depth and the gaps either side of it, metres.
static func clearance(style_id: String) -> float:
	var s: Dictionary = FrameStyle.STYLES.get(style_id, FrameStyle.STYLES["channel"])
	var member: Vector2 = s.get("member", Vector2(0.16, 0.22))
	return float(s.get("skin", 0.08)) + member.y + FrameHull.GAP * 2.0 + 0.12


## An eight-sided cross-section filling `r` (x across, y up), chamfered at the corners.
static func section(r: Rect2) -> PackedVector2Array:
	var c := minf(CHAMFER, minf(r.size.x, r.size.y) * 0.25)
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	return PackedVector2Array([Vector2(x0 + c, y1), Vector2(x1 - c, y1), Vector2(x1, y1 - c), Vector2(x1, y0 + c),
			Vector2(x1 - c, y0), Vector2(x0 + c, y0), Vector2(x0, y0 + c), Vector2(x0, y1 - c)])


## The structure's parts as a list for the spec (from the proposal, before it is built):
## {stations, nodes, rings, stringers, plates, glass, openings, welds, rivets, member_m, skin_m2}.
static func counts(p: Dictionary) -> Dictionary:
	if p.is_empty():
		return {"stations": 0, "nodes": 0, "rings": 0, "stringers": 0, "plates": 0, "glass": 0,
				"openings": 0, "welds": 0, "rivets": 0, "bolts": 0, "member_m": 0.0, "skin_m2": 0.0,
				"decks": 0, "deck_plates": 0, "walls": 0, "studs": 0, "wall_panels": 0, "armour": 0, "armour_m2": 0.0,
				"open": 0, "limbs": 0, "struts": 0}
	var st: Array = p.stations
	var s: Dictionary = FrameStyle.STYLES.get(str(p.style), FrameStyle.STYLES["channel"])
	var pitch := float(s.get("rivet_pitch", 0.5))
	var member_m := 0.0
	var skin_m2 := 0.0
	var rivets := 0
	var armour_m2 := 0.0
	for i in st.size():
		var a: PackedVector2Array = st[i].profile
		for k in SIDES:
			member_m += a[k].distance_to(a[(k + 1) % SIDES])
		if i == 0 or i == st.size() - 1:
			skin_m2 += absf(_area(a))
			rivets += int(_perimeter(a) / pitch)
		if i == 0:
			continue
		var b: PackedVector2Array = st[i - 1].profile
		var dz := float(st[i].z) - float(st[i - 1].z)
		for k in SIDES:
			var la := a[k].distance_to(a[(k + 1) % SIDES])
			var lb := b[k].distance_to(b[(k + 1) % SIDES])
			var along := Vector3(a[k].x - b[k].x, a[k].y - b[k].y, dz).length()
			member_m += along
			var kind := panel_at(p, i - 1, k)
			if kind == "open":
				continue
			if kind == "armour":
				armour_m2 += (la + lb) * 0.5 * along
			skin_m2 += (la + lb) * 0.5 * along
			# Rows along the rings at both ends and the stringers at both sides.
			rivets += int(la / pitch) + int(lb / pitch) + int(along / pitch) * 2
	var rings := st.size() * SIDES - (p.get("hand_skip", {}) as Dictionary).size()
	var stringers := (st.size() - 1) * SIDES - (p.get("no_stringer", {}) as Dictionary).size()
	var open := (p.get("open", {}) as Dictionary).size()
	var plates := (st.size() - 1) * SIDES + 2 - open
	# A weld at each ring corner (the mitre) and at each end of a stringer.
	var welds := rings + stringers * 2
	# Inside, estimated before it is built: the decks' members, plates and spot welds; the
	# walls' studs and rails, panels and bolts.
	var deck_plates := 0
	var studs := 0
	var wall_panels := 0
	var bolts := 0
	for dk: Dictionary in p.get("decks", []):
		var len := float(dk.z1) - float(dk.z0)
		var width := (_rect_near(st, (float(dk.z0) + float(dk.z1)) * 0.5) as Rect2).size.x
		var beams := 0
		for s2: Dictionary in st:
			if float(s2.z) > float(dk.z0) and float(s2.z) < float(dk.z1):
				beams += 1
		var lanes := maxi(1, ceili(width / LANE))
		member_m += beams * width + (lanes - 1) * len
		welds += beams * 2 + (lanes - 1) * maxi(beams - 1, 1) * 2
		deck_plates += lanes * maxi(beams + 1, 1)
		welds += int(width * len / 0.5)  # spot welds
	for w: Dictionary in p.get("walls", []):
		var len := float(w.t1) - float(w.t0)
		var hgt := float(w.y1) - float(w.y0)
		var n := int(len / STUD) + 1 + 2 * (w.doors as Array).size()
		studs += n
		member_m += n * hgt + 2.0 * len
		wall_panels += 2 * maxi(1, ceili(len / STUD))
		bolts += 2 * maxi(1, ceili(len / STUD)) * (int(hgt) + 2)
		welds += n
	# Her wings, fins, pods and fairings (DesignShape): their own frames and skin, bolted on.
	var limbs := 0
	var struts := 0
	for limb: Dictionary in p.get("limbs", []):
		var lc := DesignShape.counts(limb)
		limbs += 1
		struts += int(lc.struts)
		member_m += float(lc.member_m)
		skin_m2 += float(lc.skin_m2)
		plates += int(lc.plates)
		rings += int(lc.rings)
		stringers += int(lc.stringers)
		bolts += int(lc.bolts)
		welds += int(lc.rings) * 2 + int(lc.stringers) * 2
		rivets += int(float(lc.skin_m2) * 4.0)
	return {"stations": st.size(), "nodes": 0, "rings": rings, "stringers": stringers, "plates": plates,
			"glass": (p.glass as Dictionary).size(), "openings": (p.openings as Array).size(),
			"welds": welds, "rivets": rivets, "bolts": bolts, "member_m": member_m, "skin_m2": skin_m2,
			"decks": (p.get("decks", []) as Array).size(), "deck_plates": deck_plates,
			"walls": (p.get("walls", []) as Array).size(), "studs": studs, "wall_panels": wall_panels,
			"armour": (p.get("armour", {}) as Dictionary).size(), "armour_m2": armour_m2, "open": open,
			"limbs": limbs, "struts": struts}


## The yard's build list for the proposal: every kind of member, plate and joint the crew will
## make, how many, and how it is fastened: [{name, qty, unit, how}].
static func build_list(p: Dictionary) -> Array[Dictionary]:
	var c := counts(p)
	var out: Array[Dictionary] = []
	if int(c.stations) == 0:
		return out
	for row: Array in [
		["Frame rings", c.rings, "x", "ends mitred, welded to each other"],
		["Stringers", c.stringers, "x", "butt welded ring to ring"],
		["Hull plates", int(c.plates) - int(c.glass) - int(c.armour), "x", "riveted to rings and stringers"],
		["Armour plates", c.armour, "x", "riveted over the frame, thicker"],
		["Glass panels", c.glass, "x", "set in the frame"],
		["Wings, fins, pods and fairings", c.get("limbs", 0), "x", "framed and plated, bolted to the hull's rings"],
		["Pod struts", c.get("struts", 0), "x", "girders bolted body to pod"],
		["Outer door frames", c.openings, "x", "posts and rails welded in"],
		["Deck plates", c.deck_plates, "x", "spot welded to beams and girders"],
		["Wall studs", c.studs, "x", "welded to the sills"],
		["Wall panels", c.wall_panels, "x", "bolted to the studs"],
		["Frame members", roundi(float(c.member_m)), "m", "steel section, cut to length"],
		["Hull skin", roundi(float(c.skin_m2)), "m2", "plate, cut to shape"],
		["Welds", c.welds, "x", ""],
		["Rivets", c.rivets, "x", ""],
		["Bolts", c.bolts, "x", ""],
	]:
		if int(row[1]) > 0:
			out.append({"name": row[0], "qty": int(row[1]), "unit": row[2], "how": row[3]})
	return out


static func _rect_near(st: Array, z: float) -> Rect2:
	return st[station_at({"stations": st}, z)].rect


## Builds the proposal into `kit` (a ShipKit with a PartModel) as parts and joints: the rings,
## stringers, nodes and skin, the openings framed, the end caps. `mats`: shell, frame, glass
## (Materials; plain paint if left out). Returns the FrameHull (its parts: rings (nodes all null),
## stringers, plates, cap_plates, jambs; its joints: welds, rivets, jamb_welds).
static func build(p: Dictionary, kit: ShipKit, mats: Dictionary = {}) -> FrameHull:
	var shell: Material = mats.get("shell", ShipKit.paint(Color(0.56, 0.58, 0.6), 0.35, 0.45))
	var steel: Material = mats.get("frame", ShipKit.paint(Color(0.34, 0.36, 0.38), 0.75, 0.4))
	var glass: Material = mats.get("glass", _glass())
	var h := FrameHull.new(kit, str(p.style), shell, steel, glass)
	h.name = "hull"
	h.groove = 0.0
	# No node blocks (beenster, 21 Nov: "why can't we just join the row beams?"): the ring's
	# girders meet on each corner, cut to the bisector and welded round the seam, and the
	# stringers butt onto the ring (Void Salvage's mitred joints, F10). Those want box members,
	# so a channel frame is built in box girders of the same size.
	if str(h.spec.get("section", "box")) != "box":
		h.spec = h.spec.duplicate()
		h.spec["section"] = "box"
	h.mitred_joints = true
	for st: Dictionary in p.stations:
		h.add_station(float(st.z), st.profile, str(st.label))
	var panes: Dictionary = p.glass
	var armour: Dictionary = p.get("armour", {})
	var open: Dictionary = p.get("open", {})
	var armour_mat: Material = mats.get("armour", ShipKit.paint(Color(0.3, 0.33, 0.3), 0.6, 0.55))
	# Painted (DesignLivery): each colour one material, armour a shade darker.
	var tints := {}
	var tint := func(c: Color, dark: bool) -> Material:
		var key := c.to_html(false) + ("a" if dark else "")
		if not tints.has(key):
			tints[key] = ShipKit.paint(c.darkened(0.25) if dark else c, 0.45, 0.5, "satin_paint")
		return tints[key]
	h.style = func(seg: int, edge: int) -> Dictionary:
		var gk := "%d:%d" % [seg, edge]
		if open.has(gk):
			return {"skip": true}
		if panes.has(gk):
			return {"mat": glass, "glass": true}
		var col: Variant = DesignLivery.colour(p, seg, edge)
		if armour.has(gk):
			return {"mat": armour_mat if col == null else tint.call(col, true), "name": "ArmourPlate"}
		return {"mat": shell if col == null else tint.call(col, false)}
	var no_stringer: Dictionary = p.get("no_stringer", {})
	h.corner_skip = func(seg: int, corner: int) -> bool:
		return no_stringer.has("%d:%d" % [seg, corner])
	var skip: Dictionary = p.skip
	h.frame_skip = func(station: int, edge: int) -> bool:
		return skip.has("%d:%d" % [station, edge])
	for o: Dictionary in p.openings:
		if int(o.edge) >= 0:
			h.opening(int(o.edge), o.box, str(o.name))
	h.build()
	var st: Array = p.stations
	for end in 2:
		var outline: PackedVector2Array = st[0 if end == 0 else st.size() - 1].profile
		var holes: Array = []
		for o: Dictionary in p.openings:
			if int(o.get("cap", -1)) == end:
				holes.append(o.hole)
		var pieces := _cut(outline, holes)
		var glazed := bool((p.get("cap_glass", [false, false]) as Array)[end])
		var cap_col: Variant = DesignLivery.cap_colour(p)
		var cap_mat: Material = shell if cap_col == null else tint.call(cap_col, false)
		h.cap(end, pieces, glass if glazed else cap_mat, "", glazed)
	# Her wings, fins, pods and fairings, in her base colour (the trim on a wing's or fin's tip).
	var limb_mat := func(_seg: int, edge: int, limb: Dictionary) -> Material:
		var l: Dictionary = p.get("livery", {})
		if l.is_empty():
			return shell
		var tip := str(limb.type) in ["wing", "fin"] and edge == (1 if str(limb.type) == "fin" or float(limb.side) > 0.0 else 3)
		return tint.call(DesignLivery.trim(l) if tip else DesignLivery.base(l), false)
	h.set_meta("limbs", DesignShape.build(p, h, kit, steel, glass, limb_mat))
	var lining: Material = mats.get("lining", ShipKit.paint(Color(0.52, 0.54, 0.54), 0.2, 0.6))
	var plating: Material = mats.get("deck", ShipKit.paint(Color(0.46, 0.48, 0.5), 0.6, 0.45))
	var decks: Array[DeckFrame] = []
	for dk: Dictionary in p.get("decks", []):
		var df := DeckFrame.new(h, plating, steel)
		df.top = float(dk.top)
		df.z0 = float(dk.z0)
		df.z1 = float(dk.z1)
		df.level = "" if decks.is_empty() else "d%d" % int(dk.deck)
		df.trim_girders = true
		var r := _rect_near(st, (df.z0 + df.z1) * 0.5)
		var lanes := maxi(1, ceili(r.size.x / LANE))
		for i in range(1, lanes):
			df.girder_x.append(r.position.x + r.size.x * float(i) / lanes)
		for o: Rect2 in dk.openings:
			df.openings.append(o)
		df.build()
		decks.append(df)
	var walls: Array[StudWall] = []
	for w: Dictionary in p.get("walls", []):
		var y0 := float(w.y0)
		var y1 := float(w.y1)
		var t0 := float(w.t0)
		var t1 := float(w.t1)
		var name := "d%d_%s_%.1f_%.1f" % [int(w.deck), "x" if w.across else "z", float(w.at), t0]
		var sw := StudWall.new(h.target, name, float(w.at) if w.across else 0.0, INNER_WALL,
				PackedVector2Array([Vector2(t0, y0), Vector2(t1, y0), Vector2(t1, y1), Vector2(t0, y1)]), lining, steel)
		if not w.across:
			sw.frame = StudWall.along(float(w.at))
		sw.floor_y = y0
		sw.spacing = STUD
		for o: Array in w.doors:
			sw.openings.append(Rect2(float(o[0]) - float(o[1]) * 0.5, y0, float(o[1]), float(o[2])))
		sw.build()
		walls.append(sw)
	h.set_meta("decks", decks)
	h.set_meta("walls", walls)
	return h


## What a frame part and a joint near it are, for the walk-inside label: "Frame ring, frame 3,
## starboard side\nWeld here (to the frame ring)". `model` holds both.
static func describe(part: PartData, joint: ConnectionData = null, model: PartModel = null) -> String:
	if part == null:
		return "Hull structure"
	var what: String = PART_NAMES.get(part.part_name, part.part_name)
	var where: Array[String] = []
	for b in part.path.split("/"):
		if b.begins_with("st:"):
			where.append("frame %s" % b.get_slice(":", 1).trim_prefix("f"))
		elif b.begins_with("bay:"):
			where.append("bay %s" % b.get_slice(":", 1).trim_prefix("f"))
		elif b.begins_with("opening:"):
			where.append("round a door")
		elif b.length() >= 2 and b[0] == "e" and b.substr(1).is_valid_int():
			where.append(EDGE_NAMES[int(b.substr(1)) % SIDES])
		elif b.length() >= 2 and b[0] == "c" and b.substr(1).is_valid_int():
			where.append("corner %d" % int(b.substr(1)))
		elif b == "front" or b == "back":
			where.append("bow end" if b == "front" else "stern end")
	var text := what if where.is_empty() else "%s, %s" % [what, ", ".join(where)]
	if joint:
		text += "\n%s here" % JOINT_NAMES.get(joint.kind, "Joint")
		var other := joint.part_b if joint.part_a == part.id else joint.part_a
		if model and model.parts.has(other) and (joint.part_a == part.id or joint.part_b == part.id):
			var on: PartData = model.parts[other]
			text += " (to the %s)" % str(PART_NAMES.get(on.part_name, on.part_name)).to_lower()
	return text


# --- Working it out -------------------------------------------------------------------

## Everything the hull goes round, as z bands: [{z0, z1, x0, x1, deck}]: each room, and each
## drawn hull outline cut into strips along the ship.
static func _content(d: DesignRecord) -> Array:
	var out: Array = []
	for r: Dictionary in d.rooms.values():
		out.append({"z0": float(r.z), "z1": float(r.z) + float(r.d), "x0": float(r.x), "x1": float(r.x) + float(r.w),
				"deck": int(r.deck)})
	for key: String in d.hull:
		var outline := d.hull_outline(int(key))
		if outline.size() < 3:
			continue
		var lo := INF
		var hi := -INF
		for q in outline:
			lo = minf(lo, q.y)
			hi = maxf(hi, q.y)
		var strips := maxi(1, ceili((hi - lo) / 0.5))
		for k in strips:
			var a := lerpf(lo, hi, float(k) / strips)
			var b := lerpf(lo, hi, float(k + 1) / strips)
			var xs := _x_range(outline, a, b)
			if xs.x <= xs.y:
				out.append({"z0": a, "z1": b, "x0": xs.x, "x1": xs.y, "deck": int(key)})
	return out


## The x range of a polygon (x, z) between z = a and z = b: (INF, -INF) if it has none.
static func _x_range(poly: PackedVector2Array, a: float, b: float) -> Vector2:
	var band := PackedVector2Array([Vector2(-1e5, a), Vector2(1e5, a), Vector2(1e5, b), Vector2(-1e5, b)])
	var lo := INF
	var hi := -INF
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, band):
		for q in piece:
			lo = minf(lo, q.x)
			hi = maxf(hi, q.x)
	return Vector2(lo, hi)


## What lies between z = a and z = b: {x0, x1, lo, hi} (decks lowest and highest), {} if nothing.
static func _span(content: Array, a: float, b: float) -> Dictionary:
	var out := {}
	for c: Dictionary in content:
		if float(c.z1) < a - 0.001 or float(c.z0) > b + 0.001:
			continue
		if out.is_empty():
			out = {"x0": c.x0, "x1": c.x1, "lo": c.deck, "hi": c.deck}
			continue
		out.x0 = minf(out.x0, c.x0)
		out.x1 = maxf(out.x1, c.x1)
		out.lo = mini(out.lo, c.deck)
		out.hi = maxi(out.hi, c.deck)
	return out


## Glass over the bridge: the roof and shoulders of every bay over a bridge on the top deck
## there, and the nose cap if a bridge is at the front.
static func _glaze(d: DesignRecord, p: Dictionary) -> void:
	var st: Array = p.stations
	var glass: Dictionary = p.glass
	var caps := [false, false]
	var body: Array = p.get("body", [0, st.size() - 1])
	var zmin := float(st[int(body[0])].z) + float(p.clearance)
	for r: Dictionary in d.rooms.values():
		if not str(r.type) in GLAZED:
			continue
		var top := true
		for o: Dictionary in d.rooms.values():
			if int(o.deck) > int(r.deck) and Rect2(o.x, o.z, o.w, o.d).intersects(Rect2(r.x, r.z, r.w, r.d)):
				top = false
		if not top:
			continue
		for k in st.size() - 1:
			if float(st[k + 1].z) > float(r.z) and float(st[k].z) < float(r.z) + float(r.d):
				for e in [7, 0, 1]:
					glass["%d:%d" % [k, e]] = true
		if float(r.z) <= zmin + 0.01:
			caps[0] = true
	# A bridge at the bow with a nose drawn out ahead of it: the nose's top glazed, a canopy.
	if caps[0] and int(body[0]) > 0:
		for k in int(body[0]):
			for e in [7, 0, 1]:
				glass["%d:%d" % [k, e]] = true
	p["cap_glass"] = caps


## Which of her ends (front, back) a door to space opens through: no nose or stern there.
static func _end_doors(d: DesignRecord, st: Array, clear: float) -> Array:
	var out := [false, false]
	for g: Dictionary in d.doors.values():
		if str(g.get("b", "")) != "" and str(g.get("a", "")) != "":
			continue
		var room_id := str(g.a) if str(g.get("a", "")) != "" else str(g.b)
		if not d.rooms.has(room_id):
			continue
		var end := _door_end(d.rooms[room_id], g)
		if end < 0:
			continue
		var cap_z := float(st[st.size() - 1 if end == 1 else 0].z)
		if absf(cap_z - float(g.z)) <= clear + 0.05:
			out[end] = true
	return out


## The end a door faces (0 front, 1 back), or -1 for a door in a side.
static func _door_end(r: Dictionary, g: Dictionary) -> int:
	var x := float(g.x)
	var z := float(g.z)
	var sides := {"px": absf(x - float(r.x) - float(r.w)), "nx": absf(x - float(r.x)),
			"pz": absf(z - float(r.z) - float(r.d)), "nz": absf(z - float(r.z))}
	var best := "px"
	for k: String in sides:
		if float(sides[k]) < float(sides[best]):
			best = k
	return 1 if best == "pz" else (0 if best == "nz" else -1)


## Doors to space: each one cut through the skin in front of it (a side) or through an end cap.
static func _openings(d: DesignRecord, p: Dictionary) -> void:
	var st: Array = p.stations
	var h := d.deck_height
	var clear := float(p.clearance)
	for g: Dictionary in d.doors.values():
		if str(g.get("b", "")) != "" and str(g.get("a", "")) != "":
			continue
		var room_id := str(g.a) if str(g.get("a", "")) != "" else str(g.b)
		if not d.rooms.has(room_id):
			continue
		var r: Dictionary = d.rooms[room_id]
		var dw := DesignCatalog.door_w(g)
		var dh := DesignCatalog.door_h(g)
		var x := float(g.x)
		var z := float(g.z)
		var y0 := int(g.deck) * h
		var sides := {"px": absf(x - float(r.x) - float(r.w)), "nx": absf(x - float(r.x)),
				"pz": absf(z - float(r.z) - float(r.d)), "nz": absf(z - float(r.z))}
		var best := "px"
		for k: String in sides:
			if float(sides[k]) < float(sides[best]):
				best = k
		var name := "door_%s" % str(g.id)
		var far := 50.0
		match best:
			"px", "nx":
				var s := 1.0 if best == "px" else -1.0
				var edge := STARBOARD if s > 0.0 else PORT
				var box := AABB(Vector3(x if s > 0.0 else x - far, y0, z - dw * 0.5), Vector3(far, dh, dw))
				(p.openings as Array).append({"name": name, "edge": edge, "box": box})
				# No ring girder across the doorway: the jambs carry round it.
				for i in st.size():
					if absf(float(st[i].z) - z) < dw * 0.5 + 0.3:
						p.skip["%d:%d" % [i, edge]] = true
				_square_up(st, z - dw * 0.5, z + dw * 0.5)
			"pz", "nz":
				var end := 1 if best == "pz" else 0
				var cap_z := float(st[st.size() - 1 if end == 1 else 0].z)
				# Only a door in the end the ship stops at; one facing aft halfway along opens
				# into the hull's own space.
				if absf(cap_z - z) > clear + 0.05:
					continue
				(p.openings as Array).append({"name": name, "edge": -1, "cap": end,
						"hole": Rect2(x - dw * 0.5, y0, dw, dh)})


## The stations either side of z0..z1 (and one more each way, so none of them leans) all take
## the section that holds them all, so the face the opening is cut in is one prism there and
## its jambs can be framed.
static func _square_up(st: Array, z0: float, z1: float) -> void:
	var lo := 0
	var hi := st.size() - 1
	for i in st.size():
		if float(st[i].z) <= z0:
			lo = i
		if float(st[st.size() - 1 - i].z) >= z1:
			hi = st.size() - 1 - i
	lo = maxi(lo - 1, 0)
	hi = mini(hi + 1, st.size() - 1)
	var r: Rect2 = st[lo].rect
	for i in range(lo, hi + 1):
		r = r.merge(st[i].rect)
	for i in range(lo, hi + 1):
		st[i].rect = r
		st[i].profile = section(r)


## An end's outline with door holes cut out, as convex pieces (the strips round each hole).
static func _cut(outline: PackedVector2Array, holes: Array) -> Array:
	var pieces: Array = [outline]
	for hole: Rect2 in holes:
		var next: Array = []
		var far := 1e4
		var around := [Rect2(-far, -far, far + hole.position.x, far * 2.0),
				Rect2(hole.end.x, -far, far, far * 2.0),
				Rect2(hole.position.x, hole.end.y, hole.size.x, far),
				Rect2(hole.position.x, -far, hole.size.x, far + hole.position.y)]
		for piece: PackedVector2Array in pieces:
			for r: Rect2 in around:
				var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
				for part: PackedVector2Array in Geometry2D.intersect_polygons(piece, box):
					if part.size() >= 3 and absf(_area(part)) > 0.01:
						next.append(part)
		pieces = next
	return pieces


static func _glass() -> StandardMaterial3D:
	var g := ShipKit.glass()
	g.albedo_color = Color(0.45, 0.65, 0.85, 0.28)
	g.metallic = 0.4
	g.roughness = 0.04
	return g


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


static func _perimeter(p: PackedVector2Array) -> float:
	var l := 0.0
	for i in p.size():
		l += p[i].distance_to(p[(i + 1) % p.size()])
	return l
