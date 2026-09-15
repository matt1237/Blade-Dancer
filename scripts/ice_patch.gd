class_name IcePatch extends Node2D

var player_ref: Player = null
var patch_radius: float = 80.0
var life_left: float = 5.0
var enemy_friction_multiplier: float = 0.42
var player_friction_multiplier: float = 0.22
var patch_source_id: int = 0
var visual_time: float = 0.0

func setup(owner_player: Player, center: Vector2, radius: float, duration: float) -> void:
	player_ref = owner_player
	global_position = center
	patch_radius = maxf(16.0, radius)
	life_left = maxf(0.1, duration)
	patch_source_id = get_instance_id()
	z_index = 1
	queue_redraw()

func _ready() -> void:
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float) -> void:
	visual_time += delta
	life_left -= delta
	if life_left <= 0.0:
		_cleanup_effects()
		queue_free()
		return
	if player_ref != null and is_instance_valid(player_ref):
		if player_ref.global_position.distance_to(global_position) <= patch_radius:
			player_ref.set_ice_slide(patch_source_id, player_friction_multiplier)
		else:
			player_ref.remove_ice_slide(patch_source_id)
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy): continue
		if enemy.global_position.distance_to(global_position) <= patch_radius:
			enemy.set_terrain_movement_modifier(patch_source_id, enemy_friction_multiplier)
		else:
			enemy.remove_terrain_movement_modifier(patch_source_id)
	queue_redraw()

func _cleanup_effects() -> void:
	if player_ref != null and is_instance_valid(player_ref): player_ref.remove_ice_slide(patch_source_id)
	if not is_inside_tree(): return
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null and is_instance_valid(enemy): enemy.remove_terrain_movement_modifier(patch_source_id)

func _exit_tree() -> void:
	_cleanup_effects()

func _draw() -> void:
	var fade: float = clampf(life_left / 0.8, 0.0, 1.0)
	var pulse: float = 0.96 + sin(visual_time * 3.0) * 0.04
	var radius: float = patch_radius * pulse
	draw_circle(Vector2.ZERO, radius, Color(0.24, 0.78, 0.98, 0.16 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.55, 0.92, 1.0, 0.58 * fade), 3.0, true)
	draw_arc(Vector2.ZERO, radius * 0.72, 0.15, 2.0, 24, Color(0.72, 0.96, 1.0, 0.34 * fade), 2.0, true)
	var crack_color: Color = Color(0.78, 0.98, 1.0, 0.42 * fade)
	for crack_index: int in range(6):
		var angle: float = float(crack_index) * TAU / 6.0 + 0.18
		var start_radius: float = radius * (0.12 + float(crack_index % 2) * 0.12)
		var end_radius: float = radius * (0.58 + float(crack_index % 3) * 0.10)
		var start_point: Vector2 = Vector2.RIGHT.rotated(angle) * start_radius
		var middle_point: Vector2 = Vector2.RIGHT.rotated(angle + 0.08) * (start_radius + end_radius) * 0.5
		var end_point: Vector2 = Vector2.RIGHT.rotated(angle) * end_radius
		draw_polyline(PackedVector2Array([start_point, middle_point, end_point]), crack_color, 2.0, true)
