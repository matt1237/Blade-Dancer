extends Control
## Actual HomeMenu + EndRunHub; disposable progression only. No Main bootstrap.
## F opens Forge, J opens Jimbo. In-memory purchases use canonical authority.
var progression: HomeProgression = HomeProgression.new()
var home: HomeMenu
var hub: EndRunHub

func _ready() -> void:
	progression.forge_purchased = true
	progression.materials["Coins"] = 10000
	progression.materials["Stone"] = 120
	progression.materials["Wood"] = 25
	progression.materials["Iron Shard"] = 18
	home = preload("res://scenes/ui/home_menu.tscn").instantiate() as HomeMenu
	add_child(home)
	home.configure(progression)
	home.forge_requested.connect(func() -> void: print("FORGE PREVIEW: actual Forge Sword signal received (minigame not started in this visual rig); writes=0"))
	home.adventure_requested.connect(_show_jimbo)
	hub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	hub.configure_town(progression, progression.sell_to_kaji, progression.buy_from_kaji, Callable(), _buy)
	hub.travel_home_requested.connect(_show_forge)
	_show_forge()
	print("FORGE PREVIEW: F workshop / J Jimbo; canonical in-memory Buy buttons; no saves loaded or written")

func _buy(id: String, quantity: int) -> int:
	var result: int = progression.trade_with_jimbo(id, quantity, true)
	print("FORGE PREVIEW buy=", id, " result=", result, " slots=", progression.forge_slot_count, " recipes=", progression.owned_forge_recipes, " writes=0")
	return result

func _show_forge() -> void:
	hub.hide()
	home.configure(progression)
	home.show_tab(HomeMenu.Tab.CRAFTING)
	home.show()
	home.forge_button.pressed.emit()

func _show_jimbo() -> void:
	home.hide()
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	hub.town_menu.open_blacksmiths()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_F: _show_forge()
	elif event.keycode == KEY_J: _show_jimbo()
