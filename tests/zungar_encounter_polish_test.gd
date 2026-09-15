class_name ZungarEncounterPolishTest extends Node

const ZUNGAR_SCENE: PackedScene = preload("res://scenes/boss/zungar.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func test_boss_wave_hard_suspends_normal_spawning() -> void:
	var host: Node2D = Node2D.new()
	var spawner: WaveSpawner = WaveSpawner.new()
	host.add_child(spawner)
	add_child(host)
	spawner.current_wave = ZungarConfig.BOSS_WAVE - 1
	spawner.training_mode = false
	spawner._start_wave()
	assert(spawner.boss_active, "Wave 20 must enter boss ownership.")
	assert(spawner.normal_spawning_suspended, "Ordinary wave spawning must be hard-suspended for the boss encounter.")
	assert(spawner.enemies_to_spawn == 0, "No normal wave slots may remain queued during Zungar.")
	spawner.complete_boss_wave()
	assert(not spawner.normal_spawning_suspended, "Normal spawning must be available again after the boss wave completes.")
	host.queue_free()

func test_summon_contract_has_cooldown_cap_and_requested_barks() -> void:
	assert(ZungarConfig.SUMMON_COOLDOWN == 20.0, "Zungar summons should have the selected 20-second cooldown.")
	assert(ZungarConfig.SUMMON_MAX_ALIVE == 3, "Zungar must never own more than three living adds.")
	assert(ZungarConfig.SUMMON_BARK == "Get in here you idiots", "Summon bark must match the encounter line.")
	assert(ZungarConfig.FRIENDLY_FIRE_BARK == "Get out of my way!", "Friendly-fire bark must match the encounter line.")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("spawner.GOBLIN_SCENE") and main_source.contains("spawner.BUG_SCENE") and main_source.contains("spawner.WOLF_SCENE") and main_source.contains("spawner.OGRE_SCENE"), "Summons must use the concrete Goblin, Bug, Wolf, and Ogre scenes.")
	var summon_pool_start: int = main_source.find("var summon_scenes: Array[PackedScene]")
	var summon_pool_end: int = main_source.find("\n", summon_pool_start)
	assert(summon_pool_start >= 0 and summon_pool_end > summon_pool_start, "The named Zungar summon pool must remain explicit.")
	var summon_pool_line: String = main_source.substr(summon_pool_start, summon_pool_end - summon_pool_start)
	assert(not summon_pool_line.contains("TURKEY_SCENE"), "Turkey must never enter Zungar's summon pool.")

func test_ready_summon_cooldown_guarantees_the_next_major_ability_is_summoning() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.set_physics_process(false)
	add_child(player)
	player.global_position = Vector2(900.0, 500.0)
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	zungar.set_physics_process(false)
	add_child(zungar)
	zungar.global_position = Vector2(600.0, 300.0)
	zungar.player_ref = player
	zungar.state = Zungar.State.CHASE
	zungar.attack_cooldown = 0.0
	zungar.summon_cooldown_left = 0.0
	zungar._process_chase(0.0)
	assert(zungar.state == Zungar.State.SUMMONING, "A ready summon cooldown must schedule allies instead of entering another random ability lottery.")
	assert(is_equal_approx(zungar.summon_cooldown_left, ZungarConfig.SUMMON_COOLDOWN), "Starting the summon must reset its independent 20-second cooldown.")
	zungar.queue_free()
	player.queue_free()

func test_polished_charge_stun_and_jump_animations_are_registered() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	zungar.set_physics_process(false)
	add_child(zungar)
	var body_sprite: AnimatedSprite2D = zungar.get_node("VisualRoot/BodySprite") as AnimatedSprite2D
	assert(body_sprite.sprite_frames.get_frame_count(&"charge_windup") == 8, "Charge windup should use the smooth eight-frame illustrated atlas.")
	assert(body_sprite.sprite_frames.get_frame_count(&"charge_travel") == 8, "Charge travel should use the smooth eight-frame illustrated atlas.")
	assert(body_sprite.sprite_frames.get_frame_count(&"stunned") == 6, "Wall/tree crashes need a distinct illustrated stunned loop.")
	assert(is_equal_approx(body_sprite.sprite_frames.get_animation_speed(&"jump"), 0.95), "Jump art should unfold slowly across the longer warning and flight.")
	assert(zungar.charge_fx != null, "Zungar should own the continuous windup/travel dirt effect.")
	zungar.queue_free()

func test_executioner_sword_uses_full_shared_combat_segment() -> void:
	var zungar: Zungar = ZUNGAR_SCENE.instantiate() as Zungar
	zungar.set_physics_process(false)
	add_child(zungar)
	zungar.global_position = Vector2(100.0, 100.0)
	zungar.blade_angle = 0.0
	var weapon_segment: Dictionary = zungar._enemy_weapon_segment()
	var expected_start: Vector2 = Vector2(114.25, 100.0)
	var expected_end: Vector2 = Vector2(195.25, 100.0)
	assert((weapon_segment["start"] as Vector2).is_equal_approx(expected_start), "Sword hilt collision must use the scaled 14.25px hand anchor.")
	assert((weapon_segment["end"] as Vector2).is_equal_approx(expected_end), "Sword tip collision must retain the enlarged 81px reach.")
	assert(zungar.is_blade_blocking(Vector2(180.0, 70.0), Vector2(180.0, 130.0), 4.0), "Player sword crossing the middle of Zungar's blade should register, not only tip contacts.")
	zungar.queue_free()

func test_hd_bonfire_uses_illustrated_animation_instead_of_polygon_fire() -> void:
	var campfire: BossCampfire = BossCampfire.new()
	add_child(campfire)
	assert(campfire.flame_sprite != null, "Boss campfire should create its illustrated AnimatedSprite2D.")
	assert(campfire.flame_sprite.sprite_frames.get_frame_count(&"burn") == 4, "The large HD bonfire should use all four painted flicker frames.")
	assert(campfire.flame_sprite.scale.x >= 0.6, "The boss bonfire should read as a substantially larger arena prop.")
	var image: Image = BossCampfire.BONFIRE_ATLAS.get_image()
	assert(image.get_size() == Vector2i(1536, 384), "Bonfire atlas should contain four 384px HD frames.")
	assert(image.detect_alpha() != Image.ALPHA_NONE, "Bonfire artwork needs a transparent illustrated silhouette.")
	campfire.queue_free()

func test_boss_spears_expose_summon_friendly_fire() -> void:
	var projectile: EnemyProjectile = EnemyProjectile.new()
	assert(not projectile.damages_boss_summons, "Normal enemy projectiles must keep friendly fire disabled.")
	projectile.damages_boss_summons = true
	projectile.boss_summon_damage = ZungarConfig.FRIENDLY_SPEAR_DAMAGE
	assert(projectile.damages_boss_summons and projectile.boss_summon_damage > 0.0, "Zungar spears need explicit add-damage configuration.")
	projectile.free()
