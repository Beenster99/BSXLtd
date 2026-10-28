extends Node3D
## The BSX Ltd shipyard: a big building on a planet, a horseshoe of wings round an open
## courtyard. The work flows clockwise round it: trucks unload at Deliveries (west wing),
## goods go on the racks in Stock and Store 2 (the back wing; Store 2 was Material prep),
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
const RefurbLine := preload("res://modules/ship_bay/internal/yard/refurb_line.gd")
const CrusherPlant := preload("res://modules/ship_bay/internal/yard/crusher_plant.gd")
const Apron := preload("res://modules/ship_bay/internal/yard/apron.gd")
const ItemLook := preload("res://modules/ship_bay/internal/yard/item_look.gd")
const Transporters := preload("res://modules/ship_bay/internal/yard/transporters.gd")
const DeliveryTrucks := preload("res://modules/ship_bay/internal/yard/delivery_trucks.gd")
const EmitterRig := preload("res://modules/ship_bay/internal/yard/emitter_rig.gd")
const YardShips := preload("res://modules/ship_bay/internal/yard/yard_ships.gd")
## Wall height of the wings (inside, floor to roof), metres.
const H := 12.0
## Wall thickness, metres.
const T := 0.5
## The courtyard's half extents (x, z), metres; the wings are WING deep round it.
const YARD := Vector2(28.0, 24.0)
## How far door frames stand proud of the wall's cut edges into the opening, metres.
const FRAME_PROUD := 0.02
const WING := 22.0
## The big doorways' height between the halls and onto the courtyard, metres: tall enough
## for the picking lifts' masts (beenster, 0.3.15), their shutters rolled up over them.
const BAY_DOOR_H := 10.0
## Room signs stand beside the doorways (not over them): their middle this high, metres,
## and their letters this tall.
const DOOR_SIGN_Y := 4.6
const DOOR_SIGN_H := 0.8
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
	"prep": {"name": "Store 2", "box": AABB(Vector3(0, 0, -46), Vector3(50, 12, 22))},
	"preassembly": {"name": "Pre-assembly", "box": AABB(Vector3(28, 0, -24), Vector3(22, 12, 48))},
	"plates": {"name": "Plate hall", "box": AABB(Vector3(-104, 0, -46), Vector3(54, 12, 26))},
	"bay": {"name": "The bay", "box": AABB(Vector3(-28, 0, -24), Vector3(56, 30, 48))},
}
## The doorways between the rooms: [room, room, the doorway's middle on the floor (yard x, z)].
## The direction signs find their way round the yard through these.
const DOORWAYS := [
	["bay", "deliveries", Vector2(-28, 0)], ["bay", "stock", Vector2(-14, -24)], ["bay", "prep", Vector2(14, -24)],
	["bay", "preassembly", Vector2(28, 0)], ["stock", "deliveries", Vector2(-39, -24)], ["stock", "prep", Vector2(0, -35)],
	["prep", "preassembly", Vector2(39, -24)], ["stock", "plates", Vector2(-50, PLATE_DOOR.x)],
]
## The plate hall's doorway off Stock's transfer aisle, on the building's west wall: its
## middle (z) and width, metres (tall like the bay doors, for the heavy lift's mast).
const PLATE_DOOR := Vector2(-26.5, 5.0)
## The direction signs: a board on each hall's wall beside the doorway onto the courtyard,
## under its THE BAY sign where there's room (beenster, 23 Oct: on the walls, out of the lifts' way): [room,
## the wall ("x": along x at z = at, "z": along z at x = at), the doorway's middle along it and
## its width, the board's face off the wall's middle line, the side of the doorway it's on,
## the way it faces] (as _door_sign takes them). And a fingerpost in the courtyard.
const DIRECTION_SIGNS := [
	["deliveries", "z", -28.0, 0.0, 10.0, -0.3, -1.0, -PI * 0.5],
	["stock", "x", -24.0, -14.0, 8.0, -0.3, -1.0, PI],   # west of it: Business's TV is east
	["prep", "x", -24.0, 14.0, 8.0, -0.3, -1.0, PI],
	["preassembly", "z", 28.0, 0.0, 20.0, 0.3, -1.0, PI * 0.5],
]
## The wall boards' middle, metres up (under the door signs at DOOR_SIGN_Y).
const DIRECTION_Y := 3.0
const FINGERPOST := Vector3(-9.0, 0.0, 16.0)
## The direction signs' letters, metres tall.
const DIRECTION_H := 0.15   # beenster, 23 Oct: 30% of the first 0.5 m
## The direction signs' boards and letters: safety yellow with black letters, to stand out
## against the dark roof.
const DIRECTION_BOARD := Color(0.95, 0.72, 0.1)
const DIRECTION_INK := Color(0.04, 0.04, 0.05)
## Clear floor kept for other modules' work places: id -> a transform in yard space whose
## origin is on the floor and whose +Z faces where the worker stands (a bench's back edge).
## Other modules get these through ShipBayBus.shipyard_spot() and add their nodes to the
## yard when ShipBayBus.shipyard_ready fires.
const SPOTS := {
	"bench_preassembly": Transform3D(Basis.IDENTITY, Vector3(40, 0, 12.6)),
	"bench_prep": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(47.2, 0, -35.0)),   # Store 2's work strip
	# The emitter frame rig on the free strip down Pre-assembly's west side, between the
	# walkway and line A's trolley, south of the courtyard doorway: the middle of its deck at
	# deck height (EmitterRig.DECK_H), +X (the coil, then the test mass rail) to the south,
	# its worker to the west.
	"rig_emitter": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(31.3, 0.95, 14.6)),
	# (With "ship_bay.upgrade_hall" on, the rig stands in the upgrade hall: UPGRADE_SPOTS.)
	# The plasma cutting bed (Tools' machine) in the middle of the plate hall west of
	# Deliveries, its long side along z, the operator's screen side to the north.
	"cutting_bed": Transform3D(Basis.IDENTITY, Vector3(-64.8, 0, -35.6)),
}
## The upgrade hall (beenster, 0.3.26: "move the field sweep machine to a new hall where we
## will have other upgrade rigs"): a free-standing shed east of Store 2, north of the crusher
## house, reached from the front strip by a path up the crusher house's east end to a roller
## door at the east end of its south wall. Its floor (x, z), height, the door (centre x,
## width, height), metres.
const UPGRADE_HALL := Rect2(62.0, -46.0, 36.0, 34.0)
const UPGRADE_H := 9.0
const UPGRADE_DOOR := Vector3(93.0, 7.0, 6.0)
## Its rig bays, one per rig the Component Upgrades plan names: [spot id, name, what it takes,
## the plan's stage it comes in ("" built), the bay's middle (x, z)]. Each bay is UPGRADE_BAY
## across (x) and along (z); the aisle from the door runs up the east side.
const UPGRADE_BAYS := [
	["rig_emitter", "EMITTER FRAME", "ATTRACTOR COILS", "", Vector2(70.0, -22.0)],
	["rig_tank", "TANK BENCH", "TANKS AND PUMPS", "U2", Vector2(81.0, -22.0)],
	["rig_engine", "ENGINE STAND", "MAIN ENGINES", "U2", Vector2(70.0, -38.0)],
	["rig_drive", "DRIVE CRADLE", "QUANTUM DRIVES", "U2", Vector2(81.0, -38.0)],
	["rig_sensor", "SENSOR AND WINCH FRAME", "RADAR, SURVEY, WINCH, NETS", "U4", Vector2(92.0, -38.0)],
]
const UPGRADE_BAY := Vector2(9.0, 12.0)
## The rigs' places in the upgrade hall, as SPOTS gives them (a bay still to come has its
## bay's middle on the floor, +Z towards the aisle). The emitter frame rig's deck middle at
## deck height, +X (the coil, then the test mass rail) to the south, its worker to the west,
## as it stood in Pre-assembly.
const UPGRADE_SPOTS := {
	"rig_emitter": Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(70.0, 0.95, -24.0)),
	"rig_tank": Transform3D(Basis.IDENTITY, Vector3(81.0, 0, -22.0)),
	"rig_engine": Transform3D(Basis.IDENTITY, Vector3(70.0, 0, -38.0)),
	"rig_drive": Transform3D(Basis.IDENTITY, Vector3(81.0, 0, -38.0)),
	"rig_sensor": Transform3D(Basis.IDENTITY, Vector3(92.0, 0, -38.0)),
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
	# The storage hall (StorageLayout): down aisle B, the bins in C2, the large and heavy racks.
	"storage_aisle": [Vector3(-11.1, 1.7, -25.6), Vector3(-11.1, 3.2, -42.0)],
	"storage_aisle_d": [Vector3(-5.7, 1.7, -25.2), Vector3(-5.7, 2.6, -42.0)],
	"plate_hall": [Vector3(-52.5, 6.5, -21.5), Vector3(-70.0, 1.0, -36.0)],
	"upgrade_hall": [Vector3(95.5, 4.5, -14.5), Vector3(74.0, 0.5, -32.0)],
	"storage_bins": [Vector3(-6.4, 1.7, -27.4), Vector3(-3.65, 1.4, -32.5)],
	"storage_bulk": [Vector3(-27.0, 6.5, -25.0), Vector3(-42.0, 1.5, -37.0)],
	"storage_heavy": [Vector3(-44.0, 2.0, -25.4), Vector3(-44.0, 3.5, -40.0)],
	"goods_in": [Vector3(-31.0, 4.6, -21.0), Vector3(-41.0, 0.0, -6.0)],
	"trolleys": [Vector3(-38.5, 3.4, -25.0), Vector3(-31.0, 0.6, -14.0)],
	"trolley_lift": [Vector3(-6.9, 1.8, -24.6), Vector3(-5.2, 4.6, -34.0)],
	"picking_lift": [Vector3(-9.6, 1.7, -25.6), Vector3(-10.6, 5.8, -34.3)],
	"hover_truck": [Vector3(-74.0, 4.5, 22.0), Vector3(-60.0, 1.8, 8.0)],
	# Dock 1 and the launch towers out on the plain.
	"dock": [Vector3(14, 3.2, 22), Vector3(-1, 5.5, -4)],
	"launch_towers": [Vector3(72, 2.0, 40), Vector3(150, 32, -450)],
	# The apron (with "ship_bay.apron"): the whole of it, the pad's hulk, the holding lane;
	# the crusher house east of Pre-assembly, outside and in.
	"apron_overview": [Vector3(30, 70, 200), Vector3(25, 0, 80)],
	"pad": [Vector3(18, 6, 112), Vector3(0, 3, 90)],
	"holding": [Vector3(115, 9, 140), Vector3(148, 1.5, 92)],
	"crusher_house": [Vector3(44, 9, 46), Vector3(66, 3, 14)],
	"crusher": [Vector3(52, 5.5, 22), Vector3(72, 2.5, 2)],
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
## The refurbishment lines in Pre-assembly (refurb_line.gd): line id -> node; `line` is
## line A.
var lines: Dictionary = {}
var line: Node3D
## The crusher bay outside Pre-assembly's south door (crusher_plant.gd).
var crusher: Node3D
## Where the extinguishers hang at the fire points (ShipBayBus.fire_points): yard space, the
## origin at a bottle's foot on the wall, -Z out of the wall into the room.
var fire_points: Array[Transform3D] = []
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
var _direction_mat: Material
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
var _bus: ShipBayBus
## The hover trolleys and their console (TrolleyFleet).
var trolleys: Node3D
## The emitter frame rig in Pre-assembly (emitter_rig.gd, Component Upgrades U1), with the
## flag "ship_bay.emitter_rig" on; else null.
var emitter_rig: Node3D
## Ships stood on the apron for a look, Settings > Debug > Ship (yard_ships.gd).
var yard_ships: Node3D
## The delivery trucks that bring each order to the truck doors (delivery_trucks.gd).
var trucks: Node3D
## The city round the yard (YardCity), with "ship_bay.city" on; else null.
var city: Node3D
## The apron's pad, docks and holding lane and the scrap end (apron.gd), with
## "ship_bay.apron" on; else null.
var apron: Node3D
## The dolly and the crawler and who drives them (transporters.gd), with "ship_bay.dolly"
## and the apron on; else null.
var transporters: Node3D


func _ready() -> void:
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
	_build_services()
	_build_doors()
	_build_lights()
	_build_signs()
	_build_roof_plant()
	_build_deliveries()
	_build_stock()
	_build_prep()
	_build_plate_hall()
	_build_preassembly()
	if Flags.is_on("ship_bay.upgrade_hall"):
		_build_upgrade_hall()
	_tag_rooms()
	_build_courtyard()
	_build_crane()
	_build_dock()
	_build_outside()
	if Flags.is_on("ship_bay.apron"):
		apron = Apron.new()
		add_child(apron)
		apron.call("build", self)
	# No city round the yard (beenster, 0.3.27: "please remove the cityscape and the moving
	# vehicles"); ship_bay.city brings it back.
	if Flags.is_on("ship_bay.city"):
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
	trucks = DeliveryTrucks.new()
	trucks.name = "Trucks"
	trucks.set("yard", self)
	add_child(trucks)
	yard_ships = YardShips.new()
	add_child(yard_ships)
	if Flags.is_on("ship_bay.emitter_rig"):
		emitter_rig = EmitterRig.new()
		var rig_spot := spot("rig_emitter")
		emitter_rig.transform = Transform3D(rig_spot.basis, rig_spot.origin - Vector3(0, EmitterRig.DECK_H, 0))
		add_child(emitter_rig)
	if apron and Flags.is_on("ship_bay.dolly"):
		transporters = Transporters.new()
		transporters.set("yard", self)
		add_child(transporters)
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
		_bus._yard = self
		_bus.shipyard_ready.emit(self)
		_bus.resume_sales()
	_on_sky_time(_sky.hour, AlienSky.daylight_at(_sky.hour))
	Settings.changed.connect(_on_setting)
	var start: String = Router.args.get("view", "")
	if VIEWS.has(start):
		show_view(start)
	elif DisplayServer.get_name() != "headless" and not HudSlots.pointer_claimed():
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
	if id == "hover_truck" and trucks and (trucks.get("runs") as Array).is_empty():
		trucks.call("park_for_show")
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
	if Flags.is_on("ship_bay.upgrade_hall") and upgrade_box().has_point(point):
		return "upgrades"
	return ""


## A work place by id (SPOTS, or UPGRADE_SPOTS with the upgrade hall built), Identity for none.
static func spot(id: String) -> Transform3D:
	if Flags.is_on("ship_bay.upgrade_hall") and UPGRADE_SPOTS.has(id):
		return UPGRADE_SPOTS[id]
	return SPOTS.get(id, Transform3D.IDENTITY)


## The upgrade hall's inside (not one of ROOMS: no doorway joins it to the halls).
static func upgrade_box() -> AABB:
	var r := UPGRADE_HALL
	return AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, UPGRADE_H, r.size.y))


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
		if DisplayServer.get_name() != "headless" and not HudSlots.pointer_claimed():
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
		# A screen that has the mouse (the wrist, a menu) keeps it free.
		if HudSlots.pointer_claimed():
			return
		_walk_again()
		if DisplayServer.get_name() != "headless":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			# The pause menu: Resume carries on where you stand.
			get_viewport().set_input_as_handled()
			Menu.open_pause()
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
	_concrete = _surface(_paint(Color(0.5, 0.49, 0.47), 0.0, 0.95), "concrete")
	_parts = _paint(Color.WHITE, 0.4, 0.55)
	for c: Color in [Color(0.78, 0.6, 0.4), Color(0.4, 0.55, 0.75), Color(0.72, 0.72, 0.7), Color(1.0, 0.62, 0.28), Color(0.5, 0.64, 0.46)]:
		_goods.append(_paint(c, 0.2, 0.6))


# --- The planet ---------------------------------------------------------------------------

## The shore (ship_bay.sea, beenster 0.3.27: the yard by the sea like a traditional
## shipyard): z of the quay's face, metres, just south of the apron (Apron.AREA ends at 150).
const SHORE_Z := 152.0
## The sea's surface under the quay's top, and the seabed under that (m).
const SEA_Y := -1.5
const SEABED_Y := -8.0


## The quay along the apron's south edge (a concrete wall with a coping, bollards and ladders),
## a rock bank either side of it, and Graphics' sea beyond (a plain blue plane without
## Graphics). Ships stand on the apron; nothing goes out on the water yet.
func _build_sea() -> void:
	var gfx := Modules.bus("graphics")
	var water: MeshInstance3D = gfx.call("sea", Vector2(4000, 2000)) if gfx and gfx.has_method("sea") else null
	if water == null:
		water = MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(4000, 2000)
		water.mesh = plane
		water.material_override = _paint(Color(0.08, 0.2, 0.3), 0.0, 0.2)
	water.name = "Sea"
	water.position = Vector3(0, SEA_Y, SHORE_Z + 1000.0)
	add_child(water)
	_block(Vector3(0, SEABED_Y, SHORE_Z + 1000.0), Vector3(4000, 0.2, 2000), _paint(Color(0.16, 0.14, 0.12), 0.0, 1.0), false).name = "Seabed"
	# The quay wall under the apron's edge, its coping a step proud of the face.
	var quay := Rect2(Apron.AREA.position.x - 5.0, 0, Apron.AREA.size.x + 10.0, 0)
	var wall_h := -SEABED_Y
	_block(Vector3(quay.get_center().x, -wall_h * 0.5 - 0.03, SHORE_Z - 1.0), Vector3(quay.size.x, wall_h, 2.0), _concrete).name = "QuayWall"
	_block(Vector3(quay.get_center().x, -0.01, SHORE_Z - 0.3), Vector3(quay.size.x, 0.06, 0.6), _paint(Color(0.72, 0.7, 0.66), 0.0, 0.9), false).name = "QuayCoping"
	var iron := _paint(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	var x := quay.position.x + 6.0
	var k := 0
	while x < quay.end.x - 3.0:
		# A bollard every 12 m, a ladder down the face every third.
		_put(_lib("bollard_post", func() -> PartShapes.PartShape: return PartShapes.prism(12, 0.22, 0.5)), _at(Vector3(x, 0.25, SHORE_Z - 0.9)), iron, false)
		_put(_lib("bollard_cap", func() -> PartShapes.PartShape: return PartShapes.prism(12, 0.3, 0.08)), _at(Vector3(x, 0.5, SHORE_Z - 0.9)), iron, false)
		if k % 3 == 1:
			for side: float in [-0.25, 0.25]:
				_put(_box(Vector3(0.05, 3.2, 0.05)), _at(Vector3(x + 6.0 + side, -1.5, SHORE_Z + 0.08)), iron, false)
			for r in 9:
				_put(_box(Vector3(0.5, 0.04, 0.04)), _at(Vector3(x + 6.0, -2.9 + r * 0.35, SHORE_Z + 0.08)), iron, false)
		x += 12.0
		k += 1
	# A rock bank either side of the quay, the ground's edge stepping down to the water.
	var rock := _paint(Color(0.36, 0.25, 0.19), 0.0, 1.0)
	for span: Vector2 in [Vector2(-2000.0, quay.position.x), Vector2(quay.end.x, 2000.0)]:
		_block(Vector3((span.x + span.y) * 0.5, -wall_h * 0.5 - 0.05, SHORE_Z - 1.5), Vector3(span.y - span.x, wall_h, 3.0), rock, false)
		_block(Vector3((span.x + span.y) * 0.5, SEA_Y - 0.3, SHORE_Z + 1.5), Vector3(span.y - span.x, 1.2, 3.0), rock, false)


func _build_planet() -> void:
	# The sky, sun and planet-light come from UI's AlienSky, which follows the time of day.
	_sky = AlienSky.new()
	_sky.time_changed.connect(_on_sky_time)
	add_child(_sky)
	_sun = _sky.sun
	_env = _sky.environment

	# The ground: dusty red-brown plain, with a concrete apron in front of the open end and
	# a road to the truck doors.
	# With the sea (ship_bay.sea) the land stops at the quay, SHORE_Z, south of the apron.
	var sea := Flags.is_on("ship_bay.sea")
	var land := Rect2(-2000, -2000, 4000, (SHORE_Z + 2000.0) if sea else 4000.0)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	var plane := PlaneMesh.new()
	plane.size = land.size
	ground.mesh = plane
	ground.position = Vector3(land.get_center().x, -0.02, land.get_center().y)
	ground.material_override = _surface(_paint(Color(0.4, 0.26, 0.18), 0.0, 1.0), "ground")
	add_child(ground)
	_collide(Vector3(land.get_center().x, -0.5, land.get_center().y), Vector3(land.size.x, 1.0, land.size.y))
	if sea:
		_build_sea()
	if Flags.is_on("ship_bay.apron"):
		# The front strip; the Apron lays the rest from z = 35.
		_block(Vector3(0, -0.01, 29.75), Vector3(90, 0.04, 10.5), _concrete, false)
		_slab_joints(Rect2(-45, 24.5, 90, 10.5), 0.0)
	else:
		_block(Vector3(0, -0.01, 56), Vector3(90, 0.04, 64), _concrete, false)
		_slab_joints(Rect2(-45, 24.5, 90, 63.5), 0.0)
	_block(Vector3(-62, -0.01, 0), Vector3(24, 0.03, 40), _surface(_paint(Color(0.24, 0.24, 0.25), 0.0, 0.9, "rubber_tread"), "asphalt"), false)
	_block(Vector3(-110, -0.01, 30), Vector3(130, 0.03, 9), _surface(_paint(Color(0.2, 0.2, 0.21), 0.0, 0.9, "rubber_tread"), "asphalt"), false)
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
	var PH := StorageLayout.PLATE_HALL
	var x0 := -YARD.x - WING
	var x1 := YARD.x + WING
	var zb := -YARD.y - WING
	return [
		["z", x0, zb, YARD.y, [[PLATE_DOOR.x, PLATE_DOOR.y, BAY_DOOR_H], [-8.0, 6.0, 6.0], [8.0, 6.0, 6.0]], -1],   # west: truck doors
		["x", zb, PH.position.x, x1, [], -1],                             # north, the plate hall's too
		["z", x1, zb, YARD.y, [[0.0, 1.4, 2.4]], 1],                      # east: a door
		["x", YARD.y, x0, -YARD.x, [[-39.0, 1.4, 2.4]], 1],               # west wing's end
		["x", YARD.y, YARD.x, x1, [[39.0, 8.0, BAY_DOOR_H]], 1],          # east wing's end
		["z", -YARD.x, -YARD.y, YARD.y, [[0.0, 10.0, BAY_DOOR_H]], 1],    # on the courtyard
		["x", -YARD.y, -YARD.x, YARD.x, [[-14.0, 8.0, BAY_DOOR_H], [14.0, 8.0, BAY_DOOR_H]], 1],
		["z", YARD.x, -YARD.y, YARD.y, [[0.0, 20.0, BAY_DOOR_H]], -1],
		["x", -YARD.y, x0, -YARD.x, [[-39.0, 10.0, BAY_DOOR_H]], 0],      # between the rooms
		["z", 0.0, zb, -YARD.y, [[-35.0, 8.0, BAY_DOOR_H]], 0],
		["x", -YARD.y, YARD.x, x1, [[39.0, 10.0, BAY_DOOR_H]], 0],
		["z", PH.position.x, zb, PH.end.y, [], -1],                       # the plate hall: west
		["x", PH.end.y, PH.position.x, x0, [], 1],                        # and south
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
			# Walls one way stand 2 mm lower so plinths meeting at a corner don't share a top.
			var tall := 0.6 if axis == "x" else 0.598
			_block(_wall_point(axis, at, p.get_center().x, tall * 0.5, float(side) * (T * 0.5 + 0.06)),
					_wall_size(axis, p.size.x, tall, 0.12), plinth, false)
			_block(_wall_point(axis, at, p.get_center().x, 0.6, float(-side) * (T * 0.5 + 0.02)),
					_wall_size(axis, p.size.x, 1.2, 0.04), _paint(Color(0.3, 0.32, 0.34), 0.3, 0.6, "satin_paint"), false)

	# Floors (epoxy, a colour per wing, walkway lines) and roofs.
	var x0 := -YARD.x - WING
	var x1 := YARD.x + WING
	var roof := _paint(Color(0.32, 0.33, 0.35), 0.4, 0.7, "galvanised")
	var walk := _paint(HAZARD, 0.0, 0.6, "satin_paint")
	# Each wing's floor a hair (0.6 mm) higher than the last: they overlap under the
	# walls, and level they flickered in the doorways between them (Z-fighting).
	var lift := 0.0
	for r: Array in [[Vector3(-25, 0, -YARD.y - WING * 0.5), Vector3(50, 0, WING), Color(0.55, 0.55, 0.53)],
			[Vector3(25, 0, -YARD.y - WING * 0.5), Vector3(50, 0, WING), Color(0.5, 0.53, 0.51)],
			[Vector3(-YARD.x - WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0), Color(0.54, 0.53, 0.5)],
			[Vector3(YARD.x + WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0), Color(0.49, 0.54, 0.51)]]:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		# The side wings' floors stop 1 mm short across, so their edges under the outer walls
		# don't lie in one plane with the north wing's.
		var across := 0.0 if s.x > s.z else 0.002
		# Solid (beenster, 0.3.27): loose parts lay on the ground 2 cm under it, thin cut plates
		# out of sight.
		_block(Vector3(c.x, lift, c.z), Vector3(s.x + T - across, 0.04, s.z + T), _surface(_paint(r[2], 0.0, 0.55, "satin_paint"), "epoxy"))
		_hall_joints(Rect2(c.x - s.x * 0.5, c.z - s.z * 0.5, s.x, s.z), lift + 0.0205)
		# Walkway lines down the long way, a metre and a half in from each wall.
		var long_x := s.x > s.z
		for k: float in [-1.0, 1.0]:
			var off := (s.z if long_x else s.x) * 0.5 - 1.6
			var p := c + (Vector3(0, 0.022 + lift, off * k) if long_x else Vector3(off * k, 0.022 + lift, 0))
			_block(p, Vector3(s.x - 3.0, 0.004, 0.1) if long_x else Vector3(0.1, 0.004, s.z - 3.0), walk, false)
		lift += 0.0006
	for r: Array in [[Vector3(0, 0, -YARD.y - WING * 0.5), Vector3(x1 - x0, 0, WING)],
			[Vector3(-YARD.x - WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)],
			[Vector3(YARD.x + WING * 0.5, 0, 0), Vector3(WING, 0, YARD.y * 2.0)]]:
		var c: Vector3 = r[0]
		var s: Vector3 = r[1]
		var size := Vector3(s.x + T + 0.6, 0.6, s.z + T + 0.6)
		var mid := c
		if s.z > s.x:
			# A side wing's roof starts where the north wing's ends: overlapping, they flickered.
			var north_edge := -YARD.y + (T + 0.6) * 0.5
			var south_edge := c.z + size.z * 0.5
			mid.z = (north_edge + south_edge) * 0.5
			size.z = south_edge - north_edge
		_block(Vector3(mid.x, H + 0.3, mid.z), size, roof)
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


## Saw-cut joints in a hall's epoxy floor on the column grid, and a darker worn lane down
## the middle where the trolleys run. `y` is the joints' centre (just over the floor).
func _hall_joints(area: Rect2, y: float) -> void:
	var joint := _paint(Color(0.2, 0.2, 0.2), 0.0, 0.9)
	var x := ceilf((area.position.x + 0.5) / BAY) * BAY
	while x < area.end.x - 0.5:
		_block(Vector3(x, y, area.get_center().y), Vector3(0.02, 0.002, area.size.y - 0.6), joint, false)
		x += BAY
	var z := ceilf((area.position.y + 0.5) / BAY) * BAY
	while z < area.end.y - 0.5:
		_block(Vector3(area.get_center().x, y, z), Vector3(area.size.x - 0.6, 0.002, 0.02), joint, false)
		z += BAY
	var long_x := area.size.x > area.size.y
	var worn := _paint(Color(0.36, 0.36, 0.35), 0.0, 0.45, "satin_paint")
	var lane := Vector3(area.size.x - 8.0, 0.001, 2.6) if long_x else Vector3(2.6, 0.001, area.size.y - 8.0)
	_block(Vector3(area.get_center().x, y - 0.0002, area.get_center().y), lane, worn, false)


## Services along the inside of every outside and courtyard wall: a cable tray under the
## eaves with drops down the columns, and a fire point (extinguishers under a lit sign)
## every other bay where the wall is clear. Each extinguisher's place goes in fire_points.
func _build_services() -> void:
	var tray_mat := _galv
	var red := _paint(Color(0.78, 0.1, 0.06), 0.2, 0.4, "gloss_paint")
	var sign_mat := _glow_mat(Color(0.35, 1.0, 0.5), 2.0)
	var ext := _lib("fire/extinguisher", func() -> PartShapes.PartShape:
			return WreckParts.pipe(0.08, 0.55, false))
	var board := _box(Vector3(0.7, 0.9, 0.03))
	var lit := _box(Vector3(0.36, 0.14, 0.03))
	var drop := _box(Vector3(0.06, 9.0, 0.04))
	var tray_y := 9.6
	for wall: Array in _walls():
		var side: int = wall[5]
		if side == 0:
			continue
		var axis: String = wall[0]
		var at: float = wall[1]
		var basis := _wall_basis(axis)
		var w_in := float(-side)
		# The tray: an open U of galvanised sheet on brackets, broken round tall openings.
		var start: float = float(wall[2]) + 0.6
		var cuts: Array = []
		for o: Array in wall[4]:
			if float(o[2]) > tray_y - 0.4:
				cuts.append([float(o[0]) - float(o[1]) * 0.5 - 0.4, float(o[0]) + float(o[1]) * 0.5 + 0.4])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		cuts.append([float(wall[3]) - 0.6, float(wall[3])])
		for c: Array in cuts:
			var run: float = float(c[0]) - start
			if run > 1.0:
				var mid := start + run * 0.5
				var off := w_in * (T * 0.5 + 0.72)
				_block(_wall_point(axis, at, mid, tray_y, off), _wall_size(axis, run, 0.02, 0.36), tray_mat, false)
				for k: float in [-1.0, 1.0]:
					_block(_wall_point(axis, at, mid, tray_y + 0.05, off + k * 0.17), _wall_size(axis, run, 0.1, 0.015), tray_mat, false)
				# Cables in the tray, a bundle of dark and orange.
				_block(_wall_point(axis, at, mid, tray_y + 0.04, off - 0.05), _wall_size(axis, run, 0.05, 0.12), _rubber, false)
				_block(_wall_point(axis, at, mid, tray_y + 0.035, off + 0.08), _wall_size(axis, run, 0.04, 0.06), _trim, false)
			start = c[1]
		# Fire points and cable drops between the columns.
		var u := floorf(float(wall[2]) / BAY) * BAY + BAY
		var n := 0
		while u < float(wall[3]) - 1.0:
			if _opening_at(wall[4], u, 1.2).is_empty():
				n += 1
				var face := w_in * (T * 0.5 + 0.03)
				if n % 2 == 1:
					_put(board, Transform3D(basis, _wall_point(axis, at, u, 1.05, face)), red, false)
					var out := Vector3(0, 0, w_in) if axis == "x" else Vector3(w_in, 0, 0)
					for k: float in [-0.15, 0.15]:
						fire_points.append(Transform3D(Basis.looking_at(out), _wall_point(axis, at, u + k, 0.475, w_in * (T * 0.5 + 0.13))))
						if not Flags.is_on("trades.extinguishers"):   # Tools hangs real ones there
							_put(ext, Transform3D(Basis(), _wall_point(axis, at, u + k, 0.75, w_in * (T * 0.5 + 0.13))), red, false)
					_put(lit, Transform3D(basis, _wall_point(axis, at, u, 1.75, face)), sign_mat, false)
				else:
					_put(drop, Transform3D(basis, _wall_point(axis, at, u, 5.0, w_in * (T * 0.5 + 0.2))), tray_mat, false)
			u += BAY


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
## The frame stands FRAME_PROUD into the opening, so its faces never lie in the same plane
## as the wall's cut edges (that flickered: Z-fighting).
func _door_frame(at: Vector3, width: float, height: float, along_x: bool) -> void:
	var across := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var basis := Basis.IDENTITY if along_x else Basis(Vector3.UP, PI * 0.5)
	var jamb := _lib("ibeam/jamb/%.1f" % height, func() -> PartShapes.PartShape:
			return PartShapes.i_beam(height, T + 0.3, 0.3))
	for side: float in [-1.0, 1.0]:
		var post := at + across * (width * 0.5 + 0.15 - FRAME_PROUD) * side
		_put(jamb, Transform3D(basis * UPRIGHT, post + Vector3(0, height * 0.5, 0)), _frame, false)
		if width > 3.0:
			var band := _box(Vector3(0.32, 0.3, T + 0.34))
			for k in int(height / 0.6):
				if k % 2 == 0:
					_put(band, Transform3D(basis, post + Vector3(0, 0.3 + k * 0.6, 0)), _hazard, false)
	var head := _lib("ibeam/head/%.1f" % width, func() -> PartShapes.PartShape:
			return PartShapes.i_beam(width + 0.6, T + 0.3, 0.3))
	_put(head, Transform3D(basis, at + Vector3(0, height + 0.15 - FRAME_PROUD, 0)), _frame, false)


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
			# Rolled up clear of the lifts' masts (the heavy lift's is 9.3 m) in the tall doorways.
			var bottom := maxf(3.2, maxf(height * 0.66, height - 0.3))
			var drop := height - bottom
			var basis := _wall_basis(axis)
			_put(_box(Vector3(width - 0.01, drop, 0.03)), Transform3D(basis, _wall_point(axis, wall[1], o[0], bottom + drop * 0.5, face)), curtain, false)
			var slat := _box(Vector3(width - 0.02, 0.025, 0.05))
			var y := bottom + 0.1
			while y < height:
				_put(slat, Transform3D(basis, _wall_point(axis, wall[1], o[0], y, face)), curtain, false)
				y += 0.11
			_put(_box(Vector3(width - 0.012, 0.12, 0.08)), Transform3D(basis, _wall_point(axis, wall[1], o[0], bottom + 0.055, face)), _hazard, false)
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


## Signs beside every doorway naming the room it leads into (beside, not over: the doorways
## are tall for the picking lifts), and the company name on the back wing's courtyard face.
func _build_signs() -> void:
	var court := YARD.x
	var back := -YARD.y
	# From the courtyard.
	_door_sign("DELIVERIES", "z", -court, 0.0, 10.0, 0.3, 1.0, PI * 0.5)
	_door_sign("STOCK", "x", back, -14.0, 8.0, 0.3, -1.0, 0.0)
	_door_sign("STORE 2", "x", back, 14.0, 8.0, 0.3, 1.0, 0.0)
	_door_sign("PRE-\nASSEMBLY", "z", court, 0.0, 20.0, -0.3, 1.0, -PI * 0.5)
	var name_board := _sign("BSX LTD", Vector3(0, 9.6, back + 0.35), 0.0, 3.2)
	name_board.modulate = TRIM
	_sign("SHIP MODIFICATION  /  REFIT  /  REPAIR", Vector3(0, 7.4, back + 0.35), 0.0, 0.5, false)
	# Back out to the bay.
	_door_sign("THE BAY", "z", -court, 0.0, 10.0, -0.3, -1.0, -PI * 0.5)
	_door_sign("THE BAY", "x", back, -14.0, 8.0, -0.3, 1.0, PI)
	_door_sign("THE BAY", "x", back, 14.0, 8.0, -0.3, -1.0, PI)
	_door_sign("THE BAY", "z", court, 0.0, 20.0, 0.3, -1.0, PI * 0.5)
	# Room to room, round the flow.
	_door_sign("STOCK", "x", back, -39.0, 10.0, 0.3, 1.0, 0.0)
	_door_sign("DELIVERIES", "x", back, -39.0, 10.0, -0.3, 1.0, PI)
	_door_sign("STORE 2", "z", 0.0, -35.0, 8.0, -0.3, 1.0, -PI * 0.5)
	_door_sign("STOCK", "z", 0.0, -35.0, 8.0, 0.3, 1.0, PI * 0.5)
	_door_sign("PRE-\nASSEMBLY", "x", back, 39.0, 10.0, -0.3, -1.0, PI)
	_door_sign("PLATE HALL", "z", -court - WING, PLATE_DOOR.x, PLATE_DOOR.y, 0.3, 1.0, PI * 0.5)
	_door_sign("STOCK", "z", -court - WING, PLATE_DOOR.x, PLATE_DOOR.y, -0.3, -1.0, -PI * 0.5)
	_door_sign("STORE 2", "x", back, 39.0, 10.0, 0.3, -1.0, 0.0)
	_sign("GOODS IN", Vector3(-court - WING - 0.4, 7.6, 0), -PI * 0.5, 1.8)
	for d: Array in DIRECTION_SIGNS:
		_direction_board(d)
	_fingerpost(FINGERPOST)


## The first doorway on the shortest way from room `from` to room `to` (yard x, z), by the
## DOORWAYS. Vector2.INF when there's no way.
static func way_to(from: String, to: String) -> Vector2:
	var first := {from: Vector2.INF}
	var queue: Array[String] = [from]
	while not queue.is_empty():
		var room: String = queue.pop_front()
		if room == to:
			return first[room]
		for d: Array in DOORWAYS:
			var next := ""
			if d[0] == room:
				next = d[1]
			elif d[1] == room:
				next = d[0]
			if next != "" and not first.has(next):
				first[next] = d[2] if room == from else first[room]
				queue.append(next)
	return Vector2.INF


## What a direction sign in `room` at `at`, read facing `yaw` (from its +Z side), says: one
## line for the rooms to the left, one for those ahead, one for those to the right, each with
## its arrow; rooms behind the reader are on the board's other face, or with `all_round` (a
## board on a wall, read facing the wall) on the side they're on.
static func direction_lines(room: String, at: Vector3, yaw: float, all_round := false) -> PackedStringArray:
	var right := Basis(Vector3.UP, yaw).x
	var ahead := -Basis(Vector3.UP, yaw).z
	var groups: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for id: String in ROOMS:
		if id == room:
			continue
		var door := way_to(room, id)
		if door == Vector2.INF:
			continue
		var d := Vector3(door.x - at.x, 0.0, door.y - at.z).normalized()
		var r := d.dot(right)
		var a := d.dot(ahead)
		var name := (ROOMS[id].name as String).to_upper()
		if a > absf(r):
			groups[1].append(name)
		elif absf(r) >= absf(a) or all_round:
			groups[2 if r > 0.0 else 0].append(name)
	var out: PackedStringArray = []
	if not groups[0].is_empty():
		out.append("←  " + "  ·  ".join(groups[0]))
	if not groups[1].is_empty():
		out.append("↑  " + "  ·  ".join(groups[1]))
	if not groups[2].is_empty():
		out.append("  ·  ".join(groups[2]) + "  →")
	return out


## What a DIRECTION_SIGNS board says, read facing the wall from about where it hangs.
static func wall_sign_lines(d: Array) -> PackedStringArray:
	var near: float = d[3] + float(d[6]) * (float(d[4]) * 0.5 + 1.5)
	return direction_lines(d[0], _wall_point(d[1], d[2], near, DIRECTION_Y, d[5]), d[7], true)


## A board on a hall's wall (a DIRECTION_SIGNS entry) listing the way to every other room,
## between the wall's columns as near the doorway as it fits.
func _direction_board(d: Array) -> void:
	if Flags.is_on("ship_bay.no_signs"):
		return
	var lines := wall_sign_lines(d)
	var longest := 0.0
	for line in lines:
		longest = maxf(longest, direction_width(line))
	var size := Vector3(longest + DIRECTION_H * 1.6, DIRECTION_H * (1.3 * lines.size() + 0.6), 0.04)
	# Centred between two of the wall's columns (they stand at BAY * k + BAY / 2), the nearest
	# bay to the doorway that clears its jamb.
	var along: float = d[3] + float(d[6]) * (float(d[4]) * 0.5 + 0.55 + size.x * 0.5)
	along = BAY * (ceilf(along / BAY) if float(d[6]) > 0.0 else floorf(along / BAY))
	var basis := Basis(Vector3.UP, d[7])
	var face := _wall_point(d[1], d[2], along, DIRECTION_Y, d[5])
	_put(_box(size), Transform3D(basis, face - basis.z * size.z * 0.5), _direction_paint(), false)
	_put(_box(Vector3(size.x + 0.01, 0.03, size.z + 0.01)), Transform3D(basis, face - basis.z * size.z * 0.5 + Vector3(0, size.y * 0.5 + 0.012, 0)), _trim, false)
	for n in lines.size():
		var y := (float(lines.size() - 1) * 0.5 - n) * DIRECTION_H * 1.3
		_direction_text(lines[n], face + basis.z * 0.005 + Vector3(0, y, 0), d[7], size.x - DIRECTION_H)


## A post in the courtyard with a blade pointing to each room's doorway, its name on both
## sides with an arrow at the pointed end.
func _fingerpost(foot: Vector3) -> void:
	if Flags.is_on("ship_bay.no_signs"):
		return
	var post_h := 2.2
	_put(_box(Vector3(0.07, post_h, 0.07)), _at(foot + Vector3(0, post_h * 0.5, 0)), _galv)
	_put(_box(Vector3(0.11, 0.04, 0.11)), _at(foot + Vector3(0, post_h + 0.02, 0)), _trim, false)
	var y := post_h - 0.15
	for id: String in ROOMS:
		if id == "bay":
			continue
		var door := way_to("bay", id)
		var to := Vector3(door.x - foot.x, 0.0, door.y - foot.z)
		var yaw := atan2(-to.z, to.x)   # the blade's +X toward the doorway
		var name := (ROOMS[id].name as String).to_upper()
		var length := direction_width(name + "  →") + DIRECTION_H * 1.6
		var b := Basis(Vector3.UP, yaw)
		var mid := foot + Vector3(0, y, 0) + b.x * (length * 0.5 + 0.035)
		_put(_box(Vector3(length, DIRECTION_H * 1.5, 0.02)), Transform3D(b, mid), _direction_paint(), false)
		_put(_box(Vector3(0.025, DIRECTION_H * 1.5 + 0.01, 0.03)), Transform3D(b, mid + b.x * (length * 0.5 - 0.0125)), _trim, false)
		_direction_text(name + "  →", mid + b.z * 0.016, yaw, length - DIRECTION_H)
		_direction_text("←  " + name, mid - b.z * 0.016, yaw + PI, length - DIRECTION_H)
		y -= DIRECTION_H * 1.5 + 0.04


## How wide a line of direction sign letters is, metres (the font Label3D draws with).
static func direction_width(text: String) -> float:
	return ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x * DIRECTION_H / 96.0


## The direction signs' yellow board paint (one material for all of them).
func _direction_paint() -> Material:
	if _direction_mat == null:
		_direction_mat = _paint(DIRECTION_BOARD, 0.1, 0.5, "satin_paint")
	return _direction_mat


## A line of direction sign letters facing `yaw` in a strip `width` metres across, set to the
## side its arrow points ("↑" lines in the middle).
func _direction_text(text: String, at: Vector3, yaw: float, width: float) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 0
	label.pixel_size = DIRECTION_H / 96.0
	label.font = ThemeDB.fallback_font   # the font direction_width measures with
	label.modulate = DIRECTION_INK
	# Centred on its own width, slid to its side of the strip.
	var slack := (width - direction_width(text)) * 0.5
	var side := 1.0 if text.ends_with("→") else 0.0 if text.begins_with("↑") else -1.0
	label.position = at + Basis(Vector3.UP, yaw).x * (slack * side)
	label.rotation.y = yaw
	label.shaded = false
	label.double_sided = false
	label.add_to_group("direction_sign")
	add_child(label)
	return label


## A room sign beside a doorway: on wall `axis` at `at`, the doorway centred at `u` and
## `width` wide, the sign `w` off the wall's middle line (its face), to side `dir` along the
## wall, a jamb's width clear of the doorway.
func _door_sign(text: String, axis: String, at: float, u: float, width: float, w: float, dir: float, yaw: float) -> Label3D:
	var wide := _board_size(text, DOOR_SIGN_H).x
	var along := u + dir * (width * 0.5 + 0.55 + wide * 0.5)
	return _sign(text, _wall_point(axis, at, along, DOOR_SIGN_Y, w), yaw, DOOR_SIGN_H)


## The dark board behind a sign's letters: wide enough for its longest line, tall enough
## for all of them.
static func _board_size(text: String, height_m: float) -> Vector2:
	var lines := text.split("\n")
	var longest := 0
	for line in lines:
		longest = maxi(longest, line.length())
	return Vector2(longest * height_m * 0.62 + height_m * 0.8, height_m * (1.3 + 1.2 * (lines.size() - 1)))


## A sign on a dark board with an orange edge (unless `board` is off), facing `yaw`.
func _sign(text: String, at: Vector3, yaw: float, height_m: float, board := true) -> Label3D:
	var label := Label3D.new()
	# No signs in the yard (beenster, 0.3.19: "not really that helpful"): an empty label
	# stands in so callers can still name or tint it.
	if Flags.is_on("ship_bay.no_signs"):
		label.visible = false
		add_child(label)
		return label
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
		var board_size := _board_size(text, height_m)
		var size := Vector3(board_size.x, board_size.y, 0.06)
		_put(_box(size), Transform3D(basis, at - basis.z * 0.06), _paint(Color(0.1, 0.11, 0.12), 0.3, 0.5, "satin_paint"), false)
		# The trim strip a touch wider, lower and shallower than the board, so no face of one
		# lies in the other's plane (that flickered).
		_put(_box(Vector3(size.x + 0.02, 0.06, 0.078)), Transform3D(basis, at - basis.z * 0.048 + Vector3(0, -size.y * 0.5 + 0.026, 0)), _trim, false)
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
	# Beside the doorway into the stores, not hanging in it.
	_sign("GOODS IN", Vector3(-44.0 - 0.55 - _board_size("GOODS IN", 0.45).x * 0.5, 5.6, -23.68), 0.0, 0.45)


## The storage hall, laid out by StorageLayout: three aisles of small racking (the bins in
## C2) on the east side, two aisles of large racks and the heavy racks by the west wall, a
## rack each side of every aisle, and the transfer aisle along the south wall. Every place is
## labelled with its location id (and the part kept there). It starts empty; the goods on it
## are drawn from the bus (_refresh_stores).
func _build_stock() -> void:
	var layout := StorageLayout.get_layout()
	var line := _paint(HAZARD, 0.0, 0.7, "hazard_paint")
	for rack: String in StorageLayout.rack_ids():
		_storage_rack(rack)
	# Lane lines down each aisle and along the transfer aisle and the back cross aisle.
	for aisle: String in layout["aisles"]:
		var x: float = layout["aisles"][aisle]
		var r := StorageLayout.rack(aisle + "1")
		var rack_len := float(r["bays"]) * float(r["bay"])
		var width := StorageLayout.aisle_width(aisle)
		for side: float in [-1.0, 1.0]:
			_block(Vector3(x + side * (width * 0.5 - 0.08), 0.024, StorageLayout.RACK_Z0 - rack_len * 0.5),
					Vector3(0.08, 0.004, rack_len), line, false)
		# Signs hang over the racks' tops, clear of the lifts' masts; the letter is painted
		# on the floor at the aisle's mouth too.
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
		if str(r["store"]) == "large":
			cats = PackedStringArray(["LARGE PARTS"])
		elif str(r["store"]) == "heavy":
			cats = PackedStringArray(["HEAVY MACHINES"])
		elif str(r["store"]) == "plate":
			cats = PackedStringArray()
			for id: String in StorageLayout.rack_ids():
				if id.begins_with(aisle):
					var name := str(StorageLayout.rack(id)["name"]).to_upper()
					if not cats.has(name):
						cats.append(name)
		if not cats.is_empty():
			_sign(" · ".join(cats), Vector3(x, 10.55, StorageLayout.RACK_Z0 + 0.2), 0.0, 0.2, false)
	for z: float in [StorageLayout.TRANSFER_Z - 1.4, StorageLayout.TRANSFER_Z + 1.4]:
		_block(Vector3(-25.0, 0.024, z), Vector3(49.0, 0.004, 0.08), line, false)
	_block(Vector3(-25.25, 0.024, StorageLayout.BACK_Z + 1.3), Vector3(48.5, 0.004, 0.08), line, false)
	# The heavy lift's hand-in: a painted box where a trolley lies along the transfer aisle.
	var hand := Vector3(-44.0, 0.0, -25.9)
	for dz: float in [-1.6, 1.6]:
		_block(hand + Vector3(0, 0.026, dz), Vector3(9.0, 0.004, 0.08), line, false)
	for dx: float in [-4.5, 4.5]:
		_block(hand + Vector3(dx, 0.026, 0), Vector3(0.08, 0.004, 3.2), line, false)
	_sign("HEAVY LIFT HAND-IN", Vector3(-44.0 - 0.55 - _board_size("HEAVY LIFT HAND-IN", 0.4).x * 0.5, 4.6, -23.68), 0.0, 0.4)


## One rack of StorageLayout: lattice end frames at each bay, orange beams and grating decks
## at each level, a location label on the beam under each place, a placard per bay.
func _storage_rack(rack: String) -> void:
	var L := StorageLayout
	var layout := L.get_layout()
	var r := L.rack(rack)
	var x := float(r["x"])
	var face := float(r["face"])
	var depth := float(r["depth"])
	var tall := float(r["height"])
	var length := float(r["bay"])
	var bays := int(r["bays"])
	var beams: Array = r["beams"]
	var heavy := str(r["store"]) != "small"
	var frame := _lib("truss/rack/%.1f/%.1f" % [tall, depth], func() -> PartShapes.PartShape:
			return PartShapes.truss(tall, 0.12 if heavy else 0.09, depth, int(tall + 1.0), 0.07 if heavy else 0.05))
	var beam := _box(Vector3(0.08 if heavy else 0.05, 0.2 if heavy else 0.12, length - 0.1))
	var deck := _lib("grating/rack/%.2f/%.2f" % [depth, length], func() -> PartShapes.PartShape:
			return WreckParts.grating(depth - 0.06, length - 0.12, 0.04 if heavy else 0.03))
	# Lattice frame stood up: its length up (Y), its height across the rack (X).
	var stand := Basis(Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1))
	for i in bays + 1:
		var z := L.RACK_Z0 - i * length
		_put(frame, Transform3D(stand, Vector3(x, tall * 0.5, z)), _blue, false)
		for side: float in [-0.5, 0.5]:
			_put(_box(Vector3(0.2 if heavy else 0.16, 0.012, 0.2 if heavy else 0.16)), _at(Vector3(x + depth * side, 0.006, z)), _bare, false)
	for bay in range(1, bays + 1):
		var z := L.bay_z(bay, rack)
		for level in range(1, beams.size() + 1):
			var y := float(beams[level - 1])
			for side: float in [-0.5, 0.5]:
				_put(beam, _at(Vector3(x + depth * side, y, z)), _trim, false)
			if level > 1:
				_put(deck, _at(Vector3(x, y + 0.075, z)), _galv, false)
		var info: Dictionary = {}
		for b: Dictionary in layout["bays"]:
			if b["rack"] == rack and b["bay"] == bay:
				info = b
		var cat := str(info.get("category", ""))
		if str(r["store"]) == "plate":
			var first: Dictionary = layout["locations"].get("%s-%02d-1-1" % [rack, bay], {})
			var p := StockPlates.item(str(first.get("home", "")))
			_tag("%s-%02d  %s  %s x %s" % [rack, bay, str(r["name"] if r.get("long", false) else r["material"]).to_upper(), p.get("length_mm", "?"), p.get("width_mm", "?")],
					Vector3(x + face * (depth * 0.5 + 0.05), tall - 0.35, z), 0.13, Vector3(face, 0, 0))
			continue
		var title := "%s-%02d  %s" % [rack, bay, str(L.CATEGORIES.get(cat, cat)).to_upper() if cat != "" else
				("LARGE PARTS" if str(r["store"]) == "large" else ("HEAVY" if heavy else "SPARE"))]
		_tag(title, Vector3(x + face * (depth * 0.5 + 0.05), tall - 0.35, z), 0.11 if not heavy else 0.16, Vector3(face, 0, 0))
	for id: String in layout["locations"]:
		var l: Dictionary = layout["locations"][id]
		if l["rack"] != rack:
			continue
		var at: Vector3 = l["at"]
		_tag(_place_text(l), Vector3(x + face * (depth * 0.5 + 0.04), at.y - 0.06 - (0.05 if heavy else 0.0), at.z), 0.045 if not heavy else 0.07, Vector3(face, 0, 0))
	_collide_xf(_box_shape(Vector3(depth + 0.1, tall, bays * length)),
			_at(Vector3(x, tall * 0.5, L.RACK_Z0 - bays * length * 0.5)))


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


## Store 2, in the old Material prep hall (beenster, 0.3.15): its racks are StorageLayout's
## and built with Stock's (_build_stock); here the lane lines along its transfer aisle and
## its back cross aisle, the lane down its west wall from Stock's doorway, and its picking
## lift's hand-in in the courtyard outside its door.
func _build_prep() -> void:
	var line := _paint(HAZARD, 0.0, 0.7, "hazard_paint")
	for z: float in [StorageLayout.TRANSFER_Z - 1.4, StorageLayout.TRANSFER_Z + 1.4]:
		_block(Vector3(25.0, 0.024, z), Vector3(49.0, 0.004, 0.08), line, false)
	_block(Vector3(25.0, 0.024, StorageLayout.BACK_Z + 1.3), Vector3(49.0, 0.004, 0.08), line, false)
	_block(Vector3(2.9, 0.024, -35.0), Vector3(0.08, 0.004, 11.6), line, false)
	var hand: Array = TrolleyFleet.HANDOFF_TROLLEYS["p7"]
	var at: Vector3 = hand[0]
	var box := Vector2(3.6, 7.2)
	for dx: float in [-box.x * 0.5, box.x * 0.5]:
		_block(Vector3(at.x + dx, 0.026, -24.0 + box.y * 0.5 + 0.3), Vector3(0.08, 0.004, box.y), line, false)
	_block(Vector3(at.x, 0.026, -24.0 + box.y + 0.3), Vector3(box.x, 0.004, 0.08), line, false)
	_sign("STORE 2 HAND-IN", Vector3(at.x, 6.4, -24.0 + 0.4), 0.0, 0.4)


## The plate hall (beenster, 0.3.23): its floor, roof and lamps (its walls are _walls()'),
## lane lines down its two aisles and along the way in from Stock's door, and the plasma
## cutting bed's place in the middle, painted out and kept clear for Tools' machine. Its
## plate racks are StorageLayout's, built with Stock's.
func _build_plate_hall() -> void:
	var r := StorageLayout.PLATE_HALL
	var line := _paint(HAZARD, 0.0, 0.7, "hazard_paint")
	# The floor runs a little under the walls; a hair over the wings' so no faces share a plane.
	_block(Vector3(r.get_center().x, 0.0024, r.get_center().y), Vector3(r.size.x + T, 0.04, r.size.y + T),
			_surface(_paint(Color(0.52, 0.54, 0.56), 0.0, 0.55, "satin_paint"), "epoxy"))   # solid, as the wings' floors
	_hall_joints(r, 0.0229)
	var roof := _paint(Color(0.32, 0.33, 0.35), 0.4, 0.7, "galvanised")
	# (It stops short of the north wing's roof: overlapping, they flickered.)
	var west := r.position.x - (T + 0.3) * 0.5
	var east := r.end.x - (T + 0.6) * 0.5 - 0.05
	_block(Vector3((west + east) * 0.5, H + 0.3, r.get_center().y), Vector3(east - west, 0.6, r.size.y + T + 0.3), roof)
	# The way in from the door, south of the racks.
	var z0 := StorageLayout.RACK_Z0
	for z: float in [z0 + 0.6, r.end.y - 1.6]:
		_block(Vector3(r.get_center().x + 0.5, 0.026, z), Vector3(r.size.x - 3.0, 0.004, 0.08), line, false)
	# The cutting bed's place: a hazard border round the room Tools asked for.
	var bed: Transform3D = SPOTS["cutting_bed"]
	var room: Vector3 = ShipBayBus.CUTTING_BED_ROOM
	for k: float in [-0.5, 0.5]:
		_block(bed * Vector3(room.x * k, 0.026, 0), Vector3(0.12, 0.004, room.z), line, false)
		_block(bed * Vector3(0, 0.026, room.z * k), Vector3(room.x + 0.12, 0.004, 0.12), line, false)
	_sign("PLASMA CUTTING", Vector3(bed.origin.x, 8.4, r.position.y + T * 0.5 + 0.1), 0.0, 0.6)
	# High-bay lamps over the aisles and the bed.
	var fixture := _lib("light_strip/bay", func() -> PartShapes.PartShape:
			return WreckParts.light_strip(2.4, 0.36, 0.1, LAMP))
	# A board over each rack's open end naming its material (one rack a material).
	for pr: Array in StorageLayout.PLATE_RACKS + StorageLayout.LONG_RACKS:
		var rack := StorageLayout.rack(pr[0])
		var board := _sign(str(rack["name"]).to_upper(), Vector3(float(rack["x"]), float(rack["height"]) + 0.7, z0 + 0.15), 0.0, 0.32)
		board.name = "PlateSign_" + str(pr[0])
	for p: Vector3 in [Vector3(-98.1, 0, -40.0), Vector3(-98.1, 0, -30.0), Vector3(-87.2, 0, -40.0), Vector3(-87.2, 0, -30.0), Vector3(-92.0, 0, -23.0),
			Vector3(-79.6, 0, -40.0), Vector3(-79.6, 0, -30.0), Vector3(-71.4, 0, -40.0), Vector3(-56.2, 0, -40.0), Vector3(-56.2, 0, -30.0),
			Vector3(bed.origin.x, 0, bed.origin.z - 4.5), Vector3(bed.origin.x, 0, bed.origin.z + 4.5), Vector3(-67.0, 0, -23.0)]:
		_put(fixture, Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI), Vector3(p.x, H - 2.3, p.z)), _parts, false)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(p.x, H - 2.8, p.z)
		lamp.light_color = LAMP
		lamp.light_energy = 2.2
		lamp.omni_range = 20.0
		lamp.omni_attenuation = 0.7
		lamp.set_meta("gfx_no_shadow", true)
		add_child(lamp)


## Marks the four enclosed halls for Graphics (a reflection probe and baked bounce light
## each): a node per hall at the yard origin, in group "gfx_room", meta "gfx_box" its
## inside. The bay is the open courtyard, so it has none.
func _tag_rooms() -> void:
	var ids := ["deliveries", "stock", "prep", "preassembly", "plates"]
	if Flags.is_on("ship_bay.upgrade_hall"):
		ids.append("upgrades")
	for id: String in ids:
		var room := Node3D.new()
		room.name = "Room_" + id
		room.add_to_group("gfx_room")
		room.set_meta("gfx_box", upgrade_box() if id == "upgrades" else ROOMS[id]["box"])
		room.set_meta("gfx_id", "room:" + id)
		add_child(room)


func _build_preassembly() -> void:
	# The two refurbishment lines side by side down the hall, intake bays at the north end,
	# their trolleys at the south end; the crusher in its own house against the east wall.
	for id: String in RefurbLine.LINES:
		var l: Node3D = RefurbLine.new(id)
		add_child(l)
		lines[id] = l
	line = lines["a"]
	crusher = CrusherPlant.new()
	add_child(crusher)
	_build_crusher_house()


## The crusher house: a clad shed on portal frames against Pre-assembly's east wall (that
## wall is its west side, its small door the way through), open onto the front strip by a
## roller door at the west end of its south wall, lamps under the rafters. The plant inside
## is CrusherPlant's.
func _build_crusher_house() -> void:
	var r := CrusherPlant.HOUSE
	var hh := CrusherPlant.HOUSE_H
	var door := CrusherPlant.HOUSE_DOOR   # centre x, width, height
	var t := 0.3
	var clad := _paint(Color(0.36, 0.39, 0.42), 0.4, 0.55, "satin_paint")
	var top := hh - 0.02
	# The floor slab and the strip of concrete in front of it out to the apron.
	# (Its edges run a little under the building's wall and past its own, so no side lies in a
	# wall's plane.)
	var slab := Rect2(r.position.x - 0.05, r.position.y - 0.05, r.size.x + 0.1, r.size.y + 0.1)
	_block(Vector3(slab.get_center().x, -0.01, slab.get_center().y), Vector3(slab.size.x, 0.04, slab.size.y), _concrete, false)
	_slab_joints(r, 0.0)
	var front := Rect2(45.0, YARD.y + 0.5, r.end.x + 2.0 - 45.0, 35.0 - (YARD.y + 0.5))
	_block(Vector3(front.get_center().x, -0.01, front.get_center().y), Vector3(front.size.x, 0.04, front.size.y), _concrete, false)
	_slab_joints(front, 0.0)
	# Walls: north and east, and the south either side of the door and over it; the west is
	# the building's own east wall. They start just clear of its cladding ribs.
	var x0 := r.position.x + 0.08
	_block(Vector3((x0 + r.end.x) * 0.5, top * 0.5, r.position.y + t * 0.5), Vector3(r.end.x - x0, top, t), clad)
	_block(Vector3(r.end.x - t * 0.5, top * 0.5, r.get_center().y), Vector3(t, top, r.size.y - t * 2.0), clad)
	var zs := r.end.y - t * 0.5 - 0.02   # its face 2 cm in from the building's wall end
	var dl := door.x - door.y * 0.5
	var dr := door.x + door.y * 0.5
	_block(Vector3((x0 + dl) * 0.5, top * 0.5, zs), Vector3(dl - x0, top, t), clad)
	_block(Vector3((dr + r.end.x - t) * 0.5, top * 0.5, zs), Vector3(r.end.x - t - dr, top, t), clad)
	_block(Vector3(door.x, (door.z + top) * 0.5, zs), Vector3(door.y, top - door.z, t), clad)
	# The roof, overhanging east and south, and an orange fascia along its front.
	_block(Vector3(r.get_center().x + 0.2, hh + 0.15, r.get_center().y + 0.2), Vector3(r.size.x + 0.4, 0.3, r.size.y + 0.4),
			_paint(Color(0.3, 0.32, 0.34), 0.4, 0.6, "satin_paint"))
	_put(_box(Vector3(r.size.x + 0.44, 0.5, 0.1)), Transform3D(Basis(), Vector3(r.get_center().x + 0.2, hh + 0.1, r.end.y + 0.45)), _trim, false)
	# Portal frames: a column at each end and a rafter across the depth every 6 m.
	var col := _lib("ibeam/house_col", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(top - 0.5, 0.4, 0.5, 0.03))
	var rafter := _lib("ibeam/house_rafter", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(r.size.y - t * 2.0 - 0.02, 0.4, 0.5, 0.03))
	var upright := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var x := r.position.x + 6.0
	while x < r.end.x - 1.0:
		for z: float in [r.position.y + t + 0.27, r.end.y - t - 0.27]:
			if z > r.end.y - 1.0 and absf(x - door.x) < door.y * 0.5 + 0.4:
				continue   # no column in the doorway
			_put(col, Transform3D(upright, Vector3(x, (top - 0.5) * 0.5, z)), _frame, false)
		_put(rafter, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, top - 0.26, r.get_center().y)), _frame, false)
		x += 6.0
	# The rolled-up shutter over the door, hazard stripes up its jambs, the sign over it.
	_put(_lib("prism/house_shutter", func() -> PartShapes.PartShape:
			return PartShapes.prism(16, 0.45, door.y + 0.6)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(door.x, door.z + 0.5, r.end.y - t - 0.5)), _frame, false)
	for k: float in [-1.0, 1.0]:
		for i in 5:
			_put(_box(Vector3(0.2, 0.6, 0.06)), Transform3D(Basis(), Vector3(door.x + k * (door.y * 0.5 + 0.1), 0.4 + i * 1.2, r.end.y + 0.031)), _hazard, false)
	_sign("CRUSHER HOUSE", Vector3(r.position.x + 22.0, door.z + 1.6, r.end.y + 0.12), 0.0, 1.5)
	# Lamps under the rafters (shadowless; they burn all day).
	for lx: float in [r.position.x + 9.0, r.get_center().x + 4.0, r.end.x - 7.0]:
		for lz: float in [r.position.y + 7.0, r.end.y - 9.0]:
			var p := Vector3(lx, top - 1.0, lz)
			var lamp := OmniLight3D.new()
			lamp.position = p
			lamp.light_color = Color(1.0, 0.93, 0.82)
			lamp.light_energy = 2.0
			lamp.omni_range = 16.0   # m
			lamp.shadow_enabled = false
			lamp.set_meta("gfx_no_shadow", true)
			add_child(lamp)
			_put(_box(Vector3(1.4, 0.12, 0.4)), Transform3D(Basis(), p + Vector3(0, 0.1, 0)), _glow_mat(Color(1.0, 0.93, 0.82), 2.5), false)


## The upgrade hall: a clad shed on portal frames standing on its own (UPGRADE_HALL), a
## roller door at the east end of its south wall onto a concrete path down the crusher
## house's east end to the front strip. Inside, an epoxy floor with a hazard-bordered bay
## for each rig (UPGRADE_BAYS), its name and what it takes painted on the floor, the bays
## still to come marked with their stage; high-bay lamps over them.
func _build_upgrade_hall() -> void:
	var r := UPGRADE_HALL
	var hh := UPGRADE_H
	var door := UPGRADE_DOOR
	var t := 0.3
	var top := hh - 0.02
	var clad := _paint(Color(0.34, 0.38, 0.44), 0.4, 0.55, "satin_paint")
	# The floor: epoxy inside, a little under the walls; the path out to the front strip.
	_block(Vector3(r.get_center().x, 0.0024, r.get_center().y), Vector3(r.size.x + 0.1, 0.04, r.size.y + 0.1),
			_surface(_paint(Color(0.5, 0.53, 0.56), 0.0, 0.55, "satin_paint"), "epoxy"))   # solid, as the wings' floors
	_hall_joints(r, 0.0229)
	var path := Rect2(88.6, r.end.y + 0.05, 10.4, 24.45 - (r.end.y + 0.05))
	_block(Vector3(path.get_center().x, -0.01, path.get_center().y), Vector3(path.size.x, 0.04, path.size.y), _concrete, false)
	_slab_joints(path, 0.0)
	var link := Rect2(90.3, 24.45, 8.7, 35.0 - 24.45)
	_block(Vector3(link.get_center().x, -0.01, link.get_center().y), Vector3(link.size.x, 0.04, link.size.y), _concrete, false)
	_slab_joints(link, 0.0)
	# Walls: north, west, east whole; the south either side of the door and over it.
	_block(Vector3(r.get_center().x, top * 0.5, r.position.y + t * 0.5), Vector3(r.size.x, top, t), clad)
	_block(Vector3(r.position.x + t * 0.5, top * 0.5, r.get_center().y), Vector3(t, top, r.size.y - t * 2.0), clad)
	_block(Vector3(r.end.x - t * 0.5, top * 0.5, r.get_center().y), Vector3(t, top, r.size.y - t * 2.0), clad)
	var zs := r.end.y - t * 0.5
	var dl := door.x - door.y * 0.5
	var dr := door.x + door.y * 0.5
	_block(Vector3((r.position.x + dl) * 0.5, top * 0.5, zs), Vector3(dl - r.position.x, top, t), clad)
	_block(Vector3((dr + r.end.x) * 0.5, top * 0.5, zs), Vector3(r.end.x - dr, top, t), clad)
	_block(Vector3(door.x, (door.z + top) * 0.5, zs), Vector3(door.y, top - door.z, t), clad)
	# The roof, overhanging all round, and an orange fascia along its front.
	_block(Vector3(r.get_center().x, hh + 0.15, r.get_center().y), Vector3(r.size.x + 0.6, 0.3, r.size.y + 0.6),
			_paint(Color(0.3, 0.32, 0.34), 0.4, 0.6, "satin_paint"))
	_put(_box(Vector3(r.size.x + 0.64, 0.5, 0.1)), Transform3D(Basis(), Vector3(r.get_center().x, hh + 0.1, r.end.y + 0.35)), _trim, false)
	# Portal frames: a column at each side and a rafter across every 6 m.
	var col := _lib("ibeam/upgrade_col", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(top - 0.5, 0.4, 0.5, 0.03))
	var rafter := _lib("ibeam/upgrade_rafter", func() -> PartShapes.PartShape:
			return PartShapes.i_beam(r.size.y - t * 2.0 - 0.02, 0.4, 0.5, 0.03))
	var upright := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var x := r.position.x + 6.0
	while x < r.end.x - 1.0:
		for z: float in [r.position.y + t + 0.27, r.end.y - t - 0.27]:
			if z > r.end.y - 1.0 and absf(x - door.x) < door.y * 0.5 + 0.4:
				continue   # no column in the doorway
			_put(col, Transform3D(upright, Vector3(x, (top - 0.5) * 0.5, z)), _frame, false)
		_put(rafter, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, top - 0.26, r.get_center().y)), _frame, false)
		x += 6.0
	# The rolled-up shutter over the door and hazard stripes up its jambs.
	_put(_lib("prism/upgrade_shutter", func() -> PartShapes.PartShape:
			return PartShapes.prism(16, 0.45, door.y + 0.6)), Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(door.x, door.z + 0.5, r.end.y - t - 0.5)), _frame, false)
	for k: float in [-1.0, 1.0]:
		for i in 5:
			_put(_box(Vector3(0.2, 0.6, 0.06)), Transform3D(Basis(), Vector3(door.x + k * (door.y * 0.5 + 0.1), 0.4 + i * 1.2, r.end.y + 0.031)), _hazard, false)
	_sign("UPGRADE HALL", Vector3(door.x - 14.0, door.z + 0.9, r.end.y + 0.12), 0.0, 1.2)
	# The bays: a hazard border each, the name and what it takes painted at the aisle end,
	# the ones to come with their stage.
	var line := _paint(HAZARD, 0.0, 0.7, "hazard_paint")
	var b := UPGRADE_BAY
	for bay: Array in UPGRADE_BAYS:
		var c: Vector2 = bay[4]
		for k: float in [-0.5, 0.5]:
			_block(Vector3(c.x + b.x * k, 0.026, c.y), Vector3(0.12, 0.004, b.y), line, false)
			_block(Vector3(c.x, 0.026, c.y + b.y * k), Vector3(b.x + 0.12, 0.004, 0.12), line, false)
		var built := str(bay[3]) == ""
		var words := [str(bay[1]), str(bay[2])] if built else [str(bay[1]), str(bay[2]), "COMING IN " + str(bay[3])]
		for n in words.size():
			var paint := Label3D.new()
			paint.name = "BayPaint_%s_%d" % [bay[0], n]
			paint.text = words[n]
			paint.font = ShipKit.mono_font()
			paint.font_size = 96
			paint.pixel_size = (0.5 if n == 0 else 0.28) / 96.0
			paint.modulate = Color(0.95, 0.75, 0.1) if n != 2 else Color(0.9, 0.9, 0.88)
			paint.outline_size = 0
			paint.shaded = true
			paint.double_sided = false
			paint.width = (b.x - 0.8) / paint.pixel_size
			paint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			paint.position = Vector3(c.x, 0.03, c.y + b.y * 0.5 - 0.9 - n * 0.7)
			paint.rotation = Vector3(-PI * 0.5, 0, 0)
			add_child(paint)
	# High-bay lamps over the bays and the aisle (shadowless; they burn all day).
	for lp: Vector2 in [Vector2(70.0, -40.0), Vector2(81.0, -40.0), Vector2(92.0, -40.0), Vector2(70.0, -30.0), Vector2(81.0, -30.0),
			Vector2(92.0, -30.0), Vector2(70.0, -19.0), Vector2(81.0, -19.0), Vector2(93.0, -19.0)]:
		var p := Vector3(lp.x, top - 1.0, lp.y)
		var lamp := OmniLight3D.new()
		lamp.position = p
		lamp.light_color = Color(1.0, 0.93, 0.82)
		lamp.light_energy = 3.0
		lamp.omni_range = 22.0   # m
		lamp.omni_attenuation = 0.6
		lamp.shadow_enabled = false
		lamp.set_meta("gfx_no_shadow", true)
		add_child(lamp)
		_put(_box(Vector3(1.4, 0.12, 0.4)), Transform3D(Basis(), p + Vector3(0, 0.1, 0)), _glow_mat(Color(1.0, 0.93, 0.82), 2.5), false)


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
		_block(Vector3(x, 0.01, mark.get_center().y), Vector3(0.3, 0.0115, mark.size.y), paint, false)   # its top clear of the cross lines'
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
	# Floodlights hung under the runway girders, between the columns, aimed into the courtyard.
	var bar := _lib("headlamp/flood", func() -> PartShapes.PartShape:
			return WreckParts.headlamp_bar(2.4, 4, LAMP))
	for x: float in [-YARD.x + 1.4, YARD.x - 1.4]:
		for z: float in [-16.5, 16.5]:
			_floodlight(bar, Vector3(x, top - 0.3, z), Vector3(x * 0.25, 0, z * 0.4))
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


## Dock 1, after a planetary shipyard's dry docks: launch towers out on the plain (the overlook
## balcony and its stair came out in 0.3.8, beenster's call). Work at height on the
## ship is done from the scissor lift (and mobile scaffolds), which drive out of the way, so
## the dock has no fixed gantries: it takes ships much bigger than the Kestrel.
const DOCK := "D1"


func _build_dock() -> void:
	_build_launch_towers()


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


## A floodlight: a lamp bar at `at` facing `target`, with a big warm spot that only burns
## at night. These are the yard's main lights after dark, so they keep their shadows.
func _floodlight(bar: String, at: Vector3, target: Vector3) -> void:
	var basis := Basis.looking_at((target - at).normalized(), Vector3.UP)
	# The bar's lamps face +Y: tip it so they face the target.
	_put(bar, Transform3D(basis * Basis(Vector3.RIGHT, -PI * 0.5), at), _parts, false)
	var flood := SpotLight3D.new()
	flood.position = at + (target - at).normalized() * 0.25
	flood.light_color = LAMP
	flood.light_energy = 10.0
	flood.spot_range = 40.0   # m
	flood.spot_angle = 45.0   # degrees
	flood.spot_attenuation = 0.7
	add_child(flood)
	flood.look_at(target)
	_night(flood)


## Outside: floodlight masts at the open corners and on the apron, a tank farm and power
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
	# Two at the open corners lighting the courtyard, two on the apron's edges over the pads.
	for mast: Array in [[Vector3(-YARD.x - 2.0, 0, YARD.y + 3.0), Vector3(-6, 0, 6)], [Vector3(YARD.x + 2.0, 0, YARD.y + 3.0), Vector3(6, 0, 6)],
			[Vector3(-47, 0, 60), Vector3(-14, 0, 56)], [Vector3(47, 0, 60), Vector3(14, 0, 56)]]:
		var foot: Vector3 = mast[0]
		_put(lattice, Transform3D(UPRIGHT, foot + Vector3(0, 7.5, 0)), _galv)
		_put(_box(Vector3(1.4, 0.4, 1.4)), _at(foot + Vector3(0, 0.2, 0)), _concrete)
		_put(platform, _at(foot + Vector3(0, 15.0, 0)), _galv, false)
		_put(ladder, _at(foot + Vector3(0, 7.3, 0.36)), _galv, false)
		var target: Vector3 = mast[1]
		var to := Vector3(target.x - foot.x, 0, target.z - foot.z).normalized()
		_floodlight(head, foot + Vector3(0, 15.6, 0) + to * 0.3, target)

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
	var pad_edge := 56.0 if Flags.is_on("ship_bay.apron") else 86.0
	while z < 86.0:
		if z < pad_edge:
			_put(stud, _at(Vector3(0, 0.02, z)), lit, false)
		for x: float in [-40.0, 40.0]:
			_put(stud, _at(Vector3(x, 0.02, z)), _glow_mat(Color(0.4, 0.86, 1.0), 3.0), false)
		z += 4.0


# --- Props --------------------------------------------------------------------------------

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
	# Goods still being beamed onto a place aren't on it yet.
	var arriving: Dictionary = trolleys.get("arriving") if trolleys else {}
	for loc: String in locations:
		var have := _bus.stock_at(loc)
		if have.is_empty():
			continue
		if arriving.has(loc):
			have = have.duplicate()
			have["qty"] = int(have["qty"]) - int(arriving[loc])
			if int(have["qty"]) <= 0:
				continue
		var l: Dictionary = locations[loc]
		var item: Dictionary = StorageLayout.items().get(have["item"], {})
		# Every part as itself (beenster 0.3.24: no crates or boxes), small ones loose in their bin.
		var room: Vector3 = l["size"]
		_goods_items(batches, str(have["item"]), int(have["qty"]), float(have.get("condition", 1.0)),
				Vector2(room.x, room.z), room.y - 0.25, l["at"], l["kind"] == "pallet")
		var room_box: Vector3 = l["size"]
		ItemLook.look_box(_stores, AABB(l["at"] - Vector3(room_box.x * 0.5, 0.0, room_box.z * 0.5), room_box),
				{"component": str(have["item"]), "condition": float(have.get("condition", 1.0)), "location": loc})
		var tag := _tag("%s  x%d" % [item.get("name", have["item"]), int(have["qty"])],
				l["at"] + Vector3(float(l["face"].x) * (float(l["size"].x) * 0.5 + 0.06), 0.55 if l["kind"] != "bulk" else 1.4, 0), 0.06, l["face"], _stores)
	var crates := _bus.delivered_crates()
	for id: String in crates:
		var c: Dictionary = crates[id]
		if str(c.get("carrier", "")) != "" or c.has("line"):
			continue   # on a trolley's deck (the trolley draws it) or the line's (it does)
		if trucks and trucks.call("is_arriving", id):
			continue   # still on its delivery truck
		var at := _bus.crate_position(id)
		var kind := StorageLayout.kind_for(float(c["mass"]), str(c["item"]))
		var h := _goods_items(batches, ItemLook.look_id(str(c["item"]), str(c.get("shape", ""))), int(c["qty"]), float(c.get("condition", 1.0)),
				Vector2(2.4, 2.4) if kind == "bulk" else Vector2(1.2, 1.4), 2.4, at, kind != "bulk")
		var foot := Vector2(2.4, 2.4) if kind == "bulk" else Vector2(1.2, 1.4)
		ItemLook.look_box(_stores, AABB(at - Vector3(foot.x * 0.5, 0.0, foot.y * 0.5), Vector3(foot.x, maxf(h, 0.2), foot.y)),
				{"component": str(c["item"]), "condition": float(c.get("condition", 1.0)), "crate_id": id, "qty": int(c["qty"]),
				"look_id": ItemLook.look_id(str(c["item"]), str(c.get("shape", "")))})
		var dest := _bus.place_for(str(c["item"]))
		var tag := _tag("%s  x%d\n%s  ->  %s" % [c["name"], int(c["qty"]), str(c["grade"]).to_upper(), dest if dest != "" else "NO SPACE"],
				at + Vector3(0, h + 0.25, 0), 0.09, Vector3(0, 0, 1), _stores)
		tag.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tag.name = "Crate_" + id.replace("/", "_")
	for batch: Dictionary in batches.values():
		var mesh: Mesh = batch["mesh"] if batch.has("mesh") else (_shapes[batch.key] as PartShapes.PartShape).mesh
		_multimesh(_stores, mesh, batch.xforms, batch.mat)


## Adds goods as they are (ItemLook), `qty` of `item` stacked over `area` (x, z) up to
## `max_height`, on a pallet when `pallet`. Returns the stack's height (m).
func _goods_items(batches: Dictionary, item: String, qty: int, condition: float, area: Vector2, max_height: float,
		at: Vector3, pallet: bool) -> float:
	var lift := 0.0
	if pallet:
		_goods_add(batches, _box(Vector3(1.0, 0.14, 1.2)), _wood, Transform3D(Basis.IDENTITY, at + Vector3(0, 0.07, 0)))
		lift = 0.144
	var size := ItemLook.size_of(item)
	var spots := ItemLook.stack(size, maxi(qty, 1), area, maxf(max_height, size.y))
	var top := 0.0
	for spot: Transform3D in spots:
		top = maxf(top, spot.origin.y + size.y)
		var place := Transform3D(Basis.IDENTITY, at + Vector3(0, lift, 0)) * spot
		for piece: Array in ItemLook.pieces(item, ItemLook.look_for(condition)):
			var b := "item|%d|%d" % [(piece[0] as Mesh).get_rid().get_id(), (piece[1] as Material).get_instance_id()]
			if not batches.has(b):
				batches[b] = {"mesh": piece[0], "mat": piece[1], "xforms": []}
			(batches[b].xforms as Array).append(place * (piece[2] as Transform3D))
	return lift + top


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
## Tags a ground paint for Graphics' ground surfaces (concrete, ground, epoxy, asphalt); with
## its flag off Graphics leaves the paint as it is.
func _surface(mat: Material, kind: String) -> Material:
	mat.set_meta("gfx_surface", kind)
	return mat


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
