extends ModuleTest
## Scrap and recycle (plan stage S5, the contracts side): scrap jobs pay by the tonne on top
## of the labour, the yard credits a crushed lot to its job with the job's disposition, and
## the order and the board say so.
##   tools/run_tests.sh contracts

const Generator := preload("res://modules/contracts/internal/offer_generator.gd")
const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")
const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")

const SCRAP := "kettle_rock.ss304"
const DISPOSE := "brine_fuels.sd302"
const BREAK := "tpa.sb301"


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
			"contracts.clients": true, "contracts.wrecks": true, "shared_components": true})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus:
		_test_pricing()
		_test_lots(bus)
		_test_words(bus)
	Flags.use(saved)
	Modules.load_all()


func _test_pricing() -> void:
	var g := Generator.new()
	check(g.scrap_fee("steel", 1000.0) == 400 and g.scrap_fee("alloy", 1000.0) == 640, "a tonne of steel costs the client 400, alloy its price factor more: %d / %d" % [g.scrap_fee("steel", 1000.0), g.scrap_fee("alloy", 1000.0)])
	check(g.scrap_fee("steel", 0.0) == 0 and g.scrap_fee("unobtainium", 1000.0) == 400, "nothing for nothing; an unknown material at the steel rate")
	var c := g.commercial(WorkOrder.SCRAP, "small", 0.0, [{"what": "material", "material": "steel", "kg": 5000.0}], 9)
	check(int(c["price"]) == g.price_for(WorkOrder.SCRAP, "small", 0.0) + 2000 and is_equal_approx(float(c["tonnes"]), 5.0) and int(c["per_tonne"]) == 400,
			"a scrap job pays labour plus the fee by the tonne: %s" % str(c))
	var b := g.commercial(WorkOrder.BREAK, "small", 0.0, [{"what": "part", "component": {"id": "Gyroscope"}, "qty": 1}], 9)
	check(not b.has("tonnes") and int(b["price"]) == g.price_for(WorkOrder.BREAK, "small", 0.0), "a break job pays labour only")
	g.scrap_pricer = func(material: String, kg: float) -> int: return int(kg) * (3 if material == "steel" else 1)
	check(g.scrap_fee("steel", 1000.0) == 3000, "Business's own rate wins once wired in")
	g.scrap_pricer = Callable()
	# Every generated scrap offer, part or whole wreck, carries the terms.
	g.wrecks = true
	var reader := Reader.new()
	var n := 0
	for client_id: String in ["scatter_metals", "kettle_rock", "carrow_underwriters"]:
		for cycle in range(1, 13):
			for tier in [1, 3]:
				var d := g.make(client_id, cycle, 0, tier)
				if d.is_empty() or String(d.get("kind", "")) != WorkOrder.SCRAP:
					continue
				n += 1
				var o := reader.read(d)
				check(o != null, "a scrap offer reads: %s" % str(reader.errors))
				if o == null:
					continue
				var kg := 0.0
				for w in o.wants:
					if String(w.get("what", "")) == "material":
						kg += float(w.get("kg", 0.0))
				check(float(o.commercial.get("tonnes", 0.0)) > 0.0 and is_equal_approx(float(o.commercial.get("tonnes", 0.0)), snappedf(kg / 1000.0, 0.1)),
						"%s: the tonnes on the order are the tonnes wanted: %s" % [o.contract_id, str(o.commercial)])
				check(int(o.commercial.get("per_tonne", 0)) > 0 and int(o.commercial.get("price", 0)) > int(o.commercial.get("per_tonne", 0)) * int(floor(float(o.commercial.get("tonnes", 0.0)))),
						"and the price covers the fee: %s" % str(o.commercial))
	check(n >= 6, "scrap offers come up, parts and wrecks: %d" % n)


func _test_lots(bus: ContractsBus) -> void:
	check(bus.job_of_order("subject:" + SCRAP) == SCRAP and bus.job_of_order("subject:nobody") == "" and bus.job_of_order("order:7") == "",
			"a subject delivery's order id names its job")
	check(bus.scrap_disposition(SCRAP) == "kept" and bus.scrap_disposition(DISPOSE) == "scrapped" and bus.scrap_disposition(BREAK) == "scrapped",
			"BSX keeps a scrap job's metal when the order leaves it the rest; other jobs' crushed lots are scrapped")
	check(bus.scrap_disposition("rook_salvage.vs101") == "" and bus.scrap_disposition("nobody") == "", "nothing for a fit job or an unknown one")
	var job := bus.get_job(SCRAP)
	job.order.keeps = "client"
	check(bus.scrap_disposition(SCRAP) == "returned", "a client who keeps the rest gets the metal back")
	job.order.keeps = "bsx"
	check(bus.get_job(SCRAP).order.commercial.get("tonnes") == 8.0 and int(job.order.commercial.get("per_tonne", 0)) == 640, "the hand-written scrap job carries its tonnes")

	var recorded: Array = []
	bus.recovery_recorded.connect(func(id: String, line: Dictionary) -> void: recorded.append([id, line]))
	bus.accept(SCRAP)
	_check_docket()
	bus.subject_landed(SCRAP)
	bus.advance(SCRAP, ContractJob.IN_BAY)
	bus.advance(SCRAP, ContractJob.IN_PROGRESS)
	check(is_equal_approx(bus.record_scrap_lot(SCRAP, {"alloy": 5000.0, "steel": 1200.0, "copper": 0.0}), 6200.0), "a crushed lot's cast goes down by material")
	check(recorded.size() == 2 and recorded[0][1].get("material") == "alloy" and recorded[0][1].get("disposition") == "kept",
			"each material is a recovery line with the job's disposition: %s" % str(recorded))
	bus.advance(SCRAP, ContractJob.INSPECTION)
	check(job.missing_wants() == PackedStringArray(["5000 of 8000 kg alloy"]), "steel does not count towards alloy: %s" % str(job.missing_wants()))
	bus.record_scrap_lot(SCRAP, {"alloy": 3000.0})
	check(bus.advance(SCRAP, ContractJob.HANDED_OVER), "eight tonnes of alloy baled, handed over")
	check(is_equal_approx(bus.record_scrap_lot("rook_salvage.vs101", {"steel": 100.0}), 0.0), "a fit job takes no lots")

	bus.accept(DISPOSE)
	bus.subject_landed(DISPOSE)
	bus.advance(DISPOSE, ContractJob.IN_BAY)
	bus.advance(DISPOSE, ContractJob.IN_PROGRESS)
	bus.advance(DISPOSE, ContractJob.INSPECTION)
	bus.record_scrap_lot(DISPOSE, {"steel": 2800.0, "alloy": 700.0})
	check(bus.advance(DISPOSE, ContractJob.HANDED_OVER), "crushing a dispose job's tank is the subject gone")
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	var back := bus2.get_job(SCRAP)
	check(back != null and back.recoveries.size() == 3 and back.order.commercial.get("tonnes") == 8.0, "the lots and the terms survive a save")
	bus2.queue_free()


func _test_words(bus: ContractsBus) -> void:
	var order := ContractDocumentView.text_of(bus.document(SCRAP, "order"))
	check("By the tonne: CR 640 a tonne for 8.0 t cut and baled" in order, "the work order spells the terms: %s" % order)
	var progress := ContractDocumentView.text_of(bus.document(SCRAP, "progress"))
	check("5,000 kg alloy, kept" in progress and "1,200 kg steel, kept" in progress, "progress lists each lot: %s" % progress)


## The accepted scrap job's docket on the board shows the rate.
func _check_docket() -> void:
	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	panel.pick_tab("accepted")
	panel.pick(SCRAP)
	var labels := panel.find_children("*", "Label", true, false)
	check(labels.any(func(l: Label) -> bool: return l.text.begins_with("BY THE TONNE: CR 640")), "the docket shows the rate: %s" % str(labels.map(func(l: Label) -> String: return l.text).filter(func(t: String) -> bool: return "TONNE" in t)))
	panel.queue_free()
