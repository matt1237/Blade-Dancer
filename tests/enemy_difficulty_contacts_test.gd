class_name EnemyDifficultyContactsTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _player_body() -> Node2D:
	var source: Player = PLAYER_SCENE.instantiate() as Player
	var source_body: CollisionShape2D = source.get_node("CollisionShape2D") as CollisionShape2D
	var body: CollisionShape2D = CollisionShape2D.new()
	body.name = "CollisionShape2D"
	body.shape = source_body.shape.duplicate() as Shape2D
	var player: CharacterBody2D = CharacterBody2D.new()
	player.add_child(body)
	add_child(player)
	source.free()
	return player

func test_wolf_and_ogre_reject_impulses_only_during_charge() -> void:
	var player: Node2D = _player_body()
	var wolf: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	wolf._configure_concrete_enemy()
	ogre._configure_concrete_enemy()
	wolf.player_ref = player
	ogre.player_ref = player
	for enemy: Enemy in [wolf, ogre]:
		enemy.charge_distance_left = 100.0
		enemy.knockback = Vector2(500, 0)
		enemy.grapple_slide_velocity = Vector2(20, 0)
		enemy._add_knockback(Vector2(200, 0))
		enemy.apply_void_pull(Vector2.RIGHT, 300.0)
		enemy.apply_grapple_force(Vector2.RIGHT * 600.0, 1.0, 1000.0, 0.25)
		assert(enemy.knockback == Vector2(500, 0), "Charge must ignore new external impulses without rewriting existing values mid-flight.")
		assert(enemy.grapple_slide_velocity == Vector2(20, 0))
		enemy.charge_distance_left = 0.0
		enemy._add_knockback(Vector2(20, 0))
		assert(enemy.knockback.x == 520.0, "Charge immunity ends as soon as charge distance is exhausted.")
		assert(not enemy._is_knockback_immune())
	wolf.free()
	ogre.free()
	player.free()

func test_charge_start_discards_stale_shove_and_windup_is_committed() -> void:
	var player: Node2D = _player_body()
	var wolf: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	wolf._configure_concrete_enemy()
	wolf.player_ref = player
	wolf.knockback = Vector2(300, 0)
	wolf.grapple_slide_velocity = Vector2(30, 0)
	wolf._begin_predictive_charge(0.0, 200.0, 2.0, 1.0)
	assert(wolf.charge_distance_left == 200.0)
	assert(wolf.knockback == Vector2.ZERO and wolf.grapple_slide_velocity == Vector2.ZERO)
	assert(wolf._is_knockback_immune())
	wolf.charge_distance_left = 0.0
	wolf.windup = 0.5
	assert(wolf._is_knockback_immune(), "Red windup is already committed; recovery is the counterplay window.")
	wolf.free()
	player.free()

func test_turkey_has_a_small_authored_speed_bump() -> void:
	var turkey: Turkey = WaveSpawner.TURKEY_SCENE.instantiate() as Turkey
	turkey._configure_concrete_enemy()
	assert(is_equal_approx(turkey.move_speed, 138.0), "Turkey is about 15% quicker than the shared 120px/s baseline.")
	turkey.free()

func test_sword_goblin_holds_a_continuous_long_metronome_beat() -> void:
	var player: Node2D = _player_body()
	var goblin: SwordGoblin = WaveSpawner.SWORD_GOBLIN_SCENE.instantiate() as SwordGoblin
	goblin._configure_concrete_enemy()
	goblin.player_ref = player
	goblin.global_position = Vector2.ZERO
	assert(is_equal_approx(goblin.metronome_arc_degrees, 90.0), "The blade arc is 90 degrees.")
	assert(is_equal_approx(goblin.metronome_frequency_hz, 0.7), "The beat is 0.7 Hz.")
	var facing: Vector2 = Vector2.LEFT
	var half_arc: float = deg_to_rad(90.0) * 0.5
	var minimum_offset: float = INF
	var maximum_offset: float = -INF
	var previous_angle: float = goblin.blade_angle
	var swept: float = 0.0
	# Advance over a beat in small steps: the blade keeps a long, live swing, never leaves the
	# arc around the player-facing direction, and actually sweeps across it.
	for index: int in range(40):
		goblin._advance_metronome_attack(0.02, facing)
		assert(is_equal_approx(goblin.blade_length, SwordGoblin.SWORD_SWING_LENGTH), "The sword stays at swing reach on the beat.")
		var offset: float = angle_difference(facing.angle(), goblin.blade_angle)
		minimum_offset = minf(minimum_offset, offset)
		maximum_offset = maxf(maximum_offset, offset)
		swept += absf(angle_difference(previous_angle, goblin.blade_angle))
		previous_angle = goblin.blade_angle
	assert(maximum_offset <= half_arc + 0.001 and minimum_offset >= -half_arc - 0.001, "The beat must stay inside the 90-degree arc around the player.")
	assert(maximum_offset - minimum_offset > deg_to_rad(30.0), "The blade must actually sweep across the arc.")
	assert(swept > deg_to_rad(45.0), "The blade keeps moving across the beat rather than holding still.")
	# The weapon is live whenever it is drawn, and only actually hurts on a real overlap.
	var attack_direction: Vector2 = Vector2.RIGHT.rotated(goblin.blade_angle)
	player.global_position = attack_direction * 60.0
	assert(goblin._has_player_damage_contact(), "An active sword sweep intersecting the player collider must hit.")
	player.global_position = Vector2(300.0, 0.0)
	assert(not goblin._has_player_damage_contact(), "A distant player is out of the blade's reach.")
	goblin.free()
	player.free()

func test_sword_goblin_advances_steadily_without_an_engagement_ring() -> void:
	var player: Node2D = _player_body()
	var goblin: SwordGoblin = WaveSpawner.SWORD_GOBLIN_SCENE.instantiate() as SwordGoblin
	goblin._configure_concrete_enemy()
	goblin.player_ref = player
	goblin.global_position = Vector2.ZERO
	player.global_position = Vector2(400.0, 0.0)
	goblin._advance_toward_player(400.0, Vector2.RIGHT)
	assert(goblin.velocity.dot(Vector2.RIGHT) > 0.0, "A far player must be advanced on, not waited out.")
	goblin.free()
	player.free()

func test_ogre_shield_parries_a_blade_crossing_its_front() -> void:
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	ogre._configure_concrete_enemy()
	ogre.global_position = Vector2.ZERO
	ogre.shield_angle = 0.0
	# The shield sits elite_shield_distance in front, so a blade crossing there is a front hit.
	var front_x: float = ogre.elite_shield_distance
	assert(ogre.is_shield_blocking(Vector2(front_x, -10.0), Vector2(front_x, 10.0)), "A blade crossing the front of the shield must parry.")
	assert(not ogre.is_shield_blocking(Vector2(-front_x, -10.0), Vector2(-front_x, 10.0)), "A blade behind the shield must not parry.")
	ogre.free()

func test_body_bump_and_spear_keep_existing_contact_checks() -> void:
	var player: Node2D = _player_body()
	var wolf: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	wolf._configure_concrete_enemy()
	wolf.player_ref = player
	wolf.global_position = Vector2.ZERO
	player.global_position = Vector2(29, 0)
	assert(wolf._has_player_damage_contact(), "Normal body collision remains a damage contact for monsters.")
	player.global_position = Vector2(31, 0)
	assert(not wolf._has_player_damage_contact())
	var goblin: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	goblin._configure_concrete_enemy()
	goblin.player_ref = player
	goblin.blade_angle = 0.0
	goblin.blade_length = goblin.duelist_thrust_blade_length
	goblin.thrust_left = 0.2
	player.global_position = Vector2(90, 0)
	assert(goblin._has_player_damage_contact(), "Spear contact remains live during its attack window.")
	wolf.free()
	goblin.free()
	player.free()
