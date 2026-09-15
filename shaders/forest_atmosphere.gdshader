shader_type canvas_item;
render_mode unshaded, blend_mix;
uniform bool clouds_enabled = false;
uniform float cloud_strength = 0.22;
uniform float cloud_scale = 360.0;
uniform float cloud_speed = 12.0;
uniform float cloud_coverage = 0.5;
uniform float cloud_softness = 0.35;
uniform bool rays_enabled = false;
uniform float ray_strength = 0.14;
uniform float ray_width = 100.0;
// 0 = perfectly vertical shafts ("sun overhead"); negative leans one way,
// positive the other (e.g. Morning vs Dusk). 25.64 reproduces the original
// fixed diagonal exactly, so old data missing this key renders unchanged.
uniform float ray_angle_degrees = 25.64;
uniform bool moon_glow_enabled = false;
uniform float moon_glow_strength = 0.16;
uniform bool dapple_enabled = false;
uniform float dapple_strength = 0.12;
uniform bool haze_enabled = false;
uniform float haze_strength = 0.1;
uniform float sunlight_warmth = 0.25;
// Neutral defaults preserve legacy Hazey rendering exactly.
uniform float mood_temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float mist_strength : hint_range(0.0, 1.0) = 0.0;
uniform float night_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 arena_rect = vec4(0.0, 0.0, 1280.0, 720.0);
uniform float elapsed = 0.0;
varying vec2 world_position;
float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1.0,0.0)), f.x), mix(hash(i+vec2(0.0,1.0)), hash(i+vec2(1.0)), f.x), f.y);
}
float cloud_blob(vec2 p, vec2 center, vec2 radius) {
	vec2 q = (p - center) / radius;
	float d = dot(q, q);
	return 1.0 - smoothstep(0.62 - cloud_softness * 0.34, 1.0 + cloud_softness * 0.55, d);
}
float rounded_clouds(vec2 p) {
	vec2 cell_size = vec2(max(cloud_scale, 1.0), max(cloud_scale * 0.72, 1.0));
	vec2 cell = floor(p / cell_size);
	float result = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 id = cell + vec2(float(x), float(y));
			vec2 jitter = (vec2(hash(id + 4.0), hash(id + 19.0)) - 0.5) * cell_size * 0.52;
			vec2 center = (id + vec2(0.5)) * cell_size + jitter;
			vec2 radius = cell_size * vec2(0.62 + hash(id + 41.0) * 0.30, 0.42 + hash(id + 73.0) * 0.25);
			float blob = cloud_blob(p, center, radius);
			blob *= smoothstep(0.18, 0.78, noise(id * 1.7 + 8.0) + cloud_coverage * 0.62);
			result = max(result, blob);
		}
	}
	return result;
}
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec2 p = world_position;
	vec2 drift = vec2(elapsed * cloud_speed, elapsed * cloud_speed * 0.28);
	float shade = 0.0; float sun = 0.0; float haze = 0.0;
	if (clouds_enabled) {
		vec2 q = (p + drift) / max(cloud_scale, 1.0);
		float cloud = rounded_clouds(p + drift);
		shade = cloud * cloud_strength;
	}
	float moon = 0.0;
	if (rays_enabled) {
		// Sparse angled shafts: no hard rectangular geometry or screen-space sliding.
		// Slope is tunable per time-of-day phase via ray_angle_degrees.
		float ray_slope = tan(radians(ray_angle_degrees));
		float diagonal = p.x - p.y * ray_slope;
		float shaft = 0.0;
		for (int i = 0; i < 4; i++) {
			float axis = -80.0 + float(i) * 445.0 + sin(float(i)*3.1 + elapsed*0.06) * 26.0;
			float d = (diagonal-axis) / max(ray_width,1.0);
			shaft += exp(-d*d*3.0);
		}
		float depth = 1.0 - smoothstep(arena_rect.y+180.0, arena_rect.y+arena_rect.w+170.0, p.y);
		sun += shaft * depth * ray_strength * (0.7 + noise(p / 175.0 + drift * 0.001) * 0.3);
	}
	if (moon_glow_enabled) {
		// Soft diffuse radial glow, no hard shafts -- moonlight doesn't need
		// them. Anchored near the top of the arena, roughly where a moon
		// would sit in the sky for this stylized top-down view.
		vec2 moon_pos = arena_rect.xy + vec2(arena_rect.z * 0.66, arena_rect.w * -0.12);
		float moon_dist = length(p - moon_pos);
		moon = moon_glow_strength * exp(-moon_dist * moon_dist / (2.0 * 340.0 * 340.0));
	}
	if (dapple_enabled) {
		float fleck = noise((p + drift*0.25) / 80.0) * 0.7 + noise(p / 29.0) * 0.3;
		sun += smoothstep(0.52,0.85,fleck) * dapple_strength;
	}
	if (haze_enabled) {
		vec2 inside = min(p-arena_rect.xy, arena_rect.xy+arena_rect.zw-p);
		float edge = min(inside.x,inside.y);
		haze = (1.0-smoothstep(-90.0,85.0,edge)) * haze_strength * smoothstep(0.1,0.8,noise((p-drift*0.6)/240.0));
	}
	// Daytime mist is broad, slow and world anchored. At night the localized
	// shader owns mist so clear light cores are never veiled by a global overlay.
	if (haze_enabled && night_strength <= 0.0001) {
		float ribbon = smoothstep(0.30, 0.82, noise(p / vec2(420.0, 110.0) + vec2(elapsed * 0.012, 0.0)));
		haze += ribbon * mist_strength * 0.18;
	}
	vec3 sunlight = mix(vec3(1.0,0.98,0.85),vec3(1.0,0.81,0.43),sunlight_warmth);
	vec3 haze_color = mix(vec3(0.50,0.65,0.58), vec3(0.60,0.72,0.85), max(-mood_temperature, 0.0));
	haze_color = mix(haze_color, vec3(0.80,0.69,0.53), max(mood_temperature, 0.0));
	vec3 moon_color = vec3(0.72, 0.83, 1.0);
	float alpha = clamp(shade + sun + haze + moon,0.0,0.5);
	vec3 rgb = (vec3(0.018,0.06,0.055)*shade + sunlight*sun + haze_color*haze + moon_color*moon) / max(shade+sun+haze+moon,0.0001);
	COLOR = vec4(rgb,alpha);
}
