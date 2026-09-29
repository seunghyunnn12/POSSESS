shader_type spatial;
render_mode diffuse_burley;
// Static architecture: procedural stone. pattern 0 = flat colour (brass, trims),
// 1 = masonry (bricks on walls, flagstones on floors) in world space.
uniform vec4 base_color : source_color = vec4(0.2, 0.25, 0.3, 1.0);
uniform float soul = 0.0;
uniform vec3 glow_color : source_color = vec3(0.0);
uniform int pattern = 0;
uniform vec3 moss : source_color = vec3(0.16, 0.2, 0.14);
varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 colour = base_color.rgb;
	float rough = 0.85;
	if (pattern == 1) {
		vec3 n = abs(world_normal);
		vec2 uv;
		vec2 cell_size;
		float grout = 0.035;
		if (n.y > 0.6) {
			// Flagstones: large offset slabs.
			uv = world_pos.xz;
			cell_size = vec2(1.6, 1.1);
			uv.x += step(1.0, mod(floor(uv.y / cell_size.y), 2.0)) * 0.8;
			grout = 0.045;
		} else {
			// Bricks: along the wall, rows offset every other course.
			uv = vec2(n.x > n.z ? world_pos.z : world_pos.x, world_pos.y);
			cell_size = vec2(0.92, 0.42);
			uv.x += step(1.0, mod(floor(uv.y / cell_size.y), 2.0)) * 0.46;
		}
		vec2 cell = floor(uv / cell_size);
		vec2 local = fract(uv / cell_size) * cell_size;
		vec2 edge = min(local, cell_size - local);
		float mortar = 1.0 - smoothstep(grout * 0.4, grout, min(edge.x, edge.y));
		float stone_tint = 0.78 + hash(cell) * 0.34;
		float grime = fbm(uv * 1.7);
		colour = base_color.rgb * stone_tint * (0.75 + grime * 0.5);
		colour = mix(colour, base_color.rgb * 0.35, mortar);
		// Damp moss creeping up from the floor line and in the joints.
		float damp = (1.0 - smoothstep(0.0, 1.4, world_pos.y)) * step(n.y, 0.6);
		colour = mix(colour, moss, clamp(damp * fbm(uv * 3.1) * 1.2 + mortar * 0.25 * grime, 0.0, 0.6));
		// Soot darkening near the ceiling.
		colour *= 1.0 - smoothstep(4.5, 7.0, world_pos.y) * 0.45 * step(n.y, 0.6);
		rough = mix(0.72, 0.95, mortar + grime * 0.3);
	}
	float grey = dot(colour, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(colour, vec3(grey) * vec3(0.85, 1.0, 1.1), soul);
	ROUGHNESS = rough;
	EMISSION = mix(glow_color, vec3(dot(glow_color, vec3(0.299, 0.587, 0.114))), soul);
}
