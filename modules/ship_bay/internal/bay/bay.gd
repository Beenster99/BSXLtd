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

const TIGHT := Color(0.3, 0.9, 0.4)
const LOOSE := Color(1.0, 0.65, 0.1)

var ship_root: Node3D
## slot_id -> Array of the model's MeshInstance3Ds inside its box.
var pieces: Dictionary = {}
## joint_id -> MeshInstance3D marker.
var markers: Dictionary = {}
var _bus: ShipBayBus
var _tight_mat := _paint(TIGHT, true)
var _loose_mat := _paint(LOOSE, true)


func _ready() -> void:
	_bus = Modules.bus("ship_bay") as ShipBayBus
	if standalone:
		_build_stage()
	_build_cradles()
	if _bus == null:
		return
	if _bus.ship == null or _bus.ship.ship_id != ship_id:
		_bus.load_ship(ship_id)
	_bus.slot_state_changed.connect(_on_slot_changed)
	_bus.component_installed.connect(func(_s: String, _c: String) -> void: _refresh_markers())
	_show_ship(_bus.ship)


func _exit_tree() -> void:
	if _bus and _bus.slot_state_changed.is_connected(_on_slot_changed):
		_bus.slot_state_changed.disconnect(_on_slot_changed)


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
			_part(cradle, PartShapes.box(Vector3(0.6, 0.03, 0.8)), Transform3D(Basis(), Vector3(x, 0.015, 0)), dark)
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


func _show_ship(def: ShipDefinition) -> void:
	if ship_root:
		ship_root.queue_free()
	pieces = {}
	markers = {}
	if def == null:
		return
	ship_root = Node3D.new()
	ship_root.name = "Ship"
	ship_root.position = Vector3(0, cradle_height, 0)
	add_child(ship_root)
	if def.model:
		ship_root.add_child(def.model.instantiate())
	pieces = pieces_by_slot(ship_root, def)
	for s in def.slots:
		for f in s.fasteners:
			var m := MeshInstance3D.new()
			var dot := SphereMesh.new()
			dot.radius = 0.06
			dot.height = 0.12
			m.mesh = dot
			m.position = f.position + f.normal * 0.03
			ship_root.add_child(m)
			markers[f.joint_id] = m
		_apply_slot(s.slot_id)
	_refresh_markers()


## The model's mesh pieces whose centre lies in each slot's box (ship space). The Kestrel's
## export has no names, so position is the only link between a piece and its slot.
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
		m.material_override = _tight_mat if _bus.is_joint_tight(id) else _loose_mat


static func _paint(c: Color, lit := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	if lit:
		m.emission_enabled = true
		m.emission = c
	return m
