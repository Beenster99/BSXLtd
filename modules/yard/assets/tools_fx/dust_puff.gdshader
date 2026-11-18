shader_type spatial;
// A puff of dust or grit (a tool's rust and grinding dust, a seam's grit as a piece comes free:
// SmokeTrail with Fx.dust_material()): a ragged little cloud, not a disc. Each puff reads its own
// patch of a tiling noise (its seed in the instance's custom data, xy), which eats into a soft
// falloff so the edge is torn and the middle uneven; the patch drifts as the puff ages (z).
// Lit like the smoke (a lamp shows it), faded by its colour's alpha.
render_mode blend_mix, depth_draw_never, cull_disabled, specular_disabled, shadows_disabled;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
// How deep the noise tears into the edge (0 a round blob), and how uneven the middle is.
uniform float ragged = 0.9;
uniform float grain = 0.7;
// Where the falloff starts (0 the middle, 1 the quad's edge).
uniform float core = 0.0;

varying vec4 v_seed;

void vertex() {
	v_seed = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	vec2 at = v_seed.xy * 17.0;
	float age = v_seed.z;
	float big = texture(noise_tex, UV * 0.45 + at + vec2(age * 0.06, -age * 0.04)).r;
	float fine = texture(noise_tex, UV * 1.3 + at.yx * 1.7 - vec2(age * 0.11, age * 0.07)).r;
	float shape = 1.0 - smoothstep(core, 1.0, r + (big - 0.5) * ragged * 1.6);
	float body = mix(1.0, clamp(fine * 1.7 - 0.4, 0.0, 1.0), grain);
	ALBEDO = COLOR.rgb;
	ALPHA = clamp(COLOR.a * shape * body, 0.0, 1.0);
	ROUGHNESS = 1.0;
}
