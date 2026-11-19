extends ModuleTest
## The TartanCo fleet screen and orders: rows from the yard's real worker bots (state, job,
## condition, charge, where), the orders' commands (groups, bots, tasks, priorities), the
## build plan as tasks under the joining rule, saving and the late joiner's snapshot, and the
## screen on the wall and the wrist.
##   tools/run_tests.sh fleet


func run_tests() -> void:
	for f: String in [YardBus.FLAG, YardBus.STATION, YardBus.DOCK, YardBus.RACKING, "fleet", FleetBus.SCREEN_FLAG]:
		Flags.set_flag(f, true)
	var bus := Modules.bus("fleet") as FleetBus
	check(bus != null, "the fleet module loads")
	if bus == null:
		return
	_orders()
	_plan()
	_rows_static()
	await _yard_rows(bus)
	await _screen(bus)
	_save(bus)


func _orders() -> void:
	var o := FleetOrders.new()
	check(o.apply({"op": "group_add", "name": "Hull crew"}), "a group is made")
	check(o.apply({"op": "group_add", "name": ""}), "a group with no name gets one")
	check(o.groups.size() == 2 and o.groups[1].name == "Group 2", "named in turn (%s)" % str(o.groups))
	check(not o.apply({"op": "bogus"}), "an unknown order is refused")
	check(o.apply({"op": "bot_assign", "serial": "TC-W3-01", "group": "g1"}), "a bot joins a group")
	check(o.apply({"op": "bot_assign", "serial": "TC-W3-01", "group": "g2"}), "and moves to another")
	check(o.group_of("TC-W3-01").id == "g2" and (o.group("g1").bots as Array).is_empty(), "a bot is in one group only")
	check(not o.apply({"op": "bot_assign", "serial": "TC-W3-01", "group": "g9"}), "not into a group that isn't there")
	check(o.apply({"op": "group_priority", "group": "g2", "priority": 9}) and int(o.group("g2").priority) == 5,
			"priority is held to 1..5")
	check(o.by_priority()[0].id == "g2", "the urgent group comes first")
	for n in 3:
		o.apply({"op": "task_add", "group": "g1", "task": {"name": "T%d" % n, "stage": "hull", "trade": "R"}})
	var tasks: Array = o.group("g1").tasks
	check(tasks.size() == 3 and tasks[0].id == "t1" and tasks[2].id == "t3", "tasks get counted ids")
	check(o.apply({"op": "task_move", "group": "g1", "task": "t3", "by": -2}) and o.group("g1").tasks[0].id == "t3",
			"a task moves up the list")
	check(not o.apply({"op": "task_move", "group": "g1", "task": "t3", "by": -1}), "not past the top")
	o.apply({"op": "task_priority", "group": "g1", "task": "t2", "priority": 5})
	check(FleetOrders.queue(o.group("g1"))[0].id == "t2", "an urgent task is taken first")
	check(o.apply({"op": "task_remove", "group": "g1", "task": "t1"}) and o.group("g1").tasks.size() == 2, "a task comes off")
	var copy := FleetOrders.new()
	copy.from_dict(JSON.parse_string(JSON.stringify(o.to_dict())))
	copy.apply({"op": "group_add", "name": "Third"})
	check(copy.groups[2].id == "g3", "ids carry on after a save (%s)" % copy.groups[2].id)
	check(o.apply({"op": "group_remove", "group": "g1"}) and o.groups.size() == 1, "a group is disbanded")


func _plan() -> void:
	var lines := [
		{"kind": "service", "id": "wire", "name": "Wiring", "qty": 40.0, "unit": "m", "hours": 2.0, "mass": 60.0},
		{"kind": "hull", "id": "welds", "name": "Welds", "qty": 120.0, "unit": "x", "hours": 1.0, "mass": 0.0},
		{"kind": "component", "id": "reactor", "name": "Fusion reactor", "qty": 1.0, "unit": "x", "hours": 9.0, "mass": 6000.0},
		{"kind": "hull", "id": "frame", "name": "Box girder", "qty": 80.0, "unit": "m", "hours": 8.0, "mass": 900.0},
		{"kind": "hull", "id": "hull", "name": "Hull plate", "qty": 90.0, "unit": "m2", "hours": 8.0, "mass": 900.0},
		{"kind": "service", "id": "fuel", "name": "Fuel pipe", "qty": 12.0, "unit": "m", "hours": 2.0, "mass": 50.0},
	]
	var t := FleetOrders.plan_tasks(lines)
	check(t.size() == 5, "every line but the joint counts is a task (%d)" % t.size())
	check(t[0].stage == "frame" and t[0].trade == "W", "the frame comes first, welded")
	check(t[1].stage == "hull" and t[1].trade == "R" and str(t[1].joins).contains("weld"),
			"hull plates riveted at the corners with a short weld")
	var by := {}
	for x in t:
		by[str(x.line)] = x
	check(by["service:wire"].trade == "R" and by["service:fuel"].trade == "B", "wires riveted, pipes bolted")
	check(str(by["component:reactor"].joins).contains("several"), "a heavy component gets several bolts")


func _rows_static() -> void:
	var r := FleetBus.row_for("Worker3", {"wear": 0.8, "charge": 0.15, "errors": ["E-17 ACTUATOR"], "model": "W-3",
			"serial": "TC-W3-01"}, Vector3(0, -5, -85), {"role": "W"})
	check(r.state == "faulted" and r.band == "poor", "a faulted, worn bot reads FAULT and poor")
	check(str(r.location).contains("B1"), "in the build berth (%s)" % r.location)
	var c := FleetBus.row_for("Worker2", {"wear": 0.1, "charging": true, "charge": 0.5}, Vector3.ZERO, {"role": "R"})
	check(c.state == "charging" and str(c.location) == "Charge dock C2, berth B1", "a charging bot is on its dock (%s)" % c.location)
	check(FleetBus.row_for("W", {"state": "working", "job": "Welding ring 4"}, Vector3.ZERO, {}).job == "Welding ring 4",
			"the yard's own job line is shown")


func _yard_rows(bus: FleetBus) -> void:
	var s := (load(YardBus.SCENE_PATH) as PackedScene).instantiate() as Node3D
	add_child(s)
	var sim: Node = s.get("sim")
	if sim:
		sim.set_process(false)
		sim.call("run_ticks", 600)
	await frames(2)
	var rows := bus.rows()
	check(rows.size() == 6, "a row for each of the crew's six bots (%d)" % rows.size())
	var serials := {}
	for r in rows:
		serials[r.serial] = true
		check(float(r.condition) > 0.0 and float(r.condition) <= 1.0 and float(r.charge) >= 0.0, "%s has condition and charge" % r.serial)
		check(str(r.location) != "", "%s has a place" % r.serial)
	check(serials.size() == 6, "every bot has its own serial (%s)" % str(serials.keys()))
	var sum := bus.summary(rows)
	check(int(sum.bots) == 6, "the header counts the fleet")
	s.queue_free()
	await frames(2)
	check(bus.rows().is_empty(), "no rows with the yard closed")


func _screen(bus: FleetBus) -> void:
	var fake := func() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		for i in 4:
			out.append(FleetBus.row_for("Worker%d" % (i + 1), {"wear": 0.2 * i, "charge": 1.0 - 0.2 * i,
					"serial": "TC-X-%02d" % i, "model": "W-3", "state": "working", "job": "Welding"}, Vector3(0, -5, -85), {"role": "W"}))
		return out
	bus.source = fake
	var screen := bus.make_screen(150.0)
	screen.size = Vector2(1400, 800)
	add_child(screen)
	await frames(2)
	check(screen.find_child("Bot_TC-X-00", true, false) != null, "a row per bot")
	check(screen.find_child("Tab_orders", true, false) != null, "the orders tab")
	screen.call("show_tab", "orders")
	(screen.find_child("NewGroup", true, false) as Button).pressed.emit()
	await frames(1)
	check(bus.orders.groups.size() == 1, "NEW GROUP makes a group")
	screen.call("select", "TC-X-01")
	var join := screen.find_child("Join_" + str(bus.orders.groups[0].id), true, false) as Button
	check(join != null, "a bot's detail offers its group")
	if join:
		join.pressed.emit()
	await frames(1)
	check(bus.orders.group_of("TC-X-01").size() > 0, "the bot joins it from the screen")
	var channel := HudSlots.holo_channel(FleetBus.HOLO_CHANNEL)
	check(not channel.is_empty(), "the fleet is a wrist channel")
	if not channel.is_empty():
		var w: Variant = (channel.factory as Callable).call(true)
		check(w is Control, "the wrist channel builds the screen on glass")
		if w is Control:
			(w as Control).free()
	var design := Modules.bus("design")
	if design and design.get("wall_views") is Dictionary:
		check((design.get("wall_views") as Dictionary).has(FleetBus.WALL_VIEW), "offered to the design room's walls")
	screen.queue_free()
	bus.source = Callable()


func _save(bus: FleetBus) -> void:
	var data := bus.save_data()
	var copy := FleetBus.new()
	copy.load_data(JSON.parse_string(JSON.stringify(data)), FleetBus.SAVE_VERSION)
	check(copy.orders.groups.size() == bus.orders.groups.size(), "orders survive a save")
	copy.apply_net_snapshot(bus.get_net_snapshot())
	check(JSON.stringify(copy.orders.to_dict()) == JSON.stringify(bus.orders.to_dict()), "a late joiner gets the same orders")
	copy.free()
