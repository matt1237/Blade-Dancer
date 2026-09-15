shader_type canvas_item;

/// Procedural "vector" sky backdrop for Resonance Rush.
///
/// Replaces stretched/tiled pixel-art background sprites (which look
/// blocky once scaled 8x across a 20,000px course) with flat-shaded
/// gradient + silhouette bands computed per-pixel in screen space. This is
/// resolution-independent (crisp at any zoom or window size) and has no
/// seams no matter how long the course gets, since nothing is tiled.
///
/// Draws on a full-rect ColorRect in a low CanvasLayer, so it always covers
/// the viewport regardless of camera position. `camera_world_pos` is fed in
/// from script each frame to drive a soft multi-layer parallax.

uniform vec2 camera_world_pos = vec2(0.0, 0.0);
uniform vec2 viewport_size = vec2(1280.0, 720.0);

uniform vec4 sky_top : source_color = vec4(0.043, 0.067, 0.145, 1.0);
uniform vec4 sky_bottom : source_color = vec4(0.32, 0.5, 0.68, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.85, 0.55, 0.55);
uniform vec4 far_mountain_color : source_color = vec4(0.28, 0.38, 0.58, 1.0);
uniform vec4 mid_mountain_color : source_color = vec4(0.16, 0.3, 0.32, 1.0);
uniform vec4 forest_color : source_color = vec4(0.07, 0.13, 0.09, 1.0);

// Cheap smooth ridge: three stacked sine harmonics read as an organic
// silhouette instead of a single obviously-periodic wave.
float ridge(float x, float seed, float amp) {
	float n1 = sin(x + seed);
	float n2 = sin(x * 2.3 + seed * 1.7) * 0.5;
	float n3 = sin(x * 4.1 + seed * 3.1) * 0.25;
	return (n1 + n2 + n3) * amp * 0.57;
}

void fragment() {
	vec2 screen_px = UV * viewport_size;

	vec4 color = mix(sky_top, sky_bottom, pow(UV.y, 0.8));

	// Soft sun/glow, parallaxed very slightly with camera x, fixed to sky y.
	vec2 sun_center = vec2(viewport_size.x * 0.72 - camera_world_pos.x * 0.02, viewport_size.y * 0.28);
	float sun_dist = distance(screen_px, sun_center) / (viewport_size.x * 0.4);
	color = mix(color, sun_color, clamp(1.0 - sun_dist, 0.0, 1.0) * sun_color.a * 0.5);

	float base_y = viewport_size.y * 0.6 - camera_world_pos.y * 0.05;

	float far_x = (screen_px.x + camera_world_pos.x * 0.05) * 0.006;
	float far_h = base_y - 90.0 - ridge(far_x, 11.0, 55.0);
	color = mix(color, far_mountain_color, smoothstep(far_h - 3.0, far_h + 3.0, screen_px.y));

	float mid_x = (screen_px.x + camera_world_pos.x * 0.16) * 0.01;
	float mid_h = base_y - 30.0 - ridge(mid_x, 41.0, 60.0);
	color = mix(color, mid_mountain_color, smoothstep(mid_h - 3.0, mid_h + 3.0, screen_px.y));

	float near_x = (screen_px.x + camera_world_pos.x * 0.38) * 0.035;
	float near_h = base_y + 25.0 - ridge(near_x, 91.0, 24.0);
	color = mix(color, forest_color, smoothstep(near_h - 2.0, near_h + 2.0, screen_px.y));

	COLOR = color;
}
