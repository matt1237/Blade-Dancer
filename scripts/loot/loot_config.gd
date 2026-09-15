class_name LootConfig extends RefCounted

# =============================================================================
# LOOT TABLES — PRIMARY EDITING AREA
# This file owns enemy-to-item drop rules. Recipes and food effects belong in
# res://scripts/home/cooking_config.gd and should only refer to item names.
# =============================================================================

## Chance that a defeated Turkey drops one Turkey.
const TURKEY_DROP_CHANCE: float = 0.45
## Chance that a defeated Goblin drops one Mushroom.
const MUSHROOM_DROP_CHANCE: float = 0.40
## Chance that a defeated Wolf drops one Wolf Meat.
const WOLF_MEAT_DROP_CHANCE: float = 0.55

static func material_drop_for_enemy(enemy: Enemy, roll: float) -> String:
	return enemy.material_drop_for_roll(roll) if enemy != null else ""
