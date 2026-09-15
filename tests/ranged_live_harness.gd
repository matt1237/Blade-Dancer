class_name RangedLiveHarness extends Node

func _ready() -> void:
	var main: Main = get_parent() as Main
	await get_tree().process_frame
	await get_tree().process_frame
	main.player.max_health = 9999.0
	main.player.health = 9999.0
	main._set_dev_start_wave(3)
	main._start_forest_run()
	await get_tree().create_timer(6.0, true, false, true).timeout
	print("RANGED HARNESS enemies=", get_tree().get_nodes_in_group("enemies").size(), " projectiles=", get_tree().get_nodes_in_group("enemy_projectiles").size())
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null: print("ENEMY name=", enemy.spawn_identity, " fire_timer=", enemy.fire_timer, " sight=", enemy._has_player_line_of_sight())
