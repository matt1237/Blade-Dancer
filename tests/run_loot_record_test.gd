class_name RunLootRecordTest extends Node

# No test instances Main's scene or reads/writes the player's save.
class NoSaveMain extends Main:
	var save_calls: int = 0
	func save_game(_path: String = SAVE_PATH) -> bool:
		save_calls += 1
		return true

class QuietFeed extends PickupFeed:
	func show_pickup(_item_name: String, _quantity: int, _rarity: ItemConfig.Rarity) -> void:
		pass

class QuietPlayer extends Player:
	func reset_run_bonuses() -> void:
		pass

func _gear(item_id: String) -> Dictionary:
	return {"id": item_id, "slot": "Sword", "base_name": "Basic Curved Sword", "techniques": {"defense": 1}, "value": 100}

func test_quantities_reset_and_snapshot_isolation() -> void:
	var record: RunLootRecord = RunLootRecord.new()
	record.record_item("Wood", 2)
	record.record_item("Wood", 3)
	record.record_item("Coins", 12)
	record.record_item(CookingConfig.WOLF_JERKY_ID, 2)
	record.record_item("Other Goods", 1)
	record.record_item("Wood", 0)
	record.record_item("Wood", -3)
	var report: Dictionary = {"loot": record.snapshot()}
	assert(report["loot"]["items"]["Wood"] == 5)
	record.reset()
	assert(record.items.is_empty() and record.gear.is_empty())
	assert(report["loot"]["items"]["Wood"] == 5)
	record.record_item("Stone", 1)
	assert(not record.items.has("Wood"))
	var text: String = RunLootRecord.review_bbcode(report)
	assert(text.contains("Wood × 5") and text.contains("Coins × 12"))
	assert(text.contains(CookingConfig.recipe_name(CookingConfig.WOLF_JERKY_ID)))
	assert(text.contains("Other Goods × 1"))

func test_gear_identity_snapshot_and_json_report_roundtrip() -> void:
	var record: RunLootRecord = RunLootRecord.new()
	var first: Dictionary = _gear("gear_1")
	record.record_gear(first)
	record.record_gear(first)
	record.record_gear(_gear("gear_2"))
	assert(record.gear.size() == 2, "Same name is not same identity; a replay is not another find")
	first["base_name"] = "Changed"
	first["techniques"]["defense"] = 9
	first.clear()
	var summary: Dictionary = {"score": 25, "loot": record.snapshot()}
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify({"The Forest": [summary]})) as Dictionary
	var restored: Dictionary = roundtrip["The Forest"][0]
	assert(restored["loot"]["gear"][0]["id"] == "gear_1")
	assert(restored["loot"]["gear"][1]["id"] == "gear_2")
	assert(restored["loot"]["gear"][0]["techniques"]["defense"] == 1)
	var text: String = RunLootRecord.review_bbcode(restored)
	assert(text.count("Curved Sword") == 2 and not text.contains("Changed"))

func test_empty_legacy_and_safe_labels() -> void:
	assert(RunLootRecord.review_bbcode({}).contains("unavailable"))
	assert(RunLootRecord.review_bbcode({"loot": RunLootRecord.new().snapshot()}).contains("No items gathered"))
	var record: RunLootRecord = RunLootRecord.new()
	record.record_item("[b]Goods", 1)
	assert(RunLootRecord.review_bbcode({"loot": record.snapshot()}).contains("[lb]b]Goods"))

func test_canonical_pickups_report_once_and_ignore_inventory_changes() -> void:
	var main: NoSaveMain = NoSaveMain.new()
	main.pickup_feed = QuietFeed.new()
	main.player = QuietPlayer.new()
	main.spawner = WaveSpawner.new()
	main.score_label = Label.new()
	for child: Node in [main.pickup_feed, main.player, main.spawner, main.score_label]:
		main.add_child(child)
	main.run_over = false
	main.collect_drop("Wood", 2)
	main.collect_drop("Wood", 4)
	main.collect_drop("Coins", 9)
	main.collect_gear_drop(_gear("gear_5"))
	# Consumption, sale/removal and direct storage/crafting/trade changes are
	# NOT acquisitions. The report must neither subtract nor count them.
	main.home_progression.materials["Wood"] = 0
	main.home_progression.gear_inventory.clear()
	main.home_progression.add_material("Stone", 40)
	main.home_progression.food_inventory[CookingConfig.WOLF_JERKY_ID] = 3
	main.spawner.current_wave = 3
	main.score = 100
	main._record_and_reset_run()
	assert(main.last_run_summary["loot"]["items"]["Wood"] == 6)
	assert(not main.last_run_summary["loot"]["items"].has("Stone"))
	assert(main.last_run_summary["loot"]["gear"].size() == 1)
	assert(main._run_review_bbcode().contains("Curved Sword"))
	var calls: int = main.save_calls
	main._record_and_reset_run()
	main._finish_run(true)
	main._finish_run(false)
	assert(main.save_calls == calls and main.scoreboards["The Forest"].size() == 1)
	main.collect_drop("Wood", 7)
	assert(main.run_loot.items["Wood"] == 6, "Closed run pickups must not alter history")
	main.run_loot.reset()
	assert(main.last_run_summary["loot"]["items"]["Wood"] == 6)
	var saved_scores: Dictionary = JSON.parse_string(JSON.stringify(main.scoreboards)) as Dictionary
	assert(saved_scores["The Forest"][0]["loot"]["gear"][0]["id"] == "gear_5")
	main.free()

func test_both_canonical_start_paths_reset_loot_not_wave_transitions() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var arena_start: String = source.get_slice("func _start_arena_run", 1).get_slice("\nfunc ", 0)
	var backyard_start: String = source.get_slice("func _start_backyard_run", 1).get_slice("\nfunc ", 0)
	assert(arena_start.contains("run_loot.reset()"))
	assert(backyard_start.contains("run_loot.reset()"))
	assert(source.count("run_loot.reset()") == 2, "No checkpoint/wave/return reset")

func test_real_hub_navigation_scrolling_and_reopen() -> void:
	var hub: EndRunHub = (load("res://scenes/ui/end_run_hub.tscn") as PackedScene).instantiate() as EndRunHub
	add_child(hub)
	var record: RunLootRecord = RunLootRecord.new()
	for index: int in range(30):
		record.record_gear(_gear("ui_gear_%d" % index))
	var formatter: Main = Main.new()
	formatter.last_run_summary = {"loot": record.snapshot()}
	var review: String = formatter._run_review_bbcode()
	hub.open_to_run_review(review, "Scoreboard")
	await get_tree().process_frame
	assert(hub.run_review.scroll_active)
	assert(hub.run_review.get_content_height() > hub.run_review.size.y)
	assert(hub.run_review.get_parsed_text().count("Curved Sword") == 30)
	hub.run_review.scroll_to_line(hub.run_review.get_line_count() - 1)
	assert(hub.run_review.get_v_scroll_bar().value > 0)
	hub.show_tab(EndRunHub.Tab.SCOREBOARD)
	assert(hub.scoreboard.visible and not hub.run_review.visible)
	hub.show_tab(EndRunHub.Tab.RUN_REVIEW)
	assert(hub.run_review.visible)
	hub.open_to_run_review(review, "Scoreboard")
	assert(hub.run_review.get_v_scroll_bar().value == 0)
	assert(hub.active_tab == EndRunHub.Tab.RUN_REVIEW)
	formatter.free()
	hub.free()

