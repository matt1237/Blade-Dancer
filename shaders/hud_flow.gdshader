shader_type canvas_item;
// Same horizontal travelling sine and cadence as health_bar_flow.gdshader.
// Private Flow palette: never recolours the shared health material/art.
uniform float flow_speed = 0.35;
uniform float flow_bands = 1.0;
uniform vec4 pale_yellow : source_color = vec4(1.0, 0.94, 0.58, 1.0);
uniform vec4 dark_gold : source_color = vec4(0.65, 0.40, 0.04, 1.0);
uniform vec4 bright_yellow : source_color = vec4(1.0, 0.84, 0.08, 1.0);
void fragment() {
	float wave = 0.5 + 0.5 * sin(UV.x * flow_bands * TAU - TIME * flow_speed * TAU);
	vec3 tint = wave < 0.5 ? mix(dark_gold.rgb, bright_yellow.rgb, wave * 2.0) : mix(bright_yellow.rgb, pale_yellow.rgb, (wave - 0.5) * 2.0);
	// Preserve the approved neutral fill texture's vertical sheen.
	COLOR.rgb *= tint;
}
