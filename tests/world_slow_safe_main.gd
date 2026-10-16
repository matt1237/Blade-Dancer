extends "res://tests/rewind_safe_main.gd"
## World Slow visual bench on real Main (save writes refused/counted by the parent rig).
## Real enemies via Main._spawn_training_enemy_at + a bug bolt; measures enemy displacement
## over 1 s normal, then calls Player.activate_world_slow() (S key manual) and measures again.
var world_enemies: Array[Enemy] = []
var rig_time: float = 0.0
var mark: Dictionary = {}
var normal_travel: float = -1.0
var triggered: bool = false
var wave_mark: float = 0.0

func _ready() -> void:
	super._ready()
	player.set_combat_contact_setting("world_slow_gesture_enabled", 1.0) # in-memory only
	var base: Vector2 = player.global_position
	var scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.SWORD_GOBLIN_SCENE, WaveSpawner.GOBLIN_SCENE]
	for index: int in range(scenes.size()):
		_spawn_training_enemy_at(base + Vector2(-320.0 + 320.0 * float(index), 260.0), scenes[index])
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy: world_enemies.append(node as Enemy)
	print("[SLOW RIG] spawned enemies=", world_enemies.size(), " writes=", write_attempts)
	if not player.slow_charge_changed.is_connected(_on_slow_charge_changed):
		player.slow_charge_changed.connect(_on_slow_charge_changed) # safe rig skips Main._ready

var bolt_mark: Vector2 = Vector2.ZERO
var bolt_normal: float = -1.0
func _bolt() -> Node2D:
	for node: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		return node as Node2D
	for node: Node in get_children():
		if node is EnemyProjectile: return node as Node2D
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_S:
		_trigger()
		return
	super._unhandled_input(event)

func _travel() -> float:
	var total: float = 0.0
	for enemy: Enemy in world_enemies:
		if is_instance_valid(enemy): total += enemy.global_position.distance_to(mark.get(enemy.get_instance_id(), enemy.global_position))
	return total

func _mark() -> void:
	for enemy: Enemy in world_enemies:
		if is_instance_valid(enemy): mark[enemy.get_instance_id()] = enemy.global_position
	wave_mark = spawner.wave_elapsed
	var bolt: Node2D = _bolt()
	if bolt != null:
		if bolt_normal < 0.0 and bolt_mark != Vector2.ZERO: bolt_normal = bolt.global_position.distance_to(bolt_mark)
		bolt_mark = bolt.global_position

func _trigger() -> void:
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	triggered = player.activate_world_slow()
	print("[SLOW RIG] activate_world_slow=", triggered, " scale=", WorldTime.enemy_scale(), " slow_icon_alpha=", get_node("CanvasLayer/SlowIcon").modulate.a)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	rig_time += delta
	if rig_time > 0.5 and rig_time < 0.52:
		spawn_boss_projectile(player.global_position + Vector2(-500, -140), Vector2.RIGHT, 0.0)
		_mark()
	if normal_travel < 0.0 and rig_time >= 1.5:
		normal_travel = _travel()
		print("[SLOW RIG] normal 1s travel=%.1f wave_dt=%.3f" % [normal_travel, spawner.wave_elapsed - wave_mark])
		_trigger()
		_mark()
	if triggered and rig_time >= 2.5 and mark.size() > 0 and normal_travel >= 0.0:
		var slow_travel: float = _travel()
		print("[SLOW RIG] slowed 1s travel=%.1f ratio=%.3f wave_dt=%.3f slow_left=%.2f writes=%d" % [slow_travel, slow_travel / maxf(normal_travel, 0.001), spawner.wave_elapsed - wave_mark, WorldTime.slow_left, write_attempts])
		var bolt: Node2D = _bolt()
		var bolt_slow: float = bolt.global_position.distance_to(bolt_mark) if bolt != null else -1.0
		print("[SLOW RIG] bolt 1s normal=%.1f slowed=%.1f ratio=%.3f tint=%s icon_alpha=%.2f" % [bolt_normal, bolt_slow, bolt_slow / maxf(bolt_normal, 0.001), player.world_slow_tint_layer != null, get_node("CanvasLayer/SlowIcon").modulate.a])
		mark.clear()
