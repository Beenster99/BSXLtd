extends RefCounted
## Checks a parsed work order file and builds a WorkOrder from it. Every problem becomes one
## readable line in `errors`; a file with any error builds nothing.

const Upgrades := preload("res://modules/contracts/internal/upgrades.gd")

var errors: PackedStringArray = []
## Callable(id: String) -> bool: is this part or module in the shared library? Unset (the
## default) accepts any id.
var component_exists: Callable
## Every change_id in the file, even on a change with other problems, so a spec override
## for it is not reported as a second error.
var _change_ids := {}


## Reads a work order from JSON text, or returns null with `errors` filled in.
func read_text(text: String) -> WorkOrder:
	errors = []
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("Not a readable contract file (line %d: %s)." % [json.get_error_line(), json.get_error_message()])
		return null
	if not json.data is Dictionary:
		errors.append("Not a readable contract file (it is not a JSON object).")
		return null
	return read(json.data)


func read(src: Dictionary) -> WorkOrder:
	errors = []
	_change_ids = {}
	if src.get("schema") != WorkOrder.SCHEMA:
		errors.append("This is not a work order (schema should be \"%s\")." % WorkOrder.SCHEMA)
		return null
	var version := _whole(src.get("schema_version"))
	if version < 1:
		errors.append("schema_version must be a whole number from 1.")
		return null
	if version > WorkOrder.SCHEMA_VERSION:
		errors.append("This contract was written for a newer BSX (schema %d; this build reads up to %d). Update BSX to open it." % [version, WorkOrder.SCHEMA_VERSION])
		return null
	var d := Upgrades.upgrade(src, version)

	var o := WorkOrder.new()
	o.raw = d
	o.contract_id = _text(d, "contract_id", "")
	o.issued_at = _text(d, "issued_at", "")
	o.title = String(d.get("title", ""))

	o.client = _dict(d, "client", "")
	_text(o.client, "company", "client")

	o.kind = String(d.get("kind", WorkOrder.FIT))
	if not o.kind in WorkOrder.KINDS:
		errors.append("kind must be one of %s." % ", ".join(WorkOrder.KINDS))
		o.kind = WorkOrder.FIT

	# A fit order is about a ship; the other kinds may leave "ship" out when a part arrives.
	var ship: Dictionary = _dict(d, "ship", "") if o.is_fit() or d.has("ship") else {}
	if o.is_fit() or d.has("ship"):
		o.ship_id = _text(ship, "ship_id", "ship")
		o.design = _text(ship, "design", "ship")
	var fit: Variant = ship.get("current_fit", [])
	if not fit is Array:
		errors.append("ship: current_fit must be a list.")
		fit = []
	for i in fit.size():
		var where := "ship.current_fit[%d]" % i
		var f: Variant = fit[i]
		if not f is Dictionary:
			errors.append("%s must be an object." % where)
			continue
		var ref := _component(f.get("component"), where + ".component")
		var condition: Variant = f.get("condition", 1.0)
		if not (condition is float or condition is int) or condition < 0.0 or condition > 1.0:
			errors.append("%s: condition must be between 0 and 1." % where)
			condition = 1.0
		o.current_fit.append({"slot": _text(f, "slot", where), "component": ref, "condition": float(condition)})

	_read_subject(d, o)
	_read_wants(d, o)
	o.keeps = String(d.get("keeps", "client" if o.kind in [WorkOrder.FIT, WorkOrder.REFURBISH] else "bsx"))
	if not o.keeps in ["bsx", "client"]:
		errors.append("keeps must be bsx or client.")
	var hazards: Variant = d.get("hazards", [])
	if hazards is Array:
		for h: Variant in hazards:
			o.hazards.append(String(h))
	else:
		errors.append("hazards must be a list.")

	_read_changes(d, o)
	_read_manifest(d, o)
	_read_spec_sheet(d, o)

	var notes: Variant = d.get("notes", [])
	if notes is Array:
		for n: Variant in notes:
			if n is Dictionary and n.get("text") is String:
				o.notes.append(n)
			else:
				errors.append("notes: each note needs a text.")
	else:
		errors.append("notes must be a list.")

	var commercial: Variant = d.get("commercial", {})
	if commercial is Dictionary:
		o.commercial = commercial
	else:
		errors.append("commercial must be an object.")

	return o if errors.is_empty() else null


## What arrives. A FIT order without one is its ship; every other kind must say.
func _read_subject(d: Dictionary, o: WorkOrder) -> void:
	var src: Variant = d.get("subject")
	if src == null:
		if o.is_fit():
			o.subject = {"type": "ship", "design": o.design}
		else:
			errors.append("a %s order needs a subject (what arrives at the yard)." % o.kind)
		return
	if not src is Dictionary:
		errors.append("subject must be an object.")
		return
	var type := String(src.get("type", ""))
	if not type in WorkOrder.SUBJECT_TYPES:
		errors.append("subject.type must be one of %s." % ", ".join(WorkOrder.SUBJECT_TYPES))
		return
	var subject := {"type": type}
	if type == "part":
		subject["component"] = _component(src.get("component"), "subject.component")
	else:
		subject["design"] = String(src.get("design", o.design))
		# A generated ship or wreck (S3): the seed and events rebuild it on every machine.
		subject["seed"] = _whole(src.get("seed", 0))
		subject["events"] = String(src.get("events", ""))
		var holds: Variant = src.get("holds", [])
		if holds is Array:
			subject["holds"] = holds
		else:
			errors.append("subject.holds must be a list.")
		subject["parts_left"] = _whole(src.get("parts_left", 0))
		subject["parts_gone"] = _whole(src.get("parts_gone", 0))
		if src.has("file"):
			subject["file"] = String(src.get("file"))
	subject["condition"] = _fraction(src.get("condition", 1.0), "subject.condition")
	subject["mass_kg"] = float(src.get("mass_kg", 0.0)) if src.get("mass_kg") is float or src.get("mass_kg") is int else 0.0
	o.subject = subject


## What comes back. Optional for FIT (the changes say); every other kind needs a line.
func _read_wants(d: Dictionary, o: WorkOrder) -> void:
	var list: Variant = d.get("wants", [])
	if not list is Array:
		errors.append("wants must be a list.")
		return
	if list.is_empty() and not o.is_fit():
		errors.append("a %s order needs at least one wants line (what comes back)." % o.kind)
		return
	for i in list.size():
		var where := "wants[%d]" % i
		var w: Variant = list[i]
		if not w is Dictionary:
			errors.append("%s must be an object." % where)
			continue
		var what := String(w.get("what", ""))
		if not what in WorkOrder.WANT_TYPES:
			errors.append("%s: what must be one of %s." % [where, ", ".join(WorkOrder.WANT_TYPES)])
			continue
		var want := {"what": what}
		match what:
			"part":
				want["component"] = _component(w.get("component"), where + ".component")
				want["qty"] = _whole(w.get("qty", 1))
				if want["qty"] < 1:
					errors.append("%s: qty must be a whole number from 1." % where)
				want["min_condition"] = _fraction(w.get("min_condition", 0.0), where + ".min_condition")
			"material":
				want["material"] = _text(w, "material", where)
				want["kg"] = float(w.get("kg", 0.0)) if w.get("kg") is float or w.get("kg") is int else 0.0
				if want["kg"] <= 0.0:
					errors.append("%s: kg must be above 0." % where)
			"condition":
				want["min_condition"] = _fraction(w.get("min_condition", 1.0), where + ".min_condition")
			"gone":
				pass
		o.wants.append(want)


func _fraction(v: Variant, where: String) -> float:
	if not (v is float or v is int) or v < 0.0 or v > 1.0:
		errors.append("%s must be between 0 and 1." % where)
		return 1.0
	return float(v)


func _read_changes(d: Dictionary, o: WorkOrder) -> void:
	var list: Variant = d.get("changes", [])
	if not list is Array or (list.is_empty() and o.is_fit()):
		errors.append("changes must be a list with at least one change.")
		return
	for i in list.size():
		var where := "changes[%d]" % i
		var c: Variant = list[i]
		if not c is Dictionary:
			errors.append("%s must be an object." % where)
			continue
		var item := ChangeItem.new()
		item.change_id = _text(c, "change_id", where)
		if _change_ids.has(item.change_id):
			errors.append("%s: change_id \"%s\" is used twice." % [where, item.change_id])
		_change_ids[item.change_id] = true
		item.action = String(c.get("action", ""))
		if not item.action in ChangeItem.ACTIONS:
			errors.append("%s: action must be add, remove or replace." % where)
			continue
		item.slot = _text(c, "slot", where)
		item.notes = String(c.get("notes", ""))
		if item.needs_removal():
			item.remove = _component(c.get("remove"), where + ".remove")
		if item.needs_install():
			item.install = _component(c.get("install"), where + ".install")
		o.changes.append(item)


func _read_manifest(d: Dictionary, o: WorkOrder) -> void:
	var list: Variant = d.get("manifest")
	if not list is Array:
		errors.append("manifest must be a list.")
		return
	for i in list.size():
		var where := "manifest[%d]" % i
		var m: Variant = list[i]
		if not m is Dictionary:
			errors.append("%s must be an object." % where)
			continue
		var line := ManifestLine.new()
		line.line_id = _text(m, "line_id", where)
		line.component = _component(m.get("component"), where + ".component")
		line.qty = _whole(m.get("qty", 1))
		if line.qty < 1:
			errors.append("%s: qty must be a whole number from 1." % where)
		line.supplied_by = String(m.get("supplied_by", "bsx"))
		if not line.supplied_by in ManifestLine.SUPPLIERS:
			errors.append("%s: supplied_by must be client or bsx." % where)
		var sources: Variant = m.get("allowed_sources", ["new"])
		if not sources is Array or sources.is_empty():
			errors.append("%s: allowed_sources must be a list." % where)
		else:
			line.allowed_sources = PackedStringArray()
			for s: Variant in sources:
				if String(s) in ManifestLine.SOURCES:
					line.allowed_sources.append(String(s))
				else:
					errors.append("%s: \"%s\" is not a source (new, refurbished, salvaged)." % [where, s])
		o.manifest.append(line)


func _read_spec_sheet(d: Dictionary, o: WorkOrder) -> void:
	var sheet: Variant = d.get("spec_sheet", {})
	if not sheet is Dictionary:
		errors.append("spec_sheet must be an object.")
		return
	o.use_library = bool(sheet.get("library", true))
	var list: Variant = sheet.get("overrides", [])
	if not list is Array:
		errors.append("spec_sheet.overrides must be a list.")
		return
	for i in list.size():
		var where := "spec_sheet.overrides[%d]" % i
		var ov: Variant = list[i]
		if not ov is Dictionary:
			errors.append("%s must be an object." % where)
			continue
		var id := _text(ov, "change_id", where)
		if not _change_ids.has(id):
			errors.append("%s: no change \"%s\" in this work order." % [where, id])
			continue
		var by_kind := {}
		for kind in SpecEntry.JOINT_KINDS:
			var v: Variant = ov.get(kind)
			if v is Dictionary:
				by_kind[kind] = v
			elif v != null:
				errors.append("%s.%s must be an object." % [where, kind])
		var merged: Dictionary = o.overrides.get(id, {})
		merged.merge(by_kind, true)
		o.overrides[id] = merged


func _component(v: Variant, where: String) -> ComponentRef:
	if not v is Dictionary or not v.get("id") is String or String(v.get("id")).is_empty():
		errors.append("%s must name a part, like {\"id\": \"IonThruster\"}." % where)
		return null
	var ref := ComponentRef.from_dict(v)
	if component_exists.is_valid() and not component_exists.call(ref.id):
		errors.append("%s: \"%s\" is not in the BSX parts library." % [where, ref.id])
	return ref


func _text(d: Dictionary, key: String, where: String) -> String:
	var v: Variant = d.get(key)
	if v is String and not v.is_empty():
		return v
	errors.append("%s%s is missing." % [where + ": " if where != "" else "", key])
	return ""


func _dict(d: Dictionary, key: String, where: String) -> Dictionary:
	var v: Variant = d.get(key)
	if v is Dictionary:
		return v
	errors.append("%s%s must be an object." % [where + ": " if where != "" else "", key])
	return {}


## A JSON number as a whole number, or -1 if it is not one.
static func _whole(v: Variant) -> int:
	if v is int:
		return v
	if v is float and v == floorf(v):
		return int(v)
	return -1
