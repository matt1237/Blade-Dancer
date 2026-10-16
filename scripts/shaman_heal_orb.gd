class_name ShamanHealOrb extends Node2D
## World-owned delivery only. Enemy owns the heal and the single regeneration slot.
const SPEED: float = 320.0
const MAX_LIFETIME: float = 4.0
const ARRIVAL_RADIUS: float = 8.0
const TARGET_OFFSET: Vector2 = Vector2(0.0, -18.0)
const DARK_GREEN: Color = Color(0.12, 0.38, 0.16, 1.0)
const LIGHT_GREEN: Color = Color(0.7, 1.0, 0.55, 1.0)
signal arrived(target: Enemy, restored: float)
var recipient: Enemy = null
var elapsed: float = 0.0
var delivered: bool = false
@onready var orb_sprite: Sprite2D = $Orb

func _ready() -> void:
	# Main clears this group on transitions; Player only attacks EnemyProjectile
	# instances in it. This harmless Node2D has no damage or deflection path.
	add_to_group("enemy_projectiles")
	add_to_group(WorldRewindRecorder.REWINDABLE_GROUP)

## --- World rewind (stage 1) ---
const REWIND_GAMEPLAY_GROUPS: Array[StringName] = [&"enemy_projectiles"]
var rewind_retired: bool = false

func _expire() -> void:
	WorldRewindRecorder.retire_or_free(self, REWIND_GAMEPLAY_GROUPS)

func rewind_stride() -> int:
	return 7

func rewind_capture(d: PackedFloat32Array, o: int) -> void:
	d[o] = global_position.x; d[o + 1] = global_position.y
	d[o + 2] = elapsed; d[o + 3] = 1.0 if delivered else 0.0
	WorldRewindRecorder.write_id(d, o + 4, recipient)

func rewind_restore(d: PackedFloat32Array, o: int) -> void:
	global_position = Vector2(d[o], d[o + 1])
	elapsed = d[o + 2]; delivered = d[o + 3] >= 0.5
	recipient = WorldRewindRecorder.read_id(d, o + 4) as Enemy

func launch(origin: Vector2, target: Enemy) -> void:
	global_position = origin
	recipient = target

func _physics_process(delta: float) -> void:
	advance_flight(delta * WorldTime.enemy_scale()) # World Slow: lifetime + travel

func advance_flight(delta: float) -> void:
	if delivered or is_queued_for_deletion() or rewind_retired: return
	if not is_instance_valid(recipient) or recipient.is_queued_for_deletion() or recipient.death_emitted or recipient.health <= 0.0:
		_expire()
		return
	var step: float = maxf(0.0, delta)
	elapsed += step
	if elapsed >= MAX_LIFETIME:
		_expire()
		return
	if orb_sprite != null:
		# Colour oscillation, never an alpha blink.
		orb_sprite.modulate = DARK_GREEN.lerp(LIGHT_GREEN, 0.5 + 0.5 * sin(elapsed * TAU * 2.5))
	var destination: Vector2 = recipient.global_position + TARGET_OFFSET
	var distance: float = global_position.distance_to(destination)
	global_position = global_position.move_toward(destination, SPEED * step)
	if distance <= SPEED * step + ARRIVAL_RADIUS:
		delivered = true # Guard before callbacks: exactly one arrival per orb.
		var before: float = recipient.health
		recipient.receive_shaman_heal()
		arrived.emit(recipient, recipient.health - before)
		_expire()
