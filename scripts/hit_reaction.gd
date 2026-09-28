class_name HitReaction extends RefCounted
## Shared defaults and contact math for the per-preset Hit Reaction controls.
## Presentation, inner-core blade resistance, and live-overlap sink stay separate.
const DEFAULT_INNER_BONE_SIZE_PERCENT: float = 50.0
const DEFAULTS: Dictionary = {
	"hit_reaction_enabled": 0.0,
	"hit_visual_recoil": 7.0,
	"hit_visual_rotation": 7.0,
	"blade_physical_reaction_enabled": 0.0,
	"blade_physical_reaction_strength": 55.0,
	"blade_sink_enabled": 0.0,
	"blade_sink_strength": 45.0,
	"blade_sink_depth_percent": 70.0,
	## Surfaced as "Sword Stickiness": the single blade-hold duration authority, and
	## the ceiling the bone stop nests inside (see bone_stop_within_hold).
	"blade_sink_dwell_time": 0.10,
	"blade_bone_stop_enabled": 0.0,
	"blade_bone_stop_duration": 0.04,
	"blade_bone_stop_cooldown": 0.6,
	"blade_glance_angle_degrees": 10.0,
	"blade_core_yield_percent": 60.0,
	"sword_knockback_away_enabled": 0.0,
	"blade_bone_debug_enabled": 0.0,
	"blade_bone_core_size_percent": DEFAULT_INNER_BONE_SIZE_PERCENT,
	"hd_hit_squash_strength": 200.0,
	"blood_amount_percent": 100.0,
	"blood_drop_size_percent": 100.0,
	"blood_chance_percent": 60.0,
	"split_kill_chance_percent": 80.0,
}

const MAX_BLADE_SINK_SLOWDOWN: float = 0.9
## Blade Sink is the flesh-speed channel only: Depth is the ceiling slowdown
## reachable at full Strength, so 70% Depth + 100% Strength advances the live
## swing at 0.30 (a touch gentler than a Bind's 0.18 bound-sword speed).
const DEFAULT_BLADE_SINK_DEPTH_PERCENT: float = 70.0
const INNER_BONE_RADIUS_FRACTION: float = DEFAULT_INNER_BONE_SIZE_PERCENT / 100.0
const BONE_CONTACT_RESPONSE_SMOOTHING: float = 40.0
const BONE_RELEASE_RESPONSE_SMOOTHING: float = 16.0
const BONE_REACTION_MAX_ANGLE: float = 0.872664626
const MINIMUM_BONE_REACTION_RATIO: float = 0.12
const MAX_BONE_RECOIL_RATIO: float = 0.7
const BROADSIDE_RECOIL_START: float = 0.82
## Contact-time slowdowns ease in and, crucially, ease back out so the un-bite is
## smooth instead of snapping the swing rate back in a single frame.
const BLADE_SINK_CONTACT_SMOOTHING: float = 40.0
const BLADE_SINK_RELEASE_SMOOTHING: float = 12.0
## The inner core yields as a gentle swing-rate cut, not a rotation: at full
## strength the live swing advances at this fraction while driving into the core.
## Much milder than a Bind's bound-sword speed, so the blade resists without stalling.
const BLADE_CORE_YIELD_FLOOR: float = 0.75

static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS.get(key, 0.0)))

## Probability (0..1) that a contact actually fires, given a visible max-chance
## slider and a hidden minimum-quality gate. The chance ramps from zero AT the
## gate up to the slider's ceiling at perfect contact (quality 1.0), so even a
## 100% ceiling still will not fire on every merely-qualifying hit.
static func contact_chance(max_percent: float, min_quality: float, quality: float) -> float:
	var ceiling: float = clampf(max_percent / 100.0, 0.0, 1.0)
	if ceiling <= 0.0:
		return 0.0
	if quality < min_quality:
		return 0.0
	if min_quality >= 1.0:
		return ceiling
	return ceiling * smoothstep(min_quality, 1.0, clampf(quality, 0.0, 1.0))

static func inner_bone_fraction(size_percent: float) -> float:
	return clampf(size_percent / 100.0, 0.0, 1.0)

static func blade_inner_bone_radius(outer_radius: float, size_percent: float = INNER_BONE_RADIUS_FRACTION * 100.0) -> float:
	return maxf(0.0, outer_radius) * inner_bone_fraction(size_percent)

static func scale_inner_bone_shape(outer_shape: Shape2D, size_fraction: float = INNER_BONE_RADIUS_FRACTION) -> Shape2D:
	if outer_shape == null:
		return null
	var scale_fraction: float = clampf(size_fraction, 0.0, 1.0)
	var inner_shape: Shape2D = outer_shape.duplicate() as Shape2D
	if inner_shape is CircleShape2D:
		var circle: CircleShape2D = inner_shape as CircleShape2D
		circle.radius *= scale_fraction
	elif inner_shape is RectangleShape2D:
		var rectangle: RectangleShape2D = inner_shape as RectangleShape2D
		rectangle.size *= scale_fraction
	elif inner_shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = inner_shape as CapsuleShape2D
		capsule.radius *= scale_fraction
		capsule.height *= scale_fraction
	else:
		return null
	return inner_shape

## A contact response is eligible only while the blade is driving inward across the inner-core boundary.
static func blade_physical_reaction_allowed(_is_stab_motion: bool, inward_alignment: float) -> bool:
	return inward_alignment > 0.02

static func advance_blade_physical_reaction(current_angle: float, pending_angle: float, delta: float) -> float:
	var smoothing: float = BONE_CONTACT_RESPONSE_SMOOTHING if absf(pending_angle) > absf(current_angle) else BONE_RELEASE_RESPONSE_SMOOTHING
	return lerpf(current_angle, pending_angle, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))

## A shallow-to-deep cut is guided along the core; broadside cuts and stabs yield outward smoothly.
static func blade_bone_reaction_angle(blade_velocity: Vector2, target_velocity: Vector2, impact_normal: Vector2, blade_axis: Vector2, strength: float, stab_motion: bool) -> float:
	var relative_velocity: Vector2 = blade_velocity - target_velocity
	if relative_velocity.length_squared() < 1.0 or impact_normal.length_squared() < 0.001 or blade_axis.length_squared() < 0.001:
		return 0.0
	var incoming_direction: Vector2 = relative_velocity.normalized()
	var normal: Vector2 = impact_normal.normalized()
	var tangent: Vector2 = normal.orthogonal()
	var approach: float = maxf(0.0, -incoming_direction.dot(normal))
	var axis_alignment: float = absf(incoming_direction.dot(blade_axis.normalized()))
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	var reflected_direction: Vector2 = (incoming_direction + normal * (2.0 * approach)).normalized()
	if stab_motion:
		var stab_ratio: float = smoothstep(0.0, 1.0, approach) * strength_ratio
		return clampf(angle_difference(incoming_direction.angle(), reflected_direction.angle()), -BONE_REACTION_MAX_ANGLE, BONE_REACTION_MAX_ANGLE) * stab_ratio
	var broadside_ratio: float = smoothstep(BROADSIDE_RECOIL_START, 1.0, 1.0 - axis_alignment)
	var tangent_sign: float = signf(incoming_direction.dot(tangent))
	if tangent_sign == 0.0:
		tangent_sign = 1.0
	var outward_bias: float = lerpf(MINIMUM_BONE_REACTION_RATIO, MAX_BONE_RECOIL_RATIO, broadside_ratio)
	var guided_direction: Vector2 = (tangent * tangent_sign + normal * outward_bias).normalized()
	var cut_correction: float = angle_difference(incoming_direction.angle(), guided_direction.angle())
	var cut_weight: float = smoothstep(0.0, 1.0, 0.5 + approach + (1.0 - axis_alignment) * 0.5) * strength_ratio
	return clampf(cut_correction, -BONE_REACTION_MAX_ANGLE, BONE_REACTION_MAX_ANGLE) * cut_weight

static func sword_knockback_direction(default_direction: Vector2, player_position: Vector2, target_position: Vector2, enabled: bool) -> Vector2:
	if not enabled:
		return default_direction
	var away_direction: Vector2 = player_position.direction_to(target_position)
	return away_direction if away_direction.length_squared() > 0.001 else default_direction

## Sink is a live contact-time rate only. Separation or either switch restores 1.0.
## Depth is the ceiling slowdown reachable at full Strength; Strength scales how
## much of that ceiling is used, so the two sliders stay independently tunable.
static func blade_sink_time_multiplier(master_enabled: bool, sink_enabled: bool, contact_active: bool, strength: float, depth_percent: float = DEFAULT_BLADE_SINK_DEPTH_PERCENT) -> float:
	if not master_enabled or not sink_enabled or not contact_active:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	var depth_ratio: float = clampf(depth_percent / 100.0, 0.0, 1.0)
	return 1.0 - depth_ratio * strength_ratio

## The bite ramps in on contact and eases back out after separation. The smoothed
## value is the live swing-rate multiplier, so release never snaps the cadence.
static func advance_blade_sink(current: float, target: float, delta: float) -> float:
	var smoothing: float = BLADE_SINK_CONTACT_SMOOTHING if target < current else BLADE_SINK_RELEASE_SMOOTHING
	return lerpf(current, target, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))

## Option A: the bone stop nests INSIDE the Sword Stickiness hold budget rather
## than adding to it, so a core catch can never stack with the flesh tail into one
## long stall. The freeze is capped by the stickiness window - it may shorten the
## catch, but the blade is never held longer than a single budget. One knob, one
## hold: raise Sword Stickiness to keep the catch intact, lower it for a crisp cut.
static func bone_stop_within_hold(bone_stop_duration: float, stickiness: float) -> float:
	return clampf(minf(maxf(bone_stop_duration, 0.0), maxf(stickiness, 0.0)), 0.0, 0.30)

## Target swing-rate multiplier for the inner core: 1.0 when the blade is not
## driving inward, easing toward the yielded floor as it presses deeper. The floor
## is the old 0.75 cap scaled by the Core Yield percent, so the slider only ever
## makes the continuous bone resistance gentler, never harsher.
static func blade_core_yield_target(strength: float, active: bool, inward_alignment: float, yield_percent: float = 100.0) -> float:
	if not active:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	var yield_ratio: float = clampf(yield_percent / 100.0, 0.0, 1.0)
	var depth: float = clampf(inward_alignment, 0.0, 1.0)
	return 1.0 - (1.0 - BLADE_CORE_YIELD_FLOOR) * yield_ratio * strength_ratio * depth

static func advance_blade_core_yield(current: float, target: float, delta: float) -> float:
	var smoothing: float = BONE_CONTACT_RESPONSE_SMOOTHING if target < current else BONE_RELEASE_RESPONSE_SMOOTHING
	return lerpf(current, target, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))
