class_name CheckpointFoodTest extends Node

## Checkpoint snacks heal only through the progression inventory boundary and
## never become expedition buffs by accident.
func test_wolf_jerky_is_a_recovery_food() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material(CookingConfig.WOLF_MEAT_MATERIAL, 2)
	progression.add_material("Forest Herb", 1)
	assert(progression.start_crafting(CookingConfig.WOLF_JERKY_ID, 100.0), "Wolf Jerky should be craftable with its ingredients.")
	progression.update_crafting(131.0)
	assert(progression.food_count(CookingConfig.WOLF_JERKY_ID) == 1, "Completed Wolf Jerky should enter food inventory.")
	assert(not progression.prepare_food(CookingConfig.WOLF_JERKY_ID), "Recovery food must not become an expedition buff.")
	var healed_amount: float = progression.consume_recovery_food(CookingConfig.WOLF_JERKY_ID, 100.0)
	assert(is_equal_approx(healed_amount, 20.0), "Wolf Jerky should restore 20% of maximum health at a checkpoint.")
	assert(progression.food_count(CookingConfig.WOLF_JERKY_ID) == 0, "Eating a snack should consume one item.")

func test_chargers_can_drop_wolf_meat() -> void:
	var wolf: Wolf = WaveSpawner.WOLF_SCENE.instantiate() as Wolf
	wolf._configure_concrete_enemy()
	assert(LootConfig.material_drop_for_enemy(wolf, 0.0) == CookingConfig.WOLF_MEAT_MATERIAL, "Wolves should provide Wolf Meat for the Jerky recipe.")
	wolf.free()
