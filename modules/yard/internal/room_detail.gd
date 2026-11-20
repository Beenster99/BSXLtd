extends RefCounted
## The station's rooms dressed to Void Salvage's standard (beenster, 20 Nov: "a more detailed
## 3D model pass on the rooms in our station"; flag yard.room_detail). Built over the plain
## shell from what the kit recorded (its walls with their door and window gaps, its lamps):
##   - walls lined with panels: seams, a fastener at each corner, a frame rib every third
##     panel, a vent grille near the top of some bays, a kick plate along the floor and a
##     cornice under the ceiling;
##   - door and window openings cased in a steel frame;
##   - ceilings hung on beams across the room (kept clear of the lamps), panelled between;
##   - floors laid as plates with seams.
## The stores hall gets the same on a bigger scale (2.4 m panels, columns every 7.2 m) and no
## ceiling of its own (its trusses are StoresShell's).
## The corridor keeps its own skirting and cove light; the design room's screen walls get
## seams only (nothing may stand out through the screens). The refurb annex is the refurb
## module's. Presentation only: no collision, a few merged meshes.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const DetailMesh := preload("res://modules/yard/internal/detail_mesh.gd")

## The rooms this pass dresses.
const ROOMS := ["corridor", "contracts", "crew", "quarters", "airlock", "design", "design_lock", "racking"]
## The stores hall's walls are 32 m high and 60 to 70 m long: bigger panels, rows and ribs.
const HALL_PITCH := 2.4
const HALL_RIB := Vector2(0.4, 0.12)
## Panel width and the rib every RIB_EVERY panels (m).
const PITCH := 1.2
const RIB_EVERY := 3
## How far each layer stands off its surface (m).
const SEAM_OUT := 0.006
const RIB_OUT := 0.064
const CASE_OUT := 0.05
## Everything under a ceiling stops this far below its top (the ceiling's face is 0.02 down).
const UNDER := 0.022

var dm := DetailMesh.new()
var _seam: Material
var _bolt: Material
var _rib: Material
var _dark: Material
var _grille: Material
var _beam: Material
var _floor_seam: Material
var _ceiling_seam: Material
var _lamps: Array[Dictionary] = []
var _pitch := PITCH
var _rib_size := Vector2(0.22, RIB_OUT)


## Dresses every room of ROOMS from what `kit` built; the meshes go under `parent`.
func build(kit, parent: Node3D) -> Node3D:
	var k = kit
	_seam = k.paint(Color(0.47, 0.49, 0.53), 0.2, 0.6, "satin_paint")
	_bolt = k.paint(Color(0.62, 0.64, 0.67), 0.8, 0.35, "brushed_steel")
	_rib = k.paint(Color(0.6, 0.62, 0.66), 0.4, 0.45, "satin_paint")
	_dark = k.paint(Kit.DARK, 0.7, 0.45, "gunmetal")
	_grille = k.paint(Color(0.3, 0.32, 0.35), 0.6, 0.5, "gunmetal")
	_beam = k.paint(Color(0.74, 0.76, 0.79), 0.3, 0.5, "satin_paint")
	_floor_seam = k.paint(Color(0.3, 0.31, 0.33), 0.5, 0.6, "gunmetal")
	_ceiling_seam = k.paint(Color(0.66, 0.68, 0.71), 0.05, 0.7, "satin_paint")
	_lamps = k.lamps
	for w: Dictionary in k.walls:
		for side: float in [-1.0, 1.0]:
			_wall_face(w, side)
	for id: String in ROOMS:
		_floor(id)
		if id != "design" and id != "racking":   # the vault; the hall's trusses
			_ceiling(id)
	var node := Node3D.new()
	node.name = "RoomDetail"
	parent.add_child(node)
	dm.commit(node, "Detail")
	return node


## The room on side `side` of wall `w` at `along` (m along it), or "".
static func room_beside(w: Dictionary, side: float, along: float, y := 1.0) -> String:
	var off := float(w.thick) * 0.5 + 0.25
	var p := Vector3(along, y, float(w.at) + side * off) if w.along_x else Vector3(float(w.at) + side * off, y, along)
	var id := YardLayout.room_at(p)
	return id if ROOMS.has(id) else ""


## A point on the face of wall `w` on `side`, `out` m off it, at `along` and height `y`.
static func face_point(w: Dictionary, side: float, along: float, y: float, out: float) -> Vector3:
	var d := float(w.thick) * 0.5 + out
	return Vector3(along, y, float(w.at) + side * d) if w.along_x else Vector3(float(w.at) + side * d, y, along)


## A box on the face: `width` along the wall, `height` up, `depth` out from it, its back on the face
## `lift` m off it.
## Its back is sunk `sink` m into what it stands on: each kind of fitting a little deeper than
## the last, so two that cross never share a plane (the z-fight check, test_zfight.gd).
func _on_face(w: Dictionary, side: float, mat: Material, along: float, y: float, width: float, height: float, depth: float, lift := 0.0, sink := 0.0) -> void:
	var c := face_point(w, side, along, y, lift + (depth - sink) * 0.5)
	var size := Vector3(width, height, depth + sink) if w.along_x else Vector3(depth + sink, height, width)
	dm.box(mat, size, c)


func _wall_face(w: Dictionary, side: float) -> void:
	var from := float(w.from)
	var to := float(w.to)
	# The room this face looks into, sampled along it (a wall can border several).
	var rooms := {}
	var a := from + 0.3
	while a < to:
		var r := room_beside(w, side, a)
		if r != "":
			rooms[r] = true
		a += 1.2
	if rooms.is_empty():
		return
	var gaps: Array = (w.gaps as Array).duplicate()
	gaps.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var y0 := float(w.y0)
	# The face's top: the lowest ceiling of the rooms it looks into.
	var top := y0 + float(w.height)
	for r: String in rooms:
		top = minf(top, (YardLayout.ROOMS[r].box as AABB).end.y)
	var corridor := rooms.has("corridor")
	var screens := rooms.has("design")
	var hall := rooms.has("racking")
	_pitch = HALL_PITCH if hall else PITCH
	_rib_size = HALL_RIB if hall else Vector2(0.22, RIB_OUT)
	# Horizontal seams: a dado at 1.2 m and one under the cornice (more on a tall wall).
	# (Walls along z sit 3 mm off the walls along x, so where two meet in a corner their
	# seams, plates and cornices don't share a plane.)
	var lift := 0.0 if w.along_x else 0.003
	var rows: Array[float] = []
	var hy := (1.25 if hall else 1.213) + lift   # (the hall's rows clear its deck's underside)
	while hy < top - 0.5:
		rows.append(hy)
		hy += _pitch
	rows.append(top - 0.317 + lift)
	# Stretch by stretch between the openings.
	var solid: Array = []   # [a, b]
	var pos := from
	for g: Array in gaps:
		if float(g[0]) > pos:
			solid.append([pos, float(g[0])])
		pos = float(g[1])
	if pos < to:
		solid.append([pos, to])
	var n := 0
	for s: Array in solid:
		var sa: float = s[0]
		var sb: float = s[1]
		if room_beside(w, side, (sa + sb) * 0.5) == "":
			continue
		for yr: float in rows:
			_on_face(w, side, _seam, (sa + sb) * 0.5, yr, sb - sa, 0.025, SEAM_OUT - 0.0015, 0.0, 0.0006)
		var x := sa + _pitch
		while x < sb - 0.3:
			n += 1
			if room_beside(w, side, x) != "":
				_seam_at(w, side, x, y0, top, rows, n % RIB_EVERY == 0 and not screens and x > sa + 0.5 and x < sb - 0.5, corridor, sb)
			x += _pitch
		if not corridor:
			# A kick plate along the floor, a cornice under the ceiling.
			_on_face(w, side, _dark, (sa + sb) * 0.5, y0 + 0.071 + lift, sb - sa, 0.14, 0.014, 0.0, 0.0024)
			if not screens:
				_on_face(w, side, _rib, (sa + sb) * 0.5, top - UNDER - 0.05 - lift, sb - sa, 0.1, 0.05, 0.0, 0.003)
	# Each opening cased in a steel frame (the corridor's doors have their own).
	if not corridor:
		for g: Array in gaps:
			var gm := (float(g[0]) + float(g[1])) * 0.5
			var other := YardLayout.room_at(face_point(w, -side, gm, 1.0, 0.25))
			var here := room_beside(w, side, gm)
			if here == "" or here in ["airlock", "design_lock"] or other in ["corridor", "airlock", "design_lock"]:
				continue   # (corridor doors have their own frames, the locks their sliding doors)
			_case(w, side, float(g[0]), float(g[1]), y0 + float(g[2]), y0 + (float(g[3]) if g.size() > 3 else 0.0))


## One vertical seam at `x` with its fasteners; a frame rib (and maybe a vent beside it) where
## `rib`, within the solid stretch that ends at `stretch_end`.
func _seam_at(w: Dictionary, side: float, x: float, y0: float, top: float, rows: Array[float], rib: bool, corridor: bool, stretch_end: float) -> void:
	var low := y0 + (1.15 if corridor else 0.14)
	_on_face(w, side, _seam, x, (low + top - 0.1) * 0.5, 0.025, top - 0.1 - low, SEAM_OUT + 0.0015, 0.0, 0.0012)
	for yr: float in rows:
		if corridor and yr < 1.2:
			continue
		for dx: float in [-0.07, 0.07]:
			for dy: float in [-0.07, 0.07]:
				_on_face(w, side, _bolt, x + dx, yr + dy, 0.032, 0.032, 0.012, SEAM_OUT)
	if not rib:
		return
	# The rib: a flat pilaster up the wall with a bolted strap at each row.
	_on_face(w, side, _rib, x, (y0 + top - UNDER - 0.004) * 0.5, _rib_size.x, top - UNDER - 0.004 - y0, _rib_size.y, 0.0, 0.0018)
	var straps: Array[float] = rows.duplicate()
	straps.append(y0 + 0.4)
	for yr: float in straps:
		_on_face(w, side, _dark, x, yr, _rib_size.x + 0.04, 0.06, 0.02, _rib_size.y)
		for dx: float in [-0.08, 0.08]:
			_on_face(w, side, _bolt, x + dx * _rib_size.x / 0.22, yr, 0.03, 0.03, 0.014, _rib_size.y + 0.02)
	# A vent grille in the bay after every other rib, under the cornice.
	if int(roundf(x / _pitch)) % (RIB_EVERY * 2) == 0:
		var vx := x + _pitch * 1.5
		if room_beside(w, side, vx) == "" or vx > stretch_end - 0.45:
			return
		var vy := top - 0.65
		_on_face(w, side, _dark, vx, vy, 0.62, 0.36, 0.03, SEAM_OUT, 0.0036)
		for i in 5:
			_on_face(w, side, _grille, vx, vy - 0.13 + i * 0.065, 0.54, 0.02, 0.02, SEAM_OUT + 0.03)


## A steel frame round an opening from `a` to `b` along the wall, open from `sill` up to `head`.
func _case(w: Dictionary, side: float, a: float, b: float, head: float, sill: float) -> void:
	var t := 0.08
	for at: float in [a - t * 0.5, b + t * 0.5]:
		_on_face(w, side, _rib, at, (sill + head) * 0.5, t, head - sill + (t if sill > 0.0 else 0.0), CASE_OUT)
	_on_face(w, side, _rib, (a + b) * 0.5, head + t * 0.5, b - a + t * 2.0, t, CASE_OUT - 0.0007, 0.0007)
	if sill > 0.0:
		_on_face(w, side, _rib, (a + b) * 0.5, sill - t * 0.5, b - a + t * 2.0, t, CASE_OUT + 0.03 - 0.0007, 0.0007)


## Beams across the room's short way, clear of its lamps, and ceiling panel seams between.
func _ceiling(id: String) -> void:
	var b: AABB = YardLayout.ROOMS[id].box
	var y := b.end.y
	var along_x := b.size.x >= b.size.z   # beams run across the long axis
	var length := b.size.x if along_x else b.size.z
	var span := b.size.z if along_x else b.size.x
	var start := b.position.x if along_x else b.position.z
	var mid := b.get_center()
	var at := PITCH * RIB_EVERY
	while at < length - 0.5:
		var p := start + at
		var size := Vector3(0.2, 0.16, span - 0.004) if along_x else Vector3(span - 0.004, 0.16, 0.2)
		var c := Vector3(p, y - UNDER - 0.08, mid.z) if along_x else Vector3(mid.x, y - UNDER - 0.08, p)
		if not _hits_lamp(c, size):
			dm.box(_beam, size, c)
		at += PITCH * RIB_EVERY
	# Panel seams on the ceiling, both ways.
	var x := b.position.x + PITCH
	while x < b.end.x - 0.1:
		dm.box(_ceiling_seam, Vector3(0.012, 0.009, b.size.z - 0.006), Vector3(x, y - 0.0215, mid.z))
		x += PITCH
	var z := b.position.z + PITCH
	while z < b.end.z - 0.1:
		dm.box(_ceiling_seam, Vector3(b.size.x - 0.006, 0.012, 0.012), Vector3(mid.x, y - 0.023, z))
		z += PITCH


func _hits_lamp(c: Vector3, size: Vector3) -> bool:
	var box := AABB(c - size * 0.5, size).grow(0.12)
	for l: Dictionary in _lamps:
		var at: Vector3 = l.at
		var panel: Vector2 = l.panel
		var lb := AABB(at - Vector3(panel.x * 0.5 + 0.06, 0.2, panel.y * 0.5 + 0.06), Vector3(panel.x + 0.12, 0.25, panel.y + 0.12))
		if lb.intersects(box):
			return true
	return false


## The floor laid as plates: seams both ways every PITCH * 2.
func _floor(id: String) -> void:
	var b: AABB = YardLayout.ROOMS[id].box
	var mid := b.get_center()
	var step := PITCH * (4.0 if id == "racking" else 2.0)
	var x := b.position.x + step
	while x < b.end.x - 0.2:
		dm.box(_floor_seam, Vector3(0.012, 0.0102, b.size.z - 0.006), Vector3(x, 0.0021, mid.z))
		x += step
	var z := b.position.z + step
	while z < b.end.z - 0.2:
		dm.box(_floor_seam, Vector3(b.size.x - 0.006, 0.0112, 0.012), Vector3(mid.x, 0.0026, z))
		z += step
