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

# ── Runtime ─────────────────────────────────────────────────────────────────
var player: CharacterBody2D
var player_anchor: AnimatableBody2D
var player_sword: RigidBody2D

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
var hud: PXHud
var tuner: PXTuningTools
var camera: Camera2D
var hit_flash: float = 0.0
var _log_accum: float = 0.0
var stuck_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_player()
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
	queue_redraw()


# ── Construction ────────────────────────────────────────────────────────────
func _build_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
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


func _build_player() -> void:
	player = _make_body(Cfg.PLAYER_RADIUS, Cfg.L_PLAYER, Cfg.L_WALLS | Cfg.L_ENEMY, Vector2.ZERO)
	# The grip is a KINEMATIC anchor (AnimatableBody2D, not StaticBody2D) we
	# drive to the hand each frame; the pin carries the hilt along with it. The
	# blade stays a REAL rigid body, so it still fully collides with walls,
	# bodies and other blades.
	player_anchor = PXBlade.make_grip()
	add_child(player_anchor)
	player_sword = PXBlade.make_blade(self, Cfg.L_PLAYER_SWORD, Cfg.L_WALLS | Cfg.L_ENEMY | Cfg.L_ENEMY_SWORD)
	PXBlade.pin(self, player_anchor, player_sword, Vector2.ZERO)
	# (The blade's pose is earned physics: the motor below, the solver above.)


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
	var body := _make_body(Cfg.ENEMY_RADIUS, Cfg.L_ENEMY, Cfg.L_WALLS | Cfg.L_PLAYER, pos)
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
		print("[PX] hp=%d en=%d hand=%.1f hilt_err=%.2f metro=%s target=%.1f sword=%.1f err=%.1f omega=%.2f tq=%.0f c=%d pv=%.0f stuck=%d player_pos=%s block=%s" % [
			int(player_health), enemies.size(), hand_radius, hilt_err, ("ON" if metronome_on else "off"),
			rad_to_deg(sword_target), rad_to_deg(player_sword.rotation), aim_error_deg,
			player_sword.angular_velocity, tq, player_sword.get_contact_count(),
			player.velocity.length(), stuck_frames, player.global_position, blocker,
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


func _current_aim_direction() -> Vector2:
	var mouse: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse - player.global_position
	if to_mouse.length_squared() < 4.0:
		return aim_direction
	return to_mouse.normalized()


func _motor_torque(sword: RigidBody2D, target_angle: float) -> float:
	return PXBlade.pd_torque(sword.rotation, sword.angular_velocity, target_angle, tuner.stiffness, tuner.damping, tuner.max_torque)


## Blade Dancer's hand rule: cursor distance drives the grip's reach, between the
## tuner's minimum and maximum. The pair is ordered here rather than trusted, so
## dragging Min past Max on the panel swaps which end is which instead of
## collapsing the range to nothing.
func _hand_radius_from_cursor() -> float:
	var minimum: float = minf(tuner.hand_min, tuner.hand_max)
	var maximum: float = maxf(tuner.hand_min, tuner.hand_max)
	if maximum - minimum < 0.001:
		return minimum
	var mouse: Vector2 = get_global_mouse_position()
	var distance: float = player.global_position.distance_to(mouse)
	var amount: float = clampf(inverse_lerp(minimum, maximum, distance), 0.0, 1.0)
	return lerpf(minimum, maximum, amount)


func _set_metronome_wanted(on: bool) -> void:
	metronome_on = on
	# Restart the sweep from the aim so switching on never snaps the blade.
	metronome_phase = 0.0


func _update_player_sword(delta: float) -> void:
	aim_direction = _current_aim_direction()
	hand_radius = _hand_radius_from_cursor()
	# The grip is INPUT: we move the hand anchor and the pin carries the hilt
	# with it. We never touch the sword's transform — the solver owns all of it,
	# so the blade collides like the rigid body it is.
	player_anchor.position = player.global_position + aim_direction * hand_radius
	sword_target = _advance_sword_target(delta)
	player_sword.apply_torque(_motor_torque(player_sword, sword_target))


## What the motor is asked to chase this frame.
##
##   OFF — the aim itself: the blade points where you point.
##   ON  — Blade Dancer's Form III arc: the SAME sine the game's metronome uses
##         (player.gd:3332), +/- arc about the aim, `frequency` cycles a second.
##
## The difference is what the arc MEANS. In the game the resulting pose is
## written straight onto the sword, so the stroke always completes. Here it is
## only a REQUEST: the motor has to earn it with torque against real mass,
## damping and contacts. A swing that meets a wall will lag, jam and lose the
## arc — and that divergence is the thing worth watching.
func _advance_sword_target(delta: float) -> float:
	var base_angle: float = aim_direction.angle()
	if not metronome_on:
		return base_angle
	metronome_phase = wrapf(metronome_phase + delta * tuner.frequency * TAU, 0.0, TAU)
	return base_angle + deg_to_rad(tuner.arc_degrees) * sin(metronome_phase)


func _update_enemies(delta: float) -> void:
	for entry: Dictionary in enemies:
		var body: CharacterBody2D = entry["body"]
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

		var to_player: Vector2 = player.global_position - body.global_position
		var distance: float = to_player.length()
		var direction: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
		var stop_range: float = Cfg.ENEMY_STOP_RANGE_ARMED if bool(entry["armed"]) else Cfg.ENEMY_STOP_RANGE_UNARMED
		if distance > stop_range:
			body.velocity = direction * Cfg.ENEMY_SPEED
		else:
			body.velocity = Vector2.ZERO
		body.move_and_slide()

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
		var body: CharacterBody2D = entry["body"]
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
		var body: CharacterBody2D = entry["body"]
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
		var body: CharacterBody2D = entry["body"]
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

	# Player.
	var body_color := Color(1.0, 0.35, 0.35) if hit_flash > 0.0 else Color(0.55, 0.85, 1.0)
	draw_circle(player.global_position, Cfg.PLAYER_RADIUS, body_color, true)
	draw_arc(player.global_position, Cfg.PLAYER_RADIUS, 0.0, TAU, 28, Color(0.9, 0.97, 1.0), 2.0)
	_draw_blade(player_sword, Color(0.86, 0.90, 0.97, 0.96))


func _process(delta: float) -> void:
	hit_flash = maxf(0.0, hit_flash - delta)


func _close() -> void:
	closed.emit()
	if get_tree().current_scene == self:
		get_tree().quit()