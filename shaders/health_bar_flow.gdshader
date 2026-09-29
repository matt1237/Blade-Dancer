shader_type canvas_item;
// Slow travelling darker band across a health bar's fill: the colour at any point
// oscillates between the bar's tint and a darker version of it, and the band sweeps
// along the bar, so the fill reads as flowing rather than painted flat. The trough is
// deeper than a whisper so the movement is legible on a 24px-tall bar.
//
// It multiplies COLOR.rgb, which already carries the layer's modulate by the time
// fragment() runs, so one material serves the enemy crimson and the player blue
// without knowing either colour. Multiplying also leaves the fill texture's own
// vertical gradient intact instead of replacing it.
uniform float flow_speed : hint_range(0.0, 2.0, 0.01) = 0.35; // band sweeps per second
uniform float flow_depth : hint_range(0.0, 0.6, 0.01) = 0.33; // how dark the trough gets
uniform float flow_bands : hint_range(0.25, 4.0, 0.05) = 1.0; // bands across the fill

void fragment() {
	// UV.x spans the stretched fill rect, so the band scales with the bar rather than
	// sitting at a fixed pixel wavelength.
	float wave = 0.5 + 0.5 * sin(UV.x * flow_bands * TAU - TIME * flow_speed * TAU);
	COLOR.rgb *= 1.0 - flow_depth * wave;
}