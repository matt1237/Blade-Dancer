extends Node
const RIG: PackedScene = preload("res://tests/chasm_walk_safe_rig.tscn")
const OVERLAY = preload("res://scripts/experimental/chasm_parallax_overlay.gd")

func test_adventure_doorways_and_signal() -> void:
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate()
	add_child(hub)
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	var card: Control = hub.adventure_card
	assert(not card.get_node("PXModeButton").visible)
	assert(not card.get_node("PXProtoButton").visible)
	var button: Button = card.get_node("ChasmTestButton")
	assert(button.visible and button.text == "Chasm test")
	var received: Array[String] = []
	hub.adventure_zone_requested.connect(func(zone: String) -> void: received.append(zone))
	button.pressed.emit()
	assert(received == ["chasm_test"])
	assert(card.get_node("ChasmButton").visible)
	hub.free()

func test_real_route_player_camera_drop_safety_and_cleanup() -> void:
	var main = RIG.instantiate()
	add_child(main)
	var player_id: int = main.player.get_instance_id()
	assert(main.chasm_test_active and main.active_adventure_zone == "chasm")
	assert(main.player.is_physics_processing() and not main.spawner.is_processing())
	assert(main.spawner.normal_spawning_suspended and not main.spawner.wave_active)
	assert(main.spawner.enemies_to_spawn == 0 and main.spawner.enemies_alive == 0)
	assert(main.chasm_stage.visible and main.chasm_stage.get_playable_rect() == Rect2(26, 26, 1228, 668))
	assert(main.chasm_stage.population.get_child_count() >= 8)
	assert(main.presentation_camera.zoom == Vector2.ONE * main.training_camera_zoom)
	assert(main.get_presentation_rect() == OVERLAY.walking_presentation_rect(main.get_gameplay_arena_rect()))
	var before: Dictionary = main.home_progression.to_save_data().duplicate(true)
	main.spawn_terrain_drop(Vector2(640, 360), "Iron Shard", 100)
	main.spawn_chest_loot(Vector2(640, 360))
	main.collect_drop("Iron Shard", 100)
	main.collect_gear_drop({"id": "test"})
	assert(main.home_progression.to_save_data() == before)
	assert(main.write_attempts == 0)
	for node: Node in main.get_children():
		assert(not node is DropPickup and not node is GearDropPickup)
	var vista = main.chasm_test_vista
	main.player.position = Vector2(800, 42)
	main._update_presentation_camera_follow(0.0, true)
	main._process(0.0)
	var first: Vector2 = vista.distant.position - main.presentation_camera.position
	var camera_first: Vector2 = main.presentation_camera.position
	main.player.position = Vector2(500, 42)
	main._update_presentation_camera_follow(0.0, true)
	main._process(0.0)
	var second: Vector2 = vista.distant.position - main.presentation_camera.position
	assert((second - first).is_equal_approx(-(main.presentation_camera.position - camera_first) * 0.22))
	assert(vista.distant.z_index < main.chasm_stage.get_node("Background").z_index)
	assert(main.presentation_camera.position == Main.clamp_presentation_center(main.player.position, Main.presentation_rect_for_arena(main.get_gameplay_arena_rect()), main.get_viewport_rect().size, main.presentation_camera.zoom))
	main._on_pause_return_home()
	assert(main.run_over and not main.chasm_test_active and main.chasm_test_vista == null)
	assert(main.home_menu.visible and get_tree().paused)
	assert(main.home_progression.to_save_data() == before and main.write_attempts == 0)
	assert(main.scoreboards["The Forest"].is_empty())
	for sprite: Node in main.chasm_stage.perimeter.get_children():
		assert(sprite.visible, "Upper exterior restored on leaving the experiment")
	get_tree().paused = false
	main.end_run_hub.adventure_zone_requested.emit("chasm")
	assert(main.player.get_instance_id() == player_id)
	assert(not main.chasm_test_active and main.chasm_test_vista == null)
	assert(main.spawner.is_processing() and not main.spawner.normal_spawning_suspended and main.spawner.wave_active)
	assert(main.get_presentation_rect() == Main.presentation_rect_for_arena(main.get_gameplay_arena_rect()))
	for sprite: Node in main.chasm_stage.perimeter.get_children(): assert(sprite.visible)
	main.spawner.set_process(false)
	main._on_adventure_zone_requested("chasm_test")
	main._start_backyard_run()
	assert(main.chasm_test_vista == null and not main.chasm_test_active)
	main.spawner.set_process(false)
	main.free()
	get_tree().paused = false
