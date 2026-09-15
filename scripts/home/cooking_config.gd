class_name CookingConfig extends RefCounted

# =============================================================================
# RECIPE TUNING — PRIMARY EDITING AREA
# Change ingredients, effects, wave duration, and crafting time here.
# Crafting time is real-world seconds and continues while the game is closed.
# =============================================================================
# --- FIRST HOME-LOOP RECIPE ---
const WILD_TURKEY_STEW_ID: String = "wild_turkey_stew"
const TURKEY_MATERIAL: String = "Turkey"
const MUSHROOM_MATERIAL: String = "Mushroom"

## Ingredients consumed by one Wild Turkey Stew.
const WILD_TURKEY_STEW_INGREDIENTS: Dictionary = {TURKEY_MATERIAL: 2, MUSHROOM_MATERIAL: 1}
## Additional maximum health during the prepared expedition.
const WILD_TURKEY_STEW_MAX_HEALTH: float = 10.0
## Health restored each second while the stew is active.
const WILD_TURKEY_STEW_REGEN_PER_SECOND: float = 0.25
## Completed waves for which one prepared stew remains active.
const WILD_TURKEY_STEW_WAVE_DURATION: int = 10
## Real-world seconds Grandma needs to cook one stew.
const WILD_TURKEY_STEW_CRAFTING_TIME: float = 50.0

# --- CHECKPOINT SNACK ---
const WOLF_JERKY_ID: String = "wolf_jerky"
const WOLF_MEAT_MATERIAL: String = "Wolf Meat"
## Ingredients consumed by one Wolf Jerky.
const WOLF_JERKY_INGREDIENTS: Dictionary = {WOLF_MEAT_MATERIAL: 2, "Forest Herb": 1}
## Fraction of maximum health restored when Wolf Jerky is eaten at a campfire.
const WOLF_JERKY_HEAL_PERCENT: float = 0.20
## Real-world seconds Grandma needs to prepare one batch of jerky.
const WOLF_JERKY_CRAFTING_TIME: float = 30.0

const RECIPE_IDS: Array[String] = [WILD_TURKEY_STEW_ID, WOLF_JERKY_ID]

static func recipe_name(recipe_id: String) -> String:
	if recipe_id == WILD_TURKEY_STEW_ID: return "Wild Turkey Stew"
	if recipe_id == WOLF_JERKY_ID: return "Wolf Jerky"
	return "Unknown Food"

static func recipe_ingredients(recipe_id: String) -> Dictionary:
	if recipe_id == WILD_TURKEY_STEW_ID: return WILD_TURKEY_STEW_INGREDIENTS.duplicate()
	if recipe_id == WOLF_JERKY_ID: return WOLF_JERKY_INGREDIENTS.duplicate()
	return {}

static func food_max_health(recipe_id: String) -> float:
	return WILD_TURKEY_STEW_MAX_HEALTH if recipe_id == WILD_TURKEY_STEW_ID else 0.0

static func food_regeneration(recipe_id: String) -> float:
	return WILD_TURKEY_STEW_REGEN_PER_SECOND if recipe_id == WILD_TURKEY_STEW_ID else 0.0

static func food_recovery_percent(recipe_id: String) -> float:
	return WOLF_JERKY_HEAL_PERCENT if recipe_id == WOLF_JERKY_ID else 0.0

static func is_recovery_food(recipe_id: String) -> bool:
	return food_recovery_percent(recipe_id) > 0.0

static func food_wave_duration(recipe_id: String) -> int:
	return WILD_TURKEY_STEW_WAVE_DURATION if recipe_id == WILD_TURKEY_STEW_ID else 0

static func crafting_time(recipe_id: String) -> float:
	if recipe_id == WILD_TURKEY_STEW_ID: return WILD_TURKEY_STEW_CRAFTING_TIME
	if recipe_id == WOLF_JERKY_ID: return WOLF_JERKY_CRAFTING_TIME
	return 0.0

static func recipe_ids() -> Array[String]:
	return RECIPE_IDS.duplicate()
