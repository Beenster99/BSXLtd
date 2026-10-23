shader_type spatial;
// Graphics: the light column over a ping, fading upward (CylinderMesh UV.y runs 0 at the top to 1 at the foot).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = colour.rgb * UV.y * 1.2 * alpha;
}
