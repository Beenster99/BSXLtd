extends Node3D
## Walk-inside mode (beenster, 18 Nov: "our VR mode, which we should rename to walkinside
## mode"): the open design built round you at full size in the hologram's look, to walk
## through with the mouse and keyboard. Floors you stand on, see-through walls with gaps at
## the doors, the parts as glowing blocks, stairs as ramps, each room's name in the air.
## It follows the design as it changes, so someone at the table can move a wall while you
## stand in the room.
##
## Built far below the design room (OFFSET) on its own physics layer, so nothing in the
## station touches it. WASD walks, Shift runs, Space jumps, the mouse looks round, Esc goes
## back to the table (DesignFurnishing).

const T := preload("res://modules/ui/api/terminal_kit.gd")
const HOLO_SHADER := preload("res://modules/design/internal/holo/holo.gdshader")

## Where the walk-inside world is built, from the design room, m.
const OFFSET := Vector3(0, -1000, 0)
## The physics layer it alone uses (bit 20).
const LAYER := 1 << 19
## Wall and floor thickness, m.
const WALL := 0.1
## A doorway: width and height, m.
const DOOR_W := 1.2
const DOOR_H := 2.2
## Stairs: the ramp's width at most, and the landing at its top, m.
const RAMP_W := 1.2
const LANDING := 1.0

## Walking speed, m/s.
@export var walk_speed := 3.0
## Running speed (Shift), m/s.
@export var run_speed := 6.0
## Jump speed, m/s.
@export var jump_speed := 4.2
## Gravity, m/s2.
@export var gravity := 9.8
## Mouse look, radians per pixel.
@export var look_speed := 0.003

var bus: DesignBus
var body: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var _built: Node3D
var _title: Label
var _where: Label
var _pitch := 0.0
var _dirty := false
## Wall pieces built last time (for tests): {deck, a, b, y0, y1}.
var wall_pieces: Array[Dictionary] = []
## Ramps built last time (for tests): room id of the lower stairs room.
var ramps: PackedStringArray = []


func setup(design_bus: DesignBus, origin: Transform3D) -> void:
	bus = design_bus
	name = "WalkInside"
	top_level = true
	global_transform = Transform3D(Basis.IDENTITY, origin.origin + OFFSET)
	_add_ground()
	_rebuild()
	_add_player()
	_add_hud()
	bus.design_changed.connect(_on_changed)
	spawn()


func _exit_tree() -> void:
	if bus and bus.design_changed.is_connected(_on_changed):
		bus.design_changed.disconnect(_on_changed)


func record() -> DesignRecord:
	return bus.library.current if bus else null


## Puts you in the airlock (else the first room), facing the middle of the ship.
func spawn() -> void:
	var rec := record()
	var at := Vector3(0, 0.1, 0)
	var face := Vector3(0, 0, -1)
	if rec and not rec.rooms.is_empty():
		var start: Dictionary = {}
		for r in rec.rooms_on(rec.decks()[0]):
			var rt := bus.catalog.room(str(r.type))
			if rt and rt.is_airlock:
				start = r
				break
		if start.is_empty():
			start = rec.rooms_on(rec.decks()[0])[0]
		var rect := Rect2(start.x, start.z, start.w, start.d)
		var c := rect.get_center()
		at = Vector3(c.x, int(start.deck) * rec.deck_height + 0.1, c.y)
		var mid := rec.bounds().get_center()
		face = Vector3(mid.x - c.x, 0, mid.y - c.y)
		if face.length() < 0.1:
			face = Vector3(0, 0, -1)
	body.position = at + Vector3(0, 0.9, 0)
	body.velocity = Vector3.ZERO
	body.rotation.y = atan2(-face.x, -face.z)
	_pitch = 0.0
	camera.rotation.x = 0.0


## The deck you're on and the room you're in ("" outside).
func where() -> Dictionary:
	var rec := record()
	if rec == null:
		return {"deck": 0, "room": ""}
	var feet := body.position.y - 0.9
	var deck := maxi(int(floor((feet + 0.5) / rec.deck_height)), 0)
	return {"deck": deck, "room": rec.room_at(deck, Vector2(body.position.x, body.position.z))}


func look(relative: Vector2) -> void:
	body.rotation.y -= relative.x * look_speed
	_pitch = clampf(_pitch - relative.y * look_speed, -1.45, 1.45)
	camera.rotation.x = _pitch


func _input(event: InputEvent) -> void:
	# Keep the mouse from the station's own walker while you're in here.
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or DisplayServer.get_name() == "headless":
			look(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if body == null:
		return
	var move := _axis(Keys.LEFT, Keys.RIGHT, Keys.FORWARD, Keys.BACK)
	var running := InputMap.has_action(Keys.RUN) and Input.is_action_pressed(Keys.RUN)
	var dir := (body.global_basis * Vector3(move.x, 0, move.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(move.length(), 1.0)
	var speed := run_speed if running else walk_speed
	body.velocity.x = dir.x * speed
	body.velocity.z = dir.z * speed
	if body.is_on_floor():
		body.velocity.y = 0.0
		if InputMap.has_action(Keys.JUMP) and Input.is_action_just_pressed(Keys.JUMP):
			body.velocity.y = jump_speed
	else:
		body.velocity.y -= gravity * delta
	body.move_and_slide()
	# Fallen off the edge of the world: back to the start.
	if body.position.y < -30.0:
		spawn()


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()
	if _where == null:
		return
	var rec := record()
	var w := where()
	var room_name := "Outside"
	if str(w.room) != "":
		var r: Dictionary = rec.rooms[w.room]
		room_name = _room_name(r)
	_title.text = "WALK-INSIDE   %s" % (rec.name.to_upper() if rec else "")
	_where.text = "DECK %d   %s" % [int(w.deck) + 1, room_name.to_upper()]


static func _axis(neg_x: String, pos_x: String, neg_y: String, pos_y: String) -> Vector2:
	for a in [neg_x, pos_x, neg_y, pos_y]:
		if not InputMap.has_action(a):
			return Vector2.ZERO
	return Input.get_vector(neg_x, pos_x, neg_y, pos_y)


func _on_changed() -> void:
	_dirty = true


func _room_name(r: Dictionary) -> String:
	if str(r.get("name", "")) != "":
		return str(r.name)
	var rt := bus.catalog.room(str(r.type))
	return rt.display_name if rt else str(r.type)


# The world

func _add_ground() -> void:
	# Space under the ship is a floor you can't see, so you can step out of the airlock and
	# look back at her.
	var g := StaticBody3D.new()
	g.name = "Ground"
	g.collision_layer = LAYER
	g.collision_mask = 0
	var s := CollisionShape3D.new()
	s.shape = WorldBoundaryShape3D.new()
	g.add_child(s)
	add_child(g)


func _rebuild() -> void:
	if _built:
		remove_child(_built)
		_built.queue_free()
	_built = Node3D.new()
	_built.name = "Design"
	add_child(_built)
	wall_pieces.clear()
	ramps.clear()
	var rec := record()
	if rec == null:
		return
	var lines := ImmediateMesh.new()
	var bright: Array[Vector3] = []
	var dim: Array[Vector3] = []
	var stairs := _stairs(rec)
	for r: Dictionary in rec.rooms.values():
		_floor(rec, r, stairs, dim)
		_label(rec, r)
	var st := DesignStructure.measure(rec)
	var wall_mat := _holo(Color(0.45, 0.85, 1.0), 0.07, 0.9)
	for e in st.outer_edges:
		_wall(rec, e, wall_mat, bright, true)
	for e in st.inner_edges:
		_wall(rec, e, wall_mat, bright, false)
	for low_id: String in stairs:
		_ramp(rec, rec.rooms[low_id], stairs[low_id], bright)
	_components(rec)
	_lines(lines, bright, Color(0.55, 0.9, 1.0))
	_lines(lines, dim, Color(0.3, 0.55, 0.75))
	var mi := MeshInstance3D.new()
	mi.name = "Lines"
	mi.mesh = lines
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_built.add_child(mi)


## Lower stairs room id -> the upper one over it.
func _stairs(rec: DesignRecord) -> Dictionary:
	var out := {}
	for r: Dictionary in rec.rooms.values():
		var rt := bus.catalog.room(str(r.type))
		if rt == null or not rt.links_decks:
			continue
		var rect := Rect2(r.x, r.z, r.w, r.d)
		for u: Dictionary in rec.rooms_on(int(r.deck) + 1):
			var ut := bus.catalog.room(str(u.type))
			if ut and ut.links_decks and Rect2(u.x, u.z, u.w, u.d).intersects(rect):
				out[str(r.id)] = str(u.id)
				break
	return out


## The ramp in a stairs room: along its long side, against its start wall, climbing to a
## landing at the far end. Returns its footprint (x, z, w, d) and which way it climbs.
static func ramp_plan(r: Dictionary) -> Dictionary:
	var along_z := float(r.d) >= float(r.w)
	var length := (float(r.d) if along_z else float(r.w)) - LANDING
	var across := float(r.w) if along_z else float(r.d)
	var width := minf(RAMP_W, across * 0.5)
	var foot := Rect2(r.x, r.z, width, length) if along_z else Rect2(r.x, r.z, length, width)
	return {"rect": foot, "along_z": along_z, "length": length, "width": width}


func _floor(rec: DesignRecord, r: Dictionary, stairs: Dictionary, grid: Array[Vector3]) -> void:
	var rect := Rect2(r.x, r.z, r.w, r.d)
	var y := int(r.deck) * rec.deck_height
	var rt := bus.catalog.room(str(r.type))
	var col := rt.colour if rt else Color(0.4, 0.7, 1.0)
	# The upper room of a stairwell has a hole over the ramp.
	var hole := Rect2()
	for low_id: String in stairs:
		if stairs[low_id] == str(r.id):
			hole = (ramp_plan(rec.rooms[low_id]).rect as Rect2).intersection(rect)
	var pieces: Array[Rect2] = [rect]
	if hole.has_area():
		pieces = _minus(rect, hole)
	var mat := _floor_mat(col)
	for p in pieces:
		_solid("Floor_" + str(r.id), Vector3(p.get_center().x, y - WALL * 0.5, p.get_center().y),
				Vector3(p.size.x, WALL, p.size.y), mat, true)
	# A metre grid on the floor, for scale.
	var gy := y + 0.01
	var x := ceilf(rect.position.x)
	while x < rect.end.x - 0.01:
		if not (hole.has_area() and x > hole.position.x and x < hole.end.x):
			grid.append_array([Vector3(x, gy, rect.position.y), Vector3(x, gy, rect.end.y)])
		x += 1.0
	var z := ceilf(rect.position.y)
	while z < rect.end.y - 0.01:
		if not (hole.has_area() and z > hole.position.y and z < hole.end.y):
			grid.append_array([Vector3(rect.position.x, gy, z), Vector3(rect.end.x, gy, z)])
		z += 1.0


## `rect` with `hole` cut out, as up to four rectangles.
static func _minus(rect: Rect2, hole: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var h := hole.intersection(rect)
	for cand in [
		Rect2(rect.position.x, rect.position.y, rect.size.x, h.position.y - rect.position.y),
		Rect2(rect.position.x, h.end.y, rect.size.x, rect.end.y - h.end.y),
		Rect2(rect.position.x, h.position.y, h.position.x - rect.position.x, h.size.y),
		Rect2(h.end.x, h.position.y, rect.end.x - h.end.x, h.size.y),
	]:
		if cand.size.x > 0.01 and cand.size.y > 0.01:
			out.append(cand)
	return out


## One wall stretch on one deck, with a doorway wherever a door stands on it.
func _wall(rec: DesignRecord, e: Dictionary, mat: Material, lines: Array[Vector3], outer: bool) -> void:
	var a: Vector2 = e.a
	var b: Vector2 = e.b
	var deck := int(e.deck)
	var y0 := deck * rec.deck_height
	var y1 := y0 + rec.deck_height - WALL
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var dir := (b - a) / length
	# Doors along this stretch, as distances from a.
	var gaps: Array[Vector2] = []
	for d: Dictionary in rec.doors.values():
		if int(d.deck) != deck:
			continue
		var at := Vector2(float(d.x), float(d.z))
		var t := (at - a).dot(dir)
		if t < -0.01 or t > length + 0.01 or (a + dir * t).distance_to(at) > 0.05:
			continue
		if outer != (str(d.b) == ""):
			continue
		gaps.append(Vector2(maxf(t - DOOR_W * 0.5, 0.0), minf(t + DOOR_W * 0.5, length)))
	gaps.sort_custom(func(p, q): return p.x < q.x)
	var start := 0.0
	for g in gaps:
		_wall_piece(rec, a, dir, deck, start, g.x, y0, y1, mat, lines)
		_wall_piece(rec, a, dir, deck, g.x, g.y, y0 + DOOR_H, y1, mat, lines)
		start = g.y
	_wall_piece(rec, a, dir, deck, start, length, y0, y1, mat, lines)


func _wall_piece(_rec: DesignRecord, a: Vector2, dir: Vector2, deck: int, t0: float, t1: float,
		y0: float, y1: float, mat: Material, lines: Array[Vector3]) -> void:
	if t1 - t0 < 0.02 or y1 - y0 < 0.02:
		return
	var p0 := a + dir * t0
	var p1 := a + dir * t1
	var mid := (p0 + p1) * 0.5
	var size := Vector3(absf(p1.x - p0.x) + (WALL if absf(dir.x) < 0.5 else 0.0), y1 - y0,
			absf(p1.y - p0.y) + (WALL if absf(dir.y) < 0.5 else 0.0))
	_solid("Wall", Vector3(mid.x, (y0 + y1) * 0.5, mid.y), size, mat, true)
	wall_pieces.append({"deck": deck, "a": p0, "b": p1, "y0": y0, "y1": y1})
	var c := [Vector3(p0.x, y0, p0.y), Vector3(p1.x, y0, p1.y), Vector3(p1.x, y1, p1.y), Vector3(p0.x, y1, p0.y)]
	lines.append_array([c[3], c[2], c[0], c[3], c[1], c[2]])


func _ramp(rec: DesignRecord, r: Dictionary, _upper_id: String, lines: Array[Vector3]) -> void:
	var plan := ramp_plan(r)
	var rect: Rect2 = plan.rect
	var h := rec.deck_height
	var y := int(r.deck) * h
	var length: float = plan.length
	var slope := Vector2(length, h).length()
	var ramp := StaticBody3D.new()
	ramp.name = "Ramp_" + str(r.id)
	ramp.collision_layer = LAYER
	ramp.collision_mask = 0
	var angle := atan2(h, length)
	var c := rect.get_center()
	ramp.position = Vector3(c.x, y + h * 0.5 - WALL * 0.5, c.y)
	if plan.along_z:
		ramp.rotation.x = -angle  # climbs towards +Z
	else:
		ramp.rotation.z = angle  # climbs towards +X
	var sz := Vector3(rect.size.x, WALL, slope) if plan.along_z else Vector3(slope, WALL, rect.size.y)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	shape.shape = box
	ramp.add_child(shape)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = _floor_mat(Color(0.55, 0.9, 1.0))
	ramp.add_child(mi)
	_built.add_child(ramp)
	ramps.append(str(r.id))
	# Its edges.
	var lo := Vector3(rect.position.x, y, rect.position.y)
	if plan.along_z:
		lines.append_array([lo, Vector3(lo.x, y + h, lo.z + length),
				lo + Vector3(rect.size.x, 0, 0), Vector3(lo.x + rect.size.x, y + h, lo.z + length)])
	else:
		lines.append_array([lo, Vector3(lo.x + length, y + h, lo.z),
				lo + Vector3(0, 0, rect.size.y), Vector3(lo.x + length, y + h, lo.z + rect.size.y)])


func _components(rec: DesignRecord) -> void:
	for c: Dictionary in rec.components.values():
		var pt := bus.catalog.part(str(c.type))
		var r: Dictionary = rec.rooms.get(c.room, {})
		if pt == null or r.is_empty():
			continue
		var f := DesignRules.footprint(c, pt)
		var y := float(r.deck) * rec.deck_height
		var h := minf(pt.size.y, rec.deck_height - WALL - 0.05)
		var at := Vector3(f.get_center().x, y + h * 0.5 + 0.02, f.get_center().y)
		_solid("Part_" + str(c.id), at, Vector3(f.size.x, h, f.size.y), _holo(pt.colour, 0.22, 1.2), true)
		var tag := Label3D.new()
		tag.name = "PartTag_" + str(c.id)
		tag.text = pt.display_name
		tag.font_size = 36
		tag.pixel_size = 0.004
		tag.modulate = pt.colour.lightened(0.3)
		tag.outline_size = 8
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = at + Vector3(0, h * 0.5 + 0.2, 0)
		_built.add_child(tag)


func _label(rec: DesignRecord, r: Dictionary) -> void:
	var rect := Rect2(r.x, r.z, r.w, r.d)
	var tag := Label3D.new()
	tag.name = "RoomTag_" + str(r.id)
	tag.text = _room_name(r).to_upper()
	tag.font_size = 64
	tag.pixel_size = 0.005
	tag.outline_size = 10
	tag.modulate = Color(0.75, 0.95, 1.0)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.position = Vector3(rect.get_center().x, int(r.deck) * rec.deck_height + 2.4, rect.get_center().y)
	_built.add_child(tag)


func _solid(id: String, at: Vector3, sz: Vector3, mat: Material, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not collide:
		mi.name = id
		mi.position = at
		_built.add_child(mi)
		return
	var sb := StaticBody3D.new()
	sb.name = id
	sb.position = at
	sb.collision_layer = LAYER
	sb.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = sz
	shape.shape = box
	sb.add_child(shape)
	sb.add_child(mi)
	_built.add_child(sb, true)


func _lines(mesh: ImmediateMesh, pts: Array[Vector3], col: Color) -> void:
	if pts.is_empty():
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for p in pts:
		mesh.surface_add_vertex(p)
	mesh.surface_end()


func _holo(col: Color, alpha: float, rim: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = HOLO_SHADER
	m.set_shader_parameter("tint", Color(col.r, col.g, col.b, alpha))
	m.set_shader_parameter("rim", rim)
	return m


## Floors are firmer than the hologram's walls, so you can see what you stand on.
func _floor_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col.r * 0.35, col.g * 0.35, col.b * 0.4, 0.75)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# You

func _add_player() -> void:
	body = CharacterBody3D.new()
	body.name = "Walker"
	body.collision_layer = 0
	body.collision_mask = LAYER
	body.floor_max_angle = deg_to_rad(50.0)
	body.floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.8
	shape.shape = cap
	body.add_child(shape)
	camera = Camera3D.new()
	camera.name = "WalkCamera"
	camera.fov = 75.0
	camera.near = 0.05
	camera.position.y = 0.75
	body.add_child(camera)
	add_child(body)


func _add_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "WalkHud"
	hud.layer = 6
	add_child(hud)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", T.box(Color(0.02, 0.05, 0.09, 0.8), T.CYAN, 1, 10.0))
	box.position = Vector2(20, 20)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(box)
	var col := VBoxContainer.new()
	box.add_child(col)
	_title = T.label("WALK-INSIDE", "display_bold", 22, T.CYAN)
	col.add_child(_title)
	_where = T.label("", "mono_bold", 18, T.TEXT)
	_where.name = "Where"
	col.add_child(_where)
	col.add_child(T.label("WASD walk   Shift run   Space jump   Mouse look   Esc back to the table",
			"body", 15, T.DIM))
	var dot := ColorRect.new()
	dot.color = Color(0.7, 0.95, 1.0, 0.7)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position -= Vector2(2, 2)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)
