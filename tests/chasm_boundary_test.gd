class_name ChasmBoundaryTest extends Node

const CHASM_SCENE: PackedScene = preload("res://scenes/chasm/chasm_stage.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const GENERATOR_SCENE: PackedScene = preload("res://scenes/terrain/arena_generator.tscn")

func test_saved_chasm_boundary_exposes_a_safe_center_and_rejects_outside_points() -> void:
	var stage: ChasmStage = CHASM_SCENE.instantiate() as ChasmStage
	add_child(stage)
	var polygon: PackedVector2Array = stage.get_boundary_polygon()
	assert(polygon.size() == 24, "The saved Chasm perimeter should be built from all 12 wall segments.")
	assert(stage.is_spawn_position_valid(Vector2(640.0, 360.0)), "The player start should be inside the saved Chasm perimeter.")
	assert(not stage.is_spawn_position_valid(Vector2(640.0, 80.0)), "Spawns above the saved top wall must be rejected.")
	assert(not stage.is_spawn_position_valid(Vector2(1100.0, 360.0)), "Spawns beyond the saved right wall must be rejected.")
	assert(not stage.is_spawn_position_valid(Vector2(100.0, 360.0)), "Spawns beyond the saved left wall must be rejected.")
	assert(not stage.is_spawn_position_valid(Vector2(640.0, 700.0)), "Spawns below the saved bottom wall must be rejected.")
	stage.free()

func test_spawn_clearance_rejects_wall_hugging_candidates() -> void:
	var stage: ChasmStage = CHASM_SCENE.instantiate() as ChasmStage
	add_child(stage)
	assert(not stage.is_spawn_position_valid(Vector2(640.0, 220.0), 52.0), "Enemy centers must keep the configured clearance from the top wall.")
	stage.free()

func test_boundary_queries_follow_saved_shape_edits() -> void:
	var stage: ChasmStage = CHASM_SCENE.instantiate() as ChasmStage
	add_child(stage)
	var before: PackedVector2Array = stage.get_boundary_polygon()
	var top_wall: CollisionShape2D = stage.get_node("ChasmBounds/Top") as CollisionShape2D
	top_wall.position += Vector2(0.0, 24.0)
	stage.refresh_boundary_geometry()
	var after: PackedVector2Array = stage.get_boundary_polygon()
	assert(not before[0].is_equal_approx(after[0]), "Spawn geometry must follow the saved wall nodes instead of duplicated coordinates.")
	stage.free()

func test_wave_spawner_rejects_chasm_outside_candidates() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var stage: ChasmStage = main.get_node("ChasmStage") as ChasmStage
	var spawner: WaveSpawner = main.get_node("WaveSpawner") as WaveSpawner
	var player: Player = main.get_node("Player") as Player
	var generator: ArenaGenerator = main.get_node("ArenaGenerator") as ArenaGenerator
	spawner.player_ref = player
	spawner.terrain_generator = generator
	spawner.set_chasm_stage(stage)
	player.global_position = Vector2(640.0, 360.0)
	for spawn_index: int in range(40):
		var spawn_position: Vector2 = spawner._random_position()
		assert(spawn_position.x >= 0.0, "Chasm must always provide an enemy spawn point.")
		assert(stage.is_spawn_position_valid(spawn_position, spawner.chasm_spawn_clearance), "Every Chasm wave candidate must pass the saved perimeter query.")
	main.free()

func test_disabled_forest_generation_clears_all_generated_bounds() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	add_child(generator)
	generator.set_forest_content_enabled(false)
	generator.regenerate()
	assert(not generator.forest_content_enabled, "Forest generation should remain disabled for Chasm.")
	assert(generator.placed_bounds.is_empty(), "Disabled Forest generation must leave no generated material bounds.")
	assert(generator.blocking_bounds.is_empty(), "Disabled Forest generation must leave no blocking terrain bounds.")
	generator.free()

func test_forest_generation_restores_after_leaving_chasm() -> void:
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	add_child(generator)
	# Force the normally-deferred overlay setup now so trap_overlay/population
	# exist for this synchronous test, instead of waiting for an idle frame.
	generator._initialize_arena()
	generator.set_forest_content_enabled(false)
	generator.regenerate()
	assert(not generator.trap_overlay.visible, "Trap overlay should hide while Chasm is active.")
	generator.generation_seed = 8128
	generator.set_forest_content_enabled(true)
	generator.regenerate()
	assert(generator.forest_content_enabled, "Forest generation should be re-enabled outside Chasm.")
	assert(not generator.placed_bounds.is_empty(), "Forest regeneration should restore generated terrain bounds.")
	# Regression coverage: trap_overlay used to stay hidden forever after a
	# Chasm visit, so every later mud patch/bear trap kept its full slow/root
	# collision while rendering nothing -- invisible hazards with real
	# movement side effects.
	assert(generator.trap_overlay.visible, "Trap overlay must become visible again after leaving Chasm, or mud patches/bear traps render invisible while still affecting movement.")
	if generator.population != null:
		assert(generator.population.visible, "Population overlay must also become visible again after leaving Chasm.")
	generator.free()
