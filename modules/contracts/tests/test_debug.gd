extends ModuleTest
## The Debug page's Contracts section: call in an offer from any client at any tier, whatever
## BSX's standing with them (host-applied in multiplayer, at once in a solo game).
##   tools/run_tests.sh contracts

const Generator := preload("res://modules/contracts/internal/offer_generator.gd")

func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
			"contracts.clients": true, "contracts.wrecks": true, "contracts.debug": true, "shared_components": true})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	check(bus != null, "contracts loads")
	if bus:
		_test_call_in(bus)
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
			"contracts.clients": true, "shared_components": true})
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	if bus:
		check(not Menu.settings_sections(Menu.DEBUG).any(func(s: Dictionary) -> bool: return s.id == ContractsBus.DEBUG_SECTION),
				"with contracts.debug off there is no Contracts section on the Debug page")
		check(bus._validate_call_in(1, {"client": "tallow_reserve", "tier": 2}) is String, "and a call-in is refused")
	Flags.use(saved)
	Modules.load_all()


func _test_call_in(bus: ContractsBus) -> void:
	check(Menu.settings_sections(Menu.DEBUG).any(func(s: Dictionary) -> bool: return s.id == ContractsBus.DEBUG_SECTION and s.label == "Contracts"),
			"a Contracts section is on the Debug page: %s" % str(Menu.settings_sections(Menu.DEBUG).map(func(s: Dictionary) -> String: return str(s.id))))
	check(bus.level_of("tallow_reserve") == 0, "Tallow Reserve is New to BSX")
	var before := bus.job_ids().size()
	var id := bus.call_in("tallow_reserve", 3)
	var job := bus.get_job(id)
	check(job != null and job.state == ContractJob.OFFERED, "calling in posts an offer: %s" % id)
	if job:
		check(String(job.order.client.get("company", "")) == "tallow_reserve", "from the client picked")
		var g := Generator.new()
		g.wrecks = true
		var same := g.make("tallow_reserve", bus.cycle(), ContractsBus.CALL_IN_SLOT, 3)
		check(String(same.get("contract_id", "")) == id and int((same.get("offer", {}) as Dictionary).get("tier", 0)) == 3,
				"it is the tier-three offer the generator writes for the first call-in slot, standing or not: %s" % id)
		check(int(job.order.commercial.get("price", 0)) == int((same.get("commercial", {}) as Dictionary).get("price", -1)), "with its price")
		check(job.expires > bus.cycle(), "it stays on the board like any offer")
	var again := bus.call_in("tallow_reserve", 3)
	check(again != "" and again != id, "a second call makes a second offer: %s" % again)
	check(bus.call_in("nobody", 2) == "" and bus.call_in("hesper_line", 1) != "", "unknown clients give nothing, known ones any tier")
	check(bus.job_ids().size() == before + 3, "three offers added")

	check(bus._validate_call_in(1, {"client": "nobody", "tier": 2}) is String and bus._validate_call_in(1, {"client": "hesper_line", "tier": 7}) is String,
			"the host refuses unknown clients and tiers")
	var ok: Variant = bus._validate_call_in(1, {"client": "oread_racing", "tier": "2"})
	check(ok is Dictionary and ok.get("client") == "oread_racing" and ok.get("tier") == 2, "and passes a good request through: %s" % str(ok))
	bus.request_call_in("oread_racing", 2)
	check(bus.job_ids().size() == before + 4, "a request with no multiplayer applies at once")

	var section: Control = bus._debug_section()
	add_child(section)
	var button: Button = section.find_child("CallIn", true, false)
	check(button != null and section.find_child("ClientChips", true, false) != null and section.find_child("TierChips", true, false) != null,
			"the section has client chips, tier chips and the button")
	if button:
		button.pressed.emit()
		check(bus.job_ids().size() == before + 5, "pressing the button calls an offer in")
	section.queue_free()
