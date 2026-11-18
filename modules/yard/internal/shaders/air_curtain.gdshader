shader_type spatial;
// The air curtain across the stores hall's open sides: a faint blue shimmer, brighter where
// you see it edge on, with slow bands rising through it and a glow along its sill.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 colour = vec3(0.35, 0.7, 1.0);
uniform float strength = 0.07;

float wave(vec2 p, float t) {
	return 0.5 + 0.5 * sin(p.x * 0.9 + sin(p.y * 0.35 + t * 0.4) * 2.0 + t * 0.7)
			* sin(p.y * 1.7 - t * 1.1 + sin(p.x * 0.21) * 3.0);
}

void fragment() {
	vec2 p = UV * vec2(60.0, 12.0);
	float t = TIME;
	float bands = wave(p, t) * 0.6 + wave(p * 1.9 + 3.1, t * 1.3) * 0.4;
	float edge_on = 1.0 - abs(dot(NORMAL, VIEW));
	float sill = smoothstep(0.08, 0.0, 1.0 - UV.y) * 1.6 + smoothstep(0.04, 0.0, UV.y) * 0.8;
	float a = strength * (0.35 + bands * 0.9 + edge_on * 1.6) + strength * sill;
	ALBEDO = colour * a;
}
