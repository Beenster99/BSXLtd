extends ModuleTest
## Ship and Bay: a part taken off the ship keeps its look (part_visual): copies of its slot's
## mesh pieces in the slot's mount space, so hung on the mount they sit where the part was.
##   tools/run_tests.sh ship_bay


func run_tests() -> void:
	var bus := Modules.bus("ship_bay") as ShipBayBus
	bus.reset_data()
	var yard := (load("res://modules/ship_bay/internal/yard/shipyard.tscn") as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	if bus.get_slots().is_empty():
		bus.load_ship("kestrel")
		await frames(3)
	var bay: Node3D = yard.get("bay")
	var pieces: Dictionary = bay.get("pieces")
	var slot_id := ""
	for s: MountSlot in bus.get_slots():
		if not (pieces.get(s.slot_id, []) as Array).is_empty():
			slot_id = s.slot_id
			break
	check(slot_id != "", "a slot with mesh pieces")
	var look := bus.part_visual(yard, slot_id)
	check(look != null and look.get_child_count() == (pieces[slot_id] as Array).size(),
			"the loose part is drawn with its own pieces, not a box")
	if look:
		var ship_root: Node3D = bay.get("ship_root")
		var first: MeshInstance3D = (pieces[slot_id] as Array)[0]
		var copy := look.get_child(0) as MeshInstance3D
		var at := bus.get_slot(slot_id).mount * copy.transform
		var was := ship_root.global_transform.affine_inverse() * first.global_transform
		check(copy.mesh == first.mesh and at.origin.distance_to(was.origin) < 0.001,
				"hung on the mount, a piece sits where it was on the ship")
		look.free()
	check(bus.part_visual(yard, "no_such_slot") == null and bus.part_visual(null, slot_id) == null, "nothing for an unknown slot or no yard")
	yard.queue_free()
	await frames(2)
