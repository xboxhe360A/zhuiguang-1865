shader_type canvas_item;

// 证据饱和度：0 = 全灰（证据缺失），1 = 原色（证据完整）。
uniform float saturation : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luma), src.rgb, saturation);
	COLOR = vec4(graded, src.a);
}
