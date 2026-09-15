class_name HomeProgressionTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const HOME_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/home_screen.tscn")
const LOOT_CONFIG_SCRIPT: Script = preload("res://scripts/loot/loot_config.gd")

func test_forge_requires_mine_wave_ten_rescue_and_purchase() -> void:
	var progression: HomeProgression = HomeProgression.new()
	assert(not progression.is_forge_unlocked())
	assert(not progression.rescue_blacksmith(), "The Blacksmith must remain unavailable before Mine Wave 10.")
	progression.mines_wave_10_cleared = true
	assert(progression.rescue_blacksmith())
	assert(not progression.is_forge_unlocked(), "Rescuing the Blacksmith alone must not unlock the Forge.")
	assert(progression.purchase_forge())
	assert(progression.is_forge_unlocked())
	assert(not progression.purchase_forge(), "The Forge should only be purchased once.")
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(progression.to_save_data())
	assert(restored.is_forge_unlocked(), "Forge progression must survive save/load.")

func test_wild_turkey_stew_craft_prepare_and_ten_wave_duration() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material(CookingConfig.TURKEY_MATERIAL, 2)
	progression.add_material(CookingConfig.MUSHROOM_MATERIAL, 1)
	assert(not progression.prepare_food(CookingConfig.WILD_TURKEY_STEW_ID), "Uncooked food must never be prepared.")
	assert(progression.can_craft(CookingConfig.WILD_TURKEY_STEW_ID))
	assert(progression.start_crafting(CookingConfig.WILD_TURKEY_STEW_ID, 1000.0))
	assert(progression.material_count(CookingConfig.TURKEY_MATERIAL) == 0)
	assert(progression.material_count(CookingConfig.MUSHROOM_MATERIAL) == 0)
	assert(progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 0, "Food must not appear before its real-time craft finishes.")
	assert(progression.update_crafting(1049.0).is_empty())
	assert(progression.update_crafting(1050.0) == CookingConfig.WILD_TURKEY_STEW_ID)
	assert(progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 1)
	assert(progression.prepare_food(CookingConfig.WILD_TURKEY_STEW_ID))
	assert(progression.begin_expedition())
	assert(progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 0)
	assert(is_equal_approx(progression.active_health_bonus(), 10.0))
	assert(is_equal_approx(progression.active_regeneration(), 0.25))
	for wave_index: int in range(9):
		progression.complete_wave()
	assert(progression.active_food_waves_remaining == 1, "Stew should remain active through the first ten waves.")
	progression.complete_wave()
	assert(progression.active_food_id.is_empty() and progression.active_food_waves_remaining == 0)

func test_home_progression_save_round_trip() -> void:
	var original: HomeProgression = HomeProgression.new()
	original.add_material("Turkey", 7)
	original.add_material("Mushroom", 4)
	original.food_inventory[CookingConfig.WILD_TURKEY_STEW_ID] = 2
	original.prepare_food(CookingConfig.WILD_TURKEY_STEW_ID)
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(original.to_save_data())
	assert(restored.material_count("Turkey") == 7 and restored.material_count("Mushroom") == 4)
	assert(restored.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 2)
	assert(restored.prepared_food_id == CookingConfig.WILD_TURKEY_STEW_ID)
	assert(str(restored.equipment["Food"]) == "Wild Turkey Stew")

func test_crafting_timestamp_survives_save_and_finishes_offline() -> void:
	var original: HomeProgression = HomeProgression.new()
	original.add_material("Turkey", 2)
	original.add_material("Mushroom", 1)
	assert(original.start_crafting(CookingConfig.WILD_TURKEY_STEW_ID, 5000.0))
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(original.to_save_data())
	assert(restored.is_crafting())
	assert(is_equal_approx(restored.crafting_remaining_seconds(5025.0), 25.0))
	assert(restored.update_crafting(5050.0) == CookingConfig.WILD_TURKEY_STEW_ID)
	assert(restored.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 1)
	assert(not restored.is_crafting())

func test_item_rarity_bags_and_alphabetical_storage() -> void:
	assert(ItemConfig.rarity("Turkey") == ItemConfig.Rarity.NORMAL)
	assert(ItemConfig.rarity("Iron Shard") == ItemConfig.Rarity.RARE)
	assert(ItemConfig.rarity("Moon Petal") == ItemConfig.Rarity.VERY_RARE)
	var drop: DropPickup = (load("res://scenes/drop_pickup.tscn") as PackedScene).instantiate() as DropPickup
	drop.setup("Moon Petal", 1, 1)
	assert(drop.rarity == ItemConfig.Rarity.VERY_RARE)
	drop.free()
	var progression: HomeProgression = HomeProgression.new()
	var screen: HomeScreen = HOME_SCREEN_SCENE.instantiate() as HomeScreen
	add_child(screen)
	screen.equipment_text = screen.get_node("EquipmentText") as RichTextLabel
	screen.storage_text = screen.get_node("StorageText") as RichTextLabel
	screen.cooking_text = screen.get_node("CookingText") as RichTextLabel
	screen.craft_stew_button = screen.get_node("CraftStewButton") as Button
	screen.prepare_stew_button = screen.get_node("PrepareStewButton") as Button
	screen.feedback_label = screen.get_node("FeedbackLabel") as Label
	screen.configure(progression)
	var previous_position: int = -1
	for material_name: String in HomeProgression.MATERIAL_NAMES:
		var current_position: int = screen.storage_text.text.find("\n%s:" % material_name)
		assert(current_position > previous_position, "Storage materials must appear in alphabetical order.")
		previous_position = current_position
	screen.free()

func test_enemy_material_drop_tables_are_concrete_enemy_specific() -> void:
	var turkey: Turkey = WaveSpawner.TURKEY_SCENE.instantiate() as Turkey
	var goblin: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	var bug: Bug = WaveSpawner.BUG_SCENE.instantiate() as Bug
	for enemy: Enemy in [turkey, goblin, bug]: enemy._configure_concrete_enemy()
	assert(LOOT_CONFIG_SCRIPT.material_drop_for_enemy(turkey, 0.0) == "Turkey")
	assert(LOOT_CONFIG_SCRIPT.material_drop_for_enemy(turkey, 0.45) == "")
	assert(LOOT_CONFIG_SCRIPT.material_drop_for_enemy(goblin, 0.0) == "Mushroom")
	assert(LOOT_CONFIG_SCRIPT.material_drop_for_enemy(bug, 0.0) == "")
	turkey.free()
	goblin.free()
	bug.free()

func test_food_and_vitality_health_bonuses_compose() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health_bar = player.get_node("HealthBar") as ProgressBar
	player.dash_timer = player.get_node("DashCooldownTimer") as Timer
	player.set_expedition_food_bonuses(10.0, 0.25)
	assert(is_equal_approx(player.max_health, 110.0))
	player.apply_bonus("health")
	assert(is_equal_approx(player.max_health, 120.0), "Rank 1 Vitality must preserve the active +10 food bonus.")
	player.set_expedition_food_bonuses(0.0, 0.0)
	assert(is_equal_approx(player.max_health, 110.0), "Food expiration must preserve Rank 1 Vitality.")
	player.free()

func test_home_screen_exposes_only_the_small_first_milestone() -> void:
	var screen: HomeScreen = HOME_SCREEN_SCENE.instantiate() as HomeScreen
	add_child(screen)
	screen.equipment_text = screen.get_node("EquipmentText") as RichTextLabel
	screen.storage_text = screen.get_node("StorageText") as RichTextLabel
	screen.cooking_text = screen.get_node("CookingText") as RichTextLabel
	screen.craft_stew_button = screen.get_node("CraftStewButton") as Button
	screen.prepare_stew_button = screen.get_node("PrepareStewButton") as Button
	screen.feedback_label = screen.get_node("FeedbackLabel") as Label
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material("Turkey", 2)
	progression.add_material("Mushroom", 1)
	screen.configure(progression)
	assert(not screen.craft_stew_button.disabled)
	assert(screen.get_node("ForgeButton").disabled, "Forge should remain a visible placeholder, not a functioning system.")
	assert(screen.equipment_text.text.contains("Sword") and screen.equipment_text.text.contains("Food"))
	screen.free()
