extends RefCounted
## Route planning over the shipyard's floor for the hover trolleys (and the picking lift):
## a grid of CELL-metre squares over the yard, blocked wherever something solid stands
## between BAND_LOW and BAND_HIGH over the floor (walls, racks, benches, the stairs, the ship
## on its cradles), with each cell's clearance to the nearest obstacle. A route for a
## trolley of radius r keeps r clear of everything, takes the shortest way through the
## doors and is then pulled straight wherever it can see past the corners.
## Built once from the yard's static collision; runs only on the peer driving the trolley.

const CELL := 0.25
## Metres over the floor that count as in the way.
const BAND_LOW := 0.12
const BAND_HIGH := 2.2
## The planned area (x, z, width, depth), metres: the three wings, the courtyard, the apron
## in front, the plate hall west of Stock and the crusher house east of Pre-assembly.
const AREA := Rect2(-86.0, -46.0, 178.0, 98.0)

var size := Vector2i.ZERO
## Blocked cells (1) as a flat array, row by row (z).
var blocked := PackedByteArray()
## Distance from each cell to the nearest blocked cell, metres.
var clearance := PackedFloat32Array()
var _grids: Dictionary = {}   # radius (cm) -> AStarGrid2D


## Reads every static collision shape under `root` (skipping bodies in `skip`) into the grid.
func build(root: Node, skip: Array = []) -> void:
	size = Vector2i(int(ceilf(AREA.size.x / CELL)), int(ceilf(AREA.size.y / CELL)))
	blocked = PackedByteArray()
	blocked.resize(size.x * size.y)
	blocked.fill(0)
	for body: Node in root.find_children("*", "CollisionObject3D", true, false):
		if body is CharacterBody3D or body is RigidBody3D or skip.has(body) or body.has_meta("look_only"):
			continue
		var co := body as CollisionObject3D
		if co.collision_layer == 0:
			continue
		for owner_id in co.get_shape_owners():
			if co.is_shape_owner_disabled(owner_id):
				continue
			var xf := co.global_transform * co.shape_owner_get_transform(owner_id)
			for i in co.shape_owner_get_shape_count(owner_id):
				var shape := co.shape_owner_get_shape(owner_id, i)
				if shape is WorldBoundaryShape3D:
					continue
				_block_box(xf * _shape_box(shape))
	_grids.clear()
	_compute_clearance()


## Marks the cells under a world-space box that reaches into the band over the floor.
func block_box(box: AABB) -> void:
	_block_box(box)
	_grids.clear()
	_compute_clearance()


## A route for a trolley of `radius` metres from `from` to `to` (floor points, yard space):
## the way-points after `from`, ending at `to` or the nearest place it can reach. Empty
## when there is no way at all. `avoid` is [[point, radius], ...] of things to go round
## this time (other trolleys in the way).
func route(from: Vector3, to: Vector3, radius: float, avoid: Array = []) -> PackedVector3Array:
	var grid := _grid(radius)
	var a := _free_near(_cell(from), grid)
	var b := _free_near(_cell(to), grid)
	if a.x < 0 or b.x < 0:
		return PackedVector3Array()
	var closed: Array[Vector2i] = []
	for o: Array in avoid:
		var p: Vector3 = o[0]
		var r := float(o[1]) + radius
		var c := _cell(p)
		var n := int(ceilf(r / CELL))
		for dz in range(-n, n + 1):
			for dx in range(-n, n + 1):
				var q := c + Vector2i(dx, dz)
				if _inside(q) and q != a and Vector2(dx, dz).length() * CELL <= r and not grid.is_point_solid(q):
					grid.set_point_solid(q, true)
					closed.append(q)
	var cells: Array[Vector2i] = grid.get_id_path(a, b) if not grid.is_point_solid(b) else ([] as Array[Vector2i])
	# Pull the line straight: from each kept point, jump to the furthest one in clear view
	# (of the walls and of whatever it is going round).
	var kept: Array[Vector2i] = []
	if not cells.is_empty():
		kept.append(cells[0])
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _clear_line(cells[i], cells[j], radius, grid):
			j -= 1
		kept.append(cells[j])
		i = j
	for q in closed:
		grid.set_point_solid(q, false)
	if cells.is_empty():
		return PackedVector3Array()
	var out := PackedVector3Array()
	for k in range(1, kept.size()):
		out.append(_point(kept[k]))
	if b == _cell(to) and not out.is_empty():
		out[out.size() - 1] = Vector3(to.x, 0.0, to.z)
	return out


## Can a trolley of `radius` stand here?
func is_free(at: Vector3, radius: float) -> bool:
	var c := _cell(at)
	return _inside(c) and clearance[c.y * size.x + c.x] >= radius


func _grid(radius: float) -> AStarGrid2D:
	var key := int(roundf(radius * 100.0))
	if _grids.has(key):
		return _grids[key]
	var g := AStarGrid2D.new()
	g.region = Rect2i(Vector2i.ZERO, size)
	g.cell_size = Vector2(CELL, CELL)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	g.update()
	for z in size.y:
		for x in size.x:
			if clearance[z * size.x + x] < radius:
				g.set_point_solid(Vector2i(x, z), true)
	_grids[key] = g
	return g


func _block_box(box: AABB) -> void:
	if box.end.y < BAND_LOW or box.position.y > BAND_HIGH:
		return
	var c0 := _cell(box.position)
	var c1 := _cell(box.end)
	for z in range(maxi(c0.y, 0), mini(c1.y, size.y - 1) + 1):
		for x in range(maxi(c0.x, 0), mini(c1.x, size.x - 1) + 1):
			blocked[z * size.x + x] = 1


## Clearance by two passes of a chamfer distance (1 across, 1.41 diagonally), in metres
## to the edge of the nearest blocked cell; the planned area's edge counts as blocked.
func _compute_clearance() -> void:
	var n := size.x * size.y
	clearance = PackedFloat32Array()
	clearance.resize(n)
	var big := 1.0e6
	for k in n:
		clearance[k] = 0.0 if blocked[k] else big
	for z in size.y:
		for x in size.x:
			var k := z * size.x + x
			if x == 0 or z == 0 or x == size.x - 1 or z == size.y - 1:
				clearance[k] = minf(clearance[k], 0.5)
	var d := 1.0
	var dd := 1.4142
	for z in size.y:
		for x in size.x:
			var k := z * size.x + x
			var v := clearance[k]
			if x > 0:
				v = minf(v, clearance[k - 1] + d)
			if z > 0:
				v = minf(v, clearance[k - size.x] + d)
				if x > 0:
					v = minf(v, clearance[k - size.x - 1] + dd)
				if x < size.x - 1:
					v = minf(v, clearance[k - size.x + 1] + dd)
			clearance[k] = v
	for z in range(size.y - 1, -1, -1):
		for x in range(size.x - 1, -1, -1):
			var k := z * size.x + x
			var v := clearance[k]
			if x < size.x - 1:
				v = minf(v, clearance[k + 1] + d)
			if z < size.y - 1:
				v = minf(v, clearance[k + size.x] + d)
				if x < size.x - 1:
					v = minf(v, clearance[k + size.x + 1] + dd)
				if x > 0:
					v = minf(v, clearance[k + size.x - 1] + dd)
			clearance[k] = v
	# Cells to metres; a free cell next to a blocked one is half a cell from its edge.
	for k in n:
		clearance[k] = maxf(clearance[k] - 0.5, 0.0) * CELL if not blocked[k] else 0.0


func _clear_line(a: Vector2i, b: Vector2i, radius: float, grid: AStarGrid2D) -> bool:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y)) * 2
	for s in steps + 1:
		var t := float(s) / maxf(steps, 1)
		var p := Vector2(a).lerp(Vector2(b), t)
		var c := Vector2i(roundi(p.x), roundi(p.y))
		if clearance[c.y * size.x + c.x] < radius or (c != a and grid.is_point_solid(c)):
			return false
	return true


func _free_near(c: Vector2i, grid: AStarGrid2D) -> Vector2i:
	for r in 48:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var p := c + Vector2i(dx, dz)
				if _inside(p) and not grid.is_point_solid(p):
					return p
	return Vector2i(-1, -1)


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - AREA.position.x) / CELL), floori((p.z - AREA.position.y) / CELL))


func _point(c: Vector2i) -> Vector3:
	return Vector3(AREA.position.x + (c.x + 0.5) * CELL, 0.0, AREA.position.y + (c.y + 0.5) * CELL)


static func _shape_box(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s := (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if shape is CylinderShape3D or shape is CapsuleShape3D:
		var r: float = shape.get("radius")
		var h: float = shape.get("height")
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB()
		var box := AABB(pts[0], Vector3.ZERO)
		for p in pts:
			box = box.expand(p)
		return box
	if shape is ConcavePolygonShape3D:
		var f := (shape as ConcavePolygonShape3D).get_faces()
		if f.is_empty():
			return AABB()
		var box := AABB(f[0], Vector3.ZERO)
		for p in f:
			box = box.expand(p)
		return box
	var mesh := shape.get_debug_mesh()
	return mesh.get_aabb() if mesh else AABB()
