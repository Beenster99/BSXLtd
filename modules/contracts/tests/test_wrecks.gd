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
	var machinery_wanted := false
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
			var gen := ShipGenerator.parse_id(String(o.subject.get("design", "")))
			check(not gen.is_empty(), "the hull is one of BSX's own generated ships: %s" % str(o.subject.get("design", "")))
			if not gen.is_empty():
				var trade := String(ContractClients.TABLE[client_id].get("trade", ""))
				check(String(gen["family"]) == ShipGenerator.family_for(trade), "%s's trade (%s) picks the family: %s" % [client_id, trade, str(gen["family"])])
				check(String(gen["size"]) in ["M", "L"], "tier three sends medium or large hulls: %s" % str(gen["size"]))
				check(int(gen["seed"]) == int(o.subject.get("seed", 0)), "the design's seed is the subject's")
			check(String(o.subject.get("name", "")) != "" and o.subject_name().begins_with(String(o.subject.get("name", ""))), "the subject is named after the ship: %s" % o.subject_name())
			check(o.title.to_lower().contains(String(o.subject.get("name", "")).to_lower()), "and so is the title: %s" % o.title)
			if o.kind == WorkOrder.BREAK:
				var ref: ComponentRef = o.wants[0]["component"]
				check((o.subject.get("holds", []) as Array).has(ref.id), "a break wants a fitting still aboard: %s" % ref.id)
				for w in o.wants:
					var r: ComponentRef = w["component"]
					if r.id in ["IonThruster", "TurbineEngine", "HydrogenEngine", "OvalEngine", "EngineBell", "Generator", "MachineUnit",
							"SwitchCabinet", "BatteryRack", "DrillHead", "LandingClamp", "Searchlight", "Antenna", "SolarPanel", "Container"]:
						machinery_wanted = true
			if (o.subject.get("holds", []) as Array).has("Turret"):
				check("weapons" in o.hazards, "a hull with a turret still on is a weapons hazard: %s" % str(o.hazards))
			if (o.subject.get("holds", []) as Array).has("jump_tank"):
				check("fuel" in o.hazards, "a hull with its jump tanks still in is a fuel hazard: %s" % str(o.hazards))
			var again := g.make(client_id, cycle, 0, 3)
			check(again == d, "the same seed makes the same ship and the same wants")
	check(n >= 8, "whole-ship offers come up often enough at tier three: %d" % n)
	check(kinds.size() >= 3, "several kinds: %s" % str(kinds.keys()))
	check(machinery_wanted, "some break job asks for the generated ship's machinery or trade gear back")
	check(sizes.has("medium"), "a medium hull is a medium job: %s" % str(sizes.keys()))
	var small_or_medium := true
	var saw_tier2 := false
	for cycle in range(1, 13):
		var d2 := g.make("scatter_metals", cycle, 0, 2)
		var gen2 := ShipGenerator.parse_id(String(d2.get("subject", {}).get("design", "")))
		if gen2.is_empty():
			continue
		saw_tier2 = true
		small_or_medium = small_or_medium and String(gen2["size"]) in ["S", "M"]
	check(saw_tier2 and small_or_medium, "tier two sends small or medium hulls")
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
	check("Seed %d" % int(job.order.subject.get("seed", 0)) in sheet and "Parts:" in sheet and "Fittings aboard:" in sheet and "Hull: a class" in sheet,
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
		var ship := String(job.order.subject.get("name", ""))
		check(ship != "" and cells.any(func(l: Label) -> bool: return l.text.begins_with(ship)), "the SHIP column names the ship: %s" % str(cells.map(func(l: Label) -> String: return l.text)))
	panel.queue_free()
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	var back := bus2.get_job(job.job_id)
	check(back != null and back.order.subject.get("seed") == job.order.subject.get("seed") and back.order.subject.get("holds") == job.order.subject.get("holds"), "a generated ship's subject survives a save")
	bus2.queue_free()
