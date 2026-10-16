class_name BlacksmithStorePreview extends Control
## Disposable visual preview; no user progression or save paths are loaded.

var progression: HomeProgression = HomeProgression.new()
var hub: EndRunHub
var blacksmith_backdrop: BlacksmithStoreBackdrop

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	progression.add_material("Coins", 1200)
	for supply: String in ["Wood", "Stone", "Iron Shard"]: progression.add_material(supply, 12)
	progression.add_gear_item({"id": progression.generate_gear_id(), "slot": "Sword", "base_name": "Basic Curved Sword", "origin": "found", "techniques": {"defense": 1}, "base_techniques": {"defense": 1}})
	progression.add_gear_item({"id": progression.generate_gear_id(), "slot": "Armor", "base_name": "Basic Knight Armor", "origin": "forged", "techniques": {"health": 2}, "base_techniques": {"health": 2}})
	hub.configure_town(progression, progression.sell_to_kaji, progression.buy_from_kaji, _sell, _buy)
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	hub.town_menu.open_blacksmiths()
	blacksmith_backdrop = hub.blacksmith_backdrop
	print("BLACKSMITH PREVIEW: original painted sign + workshop lights + birds + localized forge dust/embers; P pause / E ambience toggle / C bird now; in-memory Buy/Sell (no save writes)")

func _sell(item_id: String, quantity: int) -> int:
	return progression.trade_with_jimbo(item_id, quantity, false)

func _buy(item_id: String, quantity: int) -> int:
	return progression.trade_with_jimbo(item_id, quantity, true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event.keycode == KEY_P:
		get_tree().paused = not get_tree().paused
		print("BLACKSMITH PREVIEW paused: ", get_tree().paused)
	elif key_event.keycode == KEY_E:
		blacksmith_backdrop.set_ambient_enabled(not blacksmith_backdrop.ambient_enabled)
		print("BLACKSMITH PREVIEW ambient: ", blacksmith_backdrop.ambient_enabled)
	elif key_event.keycode == KEY_C:
		blacksmith_backdrop.bird_wait = 0.0
		blacksmith_backdrop.bird_test_override = true
		blacksmith_backdrop.bird_duration = 1000.0
		blacksmith_backdrop.advance_ambient(0.01)
		print("BLACKSMITH PREVIEW bird passage requested")
