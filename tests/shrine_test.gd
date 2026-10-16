extends Node

func _gear(id: String = "gear_1", ranks: Dictionary = {"chakram": 2, "defense": 3}) -> Dictionary:
	return {"id": id, "origin": "found", "slot": "Chakram", "base_name": "Steel Chakram", "techniques": ranks.duplicate(true)}

func test_knowledge_thresholds_permanent_ranks_and_caps() -> void:
	var p: HomeProgression = HomeProgression.new()
	assert(HomeProgression.knowledge_threshold(1) == 20)
	assert(HomeProgression.knowledge_threshold(2) == 50)
	assert(HomeProgression.knowledge_threshold(3) == 90)
	assert(HomeProgression.knowledge_threshold(4) == 140)
	for rank: int in range(1, BonusConfig.MAX_RANK + 1):
		p.skill_knowledge["chakram"] = HomeProgression.knowledge_threshold(rank) - 1
		assert(p.learned_skill_rank("chakram") == rank - 1)
		p.skill_knowledge["chakram"] += 1
		assert(p.learned_skill_rank("chakram") == rank)
	p.skill_knowledge["chakram"] = HomeProgression.SHRINE_INT_MAX
	assert(p.learned_skill_rank("chakram") == BonusConfig.MAX_RANK)
	assert(p.learned_skill_rank("unknown") == 0)

func test_exchange_available_only_no_arbitrary_cap_and_overflow() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.materials["Coins"] = 1000000000
	assert(p.exchange_shrine_coins(1000000000) == 1000000000)
	assert(p.material_count("Coins") == 0 and p.resonance == 1000000000)
	assert(p.exchange_shrine_coins(-1) == 0)
	p.materials["Coins"] = 20
	p.resonance = HomeProgression.SHRINE_INT_MAX - 5
	assert(p.exchange_shrine_coins(10) == 5)
	assert(p.resonance == HomeProgression.SHRINE_INT_MAX and p.material_count("Coins") == 15)
	assert(p.exchange_shrine_coins(1) == 0)
	assert(ShrineMenu.parse_amount("9223372036854775807") == HomeProgression.SHRINE_INT_MAX)
	for invalid: String in ["9223372036854775808", "1.5", "-2", "1e3", "", "abc"]:
		assert(ShrineMenu.parse_amount(invalid) == 0)

func test_salvage_exact_all_skills_consumed_not_equipped_or_player_made() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.add_gear_item(_gear())
	assert(p.shrine_salvage_gains("gear_1") == {"chakram": 2, "defense": 3})
	p.equip_gear("gear_1")
	assert(p.salvage_shrine_gear("gear_1") == 0)
	p.unequip_gear("Chakram")
	for origin: String in ["forged", "skill", "starter", "unknown"]:
		p.gear_inventory[0]["origin"] = origin
		assert(p.salvage_shrine_gear("gear_1") == 0)
	p.gear_inventory[0]["origin"] = "found"
	p.gear_inventory[0]["skill_infusions"] = {"chakram": 1}
	assert(p.salvage_shrine_gear("gear_1") == 0)
	p.gear_inventory[0].erase("skill_infusions")
	p.skill_knowledge["chakram"] = 18
	p.resonance = 99
	assert(p.salvage_shrine_gear("gear_1") == 1)
	assert(p.gear_inventory.is_empty() and p.skill_knowledge == {"chakram": 20, "defense": 3})
	assert(p.learned_skill_rank("chakram") == 1 and p.resonance == 99)
	assert(p.salvage_shrine_gear("gear_1") == 0)
	var ring: Dictionary = _gear("ring", {"health": 1})
	ring["slot"] = "Ring"
	ring["base_name"] = "Clear Quartz Ring"
	p.add_gear_item(ring)
	assert(p.salvage_shrine_gear("ring") == 1)
	assert(p.skill_knowledge["health"] == 1)

func test_legacy_unknown_invalid_duplicate_blank_and_overflow_protection() -> void:
	var p: HomeProgression = HomeProgression.new()
	var legacy: Dictionary = _gear("legacy")
	legacy.erase("origin")
	p.load_save_data({"gear_inventory": [legacy]})
	assert(p.shrine_salvage_gains("legacy") == {"chakram": 2, "defense": 3})
	for ranks: Dictionary in [{}, {"unknown": 2}, {"chakram": -1}, {"chakram": 8}, {"chakram": 1.5}]:
		p.gear_inventory = [_gear("invalid", ranks)]
		assert(p.salvage_shrine_gear("invalid") == 0)
		p.load_save_data({"gear_inventory": [_gear("invalid", ranks)]})
		assert(p.salvage_shrine_gear("invalid") == 0, "Normalization must not make invalid gear farmable")
	p.gear_inventory = [_gear(), _gear()]
	assert(p.salvage_shrine_gear("gear_1") == 0)
	p.gear_inventory = [_gear()]
	p.skill_knowledge["defense"] = HomeProgression.SHRINE_INT_MAX
	assert(p.salvage_shrine_gear("gear_1") == 0)
	assert(not p.gear_inventory.is_empty() and not p.skill_knowledge.has("chakram"))

func test_schema_defaults_sanitize_and_json_roundtrip() -> void:
	var p: HomeProgression = HomeProgression.new()
	p.load_save_data({"resonance": -5, "skill_knowledge": {"unknown": 90, "chakram": -1, "defense": "invalid", "regen": 90.9}})
	assert(p.resonance == 0 and p.skill_knowledge == {"regen": 90})
	p.resonance = 125
	p.skill_knowledge["chakram"] = 50
	var q: HomeProgression = HomeProgression.new()
	q.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	assert(q.resonance == 125 and q.learned_skill_rank("chakram") == 2)
	p.resonance = HomeProgression.SHRINE_INT_MAX - 5
	p.skill_knowledge["chakram"] = HomeProgression.SHRINE_INT_MAX - 7
	q.load_save_data(JSON.parse_string(JSON.stringify(p.to_save_data())) as Dictionary)
	assert(q.resonance == p.resonance and q.skill_knowledge["chakram"] == p.skill_knowledge["chakram"])
	q.load_save_data({})
	assert(q.resonance == 0 and q.skill_knowledge.is_empty())
	q.load_save_data({"resonance": INF, "skill_knowledge": [1, 2]})
	assert(q.resonance == 0 and q.skill_knowledge.is_empty())

func test_main_atomic_failure_restores_all_trade_fields_without_buff_loss() -> void:
	var main: Main = preload("res://tests/general_store_save_failure.gd").new() as Main
	var p: HomeProgression = main.home_progression
	p.add_material("Coins", 150)
	p.add_gear_item(_gear())
	p.skill_knowledge["chakram"] = 18
	p.active_food_waves_remaining = 4
	p.update_kaji()
	p.update_jimbo()
	var before: Dictionary = p.to_save_data()
	assert(main._exchange_shrine_coins(100) == -1)
	assert(p.materials == before["materials"] and p.resonance == 0)
	assert(main._salvage_shrine_gear("gear_1") == -1)
	for key: String in ["gear_inventory", "next_gear_item_id", "skill_knowledge", "resonance", "discovered_items", "equipment", "equipped_gear_ids", "jimbo_stock", "kaji_stock"]:
		assert(p.get(key) == before[key], key)
	assert(p.active_food_waves_remaining == 4)
	main.free()

func test_real_writer_parameter_path_failure_restores_merchant_clocks_and_counters() -> void:
	var main: Main = preload("res://tests/shrine_save_failure.gd").new() as Main
	var p: HomeProgression = main.home_progression
	p.add_material("Coins", 150)
	p.add_gear_item(_gear())
	p.kaji_updated_at_unix = 1000
	p.jimbo_updated_at_unix = 1000
	p.kaji_gold = 12.5
	p.jimbo_gold = 22.5
	main.last_saved_at_unix = 1234
	var before: Dictionary = p.to_save_data()
	assert(main._exchange_shrine_coins(125) == -1)
	assert(p.to_save_data() == before and main.last_saved_at_unix == 1234)
	assert(main._salvage_shrine_gear("gear_1") == -1)
	assert(p.to_save_data() == before and main.last_saved_at_unix == 1234)
	main.free()

func test_main_atomic_success_disposable_save_roundtrip() -> void:
	var main: GeneralStoreTempSave = preload("res://tests/general_store_temp_save.gd").new() as GeneralStoreTempSave
	var p: HomeProgression = main.home_progression
	p.add_material("Coins", 250)
	p.add_gear_item(_gear())
	assert(main._exchange_shrine_coins(125) == 125)
	assert(main._salvage_shrine_gear("gear_1") == 1)
	var q: HomeProgression = HomeProgression.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(main.temporary_path)) as Dictionary
	q.load_save_data(data["home_progression"])
	assert(q.resonance == 125 and q.material_count("Coins") == 125)
	assert(q.gear_inventory.is_empty() and q.skill_knowledge == {"chakram": 2, "defense": 3})
	main.free()

func test_real_hub_preview_confirmation_revalidation_and_navigation() -> void:
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	var p: HomeProgression = HomeProgression.new()
	p.add_material("Coins", 100)
	p.add_gear_item(_gear())
	hub.configure_town(p, p.sell_to_kaji, p.buy_from_kaji, Callable(), Callable(), p.exchange_shrine_coins, p.salvage_shrine_gear)
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	hub.town_menu.open_shrine()
	var menu: ShrineMenu = hub.town_menu.shrine_page
	assert(hub.town_menu.shrine_is_open())
	assert(hub.shrine_backdrop.texture == EndRunHub.SHRINE_PAINTING and hub.shrine_backdrop.material == null)
	menu.amount_input.text = "75"
	menu._preview_exchange()
	assert(p.resonance == 0)
	menu._commit()
	assert(p.resonance == 75 and p.material_count("Coins") == 25)
	menu.select_page("Salvage")
	menu._preview_salvage("gear_1")
	assert(p.gear_inventory.size() == 1)
	p.equip_gear("gear_1")
	menu._commit()
	assert(p.gear_inventory.size() == 1 and p.skill_knowledge.is_empty())
	p.unequip_gear("Chakram")
	menu._preview_salvage("gear_1")
	p.gear_inventory[0]["techniques"]["chakram"] = 3
	menu._commit()
	assert(p.gear_inventory.size() == 1)
	menu._preview_salvage("gear_1")
	menu._commit()
	assert(p.gear_inventory.is_empty() and p.skill_knowledge["chakram"] == 3)
	menu.select_page("Infuse")
	assert(p.resonance == 75)
	hub.town_menu.open_town()
	assert(not hub.shrine_backdrop.visible and not hub.town_menu.shrine_is_open())
	hub.free()
