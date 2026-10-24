class_name FieldSweep
extends RefCounted
## The emitter frame rig's test for an upgraded attractor coil (U1), and the shape every
## rig test follows: the tier's rated figures come from the add-ons fitted, the unit reaches
## a share of that gain set by how well its joints were made, and a failed joint trips the
## test. Pure logic: the bus stores the plate, gives it a serial and shares it.

## Words and display units for the figures a plate shows: stat -> [label, unit, scale].
const STATS := {
	"attract_reach": ["Reach", "m", 1.0],
	"attract_max_mass": ["Max mass", "t", 0.001],
	"attract_speed": ["Pull speed", "m/s", 1.0],
	"attract_accel": ["Pull accel", "m/s²", 1.0],
}


## request: {unit_id, family?, tier?, base: {stat: value}, addons: [{part, tier, mount}],
## joint_ids: [...], rated?: {stat: value}, job_id?}. records: joint_id -> JointRecord.
static func run(request: Dictionary, records: Dictionary, rules: RigRules, time := 0) -> UpgradePlate:
	var p := UpgradePlate.new()
	p.unit_id = str(request.get("unit_id", ""))
	p.family = str(request.get("family", family_of(p.unit_id)))
	p.job_id = str(request.get("job_id", ""))
	p.time = time
	p.base = _floats(request.get("base", {}))
	p.addons.assign(request.get("addons", []))
	var top := 1
	for a in p.addons:
		top = maxi(top, int(a.get("tier", 1)))
	p.tier = clampi(int(request.get("tier", top)), 1, 3)
	p.rated = _floats(request["rated"]) if request.has("rated") else rated(p.base, p.addons, rules)

	var total := 0
	var graded := 0
	var fails: Array[Dictionary] = []
	for id in request.get("joint_ids", []):
		var r: JointRecord = records.get(StringName(id))
		if r == null:
			continue
		var line := {"joint_id": String(r.joint_id), "trade": String(r.trade),
				"component_id": String(r.component_id), "mount_id": String(r.mount_id),
				"score": r.score, "grade": String(r.grade), "faults": r.faults.duplicate(true)}
		p.joints.append(line)
		if r.score >= 0:
			graded += 1
			total += r.score
		if r.grade == JointRecord.FAIL:
			fails.append(line)
	p.average = float(total) / graded if graded > 0 else 0.0
	p.quality = p.average / 100.0
	p.grade = SurveyReport.letter(p.average, fails.size()) if graded > 0 else "–"
	p.efficiency = rules.efficiency_floor + rules.efficiency_slope * p.quality if graded > 0 else 0.0
	for stat in p.base:
		var b: float = p.base[stat]
		p.tested[stat] = b + (float(p.rated.get(stat, b)) - b) * p.efficiency if graded > 0 else b

	if p.addons.is_empty() or graded == 0:
		p.snags.append({"code": "nothing_fitted", "text": "No add-ons fitted and joined on this unit yet."})
	for line in fails:
		var why: String = str(line.faults[0].get("text", "")) if not line.faults.is_empty() else "failed"
		p.snags.append({"code": "trip", "joint_id": line.joint_id,
				"text": "Tripped at %s: %s." % [SurveyDesk.joint_words(line), why.to_lower()]})
	var cooled := p.addons.any(func(a: Dictionary) -> bool: return str(a.get("part", "")) in rules.coolers)
	for a in p.addons:
		if int(a.get("tier", 1)) >= 3 and not cooled:
			p.snags.append({"code": "overheat", "part": str(a.get("part", "")),
					"text": "Overheated: the tier 3 %s needs a heat exchanger fitted first." % part_words(str(a.get("part", "")))})
	if graded > 0 and p.efficiency < rules.pass_efficiency:
		p.snags.append({"code": "short", "text": "Fell short: %s. Rework the weakest joints." % _short_words(p)})
	p.passed = p.snags.is_empty()
	return p


## The tier's rated figures: base times every fitted add-on's multipliers.
static func rated(base: Dictionary, addons: Array, rules: RigRules) -> Dictionary:
	var out := base.duplicate()
	for a in addons:
		var by_tier: Dictionary = rules.gains.get(str(a.get("part", "")), {})
		var mult: Dictionary = by_tier.get(int(a.get("tier", 1)), {})
		for stat in mult:
			if out.has(stat):
				out[stat] = float(out[stat]) * float(mult[stat])
	return out


## "attractor_coil_1" -> "attractor_coil".
static func family_of(unit_id: String) -> String:
	var parts := unit_id.split("_")
	if parts.size() > 1 and parts[-1].is_valid_int():
		parts.remove_at(parts.size() - 1)
	return "_".join(parts)


## "field_emitter_array" -> "field emitter array".
static func part_words(part: String) -> String:
	return part.replace("_", " ")


## "Reach 21.4 m" for a stat's value.
static func stat_text(stat: String, value: float) -> String:
	var w: Array = STATS.get(stat, [stat.capitalize(), "", 1.0])
	var v := value * float(w[2])
	return "%s %s %s" % [w[0], ("%.1f" % v) if absf(v) < 100.0 else str(roundi(v)), w[1]]


static func _short_words(p: UpgradePlate) -> String:
	for stat in p.rated:
		if float(p.rated[stat]) > float(p.base.get(stat, 0.0)):
			var w: Array = STATS.get(stat, [stat.capitalize(), "", 1.0])
			return "%s of %s rated" % [stat_text(stat, float(p.tested[stat])),
					("%.1f %s" % [float(p.rated[stat]) * float(w[2]), w[1]]).strip_edges()]
	return "below the tier's rating"


static func _floats(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d:
		out[str(k)] = float(d[k])
	return out
