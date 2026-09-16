shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(0.2, 0.25, 0.3, 1.0);
uniform float soul = 0.0;
uniform vec3 glow_color : source_color = vec3(0.0);
void fragment() {
	float grey = dot(base_color.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(base_color.rgb, vec3(grey) * vec3(0.85, 1.0, 1.1), soul);
	ROUGHNESS = 0.85;
	EMISSION = mix(glow_color, vec3(dot(glow_color, vec3(0.299, 0.587, 0.114))), soul);
}
