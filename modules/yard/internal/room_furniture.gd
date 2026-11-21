extends RefCounted
## The crew room and the contracts desk furnished to Void Salvage's standard (beenster, 20 Nov:
## "bring them up to Void Salvage standards"; flag yard.room_detail): Void Salvage's own mess
## tables, stools, corner sofa, lockers, galley, media wall, planter, seats and cabinets
## (VsParts, as the quarters already use), and a reception desk drawn in detail. Lived-in's mugs,
## jackets, plants and steam still land where they did. Built once into the station's kit.

const Kit := preload("res://modules/yard/internal/yard_kit.gd")
const DetailMesh := preload("res://modules/yard/internal/detail_mesh.gd")

## How high the mess tables' tops stand (m): the mugs go on them.
const TABLE_TOP := 0.81

var _kit
var _root: Node3D
var dm := DetailMesh.new()
var placed: Array[Node3D] = []


func build(kit, root: Node3D) -> void:
	_kit = kit
	_root = root
	_crew()
	_contracts()
	var node := Node3D.new()
	node.name = "RoomFurniture"
	root.add_child(node)
	dm.commit(node, "Detail")


## The crew room (x 0..20, z 0..12): the corridor door at x 9..11, the quarters' at z 5.2..6.8
## in the east wall, the window onto the dock along z 12.
func _crew() -> void:
	var k = _kit
	# Two rows of two mess tables end to end, stools down both sides.
	for z: float in [3.5, 7.0]:
		for x: float in [5.05, 6.95]:
			_vs("MessTable", Vector3(x, 0.0, z), 0.0)
		for x: float in [4.6, 5.5, 6.5, 7.4]:
			for side: float in [-1.0, 1.0]:
				_vs("Stool", Vector3(x, 0.0, z + side * 0.72), 0.0)
	# The galley along the corridor wall; the coffee machine on its own counter beside it.
	_vs("GalleyCounter", Vector3(1.65, 0.0, 0.45), 0.0)
	var bench: Material = k.paint(Color(0.3, 0.32, 0.36), 0.3, 0.6)
	k.span(Vector3(3.25, 0.0, 0.2), Vector3(4.5, 0.95, 0.85), bench)
	k.box(Vector3(0.45, 0.6, 0.4), Vector3(3.8, 1.25, 0.55), k.paint(Kit.DARK, 0.6, 0.35))
	k.box(Vector3(0.12, 0.05, 0.02), Vector3(3.8, 1.4, 0.76), k.glow(Color(0.3, 1.0, 0.5), 3.0), false)
	# Its sign on the wall behind it (it hung in the air over the machine's front).
	k.sign("COFFEE", Vector3(3.8, 1.85, 0.2), Vector3.BACK, 0.0035, Color.WHITE)
	# The corner sofa facing the window, an armchair beside it.
	_vs("CornerSofa", Vector3(13.0, 0.0, 8.7), 0.0)
	_vs("Armchair", Vector3(16.0, 0.0, 9.6), -PI * 0.3)
	# Six lockers down the east wall, short of the quarters' door.
	for i in 6:
		_vs("Locker", Vector3(19.6, 0.0, 0.62 + i * 0.81), -PI * 0.5)
	# The media wall on the west wall, a planter under the window, the room's switch cabinet.
	_vs("MediaWall", Vector3(0.3, 0.0, 6.5), PI * 0.5)
	_vs("Planter", Vector3(5.0, 0.0, 11.5), PI)
	_vs("SwitchCabinet", Vector3(0.45, 0.0, 11.5), PI * 0.5)
	_vs("JunctionBox", Vector3(8.4, 1.9, 0.22), 0.0)
	k.ceiling_lamp(Vector3(6.0, 3.2, 5.0), Vector2(2.0, 0.6), 0.9, 9.0)
	k.ceiling_lamp(Vector3(14.0, 3.2, 5.0), Vector2(2.0, 0.6), 0.9, 9.0)
	var warm := OmniLight3D.new()
	warm.position = Vector3(13.0, 1.6, 10.5)
	warm.light_color = Color(1.0, 0.75, 0.5)
	warm.light_energy = 0.6
	warm.omni_range = 6.0
	warm.set_meta("gfx_no_shadow", true)   # a glow by the sofa: its shadows cost a whole pass
	_root.add_child(warm)


## The contracts desk (x -12..0, z 0..10): the corridor door at x -7..-5, the window along z 10.
## The desk's use area and the board on the wall stay the station's.
func _contracts() -> void:
	var k = _kit
	_desk(Vector3(-10.0, 0.0, 5.0), Vector3(-4.0, 1.05, 5.8))
	for x: float in [-8.5, -5.5]:
		k.box(Vector3(0.9, 0.55, 0.05), Vector3(x, 1.45, 5.55), k.glow(Color(0.2, 0.55, 0.9), 1.5), false)
		k.box(Vector3(0.06, 0.3, 0.06), Vector3(x, 1.2, 5.6), k.paint(Kit.DARK, 0.7, 0.45, "gunmetal"), false)
		_vs("Seat", Vector3(x, 0.0, 7.0), PI)
	# Visitors' seats facing the desk, a planter and cabinets along the window.
	for x: float in [-8.0, -6.0]:
		_vs("Seat", Vector3(x, 0.0, 3.2), 0.0)
	_vs("Planter", Vector3(-1.4, 0.0, 9.45), PI)
	_vs("SwitchCabinet", Vector3(-0.45, 0.0, 1.0), -PI * 0.5)
	_vs("JunctionBox", Vector3(-3.6, 1.9, 0.22), 0.0)
	k.ceiling_lamp(Vector3(-6.0, 3.2, 3.0), Vector2(2.0, 0.6), 0.9, 8.0)
	k.ceiling_lamp(Vector3(-6.0, 3.2, 7.5), Vector2(2.0, 0.6), 0.9, 8.0)


## A reception desk from corner `a` to `b` (its front faces -z, towards the door): a recessed
## plinth, a front of ribbed panels, end panels, an overhanging worktop with an orange edge.
func _desk(a: Vector3, b: Vector3) -> void:
	var k = _kit
	k.solid(b - a, (a + b) * 0.5)
	var body: Material = k.paint(Color(0.85, 0.86, 0.88), 0.1, 0.5, "satin_paint")
	var dark: Material = k.paint(Kit.DARK, 0.7, 0.45, "gunmetal")
	var top: Material = k.paint(Color(0.3, 0.32, 0.35), 0.2, 0.35, "satin_paint")
	var edge: Material = k.paint(Kit.ORANGE, 0.1, 0.4, "enamel")
	var steel: Material = k.paint(Color(0.62, 0.64, 0.67), 0.8, 0.35, "brushed_steel")
	var mid_x := (a.x + b.x) * 0.5
	var w := b.x - a.x
	var d := b.z - a.z
	# Plinth, set back 6 cm.
	dm.span(dark, Vector3(a.x + 0.06, 0.0, a.z + 0.06), Vector3(b.x - 0.06, 0.1, b.z - 0.06))
	# The carcass and its end panels.
	dm.span(body, Vector3(a.x + 0.04, 0.1, a.z + 0.04), Vector3(b.x - 0.04, b.y - 0.06, b.z - 0.02))
	for x: float in [a.x, b.x - 0.04]:
		dm.span(body, Vector3(x, 0.0, a.z), Vector3(x + 0.04, b.y - 0.06, b.z))
	# The front: panels with grooves between, a steel kick strip.
	var panels := int(roundf(w / 0.6))
	for i in panels:
		var x0 := a.x + 0.04 + (w - 0.08) * i / panels
		var x1 := a.x + 0.04 + (w - 0.08) * (i + 1) / panels
		dm.span(body, Vector3(x0 + 0.008, 0.12, a.z + 0.012), Vector3(x1 - 0.008, b.y - 0.1, a.z + 0.04))
	dm.span(steel, Vector3(a.x + 0.04, 0.1, a.z + 0.03), Vector3(b.x - 0.04, 0.115, a.z + 0.041))
	# The worktop overhanging the front, its orange edge, a cable grommet each screen.
	dm.span(top, Vector3(a.x - 0.03, b.y - 0.06, a.z - 0.06), Vector3(b.x + 0.03, b.y - 0.012, b.z + 0.02))
	dm.span(edge, Vector3(a.x - 0.031, b.y - 0.062, a.z - 0.075), Vector3(b.x + 0.031, b.y, a.z - 0.058))
	dm.span(edge, Vector3(a.x - 0.031, b.y - 0.012, a.z - 0.06), Vector3(b.x + 0.031, b.y, b.z + 0.021))
	for x: float in [mid_x - w * 0.25, mid_x + w * 0.25]:
		dm.box(dark, Vector3(0.08, 0.004, 0.08), Vector3(x, b.y + 0.002, a.z + d * 0.75))


## A Void Salvage part stood on the floor at `at` (its bottom on at.y, its middle over at),
## turned `yaw` about y (its front, +z, turned with it), solid.
func _vs(id: String, at: Vector3, yaw: float) -> Node3D:
	var n := VsParts.instance(id)
	if n == null:
		return null
	var shape := VsParts.shape(id)
	var box := shape.mesh.get_aabb()
	# Void Salvage's parts face -Z (a seat's back, a locker's hinges and a counter's wall side
	# are at +Z), so the half turn makes `yaw` turn their front from +Z as the rooms are laid
	# out (0.5.1 playtest: "some of the furniture is the wrong way around").
	var basis := Basis(Vector3.UP, yaw + PI)
	var offset := basis * Vector3(box.get_center().x, box.position.y, box.get_center().z)
	n.transform = Transform3D(basis, at - offset)
	n.name = "%s_%d" % [id, _root.get_child_count()]
	_root.add_child(n)
	if shape.collision != null:
		var cs := CollisionShape3D.new()
		cs.shape = shape.collision
		cs.transform = n.transform
		_kit.body.add_child(cs)
	placed.append(n)
	return n
