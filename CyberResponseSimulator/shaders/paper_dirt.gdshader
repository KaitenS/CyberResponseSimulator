shader_type canvas_item;

uniform float dirtiness : hint_range(0.0, 1.0) = 0.0;
uniform vec4 stain_color : source_color = vec4(0.42, 0.30, 0.16, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float n = fbm(UV * vec2(8.0, 5.0));
	float threshold = 1.0 - dirtiness * 0.65;
	float stain = smoothstep(threshold - 0.08, threshold + 0.08, n);
	float grain = fbm(UV * vec2(60.0, 40.0));
	float alpha = stain * (0.35 + 0.4 * grain) * step(0.001, dirtiness);
	COLOR = vec4(stain_color.rgb, alpha);
}