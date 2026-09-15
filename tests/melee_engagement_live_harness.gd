class_name MeleeEngagementLiveHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
	main.home_menu.visible = false
	main.end_run_hub.visible = false
	main.run_over = false
	main.spawner.set_process(false)
	main._clear_runtime_entities()
	await get_tree().process_frame
	main.player.global_position = Vector2(640.0, 360.0)
	main.player.max_health = 9999.0
	main.player.health = 9999.0
	main.player.set_physics_process(true)
	var enemy_scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE, WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]
	for index: int in range(enemy_scenes.size()):
		var enemy: Enemy = enemy_scenes[index].instantiate() as Enemy
		var angle: float = TAU * float(index) / float(enemy_scenes.size())
		enemy.global_position = main.player.global_position + Vector2.RIGHT.rotated(angle) * (115.0 + float(index % 3) * 32.0)
		main.add_child(enemy)
	for sample_index: int in range(8):
		await get_tree().create_timer(0.75).timeout
		if sample_index == 2 or sample_index == 4: _defeat_one_waiting_enemy()
		_print_engagement_sample(sample_index, main)

func _defeat_one_waiting_enemy() -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null and enemy.engagement_role() == "waiting":
			enemy.take_damage(9999.0)
			print("ENGAGEMENT STRESS removed waiting enemy id=", enemy.get_instance_id())
			return

func _print_engagement_sample(sample_index: int, main: Main) -> void:
	var role_counts: Dictionary[String, int] = {"attacker": 0, "pressure": 0, "waiting": 0, "exempt": 0}
	var inner_count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null: continue
		var role: String = enemy.engagement_role()
		role_counts[role] = role_counts.get(role, 0) + 1
		if enemy.global_position.distance_to(main.player.global_position) < 100.0: inner_count += 1
	print("ENGAGEMENT SAMPLE ", sample_index, " roles=", role_counts, " inner_under_100=", inner_count)
