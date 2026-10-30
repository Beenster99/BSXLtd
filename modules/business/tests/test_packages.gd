extends ModuleTest
## Frame packages (beenster, 0.3.31): a committed frame shows on the Buy tab as a package with
## its own ref and buys nothing; ORDER buys it (one supplier with everything when one has it)
## and its orders are marked for the courtyard; a package can be dropped; packages survive a
## save; the wrist lists them under PACKAGES.
##   tools/run_tests.sh business

const Wrist := preload("res://modules/business/internal/ui/wrist_screen.gd")


func run_tests() -> void:
	var saved := Flags.all()
	Flags.use({"core": true, "ui": true, "contracts": true, "ship_bay": true, "business": true})
	Modules.load_all()
	var bus := Modules.bus("business") as BusinessBus
	check(bus != null, "business loads")
	if bus == null:
		Flags.use(saved)
		Modules.load_all()
		return
	bus.reset()

	# Two beam bars, a few of each.
	var parts := {}
	for l in bus.get_listings("beams"):
		if l.available >= 4:
			parts[l.part] = true
		if parts.size() == 2:
			break
	check(parts.size() == 2, "two beam bars on the market")
	var items: Array = []
	for part: String in parts:
		items.append({"part": part, "qty": 3})

	var cash := bus.get_cash()
	var orders := bus.get_orders().size()
	var changed: Array = []
	bus.package_changed.connect(func(ref: String) -> void: changed.append(ref))
	var ref := bus.propose_package("Frame for the Kestrel", items, "JOB-1")
	var ref2 := bus.propose_package("Second frame", items)
	check(ref.begins_with("PKG-") and ref2.begins_with("PKG-") and ref != ref2, "each package has its own ref: %s, %s" % [ref, ref2])
	check(bus.get_cash() == cash and bus.get_orders().size() == orders, "proposing buys nothing")
	check(changed == [ref, ref2], "and says so: %s" % str(changed))
	check(bus.propose_package("Empty", []) == "", "an empty package isn't made")
	var listed := bus.get_packages()
	check(listed.size() == 2 and listed[0].ref == ref2 and listed[1].state == "proposed", "packages are listed newest first, proposed")
	check(listed[1].destination == "courtyard" and listed[1].contract_id == "JOB-1", "for the courtyard and the job")

	var plan := bus.quote_package(ref)
	check((plan.missing as Array).is_empty() and int(plan.cost) > 0 and (plan.basket as Array).size() == 2, "it can be priced today: %d CR" % int(plan.cost))
	var one := _one_supplier(bus, items)
	if one != "":
		check(plan.suppliers == [one], "from the one supplier with every part, the cheapest: %s" % str(plan.suppliers))

	# The wrist shows it under PACKAGES.
	var wrist := Wrist.new(bus, "orders", true)
	wrist.size = Vector2(860, 420)
	add_child(wrist)
	await frames(2)
	wrist.refresh()
	check(wrist._categories().size() > 0 and wrist._categories()[0] == "packages", "the Buy tab has a PACKAGES chip first")
	check(wrist.find_child("Package_" + ref, true, false) != null and wrist.find_child("Heading_packages", true, false) != null,
			"ALL lists the packages under their heading")
	wrist.category = "packages"
	wrist.refresh()
	check(wrist.shown_listings().is_empty() and wrist.shown_packages().size() == 2, "PACKAGES shows only the packages")
	var order := wrist.find_child("Order_" + ref, true, false) as Button
	check(order != null and not order.disabled, "a proposed package has ORDER")

	var r := wrist.order_package(ref)
	check(r.is_ok() and r.order_ids.size() >= 1, "ORDER buys it: %s" % r.message)
	check(bus.get_cash() == cash - r.cost and r.cost == int(plan.cost), "for the price it showed: %d" % r.cost)
	var got := 0
	for id in r.order_ids:
		var o := bus.get_order(id)
		check(o.destination == "courtyard" and o.package_ref == ref and o.contract_id == "JOB-1", "%s goes to the courtyard for the package" % id)
		got += o.item_count()
	check(got == 6, "every part is on order: %d" % got)
	var pkg: Dictionary = bus.get_packages().filter(func(p: Dictionary) -> bool: return p.ref == ref)[0]
	check(pkg.state == "ordered" and pkg.cost == r.cost and pkg.order_ids.size() == r.order_ids.size(), "the package shows it's ordered")
	check(not bus.order_package(ref).is_ok(), "a package is ordered once")
	await frames(2)
	check(wrist.find_child("Order_" + ref, true, false) == null, "an ordered package has no ORDER")
	check(wrist.shown_deliveries().size() == r.order_ids.size(), "its orders are in Deliveries under PACKAGES")

	# Dropping one, and a save.
	check(bus.cancel_package(ref2).is_ok() and bus.get_packages().size() == 1, "a proposed package can be dropped")
	check(not bus.cancel_package(ref).is_ok(), "an ordered one can't")
	var data := bus.save_data()
	bus.reset()
	check(bus.get_packages().is_empty(), "a reset clears packages")
	bus.load_data(data, bus.save_version())
	var back := bus.get_packages()
	check(back.size() == 1 and back[0].ref == ref and back[0].state == "ordered" and int(back[0].cost) == r.cost, "packages come back from a save")
	check(bus.get_order(r.order_ids[0]).destination == "courtyard", "and their orders still go to the courtyard")
	var ref3 := bus.propose_package("Third", items, "", "courtyard", "kestrel")
	check(ref3 != ref and ref3 != ref2, "refs aren't reused after a save: %s" % ref3)
	var again := bus.propose_package("Third, again", [items[0]], "", "courtyard", "kestrel")
	check(again == ref3 and bus.get_package(ref3).items.size() == 1 and bus.get_package(ref3).title == "Third, again",
			"committing the same frame again replaces its package and keeps the ref")
	check(bus.propose_package("Ordered one", items, "", "courtyard", "") != ref, "an ordered package is never replaced")

	wrist.queue_free()
	bus.reset()
	Flags.use(saved)
	Modules.load_all()


## The cheapest supplier with every item in stock, new first, or "".
static func _one_supplier(bus: BusinessBus, items: Array) -> String:
	var best := ""
	var best_cost := -1
	for s in bus.get_suppliers():
		var total := 0
		for item: Dictionary in items:
			var pick := -1
			var pick_new := false
			for l in bus.get_listings():
				if l.part != item.part or l.supplier_id != s.id or l.available < int(item.qty):
					continue
				var c := bus.listing_cost(l, int(item.qty))
				var is_new := l.condition == PartCondition.NEW
				if pick < 0 or (is_new and not pick_new) or (is_new == pick_new and c < pick):
					pick = c
					pick_new = is_new
			if pick < 0:
				total = -1
				break
			total += pick
		if total >= 0 and (best_cost < 0 or total < best_cost):
			best = s.id
			best_cost = total
	return best
