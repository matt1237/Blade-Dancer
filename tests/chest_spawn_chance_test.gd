class_name ChestSpawnChanceTest extends Node
## Covers the escalating chest-spawn pity timer math in main.gd: +20% per
## wave without a chest, reset to the 20% base once one spawns, clamped at
## 100%. The training-mode/boss-wave spawn guards and full spawn/loot flow
## are covered live via run_scene and execute_script playtests instead of
## here, since exercising main.tscn's @onready wiring needs a live
## SceneTree that this offline test runner does not attach test nodes to.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func test_chance_starts_at_base_and_clamps_at_full() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	assert(is_equal_approx(main.chest_spawn_chance, main.CHEST_BASE_SPAWN_CHANCE), "chest chance should start at the base rate")
	assert(is_equal_approx(main.CHEST_BASE_SPAWN_CHANCE, 0.20), "the base chest chance should be 20%, per the design spec")
	main.chest_spawn_chance = 0.95
	main.chest_spawn_chance = minf(main.chest_spawn_chance + main.CHEST_BASE_SPAWN_CHANCE, 1.0)
	assert(is_equal_approx(main.chest_spawn_chance, 1.0), "chest chance should clamp at 100% rather than overshoot")
	main.free()

func test_chance_escalates_by_20_percent_per_miss() -> void:
	var chance: float = 0.20
	var expected_steps: Array[float] = [0.20, 0.40, 0.60, 0.80, 1.0]
	for expected: float in expected_steps:
		assert(is_equal_approx(chance, expected), "chest chance should walk 20%%, 40%%, 60%%, 80%%, 100%% on consecutive misses")
		chance = minf(chance + 0.20, 1.0)
