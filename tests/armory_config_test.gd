class_name ArmoryConfigTest extends Node
## Covers the chest-item roll rules in res://scripts/home/armory_config.gd:
## technique-roll count by wave, value calc, and the per-item rank cap.

func test_roll_count_by_wave() -> void:
	assert(ArmoryConfig.technique_roll_count(1) == 1, "waves 1-9 roll once")
	assert(ArmoryConfig.technique_roll_count(9) == 1, "wave 9 still rolls once")
	assert(ArmoryConfig.technique_roll_count(10) == 2, "wave 10 starts rolling twice")
	assert(ArmoryConfig.technique_roll_count(19) == 2, "wave 19 still rolls twice")
	assert(ArmoryConfig.technique_roll_count(20) == 3, "wave 20 starts rolling three times")

func test_item_value_is_100_per_rank() -> void:
	assert(ArmoryConfig.item_value({"moon": 2}) == 200, "two ranks on one technique is 200 coins")
	assert(ArmoryConfig.item_value({"moon": 1, "vampirism": 1}) == 200, "two ranks split across techniques is still 200 coins")
	assert(ArmoryConfig.item_value({}) == 0, "no techniques is worth nothing")

func test_roll_item_respects_rank_cap_and_pools() -> void:
	# A very high wave rolls many techniques onto one item; none should ever
	# exceed BonusConfig.MAX_RANK, and the slot/base name must be consistent.
	for _attempt: int in range(10):
		var item: Dictionary = ArmoryConfig.roll_item(500, "test_item")
		var techniques: Dictionary = item["techniques"]
		for bonus_id: String in techniques.keys():
			assert(int(techniques[bonus_id]) <= BonusConfig.MAX_RANK, "%s exceeded MAX_RANK" % bonus_id)
		assert(int(item["value"]) == ArmoryConfig.item_value(techniques), "value must match the techniques rolled")
		assert(ArmoryConfig.GEAR_SLOTS.has(item["slot"]), "rolled slot must be a real gear slot")
		assert((ArmoryConfig.SLOT_ITEM_POOL[item["slot"]] as Array).has(item["base_name"]), "rolled base name must belong to its slot's pool")

func test_display_label_formats_techniques() -> void:
	var label: String = ArmoryConfig.display_label({"base_name": "Basic Curved Sword", "techniques": {"regen": 1, "vampirism": 1}})
	assert(label == "Curved Sword (Regeneration 1, Vampirism 1)", "display label should list techniques alphabetically by id, got: %s" % label)
	var base_label: String = ArmoryConfig.display_label({"base_name": "Basic Longsword", "techniques": {}})
	assert(base_label == "Longsword", "an item with no techniques just shows its short name, got: %s" % base_label)
