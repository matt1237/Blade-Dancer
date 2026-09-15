shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform bool core_layer = true;
uniform bool before_beat = true;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float windup : hint_range(0.0, 1.0) = 0.0;
uniform float release_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 selected_color : source_color = vec4(1.0, 0.65, 0.12, 1.0);
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
	vec2 p = (UV - vec2(0.5)) * 2.0;
	float r = length(p);
	float angle = atan(p.y, p.x);
	// TIME only keeps the stationary idle nucleus alive. Combat amplitude remains
	// entirely controlled by charge/windup/release_progress.
	float idle_breath = sin(TIME * 1.65) * 0.010;
	float edge_radius = 0.47 + idle_breath + charge * 0.012;
	float body = 1.0 - smoothstep(edge_radius - 0.025, edge_radius + 0.025, r);
	float halo = exp(-r * r * 5.8) * (0.14 + 0.08 * sin(TIME * 1.65) * sin(TIME * 1.65));

	// Compress only the inner energy on windup; the circular outer anchor never moves.
	float inner_compression = before_beat ? 0.12 * windup : -0.05 * (1.0 - release_progress);
	vec2 inner_p = vec2(p.x * (1.0 + inner_compression), p.y * (1.0 - inner_compression * 0.32));
	float inner_r = length(inner_p);
	float plasma = 0.5 + 0.5 * sin(inner_r * 28.0 - TIME * 1.15 + sin(angle * 3.0 + TIME * 0.42) * 1.2);
	plasma *= 0.5 + 0.5 * sin(angle * 5.0 - TIME * 0.55 + inner_r * 11.0);
	float plasma_mask = (1.0 - smoothstep(0.12, 0.43, inner_r)) * body;
	float filaments = 1.0 - smoothstep(0.08, 0.28, abs(sin(angle * 3.0 + inner_r * 14.0 - TIME * 0.48)));
	filaments *= smoothstep(0.08, 0.17, inner_r) * (1.0 - smoothstep(0.28, 0.44, inner_r)) * body;
	float nucleus = 1.0 - smoothstep(0.03, 0.18 - charge * 0.018, inner_r);

	vec3 phase_color = mix(vec3(1.0), selected_color.rgb, charge);
	vec3 nucleus_color = mix(vec3(1.0), mix(selected_color.rgb, vec3(1.0), 0.24), charge);
	vec3 rgb = phase_color * (0.62 + plasma * plasma_mask * 0.34);
	rgb += phase_color * filaments * (0.20 + charge * 0.25);
	rgb = mix(rgb, nucleus_color * (1.10 + charge * 0.12), nucleus);

	// A narrow near-peak rim/corona reads as impact without creating another core.
	float peak = pow(charge, 10.0);
	float rim = exp(-pow((r - edge_radius + 0.012) / 0.032, 2.0)) * peak;
	rgb += mix(selected_color.rgb, vec3(1.0), 0.62) * rim * 0.75;
	float alpha = clamp(body + halo * (1.0 - smoothstep(0.72, 0.98, r)), 0.0, 1.0);
	COLOR = vec4(rgb * tint.rgb, alpha * tint.a);
}
