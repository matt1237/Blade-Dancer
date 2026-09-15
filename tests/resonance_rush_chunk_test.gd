class_name ResonanceRushChunkTest extends Node

const GRAYBOX_CHUNK: PackedScene = preload("res://scenes/minigames/resonance_rush/chunks/rush_chunk_graybox.tscn")

func _make_chunk() -> ResonanceRushChunk:
	var chunk: ResonanceRushChunk = GRAYBOX_CHUNK.instantiate() as ResonanceRushChunk
	add_child(chunk)
	chunk._rebuild_from_drive_path()
	return chunk

func test_graybox_chunk_has_required_authoring_structure() -> void:
	var chunk: ResonanceRushChunk = _make_chunk()
	assert(chunk.has_node("Artwork"))
	assert(chunk.has_node("DrivePath"))
	assert(chunk.has_node("GroundBody/GroundCollision"))
	assert(chunk.has_node("EntryMarker"))
	assert(chunk.has_node("ExitMarker"))
	assert(chunk.has_node("Props"))
	assert(chunk.has_node("GrapplePoints"))
	assert(chunk.has_node("GrapplePoints/GrapplePointExample"))
	var grapple_point: ResonanceRushGrapplePoint = chunk.get_node("GrapplePoints/GrapplePointExample") as ResonanceRushGrapplePoint
	# Child _ready() is deferred by this synchronous test harness.
	grapple_point._ready()
	assert(grapple_point.is_in_group("resonance_grapple_point"))
	assert(chunk.has_node("GameplayMarkers"))
	chunk.free()

func test_curve_builds_preview_collision_and_sockets() -> void:
	var chunk: ResonanceRushChunk = _make_chunk()
	var points: PackedVector2Array = chunk.get_surface_points()
	var preview: Polygon2D = chunk.get_node("GroundPreview") as Polygon2D
	var collision: CollisionPolygon2D = chunk.get_node("GroundBody/GroundCollision") as CollisionPolygon2D
	var entry: Marker2D = chunk.get_node("EntryMarker") as Marker2D
	var exit: Marker2D = chunk.get_node("ExitMarker") as Marker2D
	assert(points.size() > 2)
	assert(preview.polygon.size() == points.size() + 2)
	assert(collision.polygon == preview.polygon)
	assert(entry.position.is_equal_approx(points[0]))
	assert(exit.position.is_equal_approx(points[points.size() - 1]))
	chunk.free()

func test_editing_drive_path_rebuilds_visible_ground() -> void:
	var chunk: ResonanceRushChunk = _make_chunk()
	var drive_path: Path2D = chunk.get_node("DrivePath") as Path2D
	var preview: Polygon2D = chunk.get_node("GroundPreview") as Polygon2D
	var before_hash: int = hash(preview.polygon)
	var old_position: Vector2 = drive_path.curve.get_point_position(3)
	drive_path.curve.set_point_position(3, old_position + Vector2(0.0, 90.0))
	chunk._rebuild_from_drive_path()
	assert(hash(preview.polygon) != before_hash)
	chunk.free()

func test_authored_terrain_queries_same_drive_path() -> void:
	var terrain: ResonanceRushAuthoredTerrain = ResonanceRushAuthoredTerrain.new()
	add_child(terrain)
	var chunk: ResonanceRushChunk = GRAYBOX_CHUNK.instantiate() as ResonanceRushChunk
	chunk.position = Vector2(200.0, 500.0)
	terrain.add_child(chunk)
	var start: Vector2 = terrain.generate_course()
	var surface_points: PackedVector2Array = chunk.get_surface_points()
	var sample_local: Vector2 = surface_points[floori(surface_points.size() * 0.5)]
	var sample_terrain: Vector2 = terrain.to_local(chunk.to_global(sample_local))
	var ground_info: Dictionary = terrain.get_ground_info(sample_terrain.x)
	assert(start.is_equal_approx(terrain.to_local(chunk.to_global(surface_points[0]))))
	assert(ground_info["has_ground"])
	assert(is_equal_approx(float(ground_info["y"]), sample_terrain.y))
	terrain.free()
