shader_type canvas_item;
render_mode blend_add, unshaded;

uniform bool core_layer = false;
uniform bool before_beat = true;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float windup : hint_range(0.0, 1.0) = 0.0;
uniform float release_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 selected_color : source_color = vec4(1.0, 0.65, 0.12, 1.0);
uniform bool preserve_gold = true;
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	vec3 pulse_color = mix(vec3(1.0), selected_color.rgb, charge);
	vec3 rgb = vec3(0.0);

	// Scale one whole authored corona about its origin; never scroll/crop a sheet.
	float spread = before_beat ? mix(0.64, 0.36, windup) : mix(0.36, 0.98, smoothstep(0.0, 1.0, release_progress));
	vec2 energy_p = vec2(p.x, p.y * 4.5);
	vec2 art_uv = energy_p / spread * 0.5 + vec2(0.5);
	vec4 art = texture(TEXTURE, clamp(art_uv, vec2(0.0), vec2(1.0)));
	float bounds = step(0.0, art_uv.x) * step(art_uv.x, 1.0) * step(0.0, art_uv.y) * step(art_uv.y, 1.0);
	float flare = (before_beat ? pow(energy, 4.0) : energy) * 0.9;
	// Remap intensity and highlight detail, never multiply blue/green over gold.
	float intensity = max(art.r, max(art.g, art.b));
	float highlight = min(art.r, min(art.g, art.b)) / max(intensity, 0.0001);
	vec3 recolored = mix(selected_color.rgb, vec3(1.0), highlight) * intensity;
	vec3 charged_art = preserve_gold ? art.rgb : recolored;
	// Suppress only the authored star beneath the mix-blended nucleus. Procedural
	// flow is deliberately not hollowed, so it can travel through the rim to center.
	float authored_star_suppression = smoothstep(0.075, 0.14, length(energy_p) / spread);
	rgb = mix(vec3(intensity), charged_art, charge) * art.a * bounds * authored_star_suppression * flare;

	// Paired motes and short horizontal tails converge to zero radius on windup,
	// then originate inside the nucleus and accelerate outward on release.
	float sparks = 0.0;
	for (int i = 0; i < 20; i++) {
		float seed = fract(float(i) * 0.618034);
		float travel = before_beat ? windup : release_progress;
		float accelerated_release = travel * travel;
		float radius = before_beat ? mix(0.62 + seed * 0.28, 0.0, travel) : mix(0.015, 0.64 + seed * 0.28, accelerated_release);
		float side = (i % 2 == 0) ? -1.0 : 1.0;
		float angle = (seed - 0.5) * (before_beat ? 0.24 : 0.34);
		vec2 direction = vec2(side * cos(angle), sin(angle));
		vec2 delta = p - direction * radius;
		float along = dot(delta, direction);
		float across = dot(delta, vec2(-direction.y, direction.x));
		float mote = exp(-pow(along / 0.020, 2.0) - pow(across / 0.008, 2.0));
		float tail_offset = before_beat ? -0.030 : 0.034;
		float trail = exp(-pow((along + tail_offset) / 0.052, 2.0) - pow(across / 0.0045, 2.0)) * 0.42;
		sparks += mote + trail;
	}
	float windup_sparks = smoothstep(0.02, 0.22, windup) * (1.0 - 0.48 * pow(windup, 8.0));
	float release_sparks = pow(sin(release_progress * PI), 2.0) * energy;
	float mote_strength = before_beat ? windup_sparks : release_sparks;

	// Thin intake filaments touch the nucleus throughout late windup. Their shape
	// contracts horizontally while the phase envelope alone drives brightness.
	float intake_length = mix(0.72, 0.055, windup);
	float intake = exp(-pow(p.y / 0.010, 2.0));
	intake *= 1.0 - smoothstep(intake_length, intake_length + 0.055, abs(p.x));
	intake *= before_beat ? smoothstep(0.08, 0.55, windup) : 0.0;

	// The release starts inside the core, breaches its rim, then accelerates on X.
	float wave_x = mix(0.018, 0.90, release_progress * release_progress);
	float bow = p.y * p.y * 1.8;
	float wave = exp(-pow((abs(p.x) + bow - wave_x) / 0.038, 2.0));
	wave *= exp(-pow(p.y / 0.15, 2.0)) * pow(sin(release_progress * PI), 2.0) * energy * 0.8;
	float inner_whoosh = exp(-pow(p.y / 0.022, 2.0));
	inner_whoosh *= 1.0 - smoothstep(wave_x + 0.015, wave_x + 0.09, abs(p.x));
	inner_whoosh *= before_beat ? 0.0 : pow(sin(release_progress * PI), 2.0) * energy * 0.38;

	// A brief selected-color corona sits outside the sole mix-blended core.
	float peak = pow(charge, 12.0);
	float corona = exp(-pow((r - 0.105) / 0.020, 2.0)) * peak;
	rgb += pulse_color * sparks * mote_strength;
	rgb += pulse_color * intake * energy * 0.75;
	rgb += pulse_color * wave * (before_beat ? 0.0 : 1.0);
	rgb += pulse_color * inner_whoosh;
	rgb += mix(selected_color.rgb, vec3(1.0), 0.42) * corona * 1.15;

	// Only the outer sprite boundary fades; there is intentionally no central hole.
	rgb *= 1.0 - smoothstep(0.94, 1.0, r);
	COLOR = vec4(rgb * tint.rgb, tint.a);
}
