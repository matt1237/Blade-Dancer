class_name BladeProfileTest extends Node
## Covers the per-sword BladeProfile hit-polyline math in player.gd:
## straight-sword parity with the old single-segment behavior, and that a
## curved profile actually produces a non-collinear polyline.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _make_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.health_bar = player.get_node("HealthBar") as ProgressBar
	return player

func test_straight_sword_polyline_is_collinear_and_matches_endpoints() -> void:
	var player: Player = _make_player()
	player.set_equipped_sword("Basic Longsword")
	var start: Vector2 = Vector2(100.0, 100.0)
	var direction: Vector2 = Vector2.RIGHT
	var samples: PackedVector2Array = player._blade_polyline_samples(start, direction)
	# Every sword now always builds a uniform hilt/mid/tip 3-point polyline
	# (see get_blade_shape_setting()); a straight profile is still exactly
	# collinear since Basic Longsword's mid/tip offsets default to 0.
	assert(samples.size() == 3, "every sword now produces a uniform hilt/mid/tip polyline")
	assert(samples[0].is_equal_approx(start), "first sample must be exactly the hilt anchor")
	var tip: Vector2 = samples[samples.size() - 1]
	assert(tip.is_equal_approx(start + direction * Player.BLADE_LENGTH), "last sample must be exactly the old straight tip")
	var straight_tip: Vector2 = start + direction * Player.BLADE_LENGTH
	var mid: Vector2 = samples[1]
	var to_tip: Vector2 = (straight_tip - start).normalized()
	var mid_offset_from_line: float = (mid - start).cross(to_tip)
	assert(is_equal_approx(mid_offset_from_line, 0.0), "a straight profile's mid-point must land exactly on the hilt-tip line")
	player.free()

func test_curved_sword_polyline_has_real_perpendicular_offset() -> void:
	var player: Player = _make_player()
	player.set_equipped_sword("Basic Curved Sword")
	var start: Vector2 = Vector2(100.0, 100.0)
	var direction: Vector2 = Vector2.RIGHT
	var samples: PackedVector2Array = player._blade_polyline_samples(start, direction)
	assert(samples.size() >= 3, "the curved profile should have at least one interior control point")
	assert(samples[0].is_equal_approx(start), "first sample is still exactly the hilt anchor")
	var tip: Vector2 = samples[samples.size() - 1]
	var straight_tip: Vector2 = start + direction * Player.BLADE_LENGTH
	assert(not tip.is_equal_approx(straight_tip), "a curved profile's tip must not land on the straight-line reach")
	player.free()

func test_closest_blade_segment_picks_the_nearest_sub_segment() -> void:
	var player: Player = _make_player()
	player.set_equipped_sword("Basic Curved Sword")
	var samples: PackedVector2Array = player._blade_polyline_samples(Vector2(0.0, 0.0), Vector2.RIGHT)
	# A point right next to the last sample (the tip) should resolve to the
	# final sub-segment, not the first one near the hilt.
	var near_tip: Vector2 = samples[samples.size() - 1] + Vector2(1.0, 0.0)
	var result: Array = player._closest_blade_segment(near_tip, samples)
	var segment_index: int = int(result[2])
	assert(segment_index == samples.size() - 2, "a point near the tip should resolve to the last sub-segment, got index %d" % segment_index)
	player.free()

func test_distance_to_blade_polyline_matches_segment_distance_for_straight_sword() -> void:
	var player: Player = _make_player()
	player.set_equipped_sword("Basic Longsword")
	var samples: PackedVector2Array = player._blade_polyline_samples(Vector2(0.0, 0.0), Vector2.RIGHT)
	var point: Vector2 = Vector2(40.0, 15.0)
	var polyline_distance: float = player._distance_to_blade_polyline(point, samples)
	var segment_distance: float = player._distance_to_segment(point, samples[0], samples[samples.size() - 1])
	assert(is_equal_approx(polyline_distance, segment_distance), "for a straight blade, polyline distance must equal the old single-segment distance")
	player.free()
