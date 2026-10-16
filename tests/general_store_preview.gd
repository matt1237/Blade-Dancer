class_name GeneralStorePreview extends Control
## Disposable, deterministic progression. Never loads or writes user saves.
var progression: HomeProgression = HomeProgression.new()
var menu: TownMenu
var hub: EndRunHub

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	progression.add_material("Coins", 180)
	progression.add_material("Forest Herb", 8)
	progression.add_material("Turkey", 7)
	progression.add_material("Mushroom", 3)
	progression.add_material("Wolf Meat", 4)
	progression.record_item_discovery(CookingConfig.WILD_TURKEY_STEW_ID)
	progression.food_inventory[CookingConfig.WILD_TURKEY_STEW_ID] = 2
	progression.kaji_gold = 120.0
	hub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	hub.configure_town(progression, progression.sell_to_kaji, progression.buy_from_kaji)
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	menu = hub.town_menu
	menu.open_general()
	menu._change_quantity("Forest Herb", false, 2)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			get_tree().paused = not get_tree().paused
			print("KAJI PREVIEW paused: ", get_tree().paused)
		elif event.keycode == KEY_E:
			var effect: ShaderMaterial = hub.shop_backdrop.painting.material as ShaderMaterial
			var enabled: bool = float(effect.get_shader_parameter("strength")) < 0.5
			effect.set_shader_parameter("strength", 1.0 if enabled else 0.0)
			print("KAJI PREVIEW effects: ", enabled)
