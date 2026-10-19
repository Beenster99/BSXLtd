class_name TradesTorqueWrench
extends Node3D
## Click-type torque wrench, held in the right hand. Built in code from boxes and cylinders,
## like Void Salvage's tools, with a small lit readout on the handle. Set to the joint's
## target; it gives one click when the pull reaches it. A powered one comes later.
##
## Its own space: the socket at the origin over the bolt, +Y out of the bolt, the handle
## running back along +Z.

const BODY := Color("c33c2e")
const STEEL := Color("b9c0c6")
const DARK := Color("1d2126")

var set_nm := 25.0
## Where the hand holds it, in its own space.
const GRIP := Vector3(0, 0.03, 0.33)

var _readout: Label3D
var _flash := 0.0
var _arm: Node3D


func _ready() -> void:
	name = "TorqueWrench"
	_arm = Node3D.new()
	add_child(_arm)
	var body := _mat(BODY, 0.3, 0.45)
	var steel := _mat(STEEL, 0.9, 0.25)
	var dark := _mat(DARK, 0.3, 0.7)
	_cyl(0.011, 0.026, Vector3(0, 0.006, 0), steel, 12)               # socket
	_cyl(0.016, 0.022, Vector3(0, 0.03, 0), steel, 16)                # ratchet head
	_box(Vector3(0.02, 0.016, 0.3), Vector3(0, 0.03, 0.16), body)     # tube
	_box(Vector3(0.028, 0.028, 0.09), Vector3(0, 0.03, 0.33), dark)   # grip
	_box(Vector3(0.024, 0.006, 0.012), Vector3(0, 0.04, 0.27), steel) # scale collar
	# Readout on top of the tube, tilted back toward the wearer's eye.
	var panel := _box(Vector3(0.07, 0.004, 0.04), Vector3(0, 0.041, 0.1), _mat(Color(0.02, 0.03, 0.04), 0.2, 0.25))
	panel.rotation.x = deg_to_rad(-20.0)
	_readout = Label3D.new()
	_readout.font_size = 48
	_readout.pixel_size = 0.00026
	_readout.modulate = Color(1.0, 0.75, 0.3)
	_readout.rotation.x = deg_to_rad(-90.0)
	_readout.position = Vector3(0, 0.003, 0)
	_readout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.add_child(_readout)
	_refresh()


## The click: a flash on the readout (the bench plays the sound and kicks the camera).
func click() -> void:
	_flash = 0.6


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta)
	_refresh()


func _refresh() -> void:
	if _readout:
		_readout.text = "SET %d Nm\n%s" % [roundi(set_nm), "CLICK" if _flash > 0.0 else "READY"]


func _box(size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	_arm.add_child(m)
	return m


func _cyl(radius: float, height: float, at: Vector3, mat: Material, radial: int) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	_arm.add_child(m)
	return m


static func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat
