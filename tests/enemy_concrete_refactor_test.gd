class_name EnemyConcreteRefactorTest extends Node

const NAMED_SCENES: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]

func test_named_scenes_create_concrete_classes_with_preserved_rewards() -> void:
	var expected_scores: Array[int] = [100, 150, 125, 150, 300]
	var expected_names: Array[StringName] = [&"turkey", &"goblin", &"bug", &"wolf", &"ogre"]
	for index: int in range(NAMED_SCENES.size()):
		var enemy: Enemy = NAMED_SCENES[index].instantiate() as Enemy
		enemy._configure_concrete_enemy()
		assert(enemy.spawn_balance_key() == expected_names[index])
		assert(enemy.score_value == expected_scores[index])
		assert((enemy is Turkey) or (enemy is Goblin) or (enemy is Bug) or (enemy is Wolf) or (enemy is Ogre))
		enemy.free()

func test_ai_and_equipment_capabilities_are_explicit() -> void:
	var turkey: Turkey = WaveSpawner.TURKEY_SCENE.instantiate() as Turkey
	var goblin: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	var bug: Bug = WaveSpawner.BUG_SCENE.instantiate() as Bug
	var wolf: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	for enemy: Enemy in [turkey, goblin, bug, wolf, ogre]: enemy._configure_concrete_enemy()
	assert(goblin.moving_weapon_enabled and goblin.spear_visual_enabled)
	assert(not bug.participates_in_melee_engagement)
	assert(wolf.charge_pose_enabled and wolf.charge_warning_tint_enabled)
	assert(ogre.shield_enabled and ogre.grapple_weight == Enemy.GrappleWeight.MEDIUM)
	assert(not turkey.shield_enabled and not goblin.shield_enabled and not bug.shield_enabled and not wolf.shield_enabled)
	for enemy: Enemy in [turkey, goblin, bug, wolf, ogre]: enemy.free()

func test_wave_unlocks_preserve_original_named_composition() -> void:
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.current_wave = 1
	assert(spawner._available_enemy_scenes() == [WaveSpawner.TURKEY_SCENE], "Wave 1 should be Turkey only.")
	spawner.current_wave = 5
	var available: Array[PackedScene] = spawner._available_enemy_scenes()
	# The later "Swords and bows!" update added the Sword and Archer Goblin variants
	# to the spawn table, so wave 5 is no longer the original five alone. The original
	# named composition must still unlock, in order, alongside those variants.
	var original_order: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]
	var cursor: int = 0
	for scene: PackedScene in available:
		if cursor < original_order.size() and scene == original_order[cursor]:
			cursor += 1
	assert(cursor == original_order.size(), "Wave 5 must still unlock every original named enemy in order.")
	assert(available.has(WaveSpawner.SWORD_GOBLIN_SCENE) and available.has(WaveSpawner.ARCHER_GOBLIN_SCENE), "Wave 5 must also unlock the Sword and Archer Goblin variants.")
	spawner.free()

func test_base_and_non_ogre_enemies_do_not_block_chakram() -> void:
	var base: Enemy = preload("res://scenes/enemy.tscn").instantiate() as Enemy
	assert(not base.shield_enabled)
	assert(not base.chakram_blocked_from_front(Vector2.RIGHT * 24.0))
	base.chakram_hit_from_behind(Vector2.RIGHT)
	assert(is_zero_approx(base.stun_left))
	base.free()
