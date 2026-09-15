class_name TerrainModule extends Node2D

const HD_WALL_HORIZONTAL: Texture2D = preload("res://assets/generated/forest_broken_stone_wall_horizontal_frame_0.png")
const HD_WALL_VERTICAL: Texture2D = preload("res://assets/generated/forest_broken_stone_wall_vertical_frame_0.png")

# Texture2D.get_image() returns a copy; share the measured alpha bounds across
# modules instead of reading the image back every time a wall redraws.
static var _hd_wall_regions: Dictionary = {}

@export var module_id: String = "forest_wall"
@export var footprint_size: Vector2 = Vector2(160.0, 40.0)
@export var blocks_navigation: bool = true
@export var draw_debug_footprint: bool = false

func _ready() -> void:
	# z_index is intentionally NOT hardcoded here. ArenaGenerator assigns it from
	# TerrainConfig.wall_visual_z_index before this node enters the tree, keeping
	# walls and traps on independently tunable visual layers.
	add_to_group("terrain_modules")
	queue_redraw()

func world_footprint() -> Rect2:
	var quarter_turn: int = posmod(roundi(rotation / (PI * 0.5)), 2)
	var rotated_size: Vector2 = Vector2(footprint_size.y, footprint_size.x) if quarter_turn == 1 else footprint_size
	return Rect2(global_position - rotated_size * 0.5, rotated_size)

func world_blocking_rects() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	var quarter_turn: int = posmod(roundi(rotation / (PI * 0.5)), 2)
	for body_node: Node in get_children():
		var body: StaticBody2D = body_node as StaticBody2D
		if body == null: continue
		for shape_node: Node in body.get_children():
			var collision: CollisionShape2D = shape_node as CollisionShape2D
			if collision == null or not collision.shape is RectangleShape2D: continue
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			var world_center: Vector2 = global_transform * (body.position + collision.position)
			var world_size: Vector2 = Vector2(rectangle.size.y, rectangle.size.x) if quarter_turn == 1 else rectangle.size
			rectangles.append(Rect2(world_center - world_size * 0.5, world_size))
	return rectangles

func _is_hd_visual() -> bool:
	var current_scene: Node = get_tree().current_scene
	return current_scene != null and str(current_scene.get("visual_style")) == "hd"

func _hd_wall_region(texture: Texture2D) -> Rect2:
	if not _hd_wall_regions.has(texture):
		var region: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
		var image: Image = texture.get_image()
		if image != null and not image.is_empty():
			var used: Rect2i = image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				region = Rect2(used)
		_hd_wall_regions[texture] = region
	return _hd_wall_regions[texture]

func _draw_hd_wall(rect: Rect2) -> void:
	var local_horizontal: bool = rect.size.x >= rect.size.y
	var wall_axis_angle: float = global_rotation if local_horizontal else global_rotation + PI * 0.5
	var screen_horizontal: bool = absf(cos(wall_axis_angle)) >= absf(sin(wall_axis_angle))
	var wall_length: float = maxf(rect.size.x, rect.size.y)
	var wall_thickness: float = minf(rect.size.x, rect.size.y)
	var texture: Texture2D = HD_WALL_HORIZONTAL if screen_horizontal else HD_WALL_VERTICAL
	# The authored lower stone course is continuous; the broken upper crest is
	# transparent sky/ground, not a doorway. Do not fill that crest with a flat
	# rectangle: it produces a visible artificial slab behind the ruined wall.
	# Collision shapes and navigation footprints are untouched.
	var visible_length: float = wall_length + 4.0
	var visible_thickness: float = maxf(wall_thickness + 24.0, 60.0) if screen_horizontal else maxf(wall_thickness * 2.0, 64.0)
	var wall_size: Vector2 = Vector2(visible_length, visible_thickness) if screen_horizontal else Vector2(visible_thickness, visible_length)
	# Select from the world axis, then counter-rotate the art only. The vertical
	# asset is authored upright, not a sideways horizontal wall. Alpha-padding is
	# excluded so the visible stone actually spans the collider, including caps.
	draw_set_transform(rect.get_center(), -global_rotation, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(-wall_size * 0.5, wall_size), _hd_wall_region(texture))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	for body_node: Node in get_children():
		var body: StaticBody2D = body_node as StaticBody2D
		if body == null: continue
		for shape_node: Node in body.get_children():
			var collision: CollisionShape2D = shape_node as CollisionShape2D
			if collision == null or not collision.shape is RectangleShape2D: continue
			var rectangle: RectangleShape2D = collision.shape as RectangleShape2D
			var center: Vector2 = body.position + collision.position
			var size: Vector2 = rectangle.size
			var rect: Rect2 = Rect2(center - size * 0.5, size)
			if _is_hd_visual():
				_draw_hd_wall(rect)
				continue
			draw_rect(rect.grow(3.0), Color("182b25"), true)
			draw_rect(rect, Color("654936"), true)
			if size.x >= size.y:
				draw_line(Vector2(rect.position.x + 8.0, center.y - 4.0), Vector2(rect.end.x - 8.0, center.y - 4.0), Color("8b6746"), 3.0, true)
				draw_line(Vector2(rect.position.x + 12.0, center.y + 5.0), Vector2(rect.end.x - 12.0, center.y + 5.0), Color("412f2c"), 2.0, true)
				for knot_x: float in range(int(rect.position.x + 20.0), int(rect.end.x - 10.0), 42):
					draw_circle(Vector2(knot_x, center.y), 4.0, Color("3b3029"))
			else:
				draw_line(Vector2(center.x - 4.0, rect.position.y + 8.0), Vector2(center.x - 4.0, rect.end.y - 8.0), Color("8b6746"), 3.0, true)
				draw_line(Vector2(center.x + 5.0, rect.position.y + 12.0), Vector2(center.x + 5.0, rect.end.y - 12.0), Color("412f2c"), 2.0, true)
				for knot_y: float in range(int(rect.position.y + 20.0), int(rect.end.y - 10.0), 42):
					draw_circle(Vector2(center.x, knot_y), 4.0, Color("3b3029"))
	if draw_debug_footprint:
		draw_rect(Rect2(-footprint_size * 0.5, footprint_size), Color(0.2, 1.0, 0.4, 0.3), false, 2.0)
