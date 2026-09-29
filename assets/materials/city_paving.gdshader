shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D surface_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D surface_arm : filter_linear_mipmap_anisotropic, repeat_enable;
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
	vec2 surface_uv = world_position.xz * 0.5;
	vec3 grain = texture(surface_color, surface_uv).rgb;
	vec3 arm = texture(surface_arm, surface_uv).rgb;
	vec3 stone = mix(vec3(0.40, 0.42, 0.39), grain, 0.32) * (0.96 + (variation - 0.5) * 0.12);
	ALBEDO = mix(vec3(0.18, 0.19, 0.17), stone, joint);
	NORMAL_MAP = texture(surface_normal, surface_uv).rgb;
	NORMAL_MAP_DEPTH = 0.45;
	AO = mix(0.7, arm.r, joint);
	ROUGHNESS = clamp(arm.g, 0.65, 1.0);
}
