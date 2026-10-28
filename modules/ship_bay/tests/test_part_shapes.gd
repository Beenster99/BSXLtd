extends ModuleTest
## Ship and Bay: a part taken off a ship keeps its own shape (beenster, 0.3.26: "on the refurb
## line the part turns into a box"). Its crate carries a shape key; trolleys, the refurbishment
## line and the crusher draw it with ItemLook.look_id, built from the bay ship's own pieces.
##   tools/run_tests.sh ship_bay

const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var was := Flags.is_on("ship_bay.bay_cradle")
	Flags.set_flag("ship_bay.bay_cradle", true)
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	bus._apply_debug_ship({"action": "random_wreck", "wreck": {"design": "vsw:corsair_frigate", "seed": 5, "events": [], "name": "Corsair", "size": "L"}})
	await frames(2)
	var bay: Node3D = yard.get("bay")
	# A hull plate: no catalogue item, so it once came off as a box.
	var slot: MountSlot
	for s in bus.ship.slots:
		if s.accepts.size() > 0 and s.accepts[0].begins_with("HullPlate") and not (bay.get("pieces")[s.slot_id] as Array).is_empty():
			slot = s
			break
	check(slot != null, "the wreck has a hull plate slot")
	var key := bus.part_shape_key(slot.slot_id)
	check(key.begins_with("vsw:corsair_frigate@5/"), "its shape key names the wreck and slot: %s" % key)
	var own := ItemLook.size_of(ItemLook.look_id(slot.accepts[0], key))
	var plain := ItemLook.size_of(slot.accepts[0])
	check(not own.is_equal_approx(plain), "drawn as itself (%s), not a stand-in (%s)" % [own, plain])
	var dims := [own.x, own.y, own.z]
	dims.sort()
	check(is_equal_approx(own.y, dims[0]), "lying with its thinnest side up: %s" % own)
	var n := ItemLook.make(ItemLook.look_id(slot.accepts[0], key), ItemLook.Look.RUST, 10.0)
	check(n.find_children("*", "MeshInstance3D", true, false).size() > 0, "it makes a mesh of it")
	n.free()
	# Beamed onto a trolley, its crate keeps the key; on the line and in the crusher its lot does.
	bus._apply_beamed({"slot": slot.slot_id, "trolley": "m", "component": slot.accepts[0], "condition": 0.4, "route": "refurb"})
	var crate := ""
	for cid in bus.trolley_load("m"):
		crate = cid
	check(crate != "" and str(bus.crate_info(crate).get("shape", "")) == key, "its crate on the trolley carries the shape: %s" % bus.crate_info(crate))
	# It weighs what it did on the ship, so the crusher melts it into ingots (0.3.26: nothing
	# off a wreck ever made one).
	var c := bus.crate_info(crate)
	check(float(c.get("mass", 0.0)) > 1.0 and str(c.get("material", "")) != "", "its crate weighs %.1f kg of %s" % [float(c.get("mass", 0.0)), c.get("material", "")])
	var dust := ShipBayBus.scrap_materials(str(c["item"]), 1, float(c["mass"]), str(c["material"]))
	var kg := 0.0
	for m: String in dust:
		kg += float(dust[m])
	check(is_equal_approx(kg, snappedf(float(c["mass"]) * ShipBayBus.RECOVERY, 0.1)), "crushed, it gives its own kilograms of dust: %s" % dust)
	var crusher := {"state": "running", "lot": {"item": str(c["item"]), "qty": 1, "mass": float(c["mass"]) * 10.0, "material": str(c["material"])},
			"dust": {}, "ingots": {}, "cast": 0}
	bus._crushed(crusher)
	check(int(crusher["cast"]) > 0, "and ten of them cast ingots: %s (dust %s, %.1f kg each)" % [crusher["ingots"], crusher["dust"], float(c["mass"])])
	# The bay's ship gone, a shape already built stays; one never built falls back to its item.
	bus._apply_debug_ship({"action": "restore_bay"})
	await frames(2)
	check(ItemLook.size_of(ItemLook.look_id(slot.accepts[0], key)).is_equal_approx(own), "it keeps its shape after the wreck has gone")
	check(ItemLook.size_of(ItemLook.look_id(slot.accepts[0], key + "x")).is_equal_approx(plain), "an unknown shape falls back to the item")
	yard.queue_free()
	await frames(2)
	Flags.set_flag("ship_bay.bay_cradle", was)
	bus.reset_data()
