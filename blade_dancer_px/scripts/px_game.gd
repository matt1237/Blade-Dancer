class_name BladeDancerPX
extends Node2D
## BLADE DANCER PX — a standalone, playable prototype (coordinator).
##
## All-new: it shares NO code with the game. It does not load player.tscn,
## player.gd, hit_reaction.gd, any enemy scene, or any existing sword system.
## It is a look-alike: the same CONCEPT (walk with WASD, the mouse steers the
## sword) rebuilt from scratch on top of a real physical blade.
##
## The one idea being felt out: the sword is a genuine RigidBody2D whose pose is
## earned by a torque motor chasing your aim — it is not animated. Movement, the
## hand position and the mouse are INPUT ONLY; once the sim runs, only the solver
## decides where the blade ends up. So it stops on walls, wedges on bodies, and
## bonks off the enemy's blade because physics says so.
##
## This file is the COORDINATOR only — the working parts live beside it:
##   px_config.gd        every constant
##   px_blade.gd         blade bodies, the pin grip, the PD motor
##   px_arena.gd         the walled box
##   px_hud.gd           status readout + CLOSE
##   px_tuning_tools.gd  the in-game overlay (live tunables + spawn toggles)
##
## Controls: WASD / arrows move, mouse steers the sword, SPACE dashes.
## The arena starts EMPTY — enemies only appear from the Tuning Tools panel.

signal closed()

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")
const PXArena = preload("res://blade_dancer_px/scripts/px_arena.gd")
const PXHud = preload("res://blade_dancer_px/scripts/px_hud.gd")
const PXTuningTools = preload("res://blade_dancer_px/scripts/px_tuning_tools.gd")
const PXTestDummy = preload("res://blade_dancer_px/scripts/px_test_dummy.gd")
const SWORD_TEXTURE: Texture2D = preload("res://assets/Blade Dancer Sword.png")
const GRASS_TEXTURE: Texture2D = preload("res://assets/generated/px_grass_field_64.png")
## The player's own knight, reused as ART ONLY (PX shares no gameplay code). These
## are the real game's default ("Basic Leather Armor") visuals: a 256x256 idle and
## a 512x256 two-frame walk atlas (two 256x256 frames side by side).
const KNIGHT_IDLE: Texture2D = preload("res://assets/generated/grim_pixel_knight_reference_pass_frame_0.png")
const KNIGHT_WALK: Texture2D = preload("res://assets/generated/grim_pixel_knight_walk.png")
## Same on-screen size as the real game: player.gd sets the HD knight to 0.28.
const KNIGHT_SCALE: float = 0.28
const KNIGHT_FRAME_SIZE: float = 256.0
const KNIGHT_WALK_FPS: float = 5.0

# ── Runtime ─────────────────────────────────────────────────────────────────
var player: CharacterBody2D
var player_anchor: AnimatableBody2D
var player_sword: RigidBody2D
var player_pin: PinJoint2D

var player_health: float = Cfg.PLAYER_MAX_HEALTH
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT
var hand_radius: float = Cfg.DEFAULT_HAND_MAX

var enemies: Array[Dictionary] = []
var chaser_wanted: bool = false
var sword_enemy_wanted: bool = false
var chaser_timer: float = 0.0
var sword_enemy_timer: float = 0.0

var aim_direction: Vector2 = Vector2.RIGHT
## The angle the motor is chasing THIS frame — the aim, or the metronome's sine
## offset from it. Telemetry measures the motor against this, not against the
## aim, because the target is what the motor was asked for.
var sword_target: float = 0.0
## Metronome state (owned by the Tuning Tools panel).
var metronome_on: bool = false
var metronome_phase: float = 0.0
## Metronome wind-up state (owned by the Tuning Tools panel).
var windup_on: bool = Cfg.WINDUP_ENABLED
## Aim FEEL (owned by the Tuning Tools panel) and its filter state. These shape
## the COMMANDED aim only — the blade still earns every degree from the motor.
var aim_inertia_on: bool = Cfg.AIM_INERTIA_ENABLED
var aim_point: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0
var _aim_ready: bool = false
## The reference/ghost pose — the ORIGINAL Blade Dancer target motion, re-derived
## here. `reference_hilt` is where the hand should be, `reference_angle` which way
## the sword should point, `reference_omega` how fast that angle is turning. The
## physical blade is asked to chase this; the ghost overlay draws it.
var reference_hilt: Vector2 = Vector2.ZERO
var reference_angle: float = 0.0
var reference_omega: float = 0.0
var _prev_reference_angle: float = 0.0
var _have_prev_reference: bool = false
## Kill switches for the three new features (owned by the Tuning Tools panel).
var servo_feedforward_on: bool = Cfg.SERVO_FEEDFORWARD_ENABLED
var hilt_spring_on: bool = Cfg.HILT_SPRING_ENABLED
var show_ghost: bool = Cfg.SHOW_GHOST_ENABLED
var hud: PXHud
var tuner: PXTuningTools
var camera: Camera2D
var hit_flash: float = 0.0
var _log_accum: float = 0.0
var stuck_frames: int = 0
## The knight's animation, advanced by hand so _draw can place him exactly between
## the world and the blade (the grass fills the arena, so a child sprite would sit
## either over everything or under the ground).
var _knight_frames: SpriteFrames = null
var _knight_anim: StringName = &"idle"
var _knight_frame: int = 0
var _knight_frame_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player()
	_build_knight_frames()
	_build_camera()
	hud = PXHud.new()
	add_child(hud)
	hud.close_requested.connect(_close)
	tuner = PXTuningTools.new()
	add_child(tuner)
	tuner.chaser_toggled.connect(_set_chaser_wanted)
	tuner.sword_enemy_toggled.connect(_set_sword_enemy_wanted)
	tuner.test_dummy_toggled.connect(_set_test_dummy_wanted)
	tuner.metronome_toggled.connect(_set_metronome_wanted)
	tuner.aim_inertia_toggled.connect(_set_aim_inertia_wanted)
	tuner.windup_toggled.connect(_set_windup_wanted)
	tuner.servo_feedforward_toggled.connect(_set_servo_feedforward_wanted)
	tuner.hilt_spring_toggled.connect(_set_hilt_spring_wanted)
	tuner.show_ghost_toggled.connect(_set_show_ghost_wanted)
	tuner.save_settings_requested.connect(_save_bdpx_global)
	tuner.load_settings_requested.connect(_load_bdpx_global)
	# Bring back the last saved BDPX setup, if there is one. Deliberately its own
	# file (user://bdpx_global.json) — the game's live save is never touched.
	if BDPXGlobal.has_save():
		apply_settings(BDPXGlobal.load_settings())
	queue_redraw()


# ── Construction ────────────────────────────────────────────────────────────
func _build_camera() -> void:
	camera = Camera2D.new()
	# Zoom 1 => one world unit is one screen pixel at the 1280x720 base viewport,
	# so a 1280x720 arena fills the screen exactly.
	camera.zoom = Vector2.ONE
	add_child(camera)
	camera.make_current()


func _make_body(radius: float, layer: int, mask: int, pos: Vector2) -> CharacterBody2D:
	var body := CharacterBody2D.new()
	body.collision_layer = layer
	body.collision_mask = mask
	body.position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	return body


## Enemies are rigid bodies, not kinematic wallbodies: this is what lets the
## blade physically shove them and slide along their shape. They seek the player
## softly (see _update_enemies), so contact is yielded, not snapped back.
func _make_enemy_body(pos: Vector2) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.mass = Cfg.ENEMY_MASS
	body.gravity_scale = 0.0
	body.linear_damp = Cfg.ENEMY_LINEAR_DAMP
	body.angular_damp = Cfg.ENEMY_ANGULAR_DAMP
	body.can_sleep = false
	body.collision_layer = Cfg.L_ENEMY
	body.collision_mask = Cfg.L_WALLS | Cfg.L_PLAYER | Cfg.L_PLAYER_SWORD
	var phys_material: PhysicsMaterial = PhysicsMaterial.new()
	phys_material.friction = Cfg.ENEMY_FRICTION
	phys_material.bounce = 0.0
	body.physics_material_override = phys_material
	body.position = pos
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = Cfg.ENEMY_RADIUS
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	return body


func _build_player() -> void:
	player = _make_body(Cfg.PLAYER_RADIUS, Cfg.L_PLAYER, Cfg.L_WALLS | Cfg.L_ENEMY, Vector2.ZERO)
	# The grip is a KINEMATIC anchor (AnimatableBody2D, not StaticBody2D) we
	# drive to the hand each frame; the pin carries the hilt along with it. The
	# blade stays a REAL rigid body, so it still fully collides with walls,
	# bodies and other blades.
	player_anchor = PXBlade.make_grip()
	add_child(player_anchor)
	player_sword = PXBlade.make_blade(self, Cfg.L_PLAYER_SWORD, Cfg.L_WALLS | Cfg.L_ENEMY | Cfg.L_ENEMY_SWORD)
	player_pin = PXBlade.pin(self, player_anchor, player_sword, Vector2.ZERO)
	# (The blade's pose is earned physics: the motor below, the solver above.)


## The knight's SpriteFrames, built the same way the real game builds its HD armor
## sprite (an idle frame + a two-frame walk atlas). Purely visual: it never touches
## the physics or the sword.
func _build_knight_frames() -> void:
	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 1.0)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", KNIGHT_IDLE)
	frames.add_animation("walking")
	frames.set_animation_speed("walking", KNIGHT_WALK_FPS)
	frames.set_animation_loop("walking", true)
	for i: int in range(2):
		var frame := AtlasTexture.new()
		frame.atlas = KNIGHT_WALK
		frame.region = Rect2(KNIGHT_FRAME_SIZE * float(i), 0.0, KNIGHT_FRAME_SIZE, KNIGHT_FRAME_SIZE)
		frames.add_frame("walking", frame)
	_knight_frames = frames


## Walk when the body is moving, idle when it stops. Facing is left/right only,
## like the real game — he never turns to face up/down in the arena.
func _update_knight(delta: float) -> void:
	if _knight_frames == null:
		return
	var anim: StringName = &"walking" if player.velocity.length() > 8.0 else &"idle"
	if anim != _knight_anim:
		_knight_anim = anim
		_knight_frame = 0
		_knight_frame_time = 0.0
	var count: int = _knight_frames.get_frame_count(_knight_anim)
	if count <= 1:
		return
	var step: float = 1.0 / maxf(_knight_frames.get_animation_speed(_knight_anim), 0.001)
	_knight_frame_time += delta
	while _knight_frame_time >= step:
		_knight_frame_time -= step
		_knight_frame = (_knight_frame + 1) % count


# ── Enemies ─────────────────────────────────────────────────────────────────
func _set_chaser_wanted(on: bool) -> void:
	chaser_wanted = on
	chaser_timer = 0.0
	if on:
		if not _has_enemy(false):
			_spawn_enemy(false, PXArena.random_edge_point())
	else:
		_remove_enemies_of_type(false)


func _set_sword_enemy_wanted(on: bool) -> void:
	sword_enemy_wanted = on
	sword_enemy_timer = 0.0
	if on:
		if not _has_enemy(true):
			_spawn_enemy(true, PXArena.random_edge_point())
	else:
		_remove_enemies_of_type(true)


func _set_test_dummy_wanted(on: bool) -> void:
	if on:
		if not _has_test_dummy():
			var entry: Dictionary = PXTestDummy.make_entry(self, Cfg.TEST_DUMMY_SPAWN_POSITION)
			enemies.append(entry)
	else:
		_remove_test_dummies()
	queue_redraw()


func _has_test_dummy() -> bool:
	for entry: Dictionary in enemies:
		if bool(entry.get("test_dummy", false)) and is_instance_valid(entry["body"]):
			return true
	return false


func _remove_test_dummies() -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if bool(entry.get("test_dummy", false)):
			_despawn_enemy(entry)
		else:
			kept.append(entry)
	enemies = kept


func _has_enemy(armed: bool) -> bool:
	for entry: Dictionary in enemies:
		if bool(entry.get("test_dummy", false)):
			continue
		if bool(entry["armed"]) == armed and is_instance_valid(entry["body"]):
			return true
	return false


func _remove_enemies_of_type(armed: bool) -> void:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if not bool(entry.get("test_dummy", false)) and bool(entry["armed"]) == armed:
			_despawn_enemy(entry)
		else:
			kept.append(entry)
	enemies = kept


func _spawn_enemy(armed: bool, pos: Vector2) -> void:
	var body := _make_enemy_body(pos)
	var entry: Dictionary = {
		"body": body,
		"armed": armed,
		"hp": Cfg.ENEMY_MAX_HEALTH,
		"hit_cd": 0.0,
		"touch_cd": 0.0,
		"flash": 0.0,
		"anchor": null,
		"sword": null,
		"sword_hit_cd": 0.0,
	}
	if armed:
		var anchor := PXBlade.make_grip()
		anchor.position = pos + Vector2(Cfg.ENEMY_RADIUS + Cfg.ENEMY_HAND_OFFSET, 0.0)
		add_child(anchor)
		var sword := PXBlade.make_blade(self, Cfg.L_ENEMY_SWORD, Cfg.L_WALLS | Cfg.L_PLAYER | Cfg.L_PLAYER_SWORD)
		sword.position = anchor.position
		PXBlade.pin(self, anchor, sword, anchor.position)
		entry["anchor"] = anchor
		entry["sword"] = sword
	enemies.append(entry)


func _despawn_enemy(entry: Dictionary) -> void:
	for key: String in ["body", "anchor", "sword"]:
		var node: Node = entry[key]
		if node != null and is_instance_valid(node):
			node.queue_free()


# ── Simulation ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_update_player(delta)
	_update_knight(delta)
	_update_player_sword(delta)
	_update_enemies(delta)
	_resolve_player_sword_hits(delta)
	_resolve_enemy_damage(delta)
	_resolve_spawns(delta)
	_update_camera(delta)
	_update_hud()
	_log_accum += delta
	var aim_error_deg: float = rad_to_deg(angle_difference(player_sword.rotation, sword_target))
	var hilt_err: float = player_anchor.global_position.distance_to(player_sword.global_position)
	if absf(aim_error_deg) > 40.0 and absf(player_sword.angular_velocity) < 0.4:
		stuck_frames += 1
	if _log_accum >= 0.25:
		_log_accum = 0.0
		var tq: float = PXBlade.pd_torque(player_sword.rotation, player_sword.angular_velocity, sword_target, tuner.stiffness, tuner.damping, tuner.max_torque)
		var blocker: String = "none"
		if player.get_slide_collision_count() > 0:
			var hit: KinematicCollision2D = player.get_slide_collision(0)
			var collider: Object = hit.get_collider()
			blocker = "%s@%s" % [collider.get_class(), (collider as Node2D).global_position]
		# Nearest enemy distance from the player (−1 = none), so we can see the
		# sword's reach against an approach.
		var near: float = -1.0
		for entry: Dictionary in enemies:
			var b: Node2D = entry["body"]
			if not is_instance_valid(b):
				continue
			var d: float = b.global_position.distance_to(player.global_position)
			if near < 0.0 or d < near:
				near = d
		print("[PX] hp=%d en=%d hand=%.1f hilt_err=%.2f metro=%s target=%.1f sword=%.1f err=%.1f omega=%.2f tq=%.0f c=%d pv=%.0f stuck=%d ref_err=%.1f wref=%.2f near=%.0f player_pos=%s block=%s" % [
			int(player_health), enemies.size(), hand_radius, hilt_err, ("ON" if metronome_on else "off"),
			rad_to_deg(sword_target), rad_to_deg(player_sword.rotation), aim_error_deg,
			player_sword.angular_velocity, tq, player_sword.get_contact_count(),
			player.velocity.length(), stuck_frames,
			rad_to_deg(angle_difference(player_sword.rotation, reference_angle)), reference_omega,
			near, player.global_position, blocker,
		])
	queue_redraw()


func _update_player(delta: float) -> void:
	dash_cooldown_left = maxf(0.0, dash_cooldown_left - delta)

	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): move.y += 1.0
	move = move.normalized()

	if Input.is_physical_key_pressed(KEY_SPACE) and dash_cooldown_left <= 0.0 and dash_time_left <= 0.0:
		dash_direction = move if move != Vector2.ZERO else aim_direction
		dash_time_left = Cfg.DASH_TIME
		dash_cooldown_left = Cfg.DASH_COOLDOWN

	if dash_time_left > 0.0:
		dash_time_left = maxf(0.0, dash_time_left - delta)
		player.velocity = dash_direction * Cfg.DASH_SPEED
	else:
		player.velocity = move * Cfg.MOVE_SPEED
	player.move_and_slide()


func _motor_torque(sword: RigidBody2D, target_angle: float, target_omega: float = 0.0) -> float:
	var omega_ref: float = target_omega if servo_feedforward_on else 0.0
	return PXBlade.servo_torque(sword.rotation, sword.angular_velocity, target_angle, omega_ref, tuner.stiffness, tuner.damping, tuner.max_torque)


## The COMMANDED aim, with optional weight. It never touches the blade: it just
## decides where the motor is asked to point.
##
##   OFF — the aim is the cursor, instantly (the old behaviour).
##   ON  — a two-stage filter, the same shape the game uses in "Core Sword &
##         Reach": the aim POINT drags toward the cursor (Mouse Drag), then the
##         aim ANGLE drags toward that point (Rotation Speed), capped at Max Turn
##         Speed. So a fast cursor flick can't whip the blade — the request has
##         weight, and the motor still has to earn the motion against real mass.
func _update_aim(delta: float) -> void:
	var cursor: Vector2 = get_global_mouse_position()
	var to_cursor: Vector2 = cursor - player.global_position
	if not _aim_ready:
		# Seed from wherever the cursor is so the first frame never snaps.
		aim_point = cursor
		aim_angle = to_cursor.angle() if to_cursor.length_squared() > 4.0 else aim_direction.angle()
		_aim_ready = true
	if aim_inertia_on:
		var drag_rate: float = clampf(tuner.mouse_drag, 2.0, 50.0)
		aim_point = aim_point.lerp(cursor, clampf(1.0 - exp(-drag_rate * delta), 0.0, 1.0))
		var to_point: Vector2 = aim_point - player.global_position
		var target_angle: float = to_point.angle() if to_point.length_squared() > 4.0 else aim_angle
		aim_angle += _aim_turn_step(aim_angle, target_angle, delta)
	else:
		aim_point = cursor
		if to_cursor.length_squared() > 4.0:
			aim_angle = to_cursor.angle()
	aim_direction = Vector2.from_angle(aim_angle)
	hand_radius = _hand_radius_from_point(aim_point)


## One frame of the aim-angle filter ("Rotation Speed", capped by "Max Turn
## Speed"). Pure and un-gated, so it can be tested without a live cursor; the
## Aim Inertia toggle is honoured by the caller. It always returns a fraction of
## the remaining error, so a big cursor jump is walked down over frames rather
## than snapping in one.
func _aim_turn_step(current_angle: float, target_angle: float, delta: float) -> float:
	var diff: float = angle_difference(current_angle, target_angle)
	var step: float = diff * clampf(tuner.rotation_speed * delta, 0.0, 1.0)
	if tuner.max_turn_speed_deg > 0.0:
		var max_step: float = deg_to_rad(tuner.max_turn_speed_deg) * delta
		step = clampf(step, -max_step, max_step)
	return step


## Blade Dancer's hand rule, copied from player.gd:_mouse_controlled_hand_radius():
## the cursor's distance from the body picks a point between min and max, but the
## distance is GEARED by `scale` — full extension needs the cursor out at
## min + (max-min)*scale, so the reach eases in rather than tracking linearly. The
## pair is ordered here rather than trusted, so dragging Min past Max on the panel
## swaps which end is which instead of collapsing the range to nothing.
func _hand_radius_from_point(point: Vector2) -> float:
	var minimum: float = minf(tuner.hand_min, tuner.hand_max)
	var maximum: float = maxf(tuner.hand_min, tuner.hand_max)
	if maximum - minimum < 0.001:
		return minimum
	var reach_scale: float = maxf(Cfg.REACH_SCALE, 0.01)
	var input_maximum: float = maxf(minimum + (maximum - minimum) * reach_scale, minimum + 0.001)
	var distance: float = player.global_position.distance_to(point)
	var amount: float = clampf(inverse_lerp(minimum, input_maximum, distance), 0.0, 1.0)
	return lerpf(minimum, maximum, amount)


func _set_metronome_wanted(on: bool) -> void:
	metronome_on = on
	# Restart the sweep from the aim so switching on never snaps the blade.
	metronome_phase = 0.0


func _set_windup_wanted(on: bool) -> void:
	windup_on = on


func _set_aim_inertia_wanted(on: bool) -> void:
	aim_inertia_on = on


func _set_servo_feedforward_wanted(on: bool) -> void:
	servo_feedforward_on = on


func _set_hilt_spring_wanted(on: bool) -> void:
	hilt_spring_on = on


func _set_show_ghost_wanted(on: bool) -> void:
	show_ghost = on
	queue_redraw()


# ── BDPX Global save ────────────────────────────────────────────────────────
## The whole tunable setup in one dictionary — the motor feel, the metronome and
## the spawn toggles — which is exactly what BDPXGlobal persists.
func current_settings() -> Dictionary:
	return {
		"stiffness": tuner.stiffness,
		"damping": tuner.damping,
		"max_torque": tuner.max_torque,
		"metronome_on": tuner.metronome_on,
		"arc_degrees": tuner.arc_degrees,
		"frequency": tuner.frequency,
		"lead_degrees": tuner.lead_degrees,
		"windup_on": tuner.windup_on,
		"windup_profile": tuner.windup_profile,
		"aim_inertia_on": tuner.aim_inertia_on,
		"mouse_drag": tuner.mouse_drag,
		"rotation_speed": tuner.rotation_speed,
		"max_turn_speed_deg": tuner.max_turn_speed_deg,
		"hand_min": tuner.hand_min,
		"hand_max": tuner.hand_max,
		"servo_feedforward_on": tuner.servo_feedforward_on,
		"hilt_spring_on": tuner.hilt_spring_on,
		"show_ghost": tuner.show_ghost,
		"ghost_opacity": tuner.ghost_opacity,
		"chaser_wanted": chaser_wanted,
		"sword_enemy_wanted": sword_enemy_wanted,
		"test_dummy_wanted": _has_test_dummy(),
	}


## Push a settings dictionary through the panel, so every control (and therefore
## every tunable and spawn toggle) adopts it. The panel's own signals do the
## spawning, so the game never reaches past the overlay.
func apply_settings(state: Dictionary) -> void:
	tuner.apply_values(state)


func _save_bdpx_global() -> void:
	BDPXGlobal.save_settings(current_settings())
	tuner.show_saved_state()


func _load_bdpx_global() -> void:
	apply_settings(BDPXGlobal.load_settings())
	tuner.show_saved_state()


func _update_player_sword(delta: float) -> void:
	_update_aim(delta)
	# The grip is INPUT: we move the hand anchor and the pin carries the hilt
	# with it. We never touch the sword's transform — the solver owns all of it,
	# so the blade collides like the rigid body it is.
	player_anchor.position = player.global_position + aim_direction * hand_radius
	reference_hilt = player_anchor.position
	sword_target = _advance_sword_target(delta)
	_update_reference_omega(delta)
	# The hilt pin: rigid, or springy enough that a contact can shove the grip off
	# the hand and it recovers. Pure on/off — no number to fiddle with.
	player_pin.softness = Cfg.HILT_SOFTNESS if hilt_spring_on else 0.0
	player_sword.apply_torque(_motor_torque(player_sword, sword_target, reference_omega))


## The reference's angular velocity, from the change in reference angle since the
## last frame. angle_difference keeps an aim that wraps past +/-PI from reporting
## a spurious full-turn spike.
func _update_reference_omega(delta: float) -> void:
	if _have_prev_reference:
		reference_omega = angle_difference(_prev_reference_angle, reference_angle) / maxf(delta, 1e-5)
	else:
		reference_omega = 0.0
		_have_prev_reference = true
	_prev_reference_angle = reference_angle


## What the motor is asked to chase this frame.
##
##   OFF — the aim itself: the blade points where you point.
##   ON  — Blade Dancer's metronome arc: the SAME sine the game's metronome uses
##         (player.gd _calculate_form_metronome), +/- arc about the aim, `frequency`
##         cycles a second. Arc/frequency are copied from the live GP2 Metronome_Bind
##         hand (105 deg @ 0.65 Hz).
##
## The difference is what the arc MEANS. In the game the resulting pose is
## written straight onto the sword, so the stroke always completes. Here it is
## only a REQUEST: the motor has to earn it with torque against real mass,
## damping and contacts. A swing that meets a wall will lag, jam and lose the
## arc — and that divergence is the thing worth watching.
func _advance_sword_target(delta: float) -> float:
	var base_angle: float = aim_direction.angle()
	if not metronome_on:
		reference_angle = base_angle
		return base_angle
	var step_scale: float = _metronome_step_scale(metronome_phase)
	metronome_phase = wrapf(metronome_phase + delta * tuner.frequency * TAU * step_scale, 0.0, TAU)
	var ideal: float = base_angle + deg_to_rad(tuner.arc_degrees) * sin(metronome_phase)
	# The GHOST is the pure original arc — the sine, untouched.
	reference_angle = ideal
	# Anti-windup leash: the sweep may LEAD the blade, but only by a bounded
	# amount. Free, the blade is always near the ideal so this changes nothing
	# and it tracks the full arc. Blocked, the target parks `lead` ahead of the
	# blade and the motor pushes at a bounded torque — the sine no longer runs
	# off on its own, so there is no stored error to snap free as a helicopter.
	var lead: float = deg_to_rad(tuner.lead_degrees)
	var offset: float = angle_difference(player_sword.rotation, ideal)
	return player_sword.rotation + clampf(offset, -lead, lead)


## Metronome wind-up. The stroke's angular speed is redistributed across the
## half-cycle — it opens at windup_speed, accelerates through the windup to
## strike_speed, then eases back to recovery_speed across recovery. This is
## Blade Dancer's Form II ("Metronome Wind-up"). A time-normalizer keeps the
## AVERAGE at the Frequency slider's rate, so wind-up changes the SHAPE of the
## stroke, not its tempo. It only reshapes the TARGET's motion; the blade still
## earns every degree from the motor.
func _metronome_step_scale(phase: float) -> float:
	if not windup_on:
		return 1.0
	var profile: float = clampf(tuner.windup_profile, 0.0, 1.0)
	if profile <= 0.0:
		return 1.0
	# One stroke is one half-cycle: reversals sit at PI/2 and 3*PI/2.
	var stroke: float = wrapf(phase - PI * 0.5, 0.0, PI) / PI
	var sample_count: int = 16
	var inverse_speed_sum: float = 0.0
	for sample_index: int in range(sample_count):
		var sample_progress: float = (float(sample_index) + 0.5) / float(sample_count)
		inverse_speed_sum += 1.0 / maxf(lerpf(1.0, _windup_raw_speed(sample_progress), profile), 0.05)
	var time_normalizer: float = inverse_speed_sum / float(sample_count)
	return lerpf(1.0, _windup_raw_speed(stroke), profile) * time_normalizer


## Raw speed multiplier at a point in the stroke, before the profile blend.
## Copied AS DATA from the game (player.gd:2106) — the same curve Form II uses.
func _windup_raw_speed(progress: float) -> float:
	var windup: float = clampf(Cfg.WINDUP_FRACTION, 0.05, 0.8)
	var recovery: float = clampf(Cfg.RECOVERY_FRACTION, 0.05, 0.8)
	if windup + recovery > 0.9:
		recovery = 0.9 - windup
	var fast_speed: float = clampf(Cfg.STRIKE_SPEED, 0.1, 6.0)
	var opening_speed: float = clampf(Cfg.WINDUP_SPEED, 0.05, 2.0)
	var closing_speed: float = clampf(Cfg.RECOVERY_SPEED, 0.05, 2.0)
	if progress < windup:
		var windup_t: float = clampf(progress / windup, 0.0, 1.0)
		var windup_eased: float = windup_t * windup_t * (3.0 - 2.0 * windup_t)
		return lerpf(opening_speed, fast_speed, windup_eased)
	var recovery_start: float = 1.0 - recovery
	if progress > recovery_start:
		var recovery_t: float = clampf((progress - recovery_start) / recovery, 0.0, 1.0)
		var recovery_eased: float = recovery_t * recovery_t * (3.0 - 2.0 * recovery_t)
		return lerpf(fast_speed, closing_speed, recovery_eased)
	return fast_speed


func _update_enemies(delta: float) -> void:
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body):
			continue
		if bool(entry.get("test_dummy", false)):
			entry["hit_cd"] = maxf(0.0, float(entry["hit_cd"]) - delta)
			entry["flash"] = maxf(0.0, float(entry["flash"]) - delta)
			PXTestDummy.tick_regeneration(entry, delta)
			continue
		entry["hit_cd"] = maxf(0.0, float(entry["hit_cd"]) - delta)
		entry["touch_cd"] = maxf(0.0, float(entry["touch_cd"]) - delta)
		entry["sword_hit_cd"] = maxf(0.0, float(entry["sword_hit_cd"]) - delta)
		entry["flash"] = maxf(0.0, float(entry["flash"]) - delta)

		var actor: RigidBody2D = body as RigidBody2D
		var to_player: Vector2 = player.global_position - actor.global_position
		var distance: float = to_player.length()
		var direction: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
		var stop_range: float = Cfg.ENEMY_STOP_RANGE_ARMED if bool(entry["armed"]) else Cfg.ENEMY_STOP_RANGE_UNARMED
		# Steer SOFTLY: ease the velocity toward the approach instead of writing it,
		# so a shove from the blade is felt and then recovered rather than snapped.
		var desired: Vector2 = direction * Cfg.ENEMY_SPEED if distance > stop_range else Vector2.ZERO
		actor.linear_velocity = actor.linear_velocity.lerp(desired, clampf(delta * Cfg.ENEMY_STEER_RESPONSE, 0.0, 1.0))

		var sword: RigidBody2D = entry["sword"]
		if sword != null and is_instance_valid(sword):
			var anchor: AnimatableBody2D = entry["anchor"]
			anchor.position = body.global_position + direction * (Cfg.ENEMY_RADIUS + Cfg.ENEMY_HAND_OFFSET)
			sword.apply_torque(_motor_torque(sword, direction.angle()))
			var tip: Vector2 = PXBlade.tip_of(sword)
			if float(entry["sword_hit_cd"]) <= 0.0 and _segment_circle_overlap(sword.global_position, tip, player.global_position, Cfg.PLAYER_RADIUS):
				player_health -= Cfg.ENEMY_SWORD_DAMAGE
				entry["sword_hit_cd"] = Cfg.SWING_HIT_COOLDOWN
				hit_flash = 0.18


func _resolve_player_sword_hits(_delta: float) -> void:
	var hilt: Vector2 = player_sword.global_position
	var tip: Vector2 = PXBlade.tip_of(player_sword)
	var omega: float = absf(player_sword.angular_velocity)
	var speed_scale: float = clampf(0.15 + omega / 4.0, 0.15, 2.0)
	var killed: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body) or float(entry["hit_cd"]) > 0.0:
			continue
		if _segment_circle_overlap(hilt, tip, body.global_position, Cfg.ENEMY_RADIUS):
			var damage: float = Cfg.SWING_DAMAGE * speed_scale
			if bool(entry.get("test_dummy", false)):
				PXTestDummy.apply_damage(entry, damage)
			else:
				entry["hp"] = float(entry["hp"]) - damage
			entry["hit_cd"] = Cfg.SWING_HIT_COOLDOWN
			entry["flash"] = 0.16
			if not bool(entry.get("test_dummy", false)) and float(entry["hp"]) <= 0.0:
				killed.append(entry)
	for entry: Dictionary in killed:
		_despawn_enemy(entry)
		enemies.erase(entry)





func _resolve_enemy_damage(_delta: float) -> void:
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body) or bool(entry.get("test_dummy", false)):
			continue
		if float(entry["touch_cd"]) <= 0.0 and body.global_position.distance_to(player.global_position) <= Cfg.ENEMY_RADIUS + Cfg.PLAYER_RADIUS:
			player_health -= Cfg.ENEMY_CONTACT_DAMAGE
			entry["touch_cd"] = Cfg.CONTACT_COOLDOWN
			hit_flash = 0.18
	if player_health <= 0.0:
		_reset_player()


func _reset_player() -> void:
	player_health = Cfg.PLAYER_MAX_HEALTH
	player.global_position = Vector2.ZERO
	var kept: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		if bool(entry.get("test_dummy", false)):
			kept.append(entry)
		else:
			_despawn_enemy(entry)
	enemies = kept
	chaser_timer = 0.0
	sword_enemy_timer = 0.0


## Keeps EXACTLY ONE of each toggled enemy alive: if it dies, another spawns
## after a short delay. Untoggled types are left alone.
func _resolve_spawns(delta: float) -> void:
	if chaser_wanted and not _has_enemy(false):
		chaser_timer += delta
		if chaser_timer >= Cfg.RESPAWN_DELAY:
			chaser_timer = 0.0
			_spawn_enemy(false, PXArena.random_edge_point())
	else:
		chaser_timer = 0.0

	if sword_enemy_wanted and not _has_enemy(true):
		sword_enemy_timer += delta
		if sword_enemy_timer >= Cfg.RESPAWN_DELAY:
			sword_enemy_timer = 0.0
			_spawn_enemy(true, PXArena.random_edge_point())
	else:
		sword_enemy_timer = 0.0


func _update_camera(delta: float) -> void:
	var target: Vector2 = player.global_position + aim_direction * 60.0
	# Keep the view INSIDE the arena. When the arena is no bigger than one screen
	# (by design) this pins the camera to the centre so the whole map stays on
	# screen; if the arena were ever made larger, the camera would follow within
	# the walls instead. Half the visible world, in arena units.
	var half_view: Vector2 = get_viewport_rect().size * 0.5 / camera.zoom
	var center: Vector2 = Cfg.ARENA.get_center()
	target.x = center.x if Cfg.ARENA.size.x <= half_view.x * 2.0 else clampf(target.x, Cfg.ARENA.position.x + half_view.x, Cfg.ARENA.end.x - half_view.x)
	target.y = center.y if Cfg.ARENA.size.y <= half_view.y * 2.0 else clampf(target.y, Cfg.ARENA.position.y + half_view.y, Cfg.ARENA.end.y - half_view.y)
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 7.0, 0.0, 1.0))


func _segment_circle_overlap(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(center) <= radius


# ── Presentation ────────────────────────────────────────────────────────────
func _update_hud() -> void:
	var lines: Array[String] = [
		"BLADE DANCER PX — playable prototype",
		"",
		"HP            %d / %d" % [maxi(0, int(round(player_health))), int(Cfg.PLAYER_MAX_HEALTH)],
		"chaser        %s" % ("ON" if chaser_wanted else "off"),
		"sword enemy   %s" % ("ON" if sword_enemy_wanted else "off"),
		"test dummy    %s" % ("ON" if _has_test_dummy() else "off"),
		"hand          %.1f px  (range %.0f-%.0f)" % [hand_radius, minf(tuner.hand_min, tuner.hand_max), maxf(tuner.hand_min, tuner.hand_max)],
		"metronome     %s" % ("ON  (%.0f deg @ %.2f Hz)" % [tuner.arc_degrees, tuner.frequency] if metronome_on else "off"),
		"",
		"WASD / arrows  move",
		"mouse          steers the sword",
		"SPACE          dash",
	]
	hud.set_lines(lines)


func _draw_blade(sword: RigidBody2D, color: Color) -> void:
	if sword == null or not is_instance_valid(sword):
		return
	var xf: Transform2D = sword.global_transform
	if sword == player_sword:
		# Only the drawing follows the solver's body. The pommel trails the hilt;
		# the art's crossguard sits at the hilt and its tip reaches the blade tip.
		var scale_factor: float = Cfg.BLADE_LENGTH / 1110.0
		var center: Vector2 = xf.origin + xf.x * (378.0 * scale_factor)
		draw_set_transform(center, xf.get_rotation() - PI * 0.5)
		draw_texture_rect(SWORD_TEXTURE, Rect2(-512.0 * scale_factor, -768.0 * scale_factor, 1024.0 * scale_factor, 1536.0 * scale_factor), false)
		draw_set_transform(Vector2.ZERO)
		return
	var half: float = Cfg.BLADE_THICKNESS * 0.5
	var corners := PackedVector2Array([
		xf * Vector2(0.0, -half),
		xf * Vector2(Cfg.BLADE_LENGTH, -half),
		xf * Vector2(Cfg.BLADE_LENGTH, half),
		xf * Vector2(0.0, half),
	])
	draw_colored_polygon(corners, color)
	draw_polyline(corners + PackedVector2Array([corners[0]]), Color(1, 1, 1, 0.85), 1.5)


func _draw() -> void:
	draw_texture_rect(GRASS_TEXTURE, Cfg.ARENA, true)
	# Aim ray.
	draw_line(player_sword.global_position, player_sword.global_position + (get_global_mouse_position() - player.global_position).normalized() * 400.0, Color(0.4, 0.7, 1.0, 0.10), 2.0)

	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body):
			continue
		var is_dummy: bool = bool(entry.get("test_dummy", false))
		var armed: bool = bool(entry["armed"])
		var base: Color = Cfg.TEST_DUMMY_COLOR if is_dummy else (Color(0.78, 0.42, 0.36) if armed else Color(0.45, 0.55, 0.62))
		if float(entry["flash"]) > 0.0: base = Color(1.0, 0.95, 0.75)
		draw_circle(body.global_position, Cfg.ENEMY_RADIUS, base, true)
		draw_arc(body.global_position, Cfg.ENEMY_RADIUS, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 2.0)
		if armed:
			_draw_blade(entry["sword"], Color(0.72, 0.30, 0.28, 0.95))
		if is_dummy:
			draw_string(ThemeDB.fallback_font, body.global_position + Vector2(-30.0, -Cfg.ENEMY_RADIUS - 19.0), Cfg.TEST_DUMMY_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Cfg.TEST_DUMMY_COLOR)
		# Health bar uses each enemy's own cap when provided.
		var max_hp: float = float(entry.get("max_hp", Cfg.ENEMY_MAX_HEALTH))
		var hp_frac: float = clampf(float(entry["hp"]) / max_hp, 0.0, 1.0)
		var bar_pos: Vector2 = body.global_position + Vector2(-Cfg.ENEMY_RADIUS, -Cfg.ENEMY_RADIUS - 12.0)
		draw_rect(Rect2(bar_pos, Vector2(Cfg.ENEMY_RADIUS * 2.0, 5.0)), Color(0, 0, 0, 0.6), true)
		var health_color: Color = Cfg.TEST_DUMMY_HEALTH_COLOR if is_dummy else Color(0.9, 0.3, 0.3)
		draw_rect(Rect2(bar_pos, Vector2(Cfg.ENEMY_RADIUS * 2.0 * hp_frac, 5.0)), health_color, true)

	# Player — the game's own knight, reused as art only. Drawn here (between the
	# world and the blade) so the sword still reads in front of him. He faces
	# left/right, like the real game; the faint ring marks the exact collision
	# point that the sword math orbits.
	var knight_tex: Texture2D = _knight_frames.get_frame_texture(_knight_anim, _knight_frame) if _knight_frames != null else null
	if knight_tex != null:
		var knight_half: float = KNIGHT_FRAME_SIZE * 0.5 * KNIGHT_SCALE
		var knight_tint: Color = Color(1.0, 0.45, 0.45, 1.0) if hit_flash > 0.0 else Color.WHITE
		draw_set_transform(player.global_position, 0.0, Vector2(-1.0, 1.0) if aim_direction.x < 0.0 else Vector2.ONE)
		draw_texture_rect(knight_tex, Rect2(-knight_half, -knight_half, knight_half * 2.0, knight_half * 2.0), false, knight_tint)
		draw_set_transform(Vector2.ZERO)
	draw_arc(player.global_position, Cfg.PLAYER_RADIUS, 0.0, TAU, 28, Color(0.9, 0.97, 1.0, 0.30), 1.5)
	# The ghost draws UNDER the solid blade: when the physics mirrors the reference
	# exactly the ghost hides completely, and any lag peeks out as a translucent edge.
	if show_ghost:
		_draw_ghost()
	_draw_blade(player_sword, Color(0.86, 0.90, 0.97, 0.96))


## The ghost: the REAL sword art at the ORIGINAL target pose (where the hand and
## blade are ASKED to be), drawn translucent UNDER the physical blade. Same
## texture, same scale, same offset as the physical blade, so any gap you see is
## pure physics lag — never an art mismatch. Tune until the ghost hides behind the
## solid blade; the thin tie line and the readout expose the remaining error.
func _draw_ghost() -> void:
	var alpha: float = clampf(tuner.ghost_opacity, 0.0, 100.0) * 0.01
	if alpha <= 0.0:
		return
	# Identical placement maths to _draw_blade's player branch, just at the
	# reference pose instead of the body's.
	var scale_factor: float = Cfg.BLADE_LENGTH / 1110.0
	var center: Vector2 = reference_hilt + Vector2.from_angle(reference_angle) * (378.0 * scale_factor)
	draw_set_transform(center, reference_angle - PI * 0.5)
	draw_texture_rect(SWORD_TEXTURE, Rect2(-512.0 * scale_factor, -768.0 * scale_factor, 1024.0 * scale_factor, 1536.0 * scale_factor), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO)
	# The gap between the reference hand and the physical hilt.
	draw_line(reference_hilt, player_sword.global_position, Color(1, 1, 1, 0.5), 1.0)
	var angular_error_deg: float = rad_to_deg(angle_difference(player_sword.rotation, reference_angle))
	var hilt_offset: float = player_sword.global_position.distance_to(reference_hilt)
	var label: String = "REF\n  err %+.1f deg\n  wref %.2f  w %.2f rad/s\n  hilt gap %.1f px" % [
		angular_error_deg, reference_omega, player_sword.angular_velocity, hilt_offset,
	]
	draw_multiline_string(ThemeDB.fallback_font, reference_hilt + Vector2(8.0, 58.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, -1, Color(0.35, 0.95, 1.0, 0.85))


func _process(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)


func _close() -> void:
	closed.emit()
	if get_tree().current_scene == self:
		get_tree().quit()