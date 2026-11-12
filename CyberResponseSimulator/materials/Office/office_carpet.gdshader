shader_type spatial;
uniform vec4 carpet_color : source_color = vec4(0.18,0.28,0.31,1.0);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 p=world_position.xz;
	float grain=fract(sin(dot(floor(p*260.0),vec2(12.9898,78.233)))*43758.5453);
	float weave=sin(p.x*900.0)*sin(p.y*900.0)*0.018;
	vec2 tile=fract(p/0.6);
	float seam=1.0-step(0.004,min(min(tile.x,tile.y),min(1.0-tile.x,1.0-tile.y)));
	ALBEDO=carpet_color.rgb*(0.94+grain*0.1+weave-seam*0.06);
	ROUGHNESS=1.0;
}