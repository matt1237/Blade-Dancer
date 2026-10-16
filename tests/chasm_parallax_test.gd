extends Node
const STAGE: PackedScene = preload("res://scenes/chasm/chasm_stage.tscn")
const OVERLAY = preload("res://scripts/experimental/chasm_parallax_overlay.gd")

func test_full_vista_coverage_fixed_size_and_depth() -> void:
	var stage: ChasmStage = STAGE.instantiate()
	add_child(stage)
	for viewport_size: Vector2 in [Vector2(1280,720), Vector2(1568,882), Vector2(1024,768), Vector2(1920,720), Vector2(720,1024)]:
		var vista = OVERLAY.new()
		stage.add_child(vista)
		vista.build(stage, viewport_size, Vector2.ONE * 1.3, true)
		assert(vista.get_child_count() == 1 and vista.distant.get_parent() == vista)
		assert(vista.distant.texture == OVERLAY.VISTA and vista.distant.z_index == -2)
		assert(vista.distant.scale.x == vista.distant.scale.y)
		var size: Vector2 = vista.image_rect().size
		if viewport_size == Vector2(1280,720): assert(size.is_equal_approx(Vector2(1736.6153846,977.3661538)))
		for zoom: float in [1.0,1.3,2.0]:
			for target: Vector2 in [Vector2(640,360),Vector2(640,26),Vector2(26,26),Vector2(1254,26),Vector2(1254,694),Vector2(26,694),Vector2(26,360),Vector2(1254,360),Vector2(640,694)]:
				var center: Vector2 = Main.clamp_presentation_center(target, OVERLAY.walking_presentation_rect(stage.arena_rect), viewport_size, Vector2.ONE * zoom)
				vista.update_camera(center)
				var footprint: Vector2 = viewport_size / zoom
				assert(vista.image_rect().grow(0.01).encloses(Rect2(center - footprint * 0.5, footprint)), "All four sides/corners covered")
				assert(vista.image_rect().size == size)
		vista.restore_perimeter()
		vista.free()
	stage.free()

func test_scroll_and_no_upper_camera_exception() -> void:
	var stage: ChasmStage = STAGE.instantiate()
	add_child(stage)
	var vista = OVERLAY.new()
	stage.add_child(vista)
	vista.build(stage, Vector2(1280,720), Vector2.ONE)
	var first: Vector2 = Vector2(280,180)
	var second: Vector2 = Vector2(1000,650)
	vista.update_camera(first)
	var screen: Vector2 = vista.distant.position - first
	vista.update_camera(second)
	assert((vista.distant.position - second - screen).is_equal_approx(-(second-first)*0.22))
	assert(OVERLAY.walking_presentation_rect(stage.arena_rect) == Main.presentation_rect_for_arena(stage.arena_rect))
	assert(OVERLAY.walking_camera_target(first,stage.arena_rect) == first)
	stage.free()

func test_exterior_disabled_normal_stage_and_population_preserved() -> void:
	var original: ChasmStage = STAGE.instantiate()
	var stage: ChasmStage = STAGE.instantiate()
	add_child(original)
	add_child(stage)
	original.population.population_seed = 42
	stage.population.population_seed = 42
	original.regenerate()
	stage.regenerate()
	var geometry: Array = _physics_snapshot(stage)
	var floor: Sprite2D = stage.get_node("Background")
	var transform: Transform2D = floor.transform
	var vista = OVERLAY.new()
	stage.add_child(vista)
	vista.build(stage, Vector2(1280,720), Vector2.ONE)
	assert(floor.visible and floor.transform == transform)
	assert(floor.texture.resource_path == "res://assets/generated/The Chasm Floor.png")
	for sprite: Sprite2D in stage.perimeter.get_children(): assert(not sprite.visible)
	for sprite: Sprite2D in original.perimeter.get_children(): assert(sprite.visible)
	assert(_physics_snapshot(stage) == geometry and _physics_snapshot(original) == geometry)
	for seed_value: int in [42,43,87193]:
		stage.population.population_seed = seed_value
		stage.regenerate()
		assert(stage.population.get_child_count() >= 8)
		for object: ChasmArenaObject in stage.population.get_children(): assert(object.visible and object.visual_sprite.visible)
		for sprite: Sprite2D in stage.perimeter.get_children(): assert(not sprite.visible)
	vista.restore_perimeter()
	for sprite: Sprite2D in stage.perimeter.get_children(): assert(sprite.visible)
	stage.free()
	original.free()

func _physics_snapshot(stage: Node) -> Array:
	var result: Array = []
	for node: Node in stage.find_children("*", "", true, false):
		if node is CollisionObject2D: result.append([stage.global_transform.affine_inverse()*node.global_transform,node.collision_layer,node.collision_mask])
		elif node is CollisionShape2D: result.append([stage.global_transform.affine_inverse()*node.global_transform,node.disabled,node.shape.get_class(),node.shape.get_rect()])
	return result
