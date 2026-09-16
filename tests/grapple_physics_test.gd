class_name GrapplePhysicsTest extends Node

func test_slack_produces_no_force_and_tension_points_inward() -> void:
	var moving: Vector2 = Vector2(200.0, 0.0)
	var anchor: Vector2 = Vector2.ZERO
	assert(GrappleController.tension_acceleration(moving, anchor, 220.0, 1000.0) == Vector2.ZERO)
	var acceleration: Vector2 = GrappleController.tension_acceleration(moving, anchor, 150.0, 1000.0)
	assert(acceleration.x < 0.0 and absf(acceleration.y) < 0.001)

func test_tether_force_is_additive_and_preserves_tangent() -> void:
	var velocity: Vector2 = Vector2(0.0, 420.0)
	var acceleration: Vector2 = GrappleController.tension_acceleration(Vector2(200.0, 0.0), Vector2.ZERO, 150.0, 1000.0)
	var result: Vector2 = velocity + acceleration * 0.1
	assert(is_equal_approx(result.y, velocity.y), "Radial tension must preserve tangential speed.")
	assert(result.x < 0.0, "Tension must add inward velocity.")

func test_target_hand_motion_splits_tangent_and_outward_radial_yank() -> void:
	var target: Vector2 = Vector2.ZERO
	var hand: Vector2 = Vector2(200.0, 0.0)
	assert(GrappleController.target_hand_acceleration(target, hand, Vector2(0.0, 500.0), 5.0, 5.0, 0.8, false) == Vector2.ZERO, "Slack rope must not redirect a target.")
	var tangent_yank: Vector2 = GrappleController.target_hand_acceleration(target, hand, Vector2(0.0, 500.0), 5.0, 5.0, 0.8, true)
	assert(tangent_yank.y > 0.0 and absf(tangent_yank.x) < 0.001, "Tangential target motion must follow the hand without radial bias.")
	var outward_yank: Vector2 = GrappleController.target_hand_acceleration(target, hand, Vector2(500.0, 0.0), 5.0, 5.0, 0.8, true)
	assert(outward_yank.x > 0.0, "Moving the hand farther from a target must tighten the taut line and yank it.")
	var inward_motion: Vector2 = GrappleController.target_hand_acceleration(target, hand, Vector2(-500.0, 0.0), 5.0, 5.0, 0.8, true)
	assert(inward_motion.length() < 0.001, "Moving the hand toward a target must not push it away.")

func test_hand_motion_steers_player_and_outward_motion_boosts_pull() -> void:
	var hand: Vector2 = Vector2(200.0, 0.0)
	var anchor: Vector2 = Vector2.ZERO
	var steering: Vector2 = GrappleController.player_hand_acceleration(hand, anchor, Vector2(0.0, 300.0), 4.0, 2.5, true)
	assert(steering.y > 0.0 and absf(steering.x) < 0.001, "Tangential hand motion should offset the player's path around an anchor.")
	var outward_yank: Vector2 = GrappleController.player_hand_acceleration(hand, anchor, Vector2(300.0, 0.0), 4.0, 2.5, true)
	assert(outward_yank.x < 0.0, "Moving the hand away from an anchor must briefly increase pull toward it.")
	var inward_motion: Vector2 = GrappleController.player_hand_acceleration(hand, anchor, Vector2(-300.0, 0.0), 4.0, 2.5, true)
	assert(inward_motion.length() < 0.001, "Moving the hand toward an anchor must not create radial push.")

func test_hand_velocity_smoothing_caps_animation_and_dash_spikes() -> void:
	var smoothed: Vector2 = GrappleController.smoothed_velocity(Vector2.ZERO, Vector2(9000.0, 0.0), 16.0, 1.0 / 60.0, 1800.0)
	assert(smoothed.length() > 0.0 and smoothed.length() <= 1800.0, "Hand velocity should remain responsive but capped.")

func test_body_movement_transfer_separates_walking_from_authored_hand_motion() -> void:
	var world_hand_velocity: Vector2 = Vector2(500.0, 120.0)
	var body_velocity: Vector2 = Vector2(500.0, 0.0)
	assert(GrappleController.authored_hand_velocity(world_hand_velocity, body_velocity, 0.0) == Vector2(0.0, 120.0), "Zero transfer must remove ordinary body travel while preserving relative hand motion.")
	assert(GrappleController.authored_hand_velocity(world_hand_velocity, body_velocity, 1.0) == world_hand_velocity, "Full transfer must preserve the complete world-space hand signal.")
	assert(GrappleController.authored_hand_velocity(world_hand_velocity, body_velocity, 0.25) == Vector2(125.0, 120.0), "Intermediate transfer must scale only the body-motion contribution.")

func test_aimed_ground_endpoint_clamps_to_tether_range() -> void:
	var origin: Vector2 = Vector2(100.0, 100.0)
	assert(GrappleController.aimed_endpoint(origin, Vector2(300.0, 100.0), 640.0) == Vector2(740.0, 100.0), "Mouse distance should supply direction only; clear shots always use maximum range.")
	assert(GrappleController.aimed_endpoint(origin, Vector2(1100.0, 100.0), 640.0) == Vector2(740.0, 100.0))

func test_rope_slither_smoothly_disappears_under_tension() -> void:
	var firing_amplitude: float = GrappleController.rope_wave_amplitude(300.0, 0.0, true)
	var slack_amplitude: float = GrappleController.rope_wave_amplitude(24.0, 0.0, false)
	var half_taut_amplitude: float = GrappleController.rope_wave_amplitude(24.0, 0.5, false)
	var taut_amplitude: float = GrappleController.rope_wave_amplitude(24.0, 1.0, false)
	assert(firing_amplitude > 0.0 and slack_amplitude > half_taut_amplitude)
	assert(is_zero_approx(taut_amplitude))

func test_committed_reel_tuning_is_restored_and_independent_from_hand_response() -> void:
	var controller: GrappleController = GrappleController.new()
	assert(is_equal_approx(controller.reel_speed, 145.0))
	assert(is_equal_approx(controller.enemy_pull_strength, 1150.0), "Enemy reel strength must match the committed pre-hand-physics tuning.")
	assert(is_equal_approx(controller.chakram_tether_strength, 800.0), "Chakram reel strength must match the committed pre-hand-physics tuning.")
	assert(is_equal_approx(controller.medium_reel_multiplier, 1.0), "Default Medium reel must preserve the original enemy acceleration.")
	var enemy_reel: Vector2 = GrappleController.tension_acceleration(Vector2(200.0, 0.0), Vector2.ZERO, 150.0, controller.enemy_pull_strength, 8.0)
	var chakram_reel: Vector2 = GrappleController.tension_acceleration(Vector2(200.0, 0.0), Vector2.ZERO, 150.0, controller.chakram_tether_strength, 8.0)
	controller.light_yank_strength = 0.0
	controller.chakram_yank_strength = 0.0
	assert(enemy_reel == Vector2(-1150.0, 0.0), "Disabling hand response must leave exact original enemy reel acceleration.")
	assert(chakram_reel == Vector2(-800.0, 0.0), "Disabling hand response must leave exact original Chakram reel acceleration.")
	assert(controller.wall_pull_strength > controller.enemy_pull_strength)
	assert(controller.tension_ramp_distance <= 12.0, "Tension ramp must engage quickly.")
	assert(controller.yoyo_enabled, "The held Chakram Yo-yo must remain enabled by default.")
	controller.free()

func test_reeling_is_gradual_and_has_a_safe_minimum() -> void:
	assert(is_equal_approx(GrappleController.reeled_length(300.0, 100.0, 0.25), 275.0))
	assert(is_equal_approx(GrappleController.reeled_length(45.0, 100.0, 1.0), GrappleController.MIN_ROPE_LENGTH))

func test_yoyo_hang_requires_time_and_low_tangential_energy_before_reeling() -> void:
	assert(not GrappleController.yoyo_should_recall(0.5, 1.25, 0.0, 190.0), "Hang Time must prevent premature recall even when the orbit has stalled.")
	assert(not GrappleController.yoyo_should_recall(1.5, 1.25, 260.0, 190.0), "Strong tangential motion must sustain orbit after Hang Time.")
	assert(GrappleController.yoyo_should_recall(1.5, 1.25, 120.0, 190.0), "A spent orbit must enter recall after Hang Time.")

func test_grapple_cannot_accelerate_chakram_beyond_sword_hit_maximum() -> void:
	var chakram: Chakram = Chakram.new()
	chakram.sword_hit_speed_ceiling = 700.0
	chakram.velocity = Vector2(690.0, 0.0)
	chakram.apply_grapple_force(Vector2(2000.0, 1000.0), 0.1)
	assert(chakram.velocity.length() <= 700.001, "Grapple tension and hand yank must respect the sword-hit maximum speed.")
	assert(chakram.velocity.y > 0.0, "The cap must preserve grapple course redirection rather than discard it.")
	chakram.velocity = Vector2.ZERO
	assert(chakram.hit_by_player_sword(Vector2.RIGHT, Vector2(1000.0, 0.0), 1.0, 0.0, 380.0, 640.0))
	assert(is_equal_approx(chakram.sword_hit_speed_ceiling, 640.0) and is_equal_approx(chakram.velocity.length(), 640.0), "A sword bat must update the same authoritative ceiling used by grapple physics.")
	chakram.free()

func test_enemy_and_chakram_lasso_forces_add_to_existing_motion() -> void:
	var enemy: Enemy = Enemy.new()
	enemy.knockback = Vector2(20.0, 35.0)
	enemy.apply_grapple_force(Vector2(-100.0, 0.0), 0.1, INF, 0.125)
	assert(enemy.knockback == Vector2(10.0, 35.0))
	assert(enemy.grapple_slide_velocity == Vector2(-1.25, 0.0), "Light yank should retain a 12.5% off-balance slide tail.")
	var chakram: Chakram = Chakram.new()
	chakram.velocity = Vector2(0.0, 300.0)
	chakram.apply_grapple_force(Vector2(-200.0, 0.0), 0.1)
	assert(chakram.velocity == Vector2(-20.0, 300.0), "Lasso force should bend Chakram momentum additively rather than overwrite it.")
	enemy.free()
	chakram.free()

func test_rope_origin_uses_visible_sword_grip_not_body_center() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	player.global_position = Vector2(100.0, 100.0)
	player.aim_angle = 0.0
	player.virtual_aim_point = Vector2(400.0, 100.0)
	var hand_position: Vector2 = player.get_grapple_hand_position()
	assert(hand_position.distance_to(player.global_position) > 1.0)
	var sword_data: Dictionary = player._sword_transform()
	var direction: Vector2 = Vector2.RIGHT.rotated(float(sword_data["angle"]))
	var expected_grip: Vector2 = (sword_data["start"] as Vector2) - direction * Player.BLADE_HILT_INSET
	assert(hand_position.distance_to(expected_grip) < 0.001)
	player.free()

func test_enemy_grapple_weights_match_authored_defaults() -> void:
	var light_scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.GOBLIN_SCENE, WaveSpawner.BUG_SCENE, WaveSpawner.WOLF_SCENE]
	for scene: PackedScene in light_scenes:
		var light_enemy: Enemy = scene.instantiate() as Enemy
		add_child(light_enemy)
		assert(light_enemy.grapple_weight == Enemy.GrappleWeight.LIGHT, "Turkey/Bug/Goblin/Wolf should be Light grapple targets.")
		light_enemy.queue_free()
	var ogre: Ogre = WaveSpawner.OGRE_SCENE.instantiate() as Ogre
	add_child(ogre)
	assert(ogre.grapple_weight == Enemy.GrappleWeight.MEDIUM, "Ogre should be a Medium grapple target.")
	ogre.queue_free()

func test_chakram_grapple_extends_once_and_pauses_flight_timer() -> void:
	var chakram: Chakram = Chakram.new()
	chakram.time_left = 3.0
	chakram.on_grapple_attached()
	assert(chakram.grapple_attached, "Chakram must remember that it is tethered.")
	assert(is_equal_approx(chakram.time_left, 8.0), "Chakram grapple should add the same +5 seconds as a sword bat.")
	chakram.on_grapple_attached()
	assert(is_equal_approx(chakram.time_left, 8.0), "Repeated updates while attached must not keep adding flight time.")
	assert(is_equal_approx(Chakram.updated_flight_time(chakram.time_left, 1.0, true), 8.0), "Tethered Chakram countdown must pause.")
	chakram.on_grapple_detached()
	assert(is_equal_approx(Chakram.updated_flight_time(chakram.time_left, 1.0, false), 7.0), "Countdown must resume after grapple release.")
	chakram.free()

func test_grapple_reports_whether_a_real_hook_flight_started() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector2(100.0, 100.0)
	player.virtual_aim_point = Vector2(500.0, 100.0)
	var controller: GrappleController = player.get_node("GrappleController") as GrappleController
	var hand: Vector2 = player.get_grapple_hand_position()
	assert(not controller.fire_at(hand), "A zero-distance/rejected grapple must report failure.")
	assert(not controller.firing and not controller.active, "Rejected shots must not create grapple state.")
	assert(controller.fire_at(hand + Vector2(300.0, 0.0)), "A clear ground shot should report a real hook flight.")
	assert(controller.firing, "Successful grapple should enter hook-flight state.")
	player.queue_free()

func test_desktop_cooldown_waits_for_confirmed_grapple_flight() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var update_index: int = source.find("grapple_acceleration = grapple_controller.update_and_get_player_acceleration(grapple_held")
	var consume_index: int = source.find("if grapple_started and (grapple_controller.firing or grapple_controller.active)")
	assert(update_index >= 0 and consume_index > update_index, "Desktop must attempt the shot before consuming a charge/cooldown.")

func test_yoyo_limit_removes_only_outward_radial_motion() -> void:
	var at_limit: Vector2 = Vector2(100.0, 0.0)
	var incoming: Vector2 = Vector2(320.0, 240.0)
	var constrained: Vector2 = Chakram.yoyo_constrained_velocity(at_limit, incoming, Vector2.ZERO, 100.0, 40.0, 18.0, 0.0, 1.0 / 60.0)
	assert(absf(constrained.x) < 0.001, "A fully extended Yo-yo must not continue moving outward.")
	assert(is_equal_approx(constrained.y, incoming.y), "Full extension must preserve tangential velocity instead of stopping the Chakram.")
	var inward: Vector2 = Chakram.yoyo_constrained_velocity(at_limit, Vector2(-180.0, 240.0), Vector2.ZERO, 100.0, 40.0, 18.0, 0.0, 1.0 / 60.0)
	assert(is_equal_approx(inward.x, -180.0) and is_equal_approx(inward.y, 240.0), "The unilateral limit must allow free inward return motion.")

func test_yoyo_soft_zone_eases_radial_speed_before_the_limit() -> void:
	var incoming: Vector2 = Vector2(300.0, 120.0)
	var eased: Vector2 = Chakram.yoyo_constrained_velocity(Vector2(85.0, 0.0), incoming, Vector2.ZERO, 100.0, 40.0, 18.0, 0.0, 1.0 / 60.0)
	assert(eased.x > 0.0 and eased.x < incoming.x, "The soft zone should burn outward energy progressively rather than reverse it.")
	assert(is_equal_approx(eased.y, incoming.y), "Soft radial damping must not erase tangent motion.")

func test_chakram_consumes_configured_yoyo_constraint_before_movement() -> void:
	var chakram: Chakram = Chakram.new()
	chakram.global_position = Vector2(120.0, 0.0)
	chakram.velocity = Vector2(300.0, 240.0)
	chakram.sword_hit_speed_ceiling = 700.0
	chakram.configure_yoyo_constraint(Vector2.ZERO, 100.0, 40.0, 18.0, 0.0)
	chakram._apply_yoyo_constraint(1.0 / 60.0)
	assert(chakram.global_position.distance_to(Vector2.ZERO) <= 100.001, "Discrete movement cannot leave a tethered Chakram beyond its local line length.")
	assert(absf(chakram.velocity.x) < 0.001 and is_equal_approx(chakram.velocity.y, 240.0), "Projection must preserve the useful orbit component.")
	chakram.free()

func test_yoyo_wrap_path_uses_last_anchor_as_local_pivot() -> void:
	var hand: Vector2 = Vector2.ZERO
	var wrap: Vector2 = Vector2(60.0, 0.0)
	var chakram_position: Vector2 = Vector2(60.0, 80.0)
	assert(is_equal_approx(GrappleController.yoyo_path_length(hand, chakram_position, true, wrap), 140.0))
	assert(is_equal_approx(GrappleController.yoyo_local_rope_length(180.0, hand, true, wrap), 120.0), "The fixed inner rope segment must reduce the line available around the newest pivot.")
	var controller: GrappleController = GrappleController.new()
	assert(controller.yoyo_enabled)
	assert(controller.yoyo_state == GrappleController.YoyoState.NONE)
	controller.free()

func test_release_preserves_player_velocity() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	var controller: GrappleController = GrappleController.new()
	controller.player = player
	controller.active = true
	controller.target_type = GrappleController.TargetType.TERRAIN
	player.velocity = Vector2(275.0, -130.0)
	controller.release_tether()
	assert(player.velocity == Vector2(275.0, -130.0), "Release must not alter momentum.")
	assert(not controller.active and controller.terrain_release_slide_left > 0.0)
	controller.free()
	player.free()
