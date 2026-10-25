shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grass_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D earth_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform vec4 layer_tint : source_color = vec4(1.0);
void fragment() {
	// Mirror each repeat to make its sampled border continuous, including authored edges.
	vec2 tiled = 1.0 - abs(mod(UV, vec2(2.0)) - 1.0);
	vec3 grass = texture(grass_tile, tiled).rgb;
	vec3 earth = texture(earth_tile, tiled).rgb;
	vec3 painted = mix(grass, earth, clamp(COLOR.r, 0.0, 1.0));
	float gray = dot(earth, vec3(0.299, 0.587, 0.114));
	vec3 rocky = gray * vec3(0.60, 0.62, 0.65);
	COLOR = vec4(mix(painted, rocky, clamp(COLOR.b, 0.0, 1.0)) * COLOR.g * layer_tint.rgb, layer_tint.a);
}
