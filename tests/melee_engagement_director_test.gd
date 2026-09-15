class_name MeleeEngagementDirectorTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
func _spawn_enemy(scene: PackedScene, position: Vector2, player: Player, director: MeleeEngagementDirector) -> Enemy:
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy._configure_concrete_enemy()
	enemy.position = position
	enemy.player_ref = player
	enemy.engagement_director = director
	return enemy

func _free_context(player: Player, director: MeleeEngagementDirector, enemies: Array[Enemy]) -> void:
	for enemy: Enemy in enemies: enemy.free()
	director.free()
	player.free()

func test_director_limits_intent_without_changing_damage_rules() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(640.0, 360.0)
	var director: MeleeEngagementDirector = MeleeEngagementDirector.new()
	director.player_ref = player
	var enemies: Array[Enemy] = [
		_spawn_enemy(WaveSpawner.TURKEY_SCENE, Vector2(700.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.GOBLIN_SCENE, Vector2(730.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.WOLF_SCENE, Vector2(760.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.OGRE_SCENE, Vector2(790.0, 360.0), player, director),
	]
	director._refresh_assignments(enemies)
	assert(director.pressure_holders.size() == 2, "Only two melee enemies should own close-pressure intent.")
	assert(director.attack_holders.size() == 1, "Only one melee enemy should own attack commitment intent.")
	var waiting_count: int = 0
	for enemy: Enemy in enemies:
		if enemy.engagement_role() == "waiting":
			waiting_count += 1
			assert(enemy.get_contact_damage() == enemy.contact_damage, "Waiting status must never suppress valid contact damage.")
	assert(waiting_count == 2, "Two of four melee enemies should wait outside the close-pressure layer.")
	var original_pressure: Array[int] = director.pressure_holders.duplicate()
	director.pressure_lease_left.clear()
	director.attack_lease_left.clear()
	director._refresh_assignments(enemies)
	for previous_holder_id: int in original_pressure:
		assert(not director.pressure_holders.has(previous_holder_id), "Expired pressure roles should rotate to waiting enemies.")
	var bug: Enemy = _spawn_enemy(WaveSpawner.BUG_SCENE, Vector2(820.0, 360.0), player, director)
	assert(bug.engagement_role() == "exempt", "Bugs operate outside melee engagement slots.")
	enemies.append(bug)
	_free_context(player, director, enemies)

func test_dead_waiting_enemy_is_removed_before_ring_spacing() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(640.0, 360.0)
	var director: MeleeEngagementDirector = MeleeEngagementDirector.new()
	director.player_ref = player
	var enemies: Array[Enemy] = [
		_spawn_enemy(WaveSpawner.TURKEY_SCENE, Vector2(680.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.GOBLIN_SCENE, Vector2(720.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.WOLF_SCENE, Vector2(760.0, 360.0), player, director),
		_spawn_enemy(WaveSpawner.OGRE_SCENE, Vector2(800.0, 360.0), player, director),
	]
	director._refresh_assignments(enemies)
	var waiting: Array[Enemy] = []
	for enemy: Enemy in enemies:
		if not director.has_pressure_slot(enemy): waiting.append(enemy)
	assert(waiting.size() == 2)
	var removed_enemy: Enemy = waiting[0]
	var surviving_enemy: Enemy = waiting[1]
	enemies.erase(removed_enemy)
	removed_enemy.free()
	var target: Vector2 = director.waiting_target(surviving_enemy)
	assert(target.distance_to(player.position) > 0.0, "A surviving waiter still needs a valid ring target after another enemy dies.")
	_free_context(player, director, enemies)

func test_waiting_enemy_peels_outward_when_crowded_inside() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(640.0, 360.0)
	var director: MeleeEngagementDirector = MeleeEngagementDirector.new()
	director.player_ref = player
	var first: Enemy = _spawn_enemy(WaveSpawner.TURKEY_SCENE, Vector2(650.0, 360.0), player, director)
	var second: Enemy = _spawn_enemy(WaveSpawner.GOBLIN_SCENE, Vector2(660.0, 360.0), player, director)
	var waiting: Enemy = _spawn_enemy(WaveSpawner.OGRE_SCENE, Vector2(670.0, 360.0), player, director)
	var enemies: Array[Enemy] = [first, second, waiting]
	director._refresh_assignments(enemies)
	assert(director.has_pressure_slot(first) and director.has_pressure_slot(second))
	assert(not director.has_pressure_slot(waiting))
	var away_from_player: Vector2 = player.global_position.direction_to(waiting.global_position)
	assert(waiting._apply_engagement_positioning(0.016), "A waiting melee enemy should use engagement positioning.")
	assert(waiting.velocity.dot(away_from_player) > 0.0, "A crowded waiting enemy should peel outward rather than push deeper.")
	assert(waiting.get_contact_damage() == waiting.contact_damage, "Peeling must not create hidden damage immunity.")
	_free_context(player, director, enemies)
