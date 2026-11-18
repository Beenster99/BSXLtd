shader_type spatial;
// VX11: a downed suit's red point (PlayerModel's "DistressPoint" on the pack). A soft dot facing
// the camera, the same size on screen at any range, drawn `pull` metres toward the eye so the
// wearer's own helmet and pack never hide it from the front; walls still do (it is depth tested).
render_mode unshaded, blend_mix, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 colour : source_color = vec4(1.0, 0.06, 0.03, 1.0);
// Its size (radians of view: metres across at a metre's distance).
uniform float size = 0.018;
// How far it is drawn toward the eye (m), never more than half the way.
uniform float pull = 0.6;

void vertex() {
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float d = length(centre);
	vec3 c = centre - centre / max(d, 1e-4) * min(pull, d * 0.5);
	c.xy += VERTEX.xy * size * max(-c.z, 0.05);
	POSITION = PROJECTION_MATRIX * vec4(c, 1.0);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	ALBEDO = colour.rgb;
	ALPHA = colour.a * (1.0 - smoothstep(0.55, 1.0, r));
}
