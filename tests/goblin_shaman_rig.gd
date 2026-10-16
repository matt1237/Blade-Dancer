class_name GoblinShamanRig extends EnemySpawnRig
## Real Main spawn path; isolated stationary injured recipient, no save writes.
var recipient: Enemy = null
var caster: GoblinShaman = null
var hp_label: Label = null
var _reported_ticks: int = 0

func spawn_now() -> void:
	super.spawn_now()
	if _main == null: return
	var player: Player = _player()
	_main._spawn_training_enemy_at(player.global_position + Vector2(185, 55), WaveSpawner.OGRE_SCENE)
	_track_new_enemies()
	for enemy: Enemy in _tracked:
		if enemy is GoblinShaman: caster = enemy as GoblinShaman
		if enemy.spawn_balance_key() == &"ogre": recipient = enemy
	if caster == null or recipient == null: return
	# Recipient remains a real Enemy with shared physics and recipient-owned ticks.
	recipient.move_speed = 0.0
	recipient.charge_cooldown = INF
	recipient.participates_in_melee_engagement = false
	recipient.take_damage(recipient.max_health * 0.65, Vector2.ZERO, 0.0)
	caster.healing_cast_started.connect(_cast_started)
	caster.healing_cast_completed.connect(_cast_completed)
	caster.healing_orb_launched.connect(_orb_launched)
	caster.healing_cast_interrupted.connect(func() -> void: print("[SHAMAN RIG] interrupted"))
	recipient.health_restored.connect(_healed)
	hp_label = Label.new()
	hp_label.position = Vector2(-50, -85)
	recipient.add_child(hp_label)
	print("[SHAMAN RIG] recipient initial hp=%.1f/%.1f caster=%s" % [recipient.health, recipient.max_health, caster.spawn_balance_key()])

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(recipient) and hp_label != null:
		hp_label.text = "Ogre HP %.0f / %.0f" % [recipient.health, recipient.max_health]

func _cast_started(target: Enemy) -> void:
	print("[SHAMAN RIG] cast START target=%s hp=%.1f duration=%.2f cooldown=%.1f" % [target.spawn_balance_key(), target.health, caster.cast_duration, caster.fire_timer])

func _cast_completed(target: Enemy, restored: float) -> void:
	print("[SHAMAN RIG] cast COMPLETE launch-only restored=%.1f hp=%.1f frame=%d regen_ticks=%d" % [restored, target.health, caster.hd_enemy_sprite.frame, target.shaman_regen_ticks_left])

func _orb_launched(orb: ShamanHealOrb) -> void:
	print("[SHAMAN RIG] ORB seeking hp=%.1f world_owned=%s" % [recipient.health, str(orb.get_parent() == caster.get_parent())])
	orb.arrived.connect(func(target: Enemy, restored: float) -> void:
		print("[SHAMAN RIG] ORB ARRIVED restored=%.1f hp=%.1f regen_ticks=%d flight=%.2fs" % [restored, target.health, target.shaman_regen_ticks_left, orb.elapsed])
	)

func _healed(amount: float) -> void:
	if amount == 1.0: _reported_ticks += 1
	print("[SHAMAN RIG] HP gain=%.1f hp=%.1f tick=%d" % [amount, recipient.health, _reported_ticks])
