extends ModuleTest
## Hover highlight and pings: a usable thing lights up under the pointer within reach and
## goes dark when the pointer leaves; a ping marks the spot, lights the thing in the
## pinger's colour, and both go when it expires.
##   tools/run_tests.sh graphics


func run_tests() -> void:
	var bus := Modules.bus("graphics") as GfxBus
	check(bus != null and bus.pointer != null, "the graphics module has its pointer")
	if bus == null or bus.pointer == null:
		return
	var pointer := bus.pointer
	pointer.attach_net(null)   # this test checks the drawing, not the network
	Flags.set_flag(GfxBus.HOVER, true)
	Flags.set_flag(GfxBus.PING, true)

	var world := Node3D.new()
	add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.make_current()
	cam.global_position = Vector3(0, 1.5, 0)
	var crate := _box(world, Vector3(0, 1.5, -2.5), true)
	crate.set_meta(GfxBus.ID_META, "crate:1")
	var wall := _box(world, Vector3(10, 1.5, 0), false)
	await frames(3)

	# Pointer (screen centre, as with the mouse captured) on the crate within reach.
	cam.look_at(Vector3(0, 1.5, -2.5))
	await frames(3)
	var mesh := crate.get_child(0) as MeshInstance3D
	check(bus.hover_target() == crate, "the crate is under the pointer")
	check(mesh.material_overlay != null, "the crate is highlighted")
	var over := mesh.material_overlay as ShaderMaterial
	check(float(over.get_shader_parameter("glow")) == 0.0 and over.next_pass != null,
			"hover is subtle: an outline only, no glow")
	check(float((over.next_pass as ShaderMaterial).get_shader_parameter("width")) < GfxBus.PointerLook.Highlighter.BOLD.width,
			"and a thinner outline than a ping's")

	# Looking at something that isn't usable: nothing highlighted.
	cam.look_at(Vector3(10, 1.5, 0))
	await frames(3)
	check(bus.hover_target() == null, "a plain wall isn't a target")
	check(mesh.material_overlay == null, "the crate's highlight is gone")
	check(wall.get_child(0).material_overlay == null, "the wall never lit")

	# Out of reach: no highlight.
	crate.global_position = Vector3(0, 1.5, -8.0)
	cam.look_at(crate.global_position)
	await frames(3)
	check(bus.hover_target() == null, "too far to use: no highlight")

	# A ping from the pointer lands on the crate, even out of reach.
	pointer.ping_life = 0.6
	pointer.ping_fade = 0.2
	check(pointer.ping_at_pointer(), "a ping lands")
	await frames(2)
	check(pointer.live.size() == 1, "one live ping")
	var marker: Node3D = pointer.live[0].node
	check(marker.global_position.distance_to(Vector3(0, 1.5, -7.5)) < 0.1, "the marker sits on the crate's face")
	check(mesh.material_overlay != null, "the pinged crate lights up")
	check(pointer.highlighter.colour_of(crate) == pointer.PING_COLOUR, "in the ping's colour")
	check(pointer.highlighter.look_of(crate) == GfxBus.PointerLook.Highlighter.BOLD, "a ping is bold, to catch the eye")

	# A ping by id (a crewmate's), and by place with no id.
	pointer.show_ping({"peer": 2, "name": "Sam", "colour": Color.GREEN, "at": Vector3(0, 0, 50), "object_id": "crate:1"})
	check(pointer.live.size() == 2 and pointer.highlighter.colour_of(crate) == Color.GREEN, "a crewmate's ping finds the crate by id")
	check((pointer.live[1].node.get_node("Label") as Label3D).text.begins_with("Sam"), "labelled with the pinger's name")
	pointer.show_ping({"peer": 2, "name": "Sam", "colour": Color.GREEN, "at": Vector3(0, 1.5, -7.6), "object_id": ""})
	check(pointer.live.size() == 2, "a player's new ping replaces their last")
	check(pointer.highlighter.is_lit(crate, "ping:2"), "a ping with no id lights what it lands beside")

	# Pings expire and take their highlight with them.
	await get_tree().create_timer(1.0).timeout
	await frames(2)
	check(pointer.live.is_empty(), "pings expire")
	check(mesh.material_overlay == null, "the crate goes dark again")
	check(get_tree().get_nodes_in_group("gfx_ping").filter(func(n): return not n.is_queued_for_deletion()).is_empty(),
			"markers are gone")

	# Through Multiplayer (solo): ping() comes back as ping_received and is drawn from it.
	var net := Modules.bus("multiplayer")
	if net and net.has_method("ping"):
		pointer.attach_net(net)
		bus.ping(Vector3(0, 1.5, -7.5), crate)
		await frames(3)
		check(pointer.live.size() == 1, "a ping through Multiplayer comes back and is drawn")
		check(pointer.highlighter.is_lit(crate), "the crate lights from the crew ping (by its id)")
		pointer.detach()
		pointer.attach_net(null)
		check(mesh.material_overlay == null, "detach clears pings and highlights")

	# Switched off, nothing highlights.
	Flags.set_flag(GfxBus.HOVER, false)
	crate.global_position = Vector3(0, 1.5, -2.5)
	cam.look_at(crate.global_position)
	await frames(3)
	check(bus.hover_target() == null and mesh.material_overlay == null, "flag off: no hover highlight")
	Flags.set_flag(GfxBus.HOVER, true)
	world.queue_free()


func _box(parent: Node3D, at: Vector3, usable: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	mesh.mesh = box
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	if usable:
		body.add_to_group(GfxBus.INTERACTABLE)
	parent.add_child(body)
	body.global_position = at
	return body
