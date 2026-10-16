class_name ChasmPerimeter extends Node2D
## Permanent presentation only: no ArenaObjects, bodies, groups, or drops.
## Owned by ChasmStage visibility; regeneration only retires the interior props.
var decoration_bounds: Array[Rect2] = []

func build(stage: ChasmStage) -> void:
	var arena: Rect2 = stage.arena_rect
	var background: Sprite2D = stage.get_node("Background") as Sprite2D
	# Mirror adjacent plates at the ORIGINAL world scale. Matching edge pixels
	# hide seams without stretching stones or changing the approved center plate.
	for y: int in range(-1, 2):
		for x: int in range(-1, 2):
			if x == 0 and y == 0: continue
			var plate: Sprite2D = Sprite2D.new()
			plate.texture = background.texture
			plate.scale = background.scale
			plate.position = arena.get_center() + Vector2(x, y) * arena.size
			plate.flip_h = x != 0
			plate.flip_v = y != 0
			plate.z_index = 0
			plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(plate)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 87193
	# Low rocky lip overlaps the wall band, never the playable interior.
	# Larger outer piles and sparse windswept trees distinguish the mine apron.
	for side: int in range(4):
		var horizontal: bool = side < 2
		var span: float = arena.size.x if horizontal else arena.size.y
		var count: int = ceili(span / 105.0)
		for index: int in range(count + 1):
			var along: float = float(index) * span / count
			var size: Vector2 = Vector2.ONE * rng.randf_range(135, 165)
			var point: Vector2
			if side == 0: point = Vector2(arena.position.x + along, arena.position.y - size.y * 0.5 + 20)
			elif side == 1: point = Vector2(arena.position.x + along, arena.end.y + size.y * 0.5 - 20)
			elif side == 2: point = Vector2(arena.position.x - size.x * 0.5 + 20, arena.position.y + along)
			else: point = Vector2(arena.end.x + size.x * 0.5 - 20, arena.position.y + along)
			_add_prop(ChasmArenaObject.IRON, point, size, index % 2 == 1)
	for point: Vector2 in [Vector2(-225, 100), Vector2(-210, 550), Vector2(1480, 180), Vector2(1510, 600), Vector2(210, -80), Vector2(1040, 800)]:
		var envelope: Vector2 = Vector2(150, 175) if point.y < 0 or point.y > arena.end.y else Vector2(190, 230)
		_add_prop(ChasmArenaObject.GNARLED, point, envelope, false)
	for point: Vector2 in [Vector2(-250, -80), Vector2(1470, -70), Vector2(-180, 800), Vector2(1460, 810)]:
		_add_prop(ChasmArenaObject.IRON, point, Vector2(170, 170), true)

func _add_prop(texture: Texture2D, point: Vector2, envelope: Vector2, flipped: bool) -> void:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * minf(envelope.x / texture.get_width(), envelope.y / texture.get_height())
	sprite.position = point
	sprite.flip_h = flipped
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Same depth as the interior props, whose insertion follows the perimeter.
	sprite.z_index = 1
	add_child(sprite)
	var size: Vector2 = texture.get_size() * sprite.scale
	decoration_bounds.append(Rect2(point - size * 0.5, size))
