class_name SwordInteractionResolver extends RefCounted

const SWEEP_SAMPLES: int = 6
const QUALITY_SPEED_REFERENCE: float = 900.0
const QUALITY_GUARD_WEIGHT: float = 0.6
const QUALITY_TIP_WEIGHT: float = 0.4

static func swept_contact(previous_start: Vector2, previous_end: Vector2, current_start: Vector2, current_end: Vector2, target: Vector2, target_radius: float, delta: float, player_velocity: Vector2 = Vector2.ZERO, movement_contribution: float = 0.25, movement_speed_cap: float = 250.0) -> SwordContactData:
	var contact: SwordContactData = SwordContactData.new()
	var old_start: Vector2 = previous_start if previous_start != Vector2.ZERO else current_start
	var old_end: Vector2 = previous_end if previous_end != Vector2.ZERO else current_end
	var best_distance: float = INF
	var best_blade_position: float = 0.5
	var best_point: Vector2 = current_start
	for sample_index: int in range(SWEEP_SAMPLES):
		var sample_ratio: float = float(sample_index) / float(SWEEP_SAMPLES - 1)
		var sample_start: Vector2 = old_start.lerp(current_start, sample_ratio)
		var sample_end: Vector2 = old_end.lerp(current_end, sample_ratio)
		var result: Dictionary = _closest_point_on_segment(target, sample_start, sample_end)
		var distance: float = float(result["distance"])
		if distance < best_distance:
			best_distance = distance
			best_blade_position = float(result["factor"])
			best_point = result["point"] as Vector2
	contact.swept_distance = best_distance
	if best_distance > target_radius: return contact
	contact.contact_point = best_point
	contact.blade_position = best_blade_position
	contact.blade_direction = (current_end - current_start).normalized()
	var current_contact_point: Vector2 = current_start.lerp(current_end, best_blade_position)
	var previous_contact_point: Vector2 = old_start.lerp(old_end, best_blade_position)
	contact.blade_velocity = (current_contact_point - previous_contact_point) / maxf(delta, 0.0001)
	contact.relative_velocity = contact.blade_velocity - player_velocity
	var movement_speed: float = minf(player_velocity.length(), maxf(0.0, movement_speed_cap))
	var movement_credit: float = movement_speed * clampf(movement_contribution, 0.0, 1.0)
	contact.impact_speed = contact.relative_velocity.length() + movement_credit
	contact.impact_quality = clampf(contact.impact_speed / QUALITY_SPEED_REFERENCE * (QUALITY_GUARD_WEIGHT + best_blade_position * QUALITY_TIP_WEIGHT), 0.0, 1.0)
	contact.impact_normal = target.direction_to(best_point) if target.distance_to(best_point) > 0.01 else -contact.blade_direction
	return contact

static func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Dictionary:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001:
		return {"point": start, "factor": 0.0, "distance": point.distance_to(start)}
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest: Vector2 = start + segment * factor
	return {"point": closest, "factor": factor, "distance": point.distance_to(closest)}
