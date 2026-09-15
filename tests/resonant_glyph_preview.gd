class_name ResonantGlyphPreview extends Node2D

const GLYPH_SCENE: PackedScene = preload("res://scenes/resonant_glyph.tscn")

func _ready() -> void:
	var positions: Array[Vector2] = [Vector2(420.0, 360.0), Vector2(640.0, 360.0), Vector2(860.0, 360.0)]
	for index: int in range(positions.size()):
		var glyph: ResonantGlyph = GLYPH_SCENE.instantiate() as ResonantGlyph
		add_child(glyph)
		glyph.global_position = positions[index]
		glyph.setup(null, index + 1)
		if index == 1:
			glyph.pulse_left = ResonantGlyph.PULSE_VISUAL_DURATION
			glyph.pulse_radius = 28.0
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1280.0, 720.0), Color("101c35"))
	draw_string(ThemeDB.fallback_font, Vector2(450.0, 170.0), "RESONANT GLYPH", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color("d9f6ff"))
	draw_string(ThemeDB.fallback_font, Vector2(410.0, 205.0), "Animated obstruction preview — middle glyph is pulsing", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("8bdcf5"))
	for glyph_position: Vector2 in [Vector2(420.0, 450.0), Vector2(640.0, 450.0), Vector2(860.0, 450.0)]:
		draw_string(ThemeDB.fallback_font, glyph_position, "SAFE TARGET", HORIZONTAL_ALIGNMENT_CENTER, 0.0, 12, Color(0.55, 0.8, 0.9, 0.8))
