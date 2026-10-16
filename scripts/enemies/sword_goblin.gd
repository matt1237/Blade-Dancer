class_name SwordGoblin extends Enemy

const RUSTED_CURVED_SWORD_TEXTURE: Texture2D = preload("res://assets/generated/hd_rusted_goblin_curved_sword.png")
const RUSTED_SWORD_AUTHORED_LENGTH: float = 46.0
const RUSTED_SWORD_BASE_SCALE: float = 0.75

enum LungePhase { READY, TELEGRAPH, LUNGE, RECOVERY }
enum MetronomePhase { READY, WINDUP, SWING, RECOVERY }

const SWORD_IDLE_LENGTH: float = 64.0
const SWORD_SWING_LENGTH: float = 80.0
const METRONOME_WINDUP_SECONDS: float = 0.28
const METRONOME_SWING_SECONDS: float = 0.20
const METRONOME_RECOVERY_SECONDS: float = 0.24
## Distance the Sword Goblin closes to before it stops advancing and holds with a light strafe.
## It keeps coming -- there is no engagement ring or waiting state.
const SWORD_ENGAGE_RANGE: float = 72.0

@export_category("Sword Goblin Metronome")
## Total side-to-side weapon arc centered on the player-facing direction.
@export var metronome_arc_degrees: float = 90.0
## Complete side-to-side cycles per second.
@export var metronome_frequency_hz: float = 0.7

@export_category("Sword Goblin Lunge")
@export var lunge_cooldown_duration: float = 10.0
@export var lunge_telegraph_duration: float = 0.75
@export var lunge_aim_lock_window: float = 0.2
@export var lunge_distance: float = 220.0
@export var lunge_speed_multiplier: float = 6.2
@export var lunge_recovery_duration: float = 0.6
@export var lunge_min_range: float = 140.0
@export var lunge_max_range: float = 300.0

var lunge_phase: LungePhase = LungePhase.READY
var lunge_cooldown_left: float = 3.0
var lunge_telegraph_left: float = 0.0
var lunge_recovery_left: float = 0.0
var lunge_direction: Vector2 = Vector2.RIGHT
var metronome_phase: MetronomePhase = MetronomePhase.READY
var metronome_phase_left: float = 0.0
var metronome_attack_center: float = 0.0
var metronome_attack_side: float = 1.0
## Continuous metronome clock, so frequency changes never snap the beat.
var metronome_time: float = 0.0
var dirt_time: float = 0.0
var rusted_sword_sprite: Sprite2D = null

func _configure_concrete_enemy() -> void:
	spawn_identity = &"sword_goblin"
	grapple_weight = GrappleWeight.LIGHT
	moving_weapon_enabled = true
	spear_visual_enabled = false
	move_speed = 132.0
	score_value = duelist_score_value
	loot_material_name = "Mushroom"
	loot_material_chance = LootConfig.MUSHROOM_DROP_CHANCE
	remnant_color = Color("a65d35")
	death_sound_category = "goblin_things"
	blade_length = SWORD_IDLE_LENGTH

func _ready() -> void:
	super._ready()
	rusted_sword_sprite = Sprite2D.new()
	rusted_sword_sprite.name = "RustedCurvedSword"
	rusted_sword_sprite.texture = RUSTED_CURVED_SWORD_TEXTURE
	rusted_sword_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rusted_sword_sprite.centered = false
	rusted_sword_sprite.position = Vector2(weapon_origin_offset, -16.0 * RUSTED_SWORD_BASE_SCALE)
	rusted_sword_sprite.z_index = 1
	add_child(rusted_sword_sprite)
	_update_rusted_sword_visual()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_rusted_sword_visual()

func _rewind_extra_stride() -> int:
	return 11

func _rewind_capture_extra(d: PackedFloat32Array, o: int) -> void:
	d[o] = float(lunge_phase); d[o + 1] = lunge_cooldown_left; d[o + 2] = lunge_telegraph_left
	d[o + 3] = lunge_recovery_left; d[o + 4] = lunge_direction.x; d[o + 5] = lunge_direction.y
	d[o + 6] = float(metronome_phase); d[o + 7] = metronome_phase_left; d[o + 8] = metronome_attack_center
	d[o + 9] = metronome_attack_side; d[o + 10] = metronome_time

func _rewind_restore_extra(d: PackedFloat32Array, o: int) -> void:
	lunge_phase = int(d[o]) as LungePhase; lunge_cooldown_left = d[o + 1]; lunge_telegraph_left = d[o + 2]
	lunge_recovery_left = d[o + 3]; lunge_direction = Vector2(d[o + 4], d[o + 5])
	metronome_phase = int(d[o + 6]) as MetronomePhase; metronome_phase_left = d[o + 7]; metronome_attack_center = d[o + 8]
	metronome_attack_side = d[o + 9]; metronome_time = d[o + 10]
	_update_rusted_sword_visual()

func _update_rusted_sword_visual() -> void:
	if rusted_sword_sprite == null: return
	rusted_sword_sprite.visible = not disarmed and blade_length > 0.0
	rusted_sword_sprite.position = Vector2.RIGHT.rotated(blade_angle) * weapon_origin_offset
	rusted_sword_sprite.rotation = blade_angle
	var reach_scale: float = maxf(0.1, blade_length / RUSTED_SWORD_AUTHORED_LENGTH)
	rusted_sword_sprite.scale = Vector2(RUSTED_SWORD_BASE_SCALE * reach_scale, RUSTED_SWORD_BASE_SCALE)

func _run_concrete_ai(delta: float) -> void:
	lunge_cooldown_left = maxf(0.0, lunge_cooldown_left - delta)
	dirt_time += delta
	var distance: float = global_position.distance_to(player_ref.global_position)
	var player_direction: Vector2 = global_position.direction_to(player_ref.global_position)
	if disarmed or health <= max_health * duelist_retreat_health_percent:
		metronome_phase = MetronomePhase.READY
		lunge_phase = LungePhase.READY
		blade_length = 0.0 if disarmed else SWORD_IDLE_LENGTH
		velocity = -player_direction * move_speed * 1.2
		return
	match lunge_phase:
		LungePhase.TELEGRAPH:
			lunge_telegraph_left = maxf(0.0, lunge_telegraph_left - delta)
			velocity = Vector2.ZERO
			if lunge_telegraph_left > lunge_aim_lock_window: lunge_direction = player_direction
			blade_angle = lerp_angle(blade_angle, lunge_direction.angle(), clampf(14.0 * delta, 0.0, 1.0))
			blade_length = SWORD_IDLE_LENGTH
			if lunge_telegraph_left <= 0.0:
				lunge_phase = LungePhase.LUNGE
				charge_distance_left = lunge_distance
			return
		LungePhase.LUNGE:
			charge_motion_this_frame = true
			var lunge_speed: float = move_speed * lunge_speed_multiplier * player_ref.get_flow_enemy_speed_multiplier()
			velocity = lunge_direction * lunge_speed
			charge_distance_left = maxf(0.0, charge_distance_left - lunge_speed * delta)
			blade_angle = lunge_direction.angle()
			blade_length = SWORD_SWING_LENGTH
			if charge_distance_left <= 0.0:
				lunge_phase = LungePhase.RECOVERY
				lunge_recovery_left = lunge_recovery_duration
			return
		LungePhase.RECOVERY:
			lunge_recovery_left = maxf(0.0, lunge_recovery_left - delta)
			velocity = Vector2.ZERO
			if lunge_recovery_left <= 0.0: lunge_phase = LungePhase.READY
			return
		LungePhase.READY:
			pass
	if lunge_cooldown_left <= 0.0 and distance >= lunge_min_range and distance <= lunge_max_range:
		lunge_phase = LungePhase.TELEGRAPH
		lunge_telegraph_left = lunge_telegraph_duration
		lunge_direction = player_direction
		lunge_cooldown_left = lunge_cooldown_duration
		return
	_advance_toward_player(distance, player_direction)
	_advance_metronome_attack(delta, player_direction)

## The Sword Goblin advances steadily toward the player, then holds sword range with a light
## strafe. No engagement ring, no waiting state -- it keeps coming.
func _advance_toward_player(distance: float, player_direction: Vector2) -> void:
	var difference: float = distance - SWORD_ENGAGE_RANGE
	if absf(difference) < 12.0:
		velocity = player_direction.orthogonal() * move_speed * 0.35 * engagement_orbit_sign
	elif difference > 0.0:
		velocity = player_direction * move_speed
	else:
		velocity = -player_direction * move_speed * 0.55

## Continuous metronome, the same shape the player's own sword swings on: the blade holds an
## even beat around the player-facing direction across metronome_arc_degrees at
## metronome_frequency_hz, instead of pausing between discrete strokes. The goblin is always
## mid-swing while it is alive and engaged.
func _advance_metronome_attack(delta: float, player_direction: Vector2) -> void:
	metronome_time += delta
	var half_arc: float = deg_to_rad(metronome_arc_degrees) * 0.5
	blade_length = SWORD_SWING_LENGTH
	blade_angle = player_direction.angle() + sin(metronome_time * TAU * metronome_frequency_hz) * half_arc
	blade_target_angle = blade_angle

func _has_player_damage_contact() -> bool:
	if super._has_player_damage_contact():
		return true
	# The blade is always mid-swing now, so the weapon is live whenever it is drawn.
	var weapon_active: bool = lunge_phase == LungePhase.LUNGE or (not disarmed and stun_left <= 0.0 and blade_length > 0.0)
	if not weapon_active or disarmed or stun_left > 0.0 or blade_length <= 0.0:
		return false
	var body: CollisionShape2D = player_ref.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.disabled or not body.shape is CircleShape2D:
		return false
	var circle: CircleShape2D = body.shape as CircleShape2D
	var segment: Dictionary = _enemy_weapon_segment()
	var start: Vector2 = body.to_local(segment["start"] as Vector2)
	var end: Vector2 = body.to_local(segment["end"] as Vector2)
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, start, end)
	return nearest.length() <= circle.radius + Enemy.SWORD_WEAPON_HIT_RADIUS

func engagement_attack_in_progress() -> bool:
	return metronome_phase != MetronomePhase.READY or lunge_phase != LungePhase.READY

func _engagement_action_in_progress() -> bool:
	return engagement_attack_in_progress()

func _is_hd_visual() -> bool:
	# This enemy's authored body and rusted curved sword are one cohesive HD
	# animation. Always use it rather than falling back to the weaponless legacy body.
	return true

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_sword_goblin_body_idle.png", "move":"res://assets/generated/hd_sword_goblin_body_walk.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.52}

func _draw_concrete_body() -> void:
	_draw_goblin()

func _draw() -> void:
	super._draw()
	if lunge_phase == LungePhase.TELEGRAPH:
		var intensity: float = 0.55 + 0.35 * sin(dirt_time * 24.0)
		for index: int in range(7):
			var side: float = -1.0 if index % 2 == 0 else 1.0
			var offset: Vector2 = -lunge_direction * (8.0 + float(index) * 3.0) + lunge_direction.orthogonal() * side * (5.0 + float(index % 3) * 4.0)
			draw_circle(offset, 2.0 + float(index % 2), Color(0.48, 0.31, 0.17, intensity))
