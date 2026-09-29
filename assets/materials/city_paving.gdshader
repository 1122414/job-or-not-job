shader_type spatial;
render_mode diffuse_burley;

varying vec3 world_position;

float tile_random(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 tile = world_position.xz / vec2(1.2, 0.6);
	tile.x += mod(floor(tile.y), 2.0) * 0.5;
	vec2 edge = min(fract(tile), 1.0 - fract(tile)) * vec2(1.2, 0.6);
	vec2 pixel_width = max(fwidth(tile) * vec2(1.2, 0.6), vec2(0.001));
	vec2 lines = 1.0 - smoothstep(vec2(0.004) - pixel_width, vec2(0.008) + pixel_width, edge);
	float joint = 1.0 - max(lines.x, lines.y);
	float variation = tile_random(floor(tile));
	float grain = tile_random(floor(world_position.xz * 90.0));
	float grain_weight = 1.0 - smoothstep(0.005, 0.03, length(fwidth(world_position.xz)));
	vec3 stone = vec3(0.53, 0.53, 0.48) + (variation - 0.5) * 0.055 + (grain - 0.5) * 0.018 * grain_weight;
	ALBEDO = mix(vec3(0.28, 0.30, 0.28), stone, joint);
	ROUGHNESS = 0.86;
}
