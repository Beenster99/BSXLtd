class_name YardToolArt
extends Node3D
## Presentation only. The existing head transform still determines reach, contact and damage.
## A fitted metal hand and the complete tool travel together; extension happens at the wrist.

## Meta on a tool's own mesh that stays drawn under the art (a live screen, its lit rim).
const LIVE := &"yard_live"

## Width of the bellows and support rails; length still follows the fitted hand.
@export_range(0.3, 1.0, 0.05) var wrist_width: float = 0.65

var tool: YardTool
var id: String
var pieces: Dictionary = {}
var wrist := Vector3.ZERO
var wrist_basis := Basis.IDENTITY
var _finish: ShaderMaterial
var _look_code := ""
var _bridge: MeshInstance3D
var _rails: Array[MeshInstance3D] = []
var _wrist_materials: Array[ShaderMaterial] = []
var _wrist_start := Vector3.ZERO
var _wrist_a := Vector3.ZERO
var _wrist_b := Vector3.ZERO
var _wrist_neck := 0.07
var _wrist_last := Vector3(INF, INF, INF)
var _wrist_last_width := -1.0
var _rotor: Node3D
var _rotor_finish: ShaderMaterial
static var _bellows: ArrayMesh


func _ready() -> void:
	name = "BlenderTool"
	process_priority = 20
	id = tool.tool_id
	var profile := YardSuitAssets.tool_profile(id)
	wrist = YardSuitAssets.vector(profile["wrist"])
	var axes: Array = profile["wrist_basis"]
	wrist_basis = Basis(YardSuitAssets.vector(axes[0]), YardSuitAssets.vector(axes[1]), YardSuitAssets.vector(axes[2]))
	_finish = YardSuitAssets.finish(YardSuitLook.default_look())
	_hide_previous_geometry()
	for key: String in YardSuitAssets.meshes("tool_" + id):
		var mesh: Mesh = YardSuitAssets.meshes("tool_" + id)[key]
		var mi := YardSuitAssets.piece(mesh, _finish, key)
		add_child(mi)
		pieces[key] = mi
		match key:
			"coil": mi.material_override = (tool as YardGrabber)._coil
			"heat": mi.material_override = (tool as YardCutter)._tip_mat
	if pieces.has("rotor"):
		_rotor = Node3D.new()
		_rotor.name = "Spindle"
		_rotor.position = Vector3(-0.065, 0, -0.165) if tool is YardGrinder else Vector3(0, 0, -0.14)
		add_child(_rotor)
		var rotor: MeshInstance3D = pieces["rotor"]
		if tool is YardGrinder:
			_rotor_finish = YardSuitAssets.finish(YardSuitLook.default_look())
			rotor.material_override = _rotor_finish
		rotor.reparent(_rotor, false)
		rotor.position = -_rotor.position
	_build_wrist()
	# A standalone tool (tests and prop previews) must not leave an unattached hand in space.
	(pieces["hand"] as MeshInstance3D).visible = false


func _hide_previous_geometry() -> void:
	var keep: Array[Node] = []
	if tool._readout:
		keep.append(tool._readout.get_parent())
	if tool is YardCutter:
		keep.append_array([(tool as YardCutter)._flame, (tool as YardCutter)._cones])
	for node in tool.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if is_ancestor_of(mi):
			continue
		var mat := mi.material_override as StandardMaterial3D
		var live := mi in keep or mi.has_meta(LIVE)
		if not live:
			mi.visible = false
		if live and tool.head and not tool.head.is_ancestor_of(mi):
			mi.reparent(self, true)


func bind_cuff(cuff: Transform3D, look: Dictionary, colour: Color) -> void:
	(pieces["hand"] as MeshInstance3D).visible = true
	var code := YardSuitLook.encode(look) + colour.to_html()
	if code != _look_code:
		_look_code = code
		_finish.set_shader_parameter("plates", YardSuitLook.PRIMARY[int(look["primary"])])
		_finish.set_shader_parameter("trim", YardSuitLook.SECONDARY[int(look["secondary"])])
		_finish.set_shader_parameter("accent", colour)
		_finish.set_shader_parameter("wear", YardSuitLook.WEAR_LEVELS[int(look["wear"])])
	var frame := wrist_frame()
	var start := frame.affine_inverse() * cuff.origin
	_bridge.visible = start.length() > 0.012
	if not _bridge.visible:
		for rail in _rails:
			rail.visible = false
		return
	_bridge.global_transform = frame
	for rail in _rails:
		rail.visible = true
		rail.global_transform = frame
	if start.is_equal_approx(_wrist_last) and is_equal_approx(wrist_width, _wrist_last_width):
		return
	_wrist_last = start
	_wrist_last_width = wrist_width
	_wrist_start = start
	# Palm geometry lies along -Z. Approach its socket from +Z, even when the
	# working head points sideways; a straight cuff-to-palm chord cuts through it.
	var radial := Vector3(start.x, start.y, 0)
	# A reversed head can put the cuff behind the fingers. Carry the bend around
	# the hand's outside before returning to the socket, rather than through it.
	if start.z < 0.03 and radial.length() < 0.26:
		radial = radial.normalized() * 0.26 if radial.length() > 0.001 else Vector3(0, -0.26, 0)
	if start.z < 0.03:
		radial.y = minf(radial.y, -0.30) if start.y < 0.05 else maxf(radial.y, 0.60)
	var bend := 0.10 + maxf(-start.z, 0.0) * 0.15 + Vector2(start.x, start.y).length() * 0.12
	_wrist_a = Vector3(radial.x, radial.y, maxf(start.z * 0.66, bend))
	_wrist_b = Vector3(0, 0, bend)
	if start.z > 0 and Vector2(start.x, start.y).length() < 0.06:
		_wrist_a = start * 0.66
		_wrist_b = Vector3(0, 0, start.z * 0.33)
	_wrist_neck = minf(0.16, start.length() * 0.4)
	_wrist_a.z = maxf(_wrist_a.z, _wrist_neck)
	_wrist_b.z = maxf(_wrist_b.z, _wrist_neck + 0.02)
	var bounds := AABB(start, Vector3.ZERO).expand(Vector3.ZERO).expand(_wrist_a).expand(_wrist_b).grow(0.08)
	_bridge.custom_aabb = bounds
	for rail in _rails:
		rail.custom_aabb = bounds
	for mat in _wrist_materials:
		mat.set_shader_parameter("start", _wrist_start)
		mat.set_shader_parameter("control_a", _wrist_a)
		mat.set_shader_parameter("control_b", _wrist_b)
		mat.set_shader_parameter("neck", _wrist_neck)
		mat.set_shader_parameter("width", wrist_width)


func wrist_point(t: float) -> Vector3:
	var end := Vector3(0, 0, _wrist_neck)
	return _wrist_start.bezier_interpolate(_wrist_a, _wrist_b, end, t / 0.85) if t < 0.85 else end * ((1.0 - t) / 0.15)


func wrist_tangent(t: float) -> Vector3:
	return _wrist_start.bezier_derivative(_wrist_a, _wrist_b, Vector3(0, 0, _wrist_neck), t / 0.85).normalized() if t < 0.85 else Vector3.FORWARD


func set_tension(value: float) -> void:
	var colour := Color(1, 0.55, 0.1).lerp(Color(1, 0.1, 0.05), smoothstep(0.85, 1.0, value))
	var strength := 1.5 * smoothstep(0.7, 1.0, value)
	if not _wrist_materials.is_empty():
		_wrist_materials[0].set_shader_parameter("glow", colour * strength)


func wrist_frame() -> Transform3D:
	return global_transform * Transform3D(wrist_basis, wrist)


## Target the arm cuff behind the authored wrist socket, not inside the old grip.
## Keep extension in the bellows; follow the head's orientation at its rest position.
func cuff_target(shoulder: Vector3, reach: float) -> Transform3D:
	var head_frame := Transform3D(tool.head.basis, tool.head_rest) if tool.head else Transform3D.IDENTITY
	var frame := tool.global_transform * head_frame * transform * Transform3D(wrist_basis, wrist)
	var outward := frame.basis.z.normalized()
	var basis := Basis(Quaternion(Vector3(0, cos(.3), sin(.3)), outward))
	var cuff := frame.origin + outward * 0.12
	# Ease into a tucked arm before the IK reach limit could clamp its cuff into
	# a turned tool. The flexible wrist covers the remaining distance.
	var tucked := shoulder + tool.global_basis * Vector3(.08, -.28, -.12)
	cuff = cuff.lerp(tucked, smoothstep(reach - 0.10, reach, shoulder.distance_to(cuff)))
	return Transform3D(basis, cuff - outward * 0.045)


func _process(delta: float) -> void:
	if not tool.is_visible_in_tree():
		return
	if _rotor:
		if tool is YardGrinder:
			_rotor.rotate_x((tool as YardGrinder)._spin * delta)
			var disc := (tool as YardGrinder)._disc_mat
			_rotor_finish.set_shader_parameter("heat", disc.emission * disc.emission_energy_multiplier)
		elif tool is YardSocket:
			_rotor.rotate_z((tool as YardSocket)._spin * delta)
	if tool is YardGrabber:
		for i in 3:
			var key := "jaw_%d" % i
			if pieces.has(key):
				var angle := PI * 0.5 + TAU * i / 3.0
				(pieces[key] as Node3D).position = Vector3(cos(angle), sin(angle), 0) * (-0.04 * (tool as YardGrabber)._closed)


func _build_wrist() -> void:
	if _bellows == null:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in 40:
			for side in 16:
				var points: Array[Vector3] = []
				for corner: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(1,1), Vector2i(0,1)]:
					var y := ring + corner.y
					var angle := TAU * (side + corner.x) / 16.0
					var radius := 0.041 if y % 2 == 0 else 0.033
					points.append(Vector3(cos(angle) * radius, y / 40.0, sin(angle) * radius))
				for j in [0, 2, 1, 0, 3, 2]:
					st.add_vertex(points[j])
		st.generate_normals()
		_bellows = st.commit()
	_bridge = YardSuitAssets.piece(_bellows, _wrist_material(0.0), "ElasticWrist")
	add_child(_bridge)
	_bridge.top_level = true
	_bridge.visible = false
	for i in 2:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.006
		cylinder.bottom_radius = 0.006
		cylinder.height = 1.0
		cylinder.radial_segments = 8
		cylinder.rings = 39
		var rail := YardSuitAssets.piece(cylinder, _wrist_material(-0.052 if i == 0 else 0.052), "WristRail%d" % i)
		add_child(rail)
		rail.top_level = true
		rail.visible = false
		_rails.append(rail)


func _wrist_material(offset: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://modules/yard/assets/tools_fx/tool_wrist.gdshader")
	mat.set_shader_parameter("rail_offset", offset)
	_wrist_materials.append(mat)
	return mat
