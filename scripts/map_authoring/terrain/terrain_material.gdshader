shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grass_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D earth_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D sand_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D stone_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer_tint : source_color = vec4(1.0);
uniform float tile_units = 128.0;
varying vec4 paint_weights;
varying vec3 terrain_position;
varying vec3 terrain_normal;

vec2 mirrored(vec2 value) {
	return 1.0 - abs(mod(value, vec2(2.0)) - 1.0);
}

void vertex() {
	paint_weights = COLOR;
	terrain_position = CUSTOM0.xyz;
	terrain_normal = CUSTOM1.xyz;
}

void fragment() {
	vec4 weights = max(paint_weights, vec4(0.0));
	float total = dot(weights, vec4(1.0));
	weights = total > 0.000001 ? weights / total : vec4(1.0, 0.0, 0.0, 0.0);
	vec3 normal = normalize(terrain_normal);
	float gradient = length(normal.xz) / max(abs(normal.y), 0.00001);
	float rock_transition = smoothstep(0.50, 1.0, gradient);
	weights.rgb *= 1.0 - rock_transition;
	weights.a = 1.0 - dot(weights.rgb, vec3(1.0));
	vec3 coordinates = terrain_position / tile_units;
	vec2 ground_uv = mirrored(coordinates.xz);
	vec3 grass = texture(grass_tile, ground_uv).rgb;
	vec3 earth = texture(earth_tile, ground_uv).rgb;
	vec3 sand = texture(sand_tile, ground_uv).rgb;
	vec3 axes = pow(abs(normal), vec3(4.0));
	axes /= max(dot(axes, vec3(1.0)), 0.00001);
	vec3 stone = texture(stone_tile, mirrored(coordinates.zy)).rgb * axes.x
		+ texture(stone_tile, ground_uv).rgb * axes.y
		+ texture(stone_tile, mirrored(coordinates.xy)).rgb * axes.z;
	float shade = 0.65 + 0.35 * max(0.0, dot(normal, normalize(vec3(-0.3, 0.8, -0.5))));
	vec3 albedo = grass * weights.r + earth * weights.g + sand * weights.b + stone * weights.a;
	COLOR = vec4(albedo * shade * layer_tint.rgb, layer_tint.a);
}
