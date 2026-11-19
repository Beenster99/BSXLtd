extends ModuleTest
## Warehouse stock: the report adds the racks up right (every unit, place and pending load
## counted once, per part, kind, storey and bay), the open design's needs come through as
## short lines, the wrist channel and the screen are there, and the screen answers clicks:
## filters, sorting, picking a line and a bay on the map.
##   tools/run_tests.sh stores

const StockScreen := preload("res://modules/stores/internal/stock_screen.gd")


func run_tests() -> void:
	var bus := Modules.bus("stores") as StoresBus
	check(bus != null, "the stores module is loaded")
	if bus == null:
		return
	check(not HudSlots.holo_channel(StoresBus.HOLO_CHANNEL).is_empty(), "warehouse stock is a wrist channel")
	check(bus.is_preview(), "with no station open it previews the starting stock")

	# The report against a store we fill ourselves.
	var store := YardRackStore.new()
	store.fill_demo(0.5, 11)
	var r := StoresReport.build(store)
	var units := 0
	var filled := 0
	for s in store.slots:
		if s.part != "":
			units += int(s.qty)
			filled += 1
	check(r.total_qty == units, "every unit counted once: %d / %d" % [r.total_qty, units])
	check(r.filled_places == filled and r.total_places == store.slots.size(), "places add up: %d of %d" % [r.filled_places, r.total_places])
	check(r.lines.size() == YardRackStore.PARTS.size(), "a line for every part the stores keep, held or not")
	var k_units := 0
	var k_places := 0
	for k in r.kinds:
		k_units += int(k.qty)
		k_places += int(k.places)
	check(k_units == units and k_places == r.total_places, "the rack kinds add up to the whole")
	check(int(r.storeys[0].places) + int(r.storeys[1].places) == r.total_places and int(r.storeys[1].places) > 0,
			"both storeys are counted")
	var bay_filled := 0
	for rack in r.racks:
		for b: Dictionary in rack.bays:
			bay_filled += int(b.filled)
	check(bay_filled == filled, "the map's bays hold every used place")
	var some := ""
	for l in r.lines:
		if int(l.qty) > 0:
			some = str(l.id)
			check(int(l.qty) == store.count(some), "%s: the line's count matches the racks" % some)
			check(int(l.places) == (l.slots as Array).size(), "%s: its places are listed" % some)
			break
	check(some != "", "something is in stock")
	check(StoresReport.place_name(store, 0).begins_with(str(YardRackStore.RACKS[0].id)), "a place has a name: %s" % StoresReport.place_name(store, 0))

	# On the way in.
	var before := r.line("FuelTank").get("inbound", 0) as int
	store.reserve("FuelTank", 1)
	r = StoresReport.build(store)
	check(int(r.line("FuelTank").inbound) == before + 1 and r.inbound_qty >= 1, "a promised load shows as inbound")

	# The open design's needs.
	var design := Modules.bus("design") as DesignBus
	if design:
		design.open_sample()
		r = StoresReport.build(store, design.catalog, design.totals(), design.library.current.name)
		check(r.design_name != "", "the open design is named")
		check(r.design_lines > 0, "the sample needs parts the stores keep: %d lines" % r.design_lines)
		var priced := r.lines.filter(func(l: Dictionary) -> bool: return float(l.unit_cost) > 0.0)
		check(not priced.is_empty() and r.total_value > 0.0, "catalogue costs give the stock a value: CR %d" % int(r.total_value))
		var empty := YardRackStore.new()
		var r2 := StoresReport.build(empty, design.catalog, design.totals(), "x")
		check(r2.lines_short == r2.design_lines and r2.total_qty == 0, "with empty racks every line the design needs is short")

	# The screen.
	var screen := bus.make_screen(150.0)
	screen.size = Vector2(1600, 900)
	add_child(screen)
	await frames(3)
	var lines := screen.find_child("Lines", true, false) as VBoxContainer
	check(lines != null and lines.get_child_count() == YardRackStore.PARTS.size(), "the table lists every part: %d" % (lines.get_child_count() if lines else -1))
	screen.call("set_filter", "HEAVY")
	await frames(1)
	var heavy := YardRackStore.parts_of_kind(YardRackStore.HEAVY).size()
	check(lines.get_child_count() == heavy, "HEAVY shows only the heavy parts: %d" % lines.get_child_count())
	screen.call("set_filter", "ALL")
	screen.call("sort_by", "qty")
	var shown: Array = screen.call("shown_lines", bus.report())
	check(int(shown[0].qty) >= int(shown[shown.size() - 1].qty), "sorted by count, most first")
	screen.call("sort_by", "qty")
	shown = screen.call("shown_lines", bus.report())
	check(int(shown[0].qty) <= int(shown[shown.size() - 1].qty), "a second click turns it round")
	var held := ""
	for l in bus.report().lines:
		if int(l.qty) > 0:
			held = str(l.id)
			break
	screen.call("select", held)
	await frames(1)
	var detail := screen.find_child("Detail", true, false) as VBoxContainer
	check(detail.get_child_count() > 4, "the chosen part lists its places")
	var line := bus.report().line(held)
	var slot: int = (line.slots as Array)[0]
	var rack := int(bus.store().slots[slot].rack)
	var b := int(bus.store().slots[slot].bay)
	screen.call("pick_bay", rack, b)
	check(screen.get("bay") == [rack, b] and str(screen.get("selected")) != "", "a bay picked on the map shows what is in it")
	var map := screen.find_child("RackMap", true, false) as Control
	await frames(2)
	check(map.call("cell_rect", rack, b).size.x > 0.0, "the map draws every bay")
	screen.queue_free()
	var factory: Callable = HudSlots.holo_channel(StoresBus.HOLO_CHANNEL).factory
	var wrist: Control = factory.call(true)
	check(wrist.name == "WarehouseStock", "the wrist channel is the same screen")
	wrist.free()
