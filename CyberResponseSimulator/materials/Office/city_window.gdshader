shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D distant_city : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D middle_city : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D near_city : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 window_size = vec2(2.1, 1.15);
uniform float parallax_strength : hint_range(0.0, 1.5) = 0.85;
uniform float panorama_offset : hint_range(0.0, 1.0) = 0.0;
uniform float exterior_brightness : hint_range(0.3, 1.5) = 0.92;
uniform vec4 sky_top : source_color = vec4(0.37,0.59,0.74,1.0);
uniform vec4 sky_horizon : source_color = vec4(0.79,0.85,0.86,1.0);
uniform float glass_reflection : hint_range(0.0, 0.2) = 0.035;
varying vec3 local_camera;
varying vec3 local_point;

void vertex(){
	local_camera = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
	local_point = VERTEX;
}

vec4 sample_city(sampler2D layer, vec2 uv){
	return texture(layer,vec2(fract(uv.x),clamp(uv.y,0.001,0.999)));
}

void fragment(){
	vec2 slope = (local_point.xy-local_camera.xy)/max(abs(local_camera.z),0.35);
	vec2 shift = clamp(vec2(slope.x,-slope.y),vec2(-1.8),vec2(1.8))*parallax_strength;
	vec2 uv = (UV-0.5)*window_size*vec2(0.18,0.30)+vec2(0.5+panorama_offset,0.49);
	float sky_mix = smoothstep(0.15,0.8,uv.y+shift.y*0.015);
	vec3 city = mix(sky_top.rgb,sky_horizon.rgb,sky_mix);
	vec4 distant = sample_city(distant_city,uv+shift*0.025);
	city = mix(city,distant.rgb,distant.a);
	vec4 middle = sample_city(middle_city,uv+shift*0.070);
	city = mix(city,middle.rgb,middle.a);
	vec4 near_layer = sample_city(near_city,uv+shift*0.160);
	city = mix(city,near_layer.rgb,near_layer.a);
	float reflection = smoothstep(0.40,0.48,UV.x+UV.y*0.6)*(1.0-smoothstep(0.50,0.65,UV.x+UV.y*0.6));
	ALBEDO = city*exterior_brightness + vec3(reflection*glass_reflection);
}