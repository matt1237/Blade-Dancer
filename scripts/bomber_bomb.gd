class_name BomberBomb extends Node2D
## Separate attack authority; never an EnemyProjectile, so swords cannot deflect it.
enum Phase { WARNING, FLIGHT, FUSE, FIRE, FINISHED }
const RADIUS: float = 69.0
# Inspected 128px frames: the ground patch spans roughly x=14..116,
# y=70..124 (minor edge flicker between frames), not the whole canvas.
# Expand the painted ground ellipse on both axes to the warning diameter.
# The visible animated footprint and damage circle share RADIUS.
const FIRE_FRAME_CENTER: Vector2 = Vector2(64.0, 64.0)
const FIRE_GROUND_RECT: Rect2 = Rect2(14.0, 70.0, 102.0, 54.0)
const WARNING_TIME: float = 0.5
const FLIGHT_TIME: float = 0.45
const FUSE_TIME: float = 0.5
const FIRE_TIME: float = 2.0
const EXPLOSION_DAMAGE: float = 15.0
const FIRE_DAMAGE: float = 5.0
const FIRE_INTERVAL: float = 0.5
const LAND_TIME: float = WARNING_TIME + FLIGHT_TIME
const EXPLODE_TIME: float = LAND_TIME + FUSE_TIME
const END_TIME: float = EXPLODE_TIME + FIRE_TIME

signal damage_pulse(amount: float)
## Presentation observes the committed phase/elapsed, including release this frame.
signal attack_advanced()
var phase: Phase = Phase.WARNING
var elapsed: float = 0.0
var launch_position: Vector2 = Vector2.ZERO
var locked_target: Vector2 = Vector2.ZERO
var player: Player = null
var thrower: Enemy = null
var armed: bool = false
var exploded: bool = false
var fire_ticks: int = 0
@onready var bomb_sprite: AnimatedSprite2D = $Bomb
@onready var fire_sprite: AnimatedSprite2D = $Fire
@onready var explosion_sprite: AnimatedSprite2D = $Explosion

func _ready() -> void:
	# Main's existing transition cleanup owns this group. No enemy lifetime link.
	add_to_group("enemy_projectiles")
	add_to_group(WorldRewindRecorder.REWINDABLE_GROUP)

## --- World rewind (stage 1): exact phase clock, target, and pulse bookkeeping ---
const REWIND_GAMEPLAY_GROUPS: Array[StringName] = [&"enemy_projectiles"]
var rewind_retired: bool = false

func rewind_stride() -> int:
	return 13

func rewind_capture(d: PackedFloat32Array, o: int) -> void:
	d[o] = global_position.x; d[o + 1] = global_position.y
	d[o + 2] = float(phase); d[o + 3] = elapsed
	d[o + 4] = launch_position.x; d[o + 5] = launch_position.y
	d[o + 6] = locked_target.x; d[o + 7] = locked_target.y
	d[o + 8] = (1.0 if armed else 0.0) + (2.0 if exploded else 0.0); d[o + 9] = float(fire_ticks)
	WorldRewindRecorder.write_id(d, o + 10, thrower)

func rewind_restore(d: PackedFloat32Array, o: int) -> void:
	global_position = Vector2(d[o], d[o + 1])
	phase = int(d[o + 2]) as Phase; elapsed = d[o + 3]
	launch_position = Vector2(d[o + 4], d[o + 5]); locked_target = Vector2(d[o + 6], d[o + 7])
	var flags: int = int(d[o + 8])
	armed = (flags & 1) != 0; exploded = (flags & 2) != 0
	fire_ticks = int(d[o + 9])
	thrower = WorldRewindRecorder.read_id(d, o + 10) as Enemy
	if is_instance_valid(thrower) and thrower is GoblinBomber:
		(thrower as GoblinBomber).attack_bomb = self
	if explosion_sprite != null and not exploded:
		explosion_sprite.stop()
	_update_visuals()
	queue_redraw()

func arm(origin: Vector2, target: Vector2, target_player: Player, source: Enemy = null) -> void:
	thrower = source
	launch_position = origin
	locked_target = target
	player = target_player
	global_position = target
	armed = true

func _physics_process(delta: float) -> void:
	# World Slow: warning/flight/fuse/fire all live on `elapsed`, so one scale covers them.
	var world_scale: float = WorldTime.enemy_scale()
	for sprite: AnimatedSprite2D in [bomb_sprite, fire_sprite, explosion_sprite]:
		if sprite != null: sprite.speed_scale = world_scale
	advance_attack(delta * world_scale)

func advance_attack(delta: float) -> void:
	if not armed or phase == Phase.FINISHED: return
	# Track the throwing hand only until release; the ground target never moves.
	if phase == Phase.WARNING and is_instance_valid(thrower):
		launch_position = thrower.global_position
	elapsed += maxf(0.0, delta)
	if elapsed + 0.000001 < WARNING_TIME:
		phase = Phase.WARNING
	elif elapsed + 0.000001 < LAND_TIME:
		phase = Phase.FLIGHT
	elif elapsed + 0.000001 < EXPLODE_TIME:
		phase = Phase.FUSE
	else:
		phase = Phase.FIRE
		if not exploded:
			exploded = true
			_pulse(EXPLOSION_DAMAGE)
			if explosion_sprite != null: explosion_sprite.play("explosion")
		# Four pulses at +0.5, +1.0, +1.5, +2.0, including the final boundary.
		while fire_ticks < 4 and elapsed + 0.000001 >= EXPLODE_TIME + float(fire_ticks + 1) * FIRE_INTERVAL:
			fire_ticks += 1
			_pulse(FIRE_DAMAGE)
	if elapsed + 0.000001 >= END_TIME:
		phase = Phase.FINISHED
		WorldRewindRecorder.retire_or_free(self, REWIND_GAMEPLAY_GROUPS)
	_update_visuals()
	attack_advanced.emit()
	queue_redraw()

func contains_point(point: Vector2) -> bool:
	return point.distance_squared_to(locked_target) <= RADIUS * RADIUS

func _pulse(amount: float) -> void:
	damage_pulse.emit(amount)
	if is_instance_valid(player) and contains_point(player.global_position):
		# Preserve canonical defense, dash immunity, damage numbers and hit audio.
		player.take_damage(amount, Vector2.ZERO, self)

func _update_visuals() -> void:
	if bomb_sprite == null: return
	bomb_sprite.visible = phase == Phase.FLIGHT or phase == Phase.FUSE
	if phase == Phase.FLIGHT:
		var progress: float = clampf((elapsed - WARNING_TIME) / FLIGHT_TIME, 0.0, 1.0)
		bomb_sprite.position = launch_position.lerp(locked_target, progress) - locked_target + Vector2(0.0, -sin(progress * PI) * 75.0)
	else:
		bomb_sprite.position = Vector2.ZERO
	fire_sprite.visible = phase == Phase.FIRE
	if fire_sprite.visible:
		# Full footprint on the very first damage frame; only the atlas animates.
		fire_sprite.scale = Vector2(RADIUS * 2.0 / FIRE_GROUND_RECT.size.x, RADIUS * 2.0 / FIRE_GROUND_RECT.size.y)
		fire_sprite.position = -(FIRE_GROUND_RECT.get_center() - FIRE_FRAME_CENTER) * fire_sprite.scale
	explosion_sprite.visible = phase == Phase.FIRE and elapsed - EXPLODE_TIME < 0.4

func is_reticle_visible() -> bool:
	return armed and (phase == Phase.WARNING or phase == Phase.FLIGHT or phase == Phase.FUSE)

func _draw() -> void:
	if armed and phase == Phase.FIRE:
		# Same center/radius as the red warning and contains_point(). The artwork
		# is elevated/perspective; this ground disk explicitly marks all damage.
		draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.24, 0.04, 0.18))
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 80, Color(1.0, 0.24, 0.04, 0.85), 3.0, true)
	if is_reticle_visible():
		var alpha: float = 0.55 + 0.2 * sin(elapsed * TAU * 2.0)
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 80, Color(1.0, 0.12, 0.08, alpha), 3.0, true)
