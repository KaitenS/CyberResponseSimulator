shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.035;
uniform float rgb_shift : hint_range(0.0, 0.03) = 0.0025;
uniform float distortion : hint_range(0.0, 0.05) = 0.003;


float random(vec2 uv) {
	return fract(
		sin(dot(uv, vec2(12.9898, 78.233)))
		* 43758.5453
	);
}


void fragment() {

	vec2 uv = SCREEN_UV;


	// ================================================
	// DISTORSIÓN HORIZONTAL
	// ================================================

	float wave = sin(
		uv.y * 35.0 +
		TIME * 3.0
	);

	uv.x += wave * distortion;


	// ================================================
	// RGB SEPARATION
	// ================================================

	float red = texture(
		screen_texture,
		uv + vec2(rgb_shift, 0.0)
	).r;

	float green = texture(
		screen_texture,
		uv
	).g;

	float blue = texture(
		screen_texture,
		uv - vec2(rgb_shift, 0.0)
	).b;


	vec3 color = vec3(
		red,
		green,
		blue
	);


	// ================================================
	// SCANLINES
	// ================================================

	float scanline = sin(
		uv.y * 900.0
	);

	scanline = scanline * 0.5 + 0.5;

	color *= 1.0 -
		scanline *
		scanline_strength;


	// ================================================
	// VHS NOISE
	// ================================================

	vec2 noise_uv = vec2(
		floor(uv.x * 600.0),
		floor(uv.y * 400.0)
	);

	float noise = random(
		noise_uv +
		TIME * 10.0
	);

	noise = noise * 2.0 - 1.0;

	color +=
		noise *
		noise_strength;


	// ================================================
	// HORIZONTAL VHS BANDS
	// ================================================

	float band = sin(
		uv.y * 18.0 -
		TIME * 2.0
	);

	band = smoothstep(
		0.65,
		0.9,
		band
	);

	color += band * 0.08;


	// ================================================
	// OUTPUT
	// ================================================

	COLOR = vec4(
		color,
		1.0
	);
}