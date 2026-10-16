extends Node2D
## Independent high-z rendering for the live sword, so the blade stays visible over
## player animation and Flow afterimages without raising every other player effect.

var sword_texture: Texture2D = null
var sword_center: Vector2 = Vector2.ZERO
var sword_rotation: float = 0.0
var sword_scale: Vector2 = Vector2.ONE
var sword_rect: Rect2 = Rect2(-512.0, -768.0, 1024.0, 1536.0)
var sword_alpha: float = 0.0

## Render-only committed poses. The controller remains geometry authority.
## Ordinary weapons continue using set_sword_pose, which clears this list.
class Pose extends RefCounted:
	var texture: Texture2D
	var center: Vector2
	var angle: float
	var visual_scale: Vector2
	var rect: Rect2
	var alpha: float

	func _init(p_texture: Texture2D, p_center: Vector2, p_angle: float, p_scale: Vector2, p_rect: Rect2, p_alpha: float) -> void:
		texture = p_texture
		center = p_center
		angle = p_angle
		visual_scale = p_scale
		rect = p_rect
		alpha = p_alpha

var sword_poses: Array[Pose] = []

func set_sword_poses(poses: Array[Pose]) -> void:
	# Copy pose values so later controller mutation cannot silently change a
	# frame that has already been committed for rendering.
	sword_poses.clear()
	for pose: Pose in poses:
		sword_poses.append(Pose.new(pose.texture, pose.center, pose.angle, pose.visual_scale, pose.rect, pose.alpha))
	# Empty multi-pose submission means hide, never resurrect the legacy sword.
	sword_alpha = 0.0
	queue_redraw()

func set_sword_pose(texture: Texture2D, center: Vector2, angle: float, visual_scale: Vector2, rect: Rect2, alpha: float) -> void:
	sword_poses.clear()
	sword_texture = texture
	sword_center = center
	sword_rotation = angle
	sword_scale = visual_scale
	sword_rect = rect
	sword_alpha = alpha
	queue_redraw()

func _draw() -> void:
	if not sword_poses.is_empty():
		for pose: Pose in sword_poses:
			if pose.texture == null or pose.alpha <= 0.01:
				continue
			draw_set_transform(pose.center, pose.angle, pose.visual_scale)
			draw_texture_rect(pose.texture, pose.rect, false, Color(1.0, 1.0, 1.0, pose.alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if sword_texture == null or sword_alpha <= 0.01:
		return
	draw_set_transform(sword_center, sword_rotation, sword_scale)
	draw_texture_rect(sword_texture, sword_rect, false, Color(1.0, 1.0, 1.0, sword_alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
