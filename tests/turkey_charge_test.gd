class_name TurkeyChargeTest extends Node

func test_short_charge_warns_then_starts_with_five_second_cooldown() -> void:
	var turkey: Turkey = WaveSpawner.TURKEY_SCENE.instantiate() as Turkey
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	turkey._configure_concrete_enemy()
	turkey.player_ref = player
	player.position = Vector2(90.0, 0.0)
	turkey._run_concrete_ai(0.01)
	assert(turkey.charge_warning_tint_enabled and is_equal_approx(turkey.windup, 0.3))
	assert(turkey.velocity == Vector2.ZERO)
	turkey._run_concrete_ai(0.31)
	assert(is_equal_approx(turkey.charge_distance_left, 80.0))
	assert(is_equal_approx(turkey.charge_cooldown, 5.0))
	assert(turkey.charge_direction.dot(Vector2.RIGHT) > 0.99)
	turkey.free()
	player.free()

func test_charge_audio_chance_boundary() -> void:
	assert(Turkey.charge_audio_should_play(0.649))
	assert(not Turkey.charge_audio_should_play(0.65))

func test_turkeys_leave_normal_spawn_pool_at_wave_five() -> void:
	var spawner: WaveSpawner = WaveSpawner.new()
	spawner.current_wave = 4
	assert(spawner._available_enemy_scenes().has(WaveSpawner.TURKEY_SCENE))
	spawner.current_wave = 5
	assert(not spawner._available_enemy_scenes().has(WaveSpawner.TURKEY_SCENE))
	spawner.current_wave = 10
	assert(not spawner._available_enemy_scenes().has(WaveSpawner.TURKEY_SCENE))
	spawner.free()
