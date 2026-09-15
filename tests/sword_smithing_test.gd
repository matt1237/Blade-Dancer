class_name SwordSmithingTest extends Node

const SMITHING_SCENE: PackedScene = preload("res://scenes/minigames/sword_smithing.tscn")

func _make_game() -> SwordSmithingGame:
	var game: SwordSmithingGame = SMITHING_SCENE.instantiate() as SwordSmithingGame
	add_child(game)
	game.reset_forge()
	return game

func test_forge_stage_colors_are_distinct_and_ordered() -> void:
	var game: SwordSmithingGame = _make_game()
	var colors: Array[Color] = []
	for stage: int in range(4):
		game.forge_stage = stage
		colors.append(game._forge_stage_color())
	assert(colors[0] == Color("8fc9e8"))
	assert(colors[1] == Color("f2d46b"))
	assert(colors[2] == Color("f29a45"))
	assert(colors[3] == Color("ef5b4f"))
	game.free()

func test_forge_drops_one_stage_every_ten_seconds() -> void:
	var game: SwordSmithingGame = _make_game()
	game.forge_stage = 3
	game.forge_stage_time_left = game.forge_stage_duration
	game._update_forge_stage_decay(game.forge_stage_duration + 0.01)
	assert(game.forge_stage == 2)
	assert(is_equal_approx(game.forge_stage_time_left, game.forge_stage_duration))
	game._update_forge_stage_decay(game.forge_stage_duration + 0.01)
	assert(game.forge_stage == 1)
	game._update_forge_stage_decay(game.forge_stage_duration + 0.01)
	assert(game.forge_stage == 0 and game.forge_stage_time_left == 0.0)
	game.free()

func test_bellows_advances_forge_stage_every_two_ready_pumps() -> void:
	var game: SwordSmithingGame = _make_game()
	game.bellows_charge = 1.0
	game._pump_bellows()
	assert(game.forge_stage == 0)
	game.bellows_charge = 1.0
	game._pump_bellows()
	assert(game.forge_stage == 1 and game._forge_stage_name() == "HOT")
	game.free()

func test_hammer_ready_sparks_only_when_refill_reaches_full() -> void:
	var game: SwordSmithingGame = _make_game()
	game.hammer_charge = 0.5
	game.hammer_charge_was_full = false
	game.hammer_ready_spark_time_left = 0.0
	game._update_hammer_recharge(game.hammer_recharge_duration * 0.25)
	assert(game.hammer_ready_spark_time_left == 0.0)
	game._update_hammer_recharge(game.hammer_recharge_duration)
	assert(game.hammer_charge == 1.0 and game.hammer_ready_spark_time_left > 0.0)
	game.free()

func test_endpoint_multiplier_rises_near_completion() -> void:
	var game: SwordSmithingGame = _make_game()
	var early_multiplier: float = game._endpoint_multiplier(0.10, game.endpoint_stretch_multiplier)
	var late_multiplier: float = game._endpoint_multiplier(0.98, game.endpoint_stretch_multiplier)
	assert(late_multiplier > early_multiplier * 2.0, "Endpoint assistance should rise sharply near completion.")
	assert(late_multiplier > 3.5, "Near-finished endpoints should approach the configured 4x maximum.")
	game.free()

func test_ideal_endpoint_strikes_can_finish_the_tip() -> void:
	var game: SwordSmithingGame = _make_game()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.65
	var tip_point: Vector2 = Vector2(game.billet_position.x - game.billet_length * 0.5, game.billet_position.y)
	for strike_index: int in range(10):
		game.hammer_charge = 1.0
		game._hammer_at(tip_point)
	assert(absf(game.section_half_widths[0] - game.target_half_widths[0]) < 0.5, "The tip must be physically able to close to its template width.")
	assert(absf(game.section_positions[0] - game.target_positions[0]) < 0.02, "Endpoint leverage should stretch the tip to full blade length.")
	game.free()

func test_hammer_recharge_controls_strike_strength() -> void:
	var game: SwordSmithingGame = _make_game()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.65
	game.hammer_charge = 0.0
	var weak_before: float = game.section_half_widths[10]
	game._hammer_at(game.billet_position)
	var weak_change: float = absf(game.section_half_widths[10] - weak_before)
	game.reset_forge()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.65
	game.hammer_charge = 1.0
	var strong_before: float = game.section_half_widths[10]
	game._hammer_at(game.billet_position)
	var strong_change: float = absf(game.section_half_widths[10] - strong_before)
	assert(strong_change > weak_change, "A fully charged hammer blow must deform more than a rushed strike.")
	game.free()

func test_reset_places_fresh_billet_on_forge() -> void:
	var game: SwordSmithingGame = _make_game()
	game.billet_position = game.anvil_rect.get_center()
	game.reset_forge()
	assert(game.billet_station == SwordSmithingGame.FORGE_STATION)
	assert(game.billet_position == game.forge_rect.get_center())
	game.free()

func test_billet_has_local_temperature_sections() -> void:
	var game: SwordSmithingGame = _make_game()
	assert(game.section_temperatures.size() == 20)
	game.billet_station = SwordSmithingGame.FORGE_STATION
	game.billet_position = game.forge_rect.get_center()
	game._heat_billet(1.0)
	var distinct_temperature: bool = false
	for temperature: float in game.section_temperatures:
		if not is_equal_approx(temperature, game.section_temperatures[0]): distinct_temperature = true
	assert(distinct_temperature, "Forge heating must be local across the billet.")
	game.free()

func test_cold_hammering_is_weaker_than_hot_hammering() -> void:
	var game: SwordSmithingGame = _make_game()
	var cold_width: float = game.section_half_widths[10]
	game._hammer_at(game.billet_position)
	var cold_change: float = absf(game.section_half_widths[10] - cold_width)
	game.section_temperatures[10] = 1.0
	var hot_width: float = game.section_half_widths[10]
	game._hammer_at(game.billet_position)
	var hot_change: float = absf(game.section_half_widths[10] - hot_width)
	assert(hot_change > cold_change, "Hotter sections should deform more strongly.")
	game.free()

func test_hammer_changes_only_visible_top_edge() -> void:
	var game: SwordSmithingGame = _make_game()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.65
	var lower_before: Array[float] = game.bottom_half_widths.duplicate()
	game._hammer_at(game.billet_position)
	assert(game.bottom_half_widths == lower_before, "A hammer strike must not deform the hidden lower edge.")
	game.free()

func test_flip_physically_swaps_visible_edges() -> void:
	var game: SwordSmithingGame = _make_game()
	game.section_half_widths[5] = 11.0
	game.bottom_half_widths[5] = 27.0
	var flip_event: InputEventKey = InputEventKey.new()
	flip_event.keycode = KEY_F
	flip_event.pressed = true
	game._unhandled_key_input(flip_event)
	assert(is_equal_approx(game.section_half_widths[5], 27.0))
	assert(is_equal_approx(game.bottom_half_widths[5], 11.0))
	game.free()

func test_billet_heats_from_overlap_without_being_dropped() -> void:
	var game: SwordSmithingGame = _make_game()
	game.billet_station = SwordSmithingGame.ANVIL_STATION
	game.dragging_billet = true
	game.billet_position = game.forge_rect.get_center()
	game._update_billet_temperatures(1.0)
	assert(game.section_temperatures[10] > 0.0, "A held billet must heat immediately while overlapping the forge.")
	game.free()

func test_ideal_quench_heat_scores_above_cold_quench() -> void:
	var game: SwordSmithingGame = _make_game()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.0
	var cold_factor: float = game.quench_score_factor()
	for section_index: int in range(game.SECTION_COUNT): game.section_temperatures[section_index] = 0.65
	assert(game.quench_score_factor() > cold_factor, "Even ideal heat across the blade must improve quench score.")
	game.free()

func test_extra_hammer_strikes_reduce_score() -> void:
	var game: SwordSmithingGame = _make_game()
	game.time_left = game.session_duration * 0.5
	game.strike_count = game.efficient_strike_count
	var efficient_score: int = game.smithing_score()
	game.strike_count = game.efficient_strike_count + 10
	assert(game.smithing_score() < efficient_score, "Extra strikes must reduce the final score.")
	game.free()

func test_remaining_time_increases_score() -> void:
	var game: SwordSmithingGame = _make_game()
	game.time_left = 10.0
	var late_score: int = game.smithing_score()
	game.time_left = game.session_duration
	assert(game.smithing_score() > late_score, "The same blade should score higher with more time remaining.")
	game.free()

func test_profile_is_exposed_and_quench_requires_accuracy() -> void:
	var game: SwordSmithingGame = _make_game()
	assert(game.forged_profile_polygon().size() == 40)
	game.minimum_quench_accuracy = 0.99
	game._drop_billet(game.trough_rect.get_center())
	assert(not game.finished, "A crude billet should not quench yet.")
	game.free()
