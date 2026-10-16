extends Node
## Per-weapon normal-combat tuning profiles for the twin/double-ended test weapons.
## Never touches user:// saves (Player._ready / save paths are not exercised).
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const DUAL: String = ArmoryConfig.DUALBLADE_NAME
const DOUBLE: String = ArmoryConfig.DOUBLE_ENDED_NAME

func _bare_player() -> Player:
	var player: Player = Player.new()
	player.combat_contact_preset = 2
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	return player

func test_profile_ids_list_four_weapons() -> void:
	var ids: Array[String] = Player.combat_tuning_profile_ids()
	assert(ids == ["Basic Longsword", "Basic Curved Sword", DUAL, DOUBLE, ArmoryConfig.GREATSWORD_NAME], str(ids))

func test_seed_copies_longsword_once_and_never_overwrites() -> void:
	var player: Player = _bare_player()
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	player.set_combat_hand_setting_for_sword("Basic Curved Sword", "frequency", 1.5)
	player.ensure_experimental_form_initialized()
	assert(player.combat_weapon_hand_settings[DUAL] == player.combat_weapon_hand_settings["Basic Longsword"])
	assert(player.combat_weapon_hand_settings[DOUBLE] == player.combat_weapon_hand_settings["Basic Longsword"])
	player.set_combat_hand_setting_for_sword(DUAL, "frequency", 4.0)
	player.ensure_experimental_form_initialized()
	assert(player.get_combat_hand_setting_for_sword(DUAL, "frequency") == 4.0, "Seeding must never overwrite a present profile.")
	player.free()

func test_equip_resolves_own_profile_and_edits_are_isolated() -> void:
	var player: Player = _bare_player()
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	player.set_combat_hand_setting_for_sword("Basic Curved Sword", "frequency", 1.5)
	player.ensure_experimental_form_initialized()
	player.set_combat_hand_setting_for_sword(DUAL, "frequency", 2.0)
	player.set_combat_hand_setting_for_sword(DOUBLE, "frequency", 2.5)
	var expected: Dictionary = {"Basic Longsword": 3.25, "Basic Curved Sword": 1.5, DUAL: 2.0, DOUBLE: 2.5}
	for weapon: String in expected:
		player.equipped_sword_id = "Basic Longsword"
		player.dualblade_equipped = false
		player.double_ended_equipped = false
		player.combat_tuning_profile_id = weapon
		if weapon == DUAL or weapon == DOUBLE:
			player.dualblade_equipped = true
			player.double_ended_equipped = weapon == DOUBLE
		else:
			player.equipped_sword_id = weapon
		assert(player.active_combat_tuning_profile_id() == weapon)
		assert(player.get_combat_hand_setting("frequency") == expected[weapon], weapon)
	player.free()

func test_set_equipped_sword_sets_profile_id() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	for weapon: String in [DUAL, DOUBLE, "Basic Curved Sword", "Basic Longsword"]:
		player.set_equipped_sword(weapon)
		assert(player.active_combat_tuning_profile_id() == weapon, weapon)
	player.set_equipped_sword(DUAL)
	assert(player.equipped_sword_id == "Basic Longsword", "Twin geometry/texture stays Longsword.")
	player.free()

func test_missing_key_falls_back_to_longsword_and_round_trips() -> void:
	var player: Player = _bare_player()
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	player.set_combat_hand_setting_for_sword("Basic Longsword", "arc", 110.0)
	# Old save: dual profile exists but lacks "arc".
	player.combat_weapon_hand_settings[DUAL] = {"2:7": {"frequency": 2.0}}
	player.ensure_experimental_form_initialized()
	assert(player.get_combat_hand_setting_for_sword(DUAL, "arc") == 110.0)
	assert(player.get_combat_hand_setting_for_sword(DUAL, "frequency") == 2.0)
	var round_trip: Variant = JSON.parse_string(JSON.stringify({"weapon_hand_settings": player.combat_weapon_hand_settings}))
	var other: Player = _bare_player()
	other.combat_weapon_hand_settings = ((round_trip as Dictionary)["weapon_hand_settings"] as Dictionary).duplicate(true)
	other.ensure_experimental_form_initialized()
	for weapon: String in Player.combat_tuning_profile_ids():
		for key: String in ["frequency", "arc"]:
			assert(other.get_combat_hand_setting_for_sword(weapon, key) == player.get_combat_hand_setting_for_sword(weapon, key), weapon + key)
	player.free()
	other.free()

func test_longsword_and_curved_unchanged_by_seeding() -> void:
	var player: Player = _bare_player()
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	player.set_combat_hand_setting_for_sword("Basic Curved Sword", "frequency", 1.5)
	var long_before: Dictionary = (player.combat_weapon_hand_settings["Basic Longsword"] as Dictionary).duplicate(true)
	var curved_before: Dictionary = (player.combat_weapon_hand_settings["Basic Curved Sword"] as Dictionary).duplicate(true)
	player.ensure_experimental_form_initialized()
	player.set_combat_hand_setting_for_sword(DUAL, "frequency", 9.0)
	assert(player.combat_weapon_hand_settings["Basic Longsword"] == long_before)
	assert(player.combat_weapon_hand_settings["Basic Curved Sword"] == curved_before)
	player.free()

func test_menu_dropdown_lists_four_labels_and_resyncs() -> void:
	var fake_main: Node = Node.new()
	add_child(fake_main)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	fake_main.add_child(player)
	player.set_physics_process(false)
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	menu.main = fake_main
	fake_main.add_child(menu)
	var option: OptionButton = menu.combat_sword_option
	assert(option != null and option.item_count == 5, "Dropdown must list five weapons.")
	var labels: Array[String] = []
	for i: int in range(option.item_count):
		labels.append(option.get_item_text(i))
	assert(labels.has("Dual Wield") and labels.has("Double Sided Sword"), str(labels))
	for i: int in range(option.item_count):
		menu._combat_sword_selected(i)
		assert(player.active_combat_tuning_profile_id() == str(option.get_item_metadata(i)))
	player.set_equipped_sword(DOUBLE)
	menu.selected_combat_sword_id = player.active_combat_tuning_profile_id()
	menu._sync_combat_sword_selector()
	assert(str(option.get_item_metadata(option.selected)) == DOUBLE)
	fake_main.free()
