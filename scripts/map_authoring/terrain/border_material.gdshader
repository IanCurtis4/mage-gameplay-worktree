shader_type canvas_item;
render_mode unshaded;
uniform sampler2D grass_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D earth_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D sand_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D stone_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform float tile_units = 128.0;
varying vec4 paint_weights;
varying vec3 world_position;
varying vec3 world_normal;
vec2 mirrored(vec2 value) { return 1.0 - abs(mod(value,vec2(2.0))-1.0); }
vec3 sample_world(sampler2D tile, vec3 p, vec3 axes) {
	return texture(tile,mirrored(p.zy)).rgb*axes.x + texture(tile,mirrored(p.xz)).rgb*axes.y + texture(tile,mirrored(p.xy)).rgb*axes.z;
}
void vertex() {
	paint_weights = COLOR; world_position = CUSTOM0.xyz; world_normal = CUSTOM1.xyz;
}
void fragment() {
	vec4 weights = max(paint_weights,vec4(0.0));
	weights /= max(dot(weights,vec4(1.0)),0.00001);
	vec3 normal = normalize(world_normal);
	vec3 axes = pow(abs(normal),vec3(4.0)); axes /= max(dot(axes,vec3(1.0)),0.00001);
	vec3 p = world_position/tile_units;
	vec3 albedo = sample_world(grass_tile,p,axes)*weights.r + sample_world(earth_tile,p,axes)*weights.g + sample_world(sand_tile,p,axes)*weights.b + sample_world(stone_tile,p,axes)*weights.a;
	float shade = 0.65 + 0.35*max(0.0,dot(normal,normalize(vec3(-0.3,0.8,-0.5))));
	COLOR = vec4(albedo*shade,1.0);
}
