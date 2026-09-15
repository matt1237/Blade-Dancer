class_name ControllerInputTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func test_controller_deadzone_preserves_direction_and_analog_strength() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.set_input_mode(Player.INPUT_MODE_CONTROLLER)
	assert(player._apply_controller_deadzone(Vector2(0.1, 0.0)) == Vector2.ZERO, "Small stick drift should be ignored.")
	var full_right: Vector2 = player._apply_controller_deadzone(Vector2.RIGHT)
	assert(full_right.x > 0.99 and absf(full_right.y) < 0.01, "A full left-stick tilt should preserve its movement direction.")
	var upward_aim: Vector2 = player._apply_controller_deadzone(Vector2.UP)
	assert(upward_aim.y < -0.99, "A full right-stick tilt should preserve its aim direction.")
	player.free()

func test_requested_xbox_button_mapping_is_explicit() -> void:
	assert(Player.CONTROLLER_DASH_BUTTON == JOY_BUTTON_LEFT_SHOULDER, "Dash must use the Xbox left bumper.")
	assert(Player.CONTROLLER_CHAKRAM_BUTTON == JOY_BUTTON_RIGHT_SHOULDER, "Chakram must use the Xbox right bumper.")
	assert(Player.CONTROLLER_STYLE_PREVIOUS_BUTTON == JOY_BUTTON_DPAD_LEFT)
	assert(Player.CONTROLLER_STYLE_NEXT_BUTTON == JOY_BUTTON_DPAD_RIGHT)
