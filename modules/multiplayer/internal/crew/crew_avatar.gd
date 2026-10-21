extends Node3D
## Another player in the world: a suit, a helmet and a name tag. The Head child is the mover
## the player's own camera drives (looking down -Z, like a camera); the body stands under it
## and turns with it. Other modules find heads by the group HEAD_GROUP, each with the meta
## "peer_id" (Graphics hangs crewmates' helmet torches on them).

const HEAD_GROUP := "crew_head"
const EYE_HEIGHT := 1.65
const SUIT := Color("e8792b")
const VISOR := Color("16191c")

var head := Node3D.new()


func _ready() -> void:
	head.name = "Head"
	head.top_level = true
	head.add_to_group(HEAD_GROUP)
	head.set_meta("peer_id", int(get_meta("peer_id", 0)))
	add_child(head)
	var helmet := _mesh(SphereMesh.new(), SUIT.lightened(0.15))
	(helmet.mesh as SphereMesh).radius = 0.17
	(helmet.mesh as SphereMesh).height = 0.34
	head.add_child(helmet)
	var visor := _mesh(BoxMesh.new(), VISOR)
	(visor.mesh as BoxMesh).size = Vector3(0.26, 0.12, 0.08)
	visor.position = Vector3(0, 0.0, -0.14)
	head.add_child(visor)
	var body := _mesh(CapsuleMesh.new(), SUIT)
	(body.mesh as CapsuleMesh).radius = 0.25
	(body.mesh as CapsuleMesh).height = 1.4
	body.position = Vector3(0, 0.75, 0)
	add_child(body)
	var tag := Label3D.new()
	tag.text = str(get_meta("player_name", "")).to_upper()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 40
	tag.pixel_size = 0.004
	tag.position = Vector3(0, 0.32, 0)
	tag.no_depth_test = true
	head.add_child(tag)


func _process(_delta: float) -> void:
	var at := head.global_transform
	var yaw := at.basis.get_euler().y
	global_transform = Transform3D(Basis(Vector3.UP, yaw), at.origin - Vector3(0, EYE_HEIGHT, 0))


func _mesh(m: Mesh, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mi.material_override = mat
	return mi
