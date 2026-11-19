class_name DesignGrades
extends RefCounted
## Size classes and grades for components, in the spirit of an outfitting sheet: every graded
## component comes in size classes 1 to 8 (within its own range) and in one of BSX's six
## grades, and its numbers (cost, mass, power, thrust, jump, attack, defence, signature,
## integrity, build hours, supplier days) follow from the two.
##
## A size/grade variant is named by a suffix on the type id: "reactor_small:5H" is the small
## fusion reactor at size 5, Hardened grade. DesignCatalog.part() derives and caches it, so a
## placed component simply stores that id as its type and everything that reads cat.part(type)
## sees the variant's numbers and its scaled size. A bare id is the base size, Standard grade.

## The grades, worst value for money first. Each multiplies the base numbers:
##   cost, mass, hours (to fit), perf (what it makes: power output, thrust, jump, attack,
##   shields, sensors), draw (power it uses), integrity, signature, lead (extra supplier days).
const GRADES: Dictionary = {
	"R": {"name": "Reclaimed", "blurb": "Refurbished salvage: cheap and quick to get, heavy, tired and loud.",
			"cost": 0.4, "mass": 1.15, "hours": 1.2, "perf": 0.8, "draw": 1.15, "integrity": 0.7, "signature": 1.3, "lead": -1},
	"S": {"name": "Standard", "blurb": "Yard standard: the numbers everything else is measured against.",
			"cost": 1.0, "mass": 1.0, "hours": 1.0, "perf": 1.0, "draw": 1.0, "integrity": 1.0, "signature": 1.0, "lead": 0},
	"L": {"name": "Lightweight", "blurb": "Alloy and composite: much lighter, a little weaker, dearer.",
			"cost": 1.7, "mass": 0.6, "hours": 1.1, "perf": 0.95, "draw": 1.0, "integrity": 0.75, "signature": 0.95, "lead": 1},
	"H": {"name": "Hardened", "blurb": "Armoured casings and doubled mounts: takes a beating, weighs it.",
			"cost": 1.8, "mass": 1.4, "hours": 1.3, "perf": 1.05, "draw": 1.05, "integrity": 1.8, "signature": 1.1, "lead": 2},
	"Q": {"name": "Quiet", "blurb": "Baffled, shielded and cooled: hard to see, a little down on output.",
			"cost": 2.4, "mass": 1.1, "hours": 1.3, "perf": 0.9, "draw": 1.05, "integrity": 0.95, "signature": 0.45, "lead": 3},
	"P": {"name": "Precision", "blurb": "Tuned and certified: the best output, hungry for power, a long wait.",
			"cost": 3.2, "mass": 0.9, "hours": 1.4, "perf": 1.3, "draw": 1.2, "integrity": 1.0, "signature": 0.85, "lead": 4},
}
const GRADE_ORDER: PackedStringArray = ["R", "S", "L", "H", "Q", "P"]
const DEFAULT_GRADE := "S"
const MIN_CLASS := 1
const MAX_CLASS := 8

## Growth per size class up (a class up holds about twice the volume).
const PER_CLASS: Dictionary = {
	"dims": 1.26, "mass": 1.9, "cost": 2.2, "hours": 1.5, "power": 2.0, "thrust": 2.0,
	"jump": 1.6, "attack": 2.0, "defence": 2.0, "integrity": 1.8, "signature": 1.8,
	"cargo": 2.0, "tank": 2.0, "sensor": 1.4,
}


## Splits "id:5H" into {id, size (0 = base), grade ("" = Standard)}.
static func parse(type_id: String) -> Dictionary:
	var i := type_id.find(":")
	if i < 0:
		return {"id": type_id, "size": 0, "grade": ""}
	var tail := type_id.substr(i + 1)
	var size := 0
	var grade := ""
	var digits := ""
	for ch in tail:
		if ch >= "0" and ch <= "9":
			digits += ch
		else:
			grade += ch
	if digits != "":
		size = int(digits)
	return {"id": type_id.substr(0, i), "size": size, "grade": grade.to_upper()}


## The type id of a variant: `variant_id("reactor_small", 5, "H")` -> "reactor_small:5H".
## The base size in Standard grade is the bare id.
static func variant_id(base: DesignPartType, size: int, grade: String) -> String:
	var s := clampi(size, sizes(base)[0], sizes(base)[1]) if size > 0 else base.size_class
	var g := grade if GRADES.has(grade) and base.graded else DEFAULT_GRADE
	if (s == base.size_class or base.size_class == 0) and g == DEFAULT_GRADE:
		return base.id
	return "%s:%s%s" % [base.id, str(s) if base.size_class > 0 else "", g]


## [smallest, largest] size class a type comes in; [0, 0] for one size only.
static func sizes(pt: DesignPartType) -> Array[int]:
	if pt.size_class <= 0:
		return [0, 0]
	var lo := pt.min_class if pt.min_class > 0 else pt.size_class
	var hi := pt.max_class if pt.max_class > 0 else pt.size_class
	return [clampi(mini(lo, pt.size_class), MIN_CLASS, MAX_CLASS), clampi(maxi(hi, pt.size_class), MIN_CLASS, MAX_CLASS)]


## "5H": the class and grade as players read them ("" for a one-size ungraded part).
static func label(pt: DesignPartType) -> String:
	var s := str(pt.size_class) if pt.size_class > 0 else ""
	return s + (pt.grade if pt.graded else "")


## A copy of `base` at `size` (0 = its own) and `grade` ("" = Standard), with every number
## scaled. Returns null for a size the type doesn't come in or an unknown grade.
static func derive(base: DesignPartType, size: int, grade: String) -> DesignPartType:
	var g := grade if grade != "" else DEFAULT_GRADE
	if not GRADES.has(g) or (not base.graded and g != DEFAULT_GRADE):
		return null
	var s := base.size_class if size <= 0 else size
	var span := sizes(base)
	if base.size_class > 0 and (s < span[0] or s > span[1]):
		return null
	if base.size_class <= 0 and size > 0:
		return null
	var d := s - base.size_class if base.size_class > 0 else 0
	var gr: Dictionary = GRADES[g]
	var p := base.duplicate() as DesignPartType
	p.base_id = base.id
	p.id = variant_id(base, s, g)
	p.size_class = s
	p.grade = g if base.graded else ""
	var k := func(key: String) -> float: return pow(float(PER_CLASS[key]), d)
	p.model_scale = k.call("dims")
	p.size = base.size * p.model_scale
	p.mass = base.mass * k.call("mass") * float(gr.mass)
	p.cost = round(base.cost * k.call("cost") * float(gr.cost) / 10.0) * 10.0
	p.build_hours = base.build_hours * k.call("hours") * float(gr.hours)
	p.power = base.power * k.call("power") * (float(gr.perf) if base.power > 0.0 else float(gr.draw))
	p.thrust = base.thrust * k.call("thrust") * float(gr.perf)
	p.jump = base.jump * k.call("jump") * float(gr.perf)
	p.attack = base.attack * k.call("attack") * float(gr.perf)
	p.defence = base.defence * k.call("defence") * (float(gr.integrity) if base.category == "defence" else float(gr.perf))
	p.integrity = base.integrity * k.call("integrity") * float(gr.integrity)
	# A part that hides the signature (negative) hides more in better grades, not less.
	p.signature = base.signature * k.call("signature") * (float(gr.signature) if base.signature >= 0.0 else float(gr.perf))
	p.cargo = base.cargo * k.call("cargo")
	p.tank = base.tank * k.call("tank")
	p.sensor = base.sensor * k.call("sensor") * float(gr.perf)
	p.access = base.access * sqrt(p.model_scale)
	p.lead_days = maxi(1, base.lead_days + int(gr.lead) + maxi(0, d) / 2)
	if p.id != base.id:
		p.display_name = "%s %s" % [base.display_name, label(p)]
	return p
