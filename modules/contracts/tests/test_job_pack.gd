extends ModuleTest
## The job pack (0.3.14 feedback): the documents that come with a contract, a spec sheet
## per object, the board's pack chips and coloured tags, and the document view.
##   tools/run_tests.sh contracts

const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")
const FIXTURE := "res://modules/contracts/tests/fixtures/kestrel_coil_fit.workorder.json"


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true, "contracts.clients": false})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.set_component_library(func(_id: String) -> bool: return true,
			func(id: String) -> Dictionary:
				return {"bolt": {"torque_nm": 180, "pattern": "cross"}, "connector": {"gauge_awg": 8}} if id == "attractor_coil_1" else {})
	check(bus.import_work_order(FIXTURE).ok(), "fixture imports")
	_test_fit_pack(bus)
	_test_part_pack(bus)
	_test_board(bus)
	Flags.use(saved)
	Modules.load_all()


func _ids(pack: Array[Dictionary]) -> PackedStringArray:
	var out := PackedStringArray()
	for d in pack:
		out.append(String(d.get("id", "")))
	return out


func _test_fit_pack(bus: ContractsBus) -> void:
	var id := "rook_salvage.bsx1"
	var pack := bus.job_pack(id)
	check(_ids(pack) == PackedStringArray(["order", "spec:c1", "manifest", "notes"]), "a fit job's pack: %s" % str(_ids(pack)))
	check(bus.job_pack("nope").is_empty() and bus.document(id, "nope").is_empty(), "unknown job or document is empty")
	var order := bus.document(id, "order")
	var text := ContractDocumentView.text_of(order)
	check("Rook Salvage (Void Salvage)" in text and "Kestrel" in text and "Pays CR 120,000" in text and "30% deposit" in text
			and "Late penalty CR 2,500 a day" in text, "the work order: %s" % text)
	check("Fitted now: Hold net in hold module 1, 80%" in text, "the work order lists what is fitted: %s" % text)
	var spec := bus.document(id, "spec:c1")
	text = ContractDocumentView.text_of(spec)
	check(spec.get("title") == "Spec sheet: Attractor coil Mk I", "a spec sheet per object: %s" % str(spec.get("title")))
	check("Swap Hold net for Attractor coil Mk I in hold module 1" in text, "the change: %s" % text)
	check("Material: Copper" in text, "the material")
	check("Torque: 200 N·m" in text and "Pattern: star" in text and "Gauge: 8 AWG" in text, "library values under the overrides: %s" % text)
	check("Keep the old net, I want it back." in text and "Coil feed must land on the hold breaker." in text, "the client's notes on the change")
	check("Parts manifest" in ContractDocumentView.text_of(bus.document(id, "manifest")) and "1 × Attractor coil Mk I (Copper), new or refurbished" in ContractDocumentView.text_of(bus.document(id, "manifest")), "the manifest")
	bus.advance(id, ContractJob.PARTS_READY)
	bus.advance(id, ContractJob.IN_BAY)
	bus.set_change_status(id, "c1", ChangeItem.STRIPPED)
	pack = bus.job_pack(id)
	check(_ids(pack)[-1] == "progress", "a taken job gains a progress sheet")
	check("C1: stripped" in ContractDocumentView.text_of(bus.document(id, "progress")), "progress lists each change's status")
	check((bus.document(id, "spec:c1").get("tags") as Array)[0].get("text") == "stripped", "the spec sheet is tagged with its status")
	var view := ContractDocumentView.new(bus.document(id, "spec:c1"), true)
	add_child(view)
	var labels := view.find_children("*", "Label", true, false)
	check(labels.size() > 8, "the view draws the sheet: %d labels" % labels.size())
	check(labels.any(func(l: Label) -> bool: return l.text == "BOLT JOINTS"), "with section headings")
	check(labels.any(func(l: Label) -> bool: return l.text == "STRIPPED"), "and tags: %s" % str(labels.map(func(l: Label) -> String: return l.text)))
	view.queue_free()


func _test_part_pack(bus: ContractsBus) -> void:
	var id := "tpa.sb301"
	var pack := bus.job_pack(id)
	check(_ids(pack) == PackedStringArray(["order", "spec:subject", "wants", "hazards", "notes"]), "a break job's pack: %s" % str(_ids(pack)))
	var spec := bus.document(id, "spec:subject")
	var text := ContractDocumentView.text_of(spec)
	check(spec.get("title") == "Spec sheet: Naval turret", "the subject's spec sheet")
	check("Naval turret, 55%, 6.2 t" in text and "Material: Mild steel, tier 1" in text, "what arrives: %s" % text)
	check("Holds: Turret base, Gun mount, Ammo box" in text, "what it holds")
	check("Strip it on the bench" in text and "Deliver: 2 × Turret base back, 60% or better" in text, "the work")
	check("HAZARD: WEAPONS" in text and "Confirm unloaded" in text, "hazards on the sheet")
	var hz := bus.document(id, "hazards")
	check((hz.get("tags") as Array).size() == 2 and "Pull the breaker" in ContractDocumentView.text_of(hz), "the hazard sheet")
	check("BSX keeps it" in ContractDocumentView.text_of(bus.document(id, "wants")), "who keeps the rest")
	check(ContractJobPack.KIND_TONES.size() == WorkOrder.KINDS.size(), "a colour per kind")


func _test_board(bus: ContractsBus) -> void:
	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	panel.pick("tpa.sb301")
	var tags: Control = panel.find_child("Tags", true, false)
	check(tags != null and tags.get_child_count() == 3, "the docket tags the kind and each hazard: %d" % (tags.get_child_count() if tags else -1))
	var chips: Control = panel.find_child("Pack", true, false)
	check(chips != null and chips.get_child_count() == 6, "summary plus five pack chips: %d" % (chips.get_child_count() if chips else -1))
	check(panel.find_child("Document_spec_subject", true, false) == null, "the summary shows first")
	panel.open_doc("spec:subject")
	check(panel.find_child("Document_spec_subject", true, false) != null, "a chip opens its document in the docket")
	check(panel.find_child("Accept", true, false) != null, "ACCEPT JOB stays under the document")
	panel.pick("brine_fuels.sd302")
	check(panel.doc == "" and panel.find_child("Document_spec_subject", true, false) == null, "picking another job goes back to its summary")
	var row: Control = panel.find_child("Row_tpa_sb301", true, false)
	var title := row.find_children("*", "Label", true, false)[0] as Label
	check(title.text.ends_with("⚠"), "a hazardous job is marked on the list: %s" % title.text)
	check(title.get_theme_color("font_color") == ContractDocumentView.tone_colour("warn"), "and coloured for its kind")
	panel.queue_free()
