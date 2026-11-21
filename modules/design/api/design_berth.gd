class_name DesignBerth
extends RefCounted
## Will the design fit the company's build berth? (beenster, 19 Nov: berths grow with
## reputation.) A berth is {name, length, beam, height} of clear space, m; the yard module gives
## the current build berth (DesignBus.berth()), DEFAULT when the yard is off. The hull needs
## CLEARANCE all round for the bots to work.

const DEFAULT: Dictionary = {"name": "Build berth", "tier": 1, "length": 60.0, "beam": 30.0, "height": 30.0}
## Room for the bots to work round the hull on every side, m.
const CLEARANCE := 2.0


## The design's size: {length (along z), beam (x), height (its decks)}, m.
static func size_of(d: DesignRecord) -> Dictionary:
	var box := d.bounds()
	var decks := d.decks()
	var n := (decks[decks.size() - 1] - decks[0] + 1) if decks.size() > 0 else 1
	var out := {"length": box.size.y, "beam": box.size.x, "height": float(n) * d.deck_height}
	# Her nose, stern, wings, fins and pods reach past her rooms (DesignShape).
	if not d.shapes.is_empty():
		var e := DesignShape.extent(DesignOutside.plan_for(d))
		out.length = maxf(float(out.length), e.size.z)
		out.beam = maxf(float(out.beam), e.size.x)
		out.height = maxf(float(out.height), e.size.y)
	# Her free beams and plates reach past her too (DesignFree), measured with her hull.
	if not d.free_beams.is_empty() or not d.free_plates.is_empty():
		var fp := DesignOutside.plan_for(d)
		var e := DesignShape.extent(fp).merge(DesignFree.extent(d))
		out.length = maxf(float(out.length), e.size.z)
		out.beam = maxf(float(out.beam), e.size.x)
		out.height = maxf(float(out.height), e.size.y)
	return out


## How the design sits in `berth`: {ok, length, beam, height (the design's), need (each with
## clearance both sides), berth, over: [names of what is too big]}.
static func fit(d: DesignRecord, berth: Dictionary) -> Dictionary:
	var s := size_of(d)
	var over: Array[String] = []
	for k: String in ["length", "beam", "height"]:
		if float(s[k]) + 2.0 * CLEARANCE > float(berth.get(k, DEFAULT[k])) + 0.001:
			over.append(k)
	return {"ok": over.is_empty(), "length": s.length, "beam": s.beam, "height": s.height, "berth": berth,
			"over": over}


## A berth from whatever the yard gives: a {name, length, beam, height} dictionary, a Vector3
## (beam, height, length) or an AABB (its longest flat side is the length); DEFAULT otherwise.
static func from_yard(v: Variant, name := "") -> Dictionary:
	var out := DEFAULT.duplicate()
	if v is Dictionary and (v as Dictionary).has("length"):
		for k: String in ["name", "tier", "length", "beam", "height"]:
			if (v as Dictionary).has(k):
				out[k] = v[k]
		return out
	var sz := Vector3.ZERO
	if v is Vector3:
		sz = v
	elif v is AABB:
		sz = (v as AABB).size
		if sz.x > sz.z:
			sz = Vector3(sz.z, sz.y, sz.x)
	if sz.x > 0.0 and sz.y > 0.0 and sz.z > 0.0:
		out = {"name": name if name != "" else str(DEFAULT.name), "tier": 1, "length": sz.z, "beam": sz.x, "height": sz.y}
	return out


## The WILL IT WORK problem for a design that will not fit, else {}.
static func problem(f: Dictionary) -> Dictionary:
	if f.ok:
		return {}
	var b: Dictionary = f.berth
	return {"code": "berth", "severity": "error", "rooms": [], "components": [], "doors": [],
			"text": "Too big for the %s (%s): %s m x %s m x %s m with %s m clearance each side, berth %s x %s x %s m" % [
				str(b.get("name", "berth")).to_lower(), ", ".join(f.over), snappedf(f.length, 0.1),
				snappedf(f.beam, 0.1), snappedf(f.height, 0.1), CLEARANCE, snappedf(float(b.length), 0.1),
				snappedf(float(b.beam), 0.1), snappedf(float(b.height), 0.1)]}
