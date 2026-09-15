class_name HomeProgressionGearTest extends Node
## Covers HomeProgression's chest-loot inventory: adding, equipping,
## unequipping, effective-rank summation, and save/load round-tripping.

func _sample_item(item_id: String, slot: String, base_name: String, techniques: Dictionary) -> Dictionary:
	return {"id": item_id, "slot": slot, "base_name": base_name, "techniques": techniques, "value": ArmoryConfig.item_value(techniques)}

func test_add_and_equip_gear() -> void:
	var progression: HomeProgression = HomeProgression.new()
	var item: Dictionary = _sample_item("gear_1", "Sword", "Basic Curved Sword", {"moon": 1})
	progression.add_gear_item(item)
	assert(progression.items_for_slot("Sword").size() == 1, "new item should show up under its slot")
	assert(progression.equip_gear("gear_1"), "equip should succeed for an owned item id")
	assert(progression.equipped_gear_ids["Sword"] == "gear_1", "equipping should record the item id in its slot")
	assert(progression.equipment["Sword"] == "Curved Sword (Moon Slash 1)", "equipment display text should stay in sync, got: %s" % progression.equipment["Sword"])
	progression.unequip_gear("Sword")
	assert(progression.equipped_gear_ids["Sword"] == "", "unequip should clear the slot")
	assert(progression.equipment["Sword"] == "Basic Longsword", "unequipping should fall back to the base item label")

func test_equip_unknown_item_fails_safely() -> void:
	var progression: HomeProgression = HomeProgression.new()
	assert(not progression.equip_gear("does_not_exist"), "equipping an unknown id should fail rather than corrupt state")
	assert(progression.equipped_gear_ids["Sword"] == "", "failed equip must not touch the slot")

func test_equipped_technique_ranks_sum_across_slots_and_caps() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.add_gear_item(_sample_item("gear_1", "Sword", "Basic Longsword", {"vampirism": 5}))
	progression.add_gear_item(_sample_item("gear_2", "Ring", "Clear Quartz Ring", {"vampirism": 5}))
	progression.equip_gear("gear_1")
	progression.equip_gear("gear_2")
	var totals: Dictionary = progression.equipped_technique_ranks()
	assert(int(totals["vampirism"]) == BonusConfig.MAX_RANK, "combined ranks from two slots must clamp at MAX_RANK, got %d" % int(totals["vampirism"]))

func test_save_and_load_round_trip() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.add_gear_item(_sample_item("gear_1", "Armor", "Basic Knight Armor", {"defense": 3}))
	progression.equip_gear("gear_1")
	var saved: Dictionary = progression.to_save_data()
	var reloaded: HomeProgression = HomeProgression.new()
	reloaded.load_save_data(saved)
	assert(reloaded.gear_inventory.size() == 1, "gear inventory should survive a save/load round trip")
	assert(reloaded.equipped_gear_ids["Armor"] == "gear_1", "equipped gear id should survive a save/load round trip")
	assert(reloaded.equipment["Armor"] == "Knight Armor (Defense 3)", "equipment display text should be rebuilt after load, got: %s" % reloaded.equipment["Armor"])

func test_load_drops_equipped_id_for_missing_item() -> void:
	var progression: HomeProgression = HomeProgression.new()
	progression.load_save_data({"equipped_gear_ids": {"Sword": "ghost_item"}, "gear_inventory": []})
	assert(progression.equipped_gear_ids["Sword"] == "", "an equipped id with no matching inventory item must not be trusted")

func test_default_armor_is_leather_not_knight() -> void:
	var progression: HomeProgression = HomeProgression.new()
	assert(progression.default_slot_label("Armor") == "Basic Leather Armor", "Basic Leather Armor (the unmodified Grim Pixel Knight look) must be the true base/default Armor item")
	assert(progression.equipped_item_label("Armor") == "Basic Leather Armor", "with nothing equipped, the Armor slot should display the Leather Armor default")
	assert(ArmoryConfig.SLOT_ITEM_POOL["Armor"].has("Basic Leather Armor"), "Basic Leather Armor must still be a valid chest-droppable Armor slot item")
	assert(ArmoryConfig.SLOT_ITEM_POOL["Armor"].has("Basic Knight Armor"), "Basic Knight Armor must remain a valid chest-droppable Armor slot item")
