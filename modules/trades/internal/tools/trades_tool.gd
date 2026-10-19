class_name TradesTool
extends Node3D
## A hand tool on the bay's hotbar, built in code the way Void Salvage builds its tools
## (SalvageTool): boxes and cylinders in plain metals, the body in BSX orange, and a small
## lit screen when it has something to say. A station puts it on the work while it is in
## use; otherwise the bay carries it in the right hand.

## Where the hand closes on it, in its own space.
var grip := Vector3.ZERO
## How it sits in a relaxed right hand: its own space as seen from the palm (fingers along
## -Z, back of the hand +Y).
var hold := Transform3D()

var _readout: Label3D
var _screen: Node3D


## Its transform when carried in a hand whose palm is at `palm`.
func carried(palm: Transform3D) -> Transform3D:
	return palm * hold * Transform3D(Basis(), -grip)


## Text for its screen (override; "" = no screen).
func readout_text() -> String:
	return ""


func _process(_delta: float) -> void:
	if _readout == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam and _screen.is_inside_tree():
		var to_eye := cam.global_position - _screen.global_position
		if to_eye.length() > 0.01:
			_screen.global_basis = Basis.looking_at(-to_eye, Vector3.UP)
	_readout.text = readout_text()


## A screen at `at` (tool space), turned to the eye each frame.
func add_screen(at: Vector3, size: Vector2, color := Color(0.6, 1.0, 0.5)) -> void:
	_screen = Node3D.new()
	_screen.position = at
	add_child(_screen)
	_readout = TradesLook.readout(_screen, Vector3.ZERO, size, color)


func box(size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO, parent: Node = self) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


## A cylinder along its own Y (rot X 90 degrees lays it along Z).
func cylinder(radius: float, length: float, at: Vector3, rot: Vector3, mat: Material, radial := 16,
		parent: Node = self, top_radius := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = radial
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	parent.add_child(m)
	return m


static func steel() -> StandardMaterial3D:
	return TradesLook.metal(Color(0.72, 0.73, 0.75), 0.95, 0.25)


static func dark() -> StandardMaterial3D:
	return TradesLook.metal(Color(0.13, 0.13, 0.15), 0.4, 0.6)


static func body() -> StandardMaterial3D:
	return TradesLook.metal(TradesLook.TRIM, 0.3, 0.55)
