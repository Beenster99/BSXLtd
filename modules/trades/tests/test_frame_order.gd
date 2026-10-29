extends ModuleTest
## trades.frame_order (beenster, 0.3.31: "Once I am happy with my new frame, what do i do to
## commit it and get the parts ordered as a package"): the Frame Builder works out the stock
## bars the frame's beams are cut from, O offers the order and O again commits the frame and
## buys the bars in one order from the shop. Committed again, it buys only what is new.


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var shop := Modules.bus("business") as BusinessBus
	check(shop != null, "the shop is there")
	if shop == null:
		return
	var saved := {}
	for flag: String in ["trades.beam_designer", "trades.beam_grow", "trades.frame_order", "trades.one_section"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)

	# The cut plan: beams packed into 6 m bars, a long one into a 12 m bar, a very long one spliced.
	var bar6 := TradesFrameOrder.bar_for("box_100x100x5", 6000)
	var bar12 := TradesFrameOrder.bar_for("box_100x100x5", 12000)
	check(bar6 == "SteelBox_100x100x5_6000" and bar12 == "SteelBox_100x100x5_12000", "the stock bars: %s, %s" % [bar6, bar12])
	var rows := [_row(1, 2.5), _row(2, 2.5), _row(3, 2.5), _row(4, 7.0), _row(5, 14.0)]
	var plan := TradesFrameOrder.cut_plan(rows)
	var cut := 0
	for b: Dictionary in plan.bars:
		check(not TradesBeamCuts.layout(TradesBeamCuts.bar_info(str(b.bar)), b.lengths).is_empty(), "each bar's cut list fits the bar: %s" % [b])
		cut += (b.lengths as Array).size()
	check(cut == 6 and int(plan.pieces) == 6 and int(plan.spliced) == 1, "every beam cut, the 14 m one in two to splice: %s" % [plan])
	# 7 m and the 14 m one's two 7 m halves take a 12 m bar each; the 2.5 m beams go in what's left of them.
	check(plan.counts == {bar12: 3}, "three 12 m bars and no more: %s" % [plan.counts])
	check(TradesFrameOrder.still_to_buy(plan.counts, {bar6: 2, bar12: 1}) == {bar12: 2}, "only what isn't ordered yet")

	# In the yard with the Frame Builder.
	bus.reset_data()
	shop.reset()
	var yard: Node3D = load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)).instantiate()
	add_child(yard)
	await frames(30)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	if rig.designer == null:
		rig.build_designer()
	var d := rig.designer
	rig.set_tool(&"tablet")
	await physics_frames(3)
	var ship := d.ship_id()
	check(d.key(TradesBus.KEY_ORDER) and d.order_offer.is_empty(), "with no beams O says there's nothing to commit")
	bus.set_beam_design(ship, [_row(1, 2.5), _row(2, 2.0), _row(3, 1.0)])
	check(d.info_lines()[-2].contains("O commits the frame") or "\n".join(d.info_lines()).contains("O commits the frame"),
			"the panel says how to commit: %s" % "\n".join(d.info_lines()))

	# O shows the order: one 6 m bar takes 2.5 + 2.0 + 1.0.
	var cash := shop.get_cash()
	var orders := shop.get_orders().size()
	check(d.key(TradesBus.KEY_ORDER) and not d.order_offer.is_empty(), "O offers the order")
	var b: Dictionary = d.order_offer.basket
	check(bool(b.ok) and int(b.cost) > 0 and (b.basket as Array).size() == 1 and int((b.basket as Array)[0].qty) == 1,
			"one bar from the shop, priced: %s" % [b])
	check(d.order_line().contains("3 beams cut from 1 x 6 m bar") and d.order_line().contains("O again"), "the line says what and how: %s" % d.order_line())
	check(shop.get_orders().size() == orders and shop.get_cash() == cash, "nothing bought yet")
	# Right click cancels it.
	d.hovered = -1
	d.root_on = ""
	d.click(false)
	check(d.order_offer.is_empty(), "right click cancels the offer")
	# O, O: committed and ordered as one order.
	d.key(TradesBus.KEY_ORDER)
	d.key(TradesBus.KEY_ORDER)
	await frames(2)
	check(shop.get_orders().size() == orders + 1, "one order placed: %d" % (shop.get_orders().size() - orders))
	check(shop.get_cash() == cash - int(b.cost), "paid for: %d CR" % (cash - shop.get_cash()))
	var c := bus.committed_frame(ship)
	check(not c.is_empty() and (c.rows as Array).size() == 3 and int(c.ordered.get(bar6, 0)) == 1 and int(c.cost) == int(b.cost),
			"the frame is committed with what was ordered: %s" % [c])
	check(d.is_committed() and "\n".join(d.info_lines()).contains("Committed  version A, 3 beams, 1 bar ordered"), "the panel says so")
	var o: PartsOrder = shop.get_orders()[-1]
	check(o.lines.size() == 1 and (o.lines[0] as OrderLine).part == bar6 and (o.lines[0] as OrderLine).qty == 1, "the order is the bar")
	# Committed again unchanged: nothing more to buy.
	d.key(TradesBus.KEY_ORDER)
	check((d.order_offer.need as Dictionary).is_empty() and d.order_line().contains("All on order"), "unchanged, nothing new to order")
	d.key(TradesBus.KEY_ORDER)
	check(shop.get_orders().size() == orders + 1, "and nothing ordered")
	# A beam added: changed since, and only the new bar is bought.
	bus.set_beam_design(ship, bus.beam_design(ship) + [_row(9, 4.0)])
	check(not d.is_committed() and "\n".join(d.info_lines()).contains("changed since"), "the panel says it changed since")
	d.key(TradesBus.KEY_ORDER)
	check(d.order_offer.need == {bar6: 1}, "only one more bar: %s" % [d.order_offer.need])
	d.key(TradesBus.KEY_ORDER)
	await frames(2)
	check(shop.get_orders().size() == orders + 2 and int(bus.committed_frame(ship).ordered.get(bar6, 0)) == 2, "bought, and counted")
	# The cutting bed takes the committed frame's cut lists bar by bar.
	if rig.cutting_bed == null:
		rig.build_cutting_bed(Transform3D(Basis(), Vector3(-20, 0, 0)))
	var bed := rig.cutting_bed
	var cuts: Array = bus.committed_frame(ship).cuts
	check(cuts.size() == 2, "two bars to cut: %s" % [cuts])
	var saw_beam := Flags.is_on("trades.beam_cutting")
	Flags.set_flag("trades.beam_cutting", true)
	bed.clear_lengths()
	bed.set_plate(TradesBeamCuts.bar_info(bar6))
	var got: Array = bed.lengths.map(func(e: Dictionary) -> int: return int(e.mm))
	check(str(got) == str(cuts[0].mm) and bed.frame_note.contains("BAR 1 OF 2"), "a bar on the bed takes the first bar's cut list: %s, %s" % [got, bed.frame_note])
	bed.panel.call("refresh")
	check(bed.panel.find_child("FrameNote", true, false) != null, "the console says where the list came from")
	check(bed.cut_lengths() == "", "START cuts it")
	for i in 4000:
		if bed.job.is_empty():
			break
		bed._process(0.05)
	check(bus.committed_frame(ship).done == [0], "that bar is cut: %s" % [bus.committed_frame(ship).done])
	bed.set_plate(TradesBeamCuts.bar_info(bar6))
	check(str(bed.lengths.map(func(e: Dictionary) -> int: return int(e.mm))) == str(cuts[1].mm) and bed.frame_note.contains("BAR 2 OF 2"),
			"the next bar takes the second: %s" % bed.frame_note)
	bed.set_plate({})
	bed.clear_lengths()
	check(TradesBeamDesigner.done_cuts(bus.committed_frame(ship), cuts) == [0], "a commit again keeps the cut bar cut")
	Flags.set_flag("trades.beam_cutting", saw_beam)
	# Saved and loaded with the ship's design.
	var data := bus.save_data()
	bus.reset_data()
	bus.load_data(data, TradesBus.SAVE_VERSION)
	check(int(bus.committed_frame(ship).ordered.get(bar6, 0)) == 2, "the commit is saved with the design")
	# Flag off: O does nothing.
	Flags.set_flag("trades.frame_order", false)
	check(not d.key(TradesBus.KEY_ORDER), "with the flag off O does nothing")

	bus.reset_data()
	shop.reset()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


## A beam along x, `l` metres long, standing clear of the others.
func _row(id: int, l: float) -> Dictionary:
	return {"id": id, "a": [0.0, 3.0 + id, 0.0], "b": [l, 3.0 + id, 0.0], "section": "box_100x100x5", "turn": 0.0}


func physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
