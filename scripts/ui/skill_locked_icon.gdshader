shader_type canvas_item;
void fragment() {
    vec4 sampled = texture(TEXTURE, UV);
    float gray = dot(sampled.rgb, vec3(0.299, 0.587, 0.114));
    COLOR = vec4(vec3(gray), sampled.a * 0.72) * COLOR;
}
