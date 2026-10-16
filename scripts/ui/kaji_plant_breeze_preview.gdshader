shader_type canvas_item;
render_mode unshaded;
// Only assigned to the isolated source foliage, never the plate or room.
uniform float phase_seconds = 0.0;
void fragment() {
	vec2 p = UV / TEXTURE_PIXEL_SIZE + vec2(436.0, 128.0);
	float anchor = smoothstep(14.0, 54.0, distance(p, vec2(527.0, 199.0)));
	float pot = step(500.0, p.x) * step(p.x, 556.0) * step(200.0, p.y);
	float top = smoothstep(140.0, 155.0, p.y);
	// Conservative erosion pins matte fringes and all background-bearing edges.
	// Only foliage-coloured interior pixels can deform; no window/wall sampling.
	vec4 base = texture(TEXTURE, UV);
	float interior = 1.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			interior *= step(0.99, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
		}
	}
	float green = smoothstep(0.70, 0.84, base.g / max(base.r, 0.001)) * step(base.b * 1.5, base.g);
	// The canopy overlaps the window arch at the left: pin that overlap entirely.
	float window_guard = smoothstep(466.0, 474.0, p.x);
	float weight = anchor * (1.0 - pot) * top * interior * green * window_guard;
	// Both waves start at zero, but differ spatially and temporally.
	float a = sin(phase_seconds * 0.81) * cos(p.y * 0.073 + p.x * 0.028);
	float b = sin(phase_seconds * 1.13) * sin(p.x * 0.091 - p.y * 0.043);
	vec2 offset = vec2(1.55 * a + 0.45 * b, 0.45 * b) * weight;
	vec4 moved = texture(TEXTURE, UV - offset * TEXTURE_PIXEL_SIZE);
	float safe = step(moved.r * 0.70, moved.g) * step(moved.b * 1.5, moved.g) * step(0.99, moved.a);
	COLOR = mix(base, moved, safe);
}
