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


static func _grade(pt: DesignPartType) -> String:
	return pt.grade if pt.grade != "" else DesignGrades.DEFAULT_GRADE


static func _row(c: Dictionary, need: float, have: float, ok: bool, share: float) -> Dictionary:
	return {"key": "clause:" + str(c.get("id", "")), "label": str(c.get("text", c.get("id", ""))),
		"need": need, "have": have, "ok": ok, "share": share, "clause": true}
