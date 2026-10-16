extends Node

func test_catalog_exact_prices_and_one_time_recipe_purchases() -> void:
	var p: HomeProgression = HomeProgression.new()
	var names: Array[String] = []
	for id: String in ArmoryConfig.FORGE_RECIPES:
		names.append(ArmoryConfig.FORGE_RECIPES[id]["name"])
		assert(int(ArmoryConfig.FORGE_PERMANENT_OFFERS[id]["coins"]) == 200)
		p.materials["Coins"] = 199
		var before: Dictionary = p.to_save_data()
		assert(p.trade_with_jimbo(id, 1, true, 1000) == 0)
		assert(p.to_save_data() == before)
		p.materials["Coins"] = 201
		before = p.to_save_data()
		for quantity: int in [-1, 0, 2]:
			assert(p.trade_with_jimbo(id, quantity, true) == 0 and p.to_save_data() == before)
		p.jimbo_gold = 499
		assert(p.trade_with_jimbo(id, 1, true, 1000) == 1)
		assert(p.material_count("Coins") == 1 and p.jimbo_gold == 500)
		assert(p.owns_forge_offer(id))
		before = p.to_save_data()
		assert(p.trade_with_jimbo(id, 1, true, 1000) == 0)
		assert(p.trade_with_jimbo(id, 1, false, 1000) == 0)
		assert(p.to_save_data() == before)
		assert(not p.materials.has(id) and not p.jimbo_stock.has(id))
	assert(names == ["Iron Longsword", "Iron Banded Chakram", "Basic Leather Armor", "Iron Band"])
	p.update_jimbo(999999)
	assert(p.owned_forge_recipes.size() == 4 and p.gear_inventory.is_empty())

func test_second_slot_requires_both_costs_atomic_and_no_quantity_exploits() -> void:
	var p: HomeProgression = HomeProgression.new()
	var id: String = ArmoryConfig.SECOND_FORGE_SLOT_ID
	for coins: int in [4999, 5000]:
		for stone: int in [99, 100]:
			p.materials["Coins"] = coins
			p.materials["Stone"] = stone
			p.materials["Wood"] = 17
			var before: Dictionary = p.to_save_data()
			if coins == 5000 and stone == 100: continue
			assert(p.trade_with_jimbo(id, 1, true) == 0)
			assert(p.to_save_data() == before)
	p.materials["Coins"] = 6000
	p.materials["Stone"] = 105
	for quantity: int in [-1, 0, 2, 9223372036854775807]:
		var before: Dictionary = p.to_save_data()
		assert(p.trade_with_jimbo(id, quantity, true) == 0)
		assert(p.to_save_data() == before)
	var before: Dictionary = p.to_save_data()
	assert(p.buy_forge_offer("unknown", 1) == 0)
	assert(p.trade_with_jimbo("forge_recipe:unknown", 1, true) == 0)
	assert(p.trade_with_jimbo("forge_upgrade:unknown", 1, true) == 0)
	assert(p.to_save_data() == before)
	p.jimbo_gold = 0
	assert(p.trade_with_jimbo(id, 1, true) == 1)
	assert(p.forge_slot_count == 2 and p.material_count("Coins") == 1000 and p.material_count("Stone") == 5)
	assert(p.material_count("Wood") == 17 and p.jimbo_gold == 500)
	before = p.to_save_data()
	assert(p.trade_with_jimbo(id, 1, true) == 0 and p.to_save_data() == before)

func test_save_roundtrip_and_migration() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.materials["Coins"] = 10000
	p.materials["Stone"] = 100
	for id: String in ArmoryConfig.FORGE_PERMANENT_OFFERS: assert(p.buy_forge_offer(id, 1) == 1)
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	assert(restored.owned_forge_recipes == p.owned_forge_recipes and restored.forge_slot_count == 2)
	restored.load_save_data({})
	assert(restored.forge_slot_count == 1 and restored.owned_forge_recipes.is_empty())
	restored.load_save_data({"forge_slot_count": 99, "owned_forge_recipes": {"unknown": true, "forge_recipe:iron_band": true}})
	assert(restored.forge_slot_count == 2 and restored.owned_forge_recipes == {"forge_recipe:iron_band": true})
	restored.load_save_data({"forge_slot_count": -5, "owned_forge_recipes": ["unknown"]})
	assert(restored.forge_slot_count == 1 and restored.owned_forge_recipes.is_empty())

func test_real_main_atomic_failure_restores_all_permanent_fields() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	var p: HomeProgression = main.home_progression
	p.materials["Coins"] = 10000
	p.materials["Stone"] = 111
	p.active_food_waves_remaining = 4
	for id: String in ArmoryConfig.FORGE_PERMANENT_OFFERS:
		var before: Dictionary = p.to_save_data()
		assert(main._buy_blacksmith_goods(id, 1) == -1)
		assert(p.to_save_data() == before)
		assert(p.active_food_waves_remaining == 4)
	main.free()

func test_real_atomic_writer_failure_restores_recipe_and_slot_purchase() -> void:
	var main: Main = preload("res://tests/shrine_save_failure.gd").new() as Main
	var p: HomeProgression = main.home_progression
	p.materials["Coins"] = 10000
	p.materials["Stone"] = 111
	var before: Dictionary = p.to_save_data()
	for id: String in ["forge_recipe:iron_longsword", ArmoryConfig.SECOND_FORGE_SLOT_ID]:
		assert(main._buy_blacksmith_goods(id, 1) == -1)
		assert(p.to_save_data() == before)
	main.free()

func test_real_main_atomic_success_in_disposable_save_only() -> void:
	var main: GeneralStoreTempSave = preload("res://tests/general_store_temp_save.gd").new() as GeneralStoreTempSave
	var p: HomeProgression = main.home_progression
	p.materials["Coins"] = 10000
	p.materials["Stone"] = 100
	for id: String in ArmoryConfig.FORGE_PERMANENT_OFFERS: assert(main._buy_blacksmith_goods(id, 1) == 1)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.temporary_path)) as Dictionary
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(data["home_progression"])
	assert(restored.forge_slot_count == 2 and restored.owned_forge_recipes.size() == 4)
	assert(restored.gear_inventory.is_empty() and restored.material_count("Coins") == 4200 and restored.material_count("Stone") == 0)
	main.free()

func test_responsive_workshop_slots_scroll_without_minigame_overlap() -> void:
	for width: int in [1280, 640, 384]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = Vector2i(width, 720)
		add_child(viewport)
		var home: HomeMenu = preload("res://scenes/ui/home_menu.tscn").instantiate() as HomeMenu
		viewport.add_child(home)
		var p: HomeProgression = HomeProgression.new()
		p.forge_purchased = true
		p.forge_slot_count = 2
		p.owned_forge_recipes["forge_recipe:iron_banded_chakram"] = true
		home.configure(p)
		home._open_forge()
		for frame: int in 5: await get_tree().process_frame
		assert(home.forge_page.position.x + home.forge_page.size.x <= width)
		assert(home.forge_columns.vertical == (width == 384))
		assert(home.forge_columns.size.x <= home.forge_page.size.x - 32.0)
		var slots: ScrollContainer = home.forge_slots.get_parent() as ScrollContainer
		assert(slots.get_global_rect().end.y <= home.forge_sword_button.get_global_rect().position.y)
		assert(home.forge_sword_button.size.x <= home.forge_page.size.x - 32.0)
		assert(home.forge_craft_button.disabled)
		viewport.free()

func test_main_existing_minigame_launch_and_close_returns_to_workshop() -> void:
	var main: Main = preload("res://tests/forge_safe_main.gd").new() as Main
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "CanvasLayer"
	main.add_child(canvas)
	var home: HomeMenu = preload("res://scenes/ui/home_menu.tscn").instantiate() as HomeMenu
	add_child(home)
	main.home_menu = home
	main.music_director = MusicDirector.new()
	main.home_progression.forge_purchased = true
	home.configure(main.home_progression)
	home._open_forge()
	home.forge_requested.connect(main._on_forge_requested)
	var before: Dictionary = main.home_progression.to_save_data()
	home.forge_sword_button.pressed.emit()
	assert(not home.visible and main.sword_smithing_instance is SwordSmithingGame)
	assert(main.sword_smithing_instance.closed.is_connected(main._on_forge_closed))
	main.sword_smithing_instance.closed.emit()
	assert(main.sword_smithing_instance == null)
	assert(home.visible and home.active_tab == HomeMenu.Tab.FORGE and home.forge_page.visible)
	assert(main.home_progression.to_save_data() == before)
	assert(main.active_forest_time_phase == "Noon")
	main.music_director.free()
	main.free()
	home.free()

func test_actual_home_and_town_ui_navigation_disabled_crafting_and_owned() -> void:
	var home: HomeMenu = preload("res://scenes/ui/home_menu.tscn").instantiate() as HomeMenu
	add_child(home)
	var p: HomeProgression = HomeProgression.new()
	home.configure(p)
	home._open_forge()
	assert(not home.forge_page.visible)
	p.forge_purchased = true
	p.materials["Coins"] = 10000
	p.materials["Stone"] = 100
	home.configure(p)
	home.show_tab(HomeMenu.Tab.CRAFTING)
	var emitted: Array = []
	home.forge_requested.connect(func() -> void: emitted.append(true))
	home.forge_button.pressed.emit()
	assert(home.active_tab == HomeMenu.Tab.FORGE and home.forge_page.visible and emitted.is_empty())
	assert(home.forge_slots.get_child_count() == 2 and home.forge_slots.get_child(1) is Label)
	assert(home.forge_slots.get_parent() is ScrollContainer)
	home.forge_slots.get_child(0).pressed.emit()
	assert(home.forge_craft_button.disabled and home.forge_recipes.get_child(0) is Label)
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	hub.configure_town(p, p.sell_to_kaji, p.buy_from_kaji, Callable(), func(id: String, qty: int) -> int: return p.trade_with_jimbo(id, qty, true))
	var town: TownMenu = hub.town_menu
	town.open_blacksmiths()
	for id: String in ArmoryConfig.FORGE_PERMANENT_OFFERS:
		town._trade_selected(id, true)
		assert(p.owns_forge_offer(id))
		for row: Dictionary in town.trade_rows:
			if row["id"] == id:
				assert(row["trade"].text == "Owned" and row["trade"].disabled)
				assert(not row["left"].visible and not row["right"].visible)
	home._open_forge()
	assert(home.forge_slots.get_child(1) is Button and home.forge_recipes.get_child_count() == 4)
	var before: Dictionary = p.to_save_data()
	home.forge_recipes.get_child(0).pressed.emit()
	assert(home.forge_status.text.contains("Crafting requirements not configured yet"))
	home.forge_sword_button.pressed.emit()
	assert(emitted.size() == 1 and p.to_save_data() == before)
	assert(home.forge_craft_button.disabled)
	home.show_tab(HomeMenu.Tab.KITCHEN)
	assert(home.kitchen_page.visible and not home.forge_page.visible)
	hub.free()
	home.free()
