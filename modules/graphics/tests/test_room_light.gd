extends ModuleTest
## G2, rooms: a node in "gfx_room" with a "gfx_box" gets a box-projected reflection probe
## and a VoxelGI the size of its box, the VoxelGI bakes shortly after, GI off drops it, and
## the flag off leaves rooms alone.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	Flags.set_flag(GfxBus.GI, true)
	var gi_was: Variant = GraphicsOptions.get_value("gi")
	GraphicsOptions.set_value("gi", 2)

	var room := _room(Vector3(20, 0, 0))
	await frames(3)
	var probe := room.get_node_or_null("GfxProbe") as ReflectionProbe
	var voxel := room.get_node_or_null("GfxVoxelGI") as VoxelGI
	check(probe != null, "the room gets a reflection probe")
	check(voxel != null, "the room gets a VoxelGI")
	if probe:
		check(probe.size.is_equal_approx(Vector3(12, 6, 8)) and probe.box_projection and probe.interior,
				"the probe fills the room, box-projected, indoors")
		check(probe.position.is_equal_approx(Vector3(0, 3, 0)), "centred on the room's box")
	if voxel:
		check(voxel.size.is_equal_approx(Vector3(12, 6, 8)), "the VoxelGI covers the room")
	check(bus.pending_bakes() == 1, "its bake is queued")
	await get_tree().create_timer(GfxBus.BAKE_DELAY + 0.3).timeout
	await frames(2)
	check(bus.pending_bakes() == 0, "and runs")

	# GI switched off in the options: the VoxelGI goes, the probe stays.
	GraphicsOptions.set_value("gi", 0)
	bus.apply_all()
	await frames(2)
	check(room.get_node_or_null("GfxVoxelGI") == null or room.get_node("GfxVoxelGI").is_queued_for_deletion(),
			"GI off: no VoxelGI")
	check(room.get_node_or_null("GfxProbe") != null, "the probe stays")
	GraphicsOptions.set_value("gi", 2)

	# Flag off: a new room is left alone.
	Flags.set_flag(GfxBus.GI, false)
	var plain := _room(Vector3(-20, 0, 0))
	await frames(3)
	check(plain.get_node_or_null("GfxProbe") == null and plain.get_node_or_null("GfxVoxelGI") == null,
			"flag off: rooms keep their own light")
	Flags.set_flag(GfxBus.GI, true)

	# A room freed before its bake (the yard unloading) drops out quietly.
	var gone := _room(Vector3(0, 0, 30))
	await frames(3)
	check(bus.pending_bakes() == 1, "a new room queues a bake")
	gone.free()
	await frames(2)
	check(bus.pending_bakes() == 0, "a freed room's bake is dropped")
	GraphicsOptions.set_value("gi", gi_was)
	room.queue_free()
	plain.queue_free()


## A 12 x 6 x 8 m room: floor, two walls and a light, tagged before it enters the tree.
func _room(at: Vector3) -> Node3D:
	var room := Node3D.new()
	room.add_to_group(GfxBus.ROOM)
	room.set_meta(GfxBus.BOX_META, AABB(Vector3(-6, 0, -4), Vector3(12, 6, 8)))
	for spec: Array in [[Vector3(0, -0.1, 0), Vector3(12, 0.2, 8)], [Vector3(-6, 3, 0), Vector3(0.2, 6, 8)],
			[Vector3(6, 3, 0), Vector3(0.2, 6, 8)]]:
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		m.mesh = box
		m.position = spec[0]
		room.add_child(m)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 5, 0)
	room.add_child(lamp)
	add_child(room)
	room.position = at
	return room
