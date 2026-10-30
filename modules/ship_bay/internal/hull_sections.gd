extends RefCounted
## A large hull's sections (S6 of the scrapyard plan, flag "ship_bay.sections"): a hull in
## Dock 2 or Dock 3 is broken up along its length into sections the dolly can carry, cut at
## its frame rings, front (-Z) to back. Each section is the parts whose middle lies between
## its two cuts, and its cut joints are the ones that join it to the section either side.
##
## Pure data from the hull's file (a Void Salvage vsship 2.x file, as WreckMaker or
## VsShipImport hands it over), the same on every peer.

## Most a section may be long (the dolly's deck) and weigh (what the dolly carries), metres
## and kilograms. Void Salvage's hulls are heavy (a Sentinel's hull plates are 5 to 9 t each),
## so these, not the plan's 30 t crane, set how many sections a hull is cut into.
const MAX_LENGTH := 12.0
const MAX_MASS := 400000.0
## The shortest section worth cutting, metres: a shorter end piece goes with its neighbour.
const MIN_LENGTH := 3.0
## Rings closer than this (metres) are one cut line.
const RING_SNAP := 0.1


## The sections of hull file `f`, front to back: [{index, z0, z1, parts (paths), mass_kg,
## cut_joints (paths of the joints to its neighbours)}]. One section for a file with no parts.
static func plan(f: Dictionary) -> Array:
	var parts: Array = f.get("parts", [])
	var b: Dictionary = f.get("derived", {}).get("bounds", {})
	var front := float((b.get("pos", [0, 0, 0]) as Array)[2])
	var back := front + float((b.get("size", [0, 0, 0]) as Array)[2])
	if parts.is_empty() or back - front <= 0.0:
		return [{"index": 0, "z0": front, "z1": back, "parts": [], "mass_kg": 0.0, "cut_joints": []}]
	var mids: Array = []   # [z, mass, path]
	var rings := {}
	for p: Dictionary in parts:
		var z := _mid_z(p)
		mids.append([z, float(p.get("mass", 0.0)), str(p.get("path", ""))])
		if str(p.get("name", "")) == "FrameRing":
			rings[snappedf(z, RING_SNAP)] = true
	var cuts := _cuts(front, back, rings.keys(), mids)
	var out: Array = []
	for i in cuts.size() - 1:
		out.append({"index": i, "z0": cuts[i], "z1": cuts[i + 1], "parts": [], "mass_kg": 0.0, "cut_joints": []})
	var where := {}
	for m: Array in mids:
		var i := section_at(cuts, float(m[0]))
		(out[i]["parts"] as Array).append(str(m[2]))
		out[i]["mass_kg"] = float(out[i]["mass_kg"]) + float(m[1])
		where[str(m[2])] = i
	for j: Dictionary in f.get("joints", []):
		var a: int = where.get(str(j.get("a", "")), -1)
		var c: int = where.get(str(j.get("b", "")), -1)
		if a < 0 or c < 0 or a == c:
			continue
		(out[a]["cut_joints"] as Array).append(str(j.get("path", "")))
		(out[c]["cut_joints"] as Array).append(str(j.get("path", "")))
	return out


## The section a part whose middle is at `z` falls in, by the cut lines `cuts` (front to back,
## the hull's ends first and last).
static func section_at(cuts: Array, z: float) -> int:
	for i in range(1, cuts.size() - 1):
		if z < float(cuts[i]):
			return i - 1
	return cuts.size() - 2


## The cut lines from `front` to `back`: at rings where they can be, each section as long as
## MAX_LENGTH allows and no heavier than MAX_MASS (a ring sooner when it would be, the tail
## too while it has rings to cut at); evenly
## where the hull has no rings to cut at.
static func _cuts(front: float, back: float, ring_z: Array, mids: Array) -> Array:
	var rings: Array = ring_z.filter(func(z: float) -> bool: return z > front + MIN_LENGTH and z < back - MIN_LENGTH)
	rings.sort()
	var cuts: Array = [front]
	var start := front
	while back - start > MAX_LENGTH or _mass_between(mids, start, INF) > MAX_MASS:
		var best := -INF
		for z: float in rings:
			if z <= start + MIN_LENGTH or z > start + MAX_LENGTH:
				continue
			if _mass_between(mids, start, z) > MAX_MASS and best > -INF:
				break
			best = z
		if best == -INF:
			if back - start <= MAX_LENGTH:
				break   # too heavy, but no ring left to cut at
			best = start + minf(MAX_LENGTH, (back - start) * 0.5)
		cuts.append(best)
		start = best
	if back - start < MIN_LENGTH and cuts.size() > 1:
		cuts.pop_back()
	cuts.append(back)
	return cuts


static func _mass_between(mids: Array, z0: float, z1: float) -> float:
	var m := 0.0
	for e: Array in mids:
		if float(e[0]) >= z0 and float(e[0]) < z1:
			m += float(e[1])
	return m


static func _mid_z(p: Dictionary) -> float:
	var box: Dictionary = p.get("box", {})
	if box.has("pos"):
		return float((box["pos"] as Array)[2]) + float((box.get("size", [0, 0, 0]) as Array)[2]) * 0.5
	var o: Variant = (p.get("xform", {}) as Dictionary).get("o", [0, 0, 0])
	return float((o as Array)[2])


## File `f` with only the parts in `keep` (path -> true) and what hangs on them: the joints
## between two kept parts, the fittings, systems and leads on kept parts, and the loose
## pieces and lights whose place (z) lies in one of `ranges` ([z0, z1) pairs). Everything
## else (materials, meshes, damage, bounds) as it is, so the kept parts build where they
## stood in the whole hull.
static func sub_file(f: Dictionary, keep: Dictionary, ranges: Array) -> Dictionary:
	var out := f.duplicate(false)
	out["parts"] = (f.get("parts", []) as Array).filter(func(p: Dictionary) -> bool: return keep.has(str(p.get("path", ""))))
	out["joints"] = (f.get("joints", []) as Array).filter(func(j: Dictionary) -> bool:
			return keep.has(str(j.get("a", ""))) and keep.has(str(j.get("b", ""))))
	for key: String in ["fittings", "systems"]:
		out[key] = (f.get(key, []) as Array).filter(func(r: Dictionary) -> bool: return _keeps(keep, str(r.get("path", ""))))
	out["pieces"] = (f.get("pieces", []) as Array).filter(func(r: Dictionary) -> bool:
			return _in(ranges, float(((r.get("xform", {}) as Dictionary).get("o", [0, 0, 0]) as Array)[2])))
	out["lights"] = (f.get("lights", []) as Array).filter(func(r: Dictionary) -> bool:
			return _in(ranges, float((r.get("at", [0, 0, 0]) as Array)[2])))
	var derived: Dictionary = (f.get("derived", {}) as Dictionary).duplicate(false)
	var routes := {}
	for k: String in (derived.get("routes", {}) as Dictionary):
		if not k.begins_with("lead:") or keep.has(k.substr(5)):
			routes[k] = derived["routes"][k]
	derived["routes"] = routes
	out["derived"] = derived
	return out


static func _in(ranges: Array, z: float) -> bool:
	for r: Array in ranges:
		if z >= float(r[0]) and z < float(r[1]):
			return true
	return false


## A record on part `path` (or on parts under it, a system's) is kept with them.
static func _keeps(keep: Dictionary, path: String) -> bool:
	if keep.has(path):
		return true
	for p: String in keep:
		if p.begins_with(path + "/"):
			return true
	return false
