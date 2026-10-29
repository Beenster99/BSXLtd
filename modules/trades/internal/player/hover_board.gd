class_name TradesHoverBoard
extends Node3D
## Your own hover board for crossing the yard (beenster, 0.3.23: "the yard is quite large ...
## spawn a personal hover board to ride around the yard a lot quicker than running. The hover
## board can raise in height with the up and down arrows"). Behind trades.hover_board.
##
## B brings it out under your feet and puts it away again. Riding, WASD steers it where you
## look, Shift goes flat out, and Space and Left Ctrl (playtest 0.3.29; the arrows before) raise and lower how high it floats
## over the courtyard's floor (playtest 0.3.24: a set height, so it doesn't bob up and down over
## a wreck's decks and holes), never lower than `min_height` over what is under it. It hangs under the
## worker's feet (this node is the worker's child), leans into the way it's going and hums.
## Step off high up and you drop, as from any height.

## How high it floats over the courtyard floor (m): what it starts at and the most; and the
## least it keeps over whatever is under it.
@export var min_height := 0.3
@export var start_height := 0.45
@export var max_height := 10.0
## How fast Space and Ctrl raise or lower it (m/s).
@export var climb_rate := 1.8
## Top speed (m/s), and flat out with Shift.
@export var cruise_speed := 8.0
@export var boost_speed := 14.0
## Speeding up and slowing down (m/s²); with no keys held it coasts down at `coast_decel`.
@export var accel := 9.0
@export var coast_decel := 5.0
## How hard it holds its height (1/s) and the fastest it rises or sinks to it (m/s).
@export var hold_rate := 6.0
@export var max_rise := 6.0
@export var max_sink := 9.0
## How far it leans into speeding up and turning (degrees at full).
@export var lean_deg := 12.0
## How far down it looks for something to float over (m); past that it falls.
@export var sense_m := 40.0
## The hum (dB), rising in pitch with speed.
@export var hum_db := -34.0

## Riding now.
var riding := false
## How high it floats now (m over the courtyard floor, `floor_y`).
var height := 0.45
## The courtyard floor's height (world y), set by the yard; NAN floats over what is under it.
var floor_y := NAN
## Under it last step: the floor's height (world y) or NAN with nothing in reach.
var ground_y := NAN

var _deck: Node3D
var _glows: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _hum: AudioStreamPlayer3D
var _lean := Vector2.ZERO  # x pitch, y roll (radians), eased
var _last_vel := Vector3.ZERO


func _ready() -> void:
	height = start_height
	_deck = build_look()
	add_child(_deck)
	for g in _deck.find_children("Glow*", "MeshInstance3D", true, false):
		_glows.append(g as MeshInstance3D)
	_light = OmniLight3D.new()
	_light.name = "Underglow"
	_light.light_color = Color(0.35, 0.8, 1.0)
	_light.light_energy = 0.6
	_light.omni_range = 1.6
	_light.shadow_enabled = false
	_light.position.y = -0.12
	_deck.add_child(_light)
	_hum = AudioStreamPlayer3D.new()
	_hum.name = "Hum"
	_hum.stream = TradesSounds.hum(0.5, 0.25, 55.0, 700.0)
	_hum.volume_db = hum_db
	_hum.max_distance = 25.0
	add_child(_hum)
	visible = false


## The board's look on its own (deck, rails, emitter pads with their glow), top at y 0, nose
## toward -Z. Crewmates' avatars get a copy (TradesCrew).
static func build_look() -> Node3D:
	var root := Node3D.new()
	root.name = "Board"
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.93, 0.55, 0.1)
	body.metallic = 0.3
	body.roughness = 0.35
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.08, 0.09)
	dark.roughness = 0.9
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.55, 0.57, 0.6)
	trim.metallic = 0.85
	trim.roughness = 0.3
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.3, 0.75, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.75, 1.0)
	glow.emission_energy_multiplier = 3.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# The deck: a long board with rounded ends, grip on top, a steel rail round the edge.
	var deck := _round_board(Vector3(0.42, 0.05, 1.15), body, Vector3(0, -0.035, 0))
	deck.name = "Deck"
	root.add_child(deck)
	root.add_child(_round_board(Vector3(0.36, 0.008, 1.0), dark, Vector3(0, -0.006, 0)))
	for side: float in [-1.0, 1.0]:
		var rail := _mesh(_box(Vector3(0.018, 0.03, 0.9)), trim, Vector3(side * 0.205, -0.03, 0))
		root.add_child(rail)
		# A stripe down each side of the grip.
		root.add_child(_mesh(_box(Vector3(0.025, 0.004, 0.7)), body, Vector3(side * 0.13, -0.001, 0)))
	# Two emitter pads underneath, fore and aft, each a ring with a lit face.
	for z: float in [-0.36, 0.36]:
		var pad := _mesh(_cylinder(0.15, 0.06), trim, Vector3(0, -0.09, z))
		root.add_child(pad)
		var face := _mesh(_cylinder(0.12, 0.01), glow, Vector3(0, -0.122, z))
		face.name = "Glow%d" % (0 if z < 0.0 else 1)
		root.add_child(face)
	# A nose light.
	var nose := _mesh(_box(Vector3(0.16, 0.02, 0.02)), glow, Vector3(0, -0.035, -0.6))
	nose.name = "GlowNose"
	root.add_child(nose)
	for m in root.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root


## Out under your feet (true) or put away (false).
func set_riding(on: bool) -> void:
	if on == riding:
		return
	riding = on
	visible = on
	_lean = Vector2.ZERO
	if on:
		height = start_height
		var worker := get_parent() as Node3D
		if not is_nan(floor_y) and worker and worker.is_inside_tree():
			# Out where you stand: on a wreck's deck it starts over the deck, not under it.
			height = clampf(worker.global_position.y - floor_y + start_height, min_height, max_height)
		if DisplayServer.get_name() != "headless":
			_hum.play()
	else:
		_hum.stop()


## One physics step riding: the velocity the worker moves with this step, from the steering
## keys (`input`: x right, y back, -1..1), Shift, the climb (Space up, Ctrl down) (-1..1) and the floor under.
func drive(worker: CharacterBody3D, input: Vector2, boost: bool, climb: float, delta: float) -> Vector3:
	height = clampf(height + climb * climb_rate * delta, min_height, max_height)
	var vel := worker.velocity
	var flat := Vector3(vel.x, 0.0, vel.z)
	var wish := worker.global_basis * Vector3(input.x, 0.0, input.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()
	if wish.length() > 0.01:
		var top := boost_speed if boost else cruise_speed
		flat = flat.move_toward(wish * top, accel * delta)
	else:
		flat = flat.move_toward(Vector3.ZERO, coast_decel * delta)
	ground_y = floor_under(worker)
	var vy: float
	if is_nan(ground_y):
		vy = vel.y - 9.0 * delta
	else:
		var want := ground_y + height
		if not is_nan(floor_y):
			want = maxf(floor_y + height, ground_y + min_height)
		vy = clampf((want - worker.global_position.y) * hold_rate, -max_sink, max_rise)
	return Vector3(flat.x, vy, flat.z)


## What's under the worker: the height of the first thing a ray down from its knees meets, or
## NAN with nothing within `sense_m`.
func floor_under(worker: CharacterBody3D) -> float:
	var space := worker.get_world_3d().direct_space_state if worker.is_inside_tree() else null
	if space == null:
		return NAN
	var from := worker.global_position + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (sense_m + 0.5))
	q.exclude = [worker.get_rid()]
	var hit := space.intersect_ray(q)
	return float((hit.position as Vector3).y) if not hit.is_empty() else NAN


func _process(delta: float) -> void:
	if not riding:
		return
	var worker := get_parent() as CharacterBody3D
	if worker == null:
		return
	# Lean into speeding up (pitch) and turning (roll), in the worker's own axes.
	var dv := (worker.velocity - _last_vel) / maxf(delta, 0.001)
	_last_vel = worker.velocity
	var local := worker.global_basis.inverse() * dv
	var full := deg_to_rad(lean_deg)
	var want := Vector2(clampf(local.z / accel, -1.0, 1.0) * full, clampf(-local.x / accel, -1.0, 1.0) * full)
	_lean = _lean.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	_deck.rotation = Vector3(_lean.x, 0.0, _lean.y)
	# A slow bob, and the hum and glow rising with speed.
	var speed := Vector2(worker.velocity.x, worker.velocity.z).length()
	var t := Time.get_ticks_msec() / 1000.0
	_deck.position.y = sin(t * 2.4) * 0.012
	_hum.pitch_scale = 0.8 + speed / boost_speed * 0.8
	var lit := 2.0 + speed / boost_speed * 3.0
	_light.light_energy = 0.4 + speed / boost_speed * 0.8
	for g in _glows:
		var m := g.get_active_material(0) as StandardMaterial3D
		if m:
			m.emission_energy_multiplier = lit


static func _mesh(mesh: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	return m


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cylinder(radius: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = h
	c.radial_segments = 20
	return c


## A flat board with round ends: a box with a disc at each end (`size` overall).
static func _round_board(size: Vector3, mat: Material, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var r := size.x * 0.5
	n.add_child(_mesh(_box(Vector3(size.x, size.y, size.z - size.x)), mat, Vector3.ZERO))
	for k: float in [-1.0, 1.0]:
		var end := _cylinder(r, size.y)
		end.radial_segments = 24
		n.add_child(_mesh(end, mat, Vector3(0, 0, k * (size.z * 0.5 - r))))
	return n
