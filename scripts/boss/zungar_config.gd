class_name ZungarConfig extends RefCounted

# =============================================================================
# ZUNGAR BOSS TUNING — PRIMARY EDITING AREA
# Times are seconds, distances are pixels, chances use 0.0–1.0 percentages.
# =============================================================================

# =============================================================================
# QUICK TUNE — health, damage, knockback, pacing
# The values changed most often live here. Per-ability detail follows below.
# =============================================================================

## Wave Zungar replaces the normal Forest wave on.
const BOSS_WAVE: int = 20
## Zungar's total health.
const MAX_HEALTH: float = 500.0
## Score awarded on defeat.
const SCORE_VALUE: int = 5000

# --- Damage dealt to the PLAYER, per ability (before the per-wave multiplier) -
const CONTACT_DAMAGE: float = 15.0            ## touching his body
const EXECUTIONER_SWORD_DAMAGE: float = 18.0  ## the metronome sword
const CHARGE_DAMAGE: float = 20.0             ## charging shoulder-first
const JUMP_SLAM_DAMAGE: float = 20.0          ## landing from the leap
const SPEAR_DAMAGE: float = 28.0              ## thrown spear
const FIRE_BONUS_DAMAGE: float = 1.75         ## extra damage per hit while he burns

# --- Knockback impulse each hit puts on the player (pixels/second) ----------
const CONTACT_KNOCKBACK: float = 260.0
const EXECUTIONER_SWORD_KNOCKBACK: float = 300.0
const CHARGE_KNOCKBACK: float = 340.0
const JUMP_SLAM_KNOCKBACK: float = 360.0
const TREE_THROW_KNOCKBACK: float = 300.0

# --- How close the player must be for a hit to land (pixels) ----------------
const CONTACT_RANGE: float = 43.5
const CHARGE_CONTACT_RANGE: float = 36.0
const TREE_THROW_RADIUS: float = 105.0

# --- Ability pacing and phases ----------------------------------------------
## Minimum seconds between two major abilities.
const ABILITY_INTERVAL: float = 5.0
## Health ratio at which he speeds up (0.5 = half health).
const AGGRESSIVE_HEALTH_RATIO: float = 0.5
## How much faster his timings run once aggressive.
const AGGRESSIVE_SPEED_MULTIPLIER: float = 1.2

# =============================================================================
# BODY, MOVEMENT, ARENA
# =============================================================================
const BODY_RADIUS: float = 22.5
const BODY_SCALE: float = 0.186
const VISUAL_SCALE: float = 0.975
const BODY_COLLISION_RADIUS: float = 19.5
const BODY_COLLISION_HEIGHT: float = 77.25

const CHASE_SPEED: float = 135.0
const ARENA_LEFT: float = 52.0
const ARENA_RIGHT: float = 1228.0
const ARENA_TOP: float = 52.0
const ARENA_BOTTOM: float = 668.0

# =============================================================================
# EXECUTIONER SWORD (persistent, metronoming, parryable)
# Hilt, visible sprite, damage line, and parry checks all consume the same
# origin + reach values, so the painted sword always matches its hitbox.
# =============================================================================
## Distance from Zungar's center to the painted hand/blade origin.
## Keep this aligned with the shared _enemy_weapon_segment() collision start.
const EXECUTIONER_SWORD_ORIGIN_OFFSET: float = 14.25
const EXECUTIONER_SWORD_REACH: float = 81.0
const EXECUTIONER_SWORD_HIT_RADIUS: float = 25.2
const EXECUTIONER_SWORD_HIT_COOLDOWN: float = 0.65
const EXECUTIONER_SWORD_METRONOME_SPEED: float = 0.5
const EXECUTIONER_SWORD_METRONOME_ARC_DEGREES: float = 50.0
const EXECUTIONER_SWORD_DRAW_SCALE: float = 1.0
# Compatibility aliases for older tests/tools and saved references.
const CLUB_REACH: float = EXECUTIONER_SWORD_REACH
const CLUB_DAMAGE: float = EXECUTIONER_SWORD_DAMAGE
const CLUB_HIT_RADIUS: float = EXECUTIONER_SWORD_HIT_RADIUS
const CLUB_HIT_COOLDOWN: float = EXECUTIONER_SWORD_HIT_COOLDOWN
const CLUB_METRONOME_SPEED: float = EXECUTIONER_SWORD_METRONOME_SPEED
const CLUB_METRONOME_ARC_DEGREES: float = EXECUTIONER_SWORD_METRONOME_ARC_DEGREES

# =============================================================================
# CHARGE (speed deliberately untouched — tune damage/knockback in QUICK TUNE)
# =============================================================================
const CHARGE_DISTANCE: float = 520.0
const CHARGE_SPEED: float = 660.0
const CHARGE_WINDUP_DURATION: float = 2.0
const CHARGE_RECOVERY_DURATION: float = 1.0
const CHARGE_TREE_STUN_DURATION: float = 2.5
const CHARGE_START_SPEED_RATIO: float = 0.2
const CHARGE_ACCELERATION_DURATION: float = 0.34
const CHARGE_DECELERATION_DISTANCE: float = 78.0
const CHARGE_DIRT_WINDUP_RATE: float = 22.0
const CHARGE_DIRT_TRAVEL_RATE: float = 38.0

# =============================================================================
# JUMP SLAM
# =============================================================================
const JUMP_SLAM_WARNING_DURATION: float = 2.5
const JUMP_SLAM_TRAVEL_DURATION: float = 1.5
const JUMP_HEIGHT: float = 520.0
const JUMP_SLAM_RADIUS: float = 82.0
const JUMP_SLAM_RECOVERY_DURATION: float = 1.5

# =============================================================================
# SPEAR
# =============================================================================
const SPEAR_THROW_INTERVAL: float = 2.0
const SPEAR_MODE_COOLDOWN: float = 7.0
const SPEAR_MODE_DURATION: float = 8.0

# =============================================================================
# FIRE STOMP, CAMPFIRE, FIRE SWORD
# =============================================================================
const FIRE_STOMP_TAUNT_DURATION: float = 1.0
const FIRE_STOMP_RECOVERY: float = 0.6
const FIRE_REACTION_DURATION: float = 2.5
const CAMPFIRE_DISABLED_DURATION: float = 3.0
const CAMPFIRE_IGNITION_RADIUS: float = 58.0
const SWORD_FIRE_DURATION: float = 9.0

# =============================================================================
# SUMMONS (allies he yells for)
# A cast fills vacant slots up to SUMMON_MAX_ALIVE: the first cast therefore
# creates three; later casts may replace defeated adds without exceeding the cap.
# =============================================================================
## Seconds between summon casts.
const SUMMON_COOLDOWN: float = 20.0
## Seconds after the fight starts before the first summon cast.
const SUMMON_START_DELAY: float = 20.0
## Wind-up length before the allies actually appear.
const SUMMON_CAST_DURATION: float = 0.9
## Never more than this many allies alive at once.
const SUMMON_MAX_ALIVE: int = 3
const SUMMON_BARK: String = "Get in here you idiots"
## Where allies emerge from — the cave mouth in the Forest arena.
const SUMMON_ENTRANCE_POSITION: Vector2 = Vector2(640.0, 118.0)
## How far they walk out of the cave before they engage (pixels).
const SUMMON_ENTRANCE_TRAVEL: float = 100.0
## Horizontal spacing between allies walking out together.
const SUMMON_ENTRANCE_SPACING: float = 70.0
## How fast they walk out of the cave (pixels/second).
const SUMMON_ENTRANCE_SPEED: float = 95.0

# =============================================================================
# FRIENDLY FIRE (Zungar hitting his own allies)
# =============================================================================
const FRIENDLY_FIRE_BARK: String = "Get out of my way!"
const FRIENDLY_FIRE_BARK_COOLDOWN: float = 1.6
const FRIENDLY_SWORD_DAMAGE: float = 26.0
const FRIENDLY_CHARGE_DAMAGE: float = 20.0
const FRIENDLY_JUMP_DAMAGE: float = 20.0
const FRIENDLY_SPEAR_DAMAGE: float = 28.0
const FRIENDLY_SWORD_KNOCKBACK: float = 260.0
const FRIENDLY_CHARGE_KNOCKBACK: float = 330.0
const FRIENDLY_JUMP_KNOCKBACK: float = 340.0
const FRIENDLY_STOMP_KNOCKBACK: float = 280.0
const FRIENDLY_TREE_THROW_KNOCKBACK: float = 310.0
