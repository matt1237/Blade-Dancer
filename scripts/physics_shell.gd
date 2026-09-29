class_name PhysicsShell extends RigidBody2D
## A rigid-body shell driven by a puppet.
##
## A shell exists so a hand-authored pose can meet the physics engine without the pose
## having to hand-author the collision response as well. The body is real -- the engine
## resolves contacts against it, so it can shove and be shoved -- but it never owns its own
## pose: a velocity servo drags it back to whatever target its owner sets each physics tick.
## The authored pose therefore stays the only authority, and the solver's contribution is
## exactly the deviation from it.
##
## The drive is a velocity servo on purpose. Writing the transform directly would throw the
## contact response away, and merely pushing with a force lets a contact impulse accumulate
## until the body leaves for good. Asking for a velocity every step keeps both: the solver's
## shove is spent inside its own step and shows up as deviation from the authored pose, while
## the following step can only ever carry the body back at the servo's speed. Only the
## push-only mode pins the transform, because there the shell is meant to be immovable.

## The asked-for speed is this many px/s per px of gap. Tight enough that a hand-driven sword
## stays on its hand, loose enough that real contacts visibly move it.
const SERVO_GAIN: float = 22.0
## Ceiling on that asked-for speed, so even a deep overlap can only ever move the body so far in
## one step. This is what makes "my sword is gone, flying at a million miles an hour" impossible.
const MAX_SERVO_SPEED: float = 2400.0
const SPIN_GAIN: float = 14.0
## The angular half of the same guarantee.
const MAX_SERVO_SPIN: float = 20.0

## How far a contact may carry this shell from its target before it is snapped back to the
## leash's edge. 0 leaves it unlimited, which is right for the blade: its leash belongs on the
## drawn pose instead, because the sword may deviate further than it should ever visibly leave
## the hand. A shell whose excursion is never meant to be seen sets this.
var max_deviation: float = 0.0
## The core shell's leash. Measured live in the training rig a bone core was thrown 930 px and
## spent half a second getting back, during which the blade had nothing to meet -- and "rocks
## with the hit and recovers" is not the same thing as "disappears".
const CORE_SHELL_LEASH: float = 32.0
## Bit for layer 7 ("blade_shell" in the project's layer names).
const BLADE_SHELL_LAYER: int = 1 << 6
## Bit for layer 8 ("bone_core_shell"). The two shells mask each other and nothing else, so
## a shell can never catch on terrain or on an enemy's ordinary body collision.
const BONE_CORE_SHELL_LAYER: int = 1 << 7
## Terrain and scenery (layer 3, value 4): a level's walls, arena obstructions, chasm bounds and
## stage borders, as opposed to any moving body. Only ever added to the blade's mask when the
## player asks the blade to meet the world, which is the one case a shell may catch on scenery.
const WORLD_LAYER: int = 1 << 2
## The blade's mask with the world included. Ordinary enemy bodies (layer 2) are deliberately
## absent: the bone shells already own those, and carrying whole enemies is a separate change.
const BLADE_SHELL_MASK_WITH_WORLD: int = BONE_CORE_SHELL_LAYER | WORLD_LAYER
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
##
## Measured origin-to-origin. Composing the two transforms and reading the result's origin would
## fold the target's absolute position through the relative rotation instead: a shell 39 px from
## its target measured 724 px that way, and the error grows with distance from the world origin.
## That is a live-view bug, not a rounding error -- it drew the sword hundreds of pixels off the
## hand and made a working leash look broken.
func deviation_offset() -> Vector2:
	return global_position - target_transform.origin

## The angular half of the same deviation, as the shortest signed angle between the two bases.
## Rotations compose exactly, so this one was never wrong.
func deviation_angle() -> float:
	return wrapf(get_rotation() - target_transform.get_rotation(), -PI, PI)

func set_target(next_target: Transform2D) -> void:
	target_transform = next_target
	if freeze:
		# A frozen kinematic body is moved by us and collides along its path, which is what
		# lets the push-only shell shove a core with no spring involved at all.
		global_transform = next_target

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not springs_enabled:
		return
	# The speed is set outright rather than pushed toward with a force. A force lets a contact
	# impulse accumulate and the body leave for good, which is precisely what a hand-driven sword
	# pressed into a solid enemy does. Setting the speed every step spends the solver's shove
	# inside its own step: it still moves the body, and the deviation it produces is what the
	# pose stage reads, but it can never carry the body away.
	var offset: Vector2 = target_transform.origin - state.get_transform().origin
	if max_deviation > 0.0 and offset.length() > max_deviation:
		# Snapped back to the leash's edge rather than pulled toward it, so a shove bigger than
		# the leash is spent at once and the shell is never missing from where it belongs.
		offset = offset.normalized() * max_deviation
		state.transform = Transform2D(state.get_transform().get_rotation(), target_transform.origin - offset)
	state.linear_velocity = (offset * SERVO_GAIN).limit_length(MAX_SERVO_SPEED)
	var angle_offset: float = wrapf(target_transform.get_rotation() - state.get_transform().get_rotation(), -PI, PI)
	state.angular_velocity = clampf(angle_offset * SPIN_GAIN, -MAX_SERVO_SPIN, MAX_SERVO_SPIN)