class_name TwinWindupStabTest
extends Node

const Fixture = preload("res://tests/dualblade_test.gd")

func test_10px_coil_20px_stab_with_exclusive_stroke_owner() -> void:
	var player: Player = Player.new()
	for cycle: int in range(4):
		for index: int in range(2):
			player.twin_stab_cycle = index
			var coil_phase: float = PI * 0.5 + (float(cycle) + 0.40) * PI
			var stab_phase: float = PI * 0.5 + (float(cycle) + 0.50) * PI
			assert(is_equal_approx(player._twin_stab_extension(coil_phase, index), -10.0))
			assert(is_equal_approx(player._twin_stab_extension(stab_phase, index), 20.0))
			assert(is_zero_approx(player._twin_stab_extension(stab_phase, 1 - index)), "Other blade only sweeps this cycle")
			assert(is_zero_approx(player._twin_stab_extension(PI * 0.5 + (float(cycle) + 0.80) * PI, index)))
	for owner_cycle: int in range(4):
		player.twin_stab_cycle = owner_cycle
		var owner: int = owner_cycle % 2
		for step: int in range(1000):
			var phase: float = float(step) * TAU / 1000.0
			var reach: float = player._twin_stab_extension(phase, owner)
			assert(reach >= -10.001 and reach <= 20.001)
			assert(is_zero_approx(player._twin_stab_extension(phase, 1 - owner)), "Inactive blade never coils or stabs")
	player.free()

func test_exactly_one_stab_at_50_percent_in_both_directions() -> void:
	var player: Player = Player.new()
	player.twin_stab_cycle = 1
	for direction: int in range(2):
		var start: float = PI * 0.5 + float(direction) * PI
		var peaks: int = 0
		for step: int in range(1, 100):
			var phase: float = start + float(step) * PI / 100.0
			var before: float = player._twin_stab_extension(phase - PI / 100.0, 1)
			var reach: float = player._twin_stab_extension(phase, 1)
			var after: float = player._twin_stab_extension(phase + PI / 100.0, 1)
			if reach > 0.0 and reach > before and reach > after:
				peaks += 1
				assert(step == 50 and is_equal_approx(reach, 20.0), "Maximum extension at sweep midpoint")
		assert(peaks == 1, "Exactly one stab per edge-to-edge sweep")
		assert(is_zero_approx(player._twin_stab_extension(start, 1)))
		assert(is_zero_approx(player._twin_stab_extension(start + PI, 1)))
	player.free()

func test_left_right_sequence_switches_at_both_edges_not_centres() -> void:
	var previous_scene: Node = get_tree().current_scene
	get_tree().current_scene = self
	var fixture: Node = Fixture.new()
	add_child(fixture)
	var player: Player = fixture.make_player()
	player.set_sword_form(Player.SwordStyle.WINDUP_THRUST)
	player.set_combat_hand_setting("frequency", 1.0)
	assert(player.twin_stab_cycle == 0, "Left blade starts")
	for stroke: int in range(8):
		var owner: int = stroke % 2
		var centre: float = PI if stroke % 2 == 0 else TAU
		player.sword_phase = centre - 0.001
		player._update_sword(0.016)
		assert(player.twin_stab_cycle == stroke, "Centre crossing must not split a stab")
		assert(player._twin_stab_extension(player.sword_phase, owner) > 19.0)
		assert(is_zero_approx(player._twin_stab_extension(player.sword_phase, 1 - owner)))
		var edge: float = PI * 1.5 if stroke % 2 == 0 else PI * 0.5
		player.sword_phase = edge - 0.001
		player._update_sword(0.016)
		assert(player.twin_stab_cycle == stroke + 1, "Swap at each outer edge")
		player._update_sword(0.016)
		assert(player.twin_stab_cycle == stroke + 1, "No duplicate swap")
	player.set_equipped_sword("Basic Longsword")
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.twin_stab_cycle == 0, "Re-equip starts left-first")
	player.free()
	fixture.free()
	get_tree().current_scene = previous_scene

func test_authored_blend_scales_coil_and_stab() -> void:
	var fixture: Node = Fixture.new()
	add_child(fixture)
	var player: Player = fixture.make_player()
	player.sword_style = Player.SwordStyle.WINDUP_THRUST
	player.aim_angle = 0.3
	player.set_combat_contact_setting("authored_metronome_enabled", 1.0)
	for blend: float in [0.0, 0.5, 1.0]:
		player.authored_metronome_swing_blend = blend
		for index: int in range(2):
			player.twin_stab_cycle = index
			for stroke: float in [0.40, 0.50]:
				player.sword_phase = PI * 0.5 + stroke * PI
				player.active_blade_index = index
				var pose: Dictionary = player._sword_intent_transform()
				var side: float = -1.0 if index == 0 else 1.0
				var rest: Vector2 = player.global_position + Vector2.from_angle(player.aim_angle) * player.combat_hand_radius + Vector2.from_angle(player.aim_angle).orthogonal() * side * 25.0
				var expected_reach: float = (-10.0 if stroke == 0.40 else 20.0) * blend
				assert(((pose["start"] as Vector2) - rest).is_equal_approx(Vector2.from_angle(float(pose["angle"])) * expected_reach))
	player.active_blade_index = -1
	player.free()
	fixture.free()
