extends Node3D
## Delivery trucks (beenster, 0.3.15): each order Business delivers comes on a hover truck
## from one of a few haulage companies, in its livery with its logo on the pod's sides and
## doors. It glides in along the road from the west, turns up the dock apron, swings round
## and backs onto a free truck door, opens its doors and sets the crates down, then closes
## up and drives away. Until it has unloaded, its crates aren't drawn on the goods-in floor
## and the trolleys leave them be.
##
## Presentation on every peer: each yard sends its own truck when it hears delivery_landed
## (the crates themselves are bus state, the same everywhere). With the flag
## "ship_bay.trucks" off, crates land at once with no truck.

## The haulage companies: name, slogan, pod colour, band and logo colour, logo shape.
const BRANDS := [
	{"name": "HALCYON FREIGHT", "tag": "SYSTEM-WIDE PARCELS", "body": Color(0.86, 0.88, 0.86), "band": Color(0.08, 0.55, 0.6), "logo": "ring"},
	{"name": "REDLINE CARGO", "tag": "FAST. HEAVY. ON TIME.", "body": Color(0.15, 0.15, 0.17), "band": Color(0.86, 0.16, 0.12), "logo": "chevron"},
	{"name": "NOVA LOGISTICS", "tag": "PARTS FOR THE OUTER BELT", "body": Color(0.9, 0.9, 0.93), "band": Color(0.46, 0.26, 0.78), "logo": "star"},
	{"name": "DUSTRUNNER", "tag": "PLANETSIDE HAULAGE", "body": Color(0.74, 0.62, 0.46), "band": Color(0.92, 0.46, 0.1), "logo": "wedge"},
	{"name": "ORBITAL EXPRESS", "tag": "DOCK TO DOCK", "body": Color(0.12, 0.2, 0.36), "band": Color(0.96, 0.76, 0.16), "logo": "arc"},
]
## The truck doors in Deliveries' west wall (z), the order a truck takes them in.
const DOCKS: Array[float] = [8.0, -8.0]
## Where a docked truck's rear stands (x), and the truck's length, metres.
const REAR_X := -50.6
const LENGTH := 16.2
## Where trucks come from and go to along the road, yard space.
const ROAD_START := Vector3(-175.0, 0, 30.0)
const ROAD_TURN := Vector3(-92.0, 0, 30.0)
## The lift pads' float over the ground, metres.
const FLOAT := 0.7

## Cruising speed on the road and backing speed onto the dock, metres per second.
@export var road_speed := 9.0
@export var back_speed := 2.2
## How fast a truck turns on the spot, radians per second.
@export var spin_rate := 0.6
## How long a docked truck stands with its doors open, seconds.
@export var dwell := 7.0
## Everything a truck does runs this much faster (tests).
@export var time_scale := 1.0
## After this long a delivery's crates land even if its truck hasn't got there, seconds.
@export var give_up_after := 120.0

var yard: Node3D
## Crate ids still on a truck: crate id -> order id.
var waiting: Dictionary = {}
## The trucks on the move: {body, order, dock, plan, step, v, t, doors, brand}.
var runs: Array = []
## Orders whose trucks haven't set off yet (both docks busy): [order id, crate ids].
var _queue: Array = []
var _bus: ShipBayBus
var _mats: Dictionary = {}
var _boxes: Dictionary = {}


func _ready() -> void:
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if _bus:
		_bus.delivery_landed.connect(_on_landed)


## True while crate `crate_id` is still on its way on a truck.
func is_arriving(crate_id: String) -> bool:
	return waiting.has(crate_id)


## The brand of the truck bringing order `order_id` (the same on every peer).
static func brand_for(order_id: String) -> Dictionary:
	return BRANDS[absi(hash(order_id)) % BRANDS.size()]


## Parks a truck of each company's livery at the docks with its doors open (screenshots).
func park_for_show(order_id := "PO-SHOW") -> void:
	var dock := 0
	var body := _build_truck(brand_for(order_id))
	body.global_transform = _dock_xform(DOCKS[dock])
	runs.append({"body": body, "order": order_id, "dock": dock, "plan": [], "step": 0, "v": 0.0, "t": 0.0, "doors": 1.0, "crates": []})
	_set_doors(runs[-1], 1.0)


func _on_landed(order_id: String, crate_ids: PackedStringArray) -> void:
	if not Flags.is_on("ship_bay.trucks") or crate_ids.is_empty():
		return
	for cid in crate_ids:
		waiting[cid] = order_id
	_queue.append([order_id, crate_ids])
	_start_queued()
	if yard:
		yard.call("_refresh_stores")


func _start_queued() -> void:
	while not _queue.is_empty():
		var dock := _free_dock()
		if dock < 0:
			return
		var next: Array = _queue.pop_front()
		_send(str(next[0]), next[1], dock)


func _free_dock() -> int:
	for i in DOCKS.size():
		if not runs.any(func(r: Dictionary) -> bool: return int(r["dock"]) == i):
			return i
	return -1


## Sends a truck for an order to dock `dock`: in along the road, up the apron, round on the
## spot to face away from the wall, back onto the door, unload, and away.
func _send(order_id: String, crate_ids: PackedStringArray, dock: int) -> void:
	var z := DOCKS[dock]
	var body := _build_truck(brand_for(order_id))
	body.global_transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), ROAD_START)
	var park := _dock_xform(z).origin
	var plan: Array = [
		{"go": ROAD_TURN, "speed": road_speed},
		{"go": Vector3(-86.0, 0, z + 9.0), "speed": road_speed * 0.6},
		{"go": Vector3(-86.0, 0, z), "speed": 3.0, "stop": true},
		{"spin": PI * 0.5},
		{"back": park},
		{"doors": 1.0},
		{"unload": true},
		{"wait": dwell},
		{"doors": 0.0},
		{"go": Vector3(-96.0, 0, z), "speed": 4.0},
		{"go": Vector3(-104.0, 0, 24.0), "speed": 6.0},
		{"go": ROAD_START, "speed": road_speed},
		{"leave": true},
	]
	runs.append({"body": body, "order": order_id, "dock": dock, "plan": plan, "step": 0, "v": 0.0, "t": 0.0,
			"doors": 0.0, "crates": crate_ids, "age": 0.0})


## A docked truck's place: nose to the west, rear doors on the truck door at z.
func _dock_xform(z: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(REAR_X - LENGTH * 0.5, 0, z))


func _physics_process(delta: float) -> void:
	var dt := delta * time_scale
	for run: Dictionary in runs.duplicate():
		run["age"] = float(run.get("age", 0.0)) + dt
		if float(run["age"]) > give_up_after:
			_unload(run)
		_step(run, dt)
	_start_queued()


func _step(run: Dictionary, dt: float) -> void:
	var plan: Array = run["plan"]
	if int(run["step"]) >= plan.size():
		return
	var s: Dictionary = plan[int(run["step"])]
	var body: Node3D = run["body"]
	var xf := body.global_transform
	if s.has("go"):
		var to: Vector3 = s["go"]
		var off := to - xf.origin
		off.y = 0.0
		var dist := off.length()
		var top := float(s.get("speed", road_speed))
		var want := minf(top, sqrt(2.0 * 2.5 * dist) + 0.3) if s.get("stop", false) else top
		run["v"] = move_toward(float(run["v"]), want, 2.5 * dt)
		if dist <= maxf(float(run["v"]) * dt, 0.05) or (not s.get("stop", false) and dist < 2.0):
			_next(run)
			return
		var dir := off / dist
		var yaw := _turn_toward(xf.basis.get_euler().y, atan2(-dir.x, -dir.z), 1.2 * dt)
		body.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin + dir * float(run["v"]) * dt)
	elif s.has("spin"):
		var now := xf.basis.get_euler().y
		var yaw := _turn_toward(now, float(s["spin"]), spin_rate * dt)
		body.global_transform = Transform3D(Basis(Vector3.UP, yaw), xf.origin)
		if absf(wrapf(yaw - float(s["spin"]), -PI, PI)) < 0.001:
			_next(run)
	elif s.has("back"):
		var to: Vector3 = s["back"]
		var off := to - xf.origin
		off.y = 0.0
		var dist := off.length()
		run["v"] = move_toward(float(run["v"]), minf(back_speed, sqrt(2.0 * 1.2 * dist) + 0.05), 1.2 * dt)
		if dist <= maxf(float(run["v"]) * dt, 0.01):
			body.global_transform = Transform3D(xf.basis, to)
			_next(run)
			return
		body.global_transform = Transform3D(xf.basis, xf.origin + off / dist * float(run["v"]) * dt)
	elif s.has("doors"):
		var target := float(s["doors"])
		_set_doors(run, move_toward(float(run["doors"]), target, 0.7 * dt))
		if is_equal_approx(float(run["doors"]), target):
			_next(run)
	elif s.has("unload"):
		_unload(run)
		_next(run)
	elif s.has("wait"):
		run["t"] = float(run["t"]) + dt
		if float(run["t"]) >= float(s["wait"]):
			_next(run)
	elif s.has("leave"):
		_unload(run)
		runs.erase(run)
		body.queue_free()


func _next(run: Dictionary) -> void:
	run["step"] = int(run["step"]) + 1
	run["t"] = 0.0
	var plan: Array = run["plan"]
	if int(run["step"]) < plan.size() and (plan[int(run["step"])] as Dictionary).has("back"):
		run["v"] = 0.0


static func _turn_toward(from: float, to: float, step: float) -> float:
	var d := wrapf(to - from, -PI, PI)
	return from + clampf(d, -step, step)


## The truck has set its crates down: they show on the goods-in floor and may be put away.
func _unload(run: Dictionary) -> void:
	var any := false
	for cid in run.get("crates", PackedStringArray()):
		if waiting.erase(cid):
			any = true
	if any and yard:
		yard.call("_refresh_stores")


func _set_doors(run: Dictionary, open: float) -> void:
	run["doors"] = open
	var body: Node3D = run["body"]
	for side: float in [-1.0, 1.0]:
		var hinge := body.get_node_or_null("Door%d" % int(side)) as Node3D
		if hinge:
			hinge.rotation.y = side * open * PI * 0.55


# --- The truck -----------------------------------------------------------------------------

func _mat(color: Color, metallic: float, roughness: float, finish := "") -> Material:
	if yard and yard.has_method("_paint"):
		return yard.call("_paint", color, metallic, roughness, finish)
	var key := "%s/%.2f/%.2f/%s" % [color.to_html(), metallic, roughness, finish]
	if not _mats.has(key):
		_mats[key] = ShipSurface.of(ShipKit.paint(color, metallic, roughness, finish))
	return _mats[key]


func _glow(color: Color, energy: float) -> Material:
	if yard and yard.has_method("_glow_mat"):
		return yard.call("_glow_mat", color, energy)
	return ShipKit.glow(color, energy)


func _piece(parent: Node3D, shape: PartShapes.PartShape, xf: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = xf
	parent.add_child(mi)
	if shape.glass:
		var g := MeshInstance3D.new()
		g.mesh = shape.glass
		g.material_override = Glazing.material(shape.glass_kind)
		g.transform = xf
		parent.add_child(g)
	return mi


func _cube(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var key := "%.3f/%.3f/%.3f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		_boxes[key] = PartShapes.box(size)
	return _piece(parent, _boxes[key], Transform3D(Basis.IDENTITY, at), mat)


func _label(parent: Node3D, text: String, at: Vector3, yaw: float, height_m: float, colour: Color, outline := Color(0, 0, 0, 0)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = height_m / 96.0
	l.modulate = colour
	l.outline_size = 8 if outline.a > 0.0 else 0
	l.outline_modulate = outline
	l.shaded = false
	l.double_sided = false
	l.position = at
	l.rotation.y = yaw
	parent.add_child(l)
	return l


## A hover truck in a company's livery. Local space: the nose to -Z, the rear doors at
## +LENGTH/2, origin on the ground under its middle.
func _build_truck(brand: Dictionary) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = "Truck_%s" % str(brand["name"]).replace(" ", "")
	body.sync_to_physics = false
	body.set_meta("brand", brand["name"])
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 3.4, LENGTH)
	shape.shape = box
	shape.position = Vector3(0, FLOAT + 1.7, 0)
	body.add_child(shape)
	var half := LENGTH * 0.5
	var paint := _mat(brand["body"], 0.25, 0.35, "gloss_paint")
	var band := _mat(brand["band"], 0.2, 0.4, "gloss_paint")
	var dark := _mat(Color(0.1, 0.11, 0.12), 0.5, 0.5)
	var steel := _mat(Color(0.55, 0.57, 0.6), 0.8, 0.35)
	var rubber := _mat(Color(0.06, 0.06, 0.06), 0.0, 0.9, "rubber_tread")
	var edge := _glow(Color(0.4, 0.86, 1.0), 4.0)
	var lamp := _glow(Color(1.0, 0.95, 0.85), 5.0)
	var red := _glow(Color(1.0, 0.15, 0.08), 4.0)
	var amber := _glow(Color(1.0, 0.62, 0.1), 3.0)
	var pod_len := 12.0
	var pod_z := half - pod_len * 0.5   # the pod's centre: its back is the truck's rear
	var pod_y := FLOAT + 0.5 + 1.35
	# The spine: a chassis beam the length of the truck, lift pads under it glowing.
	_piece(body, PartShapes.chamfer_box(Vector3(2.2, 0.45, LENGTH - 0.6), 0.12), Transform3D(Basis.IDENTITY, Vector3(0, FLOAT + 0.22, 0)), dark)
	for z: float in [-6.6, -3.3, 0.0, 3.3, 6.6]:
		for x: float in [-0.65, 0.65]:
			_piece(body, PartShapes.prism(16, 0.42, 0.08), Transform3D(Basis.IDENTITY, Vector3(x, FLOAT - 0.04, z)), edge)
		_cube(body, Vector3(2.4, 0.18, 0.5), Vector3(0, FLOAT + 0.1, z), steel)   # pad cross-members
	for z: float in [-3.0, 4.0]:
		var under := OmniLight3D.new()
		under.position = Vector3(0, 0.25, z)
		under.light_color = Color(0.4, 0.86, 1.0)
		under.light_energy = 1.2
		under.omni_range = 3.0
		under.set_meta("gfx_no_shadow", true)
		body.add_child(under)
	# The pod: a ribbed box van in the company's paint, a band down each side, the logo and
	# name on the sides, roof marker lamps, a bumper and tail lamps at the back.
	_piece(body, PartShapes.chamfer_box(Vector3(2.5, 2.7, pod_len), 0.08), Transform3D(Basis.IDENTITY, Vector3(0, pod_y, pod_z)), paint)
	for i in 9:
		var z := pod_z - pod_len * 0.5 + 0.7 + i * (pod_len - 1.4) / 8.0
		for side: float in [-1.0, 1.0]:
			_cube(body, Vector3(0.05, 2.5, 0.1), Vector3(side * 1.27, pod_y, z), steel)
		_cube(body, Vector3(2.3, 0.05, 0.1), Vector3(0, pod_y + 1.37, z), steel)
	for side: float in [-1.0, 1.0]:
		_cube(body, Vector3(0.04, 0.38, pod_len - 0.4), Vector3(side * 1.28, pod_y - 0.9, pod_z), band)
		_cube(body, Vector3(0.04, 0.08, pod_len - 0.4), Vector3(side * 1.28, pod_y + 1.1, pod_z), band)
		_logo(body, brand, Vector3(side * 1.31, pod_y + 0.25, pod_z - 3.4), side)
		_label(body, str(brand["name"]), Vector3(side * 1.31, pod_y + 0.35, pod_z + 1.2), side * PI * 0.5, 0.62, brand["band"], Color(0.02, 0.02, 0.02, 0.6))
		_label(body, str(brand["tag"]), Vector3(side * 1.31, pod_y - 0.3, pod_z + 1.2), side * PI * 0.5, 0.22, brand["band"].lightened(0.2))
		_cube(body, Vector3(0.06, 0.06, LENGTH - 1.0), Vector3(side * 1.12, FLOAT + 0.47, 0), edge)   # lit edge strip
		for z: float in [pod_z - 5.6, pod_z, pod_z + 5.6]:
			_cube(body, Vector3(0.06, 0.1, 0.16), Vector3(side * 1.27, pod_y + 1.3, z), amber)   # side markers
	# The rear: two door leaves on hinges at the pod's back corners (they swing open at the
	# dock), the logo on them, a bumper, tail lamps and a step.
	for side: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.name = "Door%d" % int(side)
		hinge.position = Vector3(side * 1.24, pod_y, half + 0.04)
		body.add_child(hinge)
		_cube(hinge, Vector3(1.22, 2.6, 0.06), Vector3(-side * 0.61, 0, 0.0), paint)
		_cube(hinge, Vector3(1.0, 0.3, 0.02), Vector3(-side * 0.61, -0.9, 0.04), band)
		for y: float in [-0.9, 0.9]:
			_cube(hinge, Vector3(0.18, 0.08, 0.06), Vector3(-side * 0.05, y, 0.04), steel)   # hinge straps
		_cube(hinge, Vector3(0.05, 1.6, 0.05), Vector3(-side * 1.12, 0, 0.06), steel)   # locking bar
		_label(hinge, str(brand["name"]).split(" ")[0], Vector3(-side * 0.61, 0.6, 0.05), 0.0, 0.2, brand["band"])
		_cube(body, Vector3(0.3, 0.16, 0.06), Vector3(side * 0.95, FLOAT + 0.62, half + 0.18), red)
		_cube(body, Vector3(0.12, 0.12, 0.06), Vector3(side * 0.55, FLOAT + 0.62, half + 0.18), amber)
	_cube(body, Vector3(2.5, 0.22, 0.25), Vector3(0, FLOAT + 0.35, half + 0.1), rubber)
	_cube(body, Vector3(1.2, 0.05, 0.4), Vector3(0, FLOAT - 0.05, half + 0.15), steel)
	_cube(body, Vector3(2.2, 0.08, 0.08), Vector3(0, pod_y + 1.4, half + 0.02), red)
	# The cab: a rounded body ahead of the pod, a raked nose with a grille and headlamps, a
	# wrap-round windscreen, side windows and doors, mirrors on arms, a roof light bar and
	# steps under the doors.
	var cab_z := pod_z - pod_len * 0.5 - 1.75   # the cab's centre, just ahead of the pod
	var cab_y := FLOAT + 0.45 + 1.15
	_piece(body, PartShapes.chamfer_box(Vector3(2.5, 2.3, 3.0), 0.45), Transform3D(Basis.IDENTITY, Vector3(0, cab_y, cab_z)), paint)
	_piece(body, PartShapes.wedge(Vector3(2.4, 1.2, 1.4)), Transform3D(Basis(Vector3.UP, PI), Vector3(0, FLOAT + 1.05, cab_z - 1.95)), paint)
	_piece(body, PartShapes.window_rect(2.2, 0.95, 0.06), Transform3D(Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI * 0.5 - 0.5), Vector3(0, cab_y + 0.55, cab_z - 1.38)), dark)
	_cube(body, Vector3(2.0, 0.45, 0.06), Vector3(0, FLOAT + 0.95, cab_z - 2.62), dark)   # grille
	for i in 5:
		_cube(body, Vector3(1.9, 0.04, 0.04), Vector3(0, FLOAT + 0.78 + i * 0.085, cab_z - 2.66), steel)
	_cube(body, Vector3(2.45, 0.12, 0.05), Vector3(0, FLOAT + 1.3, cab_z - 2.55), band)
	for side: float in [-1.0, 1.0]:
		_cube(body, Vector3(0.5, 0.18, 0.06), Vector3(side * 0.85, FLOAT + 0.95, cab_z - 2.66), lamp)   # headlamps
		_cube(body, Vector3(0.18, 0.1, 0.06), Vector3(side * 1.12, FLOAT + 1.2, cab_z - 2.6), amber)
		_piece(body, PartShapes.window_rect(1.3, 0.7, 0.05), Transform3D(Basis(Vector3.UP, side * PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5), Vector3(side * 1.26, cab_y + 0.5, cab_z + 0.1)), dark)
		_cube(body, Vector3(0.03, 1.9, 0.03), Vector3(side * 1.27, cab_y - 0.1, cab_z - 0.75), dark)   # door seams
		_cube(body, Vector3(0.03, 1.9, 0.03), Vector3(side * 1.27, cab_y - 0.1, cab_z + 0.85), dark)
		_cube(body, Vector3(0.05, 0.05, 0.25), Vector3(side * 1.29, cab_y - 0.1, cab_z + 0.6), steel)   # door handle
		_cube(body, Vector3(0.04, 0.3, 1.6), Vector3(side * 1.27, cab_y - 0.85, cab_z + 0.05), band)
		_cube(body, Vector3(0.5, 0.04, 0.04), Vector3(side * 1.5, cab_y + 0.55, cab_z - 1.1), steel)   # mirror arm
		_cube(body, Vector3(0.08, 0.42, 0.24), Vector3(side * 1.75, cab_y + 0.5, cab_z - 1.1), dark)
		for k in 2:
			_cube(body, Vector3(0.3, 0.05, 0.5), Vector3(side * 1.25, FLOAT + 0.25 + k * 0.32, cab_z + 0.05), steel)   # steps
	_cube(body, Vector3(1.6, 0.1, 0.18), Vector3(0, cab_y + 1.2, cab_z - 0.6), amber)   # roof light bar
	_cube(body, Vector3(1.8, 0.06, 0.3), Vector3(0, cab_y + 1.13, cab_z - 0.6), dark)
	_logo(body, brand, Vector3(0, cab_y + 0.15, cab_z - 1.6), 0.0, 0.35)
	var head := SpotLight3D.new()
	head.position = Vector3(0, FLOAT + 0.95, cab_z - 2.8)
	head.light_color = Color(1.0, 0.95, 0.85)
	head.light_energy = 2.5
	head.spot_range = 22.0
	head.spot_angle = 35.0
	head.set_meta("gfx_no_shadow", true)
	body.add_child(head)
	# The coupling between cab and pod.
	_cube(body, Vector3(2.2, 1.6, 0.2), Vector3(0, FLOAT + 1.4, pod_z - pod_len * 0.5 - 0.12), dark)
	return body


## The company's logo, a flat badge on a side (`side` +1 east-facing, -1 west; 0 the front).
func _logo(parent: Node3D, brand: Dictionary, at: Vector3, side: float, scale := 1.0) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation.y = side * PI * 0.5 if side != 0.0 else PI
	holder.scale = Vector3.ONE * scale
	parent.add_child(holder)
	var c := _mat(brand["band"], 0.2, 0.4, "gloss_paint")
	var back := _mat((brand["body"] as Color).darkened(0.25), 0.2, 0.5)
	_cube(holder, Vector3(1.6, 1.6, 0.02), Vector3.ZERO, back)
	match str(brand["logo"]):
		"ring":
			for i in 16:
				var a := TAU * i / 16.0
				var seg := _cube(holder, Vector3(0.22, 0.12, 0.03), Vector3(cos(a) * 0.55, sin(a) * 0.55, 0.02), c)
				seg.rotation.z = a + PI * 0.5
			_cube(holder, Vector3(0.3, 0.3, 0.03), Vector3(0, 0, 0.02), c)
		"chevron":
			for k in 3:
				for s: float in [-1.0, 1.0]:
					var bar := _cube(holder, Vector3(0.6, 0.14, 0.03), Vector3(s * 0.2, 0.35 - k * 0.35, 0.02), c)
					bar.rotation.z = -s * 0.6
		"star":
			for k in 4:
				var ray := _cube(holder, Vector3(1.3 if k % 2 == 0 else 0.8, 0.12, 0.03), Vector3(0, 0, 0.02), c)
				ray.rotation.z = k * PI * 0.25
		"wedge":
			for k in 4:
				_cube(holder, Vector3(1.2 - k * 0.28, 0.2, 0.03), Vector3(-k * 0.14, 0.45 - k * 0.3, 0.02), c)
		_:
			for i in 9:
				var a := PI * 0.15 + PI * 0.7 * i / 8.0
				var seg := _cube(holder, Vector3(0.24, 0.1, 0.03), Vector3(cos(a) * 0.6, sin(a) * 0.6 - 0.3, 0.02), c)
				seg.rotation.z = a + PI * 0.5
			_cube(holder, Vector3(0.22, 0.22, 0.03), Vector3(0, 0.05, 0.02), c)
