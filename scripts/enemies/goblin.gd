class_name Goblin extends Enemy

func _configure_concrete_enemy() -> void:
	spawn_identity = &"goblin"
	grapple_weight = GrappleWeight.LIGHT
	moving_weapon_enabled = true
	spear_visual_enabled = true
	score_value = duelist_score_value
	loot_material_name = "Mushroom"
	loot_material_chance = LootConfig.MUSHROOM_DROP_CHANCE
	remnant_color = Color("bd5ee6")
	duelist_metronome = randf() < duelist_metronome_chance

func _run_concrete_ai(delta: float) -> void:
	_duelist(delta)

func engagement_attack_in_progress() -> bool:
	return thrust_left > 0.0

func _engagement_action_in_progress() -> bool:
	return thrust_left > 0.0

func _hd_visual_config() -> Dictionary:
	return {"idle":"res://assets/generated/hd_enemy_duelist_idle.png", "move":"res://assets/generated/hd_enemy_duelist_walk.png", "frame_size":Vector2(128.0, 128.0), "frame_count":4, "scale":0.44}

func _draw_concrete_body() -> void:
	_draw_goblin()
