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
var _lamps: Array[MeshInstance3D] = []
var _lamp_mats: Dictionary = {}
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
	_apply_doors()


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
	var c := Color(0.2, 1.0, 0.35)
	if state == State.PUMPING:
		c = Color(1.0, 0.6, 0.1)
	elif is_busy():
		c = Color(1.0, 0.2, 0.15)
	for l in _lamps:
		l.material_override = _lamp_mat(c)


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
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.3, 0.22)
	mi.mesh = mesh
	mi.material_override = _kit.glow(Color(0.2, 0.5, 0.9), 1.5)
	mi.position = facing * 0.02
	area.add_child(mi)
	match where:
		"corridor":
			area.set_meta("yard_use", func() -> void: cycle(false))
		"outside":
			area.set_meta("yard_use", func() -> void: cycle(true))
		_:
			area.set_meta("yard_use", toggle)
	area.set_meta("yard_hint", func() -> String: return _hint(where))
	area.add_to_group("gfx_interactable")
	area.set_meta("gfx_id", "airlock:" + where)
	add_child(area)


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


func _lamp_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _lamp_mats.has(key):
		_lamp_mats[key] = _kit.glow(c, 4.0)
	return _lamp_mats[key]
