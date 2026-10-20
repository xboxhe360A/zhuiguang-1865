shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 1.0) = 0.35;
uniform float grain_scale = 22.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	float luma = dot(src.rgb, vec3(0.2126, 0.7152, 0.0722));
	vec3 graded = mix(vec3(luma), src.rgb, saturation);
	vec3 latent = vec3(luma) * 0.32 + vec3(0.014, 0.045, 0.055);

	float n = value_noise(UV * vec2(grain_scale, grain_scale * 1.6)) * 0.72;
	n += value_noise(UV * vec2(grain_scale * 2.7)) * 0.28;

	float threshold = progress * 1.08;
	float latent_mask = smoothstep(threshold - 0.05, threshold + 0.05, n);
	vec3 col = mix(graded, latent, latent_mask);
	col = mix(latent, col, smoothstep(0.0, 0.25, progress));
	COLOR = vec4(col, src.a);
}
