shader_type canvas_item;
// ▽ Rewind playback: desaturated sepia wash over the whole screen with a soft vignette.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec3 source = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(source, vec3(0.299, 0.587, 0.114));
	vec3 sepia = vec3(grey * 1.07, grey * 0.88, grey * 0.66);
	float vignette = smoothstep(0.85, 0.25, distance(SCREEN_UV, vec2(0.5)));
	vec3 tinted = mix(source, sepia, strength) * mix(0.72, 1.0, vignette);
	COLOR = vec4(tinted, 1.0);
}
