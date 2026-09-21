class_name SwordGoblin extends Enemy

const RUSTED_CURVED_SWORD_TEXTURE: Texture2D = preload("res://assets/generated/hd_rusted_goblin_curved_sword.png")
const RUSTED_SWORD_AUTHORED_LENGTH: float = 46.0
const RUSTED_SWORD_BASE_SCALE: float = 0.75

enum LungePhase { READY, TELEGRAPH, LUNGE, RECOVERY }

@export_category("Sword Goblin Metronome")
## Total side-to-side weapon arc centered on the player-facing direction.
@export var metronome_arc_degrees: float = 100.0
## Complete side-to-side cycles per second.
@export var metronome_frequency_hz: float = 0.6

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
	blade_length = 46.0

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
	match lunge_phase:
		LungePhase.TELEGRAPH:
			lunge_telegraph_left = maxf(0.0, lunge_telegraph_left - delta)
			velocity = Vector2.ZERO
			if lunge_telegraph_left > lunge_aim_lock_window: lunge_direction = player_direction
			blade_angle = lerp_angle(blade_angle, lunge_direction.angle(), clampf(14.0 * delta, 0.0, 1.0))
			blade_length = 46.0
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
			blade_length = 54.0
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
	_duelist(delta)
	# The metronome is centered on the live player-facing direction. This writes
	# the authoritative combat angle, so rendered sword and collision stay aligned.
	var half_arc_radians: float = deg_to_rad(metronome_arc_degrees) * 0.5
	var metronome_offset: float = sin(dirt_time * TAU * metronome_frequency_hz) * half_arc_radians
	blade_angle = player_direction.angle() + metronome_offset
	blade_target_angle = blade_angle
	blade_length = minf(blade_length, 46.0)

func engagement_attack_in_progress() -> bool:
	return thrust_left > 0.0 or lunge_phase != LungePhase.READY

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
