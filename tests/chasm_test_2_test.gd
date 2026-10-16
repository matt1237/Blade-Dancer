extends Node
const RIG: PackedScene = preload("res://tests/chasm_walk_safe_rig.tscn")
const PLATE = preload("res://scripts/experimental/chasm_test_2_painting.gd")

func test_button_layout_and_distinct_route() -> void:
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate()
	add_child(hub)
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	var buttons: Array[Button] = []
	var received: Array[String] = []
	hub.adventure_zone_requested.connect(func(zone: String) -> void: received.append(zone))
	for name_value: String in ["ForestButton", "ChasmButton", "BackyardButton", "ChasmTestButton", "ChasmTest2Button", "TownButton"]:
		var button: Button = hub.adventure_card.get_node(name_value)
		assert(button.visible)
		assert(Rect2(Vector2.ZERO, hub.size).encloses(Rect2(hub.adventure_card.position + button.position, button.size)))
		for other: Button in buttons: assert(not button.get_rect().intersects(other.get_rect()))
		buttons.append(button)
	assert(buttons[3].text == "Chasm test" and buttons[4].text == "Chasm Test 2")
	buttons[3].pressed.emit()
	buttons[4].pressed.emit()
	buttons[1].pressed.emit()
	assert(received == ["chasm_test", "chasm_test_2", "chasm"])
	hub.free()

func test_full_fixed_painting_geometry_camera_economy_and_cleanup() -> void:
	var main = RIG.instantiate()
	add_child(main)
	var player_id: int = main.player.get_instance_id()
	var before: Dictionary = main.home_progression.to_save_data().duplicate(true)
	var old_geometry: Array = _physics_snapshot(main.chasm_stage)
	main.end_run_hub.adventure_zone_requested.emit("chasm_test_2")
	assert(main.chasm_test_active and main.chasm_test_style == "chasm_test_2")
	assert(main.active_adventure_zone == "chasm" and main.player.get_instance_id() == player_id)
	assert(main.player.is_physics_processing() and not main.spawner.is_processing())
	assert(main.spawner.normal_spawning_suspended and not main.spawner.wave_active and main.spawner.enemies_to_spawn == 0)
	assert(_physics_snapshot(main.chasm_stage) == old_geometry)
	assert(main.chasm_stage.get_playable_rect() == Rect2(26, 26, 1228, 668))
	assert(not main.chasm_stage.get_node("Background").visible and not main.chasm_stage.perimeter.visible)
	var vista = main.chasm_test_vista
	var sprite: Sprite2D = vista.painting
	assert(sprite.texture == PLATE.PAINTING and sprite.texture.get_size() == Vector2(1536, 1024))
	assert(sprite.texture.resource_path == "res://assets/generated/ChasmTest3.png")
	assert(vista.distant.texture == Main.CHASM_TEST_OVERLAY.VISTA and vista.distant.z_index < sprite.z_index)
	assert(not sprite.region_enabled and not sprite.texture is AtlasTexture)
	assert(sprite.scale.x == sprite.scale.y and not sprite.flip_h and not sprite.flip_v)
	assert(vista.get_child_count() == 2 and vista.get_child(1) == sprite)
	var fixed_transform: Transform2D = sprite.global_transform
	var image_bounds: Rect2 = PLATE.painting_rect(main.chasm_stage.get_playable_rect())
	assert(is_equal_approx(sprite.scale.x, 1228.0 / 1000.0))
	assert(image_bounds.size.x < 1900.0 and image_bounds.size.y < 1260.0)
	var source_playable: Rect2 = Rect2((main.chasm_stage.get_playable_rect().position-image_bounds.position)/sprite.scale, main.chasm_stage.get_playable_rect().size/sprite.scale)
	assert(PLATE.PRESENTATION_SOURCE_FLOOR.grow(0.01).encloses(source_playable))
	assert(main.get_presentation_rect() == PLATE.presentation_rect(main.get_gameplay_arena_rect(),main.chasm_stage.get_playable_rect()))
	for point: Vector2 in [Vector2(640, 360), Vector2(42, 42), Vector2(1238, 42), Vector2(1238, 678), Vector2(42, 678)]:
		main.player.position = point
		main._update_presentation_camera_follow(0.0, true)
		vista.update_camera(main.presentation_camera.position)
		assert(sprite.global_transform == fixed_transform)
		assert(main.presentation_camera.zoom == Vector2.ONE * main.training_camera_zoom)
		assert(main.presentation_camera.position == Main.clamp_presentation_center(point, main.get_presentation_rect(), main.get_viewport_rect().size, main.presentation_camera.zoom))
		var visible_size: Vector2 = main.get_viewport_rect().size / main.presentation_camera.zoom.min(Vector2.ONE)
		assert(vista.image_rect().grow(0.01).encloses(Rect2(main.presentation_camera.position - visible_size * 0.5, visible_size)))
		var actual_view: Rect2 = Rect2(main.presentation_camera.position - main.get_viewport_rect().size / main.presentation_camera.zoom * 0.5, main.get_viewport_rect().size / main.presentation_camera.zoom)
		assert(actual_view.has_point(point)) # Bottom clamp must not hide the player.
		# At the upper corners the existing follow now reveals the actual side rocks.
		if point.y == 42.0:
			var side_source: Vector2 = Vector2(100, 420) if point.x < 640.0 else Vector2(1436, 420)
			assert(actual_view.has_point(image_bounds.position + side_source * sprite.scale))
	main.spawn_terrain_drop(Vector2(640, 360), "Iron Shard", 100)
	main.spawn_chest_loot(Vector2(640, 360))
	main.collect_drop("Iron Shard", 100)
	main.collect_gear_drop({"id": "test2"})
	assert(main.home_progression.to_save_data() == before and main.write_attempts == 0)
	for node: Node in main.get_children(): assert(not node is DropPickup and not node is GearDropPickup)
	assert(main.run_loot.snapshot().is_empty() or main.run_loot.snapshot() == RunLootRecord.new().snapshot())
	main._on_pause_return_home()
	assert(main.run_over and main.chasm_test_vista == null and main.chasm_test_style.is_empty())
	assert(main.home_menu.visible and main.chasm_stage.get_node("Background").visible and main.chasm_stage.perimeter.visible)
	assert(main.home_progression.to_save_data() == before and main.write_attempts == 0 and main.scoreboards["The Forest"].is_empty())
	main._on_adventure_zone_requested("chasm_test")
	assert(main.chasm_test_vista.get_script() == Main.CHASM_TEST_OVERLAY)
	assert(main.get_presentation_rect() == Main.CHASM_TEST_OVERLAY.walking_presentation_rect(main.get_gameplay_arena_rect()))
	main._on_adventure_zone_requested("chasm")
	assert(not main.chasm_test_active and main.chasm_test_vista == null and main.chasm_stage.perimeter.visible)
	assert(main.spawner.is_processing() and not main.spawner.normal_spawning_suspended)
	main.spawner.set_process(false)
	main._on_adventure_zone_requested("chasm_test_2")
	main._start_backyard_run()
	assert(not main.chasm_test_active and main.chasm_test_vista == null)
	main.spawner.set_process(false)
	main.free()
	get_tree().paused = false

func test_shared_vista_covers_foreground_exterior_at_every_zoom_and_corner() -> void:
	var stage: ChasmStage = preload("res://scenes/chasm/chasm_stage.tscn").instantiate()
	add_child(stage)
	for viewport_size: Vector2 in [Vector2(1280,720),Vector2(1568,882),Vector2(1024,768),Vector2(1920,720),Vector2(720,1024)]:
		var vista = PLATE.new()
		stage.add_child(vista)
		vista.build(stage,viewport_size,Vector2.ONE * 1.3)
		var fixed: Transform2D = vista.painting.transform
		var size: Vector2 = vista.image_rect().size
		for zoom: float in [1.0,1.3,2.0]:
			for target: Vector2 in [Vector2(640,360),Vector2(42,42),Vector2(1238,42),Vector2(1238,678),Vector2(42,678),Vector2(42,360),Vector2(1238,360),Vector2(640,42),Vector2(640,678)]:
				var center: Vector2 = Main.clamp_presentation_center(target,vista.presentation_bounds,viewport_size,Vector2.ONE * zoom)
				vista.update_camera(center)
				var visible_size: Vector2 = viewport_size / zoom
				assert(vista.image_rect().grow(0.01).encloses(Rect2(center-visible_size*0.5,visible_size)))
				assert(vista.painting.transform == fixed and vista.image_rect().size == size)
		vista.restore_perimeter()
		vista.free()
	stage.free()

func test_source_and_imported_alpha_preserved() -> void:
	var source: Image = Image.new()
	assert(source.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/generated/ChasmTest3.png")) == OK)
	var imported: Image = PLATE.PAINTING.get_image()
	if imported.is_compressed(): imported.decompress()
	assert(source.get_size() == Vector2i(1536,1024) and imported.get_size() == source.get_size())
	var zeros: int = 0
	for y: int in source.get_height():
		for x: int in source.get_width():
			var a: float = source.get_pixel(x,y).a
			assert(a == imported.get_pixel(x,y).a)
			if a == 0.0: zeros += 1
	assert(zeros == 164332, "Preserve actual transparent exterior, not a brown RGB mask")
	for point: Vector2i in [Vector2i(0,0),Vector2i(1535,0),Vector2i(0,1023),Vector2i(1535,1023)]: assert(source.get_pixelv(point).a == 0.0)
	assert(source.get_pixel(768,512).a > 0.98)

func _physics_snapshot(stage: Node) -> Array:
	var result: Array = []
	for node: Node in stage.find_children("*", "", true, false):
		if node is CollisionObject2D: result.append([stage.global_transform.affine_inverse() * node.global_transform, node.collision_layer, node.collision_mask])
		elif node is CollisionShape2D: result.append([stage.global_transform.affine_inverse() * node.global_transform, node.disabled, node.shape.get_class(), node.shape.get_rect()])
	return result
