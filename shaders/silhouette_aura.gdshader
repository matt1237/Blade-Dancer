shader_type canvas_item;
// Flattens any sprite's texture into a solid, oscillating-color silhouette
// using only its alpha shape. Node modulate.a still works as a final fade
// multiplier (COLOR.a already carries modulate by the time fragment() runs),
// so per-instance fades (e.g. afterimage aging) work without touching the
// shared aura_color uniform.
uniform vec4 aura_color : source_color = vec4(1.0, 0.9, 0.6, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(aura_color.rgb, tex.a * aura_color.a * COLOR.a);
}
