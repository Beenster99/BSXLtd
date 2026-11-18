// (From Void Salvage 6523ae5, shaders/fx_field.gdshaderinc.)
// A field's line, the fragment shared by FieldLines' ribbons (fx_field.gdshader) and FieldGrip's
// tethers (fx_tether.gdshader), VX18 and VX21: bands of light flowing inward along it, brighter
// toward the intake, soft across. UV.x runs along a line (with its own offset), `inward` is how far
// in it is (0 the mouth or the piece, 1 the intake), UV.y across. Lines are drawn only from
// 1 - `extent` inward (the ripple reaching out as a field comes on, the collapse as it lets go),
// with a bright front at that edge while it moves.

uniform vec3 colour : source_color = vec3(0.45, 0.85, 1.0);
// How hard the field pulls (0..1): its brightness and how fast it flows.
uniform float strength = 1.0;
// Bands a second flowing inward, bands along a line, and the brightness.
uniform float flow = 1.6;
uniform float bands = 7.0;
uniform float energy = 2.2;
// How far out from the intake the lines are drawn (0..1 of their length).
uniform float extent = 1.0;
// Straining (0..1): the bands stutter and the line flickers.
uniform float strain = 0.0;

varying float inward;

float field_hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void field_fragment(vec2 uv, inout vec3 albedo, inout float alpha, float time) {
	float across = abs(uv.y - 0.5) * 2.0;
	float soft = pow(1.0 - across, 1.6);
	float band = fract(uv.x * bands - time * flow * (0.4 + 0.6 * strength));
	float pulse = smoothstep(0.0, 0.25, band) * (1.0 - smoothstep(0.35, 1.0, band));
	float in_ramp = mix(0.25, 1.0, inward) * smoothstep(0.0, 0.12, inward);
	float edge = 1.0 - extent;
	float shown = smoothstep(edge - 0.03, edge, inward);
	float front = (1.0 - smoothstep(0.0, 0.06, abs(inward - edge))) * step(0.001, edge) * step(extent, 0.999);
	float flick = 1.0 - strain * 0.75 * step(0.55, field_hash(floor(time * 23.0) + uv.x * 3.0));
	albedo = colour * energy;
	alpha = clamp((soft * (0.25 + 0.75 * pulse) * in_ramp * shown + front * soft * 1.5) * strength * flick, 0.0, 1.0);
}
