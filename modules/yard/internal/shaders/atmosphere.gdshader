shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
// A thin blue halo round the planet's limb (drawn on a slightly larger sphere's inside).

uniform vec3 colour : source_color = vec3(0.35, 0.6, 1.0);
uniform float strength = 1.6;
uniform vec3 sun_dir = vec3(0.4, 0.5, -0.3);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float glow = pow(rim, 6.0) * strength;
	float lit = smoothstep(-0.3, 0.4, dot(-world_normal, normalize(sun_dir)));
	ALBEDO = colour * glow * (0.15 + 0.85 * lit);
}
