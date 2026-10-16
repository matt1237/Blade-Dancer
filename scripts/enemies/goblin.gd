class_name Goblin extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"goblin"
	grapple_weight = GrappleWeight.LIGHT
	moving_weapon_enabled = true
	spear_visual_enabled = true
	# Spear 15% shorter than the shared duelist reach (visible spear = blade + 26px shaft/head):
	# idle 72 -> 61.2px, thrust 100 -> 85px. Hitbox and art both follow blade_length.
	duelist_blade_length = 35.2
	duelist_thrust_blade_length = 59.0
	score_value = duelist_score_value
	loot_material_name = "Mushroom"
	loot_material_chance = LootConfig.MUSHROOM_DROP_CHANCE
	remnant_color = Color("bd5ee6")
	death_sound_category = "goblin_things"
	duelist_metronome = randf() < duelist_metronome_chance

func _run_concrete_ai(delta: float) -> void:
	_duelist(delta)

func _has_player_damage_contact() -> bool:
	if super._has_player_damage_contact():
		return true
	if thrust_left <= 0.0 or disarmed or stun_left > 0.0 or blade_length <= 0.0 or health <= max_health * duelist_retreat_health_percent:
		return false
	# Test the actual player collider, not sprite/draw layers or a proximity aura.
	var body: CollisionShape2D = player_ref.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body == null or body.disabled or not body.shape is CircleShape2D:
		return false
	var circle: CircleShape2D = body.shape as CircleShape2D
	var segment: Dictionary = _enemy_weapon_segment()
	var direction: Vector2 = Vector2.RIGHT.rotated(blade_angle)
	var tip: Vector2 = segment["end"] as Vector2
	var head_base: Vector2 = tip - direction * SPEAR_HEAD_LENGTH
	var start_local: Vector2 = body.to_local(segment["start"] as Vector2)
	var base_local: Vector2 = body.to_local(head_base)
	var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, start_local, base_local)
	if nearest.length() <= circle.radius + SPEAR_SHAFT_WIDTH * 0.5:
		return true
	# The head is a triangle, not an extra invisible 26px reach allowance.
	var tangent: Vector2 = direction.orthogonal() * SPEAR_HEAD_HALF_WIDTH
	var head: PackedVector2Array = PackedVector2Array([body.to_local(head_base + tangent), body.to_local(tip), body.to_local(head_base - tangent)])
	if Geometry2D.point_is_inside_triangle(Vector2.ZERO, head[0], head[1], head[2]):
		return true
	for index: int in range(3):
		nearest = Geometry2D.get_closest_point_to_segment(Vector2.ZERO, head[index], head[(index + 1) % 3])
		if nearest.length() <= circle.radius:
			return true
	return false

func engagement_attack_in_progress() -> bool:
	return thrust_left > 0.0

func _engagement_action_in_progress() -> bool:
	return thrust_left > 0.0

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_duelist_idle.png", "move":"res://assets/generated/hd_enemy_duelist_walk.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.44}

func _draw_concrete_body() -> void:
	_draw_goblin()
