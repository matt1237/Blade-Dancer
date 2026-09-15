class_name Bug extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"bug"
	grapple_weight = GrappleWeight.LIGHT
	participates_in_melee_engagement = false
	score_value = ranged_score_value
	remnant_color = Color("4e83d1")
	ranged_cover_cooldown_left = randf_range(ranged_initial_cooldown_min, ranged_initial_cooldown_max)

func _run_concrete_ai(delta: float) -> void:
	_ranged(delta)

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_blue_bug_idle.png", "move":"res://assets/generated/hd_enemy_blue_bug_fly.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.42}

func _draw_concrete_body() -> void:
	_draw_flying_bug()
