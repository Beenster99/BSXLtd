shader_type spatial;
// Rivet heads, bolt heads, weld beads, loom plugs, sheared stubs and weld scars: drawn in
// batches (one MultiMesh per mesh and material on each structure, see JointBatch), so a
// wreck's thousands of joints cost a handful of draw calls. Heat comes per instance:
// INSTANCE_CUSTOM.x is 0 cold .. 1 glowing hot (a tool working the joint); .y is 1 on a seized
// bolt, which glows amber through the pilot's survey glass.

render_mode cull_back;

uniform vec3 albedo : source_color = vec3(0.6);
uniform float metallic = 0.8;
uniform float roughness = 0.35;

#include "res://shared/void_salvage/shaders/survey_glass.gdshaderinc"

varying float heat;
varying float seized;
varying vec3 world_pos;

void vertex() {
	heat = INSTANCE_CUSTOM.x;
	seized = INSTANCE_CUSTOM.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Dull red, to orange, to near white at full heat.
	vec3 glow = mix(vec3(0.9, 0.15, 0.02), vec3(1.0, 0.75, 0.4), heat);
	ALBEDO = mix(albedo, vec3(0.25, 0.12, 0.08), heat * 0.6);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = glow * heat * heat * 6.0;
	if (seized > 0.5 && survey_layer >= 0 && survey_through_glass(world_pos, CAMERA_POSITION_WORLD)) {
		ALBEDO = vec3(1.0, 0.7, 0.1);
		EMISSION += vec3(1.0, 0.65, 0.05) * (2.0 + sin(TIME * 5.0));
	}
}
