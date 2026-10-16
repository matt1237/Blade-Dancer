class_name EnemyChargeCommitmentRig extends EnemySpawnRig
## Real Main + real training spawns, automatic warning/rush hit probes.
## All rig changes are in memory; no preset/save writes.

func spawn_now() -> void:
	pass # The sequential probe below owns test-only spawn timing.

func _ready() -> void:
	await super._ready()
	if _main == null:
		return
	_main.set_px_mode(false)
	var player: Player = _player()
	player.sword_stowed = true
	player.invulnerable = 60.0
	for type_name: String in ["turkey", "wolf", "ogre"]:
		await _probe(type_name)
	print("[CHARGE BENCH] COMPLETE")

func _probe(type_name: String) -> void:
	var player: Player = _player()
	var offset: Vector2 = Vector2(200.0 if type_name == "ogre" else 90.0, 0.0)
	_main._spawn_training_enemy_at(player.global_position + offset, _scene_for(type_name))
	_track_new_enemies()
	var alive: Array[Enemy] = _alive_enemies()
	if alive.is_empty():
		push_error("[CHARGE BENCH] no spawn: " + type_name)
		return
	var enemy: Enemy = alive[alive.size() - 1]
	# Seed pre-warning motion to verify commitment entry sheds it.
	enemy.knockback = Vector2.UP * 100.0
	enemy.grapple_slide_velocity = Vector2.UP * 20.0
	var saw_warning: bool = false
	for frame: int in range(120):
		await get_tree().physics_frame
		if enemy.windup > 0.0:
			saw_warning = true
			break
	if not saw_warning:
		push_error("[CHARGE BENCH] no red warning: " + type_name)
		enemy.queue_free()
		return
	var warning_before: float = enemy.windup
	var hp_before: float = enemy.health
	_apply_test_hit(enemy, 1.0) # Real sword damage/presentation call path.
	player._trigger_hilt_bash(enemy, enemy.global_position)
	enemy.apply_grapple_force(Vector2.UP * 600.0, 0.1, 1000.0, 0.25)
	if enemy.shield_enabled:
		_probe_player_shield_contact(enemy, player)
	var warning_position: Vector2 = enemy.global_position
	await get_tree().physics_frame
	var warning_ok: bool = enemy.health < hp_before and enemy.stun_left == 0.0 and enemy.windup < warning_before and enemy.knockback == Vector2.ZERO and enemy.grapple_slide_velocity == Vector2.ZERO and enemy.global_position.distance_to(warning_position) < 0.1
	print("[CHARGE BENCH] %s warning=%s hp=%.1f stun=%.3f pending=%s" % [type_name, str(warning_ok), enemy.health, enemy.stun_left, str(enemy.knockback)])
	var saw_rush: bool = false
	for frame: int in range(120):
		await get_tree().physics_frame
		if enemy.charge_distance_left > 0.0:
			saw_rush = true
			break
	if not saw_rush:
		push_error("[CHARGE BENCH] no moving charge: " + type_name)
		enemy.queue_free()
		return
	var distance_before: float = enemy.charge_distance_left
	_apply_test_hit(enemy, 1.0)
	player._trigger_hilt_bash(enemy, enemy.global_position)
	# Chakram rear-shield reaction plus its ordinary damage/force channel.
	enemy.take_damage(1.0, Vector2.UP * 180.0, 0.18)
	enemy.chakram_hit_from_behind(Vector2.UP * 180.0)
	enemy.apply_grapple_force(Vector2.UP * 600.0, 0.1, 1000.0, 0.25)
	await get_tree().physics_frame
	var rush_ok: bool = enemy.charge_distance_left < distance_before and enemy.stun_left == 0.0 and enemy.knockback == Vector2.ZERO and enemy.grapple_slide_velocity == Vector2.ZERO
	print("[CHARGE BENCH] %s rush=%s distance=%.1f->%.1f hp=%.1f" % [type_name, str(rush_ok), distance_before, enemy.charge_distance_left, enemy.health])
	for frame: int in range(240):
		await get_tree().physics_frame
		if enemy.charge_recovery_left > 0.0:
			break
	var no_deferred_stun: bool = enemy.stun_left == 0.0
	_apply_test_hit(enemy, 1.0)
	var recovery_ok: bool = enemy.charge_recovery_left > 0.0 and no_deferred_stun and enemy.stun_left > 0.0 and enemy.knockback.length() > 0.0
	print("[CHARGE BENCH] %s recovery=%s" % [type_name, str(recovery_ok)])
	# A second committed warning is still killable through the same damage path.
	enemy._begin_charge_windup(0.3)
	_apply_test_hit(enemy, 99999.0)
	var death_ok: bool = enemy.death_emitted and enemy.is_queued_for_deletion() and enemy.velocity == Vector2.ZERO
	print("[CHARGE BENCH] %s death=%s RESULT=%s" % [type_name, str(death_ok), "PASS" if warning_ok and rush_ok and recovery_ok and death_ok else "FAIL"])
	await get_tree().physics_frame

func _probe_player_shield_contact(enemy: Enemy, player: Player) -> void:
	enemy.shield_angle = enemy.global_position.angle_to_point(player.global_position)
	enemy.shield_parry_cooldown_left = 0.0
	var shield_direction: Vector2 = Vector2.from_angle(enemy.shield_angle)
	var center: Vector2 = enemy.global_position + shield_direction * enemy.elite_shield_distance
	var tangent: Vector2 = shield_direction.orthogonal()
	var start: Vector2 = center - tangent * 8.0
	var end: Vector2 = center + tangent * 8.0
	player.hit_stagger_left = 0.0
	player.hit_knockback = Vector2.ZERO
	player.current_blade_samples = PackedVector2Array([start, end])
	player.blade_velocity = tangent * 900.0
	player._check_sword_hits(start, end, 1.0 / 60.0)
	var shield_ok: bool = player.hit_stagger_left >= Player.SHIELD_CLASH_STUN_DURATION and player.hit_knockback.length() >= Player.SHIELD_CLASH_KNOCKBACK and enemy.stun_left == 0.0
	print("[CHARGE BENCH] ogre real shield contact=%s player_stun=%.3f player_recoil=%.1f" % [str(shield_ok), player.hit_stagger_left, player.hit_knockback.length()])
	if not shield_ok:
		push_error("[CHARGE BENCH] shield contact failed")
