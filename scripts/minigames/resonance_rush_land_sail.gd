class_name ResonanceRushLandSail extends CharacterBody2D

## The Land Sail — momentum-driven ground + grapple + glide controller.
##
## Deliberately does NOT use move_and_slide() against the course. Canonical
## authored worlds retain a track ID plus baked arc-length progress while
## grounded, allowing stacked surfaces, backward-running curves, and loops.
## Legacy height-field scenes remain supported as a temporary fallback.
##
## Flow: GROUND -> (ramp end / mushroom bounce) -> AIR -> (grapple fired) ->
## GRAPPLE -> (release) -> AIR -> (hold glide) -> GLIDE -> (land) -> GROUND.

signal altitude_changed(altitude_m: float)
signal state_changed(state_name: String)
signal fell_off_course()

enum State { GROUND, AIR, GRAPPLE, GLIDE }

@export_category("Ground Movement")
@export var acceleration: float = 900.0
@export var max_ground_speed: float = 640.0
## Lowered from an earlier, harsher default — momentum-driven ground travel
## should coast, not bleed speed the instant you let off the accelerator.
@export var ground_friction: float = 220.0
@export var reverse_brake_strength: float = 700.0
## How strongly slope angle steals/adds speed, Sonic-style.
@export var slope_gravity_scale: float = 1.0
@export var initial_ground_speed: float = 260.0
@export var ground_clearance: float = 18.0

@export_category("Air")
@export var gravity: float = 1450.0
@export var air_control: float = 260.0
## Extra vertical boost automatically applied when leaving a steep ramp.
@export var jump_impulse: float = 260.0
## Manual jump impulse — Space bar while grounded. Separate from jump_impulse
## (the automatic ramp-launch boost) so the two can be tuned independently.
@export var manual_jump_impulse: float = 480.0
@export var vehicle_weight: float = 1.0
## Fraction of speed kept when landing after an aerial sequence.
@export var momentum_retention: float = 0.94
## Briefly ignore the track just left so a jump/ramp launch cannot snap back.
@export var track_detach_ignore_seconds: float = 0.16

@export_category("Grapple")
## Roughly 1.75x the 160 px Land Sail artwork length (halved from an earlier,
## too-generous range).
@export var grapple_max_range: float = 280.0
@export var grapple_rope_length_max: float = 280.0
## Visible hook-tip travel speed; max-range shots take about 0.19 seconds.
@export var grapple_projectile_speed: float = 1500.0
## Gravity contribution while attached to the rope.
@export var grapple_strength: float = 2.4
## A/D applies continuous angular torque: A counter-clockwise, D clockwise.
@export var grapple_pump_acceleration: float = 920.0
@export var grapple_max_swing_speed: float = 1250.0
## Kept very close to 1.0 so deliberately pumped swing speed survives.
@export var swing_damping: float = 0.9994
@export var release_momentum_multiplier: float = 1.3
@export var grapple_aim_tolerance_degrees: float = 65.0
## W/S reels the rope in/out while attached — W shortens (climb closer),
## S lengthens (drop lower), clamped to [25%, 100%] of grapple_rope_length_max.
@export var grapple_reel_speed: float = 220.0
@export var show_grapple_range_debug: bool = false

@export_category("Glide")
@export var glide_duration: float = 5.0
## Lift applied while holding the opposite direction to travel.
@export var glide_lift: float = 620.0
## Drag applied while gliding.
@export var glide_drag: float = 40.0
## Forward acceleration while diving in the travel direction.
@export var dive_acceleration: float = 900.0
@export var max_glide_speed: float = 900.0
## Converts forward momentum while pulling up into lift.
@export var upward_conversion: float = 0.45
## Fraction of full glide_duration recharged per second while not gliding.
@export var glide_recharge_rate: float = 0.6

@export_category("Glide Transformation")
## Time for the upright land sail to hinge upward into its broad glider form.
@export var glider_deploy_seconds: float = 0.28
## Folding is slightly quicker so cancelling glide remains immediate and clear.
@export var glider_fold_seconds: float = 0.2
@export var glider_deployed_scale: float = 1.08
@export var glider_flip_degrees: float = 78.0
@export var glider_flutter_amount: float = 0.015

@export_category("Style")
@export var trick_spin_speed_degrees: float = 380.0
@export var quick_twirl_duration: float = 0.35
## A quick tap of A/D in the air gives a small, weak lean; holding it ramps
## up to the full spin speed over this many seconds — keeps a light air-steer
## tap from looking/feeling like an out-of-control barrel roll.
@export var trick_spin_ramp_up_seconds: float = 0.5
## How eagerly the sail's visual pitch banks to face its own velocity while
## gliding — separate from the trick-spin rotation used in plain AIR state.
@export var glide_bank_smoothing: float = 8.0

@export_category("Mushroom Bounce")
@export var mushroom_bounce_impulse: float = 780.0
@export var mushroom_min_forward_speed: float = 420.0

@export_category("Altitude")
@export var meters_per_pixel: float = 0.5

@onready var sprite: Sprite2D = $Sprite2D
@onready var glider_sprite: Sprite2D = $GliderSprite
@onready var grapple_line: Line2D = $GrappleLine
@onready var grapple_tip: Polygon2D = $GrappleTip
@onready var bounce_detector: Area2D = $BounceDetector
@onready var glide_trail: Line2D = $GlideTrail

var terrain: ResonanceRushTerrain = null
## True when `terrain` is a ResonanceRushTrackWorld (multi-surface authored
## world). Ground movement then follows (track_id, arc-length progress)
## instead of the legacy one-y-per-x height-field query.
var track_mode: bool = false
var current_track_id: int = -1
var current_track_progress: float = 0.0
var last_safe_track_id: int = -1
var last_safe_track_progress: float = 0.0
## Track just left (via jump/ramp/fall) is ignored by find_landing() for a
## short window so an upward launch cannot immediately re-snap to it.
var track_detach_timer: float = 0.0
var track_detach_ignored_id: int = -1
var state: State = State.GROUND
var ground_speed: float = 0.0
var slope_angle: float = 0.0
var glide_energy: float = 0.0
var grapple_anchor: Vector2 = Vector2.ZERO
var grapple_rope_length: float = 0.0
var grapple_point_active: Node2D = null
var grapple_shot_active: bool = false
var grapple_shot_target: Node2D = null
var grapple_tip_position: Vector2 = Vector2.ZERO
var last_safe_position: Vector2 = Vector2.ZERO
var last_safe_speed: float = 0.0
var visual_rotation: float = 0.0
var quick_twirl_time_left: float = 0.0
var start_y: float = 0.0
var altitude_m: float = 0.0
## Tracks how long the current air-steer direction has been held, for the
## tap-vs-hold trick-spin ramp described above.
var air_steer_hold_direction: float = 0.0
var air_steer_hold_time: float = 0.0
var glide_trail_points: PackedVector2Array = PackedVector2Array()
## 0 = upright land-sail artwork, 1 = fully opened overhead glider artwork.
## Driving this blend every frame makes deployment reversible if Space is
## tapped during the flip instead of locking the controller inside a Tween.
var glide_form_blend: float = 0.0

func _ready() -> void:
	bounce_detector.area_entered.connect(_on_bounce_detector_area_entered)
	grapple_line.visible = false
	grapple_tip.visible = false
	glide_trail.visible = false
	glider_sprite.visible = false

func begin_at(course_start: Vector2) -> void:
	global_position = course_start
	start_y = course_start.y
	last_safe_position = course_start
	ground_speed = initial_ground_speed
	last_safe_speed = ground_speed
	velocity = Vector2(ground_speed, 0.0)
	track_mode = terrain != null and terrain.has_method("is_track_world")
	if track_mode:
		var start_contact: Dictionary = terrain.get_start_contact()
		current_track_id = start_contact.get("track_id", -1)
		current_track_progress = start_contact.get("progress", 0.0)
		last_safe_track_id = current_track_id
		last_safe_track_progress = current_track_progress
		track_detach_timer = 0.0
		track_detach_ignored_id = -1
	state = State.GROUND
	glide_energy = glide_duration
	grapple_shot_active = false
	grapple_shot_target = null
	if grapple_line != null:
		grapple_line.visible = false
	if grapple_tip != null:
		grapple_tip.visible = false
	glide_form_blend = 0.0
	if glider_sprite != null:
		glider_sprite.visible = false
		glider_sprite.modulate.a = 0.0
	if sprite != null:
		sprite.modulate.a = 1.0
	state_changed.emit("GROUND")

func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	match state:
		State.GROUND: _process_ground(delta)
		State.AIR: _process_air(delta)
		State.GRAPPLE: _process_grapple(delta)
		State.GLIDE: _process_glide(delta)
	if grapple_shot_active:
		_process_grapple_projectile(delta)
	_process_common(delta)
	_update_altitude()
	_update_visual(delta)

func _horizontal_input() -> float:
	var right: float = 1.0 if (Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) else 0.0
	var left: float = 1.0 if (Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)) else 0.0
	return right - left

## Absolute elevator-style pitch control, like a standard flight/glide game:
## A always pitches the nose up, D always pitches it down — regardless of
## which way you're currently traveling. Rotation direction is therefore
## constant, so holding one key continuously sweeps through a full 360° loop
## instead of reversing meaning the moment you're flying "backward".
func _glide_pitch_input() -> float:
	return _horizontal_input()

## W/Up shortens the grapple rope (reel in/climb), S/Down lengthens it (let out/drop).
func _vertical_input() -> float:
	var up: float = 1.0 if (Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) else 0.0
	var down: float = 1.0 if (Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) else 0.0
	return up - down

func _process_ground(delta: float) -> void:
	if track_mode:
		_process_ground_track(delta)
	else:
		_process_ground_heightfield(delta)

## Shared ground-speed integrator. Applies reverse_brake_strength only when
## the input opposes the vehicle's CURRENT motion (a snappy brake, like
## letting off the gas and tapping the other direction), and the full
## symmetric acceleration otherwise — including building speed backward from
## a stop or while already reversing. Reusing reverse_brake_strength for that
## second case made reverse permanently weaker than forward and (combined
## with the old asymmetric speed clamp) made backward driving, launches, and
## the resulting airtime all feel different from forward.
func _accelerate_ground_speed(current_speed: float, input_dir: float, delta: float) -> float:
	if input_dir > 0.0:
		if current_speed < 0.0:
			return current_speed + reverse_brake_strength * input_dir * delta
		return current_speed + acceleration * input_dir * delta
	elif input_dir < 0.0:
		if current_speed > 0.0:
			return current_speed + reverse_brake_strength * input_dir * delta
		return current_speed + acceleration * input_dir * delta
	return move_toward(current_speed, 0.0, ground_friction * delta)

func _process_ground_heightfield(delta: float) -> void:
	var input_dir: float = _horizontal_input()
	var ground_info: Dictionary = terrain.get_ground_info(global_position.x)
	if not ground_info["has_ground"]:
		_enter_air()
		return
	var tangent: Vector2 = ground_info["tangent"]
	slope_angle = tangent.angle()
	var slope_accel: float = sin(slope_angle) * gravity * slope_gravity_scale * 0.35
	ground_speed = _accelerate_ground_speed(ground_speed, input_dir, delta)
	ground_speed += slope_accel * delta
	ground_speed = clampf(ground_speed, -max_ground_speed * 1.35, max_ground_speed * 1.35)
	var next_x: float = global_position.x + tangent.x * ground_speed * delta
	var next_ground: Dictionary = terrain.get_ground_info(next_x)
	velocity = tangent * ground_speed
	if next_ground["has_ground"]:
		global_position = Vector2(next_x, next_ground["y"] - ground_clearance)
		last_safe_position = global_position
		last_safe_speed = ground_speed
	else:
		if absf(slope_angle) > deg_to_rad(18.0):
			velocity.y -= jump_impulse
		_enter_air()

## Track-mode grounded movement: progress advances along (track_id,
## arc-length) via ResonanceRushTrackWorld.advance_contact() instead of an X
## lookup — this is what lets stacked platforms, backward curves, and loops
## exist.
##
## Slope/gravity uses real energy conservation (½v² + g·h = const) rather than
## the height-field's instantaneous sin(angle)·gravity approximation. That
## approximation reads the LOCAL tangent at a single point and is blind to how
## much height the vehicle actually gains/loses over the step; on a tightly
## curved track (a 32-point polygon loop) that mismatch compounds every
## vertex and silently drains speed climbing a loop that should return it in
## full. Deriving the speed change from the step's *actual* height change
## instead is exact regardless of how sharply the track curves.
func _process_ground_track(delta: float) -> void:
	var input_dir: float = _horizontal_input()
	var start_pose: Dictionary = terrain.get_track_pose(current_track_id, current_track_progress)
	if start_pose.is_empty():
		_enter_air()
		return
	var tangent: Vector2 = start_pose["tangent"]
	slope_angle = tangent.angle()
	ground_speed = _accelerate_ground_speed(ground_speed, input_dir, delta)
	var travel_direction: float = signf(ground_speed) if absf(ground_speed) > 0.01 else 1.0
	var advanced: Dictionary = terrain.advance_contact(current_track_id, current_track_progress, ground_speed * delta)
	if advanced.is_empty():
		velocity = tangent * ground_speed
		_enter_air()
		return
	if not advanced.get("detached", true):
		var height_change: float = advanced["position"].y - start_pose["position"].y
		var speed_squared: float = ground_speed * ground_speed + 2.0 * gravity * slope_gravity_scale * height_change
		ground_speed = travel_direction * sqrt(maxf(0.0, speed_squared))
		ground_speed = clampf(ground_speed, -max_ground_speed * 1.35, max_ground_speed * 1.35)
		current_track_id = advanced["track_id"]
		current_track_progress = advanced["progress"]
		global_position = advanced["position"] - advanced["normal"] * ground_clearance
		velocity = advanced["tangent"] * ground_speed
		last_safe_position = global_position
		last_safe_speed = ground_speed
		last_safe_track_id = current_track_id
		last_safe_track_progress = current_track_progress
	else:
		velocity = tangent * ground_speed
		if absf(slope_angle) > deg_to_rad(18.0):
			velocity.y -= jump_impulse
		track_detach_ignored_id = current_track_id
		track_detach_timer = track_detach_ignore_seconds
		_enter_air()

func _process_air(delta: float) -> void:
	var input_dir: float = _horizontal_input()
	velocity.y += gravity * vehicle_weight * delta
	velocity.x += input_dir * air_control * delta
	velocity.x = clampf(velocity.x, -max_ground_speed * 1.4, max_ground_speed * 1.4)
	var previous_position: Vector2 = global_position
	global_position += velocity * delta
	if track_mode:
		_try_land_track(previous_position)
	else:
		var ground_info: Dictionary = terrain.get_ground_info(global_position.x)
		if ground_info["has_ground"] and global_position.y >= ground_info["y"] - ground_clearance and velocity.y >= 0.0:
			_land_on_ground(ground_info)
		elif global_position.y > terrain.max_world_y:
			_respawn_at_last_safe()

## Sweeps previous->current position against every independent track ribbon
## (via ResonanceRushTrackWorld.find_landing) so a fall correctly picks
## whichever surface — forest road, mountain platform, or sky platform — is
## actually beneath the vehicle, rather than always the single global ground.
func _try_land_track(previous_position: Vector2) -> void:
	var ignore_id: int = track_detach_ignored_id if track_detach_timer > 0.0 else -1
	var landing: Dictionary = terrain.find_landing(previous_position, global_position, velocity, ground_clearance, ignore_id)
	if not landing.is_empty() and velocity.y >= 0.0:
		_land_on_track(landing)
	elif global_position.y > terrain.max_world_y:
		_respawn_at_last_safe()

func _land_on_track(landing: Dictionary) -> void:
	current_track_id = landing["track_id"]
	current_track_progress = landing["progress"]
	global_position = landing["position"] - landing["normal"] * ground_clearance
	var horizontal_sign: float = signf(velocity.dot(landing["tangent"])) if absf(velocity.dot(landing["tangent"])) > 1.0 else 1.0
	ground_speed = velocity.length() * horizontal_sign * momentum_retention
	glide_trail_points.clear()
	glide_trail.points = glide_trail_points
	state = State.GROUND
	state_changed.emit("GROUND")
	last_safe_position = global_position
	last_safe_speed = ground_speed
	last_safe_track_id = current_track_id
	last_safe_track_progress = current_track_progress

func _land_on_ground(ground_info: Dictionary) -> void:
	global_position.y = ground_info["y"] - ground_clearance
	# Preserve total kinetic energy on landing, not just the horizontal
	# component — discarding velocity.y here meant a fast, mostly-vertical
	# dive (from a swing or glide) evaporated into almost nothing the instant
	# you touched down, which read as "momentum carry is poor."
	var horizontal_sign: float = signf(velocity.x) if absf(velocity.x) > 1.0 else 1.0
	ground_speed = velocity.length() * horizontal_sign * momentum_retention
	glide_trail_points.clear()
	glide_trail.points = glide_trail_points
	state = State.GROUND
	state_changed.emit("GROUND")
	last_safe_position = global_position
	last_safe_speed = ground_speed

func _enter_air() -> void:
	if state != State.AIR:
		state = State.AIR
		state_changed.emit("AIR")

func _respawn_at_last_safe() -> void:
	_cancel_grapple_shot()
	global_position = last_safe_position
	ground_speed = last_safe_speed * 0.6
	velocity = Vector2.ZERO
	if track_mode:
		current_track_id = last_safe_track_id
		current_track_progress = last_safe_track_progress
	state = State.GROUND
	state_changed.emit("GROUND")
	fell_off_course.emit()

func _try_fire_grapple() -> void:
	if grapple_shot_active or state == State.GRAPPLE:
		return
	var aim_direction: Vector2 = (get_global_mouse_position() - global_position).normalized()
	var best_point: Node2D = null
	var best_score: float = -INF
	for node: Node in get_tree().get_nodes_in_group("resonance_grapple_point"):
		var point: Node2D = node as Node2D
		if point == null:
			continue
		var to_point: Vector2 = point.global_position - global_position
		var distance: float = to_point.length()
		if distance > grapple_max_range or distance < 20.0:
			continue
		var alignment: float = aim_direction.dot(to_point.normalized())
		if alignment < cos(deg_to_rad(grapple_aim_tolerance_degrees)):
			continue
		var score: float = alignment - distance / grapple_max_range * 0.3
		if score > best_score:
			best_score = score
			best_point = point
	if best_point != null:
		_launch_grapple_projectile(best_point)

func _launch_grapple_projectile(point: Node2D) -> void:
	grapple_shot_active = true
	grapple_shot_target = point
	grapple_tip_position = global_position
	grapple_line.visible = true
	grapple_tip.visible = true
	grapple_tip.position = Vector2.ZERO
	grapple_line.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])

func _process_grapple_projectile(delta: float) -> void:
	if not is_instance_valid(grapple_shot_target):
		_cancel_grapple_shot()
		return
	var target_position: Vector2 = grapple_shot_target.global_position
	if global_position.distance_to(target_position) > grapple_max_range * 1.12:
		_cancel_grapple_shot()
		return
	grapple_tip_position = grapple_tip_position.move_toward(target_position, grapple_projectile_speed * delta)
	if grapple_tip != null:
		grapple_tip.position = to_local(grapple_tip_position)
	if grapple_tip_position.distance_squared_to(target_position) <= 9.0:
		_attach_grapple(grapple_shot_target)
		return
	if grapple_line != null:
		grapple_line.points = PackedVector2Array([Vector2.ZERO, to_local(grapple_tip_position)])

func _cancel_grapple_shot() -> void:
	grapple_shot_active = false
	grapple_shot_target = null
	if grapple_tip != null:
		grapple_tip.visible = false
	if state != State.GRAPPLE and grapple_line != null:
		grapple_line.visible = false

func _attach_grapple(point: Node2D) -> void:
	grapple_shot_active = false
	grapple_shot_target = null
	if grapple_tip != null:
		grapple_tip.visible = false
	if glide_trail != null:
		glide_trail.visible = false
	glide_trail_points.clear()
	grapple_point_active = point
	grapple_anchor = point.global_position
	grapple_rope_length = clampf(global_position.distance_to(grapple_anchor), 40.0, grapple_rope_length_max)
	state = State.GRAPPLE
	state_changed.emit("GRAPPLE")
	if grapple_line != null:
		grapple_line.visible = true

func _process_grapple(delta: float) -> void:
	if not is_instance_valid(grapple_point_active):
		_release_grapple()
		return
	grapple_anchor = grapple_point_active.global_position
	var radial: Vector2 = (global_position - grapple_anchor).normalized()
	var tangent: Vector2 = Vector2(-radial.y, radial.x)
	# Swing acceleration comes from gravity plus deliberate angular pumping —
	# not a winch pulling the player straight toward the anchor. Positive D is
	# clockwise and A is counter-clockwise, so a stationary player hanging below
	# the anchor can build into wider arcs and eventually a complete loop.
	var gravity_tangential: float = tangent.dot(Vector2(0.0, gravity)) * delta * grapple_strength
	var pump_input: float = _horizontal_input()
	var pump_acceleration: float = -pump_input * grapple_pump_acceleration * delta
	velocity += tangent * (gravity_tangential + pump_acceleration)
	velocity.y += gravity * vehicle_weight * delta * 0.2
	var radial_speed: float = velocity.dot(radial)
	velocity -= radial * radial_speed
	if velocity.length() > grapple_max_swing_speed:
		velocity = velocity.normalized() * grapple_max_swing_speed
	velocity *= swing_damping
	global_position += velocity * delta
	# W reels in (shorter rope, climb closer to the anchor); S lets out
	# (longer rope, drop lower) — clamped between 25% and 100% of the rope's
	# rated maximum length.
	var reel_input: float = _vertical_input()
	if reel_input != 0.0:
		grapple_rope_length = clampf(grapple_rope_length - reel_input * grapple_reel_speed * delta, grapple_rope_length_max * 0.25, grapple_rope_length_max)
	global_position = grapple_anchor + (global_position - grapple_anchor).normalized() * grapple_rope_length
	if grapple_line != null:
		grapple_line.points = PackedVector2Array([Vector2.ZERO, to_local(grapple_anchor)])

func _release_grapple() -> void:
	if grapple_line != null:
		grapple_line.visible = false
	if grapple_tip != null:
		grapple_tip.visible = false
	grapple_point_active = null
	velocity *= release_momentum_multiplier
	_enter_air()

func _enter_glide() -> void:
	state = State.GLIDE
	state_changed.emit("GLIDE")
	glide_trail_points.clear()
	# Pure rotation takes over as the sole representation of orientation
	# during glide (see _update_visual/_update_glider_form); clear any
	# leftover mirror from ground/air driving so it can't combine with the
	# rotation and desync the visual.
	if sprite != null:
		sprite.flip_h = false
	if glider_sprite != null:
		glider_sprite.flip_h = false
	if glide_trail != null:
		glide_trail.visible = true
		glide_trail.default_color = Color(0.75, 0.95, 1.0, 0.75)

func _process_glide(delta: float) -> void:
	var pitch_input: float = _glide_pitch_input()
	# A/D only rotates the flight vector. It must not directly brake or bleed
	# horizontal momentum: that was what made pulling up feel like a parachute.
	if pitch_input != 0.0 and velocity.length() > 1.0:
		var air_speed: float = velocity.length()
		var pitch_rate: float = deg_to_rad(115.0)
		velocity = velocity.normalized().rotated(pitch_input * pitch_rate * delta) * air_speed
	velocity.y += gravity * vehicle_weight * delta * 0.25
	velocity = velocity.move_toward(Vector2.ZERO, glide_drag * delta * 0.2)
	if velocity.length() > max_glide_speed:
		velocity = velocity.normalized() * max_glide_speed
	var previous_position: Vector2 = global_position
	global_position += velocity * delta
	glide_energy -= delta
	_update_glide_trail()
	if glide_energy <= 0.0:
		_exit_glide()
	if track_mode:
		_try_land_track(previous_position)
	else:
		var ground_info: Dictionary = terrain.get_ground_info(global_position.x)
		if ground_info["has_ground"] and global_position.y >= ground_info["y"] - ground_clearance and velocity.y >= 0.0:
			_land_on_ground(ground_info)
		elif global_position.y > terrain.max_world_y:
			_respawn_at_last_safe()

## A short fading ribbon trailing the sail — the main visible proof that
## gliding is actually doing something distinct from plain falling.
## GlideTrail is a top_level node (see scene file) so these are recorded in
## world space; a plain child Line2D would have its points dragged along
## with the sail every frame and never show a trail at all.
func _update_glide_trail() -> void:
	glide_trail_points.append(global_position)
	var trail_cap: int = 16
	while glide_trail_points.size() > trail_cap:
		glide_trail_points.remove_at(0)
	if glide_trail != null:
		glide_trail.points = glide_trail_points

func _exit_glide() -> void:
	if state == State.GLIDE:
		state = State.AIR
		state_changed.emit("AIR")
	if glide_trail != null:
		glide_trail.visible = false
	glide_trail_points.clear()

func _process_common(delta: float) -> void:
	if state != State.GLIDE:
		glide_energy = minf(glide_duration, glide_energy + glide_duration * glide_recharge_rate * delta)
	if quick_twirl_time_left > 0.0:
		quick_twirl_time_left -= delta
	if track_detach_timer > 0.0:
		track_detach_timer -= delta
	if show_grapple_range_debug:
		queue_redraw()

## Space is a single context-sensitive button: jump off the ground, or fold
## into/out of glide mode in the air. A discrete press leaves A/D free for
## direction-relative glider pitch control.
func _handle_space_press() -> void:
	match state:
		State.GROUND: _perform_jump()
		State.AIR:
			if glide_energy > 0.05:
				_enter_glide()
		State.GLIDE:
			_exit_glide()

func _perform_jump() -> void:
	var tangent: Vector2 = Vector2.RIGHT
	if track_mode:
		var pose: Dictionary = terrain.get_track_pose(current_track_id, current_track_progress)
		if not pose.is_empty():
			tangent = pose["tangent"]
		track_detach_ignored_id = current_track_id
		track_detach_timer = track_detach_ignore_seconds
	else:
		var ground_info: Dictionary = terrain.get_ground_info(global_position.x)
		if ground_info["has_ground"]:
			tangent = ground_info["tangent"]
	velocity = tangent * ground_speed
	velocity.y -= manual_jump_impulse
	_enter_air()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and state != State.GRAPPLE:
			_try_fire_grapple()
		elif not event.pressed:
			if grapple_shot_active:
				_cancel_grapple_shot()
			elif state == State.GRAPPLE:
				_release_grapple()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F and (state == State.AIR or state == State.GLIDE):
			quick_twirl_time_left = quick_twirl_duration
		elif event.physical_keycode == KEY_SPACE:
			_handle_space_press()

func _update_altitude() -> void:
	altitude_m = maxf(0.0, (start_y - global_position.y) * meters_per_pixel)
	altitude_changed.emit(altitude_m)

func get_debug_speed_max() -> float:
	return maxf(max_glide_speed, max_ground_speed * 1.35)

func get_debug_horizontal_speed() -> float:
	return absf(velocity.x)

## Linear momentum magnitude. With the default mass-like vehicle_weight of 1,
## this equals total airspeed; changing weight makes the distinction explicit.
func get_debug_momentum() -> float:
	return velocity.length() * vehicle_weight

func get_debug_momentum_max() -> float:
	var peak_release_speed: float = grapple_max_swing_speed * release_momentum_multiplier
	return maxf(get_debug_speed_max(), peak_release_speed) * vehicle_weight

func _draw() -> void:
	if show_grapple_range_debug:
		draw_circle(Vector2.ZERO, grapple_max_range, Color(0.2, 0.75, 1.0, 0.025))
		draw_arc(Vector2.ZERO, grapple_max_range, 0.0, TAU, 96, Color(0.3, 0.85, 1.0, 0.28), 2.0, true)

func _update_visual(delta: float) -> void:
	var base_scale: Vector2 = Vector2.ONE
	match state:
		State.GROUND:
			visual_rotation = lerp_angle(visual_rotation, slope_angle, 10.0 * delta)
			base_scale = Vector2(1.0, 1.0 + sin(Time.get_ticks_msec() * 0.01) * 0.02)
		State.GLIDE:
			# Full unclamped rotation, matching true flight angle exactly —
			# including upside-down at the top of a loop. Deliberately NOT
			# combined with sprite flip_h here: mirroring while also freely
			# rotating is what caused the old "flying backward" glitch.
			# Rotation alone already reads correctly forward, backward, and
			# upside-down, with no discrete flip to desync from it.
			if velocity.length() > 10.0:
				visual_rotation = lerp_angle(visual_rotation, velocity.angle(), glide_bank_smoothing * delta)
		State.GRAPPLE:
			# A/D pumps angular swing momentum, but the vehicle itself stays
			# upright instead of barrel-rolling around the anchor.
			visual_rotation = lerp_angle(visual_rotation, 0.0, 10.0 * delta)
		_:
			_update_air_trick_spin(delta)
	_update_glider_form(delta, base_scale)

## Hinges the visible upright sail upward and reveals the broad glider wing.
## Both textures contain the same chassis, so the quick squash/flip/crossfade
## reads as one mechanism changing configuration while preserving the vehicle.
func _update_glider_form(delta: float, base_scale: Vector2) -> void:
	if sprite == null or glider_sprite == null:
		return
	var wants_glider: bool = state == State.GLIDE
	var transition_seconds: float = glider_deploy_seconds if wants_glider else glider_fold_seconds
	var transition_step: float = delta / maxf(0.01, transition_seconds)
	var target_blend: float = 1.0 if wants_glider else 0.0
	glide_form_blend = move_toward(glide_form_blend, target_blend, transition_step)
	var eased_blend: float = glide_form_blend * glide_form_blend * (3.0 - 2.0 * glide_form_blend)
	# Driven by actual travel direction rather than sprite.flip_h, since
	# flip_h is intentionally left untouched during GLIDE (see below) and
	# would otherwise freeze this hinge-tilt direction mid-flight.
	var facing_sign: float = -1.0 if velocity.x < 0.0 else 1.0
	var flip_radians: float = deg_to_rad(glider_flip_degrees) * facing_sign

	# The old upright sail narrows and rotates away around the shared chassis.
	sprite.rotation = visual_rotation - flip_radians * eased_blend
	sprite.scale = Vector2(base_scale.x, base_scale.y * lerpf(1.0, 0.12, eased_blend))
	sprite.modulate.a = 1.0 - clampf(eased_blend / 0.72, 0.0, 1.0)

	# The overhead wing begins edge-on, flips open, then subtly flexes in air.
	var reveal: float = clampf((eased_blend - 0.08) / 0.92, 0.0, 1.0)
	var flutter: float = sin(Time.get_ticks_msec() * 0.012) * glider_flutter_amount * reveal
	glider_sprite.visible = glide_form_blend > 0.001
	glider_sprite.rotation = visual_rotation - flip_radians * (1.0 - eased_blend)
	glider_sprite.scale = Vector2(
		lerpf(0.82, glider_deployed_scale, reveal) * (1.0 + flutter),
		lerpf(0.08, 1.0, reveal) * (1.0 - flutter * 0.5)
	)
	glider_sprite.modulate.a = reveal
	# Mirroring is reserved for states that stay roughly upright (ground
	# driving, plain falling). During GLIDE, orientation — including facing
	# backward or being upside-down mid-loop — is fully represented by
	# visual_rotation alone; also mirroring here would fight the rotation
	# and cause a visible flicker right as the loop crosses vertical.
	if state != State.GLIDE and absf(velocity.x) > 1.0:
		var facing_left: bool = velocity.x < 0.0
		sprite.flip_h = facing_left
		glider_sprite.flip_h = facing_left

## Tapping A/D in the air gives a small, weak lean; holding it continuously
## ramps up to the full spin speed over trick_spin_ramp_up_seconds. Without
## this, a quick tap to nudge your landing looked identical to a full
## deliberate barrel roll, which read as "the spin is messing with my control."
func _update_air_trick_spin(delta: float) -> void:
	var input_dir: float = _horizontal_input()
	if quick_twirl_time_left > 0.0:
		visual_rotation += (TAU / quick_twirl_duration) * delta
		return
	if Input.is_physical_key_pressed(KEY_F):
		visual_rotation += deg_to_rad(trick_spin_speed_degrees) * 0.5 * delta
		return
	if input_dir == 0.0:
		air_steer_hold_direction = 0.0
		air_steer_hold_time = 0.0
		visual_rotation = lerp_angle(visual_rotation, 0.0, 2.0 * delta)
		return
	if signf(input_dir) == air_steer_hold_direction:
		air_steer_hold_time += delta
	else:
		air_steer_hold_direction = signf(input_dir)
		air_steer_hold_time = 0.0
	var ramp: float = clampf(air_steer_hold_time / trick_spin_ramp_up_seconds, 0.2, 1.0)
	visual_rotation += deg_to_rad(trick_spin_speed_degrees) * ramp * input_dir * delta

func _on_bounce_detector_area_entered(area: Area2D) -> void:
	if not area.is_in_group("resonance_mushroom"):
		return
	var forward_sign: float = signf(velocity.x) if absf(velocity.x) > 1.0 else 1.0
	velocity.x = forward_sign * maxf(absf(velocity.x), mushroom_min_forward_speed)
	velocity.y = -mushroom_bounce_impulse
	ground_speed = velocity.x
	_enter_air()
