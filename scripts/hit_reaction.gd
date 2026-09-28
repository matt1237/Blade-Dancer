class_name HitReaction extends RefCounted
## Shared defaults and contact math for the per-preset Hit Reaction controls.
## Presentation, inner-core blade resistance, and live-overlap sink stay separate.
const DEFAULTS: Dictionary = {
	"hit_reaction_enabled": 0.0,
	"hit_visual_recoil": 7.0,
	"hit_visual_rotation": 7.0,
	"blade_physical_reaction_enabled": 0.0,
	"blade_physical_reaction_strength": 55.0,
	"blade_sink_enabled": 0.0,
	"blade_sink_strength": 45.0,
	"sword_knockback_away_enabled": 0.0,
	"blade_bone_debug_enabled": 0.0,
	"hd_hit_squash_strength": 200.0,
	"kill_blood_splatter_chance": 30.0,
}

const MAX_BLADE_SINK_SLOWDOWN: float = 0.9
const INNER_BONE_RADIUS_FRACTION: float = 0.5
const BONE_RESPONSE_SMOOTHING: float = 14.0
const BONE_REACTION_MAX_ANGLE: float = 0.6108652382
const MINIMUM_BONE_REACTION_RATIO: float = 0.12
const MAX_BONE_RECOIL_RATIO: float = 0.7
const BROADSIDE_RECOIL_START: float = 0.82

static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS.get(key, 0.0)))

static func blade_inner_bone_radius(outer_radius: float) -> float:
	return maxf(0.0, outer_radius) * INNER_BONE_RADIUS_FRACTION

static func scale_inner_bone_shape(outer_shape: Shape2D) -> Shape2D:
	if outer_shape == null:
		return null
	var inner_shape: Shape2D = outer_shape.duplicate() as Shape2D
	if inner_shape is CircleShape2D:
		var circle: CircleShape2D = inner_shape as CircleShape2D
		circle.radius *= INNER_BONE_RADIUS_FRACTION
	elif inner_shape is RectangleShape2D:
		var rectangle: RectangleShape2D = inner_shape as RectangleShape2D
		rectangle.size *= INNER_BONE_RADIUS_FRACTION
	elif inner_shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = inner_shape as CapsuleShape2D
		capsule.radius *= INNER_BONE_RADIUS_FRACTION
		capsule.height *= INNER_BONE_RADIUS_FRACTION
	else:
		return null
	return inner_shape

## A contact response is eligible only while the blade is driving inward across the inner-core boundary.
static func blade_physical_reaction_allowed(_is_stab_motion: bool, inward_alignment: float) -> bool:
	return inward_alignment > 0.02

static func advance_blade_physical_reaction(current_angle: float, pending_angle: float, delta: float) -> float:
	return lerpf(current_angle, pending_angle, clampf(maxf(delta, 0.0) * BONE_RESPONSE_SMOOTHING, 0.0, 1.0))

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
static func blade_sink_time_multiplier(master_enabled: bool, sink_enabled: bool, flesh_overlap: bool, strength: float) -> float:
	if not master_enabled or not sink_enabled or not flesh_overlap:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	return 1.0 - MAX_BLADE_SINK_SLOWDOWN * strength_ratio
