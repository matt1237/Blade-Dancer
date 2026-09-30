extends Node

## PX control-pass suite: the reference-following servo, the GP2 hand gearing,
## the hilt spring, the ghost, and their kill switches. Modules are bound through
## PRELOADED PATHS so this stays isolated from the game.

const PX_SCENE: PackedScene = preload("res://blade_dancer_px/scenes/px_game.tscn")
const PXGame = preload("res://blade_dancer_px/scripts/px_game.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")
const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const GlobalStore = preload("res://blade_dancer_px/scripts/bdpx_global.gd")


func _spawn() -> PXGame:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	return proto


## The blade must SHOVE a body it strikes, not wedge on it. Measured on a bare
## rigid body (not in proto.enemies, so nothing steers or respawns it) placed on
## the sweep axis — this isolates the raw physical push from enemy AI. A 6 kg body
## used to barely budge (~60 px) and read as "the sword gets stuck"; the lighter
## enemy settings must drive it well clear of the swing.
func test_the_blade_shoves_a_body_it_strikes() -> void:
	var backup: Variant = GlobalStore.load_settings() if GlobalStore.has_save() else null
	GlobalStore.clear_save()
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	proto._set_metronome_wanted(true)
	# Pin the aim to whatever direction the headless cursor settles on.
	proto.tuner.mouse_drag = 50.0
	proto.tuner.rotation_speed = 40.0
	for _i: int in range(40):
		await get_tree().physics_frame
	var aim: Vector2 = proto.aim_direction
	var rb := RigidBody2D.new()
	rb.mass = Cfg.ENEMY_MASS
	rb.gravity_scale = 0.0
	rb.linear_damp = Cfg.ENEMY_LINEAR_DAMP
	rb.angular_damp = Cfg.ENEMY_ANGULAR_DAMP
	rb.can_sleep = false
	rb.contact_monitor = true
	rb.max_contacts_reported = 8
	rb.collision_layer = Cfg.L_ENEMY
	rb.collision_mask = Cfg.L_WALLS | Cfg.L_PLAYER | Cfg.L_PLAYER_SWORD
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Cfg.ENEMY_RADIUS
	cs.shape = circle
	rb.add_child(cs)
	proto.add_child(rb)
	rb.global_position = proto.player.global_position + aim * 70.0
	var start: Vector2 = rb.global_position
	var max_move: float = 0.0
	var contacts: int = 0
	for _i: int in range(180):
		await get_tree().physics_frame
		max_move = maxf(max_move, rb.global_position.distance_to(start))
		contacts = maxi(contacts, rb.get_contact_count())
	assert(contacts > 0, "The blade must actually reach the body on the sweep axis.")
	assert(max_move > 90.0, "The swing must drive the body well clear, not wedge on it (moved %.1f px)." % max_move)
	proto.queue_free()
	await get_tree().process_frame
	GlobalStore.clear_save()
	if backup != null:
		GlobalStore.save_settings(backup as Dictionary)


# ── The servo ───────────────────────────────────────────────────────────────
func test_servo_feeds_forward_the_reference_speed() -> void:
	# At rest on target, a reference that is turning must still draw a torque.
	var moving: float = PXBlade.servo_torque(0.0, 0.0, 0.0, 5.0, 90000.0, 15000.0, 180000.0)
	assert(is_equal_approx(moving, 15000.0 * 5.0), "A moving target must pull the blade toward its speed (%.0f)." % moving)
	# Matching the reference speed exactly needs no help: the term is zero.
	var matched: float = PXBlade.servo_torque(0.0, 5.0, 0.0, 5.0, 90000.0, 15000.0, 180000.0)
	assert(is_zero_approx(matched), "Matching the reference speed must need no feed-forward torque.")
	# A still target is exactly the old PD motor.
	var still: float = PXBlade.servo_torque(0.3, 1.0, 0.0, 0.0, 90000.0, 15000.0, 180000.0)
	assert(is_equal_approx(still, PXBlade.pd_torque(0.3, 1.0, 0.0, 90000.0, 15000.0, 180000.0)), "A still target must reduce to plain PD.")
	# The cap still binds, so a collision can out-torque the servo.
	var capped: float = PXBlade.servo_torque(0.0, 0.0, 0.0, 100.0, 90000.0, 15000.0, 180000.0)
	assert(is_equal_approx(capped, 180000.0), "The servo must still be capped.")


# ── The hand gearing (GP2 "scale") ──────────────────────────────────────────
func test_reach_is_geared_not_linear() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	proto.player.global_position = Vector2.ZERO
	proto.tuner.hand_min = 5.0
	proto.tuner.hand_max = 30.0
	# Full extension only needs the cursor out at min + (max-min)*scale. Derive it
	# from the config so this test keeps tracking the GP2 "scale" it copies.
	var geared_limit: float = proto.tuner.hand_min + (proto.tuner.hand_max - proto.tuner.hand_min) * Cfg.REACH_SCALE
	assert(is_equal_approx(proto._hand_radius_from_point(Vector2(0.0, 0.0)), 5.0), "A cursor on the body must hug at the minimum.")
	assert(is_equal_approx(proto._hand_radius_from_point(Vector2(geared_limit, 0.0)), 30.0), "A cursor out at the geared limit (%.0f px) must reach the maximum." % geared_limit)
	# A cursor well short of the geared limit is BELOW the linear midpoint (gearing eases the reach in).
	var short_of: float = proto._hand_radius_from_point(Vector2(geared_limit * 0.4, 0.0))
	var linear_mid: float = lerpf(5.0, 30.0, 0.5)
	assert(short_of < linear_mid, "Gearing must ease the reach in below the linear midpoint (%.2f vs %.2f)." % [short_of, linear_mid])
	assert(short_of > 5.0, "The reach must still grow with cursor distance.")
	proto.queue_free()
	await get_tree().process_frame


# ── The reference / ghost ───────────────────────────────────────────────────
func test_the_ghost_is_the_pure_unleashed_arc() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	proto.aim_direction = Vector2.RIGHT
	proto.aim_angle = 0.0
	proto.tuner.arc_degrees = 90.0
	proto._set_metronome_wanted(true)
	# A quarter-turn of phase sits at the top of the sine: the arc is at full
	# amplitude, untouched by the anti-windup leash.
	proto.metronome_phase = PI * 0.5
	proto._advance_sword_target(0.0)
	assert(is_equal_approx(proto.reference_angle, deg_to_rad(90.0)), "The ghost must be the pure arc (+90 deg), not a leashed target (%.1f deg)." % rad_to_deg(proto.reference_angle))
	proto.queue_free()
	await get_tree().process_frame


func test_reference_omega_tracks_the_reference_angle() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	proto.reference_angle = 0.0
	proto._prev_reference_angle = 0.0
	proto._have_prev_reference = true
	proto.reference_angle = 0.5
	proto._update_reference_omega(0.5)
	assert(is_equal_approx(proto.reference_omega, 1.0), "Reference speed must be the change in reference angle over time (%.2f)." % proto.reference_omega)
	proto.queue_free()
	await get_tree().process_frame


# ── Kill switches ───────────────────────────────────────────────────────────
func test_the_new_toggles_kill_their_features() -> void:
	var proto: PXGame = _spawn()
	await get_tree().physics_frame
	# Servo feed-forward OFF must reduce the motor to the old plain PD behaviour.
	(proto.tuner._toggle_buttons["servo_feedforward_on"] as Button).button_pressed = false
	assert(not proto.servo_feedforward_on, "The servo toggle must switch the feed-forward off.")
	var off_torque: float = proto._motor_torque(proto.player_sword, 0.0, 5.0)
	var plain: float = PXBlade.pd_torque(proto.player_sword.rotation, proto.player_sword.angular_velocity, 0.0, proto.tuner.stiffness, proto.tuner.damping, proto.tuner.max_torque)
	assert(is_equal_approx(off_torque, plain), "With the servo off the motor must ignore the reference speed.")
	# Hilt spring ON must soften the pin; OFF must weld it rigid. Forced ON here so
	# this never depends on whatever a saved setup happened to leave behind.
	(proto.tuner._toggle_buttons["hilt_spring_on"] as Button).button_pressed = true
	await get_tree().physics_frame
	assert(proto.hilt_spring_on, "The hilt spring toggle must switch the spring on.")
	assert(is_equal_approx(proto.player_pin.softness, Cfg.HILT_SOFTNESS), "With the spring on the pin must be soft.")
	(proto.tuner._toggle_buttons["hilt_spring_on"] as Button).button_pressed = false
	await get_tree().physics_frame
	assert(is_equal_approx(proto.player_pin.softness, 0.0), "With the spring off the pin must be rigid.")
	# Ghost OFF must clear the flag.
	(proto.tuner._toggle_buttons["show_ghost"] as Button).button_pressed = false
	assert(not proto.show_ghost, "The ghost toggle must hide the overlay.")
	proto.queue_free()
	await get_tree().process_frame