class_name ChargedGuardTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME
	return player

func test_guard_is_inert_when_disabled() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 0.0)
	player.charged_guard_charge = 0.2
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	player.sword_phase = 1.4
	player._update_charged_guard(0.1)
	assert(is_zero_approx(player.charged_guard_charge), "Disabled Charged Guard must clear acquisition state.")
	assert(not player.charged_guard_locked, "Disabled Charged Guard must not lock or alter the sword.")
	player.free()

func test_pommel_alignment_requires_strong_axis_drive() -> void:
	var blade_direction: Vector2 = Vector2.RIGHT
	var direct_pommel_pull: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2.LEFT * 200.0)
	var diagonal_pull: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2(-1.0, 1.0).normalized() * 200.0)
	var tipward_push: float = Player.charged_guard_pommel_alignment(blade_direction, Vector2.RIGHT * 200.0)
	assert(is_equal_approx(direct_pommel_pull, 1.0), "Driving directly opposite the blade axis should strongly qualify.")
	assert(diagonal_pull < 0.82, "A diagonal gesture should not qualify from a partial backward component.")
	assert(tipward_push < 0.0, "Pushing toward the tip must not qualify as a pommel pull.")
	var baseline_rate: float = Player.charged_guard_charge_multiplier(false, false, false, 0.5, 0.5, 1.0)
	var boosted_rate: float = Player.charged_guard_charge_multiplier(true, true, true, 0.5, 0.5, 1.0)
	assert(boosted_rate > baseline_rate, "Near-body position, recent movement, and pommel pull should independently stack as charge-rate boosts.")

func test_pommel_gesture_latches_candidate_then_locks_after_guard_hold() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.sword_phase = 1.2
	player.player_aim_turn_sign = -1.0
	player.charged_guard_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	var initial_transform: Dictionary = player._sword_transform()
	var blade_direction: Vector2 = Vector2.RIGHT.rotated(float(initial_transform["angle"]))
	player.charged_guard_authored_aim_velocity = -blade_direction * 200.0
	for _frame: int in range(8):
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_candidate_active, "Sustained pommel-directed counter-drive in the reversal window should latch a guard candidate.")
	assert(player.charged_guard_candidate_latch_left > 0.0, "A qualified gesture should grant a forgiving stabilization window.")
	player.authored_virtual_aim_velocity = Vector2.ZERO
	player.charged_guard_authored_aim_velocity = Vector2.ZERO
	player.charged_guard_aim_turn_sign = 0.0
	for _frame: int in range(20):
		if player.charged_guard_locked:
			break
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_locked, "A latched and maintained folded guard should lock after the short hold.")
	player.charged_guard_authored_angular_travel = deg_to_rad(4.0)
	player.charged_guard_authored_aim_velocity = Vector2(400.0, 0.0)
	player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_locked, "Deliberate authored motion should release the lock.")
	player.free()

func test_locked_guard_charges_blue_after_tunable_hold_and_persists() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.set_combat_contact_setting("charged_guard_position_charge_enabled", 1.0)
	assert(is_equal_approx(player.get_combat_contact_setting("charged_guard_awaken_duration"), 1.0), "The charged-position confirmation should default to one second.")
	player.charged_guard_locked = true
	for _frame: int in range(59):
		player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_fully_charged, "The blue charged state must wait for the full hold duration.")
	player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_fully_charged, "Holding the locked guard for the configured second should activate its charged state.")
	for _frame: int in range(60):
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_fully_charged, "The completed charged state should persist while the player holds still.")
	player.free()

func test_guard_only_aim_signals_ignore_player_motion_across_input_modes() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.mobile_input_enabled = true
	player.sword_phase = 1.2
	player.mobile_aim_direction = Vector2.LEFT
	player.has_virtual_aim_sample = true
	player.virtual_aim_point = player.global_position + Vector2.LEFT * 120.0
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(absf(cos(player.sword_phase)) <= player.get_combat_contact_setting("charged_guard_acquisition_window"), "The walking regression must be exercised inside the Guard acquisition window.")
	for _frame: int in range(5):
		player.global_position += Vector2(5.0, 2.0)
		player._update_virtual_aim_point(1.0 / 60.0)
		player._update_charged_guard(1.0 / 60.0)
	assert(player.authored_virtual_aim_velocity.length() > 0.0, "This setup should reproduce legacy aim velocity contaminated by player movement.")
	assert(is_zero_approx(player.charged_guard_authored_aim_velocity.length()), "Mobile player translation with an unchanged aim stick must not count as Guard hand travel.")
	assert(not player.charged_guard_candidate_active and not player.charged_guard_locked, "Player movement alone must not acquire Guard.")
	player.mobile_aim_direction = Vector2.UP
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(player.charged_guard_authored_aim_velocity.length() > 0.0, "A real mobile aim change must still author Guard motion.")
	player.mobile_input_enabled = false
	player.set_input_mode("controller")
	player.controller_aim_direction = Vector2.RIGHT
	player.has_virtual_aim_sample = true
	player._update_virtual_aim_point(1.0 / 60.0)
	player.global_position += Vector2(7.0, -3.0)
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(is_zero_approx(player.charged_guard_authored_aim_velocity.length()), "Controller player translation with a steady stick must not count as Guard hand travel.")
	player.controller_aim_direction = Vector2.DOWN
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(player.charged_guard_authored_aim_velocity.length() > 0.0, "A real controller aim change must still author Guard motion.")
	player.set_input_mode("keyboard_mouse")
	player.virtual_aim_point = player.global_position + Vector2.RIGHT * 100.0
	player.has_virtual_aim_sample = true
	var mouse_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_motion.relative = Vector2(0.0, 20.0)
	player._input(mouse_motion)
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(player.charged_guard_authored_aim_velocity.length() > 0.0, "Actual mouse movement must still author Guard motion.")
	player.global_position += Vector2(9.0, 4.0)
	player._update_virtual_aim_point(1.0 / 60.0)
	assert(is_zero_approx(player.charged_guard_authored_aim_velocity.length()), "Player translation without a mouse-motion event must not count as Guard hand travel.")
	player.set_combat_contact_setting("charged_guard_position_charge_enabled", 1.0)
	player.charged_guard_locked = true
	for _frame: int in range(30):
		player.global_position += Vector2(4.0, 2.0)
		player._update_virtual_aim_point(1.0 / 60.0)
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_locked and player.charged_guard_awaken_charge > 0.0, "Walking with the mouse/aim held still must not release Guard or interrupt its charged hold.")
	player.free()

func test_charged_guard_position_stage_defaults_off_and_can_be_disabled_without_losing_guard() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	assert(is_zero_approx(player.get_combat_contact_setting("charged_guard_position_charge_enabled")), "The disruptive follow-up layer should be opt-in so the proven Guard starts unchanged.")
	player.set_combat_contact_setting("charged_guard_position_charge_enabled", 0.0)
	player.charged_guard_locked = true
	player.charged_guard_initial_lock_angle = 0.4
	player.charged_guard_lock_angle = 1.2
	player.charged_guard_initial_hand_offset = Vector2(30.0, 0.0)
	player.charged_guard_lock_hand_offset = Vector2(70.0, 0.0)
	player.charged_guard_awaken_charge = 0.8
	player.charged_guard_fully_charged = true
	player.charged_guard_afterimages.append(Vector2(20.0, 10.0))
	player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_locked, "Turning the new stage off must preserve the original Guard lock.")
	assert(not player.charged_guard_fully_charged and is_zero_approx(player.charged_guard_awaken_charge), "The disabled follow-up stage must stop and reset its own charge timer.")
	assert(player.charged_guard_afterimages.is_empty(), "The disabled stage must remove its afterimages.")
	assert(is_equal_approx(player.charged_guard_lock_angle, player.charged_guard_initial_lock_angle), "Disabling the stage restores the original locked sword angle.")
	assert(player.charged_guard_lock_hand_offset.is_equal_approx(player.charged_guard_initial_hand_offset), "Disabling the stage restores the original hand position.")
	player.free()

func test_charged_guard_allows_slow_reposition_but_fast_flick_breaks() -> void:
	var slow_scale: float = Player.charged_guard_slow_reposition_scale(40.0, 270.0)
	assert(is_equal_approx(slow_scale, 0.70), "Slow authored input should reposition the charged sword at 70% response when the player is stationary.")
	var movement_suppressed_scale: float = Player.charged_guard_slow_reposition_scale(40.0, 270.0, true)
	assert(is_equal_approx(movement_suppressed_scale, 1.0), "Player translation must not be misread as slow aim repositioning while charged.")
	assert(Player.charged_guard_motion_breaks(deg_to_rad(3.0), 400.0, 270.0), "A medium/fast deliberate aim flick should still break charged Guard.")
	assert(not Player.charged_guard_motion_breaks(deg_to_rad(1.0), 400.0, 270.0), "Low angular travel should retain Guard even at a high aim speed.")
	assert(not Player.charged_guard_motion_breaks(deg_to_rad(3.0), 100.0, 270.0), "Player movement alone must not meet the authored aim-speed threshold.")
	var bounded_offset: Vector2 = Player.charged_guard_clamp_hand_offset(Vector2(100.0, 0.0), 30.0)
	assert(is_equal_approx(bounded_offset.length(), 30.0), "Charged hand reposition must remain inside the original lock radius.")

func test_charged_guard_orientation_tracks_hand_radius_without_turning_into_player() -> void:
	var outward_angle: float = Player.charged_guard_safe_blade_angle(0.0, Vector2.RIGHT * 80.0, Vector2.RIGHT)
	assert(is_equal_approx(outward_angle, 0.0), "An outward blade at max hand reach should remain unchanged.")
	var defense_stance_angle: float = deg_to_rad(80.0)
	var preserved_defense_angle: float = Player.charged_guard_safe_blade_angle(defense_stance_angle, Vector2.RIGHT * 80.0, Vector2.RIGHT)
	assert(is_equal_approx(preserved_defense_angle, defense_stance_angle), "A near-tangential defensive stance like the accepted reference should remain reachable.")
	var max_reach_inward_angle: float = Player.charged_guard_safe_blade_angle(PI, Vector2.RIGHT * 80.0, Vector2.RIGHT)
	assert(Vector2.RIGHT.rotated(max_reach_inward_angle).dot(Vector2.RIGHT) >= -0.001, "At max reach the blade may not point back through the player.")
	var minimum_hand: Vector2 = Player.charged_guard_clamp_hand_offset(Vector2.ZERO, 80.0, Player.CHARGED_GUARD_MIN_HAND_RADIUS, Vector2.DOWN)
	assert(is_equal_approx(minimum_hand.length(), Player.CHARGED_GUARD_MIN_HAND_RADIUS), "The hand should stop at a non-singular minimum radius instead of crossing the player center.")
	var inward_return_angle: float = Player.charged_guard_safe_blade_angle(-PI * 0.5, Vector2.DOWN * Player.CHARGED_GUARD_MIN_HAND_RADIUS, Vector2.DOWN)
	assert(Vector2.DOWN.dot(Vector2.RIGHT.rotated(inward_return_angle)) >= -0.001, "As the hand returns inward, the blade must rotate around the safe outward side rather than impale the player.")

func test_pommel_acquisition_window_reaches_further_into_the_stroke() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.sword_phase = acos(0.60)
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	var transform: Dictionary = player._sword_transform()
	player.charged_guard_authored_aim_velocity = -Vector2.RIGHT.rotated(float(transform["angle"])) * 200.0
	player.charged_guard_aim_turn_sign = -1.0
	for _frame: int in range(8):
		player._update_charged_guard(1.0 / 60.0)
	assert(player.charged_guard_candidate_active, "The slightly wider counter-phase window should allow pommel-drive through more of the metronome stroke.")
	player.free()

func test_countersteering_without_pommel_drive_does_not_acquire() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.sword_phase = 1.2
	player.player_aim_turn_sign = -1.0
	player.authored_sword_engagement = 1.0
	player.charged_guard_authored_aim_velocity = Vector2.RIGHT * 400.0
	player.charged_guard_aim_turn_sign = -1.0
	for _frame: int in range(12):
		player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_candidate_active, "Angular counter-steering without a blade-axis pommel pull must not activate Guard.")
	player.free()

func test_stroke_drive_rewards_fast_travel_more_than_slow_travel() -> void:
	var slow: float = Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.20)
	var fast: float = Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.90)
	var longer: float = Player.authored_stroke_drive_increment(deg_to_rad(60.0), 60.0, 0.90)
	assert(slow < fast, "At equal travel, deliberate faster authored movement should earn more Stroke Drive.")
	assert(fast < longer, "More aligned travel at the same pace should earn more Stroke Drive.")
	assert(is_zero_approx(Player.authored_stroke_drive_increment(deg_to_rad(30.0), 60.0, 0.0)), "No authored motion must earn no drive.")

func test_apex_duration_has_preset_default_and_persistence_key() -> void:
	var player: Player = _new_player()
	assert(is_equal_approx(player.get_combat_contact_setting("apex_hang_duration"), 0.14), "Shipped apex hang duration should remain 0.14 seconds.")
	player.set_combat_contact_setting("apex_hang_duration", 0.27)
	assert(is_equal_approx(player.get_combat_contact_setting("apex_hang_duration"), 0.27), "Apex hang duration should persist through the contact preset authority.")
	player.free()

func test_training_ui_has_guard_tab_and_collapsed_core_section() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	add_child(menu)
	var tabs: TabContainer = menu.get_node("Panel/TrainingTabs") as TabContainer
	var guard_tab_found: bool = false
	for tab: Node in tabs.get_children():
		if tab.name == "Charged Guard":
			guard_tab_found = true
	assert(guard_tab_found, "The opt-in guard and apex tuners need their dedicated tab.")
	var combat_scroll: ScrollContainer = tabs.get_child(4) as ScrollContainer
	var combat_box: VBoxContainer = combat_scroll.get_child(0) as VBoxContainer
	var core_collapsed: bool = false
	for child: Node in combat_box.get_children():
		if child is VBoxContainer and child.get_child_count() >= 2:
			var header: Button = child.get_child(0) as Button
			if header != null and header.text.contains("CORE SWORD & REACH"):
				core_collapsed = not (child.get_child(1) as Control).visible
	assert(core_collapsed, "Core Sword & Reach should start collapsed to reduce tuner clutter.")
	var blade_shape_collapsed: bool = false
	for child: Node in combat_box.get_children():
		if child is VBoxContainer and child.get_child_count() >= 2:
			var header: Button = child.get_child(0) as Button
			if header != null and header.text.contains("BLADE SHAPE"):
				blade_shape_collapsed = not (child.get_child(1) as Control).visible
	assert(blade_shape_collapsed, "Blade Shape should start collapsed to reduce tuner clutter.")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	assert(main_source.contains("swing_gesture_gearing_degrees"), "Swing Gesture Gearing must be included in global-preset persistence.")
	assert(main_source.contains("apex_hang_duration") and main_source.contains("charged_guard_enabled"), "Apex duration and Charged Guard opt-in must be included in global-preset persistence.")
	assert(main_source.contains("contact_keys.append_array(CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS)"), "GP2 materialization must serialize the canonical Guard tuning keys.")
	var initialize_start: int = main_source.find("func _initialize_global_presets()")
	var saved_slot_check: int = main_source.find("GlobalPresetConfig.has_library() and _global_state_complete(GlobalPresetConfig.get_slot(2))", initialize_start)
	var baked_fallback: int = main_source.find("var baked_game_default: Dictionary = _load_baked_global_preset()", initialize_start)
	assert(saved_slot_check >= 0 and baked_fallback > saved_slot_check, "A previously saved user GP2 must load before the baked first-run fallback, or tuner edits are lost at relaunch.")
	for tuning_key: String in CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS:
		assert(CombatSettingsConfig.built_in_contact_settings()["2"].has(tuning_key), "Guard tuning key %s must have a built-in default." % tuning_key)
		assert(menu.contact_controls.has(tuning_key), "Guard tuning key %s needs one visible slider in the Charged Guard tab." % tuning_key)
		var guard_tooltip: String = (menu.contact_controls[tuning_key]["slider"] as HSlider).tooltip_text
		assert(guard_tooltip.contains("← LEFT:") and guard_tooltip.contains("→ RIGHT:") and guard_tooltip.contains("TIP:"), "Guard slider %s needs the full description/left/right/tip tooltip contract." % tuning_key)
	var guard_tab: ScrollContainer = tabs.get_node("Charged Guard") as ScrollContainer
	var state_toggle: HSlider = menu.contact_controls["charged_guard_position_charge_enabled"]["slider"] as HSlider
	assert(is_zero_approx(state_toggle.min_value) and is_equal_approx(state_toggle.max_value, 1.0) and is_equal_approx(state_toggle.step, 1.0), "The charged-position toggle must be a binary 0/1 control.")
	for tuning_key: String in CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS:
		var guard_slider: HSlider = menu.contact_controls[tuning_key]["slider"] as HSlider
		assert(guard_tab.is_ancestor_of(guard_slider), "Guard tuner %s must live inside the Charged Guard tab." % tuning_key)
	menu.free()
