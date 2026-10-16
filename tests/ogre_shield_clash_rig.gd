class_name OgreShieldClashRig extends EnemySpawnRig
## Live bench for the Ogre shield clash. It boots the REAL main scene, spawns one Ogre with its
## shield facing the player, drives the REAL blade-contact path across the front of the shield, and
## reports whether the clash knocked the player back and pinned them (player + input + sword).
## TEST RIG ONLY: it never writes saves or global presets.

func _ready() -> void:
	await super._ready()
	if _main == null:
		return
	await get_tree().process_frame
	var alive: Array[Enemy] = _alive_enemies()
	if alive.is_empty():
		print("[SHIELD CLASH PROBE] no ogre spawned")
		return
	_probe_shield_clash(alive[0])

func _probe_shield_clash(ogre: Enemy) -> void:
	var player: Player = _player()
	if player == null or ogre == null:
		print("[SHIELD CLASH PROBE] missing player or ogre")
		return
	# Face the shield straight at the player so the front of the shield meets the blade.
	ogre.shield_angle = ogre.global_position.angle_to_point(player.global_position)
	ogre.stun_left = 0.0
	ogre.shield_parry_cooldown_left = 0.0
	var shield_direction: Vector2 = Vector2.RIGHT.rotated(ogre.shield_angle)
	var shield_center: Vector2 = ogre.global_position + shield_direction * ogre.elite_shield_distance
	var tangent: Vector2 = shield_direction.orthogonal()
	var blade_start: Vector2 = shield_center - tangent * 8.0
	var blade_end: Vector2 = shield_center + tangent * 8.0
	player.hit_stagger_left = 0.0
	player.hit_knockback = Vector2.ZERO
	player.blade_freeze_left = 0.0
	player.clash_recovery_left = 0.0
	player.current_blade_samples = PackedVector2Array([blade_start, blade_end])
	player.blade_velocity = tangent * 900.0
	var forgiveness: float = player.get_combat_contact_setting("parry_contact_tolerance")
	var blocking: bool = ogre.is_shield_blocking(blade_start, blade_end, forgiveness)
	player._check_sword_hits(blade_start, blade_end, 1.0 / 60.0)
	print("[SHIELD CLASH PROBE] blocking=%s stagger=%.3f knockback=%s freeze=%.3f" % [
		str(blocking), player.hit_stagger_left, str(player.hit_knockback), player.blade_freeze_left])
	var direction_to_contact: Vector2 = player.global_position.direction_to((blade_start + blade_end) * 0.5)
	var knocked_away: bool = player.hit_knockback.dot(-direction_to_contact) > 0.0
	if player.hit_stagger_left >= Player.SHIELD_CLASH_STUN_DURATION and is_zero_approx(player.blade_freeze_left) and knocked_away:
		print("[SHIELD CLASH PROBE] PASS: the shield knocked the player back and briefly stunned them without freezing the sword.")
	else:
		print("[SHIELD CLASH PROBE] FAIL: no clash pause was produced.")