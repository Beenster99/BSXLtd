extends RefCounted
## The sea for a shore (GfxBus.sea): a plane of water at y 0 of its parent. With "graphics.sea"
## on it wears the sea shader (swells, ripples, the sky's reflection, depth colour, foam
## round anything solid in it); off, a plain dark-blue plane.

const SeaShader := preload("res://modules/graphics/internal/sea.gdshader")
## Swells need vertices: one about every this many metres, up to the plane mesh's limit.
const GRID := 6.0
const MAX_SUBDIVIDE := 400
## The plain water (flag off).
const PLAIN := Color(0.03, 0.09, 0.12)


static func make(size: Vector2, styled: bool) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	if styled:
		plane.subdivide_width = mini(int(size.x / GRID), MAX_SUBDIVIDE)
		plane.subdivide_depth = mini(int(size.y / GRID), MAX_SUBDIVIDE)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("gfx_coplanar_ok", true)
	if styled:
		var m := ShaderMaterial.new()
		m.shader = SeaShader
		mi.material_override = m
		# The swells lift the surface a little: keep it from being culled at the screen's edge.
		mi.extra_cull_margin = 1.0
	else:
		var m := StandardMaterial3D.new()
		m.albedo_color = PLAIN
		m.roughness = 0.12
		mi.material_override = m
	return mi
