class_name EnemyVisualsTest extends Node

const BEAR_TRAP_SCENE: PackedScene = preload("res://scenes/terrain/bear_trap.tscn")
const MUD_PATCH_SCENE: PackedScene = preload("res://scenes/terrain/mud_patch.tscn")
const NAMED_ENEMY_SCENES: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE, WaveSpawner.OGRE_SCENE]

func test_hd_enemy_scales_match_classic_readability_targets() -> void:
	var expected_scales: Array[float] = [0.50, 0.44, 0.42, 0.44, 0.40]
	for index: int in range(NAMED_ENEMY_SCENES.size()):
		var enemy: Enemy = NAMED_ENEMY_SCENES[index].instantiate() as Enemy
		enemy._configure_concrete_enemy()
		enemy._setup_hd_enemy_sprite()
		assert(is_equal_approx(enemy.hd_enemy_base_scale, expected_scales[index]), "HD scale drifted for %s." % NAMED_ENEMY_SCENES[index].resource_path)
		enemy.free()

func test_hd_wolf_restores_classic_red_windup_warning() -> void:
	var player: Player = Player.new()
	player.visual_style = "hd"
	var enemy: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	enemy._configure_concrete_enemy()
	enemy.player_ref = player
	enemy._setup_hd_enemy_sprite()
	enemy.windup = 0.4
	enemy._update_hd_enemy_sprite()
	assert(enemy.hd_enemy_sprite.self_modulate.g < 1.0 and enemy.hd_enemy_sprite.self_modulate.b < 1.0, "HD charger should tint red during windup.")
	enemy.windup = 0.0
	enemy._update_hd_enemy_sprite()
	assert(enemy.hd_enemy_sprite.self_modulate == Color.WHITE, "HD charger warning tint should clear after windup.")
	enemy.free()
	player.free()

func test_hazard_collision_shapes_follow_configured_visual_geometry() -> void:
	var config: TerrainConfig = TerrainConfig.new()
	config.bear_trap_radius = 22.0
	config.mud_radius = 46.0
	var trap: BearTrap = BEAR_TRAP_SCENE.instantiate() as BearTrap
	trap.configure(config)
	var trap_shape_node: CollisionShape2D = trap.get_node("CollisionShape2D") as CollisionShape2D
	var trap_shape: CircleShape2D = trap_shape_node.shape as CircleShape2D
	assert(is_equal_approx(trap_shape.radius, config.bear_trap_radius), "Bear-trap collision radius must follow TerrainConfig.")
	assert(trap.world_footprint().size == Vector2.ONE * config.bear_trap_radius * 2.0, "Bear-trap footprint must remain centered on its collision radius.")
	var mud: MudPatch = MUD_PATCH_SCENE.instantiate() as MudPatch
	mud.configure(config)
	var mud_shape_node: CollisionShape2D = mud.get_node("CollisionShape2D") as CollisionShape2D
	var mud_shape: CircleShape2D = mud_shape_node.shape as CircleShape2D
	assert(is_equal_approx(mud_shape.radius, config.mud_radius), "Mud collision radius must follow TerrainConfig.")
	assert(mud.world_footprint().size == Vector2.ONE * config.mud_radius * 2.0, "Mud footprint must remain centered on its collision radius.")
	trap.free()
	mud.free()
