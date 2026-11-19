extends Node3D
## Contact sheets of part models, one framed shot a part, for checking looks and screenshots:
##   godot --path . res://modules/part_models/internal/tools/part_sheet.tscn -- --out=/tmp/sheets
##       [--ids=fridge,desk] [--vs=Reactor,Seat] [--cols=6] [--cell=360] [--name=sheet]
## Without --ids it shoots every PartModels id. "landing_gear@0.5" poses a moving part (0 stowed,
## 1 deployed: PartModels.pose). Needs a window (xvfb-run works).

var _cell := 360
var _cols := 6


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var out: String = args.get("out", "user://part_sheets")
	_cols = int(args.get("cols", "6"))
	_cell = int(args.get("cell", "360"))
	var items: Array = []
	if args.has("ids"):
		for id in str(args["ids"]).split(","):
			items.append(["bsx", id])
	if args.has("vs"):
		for id in str(args["vs"]).split(","):
			items.append(["vs", id])
	if items.is_empty():
		for id in PartModels.ids():
			items.append(["bsx", id])
	DirAccess.make_dir_recursive_absolute(out)
	var rows := ceili(float(items.size()) / _cols)
	var sheet := Image.create(_cols * _cell, rows * _cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.09, 0.1))
	var vp := SubViewport.new()
	vp.size = Vector2i(_cell, _cell)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.14, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.4
	vp.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 35.0
	vp.add_child(cam)
	var floor := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	floor.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.2, 0.21, 0.23)
	floor.material_override = fm
	vp.add_child(floor)
	var label := Label3D.new()
	vp.add_child(label)
	for f in 8:
		await RenderingServer.frame_post_draw
	for i in items.size():
		var kind: String = items[i][0]
		var id: String = items[i][1]
		var pose := -1.0
		if id.contains("@"):
			pose = float(id.get_slice("@", 1))
			id = id.get_slice("@", 0)
		var n: Node3D = PartModels.instance(id) if kind == "bsx" else VsParts.instance(id)
		if n == null:
			push_warning("no model: " + id)
			continue
		vp.add_child(n)
		if pose >= 0.0:
			PartModels.pose(n, id, pose)
		var box := _box(n)
		if kind == "vs":
			n.position.y -= box.position.y
			box.position.y = 0.0
		var r := maxf(box.size.length() * 0.5, 0.2)
		var mid := box.get_center()
		var dir := Vector3(-0.75, 0.55, -1.0).normalized()
		cam.position = mid + dir * r / sin(deg_to_rad(cam.fov * 0.5)) * 1.0
		cam.look_at(mid)
		label.text = id
		label.pixel_size = r * 0.0025
		label.font_size = 48
		label.outline_size = 12
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = mid - cam.basis.y * r * 0.82
		for f in 4:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, vp.size), Vector2i((i % _cols) * _cell, (i / _cols) * _cell))
		n.queue_free()
		await get_tree().process_frame
	var path := out.path_join(str(args.get("name", "sheet")) + ".png")
	sheet.save_png(path)
	print("PartSheet: ", path)
	get_tree().quit()


func _box(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
