extends Node3D
## The inspection scan (beenster, 0.4.7 playtest: "have the refurb bot hover near the item and
## then have it scan across the item with beams"): the drone hovers off the part and a curtain of
## beams fans out of its camera eye onto a line of light that sweeps across the part and back,
## the way a survey sweep passes along a wreck. The line on the part is drawn by the part itself
## (`line_material`, a pass over its own surface, so it follows the part's real shape, with faint
## contour bands left behind it); this draws the beams from the eye to that line. Presentation only.

const SCAN_SHADER := preload("res://modules/refurb/internal/refurb_scan.gdshader")
const BEAM := Color(0.35, 0.78, 1.0)
## One pass across the part and back takes this long (s).
const PERIOD := 3.2
## Points along the beams' far edge.
const FAN_POINTS := 10

var _mesh: ImmediateMesh
var _mi: MeshInstance3D
var _dot: MeshInstance3D

static var _beam_mat: StandardMaterial3D


func _ready() -> void:
	name = "Scan"
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.name = "Beams"
	_mi.mesh = _mesh
	_mi.material_override = beam_material()
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mi.set_meta("gfx_coplanar_ok", true)
	add_child(_mi)
	# A bright spot on the eye while it scans.
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 10
	sm.rings = 5
	_dot = MeshInstance3D.new()
	_dot.name = "EyeGlow"
	_dot.mesh = sm
	var g := StandardMaterial3D.new()
	g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.albedo_color = Color(0.6, 0.9, 1.0)
	_dot.material_override = g
	_dot.visible = false
	add_child(_dot)
	top_level = true
	global_transform = Transform3D()


## Off: nothing drawn.
func stop() -> void:
	_mesh.clear_surfaces()
	_dot.visible = false


## Beams from `eye` (global) to the points of `edge` (global, in order along the line), the
## curtain between them faint, each beam brighter, all fading towards the part.
func draw_fan(eye: Vector3, edge: PackedVector3Array, strength: float) -> void:
	_mesh.clear_surfaces()
	if edge.size() < 2:
		_dot.visible = false
		return
	_dot.visible = true
	_dot.global_position = eye
	var near := Color(BEAM.r, BEAM.g, BEAM.b, 0.3 * strength)
	var far := Color(BEAM.r, BEAM.g, BEAM.b, 0.1 * strength)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in edge.size() - 1:
		_mesh.surface_set_color(near)
		_mesh.surface_add_vertex(eye)
		_mesh.surface_set_color(far)
		_mesh.surface_add_vertex(edge[k])
		_mesh.surface_add_vertex(edge[k + 1])
	_mesh.surface_end()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in edge.size():
		_mesh.surface_set_color(Color(BEAM.r, BEAM.g, BEAM.b, 0.7 * strength))
		_mesh.surface_add_vertex(eye)
		_mesh.surface_set_color(Color(BEAM.r, BEAM.g, BEAM.b, 0.25 * strength))
		_mesh.surface_add_vertex(edge[k])
	_mesh.surface_end()


## Where the sweep is on a part whose box (shop space, `box`) the shop gives, at `clock` (s):
## {"axis": the box's long level axis (unit, shop space), "at": the plane's point (shop space),
## "dir": +1 / -1, the way it is going}. It sweeps the long way, across and back.
static func sweep(box: AABB, clock: float, seed_phase: float) -> Dictionary:
	var along_x := box.size.x >= box.size.z
	var axis := Vector3.RIGHT if along_x else Vector3.BACK
	var lo := box.position.x if along_x else box.position.z
	var hi := box.end.x if along_x else box.end.z
	var inset := minf((hi - lo) * 0.04, 0.05)
	var a := clock * TAU / PERIOD + seed_phase
	var t := 0.5 - 0.5 * cos(a)
	var s := lerpf(lo + inset, hi - inset, t)
	var at := box.get_center()
	if along_x:
		at.x = s
	else:
		at.z = s
	return {"axis": axis, "at": at, "dir": 1.0 if sin(a) >= 0.0 else -1.0}


## The far edge of the curtain (shop space): the part's slice at the sweep, the side facing the
## bot at `from` (shop space), up the near face and over the top if the bot is above it.
static func edge(box: AABB, sw: Dictionary, from: Vector3) -> PackedVector3Array:
	var axis: Vector3 = sw.axis
	var at: Vector3 = sw.at
	var across := Vector3.BACK if axis == Vector3.RIGHT else Vector3.RIGHT
	var c := box.get_center()
	var half := (box.size.z if axis == Vector3.RIGHT else box.size.x) * 0.5
	var side := signf((from - c).dot(across))
	if side == 0.0:
		side = 1.0
	var bottom := box.position.y + box.size.y * 0.05
	var top := box.end.y
	var base := Vector3(at.x, 0, at.z)
	var near_w := c.dot(across) + side * half
	var pts := PackedVector3Array()
	var over := from.y > top
	var n := FAN_POINTS
	for k in n:
		var t := float(k) / float(n - 1)
		var p := base
		if over:
			# Up the near face to the top edge, then across the top.
			if t < 0.5:
				p += across * (near_w - base.dot(across)) + Vector3(0, lerpf(bottom, top, t * 2.0), 0)
			else:
				var w := lerpf(near_w, c.dot(across) - side * half, (t - 0.5) * 2.0)
				p += across * (w - base.dot(across)) + Vector3(0, top, 0)
		else:
			p += across * (near_w - base.dot(across)) + Vector3(0, lerpf(bottom, top, t), 0)
		pts.append(p)
	return pts


## The line's pass over a part's own surface (each part has its own: set its plane with `aim_line`).
static func line_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SCAN_SHADER
	m.set_shader_parameter("colour", Color(BEAM.r, BEAM.g, BEAM.b))
	m.set_shader_parameter("glow", 0.0)
	m.render_priority = 1
	return m


## The plane (global normal and offset), its way and strength.
static func aim_line(m: ShaderMaterial, normal: Vector3, offset: float, dir: float, strength: float) -> void:
	m.set_shader_parameter("sweep", Vector4(normal.x, normal.y, normal.z, offset))
	m.set_shader_parameter("dir", dir)
	m.set_shader_parameter("glow", strength)


static func beam_material() -> StandardMaterial3D:
	if _beam_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(1, 1, 1)
		_beam_mat = m
	return _beam_mat
