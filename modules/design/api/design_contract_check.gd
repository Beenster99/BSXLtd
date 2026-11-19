class_name DesignContractCheck
extends RefCounted
## Scores a design against a ship order's special clauses (ShipOrders.CLAUSES: rooms, parts
## and grades it must have), in the same rows DesignTotals.fit gives for the numeric demands,
## so a view can list both together: {key: "clause:<id>", label, need, have, ok, share (0..1)}.


## One row per clause of `order` ({} or no clauses: none).
static func clauses(order: Dictionary, d: DesignRecord, cat: DesignCatalog) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in order.get("clauses", []):
		out.append(check(c, d, cat))
	return out


## Every criterion of `order`: the numeric demands (totals.fit), then the clauses.
static func all(order: Dictionary, d: DesignRecord, cat: DesignCatalog, totals: DesignTotals) -> Array[Dictionary]:
	var out: Array[Dictionary] = totals.fit(order.get("demands", {}))
	out.append_array(clauses(order, d, cat))
	return out


static func check(c: Dictionary, d: DesignRecord, cat: DesignCatalog) -> Dictionary:
	var need := 1.0
	var have := 0.0
	var ok := false
	match str(c.get("kind", "")):
		"room":
			need = float(c.get("min_m2", 0.0))
			for r: Dictionary in d.rooms.values():
				if str(r.type) == str(c.get("room", "")):
					have += float(r.w) * float(r.d)
			ok = have >= need and have > 0.0
		"part":
			need = float(c.get("count", 1))
			var want: Array = c.get("parts", [])
			for p: Dictionary in d.components.values() + d.mounts.values():
				var base := cat.base_of(str(p.type))
				if base != null and want.has(base.id):
					have += 1.0
			ok = have >= need
		"no_grade":
			need = 0.0
			for p: Dictionary in d.components.values() + d.mounts.values():
				var pt := cat.part(str(p.type))
				if pt != null and pt.graded and _grade(pt) == str(c.get("grade", "")):
					have += 1.0
			ok = have == 0.0
			return _row(c, need, have, ok, 1.0 if ok else 0.0)
		"grade":
			var grades: Array = c.get("grades", [])
			need = 0.0
			for p: Dictionary in d.components.values() + d.mounts.values():
				var pt := cat.part(str(p.type))
				if pt == null or not pt.graded or pt.category != str(c.get("category", "")):
					continue
				need += 1.0
				if grades.has(_grade(pt)):
					have += 1.0
			ok = need > 0.0 and have >= need
			return _row(c, need, have, ok, have / need if need > 0.0 else 0.0)
	return _row(c, need, have, ok, clampf(have / need, 0.0, 1.0) if need > 0.0 else (1.0 if ok else 0.0))


## The surveyors' cycle of the moving parts (MotionBus.cycle, read by name so motion stays
## optional) as trial rows: every moving part runs out and back clear of everything, and she
## sets down on her legs without tipping or overloading a foot. None for a ship with nothing
## that moves and no legs.
static func motion_rows(cycle: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parts: Array = cycle.get("parts", [])
	if not parts.is_empty():
		var clear := 0
		var notes: Array = []
		for p: Dictionary in parts:
			if p.get("clear", false):
				clear += 1
			else:
				notes.append(str(p.get("name", "")))
		var row := _row({"id": "motion", "text": "Moving parts cycle clear"}, float(parts.size()), float(clear),
				clear == parts.size(), float(clear) / float(parts.size()))
		row["notes"] = notes
		out.append(row)
	var ground: Dictionary = cycle.get("ground", {})
	if int(ground.get("legs", 0)) > 0 or not (ground.get("problems", []) as Array).is_empty():
		var bad := 0
		for pr: Dictionary in ground.get("problems", []):
			if str(pr.get("severity", "")) == DesignRules.ERROR:
				bad += 1
		out.append(_row({"id": "ground", "text": "Sets down safely"}, 0.0, float(bad), bad == 0, 1.0 if bad == 0 else 0.0))
	return out


static func _grade(pt: DesignPartType) -> String:
	return pt.grade if pt.grade != "" else DesignGrades.DEFAULT_GRADE


static func _row(c: Dictionary, need: float, have: float, ok: bool, share: float) -> Dictionary:
	return {"key": "clause:" + str(c.get("id", "")), "label": str(c.get("text", c.get("id", ""))),
		"need": need, "have": have, "ok": ok, "share": share, "clause": true}
