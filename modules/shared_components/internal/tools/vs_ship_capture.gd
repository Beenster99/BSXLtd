extends Node
## Builds a vsship 2.0 file with VsShipImport and shoots it: four views round the outside,
## one from each room in `layout.rooms` (from its aft end looking forward), the seats' view,
## two close-ups of the fasteners, then the cavity (the linings hidden: the loom and the device
## leads on the frame, from the hold) and the bare frame (the skin hidden too). Needs a renderer:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/shared_components/internal/tools/vs_ship_capture.tscn \
##       -- --file=res://modules/shared_components/data/ships/kestrel.vsship.json --out=/abs/dir

const SIZE := Vector2i(1600, 900)
## Hidden for the services shots: the skin, the linings, the walls' and ceilings' panels.
const SKIN_AND_LININGS: PackedStringArray = ["HullPlate", "WindowPane", "CapPlate", "InnerPanel", "WallPanel", "CeilingPanel"]

var _cam: Camera3D


func _ready() -> void:
	_run()


func _run() -> void:
	var out := "user://vs_ship_capture"
	var path := "res://modules/shared_components/data/ships/kestrel.vsship.json"
	var damage := ""
	var seed_value := 84
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--file="):
			path = arg.trim_prefix("--file=")
		elif arg.begins_with("--damage="):
			damage = arg.trim_prefix("--damage=")   # "fire:3,stripped:1": shoot it as a wreck (WreckMaker)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(SIZE)
	get_tree().root.size = SIZE
	var f := VsShipImport.read(path)
	var id: String = str(f.get("ship", {}).get("id", "ship"))
	if damage != "":
		f = WreckMaker.make(f, seed_value, damage)
		id += "_wreck"
		print("vs_ship_capture: wreck %s seed %d: %s" % [damage, seed_value, str(WreckMaker.summary(f))])
	var body := RigidBody3D.new()
	body.freeze = true
	var im := VsShipImport.new()
	im.build(f, body)
	add_child(body)
	print("vs_ship_capture: %s, %d parts, %d joints, %d fittings, %d warnings" % [id, im.parts_by_path.size(),
			im.joints_by_path.size(), im.fittings_built.size(), im.warnings.size()])
	_light()
	_cam = Camera3D.new()
	_cam.far = 400.0
	_cam.near = 0.05
	add_child(_cam)
	_cam.current = true
	var bounds: Dictionary = f.get("derived", {}).get("bounds", {})
	var lo := VsShipImport.vec3(bounds.get("pos", [-4, -2, -8]))
	var size := VsShipImport.vec3(bounds.get("size", [8, 4, 16]))
	var centre := lo + size * 0.5
	var r := size.length() * 0.65
	# Outside: front quarter, rear quarter, side, above.
	await _shoot(out, id + "_01_front_quarter", centre + Vector3(-0.7, 0.45, -0.75).normalized() * r, centre)
	await _shoot(out, id + "_02_rear_quarter", centre + Vector3(0.7, 0.4, 0.75).normalized() * r, centre)
	await _shoot(out, id + "_03_side", centre + Vector3(-1.0, 0.15, 0.0).normalized() * r, centre)
	await _shoot(out, id + "_04_above", centre + Vector3(0.0, 1.0, -0.001).normalized() * r, centre)
	# Inside: each room from its aft end, eye height, looking forward.
	var n := 5
	for room: Dictionary in f.get("layout", {}).get("rooms", []):
		var p := VsShipImport.vec3(room.get("pos", [0, 0, 0]))
		var s := VsShipImport.vec3(room.get("size", [1, 1, 1]))
		var eye := Vector3(p.x + s.x * 0.5, p.y + minf(1.6, s.y * 0.6), p.z + s.z - 0.3)
		# Step forward out of anything standing against the aft wall (a reactor cabinet).
		var q := PhysicsPointQueryParameters3D.new()
		for i in 8:
			q.position = eye
			if _cam.get_world_3d().direct_space_state.intersect_point(q, 1).is_empty():
				break
			eye.z -= 0.25
		var look := Vector3(p.x + s.x * 0.5, p.y + minf(1.2, s.y * 0.45), p.z + 0.5)
		await _shoot(out, "%s_%02d_room_%d" % [id, n, n - 5], eye, look, 80.0)
		n += 1
	# The pilot's view.
	var seats: Array = f.get("layout", {}).get("seats", [])
	if not seats.is_empty():
		var at := VsShipImport.vec3(seats[0].get("at", [0, 1, 0]))
		await _shoot(out, "%s_%02d_pilot" % [id, n], at + Vector3(0, 0.5, 0), at + Vector3(0, 0.5, -3), 80.0)
		n += 1
	# Close-ups: the first hull plate's rivets from outside, a lining's bolts from inside.
	for want: String in ["HullPlate", "InnerPanel"]:
		for rec: Dictionary in f.get("parts", []):
			if rec.get("name", "") == want:
				var box: Dictionary = rec.get("box", {})
				var bp := VsShipImport.vec3(box.get("pos", [0, 0, 0]))
				var bs := VsShipImport.vec3(box.get("size", [1, 1, 1]))
				var mid := bp + bs * 0.5
				var outward := (mid - Vector3(0.0, mid.y, mid.z)).normalized() if want == "HullPlate" else (Vector3(0.0, mid.y, mid.z) - mid).normalized()
				if outward.length() < 0.5:
					outward = Vector3(0, 1, 0)
				await _shoot(out, "%s_%02d_close_%s" % [id, n, want.to_lower()], mid + outward * 1.2 + Vector3(0, 0.3, 0), mid, 55.0)
				n += 1
				break
	# The services: skin and linings off, a close-up of the first device lead's route (the
	# breaker panel's where there is one) on the frame; then the bare frame whole.
	var routes: Dictionary = f.get("derived", {}).get("routes", {})
	var lead_key := "lead:fitting:breaker_panel" if routes.has("lead:fitting:breaker_panel") else ""
	for key: String in routes:
		if lead_key == "" and key.begins_with("lead:"):
			lead_key = key
	_hide(im, SKIN_AND_LININGS)
	if lead_key != "":
		var pts: Array = routes[lead_key]
		var mid := VsShipImport.vec3(pts[pts.size() / 2])
		# From inside the room, below and across from the route's middle, looking up at it.
		var across := -signf(mid.x) if absf(mid.x) > 0.3 else 1.0
		await _shoot(out, "%s_%02d_cavity" % [id, n], mid + Vector3(across * 0.8, -0.45, 0.5), mid, 50.0)
		n += 1
	await _shoot(out, "%s_%02d_frame" % [id, n], centre + Vector3(-0.7, 0.55, -0.75).normalized() * r * 0.8, centre)
	get_tree().quit()


## Hides every part of these names (linings, skin) so the frame and what runs on it show.
func _hide(im: VsShipImport, names: PackedStringArray) -> void:
	for path: String in im.parts_by_path:
		var part: PartData = im.parts_by_path[path]
		if names.has(part.part_name):
			var look := im.kit.model.part_visual(part.id) as Node3D
			if look != null:
				look.visible = false


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.45
	add_child(fill)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.06, 0.07, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.65)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)


func _shoot(out: String, name: String, from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	_cam.fov = fov
	_cam.position = from
	_cam.look_at(at, Vector3.UP if absf(from.direction_to(at).dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("vs_ship_capture: ", name)
