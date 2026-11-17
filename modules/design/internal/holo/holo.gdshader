shader_type spatial;
// The design room's hologram look: see-through, glowing at its edges, faint scan lines,
// nothing above the cutting plane. Light-blue on purpose so it never reads as a real ship.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.45, 0.85, 1.0, 0.2);
uniform float rim = 1.0;
// World height above which nothing is drawn (the cutting plane).
uniform float cut_y = 100.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (world_pos.y > cut_y) {
		discard;
	}
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(1.0 - facing, 2.0) * rim;
	float scan = 0.85 + 0.15 * sin(world_pos.y * 220.0 - TIME * 3.0);
	float near_cut = smoothstep(0.03, 0.0, cut_y - world_pos.y) * step(cut_y, 99.0);
	vec3 c = tint.rgb * (tint.a + edge * 0.6) * scan + vec3(1.0, 0.7, 0.4) * near_cut;
	ALBEDO = c;
	ALPHA = clamp(tint.a + edge * 0.5 + near_cut, 0.0, 1.0);
}
