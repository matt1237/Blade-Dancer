class_name BossArenaBorder extends Node2D

const HD_BORDER_TREE: Texture2D = preload("res://assets/generated/forest_border_tree_cluster_frame_0.png")
const HD_BORDER_SHRUB: Texture2D = preload("res://assets/generated/forest_border_shrub_cluster_frame_0.png")
const HD_BORDER_TREE_ALT: Texture2D = preload("res://assets/generated/forest_border_tree_cluster_alt_frame_0.png")
const HD_BORDER_SHRUB_ALT: Texture2D = preload("res://assets/generated/forest_border_shrub_cluster_alt_frame_0.png")
const HD_BOULDER: Texture2D = preload("res://assets/generated/forest_large_boulder_cluster_alt_frame_0.png")
const HD_FALLEN_LOG: Texture2D = preload("res://assets/generated/forest_fallen_log_horizontal_frame_0.png")
const HD_STANDING_STONE: Texture2D = preload("res://assets/generated/forest_standing_stone_frame_0.png")
const HD_BRACKEN: Texture2D = preload("res://assets/generated/forest_bracken_cluster_frame_0.png")
const HD_WILDFLOWER_GRASS: Texture2D = preload("res://assets/generated/forest_wildflower_grass_cluster_frame_0.png")
const HD_BROKEN_WALL_HORIZONTAL: Texture2D = preload("res://assets/generated/forest_broken_stone_wall_horizontal_frame_0.png")
const HD_BROKEN_WALL_VERTICAL: Texture2D = preload("res://assets/generated/forest_broken_stone_wall_vertical_frame_0.png")


## Permanent perimeter for the Zungar arena. Unlike generated terrain, this remains
## present after ArenaGenerator.prepare_boss_arena() clears normal modules.
@export var arena_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
@export var border_thickness: float = 52.0
@export var grass_height: float = 34.0

# These knobs affect only the optional small bracken / flower accents. The
# opaque soil, overlapping canopy and larger landmarks never lose coverage.
var edge_scale: float = 2.4
var edge_density: float = 0.55
var landmark_settings: Dictionary = {}
var _hd_prop_regions: Dictionary = {}

func apply_visual_settings(settings: Dictionary) -> void:
	var requested_scale: Variant = settings.get("edge_scale", 2.4)
	var requested_density: Variant = settings.get("edge_density", 0.55)
	edge_scale = 2.4
	edge_density = 0.55
	if (requested_scale is float or requested_scale is int) and is_finite(float(requested_scale)):
		edge_scale = clampf(float(requested_scale), 1.0, 4.0)
	if (requested_density is float or requested_density is int) and is_finite(float(requested_density)):
		edge_density = clampf(float(requested_density), 0.0, 1.0)
	for key: String in ["border_rocks", "border_logs", "border_stones", "border_ruins", "border_trees", "landmark_scale", "landmark_depth", "landmark_prominence"]:
		landmark_settings[key] = settings.get(key, 1.0 if key.begins_with("border_") or key == "landmark_scale" else 0.0)
	queue_redraw()

func _ready() -> void:
	z_index = 1
	_build_collision()
	queue_redraw()

func _build_collision() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "BossArenaPerimeterCollision"
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	# Centered exactly on the arena_rect edge — no extra offset. This is the single
	# source of truth for the physical wall; the grass art below must match it exactly.
	var rectangles: Array[Rect2] = [
		Rect2(arena_rect.position.x - border_thickness * 0.5, arena_rect.position.y - border_thickness * 0.5, arena_rect.size.x + border_thickness, border_thickness),
		Rect2(arena_rect.position.x - border_thickness * 0.5, arena_rect.end.y - border_thickness * 0.5, arena_rect.size.x + border_thickness, border_thickness),
		Rect2(arena_rect.position.x - border_thickness * 0.5, arena_rect.position.y, border_thickness, arena_rect.size.y),
		Rect2(arena_rect.end.x - border_thickness * 0.5, arena_rect.position.y, border_thickness, arena_rect.size.y)
	]
	for index: int in range(rectangles.size()):
		var collision: CollisionShape2D = CollisionShape2D.new()
		collision.name = "BorderCollision%d" % index
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rectangles[index].size
		collision.shape = shape
		collision.position = rectangles[index].get_center()
		body.add_child(collision)

func _is_hd_visual() -> bool:
	var current_scene: Node = get_tree().current_scene
	return current_scene != null and str(current_scene.get("visual_style")) == "hd"

func _draw_hd_border() -> void:
	# Continuous overscan enclosure: +Y in each local frame faces the clearing.
	# The authored hard top cuts face outward, hidden by successive canopy courses.
	# All art, including shadows, stays behind the existing collider inner face.
	var half: float = border_thickness * 0.5
	var origins: Array[Vector2] = [arena_rect.position, arena_rect.end,
		Vector2(arena_rect.position.x, arena_rect.end.y), Vector2(arena_rect.end.x, arena_rect.position.y)]
	var angles: Array[float] = [0.0, PI, -PI * 0.5, PI * 0.5]
	# Draw ALL foundations first so side foundations never erase corner foliage.
	for side: int in range(4):
		var span: float = arena_rect.size.x if side < 2 else arena_rect.size.y
		var margin: float = 360.0 if side < 2 else 180.0
		var depth: float = 180.0 if side < 2 else 360.0
		draw_set_transform(origins[side], angles[side])
		# Opaque leaf-litter beneath alpha holes, with an organic scalloped edge.
		# Covers the entire Rect(-360,-180,2000,1080), including all four corners.
		var soil: PackedVector2Array = PackedVector2Array([Vector2(-margin - 180.0, -depth - 180.0), Vector2(span + margin + 180.0, -depth - 180.0)])
		var count: int = ceili((span + margin * 2.0 + 360.0) / 18.0)
		for point: int in range(count + 1):
			var x: float = lerpf(span + margin + 180.0, -margin - 180.0, float(point) / count)
			soil.append(Vector2(x, half - 22.0 + 3.0 * sin(x * 0.071 + side) - (1.0 + sin(x * 0.019 + side * 1.7)) * 13.0))
		draw_colored_polygon(soil, Color("12271c"))
	# Clearing-outward layering buries the hard top edges under the natural lower
	# silhouette of the next course. Staggering and 65% overlap eliminate gaps.
	for course: int in range(11):
		for side: int in range(4):
			if side < 2 and course > 6:
				continue
			var span: float = arena_rect.size.x if side < 2 else arena_rect.size.y
			var margin: float = 360.0 if side < 2 else 180.0
			draw_set_transform(origins[side], angles[side])
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 7319 + side * 997 + course * 131
			var spacing: float = 43.0 if course == 0 else 62.0
			var x: float = -margin - 150.0 - float(course % 2) * spacing * 0.5
			while x < span + margin + 150.0:
				var size: Vector2 = Vector2(rng.randf_range(126.0, 164.0), rng.randf_range(100.0, 125.0))
				var texture: Texture2D = HD_BORDER_SHRUB if rng.randf() < 0.5 else HD_BORDER_SHRUB_ALT
				if course > 0:
					size = Vector2.ONE * rng.randf_range(182.0, 230.0)
					texture = HD_BORDER_SHRUB if rng.randf() < 0.5 else HD_BORDER_SHRUB_ALT
				var tip: float = half - 5.0 - course * 48.0 - rng.randf_range(0.0, 8.0) - (1.0 + sin(x * 0.019 + side * 1.7)) * 13.0
				var rect: Rect2 = Rect2(Vector2(x + rng.randf_range(-9.0, 9.0) - size.x * 0.5, tip - size.y), size)
				# Actual texture-shaped contact shadows between overlapping layers;
				# no rectangular shadow strips or inward-expanded combat boundary.
				draw_texture_rect(texture, Rect2(rect.position + Vector2(3.0, 4.0), rect.size), false, Color(0.035, 0.085, 0.055, 0.66))
				var light: float = clampf(0.96 - course * 0.065 + rng.randf_range(-0.045, 0.045), 0.48, 1.0)
				draw_texture_rect(texture, rect, false, Color(light * 0.91, light, light * 0.92, 1.0))
				if course == 0:
					# Preserve the canopy's seeded layout. Small bracken is now drawn
					# upright in the accent pass, never rotated toward the clearing.
					rng.randf()
				x += spacing
	draw_set_transform(Vector2.ZERO)
	_draw_hd_landmarks()
	_draw_hd_edge_accents()

func _hd_prop_region(texture: Texture2D) -> Rect2:
	if not _hd_prop_regions.has(texture):
		var region: Rect2 = Rect2(Vector2.ZERO, texture.get_size())
		var image: Image = texture.get_image()
		if image != null and not image.is_empty():
			var used: Rect2i = image.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				region = Rect2(used)
		_hd_prop_regions[texture] = region
	return _hd_prop_regions[texture]

func _hd_edge_prop_rect(side: int, along: float, size: Vector2, outset: float) -> Rect2:
	# Anchor the INWARD edge, not the center. Increasing size grows outward into
	# the solid perimeter, never onto walkable ground. All art remains upright.
	var half: float = border_thickness * 0.5
	var gap: float = maxf(outset, 6.0) # Includes room for the (2, 3) contact shadow.
	var x: float = lerpf(arena_rect.position.x, arena_rect.end.x, along)
	var y: float = lerpf(arena_rect.position.y, arena_rect.end.y, along)
	match side:
		0:
			return Rect2(Vector2(x - size.x * 0.5, arena_rect.position.y + half - gap - size.y), size)
		1:
			return Rect2(Vector2(x - size.x * 0.5, arena_rect.end.y - half + gap), size)
		2:
			return Rect2(Vector2(arena_rect.position.x + half - gap - size.x, y - size.y * 0.5), size)
		_:
			return Rect2(Vector2(arena_rect.end.x - half + gap, y - size.y * 0.5), size)

func _draw_hd_edge_prop(texture: Texture2D, rect: Rect2, tint: Color) -> void:
	var region: Rect2 = _hd_prop_region(texture)
	draw_texture_rect_region(texture, Rect2(rect.position + Vector2(2.0, 3.0), rect.size), region, Color(0.035, 0.085, 0.055, 0.5))
	draw_texture_rect_region(texture, rect, region, tint)

func _draw_hd_landmarks() -> void:
	# A few staggered landmarks, not matching rows of the same object on each
	# side. These are independently tunable and remain outside the solid inner edge.
	var landmark_scale: float = float(landmark_settings.get("landmark_scale", 1.0))
	var landmark_depth: float = float(landmark_settings.get("landmark_depth", 0.0))
	var prominence: float = float(landmark_settings.get("landmark_prominence", 0.0))
	var saved_z: int = z_index
	if prominence > 0.0: z_index = saved_z + 1
	var tree_factor: int = clampi(roundi(float(landmark_settings.get("border_trees", 1.0))), 0, 3)
	if tree_factor > 0:
		_draw_hd_edge_prop(HD_BORDER_TREE, _hd_edge_prop_rect(2, 0.27, Vector2(144.0, 166.0) * landmark_scale, 18.0 + landmark_depth), Color(0.88, 0.95, 0.88))
		_draw_hd_edge_prop(HD_BORDER_TREE_ALT, _hd_edge_prop_rect(3, 0.76, Vector2(152.0, 174.0) * landmark_scale, 20.0 + landmark_depth), Color(0.9, 0.96, 0.89))
	var category_specs: Array[Dictionary] = [
		{"key": "border_rocks", "texture": HD_BOULDER, "size": Vector2(96.0, 76.0), "side": 0},
		{"key": "border_logs", "texture": HD_FALLEN_LOG, "size": Vector2(122.0, 58.0), "side": 1},
		{"key": "border_stones", "texture": HD_STANDING_STONE, "size": Vector2(62.0, 92.0), "side": 2},
		{"key": "border_ruins", "texture": HD_BROKEN_WALL_HORIZONTAL, "size": Vector2(150.0, 72.0), "side": 0}
	]
	for category: Dictionary in category_specs:
		var amount: int = clampi(roundi(float(landmark_settings.get(str(category["key"]), 1.0))), 0, 3)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 59131 + int(category["side"]) * 811 + str(category["key"]).hash()
		for index: int in range(amount):
			var along: float = (float(index) + rng.randf_range(0.25, 0.8)) / maxf(float(amount), 1.0)
			var size: Vector2 = category["size"] * landmark_scale * rng.randf_range(0.9, 1.1)
			var rect: Rect2 = _hd_edge_prop_rect(int(category["side"]), along, size, 12.0 + landmark_depth)
			_draw_hd_edge_prop(category["texture"], rect, Color(0.92, 0.96, 0.9))
	z_index = saved_z

func _draw_hd_edge_accents() -> void:
	var count: int = roundi(95.0 * edge_density)
	var perimeter: float = 2.0 * (arena_rect.size.x + arena_rect.size.y)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for index: int in range(95):
		# A stable, evenly spread subset: density removes only accents, without
		# reshuffling surviving props or changing the foundation / canopy RNG.
		if posmod(index * 37, 95) >= count:
			continue
		rng.seed = 41923 + index * 997
		var distance: float = (float(index) + rng.randf_range(0.2, 0.8)) * perimeter / 95.0
		var side: int = 0
		var span: float = arena_rect.size.x
		while side < 3 and distance >= span:
			distance -= span
			side += 1
			span = arena_rect.size.x if side < 2 else arena_rect.size.y
		var along: float = distance / maxf(span, 1.0)
		var bracken: bool = index % 3 == 1
		var texture: Texture2D = HD_BRACKEN if bracken else HD_WILDFLOWER_GRASS
		var base_size: Vector2 = Vector2(23.0, 16.0) if bracken else Vector2(18.0, 18.0)
		var size: Vector2 = base_size * edge_scale * rng.randf_range(0.85, 1.15)
		var rect: Rect2 = _hd_edge_prop_rect(side, along, size, rng.randf_range(6.0, 18.0))
		_draw_hd_edge_prop(texture, rect, Color(0.85, 0.94, 0.82, 0.9))

# Retained as an unused authored-prop reference; HD uses the continuous canopy above.
func _draw_hd_border_sparse_reference() -> void:
	# The HD border is assembled from authored silhouettes. No stretched plate or
	# repeated texture strip is used, so the playable edge reads as real foliage.
	# ForestFloor paints the complete visual rectangle underneath this artwork. Do
	# not draw opaque rectangular bands here; they create the side seams we are
	# deliberately replacing with layered foliage.
	var tree_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 36.0, arena_rect.position.y - 54.0),
		Vector2(arena_rect.position.x + 248.0, arena_rect.position.y - 60.0),
		Vector2(arena_rect.position.x + 620.0, arena_rect.position.y - 48.0),
		Vector2(arena_rect.end.x - 240.0, arena_rect.position.y - 55.0),
		Vector2(arena_rect.end.x - 28.0, arena_rect.position.y - 50.0),
		Vector2(arena_rect.position.x + 18.0, arena_rect.end.y + 54.0),
		Vector2(arena_rect.position.x + 310.0, arena_rect.end.y + 60.0),
		Vector2(arena_rect.position.x + 700.0, arena_rect.end.y + 52.0),
		Vector2(arena_rect.end.x - 260.0, arena_rect.end.y + 58.0),
		Vector2(arena_rect.end.x - 24.0, arena_rect.end.y + 54.0),
		Vector2(arena_rect.position.x - 58.0, arena_rect.position.y + 210.0),
		Vector2(arena_rect.position.x - 55.0, arena_rect.end.y - 210.0),
		Vector2(arena_rect.end.x + 58.0, arena_rect.position.y + 220.0),
		Vector2(arena_rect.end.x + 58.0, arena_rect.end.y - 205.0)
	]
	var tree_sizes: Array[Vector2] = [
		Vector2(172.0, 172.0), Vector2(132.0, 132.0), Vector2(148.0, 148.0), Vector2(138.0, 138.0),
		Vector2(180.0, 180.0), Vector2(156.0, 156.0), Vector2(132.0, 132.0), Vector2(164.0, 164.0),
		Vector2(146.0, 146.0), Vector2(178.0, 178.0), Vector2(126.0, 126.0), Vector2(144.0, 144.0),
		Vector2(132.0, 132.0), Vector2(152.0, 152.0)
	]
	for tree_index: int in range(tree_positions.size()):
		var tree_size: Vector2 = tree_sizes[tree_index]
		var tree_center: Vector2 = tree_positions[tree_index]
		var tree_texture: Texture2D = HD_BORDER_TREE_ALT if tree_index % 3 == 1 else HD_BORDER_TREE
		draw_texture_rect(tree_texture, Rect2(tree_center - tree_size * 0.5, tree_size), false)
	var shrub_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 116.0, arena_rect.position.y - 34.0),
		Vector2(arena_rect.position.x + 420.0, arena_rect.position.y - 30.0),
		Vector2(arena_rect.position.x + 840.0, arena_rect.position.y - 42.0),
		Vector2(arena_rect.end.x - 112.0, arena_rect.position.y - 30.0),
		Vector2(arena_rect.position.x + 142.0, arena_rect.end.y + 30.0),
		Vector2(arena_rect.position.x + 520.0, arena_rect.end.y + 24.0),
		Vector2(arena_rect.position.x + 940.0, arena_rect.end.y + 38.0),
		Vector2(arena_rect.end.x - 130.0, arena_rect.end.y + 26.0),
		Vector2(arena_rect.position.x - 38.0, arena_rect.position.y + 112.0),
		Vector2(arena_rect.position.x - 40.0, arena_rect.position.y + 440.0),
		Vector2(arena_rect.end.x + 38.0, arena_rect.position.y + 120.0),
		Vector2(arena_rect.end.x + 42.0, arena_rect.position.y + 470.0)
	]
	var shrub_sizes: Array[Vector2] = [Vector2(122.0, 92.0), Vector2(106.0, 82.0), Vector2(136.0, 102.0), Vector2(116.0, 88.0), Vector2(132.0, 98.0), Vector2(110.0, 84.0), Vector2(126.0, 94.0), Vector2(114.0, 86.0), Vector2(108.0, 82.0), Vector2(132.0, 98.0), Vector2(118.0, 88.0), Vector2(128.0, 96.0)]
	for shrub_index: int in range(shrub_positions.size()):
		var shrub_size: Vector2 = shrub_sizes[shrub_index]
		var shrub_center: Vector2 = shrub_positions[shrub_index]
		var shrub_texture: Texture2D = HD_BORDER_SHRUB_ALT if shrub_index % 3 == 1 else HD_BORDER_SHRUB
		draw_texture_rect(shrub_texture, Rect2(shrub_center - shrub_size * 0.5, shrub_size), false)
	var boulder_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 164.0, arena_rect.position.y - 48.0),
		Vector2(arena_rect.end.x - 178.0, arena_rect.position.y - 44.0),
		Vector2(arena_rect.position.x + 170.0, arena_rect.end.y + 48.0),
		Vector2(arena_rect.end.x - 180.0, arena_rect.end.y + 44.0)
	]
	for boulder_position: Vector2 in boulder_positions:
		draw_texture_rect(HD_BOULDER, Rect2(boulder_position - Vector2(58.0, 42.0), Vector2(116.0, 84.0)), false)
	var log_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 430.0, arena_rect.position.y - 48.0),
		Vector2(arena_rect.end.x - 470.0, arena_rect.end.y + 48.0),
		Vector2(arena_rect.position.x + 70.0, arena_rect.end.y + 52.0)
	]
	for log_position: Vector2 in log_positions:
		draw_texture_rect(HD_FALLEN_LOG, Rect2(log_position - Vector2(76.0, 44.0), Vector2(152.0, 88.0)), false)
	var stone_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 78.0, arena_rect.position.y - 70.0),
		Vector2(arena_rect.end.x - 74.0, arena_rect.position.y - 64.0),
		Vector2(arena_rect.position.x + 78.0, arena_rect.end.y + 70.0),
		Vector2(arena_rect.end.x - 80.0, arena_rect.end.y + 64.0)
	]
	for stone_position: Vector2 in stone_positions:
		draw_texture_rect(HD_STANDING_STONE, Rect2(stone_position - Vector2(42.0, 58.0), Vector2(84.0, 116.0)), false)
	var wall_horizontal_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 360.0, arena_rect.position.y - 44.0),
		Vector2(arena_rect.end.x - 350.0, arena_rect.end.y + 44.0)
	]
	for wall_position: Vector2 in wall_horizontal_positions:
		draw_texture_rect(HD_BROKEN_WALL_HORIZONTAL, Rect2(wall_position - Vector2(78.0, 38.0), Vector2(156.0, 76.0)), false)
	var wall_vertical_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x - 48.0, arena_rect.position.y + 310.0),
		Vector2(arena_rect.end.x + 48.0, arena_rect.position.y + 350.0)
	]
	for wall_position: Vector2 in wall_vertical_positions:
		draw_texture_rect(HD_BROKEN_WALL_VERTICAL, Rect2(wall_position - Vector2(38.0, 78.0), Vector2(76.0, 156.0)), false)
	var bracken_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 260.0, arena_rect.position.y - 48.0),
		Vector2(arena_rect.position.x + 720.0, arena_rect.position.y - 44.0),
		Vector2(arena_rect.end.x - 270.0, arena_rect.end.y + 48.0),
		Vector2(arena_rect.position.x + 420.0, arena_rect.end.y + 44.0),
		Vector2(arena_rect.position.x - 70.0, arena_rect.position.y + 500.0),
		Vector2(arena_rect.end.x + 70.0, arena_rect.position.y + 520.0)
	]
	for bracken_position: Vector2 in bracken_positions:
		draw_texture_rect(HD_BRACKEN, Rect2(bracken_position - Vector2(58.0, 43.0), Vector2(116.0, 86.0)), false)
	var flower_positions: Array[Vector2] = [
		Vector2(arena_rect.position.x + 210.0, arena_rect.position.y - 42.0),
		Vector2(arena_rect.position.x + 560.0, arena_rect.position.y - 38.0),
		Vector2(arena_rect.end.x - 210.0, arena_rect.end.y + 42.0),
		Vector2(arena_rect.position.x + 770.0, arena_rect.end.y + 38.0),
		Vector2(arena_rect.position.x - 50.0, arena_rect.position.y + 170.0),
		Vector2(arena_rect.end.x + 52.0, arena_rect.position.y + 190.0)
	]
	for flower_position: Vector2 in flower_positions:
		draw_texture_rect(HD_WILDFLOWER_GRASS, Rect2(flower_position - Vector2(36.0, 36.0), Vector2(72.0, 72.0)), false)

func _draw() -> void:
	if _is_hd_visual():
		_draw_hd_border()
		return
	var dark_grass: Color = Color("123d2c")
	var deep_grass: Color = Color("0b281f")
	var edge_highlight: Color = Color("2b6842")
	var half: float = border_thickness * 0.5
	# Solid dark strips make the playable boundary unmistakable. Same rects as collision above.
	draw_rect(Rect2(arena_rect.position.x - half, arena_rect.position.y - half, arena_rect.size.x + border_thickness, border_thickness), deep_grass)
	draw_rect(Rect2(arena_rect.position.x - half, arena_rect.end.y - half, arena_rect.size.x + border_thickness, border_thickness), deep_grass)
	draw_rect(Rect2(arena_rect.position.x - half, arena_rect.position.y, border_thickness, arena_rect.size.y), deep_grass)
	draw_rect(Rect2(arena_rect.end.x - half, arena_rect.position.y, border_thickness, arena_rect.size.y), deep_grass)
	# Tall irregular grass along the inside edge gives the wall a natural silhouette.
	for x: int in range(int(arena_rect.position.x), int(arena_rect.end.x), 18):
		var top_x: float = float(x)
		var top_y: float = arena_rect.position.y + 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(top_x - 8.0, top_y + 25.0), Vector2(top_x - 2.0, top_y - grass_height), Vector2(top_x + 3.0, top_y + 25.0)]), dark_grass)
		draw_colored_polygon(PackedVector2Array([Vector2(top_x + 1.0, top_y + 25.0), Vector2(top_x + 9.0, top_y - grass_height * 0.72), Vector2(top_x + 12.0, top_y + 25.0)]), edge_highlight)
		var bottom_y: float = arena_rect.end.y - 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(top_x - 8.0, bottom_y - 25.0), Vector2(top_x - 2.0, bottom_y + grass_height), Vector2(top_x + 3.0, bottom_y - 25.0)]), dark_grass)
		draw_colored_polygon(PackedVector2Array([Vector2(top_x + 1.0, bottom_y - 25.0), Vector2(top_x + 9.0, bottom_y + grass_height * 0.72), Vector2(top_x + 12.0, bottom_y - 25.0)]), edge_highlight)
	for y: int in range(int(arena_rect.position.y), int(arena_rect.end.y), 18):
		var left_y: float = float(y)
		var left_x: float = arena_rect.position.x + 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(left_x + 25.0, left_y - 8.0), Vector2(left_x - grass_height, left_y - 2.0), Vector2(left_x + 25.0, left_y + 3.0)]), dark_grass)
		draw_colored_polygon(PackedVector2Array([Vector2(left_x + 25.0, left_y + 1.0), Vector2(left_x - grass_height * 0.72, left_y + 9.0), Vector2(left_x + 25.0, left_y + 12.0)]), edge_highlight)
		var right_x: float = arena_rect.end.x - 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(right_x - 25.0, left_y - 8.0), Vector2(right_x + grass_height, left_y - 2.0), Vector2(right_x - 25.0, left_y + 3.0)]), dark_grass)
		draw_colored_polygon(PackedVector2Array([Vector2(right_x - 25.0, left_y + 1.0), Vector2(right_x + grass_height * 0.72, left_y + 9.0), Vector2(right_x - 25.0, left_y + 12.0)]), edge_highlight)
