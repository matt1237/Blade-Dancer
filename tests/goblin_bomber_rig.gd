class_name GoblinBomberRig extends EnemySpawnRig
## Read-only observations of the real Main-spawned bomber's attack.
var _observed: Dictionary[int, int] = {}

func _process(delta: float) -> void:
	super._process(delta)
	if _main == null: return
	for node: Node in _main.get_children():
		var bomb: BomberBomb = node as BomberBomb
		if bomb == null: continue
		var id: int = bomb.get_instance_id()
		if not _observed.has(id):
			bomb.damage_pulse.connect(_log_pulse.bind(bomb))
		if int(_observed.get(id, -1)) != int(bomb.phase):
			print("[BOMBER RIG] %s elapsed=%.3f target=%s bomber_alive=%s" % [BomberBomb.Phase.keys()[bomb.phase], bomb.elapsed, str(bomb.locked_target), str(is_instance_valid(bomb.thrower))])
		_observed[id] = int(bomb.phase)

func _log_pulse(amount: float, bomb: BomberBomb) -> void:
	print("[BOMBER RIG] pulse=%.0f elapsed=%.3f in_radius=%s" % [amount, bomb.elapsed, str(is_instance_valid(bomb.player) and bomb.contains_point(bomb.player.global_position))])
