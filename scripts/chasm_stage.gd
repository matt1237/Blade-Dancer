class_name ChasmStage extends Node2D

## The order follows the saved perimeter clockwise from the top edge.
## Spawn validation reads the live CollisionShape2D nodes, so editor adjustments
## remain authoritative without duplicating their coordinates in code.
const BOUNDARY_ORDER: Array[String] = [
	"Top",
	"RightTopSlope",
	"RightUpper",
	"RightMiddle",
	"RightLower",
	"RightBottom",
	"Bottom",
	"LeftBottom",
	"LeftLower",
	"LeftMiddle",
	"LeftUpper",
	"TopLeftSlope",
]

@export var arena_rect: Rect2 = Rect2(0.0, 0.0, 1280.0, 720.0)
@export var spawn_boundary_clearance: float = 52.0
@export var maximum_runtime_closure_gap: float = 160.0

var _all_boundary_segments: Array[PackedVector2Array] = []
var _runtime_closures: Array[CollisionShape2D] = []

func _ready() -> void:
	_rebuild_runtime_boundary_closures()

func set_collision_enabled(enabled: bool) -> void:
	var bounds: StaticBody2D = get_node_or_null("ChasmBounds") as StaticBody2D
	if bounds != null:
		bounds.collision_layer = 4 if enabled else 0

func get_spawn_rect() -> Rect2:
	return arena_rect

func is_spawn_position_valid(candidate_position: Vector2, clearance: float = 52.0) -> bool:
	if not arena_rect.has_point(candidate_position):
		return false
	var boundary_polygon: PackedVector2Array = get_boundary_polygon()
	if boundary_polygon.size() < 3 or not _point_in_polygon(candidate_position, boundary_polygon):
		return false
	var required_clearance: float = maxf(clearance, spawn_boundary_clearance)
	var boundary_segments: Array[PackedVector2Array] = _all_boundary_segments
	if boundary_segments.is_empty():
		boundary_segments = _get_oriented_boundary_segments()
	for segment: PackedVector2Array in boundary_segments:
		if segment.size() < 2:
			return false
		if _distance_to_segment(candidate_position, segment[0], segment[1]) < required_clearance:
			return false
	return true

func get_boundary_polygon() -> PackedVector2Array:
	var oriented_segments: Array[PackedVector2Array] = _get_oriented_boundary_segments()
	if oriented_segments.size() != BOUNDARY_ORDER.size():
		return PackedVector2Array()
	var polygon: PackedVector2Array = PackedVector2Array()
	for segment: PackedVector2Array in oriented_segments:
		polygon.append(segment[0])
		polygon.append(segment[1])
	return polygon

func refresh_boundary_geometry() -> void:
	_rebuild_runtime_boundary_closures()

func _rebuild_runtime_boundary_closures() -> void:
	for closure: CollisionShape2D in _runtime_closures:
		if is_instance_valid(closure): closure.free()
	_runtime_closures.clear()
	_all_boundary_segments.clear()
	var oriented_segments: Array[PackedVector2Array] = _get_oriented_boundary_segments()
	if oriented_segments.size() != BOUNDARY_ORDER.size():
		return
	for segment: PackedVector2Array in oriented_segments:
		_all_boundary_segments.append(segment)
	for segment_index: int in range(oriented_segments.size()):
		var current_segment: PackedVector2Array = oriented_segments[segment_index]
		var next_segment: PackedVector2Array = oriented_segments[(segment_index + 1) % oriented_segments.size()]
		var connector_start: Vector2 = current_segment[1]
		var connector_end: Vector2 = next_segment[0]
		var connector_length: float = connector_start.distance_to(connector_end)
		if connector_length <= 2.0:
			continue
		var connector_segment: PackedVector2Array = PackedVector2Array([connector_start, connector_end])
		_all_boundary_segments.append(connector_segment)
		if connector_length <= maximum_runtime_closure_gap:
			_create_runtime_closure(segment_index, connector_start, connector_end)

func _create_runtime_closure(index: int, start: Vector2, end: Vector2) -> void:
	var bounds: StaticBody2D = get_node_or_null("ChasmBounds") as StaticBody2D
	if bounds == null:
		return
	var closure: CollisionShape2D = CollisionShape2D.new()
	closure.name = "RuntimeClosure_%02d" % index
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(start.distance_to(end), 28.0)
	closure.shape = rectangle
	bounds.add_child(closure)
	closure.global_position = (start + end) * 0.5
	closure.global_rotation = (end - start).angle()
	_runtime_closures.append(closure)

func _get_boundary_segments() -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	for segment_name: String in BOUNDARY_ORDER:
		var shape_node: CollisionShape2D = get_node_or_null("ChasmBounds/" + segment_name) as CollisionShape2D
		if shape_node == null:
			return []
		var rectangle: RectangleShape2D = shape_node.shape as RectangleShape2D
		if rectangle == null or rectangle.size.x <= 0.0:
			return []
		var half_width: float = rectangle.size.x * 0.5
		var shape_transform: Transform2D = shape_node.global_transform
		var first_point: Vector2 = shape_transform * Vector2(-half_width, 0.0)
		var second_point: Vector2 = shape_transform * Vector2(half_width, 0.0)
		segments.append(PackedVector2Array([first_point, second_point]))
	return segments

func _get_oriented_boundary_segments() -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = _get_boundary_segments()
	if segments.size() != BOUNDARY_ORDER.size():
		return []
	var orientation_count: int = 1 << segments.size()
	var best_mask: int = 0
	var best_cost: float = INF
	for mask: int in range(orientation_count):
		var total_cost: float = 0.0
		for segment_index: int in range(segments.size()):
			var current_segment: PackedVector2Array = segments[segment_index]
			var next_segment: PackedVector2Array = segments[(segment_index + 1) % segments.size()]
			var current_end: Vector2 = current_segment[1] if ((mask >> segment_index) & 1) == 0 else current_segment[0]
			var next_start: Vector2 = next_segment[0] if ((mask >> ((segment_index + 1) % segments.size())) & 1) == 0 else next_segment[1]
			total_cost += current_end.distance_to(next_start)
			if total_cost >= best_cost:
				break
		if total_cost < best_cost:
			best_cost = total_cost
			best_mask = mask
	var oriented_segments: Array[PackedVector2Array] = []
	for segment_index: int in range(segments.size()):
		var segment: PackedVector2Array = segments[segment_index]
		if ((best_mask >> segment_index) & 1) == 0:
			oriented_segments.append(segment)
		else:
			oriented_segments.append(PackedVector2Array([segment[1], segment[0]]))
	return oriented_segments

func _point_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	var inside: bool = false
	var previous_index: int = polygon.size() - 1
	for current_index: int in range(polygon.size()):
		var current_point: Vector2 = polygon[current_index]
		var previous_point: Vector2 = polygon[previous_index]
		if (current_point.y > point.y) != (previous_point.y > point.y):
			var intersection_x: float = (previous_point.x - current_point.x) * (point.y - current_point.y) / (previous_point.y - current_point.y) + current_point.x
			if point.x < intersection_x:
				inside = not inside
		previous_index = current_index
	return inside

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * factor)
