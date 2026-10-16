class_name Turkey extends Enemy

const CHARGE_AUDIO_CHANCE = 0.65


func _configure_concrete_enemy() -> void:
	spawn_identity = &"turkey"
	move_speed = Enemy.TURKEY_MOVE_SPEED
	grapple_weight = GrappleWeight.LIGHT
	score_value = chaser_score_value
	loot_material_name = "Turkey"
	loot_material_chance = LootConfig.TURKEY_DROP_CHANCE
	remnant_color = Color("6d3c55")
	death_sound_category = "turkey_death"
	charge_warning_tint_enabled = true
	charger_windup_duration = 0.3
	charger_charge_distance = 80.0
	charger_charge_speed_multiplier = 2.4
	charger_aim_lead = 0.0
	charge_start_distance = 110.0
	charge_cooldown_duration = 5.0
	charge_recovery_duration = 0.2

func _is_knockback_immune() -> bool:
	return _charge_commitment_active()

func _run_concrete_ai(delta: float) -> void:
	if _advance_charge(delta, charger_charge_speed_multiplier):
		return
	if charge_recovery_left > 0.0:
		velocity = Vector2.ZERO
		return
	if windup > 0.0:
		windup = maxf(0.0, windup - delta)
		velocity = Vector2.ZERO
		if windup <= 0.0:
			_begin_predictive_charge(charger_aim_lead, charger_charge_distance, charger_charge_speed_multiplier, charge_cooldown_duration)
		return
	if charge_cooldown <= 0.0 and global_position.distance_to(player_ref.global_position) <= charge_start_distance:
		_begin_charge_windup(charger_windup_duration)
		if charge_audio_should_play(randf()) and is_inside_tree():
			var main_scene: Node = get_tree().current_scene
			if main_scene != null and main_scene.has_method("play_enemy_death"):
				main_scene.call("play_enemy_death", death_sound_category, death_sound_pitch)
		return
	_chaser(delta)

static func charge_audio_should_play(roll: float) -> bool:
	return roll < CHARGE_AUDIO_CHANCE

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
