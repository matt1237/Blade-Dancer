class_name ArmoryConfig extends RefCounted
## Data-only config for chest-dropped gear: slot pools, technique-rank rolls,
## and coin value. No gameplay state lives here — HomeProgression owns the
## persisted gear_inventory/equipped_gear_ids; player.gd/main.gd read this
## config to apply effects. See docs/architecture.md "data versus behavior".

## Stable capability identity; geometry uses Basic Longsword, hand tuning has its own profile (seeded from Longsword).
const DUALBLADE_NAME: String = "Twin Longswords (Test)"
const DUALBLADE_ID: String = "approved_test_dualblade_v1"

static func dualblade_test_item() -> Dictionary:
	return {"id": DUALBLADE_ID, "slot": "Sword", "base_name": DUALBLADE_NAME, "origin": "approved_test", "techniques": {}, "base_techniques": {}, "value": 0}

## Approved test capability: one rigid double-ended weapon held crosswise; tuning
## has its own profile seeded from Basic Longsword. Never pooled/sold/salvaged.
const DOUBLE_ENDED_NAME: String = "Double-Ended Iron Sword (Test)"
const DOUBLE_ENDED_ID: String = "approved_test_double_ended_v1"

static func double_ended_test_item() -> Dictionary:
	return {"id": DOUBLE_ENDED_ID, "slot": "Sword", "base_name": DOUBLE_ENDED_NAME, "origin": "approved_test", "techniques": {}, "base_techniques": {}, "value": 0}

## Approved test capability: heavy single greatsword with its own traced,
## variable-width blade shape and a fixed +20% damage property. Never pooled/sold/salvaged.
const GREATSWORD_NAME: String = "Iron Greatsword (Test)"
const GREATSWORD_ID: String = "approved_test_iron_greatsword_v1"

static func greatsword_test_item() -> Dictionary:
	return {"id": GREATSWORD_ID, "slot": "Sword", "base_name": GREATSWORD_NAME, "origin": "approved_test", "techniques": {}, "base_techniques": {}, "value": 0}

const GEAR_SLOTS: Array[String] = ["Armor", "Chakram", "Sword", "Ring"]

## Permanent knowledge, NOT inventory gear or replenishing merchant stock.
## Output identities/material requirements/times await approval. Never roll skills.
const FORGE_RECIPES: Dictionary = {
	"forge_recipe:iron_longsword": {"name": "Iron Longsword", "coins": 200},
	"forge_recipe:iron_banded_chakram": {"name": "Iron Banded Chakram", "coins": 200},
	"forge_recipe:basic_leather_armor": {"name": "Basic Leather Armor", "coins": 200},
	"forge_recipe:iron_band": {"name": "Iron Band", "coins": 200},
}
const SECOND_FORGE_SLOT_ID: String = "forge_upgrade:second_slot"
const FORGE_PERMANENT_OFFERS: Dictionary = {
	"forge_recipe:iron_longsword": FORGE_RECIPES["forge_recipe:iron_longsword"],
	"forge_recipe:iron_banded_chakram": FORGE_RECIPES["forge_recipe:iron_banded_chakram"],
	"forge_recipe:basic_leather_armor": FORGE_RECIPES["forge_recipe:basic_leather_armor"],
	"forge_recipe:iron_band": FORGE_RECIPES["forge_recipe:iron_band"],
	SECOND_FORGE_SLOT_ID: {"name": "Second Forge Slot", "coins": 5000, "stone": 100},
}

static func forge_offer_cost_label(id: String) -> String:
	var offer: Dictionary = FORGE_PERMANENT_OFFERS.get(id, {})
	if offer.is_empty(): return ""
	return "%d Coins%s" % [int(offer["coins"]), " + %d Stone" % int(offer["stone"]) if offer.has("stone") else ""]

## Base item pool per slot. Armor and Sword each have two visually distinct
## base items today (the always-available default plus one chest-droppable
## reskin/upgrade); Chakram and Ring have exactly one base item for now.
const SLOT_ITEM_POOL: Dictionary = {
	"Armor": ["Basic Leather Armor", "Basic Knight Armor"],
	"Chakram": ["Steel Chakram"],
	"Sword": ["Basic Longsword", "Basic Curved Sword"],
	"Ring": ["Clear Quartz Ring"],
}

## Coins earned per technique rank when displaying an item's worth.
const COIN_VALUE_PER_RANK: int = 100

## 5% chance a chest yields two independent item rolls instead of one.
const DOUBLE_ROLL_CHANCE: float = 0.05

static func slot_for_item_name(base_name: String) -> String:
	if base_name == DUALBLADE_NAME or base_name == DOUBLE_ENDED_NAME or base_name == GREATSWORD_NAME: return "Sword"
	for slot: String in GEAR_SLOTS:
		if (SLOT_ITEM_POOL[slot] as Array).has(base_name): return slot
	return ""

## Number of technique-rank rolls an item found on the given wave gets.
## Waves 1-9 → 1 roll, 10-19 → 2 rolls, 20-29 → 3 rolls, and so on.
static func technique_roll_count(wave: int) -> int:
	return int(floor(maxf(0.0, float(wave)) / 10.0)) + 1

## Rolls a single gear item. Returns a Dictionary:
## {id, slot, base_name, techniques: {bonus_id: rank}, value}
static func roll_item(wave: int, item_id: String) -> Dictionary:
	var slot: String = GEAR_SLOTS[randi_range(0, GEAR_SLOTS.size() - 1)]
	var pool: Array = SLOT_ITEM_POOL[slot]
	var base_name: String = pool[randi_range(0, pool.size() - 1)]
	var techniques: Dictionary = {}
	var roll_count: int = technique_roll_count(wave)
	var bonus_ids: Array[String] = BonusConfig.all_bonus_ids()
	for _roll_index: int in range(roll_count):
		var attempts_left: int = bonus_ids.size()
		var bonus_id: String = bonus_ids[randi_range(0, bonus_ids.size() - 1)]
		# Avoid wasting a roll on a technique already capped at MAX_RANK on
		# this item; try a few different techniques before giving up.
		while int(techniques.get(bonus_id, 0)) >= BonusConfig.MAX_RANK and attempts_left > 0:
			bonus_id = bonus_ids[randi_range(0, bonus_ids.size() - 1)]
			attempts_left -= 1
		techniques[bonus_id] = mini(BonusConfig.MAX_RANK, int(techniques.get(bonus_id, 0)) + 1)
	return {
		"id": item_id,
		"origin": "found",
		"base_techniques": techniques.duplicate(true),
		"slot": slot,
		"base_name": base_name,
		"techniques": techniques,
		"value": item_value(techniques),
	}

## Old persisted gear was exclusively chest loot. Defaults are display-only,
## never inventory entries. Explicit skill/starter origins are not sellable.
static func smith_base_techniques(item: Dictionary) -> Dictionary:
	var ranks: Dictionary = (item.get("base_techniques", item.get("techniques", {})) as Dictionary).duplicate(true)
	if not item.has("base_techniques"):
		var infusions: Dictionary = item.get("skill_infusions", {}) as Dictionary
		for key: String in infusions:
			ranks[key] = maxi(0, int(ranks.get(key, 0)) - int(infusions[key]))
	for key: String in ranks.keys():
		if not BonusConfig.all_bonus_ids().has(key) or int(ranks[key]) <= 0:
			ranks.erase(key)
		else:
			ranks[key] = clampi(int(ranks[key]), 0, BonusConfig.MAX_RANK)
	return ranks

static func smith_eligible(item: Dictionary) -> bool:
	var base: String = str(item.get("base_name", ""))
	var slot: String = slot_for_item_name(base)
	return slot in ["Sword", "Armor", "Chakram"] and slot == str(item.get("slot", "")) and str(item.get("origin", "found")) in ["found", "forged"] and not str(item.get("id", "")).is_empty()

static func smith_value(item: Dictionary) -> int:
	return item_value(smith_base_techniques(item)) if smith_eligible(item) else 0

static func smith_stock_key(item: Dictionary) -> String:
	var ranks: Dictionary = smith_base_techniques(item)
	for key: String in ranks: ranks[key] = int(ranks[key])
	ranks.sort()
	return "smith:" + str(item.get("base_name", "")) + ":" + JSON.stringify(ranks)

static func total_rank_count(techniques: Dictionary) -> int:
	var total: int = 0
	for bonus_id: String in techniques: total += int(techniques[bonus_id])
	return total

static func item_value(techniques: Dictionary) -> int:
	return total_rank_count(techniques) * COIN_VALUE_PER_RANK

## Display label like "Curved Sword (Regeneration 1, Vampirism 1)".
static func display_label(item: Dictionary) -> String:
	var techniques: Dictionary = item.get("techniques", {}) as Dictionary
	var bonus_ids: Array = techniques.keys()
	bonus_ids.sort()
	var parts: Array[String] = []
	for bonus_id: String in bonus_ids:
		parts.append("%s %d" % [BonusConfig.display_name(bonus_id), int(techniques[bonus_id])])
	var short_name: String = str(item.get("base_name", "")).trim_prefix("Basic ")
	if parts.is_empty(): return short_name
	return "%s (%s)" % [short_name, ", ".join(parts)]
