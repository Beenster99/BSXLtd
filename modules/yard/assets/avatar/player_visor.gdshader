// A suit helmet's visor (PlayerModel._visor_look): coated glass that reads in the dark. Space
// gives a mirror nothing to show, so the glass carries a soft light of its own: a horizon and
// a strip light in the reflection, placed from the view, so they slide over the curve as the
// head or the eye moves; a little of the suit's accent from the displays inside, low down.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.02, 0.03, 0.04, 1.0);     // the glass
uniform vec4 sheen : source_color = vec4(0.5, 0.6, 0.7, 1.0);       // what it reflects
uniform vec4 inner : source_color = vec4(1.0, 0.5, 0.1, 1.0);       // the displays inside (the accent)
uniform float mirror : hint_range(0.0, 1.0) = 0.9;                  // metallic coating
uniform float sheen_energy = 0.55;
uniform float inner_energy = 0.22;
uniform float roughness : hint_range(0.0, 1.0) = 0.06;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float fresnel = pow(1.0 - facing, 3.0);
	vec3 r = reflect(-v, n);
	float sky = smoothstep(-0.25, 0.55, r.y);
	float strip = exp(-pow((r.y - 0.52) / 0.11, 2.0)) * smoothstep(0.95, 0.2, abs(r.x));
	float spot = exp(-(pow((r.x + 0.42) / 0.16, 2.0) + pow((r.y - 0.2) / 0.3, 2.0)));
	vec3 env = sheen.rgb * (0.10 * sky + 0.75 * strip + 0.35 * spot);
	float low = smoothstep(0.11, -0.02, local_pos.y);
	ALBEDO = tint.rgb;
	METALLIC = mirror;
	ROUGHNESS = roughness;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.05;
	RIM = 0.5;
	RIM_TINT = 0.3;
	EMISSION = env * sheen_energy * (0.45 + 0.55 * fresnel) + tint.rgb * sheen.rgb * 0.25
			+ inner.rgb * inner_energy * low * (0.35 + 0.65 * facing);
}
