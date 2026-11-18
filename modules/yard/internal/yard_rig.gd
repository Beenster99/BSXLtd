class_name YardRig
extends RigidBody3D
## You in the orbital yard, in the Void Salvage suit: its jet-rig (JetRig at Void Salvage
## 6523ae5) ported to the yard. Walk where the station has gravity, fly where the dock is
## weightless; the switch happens as you pass the airlock's outer door.
##
## Ported as Void Salvage has it: a 110 kg body, thrust per axis with boost and brake, the
## suit's dampeners, gyros that turn the body after the mouse with capped rates (the look debt),
## roll on Q/E, the glide (hold forward and the body lays out behind you), and on a deck: walking
## and running, the boots' grip, the head taking the pitch. Left out until later stages: tools,
## seats, ships, air and fuel, being downed, multiplayer.
##
## The rig's origin is its centre (chest height): the eye is EYE over it, the soles FEET under.
## `place` and `feet` work in feet, as the stand-in mover did.

const FEET: float = 1.25
const EYE: float = 0.3

@export_group("Thrust")
## The jets' push along each axis (N), boosted with Shift, and the brake's (N).
@export var thrust_force: float = 500.0
@export var boost_multiplier: float = 2.5
@export var brake_force: float = 800.0
## How hard the dampeners stop drift on the axes you aren't thrusting along (m/s²).
@export var dampener_strength: float = 2.5

@export_group("Rotation")
## Radians of turn per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0022
## The gyros' caps (rad/s): yaw and pitch flying free, and both while gliding.
@export var max_yaw_rate: float = 8.0
@export var max_pitch_rate: float = 3.0
@export var max_turn_rate: float = 2.2
## The most mouse turn owed at once (rad).
@export var look_debt_max: float = 4.0
## Roll on Q/E (rad/s).
@export var roll_rate: float = 1.4
## How quickly the gyros reach the turn asked (1/s).
@export var gyro_response: float = 9.0

@export_group("On deck")
## The station's gravity in its rooms (m/s²; Void Salvage's ships use 4.5).
@export var deck_gravity: float = 4.5
## Slide stopped per second standing still (m/s²).
@export var deck_grip: float = 3.5
## How far the head looks up or down on a deck (rad).
@export var deck_pitch_limit: float = 1.45
@export var walk_speed: float = 3.0       # m/s
@export var run_speed: float = 5.5        # m/s
@export var walk_accel: float = 18.0      # m/s²
@export var jump_speed: float = 2.6       # m/s

@export_group("Glide")
## Laid out this far forward while gliding (degrees), at this rate (1/s), from this much forward input.
@export var glide_angle: float = 70.0
@export var glide_rate: float = 3.0
@export var glide_threshold: float = 0.5

@export_group("Helmet lamp")
@export var lamp_energy: float = 7.0
@export var lamp_range: float = 55.0      # m
@export var lamp_angle: float = 34.0      # degrees

@export_group("View")
## Field of view (degrees), and how far behind the head the third-person camera sits (m).
@export var fov: float = 80.0
@export var third_person_distance: float = 3.2

@export_group("Use")
## How far you can reach to use something (m).
@export var reach: float = 3.0

## A function that says if a point (station space) has gravity; set by the station.
var gravity_at: Callable
## True while the station's gravity holds you.
var in_gravity := true
## Thrust asked this step (rig space, -Z forward): the figure leans with it.
var thrust_input := Vector3.ZERO
## How much the jets work (0..1, eased): the camera's rumble.
var throttle: float = 0.0
## 0 upright .. 1 laid out in the glide.
var glide: float = 0.0
## The suit's dampeners (Z).
var dampeners := true
## Seen from behind (V).
var third_person := false
var head: Node3D
var camera: Camera3D
var lamp: SpotLight3D
var feel: YardCameraFeel
var avatar: YardAvatar
## Whatever usable thing the view is on (a node with meta "yard_use"), or null.
var looking_at: Node
## The suit's accent colour.
var accent := Color(0.2, 0.75, 0.8)

var _body: CollisionShape3D
var _on_deck := false
var _grounded := false
var _deck_pitch: float = 0.0
var _look_debt := Vector2.ZERO
var _mouse_delta := Vector2.ZERO
var _glide_held := false
var _floor: Node3D
var _place_pending := false
var _place_to := Transform3D()
var _place_pitch: float = 0.0


func _init() -> void:
	mass = 110.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.15, 0)
	gravity_scale = 0.0
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 6
	var m := PhysicsMaterial.new()
	m.friction = 0.3
	physics_material_override = m


func _ready() -> void:
	_body = CollisionShape3D.new()
	_body.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	_body.shape = capsule
	_body.position.y = -FEET + capsule.height * 0.5
	add_child(_body)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = EYE
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.near = 0.05
	camera.far = 60000.0
	camera.fov = fov
	head.add_child(camera)
	lamp = SpotLight3D.new()
	lamp.name = "HelmetLamp"
	lamp.position = Vector3(0.12, 0.08, -0.25)
	lamp.light_color = Color(1, 0.94, 0.84)
	lamp.light_energy = lamp_energy
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.004
	lamp.shadow_normal_bias = 1.0
	lamp.spot_range = lamp_range
	lamp.spot_angle = lamp_angle
	lamp.spot_angle_attenuation = 0.8
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.visible = false
	head.add_child(lamp)
	feel = YardCameraFeel.new()
	feel.name = "CameraFeel"
	add_child(feel)
	# Your own body: unseen in first person but for the forearms, it still casts its shadow.
	avatar = YardAvatar.new()
	avatar.name = "Avatar"
	add_child(avatar)
	avatar.setup_shadow(accent, lamp, YardSuitLook.default_look(), "")
	lamp.shadow_caster_mask = 0xFFFFFFFF & ~YardAvatar.OWN_BODY_LAYER


## The mouse's travel (pixels), turned by the gyros over the next steps.
func look(relative: Vector2) -> void:
	_mouse_delta += relative


## Stands (or floats) with the soles at `at`, looking towards `target`.
func place(at: Vector3, target: Vector3) -> void:
	var centre := at + Vector3(0, FEET, 0)
	var eye := centre + Vector3(0, EYE, 0)
	var flat := Vector3(target.x - at.x, 0.0, target.z - at.z)
	var yaw := atan2(-flat.x, -flat.z) if flat.length() > 0.01 else rotation.y
	_place_pitch = atan2(target.y - eye.y, Vector2(target.x - eye.x, target.z - eye.z).length())
	_place_to = Transform3D(Basis(Vector3.UP, yaw), centre)
	in_gravity = _gravity_here(centre)
	_place_pending = true
	# Also now, so whoever placed it reads the new place before the next step.
	global_transform = _place_to
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_look_debt = Vector2.ZERO
	_mouse_delta = Vector2.ZERO
	_apply_place_pitch()


## Where the soles are now (station space; the station is at the origin).
func feet() -> Vector3:
	return global_transform * Vector3(0, -FEET, 0)


## Standing on a deck (in the station's gravity), not floating free.
func on_deck() -> bool:
	return _on_deck


## Feet on the floor.
func grounded() -> bool:
	return _grounded


## How fast you move over what you stand on (m/s, world): the station stands still.
func ground_velocity() -> Vector3:
	return linear_velocity


## What the boots stand on (null floating).
func floor_body() -> Node3D:
	return _floor if _grounded and is_instance_valid(_floor) else null


## The mouse turn still owed (rad; x yaw, y pitch). For tests.
func look_debt() -> Vector2:
	return _look_debt


func _apply_place_pitch() -> void:
	if head == null:
		return
	if in_gravity:
		_on_deck = true
		_deck_pitch = clampf(_place_pitch, -deck_pitch_limit, deck_pitch_limit)
		head.rotation = Vector3(_deck_pitch, 0, 0)
	else:
		_on_deck = false
		_deck_pitch = 0.0
		head.rotation = Vector3.ZERO
		global_transform.basis = _place_to.basis * Basis(Vector3.RIGHT, _place_pitch)
		_place_to.basis = global_transform.basis


func _physics_process(_delta: float) -> void:
	if not _controls_free():
		return
	if _just("yard.dampeners"):
		dampeners = not dampeners
	if _just("yard.lamp"):
		lamp.visible = not lamp.visible
	if _just("yard.view"):
		third_person = not third_person


func _process(delta: float) -> void:
	_update_look_target()
	if feel == null:
		return
	feel.set_rumble("jets", throttle * feel.jet_rumble)
	var walking := ground_velocity().length() if _on_deck and _grounded else 0.0
	var fov_goal := 0.0
	if not _on_deck and _controls_free():
		if _held(Keys.RUN) > 0.0 and thrust_input.length() > 0.1:
			fov_goal = feel.boost_fov_deg
		elif _held("yard.brake") > 0.0 and linear_velocity.length() > feel.brake_fov_speed:
			fov_goal = -feel.brake_fov_deg
	feel.step(delta, head.global_basis, minf(walking, 8.0), fov_goal)
	camera.transform = feel.offset
	if third_person:
		camera.transform = Transform3D(Basis(), _chase_offset()) * feel.offset
	camera.fov = fov + feel.fov_extra
	if avatar:
		avatar.show_from_outside(third_person or not camera.current)


## Behind and a little over the head, pulled in where a wall is closer.
func _chase_offset() -> Vector3:
	var want := Vector3(0.0, 0.35, third_person_distance)
	if not is_inside_tree():
		return want
	var from := head.global_position
	var to := head.global_transform * want
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return want
	var d := from.distance_to(hit.position as Vector3) - 0.25
	return want.normalized() * maxf(d, 0.3)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var dt := state.step
	if _place_pending:
		_place_pending = false
		state.transform = _place_to
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_grounded = false
		return
	in_gravity = _gravity_here(state.transform.origin)
	if in_gravity != _on_deck:
		_set_on_deck(state, in_gravity)
	_update_glide(state)
	if _on_deck:
		_apply_deck_gyros(state, dt)
	else:
		_apply_gyros(state, dt)
	var demand := 0.0
	thrust_input = Vector3.ZERO
	if _on_deck:
		state.linear_velocity += Vector3.DOWN * deck_gravity * dt
		_grounded = false
		_floor = null
		for i in state.get_contact_count():
			if state.get_contact_local_normal(i).y > 0.6:
				_grounded = true
				_floor = state.get_contact_collider_object(i) as Node3D
		if _grounded:
			_walk(state, dt)
		else:
			demand = _apply_thrust(state, dt)
		_deck_grip(state, dt)
	else:
		_grounded = false
		_floor = null
		demand = _apply_thrust(state, dt)
	throttle = move_toward(throttle, clampf(demand / boost_multiplier, 0.0, 1.0), dt * 4.0)


## Stepping into gravity: from free flight (look with the whole body) to standing (look up and
## down with the head), and back. The view doesn't jump either way.
func _set_on_deck(state: PhysicsDirectBodyState3D, on: bool) -> void:
	_on_deck = on
	_grounded = false
	if not on:
		# Fold the head's pitch back into the body.
		state.transform = Transform3D(state.transform.basis * Basis(Vector3.RIGHT, _deck_pitch),
				state.transform.origin)
		_deck_pitch = 0.0
		head.rotation = Vector3.ZERO
		return
	# Upright, keeping where you look (the pitch goes to the head, which pivots at the eye).
	_set_glide(0.0)
	_glide_held = false
	var forward := -state.transform.basis.z
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.05:
		flat = state.transform.basis.y * -signf(forward.y)
		flat.y = 0.0
		if flat.length() < 0.05:
			flat = Vector3.FORWARD
	var basis := Basis.looking_at(flat.normalized(), Vector3.UP)
	var eye := state.transform * head.position
	_deck_pitch = clampf(asin(clampf(forward.y, -1.0, 1.0)), -deck_pitch_limit, deck_pitch_limit)
	head.rotation = Vector3(_deck_pitch, 0, 0)
	state.transform = Transform3D(basis, eye - basis * head.position)
	state.angular_velocity = Vector3.ZERO


## Flying free: the look debt becomes this step's turn rate, each axis under its cap (mouse up =
## pitch up); what is asked comes off the debt, the gyros' easing delivers it.
func _apply_gyros(state: PhysicsDirectBodyState3D, dt: float) -> void:
	_take_mouse()
	var slow := glide > 0.01
	var yaw_cap := max_turn_rate if slow else max_yaw_rate
	var pitch_cap := max_turn_rate if slow else max_pitch_rate
	var yaw := clampf(_look_debt.x / dt, -yaw_cap, yaw_cap)
	var pitch := clampf(_look_debt.y / dt, -pitch_cap, pitch_cap)
	_look_debt -= Vector2(yaw, pitch) * dt
	var roll := (_held("yard.roll_left") - _held("yard.roll_right")) * roll_rate if _controls_free() else 0.0
	var target := state.transform.basis * Vector3(pitch, yaw, roll)
	var blend := 1.0 - exp(-gyro_response * dt)
	state.angular_velocity = state.angular_velocity.lerp(target, blend)


## On a deck: the mouse turns you round the deck's up and tilts the head; the gyros keep you upright.
func _apply_deck_gyros(state: PhysicsDirectBodyState3D, dt: float) -> void:
	_take_mouse()
	var yaw := clampf(_look_debt.x / dt, -max_yaw_rate, max_yaw_rate)
	_look_debt.x -= yaw * dt
	# Pitch goes to the head at once (it swings nothing).
	_deck_pitch = clampf(_deck_pitch + _look_debt.y, -deck_pitch_limit, deck_pitch_limit)
	_look_debt.y = 0.0
	head.rotation = Vector3(_deck_pitch, 0, 0)
	var level := state.transform.basis.y.cross(Vector3.UP) * 8.0
	var target := Vector3.UP * yaw + level
	var blend := 1.0 - exp(-gyro_response * 1.5 * dt)
	state.angular_velocity = state.angular_velocity.lerp(target, blend)


func _take_mouse() -> void:
	if not _controls_free():
		_look_debt = Vector2.ZERO
		_mouse_delta = Vector2.ZERO
		return
	_look_debt += Vector2(-_mouse_delta.x, -_mouse_delta.y) * mouse_sensitivity
	_mouse_delta = Vector2.ZERO
	_look_debt = _look_debt.clamp(Vector2(-look_debt_max, -look_debt_max), Vector2(look_debt_max, look_debt_max))


## On your feet: walk (or run) where you face, jump with Space. The station stands still.
func _walk(state: PhysicsDirectBodyState3D, dt: float) -> void:
	var input := Vector2.ZERO
	if _controls_free():
		input = Vector2(_held(Keys.RIGHT) - _held(Keys.LEFT), _held(Keys.BACK) - _held(Keys.FORWARD)).limit_length(1.0)
	var basis := state.transform.basis
	var wish := basis.x * input.x + basis.z * input.y
	wish.y = 0.0
	if wish.length() > 0.001:
		wish = wish.normalized() * input.length()
	var speed := run_speed if _held(Keys.RUN) > 0.0 else walk_speed
	var rel := state.linear_velocity
	var flat := Vector3(rel.x, 0.0, rel.z)
	state.linear_velocity += (wish * speed - flat).limit_length(walk_accel * dt)
	if _controls_free() and _just(Keys.JUMP):
		state.linear_velocity += Vector3.UP * jump_speed
		_grounded = false


## Standing with no input: the boots grip, so you stop instead of sliding round the deck.
func _deck_grip(state: PhysicsDirectBodyState3D, dt: float) -> void:
	if not _grounded or throttle > 0.05:
		return
	if _controls_free() and _held(Keys.RIGHT) + _held(Keys.LEFT) + _held(Keys.BACK) + _held(Keys.FORWARD) > 0.0:
		return
	var slide := Vector3(state.linear_velocity.x, 0.0, state.linear_velocity.z)
	var speed := slide.length()
	if speed > 0.001:
		state.linear_velocity -= slide / speed * minf(speed, deck_grip * dt)


## The jets: thrust along each of the rig's axes, boost, the dampeners and the brake. Returns
## how hard the jets worked (1 = one axis at full thrust).
func _apply_thrust(state: PhysicsDirectBodyState3D, dt: float) -> float:
	var force := Vector3.ZERO
	var demand := 0.0
	var free := _controls_free()
	var input := Vector3.ZERO
	if free:
		input = Vector3(_held(Keys.RIGHT) - _held(Keys.LEFT), _held("yard.up") - _held("yard.down"),
				_held(Keys.BACK) - _held(Keys.FORWARD)).limit_length(1.0)
	thrust_input = input
	if not input.is_zero_approx():
		var boost := boost_multiplier if _held(Keys.RUN) > 0.0 else 1.0
		force += state.transform.basis * input * thrust_force * boost
		demand += input.length() * boost
	var braking := free and _held("yard.brake") > 0.0
	if dampeners and not _on_deck and not braking:
		var basis := state.transform.basis
		for axis in 3:
			if absf(input[axis]) > 0.01:
				continue
			var dir: Vector3 = basis[axis]
			var along := state.linear_velocity.dot(dir)
			if absf(along) < 0.005:
				continue
			var push := minf(dampener_strength * mass, mass * absf(along) / dt)
			force -= dir * signf(along) * push
			demand += push / thrust_force * 0.5
	if braking:
		var speed := state.linear_velocity.length()
		if speed > 0.02:
			var applied := minf(brake_force, mass * speed / dt)
			force -= state.linear_velocity / speed * applied
			demand += applied / brake_force
	state.linear_velocity += force / mass * dt
	return demand


## The glide: hold forward flying free and the body lays out behind the eye.
func _update_glide(state: PhysicsDirectBodyState3D) -> void:
	var forward := _held(Keys.FORWARD) - _held(Keys.BACK) if _controls_free() else 0.0
	if _on_deck or forward < -glide_threshold:
		_glide_held = false
	elif forward > glide_threshold:
		_glide_held = true
	var want := 1.0 if _glide_held else 0.0
	if is_equal_approx(want, glide):
		return
	var next := move_toward(glide, want, glide_rate * state.step)
	if _room_for(state, _body_pose(next)):
		_set_glide(next)


## Is the capsule clear of walls if it stood at `pose` (rig space)?
func _room_for(state: PhysicsDirectBodyState3D, pose: Transform3D) -> bool:
	var capsule := _body.shape as CapsuleShape3D
	var probe := CapsuleShape3D.new()
	probe.radius = capsule.radius * 0.9
	probe.height = maxf(capsule.height - 0.1, probe.radius * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = state.transform * pose
	query.exclude = [get_rid()]
	return state.get_space_state().intersect_shape(query, 1).is_empty()


## The capsule's place in the rig at glide `g`: upright (its feet at FEET) turned forward
## about the eye, so the view stays put and the legs swing out behind.
func _body_pose(g: float) -> Transform3D:
	var h := (_body.shape as CapsuleShape3D).height
	var upright := Transform3D(Basis(), Vector3(0.0, -FEET + h * 0.5, 0.0))
	var pivot := Vector3(0.0, EYE, 0.0)
	var turn := Basis(Vector3.RIGHT, -deg_to_rad(glide_angle) * g)
	return Transform3D(turn, pivot - turn * pivot) * upright


func _set_glide(g: float) -> void:
	glide = clampf(g, 0.0, 1.0)
	if _body:
		_body.transform = _body_pose(glide)


func _gravity_here(centre: Vector3) -> bool:
	return gravity_at.call(centre) if gravity_at.is_valid() else true


## Uses whatever the view is on (F).
func use() -> void:
	if looking_at and looking_at.has_meta("yard_use"):
		(looking_at.get_meta("yard_use") as Callable).call()


## The hint for what the view is on ("" for nothing).
func hint() -> String:
	if looking_at == null or not looking_at.has_meta("yard_hint"):
		return ""
	var h: Variant = looking_at.get_meta("yard_hint")
	return str((h as Callable).call()) if h is Callable else str(h)


func _update_look_target() -> void:
	looking_at = null
	if head == null or not is_inside_tree():
		return
	var from := head.global_position
	var to := from - head.global_basis.z * reach
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [get_rid()]
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var n := hit.collider as Node
	while n and not n.has_meta("yard_use"):
		n = n.get_parent()
		if n is Node3D and n.name == "Station":
			n = null
	looking_at = n


## A screen that has the mouse (a console, the wrist) keeps your hands off the controls.
func _controls_free() -> bool:
	return not HudSlots.pointer_claimed()


func _held(action: String) -> float:
	return 1.0 if InputMap.has_action(action) and Input.is_action_pressed(action) else 0.0


func _just(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_just_pressed(action)
