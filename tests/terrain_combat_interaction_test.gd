class_name TerrainCombatInteractionTest extends Node

const BEAR_TRAP_SCENE: PackedScene = preload("res://scenes/terrain/bear_trap.tscn")
const MUD_PATCH_SCENE: PackedScene = preload("res://scenes/terrain/mud_patch.tscn")
const GENERATOR_SCENE: PackedScene = preload("res://scenes/terrain/arena_generator.tscn")

func test_traps_detect_players_and_enemies_and_render_below_them() -> void:
	# Players/enemies must render ON TOP of traps (z_index 2), not the reverse.
	# Calling _ready() directly (rather than add_child()) is deliberate here: it is
	# a fully synchronous, reliable way to exercise the exact real ordering — configure()
	# first (as ArenaGenerator._configure_module() does before tree entry), then _ready()
	# (as the engine does on tree entry) — without depending on the test runner ever
	# processing a real scene-tree frame, which it does not (see architecture.md rule 8).
	var generator: ArenaGenerator = GENERATOR_SCENE.instantiate() as ArenaGenerator
	var trap: BearTrap = BEAR_TRAP_SCENE.instantiate() as BearTrap
	var mud: MudPatch = MUD_PATCH_SCENE.instantiate() as MudPatch
	generator._configure_module(trap)
	generator._configure_module(mud)
	trap._ready()
	mud._ready()
	assert(trap.collision_mask == 3, "Bear traps should detect player and enemy collision layers.")
	assert(mud.collision_mask == 3, "Mud should detect player and enemy collision layers.")
	assert(trap.z_index == generator.config.trap_visual_z_index, "_ready() must not override the z_index configure() already assigned.")
	assert(mud.z_index == generator.config.trap_visual_z_index, "_ready() must not override the z_index configure() already assigned.")
	assert(trap.z_index < 2 and mud.z_index < 2, "Trap visuals must render below character sprites (player/enemy z_index is 2).")
	trap.free()
	mud.free()
	generator.free()

func test_enemy_terrain_slowdown_is_separate_from_body_pressure() -> void:
	var enemy: Enemy = Enemy.new()
	enemy.set_terrain_movement_modifier(42, 0.5)
	assert(is_equal_approx(enemy._terrain_movement_multiplier(), 0.5), "Mud should slow enemies through a dedicated terrain modifier.")
	enemy.remove_terrain_movement_modifier(42)
	assert(is_equal_approx(enemy._terrain_movement_multiplier(), 1.0), "Leaving mud should restore normal enemy movement.")
	enemy.free()
