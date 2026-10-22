extends Node3D
## One of the independent surveyors: hi-vis vest, white hard hat, a tablet in one hand and
## a scanner in the other. Walks in from the bay's open side to each joint it was given,
## stands scanning it (a beam from the scanner, the tablet lighting up as they note it), then
## waits about until leave() sends it back out. Built in code; moves on the floor (y = 0)
## in yard space without physics, since nobody can block a surveyor.

const VEST := Color("d8ef2a")
const STRIPE := Color("c9cdd1")
const TROUSERS := Color("2b3036")
const SKIN := Color("c69a7a")
const HAT := Color("f2f2ee")
const BEAM := Color("6fc8e8")

enum State { WALK, SCAN, NOTES, LEAVE }

var speed := 1.4
var scan_s := 4.0
## Each {stand: Vector3 (floor), at: Vector3 (the joint)}, in parent space.
var stops: Array[Dictionary] = []
var exit_point := Vector3.ZERO
var state := State.WALK
var _stop := 0
var _timer := 0.0
var _walked := 0.0
var _legs: Array[Node3D] = []
var _beam: MeshInstance3D
var _screen: StandardMaterial3D
var _scanner: Node3D


func _init(p_stops: Array[Dictionary], p_exit: Vector3, p_speed := 1.4, p_scan_s := 4.0) -> void:
	stops = p_stops
	exit_point = p_exit
	speed = p_speed
	scan_s = p_scan_s
	name = "Surveyor"
	_build()


func _ready() -> void:
	position = exit_point
	if stops.is_empty():
		state = State.NOTES


## Done here: walk back out and go.
func leave() -> void:
	state = State.LEAVE
	_beam.visible = false


func is_scanning() -> bool:
	return state == State.SCAN


func _process(delta: float) -> void:
	match state:
		State.WALK:
			if _walk_to(stops[_stop].stand, delta):
				state = State.SCAN
				_timer = scan_s
				_face(stops[_stop].at)
				_aim(stops[_stop].at)
		State.SCAN:
			_timer -= delta
			_screen.emission_energy_multiplier = 1.5 + sin(_timer * 9.0)
			if _timer <= 0.0:
				_beam.visible = false
				_screen.emission_energy_multiplier = 0.6
				_stop += 1
				state = State.WALK if _stop < stops.size() else State.NOTES
		State.NOTES:
			# Writing it up: stand still, tablet glowing, until the visit's over.
			_screen.emission_energy_multiplier = 1.2
			_pose_legs(0.0)
		State.LEAVE:
			if _walk_to(exit_point, delta):
				queue_free()


## Steps towards `target`; true once there.
func _walk_to(target: Vector3, delta: float) -> bool:
	var to := Vector3(target.x - position.x, 0.0, target.z - position.z)
	var d := to.length()
	if d < 0.05:
		_pose_legs(0.0)
		return true
	var step := minf(d, speed * delta)
	position += to / d * step
	_face(target)
	_walked += step
	_pose_legs(sin(_walked * 4.2) * 0.45)
	return false


func _face(p: Vector3) -> void:
	var flat := Vector3(p.x, position.y, p.z)
	if flat.distance_to(position) > 0.01:
		look_at(flat, Vector3.UP, true)


## Stretches the scan beam from the scanner to the joint.
func _aim(at: Vector3) -> void:
	var from := _scanner.global_position if is_inside_tree() else position + Vector3(0.3, 1.2, 0.4)
	var to_world := (get_parent() as Node3D).to_global(at) if get_parent() is Node3D else at
	(_beam.mesh as CylinderMesh).height = maxf(from.distance_to(to_world), 0.1)
	_beam.global_position = from.lerp(to_world, 0.5)
	if from.distance_to(to_world) > 0.01:
		var dir := (to_world - from).normalized()
		var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		_beam.global_basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI / 2.0)
	_beam.visible = true


func _pose_legs(swing: float) -> void:
	if _legs.size() == 2:
		_legs[0].rotation.x = swing
		_legs[1].rotation.x = -swing


func _build() -> void:
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(0.11 * side, 0.9, 0.0)
		add_child(hip)
		hip.add_child(_box(Vector3(0.15, 0.88, 0.17), TROUSERS, Vector3(0, -0.44, 0)))
		hip.add_child(_box(Vector3(0.16, 0.1, 0.26), Color("1b1d20"), Vector3(0, -0.85, 0.04)))
		_legs.append(hip)
	add_child(_box(Vector3(0.44, 0.62, 0.26), VEST, Vector3(0, 1.22, 0)))
	for y in [1.08, 1.3]:
		add_child(_box(Vector3(0.45, 0.05, 0.27), STRIPE, Vector3(0, y, 0), 0.6))
	var back := Label3D.new()
	back.text = "K&V\nSURVEY"
	back.font_size = 40
	back.pixel_size = 0.0025
	back.modulate = Color("1f2328")
	back.outline_size = 0
	back.position = Vector3(0, 1.22, -0.135)
	back.rotation.y = PI
	add_child(back)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.26
	head.mesh = sphere
	head.material_override = _mat(SKIN)
	head.position = Vector3(0, 1.66, 0)
	add_child(head)
	var hat := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.14
	dome.height = 0.2
	dome.is_hemisphere = true
	hat.mesh = dome
	hat.material_override = _mat(HAT)
	hat.position = Vector3(0, 1.72, 0)
	add_child(hat)
	var brim := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.015
	brim.mesh = disc
	brim.material_override = _mat(HAT)
	brim.position = Vector3(0, 1.725, 0.03)
	add_child(brim)
	# Arms forward: the tablet in the left hand, the scanner in the right.
	add_child(_box(Vector3(0.09, 0.09, 0.42), VEST, Vector3(-0.27, 1.3, 0.2)))
	add_child(_box(Vector3(0.09, 0.09, 0.42), VEST, Vector3(0.27, 1.3, 0.2)))
	var tablet := _box(Vector3(0.26, 0.02, 0.19), Color("22262a"), Vector3(-0.22, 1.27, 0.44))
	tablet.rotation.x = -0.6
	add_child(tablet)
	var screen := MeshInstance3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3(0.23, 0.004, 0.16)
	screen.mesh = quad
	_screen = _mat(BEAM)
	_screen.emission_enabled = true
	_screen.emission = BEAM
	_screen.emission_energy_multiplier = 0.6
	screen.material_override = _screen
	screen.position = Vector3(0, 0.012, 0)
	tablet.add_child(screen)
	_scanner = _box(Vector3(0.07, 0.07, 0.22), Color("e8792b"), Vector3(0.27, 1.32, 0.48))
	add_child(_scanner)
	var lens := _box(Vector3(0.05, 0.05, 0.01), BEAM, Vector3(0, 0, 0.115))
	var lens_mat := lens.material_override as StandardMaterial3D
	lens_mat.emission_enabled = true
	lens_mat.emission = BEAM
	lens_mat.emission_energy_multiplier = 3.0
	_scanner.add_child(lens)
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	# Narrow at the scanner, spreading over the joint.
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.006
	cyl.height = 1.0
	_beam.mesh = cyl
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.albedo_color = Color(BEAM, 0.5)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func _box(size: Vector3, colour: Color, at: Vector3, rough := 0.85) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	var mat := _mat(colour)
	mat.roughness = rough
	m.material_override = mat
	m.position = at
	return m


func _mat(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	return mat
