class_name StageChecks
extends RefCounted
## The decommissioning rules the surveyors check on a large job's stages (plan stage S6):
## the reactor comes out before anything is cut, and every weapon is destroyed in the yard.
## Pure logic over a Contracts job read by field (order.stages, order.hazards, recoveries),
## so the bus and the tests share it.

const REACTOR_OUT := "reactor_out"
const WEAPONS_DESTROYED := "weapons_destroyed"
const ALL: PackedStringArray = [REACTOR_OUT, WEAPONS_DESTROYED]


## The job's stage plan: [{id, name, checks?}], [] when it has none.
static func stages(job: Object) -> Array:
	var order: Variant = job.get("order") if job else null
	var list: Variant = order.get("stages") if order is Object else null
	return list if list is Array else []


## The stage open for sign-off: the first one not in `signed` (stage ids), {} when all are.
static func open_stage(job: Object, signed: PackedStringArray) -> Dictionary:
	for st: Variant in stages(job):
		if st is Dictionary and not signed.has(str(st.get("id", ""))):
			return st
	return {}


## True when the job decommissions a warship: its subject carries weapons.
static func decommissioning(job: Object) -> bool:
	var order: Variant = job.get("order") if job else null
	var hazards: Variant = order.get("hazards") if order is Object else null
	return hazards != null and "weapons" in hazards


## The rules a stage is checked against. The stage's own `checks` when Contracts set them;
## otherwise on a decommissioning job every stage checks both, since the reactor and the
## weapons come out first and nothing after may undo that.
static func checks_for(job: Object, stage: Dictionary) -> PackedStringArray:
	if stage.has("checks"):
		var out := PackedStringArray()
		for c: Variant in stage["checks"]:
			if str(c) in ALL:
				out.append(str(c))
		return out
	return ALL.duplicate() if decommissioning(job) else PackedStringArray()


## Runs the checks over what has come out of the job so far: [{id, label, passed, detail}].
static func run(job: Object, ids: PackedStringArray, rules: SurveyRules) -> Array[Dictionary]:
	var lines: Array = job.get("recoveries") if job and job.get("recoveries") is Array else []
	var out: Array[Dictionary] = []
	for id in ids:
		match id:
			REACTOR_OUT:
				out.append(_reactor_out(lines, rules))
			WEAPONS_DESTROYED:
				out.append(_weapons_destroyed(lines, rules))
	return out


## The reactor is recorded out, and no metal was cut from the hull before it was.
static func _reactor_out(lines: Array, rules: SurveyRules) -> Dictionary:
	var c := {"id": REACTOR_OUT, "label": "Reactor out first", "passed": false, "detail": ""}
	var first_cut := -1
	for i in lines.size():
		var line: Dictionary = lines[i]
		if line.has("material") and not line.has("component") and first_cut < 0:
			first_cut = i
		if _matches(_component_id(line), rules.reactor_words):
			if first_cut >= 0:
				c["detail"] = "Hull metal was cut before the reactor came out"
			else:
				c["passed"] = true
				c["detail"] = "Reactor removed before any cutting"
			return c
	c["detail"] = "Hull cut with the reactor still aboard" if first_cut >= 0 else "The reactor hasn't come out yet"
	return c


## At least one weapon is recorded destroyed, and none has gone any other way.
static func _weapons_destroyed(lines: Array, rules: SurveyRules) -> Dictionary:
	var c := {"id": WEAPONS_DESTROYED, "label": "Weapons destroyed", "passed": false, "detail": ""}
	var destroyed := 0
	var astray := PackedStringArray()
	for line: Dictionary in lines:
		var id := _component_id(line)
		if not _matches(id, rules.weapon_words):
			continue
		if str(line.get("disposition", "")) == "destroyed":
			destroyed += 1
		else:
			astray.append("%s %s" % [id.replace("_", " "), str(line.get("disposition", "")) ])
	if not astray.is_empty():
		c["detail"] = "Weapons not destroyed: " + ", ".join(astray)
	elif destroyed == 0:
		c["detail"] = "No weapons recorded destroyed yet"
	else:
		c["passed"] = true
		c["detail"] = "%d weapon%s destroyed" % [destroyed, "" if destroyed == 1 else "s"]
	return c


static func _component_id(line: Dictionary) -> String:
	var comp: Variant = line.get("component")
	return str(comp.get("id", "")).to_lower() if comp is Dictionary else ""


static func _matches(id: String, words: PackedStringArray) -> bool:
	if id == "":
		return false
	for w in words:
		if id.contains(w):
			return true
	return false
