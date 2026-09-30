class_name PXMotorSwordLab
extends Node2D
## PX MODE — Physics Motor Sword Lab (standalone, isolated).
##
## WHAT THIS ASKS
##   If a sword is asked to follow its swing using TORQUE ONLY (a PD motor
##   driving a physical body), does Godot's own solver produce natural
##   hard-contact behaviour — does the blade stop dead on an obstacle, or
##   does it shove through and slide around it?
##
## ISOLATION (why this is trustworthy)
##   This scene shares NO runtime code with the game. It does not touch
##   player.gd, hit_reaction.gd, Blade Sink, Blade Physical Reaction, Bone
##   Stop/Slide/Bind/Constraint, Core Yield, the Blade Shell, Full Physical,
##   Hard Contact Clash, Body Block, depenetration or any enemy hit/reaction
##   logic. It borrows DATA ONLY from Blade Dancer — blade length and
##   thickness — as input to a fresh collider and a fresh contact model.
##   The target angle comes from a SYNTHETIC metronome, so there is nothing
##   of the game's animation in the loop either.
##
## ARCHITECTURE
##   HandAnchor  StaticBody2D  — the authored hilt position (a sibling).
##   Pivot       PinJoint2D    — constrains the sword's hilt to the anchor.
##   Sword       RigidBody2D   — a real physical blade (sibling, NOT a child
##                               of the moving hand).
##   Obstacle    StaticBody2D  — a hard circle.
##   The motor is a PD torque applied to the sword every physics tick. The
##   metronome NEVER writes the sword's transform, rotation or angular
##   velocity — it only states a target angle, and the motor has to earn it.

signal closed()

# ── The motor: exactly three knobs ──────────────────────────────────────────
const MOTOR_STIFFNESS: float = 150000.0  ## torque (N·m) per radian of error
const MOTOR_DAMPING: float = 2000.0      ## torque (N·m) per rad/s of spin
const MAX_TORQUE: float = 250000.0       ## torque ceiling (N·m)

# ── The synthetic metronome (the target signal) ─────────────────────────────
const BASE_ANGLE_DEG: float = 0.0       ## swing centre, measured from +X
const SWING_AMPLITUDE_DEG: float = 60.0 ## half the sweep
const SWING_PERIOD: float = 1.6         ## seconds for a full there-and-back

# ── Borrowed data + lab geometry ────────────────────────────────────────────
const BLADE_LENGTH: float = 84.0        ## Blade Dancer's BLADE_LENGTH
const BLADE_THICKNESS: float = 12.0     ## visual/collider thickness of the blade
const OBSTACLE_RADIUS: float = 9.0
const OBSTACLE_FRACTION: float = 0.35   ## how far along the blade the circle bites
const OBSTACLE_BEARING_DEG: float = 45.0 ## where in the sweep the circle sits
const HILT_POINT: Vector2 = Vector2.ZERO

# ── Nodes ───────────────────────────────────────────────────────────────────
var hand_anchor: StaticBody2D
var pivot: PinJoint2D
var sword: RigidBody2D
var obstacle: StaticBody2D
var camera: Camera2D
var hud: Label

# ── Measured (updated every physics tick, shown on the HUD) ─────────────────
var swing_time: float = 0.0
var target_angle: float = 0.0
var actual_angle: float = 0.0
var angle_error: float = 0.0
var angular_velocity: float = 0.0
var motor_torque: float = 0.0
var hilt_error: float = 0.0
var engine_contacts: int = 0
var contact_fraction: float = -1.0   ## along-blade position of the obstacle
var contact_perp: float = 0.0        ## perpendicular distance, blade axis to circle centre
var overlap: float = 0.0             ## >0 means the blade is INSIDE the circle by this many px


func _ready() -> void:
	# A hub may be showing (paused tree) when this is launched from Adventure;
	# ALWAYS keeps the simulation stepping through the pause, like Resonance Rush.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_world()
	_build_hud()
	queue_redraw()


func _build_world() -> void:
	# Anchor: the authored hilt. Never moves. zero layers — collides with nothing.
	hand_anchor = StaticBody2D.new()
	hand_anchor.name = "HandAnchor"
	hand_anchor.position = HILT_POINT
	hand_anchor.collision_layer = 0
	hand_anchor.collision_mask = 0
	var anchor_shape := CollisionShape2D.new()
	var anchor_circle := CircleShape2D.new()
	anchor_circle.radius = 2.0
	anchor_shape.shape = anchor_circle
	hand_anchor.add_child(anchor_shape)
	add_child(hand_anchor)

	# Sword: a real physical blade. Long axis along local +X, origin at the hilt.
	sword = RigidBody2D.new()
	sword.name = "Sword"
	sword.position = HILT_POINT
	sword.mass = 1.0
	sword.gravity_scale = 0.0
	sword.linear_damp = 0.0
	sword.angular_damp = 0.0
	sword.can_sleep = false
	sword.contact_monitor = true
	sword.max_contacts_reported = 8
	sword.continuous_cd = RigidBody2D.CCD_MODE_DISABLED
	sword.collision_layer = 1
	sword.collision_mask = 1
	var blade_shape := CollisionShape2D.new()
	var blade_rect := RectangleShape2D.new()
	blade_rect.size = Vector2(BLADE_LENGTH, BLADE_THICKNESS)
	blade_shape.shape = blade_rect
	blade_shape.position = Vector2(BLADE_LENGTH * 0.5, 0.0)
	sword.add_child(blade_shape)
	add_child(sword)

	# Pivot: a pin from the anchor to the sword's hilt.
	pivot = PinJoint2D.new()
	pivot.name = "Pivot"
	pivot.position = HILT_POINT
	pivot.softness = 0.0
	pivot.disable_collision = true
	add_child(pivot)
	pivot.node_a = pivot.get_path_to(hand_anchor)
	pivot.node_b = pivot.get_path_to(sword)

	# Obstacle: a hard circle placed on the arc the blade sweeps.
	obstacle = StaticBody2D.new()
	obstacle.name = "Obstacle"
	obstacle.position = Vector2(OBSTACLE_FRACTION * BLADE_LENGTH, 0.0).rotated(
		deg_to_rad(OBSTACLE_BEARING_DEG)
	)
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	var obstacle_shape := CollisionShape2D.new()
	var obstacle_circle := CircleShape2D.new()
	obstacle_circle.radius = OBSTACLE_RADIUS
	obstacle_shape.shape = obstacle_circle
	obstacle.add_child(obstacle_shape)
	add_child(obstacle)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.position = Vector2(35.0, 0.0)
	camera.zoom = Vector2(3.0, 3.0)
	add_child(camera)
	camera.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HudLayer"
	add_child(layer)

	hud = Label.new()
	hud.name = "Readout"
	hud.position = Vector2(18.0, 14.0)
	hud.add_theme_font_size_override("font_size", 16)
	hud.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	layer.add_child(hud)

	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "CLOSE"
	close_button.anchor_left = 1.0
	close_button.anchor_right = 1.0
	close_button.offset_left = -132.0
	close_button.offset_right = -18.0
	close_button.offset_top = 16.0
	close_button.offset_bottom = 56.0
	close_button.pressed.connect(_close)
	layer.add_child(close_button)


func _physics_process(delta: float) -> void:
	swing_time += delta

	# Synthetic metronome — the ONLY place a target is stated.
	target_angle = deg_to_rad(BASE_ANGLE_DEG) \
		+ deg_to_rad(SWING_AMPLITUDE_DEG) * sin(TAU * swing_time / SWING_PERIOD)

	# PD torque toward the target. Nothing else is written to the body.
	actual_angle = sword.rotation
	angular_velocity = sword.angular_velocity
	angle_error = angle_difference(actual_angle, target_angle)
	motor_torque = clampf(
		angle_error * MOTOR_STIFFNESS - angular_velocity * MOTOR_DAMPING,
		-MAX_TORQUE,
		MAX_TORQUE
	)
	sword.apply_torque(motor_torque)

	# Diagnostics.
	hilt_error = sword.global_position.distance_to(hand_anchor.global_position)
	engine_contacts = sword.get_contact_count()

	# Geometry-derived contact measure (independent of engine reporting):
	# express the obstacle centre in the blade's local frame, where the blade
	# spans x in [0, BLADE_LENGTH] and y in [-thickness/2, +thickness/2].
	var local_obstacle: Vector2 = sword.to_local(obstacle.global_position)
	contact_fraction = clampf(local_obstacle.x, 0.0, BLADE_LENGTH) / BLADE_LENGTH
	contact_perp = absf(local_obstacle.y)
	var within_span: bool = local_obstacle.x >= 0.0 and local_obstacle.x <= BLADE_LENGTH
	var surface_gap: float = contact_perp - (BLADE_THICKNESS * 0.5 + OBSTACLE_RADIUS)
	overlap = -surface_gap if within_span else 0.0

	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	var lines: Array[String] = []
	lines.append("PX MODE — Physics Motor Sword Lab")
	lines.append("")
	lines.append("motor  k=%.0f  d=%.0f  max=%.0f" % [MOTOR_STIFFNESS, MOTOR_DAMPING, MAX_TORQUE])
	lines.append("signal amp=%.0f deg  period=%.2fs  base=%.0f deg" % [
		SWING_AMPLITUDE_DEG, SWING_PERIOD, BASE_ANGLE_DEG
	])
	lines.append("")
	lines.append("target   %6.1f deg" % rad_to_deg(target_angle))
	lines.append("actual   %6.1f deg" % rad_to_deg(actual_angle))
	lines.append("error    %6.1f deg" % rad_to_deg(angle_error))
	lines.append("omega    %6.2f rad/s" % angular_velocity)
	lines.append("torque   %7.0f N·m" % motor_torque)
	lines.append("hilt err %6.2f px" % hilt_error)
	lines.append("")
	lines.append("engine contacts  %d" % engine_contacts)
	lines.append("blade frac       %5.2f  (obstacle at %.2f)" % [contact_fraction, OBSTACLE_FRACTION])
	lines.append("blade dist       %5.1f px  (surface +%.1f)" % [
		contact_perp, BLADE_THICKNESS * 0.5 + OBSTACLE_RADIUS
	])
	if overlap > 0.01:
		lines.append(">> BLADE INSIDE OBSTACLE by %.1f px" % overlap)
	else:
		lines.append(">> blade outside obstacle")
	hud.text = "\n".join(lines)


func _close() -> void:
	closed.emit()
	if get_tree().current_scene == self:
		get_tree().quit()


func _draw() -> void:
	# Backdrop.
	draw_rect(Rect2(Vector2(-260.0, -200.0), Vector2(620.0, 400.0)), Color(0.06, 0.07, 0.09), true)

	# The obstacle.
	draw_circle(obstacle.global_position, OBSTACLE_RADIUS, Color(0.55, 0.18, 0.18, 0.35), true)
	draw_arc(obstacle.global_position, OBSTACLE_RADIUS, 0.0, TAU, 48, Color(0.95, 0.45, 0.4), 2.0)

	# The metronome ghost — where the blade is being ASKED to be.
	var ghost_dir := Vector2.RIGHT.rotated(target_angle)
	draw_line(HILT_POINT, HILT_POINT + ghost_dir * BLADE_LENGTH, Color(0.35, 0.85, 1.0, 0.55), 2.0)

	# The real, physical blade, drawn from the sword's own transform.
	var xf: Transform2D = sword.global_transform
	var half := BLADE_THICKNESS * 0.5
	var corners := PackedVector2Array([
		xf * Vector2(0.0, -half),
		xf * Vector2(BLADE_LENGTH, -half),
		xf * Vector2(BLADE_LENGTH, half),
		xf * Vector2(0.0, half),
	])
	draw_colored_polygon(corners, Color(0.78, 0.82, 0.88, 0.9))
	draw_polyline(corners + PackedVector2Array([corners[0]]), Color(0.95, 0.97, 1.0), 1.5)

	# Hilt pivot.
	draw_circle(HILT_POINT, 3.0, Color(1.0, 0.85, 0.35))

	# Mark where the blade's near point to the obstacle is this frame.
	var near_point: Vector2 = sword.to_global(Vector2(contact_fraction * BLADE_LENGTH, 0.0))
	var marker_color := Color(1.0, 0.3, 0.3) if overlap > 0.01 else Color(0.5, 1.0, 0.6)
	draw_circle(near_point, 2.5, marker_color)