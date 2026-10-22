shader_type spatial;
// Graphics: the highlight drawn over something you can use or that was pinged. A material
// overlay (drawn on top of the thing's own materials, which it never replaces): a glowing
// rim where the surface turns away from you plus a faint fill, pulsing gently. No fog: an
// additive pass would add the haze colour over the whole thing (a pale wash). Its next
// pass (highlight_outline) draws the outline round it.
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 colour : source_color = vec4(0.62, 0.9, 1.0, 1.0);
uniform float strength = 1.0;
// The rim and fill's share: 0 for the subtle look, which is only the outline.
uniform float glow = 1.0;
uniform float fill = 0.06;
uniform float rim_power = 2.5;
uniform float pulse_speed = 3.0;  // rad/s

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	ALBEDO = colour.rgb * (rim + fill) * strength * pulse * glow;
}
