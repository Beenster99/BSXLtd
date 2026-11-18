shader_type spatial;
// (From Void Salvage 6523ae5, shaders/fx_tether.gdshader.) A grip's tether (VX21, FieldGrip): a line of light from the field's intake (or the claw) to a
// piece it has hold of, bowed and writhing, flowing toward the intake. The mesh is a unit strip:
// UV2.x how far along it is (0 at the piece, 1 at the intake), UV.y across. Its curve is a
// quadratic Bezier through each instance's `from_piece`, `bend` and `to_intake` (world, m), turned to
// the eye here; `width` its width (m). The look is fx_field.gdshaderinc's.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://modules/yard/assets/tools_fx/field_line.gdshaderinc"

instance uniform vec3 from_piece = vec3(0.0);
instance uniform vec3 bend = vec3(0.0, 0.5, 0.0);
instance uniform vec3 to_intake = vec3(0.0, 1.0, 0.0);
instance uniform float width = 0.05;
instance uniform float seed = 0.0;

void vertex() {
	float s = UV2.x;
	vec3 w = mix(mix(from_piece, bend, s), mix(bend, to_intake, s), s);
	vec3 dw = 2.0 * (1.0 - s) * (bend - from_piece) + 2.0 * s * (to_intake - bend);
	vec3 p = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	vec3 t = (VIEW_MATRIX * vec4(dw, 0.0)).xyz;
	vec3 side = cross(t, p);
	side = length(side) > 1e-6 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	// Thinner at the intake, as the field's own lines.
	VERTEX = p + side * (UV.y - 0.5) * width * mix(1.0, 0.45, s);
	NORMAL = vec3(0.0, 0.0, 1.0);
	inward = s;
}

void fragment() {
	vec3 albedo;
	float alpha;
	field_fragment(vec2(UV.x + seed, UV.y), albedo, alpha, TIME);
	ALBEDO = albedo;
	ALPHA = alpha;
}
