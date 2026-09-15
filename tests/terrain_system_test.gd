class_name TerrainSystemTest extends Node

const GENERATOR_SCENE: PackedScene = preload("res://scenes/terrain/arena_generator.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func test_thirty_generated_layouts_keep_safety_rules() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	add_child(generator)
	for iteration: int in range(30):
		generator.generation_seed = 1000 + iteration
		generator.regenerate()
		assert(generator.placed_bounds.size() >= generator.config.minimum_modules, "Generator should place the configured minimum modules.")
		assert(ArenaLayoutValidator.routes_remain_open(generator.blocking_bounds, generator.config), "Every generated layout must preserve all required routes.")
		var occupied_area: float = 0.0
		for first_index: int in range(generator.placed_bounds.size()):
			var first: Rect2 = generator.placed_bounds[first_index]
			occupied_area += first.get_area()
			var closest_spawn_point: Vector2 = Vector2(clampf(generator.config.player_spawn.x, first.position.x, first.end.x), clampf(generator.config.player_spawn.y, first.position.y, first.end.y))
			assert(closest_spawn_point.distance_to(generator.config.player_spawn) >= generator.config.player_spawn_clearance, "Modules must preserve player spawn clearance.")
			for second_index: int in range(first_index + 1, generator.placed_bounds.size()):
				assert(not first.grow(generator.config.module_spacing).intersects(generator.placed_bounds[second_index]), "Generated modules must not overlap.")
		var open_ratio: float = 1.0 - occupied_area / generator.config.arena_rect.get_area()
		assert(open_ratio >= generator.config.minimum_open_area_ratio, "Generated layout must preserve open combat space.")
	generator.free()

func test_enemy_spawns_never_overlap_player_or_terrain() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	var player: Player = main.get_node("Player") as Player
	var generator: ArenaGenerator = main.get_node("ArenaGenerator") as ArenaGenerator
	spawner.player_ref = player
	spawner.terrain_generator = generator
	spawner.set_process(false)
	player.set_physics_process(false)
	for layout_index: int in range(20):
		generator.generation_seed = 5000 + layout_index
		generator.regenerate()
		for spawn_index: int in range(100):
			var spawn_position: Vector2 = spawner._random_position()
			assert(spawn_position.x >= 0.0, "A safe generated layout should always provide an enemy spawn point.")
			assert(spawn_position.distance_to(player.global_position) > 180.0, "Enemies must not spawn inside player clearance.")
			assert(generator.is_position_clear(spawn_position, 52.0), "Enemies must not spawn on walls, mud, or bear traps.")
	main.free()

func test_wall_collision_los_and_cover_queries() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	generator.wall_collision_bounds = [Rect2(600.0, 280.0, 40.0, 160.0)]
	var blocked_hit: Dictionary = generator.segment_wall_collision(Vector2(300.0, 360.0), Vector2(800.0, 360.0), 0.0)
	assert(not blocked_hit.is_empty(), "A projectile segment through a wall should report a collision.")
	assert((blocked_hit["normal"] as Vector2).is_equal_approx(Vector2.LEFT), "The wall collision should return a usable reflection normal.")
	assert(not generator.has_line_of_sight(Vector2(300.0, 360.0), Vector2(800.0, 360.0)), "Walls must block ranged line of sight.")
	assert(generator.has_line_of_sight(Vector2(300.0, 200.0), Vector2(800.0, 200.0)), "Clear shots above a wall must remain valid.")
	assert(generator.has_line_of_sight(Vector2(300.0, 270.0), Vector2(800.0, 270.0), 0.0), "A centerline-only ray demonstrates the old false-clear edge case.")
	assert(not generator.has_line_of_sight(Vector2(300.0, 270.0), Vector2(800.0, 270.0), EnemyProjectile.WALL_LOS_CLEARANCE), "Projectile-sized LOS must reject shots that would clip a wall edge.")
	var predictable_peek_distance: float = 48.0
	var cover: Dictionary = generator.find_cover_positions(Vector2(800.0, 360.0), Vector2(300.0, 360.0), EnemyProjectile.WALL_LOS_CLEARANCE, predictable_peek_distance)
	assert(not cover.is_empty(), "A wall between ranged enemy and player should provide hidden and peek positions.")
	assert((cover["hidden"] as Vector2).distance_to(cover["peek"] as Vector2) >= 140.0, "Peek movement should carry the enemy a consistent, counterable distance beyond this wall edge.")
	assert(not generator.has_line_of_sight(cover["hidden"] as Vector2, Vector2(300.0, 360.0), EnemyProjectile.WALL_LOS_CLEARANCE), "The hidden cover point must actually break line of sight.")
	assert(generator.has_line_of_sight(cover["peek"] as Vector2, Vector2(300.0, 360.0), EnemyProjectile.WALL_LOS_CLEARANCE), "The peek point must provide a valid firing line.")
	generator.free()

func test_cover_fire_uses_fixed_aim_and_post_shot_windows() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	var ranged: Bug = WaveSpawner.BUG_SCENE.instantiate() as Bug
	ranged.player_ref = player
	ranged.ranged_hidden_position = Vector2.ZERO
	ranged.ranged_peek_position = Vector2(140.0, 0.0)
	ranged.ranged_cover_phase = Enemy.RangedCoverPhase.HIDDEN
	ranged.ranged_cover_phase_left = 0.01
	ranged._update_ranged_cover_fire(0.02, Vector2.LEFT)
	assert(ranged.ranged_cover_phase == Enemy.RangedCoverPhase.PEEK)
	assert(is_equal_approx(ranged.ranged_cover_phase_left, ranged.ranged_cover_aim_duration), "Every peek should begin with the same visible aiming delay.")
	ranged.global_position = ranged.ranged_peek_position
	ranged._update_ranged_cover_fire(ranged.ranged_cover_aim_duration * 0.5, Vector2.LEFT)
	assert(not ranged.ranged_cover_has_fired, "Enemy must not shoot before the fixed aim delay expires.")
	ranged.ranged_cover_has_fired = true
	ranged.ranged_cover_phase_left = ranged.ranged_cover_post_shot_exposure_duration
	ranged._update_ranged_cover_fire(ranged.ranged_cover_post_shot_exposure_duration * 0.5, Vector2.LEFT)
	assert(ranged.ranged_cover_phase == Enemy.RangedCoverPhase.PEEK, "Enemy should remain exposed during the punish window.")
	ranged._update_ranged_cover_fire(ranged.ranged_cover_post_shot_exposure_duration, Vector2.LEFT)
	assert(ranged.ranged_cover_phase == Enemy.RangedCoverPhase.SEEK, "Enemy should return to its locked hiding point after the punish window.")
	ranged.free()
	player.free()

func test_ground_is_below_traps_and_player() -> void:
	# NOTE: this synchronous test harness never processes a real scene-tree frame
	# (confirmed: get_tree() is null even after add_child() here), so a freshly
	# instantiated node's own _ready() cannot be relied on to have run. That means
	# this test can only verify the deterministic, pre-tree-entry wiring: that
	# ArenaGenerator._configure_module() assigns each module's z_index from the
	# correct config field, and that the configured values sit below the player.
	# The class of bug where a node's own _ready() later overwrites that value
	# (exactly what shipped: bear_trap.gd/mud_patch.gd hardcoded z_index=5 in
	# _ready(), silently overriding _configure_module()'s assignment) is instead
	# caught live by tests/terrain_zorder_live_harness.tscn via run_scene, which
	# runs inside an actually-processing SceneTree where deferred _ready() calls
	# settle before anything is checked.
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var floor_node: Node2D = main.get_node("ForestFloor") as Node2D
	var generator: ArenaGenerator = main.get_node("ArenaGenerator") as ArenaGenerator
	var player: Player = main.get_node("Player") as Player
	assert(floor_node.z_index < player.z_index, "Forest grass must render below the player.")
	assert(generator.config.trap_visual_z_index < player.z_index, "Configured trap layer must render below the player.")
	assert(generator.config.wall_visual_z_index < player.z_index, "Configured wall layer must render below the player.")
	var mud_scene: PackedScene = load("res://scenes/terrain/mud_patch.tscn") as PackedScene
	var mud: MudPatch = mud_scene.instantiate() as MudPatch
	generator._configure_module(mud)
	assert(mud.z_index == generator.config.trap_visual_z_index, "configure_module must assign a trap's z_index from trap_visual_z_index.")
	var trap_scene: PackedScene = load("res://scenes/terrain/bear_trap.tscn") as PackedScene
	var trap: BearTrap = trap_scene.instantiate() as BearTrap
	generator._configure_module(trap)
	assert(trap.z_index == generator.config.trap_visual_z_index, "configure_module must assign a trap's z_index from trap_visual_z_index.")
	var wall_scene: PackedScene = load("res://scenes/terrain/forest_wall_i.tscn") as PackedScene
	var wall: TerrainModule = wall_scene.instantiate() as TerrainModule
	generator._configure_module(wall)
	assert(wall.z_index == generator.config.wall_visual_z_index, "configure_module must assign a wall's z_index from wall_visual_z_index, not trap_visual_z_index.")
	mud.free()
	trap.free()
	wall.free()
	main.free()

func test_wall_and_trap_visual_layers_are_independently_configurable() -> void:
	# Walls and traps must be genuinely separate settings, not the same value in two names.
	var generator: ArenaGenerator = load("res://scenes/terrain/arena_generator.tscn").instantiate() as ArenaGenerator
	generator.config = generator.config.duplicate() as TerrainConfig
	generator.config.wall_visual_z_index = 3
	generator.config.trap_visual_z_index = 9
	var mud: MudPatch = (load("res://scenes/terrain/mud_patch.tscn") as PackedScene).instantiate() as MudPatch
	generator._configure_module(mud)
	assert(mud.z_index == 9, "Traps must use trap_visual_z_index specifically.")
	var wall: TerrainModule = (load("res://scenes/terrain/forest_wall_i.tscn") as PackedScene).instantiate() as TerrainModule
	generator._configure_module(wall)
	assert(wall.z_index == 3, "Walls must use wall_visual_z_index specifically, independent of traps.")
	mud.free()
	wall.free()
	generator.free()

func test_player_terrain_effect_api() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_terrain_movement_modifier(10, 0.7)
	assert(is_equal_approx(player._terrain_movement_multiplier(), 0.7), "Mud should slow movement by 30 percent.")
	player.set_terrain_dash_block(10, true)
	assert(player._terrain_dash_blocked(), "Mud should block dash.")
	player.remove_terrain_effect(10)
	assert(is_equal_approx(player._terrain_movement_multiplier(), 1.0), "Leaving mud should restore movement.")
	assert(not player._terrain_dash_blocked(), "Leaving mud should restore dash.")
	player.apply_terrain_root(1.0)
	assert(player.terrain_root_left >= 1.0, "Bear trap should apply a one-second root.")
	assert(player._terrain_dash_blocked(), "Bear-trap root should block dash.")
	player.free()
