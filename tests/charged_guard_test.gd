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
	player.charged_guard_authored_lateral_aim_speed = player.get_combat_contact_setting("charged_guard_break_speed") + 1.0
	player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_locked, "A deliberate sideways flick should release the lock.")
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
	assert(Player.charged_guard_motion_breaks(400.0, 270.0), "A medium/fast deliberate sideways flick should still break charged Guard.")
	assert(not Player.charged_guard_motion_breaks(0.0, 270.0), "A purely radial push must retain Guard however fast it is.")
	assert(not Player.charged_guard_motion_breaks(100.0, 270.0), "Player movement alone must not meet the authored flick threshold.")
	var bounded_offset: Vector2 = Player.charged_guard_clamp_hand_offset(Vector2(100.0, 0.0), 30.0)
	assert(is_equal_approx(bounded_offset.length(), 30.0), "Charged hand reposition must remain inside the original lock radius.")

func test_charged_hand_keeps_following_the_cursor_while_the_player_walks() -> void:
	# Regression: the reposition scale was doing double duty as "should the hand follow at
	# all", so walking -- which returns the full-speed 1.0 scale -- skipped repositioning
	# entirely and pinned the charged blade in place. Speed and following are separate.
	var break_speed: float = 600.0
	var step: float = 1.0 / 60.0
	var walking_scale: float = Player.charged_guard_slow_reposition_scale(0.0, break_speed, true)
	assert(is_equal_approx(walking_scale, 1.0), "Player translation must keep the charged hand at full reposition speed.")
	assert(Player.charged_guard_hand_follows_cursor(true, true, 1.0), "A ramped-in charged guard must follow the cursor at full speed, which is exactly the scale walking produces.")
	assert(Player.charged_guard_hand_follows_cursor(true, true, 0.70), "The damped band must still follow the cursor, just more slowly.")
	assert(not Player.charged_guard_hand_follows_cursor(true, true, 0.0), "The hand holds still only while the wake-up ramp is still at zero.")
	assert(not Player.charged_guard_hand_follows_cursor(false, true, 1.0), "The confirm hold before the charged state must stay frozen.")
	assert(not Player.charged_guard_hand_follows_cursor(true, false, 1.0), "With the position stage off the charged hand must never reposition.")
	var current_offset: Vector2 = Vector2.RIGHT * 20.0
	var walked: Vector2 = Player.charged_guard_repositioned_hand_offset(current_offset, Vector2.UP * 20.0, Player.CHARGED_GUARD_REPOSITION_SPEED * walking_scale, step)
	assert(walked.distance_to(current_offset) > 0.0, "While walking, the charged hand must still travel toward the cursor instead of freezing in place.")

func test_charged_hand_ignores_player_translation_and_follows_the_cursor_itself() -> void:
	# End-to-end through the real aim update. The camera leads, lags and clamps relative to
	# the player, so the cursor's *world point* slides while the player walks; an earlier
	# build drove the charged hand from it and player movement steered the guard. The hand
	# must now read only the cursor's own motion, which is zero on a still cursor.
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.set_combat_contact_setting("charged_guard_position_charge_enabled", 1.0)
	player.set_input_mode("keyboard_mouse")
	player.has_virtual_aim_sample = true
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	player.charged_guard_reposition_ramp = 1.0
	player.charged_guard_lock_radius = 40.0
	player.charged_guard_lock_hand_offset = Vector2.RIGHT * 30.0
	player.charged_guard_radial_direction = Vector2.RIGHT
	player.charged_guard_lock_angle = 0.0
	player.aim_angle = 0.0
	var offset_before: Vector2 = player.charged_guard_lock_hand_offset
	var angle_before: float = player.charged_guard_lock_angle
	for _frame: int in range(30):
		# Walking hard, exactly as _physics_process detects it, with the cursor untouched.
		player.global_position += Vector2(9.0, 4.0)
		player.charged_guard_movement_suppression_left = 0.40
		player._update_aim(1.0 / 60.0)
	assert(player.charged_guard_movement_suppression_left > 0.0, "This setup must reproduce the walking suppression that used to freeze the hand.")
	assert(player.charged_guard_cursor_motion.is_zero_approx(), "The walk phase is only meaningful with no cursor motion.")
	assert(player.charged_guard_lock_hand_offset.is_equal_approx(offset_before), "Walking must not move the charged hand: the cursor's world point follows the camera, the cursor itself did not move.")
	assert(is_equal_approx(player.charged_guard_lock_angle, angle_before), "Walking must not turn the charged blade either.")
	# A real cursor move must still reposition the hand and turn the blade.
	var motion_event: InputEventMouseMotion = InputEventMouseMotion.new()
	motion_event.relative = Vector2(0.0, 60.0)
	player._input(motion_event)
	player._update_aim(1.0 / 60.0)
	assert(player.charged_guard_cursor_motion.length() > 0.0, "A real mouse-motion event must reach the charged guard as cursor motion.")
	assert(not player.charged_guard_lock_hand_offset.is_equal_approx(offset_before), "A real cursor move must still reposition the charged hand.")
	assert(not is_equal_approx(player.charged_guard_lock_angle, angle_before), "A real cursor move must still turn the charged blade.")
	assert(player.charged_guard_lock_hand_offset.length() <= player.charged_guard_lock_radius + 0.001, "Cursor-driven repositioning must still respect the lock radius.")
	player.free()

func test_charged_guard_reposition_converges_instead_of_accumulating_cursor_displacement() -> void:
	# Regression: the locked hand used to integrate raw cursor displacement, so
	# leaving the hand range and re-entering from a new direction snapped the
	# blade onto a stale radial direction. The hand must converge on the bounded
	# aim target and never move further in one step than its reposition speed.
	var minimum_radius: float = Player.CHARGED_GUARD_MIN_HAND_RADIUS
	var lock_radius: float = 40.0
	var reposition_speed: float = 270.0
	var step: float = 1.0 / 60.0
	var offset: Vector2 = Vector2.RIGHT * lock_radius
	var outward_target: Vector2 = Player.charged_guard_clamp_hand_offset(Vector2.RIGHT * 500.0, lock_radius, minimum_radius, Vector2.RIGHT)
	assert(is_equal_approx(outward_target.length(), lock_radius), "An aim flung outside the hand range must clamp to the lock radius rather than accumulate.")
	var outward_offset: Vector2 = Player.charged_guard_repositioned_hand_offset(offset, outward_target, reposition_speed, step)
	assert(outward_offset.length() <= lock_radius + 0.001, "Repositioning may never carry the hand beyond the lock radius.")
	var inward_target: Vector2 = Player.charged_guard_clamp_hand_offset(Vector2.LEFT * 500.0, lock_radius, minimum_radius, Vector2.RIGHT)
	var swing_offset: Vector2 = Player.charged_guard_repositioned_hand_offset(outward_offset, inward_target, reposition_speed, step)
	var travelled: float = outward_offset.distance_to(swing_offset)
	assert(travelled > 0.0, "Re-entering from a new direction must move the hand toward the new target.")
	assert(travelled <= reposition_speed * step + 0.001, "A single reposition step must never exceed the reposition speed, so re-entry from a new direction cannot jump.")
	var settled: Vector2 = outward_offset
	for _frame: int in range(60):
		settled = Player.charged_guard_repositioned_hand_offset(settled, inward_target, reposition_speed, step)
	assert(settled.is_equal_approx(inward_target), "Sustained repositioning must settle exactly on the bounded aim target.")

func test_guard_break_speed_is_tunable_and_defaults_to_the_shipped_threshold() -> void:
	var player: Player = _new_player()
	var shipped_threshold: float = player.get_combat_contact_setting("charged_guard_break_speed")
	assert(is_equal_approx(shipped_threshold, 600.0), "The Guard break threshold should default to 600 px/s of sideways aim movement.")
	assert(Player.charged_guard_motion_breaks(shipped_threshold + 1.0, shipped_threshold), "A sideways flick just above the tuned threshold must break the guard.")
	assert(not Player.charged_guard_motion_breaks(shipped_threshold - 1.0, shipped_threshold), "A sideways flick just below the tuned threshold must not break the guard.")
	player.set_combat_contact_setting("charged_guard_break_speed", 1000.0)
	var raised_threshold: float = player.get_combat_contact_setting("charged_guard_break_speed")
	assert(is_equal_approx(raised_threshold, 1000.0), "The Guard break threshold must persist through the contact preset authority.")
	assert(not Player.charged_guard_motion_breaks(700.0, raised_threshold), "Raising the tuner must stop the same flick from breaking the guard.")
	assert(Player.charged_guard_motion_breaks(700.0, shipped_threshold), "The same flick must still break the guard at the shipped threshold, proving the tuner is what changed.")
	player.free()

func test_charged_guard_blade_conform_sweeps_instead_of_snapping() -> void:
	# Regression: the guard hard-clamped the blade onto +/-90 degrees off the hand
	# radial direction. The metronome arc swings the blade well past that limit, so
	# the clamp could rotate the sword tens of degrees in a single frame.
	var radial_direction: Vector2 = Vector2.RIGHT
	var hand_offset: Vector2 = Vector2.RIGHT * 40.0
	var conform_rate: float = 8.0
	var step: float = 1.0 / 60.0
	var unsafe_angle: float = deg_to_rad(140.0)
	var safe_limit: float = deg_to_rad(90.0)
	var first_step: float = Player.charged_guard_conformed_blade_angle(unsafe_angle, hand_offset, radial_direction, conform_rate, step)
	var swept_degrees: float = absf(rad_to_deg(angle_difference(unsafe_angle, first_step)))
	assert(swept_degrees > 0.0, "An out-of-cone blade must start sweeping back toward the safe angle.")
	assert(swept_degrees < 10.0, "One frame must never rotate the blade by the whole clamp distance, which is what popped.")
	var settled: float = unsafe_angle
	for _frame: int in range(120):
		settled = Player.charged_guard_conformed_blade_angle(settled, hand_offset, radial_direction, conform_rate, step)
	assert(absf(angle_difference(safe_limit, settled)) < deg_to_rad(0.5), "Sustained conforming must settle on the 90 degree safe boundary without overshooting.")
	var in_cone_angle: float = deg_to_rad(45.0)
	assert(is_equal_approx(Player.charged_guard_conformed_blade_angle(in_cone_angle, hand_offset, radial_direction, conform_rate, step), in_cone_angle), "A blade already inside the safe cone must be left completely untouched.")

func test_guard_break_measure_tracks_the_blade_not_the_cursor_distance() -> void:
	# Regression, second pass. The first form divided the aim's travel by the live
	# player-to-cursor distance, so the same flick broke the guard up close, did nothing
	# far away, and left the tuner inert past ~130 px. Removing that division made the
	# measure distance-free in CURSOR pixels -- but the hand's reach is clamped, so past
	# hand range a sideways sweep of p px at distance d swings the blade only
	# (reach / d) * p px. Raw cursor pixels therefore broke the guard on sweeps that barely
	# moved the blade, which is the accidental break that was reported.
	var delta: float = 1.0 / 60.0
	var reach_limit: float = 80.0
	var sideways_flick: Vector2 = Vector2(0.0, 4.0)
	var inside_speed: float = Player.charged_guard_lateral_aim_speed(Vector2(40.0, 0.0), sideways_flick, delta, reach_limit)
	assert(is_equal_approx(inside_speed, 4.0 / delta), "Inside hand range the measure must be the cursor's own sideways speed in px/s, leaving the tuned feel untouched.")
	var edge_speed: float = Player.charged_guard_lateral_aim_speed(Vector2(reach_limit, 0.0), sideways_flick, delta, reach_limit)
	assert(is_equal_approx(edge_speed, inside_speed), "The gearing must begin exactly at the hand-range limit, with no step at the boundary.")
	var far_speed: float = Player.charged_guard_lateral_aim_speed(Vector2(reach_limit * 4.0, 0.0), sideways_flick, delta, reach_limit)
	assert(is_equal_approx(far_speed, inside_speed / 4.0), "Past hand range the measure must fall off as reach / distance, the share of the sweep that can actually move the hand.")
	var ungeared_speed: float = Player.charged_guard_lateral_aim_speed(Vector2(reach_limit * 4.0, 0.0), sideways_flick, delta)
	assert(is_equal_approx(ungeared_speed, inside_speed), "Mobile and controller aim is already in hand-space, so a zero reach limit must disable the gearing entirely.")
	var radial_push: Vector2 = Vector2(6.0, 0.0)
	var push_speed: float = Player.charged_guard_lateral_aim_speed(Vector2(300.0, 0.0), radial_push, delta, reach_limit)
	assert(is_zero_approx(push_speed), "Pushing the cursor straight out along the aim axis must measure as no sideways flick at all.")
	var yank: Vector2 = Vector2(0.0, 10.0)
	var near_yank: float = Player.charged_guard_lateral_aim_speed(Vector2(40.0, 0.0), yank, delta, reach_limit)
	var far_yank: float = Player.charged_guard_lateral_aim_speed(Vector2(reach_limit * 4.0, 0.0), yank, delta, reach_limit)
	assert(Player.charged_guard_motion_breaks(near_yank, 600.0), "A sideways yank inside hand range must still break the guard at the shipped threshold.")
	assert(not Player.charged_guard_motion_breaks(far_yank, 600.0), "The identical cursor sweep at four times hand range must no longer break the guard; that is the accidental break that was reported.")
	assert(Player.charged_guard_motion_breaks(far_yank, 120.0), "A deliberately lowered threshold must still let a range sweep break the guard, so the tuner is never inert.")
	assert(not Player.charged_guard_motion_breaks(push_speed, 1.0), "A purely radial push must retain the guard even against a near-zero threshold.")

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

func test_charged_guard_shimmer_oscillates_between_blue_and_white() -> void:
	var speed: float = FlowColorUtils.CHARGE_SHIMMER_SPEED
	var blue_phase: Color = FlowColorUtils.charged_oscillating_color(3.0 * PI / (2.0 * speed))
	var white_phase: Color = FlowColorUtils.charged_oscillating_color(PI / (2.0 * speed))
	assert(not blue_phase.is_equal_approx(white_phase), "The charged shimmer must actually oscillate instead of holding one tone.")
	assert(white_phase.r > blue_phase.r and white_phase.g > blue_phase.g, "The shimmer must lighten toward white, not darken.")
	assert(blue_phase.b >= blue_phase.r and white_phase.b >= white_phase.r, "Both ends of the shimmer must stay blue-led so the state still reads as the blue guard.")
	assert(is_equal_approx(blue_phase.a, 1.0) and is_equal_approx(white_phase.a, 1.0), "The shimmer tone must stay opaque; callers apply their own alpha.")

func test_charged_guard_afterimages_emit_continuously_while_blue() -> void:
	var player: Player = _new_player()
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	player.set_combat_contact_setting("charged_guard_position_charge_enabled", 1.0)
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	player.charged_guard_lock_hand_offset = Vector2(40.0, 0.0)
	for _frame: int in range(30):
		player._update_charged_guard(1.0 / 60.0)
	assert(not player.charged_guard_afterimages.is_empty(), "A fully charged guard must trail afterimages even while the hand holds still.")
	assert(player.charged_guard_afterimages.size() <= Player.CHARGED_GUARD_AFTERIMAGE_COUNT, "The afterimage trail must stay inside its fixed pool size.")
	for image: Vector2 in player.charged_guard_afterimages:
		assert(image.is_equal_approx(Vector2(40.0, 0.0)), "Each afterimage must record the hand offset it was sampled at.")
	player.free()
