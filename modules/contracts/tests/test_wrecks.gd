extends ModuleTest
## Ships and wrecks as contract subjects (plan stage S3): BSX's own clients send whole ships
## and wrecks the offer generator makes with Shared Components' WreckMaker, seeded per offer,
## with wants drawn from what is really left on them; the board, the spec sheet, the subject
## sent to Ship and Bay, and the flag.
##   tools/run_tests.sh contracts

const Generator := preload("res://modules/contracts/internal/offer_generator.gd")
const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true, "contracts.clients": true, "contracts.wrecks": false})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	check(Modules.is_loaded("shared_components"), "shared components is a dependency now")
	_test_facts()
	_test_generator()
	bus.add_standing("hesper_line", 30)
	bus.add_standing("carrow_underwriters", 30)
	bus.add_standing("scatter_metals", 30)
	bus.add_standing("tallow_reserve", 30)
	for i in 12:
		bus.advance_cycle()
	check(_whole(bus).is_empty(), "no whole-ship offers with contracts.wrecks off")

	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true, "contracts.clients": true, "contracts.wrecks": true})
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	_test_board(bus)
	Flags.use(saved)
	Modules.load_all()


func _whole(bus: ContractsBus) -> Array[ContractJob]:
	var out: Array[ContractJob] = []
	for id in bus.job_ids():
		var job := bus.get_job(id)
		if String(job.order.subject.get("type", "")) in ["ship", "wreck"] and not job.order.is_fit():
			out.append(job)
	return out


func _test_facts() -> void:
	var designs := VsShipImport.designs()
	check(not designs.is_empty(), "shared components lists ship designs: %s" % str(designs))
	if designs.is_empty():
		return
	var clean := WreckMaker.for_design(designs[0], 7, "")
	var facts := Generator.ship_facts(clean)
	check(float(facts["mass_kg"]) > 1000.0 and int(facts["parts_gone"]) == 0 and is_equal_approx(float(facts["condition"]), 1.0),
			"a clean ship: all its mass, nothing gone, condition 1: %s" % str(facts))
	check((facts["holds"] as Array).has("galley"), "it lists the fittings aboard: %s" % str(facts["holds"]))
	var wreck := WreckMaker.for_design(designs[0], 7, "fire:4,stripped:3")
	var wf := Generator.ship_facts(wreck)
	check(float(wf["mass_kg"]) < float(facts["mass_kg"]) and int(wf["parts_gone"]) > 0, "a burnt, stripped wreck is lighter with parts gone: %s" % str(wf))
	check(float(wf["condition"]) < 0.9, "and in worse condition: %.2f" % float(wf["condition"]))
	check((wf["holds"] as Array).size() < (facts["holds"] as Array).size(), "stripping took fittings")


func _test_generator() -> void:
	var g := Generator.new()
	g.wrecks = true
	var reader := Reader.new()
	var kinds := {}
	var sizes := {}
	var n := 0
	for client_id: String in ["hesper_line", "carrow_underwriters", "scatter_metals", "tallow_reserve"]:
		for cycle in range(1, 9):
			var d := g.make(client_id, cycle, 0, 3)
			if d.is_empty() or not String(d.get("subject", {}).get("type", "")) in ["ship", "wreck"]:
				continue
			n += 1
			var o := reader.read(d)
			check(o != null, "%s cycle %d whole-ship offer reads: %s" % [client_id, cycle, str(reader.errors)])
			if o == null:
				continue
			kinds[o.kind] = true
			sizes[String((d["offer"] as Dictionary).get("size", ""))] = true
			check(o.subject.get("seed", 0) > 0 and float(o.subject.get("mass_kg", 0.0)) > 1000.0, "the subject carries a seed and the mass left")
			check((o.kind == WorkOrder.REFURBISH) == (o.subject.get("type") == "ship"), "a refurbish takes a ship, the rest a wreck")
			check(o.subject.get("events", "") != "", "events say what happened to it")
			if o.kind == WorkOrder.BREAK:
				var ref: ComponentRef = o.wants[0]["component"]
				check((o.subject.get("holds", []) as Array).has(ref.id), "a break wants a fitting still aboard: %s" % ref.id)
			var again := g.make(client_id, cycle, 0, 3)
			check(again == d, "the same seed makes the same ship and the same wants")
	check(n >= 8, "whole-ship offers come up often enough at tier three: %d" % n)
	check(kinds.size() >= 3, "several kinds: %s" % str(kinds.keys()))
	check(sizes.has("medium"), "the Kestrel is a medium job: %s" % str(sizes.keys()))
	var tier1 := g.make("hesper_line", 3, 0, 1)
	check(String(tier1.get("subject", {}).get("type", "")) == "part", "tier one still sends parts to the bench")
	g.wrecks = false
	check(String(g.make("hesper_line", 3, 0, 3).get("subject", {}).get("type", "")) == "part", "with wrecks off, parts only")


func _test_board(bus: ContractsBus) -> void:
	bus.add_standing("hesper_line", 30)
	bus.add_standing("carrow_underwriters", 30)
	bus.add_standing("scatter_metals", 30)
	bus.add_standing("tallow_reserve", 30)
	for i in 12:
		bus.advance_cycle()
	var whole := _whole(bus)
	check(not whole.is_empty(), "trusted BSX clients send whole ships and wrecks: %d" % whole.size())
	if whole.is_empty():
		return
	var job := whole[0]
	var sheet := ContractDocumentView.text_of(bus.document(job.job_id, "spec:subject"))
	check("Seed %d" % int(job.order.subject.get("seed", 0)) in sheet and "Parts:" in sheet and "Fittings aboard:" in sheet,
			"the spec sheet describes the generated ship: %s" % sheet)
	var due: Array = []
	bus.subject_due.connect(func(id: String, s: Dictionary) -> void: due.append([id, s]))
	check(bus.accept(job.job_id), "accept it")
	check(due.size() == 1, "subject_due for Ship and Bay")
	if due.size() == 1:
		var s: Dictionary = due[0][1]
		check(s.get("type") in ["ship", "wreck"] and s.has("design") and s.has("seed") and s.has("events"),
				"with design, seed and events to rebuild it: %s" % str(s.keys()))
		var again := WreckMaker.for_design(String(s["design"]), int(s["seed"]), String(s["events"]))
		check(is_equal_approx(float(Generator.ship_facts(again)["mass_kg"]), float(s["mass_kg"])), "and the bay gets the same ship back from them")
	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	panel.pick_tab("accepted")
	var row: Control = panel.find_child("Row_" + job.job_id.validate_node_name(), true, false)
	check(row != null, "the job is on the accepted tab")
	if row:
		var cells := row.find_children("*", "Label", true, false)
		check(cells.any(func(l: Label) -> bool: return l.text.begins_with("Kestrel") or l.text.begins_with("Manta")), "the SHIP column names the design: %s" % str(cells.map(func(l: Label) -> String: return l.text)))
	panel.queue_free()
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	var back := bus2.get_job(job.job_id)
	check(back != null and back.order.subject.get("seed") == job.order.subject.get("seed") and back.order.subject.get("holds") == job.order.subject.get("holds"), "a generated ship's subject survives a save")
	bus2.queue_free()
