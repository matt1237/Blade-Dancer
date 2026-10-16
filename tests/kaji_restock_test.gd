class_name KajiRestockTest extends Node

func _depleted() -> HomeProgression:
	var p: HomeProgression = HomeProgression.new()
	p.record_item_discovery("Turkey")
	p.record_item_discovery("Mushroom")
	p.add_material("Coins", 1000)
	p.update_kaji(1000.25)
	assert(p.buy_from_kaji("Turkey", 5, 1000.25) == 5)
	return p

func test_partial_forty_minutes_hour_and_four_hours() -> void:
	var p: HomeProgression = _depleted()
	p.update_kaji(2200.25)
	assert(p.general_stock_count("Turkey") == 0)
	assert(p.kaji_stock_elapsed["Turkey"] == 1200.0)
	p.update_kaji(3399.75)
	assert(p.general_stock_count("Turkey") == 0)
	p.update_kaji(3400.25)
	assert(p.general_stock_count("Turkey") == 1)
	p.update_kaji(4600.25)
	assert(p.general_stock_count("Turkey") == 1 and p.kaji_stock_elapsed["Turkey"] == 1200.0)
	p.update_kaji(15400.25)
	assert(p.general_stock_count("Turkey") == 5 and p.kaji_stock_elapsed["Turkey"] == 0.0)
	assert(p.general_stock_count("Mushroom") == 5)
	assert(p.kaji_stock_elapsed["Mushroom"] == 0.0)

func test_offline_json_fraction_exact_and_repeated_access() -> void:
	var p: HomeProgression = _depleted()
	p.update_kaji(2200.75)
	var data: Dictionary = JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(data)
	assert(restored.kaji_updated_at_unix == 2200.75)
	assert(restored.kaji_stock_elapsed["Turkey"] == 1200.5)
	restored.update_kaji(3400.25)
	assert(restored.general_stock_count("Turkey") == 1)
	for visit: int in range(10):
		restored.update_kaji(3400.25)
		assert(restored.general_stock_count("Turkey") == 1)
		assert(restored.kaji_stock_elapsed["Turkey"] == 0.0)
	restored.update_kaji(15400.25)
	assert(restored.general_stock_count("Turkey") == 5)

func test_per_item_saturation_no_bank_and_purchase_conservation() -> void:
	var p: HomeProgression = _depleted()
	p.kaji_gold = 0.0
	p.update_kaji(4600.25)
	assert(p.general_stock_count("Turkey") == 1)
	assert(p.buy_from_kaji("Mushroom", 5, 4600.25) == 5)
	assert(p.kaji_stock_elapsed["Mushroom"] == 0.0)
	p.update_kaji(5800.25)
	assert(p.general_stock_count("Turkey") == 2)
	assert(p.general_stock_count("Mushroom") == 0)
	p.update_kaji(100000.25)
	assert(p.general_stock_count("Turkey") == 5)
	var coins: int = p.material_count("Coins")
	var owned: int = p.material_count("Turkey")
	assert(p.buy_from_kaji("Turkey", 5, 100000.25) == 5)
	assert(p.material_count("Coins") == coins - 40)
	assert(p.material_count("Turkey") == owned + 5)
	p.update_kaji(100000.25)
	p.record_item_discovery("Turkey")
	assert(p.general_stock_count("Turkey") == 0 and p.kaji_stock_elapsed["Turkey"] == 0.0)
	p.update_kaji(102399.25)
	assert(p.general_stock_count("Turkey") == 0)
	p.update_kaji(102400.25)
	assert(p.buy_from_kaji("Turkey", 99, 102400.25) == 1)
	assert(p.general_stock_count("Turkey") == 0)

func test_old_save_no_retroactive_stock_and_filters() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.load_save_data({"kaji_updated_at_unix": 1.0, "kaji_gold": 0.0, "discovered_items": {"Turkey": true, "Moon Petal": true}, "kaji_stock": {"Turkey": 0, "Moon Petal": 0, "Mushroom": 0}})
	p.update_kaji(100000.5)
	assert(p.general_stock_count("Turkey") == 0)
	assert(p.kaji_stock_elapsed["Turkey"] == 0.0)
	assert(p.kaji_gold == 500.0, "Existing purse still receives its elapsed time")
	assert(not p.kaji_stock.has("Mushroom") and not p.kaji_stock.has("Moon Petal"))
	p.update_kaji(102400.5)
	assert(p.general_stock_count("Turkey") == 1)

func test_clock_rollback_purchase_no_duplicate_future_elapsed() -> void:
	var p: HomeProgression = _depleted()
	p.update_kaji(4600.25)
	assert(p.buy_from_kaji("Turkey", 1, 2000.25) == 1)
	p.update_kaji(1000.25)
	p.update_kaji(4600.25)
	assert(p.general_stock_count("Turkey") == 0)
	assert(p.kaji_updated_at_unix == 4600.25 and p.kaji_stock_elapsed["Turkey"] == 1200.0)
	p.update_kaji(5800.25)
	assert(p.general_stock_count("Turkey") == 1)

func test_atomic_failure_restores_elapsed_stock_clock_and_buff() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	main.home_progression = _depleted()
	# Future high-water makes deterministic rollback checks independent of wall time.
	main.home_progression.kaji_updated_at_unix = Time.get_unix_time_from_system() + 10000.25
	main.home_progression.kaji_stock["Turkey"] = 2
	main.home_progression.kaji_stock_elapsed["Turkey"] = 1234.5
	main.home_progression.active_food_id = CookingConfig.WILD_TURKEY_STEW_ID
	main.home_progression.active_food_waves_remaining = 4
	var before: Dictionary = main.home_progression.to_save_data()
	assert(main._buy_general_goods("Turkey", 2) == -1)
	assert(main.home_progression.to_save_data() == before)
	assert(main.home_progression.active_food_waves_remaining == 4)
	assert(main._sell_general_goods("Turkey", 1) == -1)
	assert(main.home_progression.to_save_data() == before)
	main.free()

func test_menu_open_and_refresh_replenish_without_reseeding() -> void:
	var p: HomeProgression = _depleted()
	p.kaji_updated_at_unix = Time.get_unix_time_from_system() - 2400.0
	var menu: TownMenu = TownMenu.new()
	menu.progression = p
	menu.buy_callback = func(_id: String, _quantity: int) -> int: return 0
	add_child(menu)
	menu.open_general()
	assert(p.general_stock_count("Turkey") == 1)
	assert(menu._quantity_limit("Turkey", true) == 1)
	menu.open_town()
	menu.open_general()
	assert(p.general_stock_count("Turkey") == 1)
	p.kaji_updated_at_unix -= 2400.0
	menu.refresh_wait = 0.0
	menu._process(1.0)
	assert(p.general_stock_count("Turkey") == 2)
	assert(menu.inventory_view["stock"]["Turkey"] == 2)
	menu.free()

func test_atomic_writer_roundtrip_elapsed_only_disposable_save() -> void:
	var main: GeneralStoreTempSave = preload("res://tests/general_store_temp_save.gd").new() as GeneralStoreTempSave
	main.home_progression = _depleted()
	main.home_progression.kaji_stock_elapsed["Turkey"] = 1234.5
	main.home_progression.kaji_updated_at_unix = Time.get_unix_time_from_system() + 10000.25
	assert(main.save_game())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.temporary_path)) as Dictionary
	var restored: HomeProgression = HomeProgression.new()
	restored.load_save_data(data["home_progression"] as Dictionary)
	assert(restored.kaji_updated_at_unix == main.home_progression.kaji_updated_at_unix)
	assert(restored.kaji_stock_elapsed == main.home_progression.kaji_stock_elapsed)
	main.free()
