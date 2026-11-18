shader_type spatial;

uniform vec3 start;
uniform vec3 control_a;
uniform vec3 control_b;
uniform float neck = 0.07;
uniform float width = 0.65;
uniform float rail_offset = 0.0;
uniform vec3 glow = vec3(0.0);

void vertex() {
	bool rail = abs(rail_offset) > 0.001;
	float t = clamp(VERTEX.y + (rail ? 0.5 : 0.0), 0.0, 1.0);
	float q = min(t / 0.85, 1.0);
	float u = 1.0 - q;
	vec3 end = vec3(0.0, 0.0, neck);
	vec3 center = u*u*u*start + 3.0*u*u*q*control_a + 3.0*u*q*q*control_b + q*q*q*end;
	vec3 along = normalize(3.0*u*u*(control_a-start) + 6.0*u*q*(control_b-control_a) + 3.0*q*q*(end-control_b));
	if (t >= 0.85) { center = end * ((1.0-t)/0.15); along = vec3(0.0, 0.0, -1.0); }
	vec3 plane = vec3(control_a.y, -control_a.x, 0.0);
	plane = length(plane) > 0.0001 ? normalize(plane) : vec3(1.0, 0.0, 0.0);
	float twist = atan(plane.y, plane.x) * smoothstep(0.0, 0.85, t);
	plane = normalize(plane - along * dot(plane, along));
	vec3 across = plane * cos(twist) + cross(along, plane) * sin(twist);
	vec3 depth = normalize(cross(across, along));
	// Flatten the socket end to the palm's shallow wrist opening.
	float flatten = mix(1.0, 0.6, smoothstep(0.7, 1.0, t));
	VERTEX = center + across * (VERTEX.x + rail_offset) * width + depth * VERTEX.z * width * flatten;
	NORMAL = normalize(across * NORMAL.x + along * NORMAL.y + depth * NORMAL.z / flatten);
}

void fragment() {
	bool rail = abs(rail_offset) > 0.001;
	ALBEDO = rail ? vec3(0.38, 0.43, 0.46) : vec3(0.055, 0.065, 0.07);
	METALLIC = rail ? 0.85 : 0.15;
	ROUGHNESS = rail ? 0.24 : 0.75;
	EMISSION = rail ? vec3(0.0) : glow;
}
