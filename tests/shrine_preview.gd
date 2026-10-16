extends Control
## Real hub, disposable progression only. No Main startup/load/save.
var progression: HomeProgression = HomeProgression.new()
var hub: EndRunHub
func _ready() -> void:
	progression.add_material("Coins", 250)
	progression.skill_knowledge = {"chakram": 18, "defense": 48, "regen": 89}
	progression.add_gear_item({"id": "gear_1", "origin": "found", "slot": "Chakram", "base_name": "Steel Chakram", "techniques": {"chakram": 2, "defense": 2}})
	progression.add_gear_item({"id": "gear_2", "origin": "found", "slot": "Ring", "base_name": "Clear Quartz Ring", "techniques": {"regen": 1}})
	hub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	add_child(hub)
	hub.configure_town(progression, progression.sell_to_kaji, progression.buy_from_kaji, Callable(), Callable(), _exchange, _salvage)
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	hub.town_menu.open_shrine()
func _exchange(amount: int) -> int:
	var result: int = progression.exchange_shrine_coins(amount)
	print("SHRINE PREVIEW exchange=", result, " Coins=", progression.material_count("Coins"), " Resonance=", progression.resonance, " writes=0")
	return result
func _salvage(id: String) -> int:
	var result: int = progression.salvage_shrine_gear(id)
	print("SHRINE PREVIEW salvage=", result, " id=", id, " knowledge=", progression.skill_knowledge, " writes=0")
	return result
