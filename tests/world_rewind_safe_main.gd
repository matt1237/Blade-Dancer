extends "res://tests/rewind_safe_main.gd"
## World rewind (spiral) visual bench on real Main (save writes refused/counted by the parent rig).
## Spawns real enemies through Main's training spawn path (_spawn_training_enemy_at), a bug bolt
## via spawn_boss_projectile and a real BomberBomb; then scripted: walk, kill one enemy, and at
## ~4.5 s call the same Player.activate_world_rewind() entry (W key does the same manually).
var world_enemies: Array[Enemy] = []
var victim: Enemy = null
var start_positions: Dictionary = {}
var rig_time: float = 0.0
var killed: bool = false
var triggered: bool = false
var bomb: BomberBomb = null

func _ready() -> void:
	super._ready()
	player.set_combat_contact_setting("world_rewind_gesture_enabled", 1.0) # in-memory only
	var base: Vector2 = player.global_position
	var scenes: Array[PackedScene] = [WaveSpawner.TURKEY_SCENE, WaveSpawner.SWORD_GOBLIN_SCENE, WaveSpawner.OGRE_SCENE]
	for index: int in range(scenes.size()):
		_spawn_training_enemy_at(base + Vector2(-260.0 + 200.0 * float(index), 170.0), scenes[index])
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is Enemy: world_enemies.append(node as Enemy)
	victim = world_enemies[0] if world_enemies.size() > 0 else null
	print("[WORLD RIG] spawned enemies=", world_enemies.size(), " via Main._spawn_training_enemy_at writes=", write_attempts)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_W:
		_trigger()
		return
	super._unhandled_input(event)

func _trigger() -> void:
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	for enemy: Enemy in world_enemies:
		if is_instance_valid(enemy): start_positions[enemy.get_instance_id()] = enemy.global_position
	triggered = player.activate_world_rewind()
	print("[WORLD RIG] activate_world_rewind=", triggered, " retired=", get_tree().get_nodes_in_group(WorldRewindRecorder.RETIRED_GROUP).size(), " alive_count=", spawner._count_alive_enemies())

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if get_tree().paused:
		return
	rig_time += delta
	if rig_time > 0.6 and rig_time < 0.7 and bomb == null:
		bomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
		add_child(bomb)
		bomb.arm(player.global_position + Vector2(300, -200), player.global_position + Vector2(260, -150), null)
		spawn_boss_projectile(player.global_position + Vector2(-400, -120), Vector2.RIGHT, 0.0)
		print("[WORLD RIG] bomb + bolt spawned")
	if rig_time > 1.2 and rig_time < 3.8:
		player.global_position += Vector2(90.0 * delta, 0.0) # scripted walk
	if not killed and rig_time > 2.5 and is_instance_valid(victim):
		killed = true
		victim.take_damage(99999.0)
		print("[WORLD RIG] killed ", victim.spawn_identity, " retired=", victim.rewind_retired, " in_enemies=", victim.is_in_group("enemies"), " alive_count=", spawner._count_alive_enemies())
	if not triggered and rig_time > 4.5 and player.rewind_charge_available:
		_trigger()

func _on_rewind_finished(at: Vector2) -> void:
	super._on_rewind_finished(at)
	for enemy: Enemy in world_enemies:
		if is_instance_valid(enemy):
			print("[WORLD RIG] after restore ", enemy.spawn_identity, " pos=", enemy.global_position, " moved_back=", enemy.global_position.distance_to(start_positions.get(enemy.get_instance_id(), enemy.global_position)), " health=", enemy.health, " retired=", enemy.rewind_retired, " visible=", enemy.visible)
	print("[WORLD RIG] victim revived=", is_instance_valid(victim) and not victim.rewind_retired and victim.is_in_group("enemies"), " alive_count=", spawner._count_alive_enemies(), " bomb_valid=", is_instance_valid(bomb), " bomb_elapsed=", bomb.elapsed if is_instance_valid(bomb) else -1.0, " writes=", write_attempts)
