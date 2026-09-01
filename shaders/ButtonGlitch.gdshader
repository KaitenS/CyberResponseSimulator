shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float rgb_split : hint_range(0.0, 0.03) = 0.012;
uniform float slice_strength : hint_range(0.0, 0.08) = 0.025;


float random(float value) {
	return fract(
		sin(value * 12.9898) *
		43758.5453
	);
}


void fragment() {

	// ==========================================
	// COORDENADAS DE PANTALLA
	// ==========================================

	vec2 screen_uv = SCREEN_UV;


	// ==========================================
	// GLITCH HORIZONTAL
	// ==========================================

	float slice = floor(UV.y * 20.0);

	float noise = random(
		slice +
		floor(TIME * 40.0)
	);


	if (
		noise > 0.82 &&
		glitch_amount > 0.01
	) {

		float offset =
			(noise - 0.5)
			*
			slice_strength
			*
			glitch_amount;

		screen_uv.x += offset;
	}


	// ==========================================
	// RGB SPLIT
	// ==========================================

	float split =
		rgb_split *
		glitch_amount;


	vec4 red = texture(
		screen_texture,
		screen_uv + vec2(split, 0.0)
	);


	vec4 green = texture(
		screen_texture,
		screen_uv
	);


	vec4 blue = texture(
		screen_texture,
		screen_uv - vec2(split, 0.0)
	);


	// ==========================================
	// COMBINAR RGB
	// ==========================================

	vec3 final_color;

	final_color.r = red.r;
	final_color.g = green.g;
	final_color.b = blue.b;


	// ==========================================
	// ALPHA
	// ==========================================

	float alpha = glitch_amount;


	COLOR = vec4(		final_color,
		alpha
	);
}