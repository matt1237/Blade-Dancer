class_name MenuFlowTest extends Node

const END_HUB_SCENE: PackedScene = preload("res://scenes/ui/end_run_hub.tscn")
const HOME_MENU_SCENE: PackedScene = preload("res://scenes/ui/home_menu.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")

func test_end_run_hub_has_only_four_navigable_destinations() -> void:
	var hub: EndRunHub = END_HUB_SCENE.instantiate() as EndRunHub
	hub.run_review_tab = hub.get_node("RunReviewTab") as Button
	hub.scoreboard_tab = hub.get_node("ScoreboardTab") as Button
	hub.home_tab = hub.get_node("HomeTab") as Button
	hub.adventure_tab = hub.get_node("AdventureTab") as Button
	hub.run_review = hub.get_node("RunReview") as RichTextLabel
	hub.scoreboard = hub.get_node("Scoreboard") as Label
	hub.home_card = hub.get_node("HomeCard") as Panel
	hub.adventure_card = hub.get_node("AdventureCard") as Panel
	hub.open_to_run_review("RUN REVIEW CONTENT", "SCOREBOARD CONTENT")
	assert(hub.active_tab == EndRunHub.Tab.RUN_REVIEW and hub.run_review.visible)
	hub.show_tab(EndRunHub.Tab.SCOREBOARD)
	assert(hub.scoreboard.visible and not hub.run_review.visible)
	hub.show_tab(EndRunHub.Tab.HOME)
	assert(hub.home_card.visible)
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	assert(hub.adventure_card.visible)
	assert(hub.get_node_or_null("SaveButton") == null and hub.get_node_or_null("LoadButton") == null and hub.get_node_or_null("TownButton") == null)
	hub.free()

func test_every_form_three_slider_has_left_and_right_feel_guidance() -> void:
	var sample: String = BackyardTrainingMenu._form_three_feel_tip("Meaning", "Loose", "Strict", "Try this")
	assert(sample.contains("FEEL GUIDE") and sample.contains("← LEFT: Loose") and sample.contains("→ RIGHT: Strict") and sample.contains("TIP: Try this"))
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	var guided_slider_count: int = 0
	for line: String in source.split("\n"):
		if line.contains("_create_hand_slider(experimental_bind_section"):
			guided_slider_count += 1
			assert(line.contains("_form_three_feel_tip("), "Every Form III slider tooltip needs explicit left/right feel guidance: %s" % line)
	assert(guided_slider_count == Player.EXPERIMENTAL_BIND_SETTING_KEYS.size() - 1, "Every player-facing Bind control except retired bind_debug must have feel guidance.")

func test_slide_clash_and_parry_controls_have_feel_guidance() -> void:
	var keys: Array[String] = [
		"clash_contact_tolerance", "clash_angle_min", "clash_angle_max", "clash_cooldown",
		"clash_player_recoil", "clash_enemy_recoil", "clash_hitstop", "clash_stagger",
		"clash_recovery", "clash_flow", "clash_sparks", "clash_shake_strength",
		"clash_shake_duration", "clash_zoom", "clash_zoom_duration", "clash_impact",
		"parry_contact_tolerance", "parry_rotation_speed", "parry_cooldown",
		"parry_player_recoil", "parry_enemy_recoil", "parry_hitstop", "parry_stagger",
		"parry_recovery", "parry_sparks", "parry_shake_strength", "parry_shake_duration",
		"parry_zoom", "parry_zoom_duration", "parry_focus", "parry_focus_duration", "parry_impact"
	]
	for key: String in keys:
		var tooltip: String = BackyardTrainingMenu._contact_feel_tip(key)
		assert(tooltip.contains("← LEFT:") and tooltip.contains("→ RIGHT:"), "Missing feel guidance for %s" % key)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	for slide_key: String in ["slide_contact_tolerance", "slide_angle", "slide_cling", "slide_friction", "slide_speed", "slide_duration", "slide_travel", "slide_spread", "slide_sparks", "slide_hitstop", "slide_shake_strength", "slide_shake_duration", "slide_zoom", "slide_zoom_duration", "slide_impact"]:
		var matching_line: String = ""
		for line: String in source.split("\n"):
			if line.contains("\"%s\"" % slide_key) and line.contains("_create_"):
				matching_line = line
				break
		assert(matching_line.contains("_form_three_feel_tip("), "Missing explicit slide feel guidance for %s" % slide_key)

func test_backyard_layout_tab_offers_forest_and_empty_without_hiding_tools() -> void:
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(menu_source.contains("layout_tab.name = \"Layout\""), "Training Tools must expose the Layout tab.")
	assert(menu_source.contains("forest_button.text = \"Forest\"") and menu_source.contains("empty_button.text = \"Empty\""), "Layout must offer Forest and Empty choices.")
	assert(main_source.contains("func set_backyard_training_layout(layout_id: String) -> void:"), "Main must own Backyard layout switching.")
	assert(main_source.contains("arena_generator.set_forest_content_enabled(use_forest)"), "Empty must remove generated collision and scenery, not merely hide it.")
	assert(main_source.contains("var forest_layout_visible: bool"), "World restoration must preserve the chosen Empty layout.")

func test_training_tools_rect_centers_the_complete_menu_assembly() -> void:
	for viewport_size: Vector2 in [Vector2(1280.0, 720.0), Vector2(960.0, 540.0), Vector2(640.0, 360.0)]:
		var menu_rect: Rect2 = BackyardTrainingMenu.centered_training_rect(viewport_size)
		assert(is_equal_approx(menu_rect.get_center().x, viewport_size.x * 0.5), "Training Tools must remain horizontally centered at every supported viewport size.")
		var assembly_top: float = menu_rect.position.y - BackyardTrainingMenu.TOGGLE_HEIGHT - BackyardTrainingMenu.TOGGLE_GAP
		var assembly_bottom: float = menu_rect.end.y
		assert(is_equal_approx((assembly_top + assembly_bottom) * 0.5, viewport_size.y * 0.5), "The toggle and panel must be vertically centered as one visible assembly.")
		assert(menu_rect.position.x >= BackyardTrainingMenu.VIEWPORT_SIDE_MARGIN and menu_rect.end.x <= viewport_size.x - BackyardTrainingMenu.VIEWPORT_SIDE_MARGIN)
	assert(is_equal_approx(BackyardTrainingMenu.centered_training_rect(Vector2(1280.0, 720.0)).size.x, 900.0), "The centered desktop menu should use the wider readable layout.")

func test_grapple_slider_labels_preserve_fractional_values() -> void:
	assert(BackyardTrainingMenu.format_grapple_value(0.125, 0.01, "×") == "0.13×")
	assert(BackyardTrainingMenu.format_grapple_value(0.9, 0.05, "×") == "0.90×")
	assert(BackyardTrainingMenu.format_grapple_value(0.12, 0.01, " s") == "0.12 s")
	assert(BackyardTrainingMenu.format_grapple_value(1300.0, 50.0, " px/s") == "1300 px/s")

func test_every_grapple_and_yoyo_control_has_complete_feel_guidance() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	for key: String in GrappleController.TUNING_KEYS:
		assert(source.contains("\"%s\"" % key) and source.contains("_grapple_feel_tip(\"%s\")" % key), "Visible Grapple tuner must use canonical guidance: %s" % key)
		var tooltip: String = BackyardTrainingMenu._grapple_feel_tip(key)
		assert(tooltip.contains("← LEFT:") and tooltip.contains("→ RIGHT:") and tooltip.contains("TIP:"), "Grapple tooltip must contain description, left feel, right feel, and tuning tip: %s" % key)

func test_grapple_ui_and_presets_share_one_authoritative_key_list() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	var seen_titles: Dictionary = {}
	for key: String in GrappleController.TUNING_KEYS:
		var matching_line: String = ""
		for line: String in source.split("\n"):
			if line.contains("_create_grapple_slider") and line.contains("\"%s\"" % key):
				matching_line = line
				break
		assert(not matching_line.is_empty(), "Canonical Grapple tuner is missing from Training Tools: %s" % key)
		var parts: PackedStringArray = matching_line.split("\"")
		var title: String = parts[3] if parts.size() > 3 else ""
		assert(not title.is_empty() and not seen_titles.has(title), "Grapple tuner titles must be distinct: %s" % title)
		seen_titles[title] = key
	assert(source.contains("key not in GrappleController.TUNING_KEYS"), "Live Grapple mutation must be gated by the canonical key list.")

func test_training_tools_use_one_sword_selector_for_visual_and_settings() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(source.contains("player.set_equipped_sword(sword_id)"), "The shared sword dropdown must immediately equip its selected visual.")
	assert(source.contains("player.set_blade_shape_setting(selected_combat_sword_id, key, value)"), "Blade shape must follow the same selected sword.")
	assert(source.contains("player.set_combat_hand_setting_for_sword(selected_combat_sword_id, key, value)"), "Hand tuning must follow the same selected sword.")
	assert(not source.contains("selected_blade_sword_id"))
	assert(not source.contains("Equip This Sword (Testing)"))
	assert(not source.contains("blade_sword_buttons"), "Visual-only sword buttons must not duplicate the dropdown.")

func test_reopening_training_tools_does_not_reload_or_reset_the_live_day_phase() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var menu: BackyardTrainingMenu = main.backyard_training_menu
	var tuner: ForestVisualTuner = menu.forest_visual_tuner
	tuner.selected_phase = "Night"
	# Direct assignment keeps this regression save-free; the menu must merely
	# preserve the already-active world clock rather than mutate persistence.
	main.active_forest_time_phase = "Night"
	main.forest_visual_settings.set_value("grass_brightness", 0.73)
	tuner._on_settings_changed_for_dirty_tracking()
	menu.close()
	menu.open()
	assert(tuner.selected_phase == "Night", "Opening Training Tools must not force the Forest tuner back to Noon.")
	assert(main.get_forest_time_phase() == "Night", "Opening Training Tools must not reset the world day-cycle clock.")
	assert(is_equal_approx(float(main.forest_visual_settings.get_value("grass_brightness")), 0.73), "Opening Training Tools must preserve unsaved live phase tuning.")
	main.free()

func test_bind_form_has_one_shared_slide_authority_for_every_weapon() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var menu: BackyardTrainingMenu = main.backyard_training_menu
	var player: Player = main.get_node("Player") as Player
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_contact_preset = 2
	menu.open()
	menu._sync_combat_controls()
	var row: Dictionary = menu.contact_controls.get("slide_cling", {}) as Dictionary
	var slider: HSlider = row.get("slider") as HSlider
	slider.value = 0.42
	assert(is_equal_approx(player.get_combat_contact_setting("slide_cling"), 0.42), "The one Slide & Bind Feel control must be the gameplay authority.")
	player.set_equipped_sword("Basic Curved Sword")
	assert(is_equal_approx(player.get_combat_contact_setting("slide_cling"), 0.42), "Curved Sword must use the shared slide profile.")
	player.set_equipped_sword("Basic Longsword")
	assert(is_equal_approx(player.get_combat_contact_setting("slide_cling"), 0.42), "Longsword must use the same shared slide profile.")
	assert((row.get("label") as Label).text == "0.42 s", "The shared slider label must show the authoritative value.")
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(not source.contains("FORM-LOCAL SLIDE ENTRY"), "The duplicate form-local Slide section must remain retired.")
	assert(source.contains("\"Rope Shortening Speed\""), "The live reeling authority must remain visible and tunable.")
	assert(source.contains("\"Yo-yo Hang Time\""), "The authored orbit window must remain visible and tunable.")
	main.free()

func test_bind_b_slider_drag_updates_without_full_panel_resync() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var menu: BackyardTrainingMenu = main.backyard_training_menu
	var player: Player = main.get_node("Player") as Player
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.combat_contact_preset = 2
	player.set_equipped_sword("Basic Curved Sword")
	menu.open()
	menu._sync_combat_controls()
	var row: Dictionary = menu.hand_controls.get("bind_capture_time", {}) as Dictionary
	var slider: HSlider = row.get("slider") as HSlider
	slider.value = 0.11
	slider.value = 0.17
	assert(is_equal_approx(slider.value, 0.17), "Bind B slider thumb must retain the latest drag value.")
	assert(is_equal_approx(player.get_combat_hand_setting_for_sword("Basic Curved Sword", "bind_capture_time"), 0.17), "Successive drag values must reach the selected sword's Bind B override.")
	assert((row.get("label") as Label).text == "0.17 s", "The local value label must update without resyncing every slider.")
	main.free()

func test_training_tools_resyncs_the_sword_selector_to_the_live_equipped_sword_on_open() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	var menu: BackyardTrainingMenu = main.backyard_training_menu
	var player: Player = main.get_node("Player") as Player
	player.equipped_sword_id = "Basic Curved Sword"
	menu.open()
	assert(menu.selected_combat_sword_id == "Basic Curved Sword", "Opening Training Tools must reflect whatever sword is actually equipped, not whatever was equipped at boot.")
	var found_selected: bool = false
	for index: int in range(menu.combat_sword_option.item_count):
		if index == menu.combat_sword_option.selected:
			found_selected = str(menu.combat_sword_option.get_item_metadata(index)) == "Basic Curved Sword"
	assert(found_selected, "The dropdown itself must visibly show the live equipped sword, not just the internal variable.")
	main.free()

func test_main_scene_no_longer_contains_the_old_run_menu() -> void:
	var main: Node = MAIN_SCENE.instantiate()
	assert(main.get_node_or_null("CanvasLayer/RunMenu") == null)
	assert(main.get_node_or_null("CanvasLayer/EndRunHub") != null)
	assert(main.get_node_or_null("CanvasLayer/HomeMenu") != null)
	assert(main.get_node_or_null("CanvasLayer/BonusPanel/RerollBonuses") != null)
	main.free()

func test_home_is_a_separate_full_screen_tabbed_menu() -> void:
	var menu: HomeMenu = HOME_MENU_SCENE.instantiate() as HomeMenu
	menu.status_tab = menu.get_node("TopBar/StatusTab") as Button
	menu.storage_tab = menu.get_node("TopBar/StorageTab") as Button
	menu.kitchen_tab = menu.get_node("TopBar/KitchenTab") as Button
	menu.options_tab = menu.get_node("TopBar/OptionsTab") as Button
	menu.settings_tab = menu.get_node("TopBar/SettingsTab") as Button
	menu.settings_page = menu.get_node("SettingsPage") as Control
	menu.music_volume_slider = menu.get_node("SettingsPage/MusicVolumeSlider") as HSlider
	menu.sfx_volume_slider = menu.get_node("SettingsPage/SfxVolumeSlider") as HSlider
	menu.music_volume_value = menu.get_node("SettingsPage/MusicVolumeValue") as Label
	menu.sfx_volume_value = menu.get_node("SettingsPage/SfxVolumeValue") as Label
	menu.metronome_color_button = menu.get_node("SettingsPage/MetronomeColorButton") as Button
	menu.status_page = menu.get_node("StatusPage") as Control
	menu.storage_page = menu.get_node("StoragePage") as Control
	menu.kitchen_page = menu.get_node("KitchenPage") as Control
	menu.options_page = menu.get_node("OptionsPage") as Control
	menu.keyboard_mouse_button = menu.get_node("OptionsPage/KeyboardMouse") as Button
	menu.controller_button = menu.get_node("OptionsPage/Controller") as Button
	menu.control_description = menu.get_node("OptionsPage/ControlDescription") as Label
	menu.controller_status = menu.get_node("OptionsPage/ControllerStatus") as Label
	menu.equipment_text = menu.get_node("StatusPage/EquipmentText") as RichTextLabel
	menu.food_slot = menu.get_node("StatusPage/FoodSlot") as Button
	menu.food_list_panel = menu.get_node("StatusPage/FoodListPanel") as Panel
	menu.food_buttons = menu.get_node("StatusPage/FoodListPanel/FoodButtons") as VBoxContainer
	menu.food_tooltip_panel = menu.get_node("StatusPage/FoodTooltipPanel") as Panel
	menu.food_tooltip_text = menu.get_node("StatusPage/FoodTooltipPanel/FoodTooltipText") as RichTextLabel
	menu.status_feedback = menu.get_node("StatusPage/StatusFeedback") as Label
	menu.storage_text = menu.get_node("StoragePage/StorageText") as RichTextLabel
	menu.cooking_text = menu.get_node("KitchenPage/CookingText") as RichTextLabel
	menu.crafting_slot = menu.get_node("KitchenPage/CraftingSlot") as Button
	menu.craft_progress = menu.get_node("KitchenPage/CraftProgress") as ProgressBar
	menu.craft_timer = menu.get_node("KitchenPage/CraftTimer") as Label
	menu.recipe_list_panel = menu.get_node("KitchenPage/RecipeListPanel") as Panel
	menu.recipe_buttons = menu.get_node("KitchenPage/RecipeListPanel/RecipeButtons") as VBoxContainer
	menu.recipe_tooltip_panel = menu.get_node("KitchenPage/RecipeTooltipPanel") as Panel
	menu.recipe_tooltip_text = menu.get_node("KitchenPage/RecipeTooltipPanel/RecipeTooltipText") as RichTextLabel
	menu.feedback_label = menu.get_node("KitchenPage/FeedbackLabel") as Label
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material("Turkey", 2)
	progression.add_material("Mushroom", 1)
	menu.configure(progression)
	menu.show_tab(HomeMenu.Tab.STATUS)
	assert(menu.status_page.visible and menu.equipment_text.text.contains("EQUIPPED GEAR") and menu.food_slot.text.contains("PREPARED FOOD"))
	menu._open_food_list()
	assert(menu.food_list_panel.visible and menu.food_buttons.get_child_count() == 1)
	menu._show_food_tooltip(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(menu.food_tooltip_text.text.contains("In Storage: [color=#f1cf78]0"))
	menu._select_prepared_food(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(progression.prepared_food_id.is_empty(), "An unavailable red meal must not be prepared.")
	progression.food_inventory[CookingConfig.WILD_TURKEY_STEW_ID] = 1
	menu._select_prepared_food(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(progression.prepared_food_id == CookingConfig.WILD_TURKEY_STEW_ID)
	menu.show_tab(HomeMenu.Tab.STORAGE)
	menu.refresh()
	assert(menu.storage_page.visible and menu.storage_text.text.contains("Moon Petal") and menu.storage_text.text.contains("Wild Turkey Stew"))
	menu.show_tab(HomeMenu.Tab.KITCHEN)
	assert(menu.kitchen_page.visible and menu.cooking_text.text.contains("GRANDMA'S KITCHEN"))
	menu._open_recipe_list()
	assert(menu.recipe_list_panel.visible and menu.recipe_buttons.get_child_count() == 2)
	menu._show_recipe_tooltip(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(menu.recipe_tooltip_text.text.contains("Crafting Time: 50 seconds"))
	assert(menu.recipe_tooltip_text.text.contains("Turkey — 2") and menu.recipe_tooltip_text.text.contains("Mushroom — 1"))
	menu._select_recipe(CookingConfig.WILD_TURKEY_STEW_ID)
	assert(progression.is_crafting() and menu.crafting_slot.text == "Wild Turkey Stew")
	assert(menu.craft_progress.visible and menu.craft_timer.visible)
	menu.show_tab(HomeMenu.Tab.OPTIONS)
	menu.set_input_mode("controller")
	assert(menu.options_page.visible and menu.controller_status.text == "ACTIVE: CONTROLLER")
	assert(menu.control_description.text.contains("LB: Dash") and menu.control_description.text.contains("RB: Chakram"))
	menu.set_input_mode("keyboard_mouse")
	assert(menu.control_description.text.contains("Hold RMB: Grapple"))
	menu.show_tab(HomeMenu.Tab.SETTINGS)
	assert(menu.settings_page.visible and menu.music_volume_slider.value == 100.0 and menu.sfx_volume_slider.value == 100.0)
	menu.set_audio_volumes(0.35, 0.8)
	assert(is_equal_approx(menu.music_volume_slider.value, 35.0) and is_equal_approx(menu.sfx_volume_slider.value, 80.0))
	assert(menu.music_volume_value.text == "35%" and menu.sfx_volume_value.text == "80%")
	menu.set_metronome_color("gold")
	menu._cycle_metronome_color()
	assert(menu.metronome_color == "blue" and menu.metronome_color_button.text == "METRONOME COLOR: MYSTIC BLUE")
	assert(menu.get_node_or_null("TopBar/AdventureButton") != null)
	menu.free()
