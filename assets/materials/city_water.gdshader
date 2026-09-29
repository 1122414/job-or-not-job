shader_type spatial;
render_mode diffuse_burley;

uniform float wave_time = 0.0;
uniform float daylight = 1.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float a = dot(p, vec2(0.7, 0.4)) + wave_time * 0.7;
	float b = dot(p, vec2(-0.35, 1.1)) - wave_time * 0.55;
	float detail = 1.0 - smoothstep(0.25, 1.6, length(fwidth(p)));
	vec2 slope = (vec2(cos(a), sin(b)) * 0.12 + vec2(sin(b * 2.7), cos(a * 2.1)) * 0.035) * detail;
	NORMAL_MAP = normalize(vec3(slope, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	float horizon = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	vec3 sea = mix(vec3(0.045, 0.16, 0.19), vec3(0.22, 0.36, 0.39), horizon);
	ALBEDO = sea * mix(0.32, 1.0, daylight);
	ROUGHNESS = 0.28;
	SPECULAR = 0.65;
}
