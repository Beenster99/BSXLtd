extends Node3D
## The airlock between the corridor and the dock: an inner and an outer door, never both
## open. F on any of its three panels (corridor, inside, on the hull outside) cycles it: the
## open door closes, the lamps go amber while it pumps, then the other door opens. Gravity
## holds inside it; past the outer door the dock is weightless.

enum State { INNER_OPEN, OUTER_OPEN, CLOSING, PUMPING, OPENING }

## Seconds for a door to close or open, and to pump the air.
@export var door_time := 0.9
@export var pump_time := 1.4

var state: State = State.INNER_OPEN
## Where the cycle is going: true towards the outer door.
var going_out := false
var inner_door: AnimatableBody3D
var outer_door: AnimatableBody3D
var _t := 0.0
## Where a pressed panel goes instead of cycling here at once (the station's shared clock).
var on_use: Callable
var _lamps: Array[MeshInstance3D] = []
var _lamp_mats: Dictionary = {}
## With yard.airlock_detail: each panel's big button and its status screen's text.
var _buttons: Array[MeshInstance3D] = []
var _screens: Array[Label3D] = []
var _kit


func build(kit) -> void:
	_kit = kit
	var k = kit
	var wall: Material = k.paint(Color(0.7, 0.72, 0.75), 0.1, 0.7)
	var hazard: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes")
	var z0 := YardLayout.AIRLOCK_DOOR_Z.x
	var z1 := YardLayout.AIRLOCK_DOOR_Z.y
	var h := YardLayout.AIRLOCK_DOOR_H
	k.wall(true, -5.0, -40.1, -33.9, 0.0, 3.2, wall)
	k.wall(true, 1.0, -40.1, -33.9, 0.0, 3.2, wall)
	for x: float in [YardLayout.AIRLOCK_INNER_X, YardLayout.AIRLOCK_OUTER_X]:
		k.wall(false, x, -5.0, 1.0, 0.0, 3.2, wall, [[z0, z1, h]], 0.3)
		k.box(Vector3(0.34, 0.12, z1 - z0 + 0.24), Vector3(x, h + 0.06, (z0 + z1) * 0.5), hazard, false)
	k.span(Vector3(-39.5, 0.002, -4.5), Vector3(-34.5, 0.012, 0.5), k.paint(Color(0.25, 0.26, 0.28), 0.6, 0.5, "tread_diamond_steel"), false)
	k.ceiling_lamp(Vector3(-37.0, 3.2, -2.0), Vector2(1.2, 1.2), 0.8, 6.0)
	inner_door = _door(YardLayout.AIRLOCK_INNER_X, "InnerDoor")
	outer_door = _door(YardLayout.AIRLOCK_OUTER_X, "OuterDoor")
	_panel(Vector3(-33.82, 1.3, -3.6), Vector3.RIGHT, "corridor")
	_panel(Vector3(-34.18, 1.3, -3.6), Vector3.LEFT, "inside")
	_panel(Vector3(-40.18, 1.3, -3.6), Vector3.LEFT, "outside")
	# State lamps over each door, both faces.
	for x: float in [-33.8, -34.2, -39.8, -40.2]:
		var lamp: MeshInstance3D = k.box(Vector3(0.06, 0.12, 0.5), Vector3(x, h + 0.3, (z0 + z1) * 0.5), _lamp_mat(Color.GREEN), false)
		_lamps.append(lamp)
	if Flags.is_on(YardBus.AIRLOCK_DETAIL):
		_detail(k, z0, z1, h)
	_apply_doors()


## Frames round both doors, handrails along the side walls, a pressure board, a vacuum sign
## by the outer door, vents and hazard strips on the thresholds (beenster, 21 Nov).
func _detail(k, z0: float, z1: float, h: float) -> void:
	var metal: Material = k.paint(Color(0.32, 0.34, 0.37), 0.6, 0.4)
	var dark: Material = k.paint(Color(0.15, 0.16, 0.18), 0.5, 0.5)
	var hazard: Material = k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes")
	var steel: Material = k.paint(Color(0.62, 0.64, 0.67), 0.8, 0.3)
	for x: float in [YardLayout.AIRLOCK_INNER_X, YardLayout.AIRLOCK_OUTER_X]:
		# Door posts, standing 2 cm into the opening so their faces clear the wall's.
		k.box(Vector3(0.4, h, 0.1), Vector3(x, h * 0.5, z0 - 0.03), metal, false, null, "AirlockFrame")
		k.box(Vector3(0.4, h, 0.1), Vector3(x, h * 0.5, z1 + 0.03), metal, false, null, "AirlockFrame")
	for x: float in [YardLayout.AIRLOCK_INNER_X - 0.32, YardLayout.AIRLOCK_OUTER_X + 0.32]:
		k.box(Vector3(0.3, 0.006, z1 - z0), Vector3(x, 0.015, (z0 + z1) * 0.5), hazard, false)
	# Handrails along both side walls, on stand-offs.
	for z: float in [-4.9, 0.9]:
		var out := 1.0 if z < 0.0 else -1.0
		k.box(Vector3(4.6, 0.045, 0.045), Vector3(-37.0, 1.05, z + out * 0.09), steel, false, null, "AirlockRail")
		for x: float in [-39.2, -37.0, -34.8]:
			k.box(Vector3(0.04, 0.04, 0.07), Vector3(x, 1.05, z + out * 0.035), steel, false)
	# Vents low on the back wall: a grille and its slats.
	for x: float in [-38.6, -35.4]:
		k.box(Vector3(0.6, 0.25, 0.03), Vector3(x, 0.35, -4.885), metal, false, null, "AirlockVent")
		for i in 4:
			k.box(Vector3(0.54, 0.022, 0.02), Vector3(x, 0.26 + i * 0.06, -4.86), dark, false)
	# The pressure board on the front wall: two dials, lock and dock.
	k.box(Vector3(0.7, 0.4, 0.03), Vector3(-37.0, 1.75, 0.885), dark, false, null, "AirlockGauges")
	for i in 2:
		var at := Vector3(-37.17 + i * 0.34, 1.72, 0.866)
		_disc(0.11, 0.012, metal, at, Vector3.FORWARD)
		_disc(0.09, 0.006, k.glow(Color(0.85, 0.9, 0.82), 0.6), at + Vector3(0, 0, -0.008), Vector3.FORWARD)
		var needle: MeshInstance3D = k.box(Vector3(0.012, 0.08, 0.004), at + Vector3(0, 0.03, -0.014), k.glow(Color(1.0, 0.25, 0.1), 2.0), false)
		needle.rotation.z = 0.7 if i == 0 else -1.1
		_label("DOCK" if i == 0 else "LOCK", at + Vector3(0, -0.15, -0.002), Vector3.FORWARD, 0.0016, Color(0.9, 0.92, 0.95))
	_label("PRESSURE", Vector3(-37.0, 1.9, 0.868), Vector3.FORWARD, 0.002, Color(0.9, 0.92, 0.95))
	# A vacuum warning by the outer door, on its inside face.
	k.box(Vector3(0.02, 0.36, 1.1), Vector3(-39.84, 1.74, -3.95), k.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6), false, null, "AirlockSign")
	_label("VACUUM BEYOND", Vector3(-39.828, 1.8, -3.95), Vector3.RIGHT, 0.0024, Color(0.08, 0.08, 0.1))
	_label("CYCLE BEFORE EXIT", Vector3(-39.828, 1.67, -3.95), Vector3.RIGHT, 0.002, Color(0.08, 0.08, 0.1))


## A flat disc of `radius` and `depth` (m) at `at`, its face turned to `normal` (station space).
func _disc(radius: float, depth: float, mat: Material, at: Vector3, normal: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 24
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = mat
	mi.basis = Basis(Quaternion(Vector3.UP, normal.normalized()))
	mi.position = at
	(parent if parent else self as Node3D).add_child(mi)
	return mi


## Unlit lettering facing `normal`.
func _label(text: String, at: Vector3, normal: Vector3, px: float, colour: Color, parent: Node3D = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = 48
	l.modulate = colour
	l.outline_size = 0
	l.double_sided = false
	l.shaded = false
	l.basis = Basis.looking_at(-normal, Vector3.UP)   # a label's front is its +z
	l.position = at
	(parent if parent else self as Node3D).add_child(l)
	return l


## Starts a cycle towards the outer door (out = true) or the inner one; does nothing if
## that door is already open or a cycle is under way.
func cycle(out: bool) -> void:
	if state == State.CLOSING or state == State.PUMPING or state == State.OPENING:
		return
	if (out and state == State.OUTER_OPEN) or (not out and state == State.INNER_OPEN):
		return
	going_out = out
	state = State.CLOSING
	_t = 0.0


## A panel pressed: "in", "out" or "toggle". Through `on_use` when the station shares it with
## the other players (co-op sync), which calls `operate` at the same moment on every machine.
func use(mode: String) -> void:
	if on_use.is_valid():
		on_use.call(mode)
	else:
		operate(mode)


func operate(mode: String) -> void:
	match mode:
		"in":
			cycle(false)
		"out":
			cycle(true)
		_:
			toggle()


## Whichever way is the other way.
func toggle() -> void:
	cycle(state == State.INNER_OPEN)


func is_busy() -> bool:
	return state == State.CLOSING or state == State.PUMPING or state == State.OPENING


## Moves the cycle on by `delta` seconds (the scene calls it each physics step; tests too).
func advance(delta: float) -> void:
	if not is_busy():
		return
	_t += delta
	match state:
		State.CLOSING:
			if _t >= door_time:
				state = State.PUMPING
				_t = 0.0
		State.PUMPING:
			if _t >= pump_time:
				state = State.OPENING
				_t = 0.0
		State.OPENING:
			if _t >= door_time:
				state = State.OUTER_OPEN if going_out else State.INNER_OPEN
				_t = 0.0
	_apply_doors()


## How open each door is (0 shut .. 1 open): [inner, outer].
func openness() -> Vector2:
	var k := clampf(_t / door_time, 0.0, 1.0)
	match state:
		State.INNER_OPEN:
			return Vector2(1, 0)
		State.OUTER_OPEN:
			return Vector2(0, 1)
		State.CLOSING:
			# The door being left closes.
			return Vector2(1.0 - k, 0) if going_out else Vector2(0, 1.0 - k)
		State.OPENING:
			return Vector2(0, k) if going_out else Vector2(k, 0)
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	advance(delta)


func _apply_doors() -> void:
	if inner_door == null:
		return
	var o := openness()
	var w := YardLayout.AIRLOCK_DOOR_Z.y - YardLayout.AIRLOCK_DOOR_Z.x
	var shut_z := (YardLayout.AIRLOCK_DOOR_Z.x + YardLayout.AIRLOCK_DOOR_Z.y) * 0.5
	inner_door.position.z = shut_z + o.x * (w + 0.05)
	outer_door.position.z = shut_z + o.y * (w + 0.05)
	_show_state()


## The lamps over the doors, the panels' buttons and their screens: green ready, red while a
## door moves, amber while it pumps.
func _show_state() -> void:
	var c := Color(0.2, 1.0, 0.35)
	var text := "READY"
	if state == State.PUMPING:
		c = Color(1.0, 0.6, 0.1)
		text = "PUMPING"
	elif is_busy():
		c = Color(1.0, 0.2, 0.15)
		text = "CYCLING"
	for l in _lamps:
		l.material_override = _lamp_mat(c)
	for b in _buttons:
		b.material_override = _button_mat(c)
	for s in _screens:
		s.text = text
		s.modulate = c


func _door(x: float, node_name: String) -> AnimatableBody3D:
	var d := AnimatableBody3D.new()
	d.name = node_name
	d.sync_to_physics = false
	var w := YardLayout.AIRLOCK_DOOR_Z.y - YardLayout.AIRLOCK_DOOR_Z.x
	var size := Vector3(0.12, YardLayout.AIRLOCK_DOOR_H, w + 0.04)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	d.add_child(cs)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _kit.paint(Color(0.55, 0.57, 0.6), 0.5, 0.45)
	d.add_child(mi)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.14, 0.2, w)
	stripe.mesh = sm
	stripe.material_override = _kit.paint(Color(1.0, 0.5, 0.12), 0.1, 0.45)
	stripe.position.y = 0.2
	d.add_child(stripe)
	d.position = Vector3(x, YardLayout.AIRLOCK_DOOR_H * 0.5, 0.0)
	add_child(d)
	return d


func _panel(at: Vector3, facing: Vector3, where: String) -> void:
	var area := Area3D.new()
	area.name = "Panel_" + where
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.2, 0.4, 0.35)
	cs.shape = shape
	area.add_child(cs)
	area.position = at
	# Its own +x faces out of the wall.
	area.basis = Basis(Vector3.UP, atan2(-facing.z, facing.x))
	if Flags.is_on(YardBus.AIRLOCK_DETAIL):
		_control_panel(area, where)
	else:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.3, 0.22)
		mi.mesh = mesh
		mi.material_override = _kit.glow(Color(0.2, 0.5, 0.9), 1.5)
		mi.position = Vector3(0.02, 0.0, 0.0)
		area.add_child(mi)
	var mode: String = {"corridor": "in", "outside": "out"}.get(where, "toggle")
	area.set_meta("yard_use", func() -> void: use(mode))
	area.set_meta("yard_hint", func() -> String: return _hint(where))
	area.add_to_group("gfx_interactable")
	area.set_meta("gfx_id", "airlock:" + where)
	add_child(area)


## A control panel in the area's space (+x out of the wall): a housing half sunk in the
## wall, a bezel, a status screen, a big lit push button in a hazard collar, its label.
func _control_panel(area: Area3D, where: String) -> void:
	var housing := MeshInstance3D.new()
	housing.name = "Housing"
	var hm := BoxMesh.new()
	hm.size = Vector3(0.06, 0.44, 0.3)
	housing.mesh = hm
	housing.material_override = _kit.paint(Color(0.24, 0.25, 0.28), 0.2, 0.5)
	housing.position = Vector3(-0.01, 0.0, 0.0)
	area.add_child(housing)
	var bezel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.4, 0.26)
	bezel.mesh = bm
	bezel.material_override = _kit.paint(Color(0.5, 0.52, 0.56), 0.2, 0.45)
	bezel.position = Vector3(0.026, 0.0, 0.0)
	area.add_child(bezel)
	var screen := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.004, 0.1, 0.2)
	screen.mesh = sm
	screen.material_override = _kit.glow(Color(0.03, 0.06, 0.08), 0.6)
	screen.position = Vector3(0.034, 0.11, 0.0)
	area.add_child(screen)
	var status := _label("READY", Vector3(0.037, 0.11, 0.0), Vector3.RIGHT, 0.0011, Color(0.2, 1.0, 0.35), area)
	status.name = "Status"
	_screens.append(status)
	var collar := _disc(0.064, 0.02, _kit.paint(Color(1.0, 0.78, 0.1), 0.1, 0.6, "hazard_stripes"),
			Vector3(0.042, -0.05, 0.0), Vector3.RIGHT, area)
	collar.name = "Collar"
	var button := _disc(0.046, 0.03, _button_mat(Color(0.2, 1.0, 0.35)), Vector3(0.05, -0.05, 0.0), Vector3.RIGHT, area)
	button.name = "Button"
	_buttons.append(button)
	var word: String = {"corridor": "CALL", "outside": "CALL"}.get(where, "CYCLE")
	_label(word, Vector3(0.033, -0.155, 0.0), Vector3.RIGHT, 0.0009, Color(0.9, 0.92, 0.95), area)


func _hint(where: String) -> String:
	if is_busy():
		return "Cycling the airlock..."
	var key := Keys.prompt(Keys.INTERACT)
	match where:
		"corridor":
			return "%s  Call the airlock" % key if state == State.OUTER_OPEN else "Airlock open"
		"outside":
			return "%s  Call the airlock" % key if state == State.INNER_OPEN else "Airlock open"
	return "%s  Cycle the airlock (%s)" % [key, "go out" if state == State.INNER_OPEN else "come in"]


## The panels' buttons: lit, but not so bright the face washes out.
func _button_mat(c: Color) -> StandardMaterial3D:
	var key := "button" + c.to_html()
	if not _lamp_mats.has(key):
		_lamp_mats[key] = _kit.glow(c, 1.2)
	return _lamp_mats[key]


func _lamp_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _lamp_mats.has(key):
		_lamp_mats[key] = _kit.glow(c, 4.0)
	return _lamp_mats[key]
