extends ModuleTest
## trades.beam_cutting (beenster, 0.3.27, stage B2 of the beam plan): the plasma bed cuts stock
## beam bars to length. A bar reads off its StockBeams id; lengths are laid along it with a kerf
## between, square or mitred at each end; on the console the next length is nudged, its ends
## stepped, added and taken off the list; START runs the torch across the bar at each cut, clear
## of it between; the pieces ("<bar>:len:<mm>") and what is left lie loose for the tractor, each
## weighing its length of the bar; a list too long for the bar is refused; a bar let go of over
## the bed settles onto it, and so does a square piece of one.

const FAKE_YARD := """extends Node3D
var walker: CharacterBody3D
var walker_active := true
func set_walker_active(on: bool) -> void:
	walker_active = on
"""
const BAR := "SteelBox_100x100x5_6000"


func physics(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var bus := Modules.bus("trades") as TradesBus
	var saved := {}
	for flag: String in ["trades.tractor", "trades.cutting_bed", "trades.beam_cutting"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	bus.reset_data()

	# Reading bars and their pieces.
	var info := TradesBeamCuts.bar_info(BAR)
	check(TradesBeamCuts.is_beam(info) and (info.size as Vector2).is_equal_approx(Vector2(6.0, 0.1)) and is_equal_approx(float(info.wall), 0.005),
			"a 6 m box bar reads as a beam: %s" % [info.get("size")])
	check(TradesCuttingBed.load_info(BAR).get("kind", "") == "beam" and TradesCuttingBed.load_info("SteelPlate_2500x1250_5").get("kind", "") != "beam",
			"the bed takes bars and plates")
	var piece := TradesBeamCuts.bar_info(TradesBeamCuts.piece_name(BAR, 2500))
	check(not piece.is_empty() and is_equal_approx((piece.size as Vector2).x, 2.5), "a square 2500 mm piece reads as a shorter bar")
	check(TradesBeamCuts.bar_info(TradesBeamCuts.piece_name(BAR, 2500, 45.0, 0.0)).is_empty(), "a mitred piece doesn't go back on the bed")
	check(TradesBeamCuts.bar_info("SteelPlate_2500x1250_5").is_empty(), "a plate isn't a bar")
	check(TradesBeamCuts.piece_name(BAR, 1200, 45.0, 30.0) == BAR + ":len:1200:45:30", "a mitred piece's name carries its ends")

	# Laying lengths along it.
	var lay := TradesBeamCuts.layout(info, [{"mm": 2000, "a": 0, "b": 0}, {"mm": 1500, "a": 0, "b": 0}])
	check((lay.pieces as Array).size() == 2 and (lay.cuts as Array).size() == 2, "two square pieces from the end take two cuts")
	check(absf(float(lay.left_m) - (6.0 - 3.5 - 2.0 * TradesBeamCuts.KERF_M)) < 0.0001, "what is left: %.4f m" % float(lay.left_m))
	var mitre := TradesBeamCuts.layout(info, [{"mm": 1000, "a": 45, "b": 45}])
	check((mitre.cuts as Array).size() == 2, "a piece mitred both ends takes two cuts")
	var c0: Array = mitre.cuts[0]
	check(absf(((c0[1] as Vector2) - (c0[0] as Vector2)).angle() - PI * 0.25) < 0.01, "a 45° end cuts across at 45°")
	check(TradesBeamCuts.layout(info, [{"mm": 4000}, {"mm": 2500}]).is_empty(), "more than the bar is refused")
	check(TradesBeamCuts.layout(info, [{"mm": 100, "a": 60, "b": 60}]).is_empty(), "a piece shorter than its mitres is refused")
	var m := TradesBeamCuts.mesh(info, 2.0, 45.0, 0.0)
	check(m.get_aabb().size.x > 1.99 and m.get_aabb().size.x < 2.01 and is_equal_approx(m.get_aabb().size.y, 0.1), "a piece builds to its length")
	var kg := TradesBeamCuts.piece_kg(info, 3.0, 0.0, 0.0)
	check(absf(kg - float(StockBeams.item(BAR).mass) * 0.5) < 0.2, "half the bar weighs half as much: %.1f kg" % kg)

	# The yard, with the bed.
	ship_bus.load_ship("vs_kestrel")
	var yard := _fake_yard()
	var walker := CharacterBody3D.new()
	walker.position = Vector3(3, 0, 12)
	yard.set("walker", walker)
	yard.add_child(walker)
	add_child(yard)
	bus._on_shipyard_ready(yard)
	await frames(2)
	var rig: TradesBay = yard.get_node(TradesBus.YARD_RIG)
	if rig.cutting_bed == null:
		rig.build_cutting_bed(Transform3D(Basis(), Vector3(-20, 0, 0)))
	var bed := rig.cutting_bed
	var beam := rig.ship_station().tractor
	bed.set_plate(info)
	check(bed.is_beam() and bed.get_node_or_null("Bar") is MeshInstance3D, "a bar lies on the bed")
	check(bed.refusal("L-DISC-600") != "", "templates aren't cut from a bar")

	# The console: nudge the next length, step its ends, add it.
	var panel := bed.panel as TradesCutterPanel
	panel.refresh()
	var list := panel.find_child("AddLength", true, false) as Button
	check(list != null and panel.find_child("EndA", true, false) is Button, "the console shows the lengths screen")
	check(bed.length_refusal() == "Add a length" and panel._cut.disabled, "nothing to cut yet")
	(panel.find_child("Step_p1000", true, false) as Button).pressed.emit()
	(panel.find_child("Step_p100", true, false) as Button).pressed.emit()
	check(panel.entry_mm == 2100, "the steps nudge the length: %d mm" % panel.entry_mm)
	(panel.find_child("AddLength", true, false) as Button).pressed.emit()
	(panel.find_child("EndB", true, false) as Button).pressed.emit()
	check(panel.entry_b == 45.0, "END B steps to 45°")
	(panel.find_child("AddLength", true, false) as Button).pressed.emit()
	check(bed.lengths.size() == 2 and int(bed.lengths[1].mm) == 2100 and float(bed.lengths[1].b) == 45.0, "two lengths on the list")
	(panel.find_child("Length_0", true, false) as Button).pressed.emit()
	check(bed.lengths.size() == 1, "clicking one takes it off")
	panel.entry_mm = 5000
	check(bed.add_length(5000) != "" and bed.lengths.size() == 1, "a length past the bar's end isn't added")
	bed.clear_lengths()
	bed.add_length(2000)
	bed.add_length(1500, 0.0, 45.0)
	panel.refresh()
	check(panel._info.text.contains("USED") and not panel._cut.disabled, "it says how much is used and START is ready: %s" % panel._info.text)

	# Bad lists from the crew are refused.
	check(bed._validate_cut(2, {"lengths": [{"mm": 9000}]}) is String, "a list too long for the bar is refused")
	var clean: Variant = bed._validate_cut(2, {"lengths": [{"mm": 500, "a": 12.0, "b": 45.0}]})
	check(clean is Dictionary and float(clean.lengths[0].a) == 0.0 and float(clean.lengths[0].b) == 45.0, "an end the console doesn't offer is squared")

	# START: the torch runs across the bar at each cut.
	check(bed.cut_lengths() == "", "START cuts the list")
	var cuts := 0
	var highest := 0.0
	var lowest := 1.0
	var was_cutting := false
	for i in 4000:
		if bed.job.is_empty():
			break
		bed._process(0.05)
		if bed.job.is_empty():
			break
		var step: Dictionary = bed.job.program[mini(int(bed.job.step), bed.job.program.size() - 1)]
		var cutting := str(step.kind) == "cut"
		if cutting and not was_cutting:
			cuts += 1
		was_cutting = cutting
		highest = maxf(highest, bed.torch_h)
		if cutting:
			lowest = minf(lowest, bed.torch_h)
	check(cuts == 2, "two cuts across the bar: %d" % cuts)
	check(highest > 0.1 + TradesCuttingBed.LIFT_M - 0.001 and lowest > 0.1, "the torch cuts on the bar's top and lifts clear of it: %.3f..%.3f" % [lowest, highest])
	check(bed.job.is_empty() and bed.plate.is_empty() and bed.head.is_equal_approx(TradesCuttingBed.PARK), "the run finishes and parks")
	check(is_equal_approx(bed.torch_h, TradesCuttingBed.LIFT_M), "the torch comes back down to rest")
	check(bed.made.size() == 3 and Array(bed.made).all(func(id: String) -> bool: return beam.loose.has(id)), "two pieces and what is left lie loose: %s" % [bed.made])
	if bed.made.size() == 3:
		var a: TradesLoosePart = beam.loose[bed.made[0]]
		var b: TradesLoosePart = beam.loose[bed.made[1]]
		var left: TradesLoosePart = beam.loose[bed.made[2]]
		check(a.component == BAR + ":len:2000" and b.component == BAR + ":len:1500:0:45", "named by bar and length: %s, %s" % [a.component, b.component])
		check(left.component.begins_with(BAR + ":len:24") and left.component.ends_with(":-45:0"), "what is left: %s" % left.component)
		var bar_kg := float(StockBeams.item(BAR).mass)
		check(absf(a.mass - bar_kg / 3.0) < 0.2 and absf(a.mass + b.mass + left.mass - bar_kg) < 0.5, "each weighs its length: %.1f, %.1f, %.1f kg" % [a.mass, b.mass, left.mass])
		var at := bed.global_transform.affine_inverse() * a.global_position
		check(absf(at.x - (-3.0 + 1.0)) < 0.01, "the first piece lies where it was cut: x %.3f" % at.x)
		check(bed.lengths.is_empty(), "the list is cleared")

		# A square piece let go of over the bed settles onto it again.
		beam.take_away(bed.made[1])
		beam.take_away(bed.made[2])
		await physics(2)
		check(bed.plate.is_empty() and beam.loose.has(bed.made[0]), "a fresh piece isn't taken straight back onto the bed")
		a.held = true
		await physics(1)
		a.held = false
		a.global_position = bed.global_transform * Vector3(0, 1.1, 0)
		a.freeze = true
		a.linear_velocity = Vector3.ZERO
		await physics(2)
		check(bed.plate.get("id", "") == BAR + ":len:2000" and is_equal_approx((bed.plate.size as Vector2).x, 2.0), "a 2 m piece settles back on the bed")
		check(TradesBeamCuts.layout(bed.plate, [{"mm": 1000}]).size() > 0, "and can be cut again")

	# With the flag off, bars aren't taken.
	Flags.set_flag("trades.beam_cutting", false)
	check(TradesCuttingBed.load_info(BAR).is_empty(), "flag off: bars aren't taken")
	Flags.set_flag("trades.beam_cutting", true)

	bed.set_plate({})
	bus.reset_data()
	yard.queue_free()
	await frames(2)
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])


func _fake_yard() -> Node3D:
	var script := GDScript.new()
	script.source_code = FAKE_YARD
	script.reload()
	var n := Node3D.new()
	n.set_script(script)
	return n
