class_name GrappleCoilContactTest extends Node

func test_coil_contact_is_armed_only_for_the_wrapped_enemy_after_one_turn() -> void:
	var chakram: Chakram = Chakram.new()
	chakram.configure_yoyo_constraint(Vector2.ZERO, 80.0, 20.0, 10.0, 0.0, 42, true)
	assert(chakram.yoyo_coil_contact_armed, "A completed coil may arm one wrapped-enemy contact.")
	assert(chakram.yoyo_coil_contact_enemy_id == 42)
	chakram.clear_yoyo_constraint()
	assert(not chakram.yoyo_coil_contact_armed, "Clearing the rope must clear the earned contact exception.")
	chakram.free()

func test_committed_coil_progresses_inward_and_unwinds_only_in_reverse() -> void:
	var inward: float = GrappleController.coil_progress(0.25, 100.0, 0.5, 200.0, false)
	assert(is_equal_approx(inward, 0.5), "Committed automation must advance by authored linear speed over path length.")
	var outward: float = GrappleController.coil_progress(inward, 100.0, 0.5, 200.0, true)
	assert(is_equal_approx(outward, 0.25), "Obstruction unwind must reverse the same normalized path without inventing rope payout.")
	var start: Vector2 = GrappleController.coil_position(Vector2.ZERO, 100.0, 30.0, 0.0, 1.0, 0.0)
	var captured: Vector2 = GrappleController.coil_position(Vector2.ZERO, 100.0, 30.0, 0.0, 1.0, 1.0)
	assert(is_equal_approx(start.length(), 100.0) and is_equal_approx(captured.length(), 30.0), "The authored spiral must finish at collision-safe capture radius.")
	var one_and_half_turn_capture: Vector2 = GrappleController.coil_position(Vector2.ZERO, 100.0, 30.0, 0.0, 1.0, 1.0, 1.5)
	assert(one_and_half_turn_capture.x < -29.9 and is_zero_approx(one_and_half_turn_capture.y), "One-and-a-half automated revolutions must visibly finish opposite the starting angle.")
	var defaults: Dictionary = GrappleController.default_tuning_state()
	assert(is_equal_approx(float(defaults["yoyo_coil_revolutions"]), 1.5))
	assert(float(defaults["yoyo_coil_tangential_speed"]) > float(defaults["yoyo_coil_radial_speed"]), "Committed coil must prioritize strong tangential travel over inward cinch.")

func test_successful_wrap_stuns_for_hold_and_begins_uncoil() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	var controller: GrappleController = player.grapple_controller
	controller.active = true
	controller.target_type = GrappleController.TargetType.CHAKRAM
	controller.yoyo_wrap_active = true
	controller.yoyo_wrap_object = enemy
	controller.yoyo_coil_phase = GrappleController.YoyoCoilPhase.DAMAGE_ARMED
	controller.yoyo_coil_committed_enemy_id = enemy.get_instance_id()
	controller.yoyo_coil_progress = 1.0
	controller.yoyo_coil_hold_duration = 1.25
	controller.notify_yoyo_coil_hit(enemy)
	assert(controller.yoyo_coil_phase == GrappleController.YoyoCoilPhase.HOLDING, "Impact must begin the timed uncoil hold.")
	assert(is_equal_approx(controller.yoyo_coil_hold_left, 1.25) and is_equal_approx(enemy.stun_left, 1.25), "Wrapped stun and visual duration must share the hold authority.")
	enemy.free()
	player.free()

func test_committed_placement_is_exact_for_chakram_and_enemy_targets() -> void:
	var controller: GrappleController = GrappleController.new()
	var chakram: Chakram = Chakram.new()
	add_child(chakram)
	chakram.velocity = Vector2(500.0, 0.0)
	controller._place_committed_target(chakram, Vector2(80.0, 40.0), 0.016)
	assert(chakram.global_position.is_equal_approx(Vector2(80.0, 40.0)) and chakram.velocity == Vector2.ZERO, "Committed Chakram placement must be exact and must not double-move through projectile physics.")
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.velocity = Vector2(200.0, 0.0)
	controller._place_committed_target(enemy, Vector2(120.0, 60.0), 0.016)
	assert(enemy.global_position.is_equal_approx(Vector2(120.0, 60.0)) and enemy.velocity == Vector2.ZERO, "A grappled enemy must use the same exact committed path authority.")
	enemy.free()
	chakram.free()
	controller.free()

func test_wrapped_hold_uses_direct_grapple_weight_authority() -> void:
	var player: Player = preload("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	player.global_position = Vector2.ZERO
	enemy.global_position = Vector2(200.0, 0.0)
	var controller: GrappleController = player.grapple_controller
	enemy.grapple_weight = Enemy.GrappleWeight.LIGHT
	var light_player_pull: Vector2 = controller._apply_enemy_grapple_response(enemy, 100.0, player.get_grapple_hand_position(), Vector2.ZERO, 0.1, controller.tension_ramp_distance)
	assert(light_player_pull == Vector2.ZERO and enemy.knockback.x < 0.0, "A wrapped Light target must reel toward the player without pulling the player.")
	enemy.knockback = Vector2.ZERO
	enemy.grapple_weight = Enemy.GrappleWeight.HEAVY
	var heavy_player_pull: Vector2 = controller._apply_enemy_grapple_response(enemy, 100.0, player.get_grapple_hand_position(), Vector2.ZERO, 0.1, controller.tension_ramp_distance)
	assert(enemy.knockback == Vector2.ZERO and heavy_player_pull.x > 0.0, "A wrapped Heavy target must remain stable and pull the player toward it.")
	enemy.free()
	player.free()

func test_obstruction_only_reverses_a_committed_coil() -> void:
	var controller: GrappleController = GrappleController.new()
	controller.yoyo_coil_phase = GrappleController.YoyoCoilPhase.TRACKING
	controller.notify_yoyo_obstruction_hit()
	assert(controller.yoyo_coil_phase == GrappleController.YoyoCoilPhase.TRACKING, "Contact before commitment must remain player-authored.")
	controller.yoyo_coil_phase = GrappleController.YoyoCoilPhase.COMMITTED
	controller.notify_yoyo_obstruction_hit()
	assert(controller.yoyo_coil_phase == GrappleController.YoyoCoilPhase.UNWINDING, "A committed coil obstruction must deterministically reverse out.")
	controller.free()
