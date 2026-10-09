shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

void fragment() {
	vec2 uv = UV;

	// Líneas CRT
	float scanlines = sin(uv.y * 500.0) * 0.06;

	// Viñeta
	vec2 centered = uv - vec2(0.5);
	float vignette = dot(centered, centered) * 0.7;

	// Ruido sutil
	float noise = fract(
		sin(dot(uv * (TIME + 1.0), vec2(12.9898, 78.233)))
		* 43758.5453
	);

	noise = (noise - 0.5) * 0.035;

	float effect = scanlines + vignette + noise;

	ALBEDO = vec3(effect);
	ALPHA = 0.20;
}