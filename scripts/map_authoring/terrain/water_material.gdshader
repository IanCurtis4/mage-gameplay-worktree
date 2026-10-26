shader_type canvas_item;
render_mode unshaded;
uniform sampler2D water_tile : source_color, repeat_enable, filter_linear_mipmap;
uniform float tile_units = 128.0;
varying vec3 world_position;
void vertex() { world_position = CUSTOM0.xyz; }
void fragment() {
	vec2 uv = world_position.xz/tile_units;
	uv = 1.0 - abs(mod(uv,vec2(2.0))-1.0);
	COLOR = vec4(texture(water_tile,uv).rgb,1.0);
}
