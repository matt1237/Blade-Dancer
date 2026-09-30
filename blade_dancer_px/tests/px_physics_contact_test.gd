extends Node

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")
const PXTestDummy = preload("res://blade_dancer_px/scripts/px_test_dummy.gd")


## Baseline: the sword is a real rigid body that meets a stationary test dummy
## instead of swatting it away. The dummy must not be launched, and the blade
## must not phase through it.
func test_sword_meets_a_stationary_dummy_without_swatting_it() -> void:
	var world: Node2D = Node2D.new()
	add_child(world)
	var grip: AnimatableBody2D = PXBlade.make_grip()
	world.add_child(grip)
	var sword: RigidBody2D = PXBlade.make_blade(world, Cfg.L_PLAYER_SWORD, Cfg.L_ENEMY)
	PXBlade.pin(world, grip, sword, Vector2.ZERO)
	var entry: Dictionary = PXTestDummy.make_entry(world, Vector2(60.0, 46.0))
	var dummy: CharacterBody2D = entry["body"] as CharacterBody2D
	assert(dummy != null, "The test dummy must be a stationary body, not a movable target.")
	var anchor: Vector2 = dummy.global_position
	var max_drift: float = 0.0
	for _frame: int in range(120):
		sword.apply_torque(PXBlade.pd_torque(sword.rotation, sword.angular_velocity, PI * 0.5, Cfg.DEFAULT_MOTOR_STIFFNESS, Cfg.DEFAULT_MOTOR_DAMPING, Cfg.DEFAULT_MAX_TORQUE))
		await get_tree().physics_frame
		max_drift = maxf(max_drift, dummy.global_position.distance_to(anchor))
	assert(max_drift < 2.0, "A stationary dummy must stay put; the blade works around it (drift %.1f px)." % max_drift)
	world.queue_free()
	await get_tree().process_frame
