extends Node3D
## The bay: a floor, a cradle and the loaded ship sitting on it, with a marker on every
## fastener (green tight, amber undone). Pieces of the model inside a slot's box hide while
## the slot is empty. Grey-box for now; Trades' tools work on it from release 0.3.

## Height of the ship's deck (y = 0 in ship space) over the bay floor, metres.
@export var cradle_height := 1.6
@export var ship_id := "vs_kestrel"
## Off when the bay sits inside another scene (the shipyard's courtyard), which brings its
## own ground, sky, sun and camera; the bay then adds only its cradles and the ship.
@export var standalone := true

## The fastener rings' one quiet colour and glow, tight or undone (beenster, 0.3.17: the
## green and amber rings hid the fasteners; Tools' look card says a joint's state). Matches
## Tools' TradesLook.QUIET_RING.
const QUIET_RING := Color(0.62, 0.74, 0.86)
const QUIET_GLOW := 0.35

const Access := preload("res://modules/ship_bay/internal/bay/bay_access.gd")
const TransportCradle := preload("res://modules/ship_bay/internal/yard/transport_cradle.gd")
## How far Use (F) reaches from the camera, metres.
const USE_REACH := 3.5

var ship_root: Node3D
## With ship_bay.bay_cradle (beenster, 0.3.19): the ship sits in a transport cradle ("BayCradle")
## on four pedestals instead of three fixed stands, so a transporter can drive it out; the
## ship rides with the cradle. Null with the flag off.
var cradle: Node3D
## The ship's model (its root node), and the lift and power unit round it.
var model: Node3D
var access: Node3D
## slot_id -> Array of the model's MeshInstance3Ds inside its box.
var pieces: Dictionary = {}
## joint_id -> MeshInstance3D marker.
var markers: Dictionary = {}
var _bus: ShipBayBus
var _tight_mat := _quiet_ring()
var _loose_mat := _tight_mat
var _head_mat := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.35))


func _ready() -> void:
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if standalone:
		_build_stage()
	if Flags.is_on("ship_bay.bay_cradle"):
		_build_transport_cradle()
	else:
		_build_cradles()
	if _bus == null:
		return
	# An emptied bay (Settings > Debug > Ship) stays empty until the Kestrel is brought back.
	if (_bus.ship == null and not _bus.bay_cleared) or (_bus.ship and _bus.ship.ship_id != ship_id):
		_bus.load_ship(ship_id)
	_bus.ship_loaded.connect(_on_ship_changed)
	_bus.ship_unloaded.connect(_on_ship_changed)
	_bus.slot_state_changed.connect(_on_slot_changed)
	_bus.ship_power_changed.connect(_on_power)
	_bus.component_installed.connect(func(_s: String, _c: String) -> void: _refresh_markers())
	_bus.joint_changed.connect(_on_joint_changed)
	_bus.marker_focus_changed.connect(_on_marker_focus)
	_show_ship(_bus.ship)


func _exit_tree() -> void:
	if _bus and _bus.ship_loaded.is_connected(_on_ship_changed):
		_bus.ship_loaded.disconnect(_on_ship_changed)
		_bus.ship_unloaded.disconnect(_on_ship_changed)
	if _bus and _bus.slot_state_changed.is_connected(_on_slot_changed):
		_bus.slot_state_changed.disconnect(_on_slot_changed)
	if _bus and _bus.ship_power_changed.is_connected(_on_power):
		_bus.ship_power_changed.disconnect(_on_power)
	if _bus and _bus.marker_focus_changed.is_connected(_on_marker_focus):
		_bus.marker_focus_changed.disconnect(_on_marker_focus)
	if _bus and _bus.joint_changed.is_connected(_on_joint_changed):
		_bus.joint_changed.disconnect(_on_joint_changed)


## Three ship cradles, each an I-beam base on the floor with two posts, a head beam under
## the belly carried on hydraulic rams and a rubber pad on top (Void Salvage's parts on its
## ship surface). One box per cradle collides.
func _build_cradles() -> void:
	var top := cradle_height - 0.5
	var yellow := ShipSurface.of(ShipKit.paint(Color(0.95, 0.75, 0.1), 0.15, 0.5, "hazard_paint"))
	var steel := ShipSurface.of(ShipKit.paint(Color(0.55, 0.57, 0.6), 0.85, 0.3, "chrome"))
	var dark := ShipSurface.of(ShipKit.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5, "gunmetal"))
	var rubber := ShipSurface.of(ShipKit.paint(Color(0.07, 0.07, 0.075), 0.0, 0.9, "rubber"))
	var upright := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	# Clear of the landing skids (z -1.6 and 5.2) and the belly jets.
	for z: float in [-3.4, 1.5, 4.2]:
		var cradle := Node3D.new()
		cradle.name = "Cradle"
		cradle.position = Vector3(0, 0, z)
		add_child(cradle)
		_part(cradle, PartShapes.i_beam(3.6, 0.6, 0.25, 0.03), Transform3D(Basis(), Vector3(0, 0.125, 0)), yellow)
		_part(cradle, PartShapes.i_beam(3.2, 0.45, 0.22, 0.03), Transform3D(Basis(), Vector3(0, top - 0.2, 0)), yellow)
		for x: float in [-1.35, 1.35]:
			_part(cradle, PartShapes.i_beam(top - 0.56, 0.4, 0.3, 0.03), Transform3D(upright, Vector3(x, 0.25 + (top - 0.56) * 0.5, 0)), yellow)
			_part(cradle, PartShapes.box(Vector3(0.6, 0.029, 0.8)), Transform3D(Basis(), Vector3(x, 0.0145, 0)), dark)   # under the flange tops
		for x: float in [-0.55, 0.55]:
			_part(cradle, WreckParts.pipe(0.09, top - 0.56, false), Transform3D(Basis(), Vector3(x, 0.25 + (top - 0.56) * 0.5, 0)), steel)
			_part(cradle, WreckParts.pipe(0.13, 0.3, true), Transform3D(Basis(), Vector3(x, 0.4, 0)), dark)
		_part(cradle, PartShapes.chamfer_box(Vector3(2.8, 0.1, 0.5), 0.03), Transform3D(Basis(), Vector3(0, top - 0.05, 0)), rubber)
		var solid := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(3.2, top, 0.6)
		shape.position.y = top * 0.5
		solid.add_child(shape)
		cradle.add_child(solid)


## The transport cradle the ship sits in, on its four pedestals: the ship's deck then stands
## at the cradle's saddle tops (cradle_height follows).
func _build_transport_cradle() -> void:
	cradle = TransportCradle.new("s")
	cradle.name = "BayCradle"
	add_child(cradle)
	cradle.position = Vector3(0, TransportCradle.REST, 0)
	cradle_height = TransportCradle.REST + float(cradle.get("saddle_top"))
	var frame := ShipSurface.of(ShipKit.paint(Color(0.34, 0.37, 0.4), 0.6, 0.45, "gunmetal"))
	var bare := ShipSurface.of(ShipKit.paint(Color(0.5, 0.52, 0.55), 0.7, 0.5))
	var stands := StaticBody3D.new()
	stands.name = "Pedestals"
	add_child(stands)
	var spots: Array[Vector3] = []
	for x: float in [-float(cradle.get("side_x")), float(cradle.get("side_x"))]:
		for z: float in cradle.get("pedestal_z"):
			spots.append(Vector3(x, 0, z))
	for at: Vector3 in spots:
		var h := TransportCradle.REST - 0.06
		_part(self, PartShapes.chamfer_box(Vector3(0.9, h, 0.9), 0.05), Transform3D(Basis(), at + Vector3(0, 0.06 + h * 0.5, 0)), frame)
		_part(self, PartShapes.box(Vector3(1.3, 0.05, 1.3)), Transform3D(Basis(), at + Vector3(0, 0.035, 0)), bare)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = Vector3(0.9, TransportCradle.REST, 0.9)
		shape.position = at + Vector3(0, TransportCradle.REST * 0.5, 0)
		stands.add_child(shape)


static func _part(parent: Node3D, shape: PartShapes.PartShape, xform: Transform3D, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = shape.mesh
	mi.material_override = mat
	mi.transform = xform
	parent.add_child(mi)


func _build_stage() -> void:
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor_mesh.mesh = plane
	floor_mesh.material_override = _paint(Color(0.22, 0.23, 0.25))
	add_child(floor_mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.06, 0.08)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.52, 0.56)
	add_child(env)
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.position = Vector3(9.5, 5.5, 13.0)
	add_child(cam)
	cam.look_at(Vector3(0, cradle_height + 1.2, 2.5))


## The bay's ship came or went (Settings > Debug > Ship, or a load): show what's there now.
func _on_ship_changed(_id: String) -> void:
	var def := _bus.ship if _bus else null
	if def == null or model == null or model.get_meta("ship_id", "") != def.ship_id:
		_show_ship(def)


func _show_ship(def: ShipDefinition) -> void:
	if ship_root:
		ship_root.queue_free()
		ship_root = null
	model = null
	if access:
		access.queue_free()
		access = null
	pieces = {}
	markers = {}
	if def == null:
		return
	ship_root = Node3D.new()
	ship_root.name = "Ship"
	if cradle:
		cradle.call("carry", ship_root, Vector3(0, float(cradle.get("saddle_top")), 0))
		cradle.set("load_t", 25.0)
	else:
		ship_root.position = Vector3(0, cradle_height, 0)
		add_child(ship_root)
	if def.model:
		model = def.model.instantiate() as Node3D
		model.set_meta("ship_id", def.ship_id)
		ship_root.add_child(model)
	pieces = model.call("slot_pieces", def) if model and model.has_method("slot_pieces") else pieces_by_slot(ship_root, def)
	_build_access()
	for s in def.slots:
		for f in s.fasteners:
			var m := _fastener_marker(f)
			ship_root.add_child(m)
			markers[f.joint_id] = m
		_apply_slot(s.slot_id)
	_refresh_markers()


## The scissor lift and the ground power unit, for a model that says where its
## side door and power socket are.
func _build_access() -> void:
	if access:
		access.queue_free()
		access = null
	if model == null or not model.has_method("access_points"):
		return
	var points: Dictionary = model.call("access_points")
	access = Access.new()
	access.name = "Access"
	add_child(access)
	if cradle:
		# Outboard of the cradle's side beam and its pin levers, with a gangway over them.
		var sill: Vector3 = points["side_door"]
		var clear := float(cradle.get("side_x")) + 0.2 + 0.35 + 0.05
		# The flank and roof stops go up with the ship.
		var levels: Array[float] = []
		for h: float in access.get("lift_levels"):
			levels.append(h if h < 1.0 else h + cradle_height - 1.6)
		access.set("lift_levels", levels)
		access.call("build", cradle_height, sill, points["power_socket"], ship_root, maxf(clear - absf(sill.x), 0.0),
				TransportCradle.REST + TransportCradle.SIZES["s"].side_h + 0.15)
	else:
		access.call("build", cradle_height, points["side_door"], points["power_socket"], ship_root)
	access.connect("power_switched", func(on: bool) -> void:
		if _bus:
			_bus.set_ship_powered(on)
		else:
			_on_power(on))
	var on := _bus != null and _bus.ship_powered
	access.call("set_power", on)
	_on_power(on, true)


## The ship powered or not; `instant` skips its power-up sweep (on loading).
func _on_power(on: bool, instant := false) -> void:
	if model and model.has_method("set_powered"):
		model.call("set_powered", on, instant)
	if access:
		access.call("set_power", on)


func _unhandled_input(event: InputEvent) -> void:
	var use: bool = event.is_action_pressed(Keys.INTERACT) if InputMap.has_action(Keys.INTERACT) \
			else (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F)
	if not use or event.is_echo():
		return
	var cam := get_viewport().get_camera_3d()
	if cam and use_along(cam.global_position, -cam.global_basis.z):
		get_viewport().set_input_as_handled()


## Left click: with the power plug in hand it goes where you look; else the first clickable
## thing within reach (the plug, its hook). _input, so a held tool doesn't take the click.
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	# A screen in front of the view (the wrist holo, a menu) keeps its clicks.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if click_along(cam.global_position, -cam.global_basis.z):
		get_viewport().set_input_as_handled()


## A left click along the ray (world space): places the plug in hand, or clicks the first
## clickable thing within reach. True if it did something.
func click_along(from: Vector3, direction: Vector3) -> bool:
	if access and bool(access.call("holding_plug")):
		access.call("place_plug", from, direction)
		return true
	return _call_along(from, direction, "ship_bay_click")


## Use (F): the first usable thing within reach along the ray (world space). True if one was.
func use_along(from: Vector3, direction: Vector3) -> bool:
	return _call_along(from, direction, "ship_bay_use")


func _call_along(from: Vector3, direction: Vector3, meta: String) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * USE_REACH)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	var body := hit.collider as CollisionObject3D
	var owner_id := body.shape_find_owner(int(hit.shape)) if body else -1
	var node: Object = body.shape_owner_get_owner(owner_id) if owner_id >= 0 else null
	for n: Object in [node, body]:
		if n and n.has_meta(meta):
			(n.get_meta(meta) as Callable).call()
			return true
	return false


## A fastener as it looks on the ship: its head (a hex bolt, a domed rivet, a round plug) on
## a thin washer ring in one quiet pale blue, tight or undone. The ring is the marker
## (Tools' look card names the state); the head is its child, so hiding the ring hides both.
func _fastener_marker(f: FastenerPoint) -> MeshInstance3D:
	var n := f.normal.normalized()
	if f.kind == "weld" and f.seam_up != Vector3.ZERO:
		# A weld is its bead along the seam on a thin strip lit by its state.
		var along := (f.seam_up - n * f.seam_up.dot(n)).normalized()
		var strip := MeshInstance3D.new()
		var length := maxf(f.seam_size.x, 0.02)
		var width := maxf(f.seam_size.y, 0.006)
		strip.mesh = PartShapes.box(Vector3(width + 0.005, 0.002, length)).mesh
		strip.transform = Transform3D(Basis(n.cross(along), n, along), f.position + n * 0.002)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bead := MeshInstance3D.new()
		bead.mesh = PartShapes.prism(6, width * 0.5, length - 0.004).mesh
		bead.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, width * 0.25, 0))
		bead.material_override = _head_mat
		strip.add_child(bead)
		return strip
	var side := Vector3.UP if absf(n.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var x := side.cross(n).normalized()
	var ring := MeshInstance3D.new()
	var big := f.kind != "rivet"
	ring.mesh = PartShapes.ring(0.026 if big else 0.017, 0.031 if big else 0.020, 0.003, 16).mesh
	ring.transform = Transform3D(Basis(x, n, x.cross(n)), f.position + n * 0.002)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var head := MeshInstance3D.new()
	match f.kind:
		"rivet":
			head.mesh = PartShapes.dome(0.014, 0.009, 8, 2).mesh
			head.position.y = 0.0045
		"connector":
			head.mesh = PartShapes.prism(12, 0.04, 0.05).mesh
			head.position.y = 0.025
		_:
			head.mesh = PartShapes.prism(6, 0.021, 0.016).mesh
			head.position.y = 0.01
	head.material_override = _head_mat
	ring.add_child(head)
	return ring


## The model's mesh pieces whose centre lies in each slot's box (ship space), for a model
## that can't say which pieces are a slot's part (`slot_pieces`).
static func pieces_by_slot(root: Node3D, def: ShipDefinition) -> Dictionary:
	var out := {}
	for s in def.slots:
		out[s.slot_id] = []
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var centre := _ship_xform(mi, root) * mi.mesh.get_aabb().get_center()
		for s in def.slots:
			if s.box.has_point(centre):
				(out[s.slot_id] as Array).append(mi)
				break
	return out


static func _ship_xform(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _on_slot_changed(slot_id: String, _old: int, _new: int) -> void:
	_apply_slot(slot_id)
	_refresh_markers()


func _apply_slot(slot_id: String) -> void:
	var gone := _bus.get_slot_state(slot_id) == ShipBayBus.SlotState.EMPTY
	for mi: MeshInstance3D in pieces.get(slot_id, []):
		mi.visible = not gone


func _refresh_markers() -> void:
	for id: String in markers:
		var m: MeshInstance3D = markers[id]
		var slot_state := _bus.get_slot_state(FastenerPoint.slot_of(id))
		m.visible = slot_state != ShipBayBus.SlotState.EMPTY
		_show_joint(id)
	_on_marker_focus(_bus.marker_focus_at, _bus.marker_focus_radius)


## A joint made or taken out: its marker shows it at once (the slot's state may not change).
func _on_joint_changed(joint_id: String, _made: bool) -> void:
	if markers.has(joint_id):
		_show_joint(joint_id)


## The ring (or weld strip) is lit by the joint's state; the head (or bead) on it shows only
## while the joint is made, so an undone bolt, a cut-out rivet or a ground-off weld leaves
## just its lit ring where it was (beenster, 0.3.20).
func _show_joint(joint_id: String) -> void:
	var m: MeshInstance3D = markers[joint_id]
	var tight := _bus.is_joint_tight(joint_id)
	m.material_override = _tight_mat if tight else _loose_mat
	for head: Node in m.get_children():
		(head as Node3D).visible = tight


## Only the rings near the focus point show (ShipBayBus.set_marker_focus); the heads always
## do. A ring out of focus drops its mesh (the head is its child, so hiding it would hide both).
func _on_marker_focus(at: Vector3, radius_m: float) -> void:
	if ship_root == null:
		return
	var local := ship_root.global_transform.affine_inverse() * at
	for id: String in markers:
		var m: MeshInstance3D = markers[id]
		if not m.has_meta("ring_mesh"):
			m.set_meta("ring_mesh", m.mesh)
		var near := is_inf(radius_m) or m.position.distance_to(local) <= radius_m
		m.mesh = m.get_meta("ring_mesh") if near else null


static func _quiet_ring() -> StandardMaterial3D:
	var m := _paint(QUIET_RING, true)
	m.emission_energy_multiplier = QUIET_GLOW
	return m


static func _paint(c: Color, lit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if lit:
		m.emission_enabled = true
		m.emission = c
	return m
