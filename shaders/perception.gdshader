shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float soul = 1.0;
uniform float rot = 0.0;
uniform float pulse = 0.0;
uniform float pain = 0.0;
uniform float clock = 0.0;

void fragment() {
	vec2 center = SCREEN_UV - vec2(0.5);
	float radius = length(center * vec2(1.0, 0.8));
	vec2 uv = SCREEN_UV - center * pulse * 0.12;
	vec3 scene = texture(screen_texture, uv).rgb;
	float grey = dot(scene, vec3(0.299, 0.587, 0.114));
	scene = mix(scene, vec3(grey) * vec3(0.83, 1.04, 1.12), soul * 0.95);
	float edge = smoothstep(0.22, 0.68, radius);
	scene *= 1.0 - edge * (0.46 + soul * 0.18);
	scene = mix(scene, vec3(0.24, 0.08, 0.20), edge * rot * (0.42 + 0.1 * sin(clock * 5.0)));
	scene += vec3(0.5, 1.0, 0.82) * pulse * (0.16 + edge * 0.65);
	scene += vec3(0.7, 0.055, 0.025) * pain * edge * 0.7;
	COLOR = vec4(scene, 1.0);
}
