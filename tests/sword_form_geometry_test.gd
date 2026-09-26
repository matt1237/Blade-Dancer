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

func test_bind_is_the_only_surviving_sword_form() -> void:
	assert(Player.SwordStyle.size() == 1, "Only the Bind form should survive the clean slate.")
	assert(int(Player.SwordStyle.BIND) == 0, "Bind must be the canonical zero-indexed form for the rebuild.")
	assert(Player.STYLE_CYCLE_ORDER == [Player.SwordStyle.BIND], "The Z/X cycle must contain only the surviving form.")
	var fresh_player: Player = PLAYER_SCENE.instantiate() as Player
	assert(fresh_player.sword_style == Player.SwordStyle.BIND, "New players must start in Form I: Bind.")
	assert(fresh_player._style_name() == "Form I: Bind")
	fresh_player.free()

func test_old_curved_bind_profile_is_promoted_to_one_shared_authority() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_settings = {"2":{"slide_contact_tolerance":16.0, "slide_angle":30.0}}
	player.combat_hand_settings = {"2:0":{"arc":88.0}, "2:7":{"arc":93.0}, "2:9":{"arc":61.0, "bind_pressure_min":12.0}}
	player.combat_weapon_hand_settings = {
		"Basic Curved Sword":{"2:9":{"rotation":13.5, "bind_pressure_min":30.0, "bind_sword_speed":0.10, "bind_slide_angle":44.0}},
		"Basic Longsword":{"2:9":{"rotation":8.0, "bind_pressure_min":12.0}}
	}
	assert(player.ensure_experimental_form_initialized(), "The first migration must report a change.")
	assert(is_equal_approx(float((player.combat_hand_settings["2:0"] as Dictionary)["bind_pressure_min"]), 30.0), "The latest Curved Sword Bind profile must become the shared canonical profile.")
	assert((player.combat_hand_settings["2:0"] as Dictionary).has("bind_enabled"), "The migrated profile must carry Bind's own marker.")
	assert(is_equal_approx(float((player.combat_hand_settings["2:0"] as Dictionary).get("arc", 88.0)), 61.0), "The retired Metronome profile at index 0 must be replaced by the legacy Bind profile, not kept.")
	assert(not player.combat_hand_settings.has("2:9") and not player.combat_hand_settings.has("2:7"), "Retired form profiles must be dropped.")
	assert(not player.ensure_experimental_form_initialized(), "Re-running the migration must be a no-op.")
	player.combat_contact_preset = 2
	player.set_equipped_sword("Basic Curved Sword")
	assert(is_equal_approx(player.get_combat_hand_setting("bind_pressure_min"), 30.0))
	player.set_equipped_sword("Basic Longsword")
	assert(is_equal_approx(player.get_combat_hand_setting("bind_pressure_min"), 30.0))
	assert(is_equal_approx(player.get_combat_contact_setting("slide_angle"), 30.0), "The one shared Slide profile must be used.")
	player.free()

func test_every_weapon_uses_travel_driven_rollover_orientation() -> void:
	for sword_id: String in Player.BLADE_PROFILES.keys():
		var edge_side: float = float(Player.BLADE_EDGE_SIDES.get(sword_id, 1.0))
		assert(is_equal_approx(absf(Player.blade_roll_target_for_travel(edge_side, 1.0)), 1.0), "Every weapon needs a valid forward rollover target.")
		assert(is_equal_approx(Player.blade_roll_target_for_travel(edge_side, -1.0), -Player.blade_roll_target_for_travel(edge_side, 1.0)), "Every weapon must flip rollover when travel reverses.")
	assert(is_equal_approx(Player.blade_roll_target_for_travel(1.0, 1.0), 1.0), "The authored edge orientation should preserve the current forward pose.")
	assert(is_equal_approx(Player.blade_roll_target_for_travel(1.0, -1.0), -1.0), "Opposing travel must request the opposite edge orientation.")

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
	assert(is_equal_approx(player.get_combat_hand_setting("backstep_impulse"), 0.0), "Backstep should default to no impulse.")
	assert(is_equal_approx(player.get_combat_hand_setting("backstep_impulse_timing"), 0.30), "Backstep timing should share the safe 30% default.")
	player.free()

func test_counter_steer_compression_shrinks_only_the_active_side_and_never_jumps_behind() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.aim_angle = 0.0
	player.combat_hand_radius = 45.0
	var compression: float = 0.22
	# Right half-stroke: sin > 0, so the destination apex sits on the +side of base.
	player.counter_steer_compression = 0.0
	var right_base: float = float(_pose(player, PI * 0.5)["angle"])
	var arc: float = player._current_sword_arc_degrees()
	player.counter_steer_compression = compression
	var right_compressed: float = float(_pose(player, PI * 0.5)["angle"])
	var right_delta: float = right_base - right_compressed
	assert(is_equal_approx(right_delta, deg_to_rad(arc) * compression), "Compression must remove exactly the configured fraction of the active side's arc.")
	assert(right_compressed > player.aim_angle, "The compressed apex must stay on the same side of base; it can never jump behind the current angle.")
	# Left half-stroke: the exact mirror, pulled toward base from the -side.
	player.counter_steer_compression = 0.0
	var left_base: float = float(_pose(player, PI * 1.5)["angle"])
	player.counter_steer_compression = compression
	var left_compressed: float = float(_pose(player, PI * 1.5)["angle"])
	assert(is_equal_approx(left_compressed - left_base, deg_to_rad(arc) * compression), "Compression must mirror on the opposing side.")
	assert(left_compressed < player.aim_angle, "The compressed apex must remain on the same side of base on the opposing stroke too.")
	player.free()

func test_counter_steer_compression_geometry_is_continuous_across_the_cycle() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.combat_contact_preset = 2
	player.aim_angle = 0.0
	player.combat_hand_radius = 45.0
	player.counter_steer_compression = Player.COUNTER_STEER_ARC_COMPRESSION_MAX
	var previous: float = float(_pose(player, 0.0001)["angle"])
	var max_step: float = 0.0
	for sample: int in range(1, 400):
		var angle: float = float(_pose(player, TAU * float(sample) / 400.0)["angle"])
		max_step = maxf(max_step, absf(angle - previous))
		previous = angle
	assert(max_step < deg_to_rad(3.0), "A constant compression must not step the blade; the geometry stays continuous.")
	assert(player.sword_phase != 0.0, "Sampling geometry must never reset the sacred metronome clock.")
	player.free()

func test_counter_steer_compression_target_gates_on_opposing_strength() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	assert(is_equal_approx(player.get_combat_hand_setting("counter_steer_arc_enabled"), 1.0), "Counter-steer should ship enabled for the A/B test.")
	assert(is_equal_approx(player.get_combat_hand_setting("counter_steer_arc_compression"), Player.COUNTER_STEER_ARC_COMPRESSION_DEFAULT), "Counter-steer compression should default to the mid value.")
	assert(is_equal_approx(Player.COUNTER_STEER_ARC_COMPRESSION_DEFAULT, 0.22), "The experiment starts around 0.22.")
	assert(is_equal_approx(Player.COUNTER_STEER_ARC_COMPRESSION_MAX, 0.40), "The exposed range tops out at 0.40.")
	player.authored_sword_engagement = 0.60
	assert(is_equal_approx(player._counter_steer_compression_target(1.0, 1.0), 0.0), "Input aligned with travel must not compress the arc.")
	assert(is_equal_approx(player._counter_steer_compression_target(0.0, 1.0), 0.0), "No authored turn must not compress the arc.")
	assert(player._counter_steer_compression_target(1.0, -1.0) > 0.0, "Opposing input must compress the active side.")
	player.authored_sword_engagement = 0.04
	assert(is_equal_approx(player._counter_steer_compression_target(1.0, -1.0), 0.0), "Weak input noise below the engagement floor must be ignored.")
	player.authored_sword_engagement = 1.0
	assert(is_equal_approx(player._counter_steer_compression_target(1.0, -1.0), Player.COUNTER_STEER_ARC_COMPRESSION_DEFAULT), "Full opposing strength must reach the configured fraction.")
	player.set_combat_hand_setting("counter_steer_arc_compression", 0.90)
	assert(is_equal_approx(player._counter_steer_compression_target(1.0, -1.0), Player.COUNTER_STEER_ARC_COMPRESSION_MAX), "The fraction must clamp to the 0.40 ceiling.")
	player.set_combat_hand_setting("counter_steer_arc_enabled", 0.0)
	assert(is_equal_approx(player._counter_steer_compression_target(1.0, -1.0), 0.0), "Disabled must produce identical, unmodified geometry.")
	player.free()

