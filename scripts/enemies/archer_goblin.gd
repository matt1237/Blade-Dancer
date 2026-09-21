class_name ArcherGoblin extends Enemy

const ARROW_SCENE: PackedScene = preload("res://scenes/projectiles/goblin_arrow.tscn")

@export_category("Archer Goblin")
@export var shot_interval: float = 3.4
@export var draw_duration: float = 0.72
@export var preferred_min_distance: float = 250.0
@export var preferred_max_distance: float = 390.0

var draw_left: float = 0.0
var shot_direction: Vector2 = Vector2.RIGHT

func _configure_concrete_enemy() -> void:
	spawn_identity = &"archer_goblin"
	grapple_weight = GrappleWeight.LIGHT
	participates_in_melee_engagement = false
	moving_weapon_enabled = false
	spear_visual_enabled = false
	move_speed = 102.0
	score_value = ranged_score_value + 25
	loot_material_name = "Mushroom"
	loot_material_chance = LootConfig.MUSHROOM_DROP_CHANCE
	remnant_color = Color("9b743d")
	fire_timer = randf_range(1.8, 3.2)

func _run_concrete_ai(delta: float) -> void:
	fire_timer = maxf(0.0, fire_timer - delta)
	var distance: float = global_position.distance_to(player_ref.global_position)
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	if draw_left > 0.0:
		draw_left = maxf(0.0, draw_left - delta)
		velocity = Vector2.ZERO
		shot_direction = direction
		if draw_left <= 0.0:
			_fire_arrow()
			fire_timer = shot_interval
		return
	if distance < preferred_min_distance:
		velocity = -direction * move_speed
	elif distance > preferred_max_distance:
		velocity = direction * move_speed
	else:
		velocity = direction.orthogonal() * (1.0 if get_instance_id() % 2 == 0 else -1.0) * move_speed * 0.45
	if fire_timer <= 0.0 and _has_player_line_of_sight():
		draw_left = draw_duration
		shot_direction = direction

func _fire_arrow() -> void:
	if not _has_player_line_of_sight(): return
	var arrow: GoblinArrow = ARROW_SCENE.instantiate() as GoblinArrow
	if arrow == null: return
	get_parent().add_child(arrow)
	arrow.global_position = global_position + shot_direction * 24.0
	arrow.damage *= maxf(1.0, wave_stat_multiplier)
	arrow.launch(shot_direction, self)

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_archer_goblin_idle.png", "move":"res://assets/generated/hd_archer_goblin_walk.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.44}

func _draw_concrete_body() -> void:
	_draw_goblin()
