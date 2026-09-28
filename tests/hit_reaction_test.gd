class_name HitReactionTest extends Node

func _contact(fraction: float, motion: Vector2, normal: Vector2 = Vector2.LEFT) -> SwordContactData:
	var contact: SwordContactData = SwordContactData.new()
	contact.blade_position = fraction
	contact.blade_direction = Vector2.RIGHT
	contact.blade_velocity = motion
	contact.impact_normal = normal
	return contact

func test_tuning_tab_starts_with_binary_switch_and_preserves_preset_copy() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu._build_hit_reaction_tab(tabs)
	var scroll: ScrollContainer = tabs.get_node("HIT REACTION") as ScrollContainer
	assert(scroll != null and menu.contact_controls.has("hit_reaction_enabled"))
	var switch: HSlider = (menu.contact_controls["hit_reaction_enabled"] as Dictionary)["slider"] as HSlider
	assert(switch.step == 1.0 and switch.min_value == 0.0 and switch.max_value == 1.0)
	var player: Player = Player.new()
	assert(player.get_combat_contact_setting("hit_reaction_enabled") == 0.0, "The shipped baseline must remain untouched until switched on.")
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("hit_tip_depth", 23.0)
	player.copy_preset_settings(2, 3)
	player.set_combat_contact_preset(3)
	assert(player.get_combat_contact_setting("hit_reaction_enabled") == 1.0 and player.get_combat_contact_setting("hit_tip_depth") == 23.0)
	player.free()
	menu.free()
	tabs.free()

func test_mid_slash_forte_and_tip_have_continuous_depth_and_resistance() -> void:
	var forte: Dictionary = HitReaction.analyze(_contact(0.1, Vector2(280, 480)), 0.1, {})
	var middle: Dictionary = HitReaction.analyze(_contact(0.5, Vector2(280, 480)), 0.5, {})
	var tip: Dictionary = HitReaction.analyze(_contact(0.9, Vector2(280, 480)), 0.9, {})
	assert(forte.max_depth < middle.max_depth and middle.max_depth < tip.max_depth)
	assert(tip.kind == "slash" and middle.kind == "slash")
	assert(HitReaction.resist(1.0, 12.0, 0.65, 1.8) < HitReaction.resist(9.0, 12.0, 0.65, 1.8))
	assert(HitReaction.resist(20.0, 12.0, 0.65, 1.8) > 9.0)
	assert(HitReaction.resist(-4.0, 12.0, 0.65, 1.8) == 0.0)

func test_forward_tip_stab_embeds_more_than_tip_slash_and_withdrawal_releases() -> void:
	var stab: Dictionary = HitReaction.analyze(_contact(0.95, Vector2(650, 0)), 0.95, {})
	var slash: Dictionary = HitReaction.analyze(_contact(0.95, Vector2(0, 650), Vector2.UP), 0.95, {})
	assert(stab.kind == "stab")
	assert(stab.max_depth > slash.max_depth + 10.0)
	var withdrawing: Dictionary = HitReaction.analyze(_contact(0.95, Vector2(-400, 0)), 0.95, {})
	assert(withdrawing.alignment == 0.0 and withdrawing.inward == 0.0)
	assert(HitReaction.resist(0.0, stab.max_depth, 0.65, 1.8) == 0.0)

func test_weak_graze_is_soft_and_impact_reflects_normal_velocity() -> void:
	var graze: Dictionary = HitReaction.analyze(_contact(0.5, Vector2(20, 90)), 0.5, {})
	var chop: Dictionary = HitReaction.analyze(_contact(0.5, Vector2(650, 0)), 0.5, {})
	assert(graze.kind == "graze")
	assert(chop.impact > graze.impact + 0.4)
	assert(graze.tangent.length() > graze.inward)

func test_enabled_contact_only_restricts_inward_pose_and_releases_on_pullback() -> void:
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	var enemy: Enemy = Enemy.new()
	var raw_samples: PackedVector2Array = player._blade_polyline_samples(-Vector2.RIGHT * Player.BLADE_HILT_INSET, Vector2.RIGHT)
	var origin: Vector2 = raw_samples[0]
	enemy.position = origin
	player.hit_reaction_contact = {"enemy": enemy, "origin": origin, "local_origin": Vector2.ZERO, "normal": Vector2.LEFT, "segment": 0, "factor": 0.0, "max_depth": 12.0, "elapsed": 0.0, "killed": false}
	var pose: Dictionary = {"start": Vector2(14, 6), "angle": 0.0}
	player._update_hit_reaction_pose(pose, 0.016)
	assert((pose["start"] as Vector2).x < 14.0, "Only inward movement should be resisted.")
	assert(is_equal_approx((pose["start"] as Vector2).y, 6.0), "Tangential authored movement must be kept.")
	var withdrawal: Dictionary = {"start": Vector2(-5, 0) + player.hit_reaction_offset, "angle": 0.0}
	player._update_hit_reaction_pose(withdrawal, 0.016)
	assert(player.hit_reaction_contact.is_empty() and player.hit_reaction_offset == Vector2.ZERO, "Pullback must immediately release without a magnetic hold.")
	assert((withdrawal["start"] as Vector2).is_equal_approx(Vector2(-5, 0)))
	player.free()
	enemy.free()

func test_lethal_hit_survives_target_being_freed_before_next_sword_frame() -> void:
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	var turkey: Enemy = Turkey.new()
	var raw_samples: PackedVector2Array = player._blade_polyline_samples(-Vector2.RIGHT * Player.BLADE_HILT_INSET, Vector2.RIGHT)
	var origin: Vector2 = raw_samples[0]
	player.hit_reaction_contact = {"enemy": turkey, "origin": origin, "local_origin": Vector2.ZERO, "normal": Vector2.LEFT, "segment": 0, "factor": 0.0, "max_depth": 12.0, "elapsed": 0.0, "killed": true}
	turkey.free()
	var pose: Dictionary = {"start": Vector2.RIGHT * 18.0, "angle": 0.0}
	player._update_hit_reaction_pose(pose, 0.016)
	assert(player.hit_reaction_offset.length() > 0.0, "The initial resisted impact survives the enemy's death.")
	player.free()

func test_lethal_contact_keeps_first_impact_then_breaks_through() -> void:
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	var enemy: Enemy = Enemy.new()
	var raw_samples: PackedVector2Array = player._blade_polyline_samples(-Vector2.RIGHT * Player.BLADE_HILT_INSET, Vector2.RIGHT)
	var origin: Vector2 = raw_samples[0]
	player.hit_reaction_contact = {"enemy": enemy, "origin": origin, "local_origin": Vector2.ZERO, "normal": Vector2.LEFT, "segment": 0, "factor": 0.0, "max_depth": 12.0, "elapsed": 0.0, "killed": true}
	var first: Dictionary = {"start": Vector2.RIGHT * 18.0, "angle": 0.0}
	player._update_hit_reaction_pose(first, 0.016)
	var first_correction: float = player.hit_reaction_offset.length()
	player.hit_reaction_contact["elapsed"] = 0.09
	var following: Dictionary = {"start": Vector2.RIGHT * 18.0 + player.hit_reaction_offset, "angle": 0.0}
	player._update_hit_reaction_pose(following, 0.016)
	assert(player.hit_reaction_offset.length() < first_correction, "Lethal breakthrough should follow the initial resisted impact.")
	player.free()
	enemy.free()

func test_shields_and_weapon_clashes_exit_before_flesh_reaction() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var shields: int = source.find("if enemy.has_method(\"is_shield_blocking\")")
	var weapons: int = source.find("if enemy.has_method(\"is_blade_blocking\")", shields)
	var flesh: int = source.find("var reaction: Dictionary = HitReaction.analyze", weapons)
	assert(shields >= 0 and weapons > shields and flesh > weapons, "Hard contacts must remain prior to the flesh-only analysis.")

func test_enemy_visual_recoil_does_not_move_gameplay_body() -> void:
	var enemy: Enemy = Enemy.new()
	var initial_position: Vector2 = enemy.position
	enemy.play_hit_reaction(Vector2.LEFT, 0.8, 10.0, 8.0, 0.06, 0.18)
	assert(enemy.position == initial_position and enemy.knockback == Vector2.ZERO)
	assert(enemy.hit_visual_distance > 0.0 and enemy.hit_visual_rotation != 0.0)
	enemy.free()

func test_kill_releases_resistance_without_changing_shield_contact_rules() -> void:
	var live: float = HitReaction.resist(22.0, 12.0, 0.65, 1.8)
	var killed: float = HitReaction.resist(22.0, 24.0, 0.65 * 0.12, 1.8)
	assert(killed < live * 0.3)
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	assert(player.get_combat_contact_setting("hit_reaction_enabled") == 0.0)
	assert(player.get_combat_contact_setting("hit_reaction_debug") == 0.0)
	player.free()
