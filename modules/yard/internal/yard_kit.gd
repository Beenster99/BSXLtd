extends RefCounted
## Simple-shape building for the orbital yard (stage 1.1 is "simple shapes first"): boxes
## with matching collision, walls with door and window gaps, paints, lamps and signs.
## Every solid goes on one StaticBody3D so the station has a single body.

const HULL := Color(0.86, 0.87, 0.88)
const WALL := Color(0.7, 0.72, 0.75)
const DECK := Color(0.42, 0.44, 0.47)
const DARK := Color(0.16, 0.17, 0.19)
const ORANGE := Color(1.0, 0.5, 0.12)
const STEEL := Color(0.55, 0.57, 0.6)
const LAMP := Color(1.0, 0.96, 0.88)

var root: Node3D
var body: StaticBody3D
var _paints: Dictionary = {}


func _init(parent: Node3D, body_name := "Body") -> void:
	root = parent
	body = StaticBody3D.new()
	body.name = body_name
	parent.add_child(body)


## A plain paint (cached by its settings).
func paint(c: Color, metal := 0.2, rough := 0.6) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [c.to_html(), metal, rough]
	if not _paints.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.metallic = metal
		m.roughness = rough
		_paints[key] = m
	return _paints[key]


func glow(c: Color, energy := 3.0) -> StandardMaterial3D:
	var key := "glow/%s/%s" % [c.to_html(), energy]
	if not _paints.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		_paints[key] = m
	return _paints[key]


func glass() -> StandardMaterial3D:
	if not _paints.has("glass"):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.7, 0.8, 0.1)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.3
		m.roughness = 0.04
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_paints["glass"] = m
	return _paints["glass"]


## A box `size` centred at `centre` (in `parent`'s space, default the root). Solid unless
## `solid` is false.
func box(size: Vector3, centre: Vector3, mat: Material, solid := true, parent: Node3D = null,
		node_name := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = centre
	if node_name != "":
		mi.name = node_name
	(parent if parent else root).add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		cs.transform = _to_body(parent, centre)
	return mi


## A box from corner `a` to corner `b` (station space).
func span(a: Vector3, b: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return box(hi - lo, (lo + hi) * 0.5, mat, solid)


## A wall along X (at z, from x0 to x1) or along Z (at x, from z0 to z1), from y0 up to
## y0 + height, `thick` through. `gaps`: [from, to, top] along the wall, open from y0 up to
## top (a door) or [from, to, top, sill] (a window, open between sill and top: give
## `pane` to glaze it).
func wall(along_x: bool, at: float, from: float, to: float, y0: float, height: float, mat: Material,
		gaps: Array = [], thick := 0.2, pane: Material = null) -> void:
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var pos := from
	for g: Array in cuts:
		var g0: float = g[0]
		var g1: float = g[1]
		var top: float = g[2]
		var sill: float = g[3] if g.size() > 3 else 0.0
		if g0 > pos:
			_wall_piece(along_x, at, pos, g0, y0, y0 + height, mat, thick)
		if top < height:
			_wall_piece(along_x, at, g0, g1, y0 + top, y0 + height, mat, thick)
		if sill > 0.0:
			_wall_piece(along_x, at, g0, g1, y0, y0 + sill, mat, thick)
			if pane:
				_wall_piece(along_x, at, g0, g1, y0 + sill, y0 + top, pane, 0.04)
		pos = g1
	if pos < to:
		_wall_piece(along_x, at, pos, to, y0, y0 + height, mat, thick)


func _wall_piece(along_x: bool, at: float, a: float, b: float, y0: float, y1: float, mat: Material,
		thick: float) -> void:
	if b - a < 0.001 or y1 - y0 < 0.001:
		return
	if along_x:
		span(Vector3(a, y0, at - thick * 0.5), Vector3(b, y1, at + thick * 0.5), mat)
	else:
		span(Vector3(at - thick * 0.5, y0, a), Vector3(at + thick * 0.5, y1, b), mat)


## A room-light: an emissive ceiling panel and an omni light under it.
func ceiling_lamp(at: Vector3, panel: Vector2, energy := 1.2, light_range := 9.0, shadow := false) -> OmniLight3D:
	box(Vector3(panel.x, 0.05, panel.y), at + Vector3(0, -0.03, 0), glow(LAMP, 2.5), false)
	var l := OmniLight3D.new()
	l.position = at + Vector3(0, -0.5, 0)
	l.light_color = Color(1.0, 0.97, 0.92)
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = shadow
	root.add_child(l)
	return l


## Flat lettering on a wall: `normal` is the way the text faces.
func sign(text: String, at: Vector3, normal: Vector3, px := 0.012, colour := Color(0.1, 0.1, 0.12),
		font_size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = font_size
	l.modulate = colour
	l.outline_size = 0
	l.double_sided = false
	l.shaded = true
	root.add_child(l)
	l.position = at + normal * 0.02
	if absf(normal.y) < 0.99:
		l.look_at(l.position - normal, Vector3.UP)
	return l


func _to_body(parent: Node3D, centre: Vector3) -> Transform3D:
	var t := Transform3D(Basis.IDENTITY, centre)
	var p := parent if parent else root
	while p and p != root:
		t = p.transform * t
		p = p.get_parent() as Node3D
	return t
