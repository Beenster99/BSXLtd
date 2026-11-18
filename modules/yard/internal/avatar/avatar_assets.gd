class_name YardSuitAssets
extends RefCounted
## Baked Blender art, shared by the wardrobe, local body and remote players.
## Meshes are cached, poses remain on YardAvatar's existing joints.

## Only the Kestrel suit is copied over from Void Salvage so far; other designs draw in primitives.
const DESIGNS: Array[String] = ["kestrel"]
const VISOR := preload("res://modules/yard/assets/avatar/player_visor.gdshader")
const FINISH := preload("res://modules/yard/assets/avatar/player_finish.gdshader")
static var _meshes: Dictionary = {}
static var _profiles: Dictionary = {}
static var _all: Dictionary = {}


static func is_design(id: String) -> bool:
	return id in DESIGNS


static func meshes(id: String) -> Dictionary:
	if _meshes.has(id):
		return _meshes[id]
	# BSX's own tools, made in code in the same finish (YardToolMesh), each in the fitted hand
	# of the Void Salvage tool whose grip it copies (MADE_TOOLS).
	if id == "tool_tractor":
		_meshes[id] = YardTractor.model()
	elif id == "tool_tablet":
		_meshes[id] = YardTablet.model()
	elif id == "tool_riveter":
		_meshes[id] = YardRiveter.model()
	elif id == "tool_welder":
		_meshes[id] = YardWelder.model()
	if _meshes.has(id):
		var out: Dictionary = _meshes[id]
		if not out.has("hand"):
			out["hand"] = meshes("tool_" + String(MADE_TOOLS[id.trim_prefix("tool_")]))["hand"]
		return out
	var scene := load("res://modules/yard/assets/avatar/" + id + ".glb") as PackedScene
	assert(scene != null, "Missing baked player asset: " + id)
	var root := scene.instantiate()
	var out: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		out[String(mi.name)] = mi.mesh
	root.free()
	_meshes[id] = out
	return out


## The scanned sets the finish layers (assets/materials, CC0): the paint's relief, scratches
## and chips; brushed metal; the rubber's grain. Uniform name -> file.
const SCANS: Dictionary = {
	"paint_normal": "res://modules/yard/assets/avatar/paintedmetal002/paintedmetal002_2048_normal.jpg",
	"paint_orm": "res://modules/yard/assets/avatar/paintedmetal002/paintedmetal002_2048_orm.jpg",
	"metal_normal": "res://modules/yard/assets/avatar/metal010/metal010_2048_normal.jpg",
	"metal_orm": "res://modules/yard/assets/avatar/metal010/metal010_2048_orm.jpg",
	"rubber_normal": "res://modules/yard/assets/avatar/rubber004/rubber004_2048_normal.jpg",
}


static func finish(look: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FINISH
	for key: String in SCANS:
		mat.set_shader_parameter(key, load(SCANS[key]))
	mat.set_shader_parameter("plates", YardSuitLook.PRIMARY[int(look["primary"])])
	mat.set_shader_parameter("trim", YardSuitLook.SECONDARY[int(look["secondary"])])
	mat.set_shader_parameter("accent", YardSuitLook.accent_color(look))
	mat.set_shader_parameter("oxygen", YardSuitLook.accent_color(look))
	mat.set_shader_parameter("wear", YardSuitLook.WEAR_LEVELS[int(look["wear"])])
	return mat


static func _data() -> Dictionary:
	if _all.is_empty():
		_all = JSON.parse_string(FileAccess.get_file_as_string("res://modules/yard/assets/avatar/player_assets.json"))
	return _all


## BSX's own tools and the Void Salvage tool each one's grip, hand and wrist copy.
const MADE_TOOLS := {"tractor": "grabber", "tablet": "scanner", "riveter": "socket", "welder": "cutter"}


static func tool_profile(id: String) -> Dictionary:
	if _profiles.is_empty():
		_profiles = _data()["tools"]
	return _profiles[MADE_TOOLS.get(id, id)]


## Where a design's torso carries the name plate ("plate", the chest joint's space) or its
## shoulder the company badge ("badge", the left upper arm's): data/player_assets.json
## "designs", written by tools/blender/player_suits/build.py.
static func anchor(design: String, which: String) -> Vector3:
	return vector(_data()["designs"][design][which])


## The visor's glass for a look: `kind` a YardSuitLook visor, `accent` the displays' light inside.
static func visor(kind: String, accent: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VISOR
	var v: Dictionary = YardSuitLook.VISORS.get(kind, YardSuitLook.VISORS["dark"])
	mat.set_shader_parameter("tint", v["tint"])
	mat.set_shader_parameter("sheen", v["sheen"])
	mat.set_shader_parameter("mirror", v["mirror"])
	mat.set_shader_parameter("roughness", v["roughness"])
	mat.set_shader_parameter("inner", accent)
	return mat


static func vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))


static func piece(mesh: Mesh, mat: Material, label: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = label
	mi.mesh = mesh
	mi.material_override = mat
	return mi
