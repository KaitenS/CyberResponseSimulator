shader_type spatial;
uniform vec4 tile_color : source_color = vec4(0.56,0.59,0.58,1.0);
uniform vec4 grout_color : source_color = vec4(0.29,0.34,0.34,1.0);
uniform float tile_size = 0.6;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=world_position.xz/tile_size;
	vec2 cell=fract(p);
	float seam=1.0-step(0.013,min(min(cell.x,cell.y),min(1.0-cell.x,1.0-cell.y)));
	float alternate=mod(floor(p.x)+floor(p.y),2.0);
	float grain=fract(sin(dot(floor(world_position.xz*180.0),vec2(12.9898,78.233)))*43758.5453);
	vec3 tile=tile_color.rgb*(0.97+alternate*0.025+grain*0.025);
	ALBEDO=mix(tile,grout_color.rgb,seam);
	ROUGHNESS=0.72;
}