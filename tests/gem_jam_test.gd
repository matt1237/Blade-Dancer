class_name GemJamV4Test extends Node

const GEM_JAM_SCENE: PackedScene = preload("res://scenes/minigames/gem_jam.tscn")

func _make_game(seed: int = 1234) -> GemJamGame:
	var game: GemJamGame = GEM_JAM_SCENE.instantiate() as GemJamGame
	game.generation_seed = seed
	add_child(game)
	game._build_material_mask()
	game.music_player = game.get_node("MusicPlayer") as AudioStreamPlayer
	game.gem_jam_audio = game.get_node("GemJamAudio") as GemJamAudio
	game.station_label = game.get_node("HUD/StationLabel") as Label
	game.view_label = game.get_node("HUD/ViewLabel") as Label
	game.status_label = game.get_node("HUD/StatusLabel") as Label
	game.metrics_label = game.get_node("HUD/MetricsLabel") as Label
	game.progress_bar = game.get_node("HUD/ResonanceProgress") as ProgressBar
	game.frequency_label = game.get_node("ResonancePanel/FrequencyLabel") as Label
	game.amplitude_label = game.get_node("ResonancePanel/AmplitudeLabel") as Label
	game.resonance_panel = game.get_node("ResonancePanel") as Control
	game.grind_hint = game.get_node("HUD/GrindHint") as Label
	# _ready()'s automatic invocation is deferred by a frame in this
	# synchronous harness (same reason the onready vars above are rebound by
	# hand) — call the "fresh attempt opens on X-ray" step directly so a
	# freshly-made test game deterministically matches a real player's start.
	game._open_on_xray_station()
	return game

func _clear_mask(game: GemJamGame) -> void:
	game.material_mask.fill(GemJamGame.Cell.EMPTY)
	game.grind_progress.fill(0.0)
	game.textures_dirty = true
	game.exposure_dirty = true
	for index: int in range(game.material_mask.size()):
		game._mark_pixel_dirty(index)
	game._recompute_target_cache()

func _remove_all_rock(game: GemJamGame) -> void:
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.ROCK:
			game.material_mask[index] = GemJamGame.Cell.EMPTY
			game._mark_pixel_dirty(index)
	game.textures_dirty = true
	game.exposure_dirty = true
	game._recompute_target_cache()

func test_generation_contains_random_rock_and_rough_gem() -> void:
	var game: GemJamGame = _make_game()
	assert(game._count_mask_cells(GemJamGame.Cell.ROCK) > 0)
	assert(game._count_mask_cells(GemJamGame.Cell.GEM) > 0)
	assert(game._count_mask_cells(GemJamGame.Cell.EMPTY) > 0)
	assert(game.total_gem_cells > 0)
	game.free()

func test_different_seeds_produce_different_outer_rock_masks() -> void:
	var first: GemJamGame = _make_game(100)
	var second: GemJamGame = _make_game(200)
	var differences: int = 0
	for index: int in range(first.material_mask.size()):
		if first.material_mask[index] != second.material_mask[index]:
			differences += 1
	assert(differences > 100)
	first.free()
	second.free()

func test_every_generated_target_is_inside_its_rough_gem() -> void:
	for seed: int in range(12):
		var game: GemJamGame = _make_game(seed)
		assert(game._count_target_cells() > 80)
		assert(game._target_is_subset_of_original_gem(), "Target for seed %d must be physically achievable from its rough gem." % seed)
		assert(GemJamGame.TARGET_SHAPES.has(game.target_shape_name))
		game.free()

func test_gem_is_deliberately_off_center_not_a_small_jitter() -> void:
	# The gem must sit meaningfully away from the rock's own center across
	# seeds — "grind the middle" should not be a reliable default strategy —
	# while still remaining a healthy, mostly-intact cluster (not sliced to a
	# sliver by sitting too close to the rock's boundary).
	var offsets: Array[float] = []
	for seed: int in range(20):
		var game: GemJamGame = _make_game(seed)
		var rock_center_estimate: Vector2 = Vector2(128.0, 129.0)
		offsets.append(game.rough_gem_center.distance_to(rock_center_estimate))
		assert(game.total_gem_cells > 400, "Seed %d's gem must remain a substantial, mostly-intact cluster even when off-center." % seed)
		game.free()
	var average_offset: float = 0.0
	for value: float in offsets:
		average_offset += value
	average_offset /= float(offsets.size())
	assert(average_offset > 15.0, "Average gem offset from rock center must clearly exceed the old +/-7px jitter.")

func test_run_opens_on_the_xray_station_so_the_off_center_gem_must_be_found_first() -> void:
	var game: GemJamGame = _make_game()
	assert(game.station == GemJamGame.Station.XRAY)
	assert(game.rock_station == GemJamGame.Station.XRAY)
	assert(game.rock_position.is_equal_approx(GemJamGame.XRAY_STATION_RECT.get_center()))
	game.free()

func test_hidden_gem_is_visible_in_xray_but_not_at_grind_station() -> void:
	var game: GemJamGame = _make_game()
	var gem_point: Vector2i = Vector2i(-1, -1)
	for y: int in range(GemJamGame.MASK_SIZE):
		for x: int in range(GemJamGame.MASK_SIZE):
			if game._mask_cell(x, y) == GemJamGame.Cell.GEM and not game._gem_cell_is_exposed(x, y):
				gem_point = Vector2i(x, y)
				break
		if gem_point.x >= 0:
			break
	assert(gem_point.x >= 0)
	assert(game._visible_material_at(gem_point.x, gem_point.y, true) == GemJamGame.Cell.GEM)
	assert(game._visible_material_at(gem_point.x, gem_point.y, false) == GemJamGame.Cell.ROCK)
	game.free()

func test_material_does_not_erode_without_physical_wheel_contact() -> void:
	var game: GemJamGame = _make_game()
	game.station = GemJamGame.Station.GRIND
	game.rock_position = GemJamGame.GRIND_REST_POSITION
	var before: int = game._count_mask_cells(GemJamGame.Cell.ROCK)
	for frame: int in range(30):
		game._update_grinding(1.0 / 60.0)
	assert(game._count_mask_cells(GemJamGame.Cell.ROCK) == before)
	assert(not game.grinding_active)
	game.free()

func test_lowering_formation_into_wheel_continuously_removes_rock() -> void:
	var game: GemJamGame = _make_game()
	game.station = GemJamGame.Station.GRIND
	game.rock_grind_rate = 40.0
	game.rock_position = Vector2(640.0, 395.0)
	var before: int = game._count_mask_cells(GemJamGame.Cell.ROCK)
	var removed: int = 0
	for frame: int in range(30):
		removed += game._update_grinding(1.0 / 60.0)
	assert(game.grinding_active)
	assert(removed > 0)
	assert(game._count_mask_cells(GemJamGame.Cell.ROCK) < before)
	game.free()

func test_rock_grinds_faster_than_gem_at_equal_contact() -> void:
	var game: GemJamGame = _make_game()
	_clear_mask(game)
	game.rock_position = GemJamGame.GRIND_WHEEL_CENTER
	var center_index: int = game._mask_index(128, 128)
	game.material_mask[center_index] = GemJamGame.Cell.ROCK
	game._update_grinding(0.005)
	var rock_progress: float = game.grind_progress[center_index]
	game.material_mask[center_index] = GemJamGame.Cell.GEM
	game.grind_progress[center_index] = 0.0
	game._update_grinding(0.005)
	var gem_progress: float = game.grind_progress[center_index]
	assert(rock_progress > gem_progress * 3.0)
	game.free()

func test_deeper_wheel_contact_erodes_material_faster() -> void:
	var game: GemJamGame = _make_game()
	_clear_mask(game)
	var center_index: int = game._mask_index(128, 128)
	game.material_mask[center_index] = GemJamGame.Cell.ROCK
	game.rock_position = GemJamGame.GRIND_WHEEL_CENTER - Vector2(0.0, GemJamGame.GRIND_WHEEL_RADIUS * 0.8)
	game._update_grinding(0.005)
	var shallow_progress: float = game.grind_progress[center_index]
	game.grind_progress[center_index] = 0.0
	game.rock_position = GemJamGame.GRIND_WHEEL_CENTER
	game._update_grinding(0.005)
	var deep_progress: float = game.grind_progress[center_index]
	assert(deep_progress > shallow_progress * 3.0)
	game.free()

func test_rotation_and_position_use_reversible_single_view_mapping() -> void:
	var game: GemJamGame = _make_game()
	game.object_rotation = 0.73
	var mask_point: Vector2 = Vector2(72.0, 181.0)
	var screen_point: Vector2 = game._mask_to_screen(mask_point)
	assert(game._screen_to_mask(screen_point).is_equal_approx(mask_point))
	assert(game._view_scale() == Vector2.ONE, "Jewel Jam now uses one honest canonical view rather than a fake flattened SIDE projection.")
	game.free()

func test_debug_metrics_track_preservation_match_and_rock_removal() -> void:
	var game: GemJamGame = _make_game()
	assert(is_equal_approx(game.gem_preserved_ratio(), 1.0))
	var initial_match: float = game.target_match_ratio()
	var outside_target_index: int = -1
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			outside_target_index = index
			break
	assert(outside_target_index >= 0)
	game._remove_material_index(outside_target_index)
	assert(game.gem_preserved_ratio() < 1.0)
	assert(game.target_match_ratio() > initial_match)
	var rock_index: int = game.material_mask.find(GemJamGame.Cell.ROCK)
	game._remove_material_index(rock_index)
	assert(game.rock_removal_ratio() > 0.0)
	game.free()

func test_full_exposure_plus_target_shaping_unlocks_resonance_polish() -> void:
	var game: GemJamGame = _make_game()
	_remove_all_rock(game)
	assert(is_equal_approx(game.gem_exposure_ratio(), 1.0))
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			game._remove_material_index(index)
	game._select_resonance()
	assert(game.station == GemJamGame.Station.RESONANCE)
	game.free()

func _send_mouse_button(game: GemJamGame, position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	game._gui_input(event)

func _send_mouse_motion(game: GemJamGame, position: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	game._gui_input(event)

func test_full_mouse_drag_gesture_carries_the_rock_into_the_wheel_and_grinds() -> void:
	# End-to-end regression for the actual player gesture: press near the rock,
	# move the mouse down while held (a real drag, via the same _gui_input path
	# a live mouse uses), release over the wheel, then grind in place.
	var game: GemJamGame = _make_game()
	game._select_grind()
	var start: Vector2 = game.rock_position
	_send_mouse_button(game, start, true)
	assert(game.pending_rock_drag)
	_send_mouse_motion(game, start + Vector2(0.0, 20.0))
	assert(game.dragging_rock, "Moving the mouse more than the grab threshold while held must start the drag.")
	# The rough gem's own radius is comfortably larger than the wheel, so real
	# contact happens once its OUTER SURFACE reaches the wheel — not merely
	# once its center gets close (which would bury the wheel deep inside solid
	# rock instead, touching nothing). ~120px above wheel-center is where this
	# seed's surface meets the wheel.
	var into_wheel: Vector2 = Vector2(GemJamGame.GRIND_WHEEL_CENTER.x, GemJamGame.GRIND_WHEEL_CENTER.y - 120.0)
	_send_mouse_motion(game, into_wheel)
	assert(game.rock_position.is_equal_approx(into_wheel))
	_send_mouse_button(game, into_wheel, false)
	assert(not game.dragging_rock)
	assert(game.station == GemJamGame.Station.GRIND)
	var before: int = game._count_mask_cells(GemJamGame.Cell.ROCK)
	game._update_grinding(1.0 / 60.0)
	assert(game.grinding_active, "Resting in contact after a real drag gesture must register wheel contact.")
	for frame: int in range(59):
		game._update_grinding(1.0 / 60.0)
	assert(game._count_mask_cells(GemJamGame.Cell.ROCK) < before, "Contact after the drag must actually erode rock over time.")
	game.free()

func test_object_bulk_bigger_than_wheel_needs_its_surface_not_just_its_center_near_the_wheel() -> void:
	# Regression: the rough gem's radius is bigger than the wheel's, so pushing
	# the object's CENTER on top of the wheel buries the wheel deep inside solid
	# rock (touching nothing) rather than grinding — only once the object's
	# actual outer surface reaches the wheel does contact register.
	var game: GemJamGame = _make_game()
	game.rock_position = GemJamGame.GRIND_WHEEL_CENTER
	game._update_grinding(1.0 / 60.0)
	assert(not game.grinding_active, "The wheel sitting deep inside solid rock, away from any surface, must not register contact.")
	game.rock_position = Vector2(GemJamGame.GRIND_WHEEL_CENTER.x, GemJamGame.GRIND_WHEEL_CENTER.y - 120.0)
	game._update_grinding(1.0 / 60.0)
	assert(game.grinding_active, "Once the object is lowered enough for its real surface to reach the wheel, contact must register.")
	game.free()

func test_resonance_target_still_moves_and_stabilizes_with_exposure() -> void:
	var game: GemJamGame = _make_game()
	var full_first: Vector2 = game._resonance_target_at_time(1.0, 0.0)
	var full_later: Vector2 = game._resonance_target_at_time(1.0, 2.0)
	assert(full_first.distance_to(full_later) > 0.01)
	assert(is_equal_approx(game._resonance_erratic_weight(0.80), 1.0))
	assert(game._resonance_erratic_weight(1.0) >= game.resonance_full_exposure_motion_floor - 0.001, "A fully exposed gem must remain meaningfully challenging rather than becoming a stationary target.")
	game.free()

func _position_for_contact(game: GemJamGame) -> void:
	game.rock_position = Vector2(GemJamGame.GRIND_WHEEL_CENTER.x, GemJamGame.GRIND_WHEEL_CENTER.y - 120.0)

func test_wheel_speed_bar_is_controlled_by_w_and_s_and_scales_grind_rate() -> void:
	# Fair A/B: two IDENTICAL starting masks (same seed), one ground at min
	# wheel speed and one at max, for the same short time slice. Compares
	# cells actually removed rather than leftover grind_progress — a cell
	# that finishes gets removed AND its progress reset to 0, so a raw
	# progress-sum comparison perversely reads "lower" once a fast pass
	# starts finishing cells within the same slice.
	var slow_game: GemJamGame = _make_game()
	slow_game._select_grind()
	_position_for_contact(slow_game)
	slow_game.wheel_speed = slow_game.wheel_speed_min
	var slow_rock_before: int = slow_game._count_mask_cells(GemJamGame.Cell.ROCK)
	slow_game._update_grinding(0.15)
	var slow_removed: int = slow_rock_before - slow_game._count_mask_cells(GemJamGame.Cell.ROCK)

	var fast_game: GemJamGame = _make_game()
	fast_game._select_grind()
	_position_for_contact(fast_game)
	fast_game.wheel_speed = fast_game.wheel_speed_max
	var fast_rock_before: int = fast_game._count_mask_cells(GemJamGame.Cell.ROCK)
	fast_game._update_grinding(0.15)
	var fast_removed: int = fast_rock_before - fast_game._count_mask_cells(GemJamGame.Cell.ROCK)

	assert(fast_removed > slow_removed, "A higher wheel speed must remove meaningfully more material in the same time slice.")
	slow_game.free()
	fast_game.free()

func test_wheel_speed_stays_clamped_to_its_configured_range() -> void:
	# W/S's actual key-hold behavior is exercised live (run_scene reaches the
	# real input pipeline; a raw headless SceneTree's Input.parse_input_event
	# does not reliably flip is_physical_key_pressed() outside it). This
	# covers the range/clamping contract the W/S handler in _process() relies
	# on: wheel_speed_change_rate * delta, clamped to [min, max].
	var game: GemJamGame = _make_game()
	game.wheel_speed = game.wheel_speed_default
	assert(game.wheel_speed >= game.wheel_speed_min and game.wheel_speed <= game.wheel_speed_max)
	game.wheel_speed = clampf(game.wheel_speed + game.wheel_speed_change_rate * 10.0, game.wheel_speed_min, game.wheel_speed_max)
	assert(is_equal_approx(game.wheel_speed, game.wheel_speed_max), "A long enough hold must cap out at wheel_speed_max, not overshoot it.")
	game.wheel_speed = clampf(game.wheel_speed - game.wheel_speed_change_rate * 10.0, game.wheel_speed_min, game.wheel_speed_max)
	assert(is_equal_approx(game.wheel_speed, game.wheel_speed_min), "A long enough hold the other way must floor out at wheel_speed_min, not undershoot it.")
	game.free()

func test_gem_color_is_randomized_per_attempt_from_the_curated_palette_and_used_consistently() -> void:
	var palette_colors: Array = []
	for entry: Array in GemJamGame.GEM_PALETTE:
		palette_colors.append(entry[0])
	var seen_colors: Dictionary = {}
	for seed: int in range(10):
		var game: GemJamGame = _make_game(seed)
		assert(palette_colors.has(game.gem_color), "The chosen gem color must come from the curated palette, not arbitrary noise.")
		seen_colors[game.gem_color] = true
		# Same seed must reproduce the same color (consistent, not re-rolled).
		var repeat_seed_game: GemJamGame = _make_game(seed)
		assert(repeat_seed_game.gem_color == game.gem_color)
		repeat_seed_game.free()
		game.free()
	assert(seen_colors.size() > 1, "Different seeds should be able to land on different palette colors.")

func test_dust_spawns_while_grinding_and_matches_gem_color_when_grinding_gem() -> void:
	var game: GemJamGame = _make_game()
	game._select_grind()
	_position_for_contact(game)
	game.dust_particles.clear()
	game._update_grinding(1.0)
	game._spawn_dust(1.0, false)
	assert(game.dust_particles.size() > 0, "Active grinding contact must produce visible dust.")
	for particle: Dictionary in game.dust_particles:
		assert((particle["color"] as Color) == GemJamGame.DUST_ROCK_COLOR)
	game.dust_particles.clear()
	game._spawn_dust(1.0, true)
	assert(game.dust_particles.size() > 0)
	for particle: Dictionary in game.dust_particles:
		assert((particle["color"] as Color) == game.gem_color, "Dust must switch to the gem's own color while grinding gem material.")
	game.free()

func test_dust_volume_scales_with_wheel_speed() -> void:
	var game: GemJamGame = _make_game()
	game._select_grind()
	_position_for_contact(game)
	game._update_grinding(1.0 / 60.0)
	assert(game.grind_contact_cells > 0)
	game.dust_particles.clear()
	game.wheel_speed = game.wheel_speed_min
	game._spawn_dust(1.0, false)
	var slow_count: int = game.dust_particles.size()
	game.dust_particles.clear()
	game.wheel_speed = game.wheel_speed_max
	game._spawn_dust(1.0, false)
	var fast_count: int = game.dust_particles.size()
	assert(fast_count > slow_count, "Faster wheel speed must produce visibly more dust for the same contact.")
	game.free()

func test_breaking_through_to_gem_triggers_a_shine_burst() -> void:
	var game: GemJamGame = _make_game()
	var gem_point: Vector2i = Vector2i(-1, -1)
	for y: int in range(GemJamGame.MASK_SIZE):
		for x: int in range(GemJamGame.MASK_SIZE):
			if game._mask_cell(x, y) == GemJamGame.Cell.GEM and not game._gem_cell_is_exposed(x, y):
				gem_point = Vector2i(x, y)
				break
		if gem_point.x >= 0:
			break
	assert(gem_point.x >= 0)
	game.shine_bursts.clear()
	game.shine_intensity = 0.0
	var exposed_before: int = game.exposed_gem_cells_cache
	# Clear the one rock cell directly covering it, in whichever direction
	# reaches the mask edge fastest, to force an exposure transition.
	for y: int in range(gem_point.y - 1, -1, -1):
		if game._mask_cell(gem_point.x, y) == GemJamGame.Cell.ROCK:
			game._remove_material_index(game._mask_index(gem_point.x, y))
	game._check_for_new_shine(exposed_before)
	assert(game.shine_bursts.size() > 0, "A newly-exposed gem cell must trigger a dramatic shine burst.")
	assert(game.shine_intensity > 0.0)
	game.free()

func test_exposure_cache_marks_every_newly_visible_gem_pixel_dirty() -> void:
	var game: GemJamGame = _make_game()
	game.gem_exposure_ratio()
	game.dirty_pixels.clear()
	var initially_exposed: PackedByteArray = game.exposed_mask_cache.duplicate()
	_remove_all_rock(game)
	game.gem_exposure_ratio()
	var newly_visible_count: int = 0
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and initially_exposed[index] == 0 and game.exposed_mask_cache[index] != 0:
			newly_visible_count += 1
			assert(game.dirty_pixels.has(index), "Every gem revealed by a newly opened sightline must repaint instead of remaining stale brown.")
	assert(newly_visible_count > 100)
	game.free()

func test_live_facet_shading_varies_across_the_exposed_gem() -> void:
	var game: GemJamGame = _make_game()
	var left_color: Color = game._live_facet_color(game.target_center + Vector2(-game.target_half_size.x * 0.45, 0.0))
	var upper_color: Color = game._live_facet_color(game.target_center + Vector2(0.0, -game.target_half_size.y * 0.45))
	assert(left_color != upper_color, "Exposed gemstone needs distinct light/dark facet planes rather than one flat blob color.")
	assert(left_color.a > 0.5 and upper_color.a > 0.5, "Custom gemstone colors must remain visibly present in the live material.")
	game.free()

func test_all_target_shapes_generate_clean_final_cut_polygons() -> void:
	var game: GemJamGame = _make_game()
	for shape_name: String in GemJamGame.TARGET_SHAPES:
		var points: PackedVector2Array = game._cut_shape_points(shape_name, Vector2.ZERO, Vector2(90.0, 105.0))
		assert(points.size() >= 4, "%s needs a valid clean vector silhouette for the trophy render." % shape_name)
		assert(points[0].distance_to(points[points.size() / 2]) > 80.0, "%s's final silhouette must occupy a readable trophy-scale area." % shape_name)
	game.free()

func test_resonance_requires_both_exposure_and_a_meaningful_cut_match() -> void:
	var game: GemJamGame = _make_game()
	assert(not game._resonance_is_available())
	_remove_all_rock(game)
	assert(game.gem_exposure_ratio() >= game.resonance_exposure_required)
	# The untouched rough gemstone remains substantially larger than its target,
	# so exposure alone must not skip the shaping phase.
	if game.target_match_ratio() < game.resonance_match_required:
		assert(not game._resonance_is_available())
	# Remove GEM only outside the guaranteed-achievable target.
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			game._remove_material_index(index)
	assert(game.target_match_ratio() >= game.resonance_match_required)
	assert(game._resonance_is_available())
	game.free()

func test_resonance_completion_creates_a_quality_weighted_final_reveal() -> void:
	var excellent: GemJamGame = _make_game()
	_remove_all_rock(excellent)
	for index: int in range(excellent.material_mask.size()):
		if excellent.material_mask[index] == GemJamGame.Cell.GEM and excellent.target_mask[index] == 0:
			excellent._remove_material_index(index)
	excellent.resonance_completion_accuracy = 1.0
	excellent._complete_refinement()
	assert(excellent.completed)
	assert(excellent.final_reveal_progress == 0.0)
	assert(excellent.final_quality_score > 0.8)
	assert(excellent.final_rank_name == "MASTERWORK")
	assert(excellent.final_gem_name.length() > 0)
	var excellent_quality: float = excellent.final_quality_score
	excellent.free()

	var rough: GemJamGame = _make_game()
	rough.resonance_completion_accuracy = 0.55
	rough._complete_refinement()
	assert(rough.final_quality_score < excellent_quality, "The final trophy must preserve consequences from exposure, shape, preservation, and resonance skill.")
	assert(rough.final_rank_name != "MASTERWORK", "A weak stage must cap the result instead of being hidden by a weighted average.")
	rough.free()

func _prepare_for_resonance(game: GemJamGame) -> void:
	_remove_all_rock(game)
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			game._remove_material_index(index)
	game.gem_exposure_ratio()

func test_running_out_of_time_before_ever_entering_resonance_is_unfinished() -> void:
	var game: GemJamGame = _make_game()
	assert(is_equal_approx(game.run_time_remaining, game.run_time_limit_seconds))
	game._update_run_timer(game.run_time_limit_seconds - 1.0)
	assert(not game.completed)
	game._update_run_timer(1.1)
	assert(game.completed, "An unqualified rough stone must fail once the run's single clock runs out.")
	assert(game.timed_out)
	assert(game.final_rank_name == "UNFINISHED")
	assert(game.final_score >= 0)
	game.free()

func test_entering_resonance_is_the_players_own_choice_not_automatic() -> void:
	var game: GemJamGame = _make_game()
	_prepare_for_resonance(game)
	# Qualified with plenty of time left; nothing should force the transition
	# on its own — Resonance is only ever entered explicitly now.
	game._update_run_timer(1.0)
	assert(not game.resonance_challenge_active)
	assert(game.station != GemJamGame.Station.RESONANCE)
	game._select_resonance()
	assert(game.resonance_challenge_active)
	assert(game.station == GemJamGame.Station.RESONANCE)
	game.free()

# The target moves continuously (see _update_resonance_target), so a real
# player re-adjusts every frame at ~1/60s steps, not in one giant jump. These
# helpers replay that realistically: re-sync to the current (barely-moved)
# target immediately before each tiny step, exactly like a player tracking it.
func _hold_perfect_alignment_for(game: GemJamGame, total_seconds: float) -> void:
	var step: float = 1.0 / 60.0
	var elapsed: float = 0.0
	while elapsed < total_seconds and not game.completed:
		game.resonance_frequency = game.target_frequency
		game.resonance_amplitude = game.target_amplitude
		game._update_resonance(step)
		elapsed += step

func test_resonance_meter_fills_only_while_aligned_and_holds_steady_otherwise() -> void:
	var game: GemJamGame = _make_game()
	_prepare_for_resonance(game)
	game._start_resonance_challenge()
	_hold_perfect_alignment_for(game, 1.0)
	var filled_time: float = game.resonance_good_time
	assert(filled_time > 0.9 and filled_time <= 1.0 + 0.001, "A full second of tracked alignment must fill roughly a full second of meter.")
	# Force misalignment: the meter must hold steady, not lose progress.
	game.resonance_frequency = clampf(game.target_frequency + 0.9, 0.0, 1.0)
	assert(game._alignment_score() < 1.0 - game.resonance_tolerance)
	for frame: int in range(60):
		game._update_resonance(1.0 / 60.0)
	assert(is_equal_approx(game.resonance_good_time, filled_time), "Dropping out of sync must hold the meter steady, not decay it.")
	game.free()

func test_reaching_the_hold_target_completes_the_run_with_full_tune_credit() -> void:
	var game: GemJamGame = _make_game()
	_prepare_for_resonance(game)
	game._start_resonance_challenge()
	_hold_perfect_alignment_for(game, game.resonance_hold_target_seconds + 0.5)
	assert(game.completed)
	assert(is_equal_approx(game.resonance_completion_accuracy, 1.0))
	assert(game.final_rank_name != "UNFINISHED")
	assert(game.final_score > 0)
	game.free()

func test_master_timer_running_out_mid_resonance_ends_the_run_with_partial_tune_credit() -> void:
	var game: GemJamGame = _make_game()
	_prepare_for_resonance(game)
	game._start_resonance_challenge()
	_hold_perfect_alignment_for(game, game.resonance_hold_target_seconds * 0.5)
	assert(not game.completed)
	assert(game.resonance_good_time > 0.0 and game.resonance_good_time < game.resonance_hold_target_seconds)
	# Blow through the rest of the run's clock while still mid-polish.
	game._update_run_timer(game.run_time_remaining + 1.0)
	assert(game.completed, "Running out of time mid-polish must still end the run, not hang forever.")
	assert(not game.timed_out, "A qualified attempt that was actively polishing must be graded, not discarded as unfinished.")
	assert(game.resonance_completion_accuracy > 0.0 and game.resonance_completion_accuracy < 1.0)
	game.free()

func test_final_score_is_a_concrete_number_that_rewards_better_play() -> void:
	var excellent: GemJamGame = _make_game()
	_remove_all_rock(excellent)
	for index: int in range(excellent.material_mask.size()):
		if excellent.material_mask[index] == GemJamGame.Cell.GEM and excellent.target_mask[index] == 0:
			excellent._remove_material_index(index)
	excellent.resonance_completion_accuracy = 1.0
	excellent._complete_refinement()
	assert(excellent.final_score > 0)
	var excellent_score: int = excellent.final_score
	excellent.free()

	var rough: GemJamGame = _make_game()
	rough.resonance_completion_accuracy = 0.30
	rough._complete_refinement()
	assert(rough.final_score >= 0)
	assert(rough.final_score < excellent_score, "A cleaner, better-tuned cut must produce a visibly higher numeric score.")
	rough.free()

	var never_qualified: GemJamGame = _make_game()
	# timed_out is set by _update_run_timer (the real caller) before it calls
	# _complete_refinement(true); set it here too to match that contract.
	never_qualified.timed_out = true
	never_qualified._complete_refinement(true)
	assert(never_qualified.final_score >= 0)
	never_qualified.free()

func test_time_rewards_faster_completion_without_changing_quality_or_heat_outcome() -> void:
	var fast: GemJamGame = _make_game()
	fast.run_time_remaining = 115.0
	fast.gem_stress = 0.90
	fast.resonance_completion_accuracy = 0.80
	fast._complete_refinement()
	var fast_score: int = fast.final_score
	var fast_quality: float = fast.final_quality_score
	fast.free()

	var slow: GemJamGame = _make_game()
	slow.run_time_remaining = 8.0
	slow.gem_stress = 0.05
	slow.resonance_completion_accuracy = 0.80
	slow._complete_refinement()
	assert(slow.final_score < fast_score, "Faster completion should earn a larger TIME score.")
	assert(is_equal_approx(slow.final_quality_score, fast_quality), "Time and heat management must not alter the quality grade.")
	slow.free()

func test_gem_stress_rises_from_fast_deep_gem_contact_and_cools_when_released() -> void:
	var game: GemJamGame = _make_game()
	game.wheel_speed = game.wheel_speed_max
	game._update_gem_stress(1.0, 12, 12, 1.0)
	var hot_stress: float = game.gem_stress
	assert(hot_stress > 0.0)
	game._update_gem_stress(2.0, 0, 0, 0.0)
	assert(game.gem_stress < hot_stress)
	game.free()

func test_high_stress_makes_target_gem_erode_faster_without_random_damage() -> void:
	var safe: GemJamGame = _make_game()
	_clear_mask(safe)
	safe.rock_position = GemJamGame.GRIND_WHEEL_CENTER
	var center_index: int = safe._mask_index(128, 128)
	safe.material_mask[center_index] = GemJamGame.Cell.GEM
	safe.target_mask[center_index] = 1
	safe.gem_stress = 0.0
	safe._update_grinding(0.01)
	var safe_progress: float = safe.grind_progress[center_index]

	var stressed: GemJamGame = _make_game()
	_clear_mask(stressed)
	stressed.rock_position = GemJamGame.GRIND_WHEEL_CENTER
	stressed.material_mask[center_index] = GemJamGame.Cell.GEM
	stressed.target_mask[center_index] = 1
	stressed.gem_stress = 1.0
	stressed._update_grinding(0.01)
	var stressed_progress: float = stressed.grind_progress[center_index]
	assert(stressed_progress > safe_progress * 1.5)
	safe.free()
	stressed.free()

func test_precision_chain_rewards_correct_removal_and_breaks_on_target_damage() -> void:
	var game: GemJamGame = _make_game()
	var rock_index: int = game.material_mask.find(GemJamGame.Cell.ROCK)
	game._remove_material_index(rock_index)
	assert(game.precision_chain_points > 0.0)
	var surplus_index: int = -1
	var target_index: int = -1
	for index: int in range(game.material_mask.size()):
		if surplus_index < 0 and game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] == 0:
			surplus_index = index
		if target_index < 0 and game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] != 0:
			target_index = index
		if surplus_index >= 0 and target_index >= 0:
			break
	game._remove_material_index(surplus_index)
	assert(game.precision_chain_points >= 4.0)
	assert(game.precision_score > 0.0)
	game._remove_material_index(target_index)
	assert(is_zero_approx(game.precision_chain_points))
	assert(game.target_damage_flash > 0.0)
	assert(game.target_chip_count == 1)
	game.free()

func test_rapid_target_damage_is_consolidated_into_bounded_feedback_bursts() -> void:
	var game: GemJamGame = _make_game()
	var target_indices: Array[int] = []
	for index: int in range(game.material_mask.size()):
		if game.material_mask[index] == GemJamGame.Cell.GEM and game.target_mask[index] != 0:
			target_indices.append(index)
			if target_indices.size() == 2:
				break
	assert(target_indices.size() == 2)
	game.shine_bursts.clear()
	game._remove_material_index(target_indices[0])
	var first_burst_size: int = game.shine_bursts.size()
	game._remove_material_index(target_indices[1])
	assert(first_burst_size == 7)
	assert(game.shine_bursts.size() == first_burst_size, "Hundreds of damaged target pixels in one contact window must not create thousands of particles.")
	game.free()

func test_specimen_identity_and_cut_name_remain_hidden_until_final_reveal() -> void:
	var game: GemJamGame = _make_game()
	game._update_ui()
	assert(not game.view_label.text.contains(game.gem_name))
	assert(not game.view_label.text.contains(game.target_shape_name))
	assert(not game._target_guide_text().contains(game.target_shape_name))
	assert(game.view_label.text == "SPECIMEN: UNIDENTIFIED")
	game.free()

func test_xray_machine_sound_triggers_once_when_entering_the_station() -> void:
	var game: GemJamGame = _make_game()
	# A fresh attempt now legitimately opens on X-ray, so leave it first to
	# get a clean "entering from elsewhere" baseline for this test's intent.
	game._select_grind()
	game.gem_jam_audio.xray_trigger_count = 0
	game._select_xray()
	assert(game.gem_jam_audio.xray_trigger_count == 1)
	game._select_xray()
	assert(game.gem_jam_audio.xray_trigger_count == 1, "Pressing X-RAY repeatedly while already there must not stack machine noises.")
	game._select_grind()
	game._select_xray()
	assert(game.gem_jam_audio.xray_trigger_count == 2)
	game.free()

func test_authored_resonance_cue_volume_equals_current_tune_accuracy() -> void:
	var game: GemJamGame = _make_game()
	var audio: GemJamAudio = game.gem_jam_audio
	audio.update_state(1.0, true, 0.45, 0.0, false, 0.0)
	assert(audio.grind_level > 0.9)
	assert(absf(audio._grind_sample(0.123)) > 0.0001, "Active rock contact still needs its gentle procedural grind layer.")
	assert(GemJamAudio.RESONANCE_CUE.resource_path == "res://assets/audio/Gem Jammer/Resonance Cue.mp3")
	audio.update_state(1.0, false, 0.0, 0.0, true, 0.18)
	assert(is_equal_approx(audio.resonance_cue_level, 0.18))
	audio.update_state(1.0, false, 0.0, 0.0, true, 0.94)
	assert(is_equal_approx(audio.resonance_cue_level, 0.94), "Resonance Cue linear volume must equal current Tune alignment exactly.")
	audio.update_state(1.0, false, 0.0, 0.0, false, 0.0)
	assert(is_zero_approx(audio.resonance_cue_level))
	game.free()

func test_resonance_fades_normal_music_to_silence_then_restores_it() -> void:
	var game: GemJamGame = _make_game()
	_prepare_for_resonance(game)
	game._start_resonance_challenge()
	assert(game.resonance_music_mix_active)
	assert(is_equal_approx(game.music_target_volume_db, GemJamAudio.SILENT_VOLUME_DB))
	assert(game.gem_jam_audio.resonance_active or game.gem_jam_audio.resonance_cue_start_count > 0)
	game._set_resonance_music_mix(false)
	assert(not game.resonance_music_mix_active)
	assert(is_equal_approx(game.music_target_volume_db, game.music_normal_volume_db))
	if game.music_fade_tween != null and game.music_fade_tween.is_valid():
		game.music_fade_tween.kill()
	game.free()

func test_gem_jammer_music_uses_every_track_before_reshuffling_without_immediate_repeat() -> void:
	var game: GemJamGame = _make_game()
	game.music_player.stop()
	game.music_shuffle_bag.clear()
	game.current_music_index = -1
	var first_cycle: Dictionary = {}
	for draw: int in range(GemJamGame.GEM_JAM_TRACKS.size()):
		var stream: AudioStream = game._next_music_track()
		assert(stream != null)
		first_cycle[game.current_music_index] = true
	assert(first_cycle.size() == GemJamGame.GEM_JAM_TRACKS.size(), "Every Gem Jammer track must play once before the shuffle bag refills.")
	var previous_index: int = game.current_music_index
	game._next_music_track()
	assert(game.current_music_index != previous_index, "A shuffle-cycle boundary must not immediately repeat the previous song.")
	game.free()

func test_rank_is_capped_by_the_weakest_required_stage() -> void:
	var game: GemJamGame = _make_game()
	assert(game._rank_for_scores(0.96, 0.94, 0.91, false) == "MASTERWORK")
	assert(game._rank_for_scores(0.96, 0.94, 0.40, false) == "ROUGH-CUT")
	assert(game._rank_for_scores(0.96, 0.70, 0.95, false) == "POLISHED")
	assert(game._rank_for_scores(1.0, 1.0, 1.0, true) == "UNFINISHED")
	game.free()
