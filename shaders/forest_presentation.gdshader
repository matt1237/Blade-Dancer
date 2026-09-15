shader_type canvas_item;

uniform float presentation_enabled = 0.0;
uniform float vignette_strength = 0.32;
uniform float saturation = 0.88;
uniform float contrast = 1.04;
uniform vec3 edge_tint : source_color = vec3(0.78, 0.91, 0.86);
uniform vec3 center_tint : source_color = vec3(1.0, 0.98, 0.90);
uniform float presentation_time = 0.0;
uniform float dapple_strength = 0.035;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 output_rgb = source.rgb;
	if (presentation_enabled >= 0.5) {
		vec2 centered_uv = UV - vec2(0.5);
		float edge_distance = length(centered_uv * vec2(1.0, 0.92));
		float edge_weight = smoothstep(0.28, 0.76, edge_distance) * vignette_strength;
		vec3 tinted = source.rgb * mix(center_tint, edge_tint, edge_weight);
		float luminance = dot(tinted, vec3(0.2126, 0.7152, 0.0722));
		tinted = mix(vec3(luminance), tinted, saturation);
		float dapple_wave = sin(UV.x * 11.0 + presentation_time * 0.18) * sin(UV.y * 7.0 - presentation_time * 0.13);
		float dapple_mask = smoothstep(-0.72, 0.72, dapple_wave);
		tinted *= 1.0 + (dapple_mask - 0.5) * dapple_strength;
		output_rgb = (tinted - vec3(0.5)) * contrast + vec3(0.5);
	}
	COLOR = vec4(clamp(output_rgb, vec3(0.0), vec3(1.0)), source.a);
}
