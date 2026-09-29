shader_type spatial;

varying vec3 world_position;

float random_value(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_value(vec2 point) {
	vec2 cell = floor(point);
	vec2 weight = smoothstep(vec2(0.0), vec2(1.0), fract(point));
	return mix(mix(random_value(cell), random_value(cell + vec2(1.0, 0.0)), weight.x),
		mix(random_value(cell + vec2(0.0, 1.0)), random_value(cell + vec2(1.0)), weight.x), weight.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float patches = noise_value(world_position.xz * 0.6);
	float fine = noise_value(world_position.xz * 65.0);
	float fine_weight = 1.0 - smoothstep(0.008, 0.04, length(fwidth(world_position.xz)));
	ALBEDO = mix(vec3(0.24, 0.31, 0.16), vec3(0.39, 0.43, 0.24), patches) + (fine - 0.5) * 0.075 * fine_weight;
	ROUGHNESS = 0.95;
}
