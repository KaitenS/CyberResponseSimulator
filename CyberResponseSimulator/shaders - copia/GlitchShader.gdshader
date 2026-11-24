shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// =====================================================
// GLITCH
// =====================================================

uniform float glitch_amount : hint_range(0.0, 1.0) = 0.0;
uniform float glitch_speed : hint_range(1.0, 60.0) = 25.0;
uniform float rgb_shift : hint_range(0.0, 0.08) = 0.015;

// =====================================================
// VHS / CRT SHUTDOWN
// =====================================================

uniform float crt_shutdown : hint_range(0.0, 1.0) = 0.0;


// =====================================================
// RANDOM
// =====================================================

float random(float value) {
	return fract(
		sin(value * 12.9898) *
		43758.5453
	);
}


// =====================================================
// FRAGMENT
// =====================================================

void fragment() {

	vec2 uv = SCREEN_UV;

	// Imagen original
	vec4 normal_color = texture(
		screen_texture,
		uv
	);


	// =================================================
	// VHS / CRT SHUTDOWN
	// =================================================

	float shutdown = crt_shutdown;

	// Suavizado
	float shutdown_smooth = smoothstep(
		0.0,
		1.0,
		shutdown
	);


	// -------------------------------------------------
	// COMPRESIÓN VERTICAL
	// -------------------------------------------------

	float vertical_scale =
		1.0 - shutdown_smooth;

	// Evitamos que desaparezca demasiado rápido
	vertical_scale = max(
		vertical_scale,
		0.015
	);


	vec2 crt_uv = uv;

	crt_uv.y =
		0.5 +
		(uv.y - 0.5) *
		vertical_scale;


	// -------------------------------------------------
	// COMPRESIÓN HORIZONTAL
	// -------------------------------------------------

	// La compresión horizontal comienza
	// principalmente al final.
	float horizontal_progress =
		smoothstep(
			0.55,
			1.0,
			shutdown
		);


	float horizontal_scale =
		1.0 -
		horizontal_progress;


	horizontal_scale = max(
		horizontal_scale,
		0.008
	);


	crt_uv.x =
		0.5 +
		(uv.x - 0.5) *
		horizontal_scale;


	// =================================================
	// VHS DISTORTION
	// =================================================

	float vhs_strength =
		shutdown_smooth *
		0.035;


	float vhs_line =
		floor(uv.y * 180.0);


	float vhs_random =
		random(
			vhs_line +
			floor(TIME * 35.0)
		);


	float vhs_glitch =
		step(
			0.75,
			vhs_random
		);


	crt_uv.x +=
		sin(
			TIME * 80.0 +
			uv.y * 120.0
		)
		*
		vhs_strength
		*
		vhs_glitch;


	// =================================================
	// GLITCH
	// =================================================

	float time_step =
		floor(
			TIME *
			glitch_speed
		);


	float flicker_random =
		random(time_step);


	float flicker =
		step(
			0.45,
			flicker_random
		);


	// -------------------------------------------------
	// HORIZONTAL GLITCH
	// -------------------------------------------------

	float line =
		floor(
			uv.y *
			160.0
		);


	float line_random =
		random(
			line +
			time_step
		);


	float line_glitch =
		step(
			0.80,
			line_random
		);


	float displacement =
		sin(
			TIME * 70.0 +
			uv.y * 100.0
		)
		*
		0.035
		*
		line_glitch
		*
		flicker
		*
		glitch_amount;


	crt_uv.x += displacement;


	// -------------------------------------------------
	// GRANDES BLOQUES
	// -------------------------------------------------

	float block =
		floor(
			uv.y *
			25.0
		);


	float block_random =
		random(
			block +
			floor(TIME * 12.0)
		);


	float block_glitch =
		step(
			0.90,
			block_random
		);


	crt_uv.x +=
		sin(
			TIME * 30.0 +
			block
		)
		*
		0.06
		*
		block_glitch
		*
		glitch_amount;


	// =================================================
	// RGB SEPARATION
	// =================================================

	float rgb_amount =
		rgb_shift *
		glitch_amount;


	// Durante el apagado también queremos
	// un pequeño desplazamiento RGB.
	rgb_amount +=
		shutdown_smooth *
		0.012;


	float red =
		texture(
			screen_texture,
			crt_uv +
			vec2(rgb_amount, 0.0)
		).r;


	float green =
		texture(
			screen_texture,
			crt_uv
		).g;


	float blue =
		texture(
			screen_texture,
			crt_uv -
			vec2(rgb_amount, 0.0)
		).b;


	vec3 effect_color =
		vec3(
			red,
			green,
			blue
		);


	// =================================================
	// VHS SCANLINES
	// =================================================

	float scanline =
		sin(
			uv.y *
			180.0 *
			3.14159
		);


	scanline =
		scanline *
		0.5 +
		0.5;


	float scanline_strength =
		max(
			glitch_amount,
			shutdown_smooth
		);


	effect_color *=
		mix(
			1.0,
			0.82,
			scanline *
			scanline_strength
		);


	// =================================================
	// VHS STATIC
	// =================================================

	float static_noise =
		random(
			uv.x * 700.0 +
			uv.y * 400.0 +
			TIME * 80.0
		);


	float static_strength =
		smoothstep(
			0.35,
			0.95,
			shutdown
		);


	effect_color =
		mix(
			effect_color,
			vec3(static_noise),
			static_strength * 0.25
		);


	// =================================================
	// FLICKER
	// =================================================

	float dark_flicker =
		step(
			0.92,
			random(
				floor(
					TIME * 35.0
				)
			)
		);


	effect_color *=
		mix(
			1.0,
			0.30,
			dark_flicker *
			max(
				glitch_amount,
				shutdown_smooth
			)
		);


	// =================================================
	// CRT BRIGHT LINE
	// =================================================

	// Cuando la pantalla está casi apagada,
	// aparece una línea brillante en el centro.
	float line_progress =
		smoothstep(
			0.72,
			0.96,
			shutdown
		);


	float distance_from_center =
		abs(
			uv.y - 0.5
		);


	float horizontal_line =
		1.0 -
		smoothstep(
			0.0,
			0.025,
			distance_from_center
		);


	// La línea se hace visible solamente
	// durante la parte final.
	float crt_line =
		horizontal_line *
		line_progress;


	// =================================================
	// PUNTO CENTRAL
	// =================================================

	float point_progress =
		smoothstep(
			0.90,
			1.0,
			shutdown
		);


	float distance_from_point =
		distance(
			uv,
			vec2(0.5)
		);


	float central_point =
		1.0 -
		smoothstep(
			0.0,
			0.012,
			distance_from_point
		);


	// Color morado del CRT
	vec3 purple =
		vec3(
			0.65,
			0.25,
			1.0
		);


	effect_color =
		mix(
			effect_color,
			purple,
			crt_line * 0.85
		);


	effect_color =
		mix(
			effect_color,
			purple,
			central_point *
			point_progress
		);


	// =================================================
	// OSCURECER PROGRESIVAMENTE
	// =================================================

	float darkness =
		smoothstep(
			0.82,
			1.0,
			shutdown
		);


	effect_color *=
		1.0 -
		darkness;


	// =================================================
	// RESULTADO
	// =================================================

	// Cuando no hay ningún efecto,
	// usamos la imagen original.
	float effect_strength =
		max(
			glitch_amount,
			shutdown
		);


	vec3 final_color =
		mix(
			normal_color.rgb,
			effect_color,
			effect_strength
		);


	COLOR =
		vec4(
			final_color,
			normal_color.a
		);
}