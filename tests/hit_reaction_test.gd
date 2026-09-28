class_name HitReactionTest extends Node

func test_hit_reaction_tab_has_fifteen_controls_and_existing_per_preset_persistence() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu._build_hit_reaction_tab(tabs)
	assert(tabs.get_node("HIT REACTION") is ScrollContainer)
	assert(menu.contact_controls.size() == HitReaction.DEFAULTS.size())
	for key: String in HitReaction.DEFAULTS.keys():
		assert(menu.contact_controls.has(key), "Every canonical Hit Reaction setting must have one visible control: %s" % key)
		var row: Dictionary = menu.contact_controls[key]
		var control: HSlider = row["slider"] as HSlider
		if key == "blade_bone_core_size_percent":
			assert(control.min_value == 10.0 and control.max_value == 100.0 and control.step == 5.0)
		elif key == "blood_amount_percent" or key == "blood_drop_size_percent":
			assert(control.min_value == 0.0 and control.max_value == 300.0 and control.step == 5.0)
		elif key == "blood_chance_percent" or key == "split_kill_chance_percent":
			assert(control.min_value == 0.0 and control.max_value == 100.0 and control.step == 5.0)
		assert(control.tooltip_text.contains("← LEFT") and control.tooltip_text.contains("→ RIGHT") and control.tooltip_text.contains("TIP:"), "Every Hit Reaction control needs complete feel guidance: %s" % key)
	var switch: HSlider = (menu.contact_controls["hit_reaction_enabled"] as Dictionary)["slider"] as HSlider
	assert(switch.step == 1.0 and switch.min_value == 0.0 and switch.max_value == 1.0)
	var player: Player = Player.new()
	for key: String in HitReaction.DEFAULTS.keys():
		assert(player.get_combat_contact_setting(key) == float(HitReaction.DEFAULTS[key]))
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("hit_visual_recoil", 12.0)
	player.set_combat_contact_setting("hit_visual_rotation", 14.0)
	player.set_combat_contact_setting("blade_physical_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_physical_reaction_strength", 85.0)
	player.set_combat_contact_setting("blade_sink_enabled", 1.0)
	player.set_combat_contact_setting("blade_sink_strength", 70.0)
	player.set_combat_contact_setting("sword_knockback_away_enabled", 1.0)
	player.set_combat_contact_setting("hd_hit_squash_strength", 250.0)
	player.set_combat_contact_setting("blade_bone_debug_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_core_size_percent", 70.0)
	player.set_combat_contact_setting("blood_amount_percent", 150.0)
	player.set_combat_contact_setting("blood_drop_size_percent", 120.0)
	player.set_combat_contact_setting("blood_chance_percent", 45.0)
	player.set_combat_contact_setting("split_kill_chance_percent", 70.0)
	player.set_combat_contact_setting("flesh_contact_drag", 99.0)
	player.set_combat_contact_setting("flesh_contact_drag_recovery", 96.0)
	player.set_combat_contact_setting("hilt_contact_drag", 98.0)
	player.set_combat_contact_setting("hilt_contact_drag_recovery", 95.0)
	player.set_combat_contact_setting("farmable_contact_drag", 97.0)
	player.set_combat_contact_setting("farmable_contact_drag_recovery", 94.0)
	player.copy_preset_settings(2, 3)
	player.set_combat_contact_preset(3)
	assert(player.get_combat_contact_setting("hit_reaction_enabled") == 1.0)
	assert(player.get_combat_contact_setting("hit_visual_recoil") == 12.0 and player.get_combat_contact_setting("hit_visual_rotation") == 14.0)
	assert(player.get_combat_contact_setting("blade_physical_reaction_enabled") == 1.0)
	assert(player.get_combat_contact_setting("blade_physical_reaction_strength") == 85.0)
	assert(player.get_combat_contact_setting("blade_sink_enabled") == 1.0)
	assert(player.get_combat_contact_setting("blade_sink_strength") == 70.0)
	assert(player.get_combat_contact_setting("sword_knockback_away_enabled") == 1.0)
	assert(player.get_combat_contact_setting("hd_hit_squash_strength") == 250.0)
	assert(player.get_combat_contact_setting("blade_bone_debug_enabled") == 1.0)
	assert(player.get_combat_contact_setting("blade_bone_core_size_percent") == 70.0)
	assert(player.get_combat_contact_setting("blood_amount_percent") == 150.0)
	assert(player.get_combat_contact_setting("blood_drop_size_percent") == 120.0)
	assert(player.get_combat_contact_setting("blood_chance_percent") == 45.0)
	assert(player.get_combat_contact_setting("split_kill_chance_percent") == 70.0)
	var preset_three: Dictionary = player.combat_contact_settings["3"] as Dictionary
	assert(not preset_three.has("flesh_contact_drag") and not preset_three.has("hilt_contact_drag") and not preset_three.has("farmable_contact_drag"), "Removed drag fields must not be copied as active preset controls.")
	assert(HitReaction.DEFAULTS.size() == 15)
	player.free()
	menu.free()
	tabs.free()

func test_inner_bone_boundary_allows_deep_cut_and_broadside_or_stab_yield_is_smooth() -> void:
	assert(is_equal_approx(HitReaction.blade_inner_bone_radius(20.0), 10.0), "The default core is 50% of outer radius, leaving a deep flesh cut.")
	assert(is_equal_approx(HitReaction.blade_inner_bone_radius(20.0, 25.0), 5.0))
	assert(is_equal_approx(HitReaction.blade_inner_bone_radius(20.0, 100.0), 20.0))
	assert(is_equal_approx(HitReaction.blade_inner_bone_radius(20.0, -10.0), 0.0))
	assert(HitReaction.DEFAULTS["hd_hit_squash_strength"] == 200.0)
	var circle_shape: CircleShape2D = CircleShape2D.new()
	circle_shape.radius = 20.0
	var inner_circle: CircleShape2D = HitReaction.scale_inner_bone_shape(circle_shape) as CircleShape2D
	assert(is_equal_approx(inner_circle.radius, 10.0))
	var quarter_core: CircleShape2D = HitReaction.scale_inner_bone_shape(circle_shape, 0.25) as CircleShape2D
	assert(is_equal_approx(quarter_core.radius, 5.0))
	var rectangle_shape: RectangleShape2D = RectangleShape2D.new()
	rectangle_shape.size = Vector2(40.0, 20.0)
	var inner_rectangle: RectangleShape2D = HitReaction.scale_inner_bone_shape(rectangle_shape) as RectangleShape2D
	assert(inner_rectangle.size.is_equal_approx(Vector2(20.0, 10.0)))
	assert(is_equal_approx(HitReaction.blade_inner_bone_radius(-3.0), 0.0))
	var normal: Vector2 = Vector2.DOWN
	var tangent_cut: float = HitReaction.blade_bone_reaction_angle(Vector2.RIGHT * 500.0, Vector2.ZERO, normal, Vector2.RIGHT, 100.0, false)
	var broadside_cut: float = HitReaction.blade_bone_reaction_angle(Vector2.RIGHT * 500.0, Vector2.ZERO, normal, Vector2.UP, 100.0, false)
	var stab_recoil: float = HitReaction.blade_bone_reaction_angle(Vector2.UP * 500.0, Vector2.ZERO, normal, Vector2.UP, 100.0, true)
	var direct_body_hit: float = HitReaction.blade_bone_reaction_angle(Vector2.DOWN * 500.0, Vector2.ZERO, Vector2.UP, Vector2.RIGHT, 80.0, false)
	assert(absf(tangent_cut) > 0.05, "A cut at the core should be guided along its boundary.")
	assert(absf(broadside_cut) > absf(tangent_cut), "A broadside cut near perpendicular to the blade axis should recoil more to avoid sticking.")
	assert(absf(stab_recoil) > 0.05, "A stab should rebound smoothly from the inner core.")
	assert(absf(rad_to_deg(direct_body_hit)) >= 38.0 and absf(rad_to_deg(direct_body_hit)) <= 50.0, "A strong inward broadside cut should clearly deflect the blade without exceeding the tuned contact cap.")
	assert(not HitReaction.blade_physical_reaction_allowed(false, -0.4), "A blade already leaving the target should not be redirected.")
	var approaching: float = HitReaction.advance_blade_physical_reaction(0.0, broadside_cut, 0.016)
	var releasing: float = HitReaction.advance_blade_physical_reaction(approaching, 0.0, 0.016)
	assert(absf(approaching) > 0.0 and absf(approaching) < absf(broadside_cut), "Core response eases in rather than snapping.")
	assert(absf(releasing) < absf(approaching), "Once contact ends, response eases back to the authored path.")

func test_blade_sink_uses_full_ninety_percent_range_only_during_master_enabled_overlap() -> void:
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 100.0), 0.1))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 50.0), 0.55))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 0.0), 1.0), "Zero strength must never slow the swing.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(false, true, true, 100.0), 1.0), "The master switch overrides sink.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, false, true, 100.0), 1.0))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, false, 100.0), 1.0), "No contact tail may slow a free swing.")

func test_sword_knockback_direction_toggle_is_independent_and_only_reverses_when_enabled() -> void:
	var normal_direction: Vector2 = Vector2.UP
	var player_position: Vector2 = Vector2.ZERO
	var target_position: Vector2 = Vector2.RIGHT * 100.0
	assert(HitReaction.sword_knockback_direction(normal_direction, player_position, target_position, false) == normal_direction)
	assert(HitReaction.sword_knockback_direction(normal_direction, player_position, target_position, true) == Vector2.RIGHT)

func test_core_yield_slows_the_swing_without_rotating_or_translating_the_blade() -> void:
	var player: Player = Player.new()
	var authored_start: Vector2 = Vector2(30.0, 20.0)
	var pose: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0, "arc_degrees": 60.0})
	assert((pose["start"] as Vector2) == authored_start, "The core yield may never translate the authored hand/hilt anchor.")
	assert(is_equal_approx(float(pose["angle"]), 0.0), "The core yield slows the swing rate; it must never rotate the blade.")
	var target: float = HitReaction.blade_core_yield_target(100.0, true, 1.0)
	assert(is_equal_approx(target, 0.75), "Full strength at full inward drive cuts the live swing to the gentle bound-sword-style floor.")
	assert(is_equal_approx(HitReaction.blade_core_yield_target(100.0, false, 1.0), 1.0), "No inward core contact means no yield.")
	assert(is_equal_approx(HitReaction.blade_core_yield_target(80.0, true, 0.0), 1.0), "Zero inward alignment means no yield.")
	assert(HitReaction.blade_core_yield_target(60.0, true, 0.5) > target, "A weaker or shallower drive yields less.")
	var eased_in: float = HitReaction.advance_blade_core_yield(1.0, target, 0.016)
	assert(eased_in < 1.0 and eased_in > target, "The yield eases in rather than snapping to full resistance.")
	var released: float = HitReaction.advance_blade_core_yield(eased_in, 1.0, 0.016)
	assert(released > eased_in and released < 1.0, "After separation the swing rate eases back rather than snapping to full speed.")
	player.free()

func test_blade_sink_bite_eases_in_and_smoothly_releases() -> void:
	var bit: float = HitReaction.advance_blade_sink(1.0, 0.1, 0.016)
	assert(bit < 1.0 and bit > 0.1, "The bite ramps in rather than snapping straight to full slowdown.")
	var released: float = HitReaction.advance_blade_sink(bit, 1.0, 0.016)
	assert(released > bit, "Release eases back toward full speed.")
	assert(released < 1.0, "One frame of release cannot snap the swing rate fully back, so the un-bite is smoothed.")
	assert(is_equal_approx(HitReaction.advance_blade_sink(1.0, 1.0, 0.016), 1.0), "A free swing stays at full rate.")

func test_narrow_blood_follows_blade_motion_only_when_enabled() -> void:
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	fx.blood_drop_count = 60
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true)
	assert(fx.blood_drops.size() > 0)
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		assert(drop.velocity.x > 0.0)
		assert(absf(drop.velocity.angle()) <= deg_to_rad(fx.blood_spread_degrees * 0.4 + 0.01))
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.DOWN * 500.0, 1.0, true)
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		assert(absf(wrapf(drop.velocity.angle() - Vector2.DOWN.angle(), -PI, PI)) <= deg_to_rad(fx.blood_spread_degrees * 0.4 + 0.01))
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, false)
	var broad: bool = false
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		broad = broad or absf(drop.velocity.angle()) > deg_to_rad(fx.blood_spread_degrees * 0.5)
	assert(broad, "The OFF state retains the original broad blood fan.")
	fx.free()

func test_blood_amount_and_droplet_size_settings_scale_the_spray() -> void:
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	fx.blood_drop_count = 20
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 0.5, 1.0)
	var half_count: int = fx.blood_drops.size()
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 2.0, 1.0)
	var double_count: int = fx.blood_drops.size()
	assert(half_count > 0 and double_count > half_count, "Blood Amount must scale the droplet count.")
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 0.0, 1.0)
	assert(fx.blood_drops.is_empty(), "0% Blood Amount disables the spray entirely.")
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 1.0, 3.0)
	var largest_big: float = 0.0
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		largest_big = maxf(largest_big, drop.radius)
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 1.0, 1.0)
	var largest_base: float = 0.0
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		largest_base = maxf(largest_base, drop.radius)
	assert(largest_big > largest_base, "Blood Droplet Size must scale the droplet radius.")
	fx.free()

func test_contact_chance_lerps_from_the_gate_up_to_the_slider_ceiling() -> void:
	# At or below the hidden quality gate the roll is zero, so a merely qualifying
	# hit never fires; it climbs smoothly to the slider ceiling only at perfect
	# contact, which is exactly what stops a fixed threshold from always firing.
	assert(is_equal_approx(HitReaction.contact_chance(100.0, 0.5, 0.5), 0.0))
	assert(is_equal_approx(HitReaction.contact_chance(100.0, 0.5, 1.0), 1.0))
	assert(is_equal_approx(HitReaction.contact_chance(80.0, 0.5, 0.75), 0.4))
	assert(is_equal_approx(HitReaction.contact_chance(50.0, 0.0, 1.0), 0.5))
	assert(is_equal_approx(HitReaction.contact_chance(100.0, 0.88, 0.88), 0.0))
	assert(is_equal_approx(HitReaction.contact_chance(100.0, 0.88, 0.94), 0.5), "Halfway between the split gate and 1.0 is a 50% ceiling allowance.")
	assert(is_equal_approx(HitReaction.contact_chance(0.0, 0.0, 1.0), 0.0), "A 0% ceiling never fires.")
	assert(HitReaction.contact_chance(100.0, 0.4, 0.6) < HitReaction.contact_chance(100.0, 0.4, 0.9), "Higher quality means a higher chance.")

func test_zero_chance_disables_blood_while_full_chance_fires() -> void:
	# Behavioral check on the FX gate: a 0% ceiling suppresses the spray entirely,
	# and a 100% ceiling at perfect quality lets a qualifying hit through.
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	var player: Player = Player.new()
	player.visual_style = "hd"
	player.set_combat_contact_setting("blood_chance_percent", 0.0)
	player.set_combat_contact_setting("split_kill_chance_percent", 0.0)
	var enemy: Enemy = Turkey.new()
	enemy.player_ref = player
	fx.blood_min_quality = 0.0
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT * 500.0, Vector2.RIGHT, 1.0, true, true, true)
	assert(fx.blood_drops.is_empty(), "A 0% Blood Chance never sprays, even on a perfect kill.")
	fx.blood_drops.clear()
	player.set_combat_contact_setting("blood_chance_percent", 100.0)
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT * 500.0, Vector2.RIGHT, 1.0, true, true, true)
	assert(not fx.blood_drops.is_empty(), "A 100% Blood Chance sprays on a perfect hit.")
	enemy.free()
	player.free()
	fx.free()

func test_removed_pose_and_drag_authorities_are_not_called() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(not source.contains("_update_hit_reaction_pose") and not source.contains("hit_reaction_offset"))
	assert(not source.contains("_trigger_contact_drag") and not source.contains("contact_drag_multiplier"))
	assert(not source.contains("blade_physical_reaction_angle"), "The rotated blade reaction was replaced by a gentle swing-rate yield.")
	assert(not source.contains("hit_knockback_scale") and not source.contains("hit_hitstop_scale"))
	assert(not source.contains("HitReaction.analyze") and not source.contains("HitReaction.resist"))
	for retired_setting: String in ["flesh_contact_drag", "hilt_contact_drag", "farmable_contact_drag", "kill_blood_splatter_chance"]:
		assert(not menu_source.contains(retired_setting), "The retired setting must not have a visible control.")

func test_hard_contacts_exit_before_cosmetic_flesh_reaction() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var shields: int = source.find("if enemy.has_method(\"is_shield_blocking\")")
	var weapons: int = source.find("if enemy.has_method(\"is_blade_blocking\")", shields)
	var flesh: int = source.find("combat_enemy.play_hit_reaction", weapons)
	assert(shields >= 0 and weapons > shields and flesh > weapons)

func test_enemy_recoil_and_lean_follow_incoming_angle_without_gameplay_movement() -> void:
	var enemy: Enemy = Enemy.new()
	enemy.play_hit_reaction(Vector2.RIGHT * 500.0, Vector2(0.0, -20.0), 1.0, 10.0, 8.0)
	assert(enemy.hit_visual_direction == Vector2.RIGHT and enemy.hit_visual_distance == 10.0)
	assert(enemy.hit_visual_rotation > 0.0 and enemy.position == Vector2.ZERO and enemy.knockback == Vector2.ZERO)
	enemy.play_hit_reaction(Vector2.LEFT * 500.0, Vector2(0.0, -20.0), 1.0, 10.0, 8.0)
	assert(enemy.hit_visual_direction == Vector2.LEFT and enemy.hit_visual_rotation < 0.0)
	enemy.free()

func test_hd_hit_axis_squish_resets_cleanly_after_the_hit() -> void:
	var enemy: Enemy = Turkey.new()
	var player: Player = Player.new()
	player.visual_style = "hd"
	enemy.player_ref = player
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.add_animation("move")
	var texture: Texture2D = preload("res://assets/generated/hd_enemy_turkey_idle.png")
	frames.add_frame("idle", texture)
	frames.add_frame("move", texture)
	sprite.sprite_frames = frames
	enemy.add_child(sprite)
	enemy.hd_enemy_sprite = sprite
	enemy.hd_enemy_base_scale = 0.5
	enemy.play_impact_deformation(Vector2(1.0, 1.0), 0.1, 0.15, 0.0, true)
	enemy.impact_deformation_left = enemy.impact_deformation_duration * 0.5
	enemy._update_hd_enemy_sprite()
	assert(absf(sprite.transform.x.dot(sprite.transform.y)) > 0.001, "A diagonal strike skews the visual along its axis.")
	enemy.impact_deformation_left = 0.0
	enemy._update_hd_enemy_sprite()
	assert(absf(sprite.transform.x.dot(sprite.transform.y)) < 0.001, "No diagonal deformation should linger after impact.")
	enemy.free()
	player.free()

func test_hit_axis_deformation_is_preserved_for_hd_without_changing_baseline() -> void:
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	fx.enable_split_kill = false
	var enemy: Enemy = Turkey.new()
	var hd_player: Player = Player.new()
	hd_player.visual_style = "hd"
	hd_player.set_combat_contact_setting("hd_hit_squash_strength", 200.0)
	# Pin both rolls to 100% so the deterministic blood assertions below hold at
	# perfect contact quality; the quality-lerp itself is covered separately.
	hd_player.set_combat_contact_setting("blood_chance_percent", 100.0)
	hd_player.set_combat_contact_setting("split_kill_chance_percent", 100.0)
	enemy.player_ref = hd_player
	enemy.impact_deformation_directional_hd = true
	fx.hit_squash_strength = 0.0
	hd_player.set_combat_contact_setting("hd_hit_squash_strength", 0.0)
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	assert(is_zero_approx(enemy.impact_deformation_compression), "Zero slider suppresses HD squash.")
	fx.enable_blood_splatter = false
	fx.blood_drops.clear()
	fx.blood_min_quality = 0.0
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT, Vector2.RIGHT, 1.0, true, true, true)
	assert(fx.blood_drops.is_empty(), "Blood disabled suppresses the kill burst too.")
	fx.enable_blood_splatter = true
	fx.blood_drops.clear()
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT, Vector2.RIGHT, 1.0, true, true, true)
	assert(not fx.blood_drops.is_empty(), "A qualifying sword kill always adds the blood burst, matching the original feel.")
	fx.blood_drops.clear()
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT, Vector2.RIGHT, 1.0, false, true, true)
	assert(not fx.blood_drops.is_empty(), "Ordinary qualifying sword hits always bleed, ungated by any kill chance.")
	assert(fx.split_remnants.is_empty(), "Enemies in classic mode do not split.")
	fx.hit_squash_strength = 2.0
	hd_player.set_combat_contact_setting("hd_hit_squash_strength", 200.0)
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	assert(enemy.impact_deformation_compression > 0.0, "Default 200% slider enables HD squash.")
	assert(enemy.impact_deformation_compression <= 0.7)
	enemy.impact_deformation_directional_hd = false
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, false, false)
	assert(not enemy.impact_deformation_directional_hd)
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	assert(enemy.impact_deformation_directional_hd)
	enemy.impact_deformation_left = enemy.impact_deformation_duration * 0.5
	var squash: Transform2D = enemy._impact_draw_transform()
	assert(squash.y.length() < squash.x.length(), "Vertical impact compresses vertically.")
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	enemy.impact_deformation_direction = Vector2.RIGHT
	enemy.impact_deformation_left = enemy.impact_deformation_duration * 0.5
	squash = enemy._impact_draw_transform()
	assert(squash.x.length() < squash.y.length(), "Horizontal impact compresses horizontally.")
	enemy.free()
	hd_player.free()
	fx.free()
