shader_type spatial;
// Rivet heads, bolt heads, weld beads, loom plugs, sheared stubs and weld scars: drawn in
// batches (one MultiMesh per mesh and material on each structure, see JointBatch), so a
// wreck's thousands of joints cost a handful of draw calls. Heat comes per instance:
// INSTANCE_CUSTOM.x is 0 cold .. 1 glowing hot (a tool working the joint); .y is 1 on a seized
// bolt, which glows amber through the pilot's survey glass and inside a scan pulse (VX8b);
// .z is the joint's kind + 1 on a live joint's head (ConnectionData.Kind; 0 on decor: stubs, scars), for the fastener hint;
// .w is 1 on a head holding the part the crosshair rests on (UX3), which the hint lights whatever its kind.

render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.6);
uniform float metallic = 0.8;
uniform float roughness = 0.35;
// A head in its part's own paint (JointView.painted_material): the colour (linear) comes in the
// instance's colour, its metal and roughness packed in the alpha (the whole part / 31 and the
// fraction: JointBatch.pack_finish), so every paint draws in one batch.
uniform bool instance_paint = false;

#include "res://shared/void_salvage/shaders/survey_glass.gdshaderinc"

// The fastener hint (FastenerHint, set each frame on the local player's machine): heads of the
// kinds the held tool can work, near where it would bite, get a faint rim of light so subtle
// rivets and flush bolts can be found. joint_hint: the centre (world) and the reach (m; 0 off);
// joint_hint_kinds: a bit per ConnectionData.Kind; joint_hint_color: rgb and strength (a).
// joint_hint_rest: the strength the rested part's heads (custom w) light at, any kind, anywhere (UX3).
global uniform vec4 joint_hint;
global uniform int joint_hint_kinds;
global uniform vec4 joint_hint_color;
global uniform float joint_hint_rest;

varying float heat;
varying float seized;
varying vec3 world_pos;
varying float hint;
varying float rest;
varying vec4 paint;

void vertex() {
	paint = COLOR;
	heat = INSTANCE_CUSTOM.x;
	seized = INSTANCE_CUSTOM.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hint = 0.0;
	rest = INSTANCE_CUSTOM.w > 0.5 ? joint_hint_rest : 0.0;
	int kind = int(INSTANCE_CUSTOM.z + 0.5) - 1;
	if (joint_hint.w > 0.0 && kind >= 0 && (joint_hint_kinds & (1 << kind)) != 0) {
		// The head's own middle, so all of it fades in together.
		vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		float d = distance(centre, joint_hint.xyz);
		hint = 1.0 - smoothstep(joint_hint.w * 0.45, joint_hint.w, d);
	}
}

void fragment() {
	// Dull red, to orange, to near white at full heat.
	vec3 glow = mix(vec3(0.9, 0.15, 0.02), vec3(1.0, 0.75, 0.4), heat);
	vec3 base = albedo;
	float metal = metallic;
	float rough = roughness;
	if (instance_paint) {
		base = paint.rgb;
		metal = floor(paint.a) / 31.0;
		rough = fract(paint.a);
	}
	ALBEDO = mix(base, vec3(0.25, 0.12, 0.08), heat * 0.6);
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = glow * heat * heat * 6.0;
	float lit = max(joint_hint_color.a * hint, rest);
	if (lit > 0.0) {
		// A soft rim (brightest edge on) and a little fill, breathing slowly.
		float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float breathe = 0.85 + 0.15 * sin(TIME * 3.0);
		EMISSION += joint_hint_color.rgb * lit * breathe * (0.25 + rim * rim);
	}
	if (seized > 0.5) {
		// Through the glass, or inside the scan pulse's shell (VX8b) for everyone.
		float shown = survey_layer >= 0 && survey_through_glass(world_pos, CAMERA_POSITION_WORLD)
				? 1.0 : survey_pulse_at(world_pos);
		if (shown > 0.0) {
			ALBEDO = mix(ALBEDO, vec3(1.0, 0.7, 0.1), shown);
			EMISSION += vec3(1.0, 0.65, 0.05) * (2.0 + sin(TIME * 5.0)) * shown;
		}
	}
}
