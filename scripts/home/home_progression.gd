class_name HomeProgression extends RefCounted

const MATERIAL_NAMES: Array[String] = ["Coins", "Stone", "Wood", "Forest Herb", "Spicy Red Berries", "Gummy Blue Berries", "Iron Shard", "Moon Petal", CookingConfig.MUSHROOM_MATERIAL, CookingConfig.TURKEY_MATERIAL, CookingConfig.WOLF_MEAT_MATERIAL]
const EQUIPMENT_SLOT_NAMES: Array[String] = ["Sword", "Chakram", "Armor", "Ring", "Food"]

const KAJI_GOLD_CAP: float = 500.0
const KAJI_GOLD_PER_SECOND: float = 125.0 / 3600.0
var kaji_gold: float = KAJI_GOLD_CAP
var kaji_updated_at_unix: float = -1.0
const KAJI_INITIAL_STOCK: int = 5
const KAJI_STOCK_SECONDS: float = 2400.0
## Per-item partial interval, consuming the SAME high-water clock as the purse.
## Missing entries initialize on first update (old saves get no retroactive stock).
var kaji_stock_elapsed: Dictionary = {}
## Historical acquisition, independent of current ownership and run reports.
var discovered_items: Dictionary = {}
## Zero entries are retained: sold-out stock never reseeds on a visit.
var kaji_stock: Dictionary = {}
## Distinct merchant ledger, persisted in the SAME progression/save authority.
var jimbo_gold: float = KAJI_GOLD_CAP
var jimbo_updated_at_unix: float = -1.0
var jimbo_stock: Dictionary = {}
var jimbo_stock_elapsed: Dictionary = {}
## Discovered base gear offers contain no ownership ID or skill infusions.
var jimbo_gear_offers: Dictionary = {}
var owned_forge_recipes: Dictionary = {}
var forge_slot_count: int = 1

func owns_forge_offer(id: String) -> bool:
	if id == ArmoryConfig.SECOND_FORGE_SLOT_ID: return forge_slot_count >= 2
	return ArmoryConfig.FORGE_RECIPES.has(id) and bool(owned_forge_recipes.get(id, false))

func can_buy_forge_offer(id: String) -> bool:
	if not ArmoryConfig.FORGE_PERMANENT_OFFERS.has(id) or owns_forge_offer(id): return false
	var offer: Dictionary = ArmoryConfig.FORGE_PERMANENT_OFFERS[id]
	return material_count("Coins") >= int(offer["coins"]) and material_count("Stone") >= int(offer.get("stone", 0))

## One-time all-or-nothing purchase; Main owns save/rollback. No gear production.
func buy_forge_offer(id: String, requested: int) -> int:
	if requested != 1 or not can_buy_forge_offer(id): return 0
	var offer: Dictionary = ArmoryConfig.FORGE_PERMANENT_OFFERS[id]
	materials["Coins"] = material_count("Coins") - int(offer["coins"])
	if offer.has("stone"): materials["Stone"] = material_count("Stone") - int(offer["stone"])
	if id == ArmoryConfig.SECOND_FORGE_SLOT_ID: forge_slot_count = 2
	else: owned_forge_recipes[id] = true
	jimbo_gold = minf(KAJI_GOLD_CAP, jimbo_gold + int(offer["coins"]))
	return 1

## Shrine balances live only in canonical progression, never combat presets.
const SHRINE_INT_MAX: int = 9223372036854775807
var resonance: int = 0
var skill_knowledge: Dictionary = {}

static func shrine_nonnegative_int(value: Variant) -> int:
	if value is int: return maxi(0, value)
	# JSON numbers are doubles. Decimal strings preserve huge integer balances.
	if value is String:
		var digits: String = value
		if digits.is_empty(): return 0
		for character: String in digits:
			if character < "0" or character > "9": return 0
		while digits.length() > 1 and digits.begins_with("0"): digits = digits.substr(1)
		var maximum: String = str(SHRINE_INT_MAX)
		if digits.length() > maximum.length() or (digits.length() == maximum.length() and digits > maximum): return SHRINE_INT_MAX
		return digits.to_int()
	if value is float:
		if not is_finite(value) or value <= 0.0: return 0
		if value >= float(SHRINE_INT_MAX): return SHRINE_INT_MAX
		return int(value)
	return 0

static func knowledge_threshold(rank: int) -> int:
	var total: int = 0
	for level: int in range(1, clampi(rank, 0, BonusConfig.MAX_RANK) + 1):
		total += 10 * (level + 1)
	return total

func learned_skill_rank(skill: String) -> int:
	if not BonusConfig.all_bonus_ids().has(skill): return 0
	var points: int = shrine_nonnegative_int(skill_knowledge.get(skill, 0))
	var learned: int = 0
	for rank: int in range(1, BonusConfig.MAX_RANK + 1):
		if points < knowledge_threshold(rank): break
		learned = rank
	return learned

func shrine_exchange_limit() -> int:
	return mini(material_count("Coins"), SHRINE_INT_MAX - resonance)

func exchange_shrine_coins(requested: int) -> int:
	if requested <= 0: return 0
	var amount: int = mini(requested, shrine_exchange_limit())
	if amount <= 0: return 0
	materials["Coins"] = material_count("Coins") - amount
	resonance += amount
	return amount

## All canonical BonusConfig ranks are skills (including health/defense).
## Gear has no separate inherent-stat dictionary or slot compatibility table.
static func shrine_valid_ranks(item: Dictionary) -> bool:
	if not item.get("techniques", null) is Dictionary: return false
	for key: Variant in item["techniques"]:
		if not key is String or not BonusConfig.all_bonus_ids().has(key): return false
		var value: Variant = item["techniques"][key]
		if not (value is int or value is float): return false
		if not is_finite(float(value)) or float(value) < 0.0 or float(value) > BonusConfig.MAX_RANK: return false
		if float(value) != float(int(value)): return false
	return true

func shrine_salvage_gains(item_id: String) -> Dictionary:
	if item_id.is_empty() or equipped_gear_ids.values().has(item_id): return {}
	var item: Dictionary = gear_item_by_id(item_id)
	var count: int = 0
	for candidate: Dictionary in gear_inventory:
		if str(candidate.get("id", "")) == item_id: count += 1
	if count != 1 or bool(item.get("shrine_invalid", false)): return {}
	if str(item.get("origin", "found")) != "found": return {}
	if ArmoryConfig.slot_for_item_name(str(item.get("base_name", ""))) != str(item.get("slot", "")) or not str(item.get("slot", "")) in ArmoryConfig.GEAR_SLOTS: return {}
	# Any player-infusion metadata protects the whole item, even legacy found loot.
	var infusions: Variant = item.get("skill_infusions", {})
	if not infusions is Dictionary or not infusions.is_empty(): return {}
	if not shrine_valid_ranks(item): return {}
	var gains: Dictionary = {}
	for key: String in item["techniques"]:
		var rank: int = int(item["techniques"][key])
		if rank <= 0: continue
		if shrine_nonnegative_int(skill_knowledge.get(key, 0)) > SHRINE_INT_MAX - rank: return {}
		gains[key] = rank
	return gains

func salvage_shrine_gear(item_id: String) -> int:
	var gains: Dictionary = shrine_salvage_gains(item_id)
	if gains.is_empty(): return 0
	for skill: String in gains:
		skill_knowledge[skill] = shrine_nonnegative_int(skill_knowledge.get(skill, 0)) + int(gains[skill])
	gear_inventory.erase(gear_item_by_id(item_id))
	return 1

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
	record_item_discovery(material_name)
	if not grandpa_chores_active: return
	if material_name == "Stone": grandpa_stone_gathered = mini(20, grandpa_stone_gathered + quantity)
	if material_name == "Wood": grandpa_wood_gathered = mini(20, grandpa_wood_gathered + quantity)

func begin_grandpa_chores() -> void:
	grandpa_chores_active = true

func record_grandpa_enemy_defeat(enemy_identity: StringName) -> void:
	if not grandpa_chores_active: return
	if enemy_identity == &"wolf": grandpa_wolves_defeated = mini(3, grandpa_wolves_defeated + 1)
	if enemy_identity in [&"goblin", &"archer_goblin", &"sword_goblin", &"goblin_bomber", &"goblin_shaman"]: grandpa_goblins_defeated = mini(3, grandpa_goblins_defeated + 1)

func grandpa_chores_complete() -> bool:
	return grandpa_chores_active and grandpa_stone_gathered >= 20 and grandpa_wood_gathered >= 20 and grandpa_wolves_defeated >= 3 and grandpa_goblins_defeated >= 3

func generate_gear_id() -> String:
	next_gear_item_id += 1
	while not gear_item_by_id("gear_%d" % next_gear_item_id).is_empty():
		next_gear_item_id += 1
	return "gear_%d" % next_gear_item_id

func add_gear_item(item: Dictionary) -> void:
	gear_inventory.append(item)
	var item_id: String = str(item.get("id", ""))
	if item_id.begins_with("gear_"): next_gear_item_id = maxi(next_gear_item_id, item_id.trim_prefix("gear_").to_int())
	_record_smith_gear(item)

func _record_smith_gear(item: Dictionary) -> void:
	if ArmoryConfig.smith_value(item) <= 0: return
	var key: String = ArmoryConfig.smith_stock_key(item)
	jimbo_gear_offers[key] = {"base_name": item["base_name"], "slot": item["slot"], "techniques": ArmoryConfig.smith_base_techniques(item)}
	_seed_jimbo_stock(key)

func _seed_jimbo_stock(key: String) -> void:
	if jimbo_stock.has(key): return
	jimbo_stock[key] = KAJI_INITIAL_STOCK
	jimbo_stock_elapsed[key] = 0.0

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
		"shrine_invalid": bool(entry.get("shrine_invalid", false)) or not shrine_valid_ranks(entry),
		"origin": str(entry.get("origin", "found")),
		"base_techniques": ArmoryConfig.smith_base_techniques(entry),
		"skill_infusions": (entry.get("skill_infusions", {}) as Dictionary).duplicate(true),
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
	# One stored Heart charge. Passing again while charged simply remains full.
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
	record_item_discovery(completed_recipe_id)
	crafting_recipe_id = ""
	crafting_started_at_unix = 0.0
	crafting_completes_at_unix = 0.0
	crafting_servings = 1
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

## High-water timestamp prevents counting the same elapsed interval twice after
## a backwards clock adjustment. Fractions survive visits, trades and saves.
func update_kaji(now_unix: float = -1.0) -> void:
	var now: float = Time.get_unix_time_from_system() if now_unix < 0.0 else now_unix
	var elapsed: float = maxf(0.0, now - kaji_updated_at_unix) if kaji_updated_at_unix >= 0.0 else 0.0
	_restock_merchant(kaji_stock, kaji_stock_elapsed, elapsed)
	if kaji_updated_at_unix < 0.0:
		kaji_updated_at_unix = now
		return
	if now <= kaji_updated_at_unix: return
	kaji_gold = clampf(kaji_gold + elapsed * KAJI_GOLD_PER_SECOND, 0.0, KAJI_GOLD_CAP)
	kaji_updated_at_unix = now

func _restock_merchant(stock_ledger: Dictionary, partial_ledger: Dictionary, elapsed: float) -> void:
	for key: String in stock_ledger:
		var stock: int = clampi(int(stock_ledger[key]), 0, KAJI_INITIAL_STOCK)
		if not partial_ledger.has(key) or stock >= KAJI_INITIAL_STOCK:
			partial_ledger[key] = 0.0
			continue
		var partial: float = minf(float(partial_ledger[key]) + elapsed, float(KAJI_INITIAL_STOCK - stock) * KAJI_STOCK_SECONDS)
		var added: int = floori(partial / KAJI_STOCK_SECONDS)
		stock_ledger[key] = stock + added
		partial_ledger[key] = 0.0 if stock + added >= KAJI_INITIAL_STOCK else partial - float(added) * KAJI_STOCK_SECONDS

func update_jimbo(now_unix: float = -1.0) -> void:
	var now: float = Time.get_unix_time_from_system() if now_unix < 0.0 else now_unix
	var elapsed: float = maxf(0.0, now - jimbo_updated_at_unix) if jimbo_updated_at_unix >= 0.0 else 0.0
	_restock_merchant(jimbo_stock, jimbo_stock_elapsed, elapsed)
	jimbo_gold = clampf(jimbo_gold + elapsed * KAJI_GOLD_PER_SECOND, 0.0, KAJI_GOLD_CAP)
	jimbo_updated_at_unix = maxf(now, jimbo_updated_at_unix)

func blacksmith_price(item_id: String, buying: bool) -> int:
	var price: int = ItemConfig.blacksmith_sale_price(item_id)
	if price == 0:
		var item: Dictionary = jimbo_gear_offers.get(item_id, {}) if buying else gear_item_by_id(item_id)
		price = ArmoryConfig.item_value(item.get("techniques", {})) if buying else ArmoryConfig.smith_value(item)
	return price * (2 if buying else 1)

func blacksmith_label(item_id: String, buying: bool) -> String:
	var item: Dictionary = jimbo_gear_offers.get(item_id, {}) if buying else gear_item_by_id(item_id)
	return ArmoryConfig.display_label(item) if not item.is_empty() else item_id

func blacksmith_stock_count(item_id: String) -> int:
	return clampi(int(jimbo_stock.get(item_id, 0)), 0, KAJI_INITIAL_STOCK) if blacksmith_price(item_id, true) > 0 else 0

func blacksmith_sellable_count(item_id: String) -> int:
	if ItemConfig.blacksmith_sale_price(item_id) > 0: return material_count(item_id)
	if equipped_gear_ids.values().has(item_id): return 0
	return 1 if ArmoryConfig.smith_value(gear_item_by_id(item_id)) > 0 else 0

func blacksmith_buyable_count(item_id: String) -> int:
	var price: int = blacksmith_price(item_id, true)
	return mini(blacksmith_stock_count(item_id), floori(float(material_count("Coins")) / float(price))) if price > 0 else 0

func trade_with_jimbo(item_id: String, requested: int, buying: bool, now_unix: float = -1.0) -> int:
	if ArmoryConfig.FORGE_PERMANENT_OFFERS.has(item_id):
		return buy_forge_offer(item_id, requested) if buying else 0
	if item_id.begins_with("forge_recipe:") or item_id.begins_with("forge_upgrade:"): return 0
	update_jimbo(now_unix)
	var price: int = blacksmith_price(item_id, buying)
	if price <= 0 or requested <= 0: return 0
	var limit: int = blacksmith_buyable_count(item_id) if buying else mini(blacksmith_sellable_count(item_id), floori(jimbo_gold / float(price)))
	var quantity: int = mini(requested, limit)
	if quantity <= 0: return 0
	if buying:
		if jimbo_gear_offers.has(item_id):
			for index: int in quantity:
				var item: Dictionary = (jimbo_gear_offers[item_id] as Dictionary).duplicate(true)
				item["id"] = generate_gear_id()
				item["origin"] = "forged"
				item["base_techniques"] = (item["techniques"] as Dictionary).duplicate(true)
				item["value"] = ArmoryConfig.item_value(item["techniques"])
				gear_inventory.append(item)
		else:
			materials[item_id] = material_count(item_id) + quantity
		jimbo_stock[item_id] = blacksmith_stock_count(item_id) - quantity
	else:
		if ItemConfig.blacksmith_sale_price(item_id) > 0:
			materials[item_id] = material_count(item_id) - quantity
		else:
			var item: Dictionary = gear_item_by_id(item_id)
			_record_smith_gear(item)
			gear_inventory.erase(item)
	materials["Coins"] = material_count("Coins") + quantity * price * (-1 if buying else 1)
	jimbo_gold = clampf(jimbo_gold + quantity * price * (1 if buying else -1), 0.0, KAJI_GOLD_CAP)
	return quantity

func kaji_refill_seconds() -> float:
	return maxf(0.0, KAJI_GOLD_CAP - kaji_gold) / KAJI_GOLD_PER_SECOND

func record_item_discovery(item_id: String) -> void:
	discovered_items[item_id] = true
	if ItemConfig.blacksmith_sale_price(item_id) > 0: _seed_jimbo_stock(item_id)
	if ItemConfig.general_purchase_price(item_id) > 0 and not kaji_stock.has(item_id):
		kaji_stock[item_id] = KAJI_INITIAL_STOCK
		kaji_stock_elapsed[item_id] = 0.0

func general_stock_count(item_id: String) -> int:
	if not discovered_items.has(item_id) or ItemConfig.general_purchase_price(item_id) <= 0: return 0
	return clampi(int(kaji_stock.get(item_id, 0)), 0, KAJI_INITIAL_STOCK)

func general_buyable_count(item_id: String) -> int:
	var price: int = ItemConfig.general_purchase_price(item_id)
	if price <= 0: return 0
	return mini(general_stock_count(item_id), floori(float(material_count("Coins")) / float(price)))

## Same authority and storage as sales; caller saves or rolls back the trade.
func buy_from_kaji(item_id: String, requested: int, now_unix: float = -1.0) -> int:
	update_kaji(now_unix)
	var price: int = ItemConfig.general_purchase_price(item_id)
	if price <= 0 or requested <= 0: return 0
	var quantity: int = mini(requested, general_buyable_count(item_id))
	if quantity <= 0: return 0
	materials["Coins"] = material_count("Coins") - quantity * price
	# Preserve the existing purse maximum; excess receipts above 500 are discarded.
	kaji_gold = minf(KAJI_GOLD_CAP, kaji_gold + quantity * price)
	kaji_stock[item_id] = general_stock_count(item_id) - quantity
	if CookingConfig.recipe_ids().has(item_id):
		food_inventory[item_id] = food_count(item_id) + quantity
	else:
		materials[item_id] = material_count(item_id) + quantity
	return quantity

func general_sellable_count(item_id: String) -> int:
	if ItemConfig.general_sale_price(item_id) <= 0: return 0
	if CookingConfig.recipe_ids().has(item_id):
		# Prepared food reserves one stored serving; active food is already consumed.
		return maxi(0, food_count(item_id) - (1 if prepared_food_id == item_id else 0))
	return material_count(item_id)

## Mutates the single progression authority. Caller must save synchronously and
## roll back on failure before reporting success to the player.
func sell_to_kaji(item_id: String, requested: int, now_unix: float = -1.0) -> int:
	update_kaji(now_unix)
	var price: int = ItemConfig.general_sale_price(item_id)
	if price <= 0 or requested <= 0: return 0
	var quantity: int = mini(mini(requested, general_sellable_count(item_id)), floori(kaji_gold / float(price)))
	if quantity <= 0: return 0
	if CookingConfig.recipe_ids().has(item_id):
		food_inventory[item_id] = food_count(item_id) - quantity
	else:
		materials[item_id] = material_count(item_id) - quantity
	materials["Coins"] = material_count("Coins") + quantity * price
	kaji_gold = maxf(0.0, kaji_gold - quantity * price)
	return quantity

func to_save_data() -> Dictionary:
	var saved_resonance: Variant = resonance
	if resonance > 9007199254740991: saved_resonance = str(resonance)
	var saved_knowledge: Dictionary = skill_knowledge.duplicate(true)
	for key: String in saved_knowledge:
		if shrine_nonnegative_int(saved_knowledge[key]) > 9007199254740991: saved_knowledge[key] = str(saved_knowledge[key])
	return {
		"owned_forge_recipes": owned_forge_recipes.duplicate(true),
		"forge_slot_count": forge_slot_count,
		"resonance": saved_resonance,
		"skill_knowledge": saved_knowledge,
		"jimbo_gold": jimbo_gold,
		"jimbo_updated_at_unix": jimbo_updated_at_unix,
		"jimbo_stock": jimbo_stock.duplicate(true),
		"jimbo_stock_elapsed": jimbo_stock_elapsed.duplicate(true),
		"jimbo_gear_offers": jimbo_gear_offers.duplicate(true),
		"discovered_items": discovered_items.duplicate(true),
		"kaji_stock": kaji_stock.duplicate(true),
		"kaji_stock_elapsed": kaji_stock_elapsed.duplicate(true),
		"kaji_gold": kaji_gold,
		"kaji_updated_at_unix": kaji_updated_at_unix,
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
	forge_slot_count = clampi(shrine_nonnegative_int(data.get("forge_slot_count", 1)), 1, 2)
	owned_forge_recipes.clear()
	var saved_recipes: Variant = data.get("owned_forge_recipes", {})
	if saved_recipes is Dictionary:
		for id: String in ArmoryConfig.FORGE_RECIPES:
			if bool(saved_recipes.get(id, false)): owned_forge_recipes[id] = true
	resonance = shrine_nonnegative_int(data.get("resonance", 0))
	skill_knowledge.clear()
	var knowledge: Variant = data.get("skill_knowledge", {})
	if knowledge is Dictionary:
		for skill: String in BonusConfig.all_bonus_ids():
			var points: int = shrine_nonnegative_int(knowledge.get(skill, 0))
			if points > 0: skill_knowledge[skill] = points
	jimbo_gold = clampf(float(data.get("jimbo_gold", KAJI_GOLD_CAP)), 0.0, KAJI_GOLD_CAP)
	jimbo_updated_at_unix = float(data.get("jimbo_updated_at_unix", -1.0))
	jimbo_stock.clear()
	jimbo_stock_elapsed.clear()
	jimbo_gear_offers.clear()
	var offers: Dictionary = data.get("jimbo_gear_offers", {}) as Dictionary
	for key: String in offers:
		var offer: Dictionary = (offers[key] as Dictionary).duplicate(true)
		offer["id"] = "validation"
		offer["origin"] = "forged"
		if ArmoryConfig.smith_value(offer) <= 0 or key != ArmoryConfig.smith_stock_key(offer): continue
		jimbo_gear_offers[key] = {"base_name": offer["base_name"], "slot": offer["slot"], "techniques": ArmoryConfig.smith_base_techniques(offer)}
	var smith_stock: Dictionary = data.get("jimbo_stock", {}) as Dictionary
	var smith_elapsed: Dictionary = data.get("jimbo_stock_elapsed", {}) as Dictionary
	for key: String in smith_stock:
		if ItemConfig.blacksmith_sale_price(key) <= 0 and not jimbo_gear_offers.has(key): continue
		jimbo_stock[key] = clampi(int(smith_stock[key]), 0, KAJI_INITIAL_STOCK)
		if smith_elapsed.has(key): jimbo_stock_elapsed[key] = clampf(float(smith_elapsed[key]), 0.0, KAJI_STOCK_SECONDS) if int(jimbo_stock[key]) < KAJI_INITIAL_STOCK else 0.0
	kaji_gold = clampf(float(data.get("kaji_gold", KAJI_GOLD_CAP)), 0.0, KAJI_GOLD_CAP)
	kaji_updated_at_unix = float(data.get("kaji_updated_at_unix", -1.0))
	var saved_materials: Dictionary = data.get("materials", {}) as Dictionary
	for material_name: String in MATERIAL_NAMES:
		materials[material_name] = maxi(0, int(saved_materials.get(material_name, materials.get(material_name, 0))))
	var saved_food: Dictionary = data.get("food_inventory", {}) as Dictionary
	for food_id: String in CookingConfig.recipe_ids():
		food_inventory[food_id] = maxi(0, int(saved_food.get(food_id, 0)))
	discovered_items.clear()
	kaji_stock.clear()
	kaji_stock_elapsed.clear()
	var saved_elapsed: Dictionary = data.get("kaji_stock_elapsed", {}) as Dictionary
	var saved_discoveries: Dictionary = data.get("discovered_items", {}) as Dictionary
	var saved_stock: Dictionary = data.get("kaji_stock", {}) as Dictionary
	for item_id: String in saved_discoveries:
		if bool(saved_discoveries[item_id]):
			discovered_items[item_id] = true
			if ItemConfig.general_purchase_price(item_id) > 0:
				kaji_stock[item_id] = clampi(int(saved_stock.get(item_id, KAJI_INITIAL_STOCK)), 0, KAJI_INITIAL_STOCK)
				if saved_elapsed.has(item_id):
					kaji_stock_elapsed[item_id] = clampf(float(saved_elapsed[item_id]), 0.0, KAJI_STOCK_SECONDS) if int(kaji_stock[item_id]) < KAJI_INITIAL_STOCK else 0.0
	# Legacy saves have no historical acquisition authority. Bootstrap storage
	# once; all future pickups/cooking record discovery before items can be sold.
	if not data.has("discovered_items"):
		for item_id: String in MATERIAL_NAMES:
			if material_count(item_id) > 0: record_item_discovery(item_id)
		for item_id: String in CookingConfig.recipe_ids():
			if food_count(item_id) > 0: record_item_discovery(item_id)
	var saved_equipment: Dictionary = data.get("equipment", {}) as Dictionary
	for slot_name: String in EQUIPMENT_SLOT_NAMES:
		if saved_equipment.has(slot_name): equipment[slot_name] = str(saved_equipment[slot_name])
	gear_inventory.clear()
	var saved_gear: Array = data.get("gear_inventory", []) as Array
	for entry: Variant in saved_gear:
		if entry is Dictionary: gear_inventory.append(_sanitize_gear_item(entry as Dictionary))
	# Merchant migration uses canonical historical discoveries/current chest gear,
	# never run reports; existing zero stock is retained.
	for key: String in discovered_items:
		if ItemConfig.blacksmith_sale_price(key) > 0: _seed_jimbo_stock(key)
	for item: Dictionary in gear_inventory: _record_smith_gear(item)
	next_gear_item_id = maxi(0, int(data.get("next_gear_item_id", 0)))
	for item: Dictionary in gear_inventory:
		var item_id: String = str(item.get("id", ""))
		if item_id.begins_with("gear_"): next_gear_item_id = maxi(next_gear_item_id, item_id.trim_prefix("gear_").to_int())
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
