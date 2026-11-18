shader_type spatial;
// The plasma's gas blown out of the back of a cut (ToolEffects.plasma): an open cone, its
// narrow end at the kerf (local y -0.5) widening to its far end (+0.5), scaled by the node.
// Self-lit, added on top: brightest at the kerf and fading out along it, soft at its edges
// (by how square to the view each face is, so it reads as glowing gas, never a glassy cone),
// rippling and flickering as the arc does. Two of these, a tight bright core and a wider
// fainter sheath.
render_mode unshaded, blend_add, cull_disabled, shadows_disabled, depth_draw_never, fog_disabled;

uniform vec3 color : source_color = vec3(0.35, 0.6, 1.0);
// The colour at the kerf, where it is hottest.
uniform vec3 core : source_color = vec3(0.85, 0.93, 1.0);
uniform float energy = 2.0;
// How fast its ripples run out along it (per second) and how many along it.
uniform float ripple_speed = 9.0;
uniform float ripples = 5.0;
// Set each frame by the effects (0..1): how strong the arc is now.
uniform float level = 1.0;

varying float along;
varying float round_at;

void vertex() {
	along = VERTEX.y + 0.5;
	round_at = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = facing * facing;
	float fade = pow(1.0 - clamp(along, 0.0, 1.0), 1.6);
	float wave = 0.65 + 0.35 * sin(along * ripples * 6.2832 - TIME * ripple_speed + round_at * 3.0);
	wave *= 0.8 + 0.2 * sin(TIME * 37.0 + round_at * 5.0);
	vec3 c = mix(core, color, smoothstep(0.0, 0.45, along));
	ALBEDO = c * energy * level * edge * fade * wave;
}
