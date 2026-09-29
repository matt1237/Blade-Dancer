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
	assert(shell.deviation_offset().is_equal_approx(Vector2.ZERO), "A shell sitting on its authored pose reports no deflection, so an untouched blade is never moved.")
	shell.global_transform = Transform2D(authored.get_rotation(), authored.origin + Vector2(400.0, -300.0))
	assert(is_equal_approx(shell.deviation_offset().length(), 500.0), "A 400 by -300 displacement is exactly 500 px. The old transform-composed form reported 724 px for a 39 px gap, and that error is what drew the sword off the hand and made a working leash look broken.")
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

func test_full_physical_makes_the_sword_a_body_and_drops_the_deflection_ceiling() -> void:
	var root: Node2D = Node2D.new()
	var player: Player = Player.new()
	root.add_child(player)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 0.0)
	player.set_combat_contact_setting("blade_shell_deflect_enabled", 0.0)
	player.set_combat_contact_setting("full_physical_enabled", 1.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.016)
	var shell: PhysicsShell = player.blade_shell
	assert(shell != null, "Full Physical on its own must create the blade's body: one switch turns the whole mode on.")
	assert(not shell.freeze and shell.springs_enabled, "The sword must be a real dynamic rigid body, not a pinned one.")
	# The body is thrown far off its authored pose by hand, then read out the way the pose stage
	# reads it. Bounded deflection must clamp that answer; Full Physical must not.
	var authored: Transform2D = player._blade_shell_transform(Vector2.ZERO, Vector2(84.0, 0.0))
	shell.global_transform = Transform2D(0.0, authored.origin + Vector2(400.0, 0.0))
	player.blade_shell_offset = Vector2.ZERO
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.05)
	var unrestricted: float = player.blade_shell_offset.length()
	player.set_combat_contact_setting("full_physical_enabled", 0.0)
	player.set_combat_contact_setting("blade_shell_deflect_enabled", 1.0)
	shell.global_transform = Transform2D(0.0, authored.origin + Vector2(400.0, 0.0))
	player.blade_shell_offset = Vector2.ZERO
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.05)
	var bounded: float = player.blade_shell_offset.length()
	assert(unrestricted > Player.BLADE_SHELL_MAX_OFFSET, "Full Physical must be knocked far harder than Deflection, not clamped into the same safe window.")
	assert(unrestricted <= Player.BLADE_SHELL_FULL_LEASH, "Full Physical must still be leashed: an unclamped sword settles 190 px off the hand, measured live, which is a flying sword.")
	assert(bounded <= Player.BLADE_SHELL_MAX_OFFSET, "Plain Deflection must still stay inside its ceiling.")
	assert(unrestricted > bounded, "The two modes must genuinely differ, or Full Physical adds nothing over Deflection.")
	root.free()

func test_full_physical_mirrors_the_whole_enemy_outline_instead_of_the_core() -> void:
	var host: Node2D = Node2D.new()
	var player: Player = Player.new()
	var enemy: Enemy = Enemy.new()
	host.add_child(enemy)
	enemy.player_ref = player
	var source: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 22.0
	source.shape = circle
	enemy.add_child(source)
	player.set_combat_contact_setting("bone_core_shell_enabled", 0.0)
	player.set_combat_contact_setting("full_physical_enabled", 0.0)
	enemy._update_bone_core_shell()
	assert(enemy.bone_core_shell == null, "With both enemy switches off there must be no body at all.")
	player.set_combat_contact_setting("bone_core_shell_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_core_size_percent", 35.0)
	enemy._update_bone_core_shell()
	var core_shell: PhysicsShell = enemy.bone_core_shell
	assert(core_shell != null and core_shell.get_child_count() == 1)
	assert(is_equal_approx(((core_shell.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius, 7.7), "The core shell must stay at the core size on its own switch.")
	player.set_combat_contact_setting("full_physical_enabled", 1.0)
	enemy._update_bone_core_shell()
	var full_shell: PhysicsShell = enemy.bone_core_shell
	assert(full_shell != null and full_shell.get_child_count() == 1)
	assert(is_equal_approx(((full_shell.get_child(0) as CollisionShape2D).shape as CircleShape2D).radius, 22.0), "Full Physical must mirror the enemy's whole visible outline, not the core.")
	assert(full_shell.collision_layer == PhysicsShell.BONE_CORE_SHELL_LAYER and full_shell.collision_mask == PhysicsShell.BLADE_SHELL_LAYER)
	assert(full_shell.max_deviation == PhysicsShell.CORE_SHELL_LEASH, "The core shell must be leashed, or a shove throws the bone 930 px away and the blade has nothing to meet for half a second.")
	assert(core_shell.max_deviation == PhysicsShell.CORE_SHELL_LEASH)
	player.set_combat_contact_setting("full_physical_enabled", 0.0)
	player.set_combat_contact_setting("bone_core_shell_enabled", 0.0)
	enemy._update_bone_core_shell()
	assert(enemy.bone_core_shell == null, "Both enemy switches off must take the body out of the world again.")
	host.free()
	player.free()

## Wall Block shares the same single swing-rate channel as Body Block and the core yield, so a
## wall, a body and a bone can never compound into a lock: the hardest ask of the frame wins.
## Blade Meets Bodies: the blade bites, then the body refuses to let it burrow. The push is zero
## while the blade is on or outside the surface and grows one-for-one past it, so a blade resting
## on a body is never moved and a driven-in blade is held out at the surface.
func test_body_surface_refuses_only_once_the_blade_has_burrowed() -> void:
	var outward: Vector2 = Vector2.RIGHT
	assert(HitReaction.body_surface_offset(30.0, 21.0, outward) == Vector2.ZERO, "A blade outside the surface is never moved.")
	assert(HitReaction.body_surface_offset(21.0, 21.0, outward) == Vector2.ZERO, "A blade exactly on the surface is never moved, so contact never snaps the pose.")
	assert(is_equal_approx(HitReaction.body_surface_offset(11.0, 21.0, outward).length(), 10.0), "The push is exactly how far past the surface the blade has been driven.")
	assert(HitReaction.body_surface_offset(11.0, 21.0, outward).normalized().is_equal_approx(outward.normalized()), "The push is straight back out along the surface normal, never sideways.")
	assert(HitReaction.BLADE_BODY_SURFACE_FRACTION < 1.0, "Body Surface holds the blade short of the enemy's own radius.")
	assert(HitReaction.BLADE_BODY_SURFACE_FRACTION > 0.55, "Body Surface sits further out than the normal bite's resting place, so turning it on makes the blade cut LESS deep, not more -- this is the bite-then-stop promise.")
	assert(is_equal_approx(HitReaction.BLADE_BODY_SURFACE_FRACTION, 0.75), "Body Surface sits at three quarters of the radius.")

## The shove only ever comes from a body genuinely closing on the blade, which is what makes an
## enemy walking into a held sword move it rather than pass through it.
func test_a_hard_shape_pushes_the_blade_out_by_exactly_how_far_in_it_is() -> void:
	# No allowance and no bite: a sample 5 px inside a wall comes back 5 px, along the normal.
	assert(HitReaction.hard_push_offset(Vector2.ZERO, Vector2(0.0, -5.0), Vector2(0.0, -1.0)) == Vector2(0.0, -5.0))
	# A sample merely NEAR the surface is pushed by nothing, so scenery the blade only brushes
	# against never repels it -- only being genuinely inside moves it.
	assert(HitReaction.hard_push_offset(Vector2.ZERO, Vector2(0.0, 5.0), Vector2(0.0, -1.0)) == Vector2.ZERO)
	# A degenerate normal is inert rather than explosive.
	assert(HitReaction.hard_push_offset(Vector2.ZERO, Vector2(3.0, 3.0), Vector2.ZERO) == Vector2.ZERO)

func test_a_bone_core_is_held_at_its_own_surface_with_no_allowance() -> void:
	# The live case that caught the original mistake. A limit of zero reads as "may sit anywhere",
	# which made the core rule a silent no-op -- the limit is the core's OWN radius, so a sample
	# 1.4 px from a turkey's centre with a 4.9 px core is pushed out to 3.5 px and cannot enter.
	var core_push: Vector2 = HitReaction.body_surface_offset(1.4, 4.9, Vector2.RIGHT)
	assert(is_equal_approx(core_push.x, 3.5), "A blade inside a bone core is held exactly on it.")
	# Flesh still bites: the same sample is pushed only to 0.75 of a body's radius, which is
	# further out than the core, so cutting happens first and the core is what refuses.
	var flesh_push: Vector2 = HitReaction.body_surface_offset(1.4, 14.0 * HitReaction.BLADE_BODY_SURFACE_FRACTION, Vector2.RIGHT)
	assert(is_equal_approx(flesh_push.x, 14.0 * 0.75 - 1.4), "Flesh keeps its bite, shallower than the surface.")
	# The core sits INSIDE the flesh, so the blade is allowed to rest between the two -- inside
	# the body, outside the bone. That is what leaves cutting intact while the core refuses.
	assert(14.0 * HitReaction.BLADE_BODY_SURFACE_FRACTION > 4.9, "The flesh surface sits outside the core, so a bite can reach bone without entering it.")

func test_bone_constraint_rejects_inward_motion_and_keeps_the_tangent() -> void:
	# The yo-yo rule, one dimension over. Hilt at the origin, the contact out to the right, and the
	# core ABOVE it, so the core's outward normal points down. Driving further up is illegal; the
	# part of that motion running along the core surface is not.
	var offset: Vector2 = Vector2(10.0, 0.0)
	var normal: Vector2 = Vector2(0.0, 1.0)
	var inward_only: Vector2 = Vector2(0.0, -4.0)
	assert(HitReaction.bone_constraint_angle(offset, inward_only, normal) > 0.0, "Inward motion becomes a rotation about the authored hilt.")
	# Motion that is purely away from the core is already legal and costs nothing at all.
	assert(is_equal_approx(HitReaction.bone_constraint_angle(offset, Vector2(0.0, 4.0), normal), 0.0), "Nothing is constrained when nothing is driven inward.")
	# Square on -- the contact lies along the normal, so no rotation about the hilt can move it off
	# the core at all. That is the bone stop's job, and it must not return an exploding angle.
	var square: Vector2 = Vector2(-4.0, 0.0)
	assert(is_equal_approx(HitReaction.bone_constraint_angle(Vector2(10.0, 0.0), square, square.normalized()), 0.0), "A square press has no tangent to resolve into.")

func test_bone_constraint_outward_angle_removes_penetration_but_not_a_square_press() -> void:
	var offset: Vector2 = Vector2(10.0, 0.0)
	# Core above, 3 px too deep: rotation carries the contact down and clear, so this is a real angle.
	assert(absf(HitReaction.bone_constraint_outward_angle(offset, Vector2(0.0, 1.0), 3.0)) > 0.0, "Residual penetration is rotated out.")
	# Square on, rotation cannot travel along the normal at all: decline rather than explode.
	assert(is_equal_approx(HitReaction.bone_constraint_outward_angle(offset, Vector2(-1.0, 0.0), 3.0), 0.0), "A square press is left to the bone stop, not to a solver.")
	assert(is_equal_approx(HitReaction.bone_constraint_outward_angle(offset, Vector2(0.0, 1.0), 0.0), 0.0), "No penetration means no correction.")

func test_body_shove_only_comes_from_a_body_closing_on_the_blade() -> void:
	var blade_ahead: Vector2 = Vector2(40.0, 0.0)
	assert(HitReaction.body_shove(Vector2(100.0, 0.0), blade_ahead, 0.35, 12.0).length() > 0.0, "A body moving towards the blade shoves it.")
	assert(HitReaction.body_shove(Vector2(-100.0, 0.0), blade_ahead, 0.35, 12.0) == Vector2.ZERO, "A body moving away from the blade never shoves it.")
	assert(HitReaction.body_shove(Vector2.ZERO, blade_ahead, 0.35, 12.0) == Vector2.ZERO, "A still body does not shove at all.")
	assert(HitReaction.body_shove(Vector2(1000.0, 0.0), blade_ahead, 0.35, 12.0).length() <= 12.0, "The shove is capped, so a charge punctuates the pose and never fires the sword away.")
	assert(is_equal_approx(HitReaction.body_shove(Vector2(100.0, 0.0), blade_ahead, 0.35, 12.0).length(), 12.0), "A fast body reaches the cap rather than exceeding it.")
	assert(is_equal_approx(HitReaction.body_shove(Vector2(20.0, 0.0), blade_ahead, 0.35, 12.0).length(), 7.0), "A slow body shoves in proportion to its speed.")

func test_wall_block_holds_the_swing_without_ever_locking_or_compounding() -> void:
	assert(is_equal_approx(HitReaction.wall_block_target(1.0), HitReaction.BLADE_WALL_BLOCK_RATE), "An unopposed swing is held to the wall's creep.")
	assert(HitReaction.BLADE_WALL_BLOCK_RATE > 0.0, "Wall Block is a creep and never a lock: the swing always finishes and releases.")
	assert(HitReaction.BLADE_WALL_BLOCK_RATE < HitReaction.BLADE_BODY_BLOCK_RATE, "A wall holds harder than a body does -- the player cannot make way for a wall.")
	assert(is_equal_approx(HitReaction.wall_block_target(0.2), HitReaction.BLADE_WALL_BLOCK_RATE), "A body's gentler 10% hold is tightened to the wall's own 5%: the wall always wins.")
	assert(is_equal_approx(HitReaction.wall_block_target(0.02), 0.02), "A harder pending rate is never loosened -- the wall only ever tightens.")
	assert(is_equal_approx(HitReaction.body_block_target(HitReaction.wall_block_target(1.0)), HitReaction.BLADE_WALL_BLOCK_RATE), "Chaining Body Block through Wall Block still lands on the wall: one channel, no stacking.")

func test_body_block_holds_the_swing_without_ever_locking_or_compounding() -> void:
	assert(HitReaction.BLADE_BODY_BLOCK_RATE > 0.0 and HitReaction.BLADE_BODY_BLOCK_RATE < 0.5, "A body block must be a stall, but never a full lock: the blade has to keep creeping forward or the player can be pinned on an enemy.")
	assert(is_equal_approx(HitReaction.body_block_target(1.0), HitReaction.BLADE_BODY_BLOCK_RATE), "A free swing inside a body must be held to the block rate.")
	assert(is_equal_approx(HitReaction.body_block_target(0.2), HitReaction.BLADE_BODY_BLOCK_RATE), "Body Block takes the harder of the two asks, so a milder core yield is overridden by the block rather than softening it.")
	assert(is_equal_approx(HitReaction.body_block_target(0.04), 0.04), "A harder ask than the block -- a lower rate -- survives it, so the two can never soften each other.")
	assert(is_equal_approx(HitReaction.body_block_target(HitReaction.BLADE_BODY_BLOCK_RATE), HitReaction.BLADE_BODY_BLOCK_RATE), "Re-applying the block must never compound, so a held swing cannot creep slower and slower.")

func test_blade_meets_the_world_only_when_asked() -> void:
	var root: Node2D = Node2D.new()
	var player: Player = Player.new()
	root.add_child(player)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 1.0)
	player.set_combat_contact_setting("blade_shell_world_enabled", 0.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.016)
	assert(player.blade_shell != null)
	assert(player.blade_shell.collision_mask == PhysicsShell.BONE_CORE_SHELL_LAYER, "With the world switch off, a blade shell must still mask cores only, so it can never catch on scenery.")
	player.set_combat_contact_setting("blade_shell_world_enabled", 1.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.016)
	assert(player.blade_shell.collision_mask == PhysicsShell.BLADE_SHELL_MASK_WITH_WORLD, "The world switch must add the terrain layer to the blade's mask.")
	assert((player.blade_shell.collision_mask & PhysicsShell.ENEMY_BODY_LAYER) == 0, "Ordinary enemy bodies stay out of it: the bone shells already own those.")
	assert(not player.blade_shell.freeze, "Asking the blade to meet the world also asks it to be driven rather than pinned, or a wall could never stop it.")
	player.set_combat_contact_setting("blade_shell_world_enabled", 0.0)
	player._update_blade_shell(Vector2.ZERO, Vector2(84.0, 0.0), 0.016)
	assert(player.blade_shell.collision_mask == PhysicsShell.BONE_CORE_SHELL_LAYER, "Turning the world switch off must return the mask to cores only.")
	player.free()
	root.free()

func test_shell_layers_are_named_in_the_project() -> void:
	assert(String(ProjectSettings.get_setting("layer_names/2d_physics/layer_7", "")) == "blade_shell")
	assert(String(ProjectSettings.get_setting("layer_names/2d_physics/layer_8", "")) == "bone_core_shell")
	assert(PhysicsShell.BLADE_SHELL_LAYER == 1 << 6, "The named layer and the shell's own bit must stay in step.")
	assert(PhysicsShell.BONE_CORE_SHELL_LAYER == 1 << 7)
	assert((PhysicsShell.BLADE_SHELL_LAYER & PhysicsShell.BONE_CORE_SHELL_LAYER) == 0, "The two shells must live on different layers.")