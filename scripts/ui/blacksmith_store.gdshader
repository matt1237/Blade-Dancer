shader_type canvas_item;
render_mode unshaded;

uniform float ambient_time = 0.0;
uniform sampler2D bird_texture : source_color, filter_linear, repeat_disable;
uniform bool bird_visible = false;
uniform vec2 bird_center = vec2(0.0);
uniform float bird_size = 30.0;
uniform bool bird_reverse = false;

float soft_ellipse(vec2 point, vec2 center, vec2 radius, float edge) {
	return 1.0 - smoothstep(1.0 - edge, 1.0, length((point - center) / radius));
}

void fragment() {
	vec2 pixel = UV * vec2(1672.0, 941.0);
	vec4 room = texture(TEXTURE, UV);
	vec3 rgb = room.rgb;
	float time = ambient_time;
	float hearth = soft_ellipse(pixel, vec2(1350.0, 382.0), vec2(180.0, 132.0), 0.65);
	float flame_breath = 0.58 + 0.24 * sin(time * 5.8) + 0.12 * sin(time * 9.7 + 1.3) + 0.06 * sin(time * 14.2);
	float hot_color = smoothstep(0.04, 0.28, room.r - room.b) * smoothstep(0.12, 0.48, room.r);
	rgb += vec3(0.18, 0.073, 0.018) * hearth * flame_breath * (0.45 + hot_color * 0.7);
	float lanterns = soft_ellipse(pixel, vec2(414.0, 226.0), vec2(40.0, 56.0), 0.75) * (0.5 + 0.5 * sin(time * 3.4))
		+ soft_ellipse(pixel, vec2(883.0, 146.0), vec2(61.0, 55.0), 0.75) * (0.5 + 0.5 * sin(time * 3.0 + 1.2))
		+ soft_ellipse(pixel, vec2(1112.0, 388.0), vec2(32.0, 48.0), 0.75) * (0.5 + 0.5 * sin(time * 4.1 + 2.3))
		+ soft_ellipse(pixel, vec2(88.0, 610.0), vec2(55.0, 82.0), 0.75) * (0.5 + 0.5 * sin(time * 3.6 + 0.5));
	rgb += room.rgb * vec3(0.10, 0.052, 0.018) * lanterns * 0.16;
	if (bird_visible) {
		vec2 bird_uv = (pixel - bird_center) / bird_size + vec2(0.5);
		float inside = step(0.0, bird_uv.x) * step(bird_uv.x, 1.0) * step(0.0, bird_uv.y) * step(bird_uv.y, 1.0);
		if (bird_reverse) { bird_uv.x = 1.0 - bird_uv.x; }
		vec4 bird = texture(bird_texture, clamp(bird_uv, vec2(0.0), vec2(1.0)));
		float left_window = smoothstep(495.0, 515.0, pixel.x) * (1.0 - smoothstep(624.0, 646.0, pixel.x)) * smoothstep(184.0, 201.0, pixel.y) * (1.0 - smoothstep(350.0, 372.0, pixel.y));
		float right_window = smoothstep(899.0, 920.0, pixel.x) * (1.0 - smoothstep(1030.0, 1050.0, pixel.x)) * smoothstep(222.0, 238.0, pixel.y) * (1.0 - smoothstep(364.0, 384.0, pixel.y));
		float glass = max(left_window, right_window) * smoothstep(0.015, 0.12, room.b - room.r);
		rgb = mix(rgb, bird.rgb * 0.88 + vec3(0.08, 0.07, 0.05), bird.a * inside * glass * 0.92);
	}
	COLOR = vec4(rgb, room.a);
}
