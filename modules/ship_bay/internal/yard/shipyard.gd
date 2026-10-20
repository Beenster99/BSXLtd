extends Node3D
## The BSX Ltd shipyard: a big building on a planet, a horseshoe of wings round an open
## courtyard. The work flows clockwise round it: trucks unload at Deliveries (west wing),
## goods go on the racks in Stock and are cut and formed in Material prep (the back wing),
## then built up into modules in Pre-assembly (east wing), which opens wide onto the
## courtyard where the salvage ship sits in the bay (the bay scene, on its cradles). The
## open end of the horseshoe faces south onto the apron, where ships come and go.
##
## Grey-box built in code, in Void Salvage's look (the salvage surface shader and its
## finishes). Yard space: metres, +Y up, the courtyard centred on the origin, north is -Z.
##   WASD walk, Shift run, Space jump, mouse look, Esc leaves.

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")
const BAY_SCENE := preload("res://modules/ship_bay/internal/bay/bay.tscn")
const Walker := preload("res://modules/ship_bay/internal/yard/yard_walker.gd")

## Wall height of the wings (inside, floor to roof), metres.
const H := 12.0
## Wall thickness, metres.
const T := 0.5
## The courtyard's half extents (x, z), metres; the wings are WING deep round it.
const YARD := Vector2(28.0, 24.0)
const WING := 22.0

## The rooms in work order, each with its floor box in yard space. Other modules get these
## through ShipBayBus.shipyard_rooms().
const ROOMS := {
	"deliveries": {"name": "Deliveries", "box": AABB(Vector3(-50, 0, -24), Vector3(22, 12, 48))},
	"stock": {"name": "Stock", "box": AABB(Vector3(-50, 0, -46), Vector3(50, 12, 22))},
	"prep": {"name": "Material prep", "box": AABB(Vector3(0, 0, -46), Vector3(50, 12, 22))},
	"preassembly": {"name": "Pre-assembly", "box": AABB(Vector3(28, 0, -24), Vector3(22, 12, 48))},
	"bay": {"name": "The bay", "box": AABB(Vector3(-28, 0, -24), Vector3(56, 30, 48))},
}
## Camera views for screenshots and a quick look round: id -> [eye, target].
const VIEWS := {
	"overview": [Vector3(70, 46, 88), Vector3(0, 0, -10)],
	"apron": [Vector3(-6, 1.7, 46), Vector3(0, 4, -10)],
	"courtyard": [Vector3(-18, 6.5, 20), Vector3(2, 2.5, -2)],
	"deliveries": [Vector3(-31, 2.2, 21), Vector3(-44, 1.5, -12)],
	"stock": [Vector3(-3, 2.5, -27), Vector3(-40, 2.0, -38)],
	"prep": [Vector3(3, 2.5, -27), Vector3(40, 1.0, -40)],
	"preassembly": [Vector3(31, 2.4, 21), Vector3(42, 1.5, -12)],
}

const SHELL := Color(0.86, 0.85, 0.82)     # warm white cladding (TradesLook.SHELL)
const DARK := Color(0.15, 0.16, 0.18)      # frames, doors, machines
const TRIM := Color("e8792b")              # BSX orange
const STEEL := Color(0.55, 0.57, 0.6)
const EDGE := Color(0.4, 0.86, 1.0)        # Void Salvage's lit edge strip
const LAMP := Color(1.0, 0.93, 0.82)

var walker: CharacterBody3D
var view_camera: Camera3D
var bay: Node3D

var _solid: StaticBody3D
var _rng := RandomNumberGenerator.new()
var _paints: Dictionary = {}
var _crates: Array = []
var _concrete: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 4021
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	add_child(_solid)
	_concrete = _plain(Color(0.36, 0.35, 0.34), 0.95)
	_build_planet()
	_build_shell()
	_build_lights()
	_build_signs()
	_build_deliveries()
	_build_stock()
	_build_prep()
	_build_preassembly()
	_build_courtyard()
	_flush_crates()
	bay = BAY_SCENE.instantiate() as Node3D
	bay.set("standalone", false)
	bay.name = "Bay"
	add_child(bay)
	walker = Walker.new()
	walker.name = "Walker"
	add_child(walker)
	walker.call("place", Vector3(-6, 0, 30), Vector3(0, 3, -4))
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.far = 6000.0
	add_child(view_camera)
	var start: String = Router.args.get("view", "")
	if VIEWS.has(start):
		show_view(start)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Looks from one of VIEWS with a still camera (screenshots); any key or click walks again.
func show_view(id: String) -> void:
	if not VIEWS.has(id):
		return
	var v: Array = VIEWS[id]
	view_camera.position = v[0]
	view_camera.look_at(v[1])
	view_camera.current = true


## The room the point (yard space) is in, or "" outside.
static func room_at(point: Vector3) -> String:
	for id: String in ROOMS:
		if (ROOMS[id].box as AABB).has_point(point):
			return id
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			walker.call("look", event.relative)
	elif event is InputEventMouseButton and event.pressed:
		_walk_again()
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if Router.has_scene("main_menu"):
				Router.goto("main_menu")
		else:
			_walk_again()


func _walk_again() -> void:
	if view_camera.current:
		(walker.get("camera") as Camera3D).current = true


# --- The planet ---------------------------------------------------------------------------

func _build_planet() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.26, 0.36, 0.52)
	sky_mat.sky_horizon_color = Color(0.86, 0.68, 0.52)
	sky_mat.ground_horizon_color = Color(0.7, 0.55, 0.42)
	sky_mat.ground_bottom_color = Color(0.3, 0.22, 0.17)
	sky_mat.sun_angle_max = 8.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.55, 0.5)
	e.ambient_light_energy = 0.45
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ssao_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.8, 0.66, 0.54)
	e.fog_density = 0.0012
	e.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-38, -32, 0)
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	# The ground: dusty red-brown plain, with a concrete apron in front of the open end.
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	ground.position.y = -0.02
	ground.material_override = _plain(Color(0.4, 0.26, 0.18), 1.0)
	add_child(ground)
	_collide(Vector3(0, -0.5, 0), Vector3(4000, 1.0, 4000))
	_block(Vector3(0, -0.01, 56), Vector3(90, 0.04, 64), _concrete, false)
	_block(Vector3(-110, -0.01, 30), Vector3(130, 0.03, 9), _plain(Color(0.2, 0.2, 0.21), 0.9), false)
	for i in 10:
		_block(Vector3(-60 - i * 12.0, 0.02, 30), Vector3(5, 0.02, 0.25), _plain(Color(0.9, 0.85, 0.7), 0.8), false)

	# Mesas on the horizon and a pale moon.
	var rock := _plain(Color(0.6, 0.38, 0.27), 1.0)
	for m: Array in [[-700, -1300, 260, 120], [400, -1500, 340, 160], [1300, -500, 220, 90],
			[-1500, 300, 300, 140], [900, 1200, 200, 70], [-500, 1400, 260, 110]]:
		var mesa := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = m[2] * 0.7
		cyl.bottom_radius = m[2]
		cyl.height = m[3]
		cyl.radial_segments = 9
		mesa.mesh = cyl
		mesa.material_override = rock
		mesa.position = Vector3(m[0], m[3] * 0.5 - 4.0, m[1])
		mesa.scale = Vector3(1.0, 1.0, 0.6)
		mesa.rotation.y = float(m[0]) * 0.01
		add_child(mesa)
	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var sphere := SphereMesh.new()
	sphere.radius = 160.0
	sphere.height = 320.0
	moon.mesh = sphere
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color(0.86, 0.84, 0.8)
	moon_mat.disable_fog = true
	moon.material_override = moon_mat
	moon.position = Vector3(-1500, 1300, -3600)
	add_child(moon)


# --- The building -------------------------------------------------------------------------

## Walls, floors and roofs of the three wings. Openings are [centre, width, height].
func _build_shell() -> void:
	var clad := _paint(SHELL, 0.2, 0.6, "satin_paint")
	var x0 := -YARD.x - WING
	var x1 := YARD.x + WING
	var zb := -YARD.y - WING
	# Outside.
	_wall_z(x0, zb, YARD.y, [[-8.0, 6.0, 6.0], [8.0, 6.0, 6.0]], clad)       # west: truck doors
	_wall_x(zb, x0, x1, [], clad)                                             # north
	_wall_z(x1, zb, YARD.y, [[0.0, 1.4, 2.4]], clad)                          # east: a door
	_wall_x(YARD.y, x0, -YARD.x, [[-39.0, 1.4, 2.4]], clad)                   # west wing's end
	_wall_x(YARD.y, YARD.x, x1, [[39.0, 8.0, 8.0]], clad)                     # east wing's end
	# On the courtyard.
	_wall_z(-YARD.x, -YARD.y, YARD.y, [[0.0, 10.0, 8.0]], clad)
	_wall_x(-YARD.y, -YARD.x, YARD.x, [[-14.0, 8.0, 7.0], [14.0, 8.0, 7.0]], clad)
	_wall_z(YARD.x, -YARD.y, YARD.y, [[0.0, 20.0, 9.0]], clad)
	# Between the rooms.
	_wall_x(-YARD.y, x0, -YARD.x, [[-39.0, 10.0, 7.0]], clad)
	_wall_z(0.0, zb, -YARD.y, [[-35.0, 8.0, 7.0]], clad)
	_wall_x(-YARD.y, YARD.x, x1, [[39.0, 10.0, 7.0]], clad)

	# Floors and roofs.
	var floor_mat := _plain(Color(0.4, 0.4, 0.39), 0.85)
	var roof := _paint(Color(0.32, 0.33, 0.35), 0.4, 0.7, "galvanised")
	for r: Array in [[Vector3(0, 0, -YARD.y - WING * 0.5), Vector3(x1 - x0, 0, WING)],
			[Vector3(-YARD.x - WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)],
			[Vector3(YARD.x + WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)]]:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		_block(Vector3(c.x, 0.0, c.z), Vector3(s.x + T, 0.04, s.z + T), floor_mat, false)
		_block(Vector3(c.x, H + 0.3, c.z), Vector3(s.x + T + 0.6, 0.6, s.z + T + 0.6), roof)
		# Roof beams across the short way, seen from inside.
		var long_x := s.x > s.z
		var span := s.x if long_x else s.z
		var n := int(span / 6.0)
		for i in n + 1:
			var u := -span * 0.5 + span * float(i) / float(n)
			var at := c + (Vector3(u, 0, 0) if long_x else Vector3(0, 0, u))
			var size := Vector3(0.35, 0.8, s.z) if long_x else Vector3(s.x, 0.8, 0.35)
			_block(Vector3(at.x, H - 0.4, at.z), size, _paint(DARK, 0.5, 0.5, "gunmetal"), false)

	# Orange trim round the top of every wall, a dark plinth round the bottom.
	var trim := _paint(TRIM, 0.1, 0.45, "gloss_paint")
	var plinth := _paint(DARK, 0.3, 0.6, "satin_paint")
	for edge: Array in [[Vector3(0, 0, zb), x1 - x0, true], [Vector3(x0, 0, (zb + YARD.y) * 0.5), YARD.y - zb, false],
			[Vector3(x1, 0, (zb + YARD.y) * 0.5), YARD.y - zb, false],
			[Vector3(0, 0, -YARD.y), YARD.x * 2.0, true], [Vector3(-YARD.x, 0, 0), YARD.y * 2.0, false],
			[Vector3(YARD.x, 0, 0), YARD.y * 2.0, false],
			[Vector3(-YARD.x - WING * 0.5, 0, YARD.y), WING, true], [Vector3(YARD.x + WING * 0.5, 0, YARD.y), WING, true]]:
		var c: Vector3 = edge[0]
		var size := Vector3(edge[1] + T + 0.7, 0.7, T + 0.25) if edge[2] else Vector3(T + 0.25, 0.7, edge[1] + T + 0.7)
		_block(Vector3(c.x, H + 0.85, c.z), size, trim, false)
		_block(Vector3(c.x, 0.3, c.z), Vector3(size.x, 0.6, size.z), plinth, false)


## A wall along X at z, from x0 to x1, with openings [x centre, width, height].
func _wall_x(z: float, x0: float, x1: float, openings: Array, mat: Material) -> void:
	for piece in _wall_pieces(x0, x1, openings):
		var p: Rect2 = piece
		_block(Vector3(p.get_center().x, p.get_center().y, z), Vector3(p.size.x, p.size.y, T), mat)
	for o: Array in openings:
		_door_frame(Vector3(o[0], 0, z), o[1], o[2], true)


## A wall along Z at x, from z0 to z1, with openings [z centre, width, height].
func _wall_z(x: float, z0: float, z1: float, openings: Array, mat: Material) -> void:
	for piece in _wall_pieces(z0, z1, openings):
		var p: Rect2 = piece
		_block(Vector3(x, p.get_center().y, p.get_center().x), Vector3(T, p.size.y, p.size.x), mat)
	for o: Array in openings:
		_door_frame(Vector3(x, 0, o[0]), o[1], o[2], false)


## The solid parts of a wall from u0 to u1 round its openings, as rects (u along, y up).
static func _wall_pieces(u0: float, u1: float, openings: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var u := u0
	for o: Array in sorted:
		var a: float = o[0] - o[1] * 0.5
		var b: float = o[0] + o[1] * 0.5
		if a > u:
			out.append(Rect2(u, 0, a - u, H))
		out.append(Rect2(a, o[2], b - a, H - o[2]))
		u = b
	if u1 > u:
		out.append(Rect2(u, 0, u1 - u, H))
	return out


## Dark jambs and a header round an opening; big ones get a rolled-up door drum and
## hazard-striped posts.
func _door_frame(at: Vector3, width: float, height: float, along_x: bool) -> void:
	var frame := _paint(DARK, 0.5, 0.5, "gunmetal")
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var thick := Vector3(0.3, 0, T + 0.3) if along_x else Vector3(T + 0.3, 0, 0.3)
	for side: float in [-1.0, 1.0]:
		var post := at + across * (width * 0.5 + 0.15) * side
		_block(Vector3(post.x, height * 0.5, post.z), thick + Vector3(0, height, 0), frame, false)
		if width > 3.0:
			for k in int(height / 0.6):
				if k % 2 == 0:
					var y := 0.3 + k * 0.6
					var s := thick * Vector3(1.02, 0, 1.02) + Vector3(0, 0.3, 0)
					_block(Vector3(post.x, y, post.z), s, _paint(Color(0.95, 0.75, 0.1), 0.1, 0.5, "hazard_paint"), false)
	var head_size := (Vector3(width + 0.6, 0.3, T + 0.3) if along_x else Vector3(T + 0.3, 0.3, width + 0.6))
	_block(at + Vector3(0, height + 0.15, 0), head_size, frame, false)
	if width > 3.0:
		var drum := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.45
		cyl.bottom_radius = 0.45
		cyl.height = width
		drum.mesh = cyl
		drum.material_override = _paint(STEEL, 0.6, 0.45, "galvanised")
		drum.position = at + Vector3(0, height + 0.75, 0)
		drum.rotation = Vector3(0, 0, PI * 0.5) if along_x else Vector3(PI * 0.5, 0, 0)
		add_child(drum)


func _build_lights() -> void:
	var panel := _glow(LAMP, 3.0)
	var spots: Array[Vector3] = []
	for z: float in [-16.0, 0.0, 16.0]:
		spots.append(Vector3(-YARD.x - WING * 0.5, 0, z))
		spots.append(Vector3(YARD.x + WING * 0.5, 0, z))
	for x: float in [-42.0, -25.0, -8.0, 8.0, 25.0, 42.0]:
		spots.append(Vector3(x, 0, -YARD.y - WING * 0.5))
	for s in spots:
		_block(Vector3(s.x, H - 0.85, s.z), Vector3(3.0, 0.1, 1.2), panel, false)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(s.x, H - 1.6, s.z)
		lamp.light_color = LAMP
		lamp.light_energy = 2.2
		lamp.omni_range = 20.0
		lamp.omni_attenuation = 0.7
		lamp.set_meta("gfx_no_shadow", true)
		add_child(lamp)


## Signs over every doorway naming the room it leads into, and the company name on the
## back wing's courtyard face.
func _build_signs() -> void:
	var court := YARD.x
	var back := -YARD.y
	# From the courtyard.
	_sign("DELIVERIES", Vector3(-court + 0.3, 10.0, 0), PI * 0.5, 1.6)
	_sign("STOCK", Vector3(-14, 9.0, back + 0.3), 0.0, 1.3)
	_sign("MATERIAL PREP", Vector3(14, 9.0, back + 0.3), 0.0, 1.3)
	_sign("PRE-ASSEMBLY", Vector3(court - 0.3, 11.0, 0), -PI * 0.5, 1.2)
	var name_board := _sign("BSX LTD", Vector3(0, 9.6, back + 0.35), 0.0, 3.2)
	name_board.modulate = TRIM
	_sign("SHIP MODIFICATION  /  REFIT  /  REPAIR", Vector3(0, 7.4, back + 0.35), 0.0, 0.5)
	# Back out to the bay.
	_sign("THE BAY", Vector3(-court - 0.3, 10.0, 0), -PI * 0.5, 1.4)
	_sign("THE BAY", Vector3(-14, 9.0, back - 0.3), PI, 1.2)
	_sign("THE BAY", Vector3(14, 9.0, back - 0.3), PI, 1.2)
	_sign("THE BAY", Vector3(court + 0.3, 11.0, 0), PI * 0.5, 1.2)
	# Room to room, round the flow.
	_sign("STOCK", Vector3(-39, 9.0, back + 0.3), 0.0, 1.2)
	_sign("DELIVERIES", Vector3(-39, 9.0, back - 0.3), PI, 1.2)
	_sign("MATERIAL PREP", Vector3(-0.3, 9.0, -35), -PI * 0.5, 1.2)
	_sign("STOCK", Vector3(0.3, 9.0, -35), PI * 0.5, 1.2)
	_sign("PRE-ASSEMBLY", Vector3(39, 9.0, back - 0.3), PI, 1.2)
	_sign("MATERIAL PREP", Vector3(39, 9.0, back + 0.3), 0.0, 1.2)
	_sign("GOODS IN", Vector3(-court - WING - 0.3, 7.6, 0), -PI * 0.5, 1.8)


func _sign(text: String, at: Vector3, yaw: float, height_m: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 12
	label.pixel_size = height_m / 96.0
	label.modulate = Color(0.95, 0.95, 0.92)
	label.outline_modulate = Color(0.05, 0.05, 0.06)
	label.position = at
	label.rotation.y = yaw
	label.shaded = false
	label.double_sided = false
	add_child(label)
	return label


# --- The rooms ----------------------------------------------------------------------------

func _build_deliveries() -> void:
	var wood := _paint(Color(0.62, 0.48, 0.3), 0.0, 0.85, "wood")
	# Dock levellers inside each truck door and a truck backed up to the south one.
	for z: float in [-8.0, 8.0]:
		_block(Vector3(-48.5, 0.05, z), Vector3(3.0, 0.1, 5.6), _paint(STEEL, 0.6, 0.5, "rubber_tread"), false)
	_truck(Vector3(-60, 0, 8))
	# Pallets of incoming goods in rows, some wrapped.
	for i in 6:
		for j in 3:
			var at := Vector3(-44 + j * 3.2, 0, -16 + i * 3.6 + (2.0 if j == 1 else 0.0))
			if at.distance_to(Vector3(-44, 0, 8)) < 3.0:
				continue
			_block(at + Vector3(0, 0.075, 0), Vector3(1.2, 0.15, 1.0), wood)
			var stack := _rng.randi_range(1, 3)
			for k in stack:
				var size := Vector3(_rng.randf_range(0.5, 1.1), _rng.randf_range(0.4, 0.7), _rng.randf_range(0.5, 0.9))
				_crate(at + Vector3(_rng.randf_range(-0.1, 0.1), 0.15 + size.y * 0.5 + k * 0.72, 0), size)
	# A forklift and the goods-in desk with its screen.
	_forklift(Vector3(-36, 0, -4), 0.4)
	_block(Vector3(-31, 0.55, 14), Vector3(1.0, 1.1, 3.2), _paint(DARK, 0.3, 0.5, "satin_paint"))
	_block(Vector3(-31, 1.12, 14), Vector3(1.1, 0.04, 3.3), _paint(Color(0.7, 0.71, 0.7), 0.3, 0.4, "brushed_alloy"), false)
	_screen(Vector3(-30.6, 1.5, 14), "GOODS IN\nBAY 2  KESTREL\n4 PALLETS DUE", -PI * 0.5)


func _build_stock() -> void:
	# Three runs of pallet racking along the wing, a walkway between each.
	for z: float in [-43.0, -36.5, -30.0]:
		_rack(Vector3(-46, 0, z), 38.0, 1.4, 4, 2.2)
	# Small-parts bins along the partition.
	for i in 6:
		var at := Vector3(-3.0, 0, -44 + i * 1.6)
		_block(at + Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 1.4), _paint(Color(0.24, 0.42, 0.62), 0.3, 0.5, "satin_paint"))
		for k in 4:
			_block(at + Vector3(-0.62, 0.3 + k * 0.45, 0), Vector3(0.05, 0.3, 1.2), _paint(TRIM, 0.1, 0.5, "plastic"), false)


func _build_prep() -> void:
	var plate := _paint(STEEL, 0.75, 0.45, "bare_steel")
	# Plate stock in stacks, by the door from Stock.
	for i in 4:
		var at := Vector3(5 + i * 3.4, 0, -42)
		_block(at + Vector3(0, 0.1, 0), Vector3(2.6, 0.2, 1.4), _paint(DARK, 0.3, 0.6, "cast_iron"))
		for k in _rng.randi_range(4, 12):
			_block(at + Vector3(_rng.randf_range(-0.05, 0.05), 0.22 + k * 0.03, 0), Vector3(2.5, 0.025, 1.25), plate, false)
	# A pipe and bar rack.
	var rack_mat := _paint(TRIM, 0.2, 0.5, "satin_paint")
	for x: float in [5.0, 9.0, 13.0]:
		_block(Vector3(x, 1.2, -32), Vector3(0.15, 2.4, 1.2), rack_mat)
	for k in 3:
		for p in 5:
			_bar(Vector3(9, 0.6 + k * 0.7, -32.3 + p * 0.15), 9.0, 0.04 + 0.01 * k, _paint(STEEL, 0.8, 0.4, "stainless"))
	# A plasma cutting table with its gantry, a saw and a press brake.
	var table := Vector3(26, 0, -38)
	_block(table + Vector3(0, 0.4, 0), Vector3(6.0, 0.8, 3.0), _paint(DARK, 0.4, 0.6, "gunmetal"))
	for k in 12:
		_block(table + Vector3(-2.75 + k * 0.5, 0.85, 0), Vector3(0.04, 0.1, 2.9), plate, false)
	for side: float in [-1.0, 1.0]:
		_block(table + Vector3(-1.0, 1.4, 1.6 * side), Vector3(0.3, 1.2, 0.2), rack_mat, false)
	_block(table + Vector3(-1.0, 2.05, 0), Vector3(0.35, 0.3, 3.4), rack_mat, false)
	_block(table + Vector3(-1.0, 1.55, 0.4), Vector3(0.2, 0.7, 0.2), _paint(DARK, 0.5, 0.4, "gunmetal"), false)
	_block(table + Vector3(-1.0, 1.15, 0.4), Vector3(0.06, 0.1, 0.06), _glow(EDGE, 6.0), false)
	_screen(table + Vector3(3.3, 1.4, -1.6), "PLASMA CUT\nPLATE 6MM\nNEST 3/8", PI * 0.5)
	_block(Vector3(40, 0.9, -42), Vector3(4.0, 1.8, 1.2), _paint(Color(0.24, 0.42, 0.62), 0.3, 0.5, "satin_paint"))
	_block(Vector3(40, 2.1, -42), Vector3(4.0, 0.6, 0.5), _paint(DARK, 0.4, 0.5, "gunmetal"))
	_block(Vector3(42, 0.5, -30), Vector3(3.0, 1.0, 1.0), _paint(DARK, 0.4, 0.5, "gunmetal"))
	_block(Vector3(42, 1.05, -30), Vector3(0.8, 0.1, 0.8), _paint(STEEL, 0.8, 0.3, "polished_steel"), false)
	for x: float in [16.0, 20.0]:
		_bench(Vector3(x, 0, -28.5))


func _build_preassembly() -> void:
	# Assembly jigs, each a frame of posts round a module going together.
	var jig := _paint(TRIM, 0.2, 0.5, "satin_paint")
	for z: float in [-14.0, 6.0]:
		var at := Vector3(42, 0, z)
		for corner: Vector3 in [Vector3(-2.5, 0, -3), Vector3(2.5, 0, -3), Vector3(-2.5, 0, 3), Vector3(2.5, 0, 3)]:
			_block(at + corner + Vector3(0, 1.75, 0), Vector3(0.25, 3.5, 0.25), jig)
		for side: float in [-3.0, 3.0]:
			_block(at + Vector3(0, 3.4, side), Vector3(5.25, 0.25, 0.25), jig, false)
		for side: float in [-2.5, 2.5]:
			_block(at + Vector3(side, 3.4, 0), Vector3(0.25, 0.25, 6.25), jig, false)
	# In the north jig an engine module (a cowl and bell, like the Kestrel's), in the south
	# a net frame.
	var engine := Vector3(42, 0, -14)
	_block(engine + Vector3(0, 0.6, 0), Vector3(2.0, 1.2, 3.0), _paint(DARK, 0.4, 0.5, "gunmetal"))
	var cowl := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 2.2
	cowl.mesh = cyl
	cowl.material_override = _paint(SHELL, 0.2, 0.5, "satin_paint")
	cowl.rotation.x = PI * 0.5
	cowl.position = engine + Vector3(0, 2.0, -0.2)
	add_child(cowl)
	var bell := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.55
	cone.bottom_radius = 0.95
	cone.height = 1.0
	bell.mesh = cone
	bell.material_override = _paint(Color(0.3, 0.27, 0.25), 0.8, 0.35, "heat_shield")
	bell.rotation.x = PI * 0.5
	bell.position = engine + Vector3(0, 2.0, 1.4)
	add_child(bell)
	var net := Vector3(42, 0, 6)
	for k in 6:
		_block(net + Vector3(0, 0.8 + k * 0.3, 0), Vector3(3.8, 0.05, 0.05), _paint(STEEL, 0.6, 0.5, "braid"), false)
		_block(net + Vector3(-1.9 + k * 0.76, 1.55, 0), Vector3(0.05, 1.6, 0.05), _paint(STEEL, 0.6, 0.5, "braid"), false)
	# A jib crane, benches and a parts cart by the opening.
	_block(Vector3(48, 3.5, -4), Vector3(0.5, 7.0, 0.5), jig)
	_block(Vector3(45, 6.8, -4), Vector3(6.0, 0.4, 0.3), jig, false)
	_block(Vector3(43, 5.5, -4), Vector3(0.04, 2.4, 0.04), _paint(DARK, 0.6, 0.4, "braid"), false)
	_block(Vector3(43, 4.2, -4), Vector3(0.3, 0.25, 0.3), _paint(Color(0.95, 0.75, 0.1), 0.2, 0.5, "hazard_paint"), false)
	for z: float in [16.0, 20.0]:
		_bench(Vector3(46, 0, z))
	_block(Vector3(33, 0.5, 14), Vector3(1.4, 0.1, 2.2), _paint(STEEL, 0.6, 0.5, "galvanised"))
	_crate(Vector3(33, 0.85, 13.6), Vector3(0.8, 0.6, 0.8))


func _build_courtyard() -> void:
	# Bay markings round the cradles and hazard lines across the open end.
	var paint := _plain(Color(0.95, 0.75, 0.1), 0.8)
	var mark := Rect2(-9, -10, 18, 22)
	_block(Vector3(0, 0.005, mark.position.y), Vector3(mark.size.x, 0.01, 0.3), paint, false)
	_block(Vector3(0, 0.005, mark.end.y), Vector3(mark.size.x, 0.01, 0.3), paint, false)
	_block(Vector3(mark.position.x, 0.005, mark.get_center().y), Vector3(0.3, 0.01, mark.size.y), paint, false)
	_block(Vector3(mark.end.x, 0.005, mark.get_center().y), Vector3(0.3, 0.01, mark.size.y), paint, false)
	for i in 28:
		_block(Vector3(-27 + i * 2.0, 0.005, YARD.y - 0.5), Vector3(1.0, 0.01, 0.6), paint, false)
	_block(Vector3(0, -0.015, 0), Vector3(YARD.x * 2.0, 0.03, YARD.y * 2.0), _concrete, false)

	# The gantry crane: rails along the tops of the side wings' courtyard walls, a bridge
	# spanning the courtyard, a trolley and a hook over the ship.
	var crane := _paint(Color(0.95, 0.75, 0.1), 0.2, 0.5, "hazard_paint")
	var rail := _paint(DARK, 0.6, 0.4, "gunmetal")
	for x: float in [-YARD.x, YARD.x]:
		_block(Vector3(x, H + 1.5, 0), Vector3(0.6, 0.5, YARD.y * 2.0), rail, false)
	var bridge_z := -3.0
	_block(Vector3(0, H + 2.4, bridge_z - 0.8), Vector3(YARD.x * 2.0 + 1.0, 1.2, 0.5), crane, false)
	_block(Vector3(0, H + 2.4, bridge_z + 0.8), Vector3(YARD.x * 2.0 + 1.0, 1.2, 0.5), crane, false)
	for x: float in [-YARD.x, YARD.x]:
		_block(Vector3(x, H + 2.0, bridge_z), Vector3(1.2, 0.8, 3.0), crane, false)
	_block(Vector3(4, H + 3.3, bridge_z), Vector3(2.2, 1.0, 2.4), _paint(DARK, 0.4, 0.5, "satin_paint"), false)
	_block(Vector3(4, (H + 2.8 + 8.0) * 0.5, bridge_z), Vector3(0.05, H + 2.8 - 8.0, 0.05), _paint(DARK, 0.6, 0.4, "braid"), false)
	_block(Vector3(4, 7.8, bridge_z), Vector3(0.5, 0.5, 0.35), crane, false)

	# Floodlight masts at the open corners, aimed at the bay.
	for x: float in [-YARD.x + 2.0, YARD.x - 2.0]:
		var foot := Vector3(x, 0, YARD.y - 3.0)
		_block(foot + Vector3(0, 7.0, 0), Vector3(0.4, 14.0, 0.4), _paint(STEEL, 0.6, 0.45, "galvanised"))
		_block(foot + Vector3(0, 14.2, 0), Vector3(2.2, 0.8, 0.5), _paint(DARK, 0.4, 0.5, "gunmetal"), false)
		_block(foot + Vector3(0, 14.2, -0.27), Vector3(2.0, 0.6, 0.05), _glow(LAMP, 5.0), false)
		var flood := SpotLight3D.new()
		flood.position = foot + Vector3(0, 14.0, -0.4)
		flood.light_color = LAMP
		flood.light_energy = 3.0
		flood.spot_range = 50.0
		flood.spot_angle = 30.0
		flood.set_meta("gfx_no_shadow", true)
		add_child(flood)
		flood.look_at(Vector3(0, 2.0, 0))
	# Bollards along the apron edge and a parts cart waiting by Pre-assembly.
	for i in 6:
		_block(Vector3(-25 + i * 10.0, 0.5, YARD.y + 1.2), Vector3(0.3, 1.0, 0.3), _paint(Color(0.95, 0.75, 0.1), 0.2, 0.5, "hazard_paint"))
	_block(Vector3(20, 0.5, 4), Vector3(1.6, 0.1, 2.4), _paint(STEEL, 0.6, 0.5, "galvanised"))
	_crate(Vector3(20, 0.85, 4), Vector3(1.2, 0.6, 1.2))


# --- Props --------------------------------------------------------------------------------

## A delivery truck, its back towards +X at `at` (the truck doors face it).
func _truck(at: Vector3) -> void:
	var body := _paint(Color(0.24, 0.42, 0.62), 0.3, 0.5, "metallic_paint")
	_block(at + Vector3(0, 2.0, 0), Vector3(9.0, 3.2, 2.5), _paint(SHELL, 0.2, 0.6, "satin_paint"))
	_block(at + Vector3(-6.0, 1.7, 0), Vector3(2.6, 2.6, 2.5), body)
	_block(at + Vector3(-7.32, 2.3, 0), Vector3(0.05, 1.0, 2.1), _plain(Color(0.1, 0.13, 0.16), 0.1), false)
	_block(at + Vector3(-1.5, 0.45, 0), Vector3(12.0, 0.3, 2.2), _paint(DARK, 0.5, 0.5, "gunmetal"), false)
	for x: float in [-6.2, -0.5, 1.5, 3.5]:
		for side: float in [-1.0, 1.0]:
			var wheel := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 0.4
			wheel.mesh = cyl
			wheel.material_override = _paint(Color(0.08, 0.08, 0.08), 0.0, 0.9, "rubber_tread")
			wheel.rotation.x = PI * 0.5
			wheel.position = at + Vector3(x, 0.5, 1.15 * side)
			add_child(wheel)
	_sign("BSX", at + Vector3(0, 2.4, 1.27), 0.0, 1.2).modulate = TRIM


func _forklift(at: Vector3, yaw: float) -> void:
	var lift := Node3D.new()
	lift.position = at
	lift.rotation.y = yaw
	add_child(lift)
	var yellow := _paint(Color(0.95, 0.75, 0.1), 0.2, 0.5, "hazard_paint")
	_block(Vector3(0, 0.7, 0), Vector3(1.2, 1.0, 2.0), yellow, true, lift)
	_block(Vector3(0, 1.9, 0.3), Vector3(1.1, 0.08, 1.2), _paint(DARK, 0.5, 0.5, "gunmetal"), false, lift)
	for side: float in [-0.5, 0.5]:
		_block(Vector3(side, 1.3, 0.85), Vector3(0.06, 1.2, 0.06), _paint(DARK, 0.5, 0.5, "gunmetal"), false, lift)
		_block(Vector3(side, 1.5, -1.15), Vector3(0.12, 2.8, 0.12), _paint(DARK, 0.5, 0.5, "gunmetal"), false, lift)
		_block(Vector3(side * 0.6, 0.15, -1.75), Vector3(0.15, 0.06, 1.1), _paint(STEEL, 0.7, 0.4, "bare_steel"), false, lift)


## A run of pallet racking from `at` along +X: uprights, beams and goods on each level.
func _rack(at: Vector3, length: float, depth: float, levels: int, level_h: float) -> void:
	var upright := _paint(Color(0.24, 0.42, 0.62), 0.3, 0.5, "satin_paint")
	var beam := _paint(TRIM, 0.2, 0.5, "satin_paint")
	var bays := int(length / 2.7)
	var bay_w := length / float(bays)
	for i in bays + 1:
		for side: float in [-0.5, 0.5]:
			_block(at + Vector3(i * bay_w, levels * level_h * 0.5, depth * side), Vector3(0.1, levels * level_h, 0.1), upright, i % 3 == 0)
	for k in levels:
		var y := 0.15 + k * level_h
		for side: float in [-0.5, 0.5]:
			_block(at + Vector3(length * 0.5, y, depth * side), Vector3(length, 0.14, 0.06), beam, false)
		for i in bays:
			for c in 2:
				if _rng.randf() < 0.2:
					continue
				var size := Vector3(_rng.randf_range(0.7, 1.15), _rng.randf_range(0.5, level_h - 0.6), depth * 0.85)
				_crate(at + Vector3(i * bay_w + bay_w * (0.27 + 0.46 * c), y + 0.07 + size.y * 0.5, 0), size)


## A workbench with a vice and a small screen.
func _bench(at: Vector3) -> void:
	_block(at + Vector3(0, 0.45, 0), Vector3(2.4, 0.9, 0.9), _paint(DARK, 0.3, 0.5, "satin_paint"))
	_block(at + Vector3(0, 0.92, 0), Vector3(2.5, 0.05, 1.0), _paint(Color(0.7, 0.71, 0.7), 0.3, 0.4, "brushed_alloy"), false)
	_block(at + Vector3(0.9, 1.02, 0.3), Vector3(0.2, 0.16, 0.25), _paint(Color(0.24, 0.42, 0.62), 0.4, 0.5, "cast_iron"), false)


## A small lit screen facing `yaw`, like TradesLook.readout.
func _screen(at: Vector3, text: String, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	_block(Vector3.ZERO, Vector3(0.9, 0.55, 0.04), _plain(Color(0.02, 0.03, 0.04), 0.25), false, holder)
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.0045
	label.modulate = Color(0.45, 0.95, 1.0)
	label.outline_size = 0
	label.shaded = false
	label.position.z = 0.025
	holder.add_child(label)


## A long round bar along X.
func _bar(centre: Vector3, length: float, radius: float, mat: Material) -> void:
	var bar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 8
	bar.mesh = cyl
	bar.material_override = mat
	bar.rotation.z = PI * 0.5
	bar.position = centre
	add_child(bar)


## A box of goods; drawn together in one MultiMesh at the end (_flush_crates).
func _crate(centre: Vector3, size: Vector3) -> void:
	var tints: Array[Color] = [Color(0.62, 0.48, 0.3), Color(0.55, 0.42, 0.26), Color(0.24, 0.42, 0.62),
			Color(0.5, 0.52, 0.5), TRIM, Color(0.3, 0.45, 0.3)]
	_crates.append([Transform3D(Basis.from_scale(size), centre), tints[_rng.randi() % tints.size()]])


func _flush_crates() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var box := BoxMesh.new()
	mm.mesh = box
	mm.instance_count = _crates.size()
	for i in _crates.size():
		mm.set_instance_transform(i, _crates[i][0])
		mm.set_instance_color(i, _crates[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Crates"
	mmi.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.8
	mmi.material_override = mat
	add_child(mmi)


# --- Building blocks ----------------------------------------------------------------------

## A box `size` at `centre`; solid ones also go into the yard's collision.
func _block(centre: Vector3, size: Vector3, mat: Material, solid := true, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	(parent if parent else self).add_child(mi)
	if solid:
		if parent:
			var body := StaticBody3D.new()
			var shape := CollisionShape3D.new()
			shape.shape = BoxShape3D.new()
			(shape.shape as BoxShape3D).size = size
			body.add_child(shape)
			mi.add_child(body)
		else:
			_collide(centre, size)
	return mi


func _collide(centre: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size
	shape.position = centre
	_solid.add_child(shape)


## Paint on Void Salvage's salvage surface shader with a finish (TradesLook.paint).
func _paint(color: Color, metallic: float, roughness: float, finish := "") -> ShaderMaterial:
	var key := "%s/%.2f/%.2f/%s" % [color.to_html(), metallic, roughness, finish]
	if _paints.has(key):
		return _paints[key]
	var m := ShaderMaterial.new()
	m.shader = SURFACE
	m.set_shader_parameter("albedo", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", roughness)
	m.set_shader_parameter("survey_skip", true)
	m.set_shader_parameter("material_finish", SurfaceFinish.code(finish) if finish != "" else 0)
	SurfaceFinish.apply(m)
	_paints[key] = m
	return m


static func _plain(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.03, 0.03, 0.03)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
