class_name HitReaction extends RefCounted
## Shared defaults and contact math for the per-preset Hit Reaction controls.
## Presentation, glancing physical response, and live-overlap sink stay separate.
const DEFAULTS: Dictionary = {
	"hit_reaction_enabled": 0.0,
	"hit_visual_recoil": 7.0,
	"hit_visual_rotation": 7.0,
	"blade_physical_reaction_enabled": 0.0,
	"blade_physical_reaction_strength": 55.0,
	"blade_sink_enabled": 0.0,
	"blade_sink_strength": 45.0,
}

const MAX_PHYSICAL_REACTION_ANGLE: float = 0.4886921906
const HEAD_ON_PASS_THROUGH_THRESHOLD: float = 0.72
const MAX_BLADE_SINK_SLOWDOWN: float = 0.18

static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS.get(key, 0.0)))

## Return an angle correction toward the incoming cut's tangent at the target.
## Positive inward alignment is required; head-on and departing cuts pass through.
static func blade_physical_reaction_allowed(is_stab_motion: bool, inward_alignment: float) -> bool:
	return not is_stab_motion and inward_alignment > 0.02 and inward_alignment < HEAD_ON_PASS_THROUGH_THRESHOLD

static func advance_blade_physical_reaction(current_angle: float, pending_angle: float, delta: float) -> float:
	return lerpf(current_angle, pending_angle, clampf(maxf(delta, 0.0) * 18.0, 0.0, 1.0))

static func blade_physical_reaction_angle(blade_velocity: Vector2, target_velocity: Vector2, impact_normal: Vector2, strength: float) -> float:
	var relative_velocity: Vector2 = blade_velocity - target_velocity
	if relative_velocity.length_squared() < 1.0 or impact_normal.length_squared() < 0.001:
		return 0.0
	var normal: Vector2 = impact_normal.normalized()
	var incoming_direction: Vector2 = relative_velocity.normalized()
	var inward_alignment: float = -incoming_direction.dot(normal)
	if not blade_physical_reaction_allowed(false, inward_alignment):
		return 0.0
	var tangent_velocity: Vector2 = relative_velocity - normal * relative_velocity.dot(normal)
	if tangent_velocity.length_squared() < 0.001:
		return 0.0
	var tangential_bias: float = clampf(inward_alignment * 0.35, 0.0, 0.25)
	var desired_direction: Vector2 = (tangent_velocity.normalized() - normal * tangential_bias).normalized()
	var correction: float = angle_difference(incoming_direction.angle(), desired_direction.angle())
	var glancing_weight: float = 1.0 - smoothstep(0.02, HEAD_ON_PASS_THROUGH_THRESHOLD, inward_alignment)
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	return clampf(correction, -MAX_PHYSICAL_REACTION_ANGLE, MAX_PHYSICAL_REACTION_ANGLE) * strength_ratio * glancing_weight

## Sink is a live contact-time rate only. Separation or either switch restores 1.0.
static func blade_sink_time_multiplier(master_enabled: bool, sink_enabled: bool, flesh_overlap: bool, strength: float) -> float:
	if not master_enabled or not sink_enabled or not flesh_overlap:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	return 1.0 - MAX_BLADE_SINK_SLOWDOWN * strength_ratio
