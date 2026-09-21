class_name HomeProgression extends RefCounted

const MATERIAL_NAMES: Array[String] = ["Coins", "Stone", "Wood", "Forest Herb", "Iron Shard", "Moon Petal", CookingConfig.MUSHROOM_MATERIAL, CookingConfig.TURKEY_MATERIAL, CookingConfig.WOLF_MEAT_MATERIAL]
const EQUIPMENT_SLOT_NAMES: Array[String] = ["Sword", "Chakram", "Armor", "Ring", "Food"]

var materials: Dictionary = {}
var food_inventory: Dictionary = {CookingConfig.WILD_TURKEY_STEW_ID: 0, CookingConfig.WOLF_JERKY_ID: 0}
var equipment: Dictionary = {
	"Sword": "Dancer's Blade",
	"Chakram": "Steel Chakram",
	"Armor": "Travel Leathers",
	"Ring": "Empty",
	"Food": "None",
}
## Chest-dropped gear. See res://scripts/home/armory_config.gd for the roll
## rules and res://scripts/ui/home_menu.gd (Armory tab) for the browsing UI.
var gear_inventory: Array[Dictionary] = []
var equipped_gear_ids: Dictionary = {"Armor": "", "Chakram": "", "Sword": "", "Ring": ""}
var next_gear_item_id: int = 0
var prepared_food_id: String = ""
var active_food_id: String = ""
var active_food_waves_remaining: int = 0
## Unlocks the next Forest destination after defeating Zungar.
var mines_unlocked: bool = false
## The Blacksmith progression is deliberately gated and data-driven. These are
## false by default; future mine/rescue/shop flows should advance them through
## the methods below rather than unlocking the Forge directly.
var mines_wave_10_cleared: bool = false
var blacksmith_rescued: bool = false
var forge_purchased: bool = false
## One initial Grandma cooking slot. Unix timestamps allow offline completion.
var crafting_recipe_id: String = ""
var crafting_started_at_unix: float = 0.0
var crafting_completes_at_unix: float = 0.0
## One cooking slot may hold one meal stack; Cauldron Catch can make it two servings.
var crafting_servings: int = 1
var cooking_bonus_pending: bool = false
## Grandpa's first chore quest begins after the cooking tutorial.
var grandpa_chores_active: bool = false
var grandpa_stone_gathered: int = 0
var grandpa_wood_gathered: int = 0
var grandpa_wolves_defeated: int = 0
var grandpa_goblins_defeated: int = 0

func _init() -> void:
	for material_name: String in MATERIAL_NAMES: materials[material_name] = 0
	_sync_equipment_display()

func material_count(material_name: String) -> int:
	return maxi(0, int(materials.get(material_name, 0)))

func add_material(material_name: String, quantity: int) -> void:
	if quantity <= 0: return
	materials[material_name] = material_count(material_name) + quantity
	if not grandpa_chores_active: return
	if material_name == "Stone": grandpa_stone_gathered = mini(20, grandpa_stone_gathered + quantity)
	if material_name == "Wood": grandpa_wood_gathered = mini(20, grandpa_wood_gathered + quantity)

func begin_grandpa_chores() -> void:
	grandpa_chores_active = true

func record_grandpa_enemy_defeat(enemy_identity: StringName) -> void:
	if not grandpa_chores_active: return
	if enemy_identity == &"wolf": grandpa_wolves_defeated = mini(3, grandpa_wolves_defeated + 1)
	if enemy_identity == &"goblin": grandpa_goblins_defeated = mini(3, grandpa_goblins_defeated + 1)

func grandpa_chores_complete() -> bool:
	return grandpa_chores_active and grandpa_stone_gathered >= 20 and grandpa_wood_gathered >= 20 and grandpa_wolves_defeated >= 3 and grandpa_goblins_defeated >= 3

func generate_gear_id() -> String:
	next_gear_item_id += 1
	return "gear_%d" % next_gear_item_id

func add_gear_item(item: Dictionary) -> void:
	gear_inventory.append(item)

func gear_item_by_id(item_id: String) -> Dictionary:
	for item: Dictionary in gear_inventory:
		if str(item.get("id", "")) == item_id: return item
	return {}

func items_for_slot(slot: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for item: Dictionary in gear_inventory:
		if str(item.get("slot", "")) == slot: results.append(item)
	return results

func equip_gear(item_id: String) -> bool:
	var item: Dictionary = gear_item_by_id(item_id)
	if item.is_empty(): return false
	equipped_gear_ids[str(item["slot"])] = item_id
	_sync_equipment_display()
	return true

func unequip_gear(slot: String) -> void:
	if not equipped_gear_ids.has(slot): return
	equipped_gear_ids[slot] = ""
	_sync_equipment_display()

func equipped_gear_item(slot: String) -> Dictionary:
	var item_id: String = str(equipped_gear_ids.get(slot, ""))
	return gear_item_by_id(item_id) if not item_id.is_empty() else {}

## Sum of technique ranks granted by every currently equipped gear item,
## combined across slots and clamped per-technique to BonusConfig.MAX_RANK.
## Applied as the baseline rank at run start; wave-reward picks stack on top.
func equipped_technique_ranks() -> Dictionary:
	var totals: Dictionary = {}
	for slot: String in ArmoryConfig.GEAR_SLOTS:
		var item: Dictionary = equipped_gear_item(slot)
		if item.is_empty(): continue
		var techniques: Dictionary = item.get("techniques", {}) as Dictionary
		for bonus_id: String in techniques:
			totals[bonus_id] = mini(BonusConfig.MAX_RANK, int(totals.get(bonus_id, 0)) + int(techniques[bonus_id]))
	return totals

## Default base-item label shown when a slot has nothing equipped yet.
func default_slot_label(slot: String) -> String:
	match slot:
		"Sword": return "Basic Longsword"
		"Chakram": return "Steel Chakram"
		"Armor": return "Basic Leather Armor"
		"Ring": return "Empty"
	return "None"

func equipped_item_label(slot: String) -> String:
	var item: Dictionary = equipped_gear_item(slot)
	return ArmoryConfig.display_label(item) if not item.is_empty() else default_slot_label(slot)

func _sync_equipment_display() -> void:
	for slot: String in ArmoryConfig.GEAR_SLOTS:
		equipment[slot] = equipped_item_label(slot)

func _sanitize_gear_item(entry: Dictionary) -> Dictionary:
	var techniques_raw: Dictionary = entry.get("techniques", {}) as Dictionary
	var techniques: Dictionary = {}
	for bonus_id: Variant in techniques_raw.keys():
		techniques[str(bonus_id)] = clampi(int(techniques_raw[bonus_id]), 0, BonusConfig.MAX_RANK)
	return {
		"id": str(entry.get("id", "")),
		"slot": str(entry.get("slot", "")),
		"base_name": str(entry.get("base_name", "")),
		"techniques": techniques,
		"value": ArmoryConfig.item_value(techniques),
	}

func food_count(food_id: String) -> int:
	return maxi(0, int(food_inventory.get(food_id, 0)))

func has_recipe_ingredients(recipe_id: String) -> bool:
	var ingredients: Dictionary = CookingConfig.recipe_ingredients(recipe_id)
	if ingredients.is_empty(): return false
	for material_name: String in ingredients:
		if material_count(material_name) < int(ingredients[material_name]): return false
	return true

func can_craft(recipe_id: String) -> bool:
	# Storage quantity does not block a new cooking job; each completed job adds
	# one or two servings to the existing meal inventory.
	return not is_crafting() and has_recipe_ingredients(recipe_id)

func set_cooking_servings(servings: int) -> void:
	if not is_crafting(): return
	crafting_servings = clampi(servings, 1, 2)
	cooking_bonus_pending = false

func arm_cooking_bonus() -> bool:
	if not is_crafting(): return false
	cooking_bonus_pending = true
	return true

func apply_cooking_bonus_to_current_meal() -> bool:
	if not is_crafting() or not cooking_bonus_pending: return false
	crafting_servings = 2
	cooking_bonus_pending = false
	return true

func start_crafting(recipe_id: String, now_unix: float = -1.0) -> bool:
	if not can_craft(recipe_id): return false
	var ingredients: Dictionary = CookingConfig.recipe_ingredients(recipe_id)
	for material_name: String in ingredients:
		materials[material_name] = material_count(material_name) - int(ingredients[material_name])
	var start_time: float = Time.get_unix_time_from_system() if now_unix < 0.0 else now_unix
	crafting_recipe_id = recipe_id
	crafting_servings = 1
	cooking_bonus_pending = false
	crafting_started_at_unix = start_time
	crafting_completes_at_unix = start_time + CookingConfig.crafting_time(recipe_id)
	return true

## Compatibility entry point for the retired prototype Home screen.
func craft(recipe_id: String) -> bool:
	return start_crafting(recipe_id)

func is_crafting() -> bool:
	return not crafting_recipe_id.is_empty() and crafting_completes_at_unix > crafting_started_at_unix

func crafting_remaining_seconds(now_unix: float = -1.0) -> float:
	if not is_crafting(): return 0.0
	var current_time: float = Time.get_unix_time_from_system() if now_unix < 0.0 else now_unix
	return maxf(0.0, crafting_completes_at_unix - current_time)

func crafting_progress(now_unix: float = -1.0) -> float:
	if not is_crafting(): return 0.0
	var total_time: float = maxf(0.001, crafting_completes_at_unix - crafting_started_at_unix)
	return clampf(1.0 - crafting_remaining_seconds(now_unix) / total_time, 0.0, 1.0)

func finish_current_crafting_now() -> String:
	if not is_crafting(): return ""
	return _complete_current_crafting()

func update_crafting(now_unix: float = -1.0) -> String:
	if not is_crafting() or crafting_remaining_seconds(now_unix) > 0.0: return ""
	return _complete_current_crafting()

func _complete_current_crafting() -> String:
	var completed_recipe_id: String = crafting_recipe_id
	food_inventory[completed_recipe_id] = food_count(completed_recipe_id) + crafting_servings
	crafting_recipe_id = ""
	crafting_started_at_unix = 0.0
	crafting_completes_at_unix = 0.0
	crafting_servings = 1
	cooking_bonus_pending = false
	return completed_recipe_id

func prepare_food(food_id: String) -> bool:
	if CookingConfig.is_recovery_food(food_id): return false
	if food_count(food_id) <= 0: return false
	prepared_food_id = food_id
	equipment["Food"] = CookingConfig.recipe_name(food_id)
	return true

## Consumes one checkpoint snack and returns the amount of maximum health to restore.
func consume_recovery_food(food_id: String, maximum_health: float) -> float:
	if not CookingConfig.is_recovery_food(food_id) or food_count(food_id) <= 0: return 0.0
	food_inventory[food_id] = food_count(food_id) - 1
	return maximum_health * CookingConfig.food_recovery_percent(food_id)

func can_rescue_blacksmith() -> bool:
	return mines_wave_10_cleared and not blacksmith_rescued

func rescue_blacksmith() -> bool:
	if not can_rescue_blacksmith(): return false
	blacksmith_rescued = true
	return true

func can_purchase_forge() -> bool:
	return blacksmith_rescued and not forge_purchased

func purchase_forge() -> bool:
	if not can_purchase_forge(): return false
	forge_purchased = true
	return true

func is_forge_unlocked() -> bool:
	return forge_purchased

func begin_expedition() -> bool:
	active_food_id = ""
	active_food_waves_remaining = 0
	if prepared_food_id.is_empty() or food_count(prepared_food_id) <= 0:
		prepared_food_id = ""
		equipment["Food"] = "None"
		return false
	food_inventory[prepared_food_id] = food_count(prepared_food_id) - 1
	active_food_id = prepared_food_id
	active_food_waves_remaining = CookingConfig.food_wave_duration(active_food_id)
	prepared_food_id = ""
	equipment["Food"] = "None"
	return true

func complete_wave() -> bool:
	if active_food_id.is_empty() or active_food_waves_remaining <= 0: return false
	active_food_waves_remaining = maxi(0, active_food_waves_remaining - 1)
	if active_food_waves_remaining <= 0:
		active_food_id = ""
		return true
	return false

func end_expedition() -> void:
	active_food_id = ""
	active_food_waves_remaining = 0

func active_health_bonus() -> float:
	return CookingConfig.food_max_health(active_food_id) if active_food_waves_remaining > 0 else 0.0

func active_regeneration() -> float:
	return CookingConfig.food_regeneration(active_food_id) if active_food_waves_remaining > 0 else 0.0

func active_food_status() -> String:
	if active_food_id.is_empty() or active_food_waves_remaining <= 0: return ""
	return "%s: %d waves" % [CookingConfig.recipe_name(active_food_id), active_food_waves_remaining]

func to_save_data() -> Dictionary:
	return {
		"materials": materials.duplicate(true),
		"food_inventory": food_inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"gear_inventory": gear_inventory.duplicate(true),
		"equipped_gear_ids": equipped_gear_ids.duplicate(true),
		"next_gear_item_id": next_gear_item_id,
		"prepared_food_id": prepared_food_id,
		"mines_unlocked": mines_unlocked,
		"mines_wave_10_cleared": mines_wave_10_cleared,
		"blacksmith_rescued": blacksmith_rescued,
		"forge_purchased": forge_purchased,
		"crafting_recipe_id": crafting_recipe_id,
		"crafting_started_at_unix": crafting_started_at_unix,
		"crafting_completes_at_unix": crafting_completes_at_unix,
		"crafting_servings": crafting_servings,
		"cooking_bonus_pending": cooking_bonus_pending,
		"grandpa_chores_active": grandpa_chores_active,
		"grandpa_stone_gathered": grandpa_stone_gathered,
		"grandpa_wood_gathered": grandpa_wood_gathered,
		"grandpa_wolves_defeated": grandpa_wolves_defeated,
		"grandpa_goblins_defeated": grandpa_goblins_defeated,
	}

func load_save_data(data: Dictionary) -> void:
	var saved_materials: Dictionary = data.get("materials", {}) as Dictionary
	for material_name: String in MATERIAL_NAMES:
		materials[material_name] = maxi(0, int(saved_materials.get(material_name, materials.get(material_name, 0))))
	var saved_food: Dictionary = data.get("food_inventory", {}) as Dictionary
	for food_id: String in CookingConfig.recipe_ids():
		food_inventory[food_id] = maxi(0, int(saved_food.get(food_id, 0)))
	var saved_equipment: Dictionary = data.get("equipment", {}) as Dictionary
	for slot_name: String in EQUIPMENT_SLOT_NAMES:
		if saved_equipment.has(slot_name): equipment[slot_name] = str(saved_equipment[slot_name])
	gear_inventory.clear()
	var saved_gear: Array = data.get("gear_inventory", []) as Array
	for entry: Variant in saved_gear:
		if entry is Dictionary: gear_inventory.append(_sanitize_gear_item(entry as Dictionary))
	next_gear_item_id = maxi(0, int(data.get("next_gear_item_id", 0)))
	for slot_name: String in ArmoryConfig.GEAR_SLOTS: equipped_gear_ids[slot_name] = ""
	var saved_equipped_gear: Dictionary = data.get("equipped_gear_ids", {}) as Dictionary
	for slot_name: String in ArmoryConfig.GEAR_SLOTS:
		var candidate_id: String = str(saved_equipped_gear.get(slot_name, ""))
		if not candidate_id.is_empty() and not gear_item_by_id(candidate_id).is_empty():
			equipped_gear_ids[slot_name] = candidate_id
	_sync_equipment_display()
	mines_unlocked = bool(data.get("mines_unlocked", false))
	mines_wave_10_cleared = bool(data.get("mines_wave_10_cleared", false))
	blacksmith_rescued = bool(data.get("blacksmith_rescued", false)) and mines_wave_10_cleared
	forge_purchased = bool(data.get("forge_purchased", false)) and blacksmith_rescued
	prepared_food_id = str(data.get("prepared_food_id", ""))
	if not CookingConfig.recipe_ids().has(prepared_food_id) or CookingConfig.is_recovery_food(prepared_food_id) or food_count(prepared_food_id) <= 0:
		prepared_food_id = ""
		equipment["Food"] = "None"
	else:
		equipment["Food"] = CookingConfig.recipe_name(prepared_food_id)
	crafting_recipe_id = str(data.get("crafting_recipe_id", ""))
	crafting_started_at_unix = float(data.get("crafting_started_at_unix", 0.0))
	crafting_completes_at_unix = float(data.get("crafting_completes_at_unix", 0.0))
	crafting_servings = clampi(int(data.get("crafting_servings", 1)), 1, 2)
	cooking_bonus_pending = bool(data.get("cooking_bonus_pending", false))
	grandpa_chores_active = bool(data.get("grandpa_chores_active", false))
	grandpa_stone_gathered = clampi(int(data.get("grandpa_stone_gathered", 0)), 0, 20)
	grandpa_wood_gathered = clampi(int(data.get("grandpa_wood_gathered", 0)), 0, 20)
	grandpa_wolves_defeated = clampi(int(data.get("grandpa_wolves_defeated", 0)), 0, 3)
	grandpa_goblins_defeated = clampi(int(data.get("grandpa_goblins_defeated", 0)), 0, 3)
	if not CookingConfig.recipe_ids().has(crafting_recipe_id) or crafting_completes_at_unix <= crafting_started_at_unix:
		crafting_recipe_id = ""
		crafting_started_at_unix = 0.0
		crafting_completes_at_unix = 0.0
		crafting_servings = 1
	end_expedition()
