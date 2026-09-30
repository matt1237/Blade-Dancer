class_name PXInWorldEnemies extends Node2D
## PX IN-WORLD ENEMIES — the lab's spawnable targets (chaser, sword enemy, test
## dummy), brought into the REAL game behind PX Mode.
##
## Ported from the standalone prototype's enemy system (px_game.gd). The bodies are
## genuine RigidBody2D, so the physics sword can SHOVE them and slide along them —
## they yield to contact instead of being scripted back, exactly like the lab. They
## share no gameplay code with the game and exist only while PX Mode is on; the
## manager is a child of the in-world sword, so standing PX Mode down removes them
## with it.
##
## Two deliberate differences from the lab: spawns land on a ring around the game's
## player (the game world is not the lab's fixed arena), and PX enemies deal NO
## damage to the real player — they are physics targets to feel the sword on, not a
## second combat system bolted onto the game.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")
const PXTestDummy = preload("res://blade_dancer_px/scripts/px_test_dummy.gd")
## The game's collision layers are unknown to PX, so an enemy simply collides with
## EVERYTHING (all 32 layers): that covers the game's walls, the physics blade, and
## the game's own bodies, without PX having to guess a single layer number.
const COLLIDE_WITH_ALL: int = 0x7FFFFFFF

## A fresh spawn — and every RESPAWN — lands this far from the player, at a random
## angle. Kept WELL INSIDE one 1280x720 screen (visible half-extents are 640 x 360) so
## a respawned chaser is always seen. Near the player, who is himself inside the arena,
## it also lands inside the walls instead of stranding outside them and never arriving
## — the failure that reads to the player as "it didn't respawn".
const SPAWN_DISTANCE_MIN: float = 190.0
const SPAWN_DISTANCE_MAX: float = 310.0

var player: Node2D = null
var sword: RigidBody2D = null

var enemies: Array[Dictionary] = []
var chaser_wanted: bool = false
var sword_enemy_wanted: bool = false
var test_dummy_wanted: bool = false
var chaser_timer: float = 0.0
var sword_enemy_timer: float = 0.0

## Enemy material (LIVE-tunable): flesh and core. See px_config for the meaning.
var flesh_radius: float = Cfg.FLESH_RADIUS_DEFAULT
var core_radius: float = Cfg.BONE_CORE_RADIUS_DEFAULT
var flesh_drag: float = Cfg.FLESH_DRAG_DEFAULT
var bone_friction: float = Cfg.BONE_FRICTION_DEFAULT
var enemy_mass: float = Cfg.ENEMY_MASS


func setup(player_node: Node2D, sword_body: RigidBody2D) -> void:
	player = player_node
	sword = sword_body
	# Run just after the sword (priority 50) so we test against this frame's blade.
	process_physics_priority = 60


## Adopt the spawn toggles from a settings dictionary (the shared PX tuner). Each
## toggle is idempotent: switching it on keeps EXACTLY ONE of that kind alive,
## switching it off removes it.
func apply_settings(s: Dictionary) -> void:
	flesh_radius = float(s.get("flesh_radius", flesh_radius))
	core_radius = float(s.get("core_radius", core_radius))
	flesh_drag = float(s.get("flesh_drag", flesh_drag))
	bone_friction = float(s.get("bone_friction", bone_friction))
	enemy_mass = float(s.get("enemy_mass", enemy_mass))
	_set_chaser_wanted(bool(s.get("chaser_wanted", chaser_wanted)))
	_set_sword_enemy_wanted(bool(s.get("sword_enemy_wanted", sword_enemy_wanted)))
	_set_test_dummy_wanted(bool(s.get("test_dummy_wanted", test_dummy_wanted)))


# ── Construction ────────────────────────────────────────────────────────────
## Enemies are rigid bodies, not kinematic wallbodies: this is what lets the blade
## physically shove them and slide along their shape.
func _make_enemy_body(pos: Vector2) -> RigidBody2D:
	var body: RigidBody2D = RigidBody2D.new()
	body.mass = enemy_mass
	body.gravity_scale = 0.0
	body.linear_damp = Cfg.ENEMY_LINEAR_DAMP
	body.angular_damp = Cfg.ENEMY_ANGULAR_DAMP
	body.can_sleep = false
	body.collision_layer = Cfg.L_ENEMY
	body.collision_mask = COLLIDE_WITH_ALL
	var phys_material: PhysicsMaterial = PhysicsMaterial.new()
	phys_material.friction = Cfg.ENEMY_FRICTION
	phys_material.bounce = 0.0
	body.physics_material_override = phys_material
	body.position = to_local(pos)
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	# The SOLID body is only the core. The flesh ring has no collider at all, so the
	# blade passes through it and only stops on the bone.
	circle.radius = core_radius
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	return body


func _spawn_point() -> Vector2:
	var angle: float = randf() * TAU
	var distance: float = randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	return player.global_position + Vector2.from_angle(angle) * distance


func _spawn_enemy(armed: bool, pos: Vector2) -> void:
	var body: RigidBody2D = _make_enemy_body(pos)
	var entry: Dictionary = {
		"body": body,
		"armed": armed,
		"hp": Cfg.ENEMY_MAX_HEALTH,
		"max_hp": Cfg.ENEMY_MAX_HEALTH,
		"hit_cd": 0.0,
		"flash": 0.0,
		"anchor": null,
		"sword": null,
	}
	if armed:
		var anchor: AnimatableBody2D = PXBlade.make_grip()
		anchor.position = to_local(pos) + Vector2(Cfg.ENEMY_RADIUS + Cfg.ENEMY_HAND_OFFSET, 0.0)
		add_child(anchor)
		var enemy_sword: RigidBody2D = PXBlade.make_blade(self, Cfg.L_ENEMY_SWORD, COLLIDE_WITH_ALL)
		enemy_sword.position = anchor.position
		PXBlade.pin(self, anchor, enemy_sword, anchor.position)
		entry["anchor"] = anchor
		entry["sword"] = enemy_sword
	enemies.append(entry)


func _despawn_enemy(entry: Dictionary) -> void:
	for key: String in ["body", "anchor", "sword"]:
		var node: Node = entry[key]
		if node != null and is_instance_valid(node):
			node.queue_free()


# ── Spawn toggles ───────────────────────────────────────────────────────────
func _set_chaser_wanted(on: bool) -> void:
	chaser_wanted = on
	chaser_timer = 0.0
	if on:
		if not _has_enemy(false):
			_spawn_enemy(false, _spawn_point())
	else:
		_remove_enemies_of_type(false)


func _set_sword_enemy_wanted(on: bool) -> void:
	sword_enemy_wanted = on
	sword_enemy_timer = 0.0
	if on:
		if not _has_enemy(true):
			_spawn_enemy(true, _spawn_point())
	else:
		_remove_enemies_of_type(true)


func _set_test_dummy_wanted(on: bool) -> void:
	test_dummy_wanted = on
	if on:
		if not _has_test_dummy():
			enemies.append(PXTestDummy.make_entry(self, _dummy_spawn_point(), core_radius))
	else:
		_remove_test_dummies()
	queue_redraw()


func _dummy_spawn_point() -> Vector2:
	return player.global_position + Vector2(0.0, -170.0)


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


# ── Simulation ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_update_enemies(delta)
	_resolve_sword_hits()
	_apply_blade_drag()
	_resolve_spawns(delta)
	queue_redraw()


func _motor_torque(enemy_sword: RigidBody2D, target_angle: float) -> float:
	return PXBlade.servo_torque(enemy_sword.rotation, enemy_sword.angular_velocity, target_angle, 0.0, Cfg.DEFAULT_MOTOR_STIFFNESS, Cfg.DEFAULT_MOTOR_DAMPING, Cfg.DEFAULT_MAX_TORQUE)


func _update_enemies(delta: float) -> void:
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body):
			continue
		entry["flash"] = maxf(0.0, float(entry["flash"]) - delta)
		if bool(entry.get("test_dummy", false)):
			entry["hit_cd"] = maxf(0.0, float(entry["hit_cd"]) - delta)
			PXTestDummy.tick_regeneration(entry, delta)
			continue
		entry["hit_cd"] = maxf(0.0, float(entry["hit_cd"]) - delta)

		var actor: RigidBody2D = body as RigidBody2D
		var to_player: Vector2 = player.global_position - actor.global_position
		var distance: float = to_player.length()
		var direction: Vector2 = to_player.normalized() if distance > 0.001 else Vector2.RIGHT
		var stop_range: float = Cfg.ENEMY_STOP_RANGE_ARMED if bool(entry["armed"]) else Cfg.ENEMY_STOP_RANGE_UNARMED
		# Steer SOFTLY: ease the velocity toward the approach instead of writing it,
		# so a shove from the blade is felt and then recovered rather than snapped.
		var desired: Vector2 = direction * Cfg.ENEMY_SPEED if distance > stop_range else Vector2.ZERO
		actor.linear_velocity = actor.linear_velocity.lerp(desired, clampf(delta * Cfg.ENEMY_STEER_RESPONSE, 0.0, 1.0))

		var enemy_sword: RigidBody2D = entry["sword"]
		if enemy_sword != null and is_instance_valid(enemy_sword):
			var anchor: AnimatableBody2D = entry["anchor"]
			anchor.position = body.position + direction * (Cfg.ENEMY_RADIUS + Cfg.ENEMY_HAND_OFFSET)
			# Point the enemy's blade at the player. It is a real body chasing an
			# angle with torque, so the player's blade can parry it.
			enemy_sword.apply_torque(_motor_torque(enemy_sword, direction.angle()))


## The physics sword's cut. Reads the live blade's transform and tests each body
## against the blade segment, exactly like the lab's _resolve_player_sword_hits.
func _resolve_sword_hits() -> void:
	if sword == null or not is_instance_valid(sword):
		return
	var hilt: Vector2 = sword.global_position
	var tip: Vector2 = PXBlade.tip_of(sword)
	var speed_scale: float = clampf(0.15 + absf(sword.angular_velocity) / 4.0, 0.15, 2.0)
	var killed: Array[Dictionary] = []
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body) or float(entry["hit_cd"]) > 0.0:
			continue
		# The cut lands anywhere in the FLESH ring; the core is the blade's hard stop.
		if not _segment_circle_overlap(hilt, tip, body.global_position, flesh_radius):
			continue
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


## The material model's FORCE. Whenever the blade is inside an enemy's flesh ring
## (or on its bone core) we add a viscous drag that OPPOSES the blade's spin — the
## "cut into something that isn't air" feel. It is a torque the solver integrates,
## never a written transform, and it is capped at the motor's own authority so the
## blade can always still move.
func _apply_blade_drag() -> void:
	if sword == null or not is_instance_valid(sword):
		return
	var omega: float = sword.angular_velocity
	if absf(omega) < 0.0001:
		return
	var hilt: Vector2 = sword.global_position
	var tip: Vector2 = PXBlade.tip_of(sword)
	var total: float = 0.0
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body):
			continue
		total += _drag_torque_for(_segment_point_distance(hilt, tip, body.global_position), omega)
	if absf(total) > 0.0001:
		sword.apply_torque(clampf(total, -Cfg.DEFAULT_MAX_TORQUE, Cfg.DEFAULT_MAX_TORQUE))


## The drag torque for one enemy at `distance` from the blade segment, given the
## blade's spin `omega`. Stronger on the bone core than in the flesh, zero outside
## the flesh. Pure, so it can be tested without a live physics world.
func _drag_torque_for(distance: float, omega: float) -> float:
	if distance <= core_radius:
		return -Cfg.BONE_FRICTION_MAX * bone_friction * omega
	if distance <= flesh_radius:
		return -Cfg.FLESH_DRAG_MAX * flesh_drag * omega
	return 0.0


func _segment_point_distance(a: Vector2, b: Vector2, point: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(point)


## Keeps EXACTLY ONE of each toggled enemy alive: if it dies, another spawns after
## a short delay. Untoggled types are left alone.
func _resolve_spawns(delta: float) -> void:
	if chaser_wanted and not _has_enemy(false):
		chaser_timer += delta
		if chaser_timer >= Cfg.RESPAWN_DELAY:
			chaser_timer = 0.0
			_spawn_enemy(false, _spawn_point())
	else:
		chaser_timer = 0.0

	if sword_enemy_wanted and not _has_enemy(true):
		sword_enemy_timer += delta
		if sword_enemy_timer >= Cfg.RESPAWN_DELAY:
			sword_enemy_timer = 0.0
			_spawn_enemy(true, _spawn_point())
	else:
		sword_enemy_timer = 0.0


func _segment_circle_overlap(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var ab: Vector2 = b - a
	var t: float = 0.0
	if ab.length_squared() > 0.0001:
		t = clampf((center - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (a + ab * t).distance_to(center) <= radius


# ── Presentation ────────────────────────────────────────────────────────────
func _draw() -> void:
	for entry: Dictionary in enemies:
		var body: Node2D = entry["body"]
		if not is_instance_valid(body):
			continue
		var is_dummy: bool = bool(entry.get("test_dummy", false))
		var armed: bool = bool(entry["armed"])
		var center: Vector2 = body.position
		var base: Color = Cfg.TEST_DUMMY_COLOR if is_dummy else (Color(0.78, 0.42, 0.36) if armed else Color(0.45, 0.55, 0.62))
		if float(entry["flash"]) > 0.0:
			base = Color(1.0, 0.95, 0.75)
		# FLESH ring (soft — the blade passes through it) then the CORE (solid — the
		# blade stops and turns on it). Seeing both makes the material model obvious.
		draw_circle(center, flesh_radius, Color(base.r, base.g, base.b, 0.20), true)
		draw_arc(center, flesh_radius, 0.0, TAU, 32, Color(base.r, base.g, base.b, 0.55), 1.5)
		draw_circle(center, core_radius, base, true)
		draw_arc(center, core_radius, 0.0, TAU, 24, Color(0, 0, 0, 0.5), 2.0)
		var enemy_sword: RigidBody2D = entry["sword"]
		if armed and enemy_sword != null and is_instance_valid(enemy_sword):
			_draw_enemy_blade(enemy_sword)
		if is_dummy:
			draw_string(ThemeDB.fallback_font, center + Vector2(-30.0, -flesh_radius - 19.0), Cfg.TEST_DUMMY_NAME, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Cfg.TEST_DUMMY_COLOR)
		var max_hp: float = float(entry.get("max_hp", Cfg.ENEMY_MAX_HEALTH))
		var hp_frac: float = clampf(float(entry["hp"]) / max_hp, 0.0, 1.0)
		var bar_pos: Vector2 = center + Vector2(-flesh_radius, -flesh_radius - 12.0)
		draw_rect(Rect2(bar_pos, Vector2(flesh_radius * 2.0, 5.0)), Color(0, 0, 0, 0.6), true)
		var health_color: Color = Cfg.TEST_DUMMY_HEALTH_COLOR if is_dummy else Color(0.9, 0.3, 0.3)
		draw_rect(Rect2(bar_pos, Vector2(flesh_radius * 2.0 * hp_frac, 5.0)), health_color, true)


## The enemy's sword drawn as a plain blade rectangle (the enemy blades reuse the
## PX geometry, not the player's sword art).
func _draw_enemy_blade(enemy_sword: RigidBody2D) -> void:
	var xf: Transform2D = enemy_sword.transform
	var half: float = Cfg.BLADE_THICKNESS * 0.5
	var corners := PackedVector2Array([
		xf * Vector2(0.0, -half),
		xf * Vector2(Cfg.BLADE_LENGTH, -half),
		xf * Vector2(Cfg.BLADE_LENGTH, half),
		xf * Vector2(0.0, half),
	])
	draw_colored_polygon(corners, Color(0.72, 0.30, 0.28, 0.95))