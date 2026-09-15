class_name MoonSlash extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 430.0
var damage: float = 24.0
var remaining: float = 170.0
var size_scale: float = 1.0
var hit_ids: Dictionary[int, bool] = {}
var owner_player: Player = null

func launch(origin: Vector2, travel_direction: Vector2, slash_damage: float, slash_size: float, owner_player_value: Player = null) -> void:
	global_position = origin
	owner_player = owner_player_value
	direction = travel_direction.normalized()
	rotation = direction.angle()
	damage = slash_damage
	size_scale = slash_size
	remaining = 170.0 * size_scale

func _physics_process(delta: float) -> void:
	var travel: float = speed * delta
	global_position += direction * travel
	remaining -= travel
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or not is_instance_valid(enemy): continue
		if enemy.has_method("shield_blocks_projectile") and enemy.shield_blocks_projectile(global_position):
			queue_free()
			return
		if not hit_ids.has(enemy.get_instance_id()) and global_position.distance_to(enemy.global_position) < 24.0 * size_scale:
			hit_ids[enemy.get_instance_id()] = true
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, direction * 150.0)
				if owner_player != null: owner_player.notify_player_damage_dealt(false)
	if remaining <= 0.0: queue_free()
	queue_redraw()

func _draw() -> void:
	var radius: float = 30.0 * size_scale
	var outer_color: Color = Color(0.25, 0.65, 1.0, 0.18)
	var glow_color: Color = Color(0.45, 0.85, 1.0, 0.42)
	var blade_color: Color = Color(0.8, 0.97, 1.0, 0.95)
	# The arc opens toward the travel direction, reading as a thrown slash instead of a bolt.
	draw_arc(Vector2.ZERO, radius + 6.0 * size_scale, -1.15, 1.15, 28, outer_color, 10.0 * size_scale, true)
	draw_arc(Vector2.ZERO, radius, -1.1, 1.1, 28, glow_color, 7.0 * size_scale, true)
	draw_arc(Vector2.ZERO, radius - 3.0 * size_scale, -1.05, 1.05, 28, blade_color, 3.0 * size_scale, true)
	draw_line(Vector2(-8.0, -radius * 0.65), Vector2(-8.0, radius * 0.65), Color(0.65, 0.92, 1.0, 0.35), 2.0 * size_scale, true)
