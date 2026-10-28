extends ModuleTest
## Playtest 0.3.27 (beenster): "i cant see the bolt and rivet highlights any more"
## (trades.clear_rings); "rotate cutter to be inline with arm: its at 90 degrees"
## (trades.cutter_inline); "volume of tools is too loud by default, reduce their sound"
## (trades.quiet_tools); "cutter should be quicker" (trades.quick_cutter); "scribe doesnt seem
## to be able to pick up the angled sections" (trades.scribe_faces).

const FLAGS := ["trades.clear_rings", "trades.cutter_inline", "trades.quiet_tools", "trades.quick_cutter",
		"trades.scribe_faces"]


func run_tests() -> void:
	var saved := {}
	for flag: String in FLAGS:
		saved[flag] = Flags.is_on(flag)

	# The ring clears a wreck's 3 cm heads.
	check(TradesShipJoints.CLEAR_RING_IN_M > 0.035, "the ring's inside (%.3f m) is wider than a wreck's bolt head" % TradesShipJoints.CLEAR_RING_IN_M)

	# The cutter along the arm, not across it.
	for on in [false, true]:
		Flags.set_flag("trades.cutter_inline", on)
		var c := TradesCutter.new()
		add_child(c)
		var body := (c.hold.basis * Vector3.BACK).normalized()
		var along := absf(body.dot(Vector3.BACK))
		if on:
			check(along > 0.99, "trades.cutter_inline: the cutter's body runs along the forearm (%.2f)" % along)
		else:
			check(along < 0.1, "without it the cutter is held across the hand, as before")
		c.free()

	# Quieter tools.
	Flags.set_flag("trades.quiet_tools", true)
	check(TradesBay.tool_db() == TradesBay.QUIET_TOOLS_DB and TradesBay.QUIET_TOOLS_DB <= -6.0, "tool sounds are %.0f dB quieter" % TradesBay.QUIET_TOOLS_DB)
	Flags.set_flag("trades.quiet_tools", false)
	check(TradesBay.tool_db() == 0.0, "and as before without the flag")

	# A quicker cutter; the welder keeps its time.
	Flags.set_flag("trades.quick_cutter", true)
	check(TradesShipJoints.grind_s() < TradesShipJoints.GRIND_S * 0.6 and TradesShipJoints.weld_cut_s() < TradesShipJoints.UNWELD_S * 0.6,
			"the cutter grinds a rivet in %.1f s and cuts a weld in %.1f s" % [TradesShipJoints.grind_s(), TradesShipJoints.weld_cut_s()])
	Flags.set_flag("trades.quick_cutter", false)
	check(TradesShipJoints.grind_s() == TradesShipJoints.GRIND_S and TradesShipJoints.weld_cut_s() == TradesShipJoints.UNWELD_S, "as before without the flag")

	# A tapering wreck plate (the Dagger's HullPlate_269): its mount faces straight out, its face
	# leans 24 degrees aft.
	var s := MountSlot.new()
	s.slot_id = "plate_hull_hull_HullPlate_269"
	s.parts = PackedStringArray(["hull/skin/HullPlate/269"])
	s.mount = Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.RIGHT), Vector3(3, 2, 0))
	s.box = AABB(Vector3(2.1, 1.4, -1.98), Vector3(1.81, 1.18, 3.95))
	var face := Vector3(0.912, 0.0, -0.41).normalized()
	Flags.set_flag("trades.scribe_faces", true)
	var plain := TradesPlateTracer.plate_of(s)
	var faced := TradesPlateTracer.plate_of(s, face)
	check(not faced.is_empty() and (faced.n as Vector3).dot(face) > 0.999, "the scribe takes the angled plate's plane from the face aimed at")
	check(not plain.is_empty() and (plain.n as Vector3).dot(Vector3.RIGHT) > 0.999, "with no face, its mount's facing as before")
	check(TradesPlateTracer.plate_of(s, Vector3.UP).get("n", Vector3.ZERO) == plain.n, "a face far off the plate's (the deck beside it) doesn't turn it")
	Flags.set_flag("trades.scribe_faces", false)
	check((TradesPlateTracer.plate_of(s, face).n as Vector3).dot(Vector3.RIGHT) > 0.999, "without the flag the face is not used")

	for flag: String in FLAGS:
		Flags.set_flag(flag, saved[flag])
