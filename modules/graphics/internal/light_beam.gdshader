shader_type spatial;
// A lamp's beam as a soft cone of lit dust (G3), for spot lights. Additive and unshaded:
// brightest along its axis near the lamp, fading toward its rim, its far end, where it
// meets a surface and when the camera is inside it. The real volumetric fog draws beams
// too on the better presets, so the bus turns this down there (strength).
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 colour : source_color = vec3(1.0);
// Overall brightness: the light's energy times the bus's beam factor.
uniform float strength = 0.2;
// The cone's length, metres (its tip is at the lamp).
uniform float length = 10.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying float along;   // 0 at the lamp .. 1 at the far end

void vertex() {
	along = clamp(0.5 - VERTEX.y / length, 0.0, 1.0);
}

void fragment() {
	// Toward the rim the cone is seen edge on: fade it there, so it reads as a volume.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(facing, 1.6);
	float fall = (1.0 - along) * (1.0 - along) * smoothstep(0.0, 0.06, along);
	// Soft where it passes into a wall or the floor.
	float scene = texture(depth_tex, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	scene = scene * 2.0 - 1.0;
#endif
	vec4 world = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	float behind = -world.z / world.w - (-VERTEX.z);
	float soft = smoothstep(0.0, 0.8, behind);
	// Gone when the camera stands in it (it would wash the view out).
	float near = smoothstep(0.6, 3.0, -VERTEX.z);
	ALBEDO = colour * strength * rim * fall * soft * near;
}
