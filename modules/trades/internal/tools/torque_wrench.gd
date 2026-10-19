class_name TradesTorqueWrench
extends Node3D
## Click-type torque wrench, held in the right hand. Built the way Void Salvage builds its
## tools (SalvageTool): boxes and cylinders in plain metals, a body in the company colour
## (BSX orange where the socket is green), and a small lit screen whose monospace text
## faces the wearer's eye. Set to the joint's target; it gives one click when the pull
## reaches it. A powered one comes later.
##
## Its own space: the socket at the origin over the bolt, +Y out of the bolt, the handle
## running back along +Z.

var set_nm := 25.0
## The torque on the bolt right now (Nm), shown on the screen while pulling.
var applied_nm := 0.0
## Where the hand holds it, in its own space.
const GRIP := Vector3(0, 0.03, 0.33)

var _readout: Label3D
var _screen: Node3D
var _flash := 0.0
var _arm: Node3D


func _ready() -> void:
	name = "TorqueWrench"
	_arm = Node3D.new()
	add_child(_arm)
	var steel := TradesLook.metal(Color(0.72, 0.73, 0.75), 0.95, 0.25)
	var dark := TradesLook.metal(Color(0.13, 0.13, 0.15), 0.4, 0.6)
	var body := TradesLook.metal(TradesLook.TRIM, 0.3, 0.55)
	var yellow := TradesLook.metal(Color(0.9, 0.75, 0.1), 0.2, 0.5)
	var along := Vector3(PI * 0.5, 0, 0)
	# Socket and drive on the bolt, the ratchet head with its reversing lever.
	_cyl(0.011, 0.026, Vector3(0, 0.006, 0), Vector3.ZERO, steel, 12)
	_cyl(0.019, 0.024, Vector3(0, 0.03, 0), Vector3.ZERO, steel, 16)
	_box(Vector3(0.006, 0.006, 0.018), Vector3(0, 0.045, -0.006), dark)
	# Tube back to the handle: steel, with the orange body over the click mechanism and a
	# yellow scale collar.
	_cyl(0.009, 0.3, Vector3(0, 0.03, 0.165), along, steel, 12)
	_box(Vector3(0.028, 0.026, 0.13), Vector3(0, 0.03, 0.12), body)
	_box(Vector3(0.03, 0.006, 0.012), Vector3(0, 0.03, 0.26), yellow)
	# Grip: dark, ribbed, with an end cap.
	_cyl(0.015, 0.1, Vector3(0, 0.03, 0.33), along, dark, 12)
	for z: float in [0.3, 0.33, 0.36]:
		_cyl(0.0165, 0.006, Vector3(0, 0.03, z), along, dark, 12)
	_cyl(0.013, 0.01, Vector3(0, 0.03, 0.385), along, steel, 12)
	# The screen on the body, turned to the eye each frame.
	_screen = Node3D.new()
	_screen.position = Vector3(0, 0.05, 0.12)
	_arm.add_child(_screen)
	_readout = TradesLook.readout(_screen, Vector3.ZERO, Vector2(0.09, 0.04), Color(0.6, 1.0, 0.5))
	_refresh()


## The click: a flash on the screen (the bench plays the sound and kicks the camera).
func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	var cam := get_viewport().get_camera_3d()
	if cam and _screen.is_inside_tree():
		var to_eye := cam.global_position - _screen.global_position
		if to_eye.length() > 0.01:
			_screen.global_basis = Basis.looking_at(-to_eye, Vector3.UP)
	_refresh()


func _refresh() -> void:
	if _readout == null:
		return
	var state := "CLICK" if _flash > 0.0 else ("%5.1f Nm" % applied_nm if applied_nm > 0.05 else "READY")
	_readout.text = "SET %3d Nm\n%s" % [roundi(set_nm), state]


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	_arm.add_child(m)
	return m


func _cyl(radius: float, height: float, at: Vector3, rot: Vector3, mat: Material, radial: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	_arm.add_child(m)
	return m
