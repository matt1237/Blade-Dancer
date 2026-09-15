class_name BearTrap extends Area2D

const HD_BEAR_TRAP: Texture2D = preload("res://assets/generated/forest_bear_trap_hd_frame_0.png")

@export var root_duration: float = 1.0
@export var rearm_duration: float = 4.0
@export var radius: float = 22.0
var armed: bool = true
var rearm_left: float = 0.0
var snap_flash_left: float = 0.0

func _ready() -> void:
	# Traps are sensors, not solid walls: detect both player and enemy bodies.
	collision_mask = 3
	z_as_relative = false
	# z_index is intentionally NOT set here. configure() assigns it from
	# TerrainConfig.trap_visual_z_index before this node enters the tree, and
	# that value must survive _ready() so players/enemies render above traps.
	add_to_group("terrain_modules")
	add_to_group("terrain_traps")
	body_entered.connect(_on_body_entered)
	queue_redraw()

func configure(config: TerrainConfig) -> void:
	root_duration = config.bear_trap_root_duration
	rearm_duration = config.bear_trap_rearm_duration
	radius = config.bear_trap_radius
	var collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = radius

func world_footprint() -> Rect2:
	return Rect2(global_position - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)

func _process(delta: float) -> void:
	snap_flash_left = maxf(0.0, snap_flash_left - delta)
	if not armed:
		rearm_left = maxf(0.0, rearm_left - delta)
		if rearm_left <= 0.0: armed = true
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not armed: return
	var player: Player = body as Player
	var enemy: Enemy = body as Enemy
	if player == null and enemy == null: return
	armed = false
	rearm_left = rearm_duration
	snap_flash_left = 0.25
	if player != null:
		player.apply_terrain_root(root_duration)
	elif enemy != null:
		enemy.stun_for(root_duration)
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 0.75)
	if main_scene.has_method("play_sfx"): main_scene.play_sfx("clash", 0.65, 0.82)

func _draw() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null and str(current_scene.get("visual_style")) == "hd":
		var trap_tint: Color = Color.WHITE if armed else Color(0.55, 0.58, 0.6, 1.0)
		# The authored 48px square is drawn at the same diameter as the
		# configured collision circle. The snap ring remains a separate telegraph.
		var visual_radius: float = radius
		draw_texture_rect(HD_BEAR_TRAP, Rect2(-visual_radius, -visual_radius, visual_radius * 2.0, visual_radius * 2.0), false, trap_tint)
		if snap_flash_left > 0.0:
			var flash_alpha_hd: float = snap_flash_left / 0.25
			draw_arc(Vector2.ZERO, 28.0 + (1.0 - flash_alpha_hd) * 18.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.18, flash_alpha_hd), 4.0, true)
		return
	var metal_dark: Color = Color("263247")
	var metal: Color = Color("8799a6") if armed else Color("59636c")
	var warning: Color = Color(0.9, 0.24, 0.12, 0.75 if armed else 0.18)
	draw_circle(Vector2.ZERO, radius + 8.0, Color(warning.r, warning.g, warning.b, warning.a * 0.12))
	draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, warning, 2.0, true)
	draw_circle(Vector2.ZERO, 9.0, metal_dark)
	draw_circle(Vector2.ZERO, 6.0, Color("9b6d3f"))
	var jaw_open: float = 10.0 if armed else 4.0
	for side_index: int in range(2):
		var side: float = -1.0 if side_index == 0 else 1.0
		var jaw_center: Vector2 = Vector2(side * jaw_open, 0.0)
		draw_arc(jaw_center, 12.0, -PI * 0.55, PI * 0.55, 12, metal_dark, 7.0, true)
		draw_arc(jaw_center, 12.0, -PI * 0.55, PI * 0.55, 12, metal, 3.0, true)
		for tooth_index: int in range(3):
			var tooth_y: float = -8.0 + float(tooth_index) * 8.0
			var tooth_base: Vector2 = Vector2(side * (jaw_open + 6.0), tooth_y)
			draw_colored_polygon(PackedVector2Array([tooth_base + Vector2(0.0, -3.0), tooth_base + Vector2(-side * 7.0, 0.0), tooth_base + Vector2(0.0, 3.0)]), metal)
	if snap_flash_left > 0.0:
		var flash_alpha: float = snap_flash_left / 0.25
		draw_arc(Vector2.ZERO, 28.0 + (1.0 - flash_alpha) * 18.0, 0.0, TAU, 28, Color(1.0, 0.55, 0.18, flash_alpha), 4.0, true)
