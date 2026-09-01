shader_type canvas_item;

// =====================================================
// COLORES
// =====================================================

uniform vec4 color_1 : source_color = vec4(0.035, 0.008, 0.08, 1.0);
uniform vec4 color_2 : source_color = vec4(0.18, 0.025, 0.38, 1.0);
uniform vec4 color_3 : source_color = vec4(0.55, 0.08, 0.85, 1.0);


// =====================================================
// CONFIGURACIÓN
// =====================================================

uniform float speed : hint_range(0.0, 2.0) = 0.15;
uniform float distortion : hint_range(0.0, 5.0) = 1.5;
uniform float contrast : hint_range(0.1, 3.0) = 1.2;
uniform float swirl : hint_range(0.0, 5.0) = 1.5;


// =====================================================
// MAIN
// =====================================================

void fragment() {

	// UV centrado
	vec2 uv = UV - vec2(0.5);


	// Corregir proporción de pantalla
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;

	uv.x *= aspect;


	// Tiempo
	float t = TIME * speed;


	// Distancia y ángulo
	float radius = length(uv);

	float angle = atan(
		uv.y,
		uv.x
	);


	// =================================================
	// REMOLINO
	// =================================================

	angle +=
		sin(
			radius * 5.0 -
			t
		)
		*
		swirl;


	// Convertir nuevamente a coordenadas
	vec2 warped_uv = vec2(
		cos(angle),
		sin(angle)
	)
	*
	radius;


	// =================================================
	// DISTORSIÓN
	// =================================================

	float wave_1 =
		sin(
			warped_uv.x * 5.0 +
			t
		);


	float wave_2 =
		cos(
			warped_uv.y * 6.0 -
			t * 0.8
		);


	float wave_3 =
		sin(
			(warped_uv.x + warped_uv.y) * 4.0 +
			t * 0.6
		);


	float pattern =
		(
			wave_1 +
			wave_2 +
			wave_3 * distortion
		)
		/
		(2.0 + distortion);


	// =================================================
	// MASAS
	// =================================================

	float blob_1 =
		sin(
			radius * 8.0 +
			pattern * 5.0 -
			t
		);


	float blob_2 =
		cos(
			angle * 5.0 +
			radius * 6.0 +
			t * 0.7
		);


	float blob =
		(
			blob_1 +
			blob_2
		)
		*
		0.5;


	// =================================================
	// NORMALIZAR
	// =================================================

	float value =
		blob * 0.5 +
		0.5;


	value =
		clamp(
			value,
			0.0,
			1.0
		);


	value =
		pow(
			value,
			contrast
		);


	// =================================================
	// COLOR
	// =================================================

	vec3 final_color;


	if (value < 0.5) {

		final_color =
			mix(
				color_1.rgb,
				color_2.rgb,
				value * 2.0
			);

	} else {

		final_color =
			mix(
				color_2.rgb,
				color_3.rgb,
				(value - 0.5) * 2.0
			);
	}


	// =================================================
	// VIÑETA
	// =================================================

	float vignette =
		1.0 -
		smoothstep(
			0.25,
			0.85,
			radius
		);


	final_color *=
		mix(
			0.65,
			1.0,
			vignette
		);


	// =================================================
	// OUTPUT
	// =================================================

	COLOR =
		vec4(
			final_color,
			1.0
		);
}