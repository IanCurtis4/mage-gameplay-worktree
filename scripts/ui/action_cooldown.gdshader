shader_type canvas_item;
uniform float elapsed_fraction : hint_range(0.0, 1.0) = 1.0;
uniform bool cooling_down = false;
uniform bool unavailable = false;
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	if (unavailable) {
		float gray = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
		texel.rgb = mix(texel.rgb, vec3(gray), 0.8) * 0.55;
	}
	if (cooling_down) {
		vec2 point = UV - vec2(0.5);
		float phase = mod(atan(point.y, point.x) + 1.57079633 + 6.28318531, 6.28318531) / 6.28318531;
		float ahead = phase - elapsed_fraction;
		float shadow = step(0.0, ahead) * mix(0.32, 0.62, smoothstep(0.0, 0.12, ahead));
		texel.rgb *= 1.0 - shadow;
		float edge = step(0.0, ahead) * (1.0 - smoothstep(0.0, 0.009, ahead));
		texel.rgb = mix(texel.rgb, vec3(0.93, 0.86, 0.64), edge * 0.65);
	}
	COLOR = texel;
}
