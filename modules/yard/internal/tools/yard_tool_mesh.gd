class_name YardToolMesh
extends RefCounted
## Builds tool models in code in the same form as the Void Salvage tools baked in Blender, so
## they wear the suit's finish (player_finish.gdshader) beside them: what each bit is made of
## rides in its vertices (COLOR the fixed colour, UV.x role + metal * 0.49, UV.y roughness).
## Chamfered boxes, cylinders with many sides, rings and bolt heads, in the tool's own space
## (+Y up, -Z its working end), grouped by key as YardToolArt reads them ("tool", "coil" ...).

## The finish's roles.
enum Role { FIXED = 0, PLATES = 1, TRIM = 2, ACCENT_LIGHT = 3, LIGHT = 4, RUBBER = 7, ACCENT_PAINT = 8 }

## The stock the tools are made of: [role, colour, metal, roughness].
const STOCK := {
	"steel": [Role.FIXED, Color(0.62, 0.63, 0.65), 0.9, 0.3],
	"dark": [Role.FIXED, Color(0.07, 0.075, 0.085), 0.45, 0.45],
	"gunmetal": [Role.FIXED, Color(0.2, 0.21, 0.23), 0.85, 0.35],
	"copper": [Role.FIXED, Color(0.65, 0.25, 0.09), 0.88, 0.28],
	"brass": [Role.FIXED, Color(0.65, 0.45, 0.17), 0.85, 0.27],
	"rubber": [Role.RUBBER, Color(0.04, 0.04, 0.045), 0.0, 0.85],
	"orange": [Role.FIXED, Color(0.86, 0.36, 0.06), 0.3, 0.35],
	"bsx": [Role.FIXED, Color(0.92, 0.48, 0.1), 0.25, 0.4],
	"ceramic": [Role.FIXED, Color(0.72, 0.75, 0.7), 0.12, 0.31],
	"plates": [Role.PLATES, Color.WHITE, 0.2, 0.4],
	"trim": [Role.TRIM, Color.WHITE, 0.3, 0.4],
	"cyan": [Role.LIGHT, Color(0.35, 0.9, 1.0), 0.0, 0.3],
	"glass": [Role.FIXED, Color(0.02, 0.03, 0.04), 0.1, 0.08],
	# The livery's own paint and lamps (the bots' and ships' accent colour).
	"accent": [Role.ACCENT_PAINT, Color.WHITE, 0.25, 0.4],
	"accent_light": [Role.ACCENT_LIGHT, Color.WHITE, 0.0, 0.3],
	"lamp": [Role.LIGHT, Color(1.0, 0.95, 0.85), 0.0, 0.3],
	"red_lamp": [Role.LIGHT, Color(1.0, 0.12, 0.08), 0.0, 0.3],
}

var _groups: Dictionary = {}


## The meshes made so far, by key.
func meshes() -> Dictionary:
	var out: Dictionary = {}
	for key: String in _groups:
		out[key] = (_groups[key] as SurfaceTool).commit()
	return out


func _st(key: String) -> SurfaceTool:
	if not _groups.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_groups[key] = st
	return _groups[key]


func _tri(key: String, stock: String, a: Vector3, b: Vector3, c: Vector3, na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
	var st := _st(key)
	var s: Array = STOCK[stock]
	var uv := Vector2(float(s[0]) + float(s[2]) * 0.49, float(s[3]))
	var flat := (b - a).cross(c - a).normalized()
	# Godot's front faces wind clockwise: take the triangle in the order a, c, b.
	for p: Array in [[a, na], [c, nc], [b, nb]]:
		st.set_color(s[1])
		st.set_uv(uv)
		st.set_normal(flat if (p[1] as Vector3).is_zero_approx() else p[1])
		st.add_vertex(p[0])


func _quad(key: String, stock: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_tri(key, stock, a, b, c)
	_tri(key, stock, a, c, d)


## A box `size` centred at `at` (turned by `basis`), its edges chamfered by `bevel`.
func box(key: String, stock: String, at: Vector3, size: Vector3, bevel: float = 0.003, basis := Basis()) -> void:
	var h := size * 0.5
	var c := minf(bevel, minf(h.x, minf(h.y, h.z)) * 0.9)
	# The point of the face on `axis` at the corner of signs `s`.
	var pt := func(axis: int, s: Vector3) -> Vector3:
		var p := Vector3()
		for i in 3:
			p[i] = s[i] * (h[i] if i == axis else h[i] - c)
		return at + basis * p
	var signs: Array[Vector3] = []
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				signs.append(Vector3(sx, sy, sz))
	var out := func(points: Array, centre: Vector3) -> Array:
		# Wind each face outward from the box's middle.
		var p0: Vector3 = points[0]
		var n: Vector3 = ((points[1] as Vector3) - p0).cross((points[2] as Vector3) - p0)
		if n.dot(centre - at) < 0.0:
			points.reverse()
		return points
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side: float in [-1.0, 1.0]:
			var q: Array = []
			for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3()
				s[axis] = side
				s[u] = k.x
				s[v] = k.y
				q.append(pt.call(axis, s))
			var mid := at + basis * (_axis(axis) * side * h[axis])
			q = out.call(q, mid)
			_quad(key, stock, q[0], q[1], q[2], q[3])
	if c <= 0.0:
		return
	# The chamfers along the twelve edges, and the eight corner facets.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				var s0 := Vector3()
				s0[u] = su
				s0[v] = sv
				s0[axis] = -1.0
				var s1 := s0
				s1[axis] = 1.0
				var q: Array = [pt.call(u, s0), pt.call(u, s1), pt.call(v, s1), pt.call(v, s0)]
				var mid := at + basis * ((_axis(u) * su * h[u]) + (_axis(v) * sv * h[v]))
				q = out.call(q, mid)
				_quad(key, stock, q[0], q[1], q[2], q[3])
	for s: Vector3 in signs:
		var t: Array = [pt.call(0, s), pt.call(1, s), pt.call(2, s)]
		t = out.call(t, at + basis * (s * h))
		_tri(key, stock, t[0], t[1], t[2])


static func _axis(i: int) -> Vector3:
	return [Vector3.RIGHT, Vector3.UP, Vector3.BACK][i]


## A round rod from `a` to `b`, radius `r` (to `r2` at `b`), capped, smooth round its sides.
func rod(key: String, stock: String, a: Vector3, b: Vector3, r: float, r2: float = -1.0, sides: int = 32) -> void:
	if r2 < 0.0:
		r2 = r
	var along := (b - a).normalized()
	var x := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := along.cross(x).normalized()
	var slope := (r - r2) / maxf(a.distance_to(b), 0.0001)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var d0 := x * cos(a0) + y * sin(a0)
		var d1 := x * cos(a1) + y * sin(a1)
		var n0 := (d0 + along * slope).normalized()
		var n1 := (d1 + along * slope).normalized()
		_tri(key, stock, a + d0 * r, a + d1 * r, b + d1 * r2, n0, n1, n1)
		_tri(key, stock, a + d0 * r, b + d1 * r2, b + d0 * r2, n0, n1, n0)
		_tri(key, stock, a, a + d1 * r, a + d0 * r)
		_tri(key, stock, b, b + d0 * r2, b + d1 * r2)


## A ring (torus) round `axis` at `at`: radius `r`, its tube `minor`.
func ring(key: String, stock: String, at: Vector3, r: float, minor: float, axis := Vector3.BACK, sides: int = 32, tube: int = 8) -> void:
	axis = axis.normalized()
	var x := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var y := axis.cross(x).normalized()
	var p := func(i: int, j: int) -> Array:
		var a := TAU * i / sides
		var b := TAU * j / tube
		var out := x * cos(a) + y * sin(a)
		var n := out * cos(b) + axis * sin(b)
		return [at + out * r + n * minor, n]
	for i in sides:
		for j in tube:
			var p00: Array = p.call(i, j)
			var p10: Array = p.call(i + 1, j)
			var p11: Array = p.call(i + 1, j + 1)
			var p01: Array = p.call(i, j + 1)
			_tri(key, stock, p00[0], p10[0], p11[0], p00[1], p10[1], p11[1])
			_tri(key, stock, p00[0], p11[0], p01[0], p00[1], p11[1], p01[1])


## A hex bolt head standing out of a surface along `normal`.
func bolt(key: String, at: Vector3, normal: Vector3, r: float = 0.0035) -> void:
	rod(key, "steel", at, at + normal.normalized() * r * 0.8, r, r * 0.92, 6)


## Machined ribs round a barrel along Z, `count` of them from z0 to z1.
func ribs(key: String, stock: String, z0: float, z1: float, r: float, count: int, x: float = 0.0, y: float = 0.0) -> void:
	for i in count:
		var z := z0 + (z1 - z0) * (i + 0.5) / count
		ring(key, stock, Vector3(x, y, z), r, 0.002, Vector3.BACK, 32, 6)


## A pistol grip in the Void Salvage tools' form (tool_designs.py `pistol`): rubber with cheek
## inserts, tread and a heel, centred on `centre`, leaned back by `tilt` (rad).
func pistol(key: String, centre: Vector3, half: Vector2, tilt: float, accent: String) -> void:
	var b := Basis(Vector3.RIGHT, tilt)
	var height := 0.112
	box(key, "rubber", centre, Vector3(half.x * 2.0, height, half.y * 2.0), 0.005, b)
	for s: float in [-1.0, 1.0]:
		box(key, accent, centre + b * Vector3(s * (half.x - 0.001), 0.012, 0.0), Vector3(0.003, 0.054, half.y * 1.25), 0.002, b)
		for ty: float in [-0.035, -0.018, -0.001, 0.016, 0.033]:
			box(key, "dark", centre + b * Vector3(s * half.x, ty, -0.002), Vector3(0.0015, 0.003, half.y * 1.45), 0.0005, b)
		bolt(key, centre + b * Vector3(s * (half.x + 0.001), 0.036, 0.008), b * Vector3(s, 0, 0), 0.0024)
	box(key, accent, centre + b * Vector3(0, -height * 0.5 - 0.004, 0.002), Vector3(half.x * 2.0 + 0.008, 0.012, half.y * 2.0 + 0.006), 0.003, b)


## The index trigger in front of a grip.
func trigger(key: String, at: Vector3) -> void:
	box(key, "orange", at, Vector3(0.017, 0.027, 0.011), 0.003)
	rod(key, "steel", Vector3(-0.011, at.y + 0.015, at.z + 0.005), Vector3(0.011, at.y + 0.015, at.z + 0.005), 0.004, -1.0, 12)


## A small lit instrument flush on the body (tool_designs.py `display`): bezel, glass, bars.
func display(key: String, at: Vector3, size: Vector2) -> void:
	box(key, "dark", at, Vector3(size.x + 0.009, 0.01, size.y + 0.009), 0.003)
	box(key, "glass", at + Vector3(0, 0.006, 0), Vector3(size.x, 0.003, size.y), 0.002)
	for i in 4:
		box(key, "cyan", at + Vector3(-size.x * 0.3 + i * size.x * 0.19, 0.008, 0), Vector3(0.006, 0.001, size.y * 0.5), 0.0005)
