class_name MobileControlsTest extends Node

const MOBILE_CONTROLS_SCENE: PackedScene = preload("res://scenes/ui/mobile_controls.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _ready() -> void:
	test_stick_vector_is_clamped_and_directional()
	test_ability_centers_are_distinct()
	test_hidden_controls_clear_all_state()
	test_player_uses_mobile_sticks_and_hold_states()
	test_multitouch_routes_sticks_and_button_release()
	test_grapple_endpoint_respects_configured_range()
	print("Mobile controls tests passed")
	get_tree().quit()

func test_stick_vector_is_clamped_and_directional() -> void:
	var controls: MobileControls = MOBILE_CONTROLS_SCENE.instantiate() as MobileControls
	add_child(controls)
	controls.current_stick_radius = 100.0
	var vector: Vector2 = controls._stick_vector(Vector2.ZERO, Vector2(300.0, 0.0))
	assert(is_equal_approx(vector.length(), 1.0), "A stick cannot exceed its maximum radius.")
	assert(vector.is_equal_approx(Vector2.RIGHT), "A right stick drag should preserve direction.")
	controls.queue_free()

func test_ability_centers_are_distinct() -> void:
	var controls: MobileControls = MOBILE_CONTROLS_SCENE.instantiate() as MobileControls
	add_child(controls)
	controls.right_stick_center = Vector2(800.0, 500.0)
	controls.current_stick_radius = 80.0
	var chakram_center: Vector2 = controls._ability_center("chakram")
	var dash_center: Vector2 = controls._ability_center("dash")
	var grapple_center: Vector2 = controls._ability_center("grapple")
	assert(chakram_center.distance_to(dash_center) > controls.current_button_radius, "Chakram and Dash buttons must not overlap.")
	assert(dash_center.distance_to(grapple_center) > controls.current_button_radius, "Dash and Grapple buttons must not overlap.")
	controls.queue_free()

func test_hidden_controls_clear_all_state() -> void:
	var controls: MobileControls = MOBILE_CONTROLS_SCENE.instantiate() as MobileControls
	add_child(controls)
	controls.force_visible_on_desktop = true
	controls.gameplay_visible = true
	controls.ability_held["dash"] = true
	controls.move_value = Vector2.RIGHT
	controls._reset_all_inputs()
	assert(controls.move_value == Vector2.ZERO, "Hiding controls must release movement.")
	assert(not bool(controls.ability_held["dash"]), "Hiding controls must release abilities.")
	controls.queue_free()

func test_player_uses_mobile_sticks_and_hold_states() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.set_mobile_controls_enabled(true)
	player.set_mobile_move_input(Vector2.LEFT)
	player.set_mobile_aim_direction(Vector2.UP)
	player.set_mobile_ability_held("dash", true)
	player.set_mobile_ability_held("chakram", true)
	player.set_mobile_ability_held("grapple", true)
	assert(player._movement_input().is_equal_approx(Vector2.LEFT), "Mobile movement must drive Player movement.")
	assert(player._current_aim_direction().is_equal_approx(Vector2.UP), "Mobile aim must drive sword direction.")
	assert(player.mobile_dash_held and player.mobile_chakram_held and player.mobile_grapple_held, "Mobile hold states must reach Player.")
	player.set_mobile_ability_held("dash", false)
	player.set_mobile_ability_held("chakram", false)
	player.set_mobile_ability_held("grapple", false)
	assert(not player.mobile_dash_held and not player.mobile_chakram_held and not player.mobile_grapple_held, "Releasing each mobile ability must clear its hold state.")
	player.set_mobile_controls_enabled(false)
	assert(player._movement_input() == Vector2.ZERO, "Disabling mobile input must release movement.")
	assert(not player.mobile_dash_held, "Disabling mobile input must release held abilities.")
	player.free()

func test_multitouch_routes_sticks_and_button_release() -> void:
	var controls: MobileControls = MOBILE_CONTROLS_SCENE.instantiate() as MobileControls
	add_child(controls)
	controls.force_visible_on_desktop = true
	controls.set_gameplay_visible(true)
	controls._handle_pointer_down(1, controls.left_stick_center + Vector2.RIGHT * controls.current_stick_radius)
	controls._handle_pointer_down(2, controls.right_stick_center + Vector2.UP * controls.current_stick_radius)
	controls._handle_pointer_down(3, controls._ability_center("dash"))
	assert(controls.move_value.x > 0.9, "The left touch must drive movement.")
	assert(controls.aim_value.y < -0.9, "The second touch must drive aim.")
	assert(bool(controls.ability_held["dash"]), "A third touch must hold Dash.")
	controls._handle_pointer_up(3)
	controls._handle_pointer_up(1)
	controls._handle_pointer_up(2)
	assert(not bool(controls.ability_held["dash"]), "Releasing the button touch must release Dash.")
	assert(controls.move_value == Vector2.ZERO, "Releasing the movement touch must stop movement.")
	controls.queue_free()

func test_grapple_endpoint_respects_configured_range() -> void:
	var endpoint: Vector2 = GrappleController.aimed_endpoint(Vector2.ZERO, Vector2.RIGHT * 1000.0, 640.0)
	assert(endpoint.distance_to(Vector2.ZERO) == 640.0, "Grapple aiming must clamp to its configured range.")
