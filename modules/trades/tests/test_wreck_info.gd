extends ModuleTest
## Playtest 0.3.27 (beenster): "i should be able to see all the information about any object
## on the wreck when i look at it" (trades.wreck_info). The right-hand panel's sheet takes what Ship and Bay knows
## of the part under the aim (ShipBayBus.inspect_at): a hull plate with no slot gets a sheet of
## its own, a part in a slot gets its condition, value, faults, power and fluid added.


func run_tests() -> void:
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	var was := Flags.is_on("trades.wreck_info")
	Flags.set_flag("trades.wreck_info", true)

	# The sheet from an answer, on its own.
	var info := {"slot_id": "", "display_name": "Hull plate", "kind": "hull", "material": "steel", "mass_kg": 84.0,
			"condition": 0.62, "wear": 0.3, "scorch": 0.0, "value_new": 1200.0, "value_now": 744.0, "removal": "attached",
			"faults": ["cracked"], "power": "none", "fluid": "", "hazard": false, "joints": {"rivet": [10, 12]}}
	var sheet := "\n".join(TradesShipJoints.info_lines(info, true))
	for want in ["HULL PLATE", "84 kg", "steel", "62% (worn 30%)", "744 cr now, 1,200 cr new", "cracked", "12 rivets, 10 in"]:
		check(sheet.contains(want), "a part with no slot: its sheet says %s" % want)
	check(not sheet.contains("POWER") and not sheet.contains("FLUID") and not sheet.contains("REMOVED"), "and leaves out what doesn't apply")
	check(not "\n".join(TradesShipJoints.info_lines({"value_new": 0.0, "value_now": 0.0, "kind": "frame"}, false)).contains("VALUE"), "no value line when it's worth nothing")
	info.merge({"power": "source", "power_level": 0.4, "fluid": "fuel", "litres": 120.0, "capacity_l": 400.0, "hazard": true}, true)
	sheet = "\n".join(TradesShipJoints.info_lines(info, false))
	check(sheet.contains("source at 40%") and sheet.contains("fuel, 120 of 400 L") and sheet.contains("HAZARD"), "power, fluid and hazard when it has them")
	check(not sheet.contains("HULL PLATE") and not sheet.contains("JOINTS"), "a slot's sheet adds only what it doesn't say already")

	# In the yard, on a wreck.
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null, "the tools are in the yard")
	if rig == null:
		Flags.set_flag("trades.wreck_info", was)
		return
	ship_bus.wreck_seed = 9
	ship_bus.debug_ship("random_wreck", "S")
	await frames(3)
	var station := rig.ship_station()
	rig.set_tool(&"hands")
	var body := _wreck_body(yard)
	check(body != null, "the wreck has a body to look at")
	var plain := []
	var slotted := []
	if body:
		var mid := body.global_position
		for o: int in body.get_shape_owners():
			if not plain.is_empty() and not slotted.is_empty():
				break
			var cs := body.shape_owner_get_owner(o) as Node3D
			if cs == null:
				continue
			var at := cs.global_position
			var out := Vector3(at.x - mid.x, 0.0, at.z - mid.z)
			if out.length() < 0.5:
				continue
			rig.worker.global_position = at + out.normalized() * 1.2 - Vector3(0, 1.55, 0)
			rig.worker.face(at)
			await frames(1)
			station.update(0.0)
			var got := station.aim_info()
			if got.is_empty():
				continue
			var lines := station.inspect_lines()
			if str(got.get("slot_id", "")) == "" and plain.is_empty() and station.aimed < 0:
				plain = [got, "\n".join(lines)]
			elif str(got.get("slot_id", "")) != "" and slotted.is_empty() and station.aimed < 0:
				slotted = [got, "\n".join(lines)]
	check(not plain.is_empty() and str(plain[1]).contains("CONDITION") and str(plain[1]).contains("MASS")
			and str(plain[1]).contains(str(plain[0].get("display_name", plain[0].get("name", ""))).to_upper()),
			"looking at a part with no slot, the panel shows its own sheet: %s" % (str(plain[1]).replace("\n", " | ") if not plain.is_empty() else "none found"))
	check(not slotted.is_empty() and str(slotted[1]).contains("SLOT") and str(slotted[1]).contains("CONDITION") and not str(slotted[1]).contains("(est.)"),
			"a part in a slot keeps its sheet and gains its condition and real mass: %s" % (str(slotted[1]).replace("\n", " | ") if not slotted.is_empty() else "none found"))
	Flags.set_flag("trades.wreck_info", false)
	check(station.aim_info().is_empty(), "without the flag, nothing new")
	Flags.set_flag("trades.wreck_info", was)
	ship_bus.debug_ship("restore_bay")


func _wreck_body(n: Node) -> CollisionObject3D:
	for b in n.find_children("Wreck", "CollisionObject3D", true, false):
		return b as CollisionObject3D
	return null
