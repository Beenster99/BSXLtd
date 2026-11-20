extends Node3D
## A part-built ship out of the build berth (master plan 7.4): what has been fixed of her so
## far, drawn as plain metal at a holding berth, and on the move behind a tug when she is
## taken from one berth to another. Presentation only: her state stays in BuildBus.builds.

const TUG_LENGTH := 11.0

var bus: Object
var contract := ""
var ship: Node3D
var _tug: Node3D
var _line: MeshInstance3D
var _glows: Array[OmniLight3D] = []
var _half := 10.0


## `towing`: a tug comes with her (she is on the move).
func setup(build_bus: Object, contract_id: String, towing := false) -> void:
	bus = build_bus
	contract = contract_id
	ship = Node3D.new()
	ship.name = "Ship"
	add_child(ship)
	var bp: Object = bus.call("blueprint", contract)
	var pl: BuildPlan = bus.call("plan", contract)
	var b: Dictionary = (bus.get("builds") as Dictionary).get(contract, {})
	if bp == null or pl == null:
		return
	var box: AABB = bp.get("bounds")
	ship.position = -box.get_center()
	_half = box.size.z * 0.5
	var model: PartModel = bp.get("model")
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.56, 0.6, 0.64)
	metal.metallic = 0.6
	metal.roughness = 0.5
	var fresh := StandardMaterial3D.new()
	fresh.albedo_color = Color(0.68, 0.62, 0.5)
	fresh.metallic = 0.5
	fresh.roughness = 0.55
	for j: int in b.get("landed", []):
		var done := bool(bus.call("job_finished", j, contract))
		for id: int in pl.jobs[j].parts:
			var v := model.part_visual(id) as MeshInstance3D
			if v == null or v.mesh == null:
				continue
			var m := MeshInstance3D.new()
			m.mesh = v.mesh
			m.transform = (model.parts[id] as PartData).local_transform
			m.material_override = metal if done else fresh
			ship.add_child(m)
	_berth_lights()
	if towing:
		_make_tug()


## Work lights over the held ship, so she shows in the dark of the berth.
func _berth_lights() -> void:
	for z: float in [-_half * 0.6, 0.0, _half * 0.6]:
		var o := OmniLight3D.new()
		o.position = Vector3(0, 9.0, z)
		o.omni_range = 18.0
		o.light_energy = 0.6
		o.light_color = Color(0.95, 0.9, 0.8)
		add_child(o)


func _make_tug() -> void:
	_tug = Node3D.new()
	_tug.name = "Tug"
	add_child(_tug)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("e8792b")
	paint.roughness = 0.5
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.16, 0.18)
	dark.metallic = 0.5
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.2, 0.5, 0.65)
	glass.emission_enabled = true
	glass.emission = Color(0.25, 0.6, 0.8)
	glass.emission_energy_multiplier = 1.2
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color(0.4, 0.7, 1.0)
	hot.emission_enabled = true
	hot.emission = Color(0.45, 0.75, 1.0)
	hot.emission_energy_multiplier = 4.0
	hot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box(_tug, Vector3(4.2, 2.6, TUG_LENGTH), Vector3.ZERO, paint)
	_box(_tug, Vector3(3.0, 1.4, 3.6), Vector3(0, 1.9, -2.6), dark)
	_box(_tug, Vector3(2.8, 0.7, 0.2), Vector3(0, 2.0, -4.45), glass)
	_box(_tug, Vector3(5.6, 0.5, 2.2), Vector3(0, -0.4, 1.0), dark)
	for x: float in [-1.4, 1.4]:
		var e := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.75
		cyl.bottom_radius = 0.9
		cyl.height = 1.6
		e.mesh = cyl
		e.material_override = dark
		e.rotation_degrees = Vector3(90, 0, 0)
		e.position = Vector3(x, 0, TUG_LENGTH * 0.5 + 0.6)
		_tug.add_child(e)
		var g := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.6
		disc.bottom_radius = 0.6
		disc.height = 0.08
		g.mesh = disc
		g.material_override = hot
		g.rotation_degrees = Vector3(90, 0, 0)
		g.position = Vector3(x, 0, TUG_LENGTH * 0.5 + 1.45)
		_tug.add_child(g)
		var l := OmniLight3D.new()
		l.light_color = Color(0.5, 0.75, 1.0)
		l.omni_range = 7.0
		l.position = Vector3(x, 0, TUG_LENGTH * 0.5 + 2.4)
		_tug.add_child(l)
		_glows.append(l)
	var beacon := OmniLight3D.new()
	beacon.light_color = Color(1.0, 0.55, 0.2)
	beacon.omni_range = 9.0
	beacon.position = Vector3(0, 3.0, 0)
	_tug.add_child(beacon)
	_glows.append(beacon)
	_line = MeshInstance3D.new()
	var rope := CylinderMesh.new()
	rope.top_radius = 0.06
	rope.bottom_radius = 0.06
	rope.height = 1.0
	_line.mesh = rope
	var cable := StandardMaterial3D.new()
	cable.albedo_color = Color(0.85, 0.8, 0.3)
	cable.emission_enabled = true
	cable.emission = Color(0.6, 0.55, 0.2)
	_line.material_override = cable
	add_child(_line)


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.position = at
	m.material_override = mat
	parent.add_child(m)


## The tow at `u` (0..1) along `dir` (station space): the tug ahead of her bow on the line,
## its jets brighter while it pulls.
func tug(u: float, dir: Vector3) -> void:
	if _tug == null:
		return
	var local := (global_basis.inverse() * dir).normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var ahead := local * (_half + 14.0)
	_tug.position = ahead
	_tug.basis = Basis.looking_at(local, Vector3.UP) if absf(local.dot(Vector3.UP)) < 0.98 else Basis.IDENTITY
	var pull := sin(u * PI)
	for l in _glows:
		l.light_energy = 0.6 + 2.2 * pull
	var a := local * _half
	var b := ahead - local * TUG_LENGTH * 0.5
	_line.position = (a + b) * 0.5
	var span := b - a
	_line.scale = Vector3(1, maxf(span.length(), 0.1), 1)
	if span.length() > 0.01:
		var y := span.normalized()
		var x := y.cross(Vector3.UP if absf(y.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT).normalized()
		_line.basis = Basis(x, y, x.cross(y)).scaled(Vector3(1, span.length(), 1))
