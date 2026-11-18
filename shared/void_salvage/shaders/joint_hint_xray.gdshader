shader_type spatial;
// The fastener hint seen through what is in front (FastenerHint): every joint head material's
// next pass (JointView). Only heads of the hinted kinds near the hint's centre draw (everything
// else is folded to nothing in the vertex stage, so it costs no pixels): a soft pulse of the
// hint's tint laid over whatever hides them (a blend, so it shows on a lamp-white plate too),
// so a flush bolt behind a lining shows where it is. Heads holding the rested part (custom w, UX3)
// draw at `joint_hint_rest` whatever their kind or distance.

render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_back, shadows_disabled;

global uniform vec4 joint_hint;
global uniform int joint_hint_kinds;
global uniform vec4 joint_hint_color;
global uniform float joint_hint_rest;
// The pulse's rate (Hz), and how much of the tint covers the head's shape through things at the
// pulse's height (0..1) and at its low.
uniform float pulse_hz = 1.2;
uniform float through = 0.55;
uniform float through_low = 0.15;
// The rested part's heads (UX3) show stronger through what hides them. Each is drawn its own size,
// only widened (across its face, and a little taller seen edge on) where it would be smaller on screen than
// `rest_min_share` of the view's height across, at most `rest_grow_max` times, so a small bolt a few
// metres off still reads without a near one swelling past its head (Dan, 2 Nov: they grew with the
// metres, 2.5 to 3.5 times a bolt). A weld bead is long already and a plug big: neither grows.
uniform float rest_through = 0.85;
uniform float rest_through_low = 0.45;
uniform float rest_min_share = 0.013;
// Seen edge on a widened head is a sliver: it is made at least this share of its least width tall
// (about its middle).
uniform float rest_min_tall = 0.4;
uniform float rest_grow_max = 4.0;

varying float hint;
varying float rested;

void vertex() {
	hint = 0.0;
	int kind = int(INSTANCE_CUSTOM.z + 0.5) - 1;
	if (joint_hint.w > 0.0 && joint_hint_color.a > 0.0 && kind >= 0 && (joint_hint_kinds & (1 << kind)) != 0) {
		// A weld bead (kind 0) by each point of it, as the head shader (FS2: a long seam's middle is far off).
		vec3 centre = kind == 0 ? (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz : (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		hint = 1.0 - smoothstep(joint_hint.w * 0.45, joint_hint.w, distance(centre, joint_hint.xyz));
	}
	hint *= min(joint_hint_color.a, 1.0);
	rested = 0.0;
	if (INSTANCE_CUSTOM.w > 0.5 && joint_hint_rest > 0.0) {
		rested = 1.0;
		hint = max(hint, min(joint_hint_rest, 1.0));
		if (kind != 0 && kind != 3) {
			// The least radius on screen, in metres at the head's distance, then in the head's own
			// space (its instance may be scaled); each rim vertex is pushed out to it, so the head's
			// outline is its own or that circle, whichever is bigger.
			vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
			float metres = distance(centre, CAMERA_POSITION_WORLD);
			float metres_least = rest_min_share * metres / max(abs(PROJECTION_MATRIX[1][1]), 1e-4);
			float least = metres_least / max(length(MODEL_MATRIX[0].xyz), 1e-4);
			float r = length(VERTEX.xz);
			if (r > 1e-6) {
				VERTEX.xz *= clamp(least / r, 1.0, rest_grow_max);
			}
			float tall = 0.5 * rest_min_tall * metres_least / max(length(MODEL_MATRIX[1].xyz), 1e-4);
			if (abs(VERTEX.y) > 1e-7 && abs(VERTEX.y) < tall) {
				VERTEX.y = sign(VERTEX.y) * tall;
			}
		}
	}
	if (hint <= 0.0) {
		VERTEX = vec3(0.0);   // folded: no triangle, no pixels
	}
}

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * 6.2831853 * pulse_hz);
	ALBEDO = mix(joint_hint_color.rgb, vec3(1.0), 0.25);
	float high = mix(through, rest_through, rested);
	float low = mix(through_low, rest_through_low, rested);
	ALPHA = clamp(mix(low, high, pulse) * hint, 0.0, 1.0);
}
