class_name ItemConfig extends RefCounted

# =============================================================================
# ITEM PRESENTATION TUNING — PRIMARY EDITING AREA
# Add an item to the rarity match below when its shared pickup bag should use
# Rare or Very Rare colors. Unknown items intentionally remain Normal.
# =============================================================================
enum Rarity { NORMAL, RARE, VERY_RARE }

const NORMAL_BAG_COLOR: Color = Color("9a6846")
const RARE_BAG_COLOR: Color = Color("4f9b58")
const VERY_RARE_BAG_COLOR: Color = Color("4f83bd")
const BAG_HIGHLIGHT: Color = Color(1.0, 0.88, 0.58, 0.55)
const BAG_OUTLINE: Color = Color("302534")

## Unknown materials intentionally default to Normal so future content remains usable
## before a rarity is explicitly assigned here.
static func rarity(item_name: String) -> Rarity:
	match item_name:
		"Iron Shard": return Rarity.RARE
		"Moon Petal": return Rarity.VERY_RARE
		_: return Rarity.NORMAL

## Canonical General-store offers. Zero means not traded (gear, currency,
## smithing/building supplies and unknown/quest objects are excluded).
static func general_sale_price(item_id: String) -> int:
	match item_id:
		"Forest Herb": return 2
		"Mushroom": return 3
		"Turkey": return 4
		"Wolf Meat": return 5
		"Moon Petal": return 12
		CookingConfig.WILD_TURKEY_STEW_ID: return 18
		CookingConfig.WOLF_JERKY_ID: return 20
		_: return 0

## Player purchase price: only registered common General goods qualify.
static func general_purchase_price(item_id: String) -> int:
	if rarity(item_id) != Rarity.NORMAL: return 0
	return general_sale_price(item_id) * 2

## Only registered smithing supplies: never infer eligibility from unknown names.
static func blacksmith_sale_price(item_id: String) -> int:
	match item_id:
		"Wood", "Stone": return 2
		"Iron Shard": return 8
	return 0

static func general_category(item_id: String) -> String:
	if CookingConfig.recipe_ids().has(item_id): return "Cooked food"
	match item_id:
		"Forest Herb", "Mushroom", "Moon Petal": return "Plant / ingredient"
		"Turkey", "Wolf Meat": return "Raw meat"
		"Iron Shard", "Stone", "Wood": return "Smithing / building material"
	return "Not traded"

static func rarity_name(value: Rarity) -> String:
	match value:
		Rarity.RARE: return "Rare"
		Rarity.VERY_RARE: return "Very Rare"
		_: return "Normal"

static func bag_color(value: Rarity) -> Color:
	match value:
		Rarity.RARE: return RARE_BAG_COLOR
		Rarity.VERY_RARE: return VERY_RARE_BAG_COLOR
		_: return NORMAL_BAG_COLOR
