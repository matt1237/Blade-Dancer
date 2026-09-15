class_name MudPatch extends Area2D

const HD_MUD_PATCH: Texture2D = preload("res://assets/generated/forest_mud_patch_hd_frame_0.png")

@export var movement_multiplier: float = 0.5
@export var disables_dash: bool = true
@export var radius: float = 46.0
var affected_players: Array[Player] = []
var affected_enemies: Array[Enemy] = []

func _ready() -> void:
	# Mud is a sensor for both player and enemy bodies, not a solid obstacle.
	collision_mask = 3
	z_as_relative = false

	# z_index is intentionally NOT set here. configure() assigns it from
	# TerrainConfig.trap_visual_z_index before this node enters the tree, and
	# that value must survive _ready() so players/enemies render above traps.
	add_to_group("terrain_modules")
	add_to_group("terrain_traps")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	queue_redraw()

func configure(config: TerrainConfig) -> void:
	movement_multiplier = config.mud_movement_multiplier
	disables_dash = config.mud_disables_dash
	radius = config.mud_radius
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = radius

func world_footprint() -> Rect2:
	return Rect2(global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player != null:
		if not affected_players.has(player): affected_players.append(player)
		player.set_terrain_movement_modifier(get_instance_id(), movement_multiplier)
		player.set_terrain_dash_block(get_instance_id(), disables_dash)
		return
	var enemy: Enemy = body as Enemy
	if enemy != null:
		if not affected_enemies.has(enemy): affected_enemies.append(enemy)
		enemy.set_terrain_movement_modifier(get_instance_id(), movement_multiplier)

func _on_body_exited(body: Node2D) -> void:
	var player: Player = body as Player
	if player != null:
		affected_players.erase(player)
		player.remove_terrain_effect(get_instance_id())
		return
	var enemy: Enemy = body as Enemy
	if enemy != null:
		affected_enemies.erase(enemy)
		enemy.remove_terrain_movement_modifier(get_instance_id())

func _exit_tree() -> void:
	for player: Player in affected_players:
		if is_instance_valid(player): player.remove_terrain_effect(get_instance_id())
	for enemy: Enemy in affected_enemies:
		if is_instance_valid(enemy): enemy.remove_terrain_movement_modifier(get_instance_id())

func _draw() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and str(current_scene.get("visual_style")) == "hd":
		# Preserve the authored 96:64 aspect ratio while keeping the visual
		# footprint inside the configured collision diameter.
		var visual_half_width: float = radius
		var visual_half_height: float = radius * (64.0 / 96.0)
		draw_texture_rect(HD_MUD_PATCH, Rect2(-visual_half_width, -visual_half_height, visual_half_width * 2.0, visual_half_height * 2.0), false)
		return
	draw_circle(Vector2.ZERO, radius + 4.0, Color(0.12, 0.16, 0.11, 0.75))
	draw_circle(Vector2.ZERO, radius, Color(0.25, 0.20, 0.12, 0.82))
	draw_circle(Vector2(-15.0, 7.0), radius * 0.42, Color(0.34, 0.27, 0.14, 0.72))
	draw_circle(Vector2(17.0, -9.0), radius * 0.3, Color(0.18, 0.14, 0.09, 0.72))
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 32, Color(0.63, 0.49, 0.22, 0.5), 2.0, true)
	for bubble_index: int in range(5):
		var angle: float = float(bubble_index) * 1.37
		var bubble_position: Vector2 = Vector2.RIGHT.rotated(angle) * (12.0 + float(bubble_index % 2) * 13.0)
		draw_circle(bubble_position, 2.5 + float(bubble_index % 2), Color(0.52, 0.4, 0.18, 0.7))
