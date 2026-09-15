class_name HDEyeAnchorZoom extends Node2D
var page: int = 0
var textures: Array[Texture2D] = []
const NAMES = ["turkey_idle", "turkey_walk", "duelist_idle", "duelist_walk", "blue_bug_idle", "blue_bug_fly", "warg_idle", "warg_charge", "elite_idle", "elite_march"]
const CROPS = [Rect2(12, 16, 42, 48), Rect2(12, 16, 42, 48), Rect2(48, 8, 48, 48), Rect2(48, 8, 48, 48), Rect2(60, 52, 48, 48), Rect2(60, 52, 48, 48), Rect2(4, 30, 48, 55), Rect2(4, 30, 48, 55), Rect2(48, 0, 48, 60), Rect2(48, 0, 48, 60)]
func _ready() -> void:
	queue_redraw()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		page = (page + 1) % 5
		queue_redraw()
func _draw() -> void:
	for row in range(2):
		var idx: int = page * 2 + row
		var tex: Texture2D = load("res://assets/generated/hd_enemy_%s.png" % NAMES[idx])
		textures.append(tex)
		var w: int = 160 if page >= 3 else 128
		for f in range(3 if page >= 3 else 4):
			var pos: Vector2 = Vector2(15 + f * 300, 35 + row * 310)
			var crop: Rect2 = CROPS[idx]
			draw_texture_rect_region(tex, Rect2(pos, crop.size * 4), Rect2(crop.position + Vector2(f*w, 0), crop.size))
			draw_string(ThemeDB.fallback_font, pos - Vector2(0, 10), "%s %d origin %s" % [NAMES[idx], f, crop.position], HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
			for x in range(0, int(crop.size.x), 5):
				draw_line(pos + Vector2(x*4,0), pos + Vector2(x*4,crop.size.y*4), Color(1,1,1,0.15))
				draw_string(ThemeDB.fallback_font, pos + Vector2(x*4,crop.size.y*4+15), str(x+int(crop.position.x)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
			for y in range(0, int(crop.size.y), 5):
				draw_line(pos + Vector2(0,y*4), pos + Vector2(crop.size.x*4,y*4), Color(1,1,1,0.15))
				draw_string(ThemeDB.fallback_font, pos + Vector2(crop.size.x*4+2,y*4), str(y+int(crop.position.y)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
