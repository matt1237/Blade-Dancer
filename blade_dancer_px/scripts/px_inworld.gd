class_name PXInWorld extends Node2D
## PX IN-WORLD — the standalone physics sword, brought into the REAL game behind
## PX Mode.
##
## It shares NO gameplay code with the game. It builds its own rigid-body blade
## (via px_blade.gd) and drives it with the PX motor, reading only the game's
## PUBLIC aim (player.aim_angle). While it is active the authored sword art is
## hidden, and the physics blade deals damage through the game's own
## Enemy.take_damage(). The game's sword transform is never written: the blade
## earns every degree from torque and the solver, exactly like the prototype.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")
const SWORD_TEXTURE: Texture2D = preload("res://assets/Blade Dancer Sword.png")

## Motor feel + aim feel, seeded from the BDPX Global save so the in-game sword
## feels like the lab. Defaults come straight from px_config.
var stiffness: float = Cfg.DEFAULT_MOTOR_STIFFNESS
var damping: float = Cfg.DEFAULT_MOTOR_DAMPING
var max_torque: float = Cfg.DEFAULT_MAX_TORQUE
## The sword BODY's own properties (what the object IS), separate from the motor
## above (how strongly you control it). Pushed straight onto the rigid body.
var sword_mass: float = Cfg.SWORD_MASS_DEFAULT
var sword_angular_damp: float = Cfg.SWORD_ANGULAR_DAMP_DEFAULT
var sword_linear_damp: float = Cfg.SWORD_LINEAR_DAMP_DEFAULT
var com_offset: float = Cfg.SWORD_COM_OFFSET_DEFAULT
var metronome_on: bool = false
var arc_degrees: float = Cfg.METRONOME_ARC_DEGREES
var frequency: float = Cfg.METRONOME_FREQUENCY
var lead_degrees: float = Cfg.METRONOME_MAX_LEAD_DEGREES
var hand_min: float = Cfg.DEFAULT_HAND_MIN
var hand_max: float = Cfg.DEFAULT_HAND_MAX

var player: Node2D = null
var blade: RigidBody2D = null
var grip: AnimatableBody2D = null
var pin: PinJoint2D = null
## The lab's spawnable PX enemies, brought into the world (children of this node).
var enemies: PXInWorldEnemies = null

var _aim_direction: Vector2 = Vector2.RIGHT
var _hand_radius: float = Cfg.DEFAULT_HAND_MAX
var _metronome_phase: float = 0.0
var _reference_angle: float = 0.0
var _reference_omega: float = 0.0
var _prev_reference_angle: float = 0.0
var _have_prev_reference: bool = false
var _hit_cooldowns: Dictionary = {}
var _active: bool = true
var _show_ghost: bool = false
var _ghost_opacity: float = Cfg.GHOST_OPACITY_PERCENT
var _servo_feedforward: bool = Cfg.SERVO_FEEDFORWARD_ENABLED
var _hilt_spring: bool = Cfg.HILT_SPRING_ENABLED
## The fastest the blade may turn, in degrees/second (the helicopter brake).
var helicopter_limit: float = Cfg.HELICOPTER_LIMIT_DEFAULT

## How hard the physics blade bites the game's enemies. Scales with how fast the
## blade is actually turning, so a lazy drift is a light cut and a real swing bites.
const HIT_DAMAGE_BASE: float = 14.0
const HIT_DAMAGE_OMEGA: float = 9.0
const HIT_COOLDOWN: float = 0.28
const ENEMY_HIT_RADIUS: float = 20.0

func setup(player_node: Node2D) -> void:
	player = player_node

func _ready() -> void:
	# Run AFTER the player's own physics step so the hand we track is current.
	process_physics_priority = 50
	_load_settings()
	if player == null:
		player = get_parent().get_node_or_null("Player") as Node2D
	if player == null:
		push_warning("PXInWorld: no player found; in-world physics sword disabled.")
		return
	var origin: Vector2 = _player_local_position()
	grip = PXBlade.make_grip()
	grip.position = origin
	add_child(grip)
	blade = PXBlade.make_blade(self, Cfg.L_PLAYER_SWORD, 0x7FFFFFFF)
	blade.position = origin
	# Never collide with our own owner: a precise per-node exception beats guessing
	# collision layers, so the blade stops on walls and enemies but not the player.
	blade.add_collision_exception_with(player)
	pin = PXBlade.pin(self, grip, blade, origin)
	pin.softness = Cfg.HILT_SOFTNESS if _hilt_spring else 0.0
	_apply_sword_body()
	# The lab's spawnable targets (chaser / sword enemy / test dummy), spawned by
	# the PX tuner's Enemies tab and removed with this node.
	enemies = PXInWorldEnemies.new()
	enemies.name = "PXInWorldEnemies"
	add_child(enemies)
	enemies.setup(player, blade)
	enemies.apply_settings(BDPXGlobal.load_settings())
	# Stow the authored sword so only the physics blade exists — and can contact.
	player.set("sword_stowed", true)
	_hide_authored_sword(true)
	queue_redraw()

func _load_settings() -> void:
	var s: Dictionary = BDPXGlobal.load_settings()
	stiffness = float(s.get("stiffness", stiffness))
	damping = float(s.get("damping", damping))
	max_torque = float(s.get("max_torque", max_torque))
	sword_mass = float(s.get("sword_mass", sword_mass))
	sword_angular_damp = float(s.get("sword_angular_damp", sword_angular_damp))
	sword_linear_damp = float(s.get("sword_linear_damp", sword_linear_damp))
	com_offset = float(s.get("com_offset", com_offset))
	metronome_on = bool(s.get("metronome_on", metronome_on))
	arc_degrees = float(s.get("arc_degrees", arc_degrees))
	frequency = float(s.get("frequency", frequency))
	lead_degrees = float(s.get("lead_degrees", lead_degrees))
	hand_min = float(s.get("hand_min", hand_min))
	hand_max = float(s.get("hand_max", hand_max))
	_servo_feedforward = bool(s.get("servo_feedforward_on", _servo_feedforward))
	_hilt_spring = bool(s.get("hilt_spring_on", _hilt_spring))
	_show_ghost = bool(s.get("show_ghost", _show_ghost))
	_ghost_opacity = float(s.get("ghost_opacity", _ghost_opacity))
	helicopter_limit = float(s.get("helicopter_limit", helicopter_limit))

func _player_local_position() -> Vector2:
	return to_local(player.global_position)

# ── Simulation ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active or player == null or not is_instance_valid(player) or blade == null:
		return
	_update_aim()
	var hand: Vector2 = _player_local_position() + _aim_direction * _hand_radius
	grip.position = hand
	var target: float = _advance_target(delta)
	_update_reference_omega(delta)
	var feedforward: float = _reference_omega if _servo_feedforward else 0.0
	blade.apply_torque(PXBlade.servo_torque(blade.rotation, blade.angular_velocity, target, feedforward, stiffness, damping, max_torque))
	# The helicopter brake: above the limit, drag a runaway spin back down.
	var heli_brake: float = _helicopter_brake_torque(blade.angular_velocity)
	if heli_brake != 0.0:
		blade.apply_torque(heli_brake)
	pin.softness = Cfg.HILT_SOFTNESS if _hilt_spring else 0.0
	_damage_enemies(delta)
	_hide_authored_sword(true)
	queue_redraw()

## The helicopter brake: zero below the limit, else a torque that opposes the spin
## and scales with how far past the limit it is (clamped to the motor's max torque).
## A pure torque — the blade's pose is still never written.
func _helicopter_brake_torque(omega: float) -> float:
	var cap: float = deg_to_rad(maxf(helicopter_limit, 0.0))
	if cap <= 0.0 or absf(omega) <= cap:
		return 0.0
	var excess: float = absf(omega) - cap
	return -signf(omega) * excess * Cfg.HELICOPTER_BRAKE_TORQUE_PER_RAD

## Adopt a live tuner dictionary from the shared Training Tools gateway. Only the
## keys we know are read, so the same dictionary may also carry OS-only keys.
func apply_settings(s: Dictionary) -> void:
	stiffness = float(s.get("stiffness", stiffness))
	damping = float(s.get("damping", damping))
	max_torque = float(s.get("max_torque", max_torque))
	sword_mass = float(s.get("sword_mass", sword_mass))
	sword_angular_damp = float(s.get("sword_angular_damp", sword_angular_damp))
	sword_linear_damp = float(s.get("sword_linear_damp", sword_linear_damp))
	com_offset = float(s.get("com_offset", com_offset))
	metronome_on = bool(s.get("metronome_on", metronome_on))
	arc_degrees = float(s.get("arc_degrees", arc_degrees))
	frequency = float(s.get("frequency", frequency))
	lead_degrees = float(s.get("lead_degrees", lead_degrees))
	hand_min = float(s.get("hand_min", hand_min))
	hand_max = float(s.get("hand_max", hand_max))
	_servo_feedforward = bool(s.get("servo_feedforward_on", _servo_feedforward))
	_hilt_spring = bool(s.get("hilt_spring_on", _hilt_spring))
	_show_ghost = bool(s.get("show_ghost", _show_ghost))
	_ghost_opacity = float(s.get("ghost_opacity", _ghost_opacity))
	helicopter_limit = float(s.get("helicopter_limit", helicopter_limit))
	# Spawn toggles ride in the same dictionary; the enemy manager owns them.
	if enemies != null and is_instance_valid(enemies):
		enemies.apply_settings(s)
	_apply_sword_body()
	queue_redraw()

## Push the sword BODY's physical properties onto the rigid body. This is "what the
## object IS" — distinct from the motor, which is "how strongly you control it".
## Nothing here writes a pose: mass and damping feed the solver, and the centre of
## mass only tells the solver where the blade balances. Damping modes are set to
## REPLACE so the slider value IS the damping (0 = honestly off, rather than the
## project's 0.1 default quietly adding in through COMBINE mode).
func _apply_sword_body() -> void:
	if blade == null or not is_instance_valid(blade):
		return
	blade.mass = maxf(sword_mass, 0.01)
	blade.angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	blade.angular_damp = maxf(sword_angular_damp, 0.0)
	blade.linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	blade.linear_damp = maxf(sword_linear_damp, 0.0)
	blade.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	blade.center_of_mass = Vector2(clampf(com_offset, 0.0, Cfg.BLADE_LENGTH), 0.0)

func _update_aim() -> void:
	# The game already owns the aim feel; we just read the angle it settled on.
	_aim_direction = Vector2.from_angle(player.aim_angle)
	_hand_radius = _hand_radius_from_point(get_global_mouse_position())

## Blade Dancer's geared hand reach (the same rule the lab copied from the game).
func _hand_radius_from_point(point: Vector2) -> float:
	var minimum: float = minf(hand_min, hand_max)
	var maximum: float = maxf(hand_min, hand_max)
	if maximum - minimum < 0.001:
		return minimum
	var reach_scale: float = maxf(Cfg.REACH_SCALE, 0.01)
	var input_maximum: float = maxf(minimum + (maximum - minimum) * reach_scale, minimum + 0.001)
	var distance: float = player.global_position.distance_to(point)
	return lerpf(minimum, maximum, clampf(inverse_lerp(minimum, input_maximum, distance), 0.0, 1.0))

func _advance_target(delta: float) -> float:
	var base_angle: float = _aim_direction.angle()
	if not metronome_on:
		_reference_angle = base_angle
		return base_angle
	_metronome_phase = wrapf(_metronome_phase + delta * frequency * TAU, 0.0, TAU)
	var ideal: float = base_angle + deg_to_rad(arc_degrees) * sin(_metronome_phase)
	_reference_angle = ideal
	# The anti-windup leash: the sweep may lead the blade, but only by a bounded
	# amount, so a blocked blade cannot store error and snap free.
	var lead: float = deg_to_rad(lead_degrees)
	var offset: float = angle_difference(blade.rotation, ideal)
	return blade.rotation + clampf(offset, -lead, lead)

func _update_reference_omega(delta: float) -> void:
	if _have_prev_reference:
		_reference_omega = angle_difference(_prev_reference_angle, _reference_angle) / maxf(delta, 1e-5)
	else:
		_reference_omega = 0.0
		_have_prev_reference = true
	_prev_reference_angle = _reference_angle

# ── Damage (through the game's own enemies) ─────────────────────────────────
func _damage_enemies(delta: float) -> void:
	for key: String in _hit_cooldowns.keys():
		_hit_cooldowns[key] = maxf(0.0, float(_hit_cooldowns[key]) - delta)
	var hilt: Vector2 = blade.global_position
	var tip: Vector2 = PXBlade.tip_of(blade)
	var direction: Vector2 = (tip - hilt).normalized()
	var speed_scale: float = clampf(0.15 + absf(blade.angular_velocity) / 4.0, 0.15, 2.0)
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node2D):
			continue
		var target: Node2D = enemy as Node2D
		var id: String = str(target.get_instance_id())
		if float(_hit_cooldowns.get(id, 0.0)) > 0.0:
			continue
		if not _segment_circle_overlap(hilt, tip, target.global_position, ENEMY_HIT_RADIUS):
			continue
		_hit_cooldowns[id] = HIT_COOLDOWN
		if target.has_method("take_damage"):
			var damage: float = (HIT_DAMAGE_BASE + absf(blade.angular_velocity) * HIT_DAMAGE_OMEGA) * speed_scale
			target.call("take_damage", damage, direction, 0.18, clampf(absf(blade.angular_velocity) / 6.0, 0.0, 1.0))

func _segment_circle_overlap(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(center) <= radius

# ── Presentation ────────────────────────────────────────────────────────────
func _hide_authored_sword(hide_it: bool) -> void:
	if player != null and is_instance_valid(player):
		var visual: Node = player.get("player_sword_visual")
		if visual is CanvasItem:
			(visual as CanvasItem).visible = not hide_it

func shutdown() -> void:
	_active = false
	if enemies != null and is_instance_valid(enemies):
		enemies.queue_free()
		enemies = null
	if player != null and is_instance_valid(player):
		player.set("sword_stowed", false)
	_hide_authored_sword(false)

func _draw() -> void:
	if blade == null or not is_instance_valid(blade):
		return
	# _draw is in this node's space and the blade is our child, so blade.position /
	# blade.rotation are already the right local values — no global conversion.
	# Match the REAL game's sword exactly: scale 0.055 and the art centre at
	# BLADE_LENGTH * 0.34 along the blade. Anything else draws at the wrong size.
	if _show_ghost:
		_draw_ghost()
	var center: Vector2 = blade.position + Vector2.from_angle(blade.rotation) * (Cfg.BLADE_LENGTH * 0.34)
	draw_set_transform(center, blade.rotation - PI * 0.5, Vector2(0.055, 0.055))
	draw_texture_rect(SWORD_TEXTURE, Rect2(-512.0, -768.0, 1024.0, 1536.0), false)
	draw_set_transform(Vector2.ZERO)

## The ghost: the same art at the reference (aim) pose, translucent, drawn UNDER the
## solid blade so any gap you see is pure physics lag, never an art mismatch.
func _draw_ghost() -> void:
	var alpha: float = clampf(_ghost_opacity, 0.0, 100.0) * 0.01
	if alpha <= 0.0:
		return
	var reference_hilt: Vector2 = _player_local_position() + _aim_direction * _hand_radius
	var center: Vector2 = reference_hilt + Vector2.from_angle(_reference_angle) * (Cfg.BLADE_LENGTH * 0.34)
	draw_set_transform(center, _reference_angle - PI * 0.5, Vector2(0.055, 0.055))
	draw_texture_rect(SWORD_TEXTURE, Rect2(-512.0, -768.0, 1024.0, 1536.0), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)