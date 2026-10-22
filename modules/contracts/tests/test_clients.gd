extends ModuleTest
## Clients, standing and generated offers (plan stage S4): the client table, seeded offers
## that read like files, the board's cycle, offers expiring, standing moving at handover
## and cancel, tiers unlocking, the pricer hook and the save.
##   tools/run_tests.sh contracts

const BoardPanel := preload("res://modules/contracts/internal/board_panel.gd")
const Generator := preload("res://modules/contracts/internal/offer_generator.gd")


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
	check(bus.cycle() == 0 and _generated(bus).is_empty(), "no cycle and no generated offers with contracts.clients off")

	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true, "contracts.clients": true})
	Modules.load_all()
	bus = Modules.bus("contracts") as ContractsBus
	_test_table()
	_test_generator()
	_test_board(bus)
	_test_standing(bus)
	_test_save(bus)
	Flags.use(saved)
	Modules.load_all()


func _generated(bus: ContractsBus) -> Array[ContractJob]:
	var out: Array[ContractJob] = []
	for id in bus.job_ids():
		if bus.get_job(id).expires >= 0:
			out.append(bus.get_job(id))
	return out


func _test_table() -> void:
	check(ContractClients.TABLE.size() == 10, "ten clients: %d" % ContractClients.TABLE.size())
	var vs := 0
	for id: String in ContractClients.TABLE:
		var c: Dictionary = ContractClients.TABLE[id]
		if c.get("game") == "void_salvage":
			vs += 1
		for kind: String in c.get("kinds", []):
			check(kind in WorkOrder.KINDS and (c.get("voice", {}) as Dictionary).has(kind), "%s has a voice for %s" % [id, kind])
		for part: String in c.get("parts", []):
			check(ContractClients.PARTS.has(part), "%s sends a known part: %s" % [id, part])
	check(vs == 4, "four Void Salvage organisations: %d" % vs)
	for part: String in ContractClients.PARTS:
		check(Materials.TABLE.has(String(ContractClients.PARTS[part]["material"])), "%s is made of a Void Salvage material" % part)
	check(ContractClients.level_for(0) == 0 and ContractClients.level_for(10) == 1 and ContractClients.level_for(69) == 2
			and ContractClients.level_for(70) == 3, "levels from points")
	check(ContractClients.level_name(3) == "Preferred", "level names")


func _test_generator() -> void:
	var g := Generator.new()
	var a := g.make("tpa", 4, 0, 1)
	var b := g.make("tpa", 4, 0, 1)
	check(not a.is_empty() and a == b, "the same client, cycle and slot make the same offer")
	check(g.make("tpa", 5, 0, 1) != a, "another cycle makes another")
	check(g.make("nobody", 1, 0, 1).is_empty(), "an unknown client posts nothing")
	var reader := preload("res://modules/contracts/internal/work_order_reader.gd").new()
	var kinds := {}
	for client_id: String in ContractClients.TABLE:
		for cycle in range(1, 13):
			for tier in range(1, 4):
				var d := g.make(client_id, cycle, 0, tier)
				var o := reader.read(d)
				if o == null:
					check(false, "%s cycle %d tier %d reads: %s" % [client_id, cycle, tier, str(reader.errors)])
					continue
				kinds[o.kind] = true
				check(o.kind in ContractClients.TABLE[client_id]["kinds"] or o.kind == WorkOrder.SCRAP, "%s posts its own kinds" % client_id)
				check(o.subject_part() != null and float(o.subject.get("mass_kg", 0.0)) > 0.0, "a part subject with mass")
				check(not o.wants.is_empty() and o.title != "" and o.notes.size() == 1, "wants, a title and a note")
				var price := int(o.commercial.get("price", 0))
				check(price >= 1600 and price <= 15000, "small band price: %d" % price)
				if o.kind == WorkOrder.BREAK:
					var ref: ComponentRef = o.wants[0]["component"]
					check(ref.id in ContractClients.PARTS[o.subject_part().id]["yields"], "a break wants what the part yields")
	check(kinds.size() == 4, "every non-fit kind gets generated: %s" % str(kinds.keys()))
	var t1 := g.make("hesper_line", 2, 0, 1)
	var t3 := g.make("hesper_line", 2, 0, 3)
	check(int(t3["commercial"]["price"]) > int(t1["commercial"]["price"]), "tier three pays more than tier one")
	g.pricer = func(_kind: String, _size: String, _t: float) -> int: return 777
	check(int(g.make("tpa", 1, 0, 1)["commercial"]["price"]) == 777, "a wired pricer sets the price")
	var posted := 0
	for cycle in range(1, 41):
		if Generator.posts("scatter_metals", cycle):
			posted += 1
	check(posted >= 18 and posted <= 38, "Scatter Metals posts most cycles: %d of 40" % posted)


func _test_board(bus: ContractsBus) -> void:
	check(bus.cycle() == 1, "the board opens on cycle 1")
	var first := _generated(bus)
	check(not first.is_empty(), "clients posted on cycle 1: %d" % first.size())
	for job in first:
		check(job.state == ContractJob.OFFERED and job.expires == 1 + Generator.OFFER_LIFE, "%s is on offer until cycle %d" % [job.job_id, job.expires])
	var expired: Array[String] = []
	bus.offer_expired.connect(func(id: String) -> void: expired.append(id))
	var cycles: Array[int] = []
	bus.cycle_advanced.connect(func(c: int) -> void: cycles.append(c))
	for i in 8:
		bus.advance_cycle()
	check(bus.cycle() == 9 and cycles.size() == 8, "eight cycles on")
	check(not expired.is_empty(), "untaken offers left the board: %d" % expired.size())
	for id in expired:
		check(bus.get_job(id) == null, "%s is gone" % id)
	for client_id: String in ContractClients.TABLE:
		check(bus._open_offers(client_id) <= ContractsBus.OFFERS_PER_CLIENT, "%s keeps at most two offers up" % client_id)
	check(bus.board(ContractsBus.LOCAL).size() > 4, "BSX's own clients fill the local tab: %d" % bus.board(ContractsBus.LOCAL).size())
	for job in bus.board(ContractsBus.VOID_SALVAGE):
		check(String(job.order.client.get("game", "")) == "void_salvage", "Void Salvage tab is Void Salvage organisations")
	var factory: Callable = HudSlots.holo_channel(ContractsBus.BOARD_CHANNEL).factory
	var panel: Control = factory.call(true)
	add_child(panel)
	panel.pick_tab("local work")
	var job: ContractJob = null
	for j in panel.jobs():
		if j.expires >= 0:
			job = j
			break
	check(job != null, "a generated offer on the local tab")
	if job == null:
		panel.queue_free()
		return
	panel.pick(job.job_id)
	var texts := PackedStringArray()
	for l in panel.find_children("*", "Label", true, false):
		texts.append((l as Label).text)
	check(texts.has("Standing: New (0)  ·  on the board until cycle %d" % job.expires), "docket shows standing and the board life: %s" % str(texts))
	check(BoardPanel.job_title(job) == job.order.title, "a generated offer's title is its own")
	panel.queue_free()


func _test_standing(bus: ContractsBus) -> void:
	var changes: Array[String] = []
	bus.standing_changed.connect(func(c: String, p: int, l: int) -> void: changes.append("%s %d %d" % [c, p, l]))
	var job: ContractJob = null
	for j in _generated(bus):
		if j.order.kind == WorkOrder.DISPOSE:
			job = j
			break
	check(job != null, "a dispose offer to run through")
	if job == null:
		return
	var client := String(job.order.client.get("company", ""))
	check(bus.accept(job.job_id) and bus.subject_landed(job.job_id), "accepted and landed")
	bus.advance_cycle(bus.cycle() + Generator.OFFER_LIFE + 1)
	check(bus.get_job(job.job_id) != null, "a taken offer never expires")
	bus.advance(job.job_id, ContractJob.IN_BAY)
	bus.advance(job.job_id, ContractJob.IN_PROGRESS)
	bus.record_scrap(job.job_id, "steel", 1000.0, "destroyed")
	bus.advance(job.job_id, ContractJob.INSPECTION)
	check(bus.advance(job.job_id, ContractJob.HANDED_OVER), "handed over")
	check(bus.standing_of(client) == 10 and bus.level_of(client) == 1, "a clean handover earns 10 points and the known level: %d" % bus.standing_of(client))
	check(changes == ["%s 10 1" % client], "standing_changed: %s" % str(changes))
	bus.add_standing(client, 20)
	check(bus.level_of(client) == 2, "trusted at 30")
	bus.advance_cycle(bus.cycle() + 30)
	var tier2 := false
	for j in _generated(bus):
		if String(j.order.client.get("company", "")) == client:
			tier2 = tier2 or int((j.order.raw.get("offer", {}) as Dictionary).get("tier", 0)) == 2
	check(tier2, "%s now posts tier two offers" % client)
	var other: ContractJob = null
	for j in _generated(bus):
		if String(j.order.client.get("company", "")) != client:
			other = j
			break
	bus.accept(other.job_id)
	bus.cancel(other.job_id, false)
	check(bus.standing_of(String(other.order.client.get("company", ""))) == 0, "cancelling a new client's job can't go below zero")
	bus.add_standing(client, -4)
	check(bus.standing_of(client) == 26, "points go down too")


func _test_save(bus: ContractsBus) -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(bus.save_data()))
	var bus2 := ContractsBus.new()
	add_child(bus2)
	bus2.load_data(data, ContractsBus.SAVE_VERSION)
	check(bus2.cycle() == bus.cycle(), "the cycle survives a save")
	check(bus2._standing == bus._standing, "standing survives a save")
	check(_generated(bus2).size() == _generated(bus).size(), "generated offers and their expiry survive a save")
	bus2.queue_free()
