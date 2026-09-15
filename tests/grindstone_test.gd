class_name GrindstoneTest extends Node

const GRINDSTONE_SCENE: PackedScene = preload("res://scenes/minigames/grindstone.tscn")

func _make_game() -> GrindstoneGame:
	var game: GrindstoneGame = GRINDSTONE_SCENE.instantiate() as GrindstoneGame
	add_child(game)
	# @onready fields are not resolved until the deferred _ready() callback,
	# which does not fire in time for a synchronous test — resolve manually.
	game.music_player = game.get_node("MusicPlayer") as AudioStreamPlayer
	game.start_game()
	return game

func test_sparks_spawn_continuously_while_holding_a_grind() -> void:
	var game: GrindstoneGame = _make_game()
	var grind_index: int = -1
	for event_index: int in range(game.events.size()):
		if int(game.events[event_index]["kind"]) == int(GrindstoneGame.EventKind.GRIND):
			grind_index = event_index
			break
	assert(grind_index >= 0)
	var grind_time: float = float(game.events[grind_index]["time"])
	game.elapsed = grind_time
	game.pressure_x = game.guide_x_at(grind_time)
	game._attempt_rhythm_press()
	assert(game.active_grind_index == grind_index)
	game.mouse_held = true
	game.active_sparks.clear()
	for _step_index: int in range(20):
		game._update_sparks(0.05)
	assert(not game.active_sparks.is_empty(), "Holding a grind must spawn sparks over time.")
	game.mouse_held = false
	game.active_sparks.clear()
	for _step_index: int in range(20):
		game._update_sparks(0.05)
	assert(game.active_sparks.is_empty(), "Sparks must not spawn once the grind is released.")
	game.free()

func test_balance_starts_centered_then_forces_drift_during_the_run() -> void:
	var game: GrindstoneGame = _make_game()
	assert(is_equal_approx(game.balance_position, 0.0))
	assert(is_equal_approx(game.balance_velocity, 0.0))
	game.rng.seed = 4451
	game._update_balance(game.balance_start_delay + 0.5)
	assert(not is_equal_approx(game.balance_force, 0.0), "The balance system should apply a force after the opening settle time.")
	game.free()

func test_balance_accuracy_rewards_centering_on_the_gauge() -> void:
	var game: GrindstoneGame = _make_game()
	game.balance_position = 0.0
	assert(is_equal_approx(game.balance_accuracy(), 1.0))
	game.balance_position = 0.9
	assert(game.balance_accuracy() < 0.1, "A balance ball far from center should score poorly.")
	game.free()

func test_accurate_tracing_emits_quiet_sparks() -> void:
	var game: GrindstoneGame = _make_game()
	game.elapsed = 8.0
	game.pressure_x = game.guide_x_at(game.elapsed)
	game.active_grind_index = -1
	game.mouse_held = false
	game.active_sparks.clear()
	game.trace_spark_timer = 0.0
	game._update_sparks(0.2)
	assert(not game.active_sparks.is_empty(), "Accurate pressure tracing should emit quiet sparks.")
	assert(float(game.active_sparks[0]["thickness"]) < 2.0, "Tracer sparks should be subtler than grind sparks.")
	game.free()

func test_releasing_mid_grind_stops_the_loop_and_plays_a_landing_hit() -> void:
	var game: GrindstoneGame = _make_game()
	var grind_index: int = -1
	for event_index: int in range(game.events.size()):
		if int(game.events[event_index]["kind"]) == int(GrindstoneGame.EventKind.GRIND):
			grind_index = event_index
			break
	assert(grind_index >= 0)
	var grind_time: float = float(game.events[grind_index]["time"])
	game.elapsed = grind_time
	game.pressure_x = game.guide_x_at(grind_time)
	game._attempt_rhythm_press()
	assert(game.active_grind_index == grind_index)
	# grind_loop_player only exists after real _ready(), which a synchronous
	# test never triggers — simulate an already-running loop so the release
	# path is actually exercised rather than trivially already-false.
	game.grind_loop_active = true
	var release_event: InputEventMouseButton = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	game._gui_input(release_event)
	assert(game.active_grind_index == -1, "Releasing the mouse mid-grind must end the hold immediately.")
	assert(not game.grind_loop_active, "The grind loop must stop once the hold ends.")
	game.free()

func test_retries_generate_different_procedural_runs() -> void:
	var game: GrindstoneGame = _make_game()
	game.randomize_runs = true
	game._generate_chart()
	var first_seed: int = game.generated_run_seed
	var first_events: Array[Dictionary] = game.events.duplicate(true)
	var first_curve_sample: float = game.guide_x_at(7.25)
	game._generate_chart()
	assert(game.generated_run_seed != first_seed, "Each retry should receive a fresh procedural seed.")
	var second_curve_sample: float = game.guide_x_at(7.25)
	var chart_changed: bool = first_events != game.events
	var curve_changed: bool = not is_equal_approx(first_curve_sample, second_curve_sample)
	assert(chart_changed or curve_changed, "A fresh run should change its timings or curvature.")
	game.free()

func test_debug_seed_reproduces_the_same_run() -> void:
	var game: GrindstoneGame = _make_game()
	game.randomize_runs = false
	game.chart_seed = 98123
	game._generate_chart()
	var first_events: Array[Dictionary] = game.events.duplicate(true)
	var first_curve_sample: float = game.guide_x_at(11.0)
	game._generate_chart()
	assert(first_events == game.events, "Disabling run randomization should reproduce chart timings.")
	assert(is_equal_approx(first_curve_sample, game.guide_x_at(11.0)), "The debug seed should reproduce guide curvature.")
	game.free()

func test_starting_a_game_selects_and_plays_a_grindstone_track() -> void:
	var game: GrindstoneGame = _make_game()
	assert(game.music_player.stream != null, "start_game() must select and assign a track.")
	assert(game.GRINDSTONE_TRACKS.has(game.music_player.stream), "The assigned stream must come from the Grindstone track library.")
	game.free()

func test_track_shuffle_bag_avoids_immediate_repeats_when_possible() -> void:
	var game: GrindstoneGame = _make_game()
	var first_index: int = game.current_track_index
	game.current_track_index = first_index
	game._refill_track_shuffle_bag()
	assert(game.track_shuffle_bag[0] != first_index or game.GRINDSTONE_TRACKS.size() <= 1, "A freshly refilled bag should not start with the just-played track when alternatives exist.")
	game.free()

func test_default_chart_stays_locked_to_strong_beats_in_4_4() -> void:
	var game: GrindstoneGame = _make_game()
	assert(game.beats_per_bar == 4)
	assert(game.is_strong_beat_locked(), "Default gap/duration choices must keep every event on beat 1 or 3 of a 4:4 bar.")
	game.track_bpm = 100.0
	game._generate_chart()
	var seconds_per_beat: float = game.beat_duration()
	for entry: Dictionary in game.events:
		var beat_in_bar: int = int(round(float(entry["time"]) / seconds_per_beat)) % game.beats_per_bar
		assert(beat_in_bar == 0 or beat_in_bar == 2, "Every event must land on beat 1 or beat 3, never beat 2 or 4.")
	game.free()

func test_odd_gap_choice_breaks_strong_beat_lock_detection() -> void:
	var game: GrindstoneGame = _make_game()
	game.event_gap_beats_choices = [2, 3]
	assert(not game.is_strong_beat_locked(), "An odd beat gap must be flagged as breaking the 4:4 strong-beat lock.")
	game.free()

func test_chart_events_are_quantized_to_the_track_bpm() -> void:
	var game: GrindstoneGame = _make_game()
	game.track_bpm = 100.0
	game._generate_chart()
	var seconds_per_beat: float = game.beat_duration()
	for entry: Dictionary in game.events:
		var beats_from_zero: float = float(entry["time"]) / seconds_per_beat
		var nearest_whole_beat: float = round(beats_from_zero)
		assert(is_equal_approx(beats_from_zero, nearest_whole_beat), "Every event must start exactly on a whole beat for the configured BPM.")
		if int(entry["kind"]) == int(GrindstoneGame.EventKind.GRIND):
			var duration_beats: float = float(entry["duration"]) / seconds_per_beat
			assert(is_equal_approx(duration_beats, round(duration_beats)), "Grind holds must last a whole number of beats.")
	game.free()

func test_different_bpm_changes_event_spacing_in_seconds() -> void:
	var slow_game: GrindstoneGame = _make_game()
	slow_game.track_bpm = 80.0
	slow_game._generate_chart()
	var fast_game: GrindstoneGame = _make_game()
	fast_game.track_bpm = 160.0
	fast_game._generate_chart()
	assert(slow_game.beat_duration() > fast_game.beat_duration(), "A lower BPM must produce a longer beat duration in seconds.")
	slow_game.free()
	fast_game.free()

func test_chart_generates_beats_and_grinds() -> void:
	var game: GrindstoneGame = _make_game()
	assert(game.events.size() > 0, "The procedural chart must generate events.")
	assert(game.beat_total > 0 and game.grind_total > 0, "Chart should include both beats and grinds with default settings.")
	game.free()

func test_pressure_point_eases_toward_mouse_target_instead_of_snapping() -> void:
	var game: GrindstoneGame = _make_game()
	game.pressure_x = game.guide_center_x
	game.target_pressure_x = game.guide_center_x + 300.0
	game._handle_pressure_input(0.016)
	assert(game.pressure_x > game.guide_center_x, "The pressure point must start moving toward the mouse target.")
	assert(game.pressure_x < game.target_pressure_x, "A single frame must not snap instantly to the mouse target.")
	game.free()

func test_pressure_point_eventually_reaches_a_held_mouse_target() -> void:
	var game: GrindstoneGame = _make_game()
	game.pressure_x = game.guide_center_x
	game.target_pressure_x = game.guide_center_x + 150.0
	for _frame_index: int in range(120):
		game._handle_pressure_input(0.016)
	assert(is_equal_approx(game.pressure_x, game.target_pressure_x), "Holding the mouse target should let the pressure point catch up over time.")
	game.free()

func test_mouse_motion_sets_target_without_moving_pressure_instantly() -> void:
	var game: GrindstoneGame = _make_game()
	game.pressure_x = game.guide_center_x
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(game.guide_center_x + 250.0, game.hit_y)
	game._gui_input(motion)
	assert(is_equal_approx(game.target_pressure_x, minf(game.pressure_max_x, game.guide_center_x + 250.0)))
	assert(is_equal_approx(game.pressure_x, game.guide_center_x), "Mouse motion alone must not move the pressure point; only the eased update loop should.")
	game.free()

func test_path_accuracy_is_independent_of_balance_accuracy() -> void:
	var game: GrindstoneGame = _make_game()
	game.balance_position = 1.0
	game.pressure_x = game.guide_x_at(0.0)
	game._update_tracing(1.0)
	assert(is_equal_approx(game.tracing_accuracy(), 1.0), "Path accuracy should measure pressure alignment without balance affecting it.")
	game.free()

func test_tracing_accuracy_rewards_following_the_guide() -> void:
	var game: GrindstoneGame = _make_game()
	game.pressure_x = game.guide_x_at(0.0)
	game._update_tracing(1.0)
	var on_guide_accuracy: float = game.tracing_accuracy()
	game.trace_score_total = 0.0
	game.trace_sample_time = 0.0
	game.pressure_x = game.guide_x_at(0.0) + game.tracing_tolerance * 5.0
	game._update_tracing(1.0)
	var off_guide_accuracy: float = game.tracing_accuracy()
	assert(on_guide_accuracy > off_guide_accuracy, "Staying on the guide must score higher than drifting far off it.")
	game.free()

func test_correctly_timed_beat_click_registers_a_hit() -> void:
	var game: GrindstoneGame = _make_game()
	var beat_index: int = -1
	for event_index: int in range(game.events.size()):
		if int(game.events[event_index]["kind"]) == int(GrindstoneGame.EventKind.BEAT):
			beat_index = event_index
			break
	assert(beat_index >= 0, "Default chart should contain at least one beat.")
	var beat_time: float = float(game.events[beat_index]["time"])
	game.elapsed = beat_time
	game.pressure_x = game.guide_x_at(beat_time)
	game._attempt_rhythm_press()
	assert(game.beat_hits == 1)
	assert(bool(game.events[beat_index]["resolved"]))
	game.free()

func test_click_far_from_any_event_counts_as_bad_press() -> void:
	var game: GrindstoneGame = _make_game()
	game.events.clear()
	game.elapsed = 5.0
	game._attempt_rhythm_press()
	assert(game.bad_clicks == 1, "Pressing with no nearby event must register as a bad press.")
	game.free()

func test_holding_through_a_grind_section_accumulates_score() -> void:
	var game: GrindstoneGame = _make_game()
	var grind_index: int = -1
	for event_index: int in range(game.events.size()):
		if int(game.events[event_index]["kind"]) == int(GrindstoneGame.EventKind.GRIND):
			grind_index = event_index
			break
	assert(grind_index >= 0, "Default chart should contain at least one grind.")
	var grind_time: float = float(game.events[grind_index]["time"])
	var duration: float = float(game.events[grind_index]["duration"])
	game.elapsed = grind_time
	game.pressure_x = game.guide_x_at(grind_time)
	game._attempt_rhythm_press()
	assert(game.active_grind_index == grind_index, "A well-timed grind press must start holding that grind.")
	game.mouse_held = true
	var step: float = 0.05
	var sample_time: float = grind_time
	while sample_time <= grind_time + duration + step:
		game.elapsed = sample_time
		game.pressure_x = game.guide_x_at(minf(sample_time, grind_time + duration))
		game._update_rhythm_events(step)
		sample_time += step
	assert(bool(game.events[grind_index]["resolved"]), "The grind event must resolve once elapsed passes its end.")
	assert(game.grind_score_total > 0.0, "Holding through a grind while aligned must accumulate grind score.")
	game.free()

func test_material_value_multiplier_is_positive_and_accuracy_driven() -> void:
	var game: GrindstoneGame = _make_game()
	game.trace_score_total = 0.0
	game.trace_sample_time = 1.0
	game.balance_score_total = 0.0
	game.balance_sample_time = 1.0
	var base_multiplier: float = game.material_value_multiplier()
	game.trace_score_total = 1.0
	game.balance_score_total = 1.0
	game.beat_hits = game.beat_total
	game.grind_score_total = float(game.grind_total)
	var perfect_multiplier: float = game.material_value_multiplier()
	assert(base_multiplier >= 1.0, "Material value must never be reduced below base value.")
	assert(perfect_multiplier > base_multiplier, "Better accuracy should increase material value.")
	game.free()

func test_final_score_blends_all_three_weighted_factors() -> void:
	var game: GrindstoneGame = _make_game()
	game.trace_score_total = 30.0
	game.trace_sample_time = 30.0
	game.beat_hits = game.beat_total
	game.grind_score_total = float(game.grind_total)
	game.balance_score_total = 30.0
	game.balance_sample_time = 30.0
	assert(game.final_score() == game.maximum_score, "A perfect run across all four accuracy factors should hit the maximum score.")
	game.free()
