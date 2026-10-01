class_name HitReaction extends RefCounted
## Shared defaults and contact math for the per-preset Hit Reaction controls.
## Presentation, inner-core blade resistance, and live-overlap sink stay separate.
const DEFAULT_INNER_BONE_SIZE_PERCENT: float = 50.0
const DEFAULTS: Dictionary = {
	"hit_reaction_enabled": 0.0,
	"hit_visual_recoil": 7.0,
	"hit_visual_rotation": 7.0,
	"blade_physical_reaction_enabled": 0.0,
	"blade_physical_reaction_strength": 55.0,
	## Surfaced as "Bone Slide". OFF keeps the fixed phase-derived glance. ON gives the
	## core a weakened copy of the blade slide: the blade latches on it the way it latches
	## on an opposing blade, is held back for as long as the overlap lasts, and drags the
	## enemy with it. Steering round the bone, into it, or off it stays the player's hand.
	"blade_bone_slide_enabled": 0.0,
	## Surfaced as "Bone Slide Effect Strength". Scales how hard the slide's hold bites and
	## how much it drags the enemy: 0% leaves the switch inert, 100% is the authored slide.
	"blade_bone_slide_strength": 100.0,
	## Surfaced as "Bone Bind". The slide's heavier sibling: the blade must stay on the core
	## for a short capture before the lock takes, and the lock then holds the swing harder
	## than a slide and survives a brief gap before letting go. Deliberately weaker than a
	## real blade Bind -- its bound sword sits at 0.18, this lock at 0.22, the slide at 0.35
	## -- and bounded in time, so it can never become a pin.
	"blade_bone_bind_enabled": 0.0,
	## Surfaced as "Bone Bind Effect Strength". Scales the lock's hold and drag against the
	## enemy in 1% steps. Ships at 100%: the effect is already the weakened one, so the
	## switch reads as a real bind next to Bone Slide out of the box.
	"blade_bone_bind_strength": 100.0,
	## Surfaced as "Flesh Bind". OFF, flesh only takes its bite and slows the swing for a beat
	## (Blade Sink). ON, the blade gripping the meat becomes a real hold: the deeper it is buried
	## the heavier the swing goes and the enemy is dragged with it. The grip captures the instant
	## the blade meets flesh and sheds fast when the blade pulls out, so a deep catch is escaped by
	## ripping the blade back out, never by pushing through. Needs the Hit Reaction master; its own
	## channel, so it composes with the bone holds.
	"blade_flesh_bind_enabled": 0.0,
	## --- Physics shells: an engine-driven contact layer beneath the authored pose. ---
	## Surfaced as "Real Contact Normals". OFF keeps the hand-rolled geometric core test.
	## ON asks the physics space itself for the true contact -- real normal, real point and
	## the other body's actual velocity -- and hands those to the existing authored response
	## in place of its approximations. The blade is still posed by hand either way.
	"blade_shell_query_enabled": 0.0,
	## Surfaced as "Blade Shell". Gives the blade a frozen kinematic rigid-body shell that
	## rides the authored pose and shoves the enemy's bone core like a real solid, so the
	## core yields and spins out of the way. One-way: the blade cannot be turned by it.
	"blade_shell_shove_enabled": 0.0,
	## Surfaced as "Blade Deflection". The two-way shell: the blade's own shell is driven
	## toward the authored pose by force rather than pinned, so the bone pushes back and the
	## blade genuinely deflects off it. The deflection is bounded and eased, and layered on
	## top of the authored pose, so the sword can never be unshaped by it.
	"blade_shell_deflect_enabled": 0.0,
	## Surfaced as "Enemy Core Shells". The other half of the pair: gives every enemy's bone
	## core a rigid-body shell of its own, so the core can yield and rotate when the blade's
	## shell drives into it instead of being an unmovable maths boundary. Independent of the
	## blade switches -- with this OFF the blade shell simply has nothing to push. With all
	## four switches OFF no shell node is created at all, so the feature leaves no footprint.
	"bone_core_shell_enabled": 0.0,
	## Surfaced as "Full Physical". The blunt switch, and the only one that changes the blade's
	## authority instead of adding a bounded deviation underneath it: the sword becomes a real
	## rigid body whose contacts are not clamped, and every enemy mirrors its whole collision
	## silhouette as a solid rather than just the core, so the blade meets a body wherever the
	## outline the player can see actually is. One switch for the lot -- with it OFF, and the
	## four above OFF, not one body of this kind exists anywhere to be removed.
	"full_physical_enabled": 0.0,
	## Surfaced as "Body Block". The whole silhouette refuses the blade instead of only the
	## core: while the blade is genuinely inside a body the swing is held to a near-stall, so
	## an enemy reads as a wall the sword has to get through. Shares the core yield's single
	## swing-rate channel, so the two take the harder of the pair and never stack.
	"blade_body_block_enabled": 0.0,
	## Surfaced as "Blade Meets the World". Adds the terrain's collision layer to the blade
	## shell's mask, so a wall can stop the sword instead of it passing through the level.
	## Off, the shell masks cores only and can never catch on scenery.
	"blade_shell_world_enabled": 0.0,
	## Surfaced as "Blade Meets Walls". The authored version of the same idea, and the one that
	## actually holds: while the blade drives into the level the swing is held to a creep and the
	## blade turns aside along the surface, so a wall can never simply be cut through. Needs no
	## shell of any kind -- it is the pose authority refusing, not a body competing with it.
	"blade_wall_block_enabled": 0.0,
	## Surfaced as "Blade Meets Bodies". A body takes its bite, then refuses to let the blade
	## burrow: the drawn blade is pushed back out to the body's surface and shoved aside by the
	## body's own movement, so an enemy walking into a held sword moves it instead of passing
	## through it. Needs only the Hit Reaction master -- no shell, no Bone Slide.
	"blade_body_surface_enabled": 0.0,
	## Surfaced as "Hard Contact Clash". A hard shape -- the level, or an enemy's bone core -- is
	## never entered by the drawn blade at all: the blade is held exactly on its surface with no
	## allowance and is stopped with clash weight, so entering a hard shape is impossible rather
	## than merely discouraged. Visual and cadence only -- the hit model is untouched, so the bone
	## stop, core yield and bone slide still fire, which is what lets the blade be refused without
	## the bone rules dying. Needs only the Hit Reaction master.
	"blade_hard_clash_enabled": 0.0,
	## Surfaced as "Bone Slide Constraint". The architecture test: the bone core becomes a real
	## unilateral movement constraint, solved against the live blade every frame, instead of asking
	## a rigid body to do it and fighting the servo. Inward motion is rejected and the surviving
	## tangent becomes rotation about the authored hilt. Needs Hit Reaction on. While ON it owns the
	## blade-angle authority, so the bone glance, the wall glance and the shell angle stand down
	## rather than competing with it.
	"blade_bone_constraint_enabled": 0.0,
	## --- Contact recoil delay: hold a hit's separation so the contact is actually felt. ---
	## Surfaced as "Recoil Delay". OFF, a flesh hit separates on the same frame it lands -- the
	## enemy's gameplay knockback and the player's own recoil push both fire at once, so the contact
	## is over before it is felt. ON, both are held for Recoil Delay Time first, so the blade stays
	## against the body for a beat before anything moves. Pure timing: damage, stagger, blood,
	## hitstop and the sword's own kick all stay immediate. Independent of the shells.
	"contact_recoil_delay_enabled": 0.0,
	## Surfaced as "Recoil Delay Time". Seconds a flesh hit's separation is held before it fires.
	## 0 restores the instant separation. Tuned in 0.01 s steps.
	"contact_recoil_delay": 0.0,
	## Surfaced as "Bone Clash". OFF, catching an enemy's bone core is weight only -- a soft slow and
	## a halt, with no spectacle. ON, the catch also reads as a solid strike: a clash-weight halt, a
	## screen shake and the clash clang. Presentation only -- no pose is written and the cut model is
	## untouched -- and it adds only the lightest knockback, so hitting bone never punishes good aim.
	## Needs the Hit Reaction master; independent of every other shell switch.
	"bone_clash_enabled": 0.0,
	"blade_sink_enabled": 0.0,
	"blade_sink_strength": 45.0,
	"blade_sink_depth_percent": 70.0,
	## Surfaced as "Sword Stickiness": the single blade-hold duration authority, and
	## the ceiling the bone stop nests inside (see bone_stop_within_hold).
	"blade_sink_dwell_time": 0.10,
	"blade_bone_stop_enabled": 0.0,
	"blade_bone_stop_duration": 0.04,
	"blade_bone_stop_cooldown": 0.6,
	"blade_glance_angle_degrees": 10.0,
	"blade_core_yield_percent": 60.0,
	"sword_knockback_away_enabled": 0.0,
	"blade_bone_debug_enabled": 0.0,
	"blade_bone_core_size_percent": DEFAULT_INNER_BONE_SIZE_PERCENT,
	"hd_hit_squash_strength": 200.0,
	"blood_amount_percent": 100.0,
	"blood_drop_size_percent": 100.0,
	"blood_chance_percent": 60.0,
	"split_kill_chance_percent": 80.0,
}

const MAX_BLADE_SINK_SLOWDOWN: float = 0.9
## Blade Sink is the flesh-speed channel only: Depth is the ceiling slowdown
## reachable at full Strength, so 70% Depth + 100% Strength advances the live
## swing at 0.30 (a touch gentler than a Bind's 0.18 bound-sword speed).
const DEFAULT_BLADE_SINK_DEPTH_PERCENT: float = 70.0
const INNER_BONE_RADIUS_FRACTION: float = DEFAULT_INNER_BONE_SIZE_PERCENT / 100.0
const BONE_CONTACT_RESPONSE_SMOOTHING: float = 40.0
const BONE_RELEASE_RESPONSE_SMOOTHING: float = 16.0
const MINIMUM_BONE_REACTION_RATIO: float = 0.12
const MAX_BONE_RECOIL_RATIO: float = 0.7
const BROADSIDE_RECOIL_START: float = 0.82
## Contact-time slowdowns ease in and, crucially, ease back out so the un-bite is
## smooth instead of snapping the swing rate back in a single frame.
const BLADE_SINK_CONTACT_SMOOTHING: float = 40.0
const BLADE_SINK_RELEASE_SMOOTHING: float = 12.0
## The inner core yields as a gentle swing-rate cut, not a rotation: at full
## strength the live swing advances at this fraction while driving into the core.
## Much milder than a Bind's bound-sword speed, so the blade resists without stalling.
const BLADE_CORE_YIELD_FLOOR: float = 0.75
## Body Block's hold. Where the core yield is a gentle rate cut that deliberately never stalls,
## a body block is meant to read as a wall: the swing creeps at this fraction of its rate for as
## long as the blade is inside a body. A stall, but not a lock -- the blade always keeps
## advancing, so it can never pin the player or outlive the contact that caused it.
const BLADE_BODY_BLOCK_RATE: float = 0.10

## Body Block's whole contribution: take the harder of whatever is already asking to slow the
## swing and the block's own hold. One channel, so a body block and a core yield add up to the
## harsher of the two rather than compounding into a longer stall than either meant.
## Wall Block's own hold. A wall stops a swing harder than a body does, because a wall is
## something the player cannot make way for: the blade creeps at this fraction while it drives
## into the level. Still a creep and never a lock, so the swing always finishes and releases.
const BLADE_WALL_BLOCK_RATE: float = 0.05

## Wall Block's contribution on the same single swing-rate channel as Body Block and the core
## yield. The hardest ask of the frame wins, so a wall and a body and a bone can never compound
## into a lock -- they take the minimum, exactly as the other two do.
static func wall_block_target(current_pending: float) -> float:
	return minf(current_pending, BLADE_WALL_BLOCK_RATE)

## Surfaced as "Blade Meets Bodies". The bite in this game is deliberate: the blade is meant to
## sink in, because cutting flesh, the bone stop and the whole core model depend on it. So this
## is not a wall that never yields -- it is a body refusing to let the blade BURROW. The drawn
## blade is pushed back out to sit at this fraction of the enemy's radius from its centre, which
## is shallower than the normal bite's own resting place, and the body's motion is added as a
## shove on top. Bite first, then the body stops it.
const BLADE_BODY_SURFACE_FRACTION: float = 0.75

## Where the drawn blade should sit relative to a body, as a push straight back out along its own
## surface normal. Zero when the blade is already at or outside the surface, so a blade merely
## resting on a body is never moved at all; it grows one-to-one with how far past the surface the
## blade has been driven, which is what stops the burrow without ever snapping the pose.
static func body_surface_offset(blade_distance: float, surface_radius: float, outward: Vector2) -> Vector2:
	return outward * maxf(0.0, surface_radius - blade_distance)

## How much a moving body shoves the blade. Only an enemy genuinely closing on the blade pushes
## it, which is what makes a body walking into a held sword move it instead of passing through.
## Bounded, so a charging enemy can punctuate the pose but can never fire the sword away.
static func body_shove(enemy_velocity: Vector2, enemy_to_blade: Vector2, gain: float, maximum: float) -> Vector2:
	if enemy_velocity.length_squared() <= 1.0 or enemy_to_blade.length_squared() <= 0.0001:
		return Vector2.ZERO
	if enemy_velocity.normalized().dot(enemy_to_blade.normalized()) <= 0.0:
		return Vector2.ZERO
	return (enemy_velocity * gain).limit_length(maximum)

## Surfaced as "Hard Contact Clash". A hard shape -- the level, or an enemy's bone core -- is
## never entered by the drawn blade at all. The blade is held exactly on its surface and stopped
## with clash weight instead of easing through it. The bind time is how long the swing is held on
## that first contact, and the cooldown stops a blade pressed against a surface from re-triggering
## the clash on every single frame.
const BLADE_HARD_BIND_TIME: float = 0.08
const BLADE_HARD_CLASH_COOLDOWN: float = 0.22

## Pushes a blade sample out of a hard shape. The surface point is the closest point on that shape
## to the sample, so the return is exactly how far the sample sits INSIDE it, along the surface
## normal -- no allowance, no bite, nothing. Applied to the whole drawn pose this is what makes
## entering a hard shape impossible rather than merely discouraged.
static func hard_push_offset(sample: Vector2, surface_point: Vector2, normal: Vector2) -> Vector2:
	if normal.length_squared() <= 0.0001:
		return Vector2.ZERO
	var unit: Vector2 = normal.normalized()
	return unit * maxf(0.0, (surface_point - sample).dot(unit))

## Surfaced as "Bone Slide Constraint". The bone core is a HARD circle and the blade is a capsule, so
## the blade may never come nearer the core than "core radius + blade radius". Because the blade is
## anchored at the hilt, the illegal angles form ONE contiguous interval -- the shadow the core casts
## from the hand -- and its boundary IS the tangency, so stopping on it is what makes the blade slide
## along the bone instead of into it.
##
## The constraint is therefore a LIMIT ON MOVEMENT, not a correction of pose. The swing may rotate the
## blade only as far as the bone's surface this frame and no further: the blade is never jumped to a
## "nearest legal angle", it is only ever robbed of the movement that would have taken it inside. That
## difference is the whole design -- starting from where the blade actually IS means it can never be
## thrown across the bone, and holding the swing at a real tangency means the swing itself carries the
## blade around the core as the hand and the bone move.
##
## There is deliberately NO velocity term here. A velocity is a rotation RATE, and the only place to
## put it is the blade ANGLE, so adding it is how a solver ends up throwing the blade to the far side
## of the bone. Measured on the rig, the tangent runs along the blade's own axis at a tangency, which
## no rotation about the hilt can produce: the term was near zero where it should have mattered and
## large where it did damage.
const BONE_CONSTRAINT_EPSILON: float = 0.0001
## A blade that is not moving is not being constrained: a resting sword near an enemy is left
## entirely alone, so this never rotates a hanging blade and never shoves a hand that is merely close.
const BONE_CONSTRAINT_MIN_BLADE_SPEED: float = 24.0

## How far to either side of the core the bone casts its shadow as seen from the hilt: a blade long
## enough to lie ACROSS the bone is stopped where the bone grazes its side, while one that can only
## reach with its TIP is stopped where the tip comes to rest on the bone. Handling only the first of
## those is what once let a blade aimed straight at bone be treated as legal.
static func bone_core_half_angle(distance: float, blade_length: float, reach_radius: float) -> float:
	if distance <= BONE_CONSTRAINT_EPSILON:
		return PI
	if distance * distance - reach_radius * reach_radius <= blade_length * blade_length:
		return asin(clampf(reach_radius / distance, -1.0, 1.0))
	return acos(clampf((distance * distance + blade_length * blade_length - reach_radius * reach_radius) / (2.0 * distance * blade_length), -1.0, 1.0))

## The law, as one pure function. Given the angle the blade is ACTUALLY at ("previous_angle") and the
## angle the swing now wants ("wanted_angle"), return the furthest the blade may be allowed to travel
## toward that want. It never returns anything outside the two, so the blade can only ever lose
## movement, never gain it -- which is precisely "the bone may not be entered".
static func bone_core_clip(previous_angle: float, wanted_angle: float, hilt: Vector2, blade_length: float, core_center: Vector2, reach_radius: float) -> float:
	var to_core: Vector2 = core_center - hilt
	var distance: float = to_core.length()
	if distance <= reach_radius:
		# The hand itself is in the bone, so no angle at all is legal. Rotation cannot rescue that --
		# the hand is pushed out on its own channel -- so the swing is left alone here.
		return wanted_angle
	if distance - reach_radius > blade_length:
		return wanted_angle   # the bone is out of the blade's reach entirely
	var core_angle: float = to_core.angle()
	var half: float = bone_core_half_angle(distance, blade_length, reach_radius)
	var previous_offset: float = angle_difference(core_angle, previous_angle)
	var wanted_offset: float = angle_difference(core_angle, wanted_angle)
	if absf(previous_offset) < half:
		# The blade BEGINS this frame inside the bone, which is the first frame of contact. Rotation
		# can then only leave by the nearer side, so the pose is projected out -- exactly once, and
		# never across the bone.
		return core_angle + (half if wanted_offset >= 0.0 else -half)
	if absf(wanted_offset) < half:
		# The swing wants the blade inside the bone: stop it dead on the surface, on the side it came
		# from. That stopping point is the tangency the blade then slides along.
		return core_angle + signf(previous_offset) * half
	if previous_offset * wanted_offset < 0.0:
		# Both ends legal but on opposite sides means this step went straight through the bone. A
		# single frame cannot legitimately cross a core, so a crossing is refused rather than allowed.
		return core_angle + signf(previous_offset) * half
	return wanted_angle

## The whole core constraint, as one pure function: where the blade is anchored ("hilt"), where it
## points ("blade_angle"), how long it is, and a hard core circle whose "reach_radius" already allows
## for the blade's own radius. Returns the contact the blade rests on and the nearest LEGAL angle:
##   angle       the blade angle projected out of the core (identical when already legal)
##   point       the point on the blade that touches the bone
##   normal      the core's outward surface normal there
##   fraction    where along the blade that contact sits (0 = hilt, 1 = tip)
##   depth       how far inside the core the wanted pose was being pushed
##   contact     whether the blade genuinely touches the bone
##   hilt_inside true when the HAND is already in the bone, where no rotation can possibly help
static func bone_core_constraint(hilt: Vector2, blade_angle: float, blade_length: float, core_center: Vector2, reach_radius: float) -> Dictionary:
	var to_core: Vector2 = core_center - hilt
	var distance: float = to_core.length()
	var result: Dictionary = {
		"angle": blade_angle, "point": hilt, "normal": Vector2.ZERO, "fraction": 0.0,
		"depth": 0.0, "contact": false, "hilt_inside": false}
	if distance <= BONE_CONSTRAINT_EPSILON:
		result["point"] = core_center
		result["normal"] = Vector2.RIGHT
		result["depth"] = reach_radius
		result["contact"] = true
		result["hilt_inside"] = true
		return result
	if distance <= reach_radius:
		# The hand is already inside the bone. Rotating the blade cannot fix that -- only moving the
		# hand can -- so the pose is left alone and the caller is told to push the hand back out.
		result["normal"] = -to_core / distance
		result["depth"] = reach_radius - distance
		result["contact"] = true
		result["hilt_inside"] = true
		return result
	if distance - reach_radius > blade_length:
		return result   # the core is entirely out of the blade's reach
	var core_angle: float = to_core.angle()
	var offset: float = angle_difference(core_angle, blade_angle)
	var half: float = bone_core_half_angle(distance, blade_length, reach_radius)
	if absf(offset) < half:
		# Inside the core's shadow, so the wanted angle is illegal: project it onto the nearer
		# boundary. That boundary is the bone's surface, which is where the blade slides along.
		result["angle"] = core_angle + (half if offset >= 0.0 else -half)
	var settled_angle: float = float(result["angle"])
	var settled_along: float = clampf(distance * cos(angle_difference(core_angle, settled_angle)), 0.0, blade_length)
	var point: Vector2 = hilt + Vector2.RIGHT.rotated(settled_angle) * settled_along
	result["point"] = point
	var to_point: Vector2 = point - core_center
	result["normal"] = to_point.normalized() if to_point.length_squared() > BONE_CONSTRAINT_EPSILON else Vector2.RIGHT
	result["fraction"] = clampf(settled_along / maxf(blade_length, BONE_CONSTRAINT_EPSILON), 0.0, 1.0)
	var wanted_distance: float = bone_segment_core_distance(hilt, blade_angle, blade_length, core_center)
	var settled_distance: float = bone_segment_core_distance(hilt, settled_angle, blade_length, core_center)
	result["depth"] = maxf(0.0, reach_radius - wanted_distance)
	result["contact"] = settled_distance <= reach_radius + 1.0
	return result

## How near a blade pointing along "angle" from "hilt" comes to a core's centre. The nearest point of
## a segment is either the perpendicular foot, the tip, or (degenerately) the hilt itself, so this is
## the whole distance test the constraint needs -- it must answer for tip-on-bone as well as for a
## blade lying across the bone.
static func bone_segment_core_distance(hilt: Vector2, angle: float, blade_length: float, core_center: Vector2) -> float:
	var to_core: Vector2 = core_center - hilt
	var distance: float = to_core.length()
	if distance <= BONE_CONSTRAINT_EPSILON:
		return 0.0
	var offset_angle: float = angle_difference(to_core.angle(), angle)
	var along: float = distance * cos(offset_angle)
	if along <= 0.0:
		return distance
	if along >= blade_length:
		return (core_center - (hilt + Vector2.RIGHT.rotated(angle) * blade_length)).length()
	return distance * sin(absf(offset_angle))

## How far the hand must be pushed straight back out of a core it is standing inside. Zero whenever
## the hilt is already clear, which is the ordinary case, so a legal pose is never nudged.
static func bone_core_hilt_push(hilt: Vector2, core_center: Vector2, reach_radius: float) -> Vector2:
	var to_core: Vector2 = core_center - hilt
	var distance: float = to_core.length()
	if distance >= reach_radius or distance <= BONE_CONSTRAINT_EPSILON:
		return Vector2.ZERO
	return -to_core * ((reach_radius - distance) / distance)

static func body_block_target(current_pending: float) -> float:
	return minf(current_pending, BLADE_BODY_BLOCK_RATE)

static func value(settings: Dictionary, key: String) -> float:
	return float(settings.get(key, DEFAULTS.get(key, 0.0)))

## Probability (0..1) that a contact actually fires, given a visible max-chance
## slider and a hidden minimum-quality gate. The chance ramps from zero AT the
## gate up to the slider's ceiling at perfect contact (quality 1.0), so even a
## 100% ceiling still will not fire on every merely-qualifying hit.
static func contact_chance(max_percent: float, min_quality: float, quality: float) -> float:
	var ceiling: float = clampf(max_percent / 100.0, 0.0, 1.0)
	if ceiling <= 0.0:
		return 0.0
	if quality < min_quality:
		return 0.0
	if min_quality >= 1.0:
		return ceiling
	return ceiling * smoothstep(min_quality, 1.0, clampf(quality, 0.0, 1.0))

static func inner_bone_fraction(size_percent: float) -> float:
	return clampf(size_percent / 100.0, 0.0, 1.0)

static func blade_inner_bone_radius(outer_radius: float, size_percent: float = INNER_BONE_RADIUS_FRACTION * 100.0) -> float:
	return maxf(0.0, outer_radius) * inner_bone_fraction(size_percent)

static func scale_inner_bone_shape(outer_shape: Shape2D, size_fraction: float = INNER_BONE_RADIUS_FRACTION) -> Shape2D:
	if outer_shape == null:
		return null
	var scale_fraction: float = clampf(size_fraction, 0.0, 1.0)
	var inner_shape: Shape2D = outer_shape.duplicate() as Shape2D
	if inner_shape is CircleShape2D:
		var circle: CircleShape2D = inner_shape as CircleShape2D
		circle.radius *= scale_fraction
	elif inner_shape is RectangleShape2D:
		var rectangle: RectangleShape2D = inner_shape as RectangleShape2D
		rectangle.size *= scale_fraction
	elif inner_shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = inner_shape as CapsuleShape2D
		capsule.radius *= scale_fraction
		capsule.height *= scale_fraction
	else:
		return null
	return inner_shape

## A contact response is eligible only while the blade is driving inward across the inner-core boundary.
static func blade_physical_reaction_allowed(_is_stab_motion: bool, inward_alignment: float) -> bool:
	return inward_alignment > 0.02

static func advance_blade_physical_reaction(current_angle: float, pending_angle: float, delta: float) -> float:
	var smoothing: float = BONE_CONTACT_RESPONSE_SMOOTHING if absf(pending_angle) > absf(current_angle) else BONE_RELEASE_RESPONSE_SMOOTHING
	return lerpf(current_angle, pending_angle, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))

static func sword_knockback_direction(default_direction: Vector2, player_position: Vector2, target_position: Vector2, enabled: bool) -> Vector2:
	if not enabled:
		return default_direction
	var away_direction: Vector2 = player_position.direction_to(target_position)
	return away_direction if away_direction.length_squared() > 0.001 else default_direction

## Sink is a live contact-time rate only. Separation or either switch restores 1.0.
## Depth is the ceiling slowdown reachable at full Strength; Strength scales how
## much of that ceiling is used, so the two sliders stay independently tunable.
static func blade_sink_time_multiplier(master_enabled: bool, sink_enabled: bool, contact_active: bool, strength: float, depth_percent: float = DEFAULT_BLADE_SINK_DEPTH_PERCENT) -> float:
	if not master_enabled or not sink_enabled or not contact_active:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	var depth_ratio: float = clampf(depth_percent / 100.0, 0.0, 1.0)
	return 1.0 - depth_ratio * strength_ratio

## The bite ramps in on contact and eases back out after separation. The smoothed
## value is the live swing-rate multiplier, so release never snaps the cadence.
static func advance_blade_sink(current: float, target: float, delta: float) -> float:
	var smoothing: float = BLADE_SINK_CONTACT_SMOOTHING if target < current else BLADE_SINK_RELEASE_SMOOTHING
	return lerpf(current, target, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))

## Flesh Bind's grip captures the instant the blade meets flesh -- no candidate delay like the
## weapon bind -- so the throttle bites at once, and then sheds fast when the blade pulls out.
## Ripping free is how the swing comes back, so only the release is rate-limited: the caller's
## delta shapes the shed, never the capture.
const FLESH_BIND_RELEASE_RATE: float = 22.0
static func advance_flesh_bind_grip(current: float, target_depth: float, delta: float) -> float:
	var target: float = clampf(target_depth, 0.0, 1.0)
	if target >= current:
		return target
	if delta <= 0.0:
		return current
	return move_toward(current, target, FLESH_BIND_RELEASE_RATE * maxf(delta, 0.0))

## Option A: the bone stop nests INSIDE the Sword Stickiness hold budget rather
## than adding to it, so a core catch can never stack with the flesh tail into one
## long stall. The freeze is capped by the stickiness window - it may shorten the
## catch, but the blade is never held longer than a single budget. One knob, one
## hold: raise Sword Stickiness to keep the catch intact, lower it for a crisp cut.
static func bone_stop_within_hold(bone_stop_duration: float, stickiness: float) -> float:
	return clampf(minf(maxf(bone_stop_duration, 0.0), maxf(stickiness, 0.0)), 0.0, 0.30)

## Effect Strength dials one bone effect from inert to its authored full value. 0% must
## leave the blade completely untouched -- no hold, no drag -- and 100% must deliver
## exactly the tuned effect, so winding a new switch down is never worse than leaving it
## off. Out-of-range values clamp rather than overshoot.
static func scale_effect_strength(full_multiplier: float, strength_percent: float) -> float:
	var strength_ratio: float = clampf(strength_percent / 100.0, 0.0, 1.0)
	return lerpf(1.0, clampf(full_multiplier, 0.0, 1.0), strength_ratio)

## Target swing-rate multiplier for the inner core: 1.0 when the blade is not
## driving inward, easing toward the yielded floor as it presses deeper. The floor
## is the old 0.75 cap scaled by the Core Yield percent, so the slider only ever
## makes the continuous bone resistance gentler, never harsher.
static func blade_core_yield_target(strength: float, active: bool, inward_alignment: float, yield_percent: float = 100.0) -> float:
	if not active:
		return 1.0
	var strength_ratio: float = clampf(strength / 100.0, 0.0, 1.0)
	var yield_ratio: float = clampf(yield_percent / 100.0, 0.0, 1.0)
	var depth: float = clampf(inward_alignment, 0.0, 1.0)
	return 1.0 - (1.0 - BLADE_CORE_YIELD_FLOOR) * yield_ratio * strength_ratio * depth

static func advance_blade_core_yield(current: float, target: float, delta: float) -> float:
	var smoothing: float = BONE_CONTACT_RESPONSE_SMOOTHING if target < current else BONE_RELEASE_RESPONSE_SMOOTHING
	return lerpf(current, target, clampf(maxf(delta, 0.0) * smoothing, 0.0, 1.0))
