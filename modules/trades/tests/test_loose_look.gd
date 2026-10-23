extends ModuleTest
## A part off the ship keeps its own look (beenster, 0.3.14: "When an object is removed it
## should not turn into an anonymous box it must remain as the same part"): the loose part in
## the real yard carries Ship and Bay's copy of the part (ShipBayBus.part_visual), not a box.

## The slot under test: Void Salvage's own slot name, or the hand-built Kestrel's until Ship
## and Bay's imported Kestrel lands.
var SLOT: String:
	get:
		var bay := Modules.bus("ship_bay") as ShipBayBus
		return "eng_port" if bay and bay.get_slot("eng_port") else "eng_aft_port_1"


func run_tests() -> void:
	var saved := {}
	for flag: String in ["trades.shipyard", "trades.tractor"]:
		saved[flag] = Flags.is_on(flag)
		Flags.set_flag(flag, true)
	var ship_bus := Modules.bus("ship_bay") as ShipBayBus
	ship_bus.reset_data()
	var yard := (load(Router.scene_path(ShipBayBus.SHIPYARD_SCENE)) as PackedScene).instantiate() as Node3D
	add_child(yard)
	await frames(3)
	var rig: TradesBay = yard.get_node_or_null(TradesBus.YARD_RIG)
	check(rig != null and ship_bus.get_slot(SLOT) != null, "the yard is up with the ship's engine slot")
	if rig == null or ship_bus.get_slot(SLOT) == null:
		yard.queue_free()
		return
	for f in ship_bus.get_fasteners(SLOT):
		ship_bus.note_joint_removed(f.joint_id)
	await frames(2)
	var part: TradesLoosePart = rig.ship_station().tractor.loose.get(SLOT)
	check(part != null, "every joint off: the part is loose")
	if part:
		var meshes := part.find_children("*", "MeshInstance3D", true, false)
		var boxes := meshes.filter(func(m: MeshInstance3D) -> bool: return m.mesh is BoxMesh and m.get_parent() == part)
		check(meshes.size() > 1 and boxes.is_empty(),
				"it looks like the part it was, not a box (%d meshes)" % meshes.size())
	yard.queue_free()
	await frames(1)
	ship_bus.reset_data()
	for flag: String in saved:
		Flags.set_flag(flag, saved[flag])
