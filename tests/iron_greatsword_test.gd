extends Node
## Iron Greatsword (Test): identity, geometry, traced variable-width shape,
## damage property, tuning profile, shell chain, ordinary-weapon invariance.
## Never touches user:// saves.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const GS: String = ArmoryConfig.GREATSWORD_NAME

func _player(weapon: String = GS) -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.set_equipped_sword(weapon)
	player.blade_roll = 1.0
	return player

func test_item_identity_and_exclusions() -> void:
	var item: Dictionary = ArmoryConfig.greatsword_test_item()
	assert(item["base_name"] == "Iron Greatsword (Test)" and item["slot"] == "Sword" and item["origin"] == "approved_test" and item["value"] == 0)
	assert((item["techniques"] as Dictionary).is_empty() and (item["base_techniques"] as Dictionary).is_empty())
	assert(ArmoryConfig.slot_for_item_name(GS) == "Sword")
	for slot: String in ArmoryConfig.SLOT_ITEM_POOL: assert(not (ArmoryConfig.SLOT_ITEM_POOL[slot] as Array).has(GS))
	assert(not ArmoryConfig.smith_eligible(item))
	var home: HomeProgression = HomeProgression.new()
	home.add_gear_item(item)
	assert(home.equip_gear(ArmoryConfig.GREATSWORD_ID))
	home.unequip_gear("Sword")
	assert(home.shrine_salvage_gains(ArmoryConfig.GREATSWORD_ID).is_empty())

func test_length_ratio_and_equip_flags() -> void:
	var player: Player = _player()
	assert(player.greatsword_equipped and not player.dualblade_equipped and player.equipped_sword_id == "Basic Longsword")
	assert(absf(player._blade_length() / Player.BLADE_LENGTH - 1.2) <= 0.02, str(player._blade_length()))
	player.set_equipped_sword("Basic Longsword")
	assert(not player.greatsword_equipped and player._blade_length() == Player.BLADE_LENGTH)
	player.free()

func test_damage_multiplier_fixed_property() -> void:
	var player: Player = _player()
	assert(is_equal_approx(player.weapon_damage_multiplier(), 1.2))
	for other: String in ["Basic Longsword", "Basic Curved Sword", ArmoryConfig.DUALBLADE_NAME, ArmoryConfig.DOUBLE_ENDED_NAME]:
		player.set_equipped_sword(other)
		assert(player.weapon_damage_multiplier() == 1.0, other)
	player.free()
	var src: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(src.contains("sword_damage * total_damage_multiplier * weapon_damage_multiplier()"), "Must ride the canonical dealt-damage line.")

func test_profile_seed_and_isolation_and_dropdown() -> void:
	var player: Player = Player.new()
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	player.ensure_experimental_form_initialized()
	assert(player.combat_weapon_hand_settings[GS] == player.combat_weapon_hand_settings["Basic Longsword"])
	player.set_combat_hand_setting_for_sword(GS, "frequency", 1.75)
	player.ensure_experimental_form_initialized()
	assert(player.get_combat_hand_setting_for_sword(GS, "frequency") == 1.75)
	assert(player.get_combat_hand_setting_for_sword("Basic Longsword", "frequency") == 3.25)
	player.greatsword_equipped = true
	player.combat_tuning_profile_id = GS
	assert(player.active_combat_tuning_profile_id() == GS and player.get_combat_hand_setting("frequency") == 1.75)
	player.free()
	var fake_main: Node = Node.new()
	add_child(fake_main)
	var live: Player = PLAYER_SCENE.instantiate() as Player
	fake_main.add_child(live)
	live.set_physics_process(false)
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	menu.main = fake_main
	fake_main.add_child(menu)
	var found: int = -1
	for i: int in range(menu.combat_sword_option.item_count):
		if menu.combat_sword_option.get_item_text(i) == "Iron Greatsword": found = i
	assert(found >= 0)
	menu._combat_sword_selected(found)
	assert(live.greatsword_equipped and live.active_combat_tuning_profile_id() == GS)
	for key: String in menu.blade_shape_controls:
		assert(not (menu.blade_shape_controls[key]["slider"] as HSlider).editable)
	assert(menu.blade_shape_status.text.contains("traced"))
	fake_main.free()

func test_traced_samples_curvature_and_taper() -> void:
	var player: Player = _player()
	var samples: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
	assert(samples.size() == Player.GREATSWORD_TRACE.size() and samples.size() >= 6 and samples.size() <= 10)
	for i: int in range(1, samples.size()): assert(samples[i].x > samples[i - 1].x, "monotonic along length")
	assert(is_equal_approx(samples[-1].x, player._blade_length()) and samples[0] == Vector2.ZERO)
	assert(absf(samples[-1].y) > 3.0, "curved tip offset " + str(samples[-1]))
	var radii: PackedFloat32Array = player._blade_sample_radii()
	assert(radii.size() == samples.size())
	assert(radii[5] > radii[7] and radii[7] > radii[8] and radii[8] > radii[9], str(radii))
	player.blade_roll = -1.0
	var mirrored: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
	assert(is_equal_approx(mirrored[-1].y, -samples[-1].y), "blade_roll mirrors trace")
	player.free()

func test_variable_width_hit() -> void:
	var player: Player = _player()
	var samples: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
	var radii: PackedFloat32Array = player._blade_sample_radii()
	var probe_distance: float = radii[1] * 0.9 # inside near base (~6px)
	var base_point: Vector2 = samples[1] + Vector2(0, -probe_distance) * (1.0 if samples[1].y <= 0.0 else 1.0)
	assert(player._point_inside_blade(base_point, samples))
	# Same perpendicular distance off the tip segment (spine side away from curve).
	var tip_dir: Vector2 = (samples[9] - samples[8]).normalized()
	var tip_normal: Vector2 = tip_dir.rotated(PI * 0.5)
	var tip_mid: Vector2 = samples[8].lerp(samples[9], 0.8)
	var tip_point: Vector2 = tip_mid + tip_normal * probe_distance
	assert(player._distance_to_blade_polyline(tip_point, samples) <= probe_distance + 0.01)
	assert(not player._point_inside_blade(tip_point, samples), "tip narrower than base")
	player.free()

func test_shell_chain_matches_samples() -> void:
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var player: Player = _player()
	holder.add_child(player)
	player.set_physics_process(false)
	var shell: PhysicsShell = player._create_blade_shell()
	var radii: PackedFloat32Array = player._blade_sample_radii()
	assert(shell.get_child_count() == Player.GREATSWORD_TRACE.size() - 1)
	assert(shell.collision_layer == PhysicsShell.BLADE_SHELL_LAYER and shell.collision_mask == PhysicsShell.BONE_CORE_SHELL_LAYER)
	var local: PackedVector2Array = player._blade_polyline_samples(Vector2(-player._blade_length() * 0.5, 0), Vector2.RIGHT)
	for i: int in range(shell.get_child_count()):
		var node: CollisionShape2D = shell.get_child(i) as CollisionShape2D
		var cap: CapsuleShape2D = node.shape as CapsuleShape2D
		assert(is_equal_approx(cap.radius, (radii[i] + radii[i + 1]) * 0.5))
		assert(node.position.distance_to((local[i] + local[i + 1]) * 0.5) < 0.01)
		assert(absf(cap.height - (local[i].distance_to(local[i + 1]) + cap.radius * 2.0)) < 0.01)
	holder.free()

func test_ordinary_weapons_unchanged() -> void:
	var holder: Node2D = Node2D.new()
	add_child(holder)
	for weapon: String in ["Basic Longsword", "Basic Curved Sword", ArmoryConfig.DUALBLADE_NAME, ArmoryConfig.DOUBLE_ENDED_NAME]:
		var player: Player = _player(weapon)
		holder.add_child(player)
		player.set_physics_process(false)
		assert(not player.greatsword_equipped and player._blade_sample_radii().is_empty(), weapon)
		var samples: PackedVector2Array = player._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
		assert(samples.size() == 3, weapon)
		var expected_radius: float = Player.BLADE_RADIUS * (0.9 if player.dualblade_equipped else 1.0)
		assert(player._blade_radius() == expected_radius and player._blade_contact_radius_at(Vector2(30, 5), samples) == expected_radius)
		var shell: PhysicsShell = player._create_blade_shell()
		assert(shell.get_child_count() == 1)
		var cap: CapsuleShape2D = (shell.get_child(0) as CollisionShape2D).shape as CapsuleShape2D
		assert(is_equal_approx(cap.radius, expected_radius) and is_equal_approx(cap.height, maxf(player._blade_length(), expected_radius * 2.0 + 1.0)), "%s r=%s h=%s len=%s" % [weapon, cap.radius, cap.height, player._blade_length()])
		shell.free()
		player.free()
	var longsword: Player = _player("Basic Longsword")
	var long_samples: PackedVector2Array = longsword._blade_polyline_samples(Vector2.ZERO, Vector2.RIGHT)
	assert(long_samples.size() == 3 and long_samples[0] == Vector2.ZERO and long_samples[1].is_equal_approx(Vector2(84.0 * Player.BLADE_SHAPE_DEFAULT_MID_T, 0)) and long_samples[2].is_equal_approx(Vector2(84, 0)), str(long_samples))
	longsword.free()
	holder.free()
