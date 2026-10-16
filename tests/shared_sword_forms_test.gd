class_name SharedSwordFormsTest
extends Node

const Fixture = preload("res://tests/dualblade_test.gd")
const WEAPONS: Array[String] = ["Basic Longsword", "Basic Curved Sword", ArmoryConfig.DUALBLADE_NAME, ArmoryConfig.DOUBLE_ENDED_NAME, ArmoryConfig.GREATSWORD_NAME]

func _fixture() -> Node:
	var fixture: Node = Fixture.new()
	add_child(fixture)
	return fixture

func test_twin_equip_defaults_to_thrust_without_overwriting_manual_selection_on_refresh() -> void:
	var player: Player = Player.new()
	assert(player.sword_style == Player.SwordStyle.METRONOME_BIND_B)
	player.set_equipped_sword(ArmoryConfig.DOUBLE_ENDED_NAME)
	assert(player.sword_style == Player.SwordStyle.METRONOME_BIND_B, "Not a default for the double-ended sword")
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.sword_style == Player.SwordStyle.WINDUP_THRUST)
	player.set_sword_form(Player.SwordStyle.MOULINET)
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.sword_style == Player.SwordStyle.MOULINET, "Gear refresh must retain a manually selected form")
	player.set_equipped_sword("Basic Longsword")
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.sword_style == Player.SwordStyle.WINDUP_THRUST, "Fresh equip restores the twin default")
	player.free()

func test_four_form_cycle_on_every_weapon_and_stable_legacy_ids() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	assert(int(Player.SwordStyle.METRONOME_BIND_B) == 9)
	assert(int(Player.SwordStyle.THRUST) == 1)
	assert(int(Player.SwordStyle.WINDUP_THRUST) == 10)
	assert(Player.STYLE_CYCLE_ORDER.size() == 4)
	for weapon: String in WEAPONS:
		player.set_equipped_sword(weapon)
		player.sword_style = Player.SwordStyle.METRONOME_BIND_B
		for style: int in Player.STYLE_CYCLE_ORDER:
			assert(int(player.sword_style) == style)
			player.cycle_sword_form(1)
		assert(player.sword_style == Player.SwordStyle.METRONOME_BIND_B)
		player.cycle_sword_form(-1)
		assert(player.sword_style == Player.SwordStyle.MOULINET_3)
	assert(Player.sword_form_name(10) == "Form II: Thrust")
	fixture.free()

func test_longsword_tuning_automatically_drives_every_weapon_without_copying_profiles() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	for style: Player.SwordStyle in [Player.SwordStyle.WINDUP_THRUST, Player.SwordStyle.MOULINET, Player.SwordStyle.MOULINET_3]:
		player.sword_style = style
		player.set_equipped_sword("Basic Longsword")
		player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 0.73)
		player.set_combat_hand_setting_for_sword("Basic Longsword", "arc", 65.0)
		player.set_combat_hand_setting("thrust_extension_px", 37.0)
		var before: Dictionary = player.combat_weapon_hand_settings.duplicate(true)
		for weapon: String in WEAPONS:
			player.set_equipped_sword(weapon)
			player.sword_style = style # explicitly test this form after the equip default
			assert(is_equal_approx(player.get_combat_hand_setting("frequency"), 0.73))
			assert(is_equal_approx(player.get_combat_hand_setting("arc"), 65.0))
			assert(is_equal_approx(player.get_combat_hand_setting("thrust_extension_px"), 37.0))
			assert(player.combat_weapon_hand_settings == before, "Equip must not materialize motion copies")
		player.set_combat_hand_setting_for_sword(ArmoryConfig.DOUBLE_ENDED_NAME, "frequency", 0.91)
		player.set_equipped_sword("Basic Longsword")
		assert(is_equal_approx(player.get_combat_hand_setting("frequency"), 0.91))
	fixture.free()

func test_shared_thrust_envelope_single_and_twins_use_own_blade_axis_only_in_form_two() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	player.sword_style = Player.SwordStyle.WINDUP_THRUST
	player.aim_angle = 0.3
	player.combat_hand_radius = 50.0
	player.set_combat_contact_setting("authored_metronome_enabled", 1.0)
	player.authored_metronome_swing_blend = 1.0
	for weapon: String in ["Basic Longsword", ArmoryConfig.DUALBLADE_NAME]:
		player.set_equipped_sword(weapon)
		for index: int in range(2 if player.dualblade_equipped else 1):
			player.active_blade_index = index if player.dualblade_equipped else -1
			player.twin_stab_cycle = index
			for sample: Vector2 in [Vector2(0.40, -10.0), Vector2(0.50, 20.0), Vector2(0.80, 0.0)]:
				player.sword_phase = PI * 0.5 + sample.x * PI
				var pose: Dictionary = player._sword_intent_transform()
				var rest: Vector2 = player.global_position + Vector2.from_angle(player.aim_angle) * 50.0
				if player.dualblade_equipped:
					rest += Vector2.from_angle(player.aim_angle).orthogonal() * (-25.0 if index == 0 else 25.0)
				assert(((pose["start"] as Vector2) - rest).distance_to(Vector2.from_angle(float(pose["angle"])) * sample.y) < 0.001)
		player.active_blade_index = -1
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.sword_phase = PI
	player.active_blade_index = 1
	var bind_pose: Dictionary = player._sword_intent_transform()
	var bind_rest: Vector2 = player.global_position + Vector2.from_angle(player.aim_angle) * 50.0 + Vector2.from_angle(player.aim_angle).orthogonal() * 25.0
	assert((bind_pose["start"] as Vector2).distance_to(bind_rest) < 0.001, "Bind must not inherit Thrust pulses")
	player.active_blade_index = -1
	fixture.free()

func test_moulinets_preserve_moving_grip_and_rotation_with_authored_gp2_enabled() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	player.set_combat_contact_setting("authored_metronome_enabled", 1.0)
	player.authored_metronome_swing_blend = 0.0
	player.aim_angle = 0.3
	for weapon: String in WEAPONS:
		player.set_equipped_sword(weapon)
		for style: Player.SwordStyle in [Player.SwordStyle.MOULINET, Player.SwordStyle.MOULINET_3]:
			player.sword_style = style
			assert(not player._authored_metronome_mode_applies(), "Metronome pose flattening must not own moulinets")
			player.active_blade_index = 0 if player.dualblade_equipped else -1
			player.sword_phase = 0.2
			player.moulinet_continuous_angle = 0.2
			var first: Dictionary = player._sword_intent_transform()
			player.sword_phase = 1.4
			player.moulinet_continuous_angle = 1.4
			var second: Dictionary = player._sword_intent_transform()
			assert((first["start"] as Vector2).distance_to(second["start"] as Vector2) > 1.0)
			assert(absf(angle_difference(float(first["angle"]), float(second["angle"]))) > 0.1)
		player.active_blade_index = -1
	fixture.free()

func test_double_ended_keeps_one_grip_and_opposed_ends_for_all_forms() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	player.set_equipped_sword(ArmoryConfig.DOUBLE_ENDED_NAME)
	for style: int in Player.STYLE_CYCLE_ORDER:
		player.sword_style = style as Player.SwordStyle
		for phase: float in [0.3, PI, 4.5]:
			player.sword_phase = phase
			player.moulinet_continuous_angle = phase
			player.active_blade_index = 0
			var a: Dictionary = player._sword_intent_transform()
			player.active_blade_index = 1
			var b: Dictionary = player._sword_intent_transform()
			var grip_a: Vector2 = (a["start"] as Vector2) - Vector2.from_angle(float(a["angle"])) * player._blade_hilt_inset()
			var grip_b: Vector2 = (b["start"] as Vector2) - Vector2.from_angle(float(b["angle"])) * player._blade_hilt_inset()
			assert(grip_a.distance_to(grip_b) < 0.001, "One rigid shared grip")
			assert(absf(absf(angle_difference(float(a["angle"]), float(b["angle"]))) - PI) < 0.001)
	player.active_blade_index = -1
	fixture.free()

func test_full_figure_eight_reverses_after_shared_phase_wrap() -> void:
	var fixture: Node = _fixture()
	var player: Player = fixture.make_player()
	player.sword_style = Player.SwordStyle.MOULINET
	player.sword_phase = 1.0
	var forward_a: Dictionary = player._calculate_form_moulinet(0.0, 50.0, 70.0)
	player.sword_phase = 1.1
	var forward_b: Dictionary = player._calculate_form_moulinet(0.0, 50.0, 70.0)
	assert(float(forward_b["angle"]) > float(forward_a["angle"]))
	player.sword_phase = TAU - 0.001
	player._advance_sword_drive(0.016, 0.016, player.sword_phase)
	assert(player.moulinet_full8_reverse_cycle)
	player.sword_phase = 1.0
	var reverse_a: Dictionary = player._calculate_form_moulinet(0.0, 50.0, 70.0)
	player.sword_phase = 1.1
	var reverse_b: Dictionary = player._calculate_form_moulinet(0.0, 50.0, 70.0)
	assert(float(reverse_b["angle"]) < float(reverse_a["angle"]))
	fixture.free()
