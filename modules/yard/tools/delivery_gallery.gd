extends Node3D
## The delivery ships on show (the "Redesign branded delivery ships" thread's screenshots): every
## freight line's courier, hauler and freighter side by side in open space, captured to PNGs.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 \
##       res://modules/yard/tools/delivery_gallery.tscn -- --out=/abs/dir [--only=line_torvale] [--open]

const Ships := preload("res://modules/yard/internal/yard_delivery_ships.gd")
const BotLook := preload("res://modules/yard/internal/yard_bot_look.gd")
const SpaceSky := preload("res://modules/yard/internal/space_sky.gd")

## Each line's ships stand in a row along x, the lines along z this far apart (m).
const LINE_GAP := 600.0
var cam: Camera3D


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "user://delivery_shots"
	var only: PackedStringArray = []
	var size := Vector2i(1600, 900)
	var open := OS.get_cmdline_user_args().has("--open")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	var sky := SpaceSky.new()
	add_child(sky)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.2, 0.9, 0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.6, 0.7, 1.0)
	add_child(fill)
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.far = 4000.0
	add_child(cam)
	var shots: Array = []
	var lines: Array[Node3D] = []
	var li := 0
	for brand: Dictionary in BotLook.BRANDS:
		var z := float(li) * LINE_GAP
		var line := Node3D.new()
		add_child(line)
		lines.append(line)
		var small := Ships.make(brand, Ships.SMALL)
		small.position = Vector3(-110, 0, z - 30)
		line.add_child(small)
		var med := Ships.make(brand, Ships.MEDIUM)
		med.position = Vector3(-40, 0, z - 30)
		line.add_child(med)
		var big := Ships.make(brand, Ships.LARGE)
		big.rotation.y = PI * 0.5   # her bow to -X like the others, her door towards +z
		big.position = Vector3(90, -8, z - 150)
		line.add_child(big)
		if open:
			Ships.set_open(small, 1.0)
			Ships.set_open(med, 1.0)
			(big.get_node("DoorTop") as Node3D).position.y = 7.6
			(big.get_node("DoorBottom") as Node3D).position.y = -7.6
		for k in 6:
			var l := _crate(k)
			med.add_child(l)
			l.position = Ships.hold_spot(Ships.MEDIUM, k)
		for k in 2:
			var l := _crate(k + 3)
			small.add_child(l)
			l.position = Ships.hold_spot(Ships.SMALL, k)
		var id: String = brand.id
		shots.append([li, "line_" + id, Vector3(-75, 55, z + 95), Vector3(10, -5, z - 90)])
		shots.append([li, "courier_" + id, Vector3(-123, 5, z - 16), Vector3(-109, -1, z - 30)])
		shots.append([li, "hauler_" + id, Vector3(-61, 8, z - 10), Vector3(-39, -1.5, z - 30)])
		shots.append([li, "hauler_aft_" + id, Vector3(-16, 7, z - 14), Vector3(-37, -1, z - 30)])
		shots.append([li, "freighter_" + id, Vector3(28, 22, z - 78), Vector3(88, 2, z - 150)])
		shots.append([li, "freighter_aft_" + id, Vector3(165, 18, z - 108), Vector3(115, 0, z - 150)])
		li += 1
	for i in 6:
		await get_tree().process_frame
	for s: Array in shots:
		if not only.is_empty() and not only.has(s[1]):
			continue
		for i in lines.size():
			lines[i].visible = i == int(s[0])
		cam.position = s[2]
		cam.look_at(s[3])
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out, s[1]]
		get_viewport().get_texture().get_image().save_png(path)
		print("captured ", path)
	get_tree().quit()


## A stand-in load (a crate with straps) for the shots.
func _crate(k: int) -> Node3D:
	var n := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.2, 1.4 + 0.3 * float(k % 3), 5.4)
	n.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = [Color(0.55, 0.57, 0.6), Color(0.35, 0.37, 0.4), Color(0.6, 0.45, 0.25)][k % 3]
	mat.metallic = 0.6
	mat.roughness = 0.45
	n.material_override = mat
	var holder := Node3D.new()
	holder.add_child(n)
	n.position.y = b.size.y * 0.5
	return holder
