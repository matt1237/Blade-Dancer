extends Node
## No Main or Player startup; no save/preset loaders or writers are invoked.
const Visual = preload("res://scripts/player_sword_visual.gd")

class DriveProbe extends Player:
	var drive_calls: int = 0
	var finish_calls: int = 0
	var response_calls: int = 0
	func _advance_sword_drive(delta: float, response_delta: float, previous_phase: float, contact_ceiling: float = INF) -> Dictionary:
		drive_calls += 1
		return super._advance_sword_drive(delta, response_delta, previous_phase, contact_ceiling)
	func _finish_sword_drive(previous_phase: float, sword_delta: float, frequency: float, pose: Dictionary) -> void:
		finish_calls += 1
		super._finish_sword_drive(previous_phase, sword_delta, frequency, pose)
	func _advance_collision_sword_pose() -> void:
		pass
	func _sword_transform() -> Dictionary:
		return {"start": Vector2(30, 0), "angle": 0.0, "arc_degrees": 45.0}
	func _resolve_sword_response(_delta: float, _pose: Dictionary) -> void:
		response_calls += 1
	func _begin_metronome_reversal_pulse(_angle: float) -> void:
		pass

func test_inventory_of_fields_exists_and_excludes_shared_authority() -> void:
	var player: Player = Player.new()
	var properties: Dictionary = {}
	for property: Dictionary in player.get_property_list():
		properties[StringName(property["name"])] = true
	var seen: Dictionary = {}
	for field: StringName in SwordBladeState.FIELDS:
		assert(properties.has(field), "Unknown blade-local field: " + field)
		assert(not seen.has(field), "Duplicate field: " + field)
		seen[field] = true
	for shared: StringName in [&"sword_phase", &"swing_time", &"aim_angle", &"swing_count", &"hit_ids", &"enemy_rehit_cooldowns", &"combat_hand_settings", &"combat_weapon_hand_settings", &"blade_profile_settings", &"authored_stroke_drive", &"velocity"]:
		assert(not seen.has(shared), "A response scope must not restore shared authority: " + shared)
	player.free()

func test_scoped_response_isolates_freeze_bind_slide_history_and_trails() -> void:
	var player: Player = Player.new()
	player.blade_freeze_left = 0.3
	player.experimental_bind_active = true
	player.bone_bind_target_id = 17
	player.previous_blade_samples = PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])
	player.blade_trail_points = [Vector2(5, 6)]
	var first: SwordBladeState = SwordBladeState.new()
	first.capture(player)
	player.blade_freeze_left = 0.0
	player.experimental_bind_active = false
	player.bone_bind_target_id = 0
	player.previous_blade_samples = PackedVector2Array()
	player.blade_trail_points.clear()
	var second: SwordBladeState = SwordBladeState.new()
	second.capture(player)
	first.with_applied(player, func() -> void:
		assert(is_equal_approx(player.blade_freeze_left, 0.3))
		assert(player.experimental_bind_active and player.bone_bind_target_id == 17)
		player.blade_freeze_left = 0.2
		player.preset_2_slide_distance_on_blade = 9.0
		player.blade_trail_points.append(Vector2(7, 8))
		player.hit_ids[123] = true
	)
	assert(player.blade_freeze_left == 0.0 and not player.experimental_bind_active)
	assert(player.blade_trail_points.is_empty() and player.previous_blade_samples.is_empty())
	assert(player.hit_ids.has(123), "Shared hit allowance must survive state restoration")
	assert((first.values[&"blade_trail_points"] as Array).size() == 2)
	assert((second.values[&"blade_trail_points"] as Array).is_empty())
	player.free()

func test_snapshot_containers_do_not_alias() -> void:
	var player: Player = Player.new()
	player.collision_sword_pose = {"nested": [1, 2]}
	player.blade_trail_points = [Vector2.ONE]
	var state: SwordBladeState = SwordBladeState.new()
	state.capture(player)
	(player.collision_sword_pose["nested"] as Array).append(3)
	player.blade_trail_points.append(Vector2.ZERO)
	state.apply(player)
	assert((player.collision_sword_pose["nested"] as Array).size() == 2)
	assert(player.blade_trail_points.size() == 1)
	player.blade_trail_points.clear()
	assert((state.values[&"blade_trail_points"] as Array).size() == 1)
	player.free()

func test_ordinary_update_advances_drive_and_response_once() -> void:
	for sword: String in ["Basic Longsword", "Basic Curved Sword"]:
		var player: DriveProbe = DriveProbe.new()
		player.equipped_sword_id = sword
		player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
		var before: float = player.sword_phase
		player._update_sword(1.0 / 60.0)
		assert(player.drive_calls == 1 and player.finish_calls == 1 and player.response_calls == 1)
		assert(player.sword_phase != before)
		player.free()

func test_one_reversal_clears_allowance_once() -> void:
	var player: DriveProbe = DriveProbe.new()
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player.sword_phase = PI * 0.5 - 0.00001
	player.hit_ids[123] = true
	player._update_sword(1.0 / 60.0)
	assert(player.swing_count == 1 and player.hit_ids.is_empty())
	assert(player.drive_calls == 1 and player.finish_calls == 1)
	player.free()

func test_stowing_consumes_response_without_advancing_drive() -> void:
	var player: DriveProbe = DriveProbe.new()
	player.sword_stowed = true
	player.blade_trail_points = [Vector2.ONE]
	player._update_sword(1.0 / 60.0)
	assert(player.drive_calls == 0 and player.finish_calls == 0 and player.response_calls == 0)
	assert(player.sword_phase == 0.0 and player.blade_trail_points.is_empty())
	player.free()

func test_freeze_preserves_ordinary_clock_and_updates_pose_history_only() -> void:
	var player: DriveProbe = DriveProbe.new()
	player.blade_freeze_left = 0.2
	player.sword_phase = 0.4
	player._update_sword(1.0 / 60.0)
	assert(player.drive_calls == 0 and player.response_calls == 0)
	assert(player.sword_phase == 0.4 and player.current_blade_samples.size() >= 2)
	player.free()

func test_ordinary_bone_stop_preserves_legacy_cadence_hold() -> void:
	var player: DriveProbe = DriveProbe.new()
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player.blade_bone_stop_left = 0.2
	player.sword_phase = 0.4
	player._update_sword(1.0 / 60.0)
	assert(player.drive_calls == 1 and player.response_calls == 1)
	assert(player.sword_phase == 0.4)
	assert(player.blade_bone_stop_left < 0.2)
	player.free()

func test_two_scoped_response_dispatches_do_not_advance_shared_clock() -> void:
	var player: DriveProbe = DriveProbe.new()
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	var first: SwordBladeState = SwordBladeState.new()
	var second: SwordBladeState = SwordBladeState.new()
	first.capture(player)
	second.capture(player)
	player._update_sword(1.0 / 60.0)
	var phase: float = player.sword_phase
	player.hit_ids[321] = true
	var pose: Dictionary = {"start": Vector2.ZERO, "angle": 0.0}
	player._resolve_scoped_sword_response(first, 1.0 / 60.0, pose)
	player._resolve_scoped_sword_response(second, 1.0 / 60.0, pose)
	assert(player.sword_phase == phase and player.drive_calls == 1 and player.finish_calls == 1)
	assert(player.hit_ids.has(321), "Response dispatch must not reset another blade's allowance")
	assert(player.response_calls == 3)
	player.free()

func test_multi_pose_renderer_returns_to_ordinary_and_empty_hides() -> void:
	var visual = Visual.new()
	var poses: Array[Visual.Pose] = [
		Visual.Pose.new(null, Vector2(0, -15), 0.0, Vector2(0.9, 0.5), Rect2(), 1.0),
		Visual.Pose.new(null, Vector2(0, 15), 0.0, Vector2(0.9, 0.5), Rect2(), 1.0),
	]
	visual.set_sword_poses(poses)
	assert(visual.sword_poses.size() == 2)
	poses[0].center = Vector2(999, 999)
	assert(visual.sword_poses[0].center == Vector2(0, -15))
	visual.set_sword_pose(null, Vector2.ZERO, 0.0, Vector2.ONE, Rect2(), 1.0)
	assert(visual.sword_poses.is_empty() and visual.sword_alpha == 1.0)
	var empty: Array[Visual.Pose] = []
	visual.set_sword_poses(empty)
	assert(visual.sword_poses.is_empty() and visual.sword_alpha == 0.0)
	visual.free()
