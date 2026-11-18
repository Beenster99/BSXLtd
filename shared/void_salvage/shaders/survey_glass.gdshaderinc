// The survey glass (SurveyGlass, docs/ECONOMY_PLAN.md 3.3), shared by the salvage surface and
// the joint heads: the pilot's front canopy glass, where the survey is projected like a HUD.
// Set every frame on the pilot's machine as global shader parameters (project.godot
// [shader_globals]); survey_layer -1 turns it all off.
global uniform int survey_layer;      // -1 = off, 0 = all, else the layer shown
global uniform int survey_layer_old;  // what the sweep is replacing
global uniform vec3 survey_pane_c;    // the pane: centre and unit axes in its plane, world space
global uniform vec3 survey_pane_u;
global uniform vec3 survey_pane_v;
global uniform vec4 survey_poly_0;    // its outline in (u, v) metres, anticlockwise, two corners each
global uniform vec4 survey_poly_1;
global uniform vec4 survey_poly_2;
global uniform vec4 survey_poly_3;
global uniform int survey_poly_n;     // how many corners (3..8); -1 = the whole canopy
global uniform vec4 survey_sweep;     // the sweep plane: normal (xyz) and offset (w)
global uniform float survey_glow;     // the sweep line's brightness (0 when still)
// The scan pulse (ScanPulse, VX8b): a shell grown from a point, inside which everyone sees the
// hazards and seized bolts the glass shows, with no glass. Set on every machine.
global uniform vec4 survey_pulse;     // its origin (xyz, world space) and radius now (w, m; 0 = none)
global uniform float survey_pulse_glow; // its strength, 0..1 (fading in and out)

// Is `world_pos` seen through the glass from `cam` (the pane lies between them, and the line
// of sight passes inside its outline)?
bool survey_through_glass(vec3 world_pos, vec3 cam) {
	if (survey_layer < 0) {
		return false;
	}
	if (survey_poly_n < 0) {
		return true;
	}
	vec3 d = world_pos - cam;
	vec3 n = cross(survey_pane_u, survey_pane_v);
	float dn = dot(d, n);
	if (abs(dn) < 1e-6) {
		return false;
	}
	float t = dot(survey_pane_c - cam, n) / dn;
	if (t <= 0.0 || t >= 1.0 || survey_poly_n < 3) {
		return false;
	}
	vec3 p = cam + d * t - survey_pane_c;
	vec2 q = vec2(dot(p, survey_pane_u), dot(p, survey_pane_v));
	vec2 corners[8] = vec2[8](survey_poly_0.xy, survey_poly_0.zw, survey_poly_1.xy, survey_poly_1.zw,
			survey_poly_2.xy, survey_poly_2.zw, survey_poly_3.xy, survey_poly_3.zw);
	for (int i = 0; i < 8; i++) {
		if (i >= survey_poly_n) {
			break;
		}
		vec2 e0 = corners[i];
		vec2 edge = corners[(i + 1) % survey_poly_n] - e0;
		vec2 rel = q - e0;
		if (edge.x * rel.y - edge.y * rel.x < 0.0) {
			return false;
		}
	}
	return true;
}

// How strongly the scan pulse shows at `world_pos`: its glow inside the shell, else 0.
float survey_pulse_at(vec3 world_pos) {
	if (survey_pulse.w <= 0.0 || survey_pulse_glow <= 0.0) {
		return 0.0;
	}
	return distance(world_pos, survey_pulse.xyz) <= survey_pulse.w ? survey_pulse_glow : 0.0;
}

// Is `world_pos` inside the scan pulse's shell while it shows?
bool survey_in_pulse(vec3 world_pos) {
	return survey_pulse_at(world_pos) > 0.0;
}

// The pulse's edge where it meets a surface: 1 on the shell, fading off `width` metres either side.
float survey_pulse_edge(vec3 world_pos, float width) {
	if (survey_pulse.w <= 0.0 || survey_pulse_glow <= 0.0) {
		return 0.0;
	}
	float d = abs(distance(world_pos, survey_pulse.xyz) - survey_pulse.w);
	return (1.0 - smoothstep(0.0, width, d)) * survey_pulse_glow;
}
