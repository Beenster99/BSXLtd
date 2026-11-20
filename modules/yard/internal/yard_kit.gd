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

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")

var root: Node3D
var body: StaticBody3D
var _paints: Dictionary = {}
## What was built, for the room detail pass to dress: every wall() call ({along_x, at, from,
## to, y0, height, gaps, thick}) and every ceiling_lamp() ({at, panel}).
var walls: Array[Dictionary] = []
var lamps: Array[Dictionary] = []


func _init(parent: Node3D, body_name := "Body") -> void:
	root = parent
	body = StaticBody3D.new()
	body.name = body_name
	parent.add_child(body)


## A surface in Void Salvage's finish (stage 1.5): the shared salvage surface shader with a
## SurfaceFinish ("satin_paint", "brushed_steel", "tread_diamond_steel"...), in colour `c`. With
## no finish given, a metal over 0.6 is brushed steel tinted `c` and anything else satin paint.
## New and clean: no wear (the finish's wear chips paint to primer). Cached.
func paint(c: Color, metal := 0.2, rough := 0.6, finish := "") -> ShaderMaterial:
	if finish == "":
		finish = "brushed_steel" if metal >= 0.6 else "satin_paint"
	var key := "%s/%s/%s/%s" % [c.to_html(), metal, rough, finish]
	if not _paints.has(key):
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		# The albedo uniform is a source_color: Godot takes it as sRGB, like a StandardMaterial3D.
		m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))
		m.set_shader_parameter("metallic", metal)
		m.set_shader_parameter("roughness", rough)
		m.set_shader_parameter("survey_skip", true)
		SurfaceFinish.apply(m)
		# Drawn in our colour (the albedo), never the finish's own swatch: the finish gives the
		# surface its grain, sheen and roughness. A finish colour is linearised by hand, which
		# the compatibility renderer converts once more (orange came out red), so none is used.
		SurfaceFinish.set_finish(m, finish, Color(c.r, c.g, c.b, 1.0))
		m.set_shader_parameter("material_blend", 0.0)
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


## Collision alone (no mesh): a box `size` centred at `centre` (station space), for a solid
## whose look is drawn some other way.
func solid(size: Vector3, centre: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	cs.transform = _to_body(null, centre)


## A solid slab from corner `a` to corner `b` drawn as tiles at most `tile` m across (a long
## floor drawn whole takes only the first eight lamps over it on the compatibility renderer).
func slab(a: Vector3, b: Vector3, mat: Material, tile := 6.0, solid := true) -> void:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	if solid:
		span(lo, hi, mat).visible = false
	var nx := maxi(1, ceili((hi.x - lo.x) / tile))
	var nz := maxi(1, ceili((hi.z - lo.z) / tile))
	var step := Vector3((hi.x - lo.x) / nx, hi.y - lo.y, (hi.z - lo.z) / nz)
	for i in nx:
		for j in nz:
			box(step, lo + Vector3((i + 0.5) * step.x, step.y * 0.5, (j + 0.5) * step.z), mat, false)


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
	walls.append({"along_x": along_x, "at": at, "from": from, "to": to, "y0": y0, "height": height, "gaps": gaps.duplicate(true), "thick": thick})
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
		slab(Vector3(a, y0, at - thick * 0.5), Vector3(b, y1, at + thick * 0.5), mat)
	else:
		slab(Vector3(at - thick * 0.5, y0, a), Vector3(at + thick * 0.5, y1, b), mat)


## A room-light (stage 1.5): a lit panel in a dark steel bezel, a spot under it throwing a
## soft pool down the room and a faint omni round it for the ceiling and the walls' tops.
## Returns the spot (its energy is the lamp's); a light_range of 0 builds the panel alone (null).
func ceiling_lamp(at: Vector3, panel: Vector2, energy := 1.2, light_range := 9.0, shadow := false) -> SpotLight3D:
	lamps.append({"at": at, "panel": panel})
	box(Vector3(panel.x + 0.12, 0.06, panel.y + 0.12), at + Vector3(0, -0.04, 0), paint(DARK, 0.7, 0.45, "gunmetal"), false)
	box(Vector3(panel.x, 0.02, panel.y), at + Vector3(0, -0.075, 0), glow(LAMP, 3.0), false)
	if light_range <= 0.0:   # the panel only: the caller lights it its own way
		return null
	var spot := SpotLight3D.new()
	spot.position = at + Vector3(0, -0.12, 0)
	spot.rotation = Vector3(-PI * 0.5, 0, 0)
	spot.light_color = Color(1.0, 0.97, 0.92)
	spot.light_energy = energy * 2.2
	spot.spot_range = light_range * 1.2
	spot.spot_angle = 68.0
	spot.spot_angle_attenuation = 0.7
	spot.shadow_enabled = shadow
	# Our own pool: the graphics module's reflector profile (a projector) draws black on the
	# compatibility renderer.
	spot.set_meta("gfx_fixed", true)
	root.add_child(spot)
	return spot


## A strip along a wall: along X (the wall at z = `at`) or Z (at x = `at`), from `from` to `to`
## at height `y`, `height` tall, standing `out` off the wall's middle (signed: which face),
## broken at the wall's `gaps` (as `wall` takes them) where they reach above it.
func trim(along_x: bool, at: float, from: float, to: float, y: float, height: float, out: float,
		mat: Material, gaps: Array = []) -> void:
	var pos := from
	var cuts: Array = gaps.duplicate()
	cuts.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	for g: Array in cuts:
		var sill: float = g[3] if g.size() > 3 else 0.0
		if y + height <= sill or y >= float(g[2]):
			continue
		_trim_piece(along_x, at + out, pos, g[0], y, height, mat)
		pos = g[1]
	_trim_piece(along_x, at + out, pos, to, y, height, mat)


func _trim_piece(along_x: bool, at: float, a: float, b: float, y: float, height: float, mat: Material) -> void:
	if b - a < 0.01:
		return
	if along_x:
		slab(Vector3(a, y, at - 0.01), Vector3(b, y + height, at + 0.01), mat, 6.0, false)
	else:
		slab(Vector3(at - 0.01, y, a), Vector3(at + 0.01, y + height, b), mat, 6.0, false)


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
