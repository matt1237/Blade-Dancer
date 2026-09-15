shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float night_strength : hint_range(0.0, 1.0) = 0.0;
uniform float mood_temperature : hint_range(-1.0, 1.0) = 0.0;
uniform float mist_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool moon_glow_enabled = false;
uniform float moon_glow_strength = 0.16;
uniform bool moon_beams_enabled = true;
uniform float moon_beam_strength = 0.12;
uniform float moon_beam_width = 150.0;
uniform float moon_beam_angle_degrees = -18.0;
uniform vec4 arena_rect = vec4(0.0, 0.0, 1280.0, 720.0);
uniform float elapsed = 0.0;
uniform int light_count = 0;
// World-space xy, world-pixel radius, reveal strength. No screen capture/BCS.
uniform vec4 lights[64];
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float reveal = 0.0;
	for (int i = 0; i < light_count; i++) {
		float d = distance(world_position, lights[i].xy) / max(lights[i].z, 1.0);
		reveal = max(reveal, (1.0 - smoothstep(0.42, 1.0, d)) * lights[i].w);
	}
	vec3 cool = vec3(0.004, 0.009, 0.028);
	vec3 warm = vec3(0.026, 0.013, 0.009);
	vec3 darkness = mix(cool, warm, (mood_temperature + 1.0) * 0.5);
	// Low, slow world-anchored mist, absent inside reveal cores.
	float mist = (0.5 + 0.5 * sin(world_position.y * 0.014 + sin(world_position.x * 0.008 + elapsed * 0.08) * 1.7 - elapsed * 0.12));
	darkness = mix(darkness, vec3(0.17, 0.20, 0.23), mist * mist_strength * 0.25);
	vec2 moon_pos = arena_rect.xy + vec2(arena_rect.z * 0.66, arena_rect.w * -0.12);
	float moon_lift = 0.0;
	if (moon_glow_enabled) {
		float moon_dist = distance(world_position, moon_pos);
		moon_lift += moon_glow_strength * exp(-moon_dist * moon_dist / (2.0 * 340.0 * 340.0));
	}
	if (moon_beams_enabled) {
		// Match the sun's four drifting shafts, but center the same pattern on
		// the moon direction and tint the resulting lift cool blue.
		float beam_slope = tan(radians(moon_beam_angle_degrees));
		float diagonal = world_position.x - world_position.y * beam_slope;
		float moon_diagonal = moon_pos.x - moon_pos.y * beam_slope;
		float shaft = 0.0;
		for (int i = 0; i < 4; i++) {
			float axis = moon_diagonal + (-1.5 + float(i)) * max(moon_beam_width, 1.0) * 2.9 + sin(float(i) * 3.1 + elapsed * 0.06) * 26.0;
			float d = (diagonal - axis) / max(moon_beam_width, 1.0);
			shaft += exp(-d * d * 3.0);
		}
		float depth = 1.0 - smoothstep(arena_rect.y + 180.0, arena_rect.y + arena_rect.w + 170.0, world_position.y);
		moon_lift += shaft * depth * moon_beam_strength * (0.7 + 0.3 * sin(world_position.x * 0.006 + elapsed * 0.03));
	}
	moon_lift = clamp(moon_lift, 0.0, 0.72);
	// Moonlight opens a real window through the darkness pass, allowing the
	// lower cloud layer to drift visibly through the blue shafts.
	float darkness_alpha = night_strength * (1.0 - clamp(reveal, 0.0, 1.0)) * (1.0 - moon_lift * 0.82);
	vec3 moon_tint = vec3(0.28, 0.48, 0.82);
	vec3 overlay_color = mix(darkness, moon_tint, moon_lift * 0.34);
	COLOR = vec4(overlay_color, clamp(darkness_alpha + moon_lift * 0.045, 0.0, 1.0));
}
