extends RefCounted
## Lamps and beams (G3): what Graphics does to the yard's lamps while "graphics.lamps" is on.
##   - A spot lamp gets a reflector's pool of light (a projector with a hot centre, a faint
##     ring where the reflector's lip catches and a soft edge) unless it has a projector.
##   - A big spot lamp (range BEAM_MIN_RANGE or more, or in group "gfx_beam") gets a soft
##     cone of lit dust under it, "GfxBeam", which follows the lamp: it hides with it, and
##     brightens and dims with its energy (night lights coming on at dusk). Meta
##     "gfx_no_beam" on a lamp keeps it plain (a torch in your face, a lamp in a cupboard).
##   The volumetric fog Core switches on also draws beams; with it on, the cones are only a
##   touch on top (VOLUMETRIC_SHARE), so they don't double up.
## Lamps with meta "gfx_fixed" (set up for a capture) are left as they are.

const BEAM_GROUP := "gfx_beam"
const NO_BEAM_META := "gfx_no_beam"
const BEAM_NAME := "GfxBeam"
## Spots reaching this far or more get a beam without asking, metres.
const BEAM_MIN_RANGE := 10.0
## The cone's length as a share of the lamp's range, and its most, metres.
const BEAM_SHARE := 0.7
const BEAM_MAX := 16.0
## Cone brightness per unit of the lamp's energy.
const BEAM_PER_ENERGY := 0.05
## The cones' share of their brightness when the volumetric fog draws real beams too.
const VOLUMETRIC_SHARE := 0.35
## Beyond this the cones aren't drawn, metres.
const BEAM_DRAW_RANGE := 140.0

const BeamShader := preload("res://modules/graphics/internal/light_beam.gdshader")

static var _profile: Texture2D


## Applies the lamp look to one light; returns its beam (new or already there) or null.
static func apply(l: Light3D) -> MeshInstance3D:
	if l is DirectionalLight3D or l.has_meta("gfx_fixed"):
		return null
	if not l is SpotLight3D:
		return null
	var spot := l as SpotLight3D
	if spot.light_projector == null:
		spot.light_projector = profile()
	if not wants_beam(spot):
		return null
	var beam := spot.get_node_or_null(BEAM_NAME) as MeshInstance3D
	if beam == null:
		beam = _make_beam(spot)
	refresh(beam)
	return beam


## True when a spot lamp should have a beam under it.
static func wants_beam(spot: SpotLight3D) -> bool:
	if spot.has_meta(NO_BEAM_META):
		return false
	return spot.is_in_group(BEAM_GROUP) or spot.spot_range >= BEAM_MIN_RANGE


## The cone's colour and brightness from its lamp now.
static func refresh(beam: MeshInstance3D) -> void:
	var spot := beam.get_parent() as SpotLight3D
	if spot == null:
		return
	var m := beam.material_override as ShaderMaterial
	var share := VOLUMETRIC_SHARE if fog_beams() else 1.0
	m.set_shader_parameter("colour", spot.light_color)
	m.set_shader_parameter("strength", spot.light_energy * BEAM_PER_ENERGY * share)


## True when the volumetric fog draws lamp beams itself (it is on, and the renderer has it:
## the Compatibility renderer doesn't).
static func fog_beams() -> bool:
	return int(GraphicsOptions.get_value("volumetrics")) > 0 \
			and RenderingServer.get_current_rendering_method() != "gl_compatibility"


## A spot's pool of light: bright centre, a faint reflector ring, a soft edge.
static func profile() -> Texture2D:
	if _profile:
		return _profile
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.46, 0.52, 0.72, 0.9, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1), Color(0.86, 0.86, 0.86), Color(0.78, 0.78, 0.78),
			Color(0.88, 0.88, 0.88), Color(0.5, 0.5, 0.5), Color(0.12, 0.12, 0.12), Color(0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 128
	t.height = 128
	_profile = t
	return t


static func _make_beam(spot: SpotLight3D) -> MeshInstance3D:
	var length := minf(spot.spot_range * BEAM_SHARE, BEAM_MAX)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.04
	cone.bottom_radius = maxf(tan(deg_to_rad(minf(spot.spot_angle, 80.0))) * length * 0.8, 0.1)
	cone.height = length
	cone.radial_segments = 24
	cone.rings = 6
	cone.cap_top = false
	cone.cap_bottom = false
	var m := ShaderMaterial.new()
	m.shader = BeamShader
	m.set_shader_parameter("length", length)
	var beam := MeshInstance3D.new()
	beam.name = BEAM_NAME
	beam.mesh = cone
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	beam.visibility_range_end = BEAM_DRAW_RANGE
	beam.visibility_range_end_margin = 20.0
	beam.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	# The cylinder stands along +Y with its narrow end up; the lamp shines down its -Z.
	beam.transform = Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -length / 2.0))
	spot.add_child(beam)
	return beam
