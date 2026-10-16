class_name GoblinSpearDamageRig extends EnemySpawnRig
## Real Main + spear goblin. Settings changed in memory only; no preset writes.
var _damage_player: Player = null
var _health_reports: int = 0
var _last_health: float = 0.0

func _ready() -> void:
	await super._ready()
	if _main == null:
		return
	_main.set_px_mode(false)
	_damage_player = _player()
	if _damage_player == null:
		return
	# Put the sword away so this check isolates an unblocked spear hitting the
	# real Player.take_damage path. Keep normal immunity, defense and enemy AI.
	_damage_player.sword_stowed = true
	_last_health = _damage_player.health
	_damage_player.health_changed.connect(_on_player_health_changed)
	print("[SPEAR DAMAGE] real goblin AI; sword stowed; starting HP=%s" % str(_damage_player.health))

func _on_player_health_changed(health: float, max_health: float) -> void:
	var lost: float = _last_health - health
	_last_health = health
	if lost <= 0.0:
		return # Normal regeneration emits this too; report damage only.
	_health_reports += 1
	var alive: Array[Enemy] = _alive_enemies()
	var distance: float = _damage_player.global_position.distance_to(alive[0].global_position) if not alive.is_empty() else -1.0
	print("[SPEAR DAMAGE] HP=%s/%s body_distance=%.1f health_events=%d" % [str(health), str(max_health), distance, _health_reports])
