extends Node2D
## Independent high-z rendering for the live sword, so the blade stays visible over
## player animation and Flow afterimages without raising every other player effect.

var sword_texture: Texture2D = null
var sword_center: Vector2 = Vector2.ZERO
var sword_rotation: float = 0.0
var sword_scale: Vector2 = Vector2.ONE
var sword_rect: Rect2 = Rect2(-512.0, -768.0, 1024.0, 1536.0)
var sword_alpha: float = 0.0

func set_sword_pose(texture: Texture2D, center: Vector2, angle: float, visual_scale: Vector2, rect: Rect2, alpha: float) -> void:
	sword_texture = texture
	sword_center = center
	sword_rotation = angle
	sword_scale = visual_scale
	sword_rect = rect
	sword_alpha = alpha
	queue_redraw()

func _draw() -> void:
	if sword_texture == null or sword_alpha <= 0.01:
		return
	draw_set_transform(sword_center, sword_rotation, sword_scale)
	draw_texture_rect(sword_texture, sword_rect, false, Color(1.0, 1.0, 1.0, sword_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
