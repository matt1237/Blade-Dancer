class_name BDOSSwordSolverTest extends Node

var SHAPE: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(40, 0), Vector2(80, 0)])

class ReachProbe extends BDOSSwordSolver:
	var received_reach: float = -1.0
	func resolve(target_hilt: Vector2, target_angle: float, shape_points: PackedVector2Array, obstacles: Array[Dictionary], hand_center: Vector2, hand_reach: float) -> void:
		received_reach = hand_reach
		super.resolve(target_hilt, target_angle, shape_points, obstacles, hand_center, hand_reach)

func test_player_uses_hand_maximum_not_animated_grip_or_input_scale() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_hand_settings = player.combat_hand_settings.duplicate(true)
	player.combat_contact_settings = player.combat_contact_settings.duplicate(true)
	player.set_combat_hand_setting("min", 5.0)
	player.set_combat_hand_setting("max", 40.0)
	player.set_combat_hand_setting("scale", 4.0)
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("collision_sword_enabled", 1.0)
	var probe: ReachProbe = ReachProbe.new()
	player.collision_sword_solver = probe
	for phase: float in [0.0, 0.7, 1.8, 3.0]:
		player.sword_phase = phase
		player.combat_hand_radius = 5.0 + phase * 5.0
		player._advance_collision_sword_pose()
		assert(is_equal_approx(probe.received_reach, 40.0), "Animated preference/input gearing must not redefine the physical hand maximum.")
	player.free()

func test_stagger_advances_only_gated_collision_geometry() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_settings = player.combat_contact_settings.duplicate(true)
	player.set_combat_contact_setting("authored_metronome_enabled", 0.0)
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("collision_sword_enabled", 1.0)
	var probe: ReachProbe = ReachProbe.new()
	player.collision_sword_solver = probe
	player.hit_stagger_left = 1.0
	player._physics_process(1.0 / 60.0)
	assert(probe.received_reach >= 0.0, "Stagger must not leave the connected sword behind while the player moves.")
	assert(player.current_blade_samples == probe.world_points(), "Stagger rendering and hit geometry must agree.")
	assert(player.previous_blade_samples == player.current_blade_samples, "Recovery must not sweep an entire stagger as an attack.")
	probe.received_reach = -1.0
	player.set_combat_contact_setting("hit_reaction_enabled", 0.0)
	player._physics_process(1.0 / 60.0)
	assert(probe.received_reach == -1.0, "Master OFF must leave the legacy stagger path untouched.")
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("collision_sword_enabled", 0.0)
	player._physics_process(1.0 / 60.0)
	assert(probe.received_reach == -1.0, "Switch OFF must leave the legacy stagger path untouched.")
	player.free()

func test_fast_rotation_cannot_cross_blade_and_withdrawal_is_free() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(50, -30), "end": Vector2(50, 30), "radius": 2.0}]
	solver.resolve(Vector2.ZERO, deg_to_rad(-80), SHAPE, obstacles, Vector2.ZERO, 0.0)
	solver.resolve(Vector2.ZERO, deg_to_rad(80), SHAPE, obstacles, Vector2.ZERO, 0.0)
	assert(solver.blocked and not solver.contacts.is_empty(), "A blocked sweep must expose real contact.")
	assert(solver.angle < 0.0, "The blade must remain on its original side rather than tunnel to the safe far endpoint.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty())
	assert(solver.hilt == Vector2.ZERO, "Fixed hand reach forbids a detached sliding sword.")
	var stopped: float = solver.angle
	solver.resolve(Vector2.ZERO, deg_to_rad(-80), SHAPE, obstacles, Vector2.ZERO, 0.0)
	assert(solver.angle < stopped, "Withdrawal must not be magnetically held.")
	assert(is_equal_approx(solver.angle, deg_to_rad(-80)))

func test_contact_projection_preserves_translation_tangent() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var shape: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(40, 0)])
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(-100, 0), "end": Vector2(150, 0), "radius": 2.0}]
	solver.resolve(Vector2(0, -5), 0.0, shape, obstacles, Vector2.ZERO, 100.0)
	solver.resolve(Vector2(20, 5), 0.0, shape, obstacles, Vector2.ZERO, 100.0)
	assert(solver.blocked)
	assert(solver.hilt.x > 10.0, "An oblique request must preserve useful motion along the surface.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty(), "A slide must be checked before it is committed.")
	assert(solver.hilt.length() <= 100.0, "The same solve must respect hand reach.")

func test_reach_boundary_and_contact_keep_a_feasible_tangent() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(-100, 0), "end": Vector2(150, 0), "radius": 2.0}]
	solver.resolve(Vector2(0, -4.06), 0.0, SHAPE, obstacles, Vector2.ZERO, 4.06)
	solver.resolve(Vector2(3, -3), 0.05, SHAPE, obstacles, Vector2.ZERO, 4.06)
	assert(solver.hilt.x > 0.05, "Reach projection must not erase all feasible tangential movement.")
	assert(solver.hilt.length() <= 4.0601)
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty())

func test_roll_morph_resolves_residual_without_freezing_translation() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(-100, 0), "end": Vector2(150, 0), "radius": 2.0}]
	solver.resolve(Vector2(0, -4.06), 0.0, SHAPE, obstacles, Vector2.ZERO, 100.0)
	var curved: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(40, 5), Vector2(80, 0)])
	solver.resolve(Vector2(10, -4.06), 0.0, curved, obstacles, Vector2.ZERO, 100.0)
	assert(solver.hilt.x > 5.0, "An inward roll must not reject the independent tangential request.")
	assert(solver.local_blade[1].y > 1.0, "A feasible rolled shape should progress rather than silently lock.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty())

func test_circle_obstacle_uses_the_actual_shape_radius_and_transform() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 14.0
	var shape_transform: Transform2D = Transform2D(Vector2(2.0, 0.0), Vector2(0.0, 2.0), Vector2(10.0, 20.0))
	var obstacle: Dictionary = BDOSSwordSolver.circle_obstacle(7, "body", shape, shape_transform)
	assert(is_equal_approx(float(obstacle["radius"]), 28.0), "The body obstacle must use the CircleShape2D radius without a core fraction.")
	assert(obstacle["start"] == Vector2(10, 20) and obstacle["end"] == Vector2(10, 20), "The obstacle must preserve the actual collision shape transform.")

func test_straight_thrust_stops_at_full_body_circle_and_uses_last_resolved_pose() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(110, 0), "end": Vector2(110, 0), "radius": 14.0}]
	solver.resolve(Vector2.ZERO, 0.0, SHAPE, obstacles, Vector2.ZERO, 100.0)
	solver.resolve(Vector2(60, 0), 0.0, SHAPE, obstacles, Vector2.ZERO, 100.0)
	assert(solver.blocked)
	assert(solver.hilt.x < 15.0, "An axial thrust must stop at the actual 14px enemy body circle, not a reduced core.")
	var first: Vector2 = solver.hilt
	solver.resolve(Vector2(60, 0), 0.0, SHAPE, obstacles, Vector2.ZERO, 100.0)
	assert(solver.hilt.distance_to(first) < 1.1, "Repeating an impossible intent must not restart from or accumulate the authored endpoint.")
	solver.resolve(Vector2.ZERO, 0.0, SHAPE, obstacles, Vector2.ZERO, 100.0)
	assert(solver.hilt.distance_to(Vector2.ZERO) < 0.001)

func test_moving_body_depenetrates_a_resting_blade_and_curve_is_checked() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var none: Array[Dictionary] = []
	solver.resolve(Vector2.ZERO, 0.0, SHAPE, none, Vector2.ZERO, 30.0)
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(40, 0), "end": Vector2(40, 0), "radius": 6.0}]
	solver.resolve(Vector2.ZERO, 0.0, SHAPE, obstacles, Vector2.ZERO, 30.0)
	assert(solver.blocked and not solver.unresolved_overlap)
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty(), "An enemy entering a resting blade must not require swing speed to react.")
	var curved: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(40, 20), Vector2(80, 0)])
	var curve_obstacle: Array[Dictionary] = [{"id": 2, "start": Vector2(40, 20), "end": Vector2(40, 20), "radius": 2.0}]
	assert(not BDOSSwordSolver.deepest_contact(Vector2.ZERO, 0.0, curved, curve_obstacle).is_empty())
	assert(BDOSSwordSolver.deepest_contact(Vector2.ZERO, 0.0, SHAPE, curve_obstacle).is_empty(), "Curve geometry must not silently reduce to a straight hilt-tip chord.")

func test_hand_tether_does_not_teleport_through_a_blocker() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var shape: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(10, 0), Vector2(20, 0)])
	var obstacles: Array[Dictionary] = [{"id": 1, "start": Vector2(50, -1000), "end": Vector2(50, 1000), "radius": 2.0}]
	solver.resolve(Vector2(-100, 0), 0.0, shape, obstacles, Vector2(-100, 0), 0.0)
	# Deliberately incompatible: move the player across an impassable blade while
	# demanding zero hand reach. Report the conflict rather than teleporting the sword.
	solver.resolve(Vector2(100, 0), 0.0, shape, obstacles, Vector2(100, 0), 0.0)
	assert(solver.hilt.x < 50.0, "A reach correction must also be swept, not jump to the safe far endpoint.")
	assert(solver.unresolved_reach, "Impossible hand/collision constraints must be exposed.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty())

func test_setting_is_default_off_master_gated_and_restores_legacy_authority() -> void:
	var player: Player = Player.new()
	assert(player.get_combat_contact_setting("collision_sword_enabled") == 0.0)
	assert(player._sword_transform() == player._sword_intent_transform(), "Default OFF must return the original authored pose unchanged.")
	player.set_combat_contact_setting("collision_sword_enabled", 1.0)
	assert(not player.collision_sword_setting_on())
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_constraint_enabled", 1.0)
	assert(player.collision_sword_setting_on())
	assert(player.process_physics_priority == 100, "The BDOS solver must sample after ordinary enemy physics.")
	assert(not player._collision_sword_touched_weapon(123), "Proximity alone must not pre-empt the new contact authority.")
	player.collision_sword_solver = BDOSSwordSolver.new()
	player.collision_sword_solver.contacts.append({"id": -123, "kind": "blade"})
	assert(player._collision_sword_touched_weapon(123))
	assert(not player._collision_sword_touched_weapon(456))
	assert(not player.bone_constraint_setting_on(), "The old bone pose authority must not compete with the new one.")
	player.collision_sword_pose = {"start": Vector2(10, 20), "angle": 0.4, "arc_degrees": 50.0}
	assert(player._sword_transform()["start"] == Vector2(10, 20), "Render/gameplay getters must read the committed pose without advancing it.")
	player.set_combat_contact_setting("collision_sword_enabled", 0.0)
	assert(player.process_physics_priority == 0, "OFF must restore the original tick order.")
	assert(player.bone_constraint_setting_on(), "OFF restores the old option without rewriting its setting.")
	player.current_blade_samples = SHAPE.duplicate()
	player.previous_blade_samples = SHAPE.duplicate()
	assert(player._sword_transform() == player._sword_intent_transform())
	assert(player.collision_sword_pose.is_empty())
	assert(player.current_blade_samples.is_empty() and player.previous_blade_samples.is_empty(), "OFF must not turn the pose discontinuity into a phantom hit sweep.")
	assert(player._collision_sword_touched_weapon(456), "OFF restores the original proximity classifiers.")
	player.free()

class ChargingEnemyProbe extends Enemy:
	func _is_knockback_immune() -> bool:
		return true

func _body_contact(solver: BDOSSwordSolver) -> Dictionary:
	for contact: Dictionary in solver.contacts:
		if String(contact.get("kind", "")) == "body":
			return contact
	return {}

func test_solver_presses_inward_but_a_tangential_pass_pushes_nothing() -> void:
	var shape: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(40, 0)])
	var wall: Array[Dictionary] = [{"id": 1, "kind": "body", "start": Vector2(45, -1000), "end": Vector2(45, 1000), "radius": 2.0}]
	var inward: BDOSSwordSolver = BDOSSwordSolver.new()
	inward.resolve(Vector2(15, 0), 0.0, shape, wall, Vector2.ZERO, 200.0)
	var contact: Dictionary = _body_contact(inward)
	assert(not contact.is_empty(), "Pressing the blade into a body must register a body contact.")
	assert(float(contact["pressure"]) > 0.0, "An inward press must expose the depenetration pressure it resisted.")
	assert((contact["normal"] as Vector2).dot(Vector2.RIGHT) < 0.0, "The contact normal must oppose the inward direction so the push points away from the blade.")
	# Pure tangential travel beside the same surface never penetrates, so there is
	# no contact to convert into a push — sliding stays free.
	var tangential: BDOSSwordSolver = BDOSSwordSolver.new()
	tangential.resolve(Vector2(0, 60), 0.0, shape, wall, Vector2.ZERO, 200.0)
	assert(_body_contact(tangential).is_empty(), "A tangential pass with no penetration must not register a body to shove.")

func test_enemy_yields_along_the_normal_and_resists_by_weight() -> void:
	var light: Enemy = Enemy.new()
	light.grapple_weight = Enemy.GrappleWeight.LIGHT
	light.receive_collision_sword_push(Vector2(0, 1), 20.0)
	assert(light.knockback.length() > 0.0, "A pressed body must yield along the contact normal.")
	assert(light.knockback.normalized().dot(Vector2(0, 1)) > 0.99, "The yield must be along the normal, not the blade's tangential motion.")
	var light_yield: float = light.knockback.length()
	var heavy: Enemy = Enemy.new()
	heavy.grapple_weight = Enemy.GrappleWeight.HEAVY
	heavy.receive_collision_sword_push(Vector2(0, 1), 20.0)
	assert(heavy.knockback.length() < light_yield, "Heavier grapple weight must yield less to the same push.")
	var charging: ChargingEnemyProbe = ChargingEnemyProbe.new()
	charging.receive_collision_sword_push(Vector2(0, 1), 100.0)
	assert(charging.knockback == Vector2.ZERO, "A charging/knockback-immune enemy must refuse the collision-sword shove.")
	light.free()
	heavy.free()
	charging.free()

func test_collision_sword_off_never_shoves_or_retains_a_solver() -> void:
	var player: Player = load("res://scenes/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_settings = player.combat_contact_settings.duplicate(true)
	var enemy: Enemy = load("res://scenes/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + Vector2(30, 10)
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	solver.initialized = true
	solver.hilt = player.global_position
	solver.angle = 0.0
	solver.local_blade = SHAPE.duplicate()
	player.set_combat_hand_setting("max", 200.0)
	# Master OFF and switch OFF: no solve, no push.
	player.set_combat_contact_setting("hit_reaction_enabled", 0.0)
	player.set_combat_contact_setting("collision_sword_enabled", 0.0)
	var before_off: Vector2 = enemy.knockback
	player.collision_sword_solver = solver
	player._advance_collision_sword_pose()
	assert(player.collision_sword_solver == null, "OFF must clear the solver.")
	assert(enemy.knockback == before_off, "OFF must never move an enemy body.")
	# ON: the pressed body yields and the solver reports the contact.
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("collision_sword_enabled", 1.0)
	player.collision_sword_solver = solver
	solver.contacts.clear()
	player._advance_collision_sword_pose()
	assert(enemy.knockback.length() > 0.0, "An overlapping body must yield to the pressing blade when the solver is on.")
	assert(enemy.knockback.dot(Vector2.DOWN) > 0.0, "The yield must point away from the blade, into the body.")
	assert(not solver.contacts.is_empty(), "The solver must expose the body contact it pushed.")
	player.free()
	enemy.free()

func test_far_side_contact_bends_the_blade_around_the_body_by_rotation() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var shape: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(20, 0), Vector2(40, 0)])
	# A body sitting off the blade's line so the contact is far out along the blade and
	# roughly perpendicular: driving the tip into it must bend the blade, not shove the hand.
	var obstacles: Array[Dictionary] = [{"id": 1, "kind": "body", "start": Vector2(40, 20), "end": Vector2(40, 20), "radius": 10.0}]
	solver.resolve(Vector2.ZERO, 0.0, shape, obstacles, Vector2.ZERO, 60.0)
	var intent_angle: float = deg_to_rad(30.0)
	solver.resolve(Vector2.ZERO, intent_angle, shape, obstacles, Vector2.ZERO, 60.0)
	assert(solver.blocked, "Driving the tip into a body must register a contact.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty(), "The bent blade must end clear of the body.")
	assert(absf(angle_difference(solver.angle, intent_angle)) > deg_to_rad(5.0), "A far side contact must change the blade angle: the blade bends around the body.")
	# An axial thrust has no lever to rotate around, so it must still stop by translation
	# and stay axial -- the bend bias must never turn a straight thrust into a spin.
	var axial: BDOSSwordSolver = BDOSSwordSolver.new()
	var axial_obstacles: Array[Dictionary] = [{"id": 2, "kind": "body", "start": Vector2(70, 0), "end": Vector2(70, 0), "radius": 10.0}]
	axial.resolve(Vector2.ZERO, 0.0, shape, axial_obstacles, Vector2.ZERO, 200.0)
	axial.resolve(Vector2(60, 0), 0.0, shape, axial_obstacles, Vector2.ZERO, 200.0)
	assert(is_zero_approx(angle_difference(axial.angle, 0.0)), "An axial thrust must stay axial: no lever, no bend.")
	assert(axial.hilt.x < 20.0, "An axial thrust must still be stopped by translation before the body.")

func test_crowded_two_body_overlap_converges_without_committing_penetration() -> void:
	var solver: BDOSSwordSolver = BDOSSwordSolver.new()
	var obstacles: Array[Dictionary] = [
		{"id": 1, "kind": "body", "start": Vector2(20, 10), "end": Vector2(20, 10), "radius": 14.0},
		{"id": 2, "kind": "body", "start": Vector2(45, 10), "end": Vector2(45, 10), "radius": 14.0},
	]
	solver.resolve(Vector2.ZERO, 0.0, SHAPE, obstacles, Vector2.ZERO, 200.0)
	assert(not solver.unresolved_overlap, "A resolvable two-obstacle overlap must converge inside the finite projection budget.")
	assert(BDOSSwordSolver.deepest_contact(solver.hilt, solver.angle, solver.local_blade, obstacles).is_empty(), "No still-overlapping pose may be committed.")
