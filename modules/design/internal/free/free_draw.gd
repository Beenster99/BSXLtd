extends RefCounted
## Draws a free-structure tool's ghost (FreeTool.ghost) as lines in 3D, in ship space: the
## grid round the pointer (on the axis plane most square to the view), guidelines to the ends
## it lines up with (x red, y green, z blue), the beam being drawn, the plate's outline, and a
## mark on the point (a ring on a node).

const GUIDE := [Color(1.0, 0.35, 0.3), Color(0.4, 1.0, 0.45), Color(0.35, 0.6, 1.0)]
const RUBBER := Color(1.0, 0.6, 0.3)
const PLATE := Color(0.45, 0.95, 1.0)
const GRID := Color(0.5, 0.75, 1.0, 0.35)
const NODE := Color(1.0, 0.95, 0.4)


## A mesh node for the ghost, unshaded, drawn over the ship.
static func make() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "FreeGhost"
	mi.mesh = ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Redraws `mi` for ghost `g`; `view` is the way the camera looks (ship space), `grid` the step.
static func draw(mi: MeshInstance3D, g: Dictionary, view: Vector3, grid: float) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if not (g.get("point") is Vector3):
		return
	var p: Vector3 = g.point
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# The grid patch: the axis plane most square to the view, 2 m each way (fewer lines on a fine grid).
	var ax := 0
	for i in 3:
		if absf(view[i]) > absf(view[ax]):
			ax = i
	var u := (ax + 1) % 3
	var w := (ax + 2) % 3
	var step := grid if grid >= 0.25 else 0.25
	var n := int(2.0 / step)
	for k in range(-n, n + 1):
		for pair: Array in [[u, w], [w, u]]:
			var a := p
			var b := p
			a[pair[0]] += k * step
			b[pair[0]] += k * step
			a[pair[1]] -= n * step
			b[pair[1]] += n * step
			_line(im, a, b, Color(GRID, GRID.a * (1.0 - absf(k) / float(n + 1))))
	for gd: Array in g.get("guides", []):
		_line(im, gd[0], gd[1], GUIDE[int(gd[2])])
	var rub: Array = g.get("rubber", [])
	if rub.size() == 2:
		_line(im, rub[0], rub[1], RUBBER)
	var ol: Array = g.get("outline", [])
	for i in ol.size():
		_line(im, ol[i], ol[(i + 1) % ol.size()], PLATE)
	# The point: a cross, ringed when it sits on a node.
	var r := 0.12
	for d: Vector3 in [Vector3(r, 0, 0), Vector3(0, r, 0), Vector3(0, 0, r)]:
		_line(im, p - d, p + d, NODE)
	if str(g.get("kind", "")) == "node":
		for i in 12:
			var a0 := TAU * i / 12.0
			var a1 := TAU * (i + 1) / 12.0
			var e0 := Vector3.ZERO
			var e1 := Vector3.ZERO
			e0[u] = cos(a0) * r * 1.6
			e0[w] = sin(a0) * r * 1.6
			e1[u] = cos(a1) * r * 1.6
			e1[w] = sin(a1) * r * 1.6
			_line(im, p + e0, p + e1, NODE)
	im.surface_end()


static func _line(im: ImmediateMesh, a: Vector3, b: Vector3, c: Color) -> void:
	im.surface_set_color(c)
	im.surface_add_vertex(a)
	im.surface_set_color(c)
	im.surface_add_vertex(b)
