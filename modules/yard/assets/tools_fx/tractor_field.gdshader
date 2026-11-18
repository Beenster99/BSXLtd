shader_type spatial;
// The hand tractor's field (BSX's own effect): an open cone from the lens to the load, additive
// and unlit. Rings of light run out along it (UV.y 0 at the lens, 1 at the load), edge-on parts
// fade so it reads as a soft volume, and it gathers from nothing at the lens to its brightest where it takes hold.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 field_color : source_color = vec3(0.35, 0.85, 1.0);
uniform float strength = 0.55;
uniform float ring_count = 7.0;   // rings along the beam at once
uniform float ring_speed = 1.4;   // beam lengths a second the rings run out

void fragment() {
	float t = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = smoothstep(0.15, 0.9, facing);
	float rings = pow(0.5 + 0.5 * sin((t * ring_count - TIME * ring_speed * ring_count) * 6.2831853), 6.0);
	float ends = smoothstep(0.0, 0.12, t) * (0.4 + 0.6 * smoothstep(0.75, 1.0, t));
	ALBEDO = field_color * strength * soft * (0.25 + 0.75 * rings) * ends;
}
