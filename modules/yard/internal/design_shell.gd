extends RefCounted
## The design room as a creative space (0.4.0 playtest): a glazed barrel vault over the room
## from the window to the back, peaking at YardBus.DESIGN_ROOM_PEAK, with the planet and the
## stars through it; a mezzanine along the back wall with a glass rail and a stair at its left
## end; the corridor door under it. The walls are left bare for the Design Room module's
## screens (YardBus.design_room_walls()): no lamps, pipes or signs on them.

## Station space (the room runs x -12..12, z -22..-4).
const X0 := -12.0
const X1 := 12.0
const Z_FRONT := -22.0
const Z_BACK := -4.0
## The vault springs from the side walls' tops.
const SPRING := 6.0
## Segments round the arch and ribs along the room.
const SEGMENTS := 16
const RIB_EVERY := 3.0
## The stair (along x, at the mezzanine's front): bottom and top x, its width along z.
const STAIR_BOTTOM_X := -4.4
const STAIR_TOP_X := -10.4
const STAIR_Z := Vector2(-9.5, -8.0)
const STEPS := 17

var _kit


func build(kit, hull: Material, wall: Material, dark: Material, deck: Material) -> void:
	_kit = kit
	var k = kit
	var pane: Material = k.glass()
	var peak := YardBus.DESIGN_ROOM_PEAK
	var half := (X1 - X0) * 0.5
	var rise := peak - SPRING
	var radius := (half * half + rise * rise) / (2.0 * rise)
	var centre_y := peak - radius
	var top_angle := asin(half / radius)
	var arc: Array[Vector2] = []   # (x, y) from the left spring to the right
	for i in SEGMENTS + 1:
		var a := lerpf(-top_angle, top_angle, float(i) / SEGMENTS)
		arc.append(Vector2(sin(a) * radius, centre_y + cos(a) * radius))
	var length := Z_BACK - Z_FRONT
	var mid_z := (Z_FRONT + Z_BACK) * 0.5
	# The glazing: one solid pane per segment, the whole room long.
	for i in SEGMENTS:
		var p := arc[i]
		var q := arc[i + 1]
		var glass := _beam(p, q, mid_z, Vector2(0.04, length + 0.05), pane, true, 0.0)
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Ribs inside the glass, and a purlin along the ridge.
	var z := Z_FRONT
	while z < Z_BACK - 0.5:   # none at the back: the gable is its own edge
		for i in SEGMENTS:
			_beam(arc[i], arc[i + 1], z, Vector2(0.28, 0.22), dark, false, 0.18)
		z += RIB_EVERY
	for i in [SEGMENTS / 4, SEGMENTS / 2, SEGMENTS * 3 / 4]:
		var at := arc[i]
		var c := Vector3(at.x, at.y, mid_z) - Vector3(at.x, at.y - centre_y, 0).normalized() * 0.2
		k.box(Vector3(0.16, 0.16, length), c, dark, false)
	# Wall plates where the vault springs from the side walls.
	for x: float in [X0, X1]:
		k.box(Vector3(0.36, 0.24, length + 0.06), Vector3(x, SPRING + 0.12, mid_z), hull, false)
	# The gables: glass at the window end (mullions in line with the window's), painted at the back.
	_gable(arc, Z_FRONT, pane, true)
	_gable(arc, Z_BACK, wall, false)
	for x: float in [-5.0, 0.0, 5.0]:
		var top := centre_y + sqrt(radius * radius - x * x)
		k.box(Vector3(0.12, top - SPRING, 0.16), Vector3(x, (top + SPRING) * 0.5, Z_FRONT), dark, false)
	# Pendant lamps hung from the ribs (the room's light now the walls are screens).
	for p: Vector2 in [Vector2(-6, -19), Vector2(6, -19), Vector2(-6, -13), Vector2(6, -13), Vector2(0, -16), Vector2(-6, -10), Vector2(6, -10)]:
		var top := centre_y + sqrt(radius * radius - p.x * p.x)
		var hang := 8.2
		k.box(Vector3(0.04, top - hang, 0.04), Vector3(p.x, (top + hang) * 0.5, p.y), dark, false)
		k.ceiling_lamp(Vector3(p.x, hang, p.y), Vector2(1.6, 1.6), 1.7, 14.0)
	_mezzanine(dark, deck, pane)


## A beam or a pane from arch point `p` to `q` at `z`: `size` is (thickness, length along z).
## `inset` moves it in from the arch, towards the room.
func _beam(p: Vector2, q: Vector2, z: float, size: Vector2, mat: Material, solid: bool, inset: float) -> MeshInstance3D:
	var along := Vector3(q.x - p.x, q.y - p.y, 0.0)
	var mid := Vector3((p.x + q.x) * 0.5, (p.y + q.y) * 0.5, z)
	var out := Vector3(-along.y, along.x, 0.0).normalized()
	if out.y < 0.0:
		out = -out
	mid -= out * (inset + size.x * 0.5)
	var basis := Basis(along.normalized(), out, along.normalized().cross(out))
	var box_size := Vector3(along.length() + 0.02, size.x, size.y)
	return _solid(box_size, Transform3D(basis, mid), mat, solid)


## A rotated box on the station's body: drawn, and solid if asked.
func _solid(size: Vector3, t: Transform3D, mat: Material, solid: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = t
	_kit.root.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		cs.transform = t
		_kit.body.add_child(cs)
	return mi


## The end wall over the side walls' tops, filled to the arch, 0.2 m thick and solid.
func _gable(arc: Array[Vector2], z: float, mat: Material, glass: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var t := 0.04 if glass else 0.2
	for side: float in [-1.0, 1.0]:
		var zz := z + side * t * 0.5
		for i in arc.size() - 1:
			var a := Vector3(arc[i].x, SPRING, zz)
			var b := Vector3(arc[i].x, arc[i].y, zz)
			var c := Vector3(arc[i + 1].x, arc[i + 1].y, zz)
			var d := Vector3(arc[i + 1].x, SPRING, zz)
			var tris := [a, b, c, a, c, d] if side > 0.0 else [a, c, b, a, d, c]
			st.set_normal(Vector3(0, 0, side))
			for v: Vector3 in tris:
				st.set_uv(Vector2(v.x, v.y) * 0.25)
				st.add_vertex(v)
				faces.append(v)
	var mi := MeshInstance3D.new()
	mi.name = "Gable_front" if glass else "Gable_back"
	mi.mesh = st.commit()
	mi.material_override = mat
	if glass:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_kit.root.add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	cs.shape = shape
	_kit.body.add_child(cs)


## Along the back wall: the deck, its fascia, a glass rail, the lamps under it, and the stair
## up from the room at its left end onto a landing.
func _mezzanine(dark: Material, deck: Material, pane: Material) -> void:
	var k = _kit
	var y := YardBus.DESIGN_MEZZANINE_Y
	var front := Z_BACK - YardBus.DESIGN_MEZZANINE_DEPTH
	k.slab(Vector3(X0, y - 0.25, front), Vector3(X1, y, Z_BACK), deck)
	k.slab(Vector3(X0, y - 0.25, STAIR_Z.x), Vector3(STAIR_TOP_X, y, front), deck)
	k.box(Vector3(X1 - STAIR_TOP_X, 0.36, 0.06), Vector3((X1 + STAIR_TOP_X) * 0.5, y - 0.12, front - 0.032), dark, false)
	k.box(Vector3(STAIR_TOP_X - X0, 0.36, 0.06), Vector3((X0 + STAIR_TOP_X) * 0.5, y - 0.12, STAIR_Z.x - 0.032), dark, false)
	# Glass rails: along the front (the stair's side included) and round the landing's edge.
	_rail(Vector3(STAIR_TOP_X, y, front + 0.04), Vector3(X1 - 0.02, y, front + 0.04), dark, pane)
	_rail(Vector3(X0 + 0.02, y, STAIR_Z.x + 0.04), Vector3(STAIR_TOP_X, y, STAIR_Z.x + 0.04), dark, pane)
	# Lamps under it (off the walls).
	for x: float in [-8.0, -2.0, 4.0, 9.5]:
		k.ceiling_lamp(Vector3(x, y - 0.25, (front + Z_BACK) * 0.5), Vector2(1.4, 0.5), 0.9, 7.0)
	# The stair: a sloped plate to walk on (the treads are drawn on it), its outer rail.
	var run := STAIR_BOTTOM_X - STAIR_TOP_X
	var slope := atan2(y, run)
	var width := STAIR_Z.y - STAIR_Z.x
	var plate := Vector3(sqrt(run * run + y * y), 0.1, width)
	var basis := Basis(Vector3.BACK, -slope)
	var mid := Vector3((STAIR_BOTTOM_X + STAIR_TOP_X) * 0.5, y * 0.5 - 0.1, (STAIR_Z.x + STAIR_Z.y) * 0.5)
	_solid(plate, Transform3D(basis, mid - basis.y * 0.05), dark, true).name = "Stair"
	var tread := run / STEPS
	for i in STEPS:
		var x := STAIR_BOTTOM_X - tread * (i + 0.5)
		k.box(Vector3(tread - 0.01, 0.05, width - 0.06), Vector3(x, y / STEPS * (i + 1) - 0.025, mid.z), deck, false)
		k.box(Vector3(0.03, y / STEPS - 0.05, width - 0.1), Vector3(x + tread * 0.5, y / STEPS * (i + 0.5) - 0.025, mid.z), dark, false)
	var rail_basis := Basis(Vector3.BACK, -slope)
	var rail_mid := Vector3(mid.x, y * 0.5 + 0.95, STAIR_Z.x + 0.04)
	_solid(Vector3(plate.x, 0.06, 0.06), Transform3D(rail_basis, rail_mid), dark, false)
	var glass := _solid(Vector3(plate.x, 0.9, 0.03), Transform3D(rail_basis, rail_mid - Vector3(0, 0.5, 0)), pane, true)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A glass balustrade from `a` to `b` (deck level, along x), 1.05 m high, with posts.
func _rail(a: Vector3, b: Vector3, dark: Material, pane: Material) -> void:
	var k = _kit
	var len := b.x - a.x
	var mid := (a + b) * 0.5
	k.box(Vector3(len, 0.06, 0.06), mid + Vector3(0, 1.05, 0), dark, false)
	var glass: MeshInstance3D = k.box(Vector3(len, 0.9, 0.03), mid + Vector3(0, 0.55, 0), pane, true)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := maxi(1, ceili(len / 1.6))
	for i in n + 1:
		k.box(Vector3(0.05, 1.05, 0.05), Vector3(a.x + len * i / n, a.y + 0.525, a.z), dark, false)
