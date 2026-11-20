extends RefCounted
## Paints for the refurb shop: Void Salvage's salvage surface with a SurfaceFinish, in our own
## colour (like the yard's), and lit materials. Cached; presentation only.

const SURFACE := preload("res://shared/void_salvage/shaders/salvage_surface.gdshader")

## The works' paints (the drones carry BSX's own livery: RefurbBotLook).
const PLATES := Color(0.8, 0.8, 0.78)
const TRIM := Color(0.1, 0.1, 0.11)
const OCHRE := Color(0.85, 0.6, 0.1)
const DECK := Color(0.36, 0.38, 0.41)
const STEEL := Color(0.55, 0.57, 0.6)
const RACK_BLUE := Color(0.2, 0.32, 0.55)
const BEAM_ORANGE := Color(1.0, 0.5, 0.12)
const HAZARD := Color(1.0, 0.78, 0.1)

static var _cache: Dictionary = {}


static func paint(c: Color, metal := 0.2, rough := 0.6, finish := "") -> ShaderMaterial:
	if finish == "":
		finish = "brushed_steel" if metal >= 0.6 else "satin_paint"
	var key := "%s/%s/%s/%s" % [c.to_html(), metal, rough, finish]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = SURFACE
		m.set_shader_parameter("albedo", Color(c.r, c.g, c.b))
		m.set_shader_parameter("metallic", metal)
		m.set_shader_parameter("roughness", rough)
		m.set_shader_parameter("survey_skip", true)
		SurfaceFinish.apply(m)
		SurfaceFinish.set_finish(m, finish, Color(c.r, c.g, c.b, 1.0))
		m.set_shader_parameter("material_blend", 0.0)
		_cache[key] = m
	return _cache[key]


static func glow(c: Color, energy := 3.0, unshaded := false) -> StandardMaterial3D:
	var key := "glow/%s/%s/%s" % [c.to_html(), energy, unshaded]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[key] = m
	return _cache[key]


## A see-through additive glow (scan fans, blast haze).
static func haze(c: Color) -> StandardMaterial3D:
	var key := "haze/%s" % c.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		_cache[key] = m
	return _cache[key]


## A box, sphere or cylinder mesh instance under `parent`.
static func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, name := "") -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _put(parent, bm, at, mat, name)


static func ball(parent: Node3D, radius: float, at: Vector3, mat: Material, scale := Vector3.ONE, name := "") -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	var mi := _put(parent, sm, at, mat, name)
	mi.scale = scale
	return mi


static func rod(parent: Node3D, radius: float, length: float, at: Vector3, mat: Material, basis := Basis(), name := "", top := -1.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = radius if top < 0.0 else top
	cm.bottom_radius = radius
	cm.height = length
	cm.radial_segments = 14
	var mi := _put(parent, cm, at, mat, name)
	mi.basis = basis
	return mi


static func _put(parent: Node3D, mesh: Mesh, at: Vector3, mat: Material, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	if name != "":
		mi.name = name
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, at: Vector3, px: float, c: Color, size := 64, facing := Vector3.BACK) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = px
	l.font_size = size
	l.modulate = c
	l.outline_size = 0
	l.position = at
	l.double_sided = false
	parent.add_child(l)
	if facing != Vector3.BACK:
		l.basis = Basis.looking_at(-facing, Vector3.UP)
	return l
