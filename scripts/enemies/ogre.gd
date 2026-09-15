class_name Ogre extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"ogre"
	max_health = elite_max_health
	grapple_weight = GrappleWeight.MEDIUM
	shield_enabled = true
	charge_pose_enabled = true
	hilt_bash_impulse_multiplier = 0.5
	score_value = elite_score_value
	remnant_color = Color("7d3548")
	remnant_radius = 24.0

func _run_concrete_ai(delta: float) -> void:
	_elite(delta)

func engagement_attack_in_progress() -> bool:
	return windup > 0.0 or charge_distance_left > 0.0 or shield_bash_left > 0.0

func _engagement_action_in_progress() -> bool:
	return windup > 0.0 or charge_distance_left > 0.0 or charge_recovery_left > 0.0 or shield_bash_left > 0.0

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_elite_idle.png", "move":"res://assets/generated/hd_enemy_elite_march.png", "frame_size":Vector2(160.0, 160.0), "frame_count":3, "scale":0.40}

func _draw_concrete_body() -> void:
	_draw_ogre()
