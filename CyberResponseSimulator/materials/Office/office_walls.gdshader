shader_type spatial;
render_mode diffuse_burley;
uniform vec4 upper_color : source_color = vec4(0.78,0.79,0.73,1.0);
uniform vec4 lower_color : source_color = vec4(0.39,0.48,0.48,1.0);
uniform float trim_height = 0.85;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float h=world_position.y;
	vec3 paint=mix(lower_color.rgb,upper_color.rgb,smoothstep(trim_height,trim_height+0.025,h));
	float fleck=fract(sin(dot(floor(world_position*220.0),vec3(12.9898,78.233,35.71)))*43758.5453);
	paint*=0.98+fleck*0.025;
	if(abs(h-trim_height)<0.018){paint=vec3(0.65,0.70,0.67);}
	if(h<0.14){paint=vec3(0.22,0.29,0.29);}
	ALBEDO=paint;
	ROUGHNESS=0.9;
}