class_name HomeTutorialGuideTest extends Node

func test_home_guide_follows_crafting_storage_and_kitchen_route() -> void:
	var scene: PackedScene = load("res://scenes/ui/home_menu.tscn") as PackedScene
	var menu: HomeMenu = scene.instantiate() as HomeMenu
	add_child(menu)
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material(CookingConfig.TURKEY_MATERIAL, 2)
	progression.add_material(CookingConfig.MUSHROOM_MATERIAL, 1)
	menu.configure(progression)
	menu.open_home()
	menu.start_post_field_tutorial()
	var guide: HomeTutorialGuide = menu.home_tutorial_guide
	assert(guide != null and guide.stage == HomeTutorialGuide.Stage.INTRO)
	assert(guide.glow.target == menu.crafting_tab and guide.glow.prompt_label.text == "Click Crafting")
	menu.show_tab(HomeMenu.Tab.CRAFTING)
	assert(guide.stage == HomeTutorialGuide.Stage.STORAGE_DOOR)
	assert(guide.glow.target == menu.storage_crafting_button)
	menu.show_tab(HomeMenu.Tab.STORAGE)
	assert(guide.stage == HomeTutorialGuide.Stage.STORAGE_ROOM)
	assert(guide.glow.target == menu.crafting_tab)
	menu.show_tab(HomeMenu.Tab.CRAFTING)
	assert(guide.stage == HomeTutorialGuide.Stage.KITCHEN_DOOR)
	assert(guide.glow.target == menu.kitchen_crafting_button)
	menu.show_tab(HomeMenu.Tab.KITCHEN)
	assert(guide.stage == HomeTutorialGuide.Stage.KITCHEN_CRAFT_SLOT)
	assert(guide.glow.target == menu.crafting_slot and guide.glow.visible)
	menu.crafting_slot.emit_signal("pressed")
	assert(guide.stage == HomeTutorialGuide.Stage.RECIPE_SELECT)
	assert(guide.glow.target != null)
	guide.skip_current_step()
	assert(guide.stage == HomeTutorialGuide.Stage.COOKING_STARTED)
	guide.on_cauldron_result(true)
	progression.arm_cooking_bonus()
	guide.on_cauldron_closed()
	assert(guide.stage == HomeTutorialGuide.Stage.MEAL_READY)
	assert(progression.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 2)
	guide.skip_current_step()
	assert(guide.stage == HomeTutorialGuide.Stage.FOOD_SELECT)
	guide.skip_current_step()
	assert(guide.stage == HomeTutorialGuide.Stage.GRANDPA_INTRO)
	assert(not guide.is_complete())
	menu.queue_free()

func test_clicking_wild_turkey_stew_starts_cooking_and_advances_guide() -> void:
	var scene: PackedScene = load("res://scenes/ui/home_menu.tscn") as PackedScene
	var menu: HomeMenu = scene.instantiate() as HomeMenu
	add_child(menu)
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material(CookingConfig.TURKEY_MATERIAL, 5)
	progression.add_material(CookingConfig.MUSHROOM_MATERIAL, 5)
	menu.configure(progression)
	menu.open_home()
	menu.start_post_field_tutorial()
	menu.show_tab(HomeMenu.Tab.CRAFTING)
	menu.show_tab(HomeMenu.Tab.STORAGE)
	menu.show_tab(HomeMenu.Tab.CRAFTING)
	menu.show_tab(HomeMenu.Tab.KITCHEN)
	menu.crafting_slot.emit_signal("pressed")
	var recipe_button: Button = menu.highlight_recipe(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(recipe_button != null)
	recipe_button.emit_signal("pressed")
	assert(progression.is_crafting())
	assert(menu.home_tutorial_guide.stage == HomeTutorialGuide.Stage.COOKING_STARTED)
	menu.queue_free()

func test_home_tutorial_has_a_skip_step_shortcut() -> void:
	var scene: PackedScene = load("res://scenes/ui/home_menu.tscn") as PackedScene
	var menu: HomeMenu = scene.instantiate() as HomeMenu
	add_child(menu)
	menu.configure(HomeProgression.new())
	menu.open_home()
	menu.start_post_field_tutorial()
	var guide: HomeTutorialGuide = menu.home_tutorial_guide
	assert(guide.skip_button != null and guide.skip_button.text == "SKIP STEP")
	guide.skip_current_step()
	assert(guide.stage == HomeTutorialGuide.Stage.STORAGE_DOOR)
	menu.queue_free()

func test_home_tutorial_dialogue_is_centralized_and_editable() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/home_tutorial_guide.gd")
	for constant_name: String in ["INTRO_PAGES", "STORAGE_DOOR_PAGES", "STORAGE_ROOM_PAGES", "KITCHEN_DOOR_PAGES", "KITCHEN_COMPLETE_PAGES"]:
		assert(source.contains("const %s: Array[String]" % constant_name), "%s must remain visible as editable dialogue copy." % constant_name)
	assert(not source.contains("dialogue.start([\"Come to the storage room.\"])") and not source.contains("dialogue.start([\"This is my kitchen."), "Dialogue calls must use centralized copy constants.")

func test_tutorial_glow_has_blue_white_falling_fade_particles() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/tutorial_button_glow.gd")
	assert(source.contains("fall_height"))
	assert(source.contains("fade: float = 1.0 - y_ratio"))
	assert(source.contains("Color(0.76, 0.93, 1.0"), "Tutorial guidance must use the requested white-blue sparkle aura.")
