class_name Glazing
extends RefCounted
## The kinds of glass a part's window or lens can be (docs/ECONOMY_PLAN.md section 7, A1
## revised). Glass is see-through, so it stays a StandardMaterial3D of its own rather than a
## finish on the salvage surface; a part names its kind in `PartShape.glass_kind` and
## WreckDesign.fit (or any builder) takes the material from `material(kind)`. One shared
## material per kind. Presentation only.
##   CLEAR     plain window glass, faint blue
##   TINTED    smoked canopy glass (cockpits, visors)
##   FROSTED   rough translucent panes (washrooms, light boxes)
##   ARMOURED  thick green-edged laminate (bridges, gun sights)
##   AMBER     a warm lamp lens
##   RED       a red lens (nav lights, warning lamps)
##   SOLAR     the glossy dark cover glass over solar cells

enum Kind { CLEAR, TINTED, FROSTED, ARMOURED, AMBER, RED, SOLAR }

## kind -> (colour with alpha, metallic, roughness).
const LOOKS: Dictionary = {
	Kind.CLEAR: [Color(0.5, 0.72, 0.9, 0.28), 0.3, 0.05],
	Kind.TINTED: [Color(0.12, 0.16, 0.2, 0.62), 0.4, 0.06],
	Kind.FROSTED: [Color(0.8, 0.85, 0.88, 0.7), 0.0, 0.6],
	Kind.ARMOURED: [Color(0.45, 0.7, 0.62, 0.45), 0.3, 0.08],
	Kind.AMBER: [Color(1.0, 0.7, 0.25, 0.6), 0.2, 0.1],
	Kind.RED: [Color(0.9, 0.12, 0.08, 0.65), 0.2, 0.1],
	Kind.SOLAR: [Color(0.1, 0.14, 0.24, 0.5), 0.5, 0.04],
}

## The kinds you look out through from inside. A lamp's highlight on glass this smooth is a
## tiny disc bright enough to bloom, mirrored onto the pane wherever you look, so these take
## no highlight from lamps or the sun (`SPECULAR_DISABLED`); they keep their tint and still
## reflect the sky and the scene.
const WINDOWS: Array[int] = [Kind.CLEAR, Kind.TINTED, Kind.ARMOURED]

static var _materials: Dictionary = {}


## The shared material for `kind`.
static func material(kind: int) -> StandardMaterial3D:
	if not _materials.has(kind):
		var look: Array = LOOKS.get(kind, LOOKS[Kind.CLEAR])
		var m := StandardMaterial3D.new()
		m.albedo_color = look[0]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = float(look[1])
		m.roughness = float(look[2])
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if WINDOWS.has(kind):
			m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_materials[kind] = m
	return _materials[kind]


static func display_name(kind: int) -> String:
	return ["Clear glass", "Tinted glass", "Frosted glass", "Armoured glass", "Amber lens", "Red lens",
			"Solar cover glass"][clampi(kind, 0, Kind.size() - 1)]


## Most crack points a cracked pane draws (the shader's array).
const MAX_CRACKS: int = 8
## The thickest glass a crack runs through, m (a curved pane's box is deeper than its glass).
const MAX_THICKNESS: float = 0.1
## How brightly a crack's broken faces glint in a light (0 none), and how much light coming
## from behind the pane a crack scatters toward you.
static var crack_glint: float = 1.6
static var crack_back_scatter: float = 0.9
static var _cracked_shader: Shader


## A crazed copy of the glass `base` (docs/DAMAGE_PLAN.md 9.3.3): a spider web of radial
## and concentric cracks round each of `cracks` ([[point in the mesh's space, radius m], ...]),
## crushed milky at each point. `pane` is the mesh's box: its thinnest side is the glass's
## thickness, which the cracks run through (empty: the faces' main axis, 2 cm). One per pane
## (a wreck has tens, not thousands).
static func cracked(base: Material, cracks: Array, pane := AABB()) -> ShaderMaterial:
	if _cracked_shader == null:
		_cracked_shader = load("res://shared/void_salvage/shaders/glass_cracked.gdshader")
	var colour := Color(0.5, 0.72, 0.9, 0.28)
	var metallic := 0.3
	var roughness := 0.05
	var std := base as StandardMaterial3D
	if std:
		colour = std.albedo_color
		metallic = std.metallic
		roughness = std.roughness
	var m := ShaderMaterial.new()
	m.shader = _cracked_shader
	m.set_shader_parameter("albedo", colour)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness", roughness)
	var points := PackedVector4Array()
	for c: Array in cracks.slice(0, MAX_CRACKS):
		var p: Vector3 = c[0]
		points.append(Vector4(p.x, p.y, p.z, float(c[1])))
	m.set_shader_parameter("crack_count", points.size())
	points.resize(MAX_CRACKS)
	m.set_shader_parameter("cracks", points)
	if pane.size != Vector3.ZERO:
		var thin := pane.size.min_axis_index()
		var normal := Vector3.ZERO
		normal[thin] = 1.0
		m.set_shader_parameter("pane_normal", normal)
		# A curved pane's box is deeper than its glass: no glass is thicker than this.
		m.set_shader_parameter("pane_thickness", minf(pane.size[thin], MAX_THICKNESS))
	m.set_shader_parameter("glint", crack_glint)
	m.set_shader_parameter("back_scatter", crack_back_scatter)
	return m
