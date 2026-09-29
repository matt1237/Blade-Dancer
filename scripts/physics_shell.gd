class_name PhysicsShell extends RigidBody2D
## A rigid-body shell driven by a puppet.
##
## A shell exists so a hand-authored pose can meet the physics engine without the pose
## having to hand-author the collision response as well. The body is real -- the engine
## resolves contacts against it, so it can shove and be shoved -- but it never owns its own
## pose: a critically damped spring drags it back to whatever target its owner sets each
## physics tick. The authored pose therefore stays the only authority, and the solver's
## contribution is exactly the deviation from it.
##
## The spring is force based on purpose. Writing the transform directly would throw away the
## very contact response the body was created to produce. Only the push-only mode pins the
## transform, because there the shell is meant to be immovable.

const POSITION_STIFFNESS: float = 900.0
const POSITION_DAMPING: float = 42.0
const ANGLE_STIFFNESS: float = 260.0
const ANGLE_DAMPING: float = 22.0
## Bit for layer 7 ("blade_shell" in the project's layer names).
const BLADE_SHELL_LAYER: int = 1 << 6
## Bit for layer 8 ("bone_core_shell"). The two shells mask each other and nothing else, so
## a shell can never catch on terrain or on an enemy's ordinary body collision.
const BONE_CORE_SHELL_LAYER: int = 1 << 7
## Enemy bodies, for the contact query's fallback when no core shells exist yet.
const ENEMY_BODY_LAYER: int = 1 << 1

## The pose the owner wants this frame. Written by the owner inside its own _physics_process,
## which runs before the physics step, so the spring always chases the current frame's pose.
var target_transform: Transform2D = Transform2D.IDENTITY
## False in push-only mode: the shell is frozen and pinned to its target instead of springing
## toward it, so it drives the other body without ever yielding itself.
var springs_enabled: bool = true

func configure_shell(layer_bits: int, mask_bits: int, body_mass: float = 1.0) -> void:
	collision_layer = layer_bits
	collision_mask = mask_bits
	mass = body_mass
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	# The engine MUST keep integrating, because the spring is applied as a force in
	# _integrate_forces. A custom integrator would skip that integration and leave
	# apply_central_force with nothing to move the body at all -- so the spring is made the
	# only *force* instead: gravity and damping are neutral, and nothing else pushes the shell.
	custom_integrator = false

## Push-only: ride the target exactly and shove whatever is in the way, yielding nothing.
func set_push_only(enabled: bool) -> void:
	freeze = enabled
	if enabled:
		freeze_mode = FREEZE_MODE_KINEMATIC
	springs_enabled = not enabled

## Mirror a body's own collision shapes, scaled to the inner core, so the shell's solidity
## matches the maths boundary the rest of the blade logic already reasons about. Mirrors the
## shape support in the blade's own scaling, so a capsule-bodied enemy is not silently left
## without a core.
func build_mirrored_shapes(source_shapes: Array[CollisionShape2D], scale_factor: float) -> int:
	for existing: Node in get_children():
		# Removed from the tree immediately rather than only queued, so a rebuild never leaves
		# a stale shape standing next to the new one.
		remove_child(existing)
		existing.queue_free()
	var safe_scale: float = clampf(scale_factor, 0.05, 1.0)
	var built: int = 0
	for source: CollisionShape2D in source_shapes:
		if source == null:
			continue
		var scaled: Shape2D = _scaled_shape(source.shape, safe_scale)
		if scaled == null:
			continue
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.shape = scaled
		# The offset is mirrored rather than discarded: an enemy whose collision shape sits
		# off its own origin (a bird's body hangs below its head) needs its core in the same
		# place, or the solid bone would appear somewhere the blade never touches.
		shape_node.transform = source.transform
		add_child(shape_node)
		built += 1
	return built

func _scaled_shape(source: Shape2D, scale_factor: float) -> Shape2D:
	if source == null:
		return null
	var result: Shape2D = source.duplicate() as Shape2D
	if result is CircleShape2D:
		(result as CircleShape2D).radius *= scale_factor
	elif result is RectangleShape2D:
		(result as RectangleShape2D).size *= scale_factor
	elif result is CapsuleShape2D:
		var capsule: CapsuleShape2D = result as CapsuleShape2D
		capsule.radius *= scale_factor
		capsule.height *= scale_factor
	else:
		return null
	return result

## How far the solver has dragged this shell off the pose its owner authored. This is the
## entire output of the deflection feature: the puppet keeps its pose and the deviation is
## layered on as presentation.
func deviation_from_target() -> Transform2D:
	return global_transform * target_transform.affine_inverse()

func set_target(next_target: Transform2D) -> void:
	target_transform = next_target
	if freeze:
		# A frozen kinematic body is moved by us and collides along its path, which is what
		# lets the push-only shell shove a core with no spring involved at all.
		global_transform = next_target

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not springs_enabled:
		return
	var offset: Vector2 = target_transform.origin - state.get_transform().origin
	# F = k * offset - c * v gives a critically damped approach, so the shell returns to the
	# authored pose without ringing and never becomes a second authority over it.
	state.apply_central_force(offset * POSITION_STIFFNESS - state.get_linear_velocity() * POSITION_DAMPING)
	var angle_offset: float = wrapf(target_transform.get_rotation() - state.get_transform().get_rotation(), -PI, PI)
	state.apply_torque(angle_offset * ANGLE_STIFFNESS - state.get_angular_velocity() * ANGLE_DAMPING)