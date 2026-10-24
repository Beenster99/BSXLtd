extends ModuleTest
## Ship and Bay in a crew: what one player does to the ship in the bay reaches the others.
## The shore power plug follows whoever holds it and stays theirs until they put it down; a
## joint made or undone, and a part set in or lifted out, change every player's tracker (so
## the green and amber rings agree). Played here as the events another player's machine
## would send (by = another peer).
##   tools/run_tests.sh ship_bay

const OTHER := 99


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var bay := (load("res://modules/ship_bay/internal/bay/bay.tscn") as PackedScene).instantiate() as Node3D
	add_child(bay)
	await frames(2)
	var access: Node3D = bay.get("access")
	check(access != null, "the bay has its power unit")
	if access == null:
		bay.queue_free()
		return
	# Another player takes the plug off its hook: here it is in their hand, not ours.
	bus.call("_apply_plug", {"state": "hand", "switch": false, "by": OTHER})
	check(access.get("plug_state") == "held", "another player's plug is in their hand")
	access.call("use_plug")
	check(access.get("plug_state") == "held" and not bool(access.call("holding_plug")), "and we can't take it from them")
	# They clip it to the hull and switch on: it is there for us and the ship powers.
	var at := Transform3D(Basis(), Vector3(4.6, 2.6, 3.0))
	var x := at
	bus.call("_apply_plug", {"state": "hull", "switch": true, "by": OTHER, "xform": [x.basis.x.x, x.basis.x.y, x.basis.x.z,
			x.basis.y.x, x.basis.y.y, x.basis.y.z, x.basis.z.x, x.basis.z.y, x.basis.z.z, x.origin.x, x.origin.y, x.origin.z]})
	var plug: Node3D = access.get("plug")
	check(access.get("plug_state") == "hull" and plug.transform.origin.distance_to(at.origin) < 0.001, "their plug on the hull is on ours too")
	check(bool(access.get("switch_on")) and bus.ship_powered, "and the ship is powered for everyone")
	check((bus.get_net_snapshot().get("plug", {}) as Dictionary).get("state", "") == "hull", "a late joiner gets where the plug is")
	# Now anyone can take it off the hull.
	access.call("use_plug")
	check(bool(access.call("holding_plug")), "off the hull it is ours to take")
	check(str(bus.plug_info.get("state", "")) == "hand", "and the others hear it is in our hand")
	access.call("use_plug")
	check(access.get("plug_state") == "hook", "hung back on its hook")

	# A joint another player undoes and makes again changes our tracker too.
	var f: FastenerPoint = bus.get_fasteners("eng_port")[0]
	check(bus.is_joint_tight(f.joint_id), "the engine's first bolt starts tight")
	bus.call("_apply_joint", {"joint": f.joint_id, "made": false, "by": OTHER})
	check(not bus.is_joint_tight(f.joint_id), "another player undoes it: undone here")
	var markers: Dictionary = bay.get("markers")
	await frames(1)
	check((markers[f.joint_id] as MeshInstance3D).material_override == bay.get("_loose_mat"), "its ring follows it here")
	bus.call("_apply_joint", {"joint": f.joint_id, "made": true, "quality": 0.9, "by": OTHER})
	check(bus.is_joint_tight(f.joint_id) and is_equal_approx(bus.joint_quality(f.joint_id), 0.9), "made again, with their quality")
	# A part they lift out and set back.
	for g: FastenerPoint in bus.get_fasteners("radar"):
		bus.call("_apply_joint", {"joint": g.joint_id, "made": false, "by": OTHER})
	check(bus.get_slot_state("radar") == ShipBayBus.SlotState.EMPTY, "every bolt out: the radar mast comes off for us too")
	bus.call("_apply_slot_move", {"slot": "radar", "component": bus.get_slot("radar").accepts[0], "op": "position", "by": OTHER})
	check(bus.get_slot_state("radar") == ShipBayBus.SlotState.POSITIONED, "set back in its slot by them: positioned here")
	bus.call("_apply_slot_move", {"slot": "radar", "op": "remove", "by": OTHER})
	check(bus.get_slot_state("radar") == ShipBayBus.SlotState.EMPTY, "and lifted out again")
	bay.queue_free()
	await frames(1)
	bus.reset_data()
