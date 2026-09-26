class_name SwordFormGeometryTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _pose(player: Player, phase: float) -> Dictionary:
	player.swing_time = 0.0
	player.sword_phase = phase
	return player._sword_transform()

func _grip(pose: Dictionary) -> Vector2:
	return (pose["start"] as Vector2) - Vector2.RIGHT.rotated(float(pose["angle"])) * Player.BLADE_HILT_INSET

func _tip(pose: Dictionary) -> Vector2:
	return _grip(pose) + Vector2.RIGHT.rotated(float(pose["angle"])) * Player.BLADE_LENGTH

func test_bind_ids_remain_save_safe_but_only_the_canonical_bind_is_selectable() -> void:
	var fresh_player: Player = PLAYER_SCENE.instantiate() as Player
	assert(fresh_player.sword_style == Player.SwordStyle.METRONOME_BIND_B, "New players must start in canonical public Form I Bind.")
	fresh_player.free()
	assert(int(Player.SwordStyle.METRONOME_WINDUP) == 7)
	assert(int(Player.SwordStyle.METRONOME_BIND) == 8, "Retired Bind A ID must remain load-safe.")
	assert(int(Player.SwordStyle.METRONOME_BIND_B) == 9, "Canonical Bind ID must remain load-safe.")
	assert(Player.SwordStyle.METRONOME_BIND not in Player.STYLE_CYCLE_ORDER)
	assert(Player.STYLE_CYCLE_ORDER.slice(0, 3) == [Player.SwordStyle.METRONOME_BIND_B, Player.SwordStyle.METRONOME_WINDUP, Player.SwordStyle.METRONOME])
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	assert(player._style_name() == "Form I: Bind")
	player.sword_style = Player.SwordStyle.METRONOME
	assert(player._style_name() == "Form III: Metronome V")
	player.free()

func test_old_curved_bind_profile_is_promoted_to_one_shared_authority() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_settings = {"2":{"slide_contact_tolerance":16.0, "slide_angle":30.0}}
	player.combat_hand_settings = {"2:7":{"arc":93.0}, "2:9":{"arc":61.0, "bind_pressure_min":12.0}}
	player.combat_weapon_hand_settings = {
		"Basic Curved Sword":{"2:9":{"rotation":13.5, "bind_pressure_min":30.0, "bind_sword_speed":0.10, "bind_slide_angle":44.0}},
		"Basic Longsword":{"2:9":{"rotation":8.0, "bind_pressure_min":12.0}}
	}
	assert(player.ensure_experimental_form_initialized())
	assert(is_equal_approx(float((player.combat_hand_settings["2:9"] as Dictionary)["bind_pressure_min"]), 30.0), "The latest Curved Sword Bind profile must become the shared canonical profile.")
	for weapon: String in ["Basic Curved Sword", "Basic Longsword"]:
		var bind_values: Dictionary = ((player.combat_weapon_hand_settings[weapon] as Dictionary)["2:9"] as Dictionary)
		assert(not bind_values.has("bind_pressure_min") and not bind_values.has("bind_slide_angle"), "Per-weapon Bind authorities must be removed.")
	player.combat_contact_preset = 2
	for style: Player.SwordStyle in [Player.SwordStyle.METRONOME_BIND, Player.SwordStyle.METRONOME_BIND_B]:
		player.sword_style = style
		player.set_equipped_sword("Basic Curved Sword")
		assert(is_equal_approx(player.get_combat_hand_setting("bind_pressure_min"), 30.0))
		player.set_equipped_sword("Basic Longsword")
		assert(is_equal_approx(player.get_combat_hand_setting("bind_pressure_min"), 30.0))
		assert(is_equal_approx(player.get_combat_contact_setting("slide_angle"), 30.0), "Both legacy Bind IDs must use the one shared Slide profile.")
	player.free()

func test_form_two_and_new_form_three_share_identical_baseline_geometry() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.combat_hand_settings = {"2:7":{"arc":87.0, "max":66.0, "frequency":0.71}}
	player.ensure_experimental_form_initialized()
	player.global_position = Vector2(240.0, 180.0)
	player.aim_angle = 0.42
	player.combat_hand_radius = 54.0
	for phase: float in [0.0, 0.7, 1.8, 3.2, 5.4]:
		player.sword_style = Player.SwordStyle.METRONOME_WINDUP
		var form_two: Dictionary = _pose(player, phase)
		player.sword_style = Player.SwordStyle.METRONOME_BIND
		var form_three: Dictionary = _pose(player, phase)
		assert((form_two["start"] as Vector2).is_equal_approx(form_three["start"] as Vector2))
		assert(is_equal_approx(float(form_two["angle"]), float(form_three["angle"])))
	player.free()

func test_every_weapon_uses_travel_driven_rollover_orientation() -> void:
	for sword_id: String in Player.BLADE_PROFILES.keys():
		var edge_side: float = float(Player.BLADE_EDGE_SIDES.get(sword_id, 1.0))
		assert(is_equal_approx(absf(Player.blade_roll_target_for_travel(edge_side, 1.0)), 1.0), "Every weapon needs a valid forward rollover target.")
		assert(is_equal_approx(Player.blade_roll_target_for_travel(edge_side, -1.0), -Player.blade_roll_target_for_travel(edge_side, 1.0)), "Every weapon must flip rollover when travel reverses.")
	assert(is_equal_approx(Player.blade_roll_target_for_travel(1.0, 1.0), 1.0), "The authored edge orientation should preserve the current forward pose.")
	assert(is_equal_approx(Player.blade_roll_target_for_travel(1.0, -1.0), -1.0), "Opposing travel must request the opposite edge orientation.")

func test_thrust_lanes_follow_globe_meridians_and_converge_on_aim() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 1
	player.sword_style = Player.SwordStyle.THRUST
	player.global_position = Vector2(40.0, 70.0)
	player.virtual_aim_point = Vector2(360.0, 190.0)
	player.aim_angle = player.global_position.direction_to(player.virtual_aim_point).angle()
	player.combat_hand_radius = 45.0
	var expected_pole: Vector2 = player.global_position + Vector2.RIGHT.rotated(player.aim_angle) * (player.combat_hand_radius + Player.BLADE_LENGTH)

	for count: int in [2, 7, 15]:
		player.set_combat_hand_setting("thrusts_per_cycle", float(count))
		for stroke: int in range(count):
			# Each outward thrust reaches its north pole exactly. The hilt trails
			# behind the tip on that stroke's longitude instead of orbiting it.
			var apex_phase: float = (float(stroke) + 0.5) * TAU / float(count)
			var pose: Dictionary = _pose(player, apex_phase)
			var hilt: Vector2 = _grip(pose)
			var tip: Vector2 = _tip(pose)
			assert(tip.distance_to(expected_pole) < 0.01, "Every longitude must converge on the reach pole.")
			assert(absf(hilt.distance_to(tip) - Player.BLADE_LENGTH) < 0.001, "Sword must remain rigid.")
			assert((tip - hilt).dot(expected_pole - player.global_position) > 0.0, "Tip must lead the hilt toward the target.")

		for sample: int in range(120):
			var pose: Dictionary = _pose(player, TAU * float(sample) / 120.0)
			assert(absf(_grip(pose).distance_to(_tip(pose)) - Player.BLADE_LENGTH) < 0.001)
	player.free()

func test_thrust_lane_handoffs_are_continuous() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 1
	player.sword_style = Player.SwordStyle.THRUST
	player.global_position = Vector2(100.0, 200.0)
	player.virtual_aim_point = Vector2(520.0, 260.0)
	player.aim_angle = player.global_position.direction_to(player.virtual_aim_point).angle()
	player.set_combat_hand_setting("thrusts_per_cycle", 7.0)
	var previous_pose: Dictionary = _pose(player, 0.0)
	for sample: int in range(1, 1401):
		var pose: Dictionary = _pose(player, TAU * float(sample) / 1400.0)
		var angle_step: float = absf(angle_difference(float(previous_pose["angle"]), float(pose["angle"])))
		var tip_step: float = _tip(previous_pose).distance_to(_tip(pose))
		assert(angle_step < deg_to_rad(12.0), "Form II longitude handoff must not snap the blade angle.")
		assert(tip_step < 18.0, "Form II longitude handoff must not create a fake swept hit.")
		previous_pose = pose
	player.free()

func test_thrust_setting_copy_rounding_and_stroke_counts() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.sword_style = Player.SwordStyle.THRUST
	player.combat_contact_preset = 1
	assert(player.get_combat_hand_setting("thrusts_per_cycle") == 7.0)
	player.set_combat_hand_setting("thrusts_per_cycle", 8.6)
	assert(player.get_combat_hand_setting("thrusts_per_cycle") == 9.0)
	player.copy_preset_settings(1, 4)
	player.combat_contact_preset = 4
	assert(player.get_combat_hand_setting("thrusts_per_cycle") == 9.0)
	for count: int in [2, 7, 15]:
		player.set_combat_hand_setting("thrusts_per_cycle", float(count))
		assert(player._thrust_stroke_index(TAU) - player._thrust_stroke_index(0.0) == count)
	player.free()

func test_all_forms_and_preset_four_are_rigid() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.aim_angle = 0.0
	player.combat_hand_radius = 45.0
	for preset: int in [1, 4]:
		player.combat_contact_preset = preset
		for style: int in range(Player.SwordStyle.size()):
			player.sword_style = style as Player.SwordStyle
			for blend: float in [0.0, 0.35, 0.5, 1.0]:
				player.p4_form_blend = blend
				for sample: int in range(200):
					var pose: Dictionary = _pose(player, TAU * sample / 200.0)
					assert(absf(_grip(pose).distance_to(_tip(pose)) - 84.0) < 0.001, "Sword must remain rigid 84px.")
	player.free()

func test_form_v_smoothing_restores_lower_is_slower_rate_direction() -> void:
	var frame_delta: float = 1.0 / 60.0
	var very_slow_weight: float = Player.moulinet_smoothing_weight(frame_delta, 0.05)
	var one_rate_weight: float = Player.moulinet_smoothing_weight(frame_delta, 1.0)
	var fast_weight: float = Player.moulinet_smoothing_weight(frame_delta, 6.0)
	assert(very_slow_weight < one_rate_weight)
	assert(one_rate_weight < fast_weight)
	assert(very_slow_weight > 0.0 and very_slow_weight < 0.001, "The 0.05 /s low end must support extremely slow Form V reversals.")

func test_swing_commitment_only_resists_opposing_input() -> void:
	var blade_direction: Vector2 = Vector2.RIGHT
	var sword_velocity: Vector2 = Vector2.DOWN * 100.0
	assert(is_equal_approx(Player.swing_commitment_turn_scale(sword_velocity, blade_direction, Vector2.ZERO, 1.0, 1.0), 1.0), "With-the-blade input must stay fully responsive.")
	assert(is_equal_approx(Player.swing_commitment_turn_scale(sword_velocity, blade_direction, Vector2.ZERO, -1.0, 0.0), 1.0), "Zero commitment must be neutral.")
	assert(is_equal_approx(Player.swing_commitment_turn_scale(sword_velocity, blade_direction, Vector2.ZERO, -1.0, 1.0), 0.25), "Full commitment must leave a controllable quarter-speed response.")
	assert(is_equal_approx(Player.swing_commitment_turn_scale(sword_velocity + Vector2.DOWN * 80.0, blade_direction, Vector2.DOWN * 80.0, -1.0, 1.0), 0.25), "Player translation must not erase sword momentum.")
	assert(is_equal_approx(Player.swing_commitment_turn_scale(Vector2.ZERO, blade_direction, Vector2.ZERO, -1.0, 1.0), 1.0), "A stationary blade must not resist aim input.")

func test_swing_commitment_duration_defaults_to_short_window() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	assert(is_equal_approx(player.get_combat_hand_setting("swing_commitment_duration"), Player.SWING_COMMITMENT_DURATION_DEFAULT), "Swing Commitment Duration should default to the short 0.16s window.")
	player.free()

func test_metronome_windup_profile_is_neutral_or_center_weighted() -> void:
	assert(is_equal_approx(Player.metronome_windup_speed_multiplier(0.2, 0.0, 0.30, 0.20), 1.0), "Zero wind-up profile must preserve linear timing.")
	var early_speed: float = Player.metronome_windup_speed_multiplier(0.10, 1.0, 0.30, 0.20)
	var strike_speed: float = Player.metronome_windup_speed_multiplier(0.55, 1.0, 0.30, 0.20)
	var recovery_speed: float = Player.metronome_windup_speed_multiplier(0.90, 1.0, 0.30, 0.20)
	var deliberately_slow_opening: float = Player.metronome_windup_speed_multiplier(0.01, 1.0, 0.30, 0.20, 0.10, 2.2, 0.10)
	var deliberately_slow_recovery: float = Player.metronome_windup_speed_multiplier(0.99, 1.0, 0.30, 0.20, 0.35, 2.2, 0.10)
	assert(deliberately_slow_opening < early_speed, "The wind-up speed tuner must make the opening phase visibly slower.")
	assert(deliberately_slow_recovery < recovery_speed, "The recovery speed tuner must make the follow-through visibly slower.")
	assert(early_speed < strike_speed, "Wind-up should be slower than the strike window.")
	assert(recovery_speed < strike_speed, "Follow-through recovery should be slower than the strike window.")
	var early_time: float = 0.0
	var total_time: float = 0.0
	for sample: int in range(100):
		var progress: float = (float(sample) + 0.5) / 100.0
		var multiplier: float = Player.metronome_windup_speed_multiplier(progress, 1.0, 0.30, 0.20)
		total_time += 1.0 / multiplier
		if progress < 0.30: early_time += 1.0 / multiplier
	total_time /= 100.0
	early_time /= 100.0
	assert(absf(total_time - 1.0) < 0.03, "Wind-up timing redistribution must preserve total stroke duration.")
	assert(early_time > 0.30, "The configured wind-up portion must consume more time than its linear share.")

func test_action_commitment_defaults_are_neutral_and_late() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	assert(is_equal_approx(player.get_combat_hand_setting("action_commitment_strength"), 0.0), "Action commitment must default neutral.")
	assert(is_equal_approx(player.get_combat_hand_setting("action_commitment_start"), 0.60), "Action commitment should default to a 60% start.")
	assert(is_equal_approx(player.get_combat_hand_setting("action_commitment_end"), 0.90), "Action commitment should default to a late recovery handoff.")
	assert(is_equal_approx(Player.metronome_action_commitment_scale(0.75, 0.0, 0.60, 0.90), 1.0), "Zero action commitment must preserve aim authority.")
	assert(is_equal_approx(Player.metronome_action_commitment_scale(0.50, 1.0, 0.60, 0.90), 1.0), "Before the action window, aim must remain redirectable.")
	assert(is_equal_approx(Player.metronome_action_commitment_scale(0.75, 1.0, 0.60, 0.90), 0.0), "Full action commitment must remove aim authority inside the window.")
	assert(is_equal_approx(Player.metronome_action_commitment_scale(0.95, 1.0, 0.60, 0.90), 1.0), "After the action window, recovery must restore aim authority.")
	assert(player.windup_step_mode == Player.ForwardStepMode.OFF, "Forward Step should begin disabled.")
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	player.windup_step_mode = Player.ForwardStepMode.SWORD_CONTACT
	player.notify_player_damage_dealt(false)
	assert(is_zero_approx(player.windup_step_active_left), "Sword-contact mode must ignore non-sword damage.")
	player.notify_sword_contact()
	assert(is_equal_approx(player.windup_step_active_left, Player.FORWARD_STEP_COMBAT_WINDOW), "Sword-contact mode should arm for three seconds.")
	player.windup_step_mode = Player.ForwardStepMode.ANY_DAMAGE
	player.notify_player_damage_dealt(false)
	assert(is_equal_approx(player.windup_step_active_left, Player.FORWARD_STEP_COMBAT_WINDOW), "Any-damage mode should arm from non-sword damage.")
	assert(is_equal_approx(player.get_combat_hand_setting("backstep_impulse"), 0.0), "Backstep should default to no impulse.")
	assert(is_equal_approx(player.get_combat_hand_setting("backstep_impulse_timing"), 0.30), "Backstep timing should share the safe 30% default.")
	player.free()

func test_moulinet_true_looping_and_sweeps() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 1
	player.aim_angle = 0.0
	player.combat_hand_radius = 45.0

	# Test all Moulinet forms: MOULINET, MOULINET_2, MOULINET_3
	for style: Player.SwordStyle in [Player.SwordStyle.MOULINET, Player.SwordStyle.MOULINET_2, Player.SwordStyle.MOULINET_3]:
		player.sword_style = style

		# 1. Hilt symmetry: at phase=0 and phase=PI, hilt is at center
		var hilt_0: Vector2 = _grip(_pose(player, 0.0))
		var hilt_pi: Vector2 = _grip(_pose(player, PI))
		assert(hilt_0.distance_to(hilt_pi) < 0.01, "Hilt must cross exactly at center.")

		# 2. Smooth angular continuity across cycle: no snapping jumps > 15 deg
		var prev_angle: float = float(_pose(player, 0.0)["angle"])
		for i in range(1, 360):
			var p_angle: float = float(_pose(player, TAU * float(i) / 360.0)["angle"])
			var step: float = absf(wrapf(p_angle - prev_angle, -PI, PI))
			assert(step < deg_to_rad(15.0), "No angular jumping or snaps in style %d." % int(style))
			prev_angle = p_angle

		# 3. Sword rigidity (always exactly 84px)
		for i in range(60):
			var pose: Dictionary = _pose(player, TAU * float(i) / 60.0)
			assert(absf(_grip(pose).distance_to(_tip(pose)) - 84.0) < 0.001)

	# 4. Moulinet 2 (Chat Formula) alternating rotation verification:
	player.sword_style = Player.SwordStyle.MOULINET_2
	# In right lobe (0 -> PI), angle increases (clockwise rotation)
	var ang_0: float = float(_pose(player, 0.0)["angle"])
	var ang_half_right: float = float(_pose(player, PI * 0.5)["angle"])
	var ang_cross: float = float(_pose(player, PI)["angle"])
	assert(ang_half_right > ang_0, "Right lobe rotates clockwise.")
	assert(ang_cross > ang_half_right, "Right lobe completes clockwise rotation.")

	# In left lobe (PI -> 2*PI), angle decreases (counter-clockwise rotation)
	var ang_half_left: float = float(_pose(player, PI * 1.5)["angle"])
	var ang_end: float = float(_pose(player, TAU)["angle"])
	assert(ang_half_left < ang_cross, "Left lobe rotates counter-clockwise.")
	assert(ang_end < ang_half_left, "Left lobe completes counter-clockwise rotation.")

	player.free()

