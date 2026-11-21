class_name DesignShape
extends RefCounted
## Her free shapes (plan 3.10, the outside designer, stage 2): a nose and a stern drawn out of
## the hull, and wings, fins, pods on struts and fairings fixed to it, every one built as real
## frames and plates (FrameHull, as the ship generator builds its wings and nacelles) and
## bolted to the hull's rings. rec.shapes: id -> {id, type, ...the type's fields (FIELDS)}.
##   nose, stern: the end frames drawn out `length` m to a tip `tip` of the body's size,
##     rounded, the tip raised or dropped by `drop` (-1 belly to 1 roof).
##   wing: a slab off both sides (or one, `mirror` off) at `at` up the side, `chord` long at the
##     root and `tip_chord` at the tip, the tip `sweep` m aft, `span` out, `thick` at the root,
##     the tip `dihedral` m up.
##   fin: a slab up off the roof (or down off the belly, `face`), `x` off the centre line.
##   pod: an eight-sided pod `length` long and `radius` round, `gap` out from the side at `at`
##     up it, on two struts.
##   fairing: a flattened pod laid on the roof, side or belly (`face`), bolted on.
## propose() calls extend() (the ends) and limbs() (the rest); DesignFrame.build builds them.

const TYPES := ["nose", "stern", "wing", "fin", "pod", "fairing"]
## The two that change the hull's own ends: one of each.
const ENDS := ["nose", "stern"]
const NAMES := {"nose": "Nose", "stern": "Tapered stern", "wing": "Wings", "fin": "Fin", "pod": "Pods on struts",
		"fairing": "Fairing"}
## Each type's fields: [field, label, default, min, max, step]. z is set where it is added.
const FIELDS := {
	"nose": [["length", "LENGTH", 4.0, 1.0, 12.0, 0.5], ["tip", "TIP SIZE", 0.35, 0.15, 1.0, 0.05],
			["drop", "TIP HEIGHT", 0.0, -1.0, 1.0, 0.25]],
	"stern": [["length", "LENGTH", 3.0, 1.0, 10.0, 0.5], ["tip", "TIP SIZE", 0.55, 0.15, 1.0, 0.05],
			["drop", "TIP HEIGHT", 0.25, -1.0, 1.0, 0.25]],
	"wing": [["chord", "ROOT CHORD", 4.0, 1.0, 16.0, 0.5], ["tip_chord", "TIP CHORD", 1.8, 0.5, 16.0, 0.25],
			["sweep", "SWEEP", 1.5, -6.0, 10.0, 0.25], ["span", "SPAN", 4.0, 1.0, 16.0, 0.5],
			["thick", "THICKNESS", 0.4, 0.2, 1.2, 0.05], ["at", "HEIGHT ON SIDE", 0.35, 0.0, 1.0, 0.05],
			["dihedral", "TIP UP", 0.0, -3.0, 3.0, 0.25]],
	"fin": [["chord", "ROOT CHORD", 3.0, 1.0, 12.0, 0.5], ["tip_chord", "TIP CHORD", 1.2, 0.5, 12.0, 0.25],
			["sweep", "SWEEP", 1.4, -6.0, 8.0, 0.25], ["height", "HEIGHT", 2.5, 0.5, 10.0, 0.25],
			["thick", "THICKNESS", 0.3, 0.2, 1.0, 0.05], ["x", "OFF CENTRE", 0.0, 0.0, 10.0, 0.25]],
	"pod": [["length", "LENGTH", 5.0, 1.5, 20.0, 0.5], ["radius", "RADIUS", 0.7, 0.3, 3.0, 0.1],
			["gap", "STRUT LENGTH", 0.8, 0.2, 4.0, 0.1], ["at", "HEIGHT ON SIDE", 0.5, 0.0, 1.0, 0.05]],
	"fairing": [["length", "LENGTH", 4.0, 1.0, 16.0, 0.5], ["radius", "SIZE", 0.6, 0.25, 2.5, 0.05],
			["x", "OFF CENTRE", 0.0, 0.0, 10.0, 0.25], ["at", "HEIGHT ON SIDE", 0.5, 0.0, 1.0, 0.05]],
}
## The faces a fin or a fairing can stand on.
const FACES := {"fin": ["roof", "belly"], "fairing": ["roof", "side", "belly"]}
## A nose's or stern's frames are no further apart than this, m, so the curve reads.
const END_STEP := 1.2
## The smallest a tip gets, m across.
const TIP_MIN := 0.6
## Room between a limb and the skin it is bolted through, m.
const ROOT_GAP := 0.03


## A new shape of `type` at `z` along the ship, with its type's defaults.
static func make(type: String, z: float = 0.0) -> Dictionary:
	var out := {"type": type, "z": z}
	for f: Array in FIELDS.get(type, []):
		out[f[0]] = f[2]
	if type in ["wing", "pod"]:
		out["mirror"] = true
	if FACES.has(type):
		out["face"] = FACES[type][0]
	return out


## A shape's field, its type's default when unset, kept in its range.
static func field(s: Dictionary, key: String) -> float:
	for f: Array in FIELDS.get(str(s.get("type", "")), []):
		if f[0] == key:
			return clampf(float(s.get(key, f[2])), float(f[3]), float(f[4]))
	return float(s.get(key, 0.0))


## Whether a shape is built on both sides.
static func mirrored(s: Dictionary) -> bool:
	match str(s.get("type", "")):
		"wing", "pod":
			return bool(s.get("mirror", true))
		"fin", "fairing":
			var side := str(s.get("type")) == "fairing" and str(s.get("face", "roof")) == "side"
			return side or field(s, "x") > 0.05
	return false


static func describe(s: Dictionary) -> String:
	var n := str(NAMES.get(str(s.get("type", "")), "Shape"))
	if FACES.has(str(s.get("type", ""))):
		n += " on the " + str(s.get("face", "roof"))
	return n


## The design's nose and stern (or {}).
static func end_shape(d: DesignRecord, type: String) -> Dictionary:
	for s: Dictionary in d.shapes.values():
		if str(s.type) == type:
			return s
	return {}


# The hull's ends -------------------------------------------------------------------------

## Draws the hull's stations out into the nose and the stern: frames before the first and after
## the last, each a rounded step smaller. Not at an end a door opens through (`doors`: [front,
## back]); notes it in p.shape_blocked. Sets p.body: the body's first and last station index.
static func extend(d: DesignRecord, p: Dictionary, doors: Array) -> void:
	var st: Array = p.stations
	p["body"] = [0, st.size() - 1]
	p["shape_blocked"] = []
	if st.is_empty():
		return
	for end in 2:
		var s := end_shape(d, ENDS[end])
		if s.is_empty():
			continue
		if bool(doors[end]):
			(p.shape_blocked as Array).append(str(s.id))
			continue
		var base: Dictionary = st[0 if end == 0 else st.size() - 1]
		var r: Rect2 = base.rect
		var length := field(s, "length")
		var tip := field(s, "tip")
		var drop := field(s, "drop")
		var n := maxi(2, ceili(length / END_STEP))
		var made: Array = []
		for j in range(1, n + 1):
			var t := float(j) / n
			# Rounded: square to the body where it starts, quickest toward the tip.
			var f := lerpf(1.0, tip, t * t)
			var size := Vector2(maxf(r.size.x * f, TIP_MIN), maxf(r.size.y * f, TIP_MIN))
			var c := r.get_center() + Vector2(0.0, drop * (r.size.y - size.y) * 0.5)
			var rr := Rect2(c - size * 0.5, size)
			var z := float(base.z) + (-length if end == 0 else length) * t
			made.append({"z": z, "label": "", "rect": rr, "profile": DesignFrame.section(rr), "shape": str(s.id)})
		if end == 0:
			made.reverse()
			p.stations = made + st
			(p.body as Array)[0] = made.size()
			(p.body as Array)[1] += made.size()
		else:
			p.stations = st + made
		st = p.stations
	for i in st.size():
		st[i].label = "f%d" % i


# Limbs -----------------------------------------------------------------------------------

## The limbs to build for the design: [{id, shape, type, side (1 starboard, -1 port, 0 on the
## centre line), name, style, stations: [{z, label, profile}], body_edge (the hull's edge it
## is bolted through), inboard (its own edge against the hull), pylons: bool}].
static func limbs(d: DesignRecord, p: Dictionary) -> Array:
	var out: Array = []
	if (p.get("stations", []) as Array).size() < 2:
		return out
	var ids := d.shapes.keys()
	ids.sort()
	for sid: String in ids:
		var s: Dictionary = d.shapes[sid]
		var type := str(s.type)
		if type in ENDS:
			continue
		var sides: Array[float] = [1.0, -1.0]
		if not mirrored(s):
			sides.clear()
			sides.append(0.0 if type in ["fin", "fairing"] and str(s.get("face", "roof")) != "side" else 1.0)
		for side: float in sides:
			var limb := _limb(p, s, side)
			if limb.is_empty():
				continue
			limb["id"] = sid
			limb["shape"] = sid
			limb["type"] = type
			limb["side"] = side
			limb["name"] = "shape_%s_%s" % [sid, "c" if side == 0.0 else ("s" if side > 0.0 else "p")]
			out.append(limb)
	return out


static func _limb(p: Dictionary, s: Dictionary, side: float) -> Dictionary:
	match str(s.type):
		"wing":
			return _wing(p, s, side)
		"fin":
			return _fin(p, s, side)
		"pod":
			return _pod(p, s, side, false)
		"fairing":
			return _pod(p, s, side, true)
	return {}


## The hull at z0..z1: its widest side (x), the side plate's lowest and highest points (the
## flat stretch the limbs stand on), the roof's highest and the belly's lowest.
static func hull_at(p: Dictionary, z0: float, z1: float) -> Dictionary:
	var st: Array = p.stations
	var x := 0.0
	var lo := -INF
	var hi := INF
	var roof := -INF
	var belly := INF
	var any := false
	for i in st.size():
		var z := float(st[i].z)
		if z < z0 - 0.01 or z > z1 + 0.01:
			continue
		any = true
		var pr: PackedVector2Array = st[i].profile
		x = maxf(x, pr[DesignFrame.STARBOARD].x)
		lo = maxf(lo, pr[DesignFrame.STARBOARD + 1].y)
		hi = minf(hi, pr[DesignFrame.STARBOARD].y)
		roof = maxf(roof, pr[DesignFrame.ROOF_EDGE].y)
		belly = minf(belly, pr[DesignFrame.BELLY_EDGE].y)
	if not any:
		var pr: PackedVector2Array = st[DesignFrame.station_at(p, (z0 + z1) * 0.5)].profile
		return {"x": pr[2].x, "lo": pr[3].y, "hi": pr[2].y, "roof": pr[0].y, "belly": pr[4].y}
	if hi < lo:
		var m := (hi + lo) * 0.5
		hi = m
		lo = m
	return {"x": x, "lo": lo, "hi": hi, "roof": roof, "belly": belly}


## The body's station z values between z0 and z1 (for the limb's ribs to bolt to), merged
## with the limb's own and kept 0.25 m apart.
static func _zs(p: Dictionary, own: Array, z0: float, z1: float) -> Array[float]:
	var zs: Array[float] = []
	for z: float in own:
		zs.append(z)
	for st: Dictionary in p.stations:
		var z := float(st.z)
		if z > z0 + 0.3 and z < z1 - 0.3:
			zs.append(z)
	zs.sort()
	var clean: Array[float] = []
	for z: float in zs:
		if clean.is_empty() or z - clean[clean.size() - 1] > 0.25:
			clean.append(z)
	return clean


## The share of the way out (0 root, 1 tip) a planform covers at z: [from, to], or [] where it
## does not reach. Root chord z0..z1, tip chord zt0..zt1.
static func _reach(z: float, z0: float, z1: float, zt0: float, zt1: float) -> Array:
	var a := 0.0
	var b := 1.0
	# Leading edge: lerp(z0, zt0, u) <= z.
	if absf(zt0 - z0) < 0.001:
		if z < z0 - 0.001:
			return []
	elif zt0 > z0:
		b = minf(b, (z - z0) / (zt0 - z0))
	else:
		a = maxf(a, (z - z0) / (zt0 - z0))
	# Trailing edge: lerp(z1, zt1, u) >= z.
	if absf(zt1 - z1) < 0.001:
		if z > z1 + 0.001:
			return []
	elif zt1 < z1:
		b = minf(b, (z - z1) / (zt1 - z1))
	else:
		a = maxf(a, (z - z1) / (zt1 - z1))
	if b < a - 0.001:
		return []
	return [clampf(a, 0.0, 1.0), clampf(maxf(a, b), 0.0, 1.0)]


## A planform's stations: at both chords' ends and the body's rings between, each section
## from `section.call(u0, u1)` (shares of the way out), a stub at least `stub` of the way where
## the planform narrows to a point.
static func _planform(p: Dictionary, z: float, chord: float, tip_chord: float, sweep: float,
		stub: float, section: Callable) -> Array:
	var z0 := z - chord * 0.5
	var z1 := z + chord * 0.5
	var zt0 := z0 + sweep
	var zt1 := zt0 + minf(tip_chord, chord + absf(sweep) + 8.0)
	var lo := minf(z0, zt0)
	var hi := maxf(z1, zt1)
	var stations: Array = []
	var zs := _zs(p, [z0, z1, zt0, zt1], lo, hi)
	for k in zs.size():
		var q := clampf(zs[k], lo + 0.001, hi - 0.001)
		var r := _reach(q, z0, z1, zt0, zt1)
		if r.is_empty():
			continue
		var u0: float = r[0]
		var u1: float = r[1]
		if u1 - u0 < stub:
			var mid := (u0 + u1) * 0.5
			u0 = maxf(0.0, mid - stub * 0.5)
			u1 = u0 + stub
		stations.append({"z": zs[k], "label": "w%d" % stations.size(), "profile": section.call(u0, u1)})
	return stations


static func _wing(p: Dictionary, s: Dictionary, side: float) -> Dictionary:
	var z := float(s.get("z", 0.0))
	var chord := field(s, "chord")
	var tip_chord := field(s, "tip_chord")
	var sweep := field(s, "sweep")
	var span := field(s, "span")
	var thick := field(s, "thick")
	var dihedral := field(s, "dihedral")
	var hull := hull_at(p, minf(z - chord * 0.5, z - chord * 0.5 + sweep), maxf(z + chord * 0.5, z - chord * 0.5 + sweep + tip_chord))
	var root_x := float(hull.x) + ROOT_GAP
	var y := lerpf(float(hull.lo), float(hull.hi), field(s, "at"))
	var stub := clampf(0.4 / span, 0.02, 0.5)
	var section := func(u0: float, u1: float) -> PackedVector2Array:
		var xa := root_x + span * u0
		var xb := root_x + span * u1
		var ya := y + dihedral * u0
		var yb := y + dihedral * u1
		var ta := lerpf(thick, thick * 0.4, u0)
		var tb := lerpf(thick, thick * 0.4, u1)
		# Edges: starboard 0 top, 1 tip, 2 bottom, 3 root; port 0 top, 1 root, 2 bottom, 3 tip.
		if side > 0.0:
			return PackedVector2Array([Vector2(xa, ya + ta * 0.5), Vector2(xb, yb + tb * 0.5),
					Vector2(xb, yb - tb * 0.5), Vector2(xa, ya - ta * 0.5)])
		return PackedVector2Array([Vector2(-xb, yb + tb * 0.5), Vector2(-xa, ya + ta * 0.5),
				Vector2(-xa, ya - ta * 0.5), Vector2(-xb, yb - tb * 0.5)])
	var stations := _planform(p, z, chord, tip_chord, sweep, stub, section)
	if stations.size() < 2:
		return {}
	return {"style": "wing", "stations": stations, "body_edge": DesignFrame.STARBOARD if side > 0.0 else DesignFrame.PORT,
			"inboard": 3 if side > 0.0 else 1, "root_x": root_x, "pylons": false}


static func _fin(p: Dictionary, s: Dictionary, side: float) -> Dictionary:
	var z := float(s.get("z", 0.0))
	var chord := field(s, "chord")
	var tip_chord := field(s, "tip_chord")
	var sweep := field(s, "sweep")
	var height := field(s, "height")
	var thick := field(s, "thick")
	var up := str(s.get("face", "roof")) != "belly"
	var x := field(s, "x") * (side if side != 0.0 else 1.0)
	var hull := hull_at(p, minf(z - chord * 0.5, z - chord * 0.5 + sweep), maxf(z + chord * 0.5, z - chord * 0.5 + sweep + tip_chord))
	var base := (float(hull.roof) + ROOT_GAP) if up else (float(hull.belly) - ROOT_GAP)
	var dir := 1.0 if up else -1.0
	var stub := clampf(0.4 / height, 0.02, 0.5)
	var section := func(u0: float, u1: float) -> PackedVector2Array:
		var ya := base + dir * height * u0
		var yb := base + dir * height * u1
		var ta := lerpf(thick, thick * 0.4, u0)
		var tb := lerpf(thick, thick * 0.4, u1)
		# Edges: 0 port face, 1 tip, 2 starboard face, 3 root.
		return PackedVector2Array([Vector2(x - ta * 0.5, ya), Vector2(x - tb * 0.5, yb), Vector2(x + tb * 0.5, yb),
				Vector2(x + ta * 0.5, ya)])
	var stations := _planform(p, z, chord, tip_chord, sweep, stub, section)
	if stations.size() < 2:
		return {}
	return {"style": "wing", "stations": stations, "body_edge": DesignFrame.ROOF_EDGE if up else DesignFrame.BELLY_EDGE,
			"inboard": 3, "pylons": false}


## An eight-sided section round (cx, cy), `rx` across and `ry` up to its flats.
static func octagon(cx: float, cy: float, rx: float, ry: float) -> PackedVector2Array:
	var ax := 0.42 * rx
	var ay := 0.42 * ry
	return PackedVector2Array([Vector2(cx - ax, cy + ry), Vector2(cx + ax, cy + ry), Vector2(cx + rx, cy + ay), Vector2(cx + rx, cy - ay),
			Vector2(cx + ax, cy - ry), Vector2(cx - ax, cy - ry), Vector2(cx - rx, cy - ay), Vector2(cx - rx, cy + ay)])


static func _pod(p: Dictionary, s: Dictionary, side: float, fairing: bool) -> Dictionary:
	var length := field(s, "length")
	var r := field(s, "radius")
	var z0 := float(s.get("z", 0.0)) - length * 0.5
	var z1 := z0 + length
	var hull := hull_at(p, z0, z1)
	var cx := 0.0
	var cy := 0.0
	var rx := r
	var ry := r
	var edge := DesignFrame.STARBOARD if side >= 0.0 else DesignFrame.PORT
	var inboard := DesignFrame.PORT if side >= 0.0 else DesignFrame.STARBOARD
	var face := str(s.get("face", "side")) if fairing else "side"
	match face:
		"roof", "belly":
			# Laid flat on the skin: half as tall as it is wide.
			ry = r * 0.5
			var up := face == "roof"
			cx = field(s, "x") * (side if side != 0.0 else 1.0)
			cy = (float(hull.roof) + ROOT_GAP + ry) if up else (float(hull.belly) - ROOT_GAP - ry)
			edge = DesignFrame.ROOF_EDGE if up else DesignFrame.BELLY_EDGE
			inboard = DesignFrame.BELLY_EDGE if up else DesignFrame.ROOF_EDGE
		_:
			var s2 := 1.0 if side >= 0.0 else -1.0
			if fairing:
				rx = r * 0.5
			ry = minf(ry, maxf((float(hull.hi) - float(hull.lo)) * 0.5, 0.3)) if fairing else ry
			var out := (ROOT_GAP + rx) if fairing else (field(s, "gap") + rx)
			cx = s2 * (float(hull.x) + out)
			cy = lerpf(float(hull.lo), float(hull.hi), field(s, "at"))
	var nose := minf(1.2, length * 0.3)
	var zs := _zs(p, [z0, z0 + nose, z1 - (nose if fairing else 0.0), z1], z0, z1)
	var stations: Array = []
	for k in zs.size():
		var sc := 1.0
		if k == 0:
			sc = 0.55
		elif k == zs.size() - 1:
			sc = 0.55 if fairing else 0.8
		stations.append({"z": zs[k], "label": "n%d" % k, "profile": octagon(cx, cy, rx * sc, ry * sc)})
	return {"style": "pod", "stations": stations, "body_edge": edge, "inboard": inboard, "pylons": not fairing,
			"centre": Vector2(cx, cy), "r": Vector2(rx, ry)}


# Building ----------------------------------------------------------------------------------

## Builds the plan's limbs into `kit` beside the body `body` (its FrameHull), each bolted to the
## body's ring girders where a rib or ring stands at the same z, pods on two struts. `mat`:
## Callable(seg, edge, limb) -> Material for a plate. Returns the limbs' FrameHulls.
static func build(p: Dictionary, body: FrameHull, kit: ShipKit, steel: Material, glass: Material,
		mat: Callable) -> Array[FrameHull]:
	var out: Array[FrameHull] = []
	for limb: Dictionary in p.get("limbs", []):
		var style := "wing" if str(limb.style) == "wing" else "kestrel"
		var cap_mat: Material = mat.call(-1, -1, limb)
		var h := FrameHull.new(kit, style, cap_mat, steel, glass)
		h.name = str(limb.name)
		h.groove = 0.0
		if style == "kestrel":
			# A pod's frame: lighter than the body's.
			h.ring_width = 0.1
			h.depth = 0.12
			h.node_size = 0.18
			h.stringer_size = 0.1
			h.stringer_depth = 0.12
			h.skin = 0.05
		for st: Dictionary in limb.stations:
			h.add_station(float(st.z), st.profile, str(st.label))
		h.style = func(seg: int, edge: int) -> Dictionary:
			return {"mat": mat.call(seg, edge, limb)}
		h.build()
		var sts: Array = h.stations
		h.cap(0, [sts[0]["profile"]], cap_mat)
		h.cap(1, [sts[sts.size() - 1]["profile"]], cap_mat)
		if bool(limb.pylons):
			_struts(h, body, kit, limb, steel)
		else:
			_root_bolts(h, body, kit, limb)
		out.append(h)
	return out


## The body's ring on edge `e` at z (within 0.25 m), or null.
static func _body_ring(body: FrameHull, e: int, z: float) -> PartData:
	for j in body.stations.size():
		if absf(body.ring_z(j) - z) <= 0.25 and j < body.rings.size():
			var ring: PartData = body.rings[j][e]
			if ring:
				return ring
	return null


## A limb's own member at its station i on its inboard edge (a rib, or a pod's ring girder).
static func _own(h: FrameHull, i: int, inboard: int) -> PartData:
	if not h.ribs.is_empty():
		return h.ribs[i] if i < h.ribs.size() else null
	return h.rings[i][inboard] if i < h.rings.size() else null


## A wing's, fin's or fairing's ribs (rings) bolted through the skin to the body's rings at the
## same z, twice each.
static func _root_bolts(h: FrameHull, body: FrameHull, kit: ShipKit, limb: Dictionary) -> void:
	var e := int(limb.body_edge)
	for i in h.stations.size():
		var own := _own(h, i, int(limb.inboard))
		if own == null:
			continue
		var z := h.ring_z(i)
		var ring := _body_ring(body, e, z)
		if ring == null:
			continue
		var pr: PackedVector2Array = h.stations[i]["profile"]
		var inb := int(limb.inboard)
		var a := pr[inb]
		var b := pr[(inb + 1) % pr.size()]
		var out := FrameHull.edge_out(body.stations[0]["profile"], e)
		for k in 2:
			var at2 := a.lerp(b, 0.25 + 0.5 * k)
			var c := kit.join(own, ring, ConnectionData.Kind.BOLT, Vector3(at2.x, at2.y, z), Vector3(out.x, out.y, 0.0),
					Vector3.ZERO, Vector2.ZERO, "%s/bolt:%s/%d" % [own.path, ring.path, k])
			if c:
				c.phase = "frame"


## A pod's two struts: girders from the body's side ring to the pod's inboard ring, at the two
## aftmost stations where both stand.
static func _struts(h: FrameHull, body: FrameHull, kit: ShipKit, limb: Dictionary, steel: Material) -> void:
	var made := 0
	var e := int(limb.body_edge)
	var c: Vector2 = limb.centre
	var r: Vector2 = limb.r
	var sx := signf(c.x) if absf(c.x) > 0.01 else 1.0
	for i in range(h.stations.size() - 1, -1, -1):
		if made >= 2:
			break
		var own := _own(h, i, int(limb.inboard))
		var z := h.ring_z(i)
		var ring := _body_ring(body, e, z)
		if own == null or ring == null:
			continue
		var pr: PackedVector2Array = body.stations[DesignFrame.station_at({"stations": _plain(body)}, z)]["profile"]
		var a := Vector3(sx * (absf(pr[e].x) + FrameHull.GAP), c.y, z)
		var b := Vector3(sx * (absf(c.x) - r.x - FrameHull.GAP), c.y, z)
		var len := a.distance_to(b)
		if len < 0.1:
			continue
		var shape := PartShapes.girder(len, 0.14, minf(0.5, r.y * 0.8))
		var strut := kit.part("Pylon", PartData.Kind.FRAME, shape, FrameParts.along(a, b), steel, "", 0.6, null,
				"%s/strut/%d" % [h.name, made])
		kit.join(strut, ring, ConnectionData.Kind.BOLT, a, Vector3(-sx, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:body" % strut.path)
		kit.join(strut, own, ConnectionData.Kind.BOLT, b, Vector3(sx, 0, 0), Vector3.ZERO, Vector2.ZERO, "%s/bolt:pod" % strut.path)
		made += 1


static func _plain(body: FrameHull) -> Array:
	var out: Array = []
	for s: Dictionary in body.stations:
		out.append({"z": float(s.z)})
	return out


# Measuring ---------------------------------------------------------------------------------

## A limb's members, skin, plates and joints, estimated before it is built (DesignFrame.counts).
static func counts(limb: Dictionary) -> Dictionary:
	var st: Array = limb.stations
	var member_m := 0.0
	var skin_m2 := 0.0
	var plates := 0
	for i in st.size():
		var a: PackedVector2Array = st[i].profile
		var n := a.size()
		for k in n:
			member_m += a[k].distance_to(a[(k + 1) % n])
		if i == 0 or i == st.size() - 1:
			skin_m2 += absf(_area(a))
			plates += 1
		if i == 0:
			continue
		var b: PackedVector2Array = st[i - 1].profile
		var dz := float(st[i].z) - float(st[i - 1].z)
		for k in n:
			var la := a[k].distance_to(a[(k + 1) % n])
			var lb := b[k].distance_to(b[(k + 1) % n])
			var along := Vector3(a[k].x - b[k].x, a[k].y - b[k].y, dz).length()
			member_m += along
			skin_m2 += (la + lb) * 0.5 * along
			plates += 1
	var n0: int = (st[0].profile as PackedVector2Array).size() if not st.is_empty() else 0
	var struts := 2 if bool(limb.get("pylons", false)) else 0
	if struts > 0:
		member_m += float(struts) * 1.0
	return {"member_m": member_m, "skin_m2": skin_m2, "plates": plates, "rings": st.size() * n0,
			"stringers": maxi(st.size() - 1, 0) * n0, "bolts": st.size() * 2 + struts * 2, "struts": struts}


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## Everything the plan builds on the outside (its body and limbs), ship space.
static func extent(p: Dictionary) -> AABB:
	var box := AABB()
	var first := true
	var all: Array = (p.get("stations", []) as Array).duplicate()
	for limb: Dictionary in p.get("limbs", []):
		all.append_array(limb.stations)
	for st: Dictionary in all:
		for v: Vector2 in (st.profile as PackedVector2Array):
			var q := Vector3(v.x, v.y, float(st.z))
			if first:
				box = AABB(q, Vector3.ZERO)
				first = false
			else:
				box = box.expand(q)
	return box


## A limb's box, ship space.
static func limb_box(limb: Dictionary) -> AABB:
	return extent({"stations": limb.stations})
