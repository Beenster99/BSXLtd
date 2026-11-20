extends RefCounted
## The numbers behind Help's size x class matrix (beenster, 20 Nov: "build a matrix of these
## capabilities and make sure it is in the help ... if I click on a reactor of A2 (size,
## class) it should highlight all the power units that this supports").
##
## Read straight from the design catalogue: every graded component in every size it comes in
## (1 smallest, 8 largest) and every grade (R S L H Q P), each with the one number that says
## what it is for (kW made, thrust, jump, damage, defence, range, room) and the power it uses.
## A supply runs a component when it makes at least the kW the component draws.

## What each kind of component is rated by, first match wins: [field, label, unit].
const METRICS: Array = [
	["output", "Power made", "kW"],
	["thrust", "Thrust", "kN"],
	["jump", "Jump", "ly"],
	["attack", "Damage", "dps"],
	["defence", "Defence", "pts"],
	["sensor", "Range", "km"],
	["cargo", "Cargo", "m³"],
	["tank", "Tank", "m³"],
	["tow_t", "Tow", "t"],
	["draw", "Power used", "kW"],
]

var catalog: DesignCatalog


func _init(cat: DesignCatalog) -> void:
	catalog = cat


## The categories with at least one sized component, in the palette's order: [[id, title]].
func categories() -> Array:
	var out: Array = []
	for c: Array in DesignCatalog.CATEGORIES:
		if not types_in(str(c[0])).is_empty():
			out.append(c)
	return out


## Base types in a category that come in sizes, by name.
func types_in(category: String) -> Array[DesignPartType]:
	var out: Array[DesignPartType] = []
	for p in catalog.parts_in(category):
		if p.size_class > 0:
			out.append(p)
	return out


## A type at a size and grade, or null where it doesn't come in that size or grade.
func variant(base: DesignPartType, size: int, grade: String) -> DesignPartType:
	if not base.graded and grade != DesignGrades.DEFAULT_GRADE:
		return null
	return catalog.part(DesignGrades.variant_id(base, size, grade)) if _has_size(base, size) else null


func _has_size(base: DesignPartType, size: int) -> bool:
	var span := DesignGrades.sizes(base)
	return size >= span[0] and size <= span[1]


## kW a part makes (0 for one that uses power).
static func output(p: DesignPartType) -> float:
	return maxf(0.0, p.power)


## kW a part uses (0 for one that makes it).
static func draw(p: DesignPartType) -> float:
	return maxf(0.0, -p.power)


static func is_supply(p: DesignPartType) -> bool:
	return p.power > 0.0


## The number a type is rated by: {field, label, unit}.
static func metric(p: DesignPartType) -> Dictionary:
	for m: Array in METRICS:
		if value_of(p, str(m[0])) > 0.0:
			return {"field": m[0], "label": m[1], "unit": m[2]}
	return {"field": "integrity", "label": "Integrity", "unit": "hp"}


static func value_of(p: DesignPartType, field: String) -> float:
	match field:
		"output":
			return output(p)
		"draw":
			return draw(p)
		_:
			return float(p.get(field))


## Whether `supply` makes enough power to run `p`.
static func runs(supply: DesignPartType, p: DesignPartType) -> bool:
	return supply != null and draw(p) > 0.0 and draw(p) <= output(supply)


## How many of the variants that use power `supply` runs, over the whole catalogue and per
## category: {ok, total, by_category: {id: [ok, total]}}.
func coverage(supply: DesignPartType) -> Dictionary:
	var ok := 0
	var total := 0
	var by := {}
	for c: Array in categories():
		var cok := 0
		var ctot := 0
		for base in types_in(str(c[0])):
			for v in all_variants(base):
				if draw(v) <= 0.0:
					continue
				ctot += 1
				if runs(supply, v):
					cok += 1
		by[str(c[0])] = [cok, ctot]
		ok += cok
		total += ctot
	return {"ok": ok, "total": total, "by_category": by}


## Every size and grade a type comes in.
func all_variants(base: DesignPartType) -> Array[DesignPartType]:
	var out: Array[DesignPartType] = []
	var span := DesignGrades.sizes(base)
	for s in range(span[0], span[1] + 1):
		for g in DesignGrades.GRADE_ORDER:
			var v := variant(base, s, g)
			if v:
				out.append(v)
	return out


## "840", "1.2k", "35k", "0.4": short enough for a matrix cell.
static func short(v: float) -> String:
	var a := absf(v)
	if a >= 100000.0:
		return "%dk" % roundi(v / 1000.0)
	if a >= 10000.0:
		return "%.0fk" % (v / 1000.0)
	if a >= 1000.0:
		return "%.1fk" % (v / 1000.0)
	if a >= 100.0:
		return "%d" % roundi(v)
	if a >= 10.0:
		return "%.0f" % v
	if a >= 1.0:
		return "%.1f" % v
	return "%.2f" % v
