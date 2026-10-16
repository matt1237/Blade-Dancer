class_name BDOSSwordSolver extends RefCounted
## BDOS ONLY. A geometric movement constraint, NOT a rigid-body simulation.
## Authored code supplies intent; this object alone owns its persistent resolved pose.
## Each local polyline segment is a capsule. Enemy body circles use their actual
## CircleShape2D radius; enemy weapon segments are capsules. The hand and blade are one rigid pose.
## No damage, canned slide, enemy movement, or contact rewards live here.
const STEP_DISTANCE: float = 1.0
const MAX_STEPS: int = 256
const CONTACT_SKIN: float = 0.05
## Projection relaxation passes per solve phase (so 2 * PROJECT_PASSES passes). The
## inner and outer loops both run this count. It was 8 (16 passes); the focused suite
## still passes at 2 (4 passes) and fails at 1 (2 passes), so 4 is the proven minimum
## that converges without changing a single resolved-pose assertion.
const PROJECT_PASSES: int = 2
const GEOMETRY_RADIUS: float = 2.0
## "Bend around". A contact far out along the blade (lever fraction past this) is
## resolved by ROTATING the blade about the hand more than by translating the grip, so
## the tip sweeps around the body instead of the hand shoving into it. A near-hilt
## contact has no lever, so it still resolves by translation (an axial thrust still
## stops, exactly as bone should).
const BEND_AXIAL_LEVER_FRACTION: float = 0.30
## How much translation weight survives at full bend. Never 0: a deep far overlap must
## still be pushable out, so the finite solve always converges.
const BEND_TRANSLATION_FLOOR: float = 0.25

var initialized: bool = false
var hilt: Vector2 = Vector2.ZERO
var angle: float = 0.0
var local_blade: PackedVector2Array = PackedVector2Array()
var contacts: Array[Dictionary] = []
var blocked: bool = false
var unresolved_overlap: bool = false
var unresolved_reach: bool = false
var substeps: int = 0

func reset() -> void:
	initialized = false
	contacts.clear()
	blocked = false
	unresolved_overlap = false
	unresolved_reach = false
	local_blade.clear()

static func circle_obstacle(id: int, kind: String, shape: CircleShape2D, shape_transform: Transform2D) -> Dictionary:
	var scale: Vector2 = shape_transform.get_scale().abs()
	var radius: float = shape.radius * maxf(scale.x, scale.y)
	return {"id": id, "kind": kind, "start": shape_transform.origin, "end": shape_transform.origin, "radius": radius}

func resolve(target_hilt: Vector2, target_angle: float, shape_points: PackedVector2Array, obstacles: Array[Dictionary], hand_center: Vector2, hand_reach: float) -> void:
	contacts.clear()
	blocked = false
	unresolved_overlap = false
	unresolved_reach = false
	if not initialized:
		hilt = target_hilt
		angle = target_angle
		local_blade = shape_points.duplicate()
		initialized = true
	# A moving obstacle may enter yesterday's resting blade. Resolve that first,
	# even if there is no input motion. Reach is a hard hand-to-player constraint,
	# not a spring and not an independent sword translation layered on the artwork.
	for pass_index: int in range(PROJECT_PASSES * 2):
		var overlap: Dictionary = deepest_contact(hilt, angle, local_blade, obstacles)
		if overlap.is_empty():
			break
		blocked = true
		_record_contact(overlap)
		var correction: Vector3 = _contact_correction(overlap, hilt, _extent(local_blade), hand_center, hand_reach)
		hilt += Vector2(correction.x, correction.y)
		angle += correction.z
		hilt = _within_reach(hilt, hand_center, hand_reach)
	if not deepest_contact(hilt, angle, local_blade, obstacles).is_empty():
		# Crowded/incompatible constraints can have no valid solution in the iteration
		# budget. Expose that fact instead of claiming non-penetration is guaranteed.
		unresolved_overlap = true
		unresolved_reach = hilt.distance_to(hand_center) > maxf(hand_reach, 0.0) + CONTACT_SKIN
		return
	var angle_travel: float = angle_difference(angle, target_angle)
	var shape_travel: float = 0.0
	if shape_points.size() == local_blade.size():
		for index: int in range(shape_points.size()):
			shape_travel = maxf(shape_travel, shape_points[index].distance_to(local_blade[index]))
	var extent: float = maxf(_extent(local_blade), _extent(shape_points))
	# Arc length, NOT endpoint displacement: a half-turn or cancelling hand+tip
	# motion still receives enough substeps to test the path between the endpoints.
	var travel: float = hilt.distance_to(target_hilt) + extent * absf(angle_travel) + shape_travel
	var required: int = maxi(1, ceili(travel / STEP_DISTANCE))
	substeps = mini(required, MAX_STEPS)
	var translation: Vector2 = (target_hilt - hilt) / float(required)
	var rotation_step: float = angle_travel / float(required)
	var original_shape: PackedVector2Array = local_blade.duplicate()
	for step_index: int in range(substeps):
		var step_shape: PackedVector2Array = shape_points.duplicate()
		if shape_points.size() == original_shape.size():
			for index: int in range(step_shape.size()):
				step_shape[index] = original_shape[index].lerp(shape_points[index], float(step_index + 1) / float(required))
		var candidate: Vector2 = _within_reach(hilt + translation, hand_center, hand_reach)
		var candidate_angle: float = angle + rotation_step
		var bounded: Vector3 = _bounded_step(candidate, candidate_angle, extent, step_shape)
		candidate = Vector2(bounded.x, bounded.y)
		candidate_angle = bounded.z
		for pass_index: int in range(PROJECT_PASSES * 2):
			var contact: Dictionary = deepest_contact(candidate, candidate_angle, step_shape, obstacles)
			if contact.is_empty():
				break
			blocked = true
			_record_contact(contact)
			# Correct the actual residual, including roll/morph and nonlinear rotation.
			# A velocity-only projection can read 'outward' while still overlapping,
			# then reject the whole tangential step forever.
			var correction: Vector3 = _contact_correction(contact, candidate, extent, hand_center, hand_reach)
			candidate = _within_reach(candidate + Vector2(correction.x, correction.y), hand_center, hand_reach)
			candidate_angle += correction.z
			bounded = _bounded_step(candidate, candidate_angle, extent, step_shape)
			candidate = Vector2(bounded.x, bounded.y)
			candidate_angle = bounded.z
		if not deepest_contact(candidate, candidate_angle, step_shape, obstacles).is_empty():
			# Keep the last legal pose. Never commit a projected slide unless it was
			# tested against ALL obstacles. Also never commit an illegal rolled shape.
			blocked = true
			continue
		hilt = candidate
		angle = candidate_angle
		local_blade = step_shape
	# An obstacle can make the hand tether unsatisfiable after a player teleport
	# or extreme body motion. Never jump the grip across the obstacle to hide that.
	unresolved_reach = hilt.distance_to(hand_center) > maxf(hand_reach, 0.0) + CONTACT_SKIN

func _contact_correction(contact: Dictionary, position: Vector2, extent: float, hand_center: Vector2, hand_reach: float) -> Vector3:
	var normal: Vector2 = contact["normal"]
	var translation_normal: Vector2 = normal
	var offset: Vector2 = position - hand_center
	if hand_reach <= 0.0:
		translation_normal = Vector2.ZERO
	elif offset.length() >= hand_reach - 0.00001:
		# At maximum extension, outward translation is unavailable. Redistribute
		# contact correction to the reachable tangent and angular leverage instead
		# of translating outward only to clamp it straight back into the contact.
		var radial: Vector2 = offset.normalized()
		translation_normal -= radial * maxf(0.0, normal.dot(radial))
	var lever: Vector2 = (contact["point"] as Vector2) - position
	# Bend bias: the further the contact sits along the blade from the hand, the more of
	# the correction is delivered as rotation about the grip (the blade visibly bends
	# around the body) and the less as hilt translation (which shoves the grip into it).
	var lever_fraction: float = clampf(lever.length() / maxf(extent, 1.0), 0.0, 1.0)
	var bend: float = smoothstep(BEND_AXIAL_LEVER_FRACTION, 1.0, lever_fraction)
	translation_normal *= lerpf(1.0, BEND_TRANSLATION_FLOOR, bend)
	var scale: float = maxf(extent, 1.0)
	var rotational_normal: float = lever.cross(normal) / scale
	var denominator: float = normal.dot(translation_normal) + rotational_normal * rotational_normal
	if denominator < 0.000001:
		return Vector3.ZERO
	var correction: float = (float(contact["depth"]) + 0.0001) / denominator
	return Vector3(translation_normal.x * correction, translation_normal.y * correction, rotational_normal * correction / scale)

func _bounded_step(position: Vector2, rotation: float, extent: float, points: PackedVector2Array) -> Vector3:
	# Returns the bounded hilt (x, y) and angle (z) as a value type and morphs the
	# caller's shape buffer in place. The previous Dictionary + PackedVector2Array
	# duplicate allocated twice per call inside the projection loop.
	var angular_step: float = angle_difference(angle, rotation)
	var shape_travel: float = 0.0
	if points.size() == local_blade.size():
		for index: int in range(points.size()):
			shape_travel = maxf(shape_travel, points[index].distance_to(local_blade[index]))
	var cost: float = hilt.distance_to(position) + extent * absf(angular_step) + shape_travel
	var fraction: float = minf(1.0, STEP_DISTANCE / maxf(cost, 0.000001))
	if points.size() == local_blade.size():
		for index: int in range(points.size()):
			points[index] = local_blade[index].lerp(points[index], fraction)
	var bounded_hilt: Vector2 = hilt.lerp(position, fraction)
	return Vector3(bounded_hilt.x, bounded_hilt.y, angle + angular_step * fraction)

func world_points() -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in local_blade:
		points.append(hilt + point.rotated(angle))
	return points

func _record_contact(contact: Dictionary) -> void:
	# Contacts are deduplicated per obstacle per frame. `pressure` accumulates the
	# depenetration depth the solver removed across every projection pass this
	# frame — the honest measure of how hard the blade was resisted inward. It is
	# exposed so a body can yield along the contact normal (BDOS two-way contact);
	# it never affects the resolved pose.
	var depth: float = float(contact.get("depth", 0.0))
	for existing: Dictionary in contacts:
		if existing.get("id", -1) == contact.get("id", -2):
			existing["pressure"] = float(existing.get("pressure", 0.0)) + depth
			return
	var stored: Dictionary = contact.duplicate()
	stored["pressure"] = depth
	contacts.append(stored)

static func _extent(points: PackedVector2Array) -> float:
	var result: float = 0.0
	for point: Vector2 in points:
		result = maxf(result, point.length())
	return result

static func _within_reach(position: Vector2, center: Vector2, reach: float) -> Vector2:
	var offset: Vector2 = position - center
	if offset.length() > maxf(reach, 0.0):
		return center + offset.normalized() * maxf(reach, 0.0)
	return position

static func closest_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var direction: Vector2 = end - start
	if direction.length_squared() < 0.000001:
		return start
	return start + direction * clampf((point - start).dot(direction) / direction.length_squared(), 0.0, 1.0)

static func closest_pair(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	# Hot path: this runs once per blade-segment/obstacle pair on every projection
	# pass and substep. It is written allocation-light on purpose — the previous
	# version built an Array of four PackedVector2Array candidates per call.
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var denominator: float = ab.cross(cd)
	if absf(denominator) > 0.000001:
		var t: float = (c - a).cross(cd) / denominator
		var u: float = (c - a).cross(ab) / denominator
		if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
			var intersection: Vector2 = a + ab * t
			return PackedVector2Array([intersection, intersection])
	var best_a: Vector2 = a
	var best_b: Vector2 = closest_on_segment(a, c, d)
	var best_distance_sq: float = best_a.distance_squared_to(best_b)
	var candidate_a: Vector2 = b
	var candidate_b: Vector2 = closest_on_segment(b, c, d)
	var candidate_distance_sq: float = candidate_a.distance_squared_to(candidate_b)
	if candidate_distance_sq < best_distance_sq:
		best_a = candidate_a
		best_b = candidate_b
		best_distance_sq = candidate_distance_sq
	candidate_a = closest_on_segment(c, a, b)
	candidate_b = c
	candidate_distance_sq = candidate_a.distance_squared_to(candidate_b)
	if candidate_distance_sq < best_distance_sq:
		best_a = candidate_a
		best_b = candidate_b
		best_distance_sq = candidate_distance_sq
	candidate_a = closest_on_segment(d, a, b)
	candidate_b = d
	candidate_distance_sq = candidate_a.distance_squared_to(candidate_b)
	if candidate_distance_sq < best_distance_sq:
		best_a = candidate_a
		best_b = candidate_b
	return PackedVector2Array([best_a, best_b])

static func deepest_contact(position: Vector2, rotation: float, points: PackedVector2Array, obstacles: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_depth: float = 0.00001
	# Blade extent is fixed for this call; hoist it so the per-obstacle broad-phase
	# does not re-walk the blade points once per obstacle.
	var blade_extent: float = _extent(points)
	for obstacle: Dictionary in obstacles:
		var start: Vector2 = obstacle["start"] as Vector2
		var end: Vector2 = obstacle["end"] as Vector2
		var radius: float = float(obstacle["radius"]) + GEOMETRY_RADIUS + CONTACT_SKIN
		if closest_on_segment(position, start, end).distance_to(position) > blade_extent + radius:
			continue
		for index: int in range(points.size() - 1):
			var a: Vector2 = position + points[index].rotated(rotation)
			var b: Vector2 = position + points[index + 1].rotated(rotation)
			var pair: PackedVector2Array = closest_pair(a, b, start, end)
			var difference: Vector2 = pair[0] - pair[1]
			var distance: float = difference.length()
			var depth: float = radius - distance
			if depth <= best_depth:
				continue
			var normal: Vector2 = difference / distance if distance > 0.00001 else Vector2.ZERO
			if normal.length_squared() < 0.5:
				# Coincident closest points have no unique normal. Choose a surface
				# perpendicular, not a hilt-to-core radial that cannot rotate an axial blade.
				normal = (end - start).orthogonal().normalized() if start != end else (b - a).orthogonal().normalized()
				if normal.length_squared() < 0.5:
					normal = Vector2.UP
				if normal.dot(position - start) < 0.0:
					normal = -normal
			best_depth = depth
			best = {"id": obstacle.get("id", 0), "kind": obstacle.get("kind", "core"), "point": pair[0], "normal": normal, "depth": depth}
	return best
