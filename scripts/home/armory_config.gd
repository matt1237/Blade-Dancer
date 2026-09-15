class_name ArmoryConfig extends RefCounted
## Data-only config for chest-dropped gear: slot pools, technique-rank rolls,
## and coin value. No gameplay state lives here — HomeProgression owns the
## persisted gear_inventory/equipped_gear_ids; player.gd/main.gd read this
## config to apply effects. See docs/architecture.md "data versus behavior".

const GEAR_SLOTS: Array[String] = ["Armor", "Chakram", "Sword", "Ring"]

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
		"slot": slot,
		"base_name": base_name,
		"techniques": techniques,
		"value": item_value(techniques),
	}

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
