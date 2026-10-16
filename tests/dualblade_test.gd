extends Node
## Save-disabled before tree entry; uses real geometry/contact implementation.
class Probe extends Player:
	var drive_calls: int = 0
	var finish_calls: int = 0
	var response_calls: int = 0
	var damage_hits: int = 0
	func _ready() -> void:
		pass
	func _load_saved_combat_settings() -> void:
		pass
	func _advance_sword_drive(delta: float, response_delta: float, previous_phase: float, contact_ceiling: float = INF) -> Dictionary:
		drive_calls += 1
		return super._advance_sword_drive(delta, response_delta, previous_phase, contact_ceiling)
	func _finish_sword_drive(previous_phase: float, sword_delta: float, frequency: float, pose: Dictionary) -> void:
		finish_calls += 1
		super._finish_sword_drive(previous_phase, sword_delta, frequency, pose)
	func _resolve_sword_response(delta: float, pose: Dictionary) -> void:
		response_calls += 1
		super._resolve_sword_response(delta, pose)
	func _trigger_successful_sword_hit(contact: SwordContactData) -> void:
		damage_hits += 1
		super._trigger_successful_sword_hit(contact)
	func _begin_metronome_reversal_pulse(_angle: float) -> void:
		pass

func make_player() -> Probe:
	var scene: PackedScene = preload("res://scenes/player.tscn")
	var player: Player = scene.instantiate()
	player.set_script(Probe)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	# Contact fixtures intentionally exercise Bind; production equip defaults to Thrust.
	player.sword_style = Player.SwordStyle.METRONOME_BIND_B
	player.sword_phase = 0.0
	player.twin_stab_cycle_started = false
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player.set_combat_contact_setting("charged_guard_enabled", 0.0)
	player.set_combat_contact_setting("collision_sword_enabled", 0.0)
	return player as Probe

func test_capability_profile_origin_and_armory_roundtrip() -> void:
	var home: HomeProgression = HomeProgression.new()
	var item: Dictionary = ArmoryConfig.dualblade_test_item()
	home.add_gear_item(item)
	assert(home.equip_gear(ArmoryConfig.DUALBLADE_ID))
	assert(home.equipped_gear_item("Sword")["base_name"] == ArmoryConfig.DUALBLADE_NAME)
	assert(not ArmoryConfig.SLOT_ITEM_POOL["Sword"].has(ArmoryConfig.DUALBLADE_NAME))
	assert(not ArmoryConfig.smith_eligible(item))
	home.unequip_gear("Sword")
	assert(home.shrine_salvage_gains(ArmoryConfig.DUALBLADE_ID).is_empty())
	var clean: Dictionary = home._sanitize_gear_item(item)
	assert(clean["id"] == ArmoryConfig.DUALBLADE_ID and clean["origin"] == "approved_test")
	var player: Player = Player.new()
	player.set_combat_hand_setting_for_sword("Basic Longsword", "frequency", 3.25)
	var before: Dictionary = player.combat_weapon_hand_settings.duplicate(true)
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.dualblade_equipped and player.equipped_sword_id == "Basic Longsword")
	assert(player.get_combat_hand_setting("frequency") == 3.25)
	assert(player.combat_weapon_hand_settings == before)
	player.set_equipped_sword("Basic Curved Sword")
	assert(not player.dualblade_equipped and player.dual_blade_states.is_empty())
	player.free()

func test_exact_geometry_shared_drive_and_one_blade_freeze() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Probe = make_player()
	player.aim_angle = 0.3
	player._update_sword(0.016)
	assert(player.drive_calls == 1 and player.finish_calls == 1 and player.response_calls == 2)
	var first: SwordBladeState = player.dual_blade_states[0]
	var second: SwordBladeState = player.dual_blade_states[1]
	var a: PackedVector2Array = first.values[&"current_blade_samples"]
	var b: PackedVector2Array = second.values[&"current_blade_samples"]
	assert(is_equal_approx(a[0].distance_to(a[-1]), 42.0))
	assert(is_equal_approx(b[0].distance_to(b[-1]), 42.0))
	# Bind has no Thrust extension; compare its two fanned grip anchors directly.
	var grip_a: Vector2 = first.values[&"dual_committed_pose"]["start"]
	var grip_b: Vector2 = second.values[&"dual_committed_pose"]["start"]
	assert(is_equal_approx((grip_b - grip_a).dot(Vector2.from_angle(0.3).orthogonal()), 50.0))
	assert(is_equal_approx(player._blade_radius(), Player.BLADE_RADIUS * 0.9))
	first.values[&"blade_freeze_left"] = 0.2
	first.values[&"frozen_blade_world_angle"] = float(first.values[&"dual_committed_pose"]["angle"])
	var frozen_angle: float = first.values[&"frozen_blade_world_angle"]
	var phase: float = player.sword_phase
	player._update_sword(0.016)
	assert(player.sword_phase != phase and player.drive_calls == 2 and player.finish_calls == 2)
	assert(is_equal_approx(first.values[&"dual_committed_pose"]["angle"], frozen_angle))
	assert(not is_equal_approx(second.values[&"dual_committed_pose"]["angle"], frozen_angle))
	assert(second.values[&"blade_freeze_left"] == 0.0)
	assert((second.values[&"blade_trail_points"] as Array).size() == 2)
	player.free()
	get_tree().current_scene = old

func test_actual_body_contacts_both_blades_and_shared_enemy_allowance() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Probe = make_player()
	# Synchronized blades: any mid-stroke phase works.
	player.sword_phase = 0.6
	player._update_sword(0.016)
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.health = 10000.0
	enemy.max_health = 10000.0
	enemy.moving_weapon_enabled = false
	enemy.shield_enabled = false
	# Both real blade-body overlap queries, not a shared invisible long blade.
	var shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
	for state: SwordBladeState in player.dual_blade_states:
		var points: PackedVector2Array = state.values[&"current_blade_samples"]
		enemy.position = points[0].lerp(points[-1], 0.75)
		assert(player._blade_overlaps_enemy_shape(points[0], points[-1], points[0], points[-1], shape, shape.shape)["overlap"])
	# Deliberately broad body intersects both cutting zones in one shared window.
	var points_a: PackedVector2Array = player.dual_blade_states[0].values[&"current_blade_samples"]
	var points_b: PackedVector2Array = player.dual_blade_states[1].values[&"current_blade_samples"]
	enemy.position = points_a[-1].lerp(points_b[-1], 0.5)
	player.hit_ids.clear()
	player.enemy_rehit_cooldowns.clear()
	player._dispatch_blade_operation(func() -> void:
		player.blade_velocity = Vector2(0, 600)
		player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016)
	)
	assert(player.damage_hits == 1, "Both blades share one enemy/window damage allowance")
	assert(player.hit_ids.has(enemy.get_instance_id()))
	enemy.free()
	player.free()
	get_tree().current_scene = old

func test_real_weapon_contact_reacts_only_on_the_contacting_blade() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	for blade_index: int in range(2):
		var player: Probe = make_player()
		player.set_combat_contact_setting("blade_freeze_duration", 0.2)
		player.set_combat_contact_setting("parry_contact_tolerance", 2.0)
		player.set_combat_contact_setting("slide_contact_tolerance", 2.0)
		player.set_combat_contact_setting("clash_contact_tolerance", 2.0)
		player._update_sword(0.016)
		var points: PackedVector2Array = player.dual_blade_states[blade_index].values[&"current_blade_samples"]
		var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
		add_child(enemy)
		enemy.set_physics_process(false)
		enemy.player_ref = player
		enemy.moving_weapon_enabled = true
		enemy.weapon_origin_offset = 0.0
		enemy.blade_length = 8.0
		enemy.blade_angle = (points[-1] - points[0]).angle() + PI * 0.5
		enemy.position = points[0].lerp(points[-1], 0.7) - Vector2.from_angle(enemy.blade_angle) * 4.0
		var shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 1.0
		player._dispatch_blade_operation(func() -> void:
			player.blade_velocity = Vector2.from_angle(enemy.blade_angle).orthogonal() * 600.0
			player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016)
		)
		assert(float(player.dual_blade_states[blade_index].values[&"blade_freeze_left"]) > 0.0, "Real opposing weapon must affect contacting state")
		assert(float(player.dual_blade_states[1-blade_index].values[&"blade_freeze_left"]) == 0.0, "The other blade must remain free")
		var phase: float = player.sword_phase
		player._update_sword(0.016)
		assert(player.sword_phase != phase)
		enemy.free()
		player.free()
	get_tree().current_scene = old

func test_shared_reversal_resets_once_for_two_responses() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Probe = make_player()
	player.sword_phase = PI * 0.5 - 0.00001
	player.hit_ids[123] = true
	player._update_sword(0.016)
	assert(player.swing_count == 1 and player.hit_ids.is_empty())
	assert(player.drive_calls == 1 and player.finish_calls == 1 and player.response_calls == 2)
	player.free()
	get_tree().current_scene = old

func _blade_offset(player: Probe, index: int) -> float:
	player.active_blade_index = index
	var pose: Dictionary = player._sword_intent_transform()
	player.active_blade_index = -1
	return angle_difference(player.aim_angle, float(pose["angle"]) + deg_to_rad(15.0) * (-1.0 if index == 0 else 1.0))

func test_synchronized_blades_share_offset_at_sampled_phases() -> void:
	var player: Probe = make_player()
	for phase: float in [0.0, 0.3, 1.0, PI * 0.5, 2.2, 4.0, 5.5, TAU]:
		player.sword_phase = phase
		var left: float = _blade_offset(player, 0)
		var right: float = _blade_offset(player, 1)
		assert(is_equal_approx(left, right), "Blades share offset at %f (%f vs %f)" % [phase, left, right])
		player.active_blade_index = 0
		var la: float = float(player._sword_intent_transform()["angle"])
		player.active_blade_index = 1
		var ra: float = float(player._sword_intent_transform()["angle"])
		player.active_blade_index = -1
		assert(is_equal_approx(angle_difference(la, ra), deg_to_rad(-30.0)), "Outward fan at %f" % phase)
	player.free()

func test_synchronized_windup_stabs_follow_each_blade() -> void:
	var player: Probe = make_player()
	player.sword_style = Player.SwordStyle.WINDUP_THRUST
	player.aim_angle = 0.3
	var forward: Vector2 = Vector2.from_angle(player.aim_angle)
	# One peak per edge-to-edge sweep, on the active blade only.
	for step: int in range(9):
		var phase: float = float(step) * PI * 0.25
		player.sword_phase = phase
		player.active_blade_index = -1
		var base: Vector2 = player._sword_intent_transform()["start"]
		for index: int in range(2):
			player.active_blade_index = index
			var pose: Dictionary = player._sword_intent_transform()
			var displacement: Vector2 = (pose["start"] as Vector2) - base
			var side: float = -1.0 if index == 0 else 1.0
			var thrust: Vector2 = displacement - forward.orthogonal() * side * 25.0
			var expected_reach: float = player._twin_stab_extension(phase, index)
			assert(thrust.is_equal_approx(Vector2.from_angle(float(pose["angle"])) * expected_reach), "Own-tip stab at phase %f blade %d" % [phase, index])
	# Return to normal grip after the release.
	player.sword_phase = PI * 0.5 + 0.80 * PI
	player.active_blade_index = -1
	var base: Vector2 = player._sword_intent_transform()["start"]
	player.active_blade_index = 0
	var shoulder: Dictionary = player._sword_intent_transform()
	var shoulder_reach: Vector2 = (shoulder["start"] as Vector2) - base + forward.orthogonal() * 25.0
	assert(shoulder_reach.is_zero_approx(), "Return to normal grip after the stab")
	player.active_blade_index = -1
	player.free()

func test_synchronized_blades_same_travel_direction() -> void:
	var player: Probe = make_player()
	for phase: float in [0.2, 1.2, 2.5, 3.6, 5.0]:
		player.sword_phase = phase
		var l0: float = _blade_offset(player, 0)
		var r0: float = _blade_offset(player, 1)
		player.sword_phase = phase + 0.02
		var dl: float = _blade_offset(player, 0) - l0
		var dr: float = _blade_offset(player, 1) - r0
		if Player.TWIN_STABS_ONLY:
			assert(is_zero_approx(dl) and is_zero_approx(dr), "No metronome sweep during stab-only trial")
			assert(is_zero_approx(l0) and is_zero_approx(r0), "Both blades retain aim plus their fixed fan")
		else:
			assert(signf(dl) == signf(dr) and signf(dl) == signf(cos(phase)), "Same direction at %f" % phase)
	player.sword_phase = 0.3
	assert(not is_equal_approx(_blade_offset(player, 1), -_blade_offset(player, 0)) or is_zero_approx(_blade_offset(player, 0)), "Not mirrored")
	player.free()

func _hit_rig(blade_index: int) -> Array:
	var player: Probe = make_player()
	player.sword_phase = 0.4
	player._update_sword(0.016)
	player._update_sword(0.016)
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.health = 10000.0
	enemy.max_health = 10000.0
	enemy.moving_weapon_enabled = false
	enemy.shield_enabled = false
	var points: PackedVector2Array = player.dual_blade_states[blade_index].values[&"current_blade_samples"]
	var other: PackedVector2Array = player.dual_blade_states[1 - blade_index].values[&"current_blade_samples"]
	enemy.position = points[0].lerp(points[-1], 0.8) + (points[-1] - other[-1]).normalized() * 6.0
	player.hit_ids.clear()
	player.enemy_rehit_cooldowns.clear()
	return [player, enemy]

func test_synchronized_each_blade_sweep_registers_hit() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	for blade_index: int in range(2):
		var rig: Array = _hit_rig(blade_index)
		var player: Probe = rig[0]
		# Only THIS blade's scoped response sweeps, using its own scoped geometry.
		player.active_blade_index = blade_index
		player.dual_blade_states[blade_index].with_applied(player, func() -> void:
			player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016)
		)
		player.active_blade_index = -1
		assert(player.damage_hits == 1, "Blade %d sweep registers its hit" % blade_index)
		rig[1].free()
		player.free()
	get_tree().current_scene = old

func test_synchronized_no_double_damage_within_window() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	var rig: Array = _hit_rig(0)
	var player: Probe = rig[0]
	for _i: int in range(2):
		player._dispatch_blade_operation(func() -> void:
			player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016)
		)
	assert(player.damage_hits == 1, "Both blades/frames share one hit")
	# A shared reversal mid-window (right blade still mid-stroke) must not
	# re-open damage: the per-enemy rehit window still holds.
	player.hit_ids.clear()
	player._dispatch_blade_operation(func() -> void:
		player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016)
	)
	assert(player.damage_hits == 1, "Rehit window blocks the second blade across the shared reset")
	rig[1].free()
	player.free()
	get_tree().current_scene = old

func test_ordinary_weapons_unaffected_by_twin_sync() -> void:
	for weapon: String in ["Longsword", "Curved Sword"]:
		var player: Probe = make_player()
		player.set_equipped_sword(weapon)
		assert(not player.dualblade_equipped)
		for phase: float in [0.0, 1.0, 2.7, 4.4]:
			player.sword_phase = phase
			var base: Dictionary = player._sword_intent_transform()
			player.active_blade_index = 1 # must be ignored outside dual
			assert(float(player._sword_intent_transform()["angle"]) == float(base["angle"]))
			player.active_blade_index = -1
			assert(player._form_phase() == phase)
		player.free()

func test_inventory_only_canonical_transaction_preserves_full_payload_and_failure() -> void:
	var path: String = "res://.godot/dualblade_transaction_test.json"
	var backup: String = "res://.godot/dualblade_transaction_test.backup.json"
	var payload: Dictionary = {"unknown_future_key": [1, {"v": true}], "settings": {"preset": 2}, "home_progression": {"gear_inventory": [{"id": "old"}], "equipped_gear_ids": {"Sword": "old"}, "kaji_updated_at_unix": 12345.5}, "save_metadata": {"last_saved_at_unix": 678.9}}
	assert(Main._write_save_payload_atomic(path, payload))
	var text: String = FileAccess.get_file_as_string(path)
	var inventory: Array = payload["home_progression"]["gear_inventory"].duplicate(true)
	inventory.append(ArmoryConfig.dualblade_test_item())
	assert(not Main._write_inventory_snapshot_transaction(path, "stale snapshot", inventory, backup))
	assert(FileAccess.get_file_as_string(path) == text)
	assert(Main._write_inventory_snapshot_transaction(path, text, inventory, backup))
	assert(FileAccess.get_file_as_string(backup) == text)
	var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(result["home_progression"]["gear_inventory"] == JSON.parse_string(JSON.stringify(inventory)))
	result["home_progression"]["gear_inventory"] = payload["home_progression"]["gear_inventory"]
	assert(result == JSON.parse_string(JSON.stringify(payload)), "Only gear inventory may differ; unknown keys/clocks/equipped/metadata survive")
