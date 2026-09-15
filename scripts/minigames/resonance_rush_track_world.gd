class_name ResonanceRushTrackWorld extends ResonanceRushTerrain

## Multi-surface authored track world.
##
## Every ResonanceRushChunk keeps its DrivePath as an independent rideable
## surface. Tracks may overlap in X, double back, stack vertically, or form a
## loop. Grounded motion uses (track_id, baked arc-length progress), never a
## one-y-per-x lookup.

class TrackData:
	var track_id: int = -1
	var chunk: ResonanceRushChunk = null
	var points: PackedVector2Array = PackedVector2Array()
	var distances: PackedFloat32Array = PackedFloat32Array()
	var length: float = 0.0
	var is_primary: bool = true

@export var connection_tolerance: float = 18.0
@export var connection_tangent_min_dot: float = 0.55
@export var landing_snap_distance: float = 34.0

var tracks: Array[TrackData] = []
var primary_track_ids: Array[int] = []

func generate_course() -> Vector2:
	tracks.clear()
	primary_track_ids.clear()
	segments.clear()
	ground_polylines.clear()
	gap_edges.clear()
	var chunks: Array[ResonanceRushChunk] = []
	_collect_chunks(self, chunks)
	max_world_y = -INF
	for chunk: ResonanceRushChunk in chunks:
		var track: TrackData = _build_track(chunk, tracks.size())
		if track == null:
			continue
		tracks.append(track)
		if track.is_primary:
			primary_track_ids.append(track.track_id)
		for point: Vector2 in track.points:
			max_world_y = maxf(max_world_y, point.y)
	if tracks.is_empty():
		push_error("ResonanceRushTrackWorld: no authored DrivePath tracks found")
		return Vector2.ZERO
	var start_track: TrackData = tracks[primary_track_ids[0]] if not primary_track_ids.is_empty() else tracks[0]
	var end_track: TrackData = tracks[primary_track_ids[primary_track_ids.size() - 1]] if not primary_track_ids.is_empty() else tracks[tracks.size() - 1]
	start_position = start_track.points[0]
	course_end_position = end_track.points[end_track.points.size() - 1]
	max_world_y += 900.0
	return start_position

func is_track_world() -> bool:
	return true

func get_start_contact() -> Dictionary:
	if tracks.is_empty():
		return {}
	var track_id: int = primary_track_ids[0] if not primary_track_ids.is_empty() else 0
	return get_track_pose(track_id, 0.0)

func get_track_pose(track_id: int, progress: float) -> Dictionary:
	if track_id < 0 or track_id >= tracks.size():
		return {}
	var track: TrackData = tracks[track_id]
	var clamped_progress: float = clampf(progress, 0.0, track.length)
	var segment_index: int = _segment_index_at_progress(track, clamped_progress)
	var a: Vector2 = track.points[segment_index]
	var b: Vector2 = track.points[segment_index + 1]
	var segment_start: float = track.distances[segment_index]
	var segment_length: float = maxf(0.001, track.distances[segment_index + 1] - segment_start)
	var ratio: float = clampf((clamped_progress - segment_start) / segment_length, 0.0, 1.0)
	var tangent: Vector2 = (b - a).normalized()
	var normal: Vector2 = Vector2(-tangent.y, tangent.x)
	return {
		"track_id": track_id,
		"progress": clamped_progress,
		"length": track.length,
		"position": a.lerp(b, ratio),
		"tangent": tangent,
		"normal": normal,
		"segment_index": segment_index,
	}

## Advances along baked arc length and crosses only explicit near-coincident
## endpoints. If no compatible endpoint exists, detached=true and the endpoint
## pose is returned so the controller can launch into AIR.
func advance_contact(track_id: int, progress: float, travel_distance: float) -> Dictionary:
	var current_track_id: int = track_id
	var current_progress: float = progress
	var remaining: float = travel_distance
	for _transfer_count: int in 5:
		if current_track_id < 0 or current_track_id >= tracks.size():
			return {"detached": true}
		var track: TrackData = tracks[current_track_id]
		var target_progress: float = current_progress + remaining
		if target_progress >= 0.0 and target_progress <= track.length:
			var pose: Dictionary = get_track_pose(current_track_id, target_progress)
			pose["detached"] = false
			return pose
		var moving_forward: bool = target_progress > track.length
		var boundary_progress: float = track.length if moving_forward else 0.0
		var overflow: float = target_progress - track.length if moving_forward else target_progress
		var connection: Dictionary = _find_endpoint_connection(current_track_id, moving_forward)
		if connection.is_empty():
			var endpoint_pose: Dictionary = get_track_pose(current_track_id, boundary_progress)
			endpoint_pose["detached"] = true
			endpoint_pose["overflow"] = overflow
			return endpoint_pose
		current_track_id = int(connection["track_id"])
		if moving_forward:
			current_progress = 0.0
			remaining = overflow
		else:
			current_progress = tracks[current_track_id].length
			remaining = overflow
	var fallback: Dictionary = get_track_pose(current_track_id, current_progress)
	fallback["detached"] = true
	return fallback

func find_nearest_contact(world_position: Vector2, max_distance: float = 120.0) -> Dictionary:
	var best: Dictionary = {}
	var best_distance_squared: float = max_distance * max_distance
	for track: TrackData in tracks:
		for index: int in range(track.points.size() - 1):
			var a: Vector2 = track.points[index]
			var b: Vector2 = track.points[index + 1]
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(world_position, a, b)
			var distance_squared: float = world_position.distance_squared_to(closest)
			if distance_squared >= best_distance_squared:
				continue
			best_distance_squared = distance_squared
			var progress: float = _progress_on_segment(track, index, closest)
			best = get_track_pose(track.track_id, progress)
	return best

## Sweeps the vehicle center against every independently rideable track ribbon.
## This is what allows a fall to select a mountain platform while a forest road
## exists beneath it at the same X coordinate.
func find_landing(previous_position: Vector2, current_position: Vector2, _current_velocity: Vector2, clearance: float, ignore_track_id: int = -1) -> Dictionary:
	var best: Dictionary = {}
	var best_travel_squared: float = INF
	for track: TrackData in tracks:
		if track.track_id == ignore_track_id:
			continue
		for index: int in range(track.points.size() - 1):
			var a: Vector2 = track.points[index]
			var b: Vector2 = track.points[index + 1]
			var tangent: Vector2 = (b - a).normalized()
			var normal: Vector2 = Vector2(-tangent.y, tangent.x)
			# The ride side sits at -normal from the drawn surface (see
			# get_track_pose / "position - normal * clearance"), so the
			# collidable plane the vehicle actually reaches is offset by
			# -normal, not +normal.
			var offset_a: Vector2 = a - normal * clearance
			var offset_b: Vector2 = b - normal * clearance
			var contact_point: Vector2 = Vector2.ZERO
			var has_contact: bool = false
			var intersection: Variant = Geometry2D.segment_intersects_segment(previous_position, current_position, offset_a, offset_b)
			if intersection is Vector2:
				contact_point = intersection as Vector2
				has_contact = true
			else:
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(current_position, offset_a, offset_b)
				if current_position.distance_to(closest) <= landing_snap_distance:
					contact_point = closest
					has_contact = true
			if not has_contact:
				continue
			var travel_squared: float = previous_position.distance_squared_to(contact_point)
			if travel_squared >= best_travel_squared:
				continue
			best_travel_squared = travel_squared
			var surface_point: Vector2 = contact_point + normal * clearance
			var progress: float = _progress_on_segment(track, index, surface_point)
			best = get_track_pose(track.track_id, progress)
			best["contact_position"] = contact_point
	return best

func _build_track(chunk: ResonanceRushChunk, track_id: int) -> TrackData:
	var local_points: PackedVector2Array = chunk.get_surface_points()
	if local_points.size() < 2:
		return null
	var track: TrackData = TrackData.new()
	track.track_id = track_id
	track.chunk = chunk
	track.is_primary = chunk.is_primary_route
	track.distances.append(0.0)
	for point: Vector2 in local_points:
		track.points.append(chunk.to_global(point))
	for index: int in range(track.points.size() - 1):
		track.length += track.points[index].distance_to(track.points[index + 1])
		track.distances.append(track.length)
	return track

func _collect_chunks(node: Node, output: Array[ResonanceRushChunk]) -> void:
	for child: Node in node.get_children():
		var chunk: ResonanceRushChunk = child as ResonanceRushChunk
		if chunk != null:
			output.append(chunk)
		else:
			_collect_chunks(child, output)

func _segment_index_at_progress(track: TrackData, progress: float) -> int:
	for index: int in range(track.distances.size() - 1):
		if progress <= track.distances[index + 1]:
			return index
	return maxi(0, track.points.size() - 2)

func _progress_on_segment(track: TrackData, segment_index: int, point: Vector2) -> float:
	var a: Vector2 = track.points[segment_index]
	var b: Vector2 = track.points[segment_index + 1]
	var segment: Vector2 = b - a
	var ratio: float = clampf((point - a).dot(segment) / maxf(0.001, segment.length_squared()), 0.0, 1.0)
	return track.distances[segment_index] + segment.length() * ratio

func _find_endpoint_connection(track_id: int, moving_forward: bool) -> Dictionary:
	var source: TrackData = tracks[track_id]
	var forced: Dictionary = _forced_connection(source, moving_forward)
	if not forced.is_empty():
		return forced
	var source_pose: Dictionary = get_track_pose(track_id, source.length if moving_forward else 0.0)
	var source_position: Vector2 = source_pose["position"]
	var source_motion: Vector2 = source_pose["tangent"] if moving_forward else -source_pose["tangent"]
	var best: Dictionary = {}
	var best_distance: float = connection_tolerance
	for candidate: TrackData in tracks:
		if candidate.track_id == track_id:
			continue
		var candidate_progress: float = 0.0 if moving_forward else candidate.length
		var candidate_pose: Dictionary = get_track_pose(candidate.track_id, candidate_progress)
		var candidate_motion: Vector2 = candidate_pose["tangent"] if moving_forward else -candidate_pose["tangent"]
		var distance: float = source_position.distance_to(candidate_pose["position"])
		if distance > best_distance or source_motion.dot(candidate_motion) < connection_tangent_min_dot:
			continue
		best_distance = distance
		best = {"track_id": candidate.track_id}
	return best

## Authored override for ambiguous junctions (e.g. a loop's entrance and a
## through-road both starting at the same coordinate) where proximity alone
## cannot tell the tracks apart.
func _forced_connection(source: TrackData, moving_forward: bool) -> Dictionary:
	if source.chunk == null:
		return {}
	var target_path: NodePath = source.chunk.forced_next_chunk if moving_forward else source.chunk.forced_previous_chunk
	if target_path.is_empty():
		return {}
	var target_chunk: ResonanceRushChunk = source.chunk.get_node_or_null(target_path) as ResonanceRushChunk
	if target_chunk == null:
		push_warning("ResonanceRushTrackWorld: %s's forced chunk connection did not resolve to a ResonanceRushChunk" % source.chunk.name)
		return {}
	for candidate: TrackData in tracks:
		if candidate.chunk == target_chunk:
			return {"track_id": candidate.track_id}
	return {}

## Legacy renderer/query intentionally disabled: each RushChunk draws its own
## independent track, including loops and stacked surfaces.
func _draw() -> void:
	pass
