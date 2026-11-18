class_name YardCutter
extends YardTool
## Gas cutting torch: slices welds fast, poor at rivets and bolts (it melts around them),
## and heats a seized bolt free for the socket. A blue jet with bright preheat cones and a
## hiss; on the metal the flame splays over a melt pool and the oxygen blows molten slag off
## along the surface (YardToolEffects). The brass tip glows dull red after a long cut.
##
## Look: a gas cutting torch. A slim knurled handle with a pistol grip and lever, red and
## blue gas valves and their hoses out of the back, a brass mixer; the copper neck bending
## down to a small brass tip rides out on its own hose; a readout (the gas and oxygen: GAS OK,
## as the bottle never runs dry; SF3 stopped it pretending to drain).

var _flame: MeshInstance3D
var _flame_mat: StandardMaterial3D
var _flame_light: OmniLight3D
var _cones: MeshInstance3D
var _tip_mat: StandardMaterial3D
## How hot the brass tip is from the heat thrown back off the work, 0..1.
var tip_heat: float = 0.0


func _init() -> void:
	tool_name = "CUTTER"
	tool_id = "cutter"
	rivet_rate = 7.0    # a 40-point rivet takes ~6 s: use the grinder
	bolt_rate = 0.0     # bolts only come out with the socket...
	bolt_heat_rate = 0.8   # ...but the torch heats a seized one free in ~1 s
	weld_rate = 32.0    # a 120-point weld takes ~4 s
	connector_rate = 30.0  # slices a loom connector in 1 s
	spot_rate = 30.0       # a 30-point spot weld takes 1 s
	follow_speed = 0.9     # (FS2) along a seam, faster and rougher than the grinder
	push_force = 15.0   # a gas jet barely pushes
	bite_point = Vector3(0.0, -0.035, -0.3)   # the flame's hot spot, a few cm off the tip
	grip = Vector3(0.0, -0.075, 0.035)
	boom = 0.5
	boom_kind = BoomKind.HOSE
	heat_rate = 2.2
	spark_color = Color(1.0, 0.92, 0.75)
	light_color = Color(0.6, 0.75, 1.0)


func _ready() -> void:
	name = "YardCutter"
	var body_mat := metal(Color(0.2, 0.22, 0.26), 0.7, 0.4)
	var brass := metal(Color(0.72, 0.56, 0.3), 0.95, 0.3)
	var copper := metal(Color(0.75, 0.42, 0.25), 0.95, 0.3)
	var rubber := metal(Color(0.08, 0.08, 0.09), 0.05, 0.9)
	var red := metal(Color(0.7, 0.12, 0.08), 0.3, 0.5)
	var blue := metal(Color(0.12, 0.3, 0.7), 0.3, 0.5)
	var along := Vector3(deg_to_rad(90.0), 0.0, 0.0)
	var across := Vector3(0.0, 0.0, deg_to_rad(90.0))
	# A gas cutting torch: a slim knurled handle tube, the brass mixer at its front, the two
	# gas valves on its left (red fuel, blue oxygen), their hoses out of the back, a pistol
	# grip with the cutting-oxygen lever.
	cylinder(0.024, 0.17, Vector3(0.0, 0.0, 0.0), along, body_mat, 16)
	for i in 4:
		cylinder(0.026, 0.012, Vector3(0.0, 0.0, -0.05 + 0.03 * float(i)), along, rubber, 16)
	box(Vector3(0.042, 0.04, 0.04), Vector3(0.0, 0.0, -0.1), brass)
	for v in 2:
		var y := 0.014 if v == 0 else -0.014
		cylinder(0.006, 0.03, Vector3(-0.035, y, 0.06), across, brass, 8)
		cylinder(0.014, 0.012, Vector3(-0.054, y, 0.06), across, red if v == 0 else blue, 12)
		rod(Vector3(0.0, y, 0.085), Vector3(0.0, y * 2.0 - 0.04, 0.2), 0.007, red if v == 0 else blue, 8)
	box(Vector3(0.04, 0.11, 0.05), Vector3(0.0, -0.075, 0.035), rubber, Vector3(0.3, 0.0, 0.0))
	box(Vector3(0.012, 0.012, 0.08), Vector3(0.0, -0.03, -0.035), red)   # lever
	# On its hose: the copper neck bending down to a small brass tip.
	begin_head(Vector3(0.0, 0.0, -0.12))
	rod(Vector3(0.0, 0.0, -0.12), Vector3(0.0, -0.008, -0.17), 0.008, copper, 10)
	rod(Vector3(0.0, -0.008, -0.17), Vector3(0.0, -0.035, -0.205), 0.008, copper, 10)
	_tip_mat = metal(Color(0.72, 0.56, 0.3), 0.95, 0.3)
	_tip_mat.emission_enabled = true
	_tip_mat.emission = Color.BLACK
	cylinder(0.011, 0.04, Vector3(0.0, -0.035, -0.225), Vector3(deg_to_rad(-90.0), 0.0, 0.0), _tip_mat, 12, 0.007)
	readout(Vector3(0.0, 0.05, 0.03), Vector2(0.1, 0.045))

	# The jet: a short glowing cone in front of the nozzle, only while firing.
	_flame = MeshInstance3D.new()
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.005
	flame_mesh.bottom_radius = 0.016
	flame_mesh.height = 0.13
	_flame.mesh = flame_mesh
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.albedo_color = Color(0.7, 0.85, 1.0)
	_flame_mat.emission_enabled = true
	_flame_mat.emission = Color(0.55, 0.75, 1.0)
	_flame_mat.emission_energy_multiplier = 8.0
	_flame.material_override = _flame_mat
	_flame.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	_flame.position = Vector3(0.0, -0.035, -0.31)
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.visible = false
	attach(_flame)
	# The preheat cones at the tip: short, near-white, inside the jet.
	_cones = MeshInstance3D.new()
	var cones_mesh := CylinderMesh.new()
	cones_mesh.top_radius = 0.001
	cones_mesh.bottom_radius = 0.006
	cones_mesh.height = 0.03
	cones_mesh.radial_segments = 8
	_cones.mesh = cones_mesh
	var cones_mat := StandardMaterial3D.new()
	cones_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cones_mat.albedo_color = Color(0.9, 0.97, 1.0)
	_cones.material_override = cones_mat
	_cones.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	_cones.position = Vector3(0.0, -0.035, -0.258)
	_cones.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cones.visible = false
	attach(_cones)

	_flame_light = OmniLight3D.new()
	_flame_light.light_color = light_color
	_flame_light.light_energy = 0.0
	_flame_light.omni_range = 1.5
	_flame_light.position = Vector3(0.0, -0.035, -0.33)
	attach(_flame_light)
	end_head()
	add_voice("cutter")


func _process(delta: float) -> void:
	_flame.visible = working
	_cones.visible = working
	if working:
		var flicker := randf_range(0.85, 1.15)
		_flame.scale = Vector3(1.0, flicker, 1.0)
		_flame_light.light_energy = 1.2 * flicker
	else:
		_flame_light.light_energy = 0.0
	# Up against the metal the tip takes back some of the heat: 20 s to glow, 8 s to cool.
	tip_heat = clampf(tip_heat + (delta / 20.0 if working and in_contact else -delta / 8.0), 0.0, 1.0)
	_tip_mat.emission = Color(0.9, 0.2, 0.04)
	_tip_mat.emission_energy_multiplier = smoothstep(0.3, 1.0, tip_heat) * 2.5


func readout_text() -> String:
	return "GAS  OK\nO2   OK"   # (SF3) the bottle never runs dry, so it no longer pretends to
