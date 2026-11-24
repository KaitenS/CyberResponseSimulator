shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 tile = fract(world_position.xz / 0.6);
	vec2 distance_to_edge = min(tile, vec2(1.0) - tile);
	float seam = 1.0 - smoothstep(0.006, 0.014, min(distance_to_edge.x, distance_to_edge.y));
	float grain = fract(sin(dot(floor(world_position * 180.0), vec3(12.9898,78.233,35.71))) * 43758.5453);
	ALBEDO = mix(vec3(0.78,0.79,0.75), vec3(0.48,0.52,0.50), seam) * (0.985 + grain * 0.025);
	ROUGHNESS = 0.95;
}
