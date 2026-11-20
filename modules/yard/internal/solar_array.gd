extends RefCounted
## Solar arrays (0.4.1 playtest: "more solar panels, which look like solar"): Void Salvage's own
## solar panel (VsParts "SolarPanel": its cells, busbars, frame and the solar glass) laid out in
## rows on a frame, drawn as one MultiMesh per layer of the part, so a few hundred panels cost a
## handful of draw calls. Presentation only.

const Look := preload("res://modules/yard/internal/yard_stock_look.gd")
const PANEL := "SolarPanel"


## Half an array's width across its `cols` (m, from its middle to the outer panel's edge), with
## `gap` between panels as in build().
static func half_width(cols: int, gap := 0.12) -> float:
	var size := VsParts.size(PANEL)
	return (cols - 1) * 0.5 * (size.x + gap) + size.x * 0.5


## Lays `cols` x `rows` panels under `parent`: the array's middle at `at`, turned by `basis`
## (its panels flat in its x-z plane, cells up +Y), the panels' long side along z, `gap` (m)
## between them. Returns the array's node.
static func build(parent: Node3D, node_name: String, at: Vector3, basis: Basis, cols: int, rows: int,
		gap := 0.12) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.transform = Transform3D(basis, at)
	parent.add_child(root)
	var size := VsParts.size(PANEL)
	var pitch := Vector2(size.x + gap, size.z + gap)
	var xforms: Array[Transform3D] = []
	for c in cols:
		for r in rows:
			var x := (float(c) - (cols - 1) * 0.5) * pitch.x
			var z := (float(r) - (rows - 1) * 0.5) * pitch.y
			xforms.append(Transform3D(Basis(), Vector3(x, 0, z)))
	var layers: Array = Look.layers(PANEL)
	for j in layers.size():
		var l: Dictionary = layers[j]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = l.mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Panels" if j == 0 else "Panels_%d" % j
		mmi.multimesh = mm
		mmi.material_override = l.material
		root.add_child(mmi)
	# The frame under them: a rail along each row's ends and a spine down the middle.
	var w := cols * pitch.x
	var d := rows * pitch.y
	var dark := _frame_material()
	for z: float in [-d * 0.5, d * 0.5]:
		_bar(root, Vector3(w, 0.08, 0.1), Vector3(0, -0.06, z), dark)
	_bar(root, Vector3(0.14, 0.14, d), Vector3(0, -0.12, 0), dark)
	for c in range(0, cols + 1, 2):
		_bar(root, Vector3(0.06, 0.06, d), Vector3((float(c) - cols * 0.5) * pitch.x, -0.07, 0), dark)
	root.set_meta("panels", xforms.size())
	return root


static var _frame: Material


static func _frame_material() -> Material:
	if _frame == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.22, 0.23, 0.25)
		m.metallic = 0.7
		m.roughness = 0.45
		_frame = m
	return _frame


static func _bar(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
