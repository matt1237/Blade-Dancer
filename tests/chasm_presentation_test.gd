extends Node

const STAGE: PackedScene = preload("res://scenes/chasm/chasm_stage.tscn")

func test_shared_camera_authority_and_edge_travel() -> void:
	# Production helpers used by both zones and the no-save preview.
	var bounds: Rect2 = Main.presentation_rect_for_arena(Rect2(0, 0, 1280, 720))
	assert(bounds == Rect2(-360, -180, 2000, 1080))
	for zoom_value: float in [1.0, 1.3, 2.0, 2.15]:
		for target: Vector2 in [Vector2(640, 360), Vector2(-80, 30), Vector2(1360, 690)]:
			var center: Vector2 = Main.clamp_presentation_center(target, bounds, Vector2(1280, 720), Vector2.ONE * zoom_value)
			assert(center.x >= 280 and center.x <= 1000)
			assert(center.y >= 180 and center.y <= 540)
	assert(Main.clamp_presentation_center(Vector2.ZERO, bounds, Vector2(1280, 720), Vector2.ONE * 1.3) == Vector2(280, 180))
	assert(Main.clamp_presentation_center(Vector2.ZERO, bounds, Vector2(2600, 1500), Vector2.ONE) == bounds.get_center())
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var camera_source: String = source.get_slice("func _update_presentation_camera()", 1).get_slice("func _update_presentation_environment()", 0)
	assert(not camera_source.contains('active_adventure_zone == "chasm"'))
	assert(camera_source.contains('training_camera_zoom if visual_style == "hd" else 1.0'))
	assert(camera_source.contains("combat_presentation_fx.camera_rest_zoom = presentation_camera.zoom"))
	assert(camera_source.contains("player.velocity * 0.12") and camera_source.contains("experimental_bind_focus_active"))

func test_perimeter_is_external_presentation_only_and_persistent() -> void:
	var stage: ChasmStage = STAGE.instantiate() as ChasmStage
	get_tree().root.add_child(stage)
	assert(stage.get_playable_rect() == Rect2(26, 26, 1228, 668))
	var perimeter: ChasmPerimeter = stage.perimeter
	assert(perimeter != null and perimeter.decoration_bounds.size() > 30)
	var view: Rect2 = Main.presentation_rect_for_arena(stage.arena_rect)
	for bounds: Rect2 in perimeter.decoration_bounds:
		assert(view.encloses(bounds))
		assert(not bounds.intersects(stage.get_playable_rect()))
	var floor_count: int = 0
	var floor_coverage: Rect2 = stage.arena_rect
	for child: Node in perimeter.get_children():
		assert(child is Sprite2D and child.get_child_count() == 0)
		assert(child.get_groups().is_empty())
		var sprite: Sprite2D = child as Sprite2D
		if sprite.texture == (stage.get_node("Background") as Sprite2D).texture:
			floor_count += 1
			assert(sprite.scale == (stage.get_node("Background") as Sprite2D).scale)
			var offset: Vector2 = (sprite.position - stage.arena_rect.get_center()) / stage.arena_rect.size
			assert(sprite.flip_h == (offset.x != 0) and sprite.flip_v == (offset.y != 0))
			floor_coverage = floor_coverage.merge(Rect2(sprite.position - stage.arena_rect.size * 0.5, stage.arena_rect.size))
	assert(floor_count == 8)
	assert(floor_coverage == Rect2(-1280, -720, 3840, 2160))
	assert(floor_coverage.encloses(view.grow(80))) # Shake/lookahead overscan, no Forest leaks.
	var child_count: int = perimeter.get_child_count()
	stage.population.population_seed = 42
	stage.regenerate()
	assert(stage.population.get_child_count() == 10)
	stage.set_collision_enabled(false)
	assert(stage.population.get_child_count() == 0)
	stage.set_collision_enabled(true)
	stage.regenerate()
	assert(stage.perimeter == perimeter and perimeter.get_child_count() == child_count)
	stage.hide()
	assert(not perimeter.is_visible_in_tree())
	stage.queue_free()
	await get_tree().process_frame
