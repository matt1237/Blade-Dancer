class_name ParryRules extends RefCounted

# Single source of truth for normal parry, slide, and blade-cling behavior.
# Boss/Elite overrides remain here too, so tuning never needs enemy-by-enemy edits.

# --- NORMAL DUELIST PARRY ---
## How quickly every normal Duelist rotates its spear toward the player.
## Higher values make defensive reactions faster and parries more reliable.
const UNIVERSAL_BLADE_ROTATION_SPEED: float = 5.0
## Minimum seconds before the same Duelist can successfully parry again.
const UNIVERSAL_PARRY_COOLDOWN_DURATION: float = 1.50
## Maximum pixel gap allowed between the player weapon and Duelist spear for a parry.
## Higher values are more forgiving; lower values require more accurate contact.
const UNIVERSAL_PARRY_CONTACT_TOLERANCE: float = 13.0
## How long a Duelist is interrupted after performing a successful parry.
const UNIVERSAL_PARRY_STAGGER_DURATION: float = 0.9

# --- BLADE SLIDES ---
## Maximum pixel gap allowed when deciding whether two nearly parallel blades slide.
const UNIVERSAL_SLIDE_CONTACT_TOLERANCE: float = 14.0
## Largest angle difference that can still count as a slide instead of a direct clash.
const UNIVERSAL_SLIDE_ANGLE_DEGREES: float = 60.0
## Seconds the blade-edge slide sparks remain visible.
const SLIDE_VISUAL_DURATION: float = 0.4
## Number of small sparks drawn along the enemy weapon during a slide.
const SLIDE_SPARK_COUNT: int = 6
## Total distance the spark cluster travels along the weapon edge.
const SLIDE_SPARK_TRAVEL_DISTANCE: float = 50.0
## Side-to-side randomness of individual slide sparks in pixels.
const SLIDE_SPARK_SPREAD: float = 4.0
## Base length of each slide spark in pixels.
const SLIDE_SPARK_LENGTH: float = 4.0
## Width of the bright contact streak drawn directly on the enemy weapon.
const SLIDE_BLADE_FLASH_WIDTH: float = 3.0
## Fraction of slide sparks colored red instead of gold. 0 disables red sparks.
const SLIDE_RED_SPARK_RATIO: float = 0.0
## Player sword-speed multiplier while blades are sliding. 0.82 means 18% slower.
const SLIDE_SWORD_SPEED_MULTIPLIER: float = 0.82
## Seconds the player sword briefly clings to the enemy blade after a slide begins.
const SLIDE_CLING_DURATION: float = 0.3

# --- COMBAT PRESET 2: DISTINCT CONTACT IDENTITIES ---
const PRESET_2_SLIDE_ANGLE_DEGREES: float = 30.0
const PRESET_2_SLIDE_CONTACT_TOLERANCE: float = 9.0
const PRESET_2_SLIDE_DURATION: float = 1.2
const PRESET_2_SLIDE_SPEED_MULTIPLIER: float = 0.80
const PRESET_2_SLIDE_CLING: float = 0.98
const PRESET_2_SLIDE_TRAVEL: float = 45.0
const PRESET_2_SLIDE_SPREAD: float = 2.0
const PRESET_2_CLASH_ANGLE_MIN: float = 31.0
const PRESET_2_CLASH_ANGLE_MAX: float = 75.0
const PRESET_2_CLASH_COOLDOWN: float = 1.0
const PRESET_2_CLASH_STAGGER: float = 0.40
const PRESET_2_CLASH_RECOVERY: float = 0.26
const PRESET_2_CLASH_FLOW: float = 0.0
const PRESET_2_CLASH_HITSTOP: float = 0.15
const PRESET_2_CLASH_RECOIL: float = 300.0
const PRESET_2_PARRY_HITSTOP: float = 0.1
const PRESET_2_PARRY_PLAYER_RECOIL: float = 70.0
const PRESET_2_PARRY_ENEMY_RECOIL: float = 300.0
const PRESET_2_PARRY_STAGGER: float = 1.0
const PRESET_2_PARRY_RECOVERY: float = 0.15

# --- ELITE SHIELD PARRY OVERRIDES ---
## Minimum seconds before an Elite shield can parry again.
const ELITE_PARRY_COOLDOWN_DURATION: float = 1.50
## Elite-only contact distance. Larger than Duelists because the shield is broader.
const ELITE_PARRY_CONTACT_TOLERANCE: float = 20.0
## How long an Elite is interrupted after its shield parries an attack.
const ELITE_PARRY_STAGGER_DURATION: float = 0.4
## Multiplies the player's global parry forgiveness when testing Elite shields.
const ELITE_PARRY_FORGIVENESS_MULTIPLIER: float = 0.95

# --- EXPERIMENTAL DIRECTIONAL PARRY TEST ---
## False keeps the reliable original parry behavior. True enables the dormant
## direction-based Parry-versus-Clash experiment.
const USE_DIRECTIONAL_PARRY_TEST: bool = false
## Required sideways component of an incoming swing for the experiment to call it a parry.
const PARRY_LATERAL_REDIRECTION_THRESHOLD: float = 0.55
## Knockback applied to an enemy when weapons produce a normal clash.
const CLASH_RECOIL_TO_ENEMY: float = 75.0
## Seconds an enemy is interrupted by a normal clash.
const CLASH_STAGGER_DURATION: float = 0.08

static func can_attempt_parry(enabled: bool, stunned: bool, latched: bool, cooldown_left: float) -> bool:
	return enabled and not stunned and not latched and cooldown_left <= 0.0

static func allowed_contact_tolerance(global_forgiveness: float, unit_tolerance: float, forgiveness_multiplier: float) -> float:
	return minf(unit_tolerance, global_forgiveness * forgiveness_multiplier)

static func classify_weapon_interception(player_blade_velocity: Vector2, enemy_blade_direction: Vector2) -> bool:
	if player_blade_velocity.length_squared() < 0.0001 or enemy_blade_direction.length_squared() < 0.0001: return false
	var lateral_direction: Vector2 = enemy_blade_direction.orthogonal()
	var lateral_component: float = absf(player_blade_velocity.normalized().dot(lateral_direction.normalized()))
	return lateral_component >= PARRY_LATERAL_REDIRECTION_THRESHOLD

static func start_parry_cooldown(duration: float) -> float:
	return maxf(0.0, duration)
