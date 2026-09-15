class_name BonusConfig extends RefCounted

# =============================================================================
# BONUS RANK TUNING — PRIMARY EDITING AREA
# Every array contains the complete value for Rank 1 through Rank 7.
# Edit these numbers and both gameplay and bonus-screen explanations update.
# Do not add a Rank 0 entry: Rank 0 means the bonus has not been acquired.
# =============================================================================
const MAX_RANK: int = 7
const BONUS_IDS: Array[String] = ["health", "chakram", "pierce", "explosion", "nova", "regen", "magnetic", "defense", "dash", "bash_dash", "grapple_mastery", "resonant_glyph", "voltage", "burning", "deflect", "moon", "flash", "disarm", "void", "chain", "vampirism", "adrenaline"]
const GRAPPLE_MAX_CHARGES_BY_RANK: Array[int] = [1, 1, 2, 2, 3, 3, 4]
const GRAPPLE_COOLDOWN_MULTIPLIER_BY_RANK: Array[float] = [1.0, 0.9, 0.8, 0.7, 0.62, 0.55, 0.48]
const GRAPPLE_RANGE_MULTIPLIER_BY_RANK: Array[float] = [1.0, 1.08, 1.16, 1.24, 1.32, 1.40, 1.50]

# --- RESONANT GLYPH ---
## Seconds between attempts to create the next safe glyph.
const RESONANT_GLYPH_COOLDOWN_BY_RANK: Array[float] = [10.0, 9.0, 8.0, 7.0, 6.0, 5.5, 5.0]
## Seconds each glyph remains in the arena.
const RESONANT_GLYPH_DURATION_BY_RANK: Array[float] = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0]
## Maximum number of glyphs that may coexist.
const RESONANT_GLYPH_MAX_ACTIVE_BY_RANK: Array[int] = [1, 1, 2, 2, 3, 3, 3]
## Radius of the enemy pulse released when a Chakram strikes a glyph.
const RESONANT_GLYPH_PULSE_RADIUS_BY_RANK: Array[float] = [120.0, 125.0, 130.0, 135.0, 140.0, 145.0, 150.0]
## Damage dealt to every enemy inside the pulse.
const RESONANT_GLYPH_PULSE_DAMAGE_BY_RANK: Array[float] = [10.0, 10.0, 11.0, 11.0, 12.0, 12.0, 13.0]
## Movement multiplier applied by the pulse. 0.90 means 10% slower.
const RESONANT_GLYPH_SLOW_MULTIPLIER_BY_RANK: Array[float] = [0.90, 0.90, 0.90, 0.89, 0.89, 0.88, 0.88]
const RESONANT_GLYPH_SLOW_DURATION_BY_RANK: Array[float] = [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0]

static func all_bonus_ids() -> Array[String]:
	return BONUS_IDS.duplicate()

# --- VITALITY ---
## Player maximum health at each rank. Base maximum health is 100.
const HEALTH_MAXIMUM_BY_RANK: Array[float] = [110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0]

# --- CHAKRAM FAMILY ---
## Total carried Chakram charges at each Chakram +1 rank. Base stock is 1.
const CHAKRAM_MAX_CHARGES_BY_RANK: Array[int] = [2, 3, 4, 5, 6, 7, 8]
## Number of enemies a Chakram can pass through before bouncing.
const CHAKRAM_PIERCE_BY_RANK: Array[int] = [1, 2, 3, 4, 5, 6, 7]
## Explosion radius in pixels after an armed Chakram hits an enemy.
const EXPLOSION_RADIUS_BY_RANK: Array[float] = [65.0, 93.0, 121.0, 149.0, 177.0, 205.0, 233.0]
## Explosion damage as a multiplier of normal Chakram damage.
const EXPLOSION_DAMAGE_MULTIPLIER_BY_RANK: Array[float] = [0.70, 0.95, 1.20, 1.45, 1.70, 1.95, 2.20]
## Magnetic Chakram turning speed in radians per second.
const MAGNETIC_TURN_RATE_BY_RANK: Array[float] = [0.55, 1.10, 1.65, 2.20, 2.75, 3.30, 3.85]

# --- FROST NOVA ---
## Radius in pixels of the Frost Nova released after the player is hit.
const FROST_NOVA_RADIUS_BY_RANK: Array[float] = [70.0, 85.0, 100.0, 115.0, 130.0, 150.0, 175.0]
## Seconds the enemy that hit the player remains frozen.
const FROST_NOVA_STUN_BY_RANK: Array[float] = [0.55, 0.70, 0.85, 1.00, 1.20, 1.40, 1.65]
## Seconds before Frost Nova can trigger again after creating an ice patch.
const FROST_NOVA_COOLDOWN_BY_RANK: Array[float] = [8.0, 7.25, 6.5, 5.75, 5.0, 4.25, 3.5]

# --- SUSTAIN AND DEFENSE ---
## Health restored per second by Regeneration.
const REGENERATION_PER_SECOND_BY_RANK: Array[float] = [0.33, 0.66, 1.00, 1.33, 1.66, 2.00, 2.5]
## Flat damage removed from every incoming hit.
const DEFENSE_REDUCTION_BY_RANK: Array[float] = [2.0, 4.0, 6.0, 8.0, 10.0, 11.0, 12.0]
## Health restored after each kill.
const VAMPIRISM_HEAL_BY_RANK: Array[float] = [1, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]

# --- DASH AND MOBILITY ---
## Maximum stored dash charges. Repeated values still improve cooldown below.
const DASH_MAX_CHARGES_BY_RANK: Array[int] = [2, 2, 3, 3, 4, 4, 5]
## Multiplies the normal dash recharge time. 0.55 means 45% faster recharge.
const DASH_COOLDOWN_MULTIPLIER_BY_RANK: Array[float] = [1.00, 0.90, 0.82, 0.75, 0.68, 0.61, 0.55]
## Multiplies Flash Step displacement distance.
const FLASH_STEP_DISTANCE_MULTIPLIER_BY_RANK: Array[float] = [1.00, 1.10, 1.20, 1.30, 1.40, 1.50, 1.60]
## Void-well pull radius created after dashing.
const VOID_DASH_RADIUS_BY_RANK: Array[float] = [180.0, 260.0, 340.0, 420.0, 500.0, 580.0, 660.0]

# Bash Dash triggers when a dash path contacts an enemy.
const BASH_DASH_DAMAGE_BY_RANK: Array[float] = [8.0, 11.0, 14.0, 17.0, 20.0, 23.0, 26.0]
const BASH_DASH_KNOCKBACK_BY_RANK: Array[float] = [180.0, 220.0, 260.0, 300.0, 340.0, 380.0, 420.0]
const BASH_DASH_STUN_BY_RANK: Array[float] = [0.20, 0.26, 0.32, 0.38, 0.44, 0.50, 0.60]

# --- BLADE STATUS EFFECTS ---
## Chance for a sword or Chakram contact to electrify an enemy.
const VOLTAGE_CHANCE_BY_RANK: Array[float] = [0.10, 0.14, 0.18, 0.22, 0.26, 0.30, 0.35]
## Total seconds the Electrified status remains active after it is applied.
const VOLTAGE_DURATION_BY_RANK: Array[float] = [5.0, 5.5, 6.0, 6.5, 7.0, 7.5, 8.0]
## Seconds between Electrified stun rolls. Lower values roll more frequently.
const VOLTAGE_TICK_INTERVAL_BY_RANK: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
## Chance on each Electrified tick to briefly stun the affected enemy.
const VOLTAGE_STUN_CHANCE_BY_RANK: Array[float] = [0.20, 0.23, 0.26, 0.29, 0.32, 0.36, 0.40]
## Seconds an enemy is unable to act after a successful Electrified stun roll.
const VOLTAGE_STUN_DURATION_BY_RANK: Array[float] = [0.55, 0.60, 0.65, 0.70, 0.75, 0.80, 0.90]

## Chance for a sword hit to ignite an enemy.
const BURN_CHANCE_BY_RANK: Array[float] = [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40]
## Total seconds the Burning status remains active after ignition.
const BURN_DURATION_BY_RANK: Array[float] = [6.5, 8.0, 9.5, 11.0, 12.5, 14.0, 14.0]
## Damage dealt by every Burning tick.
const BURN_DAMAGE_PER_TICK_BY_RANK: Array[float] = [2.0, 4.0, 6.0, 6.0, 7.0, 7.0, 7.0]
## Seconds between Burning damage ticks. Lower values deal damage more frequently.
const BURN_TICK_INTERVAL_BY_RANK: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
## Delay before Burning deals its first damage tick after ignition.
const BURN_INITIAL_TICK_DELAY_BY_RANK: Array[float] = [0.20, 0.20, 0.20, 0.20, 0.20, 0.20, 0.20]
## Chance for a successful Duelist parry interaction to disarm the enemy.
const DISARM_CHANCE_BY_RANK: Array[float] = [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40]

# --- DEFLECT AND SWORD ABILITIES ---
## Maximum projectile-deflect charges.
const DEFLECT_MAX_CHARGES_BY_RANK: Array[int] = [1, 2, 3, 4, 5, 6, 7]
## Seconds required to restore one projectile-deflect charge.
const DEFLECT_RECHARGE_BY_RANK: Array[float] = [5.0, 4.5, 4.0, 3.5, 3.0, 2.5, 2.0]
## Damage dealt by one Moon Slash.
const MOON_SLASH_DAMAGE_BY_RANK: Array[float] = [28.0, 36.0, 44.0, 52.0, 60.0, 68.0, 76.0]
## Number of sword swings required between Moon Slash releases.
const MOON_SLASH_SWINGS_BY_RANK: Array[int] = [7, 5, 3, 3, 3, 3, 3]

# --- CHAIN LIGHTNING ---
## Damage dealt by each lightning segment.
const CHAIN_LIGHTNING_DAMAGE_BY_RANK: Array[float] = [17.0, 24.0, 31.0, 38.0, 45.0, 52.0, 59.0]
## Seconds between chain-lightning pulses. Lower values trigger more often.
const CHAIN_LIGHTNING_INTERVAL_BY_RANK: Array[float] = [1.15, 0.97, 0.79, 0.61, 0.45, 0.40, 0.35]

# --- ADRENALINE ---
## Flow percentage where Adrenaline begins slowing enemies.
const ADRENALINE_THRESHOLD_BY_RANK: Array[float] = [90, 90.0, 90.0, 85.0, 80.0, 75.0, 75.0]
## Enemy slowdown at the activation threshold.
const ADRENALINE_BASE_SLOW_BY_RANK: Array[float] = [0.15, 0.15, 0.15, 0.15, 0.15, 0.15, 0.20]
## Enemy slowdown at 100 Flow. Rank 7 scales from 15% to 20%.
const ADRENALINE_MAX_SLOW_BY_RANK: Array[float] = [0.15, 0.16, 0.17, 0.18, 0.19, 0.20, 0.25]

# =============================================================================
# RANK LOOKUP AND APPLICATION
# =============================================================================
static func rank(player: Player, bonus_id: String) -> int:
	match bonus_id:
		"health": return player.health_bonus_rank
		"chakram": return player.chakram_charge_rank
		"pierce": return player.chakram_pierce
		"explosion": return player.chakram_explosion_level
		"nova": return player.frost_nova_rank
		"regen": return player.regeneration_rank
		"magnetic": return player.magnetic_level
		"defense": return player.defense_rank
		"dash": return player.dash_bonus_rank
		"bash_dash": return player.bash_dash_rank
		"grapple_mastery": return player.grapple_mastery_rank
		"resonant_glyph": return player.resonant_glyph_rank
		"voltage": return player.voltage_rank
		"burning": return player.burning_rank
		"deflect": return player.deflect_rank
		"moon": return player.moon_slash_rank
		"flash": return player.flash_step_rank
		"disarm": return player.disarm_rank
		"void": return player.void_dash_level
		"chain": return player.chain_lightning_level
		"vampirism": return player.vampirism_rank
		"adrenaline": return player.adrenaline_rank
		_: return 0

static func set_rank(player: Player, bonus_id: String, rank_value: int) -> void:
	var clamped_rank: int = clampi(rank_value, 0, MAX_RANK)
	var old_chakram_max: int = player.max_chakram_charges
	var old_dash_max: int = player.max_dash_charges
	var old_deflect_max: int = deflect_max_charges(player.deflect_rank)
	var old_health_max: float = player.max_health
	match bonus_id:
		"health": player.health_bonus_rank = clamped_rank
		"chakram": player.chakram_charge_rank = clamped_rank
		"pierce": player.chakram_pierce = clamped_rank
		"explosion": player.chakram_explosion_level = clamped_rank
		"nova": player.frost_nova_rank = clamped_rank
		"regen": player.regeneration_rank = clamped_rank
		"magnetic": player.magnetic_level = clamped_rank
		"defense": player.defense_rank = clamped_rank
		"dash": player.dash_bonus_rank = clamped_rank
		"bash_dash": player.bash_dash_rank = clamped_rank
		"grapple_mastery": player.grapple_mastery_rank = clamped_rank
		"resonant_glyph":
			player.resonant_glyph_rank = clamped_rank
			player.reset_resonant_glyph_timer()
		"voltage":
			player.voltage_enabled = clamped_rank > 0
			player.voltage_rank = clamped_rank
		"burning": player.burning_rank = clamped_rank
		"deflect": player.deflect_rank = clamped_rank
		"moon": player.moon_slash_rank = clamped_rank
		"flash":
			player.flash_step_enabled = clamped_rank > 0
			player.flash_step_rank = clamped_rank
		"disarm": player.disarm_rank = clamped_rank
		"void": player.void_dash_level = clamped_rank
		"chain": player.chain_lightning_level = clamped_rank
		"vampirism": player.vampirism_rank = clamped_rank
		"adrenaline": player.adrenaline_rank = clamped_rank
	player.max_health = health_maximum(player.health_bonus_rank) + player.expedition_food_health_bonus
	if player.max_health > old_health_max:
		player.health = minf(player.max_health, player.health + (player.max_health - old_health_max))
	else:
		player.health = minf(player.health, player.max_health)
	player.max_chakram_charges = chakram_max_charges(player.chakram_charge_rank)
	if player.max_chakram_charges > old_chakram_max:
		player.chakram_charges = mini(player.max_chakram_charges, player.chakram_charges + (player.max_chakram_charges - old_chakram_max))
	else:
		player.chakram_charges = mini(player.chakram_charges, player.max_chakram_charges)
	player.max_dash_charges = dash_max_charges(player.dash_bonus_rank)
	if player.max_dash_charges > old_dash_max:
		player.dash_charges = mini(player.max_dash_charges, player.dash_charges + (player.max_dash_charges - old_dash_max))
	else:
		player.dash_charges = mini(player.dash_charges, player.max_dash_charges)
	var new_deflect_max: int = deflect_max_charges(player.deflect_rank)
	if new_deflect_max > old_deflect_max:
		player.deflect_charges = mini(new_deflect_max, player.deflect_charges + (new_deflect_max - old_deflect_max))
		player.deflect_recharge_left = deflect_recharge(player.deflect_rank)
	else:
		player.deflect_charges = mini(player.deflect_charges, new_deflect_max)
	player._synchronize_rank_zero_bonus_state()
	player.health_changed.emit(player.health, player.max_health)

static func can_upgrade(player: Player, bonus_id: String) -> bool:
	return rank(player, bonus_id) < MAX_RANK

static func apply_to_player(player: Player, bonus_id: String) -> void:
	var current_rank: int = rank(player, bonus_id)
	if current_rank >= MAX_RANK: return
	var next_rank: int = current_rank + 1
	match bonus_id:
		"health":
			var old_maximum: float = player.max_health
			player.health_bonus_rank = next_rank
			player.max_health = health_maximum(next_rank) + player.expedition_food_health_bonus
			player.health = minf(player.max_health, player.health + maxf(0.0, player.max_health - old_maximum))
			player.health_bar.max_value = player.max_health
			player.health_bar.value = player.health
			player.health_changed.emit(player.health, player.max_health)
		"chakram":
			var old_charges: int = player.max_chakram_charges
			player.chakram_charge_rank = next_rank
			player.max_chakram_charges = chakram_max_charges(next_rank)
			player.chakram_charges = mini(player.max_chakram_charges, player.chakram_charges + maxi(0, player.max_chakram_charges - old_charges))
		"pierce": player.chakram_pierce = next_rank
		"explosion": player.chakram_explosion_level = next_rank
		"nova":
			player.frost_nova_rank = next_rank
			player.frost_nova_enabled = true
		"regen":
			player.regeneration_rank = next_rank
			player.regeneration_enabled = true
		"magnetic": player.magnetic_level = next_rank
		"defense": player.defense_rank = next_rank
		"dash":
			var old_dash_charges: int = player.max_dash_charges
			player.dash_bonus_rank = next_rank
			player.max_dash_charges = dash_max_charges(next_rank)
			player.dash_charges = mini(player.max_dash_charges, player.dash_charges + maxi(0, player.max_dash_charges - old_dash_charges))
		"bash_dash": player.bash_dash_rank = next_rank
		"grapple_mastery": player.grapple_mastery_rank = next_rank
		"resonant_glyph":
			player.resonant_glyph_rank = next_rank
			player.reset_resonant_glyph_timer()
		"voltage":
			player.voltage_rank = next_rank
			player.voltage_enabled = true
		"burning": player.burning_rank = next_rank
		"deflect":
			var old_deflect_charges: int = deflect_max_charges(player.deflect_rank)
			player.deflect_rank = next_rank
			var new_deflect_charges: int = deflect_max_charges(next_rank)
			player.deflect_charges = mini(new_deflect_charges, player.deflect_charges + maxi(0, new_deflect_charges - old_deflect_charges))
			player.deflect_recharge_left = deflect_recharge(next_rank)
		"moon": player.moon_slash_rank = next_rank
		"flash":
			player.flash_step_rank = next_rank
			player.flash_step_enabled = true
		"disarm": player.disarm_rank = next_rank
		"void": player.void_dash_level = next_rank
		"chain": player.chain_lightning_level = next_rank
		"vampirism": player.vampirism_rank = next_rank
		"adrenaline": player.adrenaline_rank = next_rank

# =============================================================================
# GAMEPLAY VALUE ACCESSORS — gameplay and UI both call these functions.
# =============================================================================
static func _rank_value(values: Array, rank_value: int, base_value: Variant) -> Variant:
	if rank_value <= 0: return base_value
	return values[clampi(rank_value, 1, MAX_RANK) - 1]

static func health_maximum(rank_value: int) -> float: return float(_rank_value(HEALTH_MAXIMUM_BY_RANK, rank_value, 100.0))
static func chakram_max_charges(rank_value: int) -> int: return int(_rank_value(CHAKRAM_MAX_CHARGES_BY_RANK, rank_value, 1))
static func explosion_radius(rank_value: int) -> float: return float(_rank_value(EXPLOSION_RADIUS_BY_RANK, rank_value, 0.0))
static func explosion_damage_multiplier(rank_value: int) -> float: return float(_rank_value(EXPLOSION_DAMAGE_MULTIPLIER_BY_RANK, rank_value, 0.0))
static func magnetic_turn_rate(rank_value: int) -> float: return float(_rank_value(MAGNETIC_TURN_RATE_BY_RANK, rank_value, 0.0))
static func frost_nova_radius(rank_value: int) -> float: return float(_rank_value(FROST_NOVA_RADIUS_BY_RANK, rank_value, 0.0))
static func frost_nova_stun(rank_value: int) -> float: return float(_rank_value(FROST_NOVA_STUN_BY_RANK, rank_value, 0.0))
static func frost_nova_cooldown(rank_value: int) -> float: return float(_rank_value(FROST_NOVA_COOLDOWN_BY_RANK, rank_value, 0.0))
static func regeneration_per_second(rank_value: int) -> float: return float(_rank_value(REGENERATION_PER_SECOND_BY_RANK, rank_value, 0.0))
static func defense_reduction(rank_value: int) -> float: return float(_rank_value(DEFENSE_REDUCTION_BY_RANK, rank_value, 0.0))
static func vampirism_heal(rank_value: int) -> float: return float(_rank_value(VAMPIRISM_HEAL_BY_RANK, rank_value, 0.0))
static func dash_max_charges(rank_value: int) -> int: return int(_rank_value(DASH_MAX_CHARGES_BY_RANK, rank_value, 1))
static func dash_cooldown_multiplier(rank_value: int) -> float: return float(_rank_value(DASH_COOLDOWN_MULTIPLIER_BY_RANK, rank_value, 1.0))
static func grapple_max_charges(rank_value: int) -> int: return int(_rank_value(GRAPPLE_MAX_CHARGES_BY_RANK, rank_value, 1))
static func grapple_cooldown_multiplier(rank_value: int) -> float: return float(_rank_value(GRAPPLE_COOLDOWN_MULTIPLIER_BY_RANK, rank_value, 1.0))
static func grapple_range_multiplier(rank_value: int) -> float: return float(_rank_value(GRAPPLE_RANGE_MULTIPLIER_BY_RANK, rank_value, 1.0))
static func resonant_glyph_cooldown(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_COOLDOWN_BY_RANK, rank_value, 0.0))
static func resonant_glyph_duration(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_DURATION_BY_RANK, rank_value, 0.0))
static func resonant_glyph_max_active(rank_value: int) -> int: return int(_rank_value(RESONANT_GLYPH_MAX_ACTIVE_BY_RANK, rank_value, 0))
static func resonant_glyph_pulse_radius(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_PULSE_RADIUS_BY_RANK, rank_value, 0.0))
static func resonant_glyph_pulse_damage(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_PULSE_DAMAGE_BY_RANK, rank_value, 0.0))
static func resonant_glyph_slow_multiplier(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_SLOW_MULTIPLIER_BY_RANK, rank_value, 1.0))
static func resonant_glyph_slow_duration(rank_value: int) -> float: return float(_rank_value(RESONANT_GLYPH_SLOW_DURATION_BY_RANK, rank_value, 0.0))
static func flash_step_distance_multiplier(rank_value: int) -> float: return float(_rank_value(FLASH_STEP_DISTANCE_MULTIPLIER_BY_RANK, rank_value, 1.0))
static func void_dash_radius(rank_value: int) -> float: return float(_rank_value(VOID_DASH_RADIUS_BY_RANK, rank_value, 0.0))
static func bash_dash_damage(rank_value: int) -> float: return float(_rank_value(BASH_DASH_DAMAGE_BY_RANK, rank_value, 0.0))
static func bash_dash_knockback(rank_value: int) -> float: return float(_rank_value(BASH_DASH_KNOCKBACK_BY_RANK, rank_value, 0.0))
static func bash_dash_stun(rank_value: int) -> float: return float(_rank_value(BASH_DASH_STUN_BY_RANK, rank_value, 0.0))
static func voltage_chance(rank_value: int) -> float: return float(_rank_value(VOLTAGE_CHANCE_BY_RANK, rank_value, 0.0))
static func voltage_duration(rank_value: int) -> float: return float(_rank_value(VOLTAGE_DURATION_BY_RANK, rank_value, 0.0))
static func voltage_tick_interval(rank_value: int) -> float: return float(_rank_value(VOLTAGE_TICK_INTERVAL_BY_RANK, rank_value, 0.0))
static func voltage_stun_chance(rank_value: int) -> float: return float(_rank_value(VOLTAGE_STUN_CHANCE_BY_RANK, rank_value, 0.0))
static func voltage_stun_duration(rank_value: int) -> float: return float(_rank_value(VOLTAGE_STUN_DURATION_BY_RANK, rank_value, 0.0))
static func burn_chance(rank_value: int) -> float: return float(_rank_value(BURN_CHANCE_BY_RANK, rank_value, 0.0))
static func burn_duration(rank_value: int) -> float: return float(_rank_value(BURN_DURATION_BY_RANK, rank_value, 0.0))
static func burn_damage_per_tick(rank_value: int) -> float: return float(_rank_value(BURN_DAMAGE_PER_TICK_BY_RANK, rank_value, 0.0))
static func burn_tick_interval(rank_value: int) -> float: return float(_rank_value(BURN_TICK_INTERVAL_BY_RANK, rank_value, 0.0))
static func burn_initial_tick_delay(rank_value: int) -> float: return float(_rank_value(BURN_INITIAL_TICK_DELAY_BY_RANK, rank_value, 0.0))
static func disarm_chance(rank_value: int) -> float: return float(_rank_value(DISARM_CHANCE_BY_RANK, rank_value, 0.0))
static func deflect_max_charges(rank_value: int) -> int: return int(_rank_value(DEFLECT_MAX_CHARGES_BY_RANK, rank_value, 0))
static func deflect_recharge(rank_value: int) -> float: return float(_rank_value(DEFLECT_RECHARGE_BY_RANK, rank_value, 0.0))
static func moon_slash_damage(rank_value: int) -> float: return float(_rank_value(MOON_SLASH_DAMAGE_BY_RANK, rank_value, 0.0))
static func moon_slash_swings(rank_value: int) -> int: return int(_rank_value(MOON_SLASH_SWINGS_BY_RANK, rank_value, 0))
static func chain_lightning_damage(rank_value: int) -> float: return float(_rank_value(CHAIN_LIGHTNING_DAMAGE_BY_RANK, rank_value, 0.0))
static func chain_lightning_interval(rank_value: int) -> float: return float(_rank_value(CHAIN_LIGHTNING_INTERVAL_BY_RANK, rank_value, 0.0))
static func adrenaline_threshold(rank_value: int) -> float: return float(_rank_value(ADRENALINE_THRESHOLD_BY_RANK, rank_value, 100.0))

static func adrenaline_slow(rank_value: int, current_flow: float = 100.0) -> float:
	if rank_value <= 0: return 0.0
	var base_slow: float = float(_rank_value(ADRENALINE_BASE_SLOW_BY_RANK, rank_value, 0.0))
	var maximum_slow: float = float(_rank_value(ADRENALINE_MAX_SLOW_BY_RANK, rank_value, 0.0))
	var threshold: float = adrenaline_threshold(rank_value)
	var progress: float = clampf((current_flow - threshold) / maxf(1.0, 100.0 - threshold), 0.0, 1.0)
	return lerpf(base_slow, maximum_slow, progress)

# =============================================================================
# BONUS SCREEN TEXT — all displayed numbers come from the accessors above.
# =============================================================================
static func display_name(bonus_id: String) -> String:
	match bonus_id:
		"health": return "Vitality"
		"chakram": return "Chakram +1"
		"pierce": return "Chakram Pierce"
		"explosion": return "Chakram Fireball"
		"nova": return "Frost Nova"
		"regen": return "Regeneration"
		"magnetic": return "Magnetic Chakram"
		"defense": return "Defense"
		"dash": return "Dash Mastery"
		"bash_dash": return "Bash Dash"
		"grapple_mastery": return "Grapple Mastery"
		"resonant_glyph": return "Resonant Glyph"
		"voltage": return "Voltage"
		"burning": return "Burning Blade"
		"deflect": return "Projectile Deflect"
		"moon": return "Moon Slash"
		"flash": return "Flash Step"
		"disarm": return "Disarm"
		"void": return "Void Dash"
		"chain": return "Chain Lightning"
		"vampirism": return "Vampirism"
		"adrenaline": return "Adrenaline"
		_: return bonus_id.capitalize()

static func description(bonus_id: String) -> String:
	match bonus_id:
		"health": return "Raises maximum health and immediately heals the amount gained."
		"chakram": return "Adds one carried Chakram charge at every rank."
		"pierce": return "Lets airborne Chakrams pass through more enemies before bouncing."
		"explosion": return "Arms batted Chakrams with a damaging area explosion."
		"nova": return "When an enemy hits you, freeze that attacker and create an icy patch. Enemies and the player slide while crossing it."
		"regen": return "Continuously restores health while the player is alive."
		"magnetic": return "Turns airborne Chakrams gradually toward nearby enemies without reversing them."
		"defense": return "Removes flat damage from every incoming hit before health is lost."
		"dash": return "Improves stored dash charges and shortens their recharge time."
		"bash_dash": return "Dashing through an enemy deals damage, knocks them back, and briefly stuns them."
		"grapple_mastery": return "Balances grapple charges, cooldown reduction, and tether range."
		"resonant_glyph": return "Creates animated glyph obstructions. A Chakram bounce releases a damaging, slowing soundwave."
		"voltage": return "Sword and Chakram contacts can Electrify an enemy. While Electrified, the enemy repeatedly rolls a chance to be briefly stunned."
		"burning": return "Sword hits can ignite an enemy. While Burning, the enemy repeatedly takes damage until the listed duration expires."
		"deflect": return "Adds rechargeable charges used to reflect enemy projectiles with the sword."
		"moon": return "Periodically releases a ranged cutting wave during sword swings."
		"flash": return "Transforms a normal dash into an instant displacement with increasing range."
		"disarm": return "Adds a chance to knock the spear from a parrying Duelist."
		"void": return "Creates a pulling void well at the end of a dash."
		"chain": return "Sends damaging lightning between multiple airborne Chakrams."
		"vampirism": return "Restores health whenever an enemy is defeated."
		"adrenaline": return "Slows enemies while Flow remains above the listed activation threshold."
		_: return "No description is available yet."

static func choice_title(bonus_id: String, player: Player) -> String:
	var next_rank: int = mini(MAX_RANK, rank(player, bonus_id) + 1)
	return "%s  |  Rank %d / %d" % [display_name(bonus_id), next_rank, MAX_RANK]

static func title(bonus_id: String, player: Player) -> String:
	return choice_title(bonus_id, player)

static func comparison_bbcode(bonus_id: String, player: Player) -> String:
	var current_rank: int = rank(player, bonus_id)
	var next_rank: int = mini(MAX_RANK, current_rank + 1)
	var current_text: String = value_text(bonus_id, current_rank)
	var next_text: String = value_text(bonus_id, next_rank)
	return "[color=#9cb4cc]Current R%d:[/color] [i][u]%s[/u][/i]   [color=#ffd94d]Next R%d:[/color] [i][u]%s[/u][/i]" % [current_rank, current_text, next_rank, next_text]

static func tooltip_bbcode(bonus_id: String, player: Player) -> String:
	var text: String = "[font_size=22][color=#ffd94d][b]%s[/b][/color][/font_size]\n" % display_name(bonus_id)
	text += "[color=#d6e2ee]%s[/color]\n\n" % description(bonus_id)
	text += comparison_bbcode(bonus_id, player) + "\n\n"
	text += "[color=#8fdcff][b]RANK PROGRESSION[/b][/color]\n"
	for rank_value: int in range(1, MAX_RANK + 1):
		var rank_color: String = "#ffd94d" if rank_value == mini(MAX_RANK, rank(player, bonus_id) + 1) else "#b9c7d6"
		text += "[color=%s]R%d:[/color] %s\n" % [rank_color, rank_value, value_text(bonus_id, rank_value)]
	return text

static func value_text(bonus_id: String, rank_value: int) -> String:
	match bonus_id:
		"health": return "%.0f maximum HP" % health_maximum(rank_value)
		"chakram": return "%d total charges" % chakram_max_charges(rank_value)
		"pierce": return "%d pierces" % int(_rank_value(CHAKRAM_PIERCE_BY_RANK, rank_value, 0))
		"explosion": return "%.0fpx radius, %s damage" % [explosion_radius(rank_value), _percent(explosion_damage_multiplier(rank_value))]
		"nova": return "%.0fpx ice radius, %ss freeze, %ss cooldown" % [frost_nova_radius(rank_value), _number(frost_nova_stun(rank_value)), _number(frost_nova_cooldown(rank_value))]
		"regen": return "%s HP per second" % _number(regeneration_per_second(rank_value))
		"magnetic": return "%s rad/s turning" % _number(magnetic_turn_rate(rank_value))
		"defense": return "%s flat damage reduction" % _number(defense_reduction(rank_value))
		"dash": return "%d charges, %s recharge time" % [dash_max_charges(rank_value), _percent(dash_cooldown_multiplier(rank_value))]
		"bash_dash": return "%s damage, %s knockback, %ss stun" % [_number(bash_dash_damage(rank_value)), _number(bash_dash_knockback(rank_value)), _number(bash_dash_stun(rank_value))]
		"grapple_mastery": return "%d charges, %s cooldown, %s range" % [grapple_max_charges(rank_value), _percent(grapple_cooldown_multiplier(rank_value)), _percent(grapple_range_multiplier(rank_value))]
		"resonant_glyph": return "%d active, %ss lifetime, %ss cooldown, %s pulse slow" % [resonant_glyph_max_active(rank_value), _number(resonant_glyph_duration(rank_value)), _number(resonant_glyph_cooldown(rank_value)), _percent(1.0 - resonant_glyph_slow_multiplier(rank_value))]
		"voltage": return "%s apply chance, %ss status, %s stun roll every %ss, %ss stun" % [_percent(voltage_chance(rank_value)), _number(voltage_duration(rank_value)), _percent(voltage_stun_chance(rank_value)), _number(voltage_tick_interval(rank_value)), _number(voltage_stun_duration(rank_value))]
		"burning": return "%s ignite chance, %ss status, %s damage every %ss (first tick after %ss)" % [_percent(burn_chance(rank_value)), _number(burn_duration(rank_value)), _number(burn_damage_per_tick(rank_value)), _number(burn_tick_interval(rank_value)), _number(burn_initial_tick_delay(rank_value))]
		"deflect": return "%d charges, %ss recharge" % [deflect_max_charges(rank_value), _number(deflect_recharge(rank_value))]
		"moon": return "%s damage every %d swings" % [_number(moon_slash_damage(rank_value)), moon_slash_swings(rank_value)]
		"flash": return "%s dash distance" % _percent(flash_step_distance_multiplier(rank_value))
		"disarm": return "%s disarm chance" % _percent(disarm_chance(rank_value))
		"void": return "%.0fpx pull radius" % void_dash_radius(rank_value)
		"chain": return "%s damage every %ss" % [_number(chain_lightning_damage(rank_value)), _number(chain_lightning_interval(rank_value))]
		"vampirism": return "%s HP healed per kill" % _number(vampirism_heal(rank_value))
		"adrenaline":
			var base_slow: float = float(_rank_value(ADRENALINE_BASE_SLOW_BY_RANK, rank_value, 0.0))
			var max_slow: float = float(_rank_value(ADRENALINE_MAX_SLOW_BY_RANK, rank_value, 0.0))
			return "%s-%s slow above %.0f%% Flow" % [_percent(base_slow), _percent(max_slow), adrenaline_threshold(rank_value)]
		_: return "Not acquired" if rank_value <= 0 else "Rank %d active" % rank_value

static func _number(value: float) -> String:
	return String.num(value, 0) if is_equal_approx(value, roundf(value)) else String.num(value, 2).trim_suffix("0")

static func _percent(value: float) -> String:
	return "%s%%" % _number(value * 100.0)
