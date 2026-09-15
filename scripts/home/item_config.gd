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
