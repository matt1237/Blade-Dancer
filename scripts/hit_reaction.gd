class_name HitReaction extends RefCounted
## Flesh-only contact math. No sword phase, aim, AI, or hard-material authority.
const DEFAULTS: Dictionary = {
	"hit_reaction_enabled": 0.0,
	"hit_reaction_debug": 0.0,
	"hit_impact_scale": 1.0,
	"hit_normal_weight": 0.8,
	"hit_min_speed": 55.0,
	"hit_forte_depth": 3.0,
	"hit_tip_depth": 13.0,
	"hit_blade_curve": 1.7,
	"hit_stab_bonus": 17.0,
	"hit_resistance": 0.65,
	"hit_resistance_curve": 1.8,
	"hit_release_speed": 300.0,
	"hit_kill_resistance": 0.12,
	"hit_kill_depth_scale": 2.0,
	"hit_kill_delay": 0.055,
	"hit_visual_recoil": 7.0,
	"hit_visual_rotation": 7.0,
	"hit_recoil_in": 0.06,
	"hit_recoil_return": 0.16,
	"hit_knockback_scale": 1.0,
	"hit_hitstop_scale": 1.0,
}

static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS.get(key, 0.0)))

static func analyze(contact: SwordContactData, blade_fraction: float, settings: Dictionary) -> Dictionary:
	var outward: Vector2 = contact.impact_normal.normalized()
	var relative: Vector2 = contact.blade_velocity
	var speed: float = relative.length()
	var inward: float = maxf(0.0, -relative.dot(outward))
	var normal_share: float = clampf(value(settings, "hit_normal_weight"), 0.0, 1.0)
	var weighted_speed: float = lerpf(speed, inward, normal_share)
	var impact: float = clampf((weighted_speed - value(settings, "hit_min_speed")) / 850.0 * value(settings, "hit_impact_scale"), 0.0, 1.0)
	var forward: Vector2 = contact.blade_direction.normalized()
	var alignment: float = maxf(0.0, relative.normalized().dot(forward)) if speed > 0.01 else 0.0
	var tip: float = pow(clampf(blade_fraction, 0.0, 1.0), maxf(0.25, value(settings, "hit_blade_curve")))
	var depth: float = lerpf(value(settings, "hit_forte_depth"), value(settings, "hit_tip_depth"), tip)
	depth += value(settings, "hit_stab_bonus") * tip * alignment * alignment
	var tangent: Vector2 = relative - outward * relative.dot(outward)
	var kind: String = "graze" if inward < 65.0 or impact < 0.08 else ("stab" if alignment >= 0.7 and tip >= 0.55 else "slash")
	return {"impact": impact, "inward": inward, "alignment": alignment, "blade_fraction": blade_fraction, "max_depth": maxf(0.5, depth), "tangent": tangent, "kind": kind}

static func resist(raw_depth: float, max_depth: float, strength: float, exponent: float) -> float:
	if raw_depth <= 0.0: return 0.0 # Pulling away must never stick.
	var limit: float = maxf(max_depth, 0.5)
	var progress: float = clampf(raw_depth / limit, 0.0, 1.0)
	var ramp: float = pow(progress, maxf(0.5, exponent))
	return minf(raw_depth, raw_depth * clampf(strength, 0.0, 1.0) * ramp + maxf(0.0, raw_depth - limit) * (1.0 - clampf(strength, 0.0, 1.0)))
