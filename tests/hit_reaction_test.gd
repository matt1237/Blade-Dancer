class_name HitReactionTest extends Node

func test_hit_reaction_tab_has_seven_controls_and_existing_per_preset_persistence() -> void:
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu._build_hit_reaction_tab(tabs)
	assert(tabs.get_node("HIT REACTION") is ScrollContainer)
	assert(menu.contact_controls.size() == 7)
	for key: String in HitReaction.DEFAULTS.keys():
		assert(menu.contact_controls.has(key), "Every canonical Hit Reaction setting must have one visible control: %s" % key)
		var row: Dictionary = menu.contact_controls[key]
		var control: HSlider = row["slider"] as HSlider
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
	var preset_three: Dictionary = player.combat_contact_settings["3"] as Dictionary
	assert(not preset_three.has("flesh_contact_drag") and not preset_three.has("hilt_contact_drag") and not preset_three.has("farmable_contact_drag"), "Removed drag fields must not be copied as active preset controls.")
	assert(HitReaction.DEFAULTS.size() == 7)
	player.free()
	menu.free()
	tabs.free()

func test_glancing_physical_reaction_deflects_tangentially_but_head_on_and_stabs_pass_through() -> void:
	var normal: Vector2 = Vector2.DOWN
	var head_on_angle: float = HitReaction.blade_physical_reaction_angle(Vector2.UP * 500.0, Vector2.ZERO, normal, 100.0)
	var glancing_angle: float = HitReaction.blade_physical_reaction_angle(Vector2(468.0, -175.0), Vector2.ZERO, normal, 100.0)
	assert(is_zero_approx(head_on_angle), "A committed head-on cut must pass through without blade pinning.")
	assert(absf(glancing_angle) > 0.1 and absf(glancing_angle) <= HitReaction.MAX_PHYSICAL_REACTION_ANGLE, "A glancing cut should yield along the body's tangent, within the authored arc limit.")
	assert(not HitReaction.blade_physical_reaction_allowed(true, 0.35), "A stab is always excluded even when its approach angle is glancing.")
	assert(not HitReaction.blade_physical_reaction_allowed(false, 0.9), "A head-on forte or tip cut passes through.")
	assert(HitReaction.blade_physical_reaction_allowed(false, 0.35), "Only a glancing cut is eligible for tangential yielding.")
	var departing_angle: float = HitReaction.blade_physical_reaction_angle(Vector2(468.0, 175.0), Vector2.ZERO, normal, 100.0)
	assert(is_zero_approx(departing_angle), "A cut already leaving the body receives no physical deflection.")
	var moving_head_on_angle: float = HitReaction.blade_physical_reaction_angle(Vector2.UP * 500.0, Vector2(0.0, -50.0), normal, 100.0)
	assert(is_zero_approx(moving_head_on_angle), "Target movement is included when classifying head-on contact.")
	var approaching: float = HitReaction.advance_blade_physical_reaction(0.0, glancing_angle, 0.016)
	var releasing: float = HitReaction.advance_blade_physical_reaction(approaching, 0.0, 0.016)
	assert(absf(approaching) > 0.0 and absf(approaching) < absf(glancing_angle), "Contact response eases in rather than snapping.")
	assert(absf(releasing) < absf(approaching), "Once contact ends, the angle eases back to the authored path.")

func test_blade_sink_is_bounded_and_exists_only_during_master_enabled_live_overlap() -> void:
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 100.0), 0.82))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 50.0), 0.91))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(false, true, true, 100.0), 1.0), "The master switch overrides sink.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, false, true, 100.0), 1.0))
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, false, 100.0), 1.0), "No contact tail may slow a free swing.")

func test_authored_pose_reaction_keeps_the_hand_anchor_and_rotates_the_complete_blade() -> void:
	var player: Player = Player.new()
	player.blade_physical_reaction_angle = deg_to_rad(12.0)
	player.blade_flesh_overlap_active = true
	player.blade_sink_strength_active = 100.0
	var authored_start: Vector2 = Vector2(30.0, 20.0)
	var pose: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0, "arc_degrees": 60.0})
	assert((pose["start"] as Vector2) == authored_start, "Neither physical reaction nor sink may translate the authored hand/hilt anchor.")
	assert(is_equal_approx(float(pose["angle"]), deg_to_rad(12.0)))
	player.blade_flesh_overlap_active = false
	player.blade_sink_strength_active = 0.0
	player.blade_physical_reaction_angle = HitReaction.advance_blade_physical_reaction(player.blade_physical_reaction_angle, 0.0, 0.016)
	var released_pose: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0, "arc_degrees": 60.0})
	assert((released_pose["start"] as Vector2) == authored_start, "Separation cannot leave a translated hilt behind.")
	assert(absf(float(released_pose["angle"])) < deg_to_rad(12.0), "Separation smoothly returns toward the authored pose.")
	player.free()

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

func test_removed_pose_and_drag_authorities_are_not_called() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(not source.contains("_update_hit_reaction_pose") and not source.contains("hit_reaction_offset"))
	assert(not source.contains("_trigger_contact_drag") and not source.contains("contact_drag_multiplier"))
	assert(not source.contains("hit_knockback_scale") and not source.contains("hit_hitstop_scale"))
	assert(not source.contains("HitReaction.analyze") and not source.contains("HitReaction.resist"))
	for retired_setting: String in ["flesh_contact_drag", "hilt_contact_drag", "farmable_contact_drag"]:
		assert(not menu_source.contains(retired_setting), "The retired Contact Drag setting must not have a visible control.")

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
	enemy._update_hd_enemy_sprite()
	assert(absf(sprite.transform.x.dot(sprite.transform.y)) > 0.001, "A diagonal strike skews the visual along its axis.")
	enemy.impact_deformation_left = 0.0
	enemy._update_hd_enemy_sprite()
	assert(absf(sprite.transform.x.dot(sprite.transform.y)) < 0.001, "No diagonal deformation should linger after impact.")
	enemy.free()
	player.free()

func test_hit_axis_deformation_is_preserved_for_hd_without_changing_baseline() -> void:
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	var enemy: Enemy = Enemy.new()
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, true, false)
	assert(not enemy.impact_deformation_directional_hd)
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.DOWN * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	assert(enemy.impact_deformation_directional_hd)
	var squash: Transform2D = enemy._impact_draw_transform()
	assert(squash.y.length() < squash.x.length(), "Vertical impact compresses vertically.")
	fx.present_enemy_hit(enemy, Vector2.ZERO, Vector2.RIGHT * 500.0, Vector2.RIGHT, 1.0, false, true, true)
	squash = enemy._impact_draw_transform()
	assert(squash.x.length() < squash.y.length(), "Horizontal impact compresses horizontally.")
	enemy.free()
	fx.free()
