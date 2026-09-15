class_name DamageNumbersTest extends Node

func test_persistent_status_vignette_colors_and_priority() -> void:
	var presentation: CombatPresentationFX = CombatPresentationFX.new()
	var player: Player = Player.new()
	add_child(presentation)
	presentation.player_ref = player
	player.max_health = 100.0
	player.health = 20.0
	player.flow = 0.0
	var danger_state: Dictionary = presentation.status_vignette_state()
	assert(bool(danger_state["active"]), "Low health should activate the persistent vignette.")
	assert((danger_state["color"] as Color).g < 0.2, "Low health vignette should be visibly red rather than gold.")
	player.health = 100.0
	player.flow = 100.0
	var flow_state: Dictionary = presentation.status_vignette_state()
	assert(bool(flow_state["active"]), "Maximum Flow should activate the persistent vignette.")
	assert((flow_state["color"] as Color).g > 0.7, "High Flow vignette should use the light-gold color.")
	player.health = 5.0
	var combined_state: Dictionary = presentation.status_vignette_state()
	assert((combined_state["color"] as Color).g < 0.2, "Low-health red should dominate when health danger and high Flow overlap.")
	assert(float(combined_state["intensity"]) <= presentation.low_health_vignette_max_alpha, "Combined states must not over-brighten the screen edges.")
	presentation.queue_free()
	player.free()

func test_damage_number_colors_and_quality_scaling() -> void:
	var presentation: CombatPresentationFX = CombatPresentationFX.new()
	add_child(presentation)
	presentation._setup_screen_overlay()
	presentation.show_damage_number(Vector2(200.0, 200.0), 25.0, false, 0.5)
	presentation.show_damage_number(Vector2(300.0, 200.0), 42.5, false, 0.8)
	presentation.show_damage_number(Vector2(400.0, 200.0), 10.0, true, 0.0)
	assert(presentation.floating_damage_numbers.size() == 3, "Three actual damage events should create three numbers.")
	assert(is_equal_approx(presentation.floating_damage_numbers[0].size_scale, 1.0), "Normal contacts use normal-sized numbers.")
	assert(is_equal_approx(presentation.floating_damage_numbers[1].size_scale, 1.5), "Quality 0.8 contacts use 1.5x numbers.")
	assert(presentation.floating_damage_numbers[1].label.text == "42.5", "Fractional actual damage remains visible.")
	var enemy_color: Color = presentation.floating_damage_numbers[0].label.get_theme_color("font_color")
	var player_color: Color = presentation.floating_damage_numbers[2].label.get_theme_color("font_color")
	assert(enemy_color.is_equal_approx(presentation.enemy_damage_number_color), "Enemy damage numbers should be red.")
	assert(player_color.is_equal_approx(presentation.player_damage_number_color), "Player damage numbers should be blue.")
	presentation._update_damage_numbers(1.0)
	assert(presentation.floating_damage_numbers.is_empty(), "Expired damage numbers should clean themselves up.")
	presentation.queue_free()
