class_name TradesWeldingHelmet
extends Node3D
## A welder's flip-down shield (beenster, 0.3.7): it rides tipped up over the forehead and
## flicks down over the face while the arc is lit, welding or unwelding. Worn by you (BenchWorker)
## and drawn on other players' avatars when they weld. Presentation only.
##
## Its own space: the head's centre at the origin, the face toward -Z.

## How far down it is (0 tipped up, 1 over the face).
var down := 0.0:
	set(value):
		down = clampf(value, 0.0, 1.0)
		if _pivot:
			_pivot.rotation.x = deg_to_rad(UP_DEG) * (1.0 - down)

## How far it tips up off the face, degrees.
const UP_DEG := 105.0

var _pivot: Node3D


func _ready() -> void:
	name = "WeldingHelmet"
	var shell := TradesLook.metal(Color(0.1, 0.11, 0.1), 0.15, 0.55)
	var trim := TradesLook.metal(TradesLook.TRIM, 0.3, 0.5)
	var lens := TradesLook.metal(Color(0.05, 0.16, 0.08), 1.0, 0.04)
	var steel := TradesLook.metal(Color(0.6, 0.6, 0.62), 0.9, 0.35)
	# The headband's pivot knobs either side of the head.
	for side: float in [-1.0, 1.0]:
		var knob := _part(CylinderMesh.new(), Vector3(side * 0.178, 0.04, 0.0), steel, self)
		(knob.mesh as CylinderMesh).top_radius = 0.028
		(knob.mesh as CylinderMesh).bottom_radius = 0.028
		(knob.mesh as CylinderMesh).height = 0.02
		knob.rotation.z = PI * 0.5
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0.04, 0)
	add_child(_pivot)
	# The shield: face plate, cheeks, brow and chin, an orange stripe over the top, the lens.
	_box(Vector3(0.32, 0.3, 0.018), Vector3(0, -0.05, -0.215), shell)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.018, 0.27, 0.2), Vector3(side * 0.16, -0.05, -0.12), shell)
	_box(Vector3(0.32, 0.018, 0.17), Vector3(0, 0.1, -0.135), shell)
	_box(Vector3(0.32, 0.018, 0.17), Vector3(0, -0.2, -0.135), shell)
	_box(Vector3(0.05, 0.022, 0.17), Vector3(0, 0.104, -0.135), trim)
	_box(Vector3(0.15, 0.06, 0.008), Vector3(0, -0.01, -0.226), lens)
	_box(Vector3(0.17, 0.08, 0.006), Vector3(0, -0.01, -0.222), TradesLook.metal(Color(0.2, 0.2, 0.2), 0.5, 0.5))
	down = down


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = size
	_part(m, at, mat, _pivot)


func _part(mesh: Mesh, at: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
