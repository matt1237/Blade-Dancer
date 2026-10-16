extends Node

func _gear(id: String = "gear_1") -> Dictionary:
	return {"id": id, "slot": "Sword", "base_name": "Basic Curved Sword", "origin": "found", "techniques": {"defense": 4}, "base_techniques": {"defense": 1}, "skill_infusions": {"defense": 3}}

func test_material_registry_discovery_prices_and_limits() -> void:
	var p: HomeProgression = HomeProgression.new()
	assert(p.blacksmith_stock_count("Wood") == 0)
	for excluded: String in ["Coins", "quest", "Unknown Ore", "Forest Herb", "Turkey", "Moon Petal"]:
		p.add_material(excluded, 10)
		assert(p.trade_with_jimbo(excluded, 1, false, 1000) == 0)
		assert(p.trade_with_jimbo(excluded, 1, true, 1000) == 0)
	for key: String in ["Wood", "Stone", "Iron Shard"]:
		p.add_material(key, 10)
		assert(p.blacksmith_stock_count(key) == 5)
		assert(p.blacksmith_price(key, true) == p.blacksmith_price(key, false) * 2)
	p.jimbo_gold = 5.0
	assert(p.trade_with_jimbo("Wood", 10, false, 1000) == 2)
	assert(p.material_count("Wood") == 8 and p.material_count("Coins") == 14)
	assert(p.blacksmith_stock_count("Wood") == 5)
	p.materials["Coins"] = 100
	assert(p.trade_with_jimbo("Wood", 20, true, 1000) == 5)
	assert(p.blacksmith_stock_count("Wood") == 0)
	p.add_material("Wood", 1)
	assert(p.blacksmith_stock_count("Wood") == 0)

func test_offline_fractional_high_water_caps_and_persistence() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.add_material("Wood", 1)
	p.update_jimbo(1000)
	p.jimbo_gold = 0.0
	p.jimbo_stock["Wood"] = 0
	p.update_jimbo(2200)
	assert(p.blacksmith_stock_count("Wood") == 0)
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	restored.update_jimbo(3400)
	assert(restored.blacksmith_stock_count("Wood") == 1)
	assert(is_equal_approx(restored.jimbo_gold, 125.0 * 2400.0 / 3600.0))
	restored.update_jimbo(1000)
	restored.update_jimbo(3400)
	assert(restored.blacksmith_stock_count("Wood") == 1)
	restored.update_jimbo(99999)
	assert(restored.blacksmith_stock_count("Wood") == 5 and restored.jimbo_gold == 500.0)
	restored.jimbo_stock["Wood"] = 0
	restored.jimbo_gold = 0
	restored.update_jimbo(99999)
	assert(restored.blacksmith_stock_count("Wood") == 0 and restored.jimbo_gold == 0)
	assert(restored.kaji_gold == 500.0)

func test_gear_origin_equipment_infusions_unique_ids_and_stock() -> void:
	var p: HomeProgression = HomeProgression.new()
	var item: Dictionary = _gear()
	p.add_gear_item(item)
	assert(p.blacksmith_price("gear_1", false) == 100)
	assert(p.equip_gear("gear_1"))
	assert(p.trade_with_jimbo("gear_1", 1, false, 1000) == 0)
	p.unequip_gear("Sword")
	var key: String = ArmoryConfig.smith_stock_key(item)
	assert(p.trade_with_jimbo("gear_1", 4, false, 1000) == 1)
	assert(p.gear_item_by_id("gear_1").is_empty())
	assert(p.blacksmith_stock_count(key) == 5)
	p.add_material("Coins", 1000)
	assert(p.trade_with_jimbo(key, 2, true, 1000) == 2)
	assert(p.gear_inventory.size() == 2)
	assert(p.gear_inventory[0]["id"] != p.gear_inventory[1]["id"])
	assert(p.gear_inventory[0]["id"] != "gear_1")
	assert(p.gear_inventory[0]["techniques"] == {"defense": 1})
	assert(not p.gear_inventory[0].has("skill_infusions"))
	var starter: Dictionary = _gear("starter")
	starter["origin"] = "skill"
	p.add_gear_item(starter)
	assert(p.blacksmith_sellable_count("starter") == 0)
	var legacy: Dictionary = _gear("legacy")
	legacy.erase("origin")
	legacy.erase("base_techniques")
	assert(ArmoryConfig.smith_value(legacy) == 100)
	var ring: Dictionary = _gear("ring")
	ring["slot"] = "Ring"
	ring["base_name"] = "Clear Quartz Ring"
	assert(not ArmoryConfig.smith_eligible(ring))
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	assert(restored.blacksmith_stock_count(key) == 3)
	assert(restored.gear_inventory[0]["base_techniques"] == {"defense": 1})
	restored.update_jimbo(3400)
	assert(restored.blacksmith_stock_count(key) == 4)
	assert(restored.gear_inventory.size() == 3, "Restocking offers must not create owned gear")
	var old_save: HomeProgression = HomeProgression.new()
	old_save.load_save_data({"materials": {"Wood": 2}, "gear_inventory": [legacy]})
	assert(old_save.blacksmith_stock_count("Wood") == 5)
	assert(old_save.blacksmith_sellable_count("legacy") == 1)
	old_save.jimbo_stock["Wood"] = 0
	old_save.update_jimbo(99999)
	assert(old_save.blacksmith_stock_count("Wood") == 0, "First update must not credit legacy offline time")

func test_atomic_save_failure_rolls_back_gear_and_id_without_buff_loss() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	var p: HomeProgression = main.home_progression
	p.add_gear_item(_gear())
	p.add_material("Coins", 1000)
	p.active_food_waves_remaining = 4
	p.add_material("Wood", 6)
	p.update_jimbo()
	var before: Dictionary = p.to_save_data()
	assert(main._sell_blacksmith_goods("gear_1", 1) == -1)
	assert(p.gear_inventory == before["gear_inventory"] and p.materials == before["materials"])
	var key: String = ArmoryConfig.smith_stock_key(_gear())
	assert(main._buy_blacksmith_goods(key, 2) == -1)
	assert(p.gear_inventory == before["gear_inventory"])
	assert(p.jimbo_stock == before["jimbo_stock"] and p.next_gear_item_id == before["next_gear_item_id"])
	assert(p.jimbo_gold == before["jimbo_gold"] and p.active_food_waves_remaining == 4)
	assert(main._sell_blacksmith_goods("Wood", 3) == -1)
	assert(main._buy_blacksmith_goods("Wood", 3) == -1)
	assert(p.materials == before["materials"] and p.jimbo_stock == before["jimbo_stock"])
	main.free()

func test_atomic_success_gear_roundtrip_only_disposable_save() -> void:
	var main: GeneralStoreTempSave = preload("res://tests/general_store_temp_save.gd").new() as GeneralStoreTempSave
	var p: HomeProgression = main.home_progression
	p.add_gear_item(_gear())
	p.add_material("Coins", 1000)
	var key: String = ArmoryConfig.smith_stock_key(_gear())
	assert(main._buy_blacksmith_goods(key, 2) == 2)
	assert(p.gear_inventory.size() == 3 and p.blacksmith_stock_count(key) == 3)
	var restored: HomeProgression = HomeProgression.new()
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.temporary_path)) as Dictionary
	restored.load_save_data(saved["home_progression"] as Dictionary)
	assert(restored.gear_inventory[0]["skill_infusions"] == {"defense": 3.0})
	assert(restored.blacksmith_price("gear_1", false) == 100)
	assert(restored.gear_inventory[1]["techniques"] == {"defense": 1})
	assert(main._sell_blacksmith_goods("gear_1", 1) == 1)
	assert(p.gear_item_by_id("gear_1").is_empty() and p.material_count("Coins") == 700)
	main.free()

func test_shared_ui_tabs_trade_and_navigation() -> void:
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	var p: HomeProgression = HomeProgression.new()
	p.add_material("Wood", 3)
	p.add_material("Coins", 100)
	hub.configure_town(p, p.sell_to_kaji, p.buy_from_kaji, func(id: String, qty: int) -> int: return p.trade_with_jimbo(id, qty, false), func(id: String, qty: int) -> int: return p.trade_with_jimbo(id, qty, true))
	var menu: TownMenu = hub.town_menu
	menu.open_blacksmiths()
	assert(menu.buy_page.get_parent() == menu.blacksmith_page)
	assert(menu.buy_page.visible and not menu.sell_page.visible)
	menu._trade_selected("Wood", true)
	assert(p.material_count("Wood") == 4 and p.material_count("Coins") == 96)
	menu._select_general_page(false)
	menu._trade_selected("Wood", false)
	assert(p.material_count("Wood") == 3 and p.material_count("Coins") == 98)
	menu.open_general()
	assert(menu.buy_page.get_parent() == menu.general_page and menu.buy_page.visible)
	menu.open_blacksmiths()
	assert(menu.sell_page.visible)
	assert(menu.jimbo_portrait.size == Vector2(238, 280))
	hub.free()
