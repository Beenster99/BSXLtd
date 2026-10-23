class_name ContractJobPack
extends RefCounted
## The job pack: the documents that come with a contract (beenster, 0.3.14 feedback: "as
## part of the contract there needs to come a sort of job pack which includes a lot of
## documents to describe the work, part of this is a spec sheet for each object"). Pure
## data, so the contracts board, the wrist Specs channel and Quality can each draw them:
## ContractsBus.job_pack(job_id) lists them, ContractsBus.document(job_id, doc_id) is one.
##
## A document is {id, kind, title, ref, tags: [{text, tone}], sections: [{heading,
## lines: [String]}]}. tone is one of TONES; the renderer picks the colour.

const TONES: PackedStringArray = ["plain", "good", "bad", "warn", "info"]
## Document kinds, in pack order.
const ORDER := "order"
const SPEC := "spec"
const WANTS := "wants"
const MANIFEST := "manifest"
const HAZARDS := "hazards"
const NOTES := "notes"
const PROGRESS := "progress"
const AS_BUILT := "as_built"

## A colour per job kind, for every screen that paints them.
const KIND_TONES: Dictionary = {"fit": "info", "break": "warn", "scrap": "plain", "refurbish": "good", "dispose": "bad"}
## What each hazard means for the crew.
const HAZARD_LINES: Dictionary = {
	"fuel": "Fuel aboard. Drain and vent before any hot work; no cutting or grinding near the tank until the gauge reads empty.",
	"coolant": "Coolant under pressure. Bleed the circuit and cap the lines before opening it.",
	"power": "Stored charge. Pull the breaker and discharge the capacitors; test dead before touching conductors.",
	"weapons": "Weapon system. Confirm unloaded and the feed cleared; the firing circuit is isolated before the breaker comes out.",
	"pressure": "Pressure vessel. Vent to atmosphere before cutting; never cut a sealed vessel.",
}


## Every document in a job's pack, in order. specs is the bus's spec lookup
## (Callable(job_id, change_id) -> SpecEntry) so the spec sheets carry library values.
static func documents(job: ContractJob, specs: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(order_doc(job))
	if job.order.is_fit():
		for c in job.order.changes:
			out.append(spec_doc(job, c, specs))
		if not job.order.manifest.is_empty():
			out.append(manifest_doc(job))
	else:
		out.append(subject_spec_doc(job))
		out.append(wants_doc(job))
	if not job.order.hazards.is_empty():
		out.append(hazards_doc(job))
	if not job.order.notes.is_empty():
		out.append(notes_doc(job))
	if job.state != ContractJob.OFFERED:
		out.append(progress_doc(job))
	return out


static func document(job: ContractJob, doc_id: String, specs: Callable) -> Dictionary:
	for d in documents(job, specs):
		if d.get("id") == doc_id:
			return d
	return {}


static func _doc(id: String, kind: String, title: String, ref: String) -> Dictionary:
	return {"id": id, "kind": kind, "title": title, "ref": ref, "tags": [], "sections": []}


static func _section(doc: Dictionary, heading: String, lines: PackedStringArray) -> void:
	if not lines.is_empty():
		(doc["sections"] as Array).append({"heading": heading, "lines": lines})


static func _tag(doc: Dictionary, text: String, tone: String) -> void:
	(doc["tags"] as Array).append({"text": text, "tone": tone})


static func order_doc(job: ContractJob) -> Dictionary:
	var o := job.order
	var d := _doc(ORDER, ORDER, "Work order", job.job_id.to_upper())
	_tag(d, o.kind, String(KIND_TONES.get(o.kind, "plain")))
	_tag(d, job.state.replace("_", " "), "good" if job.state in [ContractJob.HANDED_OVER, ContractJob.CLOSED] else "plain")
	var who := String(o.client.get("display_name", o.client.get("company", "")))
	var where := "Void Salvage" if String(o.client.get("game", "")) == "void_salvage" else "local"
	_section(d, "Client", PackedStringArray(["%s (%s)" % [who, where], "Issued %s" % o.issued_at]))
	var subject := PackedStringArray()
	if o.is_fit():
		subject.append("Ship: %s (%s)" % [words(o.design), o.ship_id])
		for f in o.current_fit:
			var ref: ComponentRef = f.get("component")
			subject.append("Fitted now: %s in %s, %d%%" % [words(ref.id if ref else "?"), slot_words(String(f.get("slot", ""))), int(roundf(float(f.get("condition", 1.0)) * 100.0))])
	else:
		subject.append("Arrives: " + subject_line(o))
		subject.append("Keeps the rest: %s" % ("BSX" if o.keeps == "bsx" else "the client"))
	_section(d, "Subject", subject)
	var c := o.commercial
	var terms := PackedStringArray(["Pays CR %s" % money(int(c.get("price", 0)))])
	if int(c.get("deposit_pct", 0)) > 0:
		terms.append("%d%% deposit on acceptance" % int(c.get("deposit_pct", 0)))
	if c.has("due_day"):
		terms.append("Due day %d" % int(c.get("due_day", 0)))
	elif c.has("deadline"):
		terms.append("Deadline %s" % String(c.get("deadline", "")))
	if float(c.get("late_penalty_per_day", 0.0)) > 0.0:
		terms.append("Late penalty CR %s a day" % money(int(c.get("late_penalty_per_day", 0))))
	_section(d, "Terms", terms)
	if not job.variations.is_empty():
		var vs := PackedStringArray()
		for v in job.variations:
			vs.append("%s: %s (CR %s)" % [String(v.get("variation_id", "")), String(v.get("description", "")), money(int(v.get("price_delta", 0)))])
		_section(d, "Variations", vs)
	return d


## A fit change's spec sheet: the part going in or out, its slot, and the settings per joint
## kind from the library with the client's overrides on top.
static func spec_doc(job: ContractJob, c: ChangeItem, specs: Callable) -> Dictionary:
	var part := c.install if c.install else c.remove
	var d := _doc("%s:%s" % [SPEC, c.change_id], SPEC, "Spec sheet: " + words(part.id if part else c.change_id), c.change_id.to_upper())
	_tag(d, job.status_of(c.change_id), "good" if job.status_of(c.change_id) == ChangeItem.INSPECTED else "bad" if job.status_of(c.change_id) == ChangeItem.FAILED else "plain")
	var what := PackedStringArray()
	match c.action:
		ChangeItem.ADD:
			what.append("Fit %s in %s" % [words(c.install.id), slot_words(c.slot)])
		ChangeItem.REMOVE:
			what.append("Take out %s from %s" % [words(c.remove.id), slot_words(c.slot)])
		_:
			what.append("Swap %s for %s in %s" % [words(c.remove.id), words(c.install.id), slot_words(c.slot)])
	if part and part.material != "":
		what.append("Material: " + material_name(part.material))
	_section(d, "Change", what)
	var spec: SpecEntry = specs.call(job.job_id, c.change_id) if specs.is_valid() else null
	if spec:
		for kind in SpecEntry.JOINT_KINDS:
			var vals: Dictionary = spec.for_kind(kind)
			if vals.is_empty():
				continue
			var lines := PackedStringArray()
			for k: String in vals:
				lines.append("%s: %s" % [words(k.trim_suffix("_nm").trim_suffix("_mm").trim_suffix("_awg")), value_text(vals[k], k)])
			_section(d, kind.capitalize() + " joints", lines)
	var notes := job.order.notes_for(c.change_id)
	if c.notes != "":
		notes.insert(0, c.notes)
	_section(d, "Client says", notes)
	var rec: InstallRecord = job.installs.get(c.change_id)
	if rec:
		var lines := PackedStringArray(["Quality %d%%" % int(roundf(rec.quality * 100.0)), "Source: %s" % rec.source])
		if rec.serial != "":
			lines.append("Serial " + rec.serial)
		for defect in rec.defects:
			lines.append("Defect: " + str(defect))
		_section(d, "As fitted", lines)
	return d


## A part subject's spec sheet (break, scrap, refurbish, dispose): what arrives, what it is
## made of, what it carries, and what it has to come out as.
static func subject_spec_doc(job: ContractJob) -> Dictionary:
	var o := job.order
	var part := o.subject_part()
	var what := words(part.id) if part else o.subject_name()
	var d := _doc("%s:subject" % SPEC, SPEC, "Spec sheet: " + what, o.kind.to_upper())
	_tag(d, o.kind, String(KIND_TONES.get(o.kind, "plain")))
	var lines := PackedStringArray([subject_line(o)])
	if part and part.material != "":
		var m: Dictionary = Materials.TABLE.get(part.material, {})
		lines.append("Material: %s, tier %d" % [material_name(part.material), int(m.get("tier", 1))])
	if part == null:
		# A whole ship or wreck BSX generates itself (S3): what the events left of it.
		var s := o.subject
		var gen := ShipGenerator.parse_id(String(s.get("design", o.design)))
		if not gen.is_empty():
			lines.append("Hull: a class %s %s of BSX's own make, design %s" % [String(gen["size"]), String(gen["family"]), String(s.get("design", ""))])
		if String(s.get("events", "")) != "":
			lines.append("Damage: " + String(s.get("events", "")).replace(":", " ").replace(",", ", "))
		if int(s.get("parts_left", 0)) > 0:
			lines.append("Parts: %d left, %d gone or cut off" % [int(s.get("parts_left", 0)), int(s.get("parts_gone", 0))])
		var holds: Array = s.get("holds", [])
		if not holds.is_empty():
			var counts := {}
			for h: String in holds:
				counts[h] = int(counts.get(h, 0)) + 1
			var names := PackedStringArray()
			for h: String in counts:
				names.append(words(h) if counts[h] == 1 else "%d × %s" % [counts[h], words(h)])
			lines.append("Fittings aboard: " + ", ".join(names))
		lines.append("Seed %d: the same ship on every machine" % int(s.get("seed", 0)))
	var info: Dictionary = ContractClients.PARTS.get(part.id, {}) if part else {}
	var yields: Array = info.get("yields", [])
	if not yields.is_empty():
		var names := PackedStringArray()
		for y: String in yields:
			names.append(words(y))
		lines.append("Holds: " + ", ".join(names))
	_section(d, "Arrives as", lines)
	var work := PackedStringArray()
	match o.kind:
		WorkOrder.BREAK:
			work.append("Strip it on the bench. Unbolt what the client wants back; cut nothing they want intact.")
		WorkOrder.SCRAP:
			work.append("Cut it down and press clean material by the kilo. Fittings off first; mixed metal spoils a bale.")
		WorkOrder.REFURBISH:
			work.append("Strip, inspect, replace worn parts, rebuild and test. It goes back to the client at the condition asked.")
		WorkOrder.DISPOSE:
			work.append("Make it safe, then destroy it. The record of destruction is the deliverable.")
	for w in o.wants:
		work.append("Deliver: " + want_line(w))
	_section(d, "Work", work)
	for h in o.hazards:
		_section(d, "Hazard: " + h, PackedStringArray([String(HAZARD_LINES.get(h, "Take care."))]))
	return d


static func wants_doc(job: ContractJob) -> Dictionary:
	var o := job.order
	var d := _doc(WANTS, WANTS, "Client wants", job.job_id.to_upper())
	var lines := PackedStringArray()
	for w in o.wants:
		lines.append(want_line(w))
	_section(d, "Back to the client", lines)
	_section(d, "Everything else", PackedStringArray(["BSX keeps it" if o.keeps == "bsx" else "Goes back to the client too, scrap included"]))
	var missing := job.missing_wants()
	if job.state != ContractJob.OFFERED:
		_section(d, "Still to do", missing if not missing.is_empty() else PackedStringArray(["Nothing: the wants are met"]))
	return d


static func manifest_doc(job: ContractJob) -> Dictionary:
	var d := _doc(MANIFEST, MANIFEST, "Parts manifest", job.job_id.to_upper())
	var bsx := PackedStringArray()
	var client := PackedStringArray()
	for m in job.order.manifest:
		var line := "%d × %s" % [m.qty, words(m.component.id)]
		if m.component.material != "":
			line += " (%s)" % material_name(m.component.material)
		if m.supplied_by == "bsx":
			bsx.append(line + ", " + " or ".join(m.allowed_sources))
		else:
			client.append(line)
	_section(d, "BSX supplies", bsx)
	_section(d, "Client supplies", client)
	return d


static func hazards_doc(job: ContractJob) -> Dictionary:
	var d := _doc(HAZARDS, HAZARDS, "Hazard sheet", job.job_id.to_upper())
	for h in job.order.hazards:
		_tag(d, h, "bad")
		_section(d, h.capitalize(), PackedStringArray([String(HAZARD_LINES.get(h, "Take care."))]))
	return d


static func notes_doc(job: ContractJob) -> Dictionary:
	var d := _doc(NOTES, NOTES, "Client notes", job.job_id.to_upper())
	var general := PackedStringArray()
	for n in job.order.notes:
		var cid := String(n.get("change_id", ""))
		if cid == "":
			general.append("“%s”" % String(n.get("text", "")))
		else:
			_section(d, "On " + cid.to_upper(), PackedStringArray(["“%s”" % String(n.get("text", ""))]))
	if not general.is_empty():
		(d["sections"] as Array).insert(0, {"heading": "General", "lines": general})
	return d


static func progress_doc(job: ContractJob) -> Dictionary:
	var d := _doc(PROGRESS, PROGRESS, "Progress", job.state.replace("_", " ").to_upper())
	var o := job.order
	if o.is_fit():
		var lines := PackedStringArray()
		for c in o.changes:
			lines.append("%s: %s" % [c.change_id.to_upper(), job.status_of(c.change_id)])
		_section(d, "Changes", lines)
	else:
		var lines := PackedStringArray()
		for r in job.recoveries:
			var comp: Dictionary = r.get("component", {})
			if comp.is_empty():
				lines.append("%s kg %s, %s" % [money(int(r.get("kg", 0))), String(r.get("material", "")), String(r.get("disposition", ""))])
			else:
				lines.append("%s at %d%%, %s" % [words(String(comp.get("id", ""))), int(roundf(float(r.get("condition", 0.0)) * 100.0)), String(r.get("disposition", ""))])
		_section(d, "Recovered so far", lines if not lines.is_empty() else PackedStringArray(["Nothing yet"]))
		_section(d, "Still wanted", job.missing_wants())
	var tests := PackedStringArray()
	for t in job.tests:
		tests.append("%s: %s" % [String(t.get("name", "")), "passed" if t.get("passed") else "failed"])
	_section(d, "Tests", tests)
	if job.open_snags > 0:
		_section(d, "Snags", PackedStringArray(["%d open" % job.open_snags]))
	return d


# Words

static func subject_line(o: WorkOrder) -> String:
	var s := o.subject
	var part := o.subject_part()
	var bits := PackedStringArray([words(part.id) if part else o.subject_name()])
	bits.append("%d%%" % int(roundf(float(s.get("condition", 1.0)) * 100.0)))
	var kg := float(s.get("mass_kg", 0.0))
	if kg > 0.0:
		bits.append("%.1f t" % (kg / 1000.0) if kg >= 1000.0 else "%d kg" % int(kg))
	return ", ".join(bits)


static func want_line(w: Dictionary) -> String:
	match String(w.get("what", "")):
		"part":
			var ref: ComponentRef = w.get("component")
			var line := "%d × %s back" % [int(w.get("qty", 1)), words(ref.id) if ref else "part"]
			if float(w.get("min_condition", 0.0)) > 0.0:
				line += ", %d%% or better" % int(roundf(float(w.get("min_condition", 0.0)) * 100.0))
			return line
		"material":
			return "%s kg of %s" % [money(int(w.get("kg", 0.0))), material_name(String(w.get("material", "")))]
		"condition":
			return "The subject back at %d%% or better" % int(roundf(float(w.get("min_condition", 1.0)) * 100.0))
	return "The subject gone: scrapped or destroyed"


## "attractor_coil_1" -> "Attractor coil Mk I"; "NavalTurret" -> "Naval turret".
static func words(id: String) -> String:
	var marks := {"1": "Mk I", "2": "Mk II", "3": "Mk III"}
	var parts := id.to_snake_case().split("_")
	if parts.size() > 1 and marks.has(parts[-1]):
		parts[-1] = marks[parts[-1]]
	var s := " ".join(parts)
	return s.substr(0, 1).to_upper() + s.substr(1)


## "hold_module_1" -> "hold module 1" (a slot keeps its number).
static func slot_words(slot: String) -> String:
	return slot.replace("_", " ")


static func material_name(id: String) -> String:
	return String(Materials.TABLE.get(id, {}).get("name", id.capitalize()))


static func value_text(v: Variant, key: String) -> String:
	var text := str(int(v)) if v is float and v == floorf(v) else str(v)
	if key == "torque_nm":
		return text + " N·m"
	if key.ends_with("_mm"):
		return text + " mm"
	if key.ends_with("_awg"):
		return text + " AWG"
	return text


static func money(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
