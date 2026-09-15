shader_type canvas_item;

// Four sRGB source textures. At detail_scale 1 each authored texel occupies
// one world pixel; only blend/mask fields are warped, never the grass blades.
uniform sampler2D grass_a : source_color, repeat_enable, filter_linear;
uniform sampler2D grass_b : source_color, repeat_enable, filter_linear;
uniform sampler2D grass_c : source_color, repeat_enable, filter_linear;
uniform sampler2D grass_d : source_color, repeat_enable, filter_linear;
uniform float detail_scale : hint_range(0.7, 1.8) = 1.0;
uniform float grass_brightness : hint_range(0.65, 1.4) = 1.0;
uniform float grass_saturation : hint_range(0.3, 1.5) = 1.0;
uniform float dirt_amount : hint_range(0.0, 1.0) = 0.85;
uniform float path_width : hint_range(80.0, 440.0) = 260.0;
uniform float path_meander : hint_range(0.0, 160.0) = 65.0;
uniform float edge_breakup : hint_range(0.0, 130.0) = 65.0;
uniform float dark_soil : hint_range(0.0, 1.0) = 0.3;
uniform vec2 clearing_center = vec2(640.0, 360.0);
uniform vec2 clearing_radius = vec2(880.0, 470.0);

// Optional GROUND-ONLY color grade. Off means no contrast, saturation or warmth
// grade; it does not bypass the ground composition. Atmosphere is a world overlay.
uniform bool grading_enabled = false;
uniform float grade_saturation : hint_range(0.4, 1.5) = 1.08;
uniform float grade_contrast : hint_range(0.8, 1.25) = 1.06;
uniform float sunlight_warmth : hint_range(0.0, 0.8) = 0.25;
varying vec2 world_position;

vec2 hash2(vec2 p) {
	// Arithmetic hash avoids large sine multipliers and their precision seams
	// on Mobile/D3D12. Adjacent noise cells must share identical corner values.
	vec3 h = fract(vec3(p.x, p.y, p.x) * vec3(0.1031, 0.1030, 0.0973));
	h += dot(h, h.yzx + 33.33);
	return fract((h.xx + h.yz) * h.zy);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i).x, hash2(i + vec2(1.0, 0.0)).x, f.x),
		mix(hash2(i + vec2(0.0, 1.0)).x, hash2(i + vec2(1.0)).x, f.x), f.y);
}

vec3 patch(vec2 uv, vec2 cell) {
	vec2 h = hash2(cell);
	// Reflections and phase offsets remove repeating motifs without stretching.
	vec2 q = uv * mix(vec2(-1.0), vec2(1.0), step(vec2(0.5), h)) + h * 17.0;
	float variant = floor(hash2(cell + vec2(73.0, 19.0)).x * 4.0);
	if (variant < 1.0) { return texture(grass_a, q).rgb; }
	if (variant < 2.0) { return texture(grass_b, q).rgb; }
	if (variant < 3.0) { return texture(grass_c, q).rgb; }
	return texture(grass_d, q).rgb;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = world_position;
	// All four supplied source images are 64 x 64. Scale affects detail only,
	// not the width/location of the path or the size of its grassy islands.
	vec2 uv = p / (64.0 * detail_scale);
	vec2 blend_uv = p / 113.0 + vec2(noise(p / 157.0), noise(p / 173.0 + 31.0)) * 1.4;
	vec2 cell = floor(blend_uv);
	vec2 f = smoothstep(vec2(0.12), vec2(0.88), fract(blend_uv));
	vec4 w = vec4((1.0-f.x)*(1.0-f.y), f.x*(1.0-f.y), (1.0-f.x)*f.y, f.x*f.y);
	w *= w;
	w /= dot(w, vec4(1.0));
	vec3 grass = patch(uv, cell) * w.x
		+ patch(uv, cell + vec2(1.0, 0.0)) * w.y
		+ patch(uv, cell + vec2(0.0, 1.0)) * w.z
		+ patch(uv, cell + vec2(1.0)) * w.w;
	float source_luminance = dot(grass, vec3(0.299, 0.587, 0.114));
	// Neutral controls preserve the rich source art: no meadow-color wash,
	// compulsory desaturation, dark base plate or screen-space haze.
	grass = mix(vec3(source_luminance), grass, grass_saturation) * grass_brightness;

	// A broad beaten clearing runs east-west around y = 360. Independently
	// broken banks and varying width avoid the silhouette of a uniform road.
	float wandering_y = clearing_center.y + path_meander * (
		0.66 * sin((p.x - clearing_center.x) / 310.0 + 0.4)
		+ 0.34 * (noise(vec2(p.x / 195.0, 8.3)) * 2.0 - 1.0));
	vec2 mask_warp = vec2(noise(p / 187.0 + 9.4), noise(p / 163.0 + 36.2)) - 0.5;
	vec2 organic_p = p + mask_warp * 116.0;
	float broad_edge = noise(organic_p / vec2(119.0, 81.0) + 14.8);
	float fine_edge = noise(p / 23.0 + 7.1);
	float broken_edge = ((broad_edge - 0.5) * 1.65 + (fine_edge - 0.5) * 0.35) * edge_breakup;
	float half_width = path_width * 0.5 * mix(0.80, 1.20, noise(vec2(p.x / 241.0, 27.6)));
	float bank_distance = abs(p.y - wandering_y) - half_width + broken_edge;
	float corridor = 1.0 - smoothstep(-19.0, 23.0, bank_distance);

	// Organic islands interrupt the interior, while isolated bare patches spread
	// into the surrounding grass. These masks never stamp road sprites or lanes.
	float island_field = noise(organic_p / vec2(101.0, 76.0) + vec2(43.7, 18.2));
	island_field = island_field * 0.82 + noise(p / 29.0 + 32.1) * 0.18;
	float islands = smoothstep(0.61, 0.78, island_field);
	float peripheral_field = noise(organic_p / vec2(144.0, 104.0) + vec2(7.9, 51.2));
	peripheral_field = peripheral_field * 0.84 + fine_edge * 0.16;
	float clearing_distance = length((p - clearing_center) / clearing_radius);
	float peripheral_patches = smoothstep(0.65, 0.79, peripheral_field);
	peripheral_patches *= mix(0.62, 0.96, smoothstep(0.3, 1.1, clearing_distance));
	float soil_shape = max(corridor * (1.0 - islands * 0.98), peripheral_patches);
	// Coverage, not a muddy translucent tint: the beaten core stays sandy while
	// the banks reveal source grass. Zero dirt_amount restores uninterrupted grass.
	float dirt_mask = smoothstep(0.10, 0.78, soil_shape * dirt_amount);
	// Grass blades/gravel bite into the banks at material-detail scale, rather
	// than leaving an airbrushed boundary around the large shape mask.
	float bank_fringe = dirt_mask * (1.0 - dirt_mask) * 4.0;
	float flecks = noise(floor(p / (2.0 * detail_scale)) * 0.79 + 83.0);
	dirt_mask = clamp(dirt_mask + (flecks - 0.52) * bank_fringe * 0.64, 0.0, 1.0);

	// Warm sand/ochre with restrained granular detail and separate darker soil.
	// Broad color variation belongs to the soil, never to an all-ground wash.
	float sand_variation = noise(organic_p / 137.0 + 21.4);
	vec3 sand = mix(vec3(0.58, 0.405, 0.225), vec3(0.75, 0.575, 0.345), sand_variation);
	float soil_pockets = smoothstep(0.45, 0.83, noise(organic_p / 88.0 + 61.8));
	sand = mix(sand, vec3(0.35, 0.255, 0.145), soil_pockets * dark_soil);
	float grain = (noise(p / (3.5 * detail_scale)) - 0.5) * 0.045
		+ (noise(p / (12.0 * detail_scale) + 17.3) - 0.5) * 0.055;
	sand += vec3(grain + (source_luminance - 0.35) * 0.035);
	vec3 ground = mix(grass, sand, dirt_mask);

	if (grading_enabled) {
		float luminance = dot(ground, vec3(0.299, 0.587, 0.114));
		ground = mix(vec3(luminance), ground, grade_saturation);
		ground = (ground - vec3(0.5)) * grade_contrast + vec3(0.5);
		ground *= vec3(1.0 + sunlight_warmth * 0.13, 1.0 + sunlight_warmth * 0.035, 1.0 - sunlight_warmth * 0.10);
	}
	// The floor draws white so authored colors are not multiplied by a base tint.
	COLOR = vec4(clamp(ground, vec3(0.0), vec3(1.0)), 1.0) * COLOR;
}
