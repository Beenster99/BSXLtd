extends ModuleTest
## Wave 4: contract variety, checked against real builds. DesignReference puts together the
## plainest ship that meets an order, priced by DesignTotals from the real catalogue; the
## contracts' budget estimate (ShipOrders.estimate) must stay close to it, or the board's
## "Generous" and "Unrealistic" labels would lie. DesignContractCheck scores an order's clauses.
##   tools/run_tests.sh design

var cat := DesignCatalog.load_default()
const Samples := preload("res://modules/design/internal/sample_designs.gd")


func run_tests() -> void:
	_reference()
	_calibration()
	_clauses()
	_tutorial()
	_board_buildable()


func _reference() -> void:
	var r := DesignReference.build({"crew": 4, "attack": 60, "defence": 150, "speed": 150, "jump_ly": 8}, [], cat)
	check(r.met, "the reference build meets a gunship's demands: misses %s" % [r.misses])
	check(float(r.cost) > 150000.0 and float(r.cost) < 1500000.0, "at a believable price: CR %d" % int(r.cost))
	var quiet := DesignReference.build({"crew": 4, "attack": 60, "defence": 150, "speed": 150, "jump_ly": 8, "stealth": 60}, [], cat)
	check(quiet.met and float(quiet.cost) > float(r.cost), "a quiet one costs more: CR %d" % int(quiet.cost))
	var far := DesignReference.build({"crew": 4, "attack": 60, "defence": 150, "speed": 150, "jump_ly": 8, "endurance_days": 90, "reactors": 0}, [], cat)
	check(far.met, "the reference build carries the tanks for 90 days without a reactor: misses %s" % [far.misses])
	check((far.totals as DesignTotals).reactors == 0 and (far.totals as DesignTotals).endurance_days() >= 90.0,
			"no reactor, %.0f days" % (far.totals as DesignTotals).endurance_days())


## The estimate against the reference build for one order of every kind of ship, small and
## medium sizes (the big ones take seconds to build; the fit was made across all sizes).
func _calibration() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var errors: Array = []
	var worst := ""
	var worst_err := 0.0
	var unmet := 0
	for role: String in ShipOrders.roles_for(true):
		var sizes: Array = ShipOrders.ROLES[role].sizes
		var size: String = sizes[0]
		if size in ["capital", "mega"]:
			continue
		var client: String = ShipClients.in_sector(str(ShipOrders.ROLES[role].sector))[0]
		var o := ShipOrders.make(client, role, size, rng, "cal", true)
		var dem: Dictionary = o.demands.duplicate()
		dem.erase("budget")
		var r := DesignReference.build(dem, o.clauses, cat)
		if not r.met:
			unmet += 1
			continue
		var err := float(o.estimate) / float(r.cost) - 1.0
		errors.append(absf(err))
		if absf(err) > worst_err:
			worst_err = absf(err)
			worst = "%s %s: estimate CR %d, build CR %d" % [size, role, int(o.estimate), int(r.cost)]
		var rows := DesignContractCheck.clauses(o, r.record, cat)
		check(rows.all(func(x): return x.ok), "the reference %s meets its own clauses: %s" % [role, rows.filter(func(x): return not x.ok).map(func(x): return x.label)])
	errors.sort()
	var median: float = errors[errors.size() / 2]
	print("contract variety: estimate vs reference build over %d orders, median %.0f%%, worst %.0f%% (%s)" % [errors.size(), median * 100.0, worst_err * 100.0, worst])
	check(unmet <= 2, "the reference build meets nearly every order: %d missed" % unmet)
	check(median < 0.15, "the budget estimate is within 15%% of a real build, typically: %.0f%%" % [median * 100.0])
	check(worst_err < 0.4, "and never more than 40%% out: %s" % worst)


func _clauses() -> void:
	var d := DesignRecord.new("cl", "Clauses")
	for op in [
		{"op": "add_room", "room": {"id": "b", "type": "bridge", "x": 0, "z": 0, "w": 5, "d": 4}},
		{"op": "add_room", "room": {"id": "m", "type": "medbay", "x": 0, "z": 4, "w": 4, "d": 4}},
		{"op": "add_room", "room": {"id": "e", "type": "engineering", "x": 0, "z": 8, "w": 6, "d": 6}},
		{"op": "add_component", "component": {"id": "c1", "type": "reactor_small:3R", "room": "e", "x": 2, "z": 10}},
		{"op": "add_mount", "mount": {"id": "t1", "type": "turret:2H", "deck": 0, "x": 0, "z": 2, "angle": PI}},
		{"op": "add_mount", "mount": {"id": "t2", "type": "turret", "deck": 0, "x": 5, "z": 2, "angle": 0.0}},
		{"op": "add_mount", "mount": {"id": "l1", "type": "landing_gear", "deck": 0, "x": 0, "z": 6, "angle": PI}},
	]:
		d.apply(op)
	var o := {"clauses": [ShipOrders.clause("medbay"), ShipOrders.clause("rough_landing"), ShipOrders.clause("no_reclaimed"),
			ShipOrders.clause("hardened_weapons"), ShipOrders.clause("gravity")]}
	var rows := DesignContractCheck.clauses(o, d, cat)
	var by := {}
	for r in rows:
		by[r.key] = r
	check(by["clause:medbay"].ok and by["clause:medbay"].have == 16.0, "a 16 m2 medbay meets the medbay clause")
	check(not by["clause:rough_landing"].ok and by["clause:rough_landing"].have == 1.0 and is_equal_approx(by["clause:rough_landing"].share, 0.25),
			"one landing leg of four is a quarter of the way")
	check(not by["clause:no_reclaimed"].ok, "a Reclaimed reactor breaks 'nothing Reclaimed'")
	check(not by["clause:hardened_weapons"].ok and is_equal_approx(by["clause:hardened_weapons"].share, 0.5), "one of two turrets Hardened is half")
	check(not by["clause:gravity"].ok, "no gravity generator, no gravity")
	d.apply({"op": "set_component", "id": "c1", "fields": {"type": "reactor_small"}})
	d.apply({"op": "set_mount", "id": "t2", "fields": {"type": "turret:2P"}})
	rows = DesignContractCheck.clauses(o, d, cat)
	check(rows[2].ok and rows[3].ok, "a Standard reactor and a Precision turret put both right")
	var t := DesignTotals.compute(d, cat)
	var all := DesignContractCheck.all({"demands": {"crew": 2, "attack": 10}, "clauses": o.clauses}, d, cat, t)
	check(all.size() == 7, "demands and clauses score together: %d rows" % all.size())


## The starter orders are easy: generous, open to a new yard, and the sample skiff meets
## every criterion as it stands, so the whole contract round can be learned on it.
func _tutorial() -> void:
	var rec := DesignRecord.new("tut", "Sample skiff")
	Samples.skiff(rec, cat)
	var t := DesignTotals.compute(rec, cat)
	var orders := ShipOrders.tutorial_orders()
	check(orders.size() == 2, "two starter orders")
	for o: Dictionary in orders:
		rec.order = o
		var t2 := DesignTotals.compute(rec, cat)
		var rows := DesignContractCheck.all(o, rec, cat, t2)
		check(rows.all(func(r: Dictionary) -> bool: return r.ok), "the sample skiff meets %s: %s" % [o.title,
				rows.filter(func(r: Dictionary) -> bool: return not r.ok).map(func(r: Dictionary) -> String: return "%s %s/%s" % [r.label, r.have, r.need])])
		check(str(o.achievability.label) == "Generous" and int(o.needs_level) == 0 and int(o.berth) == 1, "and it is generous, open from the start, starter berth")
		var q := ShipOrders.quote(o, t.cost)
		check(int(q.margin) > 0, "the sample skiff makes a profit on it: CR %d" % int(q.margin))


## Every order on a sample of boards can be built: the reference build meets every demand
## and clause of each small, medium and large order on four cycles (the big sizes take
## seconds each; a sweep of 40 cycles, every size, met all 240 on 20 Nov 2026).
func _board_buildable() -> void:
	var missed: Array = []
	var n := 0
	for cycle in [0, 7, 20, 29]:
		for o: Dictionary in ShipOrders.for_cycle(cycle):
			if not str(o.size) in ["small", "medium", "large"]:
				continue
			n += 1
			var dem: Dictionary = o.demands.duplicate()
			dem.erase("budget")
			var r := DesignReference.build(dem, o.clauses, cat)
			var rows := DesignContractCheck.clauses(o, r.record, cat).filter(func(x): return not x.ok)
			if not r.met or not rows.is_empty():
				missed.append("%s %s %s: %s %s" % [o.id, o.size, o.role, r.misses, rows.map(func(x): return x.label)])
	check(n >= 10 and missed.is_empty(), "the cheapest build meets every order on the board (%d tried): %s" % [n, missed])
