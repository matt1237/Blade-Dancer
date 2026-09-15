class_name ResonanceRushMovementCourseTest extends Node

const COURSE_SCENE: PackedScene = preload("res://scenes/minigames/resonance_rush/rush_movement_test_course.tscn")

func _make_course() -> Node2D:
	var course: Node2D = COURSE_SCENE.instantiate() as Node2D
	add_child(course)
	return course

func test_course_has_four_authored_chunks_and_expected_bounds() -> void:
	var course: Node2D = _make_course()
	var terrain: ResonanceRushAuthoredTerrain = course.get_node("TerrainRoot") as ResonanceRushAuthoredTerrain
	var start: Vector2 = terrain.generate_course()
	assert(terrain.get_child_count() == 4)
	assert(start.is_equal_approx(Vector2(200.0, 500.0)))
	assert(terrain.course_end_position.is_equal_approx(Vector2(9200.0, 220.0)))
	assert(terrain.segments.size() > 500)
	course.free()

func test_course_has_continuous_seam_and_two_deliberate_gaps() -> void:
	var course: Node2D = _make_course()
	var terrain: ResonanceRushAuthoredTerrain = course.get_node("TerrainRoot") as ResonanceRushAuthoredTerrain
	terrain.generate_course()
	assert(terrain.get_ground_info(2200.0)["has_ground"])
	assert(not terrain.get_ground_info(3900.0)["has_ground"])
	assert(terrain.get_ground_info(4200.0)["has_ground"])
	assert(not terrain.get_ground_info(6400.0)["has_ground"])
	assert(terrain.get_ground_info(6900.0)["has_ground"])
	course.free()

func test_grapple_canyon_contains_two_authored_anchors() -> void:
	var course: Node2D = _make_course()
	var grapple_container: Node2D = course.get_node("TerrainRoot/GrappleLandingRamp/GrapplePoints") as Node2D
	assert(grapple_container.get_child_count() == 2)
	assert(grapple_container.has_node("CanyonAnchor"))
	assert(grapple_container.has_node("PumpAnchor"))
	course.free()
