extends Node3D
## The BSX Ltd shipyard: a big building on a planet, a horseshoe of wings round an open
## courtyard. The work flows clockwise round it: trucks unload at Deliveries (west wing),
## goods go on the racks in Stock and are cut and formed in Material prep (the back wing),
## then built up into modules in Pre-assembly (east wing), which opens wide onto the
## courtyard where the salvage ship sits in the bay (the bay scene, on its cradles). The
## open end of the horseshoe faces south onto the apron, where ships come and go.
##
## Built in code from Void Salvage's own parts library (PartShapes, WreckParts) on its
## salvage surface shader and finishes (ShipSurface), so the yard has the same look and
## detail as the ships it works on: a steel frame of I-beam columns, roof trusses, purlins
## and girts inside profiled cladding, roller shutters, dock shelters, a gantry crane over
## the bay, racking, machines and lamps. Repeated parts are drawn as one MultiMesh per part,
## paint and patch of the yard. Yard space: metres, +Y up, the courtyard centred on the
## origin, north is -Z.
##   WASD walk, Shift run, Space jump, mouse look, Esc leaves.

const BAY_SCENE := preload("res://modules/ship_bay/internal/bay/bay.tscn")
const Walker := preload("res://modules/ship_bay/internal/yard/yard_walker.gd")
const TrolleyFleet := preload("res://modules/ship_bay/internal/yard/trolley_fleet.gd")
const City := preload("res://modules/ship_bay/internal/yard/yard_city.gd")
const StorageLayout := preload("res://modules/ship_bay/internal/storage/storage_layout.gd")
## Crate tints by category for goods in the stores.
const CATEGORY_TINT := {
	"engines": Color(0.85, 0.45, 0.2), "electronics": Color(0.3, 0.5, 0.75), "machinery": Color(0.55, 0.55, 0.3),
	"fluids": Color(0.25, 0.6, 0.55), "weapons": Color(0.45, 0.42, 0.4), "cargo": Color(0.6, 0.48, 0.32),
	"hull": Color(0.7, 0.71, 0.72), "frame": Color(0.5, 0.52, 0.56), "wiring": Color(0.75, 0.55, 0.25),
	"piping": Color(0.6, 0.62, 0.6), "glass": Color(0.55, 0.7, 0.75), "fittings": Color(0.65, 0.6, 0.55),
	"modules": Color(0.95, 0.55, 0.15), "fasteners": Color(0.3, 0.33, 0.38),
}

## Wall height of the wings (inside, floor to roof), metres.
const H := 12.0
## Wall thickness, metres.
const T := 0.5
## The courtyard's half extents (x, z), metres; the wings are WING deep round it.
const YARD := Vector2(28.0, 24.0)
const WING := 22.0
## Column and truss spacing, metres; stations sit at BAY * k + BAY / 2 all over the yard.
const BAY := 6.0
## Repeated parts are batched per patch of the yard this wide (metres), so the
## Compatibility renderer's eight lamps per mesh are the lamps near it.
const CHUNK := 25.0

## The rooms in work order, each with its floor box in yard space. Other modules get these
## through ShipBayBus.shipyard_rooms().
const ROOMS := {
	"deliveries": {"name": "Deliveries", "box": AABB(Vector3(-50, 0, -24), Vector3(22, 12, 48))},
	"stock": {"name": "Stock", "box": AABB(Vector3(-50, 0, -46), Vector3(50, 12, 22))},
	"prep": {"name": "Material prep", "box": AABB(Vector3(0, 0, -46), Vector3(50, 12, 22))},
	"preassembly": {"name": "Pre-assembly", "box": AABB(Vector3(28, 0, -24), Vector3(22, 12, 48))},
	"bay": {"name": "The bay", "box": AABB(Vector3(-28, 0, -24), Vector3(56, 30, 48))},
}
## Clear floor kept for other modules' work places: id -> a transform in yard space whose
## origin is on the floor and whose +Z faces where the worker stands (a bench's back edge).
## Other modules get these through ShipBayBus.shipyard_spot() and add their nodes to the
## yard when ShipBayBus.shipyard_ready fires.
const SPOTS := {
	"bench_preassembly": Transform3D(Basis.IDENTITY, Vector3(34, 0, -20.5)),
	"bench_prep": Transform3D(Basis.IDENTITY, Vector3(18, 0, -29)),
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
	# The Kestrel on its cradles (ship space + the cradle height).
	"kestrel_front": [Vector3(8, 5.2, -12), Vector3(0, 2.6, 0.5)],
	"kestrel_stern": [Vector3(6.5, 4.2, 15), Vector3(0, 2.6, 5.5)],
	"kestrel_rivets": [Vector3(4.4, 3.3, 3.6), Vector3(2.6, 2.7, 1.2)],
	"kestrel_cabin": [Vector3(0, 3.45, -3.0), Vector3(0, 2.7, 1.4)],
	"kestrel_hold": [Vector3(0.3, 3.4, 2.0), Vector3(0, 2.3, 6.4)],
	"kestrel_access": [Vector3(-7.5, 3.2, 9.5), Vector3(-1.0, 1.6, 3.5)],
	"kestrel_lift": [Vector3(-7.5, 3.4, -2.5), Vector3(-3.0, 1.5, 2.6)],
	# The city round the yard: south over the apron, and north-west to downtown.
	"city": [Vector3(30, 24, 100), Vector3(-120, 40, 600)],
	"downtown": [Vector3(-40, 48, 70), Vector3(-560, 90, -620)],
	"kestrel_power": [Vector3(9.5, 2.8, 3.0), Vector3(3.6, 1.4, 6.6)],
	"scaffolds": [Vector3(13.5, 7.5, 10.0), Vector3(3.6, 3.0, -1.0)],
	# The storage hall (StorageLayout): down aisle B, the bins in D2, the bulk floor, goods in.
	"storage_aisle": [Vector3(-21.55, 1.7, -25.6), Vector3(-21.55, 3.2, -42.0)],
	"storage_aisle_d": [Vector3(-10.95, 1.7, -25.2), Vector3(-10.95, 2.6, -42.0)],
	"storage_bins": [Vector3(-11.6, 1.7, -27.4), Vector3(-8.9, 1.4, -32.5)],
	"storage_bulk": [Vector3(-29.8, 6.0, -25.4), Vector3(-42.0, 0.0, -37.0)],
	"goods_in": [Vector3(-31.0, 4.6, -21.0), Vector3(-41.0, 0.0, -6.0)],
	"trolleys": [Vector3(-38.5, 3.4, -25.0), Vector3(-31.0, 0.6, -14.0)],
	"trolley_lift": [Vector3(-12.2, 1.8, -24.6), Vector3(-10.4, 4.6, -34.0)],
	"picking_lift": [Vector3(-20.0, 1.7, -25.6), Vector3(-20.55, 5.8, -34.3)],
	"trolley_tv": [Vector3(-34.0, 1.9, 12.0), Vector3(-28.3, 2.5, 12.0)],
	"hover_truck": [Vector3(-74.0, 4.5, 22.0), Vector3(-60.0, 1.8, 8.0)],
	# Dock 1: the overlook, the launch towers out on the plain.
	"dock": [Vector3(14, 3.2, 22), Vector3(-1, 5.5, -4)],
	"overlook": [Vector3(-3, 7.1, -22.4), Vector3(1, 1.5, 4)],
	"launch_towers": [Vector3(72, 2.0, 40), Vector3(150, 32, -450)],
}

const SHELL := Color(0.86, 0.85, 0.82)     # warm white cladding (TradesLook.SHELL)
const DARK := Color(0.15, 0.16, 0.18)      # frames, doors, machines
const TRIM := Color("e8792b")              # BSX orange
const HAZARD := Color(0.95, 0.75, 0.1)     # crane and safety yellow
const BLUE := Color(0.2, 0.36, 0.56)       # racking and machine blue
const STEEL := Color(0.55, 0.57, 0.6)
const EDGE := Color(0.4, 0.86, 1.0)        # Void Salvage's lit edge strip
const LAMP := Color(1.0, 0.93, 0.82)

## A part along X stood upright (X -> Y).
const UPRIGHT := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
## A part along Y laid along X, and along Z.
const Y_TO_X := Basis(Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1))
const Y_TO_Z := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
## A part along X facing +Y turned to run along Z facing -X (lamp bars, grilles).
const FACE_NX := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))

## The hour of the day, 0..24: moves the sun and the sky, and the yard's night lights come on
## as it gets dark. Follows the "world/time_of_day" setting when there is one.
@export_range(0.0, 24.0) var time_of_day := 14.0

var walker: CharacterBody3D
var view_camera: Camera3D
var bay: Node3D
## False while another module has control (ShipBayBus.set_walker_active).
var walker_active := true
var _walker_layers := Vector2i(1, 1)

var _solid: StaticBody3D
var _sun: DirectionalLight3D
var _env: Environment
var _sky: AlienSky
## Lights that only burn at night, each with its full energy in meta "night_energy".
var _night_lights: Array[Light3D] = []
var _night_lens: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _paints: Dictionary = {}
## Library shapes by key, made once (_lib).
var _shapes: Dictionary = {}
## Batches waiting to be drawn: "<shape>|<material>|<patch>" -> {shape, mat, xforms}.
var _batches: Dictionary = {}
var _glows: Dictionary = {}
## The collision bodies the yard built itself, before other modules added theirs.
var _own_bodies: Dictionary = {}

# The yard's paints (_paints_init).
var _frame: Material
var _galv: Material
var _trim: Material
var _hazard: Material
var _blue: Material
var _rubber: Material
var _bare: Material
var _wood: Material
var _concrete: Material
var _parts: Material   # white: a library part shows its own zones and colours
var _goods: Array[Material] = []   # crate tints
var _labels: Node3D                 # location labels and tags
var _stores: Node3D                 # goods on the shelves and delivered crates, redrawn
var _stores_paint: Dictionary = {}  # category -> crate material
var _bus: ShipBayBus
## The hover trolleys and their console (TrolleyFleet).
var trolleys: Node3D
## The city round the yard (YardCity).
var city: Node3D


func _ready() -> void:
	_rng.seed = 4021
	_solid = StaticBody3D.new()
	_solid.name = "Solid"
	add_child(_solid)
	_paints_init()
	_labels = Node3D.new()
	_labels.name = "Labels"
	add_child(_labels)
	_stores = Node3D.new()
	_stores.name = "Stores"
	add_child(_stores)
	_build_planet()
	_build_shell()
	_build_frame()
	_build_doors()
	_build_lights()
	_build_signs()
	_build_roof_plant()
	_build_deliveries()
	_build_stock()
	_build_prep()
	_build_preassembly()
	_build_courtyard()
	_build_crane()
	_build_dock()
	_build_outside()
	city = City.new()
	add_child(city)
	_build_night_lights()
	_flush()
	bay = BAY_SCENE.instantiate() as Node3D
	bay.set("standalone", false)
	bay.name = "Bay"
	add_child(bay)
	walker = Walker.new()
	walker.name = "Walker"
	add_child(walker)
	walker.call("place", Vector3(-6, 0, 30), Vector3(0, 3, -4))
	trolleys = TrolleyFleet.new()
	trolleys.set("yard", self)
	add_child(trolleys)
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.far = 6000.0
	add_child(view_camera)
	for body: Node in find_children("*", "CollisionObject3D", true, false):
		_own_bodies[body] = true
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.stock_changed.connect(_refresh_stores)
		_refresh_stores()
		_bus.shipyard_ready.emit(self)
	_on_sky_time(_sky.hour, AlienSky.daylight_at(_sky.hour))
	Settings.changed.connect(_on_setting)
	var start: String = Router.args.get("view", "")
	if VIEWS.has(start):
		show_view(start)
	elif DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if _bus and _bus.stock_changed.is_connected(_refresh_stores):
		_bus.stock_changed.disconnect(_refresh_stores)
	if Settings.changed.is_connected(_on_setting):
		Settings.changed.disconnect(_on_setting)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Sets the hour (0..24) for this yard alone (screenshots, tests): the sky moves the sun and
## the night lights follow. A change to the time-of-day setting puts it back on the setting.
func set_time_of_day(hour: float) -> void:
	_sky.set_hour(fposmod(hour, 24.0))


func _on_setting(section: String, key: String, _value: Variant) -> void:
	if section == AlienSky.SECTION and key == AlienSky.KEY:
		_sky.set_hour(-1.0)


## The sky moved: the night lights fade in as the daylight goes.
func _on_sky_time(hour: float, daylight: float) -> void:
	time_of_day = hour
	var night := 1.0 - smoothstep(0.0, 0.3, daylight)
	for l in _night_lights:
		l.light_energy = float(l.get_meta("night_energy")) * night
		l.visible = night > 0.01
	if _night_lens:
		_night_lens.emission_energy_multiplier = lerpf(0.15, 4.0, night)
	if city:
		city.call("set_night", night)


## Is it dark enough for the night lights (0 day .. 1 full night)?
func night_amount() -> float:
	return 1.0 - smoothstep(0.0, 0.3, AlienSky.daylight_at(time_of_day))


## Registers a light that only burns at night.
func _night(l: Light3D) -> void:
	l.set_meta("night_energy", l.light_energy)
	_night_lights.append(l)


## Lamp posts round the courtyard and down the apron, and wall lamps over the big doors:
## off by day, they come on at dusk.
func _build_night_lights() -> void:
	_night_lens = ShipKit.glow(LAMP, 4.0)
	var pole := _lib("pipe/lamp_pole", func() -> PartShapes.PartShape: return WreckParts.pipe(0.09, 7.0, false))
	var arm := _lib("pipe/lamp_arm", func() -> PartShapes.PartShape: return WreckParts.pipe(0.05, 1.2, false))
	var base := _lib("prism/lamp_base", func() -> PartShapes.PartShape: return PartShapes.prism(8, 0.22, 0.6))
	var housing := _lib("chamfer/lamp_head", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.7, 0.14, 0.32), 0.04))
	var lens := _box(Vector3(0.6, 0.02, 0.24))
	var posts: Array[Vector3] = []
	for x: float in [-22.0, 22.0]:
		for z: float in [-14.0, 2.0, 18.0]:
			posts.append(Vector3(x, 0, z))
	for x: float in [-34.0, 34.0]:
		for z: float in [38.0, 58.0, 78.0]:
			posts.append(Vector3(x, 0, z))
	for p in posts:
		var toward := signf(-p.x)   # the arm reaches in toward the middle
		_put(base, _at(p + Vector3(0, 0.3, 0)), _concrete)
		_put(pole, _at(p + Vector3(0, 3.6 + 0.3, 0)), _galv)
		_put(arm, Transform3D(Y_TO_X, p + Vector3(toward * 0.6, 7.1, 0)), _galv, false)
		var head := p + Vector3(toward * 1.2, 7.0, 0)
		_put(housing, _at(head), _frame, false)
		_put(lens, _at(head + Vector3(0, -0.08, 0)), _night_lens, false)
		var l := SpotLight3D.new()
		l.position = head + Vector3(0, -0.2, 0)
		l.rotation_degrees = Vector3(-90, 0, 0)
		l.light_color = LAMP
		l.light_energy = 12.0
		l.spot_range = 20.0
		l.spot_angle = 62.0
		l.spot_attenuation = 0.8
		l.set_meta("gfx_no_shadow", true)
		add_child(l)
		_night(l)
	# Wall lamps on the wings' courtyard faces, over each big doorway.
	var wall_lamp := _lib("chamfer/wall_lamp", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.6, 0.25, 0.3), 0.04))
	for spot: Array in [[Vector3(-YARD.x + 0.35, 9.2, -12.0), Vector3.RIGHT], [Vector3(-YARD.x + 0.35, 9.2, 12.0), Vector3.RIGHT],
			[Vector3(YARD.x - 0.35, 9.2, -12.0), Vector3.LEFT], [Vector3(YARD.x - 0.35, 9.2, 12.0), Vector3.LEFT],
			[Vector3(-14.0, 9.2, -YARD.y + 0.35), Vector3.BACK], [Vector3(14.0, 9.2, -YARD.y + 0.35), Vector3.BACK]]:
		var at: Vector3 = spot[0]
		var out: Vector3 = spot[1]
		var yaw := atan2(out.x, out.z)
		_put(wall_lamp, _at(at, yaw), _frame, false)
		_put(_box(Vector3(0.5, 0.02, 0.2)), _at(at + Vector3(0, -0.13, 0) + out * 0.02, yaw), _night_lens, false)
		var w := SpotLight3D.new()
		w.position = at + out * 0.3 + Vector3(0, -0.2, 0)
		w.light_color = LAMP
		w.light_energy = 5.0
		w.spot_range = 22.0
		w.spot_angle = 60.0
		w.set_meta("gfx_no_shadow", true)
		add_child(w)
		w.look_at(w.position + out * 0.6 + Vector3(0, -1.0, 0))
		_night(w)


## Looks from one of VIEWS with a still camera (screenshots); any key or click walks again.
func show_view(id: String) -> void:
	if not VIEWS.has(id):
		return
	var v: Array = VIEWS[id]
	view_camera.position = v[0]
	view_camera.look_at(v[1])
	view_camera.current = true


## True for a collision body the yard built, false for one another module added to it.
func is_own_body(body: Object) -> bool:
	return _own_bodies.has(body)


## The room the point (yard space) is in, or "" outside.
static func room_at(point: Vector3) -> String:
	for id: String in ROOMS:
		if (ROOMS[id].box as AABB).has_point(point):
			return id
	return ""


## Hands control to another module (off) or takes it back (on). Off, the walker stands still
## where it is, the yard leaves the mouse and keys alone and its cameras stand down.
func set_walker_active(on: bool) -> void:
	if on == walker_active:
		return
	walker_active = on
	walker.set_physics_process(on)
	walker.velocity = Vector3.ZERO
	# Off, it stands nowhere: nothing bumps into it.
	if on:
		walker.collision_layer = _walker_layers.x
		walker.collision_mask = _walker_layers.y
	else:
		_walker_layers = Vector2i(walker.collision_layer, walker.collision_mask)
		walker.collision_layer = 0
		walker.collision_mask = 0
	var cam := walker.get("camera") as Camera3D
	if on:
		cam.current = true
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		# Without handing the view on to the yard's other camera.
		cam.clear_current(false)
		view_camera.clear_current(false)


func _unhandled_input(event: InputEvent) -> void:
	if not walker_active:
		return
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


func _paints_init() -> void:
	_frame = _paint(DARK, 0.5, 0.5, "gunmetal")
	_galv = _paint(STEEL, 0.6, 0.45, "galvanised")
	_trim = _paint(Color(1.0, 0.55, 0.16), 0.1, 0.45, "gloss_paint")
	_hazard = _paint(HAZARD, 0.15, 0.5, "hazard_paint")
	_blue = _paint(BLUE, 0.3, 0.5, "satin_paint")
	_rubber = _paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber")
	_bare = _paint(STEEL, 0.75, 0.42, "bare_steel")
	_wood = _paint(Color(0.62, 0.48, 0.3), 0.0, 0.85, "wood")
	_concrete = _paint(Color(0.5, 0.49, 0.47), 0.0, 0.95)
	_parts = _paint(Color.WHITE, 0.4, 0.55)
	for c: Color in [Color(0.78, 0.6, 0.4), Color(0.4, 0.55, 0.75), Color(0.72, 0.72, 0.7), Color(1.0, 0.62, 0.28), Color(0.5, 0.64, 0.46)]:
		_goods.append(_paint(c, 0.2, 0.6))


# --- The planet ---------------------------------------------------------------------------

func _build_planet() -> void:
	# The sky, sun and planet-light come from UI's AlienSky, which follows the time of day.
	_sky = AlienSky.new()
	_sky.time_changed.connect(_on_sky_time)
	add_child(_sky)
	_sun = _sky.sun
	_env = _sky.environment

	# The ground: dusty red-brown plain, with a concrete apron in front of the open end and
	# a road to the truck doors.
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	ground.mesh = plane
	ground.position.y = -0.02
	ground.material_override = _paint(Color(0.4, 0.26, 0.18), 0.0, 1.0)
	add_child(ground)
	_collide(Vector3(0, -0.5, 0), Vector3(4000, 1.0, 4000))
	_block(Vector3(0, -0.01, 56), Vector3(90, 0.04, 64), _concrete, false)
	_slab_joints(Rect2(-45, 24.5, 90, 63.5), 0.0)
	_block(Vector3(-62, -0.01, 0), Vector3(24, 0.03, 40), _paint(Color(0.24, 0.24, 0.25), 0.0, 0.9, "rubber_tread"), false)
	_block(Vector3(-110, -0.01, 30), Vector3(130, 0.03, 9), _paint(Color(0.2, 0.2, 0.21), 0.0, 0.9, "rubber_tread"), false)
	var line := _paint(Color(0.9, 0.85, 0.7), 0.0, 0.8)
	for i in 10:
		_put(_box(Vector3(5, 0.02, 0.25)), _at(Vector3(-60 - i * 12.0, 0.02, 30)), line, false)

	# Mesas on the horizon and a pale moon.
	var rock := _paint(Color(0.6, 0.38, 0.27), 0.0, 1.0)
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


## Dark saw-cut joints in a concrete slab every BAY metres over `area` (x, z) at height y.
func _slab_joints(area: Rect2, y: float) -> void:
	var joint := _paint(Color(0.16, 0.16, 0.16), 0.0, 0.9)
	var x := ceilf(area.position.x / BAY) * BAY
	while x < area.end.x:
		_block(Vector3(x, y + 0.012, area.get_center().y), Vector3(0.03, 0.01, area.size.y), joint, false)
		x += BAY
	var z := ceilf(area.position.y / BAY) * BAY
	while z < area.end.y:
		_block(Vector3(area.get_center().x, y + 0.012, z), Vector3(area.size.x, 0.01, 0.03), joint, false)
		z += BAY


# --- The building -------------------------------------------------------------------------

## The walls: [axis, at, from, to, openings, clad side]. "x" walls run along X at z = at, "z"
## walls along Z at x = at. Openings are [centre, width, height]. The clad side (+1/-1) faces
## outside or the courtyard and gets the profiled sheet; 0 is a partition between rooms.
func _walls() -> Array:
	var x0 := -YARD.x - WING
	var x1 := YARD.x + WING
	var zb := -YARD.y - WING
	return [
		["z", x0, zb, YARD.y, [[-8.0, 6.0, 6.0], [8.0, 6.0, 6.0]], -1],   # west: truck doors
		["x", zb, x0, x1, [], -1],                                        # north
		["z", x1, zb, YARD.y, [[0.0, 1.4, 2.4]], 1],                      # east: a door
		["x", YARD.y, x0, -YARD.x, [[-39.0, 1.4, 2.4]], 1],               # west wing's end
		["x", YARD.y, YARD.x, x1, [[39.0, 8.0, 8.0]], 1],                 # east wing's end
		["z", -YARD.x, -YARD.y, YARD.y, [[0.0, 10.0, 8.0]], 1],           # on the courtyard
		["x", -YARD.y, -YARD.x, YARD.x, [[-14.0, 8.0, 7.0], [14.0, 8.0, 7.0]], 1],
		["z", YARD.x, -YARD.y, YARD.y, [[0.0, 20.0, 9.0]], -1],
		["x", -YARD.y, x0, -YARD.x, [[-39.0, 10.0, 7.0]], 0],             # between the rooms
		["z", 0.0, zb, -YARD.y, [[-35.0, 8.0, 7.0]], 0],
		["x", -YARD.y, YARD.x, x1, [[39.0, 10.0, 7.0]], 0],
	]


## Yard point of a wall's (u along, y, w across) coordinates.
static func _wall_point(axis: String, at: float, u: float, y: float, w: float) -> Vector3:
	return Vector3(u, y, at + w) if axis == "x" else Vector3(at + w, y, u)


## Walls, floors and roofs of the three wings.
func _build_shell() -> void:
	var clad := _paint(SHELL, 0.2, 0.6, "satin_paint")
	var liner := _paint(Color(0.78, 0.78, 0.76), 0.1, 0.7, "satin_paint")
	var plinth := _paint(DARK, 0.3, 0.6, "satin_paint")
	var rib := _box(Vector3(0.12, H - 0.7, 0.05))
	for wall: Array in _walls():
		var axis: String = wall[0]
		var at: float = wall[1]
		var side: int = wall[5]
		for p: Rect2 in _wall_pieces(wall[2], wall[3], wall[4]):
			var c := _wall_point(axis, at, p.get_center().x, p.get_center().y, 0.0)
			_block(c, _wall_size(axis, p.size.x, p.size.y, T), clad if side != 0 else liner)
		for o: Array in wall[4]:
			_door_frame(_wall_point(axis, at, o[0], 0.0, 0.0), o[1], o[2], axis == "x")
		if side == 0:
			continue
		# The profiled sheet: a rib every 0.6 m on the clad face, short over the openings.
		var face := float(side) * (T * 0.5 + 0.025)
		var u: float = wall[2] + 0.3
		while u < wall[3]:
			var over := _opening_at(wall[4], u, 0.15)
			if over.is_empty():
				_put(rib, Transform3D(_wall_basis(axis), _wall_point(axis, at, u, 0.6 + (H - 0.7) * 0.5, face)), clad, false)
			elif H - over[2] - 0.3 > 0.2:
				var run: float = H - over[2] - 0.35
				_put(_box(Vector3(0.12, run, 0.05)), Transform3D(_wall_basis(axis),
						_wall_point(axis, at, u, over[2] + 0.35 + run * 0.5, face)), clad, false)
			u += 0.6
		# A dark plinth along the bottom of the clad face, a liner dado inside.
		for p: Rect2 in _wall_pieces(wall[2], wall[3], wall[4]):
			if p.position.y > 0.0:
				continue
			_block(_wall_point(axis, at, p.get_center().x, 0.3, float(side) * (T * 0.5 + 0.06)),
					_wall_size(axis, p.size.x, 0.6, 0.12), plinth, false)
			_block(_wall_point(axis, at, p.get_center().x, 0.6, float(-side) * (T * 0.5 + 0.02)),
					_wall_size(axis, p.size.x, 1.2, 0.04), _paint(Color(0.3, 0.32, 0.34), 0.3, 0.6, "satin_paint"), false)

	# Floors (epoxy, a colour per wing, walkway lines) and roofs.
	var x0 := -YARD.x - WING
	var x1 := YARD.x + WING
	var roof := _paint(Color(0.32, 0.33, 0.35), 0.4, 0.7, "galvanised")
	var walk := _paint(HAZARD, 0.0, 0.6, "satin_paint")
	for r: Array in [[Vector3(-25, 0, -YARD.y - WING * 0.5), Vector3(50, 0, WING), Color(0.55, 0.55, 0.53)],
			[Vector3(25, 0, -YARD.y - WING * 0.5), Vector3(50, 0, WING), Color(0.5, 0.53, 0.51)],
			[Vector3(-YARD.x - WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0), Color(0.54, 0.53, 0.5)],
			[Vector3(YARD.x + WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0), Color(0.49, 0.54, 0.51)]]:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		_block(Vector3(c.x, 0.0, c.z), Vector3(s.x + T, 0.04, s.z + T), _paint(r[2], 0.0, 0.8), false)
		# Walkway lines down the long way, a metre and a half in from each wall.
		var long_x := s.x > s.z
		for k: float in [-1.0, 1.0]:
			var off := (s.z if long_x else s.x) * 0.5 - 1.6
			var p := c + (Vector3(0, 0.022, off * k) if long_x else Vector3(off * k, 0.022, 0))
			_block(p, Vector3(s.x - 3.0, 0.004, 0.1) if long_x else Vector3(0.1, 0.004, s.z - 3.0), walk, false)
	for r: Array in [[Vector3(0, 0, -YARD.y - WING * 0.5), Vector3(x1 - x0, 0, WING)],
			[Vector3(-YARD.x - WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)],
			[Vector3(YARD.x + WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)]]:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		_block(Vector3(c.x, H + 0.3, c.z), Vector3(s.x + T + 0.6, 0.6, s.z + T + 0.6), roof)
		# Standing seams across the roof's top, every metre.
		var long_x := s.x > s.z
		var n := int((s.x if long_x else s.z))
		var seam := _box(Vector3(0.05, 0.05, s.z) if long_x else Vector3(s.x, 0.05, 0.05))
		for i in n:
			var u := -(s.x if long_x else s.z) * 0.5 + 0.5 + float(i)
			_put(seam, _at(c + (Vector3(u, H + 0.625, 0) if long_x else Vector3(0, H + 0.625, u))), roof, false)

	# Orange trim round the top of every outside and courtyard wall: a coping on a parapet.
	for wall: Array in _walls():
		if wall[5] == 0:
			continue
		var run: float = float(wall[3]) - float(wall[2])
		var mid: float = (float(wall[2]) + float(wall[3])) * 0.5
		_block(_wall_point(wall[0], wall[1], mid, H + 0.85, 0.0), _wall_size(wall[0], run + T + 0.7, 0.7, T + 0.25), _trim, false)
		_block(_wall_point(wall[0], wall[1], mid, H + 1.24, 0.0), _wall_size(wall[0], run + T + 0.8, 0.08, T + 0.35), _galv, false)


## The size of a box `along` long, `tall` high and `thick` through a wall on `axis`.
static func _wall_size(axis: String, along: float, tall: float, thick: float) -> Vector3:
	return Vector3(along, tall, thick) if axis == "x" else Vector3(thick, tall, along)


## Turns a part made facing Z (its X along the wall) to lie on a wall on `axis`.
static func _wall_basis(axis: String) -> Basis:
	return Basis.IDENTITY if axis == "x" else Basis(Vector3.UP, PI * 0.5)


## The opening [centre, width, height] that u is within `margin` of, or [].
static func _opening_at(openings: Array, u: float, margin: float) -> Array:
	for o: Array in openings:
		if absf(u - float(o[0])) < float(o[1]) * 0.5 + margin:
			return o
	return []


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


## Dark steel jambs and a header round an opening, hazard stripes on the big ones' posts.
func _door_frame(at: Vector3, width: float, height: float, along_x: bool) -> void:
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var basis := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	var jamb := _lib("ibeam/jamb/%.1f" % height, func() -> PartShapes.PartShape:
			return PartShapes.i_beam(height, T + 0.3, 0.3))
	for side: float in [-1.0, 1.0]:
		var post := at + across * (width * 0.5 + 0.15) * side
		_put(jamb, Transform3D(basis * UPRIGHT, post + Vector3(0, height * 0.5, 0)), _frame, false)
		if width > 3.0:
			var band := _box(Vector3(0.32, 0.3, T + 0.34))
			for k in int(height / 0.6):
				if k % 2 == 0:
					_put(band, Transform3D(basis, post + Vector3(0, 0.3 + k * 0.6, 0)), _hazard, false)
	var head := _lib("ibeam/head/%.1f" % width, func() -> PartShapes.PartShape:
			return PartShapes.i_beam(width + 0.6, T + 0.3, 0.3))
	_put(head, Transform3D(basis, at + Vector3(0, height + 0.15, 0)), _frame, false)


## The steel frame inside: an I-beam column at every station along each outside and
## courtyard wall, girts between them, a truss across each wing at every station with
## purlins along it, and a red sprinkler main.
func _build_frame() -> void:
	var col := _lib("ibeam/column", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(H, 0.32, 0.45, 0.022))
	var girt_y: Array[float] = [4.0, 8.0]
	for wall: Array in _walls():
		var side: int = wall[5]
		if side == 0:
			continue
		var axis: String = wall[0]
		var inside := float(-side) * (T * 0.5 + 0.23)
		var u := floorf(float(wall[2]) / BAY) * BAY + BAY * 0.5
		while u < float(wall[3]):
			if u > float(wall[2]) + 0.5 and _opening_at(wall[4], u, 0.6).is_empty():
				_put(col, Transform3D(_wall_basis(axis) * UPRIGHT, _wall_point(axis, wall[1], u, H * 0.5, inside)), _frame)
			u += BAY
		# Girts: C-rails along the wall, broken round anything taller than them.
		for y in girt_y:
			var start: float = wall[2]
			var cuts: Array = []
			for o: Array in wall[4]:
				if float(o[2]) > y - 0.2:
					cuts.append([float(o[0]) - float(o[1]) * 0.5 - 0.35, float(o[0]) + float(o[1]) * 0.5 + 0.35])
			cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
			cuts.append([float(wall[3]), float(wall[3])])
			for c: Array in cuts:
				var run: float = float(c[0]) - start
				if run > 0.5:
					var girt := _lib("ibeam/girt/%.2f" % run, func() -> PartShapes.PartShape:
							return PartShapes.i_beam(run, 0.12, 0.2))
					_put(girt, Transform3D(_wall_basis(axis), _wall_point(axis, wall[1], start + run * 0.5, y,
							float(-side) * (T * 0.5 + 0.08))), _galv, false)
				start = c[1]

	# Roof trusses across each wing at every station, purlins along on top of them.
	var red := _paint(Color(0.75, 0.12, 0.08), 0.2, 0.45, "gloss_paint")
	for wing: Array in [[Rect2(-50, -46, 100, 22), true], [Rect2(-50, -24, 22, 48), false],
			[Rect2(28, -24, 22, 48), false]]:
		var r: Rect2 = wing[0]
		var long_x: bool = wing[1]
		var span := (r.size.y if long_x else r.size.x) - 1.2
		var truss := _lib("truss/%.1f" % span, func() -> PartShapes.PartShape:
				return PartShapes.truss(span, 0.3, 1.3, 8, 0.07))
		var c := r.get_center()
		var u := floorf((r.position.x if long_x else r.position.y) / BAY) * BAY + BAY * 0.5
		var u_end := r.end.x if long_x else r.end.y
		while u < u_end:
			if u > (r.position.x if long_x else r.position.y) + 0.5:
				var p := Vector3(u, H - 0.65, c.y) if long_x else Vector3(c.x, H - 0.65, u)
				_put(truss, Transform3D(Basis(Vector3.UP, -PI * 0.5) if long_x else Basis.IDENTITY, p), _galv, false)
			u += BAY
		var length := r.size.x if long_x else r.size.y
		var purlin := _lib("ibeam/purlin/%.1f" % length, func() -> PartShapes.PartShape:
				return PartShapes.i_beam(length, 0.12, 0.22))
		for k in 5:
			var w := -span * 0.5 + span * (0.1 + 0.2 * k)
			var p := Vector3(c.x, H - 0.11, c.y + w) if long_x else Vector3(c.x + w, H - 0.11, c.y)
			_put(purlin, Transform3D(Basis.IDENTITY if long_x else Basis(Vector3.UP, -PI * 0.5), p), _galv, false)
		var main := _lib("pipe/sprinkler/%.1f" % length, func() -> PartShapes.PartShape:
				return WreckParts.pipe(0.06, length, false))
		var mp := Vector3(c.x, H - 1.55, c.y + 2.5) if long_x else Vector3(c.x + 2.5, H - 1.55, c.y)
		_put(main, Transform3D(Y_TO_X if long_x else Y_TO_Z, mp), red, false)


## Roller shutters in the big openings, rolled most of the way up (the curtain's bottom
## rail well over head height), with a hood over the drum and guide rails down the jambs;
## the small doors stand open.
func _build_doors() -> void:
	var curtain := _paint(Color(0.62, 0.64, 0.66), 0.55, 0.45, "galvanised")
	for wall: Array in _walls():
		var axis: String = wall[0]
		var side: int = wall[5]
		var face := float(side if side != 0 else 1) * (T * 0.5 + 0.12)
		for o: Array in wall[4]:
			var width: float = o[1]
			var height: float = o[2]
			if width < 3.0:
				# An open steel door leaf swung back against the wall inside, a lit sign over it.
				var leaf := _box(Vector3(width - 0.1, 2.3, 0.05))
				_put(leaf, Transform3D(_wall_basis(axis), _wall_point(axis, wall[1], float(o[0]) + width + 0.25, 1.17,
						float(-side) * (T * 0.5 + 0.06))), _frame, false)
				_put(_box(Vector3(0.5, 0.2, 0.05)), Transform3D(_wall_basis(axis),
						_wall_point(axis, wall[1], o[0], height + 0.55, float(-side if side != 0 else 1) * (T * 0.5 + 0.03))),
						_glow_mat(Color(0.3, 1.0, 0.45), 3.0), false)
				continue
			var bottom := maxf(3.2, height * 0.66)
			var drop := height - bottom
			var basis := _wall_basis(axis)
			_put(_box(Vector3(width, drop, 0.03)), Transform3D(basis, _wall_point(axis, wall[1], o[0], bottom + drop * 0.5, face)), curtain, false)
			var slat := _box(Vector3(width - 0.02, 0.025, 0.05))
			var y := bottom + 0.1
			while y < height:
				_put(slat, Transform3D(basis, _wall_point(axis, wall[1], o[0], y, face)), curtain, false)
				y += 0.11
			_put(_box(Vector3(width, 0.12, 0.08)), Transform3D(basis, _wall_point(axis, wall[1], o[0], bottom + 0.06, face)), _hazard, false)
			_put(_box(Vector3(width + 0.6, 0.7, 0.55)), Transform3D(basis, _wall_point(axis, wall[1], o[0], height + 0.65,
					float(side if side != 0 else 1) * (T * 0.5 + 0.3))), _frame, false)
			for k: float in [-1.0, 1.0]:
				var rail := _lib("ibeam/rail/%.1f" % height, func() -> PartShapes.PartShape:
						return PartShapes.i_beam(height, 0.1, 0.14))
				_put(rail, Transform3D(basis * UPRIGHT, _wall_point(axis, wall[1], float(o[0]) + (width * 0.5 - 0.07) * k,
						height * 0.5, face)), _galv, false)


## High-bay lamps hung under the trusses, each a lit strip with a lamp under it.
func _build_lights() -> void:
	var fixture := _lib("light_strip/bay", func() -> PartShapes.PartShape:
			return WreckParts.light_strip(2.4, 0.36, 0.1, LAMP))
	var hanger := _lib("pipe/hanger", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.012, 1.0, false))
	var spots: Array = []
	for z: float in [-15.0, -3.0, 3.0, 15.0]:
		spots.append([Vector3(-YARD.x - WING * 0.5, 0, z), false])
		spots.append([Vector3(YARD.x + WING * 0.5, 0, z), false])
	for x: float in [-45.0, -33.0, -21.0, -9.0, 9.0, 21.0, 33.0, 45.0]:
		spots.append([Vector3(x, 0, -YARD.y - WING * 0.5), true])
	for s: Array in spots:
		var p: Vector3 = s[0]
		# Along the truss it hangs from (trusses run across each wing).
		var basis := Basis(Vector3.UP, -PI * 0.5) if s[1] else Basis.IDENTITY
		_put(fixture, Transform3D(basis * Basis(Vector3.RIGHT, PI), Vector3(p.x, H - 2.3, p.z)), _parts, false)
		for k: float in [-1.0, 1.0]:
			_put(hanger, _at(Vector3(p.x, H - 1.8, p.z) + basis * Vector3(1.0 * k, 0, 0)), _galv, false)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p.x, H - 2.8, p.z)
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
	_sign("SHIP MODIFICATION  /  REFIT  /  REPAIR", Vector3(0, 7.4, back + 0.35), 0.0, 0.5, false)
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
	_sign("GOODS IN", Vector3(-court - WING - 0.4, 7.6, 0), -PI * 0.5, 1.8)


## A sign on a dark board with an orange edge (unless `board` is off), facing `yaw`.
func _sign(text: String, at: Vector3, yaw: float, height_m: float, board := true) -> Label3D:
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
	if board:
		var basis := Basis(Vector3.UP, yaw)
		var size := Vector3(text.length() * height_m * 0.62 + height_m * 0.8, height_m * 1.3, 0.06)
		_put(_box(size), Transform3D(basis, at - basis.z * 0.06), _paint(Color(0.1, 0.11, 0.12), 0.3, 0.5, "satin_paint"), false)
		_put(_box(Vector3(size.x, 0.06, 0.08)), Transform3D(basis, at - basis.z * 0.05 + Vector3(0, -size.y * 0.5 + 0.03, 0)), _trim, false)
	return label


## Air handlers, fans and an antenna mast on the roofs, skylight strips between them.
func _build_roof_plant() -> void:
	var top := H + 0.6
	for x: float in [-38.0, -14.0, 14.0, 38.0]:
		var ahu := _lib("machine/ahu", func() -> PartShapes.PartShape:
				return WreckParts.machine_unit(Vector3(4.0, 1.6, 2.2)))
		_put(ahu, _at(Vector3(x, top + 0.8, -40.0), PI), _parts)
		var fan := _lib("grille_drum/roof", func() -> PartShapes.PartShape:
				return WreckParts.grille_drum(0.55, 0.7))
		for k: float in [-1.0, 1.0]:
			_put(fan, _at(Vector3(x + k * 1.2, top + 1.6 + 0.35, -40.0)), _parts, false)
		var duct := _lib("pipe/duct", func() -> PartShapes.PartShape:
				return WreckParts.pipe(0.35, 6.0))
		_put(duct, Transform3D(Y_TO_Z, Vector3(x, top + 0.5, -35.6)), _galv, false)
	var sky := _lib("window/skylight", func() -> PartShapes.PartShape:
			return PartShapes.window_rect(1.4, 9.0, 0.1))
	for x: float in [-45.0, -27.0, -9.0, 9.0, 27.0, 45.0]:
		_put(sky, _at(Vector3(x, top + 0.05, -35.0)), _frame, false)
	for z: float in [-15.0, 3.0, 15.0]:
		for x: float in [-39.0, 39.0]:
			_put(sky, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, top + 0.05, z)), _frame, false)
	var mast := _lib("antenna/roof", func() -> PartShapes.PartShape:
			return WreckParts.antenna(7.0, 1.4))
	_put(mast, _at(Vector3(-46.0, top + 3.5, -42.0)), _parts, false)
	var box := _lib("switch_cabinet/roof", func() -> PartShapes.PartShape:
			return WreckParts.switch_cabinet())
	_put(box, _at(Vector3(-44.0, top + 0.7, -42.0)), _parts, false)


# --- The rooms ----------------------------------------------------------------------------

func _build_deliveries() -> void:
	# Dock shelters and bumpers round each truck door outside, a tread-plate leveller and a
	# dock lamp on a swing arm inside; a truck backed up to the south one.
	for z: float in [-8.0, 8.0]:
		var out := -YARD.x - WING - T * 0.5
		for k: float in [-1.0, 1.0]:
			_put(_box(Vector3(0.7, 5.6, 0.5)), _at(Vector3(out - 0.35, 2.9, z + 3.25 * k)), _rubber, false)
			_put(_box(Vector3(0.3, 0.45, 0.25)), _at(Vector3(out - 0.15, 1.25, z + 2.0 * k)), _rubber, false)
		_put(_box(Vector3(0.9, 0.7, 7.0)), _at(Vector3(out - 0.45, 6.45, z)), _rubber, false)
		_block(Vector3(-48.5, 0.03, z), Vector3(3.0, 0.06, 5.6), _paint(STEEL, 0.6, 0.5, "rubber_tread"), false)
		_block(Vector3(-47.0, 0.04, z), Vector3(0.1, 0.07, 5.6), _hazard, false)
		var arm := _lib("ibeam/dock_arm", func() -> PartShapes.PartShape:
				return PartShapes.i_beam(1.6, 0.06, 0.08))
		_put(arm, _at(Vector3(-48.9, 3.6, z - 3.9)), _frame, false)
		var head := _lib("headlamp/dock", func() -> PartShapes.PartShape:
				return WreckParts.headlamp_bar(0.6, 2, LAMP))
		_put(head, Transform3D(FACE_NX, Vector3(-48.1, 3.6, z - 3.9)), _parts, false)
	_truck(Vector3(-51.3, 0, 8))
	# Goods-in spots where deliveries are set down (StorageLayout.goods_in), numbered on the floor.
	var spot_line := _paint(Color(0.9, 0.9, 0.88), 0.0, 0.8)
	var spots: Array = StorageLayout.get_layout()["goods_in"]
	for i in spots.size():
		var at: Vector3 = spots[i]
		for dz: float in [-0.75, 0.75]:
			_block(at + Vector3(0, 0.024, dz), Vector3(1.6, 0.004, 0.06), spot_line, false)
		for dx: float in [-0.8, 0.8]:
			_block(at + Vector3(dx, 0.024, 0), Vector3(0.06, 0.004, 1.5), spot_line, false)
		var n := _tag("GI-%02d" % (i + 1), at + Vector3(0, 0.03, 0.95), 0.18, Vector3.ZERO)
		n.rotation = Vector3(-PI * 0.5, 0, 0)
	_sign("GOODS IN", Vector3(-40.8, 5.6, -23.6), 0.0, 0.45)
	# The goods-in desk with its screen, stool and a shelf behind.
	_put(_lib("cbox/desk", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(1.0, 1.05, 3.2), 0.04)), _at(Vector3(-31, 0.525, 14)), _paint(DARK, 0.3, 0.5, "satin_paint"))
	_put(_box(Vector3(1.1, 0.04, 3.3)), _at(Vector3(-31, 1.07, 14)), _paint(Color(0.7, 0.71, 0.7), 0.3, 0.4, "brushed_alloy"), false)
	_screen(Vector3(-30.6, 1.5, 14), "GOODS IN\nBAY 2  KESTREL\n4 PALLETS DUE", -PI * 0.5)
	_put(_lib("stool", func() -> PartShapes.PartShape: return WreckParts.stool()), _at(Vector3(-32.0, 0.375, 13.2)), _parts, false)
	for k in 2:
		_put(_lib("shelf_rack", func() -> PartShapes.PartShape: return WreckParts.shelf_rack()),
				_at(Vector3(-28.25 - 0.32, 1.0, 17.0 + k * 1.7), PI * 0.5), _parts)


## The storage hall, laid out by StorageLayout: four aisles of racking with a rack each side,
## the small-parts bins in D2, a bulk floor west of the racks, and the transfer aisle along
## the south wall. Every place is labelled with its location id and the part kept there.
## It starts empty; the goods on it are drawn from the bus (_refresh_stores).
func _build_stock() -> void:
	var layout := StorageLayout.get_layout()
	var locations: Dictionary = layout["locations"]
	var line := _paint(HAZARD, 0.0, 0.7, "hazard_paint")
	var white := _paint(Color(0.9, 0.9, 0.88), 0.0, 0.8)
	for rack: String in StorageLayout.rack_ids():
		_storage_rack(rack)
	# Lane lines down each aisle and along the transfer aisle and the back cross aisle.
	var rack_len := StorageLayout.BAYS * StorageLayout.BAY_LENGTH
	for aisle: String in layout["aisles"]:
		var x: float = layout["aisles"][aisle]
		for side: float in [-1.0, 1.0]:
			_block(Vector3(x + side * (StorageLayout.AISLE_WIDTH * 0.5 - 0.08), 0.024, StorageLayout.RACK_Z0 - rack_len * 0.5),
					Vector3(0.08, 0.004, rack_len), line, false)
		# Signs hang over the racks' tops, clear of the picking lift's mast; the letter is
		# painted on the floor at the aisle's mouth too.
		var sign := _sign("AISLE %s" % aisle, Vector3(x, 9.9, StorageLayout.RACK_Z0 + 0.2), 0.0, 0.45)
		sign.name = "AisleSign_" + aisle
		var letter := _tag(aisle, Vector3(x, 0.03, StorageLayout.RACK_Z0 + 1.0), 1.1, Vector3.ZERO)
		letter.rotation = Vector3(-PI * 0.5, 0, 0)
		letter.modulate = HAZARD
		var cats := PackedStringArray()
		for b: Dictionary in layout["bays"]:
			if str(b["rack"]).begins_with(aisle) and b["category"] != "":
				var n: String = StorageLayout.CATEGORIES.get(b["category"], str(b["category"]).capitalize())
				if not cats.has(n.to_upper()):
					cats.append(n.to_upper())
		if not cats.is_empty():
			_sign(" · ".join(cats), Vector3(x, 10.55, StorageLayout.RACK_Z0 + 0.2), 0.0, 0.2, false)
	for z: float in [StorageLayout.TRANSFER_Z - 1.4, StorageLayout.TRANSFER_Z + 1.4]:
		_block(Vector3(-25.0, 0.024, z), Vector3(49.0, 0.004, 0.08), line, false)
	_block(Vector3(-18.9, 0.024, StorageLayout.BACK_Z + 1.3), Vector3(21.0, 0.004, 0.08), line, false)
	# The bulk floor: painted bays with their ids on the floor and a sign over them.
	for id: String in locations:
		var l: Dictionary = locations[id]
		if l["kind"] != "bulk":
			continue
		var at: Vector3 = l["at"]
		var size: Vector3 = l["size"]
		for dz: float in [-0.5, 0.5]:
			_block(at + Vector3(0, 0.024, size.z * dz), Vector3(size.x, 0.004, 0.07), white, false)
		for dx: float in [-0.5, 0.5]:
			_block(at + Vector3(size.x * dx, 0.024, 0), Vector3(0.07, 0.004, size.z), white, false)
		var floor_id := _tag(id, at + Vector3(-float(l["face"].x) * 1.6, 0.03, 0), 0.32, Vector3.ZERO)
		floor_id.rotation = Vector3(-PI * 0.5, PI * 0.5 * float(l["face"].x), 0)
		_tag(_place_text(l), at + Vector3(float(l["face"].x) * (size.x * 0.5 + 0.125), 0.5, 0), 0.07, l["face"])
		_put(_box(Vector3(0.12, 0.7, 0.12)), _at(at + Vector3(float(l["face"].x) * (size.x * 0.5 + 0.06), 0.35, 0)), _hazard)
	_sign("BULK STORE  Z-01 - Z-18", Vector3(-39.5, 6.4, -27.6), 0.0, 0.45)
	# Small-parts shelving along the partition to Material prep.
	for i in 4:
		_put(_lib("shelf_rack", func() -> PartShapes.PartShape: return WreckParts.shelf_rack()),
				_at(Vector3(-0.62, 1.0, -44.6 + i * 1.7), PI * 0.5), _parts)


## One rack of StorageLayout: lattice end frames at each bay, orange beams and grating decks
## at each level, a location label on the beam under each place, a placard per bay.
func _storage_rack(rack: String) -> void:
	var L := StorageLayout
	var layout := L.get_layout()
	var x := L.rack_x(rack)
	var face := L.rack_face(rack)
	var depth := L.RACK_DEPTH
	var tall := L.RACK_HEIGHT
	var frame := _lib("truss/rack/%.1f/%.1f" % [tall, depth], func() -> PartShapes.PartShape:
			return PartShapes.truss(tall, 0.09, depth, 10, 0.05))
	var beam := _box(Vector3(0.05, 0.12, L.BAY_LENGTH - 0.1))
	var deck := _lib("grating/rack/%.2f/%.2f" % [depth, L.BAY_LENGTH], func() -> PartShapes.PartShape:
			return WreckParts.grating(depth - 0.06, L.BAY_LENGTH - 0.12, 0.03))
	# Lattice frame stood up: its length up (Y), its height across the rack (X).
	var stand := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	for i in L.BAYS + 1:
		var z := L.RACK_Z0 - i * L.BAY_LENGTH
		_put(frame, Transform3D(stand, Vector3(x, tall * 0.5, z)), _blue, false)
		for side: float in [-0.5, 0.5]:
			_put(_box(Vector3(0.16, 0.012, 0.16)), _at(Vector3(x + depth * side, 0.006, z)), _bare, false)
	for bay in range(1, L.BAYS + 1):
		var z := L.bay_z(bay)
		for level in range(1, L.LEVELS + 1):
			var y := L.BEAM_Y + (level - 1) * L.LEVEL_PITCH
			for side: float in [-0.5, 0.5]:
				_put(beam, _at(Vector3(x + depth * side, y, z)), _trim, false)
			if level > 1:
				_put(deck, _at(Vector3(x, y + 0.075, z)), _galv, false)
		var info: Dictionary = {}
		for b: Dictionary in layout["bays"]:
			if b["rack"] == rack and b["bay"] == bay:
				info = b
		var cat := str(info.get("category", ""))
		var title := "%s-%02d  %s" % [rack, bay, str(L.CATEGORIES.get(cat, cat)).to_upper() if cat != "" else "SPARE"]
		_tag(title, Vector3(x + face * (depth * 0.5 + 0.05), L.BEAM_Y + L.LEVELS * L.LEVEL_PITCH - 0.25, z), 0.11, Vector3(face, 0, 0))
	for id: String in layout["locations"]:
		var l: Dictionary = layout["locations"][id]
		if l["rack"] != rack:
			continue
		var at: Vector3 = l["at"]
		_tag(_place_text(l), Vector3(x + face * (depth * 0.5 + 0.04), at.y - 0.06, at.z), 0.045, Vector3(face, 0, 0))
	_collide_xf(_box_shape(Vector3(depth + 0.1, tall, L.BAYS * L.BAY_LENGTH)),
			_at(Vector3(x, tall * 0.5, L.RACK_Z0 - L.BAYS * L.BAY_LENGTH * 0.5)))


## "B2-03-4-1\nIon thruster" for a location; spare places show their id alone.
func _place_text(l: Dictionary) -> String:
	var home := str(l["home"])
	if home == "":
		return str(l["id"])
	var item: Dictionary = StorageLayout.items().get(home, {})
	return "%s\n%s" % [l["id"], item.get("name", home)]


## A small flat label facing `face` (Vector3.ZERO: left as made, for the caller to turn).
func _tag(text: String, at: Vector3, height_m: float, face: Vector3, parent: Node = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.outline_size = 6
	label.pixel_size = height_m / 48.0
	label.modulate = Color(0.95, 0.95, 0.9)
	label.outline_modulate = Color(0.03, 0.03, 0.04)
	label.shaded = false
	label.double_sided = false
	label.position = at
	if face != Vector3.ZERO:
		label.rotation.y = atan2(face.x, face.z)
	(parent if parent else _labels).add_child(label)
	return label


func _build_prep() -> void:
	var plate := _paint(STEEL, 0.75, 0.45, "bare_steel")
	# Plate stock in stacks on I-beam dunnage, by the door from Stock.
	var dunnage := _lib("ibeam/dunnage", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(1.5, 0.12, 0.18))
	var sheet := _box(Vector3(2.5, 0.025, 1.25))
	for i in 4:
		var at := Vector3(5 + i * 3.4, 0, -42)
		for k: float in [-0.9, 0.0, 0.9]:
			_put(dunnage, Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3(k, 0.09, 0)), _paint(DARK, 0.3, 0.6, "cast_iron"))
		for k in _rng.randi_range(4, 12):
			_put(sheet, _at(at + Vector3(_rng.randf_range(-0.05, 0.05), 0.195 + k * 0.03, 0)), plate, false)
	# A cantilever rack of pipe and bar.
	var arm := _box(Vector3(0.1, 0.08, 1.1))
	var post := _lib("ibeam/cantilever", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(2.6, 0.2, 0.25))
	for x: float in [5.0, 9.0, 13.0]:
		_put(post, Transform3D(UPRIGHT, Vector3(x, 1.3, -32.6)), _trim)
		_put(_box(Vector3(0.25, 0.08, 1.4)), _at(Vector3(x, 0.04, -32.2)), _trim)
		for k in 3:
			_put(arm, _at(Vector3(x, 0.5 + k * 0.75, -32.0)), _trim, false)
	for k in 3:
		var bar := _lib("pipe/bar/%d" % k, func() -> PartShapes.PartShape:
				return WreckParts.pipe(0.035 + 0.012 * k, 9.0, false))
		for p in 5:
			_put(bar, Transform3D(Y_TO_X, Vector3(9, 0.6 + k * 0.75, -32.35 + p * 0.17)), _paint(Color(0.7, 0.72, 0.74), 0.6, 0.4, "brushed_steel"), false)

	# A plasma cutting table: a steel bed of slats over a water tray, a gantry and its head.
	var table := Vector3(26, 0, -38)
	_put(_lib("cbox/plasma_tray", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(6.0, 0.75, 3.0), 0.03)), _at(table + Vector3(0, 0.375, 0)), _paint(DARK, 0.4, 0.6, "gunmetal"))
	var slat := _box(Vector3(0.03, 0.12, 2.9))
	for k in 24:
		_put(slat, _at(table + Vector3(-2.875 + k * 0.25, 0.81, 0)), plate, false)
	var rail := _lib("ibeam/plasma_rail", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(6.4, 0.12, 0.16))
	for side: float in [-1.0, 1.0]:
		_put(rail, _at(table + Vector3(0, 0.83, 1.6 * side)), _bare, false)
		_put(_lib("machine/plasma_carriage", func() -> PartShapes.PartShape:
				return WreckParts.machine_unit(Vector3(0.5, 1.1, 0.4))), _at(table + Vector3(-1.0, 1.45, 1.65 * side)), _parts, false)
	var bridge := _lib("ibeam/plasma_bridge", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(3.6, 0.22, 0.3))
	_put(bridge, Transform3D(Basis(Vector3.UP, PI * 0.5), table + Vector3(-1.0, 2.1, 0)), _trim, false)
	_put(_lib("jbox/torch", func() -> PartShapes.PartShape:
			return WreckParts.junction_box(Vector3(0.3, 0.4, 0.3))), _at(table + Vector3(-1.0, 1.75, 0.4)), _parts, false)
	_put(_lib("pipe/torch", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.03, 0.5, false)), _at(table + Vector3(-1.0, 1.3, 0.4)), _bare, false)
	_put(_box(Vector3(0.06, 0.06, 0.06)), _at(table + Vector3(-1.0, 1.02, 0.4)), _glow_mat(EDGE, 6.0), false)
	_put(_lib("cbox/plasma_desk", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.7, 1.1, 0.6), 0.03)), _at(table + Vector3(3.6, 0.55, -1.2)), _paint(DARK, 0.3, 0.5, "satin_paint"))
	_screen(table + Vector3(3.6, 1.5, -0.88), "PLASMA CUT\nPLATE 6MM\nNEST 3/8", 0.0)

	# A press brake and a saw with its roller table.
	_put(_lib("machine/press_brake", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(4.0, 2.6, 1.4), Color(1.0, 0.6, 0.15))), _at(Vector3(40, 1.3, -43.5), PI), _paint(BLUE, 0.35, 0.5))
	_put(_lib("machine/saw", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(1.6, 1.4, 1.2))), _at(Vector3(44, 0.7, -30), -PI * 0.5), _paint(BLUE, 0.35, 0.5))
	var roller := _lib("pipe/roller", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.05, 0.7, false))
	for k in 10:
		_put(roller, Transform3D(Y_TO_Z, Vector3(41.6 - k * 0.4, 0.9, -30)), _bare, false)
	var leg := _box(Vector3(0.06, 0.88, 0.06))
	for x: float in [37.8, 41.6]:
		for s: float in [-0.35, 0.35]:
			_put(leg, _at(Vector3(x, 0.44, -30 + s)), _frame, false)
	_put(_box(Vector3(4.0, 0.08, 0.06)), _at(Vector3(39.8, 0.86, -30.36)), _frame, false)
	_put(_box(Vector3(4.0, 0.08, 0.06)), _at(Vector3(39.8, 0.86, -29.64)), _frame, false)

	# A welding bay: orange screens on a pipe frame round a bench.
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.95, 0.4, 0.08, 0.55)
	screen.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	screen.roughness = 0.6
	screen.cull_mode = BaseMaterial3D.CULL_DISABLED
	var frame_pipe := _lib("pipe/screen", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.025, 2.0, false))
	for s: Array in [[Vector3(30.5, 0, -27.5), 0.0], [Vector3(33.5, 0, -27.5), 0.0], [Vector3(35.0, 0, -29.0), PI * 0.5]]:
		var basis := Basis(Vector3.UP, s[1])
		var p: Vector3 = s[0]
		_put(_box(Vector3(2.9, 1.7, 0.01)), Transform3D(basis, p + Vector3(0, 1.1, 0)), screen, false)
		for k: float in [-1.45, 1.45]:
			_put(frame_pipe, Transform3D(basis, p + basis * Vector3(k, 1.0, 0)), _galv, false)
			_put(_box(Vector3(0.5, 0.04, 0.04)), Transform3D(basis * Basis(Vector3.UP, PI * 0.5), p + basis * Vector3(k, 0.02, 0)), _galv, false)
	_put(_lib("workbench", func() -> PartShapes.PartShape: return WreckParts.workbench()), _at(Vector3(32.0, 0.975, -30.0), PI), _parts)
	_put(_lib("machine/welder", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(0.6, 0.9, 0.8), Color(0.3, 0.7, 1.0))), _at(Vector3(34.0, 0.45, -30.3)), _paint(BLUE, 0.35, 0.5))
	# Benches along the courtyard wall, either side of the door.
	for x: float in [6.0, 24.0]:
		_put(_lib("workbench", func() -> PartShapes.PartShape: return WreckParts.workbench()), _at(Vector3(x, 0.975, -25.1)), _parts)


func _build_preassembly() -> void:
	# Assembly jigs: an I-beam base frame, posts and top rails round a module going together.
	var post := _lib("ibeam/jig_post", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(3.5, 0.25, 0.25))
	var rail_x := _lib("ibeam/jig_x", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(5.25, 0.22, 0.25))
	var rail_z := _lib("ibeam/jig_z", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(6.25, 0.22, 0.25))
	for z: float in [-14.0, 6.0]:
		var at := Vector3(42, 0, z)
		for corner: Vector3 in [Vector3(-2.5, 0, -3), Vector3(2.5, 0, -3), Vector3(-2.5, 0, 3), Vector3(2.5, 0, 3)]:
			_put(post, Transform3D(UPRIGHT, at + corner + Vector3(0, 1.75, 0)), _trim)
			_put(_box(Vector3(0.5, 0.03, 0.5)), _at(at + corner + Vector3(0, 0.015, 0)), _bare, false)
		for y: float in [0.13, 3.4]:
			for side: float in [-3.0, 3.0]:
				_put(rail_x, _at(at + Vector3(0, y, side)), _trim, false)
			for side: float in [-2.5, 2.5]:
				_put(rail_z, Transform3D(Basis(Vector3.UP, PI * 0.5), at + Vector3(side, y, 0)), _trim, false)
	# In the north jig an engine module (a cowl, a tank and a bell, like the Kestrel's) on a
	# stand; in the south a frame section going together.
	var engine := Vector3(42, 0, -14)
	_put(_lib("cbox/engine_stand", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(2.0, 1.1, 3.0), 0.05)), _at(engine + Vector3(0, 0.55, 0)), _paint(DARK, 0.4, 0.5, "gunmetal"))
	_put(_lib("tank/engine", func() -> PartShapes.PartShape: return WreckParts.tank(0.7, 2.2)),
			Transform3D(Y_TO_Z, engine + Vector3(0, 1.85, -0.4)), _parts, false)
	_put(_lib("engine_bell/module", func() -> PartShapes.PartShape: return WreckParts.engine_bell(0.8, 1.6)),
			Transform3D(Y_TO_Z, engine + Vector3(0, 1.85, 1.5)), _parts, false)
	_put(_lib("generator/engine", func() -> PartShapes.PartShape:
			return WreckParts.generator(Vector3(1.2, 0.8, 1.0))), _at(engine + Vector3(0, 1.5, -2.0)), _parts, false)
	var net := Vector3(42, 0, 6)
	var member := _lib("ibeam/frame_member", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(3.6, 0.1, 0.16))
	var upright := _lib("ibeam/frame_upright", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(2.6, 0.1, 0.16))
	for k in 4:
		_put(member, _at(net + Vector3(0, 0.6 + k * 0.8, 0)), _galv, false)
	for k in 5:
		_put(upright, Transform3D(UPRIGHT, net + Vector3(-1.75 + k * 0.875, 1.8, 0)), _galv, false)
	_put(_lib("window/section", func() -> PartShapes.PartShape:
			return PartShapes.window_rect(1.4, 0.9, 0.06)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), net + Vector3(0, 2.2, 0.12)), _frame, false)
	# A jib crane: a column, a boom, a hoist and its hook.
	var jib := Vector3(48.5, 0, -4)
	_put(_lib("ibeam/jib_col", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(7.0, 0.4, 0.5)), Transform3D(UPRIGHT, jib + Vector3(0, 3.5, 0)), _hazard)
	_put(_lib("ibeam/jib_boom", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(6.0, 0.25, 0.4)), _at(jib + Vector3(-3.0, 6.6, 0)), _hazard, false)
	_put(_lib("jbox/hoist", func() -> PartShapes.PartShape:
			return WreckParts.junction_box(Vector3(0.5, 0.45, 0.4), Color(1.0, 0.6, 0.15))), _at(jib + Vector3(-4.6, 6.1, 0)), _parts, false)
	_put(_lib("pipe/hoist_cable", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.012, 1.8, false)), _at(jib + Vector3(-4.6, 4.95, 0)), _frame, false)
	_put(_lib("cbox/hook", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.3, 0.35, 0.22), 0.04)), _at(jib + Vector3(-4.6, 3.9, 0)), _hazard, false)
	_put(_lib("ring/hook", func() -> PartShapes.PartShape:
			return PartShapes.ring(0.08, 0.13, 0.05)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), jib + Vector3(-4.6, 3.6, 0)), _bare, false)
	# Benches and shelving along the east wall, a tank module on a cradle, a parts cart.
	for z: float in [16.0, 19.0]:
		_put(_lib("workbench", func() -> PartShapes.PartShape: return WreckParts.workbench()),
				_at(Vector3(49.35, 0.975, z), PI * 0.5), _parts)
	for i in 3:
		_put(_lib("shelf_rack", func() -> PartShapes.PartShape: return WreckParts.shelf_rack()),
				_at(Vector3(49.44, 1.0, 10.0 + i * 1.7), PI * 0.5), _parts)
	_put(_lib("tank/module", func() -> PartShapes.PartShape: return WreckParts.tank(0.8, 3.2)),
			Transform3D(Y_TO_Z, Vector3(38, 1.25, 18)), _parts)
	for k: float in [-1.0, 1.0]:
		_put(_box(Vector3(1.6, 0.45, 0.3)), _at(Vector3(38, 0.225, 18 + k * 1.0)), _trim)
	_cart(Vector3(33, 0, 14))


func _build_courtyard() -> void:
	# The slab, its joints, bay markings round the cradles and hazard lines across the open
	# end, a drain along it.
	_block(Vector3(0, -0.015, 0), Vector3(YARD.x * 2.0, 0.03, YARD.y * 2.0), _concrete, false)
	_slab_joints(Rect2(-YARD.x, -YARD.y, YARD.x * 2.0, YARD.y * 2.0), 0.0)
	var paint := _paint(HAZARD, 0.0, 0.7, "satin_paint")
	var mark := Rect2(-9, -10, 18, 22)
	for z: float in [mark.position.y, mark.end.y]:
		_block(Vector3(0, 0.01, z), Vector3(mark.size.x, 0.01, 0.3), paint, false)
	for x: float in [mark.position.x, mark.end.x]:
		_block(Vector3(x, 0.01, mark.get_center().y), Vector3(0.3, 0.01, mark.size.y), paint, false)
	var chevron := _box(Vector3(1.6, 0.01, 0.35))
	for corner: Vector2 in [mark.position, Vector2(mark.end.x, mark.position.y), Vector2(mark.position.x, mark.end.y), mark.end]:
		for k in 3:
			var inward := Vector2(-signf(corner.x), -signf(corner.y - mark.get_center().y))
			var p := corner + inward * (0.9 + k * 0.8)
			_put(chevron, Transform3D(Basis(Vector3.UP, PI * 0.25 * signf(inward.x * inward.y)), Vector3(p.x, 0.011, p.y)), paint, false)
	var bay_label := Label3D.new()
	bay_label.text = "BAY 1"
	bay_label.font_size = 96
	bay_label.pixel_size = 1.6 / 96.0
	bay_label.modulate = HAZARD
	bay_label.outline_size = 0
	bay_label.position = Vector3(0, 0.02, mark.end.y + 1.6)
	bay_label.rotation = Vector3(-PI * 0.5, 0, 0)
	add_child(bay_label)
	var stripe := _box(Vector3(1.0, 0.01, 0.6))
	for i in 28:
		_put(stripe, _at(Vector3(-27 + i * 2.0, 0.01, YARD.y - 0.5)), paint, false)
	var drain := _lib("grating/drain", func() -> PartShapes.PartShape:
			return WreckParts.grating(0.5, 54.0, 0.04))
	_put(drain, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.0, YARD.y - 1.5)), _galv, false)
	# Tie-down rings round the bay and a power pedestal at each corner.
	var ring := _lib("ring/tie_down", func() -> PartShapes.PartShape:
			return PartShapes.ring(0.1, 0.17, 0.04))
	for x: float in [-6.0, 6.0]:
		for z: float in [-8.0, -2.0, 4.0, 10.0]:
			_put(ring, _at(Vector3(x, 0.02, z)), _bare, false)
	var pedestal := _lib("switch_cabinet/pedestal", func() -> PartShapes.PartShape:
			return WreckParts.switch_cabinet(Vector3(0.7, 1.4, 0.4), Color(1.0, 0.6, 0.15)))
	for x: float in [-11.0, 11.0]:
		for z: float in [-11.5, 13.5]:
			_put(pedestal, _at(Vector3(x, 0.7, z), 0.0 if z > 0.0 else PI), _paint(Color(0.34, 0.37, 0.4), 0.35, 0.5))
			_put(_box(Vector3(1.0, 0.1, 0.7)), _at(Vector3(x, 0.05, z)), _hazard, false)
	# Bollards along the apron edge.
	var bollard := _lib("prism/bollard", func() -> PartShapes.PartShape:
			return PartShapes.prism(12, 0.16, 1.0))
	var band := _lib("prism/bollard_band", func() -> PartShapes.PartShape:
			return PartShapes.prism(12, 0.165, 0.12))
	for i in 6:
		var p := Vector3(-25 + i * 10.0, 0.5, YARD.y + 1.2)
		_put(bollard, _at(p), _hazard)
		_put(band, _at(p + Vector3(0, 0.3, 0)), _glow_mat(Color(1.0, 0.9, 0.7), 0.6), false)
	_cart(Vector3(20, 0, 4))


## The gantry crane: runway columns standing in the courtyard's corners carrying lattice
## runway girders along the side wings, a bridge of two trusses across with a walkway, end
## trucks, a trolley, its hoist line and hook block over the ship.
func _build_crane() -> void:
	var top := H + 3.0
	var col := _lib("ibeam/runway_col", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(top, 0.55, 0.65, 0.04))
	var girder := _lib("truss/runway", func() -> PartShapes.PartShape:
			return PartShapes.truss(YARD.y * 2.0 - 2.0, 0.6, 1.6, 12, 0.1))
	var rail := _lib("ibeam/crane_rail", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(YARD.y * 2.0 - 2.0, 0.2, 0.18))
	for x: float in [-YARD.x + 1.4, YARD.x - 1.4]:
		for z: float in [-21.0, -12.0, 12.0, 21.0]:
			_put(col, Transform3D(UPRIGHT, Vector3(x, top * 0.5, z)), _hazard)
			_put(_box(Vector3(1.0, 0.06, 1.0)), _at(Vector3(x, 0.03, z)), _bare, false)
		_put(girder, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x, top + 0.8, 0)), _hazard, false)
		_put(rail, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x, top + 1.69, 0)), _bare, false)
	var bridge_z := -3.0
	var span := YARD.x * 2.0 - 1.2
	var bridge := _lib("truss/bridge", func() -> PartShapes.PartShape:
			return PartShapes.truss(span, 0.4, 1.8, 16, 0.1))
	for k: float in [-1.0, 1.0]:
		_put(bridge, _at(Vector3(0, top + 2.9, bridge_z + 0.9 * k)), _hazard, false)
	var deck := _lib("grating/bridge", func() -> PartShapes.PartShape:
			return WreckParts.grating(1.4, span - 2.0))
	_put(deck, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, top + 3.82, bridge_z)), _galv, false)
	var railing := _lib("railing/bridge", func() -> PartShapes.PartShape:
			return WreckParts.railing(4.0))
	var x := -span * 0.5 + 3.0
	while x < span * 0.5 - 2.0:
		_put(railing, _at(Vector3(x, top + 4.37, bridge_z - 0.68)), _hazard, false)
		x += 4.0
	var truck := _lib("machine/end_truck", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(1.0, 0.9, 3.4), Color(1.0, 0.6, 0.15)))
	for side: float in [-1.0, 1.0]:
		_put(truck, _at(Vector3(side * (YARD.x - 1.4), top + 2.25, bridge_z)), _paint(HAZARD, 0.3, 0.5), false)
	var trolley := _lib("machine/trolley", func() -> PartShapes.PartShape:
			return WreckParts.machine_unit(Vector3(2.2, 1.1, 2.6)))
	_put(trolley, _at(Vector3(4, top + 4.4, bridge_z), PI * 0.5), _paint(HAZARD, 0.3, 0.5), false)
	var cable_len := top + 3.8 - 8.4
	var cable := _lib("pipe/crane_cable", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.025, cable_len, false))
	for k: float in [-0.15, 0.15]:
		_put(cable, _at(Vector3(4 + k, 8.4 + cable_len * 0.5, bridge_z)), _frame, false)
	_put(_lib("cbox/hook_block", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.7, 0.8, 0.4), 0.06)), _at(Vector3(4, 8.0, bridge_z)), _hazard, false)
	_put(_lib("ring/crane_hook", func() -> PartShapes.PartShape:
			return PartShapes.ring(0.16, 0.26, 0.1)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(4, 7.3, bridge_z)), _bare, false)


## Dock 1, after a planetary shipyard's dry docks: an overlook balcony on the north wall with a
## stair down into the courtyard, and launch towers out on the plain. Work at height on the
## ship is done from the scissor lift (and mobile scaffolds), which drive out of the way, so
## the dock has no fixed gantries: it takes ships much bigger than the Kestrel.
const DOCK := "D1"
const OVERLOOK := Rect2(-8.0, -23.75, 16.0, 1.8)   # x, z, length, depth of the balcony
const OVERLOOK_Y := 5.2


func _build_dock() -> void:
	_build_overlook()
	_build_launch_towers()


## A railed balcony along the courtyard's north wall under the name board, on brackets,
## with a stair down to the courtyard at its west end, lamps over it.
func _build_overlook() -> void:
	var o := OVERLOOK
	var cx := o.position.x + o.size.x * 0.5
	var cz := o.position.y + o.size.y * 0.5
	_put(_lib("grating/overlook", func() -> PartShapes.PartShape:
			return WreckParts.grating(o.size.y, o.size.x, 0.08)), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(cx, OVERLOOK_Y, cz)), _galv, false)
	_collide(Vector3(cx, OVERLOOK_Y - 0.04, cz), Vector3(o.size.x, 0.1, o.size.y))
	# The edge beam, brackets back to the wall, the guard rail along the front and the east end.
	_put(_box(Vector3(o.size.x, 0.3, 0.2)), _at(Vector3(cx, OVERLOOK_Y - 0.2, o.end.y - 0.1)), _trim, false)
	var x := o.position.x + 1.0
	while x < o.end.x:
		_put(_box(Vector3(0.12, 1.2, 0.12)), Transform3D(Basis(Vector3.RIGHT, -0.75), Vector3(x, OVERLOOK_Y - 0.7, o.position.y + 0.55)), _frame, false)
		x += 3.0
	var guard := _lib("railing/overlook", func() -> PartShapes.PartShape:
			return WreckParts.railing(4.0, 1.1))
	x = o.position.x + 2.0 + 1.3
	while x < o.end.x - 1.0:
		_put(guard, _at(Vector3(x, OVERLOOK_Y + 0.55, o.end.y - 0.05)), _hazard, false)
		x += 4.0
	_put(_lib("railing/overlook_end", func() -> PartShapes.PartShape:
			return WreckParts.railing(o.size.y, 1.1)), _at(Vector3(o.end.x - 0.05, OVERLOOK_Y + 0.55, cz), PI * 0.5), _hazard, false)
	_collide(Vector3(cx + 1.3, OVERLOOK_Y + 0.55, o.end.y - 0.05), Vector3(o.size.x - 2.6, 1.1, 0.06))
	_collide(Vector3(o.end.x - 0.05, OVERLOOK_Y + 0.55, cz), Vector3(0.06, 1.1, o.size.y))
	# The stair: down from the west end towards the bay, its top at the balcony's front edge.
	var run := OVERLOOK_Y / 0.72
	var width := 1.3
	var stair := _lib("stair/overlook", func() -> PartShapes.PartShape:
			return WreckParts.stair(width, OVERLOOK_Y, run))
	var sx := o.position.x + width * 0.5
	_put(stair, Transform3D(Basis.IDENTITY, Vector3(sx, OVERLOOK_Y * 0.5, o.end.y + run * 0.5)), _galv)
	var side_rail := _lib("railing/overlook_stair", func() -> PartShapes.PartShape:
			return WreckParts.railing(sqrt(run * run + OVERLOOK_Y * OVERLOOK_Y), 1.0))
	var pitch := atan2(OVERLOOK_Y, run)
	for k: float in [-1.0, 1.0]:
		var basis := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.BACK, -pitch)
		_put(side_rail, Transform3D(basis, Vector3(sx + k * (width * 0.5 + 0.03), OVERLOOK_Y * 0.5 + 0.55, o.end.y + run * 0.5)), _hazard, false)
	# Lamps under the name board light the balcony.
	for lx: float in [-5.0, 0.0, 5.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, OVERLOOK_Y + 2.4, o.position.y + 0.6)
		lamp.light_color = LAMP
		lamp.light_energy = 1.2
		lamp.omni_range = 5.0
		lamp.set_meta("gfx_no_shadow", true)
		add_child(lamp)
		_night(lamp)
		_put(_box(Vector3(0.5, 0.08, 0.25)), _at(Vector3(lx, OVERLOOK_Y + 2.5, o.position.y + 0.25)), _glow_mat(LAMP, 2.0), false)


## Launch towers far out on the plain to the north, each with a ship standing in it: a
## lattice tower with swing arms, a white hull with an orange band and a nose cone, a red
## beacon on top. Scenery only (no collision).
func _build_launch_towers() -> void:
	var sites := [[Vector3(-160, 0, -460), 72.0], [Vector3(90, 0, -380), 56.0], [Vector3(260, 0, -520), 84.0]]
	var hull := _paint(SHELL, 0.1, 0.45, "gloss_paint")
	var beacon := _glow_mat(Color(1.0, 0.15, 0.1), 6.0)
	for site: Array in sites:
		var at: Vector3 = site[0]
		var h: float = site[1]
		var key := "truss/launch_%d" % int(h)
		_put(_lib(key, func() -> PartShapes.PartShape:
				return PartShapes.truss(h, 6.0, 6.0, int(h / 6.0), 0.5)), Transform3D(UPRIGHT, at + Vector3(12, h * 0.5, 0)), _trim, false)
		_put(_box(Vector3(30, 2.0, 30)), _at(at + Vector3(4, 1.0, 0)), _concrete, false)
		var ship_h := h * 0.82
		var r := ship_h * 0.07
		_put(_lib("cyl/launch_%d" % int(h), func() -> PartShapes.PartShape:
				return PartShapes.prism(24, r, ship_h * 0.8)), _at(at + Vector3(0, 2.0 + ship_h * 0.4, 0)), hull, false)
		_put(_lib("cyl/launch_band_%d" % int(h), func() -> PartShapes.PartShape:
				return PartShapes.prism(24, r * 1.02, ship_h * 0.08)), _at(at + Vector3(0, 2.0 + ship_h * 0.55, 0)), _trim, false)
		_put(_lib("cone/launch_%d" % int(h), func() -> PartShapes.PartShape:
				return PartShapes.frustum(r, r * 0.08, ship_h * 0.2, 24)), _at(at + Vector3(0, 2.0 + ship_h * 0.9, 0)), hull, false)
		for k in 3:
			var y := h * (0.35 + k * 0.22)
			_put(_box(Vector3(9.0, 1.2, 2.0)), _at(at + Vector3(6.5, y, 0)), _trim, false)
		_put(_box(Vector3(1.2, 1.2, 1.2)), _at(at + Vector3(12, h + 1.0, 0)), beacon, false)


## Outside: floodlight masts at the open corners aimed at the bay, a tank farm and power
## plant off the east wall, landing lights down the apron.
func _build_outside() -> void:
	var lattice := _lib("truss/mast", func() -> PartShapes.PartShape:
			return PartShapes.truss(15.0, 0.6, 0.6, 10, 0.06))
	var head := _lib("headlamp/flood", func() -> PartShapes.PartShape:
			return WreckParts.headlamp_bar(2.4, 4, LAMP))
	var platform := _lib("grating/mast", func() -> PartShapes.PartShape:
			return WreckParts.grating(1.6, 1.6))
	var ladder := _lib("ladder/mast", func() -> PartShapes.PartShape:
			return WreckParts.ladder(14.6, 0.45))
	for x: float in [-YARD.x - 2.0, YARD.x + 2.0]:
		var foot := Vector3(x, 0, YARD.y + 3.0)
		_put(lattice, Transform3D(UPRIGHT, foot + Vector3(0, 7.5, 0)), _galv)
		_put(_box(Vector3(1.4, 0.4, 1.4)), _at(foot + Vector3(0, 0.2, 0)), _concrete)
		_put(platform, _at(foot + Vector3(0, 15.0, 0)), _galv, false)
		_put(ladder, _at(foot + Vector3(0, 7.3, 0.36)), _galv, false)
		var aim := (Vector3(0, 2.0, 0) - (foot + Vector3(0, 15.6, 0))).normalized()
		var basis := Basis.looking_at(aim, Vector3.UP)
		# The bar's lamps face +Y: tip it so they face the bay.
		_put(head, Transform3D(basis * Basis(Vector3.RIGHT, -PI * 0.5), foot + Vector3(0, 15.6, -0.3)), _parts, false)
		var flood := SpotLight3D.new()
		flood.position = foot + Vector3(0, 15.4, -0.5)
		flood.light_color = LAMP
		flood.light_energy = 10.0
		flood.spot_range = 55.0
		flood.spot_angle = 30.0
		flood.set_meta("gfx_no_shadow", true)
		add_child(flood)
		flood.look_at(Vector3(0, 2.0, 0))
		_night(flood)

	# The tank farm: three upright tanks on plinths, piped to a manifold, with a fence.
	var tank := _lib("tank/farm", func() -> PartShapes.PartShape: return WreckParts.tank(1.5, 7.0))
	for i in 3:
		var p := Vector3(57.0, 0, -32.0 + i * 4.5)
		_put(_box(Vector3(3.6, 0.3, 3.6)), _at(p + Vector3(0, 0.15, 0)), _concrete)
		_put(tank, _at(p + Vector3(0, 3.8, 0)), _parts)
		_put(_lib("pipe/farm_drop", func() -> PartShapes.PartShape:
				return WreckParts.pipe(0.09, 1.2)), _at(p + Vector3(-1.7, 0.9, 0)), _galv, false)
	_put(_lib("pipe/farm_main", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.12, 11.0)), Transform3D(Y_TO_Z, Vector3(55.3, 0.4, -27.5)), _galv, false)
	_put(_lib("pipe/farm_in", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.12, 5.0)), Transform3D(Y_TO_X, Vector3(52.8, 0.4, -22.0)), _galv, false)
	var fence := _lib("railing/fence", func() -> PartShapes.PartShape: return WreckParts.railing(3.0, 1.6))
	for i in 5:
		_put(fence, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(60.5, 0.8, -34.0 + i * 3.0)), _galv, false)
	# Two generator sets behind the north-east corner.
	for i in 2:
		_put(_lib("generator/plant", func() -> PartShapes.PartShape:
				return WreckParts.generator(Vector3(2.6, 2.2, 4.4))), _at(Vector3(56.5 + i * 3.6, 1.1, -42.0)), _parts)
		_put(_box(Vector3(3.2, 0.2, 5.0)), _at(Vector3(56.5 + i * 3.6, 0.1, -42.0)), _concrete, false)
	# Landing lights in the apron, down the middle and along its edges.
	var stud := _box(Vector3(0.3, 0.04, 0.3))
	var lit := _glow_mat(Color(1.0, 0.85, 0.5), 3.0)
	var z := 30.0
	while z < 86.0:
		_put(stud, _at(Vector3(0, 0.02, z)), lit, false)
		for x: float in [-40.0, 40.0]:
			_put(stud, _at(Vector3(x, 0.02, z)), _glow_mat(Color(0.4, 0.86, 1.0), 3.0), false)
		z += 4.0


# --- Props --------------------------------------------------------------------------------

## A hover truck backed up to a dock: its cargo pod's doors at `rear` (the pod runs off
## towards -X), floating on a spine of lift pads with a cab ahead of it: a rounded nose with
## a wrap-round windscreen, Void Salvage's lit edge strip down both sides, running lamps.
func _truck(rear: Vector3) -> void:
	const FLOAT := 0.7   # the spine's underside over the ground, metres
	var pod := _lib("container/hover_pod", func() -> PartShapes.PartShape:
			return WreckParts.container(Vector3(2.5, 2.7, 12.0), TRIM))
	var c := rear + Vector3(-6.05, 0, 0)
	_put(pod, Transform3D(Basis(Vector3.UP, PI * 0.5), c + Vector3(0, FLOAT + 0.45 + 1.35, 0)), _parts)
	var paint := _paint(Color(0.9, 0.91, 0.9), 0.2, 0.4, "gloss_paint")
	# The spine under the pod and cab, its lift pads glowing blue underneath.
	_put(_lib("cbox/hover_spine", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(17.0, 0.45, 2.2), 0.12)), _at(rear + Vector3(-8.5, FLOAT + 0.22, 0)), _frame, false)
	var pad := _lib("prism/hover_pad", func() -> PartShapes.PartShape:
			return PartShapes.prism(16, 0.42, 0.08))
	var glow := _glow_mat(EDGE, 4.0)
	for x: float in [-1.6, -5.0, -8.4, -11.8, -15.4]:
		for side: float in [-0.6, 0.6]:
			_put(pad, _at(rear + Vector3(x, FLOAT - 0.04, side)), glow, false)
	for x: float in [-3.3, -10.1]:
		var lift := OmniLight3D.new()
		lift.position = rear + Vector3(x, 0.25, 0)
		lift.light_color = EDGE
		lift.light_energy = 1.4
		lift.omni_range = 3.0
		lift.set_meta("gfx_no_shadow", true)
		add_child(lift)
	_put(_box(Vector3(0.15, 0.25, 2.5)), _at(rear + Vector3(0.0, FLOAT + 0.3, 0)), _hazard, false)
	# The cab: a rounded body, a raked nose, the windscreen wrapping round it.
	var cab := rear + Vector3(-15.6, 0, 0)
	_put(_lib("cbox/hover_cab", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(3.0, 2.3, 2.5), 0.45)), _at(cab + Vector3(0.2, FLOAT + 0.45 + 1.15, 0)), paint)
	_put(_lib("wedge/hover_nose", func() -> PartShapes.PartShape:
			return PartShapes.wedge(Vector3(2.4, 1.2, 1.4))), Transform3D(Basis(Vector3.UP, -PI * 0.5), cab + Vector3(-1.95, FLOAT + 0.45 + 0.6, 0)), paint, false)
	_put(_lib("window/hover_screen", func() -> PartShapes.PartShape:
			return PartShapes.window_rect(2.2, 0.9, 0.06)), Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5 - 0.5), cab + Vector3(-1.38, FLOAT + 0.45 + 1.75, 0)), _frame, false)
	for side: float in [-1.0, 1.0]:
		_put(_lib("window/hover_side", func() -> PartShapes.PartShape:
				return PartShapes.window_rect(1.3, 0.65, 0.05)), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), cab + Vector3(-0.3, FLOAT + 0.45 + 1.75, 1.26 * side)), _frame, false)
		# The lit edge strip down the cab and the pod.
		_put(_box(Vector3(16.6, 0.06, 0.04)), _at(rear + Vector3(-8.5, FLOAT + 0.47, 1.12 * side)), glow, false)
	_put(_lib("headlamp/hover_truck", func() -> PartShapes.PartShape:
			return WreckParts.headlamp_bar(2.0, 4, LAMP)), Transform3D(FACE_NX, cab + Vector3(-2.62, FLOAT + 0.75, 0)), _parts, false)
	_put(_box(Vector3(0.1, 0.1, 2.2)), _at(rear + Vector3(0.02, FLOAT + 3.4, 0)), _glow_mat(Color(1.0, 0.2, 0.1), 3.0), false)
	_collide_xf(_box_shape(Vector3(17.6, 3.2, 2.6)), _at(rear + Vector3(-8.6, FLOAT + 1.6, 0)))
	_sign("BSX", c + Vector3(0, FLOAT + 2.0, 1.29), 0.0, 1.2, false).modulate = TRIM


## One of a few crate sizes from the parts library, as a shape key.
func _crate_key(i: int) -> String:
	var sizes: Array[Vector3] = [Vector3(1.0, 0.8, 0.9), Vector3(1.1, 0.55, 0.9), Vector3(0.8, 0.65, 0.8), Vector3(1.2, 1.1, 1.0)]
	var s := sizes[i]
	return _lib("crate/%d" % i, func() -> PartShapes.PartShape: return WreckParts.cargo_crate(s))


## A parts cart: a grating deck on a steel frame, castors and a crate.
func _cart(at: Vector3) -> void:
	_put(_lib("grating/cart", func() -> PartShapes.PartShape: return WreckParts.grating(1.4, 2.2)), _at(at + Vector3(0, 0.62, 0)), _galv)
	var leg := _box(Vector3(0.05, 0.5, 0.05))
	var castor := _lib("prism/castor", func() -> PartShapes.PartShape: return PartShapes.prism(10, 0.07, 0.05))
	for x: float in [-0.65, 0.65]:
		for z: float in [-1.05, 1.05]:
			_put(leg, _at(at + Vector3(x, 0.35, z)), _galv, false)
			_put(castor, Transform3D(Y_TO_X, at + Vector3(x, 0.07, z)), _rubber, false)
	_put(_lib("pipe/cart_handle", func() -> PartShapes.PartShape: return WreckParts.pipe(0.02, 1.3, false)),
			Transform3D(Y_TO_X, at + Vector3(0, 1.05, 1.1)), _galv, false)
	var crate := _crate_key(2)
	_put(crate, _at(at + Vector3(0, 0.66 + 0.325, -0.4)), _goods[0], false)


## A small lit screen facing `yaw`, like TradesLook.readout.
func _screen(at: Vector3, text: String, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = yaw
	add_child(holder)
	_put(_lib("cbox/screen", func() -> PartShapes.PartShape:
			return PartShapes.chamfer_box(Vector3(0.95, 0.6, 0.06), 0.015)), Transform3D(Basis(Vector3.UP, yaw), at), _frame, false)
	_put(_box(Vector3(0.86, 0.5, 0.01)), Transform3D(Basis(Vector3.UP, yaw), at + Basis(Vector3.UP, yaw).z * 0.031),
			_paint(Color(0.02, 0.03, 0.04), 0.0, 0.25), false)
	var label := Label3D.new()
	label.text = text
	label.font_size = 32
	label.pixel_size = 0.0045
	label.modulate = Color(0.45, 0.95, 1.0)
	label.outline_size = 0
	label.shaded = false
	label.position.z = 0.04
	holder.add_child(label)


# --- The stores -------------------------------------------------------------------------

## Redraws what the bus says is in the stores: a tote, a crate on a pallet or a big crate
## on each location that holds goods, and each delivered crate on its goods-in spot,
## labelled with what it holds and where it is going.
func _refresh_stores() -> void:
	for c in _stores.get_children():
		c.free()
	if _bus == null:
		return
	var locations: Dictionary = StorageLayout.get_layout()["locations"]
	var batches := {}
	for loc: String in locations:
		var have := _bus.stock_at(loc)
		if have.is_empty():
			continue
		var l: Dictionary = locations[loc]
		var item: Dictionary = StorageLayout.items().get(have["item"], {})
		_goods_box(batches, l["kind"], float(item.get("mass", 0.0)), str(item.get("category", "")), l["at"])
		var tag := _tag("%s  x%d" % [item.get("name", have["item"]), int(have["qty"])],
				l["at"] + Vector3(float(l["face"].x) * (float(l["size"].x) * 0.5 + 0.06), 0.55 if l["kind"] != "bulk" else 1.4, 0), 0.06, l["face"], _stores)
	var crates := _bus.delivered_crates()
	for id: String in crates:
		var c: Dictionary = crates[id]
		if str(c.get("carrier", "")) != "":
			continue   # on a trolley's deck: the trolley draws it
		var at := _bus.crate_position(id)
		var kind := StorageLayout.kind_for(float(c["mass"]))
		var cat := str(StorageLayout.items().get(c["item"], {}).get("category", ""))
		var h := _goods_box(batches, "pallet" if kind == "bin" else kind, float(c["mass"]) * (int(c["qty"]) if kind == "bin" else 1), cat, at)
		var dest := _bus.place_for(str(c["item"]))
		var tag := _tag("%s  x%d\n%s  ->  %s" % [c["name"], int(c["qty"]), str(c["grade"]).to_upper(), dest if dest != "" else "NO SPACE"],
				at + Vector3(0, h + 0.25, 0), 0.09, Vector3(0, 0, 1), _stores)
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.name = "Crate_" + id.replace("/", "_")
	for batch: Dictionary in batches.values():
		_multimesh(_stores, (_shapes[batch.key] as PartShapes.PartShape).mesh, batch.xforms, batch.mat)


## Adds the look of goods of one kind to `batches`: a tote (bin), a crate on a pallet, or a
## big crate (bulk), sized by mass (kg), tinted by category. Returns its height (m).
func _goods_box(batches: Dictionary, kind: String, mass: float, category: String, at: Vector3) -> float:
	if not _stores_paint.has(category):
		_stores_paint[category] = _paint(CATEGORY_TINT.get(category, Color(0.6, 0.6, 0.6)), 0.15, 0.6)
	var mat: Material = _stores_paint[category]
	var size: Vector3
	var lift := 0.0
	match kind:
		"bin":
			size = Vector3(0.6, 0.32, 0.9)
		"bulk":
			size = Vector3(3.6, clampf(1.0 + mass / 15000.0, 1.0, 2.6), 2.2)
		_:
			size = Vector3(1.0, clampf(0.35 + mass / 2500.0, 0.35, 1.35), 1.2)
			lift = 0.144
			_goods_add(batches, _box(Vector3(1.0, 0.14, 1.2)), _wood, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.07, 0)))
	var key := _lib("crate/stores/%.2f/%.2f/%.2f" % [size.x, size.y, size.z], func() -> PartShapes.PartShape:
			return WreckParts.cargo_crate(size))
	_goods_add(batches, key, mat, Transform3D(Basis.IDENTITY, at + Vector3(0, lift + size.y * 0.5, 0)))
	return lift + size.y


func _goods_add(batches: Dictionary, key: String, mat: Material, xform: Transform3D) -> void:
	var b := "%s|%d" % [key, mat.get_instance_id()]
	if not batches.has(b):
		batches[b] = {"key": key, "mat": mat, "xforms": []}
	(batches[b].xforms as Array).append(xform)


# --- Building blocks ----------------------------------------------------------------------

## Makes the library shape `key` once with `make` and returns the key.
func _lib(key: String, make: Callable) -> String:
	if not _shapes.has(key):
		_shapes[key] = make.call()
	return key


## A plain box from the parts library, as a shape key.
func _box(size: Vector3) -> String:
	return _lib("box/%.3f/%.3f/%.3f" % [size.x, size.y, size.z], func() -> PartShapes.PartShape:
			return PartShapes.box(size))


## Puts the library shape `key` at `xform`, drawn with every other copy of it in the same
## paint and patch of the yard as one MultiMesh (_flush); solid ones collide.
func _put(key: String, xform: Transform3D, mat: Material, solid := true) -> void:
	var shape: PartShapes.PartShape = _shapes[key]
	var cell := Vector2i(floori(xform.origin.x / CHUNK), floori(xform.origin.z / CHUNK))
	var batch := "%s|%d|%d,%d" % [key, mat.get_instance_id(), cell.x, cell.y]
	if not _batches.has(batch):
		_batches[batch] = {"shape": shape, "mat": mat, "xforms": []}
	(_batches[batch].xforms as Array).append(xform)
	if solid:
		_collide_xf(shape.collision, xform)


## Draws every batch: the part's body in its paint, its glass and its lit parts.
func _flush() -> void:
	var holder := Node3D.new()
	holder.name = "Parts"
	add_child(holder)
	for batch: Dictionary in _batches.values():
		var shape: PartShapes.PartShape = batch.shape
		var xforms: Array = batch.xforms
		_multimesh(holder, shape.mesh, xforms, batch.mat)
		if shape.glass:
			_multimesh(holder, shape.glass, xforms, Glazing.material(shape.glass_kind), false)
		if shape.glow:
			_multimesh(holder, shape.glow, xforms, _glow_mat(shape.glow_color, 2.5), false)
	_batches.clear()


func _multimesh(holder: Node3D, mesh: Mesh, xforms: Array, mat: Material, shadows := true) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(mmi)


## A big one-off box (walls, floors, roofs) `size` at `centre`; solid ones also collide.
func _block(centre: Vector3, size: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	add_child(mi)
	if solid:
		_collide(centre, size)
	return mi


func _collide(centre: Vector3, size: Vector3) -> void:
	_collide_xf(_box_shape(size), _at(centre))


func _collide_xf(shape: Shape3D, xform: Transform3D) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.transform = xform
	_solid.add_child(col)


static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


static func _at(p: Vector3, yaw := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## Paint on Void Salvage's ship surface (the salvage shader with a finish, ShipSurface.of).
func _paint(color: Color, metallic: float, roughness: float, finish := "") -> Material:
	var key := "%s/%.2f/%.2f/%s" % [color.to_html(), metallic, roughness, finish]
	if not _paints.has(key):
		_paints[key] = ShipSurface.of(ShipKit.paint(color, metallic, roughness, finish))
	return _paints[key]


func _glow_mat(color: Color, energy: float) -> Material:
	var key := "%s/%.1f" % [color.to_html(), energy]
	if not _glows.has(key):
		_glows[key] = ShipKit.glow(color, energy)
	return _glows[key]
