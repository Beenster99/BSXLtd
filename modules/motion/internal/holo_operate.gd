extends Node3D
## OPERATE on the holotable: each moving part of the open design plays its move in a loop
## (MotionBus.phase_of), its swept volume glowing round it, cyan where it moves clear and red
## where it hits something (the same clashes as WILL IT WORK). SET HER DOWN puts her legs
## down, a pad under her, her centre of mass and the line round her feet. Built under the
## holotable's "Ship" node (design space, metres), so the table's turn, zoom, cut and section
## apply; rebuilt with the hologram on every edit.

const CLEAR := Color(0.35, 1.0, 0.85)
const CLASH := Color(1.0, 0.25, 0.2)
const PIECE := Color(1.0, 0.82, 0.35)
const PAD := Color(0.6, 0.75, 0.9)

var bus: MotionBus
var table: Node3D
## mover id -> {mv, pieces: [MeshInstance3D], sweep: Node3D}
var parts: Dictionary = {}
var ground_node: Node3D
## How far SET HER DOWN lifts the hologram so her feet stand on the table, m (design space).
var stand_height := 0.0


func setup(motion_bus: MotionBus, holo_table: Node3D) -> void:
	bus = motion_bus
	table = holo_table
	var r := bus.report()
	if r.is_empty():
		return
	for mv: Dictionary in r.movers:
		_add_mover(mv, r.clashes.has(mv.id))
	_add_ground(r.ground)
	bus.operate_changed.connect(_show)
	_show()


func _exit_tree() -> void:
	if bus and bus.operate_changed.is_connected(_show):
		bus.operate_changed.disconnect(_show)


func _mat(col: Color, alpha: float, rim := 1.0) -> Material:
	if table and table.has_method("holo_mat"):
		return table.call("holo_mat", col, alpha, rim)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _box(parent: Node3D, xf: Transform3D, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _add_mover(mv: Dictionary, clash: bool) -> void:
	var holder := Node3D.new()
	holder.name = "Mover_" + str(mv.id).replace(":", "_")
	add_child(holder)
	var piece_mat := _mat(CLASH if clash else PIECE, 0.55, 1.4)
	var pieces: Array[MeshInstance3D] = []
	for p: Dictionary in MotionMovers.pieces(mv, 0.0):
		var mi := _box(holder, p.xf, p.size, piece_mat)
		mi.name = str(p.name)
		pieces.append(mi)
	# The swept volume: every other step of the move, faint.
	var sweep := Node3D.new()
	sweep.name = "Sweep"
	holder.add_child(sweep)
	var sweep_mat := _mat(CLASH if clash else CLEAR, 0.07 if not clash else 0.12, 0.8)
	var steps := MotionMovers.SWEEP_STEPS
	for i in range(0, steps + 1, 2):
		for p: Dictionary in MotionMovers.pieces(mv, float(i) / steps):
			_box(sweep, p.xf, p.size, sweep_mat)
	parts[mv.id] = {"mv": mv, "pieces": pieces, "sweep": sweep, "clash": clash}


func _add_ground(g: Dictionary) -> void:
	ground_node = Node3D.new()
	ground_node.name = "Ground"
	add_child(ground_node)
	if g.get("cases", []).is_empty():
		return
	var c := _case(g)
	var h := float(c.height)
	stand_height = h
	# The pad, under her at the height she stands at.
	var feet: Array = g.feet
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for f: Dictionary in feet:
		lo = lo.min(Vector2(f.at.x, f.at.z))
		hi = hi.max(Vector2(f.at.x, f.at.z))
	var mid := (lo + hi) * 0.5
	var span := (hi - lo) + Vector2(6, 6)
	_box(ground_node, Transform3D(Basis.IDENTITY, Vector3(mid.x, -h - 0.03, mid.y)), Vector3(span.x, 0.04, span.y), _mat(PAD, 0.18, 0.6))
	# Her centre of mass, a plumb line to the pad, and the line round her feet.
	var ok := float(c.tip_deg) >= MotionGround.MIN_TIP
	var col := CLEAR if ok else (CLASH if float(c.tip_deg) < 0.0 else Color(1.0, 0.8, 0.3))
	var cog: Vector3 = c.cog
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	ball.mesh = sm
	ball.material_override = _mat(col, 0.8, 1.6)
	ball.position = cog
	ball.name = "CentreOfMass"
	ground_node.add_child(ball)
	_box(ground_node, Transform3D(Basis.IDENTITY, Vector3(cog.x, (cog.y - h) * 0.5, cog.z)), Vector3(0.05, cog.y + h, 0.05), _mat(col, 0.6))
	var pts := PackedVector2Array()
	for f: Dictionary in feet:
		pts.append(Vector2(f.at.x, f.at.z))
	var hull := Geometry2D.convex_hull(pts)
	for i in hull.size() - 1:
		var a := hull[i]
		var b := hull[i + 1]
		var m := (a + b) * 0.5
		var len := a.distance_to(b)
		var xf := Transform3D(Basis(Vector3.UP, atan2(-(b - a).y, (b - a).x)), Vector3(m.x, -h + 0.02, m.y))
		_box(ground_node, xf, Vector3(len, 0.04, 0.08), _mat(col, 0.9, 1.4))
	# Each foot, coloured by its load against its rating.
	for i in feet.size():
		var f: Dictionary = feet[i]
		var kg := float(c.loads[i])
		var share := kg / maxf(float(f.rated), 1.0)
		var fc := CLASH if share > 1.0 or kg < 0.0 else (Color(1.0, 0.8, 0.3) if share > 0.85 else CLEAR)
		_box(ground_node, Transform3D(Basis.IDENTITY, Vector3(f.at.x, -h + 0.08, f.at.z)), Vector3(0.9, 0.12, 0.9), _mat(fc, 0.9, 1.5))


## The case on show: the bus's pad and hold.
func _case(g: Dictionary) -> Dictionary:
	for c: Dictionary in g.cases:
		if c.pad == bus.pad and c.load == ("full" if bus.full_hold else "empty"):
			return c
	return g.cases[0]


func _show() -> void:
	for id: String in parts:
		var p: Dictionary = parts[id]
		var leg := str(p.mv.spec.kind) == "leg"
		(p.sweep as Node3D).visible = bus.operating
		for mi: MeshInstance3D in p.pieces:
			mi.visible = bus.operating or (leg and bus.grounded)
	if ground_node:
		ground_node.visible = bus.grounded
	# Standing on her legs, she stands on the table, not through it.
	var ship := get_parent() as Node3D
	if ship:
		ship.position.y = stand_height if bus.grounded else 0.0


func _process(_delta: float) -> void:
	if bus == null or not (bus.operating or bus.grounded):
		return
	var now := Time.get_ticks_msec()
	for id: String in parts:
		var p: Dictionary = parts[id]
		var t := bus.phase_of(p.mv, now)
		var ps := MotionMovers.pieces(p.mv, t)
		var meshes: Array[MeshInstance3D] = p.pieces
		for i in mini(ps.size(), meshes.size()):
			meshes[i].transform = ps[i].xf
			var bm := meshes[i].mesh as BoxMesh
			if not bm.size.is_equal_approx(ps[i].size):
				bm.size = ps[i].size
