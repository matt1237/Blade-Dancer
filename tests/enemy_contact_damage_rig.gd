class_name EnemyContactDamageRig extends EnemySpawnRig
## Real enemy combat/contact bench. Player sword is stowed in-memory so its
## outgoing hits cannot interrupt the enemy; no player save/preset is written.
var _observed_player: Player = null
var _last_hp: float = 0.0
var _hits: int = 0

func _ready() -> void:
	await super._ready()
	if _main == null:
		return
	_main.set_px_mode(false)
	_observed_player = _player()
	if _observed_player == null:
		return
	_observed_player.sword_stowed = true
	_last_hp = _observed_player.health
	_observed_player.health_changed.connect(_on_health_changed)
	print("[ENEMY DAMAGE BENCH] type=%s; sword stowed; HP=%s" % [enemy_type, str(_last_hp)])

func _on_health_changed(health: float, max_health: float) -> void:
	var damage: float = _last_hp - health
	_last_hp = health
	if damage <= 0.0:
		return
	_hits += 1
	print("[ENEMY DAMAGE BENCH] type=%s damage=%.1f HP=%.1f/%0.1f contacts=%d" % [enemy_type, damage, health, max_health, _hits])
