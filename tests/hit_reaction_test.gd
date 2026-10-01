class_name HitReactionTest extends Node

func test_hit_reaction_tab_has_every_canonical_control_and_existing_per_preset_persistence() -> void:
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
		elif key == "blade_sink_depth_percent":
			assert(control.min_value == 0.0 and control.max_value == 100.0 and control.step == 1.0, "Sink Depth must tune in 1% steps.")
		elif key == "blade_sink_dwell_time":
			assert(control.min_value == 0.0 and control.max_value == 0.30 and control.step == 0.01, "Sword Stickiness must tune 0 to 0.30s in 0.01s steps.")
		elif key == "blade_bone_stop_enabled":
			assert(control.min_value == 0.0 and control.max_value == 1.0 and control.step == 1.0)
		elif key == "blade_bone_stop_duration":
			assert(control.min_value == 0.0 and control.max_value == 0.12 and control.step == 0.01)
		elif key == "blade_bone_stop_cooldown":
			assert(control.min_value == 0.0 and control.max_value == 2.0 and control.step == 0.05)
		elif key == "blade_glance_angle_degrees":
			assert(control.min_value == 0.0 and control.max_value == 20.0 and control.step == 1.0, "The bone glance must stay capped at a safe 20 degrees.")
		elif key == "blade_core_yield_percent":
			assert(control.min_value == 0.0 and control.max_value == 100.0 and control.step == 1.0)
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
	player.set_combat_contact_setting("blade_sink_depth_percent", 55.0)
	player.set_combat_contact_setting("blade_sink_dwell_time", 0.14)
	player.set_combat_contact_setting("blade_bone_stop_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_stop_duration", 0.09)
	player.set_combat_contact_setting("blade_bone_stop_cooldown", 1.20)
	player.set_combat_contact_setting("blade_glance_angle_degrees", 16.0)
	player.set_combat_contact_setting("blade_core_yield_percent", 35.0)
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
	assert(player.get_combat_contact_setting("blade_sink_depth_percent") == 55.0)
	assert(player.get_combat_contact_setting("blade_sink_dwell_time") == 0.14)
	assert(player.get_combat_contact_setting("blade_bone_stop_enabled") == 1.0)
	assert(player.get_combat_contact_setting("blade_bone_stop_duration") == 0.09)
	assert(player.get_combat_contact_setting("blade_bone_stop_cooldown") == 1.20)
	assert(player.get_combat_contact_setting("blade_glance_angle_degrees") == 16.0)
	assert(player.get_combat_contact_setting("blade_core_yield_percent") == 35.0)
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
	assert(HitReaction.DEFAULTS.size() == 41, "Bone Slide and Bone Bind each add a canonical Hit Reaction setting plus one Effect Strength tuner apiece, the Physics Shells layer adds its four switches, Full Physical, Body Block, Blade Meets the World, Blade Meets Walls, Blade Meets Bodies, Hard Contact Clash and Bone Slide Constraint, Contact Recoil Delay adds its switch and its hold time, and Bone Clash and Flesh Bind each add their switch.")
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
	assert(not HitReaction.blade_physical_reaction_allowed(false, -0.4), "A blade already leaving the target should not be redirected.")
	var approaching: float = HitReaction.advance_blade_physical_reaction(0.0, 0.35, 0.016)
	var releasing: float = HitReaction.advance_blade_physical_reaction(approaching, 0.0, 0.016)
	assert(absf(approaching) > 0.0 and absf(approaching) < 0.35, "Core response eases in rather than snapping.")
	assert(absf(releasing) < absf(approaching), "Once contact ends, response eases back to the authored path.")

func test_bone_slide_and_bone_bind_ship_off_and_mirror_the_blade_effects() -> void:
	assert(HitReaction.DEFAULTS.has("blade_bone_slide_enabled"), "Bone Slide ships as a canonical Hit Reaction setting.")
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_bone_slide_enabled"], 0.0), "Bone Slide defaults OFF, so the shipped behaviour stays the fixed glance.")
	assert(HitReaction.DEFAULTS.has("blade_bone_bind_enabled"), "Bone Bind ships as a canonical Hit Reaction setting.")
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_bone_bind_enabled"], 0.0), "Bone Bind defaults OFF.")
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_bone_slide_strength"], 100.0), "Bone Slide ships at its authored full effect strength.")
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_bone_bind_strength"], 100.0), "Bone Bind ships at its authored full effect strength, which is itself weaker than a blade Bind.")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(menu_source.contains("\"blade_bone_slide_enabled\", \"Bone Slide — OFF / ON\""), "Bone Slide needs a visible OFF/ON control in the physical box.")
	assert(menu_source.contains("\"blade_bone_bind_enabled\", \"Bone Bind — OFF / ON\""), "Bone Bind needs a visible OFF/ON control in the physical box.")
	assert(menu_source.contains("\"blade_bone_slide_strength\", \"Bone Slide Effect Strength\", 0.0, 100.0, 1.0"), "The slide strength tuner must run 0-100% in 1% steps.")
	assert(menu_source.contains("\"blade_bone_bind_strength\", \"Bone Bind Effect Strength\", 0.0, 100.0, 1.0"), "The bind strength tuner must run 0-100% in 1% steps.")
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	assert(source.contains("bone_slide_left = maxf(bone_slide_left, BONE_SLIDE_REFRESH)"), "Bone Slide latches on the core and refreshes while the blade keeps overlapping it, exactly like the blade slide.")
	assert(source.contains("bone_bind_dwell >= BONE_BIND_CAPTURE_TIME"), "Bone Bind must be earned by a continuous capture on the core, like a blade Bind.")
	assert(source.contains("bone_bind_missing > BONE_BIND_RELEASE_GRACE"), "Bone Bind must release on a short grace once the blade leaves, never pin it.")
	assert(source.contains("bone_bind_left <= 0.0 or bone_bind_missing"), "Bone Bind must be bounded in time, exactly like a blade Bind.")
	assert(source.contains("bone_hold_multiplier, minf(bone_slide_target, bone_bind_target), delta)"), "Both bone effects ease in and back out through the shared eased channel, so neither ever snaps.")
	assert(source.contains("bone_hold_enemy.velocity *="), "The core drags the enemy the way a blade slide does.")
	assert(source.contains("minf(bone_slide_target, bone_bind_target)"), "The two effects share one hold channel, so they can never stack on the same enemy.")
	assert(source.contains("HitReaction.scale_effect_strength("), "Both effects must route their hold through the shared Effect Strength scaling.")
	assert(source.contains("get_combat_contact_setting(\"blade_bone_slide_enabled\") >= 0.5"), "Bone Slide must be gated by its own switch.")
	assert(source.contains("get_combat_contact_setting(\"blade_bone_bind_enabled\") >= 0.5"), "Bone Bind must be gated by its own switch.")
	assert(not source.contains("blade_bone_reaction_angle"), "Bone Slide is a copy of the blade slide, not its own pose maths.")
	assert(not source.contains("bone_recoil_"), "The invented banked recoil must be gone.")
	assert(source.contains("move_toward(blade_glance_angle, 0.0, delta * BLADE_GLANCE_RECOVERY_SPEED)"), "With Bone Slide OFF the original glance decay must remain untouched.")

func test_effect_strength_scales_a_bone_effect_from_inert_to_full() -> void:
	assert(is_equal_approx(HitReaction.scale_effect_strength(0.35, 0.0), 1.0), "0% effect strength must leave the blade completely untouched.")
	assert(is_equal_approx(HitReaction.scale_effect_strength(0.35, 100.0), 0.35), "100% must deliver the authored full effect.")
	assert(is_equal_approx(HitReaction.scale_effect_strength(0.35, 50.0), 0.675), "Half strength sits half way between no effect and the full effect.")
	assert(is_equal_approx(HitReaction.scale_effect_strength(0.35, 250.0), 0.35), "Over-range strength clamps to the authored effect.")
	assert(is_equal_approx(HitReaction.scale_effect_strength(0.35, -40.0), 1.0), "Under-range strength clamps to inert.")

func test_physics_shells_ship_all_off_and_leave_no_footprint() -> void:
	for key: String in ["blade_shell_query_enabled", "blade_shell_shove_enabled", "blade_shell_deflect_enabled", "bone_core_shell_enabled", "full_physical_enabled", "blade_body_block_enabled", "blade_shell_world_enabled", "blade_wall_block_enabled", "blade_body_surface_enabled", "blade_hard_clash_enabled", "blade_bone_constraint_enabled", "bone_clash_enabled"]:
		assert(HitReaction.DEFAULTS.has(key), "Every Physics Shells switch must be a canonical Hit Reaction setting: %s" % key)
		assert(is_equal_approx(HitReaction.DEFAULTS[key], 0.0), "Physics Shells must ship OFF so the authored pose stays untouched: %s" % key)
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(menu_source.contains("\"Physics Shells\""), "The shell switches need their own sub-tab in the Hit Reaction tab.")
	for label: String in ["Real Contact Normals — OFF / ON", "Blade Shell — OFF / ON", "Blade Deflection — OFF / ON", "Enemy Core Shells — OFF / ON", "Blade Meets Walls — OFF / ON", "Blade Meets Bodies — OFF / ON", "Hard Contact Clash — OFF / ON", "Bone Slide Constraint — OFF / ON", "Bone Clash — OFF / ON"]:
		assert(menu_source.contains(label), "Every Physics Shells switch needs a visible OFF/ON control: %s" % label)
	assert(menu_source.contains("shells_box, \"blade_shell_query_enabled\""), "The shell switches must live in the Physics Shells section, not the physical box.")

func test_blade_sink_depth_and_strength_compose_and_only_apply_during_contact() -> void:
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 100.0), 0.30), "Full strength uses the default 70% Depth ceiling, so the swing advances at 30%.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 50.0), 0.65), "Strength uses only half of the Depth ceiling.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 100.0, 100.0), 0.0), "A 100% Depth ceiling at full strength stops the swing entirely.")
	assert(is_equal_approx(HitReaction.blade_sink_time_multiplier(true, true, true, 100.0, 0.0), 1.0), "A 0% Depth ceiling never slows the swing.")
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

func test_bone_constraint_turns_the_blade_about_the_hilt_and_owns_the_angle() -> void:
	# Integration, not helper maths: this goes through the very pose function the game commits, so
	# it proves the live path actually APPLIES the solver. That is the mistake worth guarding
	# against -- helpers that pass their own tests while gameplay never calls them.
	var player: Player = Player.new()
	var authored_start: Vector2 = Vector2(30.0, 20.0)
	player.bone_constraint_angle = 0.0
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_constraint_enabled", 0.0)
	player.blade_glance_angle = 0.4
	var off_pose: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0})
	assert(is_equal_approx(float(off_pose["angle"]), 0.4), "With the switch OFF the authored pose keeps its ordinary glance.")
	# With the switch ON the constraint is the only opinion about the blade angle. There is no bone in
	# range here, so the solve correctly yields nothing -- and the glance STILL stands down, which is
	# what proves the constraint has taken over the live blade angle.
	player.set_combat_contact_setting("blade_bone_constraint_enabled", 1.0)
	player.blade_glance_angle = 0.4
	var on_pose: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0})
	assert(is_equal_approx(float(on_pose["angle"]), 0.0), "The glance stands down while the constraint owns the angle.")
	assert(is_equal_approx(player.bone_constraint_angle_pending, 0.0), "The solver sets the constraint angle every frame, so no stale correction can survive.")
	assert((on_pose["start"] as Vector2).is_equal_approx(authored_start), "The hilt is never moved to satisfy bone contact -- rotation is the only degree of freedom the core can touch.")
	assert(player.bone_hilt_push_pending == Vector2.ZERO, "Nothing pushes the hand when there is no bone to stand in.")
	player.free()

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
	var glanced: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0, "arc_degrees": 60.0})
	assert(is_equal_approx(float(glanced["angle"]), 0.0), "A zero glance leaves the authored angle untouched.")
	player.blade_glance_angle = 0.2
	var deflected: Dictionary = player._apply_flesh_contact_pose({"start": authored_start, "angle": 0.0, "arc_degrees": 60.0})
	assert(is_equal_approx(float(deflected["angle"]), 0.2), "The bone glance deflects the rendered pose by exactly its bounded angle.")
	assert((deflected["start"] as Vector2) == authored_start, "Even a deflecting glance may never translate the authored hilt anchor.")
	var eased_in: float = HitReaction.advance_blade_core_yield(1.0, target, 0.016)
	assert(eased_in < 1.0 and eased_in > target, "The yield eases in rather than snapping to full resistance.")
	var released: float = HitReaction.advance_blade_core_yield(eased_in, 1.0, 0.016)
	assert(released > eased_in and released < 1.0, "After separation the swing rate eases back rather than snapping to full speed.")
	player.free()

func test_blade_core_yield_percent_scales_the_gentle_floor() -> void:
	assert(is_equal_approx(HitReaction.blade_core_yield_target(100.0, true, 1.0, 60.0), 0.85), "The default 60% Core Yield is gentler than the old 0.75 floor.")
	assert(is_equal_approx(HitReaction.blade_core_yield_target(100.0, true, 1.0, 100.0), 0.75), "100% Core Yield restores the old full-strength floor.")
	assert(is_equal_approx(HitReaction.blade_core_yield_target(100.0, true, 1.0, 0.0), 1.0), "0% Core Yield turns the continuous resistance off.")
	assert(is_equal_approx(HitReaction.blade_core_yield_target(100.0, false, 1.0, 60.0), 1.0), "No inward core contact means no yield at any percent.")

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

func test_bug_bleeds_green_while_default_enemies_stay_red() -> void:
	# The Bug carries its own blood tint; every other enemy leaves it unset and so
	# falls back to the FX default red.
	var bug: Bug = WaveSpawner.BUG_SCENE.instantiate() as Bug
	bug._configure_concrete_enemy()
	assert(bug.blood_tint.a > 0.0, "The Bug must opt into a blood tint.")
	assert(bug.blood_tint.g > bug.blood_tint.r and bug.blood_tint.g > bug.blood_tint.b, "The Bug's blood tint must read green.")
	var goblin: Goblin = WaveSpawner.GOBLIN_SCENE.instantiate() as Goblin
	goblin._configure_concrete_enemy()
	assert(goblin.blood_tint.a <= 0.0, "An untinted enemy must fall back to the FX red.")
	bug.free()
	goblin.free()

func test_blood_tint_recolours_the_spray_and_the_pool() -> void:
	var green: Color = Color(0.2, 0.8, 0.2, 0.96)
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	fx.blood_drop_count = 8
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true, 1.0, 1.0, green)
	assert(fx.blood_drops.size() > 0)
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		assert(drop.color.g > drop.color.r and drop.color.g > drop.color.b, "A tinted spray must carry the tint colour on every droplet.")
	fx.blood_drops.clear()
	fx._spawn_blood(Vector2.ZERO, Vector2.RIGHT * 500.0, 1.0, true)
	for drop: CombatPresentationFX.BloodDrop in fx.blood_drops:
		assert(drop.color.is_equal_approx(fx.blood_color), "An untinted spray keeps the FX default red.")
	fx.free()
	var decals: BloodDecals = BloodDecals.new()
	decals.spawn_pool(Vector2.ZERO, 20.0, green)
	assert(decals.pools.size() == 1 and is_equal_approx(decals.pools[0].color.g, green.g), "A tinted pool keeps the supplied hue.")
	decals.pools.clear()
	decals.spawn_pool(Vector2.ZERO, 20.0)
	assert(decals.pools.size() == 1 and decals.pools[0].color.is_equal_approx(decals.pool_color), "An untinted pool keeps the default red.")
	decals.free()

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
	assert(not source.contains("blade_physical_reaction_angle"), "The old unbounded rotated blade reaction was replaced by a bounded, tunable bone glance plus a swing-rate yield.")
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

func test_hit_reaction_blade_and_blood_sections_are_collapsed_dropdowns() -> void:
	# The deep tuners live in always-collapsed dropdown sections - the same idiom the
	# Combat Presets tab uses - not a nested TabContainer. Their open state is never
	# saved or restored, so every launch starts collapsed for a clean menu.
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	var tabs: TabContainer = TabContainer.new()
	menu._build_hit_reaction_tab(tabs)
	var scroll: Node = tabs.get_node("HIT REACTION")
	assert(scroll != null, "HIT REACTION must remain a ScrollContainer tab.")
	assert(scroll.find_child("HitReactionSections", true, false) == null, "The old nested TabContainer section host must be gone.")
	var headers: Array[Button] = []
	_collect_buttons(scroll, headers)
	var expected_sections: Array[String] = ["Blade Sink", "Blade Physical Reaction", "Enemy Visual FX", "Blood & Death"]
	var found: Dictionary = {}
	for header: Button in headers:
		for section_name: String in expected_sections:
			if header.text.ends_with(section_name):
				found[section_name] = header
	for section_name: String in expected_sections:
		assert(found.has(section_name), "HIT REACTION must expose a %s dropdown section." % section_name)
		var header: Button = found[section_name]
		assert(header.text.begins_with("▶ "), "Section %s must start collapsed on init, ignoring any saved open state." % section_name)
	menu.free()
	tabs.free()

func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node as Button)
	for child: Node in node.get_children():
		_collect_buttons(child, out)

func test_bone_stop_nests_inside_the_sword_stickiness_hold_budget() -> void:
	# Option A: the bone stop can never outlast the Sword Stickiness hold, so a core
	# catch cannot stack with the flesh tail into one unpredictable long stall.
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_sink_dwell_time"], 0.10), "Sword Stickiness defaults to 0.10 s, the single hold budget.")
	assert(is_equal_approx(HitReaction.bone_stop_within_hold(0.08, 0.10), 0.08), "A short catch inside a longer hold is kept intact.")
	assert(is_equal_approx(HitReaction.bone_stop_within_hold(0.08, 0.05), 0.05), "A catch longer than the hold is clipped to the hold, never added on top of it.")
	assert(is_equal_approx(HitReaction.bone_stop_within_hold(0.08, 0.0), 0.0), "A zero hold budget freezes nothing.")
	assert(is_equal_approx(HitReaction.bone_stop_within_hold(0.5, 0.30), 0.30), "The catch stays within the hold and the 0.30 s ceiling.")
	assert(is_equal_approx(HitReaction.bone_stop_within_hold(-0.1, 0.10), 0.0), "A negative catch duration clamps to zero.")

func test_bone_clash_is_a_presentation_only_hit_reaction_switch() -> void:
	# Bone Clash must be a canonical Hit Reaction setting that ships OFF, must expose a visible
	# OFF/ON control in the Physics Shells section, and must fire only with the master behind it.
	assert(HitReaction.DEFAULTS.has("bone_clash_enabled"), "Bone Clash must be a canonical Hit Reaction setting.")
	assert(is_equal_approx(HitReaction.DEFAULTS["bone_clash_enabled"], 0.0), "Bone Clash must ship OFF so the authored pose stays untouched.")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(menu_source.contains("shells_box, \"bone_clash_enabled\""), "Bone Clash belongs in the Physics Shells section.")
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 0.0)
	player.set_combat_contact_setting("bone_clash_enabled", 1.0)
	assert(not player.bone_clash_on(), "Bone Clash cannot fire without the Hit Reaction master, like every shell switch.")
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	assert(player.bone_clash_on(), "With the master on, the Bone Clash switch turns the effect on.")
	player.set_combat_contact_setting("bone_clash_enabled", 0.0)
	assert(not player.bone_clash_on(), "With the switch off the effect is inert.")
	player.free()

func test_flesh_bind_is_a_master_gated_grip_that_captures_instantly_on_flesh_contact() -> void:
	# Flesh Bind must ship OFF behind the master, live in the Blade Physical Reaction section, and
	# capture the grip the instant the blade meets flesh -- no candidate delay -- while still
	# shedding fast so ripping the blade out restores the swing.
	assert(HitReaction.DEFAULTS.has("blade_flesh_bind_enabled"), "Flesh Bind must be a canonical Hit Reaction setting.")
	assert(is_equal_approx(HitReaction.DEFAULTS["blade_flesh_bind_enabled"], 0.0), "Flesh Bind must ship OFF so the authored pose stays untouched.")
	var menu_source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(menu_source.contains("physical_box, \"blade_flesh_bind_enabled\""), "Flesh Bind belongs in the Blade Physical Reaction section.")
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 0.0)
	player.set_combat_contact_setting("blade_flesh_bind_enabled", 1.0)
	assert(not player.flesh_bind_on(), "Flesh Bind cannot fire without the Hit Reaction master.")
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	assert(player.flesh_bind_on(), "With the master on, the Flesh Bind switch turns the grip on.")
	player.set_combat_contact_setting("blade_flesh_bind_enabled", 0.0)
	assert(not player.flesh_bind_on(), "With the switch off the grip is inert.")
	var captured: float = HitReaction.advance_flesh_bind_grip(0.0, 0.8, 0.0)
	assert(is_equal_approx(captured, 0.8), "The grip must capture the instant the blade meets flesh, with no ramp-in.")
	var shed: float = HitReaction.advance_flesh_bind_grip(1.0, 0.0, 0.02)
	assert(shed < 1.0 and shed > 0.0, "Ripping the blade out must shed the grip over a beat, never leave it stuck.")
	assert(is_equal_approx(HitReaction.advance_flesh_bind_grip(1.0, 0.0, 1.0), 0.0), "Given time out of flesh the grip must clear completely.")
	player.free()

func test_flesh_bind_hinge_and_push_are_bounded_and_release_with_the_grip() -> void:
	# The other two halves of Flesh Bind: the buried blade resists turning (hinge, a clamped aim
	# dent), and the body's own closing motion shoves us (push, capped). Both ride the one grip and
	# both must be inert when the switch is off -- so a blade is never turned and a body never pushes.
	var player: Player = Player.new()
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_flesh_bind_enabled", 1.0)
	# Hinge: a full grip dents the aim's own rotation, but only ever up to the clamp.
	player.flesh_bind_grip = 1.0
	player.aim_angle = 0.0
	player.flesh_bind_prev_aim = 0.0
	player.aim_angle = 0.5
	player._apply_flesh_bind_retention()
	assert(player.aim_angle < 0.5, "A gripped blade must fight being turned.")
	assert(player.aim_angle >= 0.5 - Player.FLESH_BIND_HINGE_MAX - 0.0001, "The hinge must be a bounded dent, never a lock.")
	# Directional: with the body outward-up, sweeping the tip down (inward) must be bitten harder
	# than sweeping it up (the pull-out), and the pull-out must still be resisted, never ignored.
	player.flesh_bind_contact_normal = Vector2.UP
	player.flesh_bind_prev_aim = 0.0
	player.aim_angle = 0.2
	player._apply_flesh_bind_retention()
	var inward_moved: float = absf(player.aim_angle)
	player.flesh_bind_prev_aim = 0.0
	player.aim_angle = -0.2
	player._apply_flesh_bind_retention()
	var outward_moved: float = absf(player.aim_angle)
	assert(inward_moved < outward_moved, "The inward turn must be bitten harder than the pull-out turn.")
	assert(outward_moved < 0.2, "The pull-out turn must still be resisted a little, just less.")
	# With the switch off the aim is untouched.
	player.set_combat_contact_setting("blade_flesh_bind_enabled", 0.0)
	player.flesh_bind_prev_aim = 0.0
	player.aim_angle = 0.5
	player._apply_flesh_bind_retention()
	assert(is_equal_approx(player.aim_angle, 0.5), "With Flesh Bind off the hinge must not touch the aim.")
	player.free()
	# Push: only a body closing on us pushes, it is capped, and no grip means no push.
	var toward_us: Vector2 = Vector2(-500.0, 0.0)
	var away: Vector2 = Vector2.LEFT
	assert(Player.flesh_bind_push(toward_us, away, 1.0, Player.FLESH_BIND_PUSH_GAIN, Player.FLESH_BIND_PUSH_MAX).length() > 0.0, "A body closing on the blade must shove us.")
	assert(is_zero_approx(Player.flesh_bind_push(Vector2(500.0, 0.0), away, 1.0, Player.FLESH_BIND_PUSH_GAIN, Player.FLESH_BIND_PUSH_MAX).length()), "A body moving away must not push.")
	assert(is_zero_approx(Player.flesh_bind_push(toward_us, away, 0.0, Player.FLESH_BIND_PUSH_GAIN, Player.FLESH_BIND_PUSH_MAX).length()), "No grip means no push.")
	var capped: Vector2 = Player.flesh_bind_push(Vector2(-999999.0, 0.0), away, 1.0, Player.FLESH_BIND_PUSH_GAIN, Player.FLESH_BIND_PUSH_MAX)
	assert(is_equal_approx(capped.length(), Player.FLESH_BIND_PUSH_MAX), "The push must stay capped so a charging body can never launch us.")

func test_contact_recoil_delay_holds_the_separation_only_when_switched_and_timed() -> void:
	# The delay is pure timing on a hit's separation: with no switch, no hold, or no cap the impulse
	# must fire exactly as it does today; with all three it must wait.
	var player: Player = Player.new()
	player.set_combat_contact_setting("contact_recoil_delay_enabled", 0.0)
	player.set_combat_contact_setting("contact_recoil_delay", 0.20)
	assert(not player.contact_recoil_delay_on(), "A hold time without the switch is inert.")
	player.set_combat_contact_setting("contact_recoil_delay_enabled", 1.0)
	player.set_combat_contact_setting("contact_recoil_delay", 0.0)
	assert(not player.contact_recoil_delay_on(), "A zero hold is not a delay even with the switch on.")
	player.set_combat_contact_setting("contact_recoil_delay", 0.20)
	assert(player.contact_recoil_delay_on(), "Switch on with a real hold turns the delay on.")
	assert(is_equal_approx(player.contact_recoil_delay_seconds(), 0.20), "The hold reads back in seconds.")
	# A held separation must NOT fire while the hold runs -- even with no constraint holding it.
	player.bone_constraint_active = false
	player.pending_sword_impulse = Vector2(10.0, 0.0)
	player.pending_sword_impulse_left = 0.20
	player.contact_hold_left = 0.20
	player._update_pending_bone_knockback(0.016)
	assert(player.pending_sword_impulse != Vector2.ZERO, "The enemy knockback is held for the delay before it separates.")
	# Once the hold has run out the impulse fires and clears, so nothing can wait forever.
	player.contact_hold_left = 0.0
	player.pending_sword_impulse_left = 0.0
	player._update_pending_bone_knockback(0.016)
	assert(player.pending_sword_impulse == Vector2.ZERO, "The knockback fires once the hold and its safety cap both expire.")
	player.free()
