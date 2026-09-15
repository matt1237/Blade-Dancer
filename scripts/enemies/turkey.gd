class_name Turkey extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"turkey"
	grapple_weight = GrappleWeight.LIGHT
	score_value = chaser_score_value
	loot_material_name = "Turkey"
	loot_material_chance = LootConfig.TURKEY_DROP_CHANCE
	remnant_color = Color("6d3c55")

func _run_concrete_ai(delta: float) -> void:
	_chaser(delta)

func _on_player_contact() -> void:
	if _has_engagement_attack_permission():
		chaser_attack_left = chaser_attack_duration
		chaser_was_attacking = true
		chaser_retreat_left = 0.0

func engagement_attack_in_progress() -> bool:
	return chaser_attack_left > 0.0 or chaser_was_attacking

func _engagement_action_in_progress() -> bool:
	return chaser_attack_left > 0.0 or chaser_was_attacking or chaser_retreat_left > 0.0

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_turkey_idle.png", "move":"res://assets/generated/hd_enemy_turkey_walk.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.50}

func _draw_concrete_body() -> void:
	_draw_wild_turkey()
