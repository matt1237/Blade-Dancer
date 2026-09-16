class_name ExperimentalBindTest extends Node

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/enemies/goblin.tscn")

func _make_pair() -> Array[Node]:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.sword_style = Player.SwordStyle.METRONOME_BIND
	player.combat_contact_preset = 2
	player.set_combat_hand_setting("bind_enabled", 1.0)
	player.set_combat_hand_setting("bind_capture_time", 0.10)
	player.set_combat_hand_setting("bind_pressure_min", 8.0)
	player.set_combat_hand_setting("bind_release_grace", 0.10)
	player.set_combat_hand_setting("bind_disengage_min_time", 0.10)
	player.set_combat_hand_setting("bind_disengage_min_travel", 14.0)
	player.set_combat_hand_setting("bind_disengage_fraction_delta", 0.12)
	player.set_combat_hand_setting("bind_disengage_endpoint", 0.18)
	player.set_combat_hand_setting("bind_disengage_leverage", 0.08)
	var enemy: Goblin = GOBLIN_SCENE.instantiate() as Goblin
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(300.0, 300.0)
	enemy.blade_angle = 0.0
	enemy.player_ref = player
	return [player, enemy]

func _arm_real_slide(player: Player, enemy: Enemy) -> Dictionary:
	var enemy_segment: Dictionary = enemy._enemy_weapon_segment()
	var blade_start: Vector2 = enemy_segment["start"] as Vector2
	var blade_end: Vector2 = enemy_segment["end"] as Vector2
	player.current_blade_samples = PackedVector2Array([blade_start, blade_start.lerp(blade_end, 0.5), blade_end])
	player.blade_velocity = Vector2(100.0, 100.0)
	assert(enemy.try_blade_slide(blade_start, blade_end, player.blade_velocity, 2), "The test must arm Form III through a real validated parallel blade slide.")
	player._trigger_blade_slide(enemy.get_slide_contact_global(), enemy)
	return {"start": blade_start, "end": blade_end}

func test_form_three_bind_requires_slide_then_continuous_pressure() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	assert(player.experimental_bind_candidate, "A validated Form III blade slide must begin a bind candidate.")
	assert(not player.experimental_bind_active, "Initial contact must not grant an instant stable bind or free counter.")
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	assert(player.experimental_bind_active, "Continuous contact plus pressure for Capture Time must earn a stable bind.")
	assert(player.experimental_bind_pressure >= 8.0, "Stable capture must retain a measured normal-pressure signal.")
	assert(player.experimental_bind_tangent_speed > 0.0, "Tangential blade travel must remain separately measurable for scrape/slide feel.")
	player._release_experimental_bind("test cleanup")
	actors[1].free()
	actors[0].free()

func test_bind_contact_fraction_tracks_live_slide_geometry_not_cached_fx_point() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.02)
	var first_fraction: float = player.experimental_bind_enemy_fraction
	var enemy_segment: Dictionary = enemy._enemy_weapon_segment()
	var enemy_end: Vector2 = enemy_segment["end"] as Vector2
	var moved_start: Vector2 = enemy_end - enemy.get_blade_direction() * 30.0
	var moved_end: Vector2 = enemy_end + enemy.get_blade_direction() * 30.0
	player.current_blade_samples = PackedVector2Array([moved_start, moved_start.lerp(moved_end, 0.5), moved_end])
	player._update_experimental_bind_contact(enemy, moved_start, moved_end, 0.02)
	assert(player.experimental_bind_enemy_fraction > first_fraction, "Guard-wrap progress must follow the live blade midpoint toward the enemy tip, not the slide FX cache.")
	player._release_experimental_bind("test cleanup")
	actors[1].free()
	actors[0].free()

func test_form_three_bind_releases_on_geometry_and_suppresses_immediate_rebind() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	assert(player.experimental_bind_active)
	player.experimental_bind_contact_seen = false
	player._finish_experimental_bind_frame(0.11)
	assert(not player.experimental_bind_active, "A blade pair that exceeds Release Grace must leave focus instead of magnetically reacquiring.")
	assert(player.experimental_bind_cooldown_left > 0.0, "Release must impose short re-bind suppression against contact spam.")
	player._begin_experimental_bind_candidate(enemy, enemy.get_slide_contact_global())
	assert(not player.experimental_bind_candidate, "Re-bind suppression must reject an immediate candidate even while weapons remain nearby.")
	actors[1].free()
	actors[0].free()

func test_bind_hinge_resists_crossing_but_allows_clean_opening() -> void:
	var crossing_correction: float = Player.experimental_hinge_correction(deg_to_rad(-4.0), 0.0, 1.0, 0.8, 1.0 / 60.0, true)
	assert(crossing_correction > 0.0, "Crossing through the opponent's blade plane must be corrected back to the owned hinge side.")
	var open_correction: float = Player.experimental_hinge_correction(deg_to_rad(16.0), 0.0, 1.0, 0.8, 1.0 / 60.0, true)
	assert(is_zero_approx(open_correction), "Opening away from contact must remain fully controllable so the hinge cannot magnetically reacquire.")

func test_only_one_opponent_can_own_an_experimental_bind() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var first_enemy: Enemy = actors[1] as Enemy
	player._begin_experimental_bind_candidate(first_enemy, first_enemy.get_slide_contact_global())
	var second_enemy: Goblin = GOBLIN_SCENE.instantiate() as Goblin
	add_child(second_enemy)
	second_enemy.set_physics_process(false)
	second_enemy.player_ref = player
	player._begin_experimental_bind_candidate(second_enemy, second_enemy.global_position)
	assert(player.experimental_bind_opponent == first_enemy, "A second weapon must use ordinary contact instead of replacing the active bind owner and pinning the player.")
	player._release_experimental_bind("test cleanup")
	second_enemy.free()
	actors[1].free()
	actors[0].free()

func test_forms_one_and_two_cannot_arm_experimental_bind() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	player._begin_experimental_bind_candidate(enemy, enemy.get_slide_contact_global())
	assert(not player.experimental_bind_candidate, "Form II must remain mechanically untouched by Form III bind state.")
	player.sword_style = Player.SwordStyle.METRONOME
	player._begin_experimental_bind_candidate(enemy, enemy.get_slide_contact_global())
	assert(not player.experimental_bind_candidate, "Form I must remain mechanically untouched by Form III bind state.")
	actors[1].free()
	actors[0].free()

func test_bind_world_slow_compensation_preserves_sword_clock() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.sword_style = Player.SwordStyle.METRONOME_BIND
	player.combat_hand_settings.clear()
	player.combat_weapon_hand_settings.clear()
	assert(is_equal_approx(player.get_combat_hand_setting("bind_sword_speed"), 1.0), "Default stable focus must not accidentally detune the sword from its musical metronome.")
	player.set_combat_hand_setting("bind_focus_time_scale", 0.60)
	player.experimental_bind_active = true
	assert(is_equal_approx(player._experimental_sword_control_delta(0.006), 0.01), "A world frame slowed to 60% must still advance the Form III sword by one real-time frame.")
	player.experimental_bind_active = false
	assert(is_equal_approx(player._experimental_sword_control_delta(0.01), 0.01), "Unbound sword timing must remain unchanged.")
	player.free()

func test_weapon_beat_requires_post_capture_pressure_spike_and_leverage() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	player.set_combat_hand_setting("bind_beat_pressure", 250.0)
	player.set_combat_hand_setting("bind_beat_spike", 100.0)
	player.set_combat_hand_setting("bind_beat_leverage", -0.10)
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	var health_before: float = enemy.health
	player.blade_velocity = Vector2(100.0, 500.0)
	player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.05)
	assert(player.experimental_bind_outcome == "WEAPON BEAT", "A new committed pressure spike with sufficient leverage must displace the weapon.")
	assert(not player.experimental_bind_active, "A weapon beat must release the bind instead of becoming a repeatable held-contact loop.")
	assert(enemy.stun_left > 0.0 and enemy.knockback.length() > 0.0, "A beat must physically displace and impair the enemy weapon stance.")
	assert(is_equal_approx(enemy.health, health_before), "A weapon beat is not health damage; a separate attack remains necessary.")
	actors[1].free()
	actors[0].free()

func test_body_or_enemy_motion_cannot_grant_a_free_weapon_beat() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	player.set_combat_hand_setting("bind_beat_pressure", 250.0)
	player.set_combat_hand_setting("bind_beat_spike", 100.0)
	player.set_combat_hand_setting("bind_beat_leverage", -1.0)
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	player.velocity = Vector2(100.0, 500.0)
	player.blade_velocity = player.velocity
	player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.05)
	assert(player.experimental_bind_active and player.experimental_bind_outcome.is_empty(), "Body translation without authored hand/blade pressure must not earn offense.")
	assert(is_zero_approx(enemy.stun_left), "Enemy movement into a held guard must not beat its own weapon.")
	player._release_experimental_bind("test cleanup")
	actors[1].free()
	actors[0].free()

func test_bad_leverage_rejects_beat_into_player_recoil() -> void:
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	player.set_combat_hand_setting("bind_beat_pressure", 250.0)
	player.set_combat_hand_setting("bind_beat_spike", 100.0)
	player.set_combat_hand_setting("bind_beat_leverage", 0.30)
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	player.velocity = Vector2.ZERO
	player.blade_velocity = Vector2(100.0, 500.0)
	player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.05)
	assert(player.experimental_bind_outcome == "BEAT REJECTED", "High pressure from a losing lever relationship must not grant a weapon beat.")
	assert(player.velocity.length() > 0.0, "A rejected beat must create physical player recoil as its anti-spam consequence.")
	assert(is_zero_approx(enemy.stun_left), "Bad leverage must not impair the opponent.")
	actors[1].free()
	actors[0].free()

func test_endpoint_guard_wrap_arms_only_a_short_collision_gated_reentry() -> void:
	assert(Player.experimental_disengagement_qualifies(0.15, 20.0, 0.50, 0.90, 0.20, 0.10, 14.0, 0.12, 0.18, 0.08))
	assert(not Player.experimental_disengagement_qualifies(0.15, 4.0, 0.50, 0.90, 0.20, 0.10, 14.0, 0.12, 0.18, 0.08), "Endpoint proximity alone must not become a canned disengagement.")
	var actors: Array[Node] = _make_pair()
	var player: Player = actors[0] as Player
	var enemy: Enemy = actors[1] as Enemy
	var segment: Dictionary = _arm_real_slide(player, enemy)
	for _step: int in range(3):
		player._update_experimental_bind_contact(enemy, segment["start"] as Vector2, segment["end"] as Vector2, 0.04)
	player.experimental_bind_elapsed = 0.15
	player.experimental_bind_tangent_travel = 20.0
	player.experimental_bind_start_enemy_fraction = 0.50
	player.experimental_bind_enemy_fraction = 0.90
	player.experimental_bind_leverage = 0.20
	player.experimental_bind_roll_crossed = true
	player.experimental_bind_start_roll = 1.0
	player.blade_roll = -0.8
	player._release_experimental_bind("blade separation")
	assert(player.experimental_reentry_opponent == enemy and player.experimental_reentry_time_left > 0.0, "A real endpoint guard wrap must arm short contact memory, not immediate damage.")
	assert(player.experimental_reentry_was_rollover and player.experimental_bind_outcome == "ROLLOVER DISENGAGE", "Rollover may communicate a completed real orientation change, but only after geometry qualified the wrap.")
	var contact: SwordContactData = SwordContactData.new()
	contact.contact_point = enemy.global_position
	contact.impact_speed = 220.0
	contact.blade_velocity = -player.experimental_reentry_inward_direction * 180.0
	assert(is_zero_approx(player._experimental_reentry_quality_for_contact(enemy, contact)), "An outward or merely nearby collision must not consume guard-wrap memory as a re-entry.")
	contact.blade_velocity = player.experimental_reentry_inward_direction * 180.0
	var quality: float = player._experimental_reentry_quality_for_contact(enemy, contact)
	assert(quality > 0.0, "Re-entry must still require a new inward, sufficiently fast swept body contact.")
	player._consume_experimental_reentry(contact, quality)
	assert(player.experimental_reentry_opponent == null and player.experimental_bind_outcome == "ROLLOVER RE-ENTRY", "A valid re-entry collision must consume its short memory exactly once.")
	actors[1].free()
	actors[0].free()

func test_focus_world_scale_is_sustained_and_restores_cleanly() -> void:
	var fx: CombatPresentationFX = CombatPresentationFX.new()
	fx.set_bind_focus(true, 0.60, 0.15, 8.0)
	fx._update_impact_time_slow(0.01)
	assert(is_equal_approx(Engine.time_scale, 0.60), "Stable bind focus must sustain the authored world speed instead of using one global hitstop pulse.")
	fx.set_bind_focus(false)
	assert(is_equal_approx(Engine.time_scale, 1.0), "Releasing focus must always restore normal world time.")
	fx.free()

func test_preset_copy_keeps_experimental_fields_out_of_forms_one_and_two() -> void:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_hand_settings.clear()
	player.combat_weapon_hand_settings.clear()
	player.ensure_experimental_form_initialized()
	player.copy_preset_settings(2, 3)
	var form_one: Dictionary = player.combat_hand_settings.get("3:0", {}) as Dictionary
	var form_two: Dictionary = player.combat_hand_settings.get("3:7", {}) as Dictionary
	var bind_form: Dictionary = player.combat_hand_settings.get("3:9", {}) as Dictionary
	assert(not form_one.has("bind_enabled") and not form_two.has("bind_enabled"), "Preset operations must not write Bind fields into ordinary forms.")
	assert(bind_form.has("bind_enabled"), "Preset operations must preserve the canonical shared Bind Form values.")
	player.free()

func test_training_tuner_keeps_slide_shared_and_bind_controls_form_specific() -> void:
	var fake_main: Node = Node.new()
	add_child(fake_main)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	fake_main.add_child(player)
	player.set_physics_process(false)
	var menu: BackyardTrainingMenu = BackyardTrainingMenu.new()
	menu.main = fake_main
	fake_main.add_child(menu)
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	menu._sync_combat_controls()
	assert(not menu.experimental_bind_section.visible, "Bind controls must be hidden for non-Bind forms.")
	var slide_row: Dictionary = menu.contact_controls.get("slide_speed", {}) as Dictionary
	assert(not slide_row.is_empty(), "Shared Slide controls must exist independently from Bind controls.")
	assert((slide_row["slider"] as HSlider).visible, "Shared Slide controls must stay visible for every form.")
	player.sword_style = Player.SwordStyle.METRONOME_BIND
	menu._sync_combat_controls()
	assert(menu.experimental_bind_section.visible, "The Bind form must reveal its form-specific tuner.")
	for setting_key: String in Player.EXPERIMENTAL_BIND_SETTING_KEYS:
		if setting_key == "bind_debug":
			assert(not menu.hand_controls.has(setting_key), "The retired player-facing Bind readout must not have a visible control.")
			continue
		var row: Dictionary = menu.hand_controls.get(setting_key, {}) as Dictionary
		assert(not row.is_empty(), "Every Bind feel setting must have a live slider row: %s" % setting_key)
		var slider: HSlider = row["slider"] as HSlider
		assert(slider.tooltip_text.contains("← LEFT:") and slider.tooltip_text.contains("→ RIGHT:"), "The full slider hover area must explain both feel directions: %s" % setting_key)
	var source: String = FileAccess.get_file_as_string("res://scripts/ui/backyard_training_menu.gd")
	assert(not source.contains("Pressure %.0f | Tangent %.0f / Travel %.0f | Leverage %.2f"), "Detailed Bind evidence must not render in the player-facing tuner.")
	fake_main.free()
