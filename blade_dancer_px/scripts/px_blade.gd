extends RefCounted
## PX BLADE — builds a real rigid-body sword and drives it with a torque motor.
##
## THE RULE OF THIS FILE: a blade's POSE is never written. Its orientation is
## earned by torque and its collisions are resolved by the solver. If you are
## ever tempted to set a sword's transform, don't — that makes it kinematic and
## it will pass straight through walls and bodies.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")


## A blade body, pin-ready: the HILT sits at the body origin and the collision
## rectangle reaches BLADE_LENGTH along +X.
static func make_blade(parent: Node, layer: int, mask: int) -> RigidBody2D:
	var sword := RigidBody2D.new()
	sword.mass = 1.0
	sword.gravity_scale = 0.0
	sword.linear_damp = 0.0
	sword.angular_damp = 0.0
	sword.can_sleep = false
	sword.contact_monitor = true
	sword.max_contacts_reported = 8
	sword.collision_layer = layer
	sword.collision_mask = mask
	var slick: PhysicsMaterial = PhysicsMaterial.new()
	slick.friction = 0.0
	sword.physics_material_override = slick
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(Cfg.BLADE_LENGTH, Cfg.BLADE_THICKNESS)
	shape.shape = rect
	shape.position = Vector2(Cfg.BLADE_LENGTH * 0.5, 0.0)
	sword.add_child(shape)
	parent.add_child(sword)
	return sword


## A kinematic grip that carries the hilt without ever being a physical block.
static func make_grip() -> AnimatableBody2D:
	var grip := AnimatableBody2D.new()
	grip.collision_layer = 0
	grip.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 2.0
	shape.shape = circle
	grip.add_child(shape)
	return grip


## Bind a grip to a blade as a rigid pin. `at` MUST be the shared origin of both
## bodies: a joint created away from them bakes that gap into the constraint
## (the phantom hilt offset we chased for a while).
static func pin(parent: Node, grip: Node2D, blade: RigidBody2D, at: Vector2) -> PinJoint2D:
	var joint := PinJoint2D.new()
	joint.position = at
	joint.softness = 0.0
	joint.bias = 0.9
	joint.disable_collision = true
	parent.add_child(joint)
	joint.node_a = joint.get_path_to(grip)
	joint.node_b = joint.get_path_to(blade)
	return joint


## World position of the blade's tip.
static func tip_of(sword: RigidBody2D) -> Vector2:
	return sword.to_global(Vector2(Cfg.BLADE_LENGTH, 0.0))


## The PD motor: torque (N·m) chasing `target_angle`, clamped to `cap`.
static func pd_torque(current_angle: float, omega: float, target_angle: float, stiffness: float, damping: float, cap: float) -> float:
	var error: float = angle_difference(current_angle, target_angle)
	return clampf(error * stiffness - omega * damping, -cap, cap)