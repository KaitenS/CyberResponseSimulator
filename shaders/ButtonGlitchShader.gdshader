shader_type canvas_item;

uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rgb_split : hint_range(0.0, 0.05) = 0.012;
uniform float slice_amount : hint_range(0.0, 0.1) = 0.02;


float random(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}


void fragment() {

	vec2 uv = UV;

	// ==========================================
	// RANDOM PARA LAS LINEAS
	// ==========================================

	float line = floor(uv.y * 25.0);

	float noise = random(
		line + floor(TIME * 35.0)
	);


	// ==========================================
	// HORIZONTAL SLICE
	// ==========================================

	if (
		noise > 0.82 &&
		glitch_amount > 0.01
	) {

		float offset =
			(noise - 0.5)
			*
			slice_amount
			*
			glitch_amount;

		uv.x += offset;
	}


	// ==========================================
	// RGB SPLIT
	// ==========================================

	float split =
		rgb_split *
		glitch_amount;


	float red = texture(
		TEXTURE,
		uv + vec2(split, 0.0)
	).r;


	float green = texture(
		TEXTURE,
		uv
	).g;


	float blue = texture(
		TEXTURE,
		uv - vec2(split, 0.0)
	).b;


	float alpha = texture(
		TEXTURE,
		uv
	).a;


	// ==========================================
	// RESULTADO
	// ==========================================

	COLOR = vec4(
		red,
		green,
		blue,
		alpha
	);
}