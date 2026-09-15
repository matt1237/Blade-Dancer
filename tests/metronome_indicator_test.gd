class_name MetronomeIndicatorTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func test_indicator_uses_exact_metronome_reversal_angles() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 1
	player.sword_style = Player.SwordStyle.METRONOME
	player.aim_angle = 0.0
	player.swing_time = 0.25 / player.metronome_swing_frequency
	var right_transform: Dictionary = player._sword_transform()
	assert(is_equal_approx(rad_to_deg(float(right_transform["angle"])), player.metronome_arc_degrees), "Right indicator limit must match the real sword reversal.")
	player.swing_time = 0.75 / player.metronome_swing_frequency
	var left_transform: Dictionary = player._sword_transform()
	assert(is_equal_approx(rad_to_deg(float(left_transform["angle"])), -player.metronome_arc_degrees), "Left indicator limit must match the real sword reversal.")
	player.free()

func test_reversal_pulse_marks_the_side_the_sword_reached() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.sword_style = Player.SwordStyle.METRONOME
	player.aim_angle = 0.0
	player._begin_metronome_reversal_pulse(deg_to_rad(player.metronome_arc_degrees))
	assert(player.metronome_reversal_side == 1.0)
	assert(is_equal_approx(player.metronome_reversal_flash_left, player.metronome_reversal_pulse_duration))
	player._begin_metronome_reversal_pulse(deg_to_rad(-player.metronome_arc_degrees))
	assert(player.metronome_reversal_side == -1.0)
	player.free()

func test_indicator_is_enabled_for_metronome_by_default() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	assert(player.show_metronome_indicator, "The Metronome readability indicator should be enabled by default.")
	assert(player.metronome_indicator_radius > 0.0, "The indicator needs a visible radius.")
	assert(is_equal_approx(player.metronome_indicator_opacity, 0.65), "The visualizer should be 35% transparent so it does not overpower the sword.")
	player.free()
