class_name GrandpaEnemyTrackingTest extends Node

func test_concrete_enemy_identities_count_for_grandpa_chores() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.begin_grandpa_chores()
	for identity: StringName in [&"wolf", &"goblin", &"archer_goblin", &"sword_goblin"]:
		progression.record_grandpa_enemy_defeat(identity)
	assert(progression.grandpa_wolves_defeated == 1)
	assert(progression.grandpa_goblins_defeated == 3)

func test_enemy_scenes_initialize_tracking_identity_on_tree_entry() -> void:
	var host: Node2D = Node2D.new()
	add_child(host)
	var expected: Array[StringName] = [&"goblin", &"archer_goblin", &"sword_goblin", &"wolf"]
	var scenes: Array[PackedScene] = [WaveSpawner.GOBLIN_SCENE, WaveSpawner.ARCHER_GOBLIN_SCENE, WaveSpawner.SWORD_GOBLIN_SCENE, WaveSpawner.WOLF_SCENE]
	for index: int in range(scenes.size()):
		var enemy: Enemy = scenes[index].instantiate() as Enemy
		host.add_child(enemy)
		assert(enemy.spawn_identity == expected[index])
		enemy.queue_free()
	host.queue_free()
