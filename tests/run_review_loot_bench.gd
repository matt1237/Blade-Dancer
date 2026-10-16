class_name RunReviewLootBench extends Control
## Real EndRunHub + canonical formatter, deterministic report only. Never
## instances gameplay, loads saves, grants inventory, or writes user://.

@onready var hub: EndRunHub = $EndRunHub

func _ready() -> void:
	var record: RunLootRecord = RunLootRecord.new()
	for item_id: String in ["Coins", "Stone", "Wood", "Forest Herb", "Iron Shard", "Moon Petal", "Mushroom", "Turkey", "Wolf Meat"]:
		record.record_item(item_id, 12 if item_id == "Coins" else 3)
	record.record_item(CookingConfig.WOLF_JERKY_ID, 2)
	record.record_gear({"id": "bench_gear_1", "slot": "Sword", "base_name": "Basic Curved Sword", "techniques": {"defense": 1}, "value": 100})
	record.record_gear({"id": "bench_gear_2", "slot": "Armor", "base_name": "Basic Knight Armor", "techniques": {"health": 2}, "value": 200})
	record.record_gear({"id": "bench_gear_3", "slot": "Sword", "base_name": "Basic Curved Sword", "techniques": {"defense": 1}, "value": 100})
	var formatter: Main = Main.new()
	formatter.last_run_summary = {"score": 2400, "wave": 5, "duration": 185.0, "damage_dealt": 3200.0, "damage_received": 45.0, "bonuses": ["Defense", "Health"], "loot": record.snapshot()}
	hub.open_to_run_review(formatter._run_review_bbcode(), "SCOREBOARD — THE FOREST\n\nDeterministic review bench (no save access).")
	formatter.free()
	await get_tree().process_frame
	assert(hub.run_review.scroll_active)
	assert(hub.run_review.get_content_height() > hub.run_review.size.y)
	# Frame the new section, leaving real hub navigation and scrolling intact.
	hub.run_review.scroll_to_line(13)
	print("[RUN REVIEW BENCH] Canonical hub, 10 goods + 3 unique gear pickups; no save access.")
	await get_tree().create_timer(2.0).timeout
	hub.run_review.scroll_to_line(hub.run_review.get_line_count() - 1)
	print("[RUN REVIEW BENCH] Scrolled to final gear row.")
