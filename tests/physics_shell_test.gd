class_name PhysicsShellTest extends Node
## Physics Shells: the wiring around the shell bodies, and the promise that all four switches
## off leaves nothing behind.
##
## The spring itself is deliberately not asserted. 2D physics is explicitly non-deterministic,
## so nothing test-critical may depend on what the solver does with a body; what is asserted
## here is everything around it -- layers, masks, freeze modes, the authored pose a shell is
## handed, the core shape it mirrors, and the footprint when the switches are off. Whether a
## shell *reads* as solid is judged live in the training rig, never from an assert.

func test_all_shell_switches_off_create_no_blade_shell_and_remove_one_again() -> void:
	var root: Node2D = Node2D.new()
	var player: Player = Player.new()
	root.add_child(player)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 0.0)
	player.set_combat_contact_setting("blade_shell_deflect_enabled", 0.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(0.0, 84.0), 0.016)
	assert(player.blade_shell == null)
	assert(root.get_node_or_null("BladeShell") == null, "All shells off must create no shell body at all -- not an inert one, none.")
	player.set_combat_contact_setting("blade_shell_shove_enabled", 1.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(0.0, 84.0), 0.016)
	assert(player.blade_shell != null, "The Blade Shell switch must create the shell body.")
	var shell: PhysicsShell = player.blade_shell
	assert(shell.collision_layer == PhysicsShell.BLADE_SHELL_LAYER)
	assert(shell.collision_mask == PhysicsShell.BONE_CORE_SHELL_LAYER, "A blade shell may only ever collide with core shells, so the blade can never catch on terrain or on an ordinary enemy body.")
	assert(shell.freeze and shell.freeze_mode == PhysicsShell.FREEZE_MODE_KINEMATIC, "The push shell is frozen kinematic: it shoves, and is never shoved.")
	assert(shell.get_child_count() == 1 and (shell.get_child(0) as CollisionShape2D).shape is CapsuleShape2D)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 0.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(0.0, 84.0), 0.016)
	assert(player.blade_shell == null)
	var leftover: Node = root.get_node_or_null("BladeShell")
	assert(leftover == null or leftover.is_queued_for_deletion(), "Turning the last switch off must take the shell body out of the world again.")
	root.free()

func test_blade_deflection_supersedes_the_push_shell() -> void:
	var root: Node2D = Node2D.new()
	var player: Player = Player.new()
	root.add_child(player)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 1.0)
	player.set_combat_contact_setting("blade_shell_deflect_enabled", 1.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.016)
	var shell: PhysicsShell = player.blade_shell
	assert(shell != null)
	assert(not shell.freeze, "Deflection is the two-way mode, so with push and deflection both on the shell must be dynamic, not frozen.")
	assert(shell.springs_enabled)
	assert(not shell.custom_integrator, "The engine must integrate the spring; a custom integrator would leave a deflecting shell unmoved.")
	root.free()

func test_blade_shell_rides_the_authored_blade_and_reports_only_deviation() -> void:
	var player: Player = Player.new()
	var authored: Transform2D = player._blade_shell_transform(Vector2(10.0, 20.0), Vector2(10.0, 104.0))
	assert(authored.origin.is_equal_approx(Vector2(10.0, 62.0)), "The shell rides the midpoint of the swung blade.")
	assert(is_equal_approx(authored.get_rotation(), PI * 0.5), "And lies along it rather than across it.")
	var shell: PhysicsShell = PhysicsShell.new()
	shell.global_transform = authored
	shell.set_target(authored)
	assert(shell.deviation_from_target().origin.is_equal_approx(Vector2.ZERO), "A shell sitting on its authored pose reports no deflection, so an untouched blade is never moved.")
	shell.global_transform = Transform2D(authored.get_rotation(), authored.origin + Vector2(400.0, -300.0))
	assert(shell.deviation_from_target().origin.length() > 100.0, "What the solver actually did to the shell is exactly what the deflection feature reads out.")
	# Whatever the solver reports is bounded before it ever reaches the pose: a deflection may
	# punctuate a swing but must never be able to unshape the sword.
	assert(Player.BLADE_SHELL_MAX_OFFSET > 0.0 and Player.BLADE_SHELL_MAX_OFFSET <= 24.0, "The deflection ceiling must stay small; it is punctuation on an authored swing, not a second swing.")
	assert(Player.BLADE_SHELL_MAX_ANGLE > 0.0 and Player.BLADE_SHELL_MAX_ANGLE <= deg_to_rad(20.0), "The deflection ceiling must stay at or under the bone glance's safe 20 degrees.")
	shell.free()
	player.free()

func test_core_shell_mirrors_the_core_size_and_only_collides_with_the_blade() -> void:
	var shell: PhysicsShell = PhysicsShell.new()
	shell.configure_shell(PhysicsShell.BONE_CORE_SHELL_LAYER, PhysicsShell.BLADE_SHELL_LAYER)
	assert(shell.collision_layer == PhysicsShell.BONE_CORE_SHELL_LAYER)
	assert(shell.collision_mask == PhysicsShell.BLADE_SHELL_LAYER, "A core shell may only ever collide with the blade shell, so a shell can never shove an enemy against the world.")
	assert(shell.gravity_scale == 0.0 and not shell.can_sleep, "A shell must never fall, and never sleep out of its spring -- a sleeping body stops integrating.")
	assert(not shell.custom_integrator, "The engine must still integrate the spring's forces. A custom integrator would leave apply_central_force with nothing to move, which is exactly the bug this guards.")
	assert(shell.linear_damp == 0.0 and shell.angular_damp == 0.0)
	assert(shell.mass > 0.0)
	var circle_body: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 20.0
	circle_body.shape = circle
	circle_body.position = Vector2(0.0, -6.0)
	var circle_shapes: Array[CollisionShape2D] = [circle_body]
	assert(shell.build_mirrored_shapes(circle_shapes, 0.35) == 1)
	var mirrored: CollisionShape2D = shell.get_child(0) as CollisionShape2D
	assert(is_equal_approx((mirrored.shape as CircleShape2D).radius, 7.0), "The shell must be the same core size the blade logic already reasons about.")
	assert(mirrored.position.is_equal_approx(Vector2(0.0, -6.0)), "The core must sit where the body's own shape sits, or the solid bone would appear somewhere the blade never reaches.")
	# A capsule is what a boss and a training dummy use, and a capsule-bodied enemy must not be
	# silently left without a core.
	var capsule_body: CollisionShape2D = CollisionShape2D.new()
	var capsule: CapsuleShape2D = CapsuleShape2D.new()
	capsule.radius = 8.0
	capsule.height = 40.0
	capsule_body.shape = capsule
	var capsule_shapes: Array[CollisionShape2D] = [capsule_body]
	assert(shell.build_mirrored_shapes(capsule_shapes, 0.5) == 1)
	var capsule_mirror: CapsuleShape2D = (shell.get_child(0) as CollisionShape2D).shape as CapsuleShape2D
	assert(is_equal_approx(capsule_mirror.radius, 4.0) and is_equal_approx(capsule_mirror.height, 20.0))
	shell.free()

func test_a_deflection_is_layered_onto_the_pose_last() -> void:
	var player: Player = Player.new()
	player.blade_glance_angle = 0.1
	player.blade_bite_offset = Vector2(0.0, 5.0)
	player.blade_shell_offset = Vector2(3.0, 4.0)
	player.blade_shell_angle = 0.2
	var posed: Dictionary = player._apply_flesh_contact_pose({"angle": 0.0, "start": Vector2(10.0, 10.0)})
	assert(is_equal_approx(float(posed["angle"]), 0.3), "The deflection angle must be added on top of the bone glance, not replace it.")
	assert((posed["start"] as Vector2).is_equal_approx(Vector2(13.0, 19.0)), "The deflection offset must be added on top of the visible bite.")
	# And with every shell effect at zero the stage is a pure no-op, so a blade that was never
	# deflected is posed exactly as it was before this feature existed.
	player.blade_glance_angle = 0.0
	player.blade_bite_offset = Vector2.ZERO
	player.blade_shell_offset = Vector2.ZERO
	player.blade_shell_angle = 0.0
	var untouched: Dictionary = player._apply_flesh_contact_pose({"angle": 0.0, "start": Vector2(10.0, 10.0)})
	assert(is_equal_approx(float(untouched["angle"]), 0.0), "A blade that was never deflected must be posed exactly as it was.")
	assert((untouched["start"] as Vector2).is_equal_approx(Vector2(10.0, 10.0)))
	player.free()

func test_shell_layers_are_named_in_the_project() -> void:
	assert(String(ProjectSettings.get_setting("layer_names/2d_physics/layer_7", "")) == "blade_shell")
	assert(String(ProjectSettings.get_setting("layer_names/2d_physics/layer_8", "")) == "bone_core_shell")
	assert(PhysicsShell.BLADE_SHELL_LAYER == 1 << 6, "The named layer and the shell's own bit must stay in step.")
	assert(PhysicsShell.BONE_CORE_SHELL_LAYER == 1 << 7)
	assert((PhysicsShell.BLADE_SHELL_LAYER & PhysicsShell.BONE_CORE_SHELL_LAYER) == 0, "The two shells must live on different layers.")