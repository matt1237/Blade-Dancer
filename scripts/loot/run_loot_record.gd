class_name RunLootRecord extends RefCounted
## Observational pickup history, not inventory. Reset only at run start;
## snapshots belong to the existing run summary/scoreboard save path.

var items: Dictionary = {}
var gear: Array[Dictionary] = []

func reset() -> void:
	items.clear()
	gear.clear()

func record_item(item_id: String, quantity: int) -> void:
	if item_id.is_empty() or quantity <= 0: return
	items[item_id] = int(items.get(item_id, 0)) + quantity

func record_gear(item: Dictionary) -> void:
	var item_id: String = str(item.get("id", ""))
	if item_id.is_empty(): return
	for collected: Dictionary in gear:
		if str(collected.get("id", "")) == item_id: return
	var collected_item: Dictionary = item.duplicate(true)
	collected_item["collected_label"] = ArmoryConfig.display_label(item)
	gear.append(collected_item)

## World rewind undid a pickup: take it back out of the run history.
func unrecord_item(item_id: String, quantity: int) -> void:
	if item_id.is_empty() or quantity <= 0 or not items.has(item_id): return
	var remaining: int = int(items[item_id]) - quantity
	if remaining > 0: items[item_id] = remaining
	else: items.erase(item_id)

func unrecord_gear(item_id: String) -> void:
	for index: int in range(gear.size() - 1, -1, -1):
		if str(gear[index].get("id", "")) == item_id:
			gear.remove_at(index)

func snapshot() -> Dictionary:
	return {"items": items.duplicate(true), "gear": gear.duplicate(true)}

## Old reports deliberately say unavailable rather than claim zero pickups.
static func review_bbcode(summary: Dictionary) -> String:
	var text: String = "[font_size=22][color=#ffd94d]ITEMS GATHERED[/color][/font_size]\n"
	if not summary.has("loot"):
		return text + "[color=#9cb4cc]Pickup history unavailable for this run.[/color]\n"
	var loot: Dictionary = summary.get("loot", {}) as Dictionary
	var collected_items: Dictionary = loot.get("items", {}) as Dictionary
	var collected_gear: Array = loot.get("gear", []) as Array
	if collected_items.is_empty() and collected_gear.is_empty():
		return text + "[color=#9cb4cc]No items gathered.[/color]\n"
	var item_ids: Array = collected_items.keys()
	item_ids.sort()
	for item_id: String in item_ids:
		var label: String = CookingConfig.recipe_name(item_id) if CookingConfig.recipe_ids().has(item_id) else item_id
		text += "%s × %d\n" % [_escape(label), int(collected_items[item_id])]
	if not collected_gear.is_empty():
		text += "[color=#ffe77a]Gear[/color]\n"
		for item: Dictionary in collected_gear:
			text += "%s × 1\n" % _escape(str(item.get("collected_label", ArmoryConfig.display_label(item))))
	return text

static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
