class_name CauldronCatchTest extends Node

const CAULDRON_CATCH_SCENE: PackedScene = preload("res://scenes/minigames/cauldron_catch.tscn")

func _make_game() -> CauldronCatchGame:
	# Match the project's established test convention (see menu_flow_test.gd):
	# manually resolve the @onready fields via get_node() instead of relying
	# on _ready(), since instantiated-but-untreed nodes never receive it here.
	var game: CauldronCatchGame = CAULDRON_CATCH_SCENE.instantiate() as CauldronCatchGame
	game.food_layer = game.get_node("FoodLayer") as Control
	game.cauldron_clip = game.get_node("CauldronClip") as Control
	game.cauldron_sprite = game.get_node("CauldronClip/Cauldron") as TextureRect
	game.cauldron_ghost = game.get_node("CauldronClip/CauldronGhost") as TextureRect
	game.score_label = game.get_node("HUD/ScoreLabel") as Label
	game.timer_label = game.get_node("HUD/TimerLabel") as Label
	game.bad_label = game.get_node("HUD/BadLabel") as Label
	game.streak_label = game.get_node("HUD/StreakLabel") as Label
	game.buff_label = game.get_node("HUD/BuffLabel") as Label
	game.shield_label = game.get_node("HUD/ShieldLabel") as Label
	game.feedback_layer = game.get_node("FeedbackLayer") as Control
	game.start_overlay = game.get_node("StartOverlay") as Panel
	game.start_button = game.get_node("StartOverlay/StartButton") as Button
	game.end_overlay = game.get_node("EndOverlay") as Panel
	game.end_title = game.get_node("EndOverlay/EndTitle") as Label
	game.end_score_label = game.get_node("EndOverlay/EndScoreLabel") as Label
	game.play_again_button = game.get_node("EndOverlay/PlayAgainButton") as Button
	game.close_button_end = game.get_node("EndOverlay/CloseButton") as Button
	game.close_button_top = game.get_node("CloseButtonTop") as Button
	game.start_button.pressed.connect(game.start_game)
	game.play_again_button.pressed.connect(game.start_game)
	game.close_button_end.pressed.connect(game._close)
	game.close_button_top.pressed.connect(game._close)
	game.end_overlay.visible = false
	add_child(game)
	game.start_game()
	return game

func test_cauldron_wraps_from_left_edge_to_right_edge() -> void:
	var game: CauldronCatchGame = _make_game()
	game.cauldron_x = game.play_field_left - 5.0
	game._handle_cauldron_input(0.0)
	assert(is_equal_approx(game.cauldron_x, game.play_field_right - 5.0), "Moving past the left edge should wrap the cauldron in from the right edge.")
	game.free()

func test_cauldron_wraps_from_right_edge_to_left_edge() -> void:
	var game: CauldronCatchGame = _make_game()
	game.cauldron_x = game.play_field_right + 5.0
	game._handle_cauldron_input(0.0)
	assert(is_equal_approx(game.cauldron_x, game.play_field_left + 5.0), "Moving past the right edge should wrap the cauldron in from the left edge.")
	game.free()

func test_ghost_cauldron_mirrors_the_real_cauldron_by_exactly_one_field_width() -> void:
	# The ghost always exists one full field-width away from the real
	# cauldron — cauldron_clip's own clipping is what makes only the
	# relevant sliver of each one actually visible, not manual show/hide
	# logic, so the two combined always look like one continuous sprite.
	var game: CauldronCatchGame = _make_game()
	var field_width: float = game.play_field_right - game.play_field_left
	game.cauldron_x = game.play_field_left + 10.0
	game._handle_cauldron_input(0.0)
	assert(game.cauldron_ghost.visible, "The ghost cauldron must always be positioned and shown; clipping — not visibility toggling — hides the irrelevant copy.")
	var real_clip_x: float = game.cauldron_sprite.position.x
	var ghost_clip_x: float = game.cauldron_ghost.position.x
	assert(is_equal_approx(absf(ghost_clip_x - real_clip_x), field_width), "The ghost must sit exactly one field-width away from the real cauldron.")
	game.free()

func test_cauldron_clip_boundary_matches_the_play_field_exactly() -> void:
	# The curtain effect only looks seamless if clipping happens exactly at
	# the same boundary the cauldron wraps at — any mismatch would either
	# show a gap or cut the sprite off before it reaches the wrap point.
	var game: CauldronCatchGame = _make_game()
	assert(is_equal_approx(game.cauldron_clip.position.x, game.play_field_left), "The clip container's left edge must match play_field_left exactly.")
	assert(is_equal_approx(game.cauldron_clip.position.x + game.cauldron_clip.size.x, game.play_field_right), "The clip container's right edge must match play_field_right exactly.")
	game.free()

func test_wrapping_does_not_pop_the_cauldron_visually() -> void:
	# The real cauldron's own alpha must never be touched by wrapping — the
	# illusion is carried entirely by clipping, not by fading the sprite.
	var game: CauldronCatchGame = _make_game()
	game.cauldron_sprite.modulate.a = 1.0
	game.cauldron_x = game.play_field_left - 5.0
	game._handle_cauldron_input(0.0)
	assert(is_equal_approx(game.cauldron_sprite.modulate.a, 1.0), "Wrapping must not fade or hide the real cauldron sprite.")
	game.free()

func test_first_catch_awards_base_points_and_starts_streak() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	assert(game.score == game.catch_points, "First catch should award the base 20 points.")
	assert(game.streak == 1)
	game.free()

func test_consecutive_catches_award_escalating_streak_bonus() -> void:
	# 1st catch: base points only. 2nd: +5 bonus. 3rd: +10 bonus. And so on.
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	assert(game.score == game.catch_points, "First catch should award base points with no bonus.")
	game._catch_food(CauldronCatchGame.FoodKind.MUSHROOM, Vector2.ZERO)
	var second_catch_points: int = game.catch_points + game.streak_bonus_increment
	assert(game.score == game.catch_points + second_catch_points, "Second unbroken catch should add a +5 streak bonus.")
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	var third_catch_points: int = game.catch_points + game.streak_bonus_increment * 2
	assert(game.score == game.catch_points + second_catch_points + third_catch_points, "Third unbroken catch should add a +10 streak bonus.")
	assert(game.streak == 3)
	game.free()

func test_missing_a_good_food_costs_only_one_streak_step() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	assert(game.streak == 3, "Three unbroken catches should build a streak of 3.")
	game._miss_food(CauldronCatchGame.FoodKind.MUSHROOM)
	assert(game.streak == 2, "A single miss should only cost one streak step, not the whole streak.")
	game.free()

func test_missing_a_good_food_at_streak_one_drops_to_zero() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._miss_food(CauldronCatchGame.FoodKind.MUSHROOM)
	assert(game.streak == 0, "Missing at streak 1 should drop to 0, not below.")
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	assert(game.score == game.catch_points * 2, "Rebuilding from 0 should award base points with no bonus.")
	game.free()

func test_missing_bad_food_is_free_and_does_not_affect_streak() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._miss_food(CauldronCatchGame.FoodKind.BAD_FRUIT)
	assert(game.streak == 1, "Letting a bad fruit fall through must not penalize the streak.")
	game.free()

func test_catching_bad_fruit_penalizes_and_clamps_at_zero() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	assert(game.score == 0, "Score should clamp at zero rather than go negative.")
	assert(game.bad_catches == 1)
	assert(game.streak == 0)
	game.free()

func test_catching_bad_fruit_subtracts_from_existing_score() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	assert(game.score == maxi(0, game.catch_points - game.bad_catch_penalty), "A bad catch must subtract its penalty from the earned score.")
	game.free()

func test_third_bad_catch_ends_the_run_in_failure() -> void:
	var game: CauldronCatchGame = _make_game()
	game.catch_points = 20
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	assert(game.is_playing, "Two bad catches should not end the run yet.")
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	assert(not game.is_playing, "A third bad catch must fail the run immediately.")
	assert(game.end_overlay.visible)
	game.free()

func test_closed_signal_reports_final_score_and_high_score_flag() -> void:
	var game: CauldronCatchGame = _make_game()
	game.set_high_score(15)
	var received_score: Array = []
	var received_high_score: Array = []
	game.closed.connect(func(final_score: int, is_new_high_score: bool) -> void:
		received_score.append(final_score)
		received_high_score.append(is_new_high_score))
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._end_game(true)
	assert(received_score.size() == 1 and received_score[0] == 20)
	assert(received_high_score[0] == true, "20 beats the seeded high score of 15.")
	game.free()

func test_timer_reaching_zero_ends_the_run_as_completed() -> void:
	var game: CauldronCatchGame = _make_game()
	game.time_left = 0.02
	game._update_timer(0.05)
	assert(not game.is_playing)
	assert(game.end_overlay.visible)
	assert(game.end_title.text == "TIME'S UP!")
	game.free()

func test_food_spawner_never_produces_a_power_up() -> void:
	var game: CauldronCatchGame = _make_game()
	# Force only the food timer to fire this tick; leave the power-up timer far off.
	game.spawn_timer_left = 0.0
	game.powerup_spawn_timer_left = 999.0
	game._update_spawning(0.001)
	game._update_powerup_spawning(0.001)
	assert(game.active_foods.size() == 1, "Only the food spawner should have fired this tick.")
	var spawned_kind: CauldronCatchGame.FoodKind = game.active_foods[0]["kind"] as CauldronCatchGame.FoodKind
	var is_regular_food: bool = spawned_kind == CauldronCatchGame.FoodKind.TURKEY or spawned_kind == CauldronCatchGame.FoodKind.MUSHROOM or spawned_kind == CauldronCatchGame.FoodKind.BAD_FRUIT
	assert(is_regular_food, "The food spawner must never produce a clock or shield — that's the power-up spawner's job.")
	game.free()

func test_powerup_spawner_fires_independently_of_the_food_timer() -> void:
	var game: CauldronCatchGame = _make_game()
	# Leave the food timer far off; force only the power-up timer to fire,
	# with clock_drop_chance pinned to guarantee a clock this roll.
	game.spawn_timer_left = 999.0
	game.powerup_spawn_timer_left = 0.0
	game.clock_drop_chance = 1.0
	game.shield_drop_chance = 0.0
	game._update_spawning(0.001)
	game._update_powerup_spawning(0.001)
	assert(game.active_foods.size() == 1, "Only the power-up spawner should have fired this tick — it must not consume a food spawn slot.")
	var spawned_kind: CauldronCatchGame.FoodKind = game.active_foods[0]["kind"] as CauldronCatchGame.FoodKind
	assert(spawned_kind == CauldronCatchGame.FoodKind.CLOCK_SLOW or spawned_kind == CauldronCatchGame.FoodKind.CLOCK_FAST)
	game.free()

func test_powerup_roll_can_legitimately_spawn_nothing() -> void:
	var game: CauldronCatchGame = _make_game()
	game.powerup_spawn_timer_left = 0.0
	game.clock_drop_chance = 0.0
	game.shield_drop_chance = 0.0
	game._update_powerup_spawning(0.001)
	assert(game.active_foods.is_empty(), "A power-up roll below both thresholds must spawn nothing — that's the whole point of a separate timer.")
	game.free()

func test_catching_green_clock_slows_good_food_and_leaves_score_untouched() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.CLOCK_SLOW, Vector2.ZERO)
	assert(game.score == 0 and game.streak == 0, "A clock catch must never award points or build a streak.")
	assert(is_equal_approx(game.speed_buff_multiplier, game.clock_slow_multiplier))
	assert(is_equal_approx(game.speed_buff_time_left, game.clock_buff_duration))
	assert(game.buff_label.visible and game.buff_label.text.begins_with("SLOWED"))
	game.free()

func test_catching_red_clock_speeds_up_good_food() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.CLOCK_FAST, Vector2.ZERO)
	assert(is_equal_approx(game.speed_buff_multiplier, game.clock_fast_multiplier))
	assert(game.buff_label.text.begins_with("SPED UP"))
	game.free()

func test_missing_a_clock_does_not_break_the_streak() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._miss_food(CauldronCatchGame.FoodKind.CLOCK_SLOW)
	assert(game.streak == 1, "Missing a clock power-up must not cost the streak.")
	game.free()

func test_active_buff_changes_effective_fall_speed_of_good_food_only() -> void:
	var game: CauldronCatchGame = _make_game()
	game.cauldron_x = -5000.0 # keep everything well out of catch range for this check
	game.speed_buff_multiplier = game.clock_slow_multiplier
	game.speed_buff_time_left = game.clock_buff_duration
	var turkey_icon: TextureRect = TextureRect.new()
	turkey_icon.size = Vector2(game.food_icon_size, game.food_icon_size)
	turkey_icon.position = Vector2(200.0, 200.0)
	game.food_layer.add_child(turkey_icon)
	game.active_foods.append({"node": turkey_icon, "kind": CauldronCatchGame.FoodKind.TURKEY, "speed": 100.0})
	var bad_icon: TextureRect = TextureRect.new()
	bad_icon.size = Vector2(game.food_icon_size, game.food_icon_size)
	bad_icon.position = Vector2(200.0, 200.0)
	game.food_layer.add_child(bad_icon)
	game.active_foods.append({"node": bad_icon, "kind": CauldronCatchGame.FoodKind.BAD_FRUIT, "speed": 100.0})
	game._update_falling_foods(1.0)
	var turkey_travel: float = turkey_icon.position.y - 200.0
	var bad_travel: float = bad_icon.position.y - 200.0
	assert(is_equal_approx(turkey_travel, 100.0 * game.clock_slow_multiplier), "Good food should fall at the buffed speed.")
	assert(is_equal_approx(bad_travel, 100.0), "Bad fruit must be unaffected by the good-food speed buff.")
	game.free()

func test_catching_shield_grants_no_points_and_starts_the_timer() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.ANGEL_SHIELD, Vector2.ZERO)
	assert(game.score == 0 and game.streak == 0, "Catching the shield must never award points or build a streak.")
	assert(is_equal_approx(game.streak_shield_time_left, game.shield_duration))
	assert(game.shield_label.visible and game.shield_label.text.begins_with("SHIELDED"))
	game.free()

func test_shield_protects_streak_from_a_missed_good_food() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.ANGEL_SHIELD, Vector2.ZERO)
	game._miss_food(CauldronCatchGame.FoodKind.MUSHROOM)
	assert(game.streak == 1, "An active shield must prevent a missed good food from breaking the streak.")
	game.free()

func test_shield_protects_streak_from_a_bad_catch_but_not_the_penalty() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.ANGEL_SHIELD, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.BAD_FRUIT, Vector2.ZERO)
	assert(game.streak == 1, "An active shield must prevent a bad catch from breaking the streak.")
	assert(game.score == maxi(0, game.catch_points - game.bad_catch_penalty), "The score penalty still applies even while shielded.")
	assert(game.bad_catches == 1, "The shield only protects the streak, not the 3-strikes fail counter.")
	game.free()

func test_shield_expires_and_streak_breaks_normally_again() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._catch_food(CauldronCatchGame.FoodKind.ANGEL_SHIELD, Vector2.ZERO)
	game.streak_shield_time_left = 0.0 # simulate the buff having timed out
	game._miss_food(CauldronCatchGame.FoodKind.MUSHROOM)
	assert(game.streak == 0, "Once the shield expires, a miss should break the streak as usual.")
	game.free()

func test_missing_the_shield_itself_does_not_break_the_streak() -> void:
	var game: CauldronCatchGame = _make_game()
	game._catch_food(CauldronCatchGame.FoodKind.TURKEY, Vector2.ZERO)
	game._miss_food(CauldronCatchGame.FoodKind.ANGEL_SHIELD)
	assert(game.streak == 1, "Letting the shield power-up fall through must not cost the streak.")
	game.free()

func test_fast_food_cannot_tunnel_through_the_catch_band_uncaught() -> void:
	# A food moving fast enough to cross the entire catch band within a single
	# frame must still register as caught (swept check), not skip straight
	# through to a miss.
	var game: CauldronCatchGame = _make_game()
	game.cauldron_x = 640.0
	var catch_top: float = game.cauldron_sprite.global_position.y
	var icon: TextureRect = TextureRect.new()
	icon.size = Vector2(game.food_icon_size, game.food_icon_size)
	# Positioned just above the catch band, moving so fast that one frame's
	# travel would land it well past play_field_bottom if unswept.
	icon.position = Vector2(640.0 - game.food_icon_size * 0.5, catch_top - game.food_icon_size - 1.0)
	game.food_layer.add_child(icon)
	game.active_foods.append({"node": icon, "kind": CauldronCatchGame.FoodKind.TURKEY, "speed": 5000.0})
	game._update_falling_foods(1.0)
	assert(game.score == game.catch_points, "The fast-moving food must still be caught, not tunnel through.")
	assert(game.active_foods.is_empty())
	game.free()

func test_bad_catch_mid_frame_does_not_crash_falling_food_update() -> void:
	# Regression test: a bad catch that ends the run mid-loop must not leave
	# _update_falling_foods() operating on stale indices into a cleared array.
	var game: CauldronCatchGame = _make_game()
	game.bad_catches = 2
	game.cauldron_x = 640.0
	for _index: int in range(3):
		var icon: TextureRect = TextureRect.new()
		icon.size = Vector2(game.food_icon_size, game.food_icon_size)
		icon.position = Vector2(640.0 - game.food_icon_size * 0.5, game.cauldron_sprite.global_position.y + 5.0)
		game.food_layer.add_child(icon)
		game.active_foods.append({"node": icon, "kind": CauldronCatchGame.FoodKind.BAD_FRUIT, "speed": 100.0})
	game._update_falling_foods(0.016)
	assert(not game.is_playing, "The third simultaneous bad catch should have ended the run.")
	assert(game.active_foods.is_empty(), "Ending the run mid-loop must leave no stale entries behind.")
	game.free()
