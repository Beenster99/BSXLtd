extends ModuleTest
## Every part a contract asks for is a real part: on Business's parts list (the market
## catalogue, every Void Salvage part the yard can buy). The client table, break-job
## yields and wreck fittings are all on it; a generated offer never names a part off it;
## a board file that does (a ship module nobody can buy yet) is withdrawn.
##   tools/run_tests.sh contracts

const Generator := preload("res://modules/contracts/internal/offer_generator.gd")
const Reader := preload("res://modules/contracts/internal/work_order_reader.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "contracts.board": true, "contracts.kinds": true,
			"contracts.clients": true, "contracts.wrecks": true, "shared_components": true, "ship_bay": true, "business": true})
	Modules.load_all()
	var bus := Modules.bus("contracts") as ContractsBus
	var business: Variant = Modules.bus("business")
	check(bus != null and business != null and business.has_method("get_catalogue"), "contracts and business load")
	if bus == null or business == null:
		Flags.use(saved)
		Modules.load_all()
		return
	var catalogue: Variant = business.call("get_catalogue")
	var listed := func(id: String) -> bool: return bool(catalogue.call("has_part", id))
	check(catalogue.call("part_names").size() > 500, "the parts list is the market catalogue")
	var shots: Array = Shots.all().map(func(s: Dictionary) -> String: return str(s.id))
	check("contracts_board" in shots and "contracts_job_under_way" in shots, "the release tour shoots the board: %s" % str(shots))

	# The tables only name real parts.
	var off := PackedStringArray()
	for part_id: String in ContractClients.PARTS:
		if not listed.call(part_id):
			off.append(part_id)
		for y: String in ContractClients.PARTS[part_id].get("yields", []):
			if not listed.call(y):
				off.append(y)
	for f: String in Generator.WANTED_FITTINGS:
		if not listed.call(f):
			off.append(f)
	for client_id: String in ContractClients.TABLE:
		for p: String in ContractClients.TABLE[client_id].get("parts", []):
			if not listed.call(p):
				off.append(p)
	check(off.is_empty(), "every subject, yield and fitting is a real part: %s" % ", ".join(off))

	# Generated offers, wrecks included, only ask for real parts.
	var g := Generator.new()
	g.wrecks = true
	g.part_exists = listed
	var reader := Reader.new()
	var asked := 0
	var bad := PackedStringArray()
	for client_id: String in ContractClients.TABLE:
		for cycle in range(1, 9):
			for tier in range(1, 4):
				var d := g.make(client_id, cycle, 0, tier)
				if d.is_empty():
					continue
				var o := reader.read(d)
				if o == null:
					check(false, "%s cycle %d tier %d reads: %s" % [client_id, cycle, tier, str(reader.errors)])
					continue
				var s := o.subject_part()
				if s != null and not listed.call(s.id):
					bad.append(s.id)
				for w: Dictionary in o.wants:
					if String(w.get("what", "")) == "part":
						asked += 1
						var ref: ComponentRef = w["component"]
						if not listed.call(ref.id):
							bad.append(ref.id)
	check(asked > 20 and bad.is_empty(), "%d generated part wants, none off the list: %s" % [asked, ", ".join(bad)])

	# The board: nothing offered names a part off the list; the ship-module fits are
	# withdrawn until Business sells modules.
	var open := PackedStringArray()
	for tab in [ContractsBus.VOID_SALVAGE, ContractsBus.LOCAL]:
		for job: ContractJob in bus.board(tab):
			open.append(job.job_id)
			check(bus.unlisted_part(job.order) == "", "%s only names real parts" % job.job_id)
	check("tpa.sb301" in open and "kettle_rock.ss304" in open, "part jobs stay on the board: %s" % ", ".join(open))
	check(not "cold_iron.vs104" in open and bus.get_job("cold_iron.vs104") == null, "the tow winch fit is withdrawn (not a part anyone can buy)")

	# A stricter list withdraws an offer already up, telling the board.
	var expired: Array[String] = []
	bus.offer_expired.connect(func(id: String) -> void: expired.append(id))
	bus.set_part_list(func(id: String) -> bool: return id != "TurretBase" and bool(catalogue.call("has_part", id)))
	check(expired == ["tpa.sb301"] and bus.get_job("tpa.sb301") == null, "the turret job goes when turret bases leave the list: %s" % str(expired))
	check(bus.get_job("kettle_rock.ss304") != null, "the others stay")

	Flags.use(saved)
	Modules.load_all()
