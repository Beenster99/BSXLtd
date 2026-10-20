extends Node
## Looks round the shipyard for placing Business's wall screens: plans of each hall from
## above and the view in front of every screen. Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/business/internal/tools/yard_capture.tscn -- --out=/abs/dir

const SIZE := Vector2i(1600, 900)


func _ready() -> void:
	var runner := Runner.new()
	get_tree().root.add_child.call_deferred(runner)


class Runner:
	extends Node

	func _ready() -> void:
		_run.call_deferred()

	func _run() -> void:
		var out := "user://yard_capture"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--out="):
				out = arg.trim_prefix("--out=")
		DirAccess.make_dir_recursive_absolute(out)
		DisplayServer.window_set_size(SIZE)
		get_tree().root.size = SIZE
		if not Modules.ready_done:
			await Modules.modules_ready
		Router.goto(ShipBayBus.SHIPYARD_SCENE)
		for i in 20:
			await get_tree().process_frame
		var yard := get_tree().current_scene as Node3D
		var walker_bus := Modules.bus("ship_bay") as ShipBayBus
		walker_bus.set_walker_active(yard, false)
		var cam := Camera3D.new()
		yard.add_child(cam)
		cam.current = true
		cam.far = 400
		await get_tree().physics_frame
		await get_tree().physics_frame
		_probe(yard)
		# Plans: each hall from straight above.
		var rooms := walker_bus.shipyard_rooms()
		for id: String in rooms:
			var box: AABB = rooms[id].box
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = maxf(box.size.x, box.size.z) + 4.0
			cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(box.get_center().x, 9.0, box.get_center().z))
			cam.near = 0.05
			await _snap(out, "plan_" + id)
		# Each screen, square on and from an angle.
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 70
		var front := yard.find_child(BusinessBus.YARD_NODE, true, false)
		if front:
			var monitors: Array = front.get("monitors")
			# Each channel square on, close enough to read.
			var first: Node3D = monitors[0]
			var tv: Control = first.find_child("Broadcast", true, false)
			for ch: String in ["orders", "goods", "accounts"]:
				tv.call("show_channel", ch)
				cam.global_position = first.global_position + first.global_basis.z * 3.4 + Vector3(0, -0.4, 0)
				cam.look_at(first.global_position)
				await _snap(out, "channel_" + ch)
			# Using it in place: the pointer over the first listing's + button.
			cam.global_position = first.global_position + first.global_basis.z * 2.6 + Vector3(0.4, -1.0, 0)
			cam.look_at(first.global_position)
			await _snap(out, "in_place_wake")
			var live: Control = first.get_node("Viewport/Terminal")
			for b: Button in live.find_children("*", "Button", true, false):
				if b.text == "+" and not b.disabled:
					var p: Vector2 = b.get_global_rect().get_center()
					var px := Vector2(front.get("SCREEN_PX"))
					var size: Vector2 = front.get("SCREEN_M")
					cam.look_at(first.to_global(Vector3((p.x / px.x - 0.5) * size.x, (0.5 - p.y / px.y) * size.y, front.get("DEPTH"))))
					break
			for k in 2:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = true
				front.call("_input", click)
				await get_tree().process_frame
				click = click.duplicate()
				click.pressed = false
				front.call("_input", click)
				await get_tree().process_frame
			await _snap(out, "in_place_click")
			for m: Node3D in monitors:
				cam.global_position = m.global_position + m.global_basis.z * 6.0 + Vector3(0, -0.6, 0)
				cam.look_at(m.global_position)
				await _snap(out, "screen_%s" % m.name)
				var aside := m.global_basis.x * (3.5 if m.global_basis.x.dot(-m.global_position) > 0 else -3.5)
				cam.global_position = m.global_position + m.global_basis.z * 4.0 + aside + Vector3(0, -0.9, 0)
				cam.look_at(m.global_position)
				await _snap(out, "screen_%s_side" % m.name)
		# The orders channel on the wrist screen, with something on the purchase order and
		# something on its way; then the accounts.
		var bus := Modules.bus("business") as BusinessBus
		var buys := bus.get_listings().filter(func(l): return l.available >= 3 and l.unit_price < 2000)
		bus.place_market_order([{"listing_id": buys[2].id, "qty": 3}])
		bus.wrist_basket[buys[0].id] = 2
		bus.wrist_basket[buys[1].id] = 1
		HudSlots.open_holo("business.orders")
		await _snap(out, "wrist_orders")
		HudSlots.open_holo("business.accounts")
		await _snap(out, "wrist_accounts")
		get_tree().quit()

	## For each --probe=x,z,dx,dz: casts from (x, 2.6, z) along (dx, 0, dz) and prints the wall.
	func _probe(yard: Node3D) -> void:
		var space := yard.get_world_3d().direct_space_state
		for arg in OS.get_cmdline_user_args():
			if not arg.begins_with("--probe="):
				continue
			var v := arg.trim_prefix("--probe=").split_floats(",")
			var from := Vector3(v[0], 2.6, v[1])
			var dir := Vector3(v[2], 0, v[3]).normalized()
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + dir * 12.0))
			print("probe %s: %s" % [arg, str(hit.get("position")) + " n" + str(hit.get("normal")) + " " + str(hit.get("collider")) if hit else "nothing"])

	func _snap(out: String, id: String) -> void:
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, id])
		print("yard_capture: ", id)
