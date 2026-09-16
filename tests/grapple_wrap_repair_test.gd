class_name GrappleWrapRepairTest extends Node

func test_held_orbit_captures_once_and_inward_motion_creates_temporary_slack() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var controller: GrappleController = player.grapple_controller
	var chakram: Chakram = Chakram.new()
	add_child(chakram)
	chakram.set_physics_process(false)
	var hand: Vector2 = player.get_grapple_hand_position()
	chakram.global_position = hand + Vector2(100.0, 0.0)
	controller.active = true
	controller.input_was_down = true
	controller.target_type = GrappleController.TargetType.CHAKRAM
	controller.target_node = chakram
	controller.rope_length = 180.0
	controller.rope_taut = false
	controller.yoyo_state = GrappleController.YoyoState.ORBITING
	controller.yoyo_boundary_wrap_enabled = false
	controller.yoyo_static_pivot_enabled = false
	controller.update_and_get_player_acceleration(true, Vector2.ZERO, 0.1)
	assert(is_equal_approx(controller.rope_length, 100.0), "Catch must capture the live Chakram radius exactly once.")
	assert(controller.rope_taut, "The direct Yo-yo catch must stay meaningfully connected during its held orbit.")
	chakram.global_position = hand + Vector2(60.0, 0.0)
	controller.reel_speed = 5000.0
	controller.yoyo_min_orbit_time = 0.0
	controller.update_and_get_player_acceleration(true, Vector2.ZERO, 2.0)
	assert(controller.yoyo_state == GrappleController.YoyoState.ORBITING, "Elapsed time must never turn a held Yo-yo into automatic recall.")
	assert(is_equal_approx(controller.rope_length, 100.0), "Inward motion must create temporary slack instead of permanently ratcheting the orbit smaller.")
	controller.release_tether()
	chakram.free()
	player.free()

func test_circle_unwinds_across_zero_without_inventing_a_turn() -> void:
	for side: float in [1.0, -1.0]:
		var arc: float = GrappleController.yoyo_accumulated_arc(0.02, TAU - 0.02, 0.0, 0.0, 0.02 * side, -0.02 * side, side)
		assert(is_zero_approx(arc), "Modulo tangent seam must not manufacture a coil.")

func test_rectangle_supports_both_legs_and_counts_live_path() -> void:
	var bounds: Rect2 = Rect2(-40.0, -20.0, 80.0, 40.0)
	for side: float in [1.0, -1.0]:
		var hand: Vector2 = Vector2(-100.0, 0.0)
		var end: Vector2 = Vector2(100.0, 0.0)
		var entry: Vector2 = GrappleController.yoyo_rect_tangent(bounds, hand, side)
		var exit: Vector2 = GrappleController.yoyo_rect_tangent(bounds, end, -side)
		assert(not GrappleController.yoyo_segment_crosses_rect(hand, entry, bounds.grow(-0.01)))
		assert(not GrappleController.yoyo_segment_crosses_rect(exit, end, bounds.grow(-0.01)))
		var arc: float = GrappleController.yoyo_rect_directed_distance(GrappleController.yoyo_rect_perimeter_parameter(bounds, entry), GrappleController.yoyo_rect_perimeter_parameter(bounds, exit), side, 240.0)
		assert(is_equal_approx(arc, 80.0))
		var controller: GrappleController = GrappleController.new()
		controller.yoyo_wrap_active = true
		controller.yoyo_wrap_bounds = bounds
		controller.yoyo_rect_wrap_sign = side
		controller.yoyo_rect_entry_parameter = GrappleController.yoyo_rect_perimeter_parameter(bounds, entry)
		controller.yoyo_rect_previous_exit_parameter = GrappleController.yoyo_rect_perimeter_parameter(bounds, exit)
		controller.yoyo_rect_arc_length = arc
		controller.yoyo_state = GrappleController.YoyoState.REELING
		controller._update_rect_wrap(hand, end, 0.5)
		assert(is_equal_approx(controller.yoyo_rect_arc_length, arc), "Reel cannot erase stationary boundary geometry.")
		assert(is_equal_approx(controller._yoyo_live_path_length(hand, end), hand.distance_to(entry) + arc + exit.distance_to(end)))
		controller.free()

func test_rectangle_diagonal_clearance_is_not_a_bounding_box_test() -> void:
	assert(not GrappleController.yoyo_segment_crosses_rect(Vector2(-100.0, 0.0), Vector2(0.0, -100.0), Rect2(-20.0, -20.0, 40.0, 40.0)))
	assert(GrappleController.yoyo_segment_crosses_rect(Vector2(-100.0, 0.0), Vector2(100.0, 0.0), Rect2(-20.0, -20.0, 40.0, 40.0)))

func test_swept_body_contact_stops_on_incoming_side_in_both_directions() -> void:
	for side: float in [1.0, -1.0]:
		var contact: Vector2 = Chakram.swept_circle_entry(Vector2(-100.0 * side, 0.0), Vector2(100.0 * side, 0.0), Vector2.ZERO, 34.0)
		assert(contact.is_equal_approx(Vector2(-34.0 * side, 0.0)))
