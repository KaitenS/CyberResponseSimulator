shader_type canvas_item;

// ==============================
// COLORES
// ==============================

uniform vec4 color_1 : source_color = vec4(0.025, 0.008, 0.055, 1.0);
uniform vec4 color_2 : source_color = vec4(0.12, 0.025, 0.22, 1.0);
uniform vec4 color_3 : source_color = vec4(0.38, 0.08, 0.55, 1.0);

// ==============================
// MOVIMIENTO
// ==============================

uniform float speed : hint_range(0.0, 2.0) = 0.12;
uniform float rotation_speed : hint_range(-2.0, 2.0) = 0.08;

// ==============================
// APARIENCIA
// ==============================

uniform float contrast : hint_range(0.1, 5.0) = 1.4;
uniform float lighting : hint_range(0.0, 2.0) = 0.3;

uniform float pixel_size : hint_range(16.0, 512.0) = 96.0;

uniform float swirl : hint_range(0.0, 5.0) = 1.0;


// ==============================
// ROTACIÓN
// ==============================

mat2 rotate(float angle)
{
    float s = sin(angle);
    float c = cos(angle);

    return mat2(
        vec2(c, -s),
        vec2(s, c)
    );
}


// ==============================
// FRAGMENT
// ==============================

void fragment()
{
    // UV va de 0 a 1
    vec2 uv = UV;

    // Centramos las coordenadas
    uv -= vec2(0.5);

    // Como nuestro proyecto es 1280x720,
    // corregimos la proporción 16:9.
    uv.x *= 1.7777778;


    // ==============================
    // PIXELACIÓN
    // ==============================

    uv = floor(uv * pixel_size) / pixel_size;


    // ==============================
    // TIEMPO
    // ==============================

    float t = TIME * speed;


    // ==============================
    // ROTACIÓN
    // ==============================

    uv = rotate(t * rotation_speed) * uv;


    // ==============================
    // REMOLINO
    // ==============================

    vec2 p = uv;

    float radius = length(p);
    float angle = atan(p.y, p.x);

    angle += radius * swirl * 4.0;
    angle += t * 0.5;

    p = vec2(
        cos(angle),
        sin(angle)
    ) * radius;


    // ==============================
    // WARPING
    // ==============================

    vec2 warped = p;
    vec2 warp_accum = p;

    for (int i = 0; i < 5; i++)
    {
        warp_accum += sin(
            max(warped.x, warped.y)
            + float(i) * 0.7
            + t * 0.25
        ) * 0.15;

        warped += 0.5 * vec2(
            cos(
                5.1123314
                + 0.353 * warp_accum.y
                + t * 0.131121
            ),

            sin(
                warp_accum.x
                - 0.113 * t
            )
        );

        warped -= vec2(
            cos(warped.x + warped.y),
            sin(warped.x * 0.711 - warped.y)
        ) * 0.12;
    }


    // ==============================
    // DISTANCIA
    // ==============================

    float dist = length(warped);


    // ==============================
    // MEZCLA DE COLORES
    // ==============================

    float paint_res = clamp(
        dist * 3.5 * contrast,
        0.0,
        2.0
    );

    float c1p = max(
        0.0,
        1.0 - contrast * abs(1.0 - paint_res)
    );

    float c2p = max(
        0.0,
        1.0 - contrast * abs(paint_res)
    );

    float c3p = 1.0 - min(
        1.0,
        c1p + c2p
    );


    // ==============================
    // NORMALIZAR
    // ==============================

    float total = c1p + c2p + c3p;

    if (total > 0.0)
    {
        c1p /= total;
        c2p /= total;
        c3p /= total;
    }


    // ==============================
    // COLOR FINAL
    // ==============================

    vec3 final_color =
        color_1.rgb * c1p +
        color_2.rgb * c2p +
        color_3.rgb * c3p;


    // ==============================
    // ILUMINACIÓN
    // ==============================

    float light =
        lighting *
        max(c1p * 5.0 - 4.0, 0.0);

    light +=
        lighting *
        max(c2p * 5.0 - 4.0, 0.0);

    final_color += light;


    // ==============================
    // VIÑETA
    // ==============================

    float vignette = 1.0 - smoothstep(
        0.25,
        0.85,
        length(uv)
    );

    final_color *= mix(
        0.65,
        1.0,
        vignette
    );


    // ==============================
    // RESULTADO
    // ==============================

    COLOR = vec4(
        final_color,
        1.0
    );
}