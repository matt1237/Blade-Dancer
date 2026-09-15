class_name Wolf extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"wolf"
	grapple_weight = GrappleWeight.LIGHT
	charge_pose_enabled = true
	charge_warning_tint_enabled = true
	score_value = charger_score_value
	loot_material_name = CookingConfig.WOLF_MEAT_MATERIAL
	loot_material_chance = LootConfig.WOLF_MEAT_DROP_CHANCE
	remnant_color = Color("8f473f")

func _run_concrete_ai(delta: float) -> void:
	_charger(delta)

func engagement_attack_in_progress() -> bool:
	return windup > 0.0 or charge_distance_left > 0.0

func _engagement_action_in_progress() -> bool:
	return windup > 0.0 or charge_distance_left > 0.0 or charge_recovery_left > 0.0

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_warg_idle.png", "move":"res://assets/generated/hd_enemy_warg_charge.png", "frame_size":Vector2(160.0, 128.0), "frame_count":3, "scale":0.44}

func _draw_concrete_body() -> void:
	_draw_wolf()
