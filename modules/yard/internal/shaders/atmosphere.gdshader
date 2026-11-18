shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;
// The air round the planet's limb (drawn on a slightly larger sphere's inside): a thin bright
// blue line where the sun lights it, going cyan at the brightest and amber toward the
// terminator, fading out on the night side.

uniform vec3 colour : source_color = vec3(0.3, 0.55, 1.0);
uniform vec3 bright : source_color = vec3(0.6, 0.85, 1.0);
uniform vec3 dusk : source_color = vec3(1.0, 0.5, 0.2);
uniform float strength = 2.2;
uniform vec3 sun_dir = vec3(0.4, 0.5, -0.3);

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float rim = 1.0 - abs(dot(normalize(NORMAL), normalize(VIEW)));
	float thin = pow(rim, 9.0);
	float wide = pow(rim, 3.0) * 0.25;
	// The shell's outward normal: its sunward limb is the bright one.
	float sun = dot(world_normal, normalize(sun_dir));
	float lit = smoothstep(-0.25, 0.35, sun);
	vec3 tone = mix(colour, bright, thin);
	tone = mix(tone, dusk, exp(-pow(sun * 5.0, 2.0)) * 0.6);
	ALBEDO = tone * (thin + wide) * strength * (0.06 + 0.94 * lit);
}
