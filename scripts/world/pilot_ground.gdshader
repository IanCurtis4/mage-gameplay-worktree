shader_type canvas_item;
render_mode unshaded;

uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D stone_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 ground_size = vec2(1640.0, 920.0);

// Reflected repeats keep unmatched generated edges continuous until authored
// transition tiles replace this pilot. No sampling outside the source texture.
vec2 tile_uv(vec2 value) {
	return abs(fract(value * 0.5) * 2.0 - 1.0);
}

void fragment() {
	vec2 point = UV * ground_size;
	vec2 iso = vec2(point.x * 0.5 + point.y, point.x * -0.5 + point.y);
	vec3 grass = texture(grass_texture, tile_uv(iso / 192.0)).rgb;
	vec3 dirt = texture(dirt_texture, tile_uv(iso / 224.0)).rgb;
	vec3 stone = texture(stone_texture, tile_uv(iso / 256.0)).rgb;
	float grain = texture(grass_texture, tile_uv(point / 413.0)).g;
	float edge = (grain - 0.35) * 92.0;
	float trail_y = ground_size.y * 0.52 + sin(point.x * 0.006) * 88.0;
	float path_mask = 1.0 - smoothstep(68.0 + edge, 135.0 + edge, abs(point.y - trail_y));
	float spur = abs(point.x - ground_size.x * 0.56 + sin(point.y * 0.009) * 48.0);
	path_mask = max(path_mask, 1.0 - smoothstep(45.0 + edge, 96.0 + edge, spur));
	vec2 plaza_point = (point - ground_size * vec2(0.58, 0.51)) / vec2(270.0, 190.0);
	float plaza = 1.0 - smoothstep(0.68, 1.06, length(plaza_point) + (grain - 0.35) * 0.32);
	vec3 ground = mix(mix(grass, dirt, path_mask), stone, plaza);
	// Gentle unification leaves room for cyan/gold targeting and warm silhouettes.
	COLOR = vec4(mix(ground, vec3(0.20, 0.25, 0.22), 0.16), 1.0);
}
