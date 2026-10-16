class_name GeneralStoreTest extends Node

func test_elapsed_cap_backward_fractional_and_offline() -> void:
	var p: HomeProgression = HomeProgression.new()
	assert(p.kaji_gold == 500.0)
	p.update_kaji(1000)
	p.kaji_gold = 0.0
	p.update_kaji(1001)
	assert(is_equal_approx(p.kaji_gold, 125.0 / 3600.0))
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	restored.update_kaji(1001)
	assert(is_equal_approx(restored.kaji_gold, p.kaji_gold))
	restored.update_kaji(900)
	restored.update_kaji(1001)
	assert(is_equal_approx(restored.kaji_gold, p.kaji_gold))
	restored.update_kaji(3880)
	assert(is_equal_approx(restored.kaji_gold, 100.0))
	restored.update_kaji(15400)
	assert(is_equal_approx(restored.kaji_gold, 500.0))
	restored.update_kaji(99999)
	restored.kaji_gold = 400.0
	restored.update_kaji(99999)
	assert(restored.kaji_gold == 400.0, "Time spent at cap must not be banked")
	restored.update_kaji(102879)
	assert(is_equal_approx(restored.kaji_gold, 500.0))

func test_affordability_currency_filters_and_reserved_food() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.update_kaji(1000)
	p.kaji_gold = 10.5
	p.add_material("Turkey", 10)
	assert(p.sell_to_kaji("Turkey", 10, 1000) == 2)
	assert(p.material_count("Turkey") == 8 and p.material_count("Coins") == 8)
	assert(p.kaji_gold == 2.5)
	assert(p.sell_to_kaji("Turkey", 1, 1000) == 0)
	assert(p.sell_to_kaji("Turkey", -1, 1000) == 0)
	for excluded: String in ["Coins", "Iron Shard", "Stone", "Wood", "Sword", "Armor", "quest_object", "gear_1"]:
		p.add_material(excluded, 20)
		assert(ItemConfig.general_sale_price(excluded) == 0)
		assert(p.sell_to_kaji(excluded, 20, 1000) == 0)
	p.kaji_gold = 500
	p.food_inventory[CookingConfig.WILD_TURKEY_STEW_ID] = 3
	assert(p.prepare_food(CookingConfig.WILD_TURKEY_STEW_ID))
	assert(p.sell_to_kaji(CookingConfig.WILD_TURKEY_STEW_ID, 3, 1000) == 2)
	assert(p.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 1)
	assert(p.prepared_food_id == CookingConfig.WILD_TURKEY_STEW_ID)
	assert(p.begin_expedition())
	assert(p.sell_to_kaji(CookingConfig.WILD_TURKEY_STEW_ID, 1, 1000) == 0)
	assert(p.active_food_waves_remaining == 10)

func test_metadata_cooked_margin_and_migration() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.load_save_data({"materials": {"Coins": 9}})
	assert(p.kaji_gold == 500 and p.material_count("Coins") == 9)
	for recipe: String in CookingConfig.recipe_ids():
		var ingredients_value: int = 0
		var ingredients: Dictionary = CookingConfig.recipe_ingredients(recipe)
		for ingredient: String in ingredients:
			ingredients_value += int(ingredients[ingredient]) * ItemConfig.general_sale_price(ingredient)
		assert(ItemConfig.general_sale_price(recipe) > ingredients_value)
		assert(ItemConfig.general_sale_price(recipe) >= 12 and ItemConfig.general_sale_price(recipe) <= 25)
		assert(ItemConfig.general_category(recipe) == "Cooked food")

func test_atomic_save_roundtrip_without_real_save() -> void:
	var main: Main = Main.new()
	main.home_progression.add_material("Turkey", 3)
	main.home_progression.update_kaji()
	assert(main.home_progression.sell_to_kaji("Turkey", 2) == 2)
	var temp: FileAccess = FileAccess.create_temp(FileAccess.WRITE, "kaji_test", "json")
	var path: String = temp.get_path_absolute()
	temp.close()
	assert(main.save_game(path))
	assert(main.save_game(path), "Atomic replace must also overwrite an existing save")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(data["home_progression"] as Dictionary)
	assert(restored.material_count("Turkey") == 1 and restored.material_count("Coins") == 8)
	assert(restored.kaji_gold >= 492.0 and restored.kaji_gold < 493.0)
	assert(data["home_progression"].has("kaji_updated_at_unix"))
	main.free()

func test_failed_trade_save_rolls_back_without_ending_buff() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	main.home_progression.add_material("Turkey", 5)
	main.home_progression.active_food_id = CookingConfig.WILD_TURKEY_STEW_ID
	main.home_progression.active_food_waves_remaining = 4
	assert(main._sell_general_goods("Turkey", 4) == -1)
	assert(main.home_progression.material_count("Turkey") == 5)
	assert(main.home_progression.material_count("Coins") == 0)
	assert(main.home_progression.kaji_gold == 500)
	assert(main.home_progression.active_food_waves_remaining == 4)
	main.free()

func test_discovery_common_filter_initial_stock_and_no_reseed() -> void:
	var p: HomeProgression = HomeProgression.new()
	assert(p.general_stock_count("Turkey") == 0)
	for excluded: String in ["Coins", "Iron Shard", "Moon Petal", "Stone", "Wood", "Sword", "quest_object"]:
		p.add_material(excluded, 1)
		assert(p.general_stock_count(excluded) == 0)
		assert(p.buy_from_kaji(excluded, 1, 1000) == 0)
	p.add_material("Turkey", 1)
	assert(p.general_stock_count("Turkey") == 5)
	assert(p.sell_to_kaji("Turkey", 1, 1000) == 1)
	assert(p.material_count("Turkey") == 0 and p.discovered_items.has("Turkey"))
	assert(p.general_stock_count("Turkey") == 5, "Sales must not inflate stock")
	p.add_material("Coins", 100)
	assert(ItemConfig.general_purchase_price("Turkey") == 2 * ItemConfig.general_sale_price("Turkey"))
	assert(p.buy_from_kaji("Turkey", 99, 1000) == 5)
	assert(p.material_count("Turkey") == 5 and p.material_count("Coins") == 65)
	assert(p.general_stock_count("Turkey") == 0)
	p.add_material("Turkey", 1)
	assert(p.general_stock_count("Turkey") == 0, "Repeat acquisition must not restock")
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	assert(restored.discovered_items.has("Turkey") and restored.general_stock_count("Turkey") == 0)
	assert(restored.buy_from_kaji("Turkey", 1, 1000) == 0)
	assert(restored.buy_from_kaji("Turkey", 1, 99999) == 1, "Offline elapsed stock replenishes before buying")

func test_purchase_affordability_food_storage_purse_cap_and_crafting_discovery() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.add_material("Turkey", 2)
	p.add_material("Mushroom", 1)
	assert(p.start_crafting(CookingConfig.WILD_TURKEY_STEW_ID, 1000))
	assert(p.finish_current_crafting_now() == CookingConfig.WILD_TURKEY_STEW_ID)
	assert(p.general_stock_count(CookingConfig.WILD_TURKEY_STEW_ID) == 5)
	p.add_material("Coins", 71)
	p.kaji_gold = 499.0
	assert(p.buy_from_kaji(CookingConfig.WILD_TURKEY_STEW_ID, 5, 1000) == 1)
	assert(p.food_count(CookingConfig.WILD_TURKEY_STEW_ID) == 2)
	assert(p.material_count(CookingConfig.WILD_TURKEY_STEW_ID) == 0)
	assert(p.material_count("Coins") == 35 and p.kaji_gold == 500.0)
	assert(p.buy_from_kaji(CookingConfig.WILD_TURKEY_STEW_ID, 1, 1000) == 0)
	assert(p.general_stock_count(CookingConfig.WILD_TURKEY_STEW_ID) == 4)
	assert(p.buy_from_kaji("Turkey", -1, 1000) == 0)

func test_discovery_legacy_migration_is_once_and_not_run_report() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.load_save_data({"materials": {"Turkey": 2}, "food_inventory": {CookingConfig.WOLF_JERKY_ID: 1}})
	assert(p.general_stock_count("Turkey") == 5)
	assert(p.general_stock_count(CookingConfig.WOLF_JERKY_ID) == 5)
	var data: Dictionary = p.to_save_data()
	data["materials"]["Mushroom"] = 4
	p.load_save_data(data)
	assert(not p.discovered_items.has("Mushroom"), "Only old saves bootstrap from storage")
	var record: RunLootRecord = RunLootRecord.new()
	record.record_item("Moon Petal", 1)
	assert(not p.discovered_items.has("Moon Petal"), "Run reports are observation, not shop authority")

func test_purchase_atomic_failure_and_success_only_temp_save() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	main.home_progression.add_material("Turkey", 1)
	main.home_progression.add_material("Coins", 100)
	main.home_progression.kaji_gold = 400.0
	main.home_progression.update_kaji()
	main.home_progression.active_food_id = CookingConfig.WILD_TURKEY_STEW_ID
	main.home_progression.active_food_waves_remaining = 4
	var before: Dictionary = main.home_progression.to_save_data()
	assert(main._buy_general_goods("Turkey", 3) == -1)
	assert(main.home_progression.materials == before["materials"])
	assert(main.home_progression.food_inventory == before["food_inventory"])
	assert(main.home_progression.kaji_stock == before["kaji_stock"])
	assert(main.home_progression.discovered_items == before["discovered_items"])
	assert(is_equal_approx(main.home_progression.kaji_gold, 400.0))
	assert(main.home_progression.active_food_waves_remaining == 4)
	main.free()
	var success: Main = preload("res://tests/general_store_temp_save.gd").new() as Main
	success.home_progression.add_material("Turkey", 1)
	success.home_progression.add_material("Coins", 100)
	success.home_progression.kaji_gold = 400.0
	assert(success._buy_general_goods("Turkey", 3) == 3)
	assert(success.home_progression.material_count("Coins") == 76)
	assert(success.home_progression.material_count("Turkey") == 4)
	assert(success.home_progression.general_stock_count("Turkey") == 2)
	assert(success.home_progression.kaji_gold >= 424 and success.home_progression.kaji_gold < 425)
	success.free()

func test_quantity_arrows_clamp_color_and_refresh_stability() -> void:
	var menu: TownMenu = TownMenu.new()
	var p: HomeProgression = HomeProgression.new()
	p.add_material("Turkey", 10)
	p.add_material("Coins", 100)
	menu.progression = p
	menu.sell_callback = func(_id: String, _quantity: int) -> int: return 0
	menu.buy_callback = menu.sell_callback
	add_child(menu)
	menu.open_general()
	menu._change_quantity("Turkey", false, 2)
	assert(menu._selected_quantity("Turkey", false) == 3)
	menu._rebuild_rows()
	assert(menu._selected_quantity("Turkey", false) == 3)
	menu.open_town()
	menu.open_general()
	assert(p.general_stock_count("Turkey") == 5)
	assert(menu._selected_quantity("Turkey", false) == 3)
	p.kaji_gold = 8.0
	menu._refresh_trade_rows()
	assert(menu._selected_quantity("Turkey", false) == 2)
	menu._change_quantity("Turkey", true, 99)
	assert(menu._selected_quantity("Turkey", true) == 5)
	p.materials["Coins"] = 7
	p.kaji_gold = 0
	menu._refresh_trade_rows()
	assert(menu._selected_quantity("Turkey", true) == 0)
	for row: Dictionary in menu.trade_rows:
		assert((row["trade"] as Button).disabled)
		assert((row["left"] as Button).disabled and (row["right"] as Button).disabled)
		assert((row["right"] as Button).get_theme_color("font_color") == TownMenu.ARROW_YELLOW)
	menu.free()

func test_navigation_portrait_greeting_and_no_run_requests() -> void:
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	var p: HomeProgression = HomeProgression.new()
	hub.configure_town(p, func(_id: String, _quantity: int) -> int: return 0)
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	(hub.adventure_card.get_node("TownButton") as Button).pressed.emit()
	assert(hub.active_tab == EndRunHub.Tab.TOWN and not hub.adventure_card.visible)
	hub.town_menu.open_general()
	assert(hub.town_menu.general_page.visible)
	assert((hub.town_menu.general_page.get_node("KajiPortrait") as TextureRect).texture == TownMenu.KAJI_PORTRAIT)
	var greeting_found: bool = false
	for child: Node in hub.town_menu.general_page.get_children():
		if child is Label and (child as Label).text == "Welcome! Got anything to trade?": greeting_found = true
	assert(greeting_found)
	hub.town_menu.open_blacksmiths()
	assert(hub.town_menu.blacksmith_page.visible)
	hub.town_menu.open_town()
	hub.town_menu.adventure_requested.emit()
	assert(hub.active_tab == EndRunHub.Tab.ADVENTURE)
	hub.free()

func test_general_page_buttons_exclusive_full_list_area_and_refresh() -> void:
	var preview: GeneralStorePreview = preload("res://tests/general_store_preview.tscn").instantiate() as GeneralStorePreview
	add_child(preview)
	var menu: TownMenu = preview.menu
	assert(menu.selected_buy_page and menu.buy_tab.button_pressed and not menu.sell_tab.button_pressed)
	assert(menu.buy_page.is_visible_in_tree() and not menu.sell_page.is_visible_in_tree())
	var buy_scroll: ScrollContainer = menu.buy_rows.get_parent() as ScrollContainer
	var sell_scroll: ScrollContainer = menu.rows.get_parent() as ScrollContainer
	assert(buy_scroll.size == menu.buy_page.size - Vector2(0, 28) and sell_scroll.size == buy_scroll.size)
	assert(buy_scroll.size.x == menu.buy_page.size.x and buy_scroll.size.x <= 500)
	assert(menu.buy_page.position.x + buy_scroll.size.x <= menu.general_page.size.x - 20)
	assert(menu.buy_page.position == menu.sell_page.position and menu.buy_page.size == menu.sell_page.size)
	assert(menu.buy_rows.get_child_count() >= 5 and menu.rows.get_child_count() >= 5)
	var materials_before: Dictionary = preview.progression.materials.duplicate()
	var stock_before: Dictionary = preview.progression.kaji_stock.duplicate()
	menu.sell_tab.pressed.emit()
	assert(not menu.selected_buy_page and menu.sell_tab.button_pressed and not menu.buy_tab.button_pressed)
	assert(menu.sell_page.is_visible_in_tree() and not menu.buy_page.is_visible_in_tree())
	assert(menu.rows.is_visible_in_tree() and not menu.buy_rows.is_visible_in_tree())
	menu.sell_tab.pressed.emit()
	assert(menu.sell_tab.button_pressed, "Clicking the active tab must not deselect both pages")
	assert(preview.progression.materials == materials_before and preview.progression.kaji_stock == stock_before)
	menu._change_quantity("Forest Herb", false, 1)
	menu._rebuild_rows()
	menu.refresh_wait = 0.0
	menu._process(1.0)
	assert(menu.sell_page.is_visible_in_tree() and not menu.buy_page.is_visible_in_tree())
	menu._trade_selected("Forest Herb", false)
	assert(not menu.selected_buy_page and menu.sell_tab.button_pressed)
	assert(menu.rows.is_visible_in_tree() and not menu.buy_rows.is_visible_in_tree())
	menu.open_town()
	assert(menu.town_page.visible and not menu.general_page.visible)
	menu.open_general()
	assert(menu.sell_page.is_visible_in_tree() and not menu.buy_page.is_visible_in_tree())
	menu.buy_tab.pressed.emit()
	menu._change_quantity("Turkey", true, 1)
	menu._trade_selected("Turkey", true)
	assert(menu.selected_buy_page and menu.buy_tab.button_pressed and not menu.sell_tab.button_pressed)
	assert(menu.buy_rows.is_visible_in_tree() and not menu.rows.is_visible_in_tree())
	preview.free()

func test_general_empty_pages_switch_without_both_lists() -> void:
	var menu: TownMenu = TownMenu.new()
	menu.progression = HomeProgression.new()
	add_child(menu)
	menu.open_general()
	assert(menu.buy_rows.get_child_count() == 1 and menu.rows.get_child_count() == 1)
	assert((menu.buy_rows.get_child(0) as Label).text == "No common goods discovered yet.")
	assert(menu.buy_rows.is_visible_in_tree() and not menu.rows.is_visible_in_tree())
	menu.sell_tab.pressed.emit()
	assert((menu.rows.get_child(0) as Label).text == "No tradable goods. Prepared servings are reserved.")
	assert(menu.rows.is_visible_in_tree() and not menu.buy_rows.is_visible_in_tree())
	menu.free()
