extends Node
## Double-Ended Iron Sword (Test). Save-disabled Probe, real geometry/contact code.
class Probe extends Player:
	var drive_calls: int = 0
	var response_calls: int = 0
	var damage_hits: int = 0
	var hilt_bashes: int = 0
	func _ready() -> void:
		pass
	func _load_saved_combat_settings() -> void:
		pass
	func _advance_sword_drive(delta: float, response_delta: float, previous_phase: float, contact_ceiling: float = INF) -> Dictionary:
		drive_calls += 1
		return super._advance_sword_drive(delta, response_delta, previous_phase, contact_ceiling)
	func _resolve_sword_response(delta: float, pose: Dictionary) -> void:
		response_calls += 1
		super._resolve_sword_response(delta, pose)
	func _trigger_successful_sword_hit(contact: SwordContactData) -> void:
		damage_hits += 1
		super._trigger_successful_sword_hit(contact)
	func _trigger_hilt_bash(enemy: Node, contact_point: Vector2) -> void:
		hilt_bashes += 1
		super._trigger_hilt_bash(enemy, contact_point)
	func _begin_metronome_reversal_pulse(_angle: float) -> void:
		pass

func make_player(weapon: String = ArmoryConfig.DOUBLE_ENDED_NAME) -> Probe:
	var player: Player = preload("res://scenes/player.tscn").instantiate()
	player.set_script(Probe)
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.set_equipped_sword(weapon)
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player.set_combat_contact_setting("charged_guard_enabled", 0.0)
	player.set_combat_contact_setting("collision_sword_enabled", 0.0)
	return player as Probe

func _end_pose(player: Probe, index: int) -> Dictionary:
	player.active_blade_index = index
	var pose: Dictionary = player._sword_intent_transform()
	player.active_blade_index = -1
	return pose

func test_item_identity_and_exclusions() -> void:
	var item: Dictionary = ArmoryConfig.double_ended_test_item()
	assert(item["base_name"] == "Double-Ended Iron Sword (Test)" and item["origin"] == "approved_test" and item["value"] == 0 and (item["techniques"] as Dictionary).is_empty())
	assert(ArmoryConfig.slot_for_item_name(item["base_name"]) == "Sword")
	assert(not ArmoryConfig.SLOT_ITEM_POOL["Sword"].has(item["base_name"]))
	assert(not ArmoryConfig.smith_eligible(item))
	var home: HomeProgression = HomeProgression.new()
	home.add_gear_item(item)
	assert(home.equip_gear(ArmoryConfig.DOUBLE_ENDED_ID))
	home.unequip_gear("Sword")
	assert(home.shrine_salvage_gains(ArmoryConfig.DOUBLE_ENDED_ID).is_empty())
	var player: Probe = make_player()
	assert(player.dualblade_equipped and player.double_ended_equipped and player.equipped_sword_id == "Basic Longsword")
	player.set_equipped_sword(ArmoryConfig.DUALBLADE_NAME)
	assert(player.dualblade_equipped and not player.double_ended_equipped)
	player.set_equipped_sword("Basic Longsword")
	assert(not player.dualblade_equipped and not player.double_ended_equipped)
	player.free()

func test_crosswise_geometry_at_several_aims() -> void:
	var player: Probe = make_player()
	for aim: float in [0.0, 0.7, PI * 0.5, 2.4, -1.9]:
		for phase: float in [0.0, 0.9, 2.5]:
			player.aim_angle = aim
			player.sword_phase = phase
			var a: Dictionary = _end_pose(player, 0)
			var b: Dictionary = _end_pose(player, 1)
			var hand: Vector2 = player._sword_intent_transform()["start"]
			var swung: float = float(player._sword_intent_transform()["angle"])
			assert((a["start"] as Vector2).is_equal_approx(hand) and (b["start"] as Vector2).is_equal_approx(hand), "Grip centre on hand")
			assert(is_equal_approx(absf(angle_difference(float(a["angle"]), float(b["angle"]))), PI), "Ends opposite, symmetric")
			assert(is_equal_approx(absf(angle_difference(swung, float(a["angle"]))), PI * 0.5), "Axis perpendicular to swung pose")
			if phase == 0.0:
				assert(is_zero_approx(Vector2.from_angle(aim).dot(Vector2.from_angle(float(a["angle"])))), "Axis perpendicular to aim at centre")
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	player.aim_angle = 0.4
	player._update_sword(0.016)
	get_tree().current_scene = old
	assert(player.drive_calls == 1 and player.response_calls == 2, "One shared drive, two end responses")
	for state: SwordBladeState in player.dual_blade_states:
		var points: PackedVector2Array = state.values[&"current_blade_samples"]
		assert(is_equal_approx(points[0].distance_to(points[-1]), Player.DOUBLE_ENDED_END_LENGTH))
	var p0: PackedVector2Array = player.dual_blade_states[0].values[&"current_blade_samples"]
	var p1: PackedVector2Array = player.dual_blade_states[1].values[&"current_blade_samples"]
	assert(p0[0].is_equal_approx(p1[0]), "Shared grip centre")
	assert(((p0[-1] + p1[-1]) * 0.5).is_equal_approx(p0[0]), "Tips symmetric about grip")
	player.free()

func test_ends_rotate_together_opposite_linear_motion() -> void:
	var player: Probe = make_player()
	player.aim_angle = 0.3
	for phase: float in [0.2, 1.2, 3.6, 5.0]:
		player.sword_phase = phase
		var a0: float = float(_end_pose(player, 0)["angle"])
		var b0: float = float(_end_pose(player, 1)["angle"])
		player.sword_phase = phase + 0.02
		var da: float = angle_difference(a0, float(_end_pose(player, 0)["angle"]))
		var db: float = angle_difference(b0, float(_end_pose(player, 1)["angle"]))
		assert(not is_zero_approx(da) and is_equal_approx(da, db), "Same rotation at %f" % phase)
		# Tip linear velocity: perpendicular to each end, so opposite directions.
		var va: Vector2 = Vector2.from_angle(a0).orthogonal() * da
		var vb: Vector2 = Vector2.from_angle(b0).orthogonal() * db
		assert(va.dot(vb) < 0.0, "Ends sweep in opposite linear directions")
	player.free()

func test_ordinary_and_twin_unchanged() -> void:
	for weapon: String in ["Basic Longsword", "Basic Curved Sword"]:
		var player: Probe = make_player(weapon)
		assert(player._blade_length() == Player.BLADE_LENGTH and player._blade_hilt_inset() == Player.BLADE_HILT_INSET and player._hilt_zone_fraction() == player.hilt_bash_blade_fraction)
		player.free()
	var twin: Probe = make_player(ArmoryConfig.DUALBLADE_NAME)
	assert(twin._blade_length() == Player.BLADE_LENGTH * 0.5 and twin._blade_hilt_inset() == Player.BLADE_HILT_INSET * 0.5 and twin._hilt_zone_fraction() == twin.hilt_bash_blade_fraction)
	twin.aim_angle = 0.3
	var a: Dictionary = _end_pose(twin, 0)
	var b: Dictionary = _end_pose(twin, 1)
	assert(is_equal_approx(angle_difference(float(a["angle"]), float(b["angle"])), deg_to_rad(-30.0)))
	assert(((b["start"] as Vector2) - (a["start"] as Vector2)).is_equal_approx(Vector2.from_angle(0.3).orthogonal() * 50.0))
	twin.free()

func _enemy(player: Probe, at: Vector2) -> Enemy:
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.health = 10000.0
	enemy.max_health = 10000.0
	enemy.moving_weapon_enabled = false
	enemy.shield_enabled = false
	enemy.position = at
	var shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 3.0
	return enemy

func _sweep_end(player: Probe, index: int) -> void:
	player.active_blade_index = index
	player.dual_blade_states[index].with_applied(player, func() -> void:
		player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016))
	player.active_blade_index = -1

func _ready_player() -> Probe:
	var player: Probe = make_player()
	player.enemy_body_contact_radius = 0.0
	player.sword_phase = 0.4
	player._update_sword(0.016)
	player._update_sword(0.016)
	return player

func test_zones_handle_and_blade_each_end() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	for index: int in range(2):
		for fraction: float in [0.25, 0.8]:
			var player: Probe = _ready_player()
			var points: PackedVector2Array = player.dual_blade_states[index].values[&"current_blade_samples"]
			var enemy: Enemy = _enemy(player, points[0].lerp(points[-1], fraction))
			var health: float = enemy.health
			player.hit_ids.clear()
			player.enemy_rehit_cooldowns.clear()
			_sweep_end(player, index)
			if fraction < player._hilt_zone_fraction():
				assert(player.hilt_bashes == 1 and player.damage_hits == 0, "End %d grip -> Hilt Bash" % index)
				assert(is_equal_approx(health - enemy.health, player.get_combat_contact_setting("hilt_bash_damage")) or player.get_combat_contact_setting("hilt_bash_enabled") < 0.5)
			else:
				assert(player.damage_hits == 1 and player.hilt_bashes == 0, "End %d blade -> blade hit" % index)
			enemy.free()
			player.free()
	get_tree().current_scene = old

func test_single_damage_per_window_both_ends() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	var player: Probe = _ready_player()
	var p0: PackedVector2Array = player.dual_blade_states[0].values[&"current_blade_samples"]
	var enemy: Enemy = _enemy(player, p0[0].lerp(p0[-1], 0.8))
	player.hit_ids.clear()
	player.enemy_rehit_cooldowns.clear()
	# Put end 1's swept tip on the same enemy too.
	for _i: int in range(2):
		player._dispatch_blade_operation(func() -> void:
			player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016))
	enemy.position = (player.dual_blade_states[1].values[&"current_blade_samples"] as PackedVector2Array)[-1]
	_sweep_end(player, 1)
	assert(player.damage_hits == 1, "Shared allowance: one damage instance")
	enemy.free()
	player.free()
	get_tree().current_scene = old

func test_independent_contact_on_one_end() -> void:
	var old: Node = get_tree().current_scene
	get_tree().current_scene = self
	for index: int in range(2):
		var player: Probe = make_player()
		player.set_combat_contact_setting("blade_freeze_duration", 0.2)
		player.set_combat_contact_setting("parry_contact_tolerance", 2.0)
		player.set_combat_contact_setting("slide_contact_tolerance", 2.0)
		player.set_combat_contact_setting("clash_contact_tolerance", 2.0)
		player._update_sword(0.016)
		var points: PackedVector2Array = player.dual_blade_states[index].values[&"current_blade_samples"]
		var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
		add_child(enemy)
		enemy.set_physics_process(false)
		enemy.player_ref = player
		enemy.moving_weapon_enabled = true
		enemy.weapon_origin_offset = 0.0
		enemy.blade_length = 8.0
		enemy.blade_angle = (points[-1] - points[0]).angle() + PI * 0.5
		enemy.position = points[0].lerp(points[-1], 0.8) - Vector2.from_angle(enemy.blade_angle) * 4.0
		var shape: CollisionShape2D = enemy.get_node("CollisionShape2D")
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 1.0
		player._dispatch_blade_operation(func() -> void:
			player.blade_velocity = Vector2.from_angle(enemy.blade_angle).orthogonal() * 600.0
			player._check_sword_hits(player.previous_blade_start, player.previous_blade_end, 0.016))
		assert(float(player.dual_blade_states[index].values[&"blade_freeze_left"]) > 0.0, "Contacting end reacts")
		assert(float(player.dual_blade_states[1 - index].values[&"blade_freeze_left"]) == 0.0, "Other end free")
		enemy.free()
		player.free()
	get_tree().current_scene = old

func test_art_atlas_untouched_and_measured() -> void:
	var player: Probe = make_player()
	var tex: AtlasTexture = player._double_ended_half_texture() as AtlasTexture
	assert(tex.atlas == Player.DOUBLE_ENDED_TEXTURE and tex.region.position.y == Player.DOUBLE_ENDED_ART_CENTER_Y)
	assert(is_equal_approx(Player.DOUBLE_ENDED_HANDLE_HALF, 320.0 * Player.DOUBLE_ENDED_ART_SCALE))
	assert(is_equal_approx(Player.DOUBLE_ENDED_END_LENGTH, 740.0 * Player.DOUBLE_ENDED_ART_SCALE))
	assert(Player.DOUBLE_ENDED_END_LENGTH - Player.DOUBLE_ENDED_HANDLE_HALF < Player.BLADE_LENGTH)
	player.free()
