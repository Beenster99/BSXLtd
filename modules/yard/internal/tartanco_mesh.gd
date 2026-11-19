extends RefCounted
## A small mesh builder for TartanCo's ships and engineers: chamfered boxes, tapered octagon
## sections along Z and cylinders, grouped by key ("hull", "shutter_1" ...) and by stock (what
## each bit is made of), so each key commits to one ArrayMesh with a surface per stock.

## stock -> [albedo, metallic, roughness, emission energy (0: none)].
const STOCK := {
	"paint": [Color(0.7, 0.7, 0.68), 0.3, 0.55, 0.0],
	"panel": [Color(0.5, 0.51, 0.53), 0.35, 0.5, 0.0],
	"grey": [Color(0.36, 0.37, 0.39), 0.5, 0.45, 0.0],
	"yellow": [Color(0.96, 0.66, 0.06), 0.25, 0.45, 0.0],
	"dark": [Color(0.07, 0.075, 0.085), 0.55, 0.45, 0.0],
	"gunmetal": [Color(0.2, 0.21, 0.23), 0.85, 0.35, 0.0],
	"steel": [Color(0.62, 0.63, 0.65), 0.9, 0.3, 0.0],
	"rubber": [Color(0.04, 0.04, 0.045), 0.0, 0.85, 0.0],
	"tartan": [Color.WHITE, 0.15, 0.7, 0.0],
	"glass": [Color(0.05, 0.09, 0.13), 0.3, 0.05, 0.0],
	"window": [Color(0.75, 0.88, 1.0), 0.0, 0.3, 0.9],
	"lamp": [Color(1.0, 0.95, 0.82), 0.0, 0.3, 3.0],
	"screen": [Color(0.3, 0.85, 1.0), 0.0, 0.3, 1.6],
	"red_lamp": [Color(1.0, 0.12, 0.08), 0.0, 0.3, 3.0],
	"green_lamp": [Color(0.15, 1.0, 0.3), 0.0, 0.3, 3.0],
	"glow": [Color(0.55, 0.8, 1.0), 0.0, 0.3, 4.0],
	"visor": [Color(0.9, 0.62, 0.15), 0.9, 0.08, 0.15],
	"suit": [Color(0.86, 0.86, 0.84), 0.05, 0.75, 0.0],
	"tread": [Color(0.3, 0.31, 0.33), 0.8, 0.4, 0.0],
	"hazard": [Color(0.96, 0.66, 0.06), 0.25, 0.45, 0.0],
}
## Stocks drawn with Void Salvage's own salvage surface (the shader, its detail maps and a
## finish from SurfaceFinish), so TartanCo's ships wear the same paint, metal, tread and
## rubber as the parts in the stores. Stock -> finish id. The rest (glass, lamps, screens,
## the tartan cloth) are plain materials.
const FINISHES := {
	"paint": "satin_paint", "panel": "metallic_paint", "grey": "satin_paint", "yellow": "gloss_paint",
	"dark": "satin_paint", "gunmetal": "gunmetal", "steel": "brushed_steel", "rubber": "rubber",
	"suit": "canvas", "tread": "tread_diamond_steel", "hazard": "hazard_stripes",
}
const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")
## How worn TartanCo keeps its kit (0 new): a working ship, looked after.
const WEAR := 0.12

static var _materials: Dictionary = {}
static var _tartan: ImageTexture

## key -> stock -> SurfaceTool
var _groups: Dictionary = {}


static func material(stock: String) -> Material:
	if not _materials.has(stock) and FINISHES.has(stock):
		var s: Array = STOCK[stock]
		var c: Color = s[0]
		var sm := ShaderMaterial.new()
		sm.shader = SURFACE
		sm.set_shader_parameter("albedo", Color(c.r, c.g, c.b))
		sm.set_shader_parameter("metallic", s[1])
		sm.set_shader_parameter("roughness", s[2])
		sm.set_shader_parameter("survey_skip", true)
		SurfaceDetail.apply(sm)
		SurfaceFinish.apply(sm)
		# Drawn in our colour, the finish giving grain, sheen and roughness (as YardKit.paint).
		SurfaceFinish.set_finish(sm, FINISHES[stock], Color(c.r, c.g, c.b, 1.0))
		sm.set_shader_parameter("material_blend", 0.0)
		sm.set_shader_parameter("condition", Vector4(WEAR, 0.0, 0.0, float(stock.hash() % 97)))
		_materials[stock] = sm
	if not _materials.has(stock):
		var s: Array = STOCK[stock]
		var m := StandardMaterial3D.new()
		m.albedo_color = s[0]
		m.metallic = s[1]
		m.roughness = s[2]
		if float(s[3]) > 0.0:
			m.emission_enabled = true
			m.emission = s[0]
			m.emission_energy_multiplier = s[3]
		if stock == "tartan":
			m.albedo_texture = tartan_texture()
			m.uv1_triplanar = true
			m.uv1_world_triplanar = false
			m.uv1_scale = Vector3(0.35, 0.35, 0.35)
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_materials[stock] = m
	return _materials[stock]


## TartanCo's own sett: a dark green ground, navy blocks, a red line and a yellow overcheck.
static func tartan_texture() -> ImageTexture:
	if _tartan:
		return _tartan
	var green := Color(0.06, 0.24, 0.13)
	var navy := Color(0.05, 0.08, 0.22)
	var black := Color(0.03, 0.03, 0.04)
	var red := Color(0.72, 0.07, 0.07)
	var yellow := Color(0.98, 0.72, 0.1)
	# The sett: colour, threads. It repeats both ways and is woven twill (over two, under two).
	var sett := [[green, 24], [black, 4], [navy, 14], [black, 4], [green, 24], [red, 4], [green, 6], [yellow, 2], [green, 6], [red, 4]]
	var line: Array[Color] = []
	for band: Array in sett:
		for i in int(band[1]):
			line.append(band[0])
	var n := line.size()
	var img := Image.create(n, n, true, Image.FORMAT_RGB8)
	for y in n:
		for x in n:
			var warp := ((x + y) / 2) % 2 == 0
			var c: Color = line[x] if warp else line[y]
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	_tartan = ImageTexture.create_from_image(img)
	return _tartan


## The meshes made so far, by key: one ArrayMesh each, a surface per stock with its material.
func meshes() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _groups:
		var mesh := ArrayMesh.new()
		for stock: String in _groups[key]:
			var st: SurfaceTool = _groups[key][stock]
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material(stock))
		out[key] = mesh
	return out


func _st(key: String, stock: String) -> SurfaceTool:
	if not _groups.has(key):
		_groups[key] = {}
	if not _groups[key].has(stock):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_groups[key][stock] = st
	return _groups[key][stock]


func tri(key: String, stock: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _st(key, stock)
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	# Godot's front faces wind clockwise seen from the front: emit a, c, b.
	for p: Vector3 in [a, c, b]:
		st.set_normal(n)
		st.set_uv(Vector2(p.x + p.z, p.y))
		st.add_vertex(p)


func quad(key: String, stock: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(key, stock, a, b, c)
	tri(key, stock, a, c, d)


## A box `size` centred at `at`, turned by `basis`, its edges chamfered by `bevel`.
func box(key: String, stock: String, at: Vector3, size: Vector3, bevel: float = 0.05, basis := Basis()) -> void:
	var h := size * 0.5
	var c := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.45)
	if c <= 0.0005:
		var p := func(x: float, y: float, z: float) -> Vector3: return at + basis * Vector3(x * h.x, y * h.y, z * h.z)
		quad(key, stock, p.call(1, -1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(1, -1, 1))
		quad(key, stock, p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), p.call(-1, -1, -1))
		quad(key, stock, p.call(-1, 1, -1), p.call(-1, 1, 1), p.call(1, 1, 1), p.call(1, 1, -1))
		quad(key, stock, p.call(-1, -1, 1), p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1))
		quad(key, stock, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1))
		quad(key, stock, p.call(1, -1, -1), p.call(-1, -1, -1), p.call(-1, 1, -1), p.call(1, 1, -1))
		return
	# A chamfered box is an octagon prism along Z with its end faces chamfered too: build it
	# as the end octagons inset by c, joined by the sides.
	var front: Array = _octagon(h.x - c, h.y - c, 0.0001, -h.z)
	var ring_a: Array = _octagon(h.x, h.y, c, -h.z + c)
	var ring_b: Array = _octagon(h.x, h.y, c, h.z - c)
	var back: Array = _octagon(h.x - c, h.y - c, 0.0001, h.z)
	var tf := func(p: Vector3) -> Vector3: return at + basis * p
	_band(key, stock, front, ring_a, tf)
	_band(key, stock, ring_a, ring_b, tf)
	_band(key, stock, ring_b, back, tf)
	_cap(key, stock, front, tf, false)
	_cap(key, stock, back, tf, true)


## Eight points round an octagon of half extents (hx, hy), corners cut by c, at z.
func _octagon(hx: float, hy: float, c: float, z: float) -> Array:
	c = minf(c, minf(hx, hy) * 0.95)
	return [Vector3(hx, -hy + c, z), Vector3(hx, hy - c, z), Vector3(hx - c, hy, z), Vector3(-hx + c, hy, z),
			Vector3(-hx, hy - c, z), Vector3(-hx, -hy + c, z), Vector3(-hx + c, -hy, z), Vector3(hx - c, -hy, z)]


func _band(key: String, stock: String, a: Array, b: Array, tf: Callable) -> void:
	var n := a.size()
	for i in n:
		var j := (i + 1) % n
		quad(key, stock, tf.call(a[i]), tf.call(a[j]), tf.call(b[j]), tf.call(b[i]))


func _cap(key: String, stock: String, ring: Array, tf: Callable, facing_plus: bool) -> void:
	var mid := Vector3.ZERO
	for p: Vector3 in ring:
		mid += p
	mid /= ring.size()
	for i in ring.size():
		var j := (i + 1) % ring.size()
		if facing_plus:
			tri(key, stock, tf.call(mid), tf.call(ring[i]), tf.call(ring[j]))
		else:
			tri(key, stock, tf.call(mid), tf.call(ring[j]), tf.call(ring[i]))


## A hull section along Z from z0 to z1, an octagon of half extents h0 at z0 tapering to h1
## at z1 (corners cut by that fraction of the smaller half), centred on (cx, cy), capped.
func section(key: String, stock: String, centre: Vector2, z0: float, h0: Vector2, z1: float, h1: Vector2, cut := 0.3, caps := true) -> void:
	var a := _octagon(h0.x, h0.y, minf(h0.x, h0.y) * cut, z0)
	var b := _octagon(h1.x, h1.y, minf(h1.x, h1.y) * cut, z1)
	var tf := func(p: Vector3) -> Vector3: return p + Vector3(centre.x, centre.y, 0)
	_band(key, stock, a, b, tf)
	if caps:
		_cap(key, stock, a, tf, false)
		_cap(key, stock, b, tf, true)


## A cylinder along `axis` (a Basis's z) centred at `at`, radius r0 at its -z end and r1 at +z.
func cylinder(key: String, stock: String, at: Vector3, length: float, r0: float, r1: float = -1.0, sides := 16, basis := Basis(), caps := true) -> void:
	if r1 < 0.0:
		r1 = r0
	var a: Array = []
	var b: Array = []
	for i in sides:
		var t := TAU * float(i) / float(sides)
		a.append(Vector3(cos(t) * r0, sin(t) * r0, -length * 0.5))
		b.append(Vector3(cos(t) * r1, sin(t) * r1, length * 0.5))
	var tf := func(p: Vector3) -> Vector3: return at + basis * p
	_band(key, stock, a, b, tf)
	if caps:
		_cap(key, stock, a, tf, false)
		_cap(key, stock, b, tf, true)


## A bar from a to b of square section w (a strut, a truss member, an arm).
func bar(key: String, stock: String, a: Vector3, b: Vector3, w: float, bevel := 0.02) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.001:
		return
	var z := d / len
	var up := Vector3.UP if absf(z.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := up.cross(z).normalized()
	var y := z.cross(x)
	box(key, stock, (a + b) * 0.5, Vector3(w, w, len), bevel, Basis(x, y, z))


## A sphere-ish ball (an icosphere's second step would do; a 12-sided UV ball is enough).
func ball(key: String, stock: String, at: Vector3, r: Vector3, rings := 8, sides := 12) -> void:
	var pts: Array = []
	for i in rings + 1:
		var v := PI * float(i) / float(rings)
		var row: Array = []
		for j in sides:
			var u := TAU * float(j) / float(sides)
			row.append(at + Vector3(sin(v) * cos(u) * r.x, cos(v) * r.y, sin(v) * sin(u) * r.z))
		pts.append(row)
	for i in rings:
		for j in sides:
			var k := (j + 1) % sides
			quad(key, stock, pts[i][j], pts[i][k], pts[i + 1][k], pts[i + 1][j])
