class_name EnemyProjectile extends Area2D

## Must match the CircleShape2D radius in enemy_projectile.tscn.
const BODY_RADIUS: float = 9.0
## Extra clearance used before ranged enemies consider a shot safe around wall edges.
const LOS_SAFETY_PADDING: float = 4.0
const WALL_LOS_CLEARANCE: float = BODY_RADIUS + LOS_SAFETY_PADDING
## Places new projectiles in front of the firing creature instead of inside its body.
const MUZZLE_OFFSET: float = 16.0
const BOSS_SUMMON_GROUP: StringName = &"zungar_summons"

var direction: Vector2 = Vector2.ZERO
@export var speed: float = 220.0
@export var damage: float = 12.0
var deflected: bool = false
## Boss spear throws use a different silhouette from ordinary Bug bolts.
var spear_visual: bool = false
## Enabled only for Zungar's projectiles. Ordinary enemies never hurt each other.
var damages_boss_summons: bool = false
var boss_summon_damage: float = 0.0
var player_ref: Player = null
var source_enemy: Node2D = null

func _ready() -> void:
	add_to_group("enemy_projectiles")
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		player_ref = players[0] as Player
	body_entered.connect(_on_body_entered)
	queue_redraw()

func launch(value: Vector2, owner_enemy: Node2D = null) -> void:
	source_enemy = owner_enemy
	direction = value.normalized()
	deflected = false
	queue_redraw()

func deflect() -> bool:
	if deflected:
		return false
	deflected = true
	speed = 380.0
	var nearest_enemy: Node2D = null
	var nearest_distance: float = INF
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy != null:
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	if nearest_enemy != null:
		direction = global_position.direction_to(nearest_enemy.global_position)
	else:
		direction = -direction
	queue_redraw()
	return true

func _physics_process(delta: float) -> void:
	# Once deflected, this is a player-owned attack and must not inherit enemy slowdown.
	var speed_multiplier: float = player_ref.get_flow_enemy_speed_multiplier() if player_ref != null and not deflected else 1.0
	var travel_start: Vector2 = global_position
	var travel_end: Vector2 = global_position + direction * speed * speed_multiplier * delta
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("get_terrain_wall_collision"):
		var wall_hit: Dictionary = main_scene.get_terrain_wall_collision(travel_start, travel_end, BODY_RADIUS)
		if not wall_hit.is_empty():
			global_position = wall_hit["position"] as Vector2
			if main_scene.has_method("spawn_impact_fx"):
				main_scene.spawn_impact_fx(global_position, 0.35)
			queue_free()
			return
	global_position = travel_end
	if deflected:
		for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
			var enemy: Node2D = enemy_node as Node2D
			if enemy != null and is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 24.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage * 1.5, direction * 180.0)
				queue_free()
				return
	elif damages_boss_summons and _hit_boss_summon_along_segment(travel_start, travel_end):
		return
	var cleanup_rect: Rect2 = GameplayBounds.arena_rect(get_tree().current_scene).grow(160.0)
	if not cleanup_rect.has_point(global_position):
		queue_free()

func _hit_boss_summon_along_segment(start: Vector2, end: Vector2) -> bool:
	for minion_node: Node in get_tree().get_nodes_in_group(BOSS_SUMMON_GROUP):
		var minion: Node2D = minion_node as Node2D
		if minion == null or not is_instance_valid(minion) or minion == source_enemy:
			continue
		if _distance_to_segment(minion.global_position, start, end) > BODY_RADIUS + 17.0:
			continue
		if minion.has_method("take_damage"):
			var applied_damage: float = boss_summon_damage if boss_summon_damage > 0.0 else damage
			minion.take_damage(applied_damage, direction * 260.0)
		if is_instance_valid(source_enemy) and source_enemy.has_method("on_friendly_fire_hit"):
			source_enemy.on_friendly_fire_hit()
		queue_free()
		return true
	return false

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var amount: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * amount)

func _draw() -> void:
	var core_color: Color = Color(0.2, 0.85, 1.0) if deflected else Color("e33128")
	var projectile_direction: Vector2 = direction if direction.length_squared() > 0.01 else Vector2.RIGHT
	draw_set_transform(Vector2.ZERO, projectile_direction.angle(), Vector2.ONE)
	if spear_visual:
		# Zungar's spear projectile.
		draw_line(Vector2(-12.0, 0.0), Vector2(18.0, 0.0), Color("3c2b2d"), 6.0, true)
		draw_line(Vector2(-10.0, 0.0), Vector2(16.0, 0.0), core_color, 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(18.0, 0.0), Vector2(8.0, -5.0), Vector2(8.0, 5.0)]), Color("dce8f2") if not deflected else Color("dffaff"))
	else:
		# Bug bolt: compact, bright, and visibly distinct from a spear.
		draw_line(Vector2(-9.0, 0.0), Vector2(9.0, 0.0), Color(core_color.r, core_color.g, core_color.b, 0.35), 8.0, true)
		draw_circle(Vector2.ZERO, 5.0, core_color)
		draw_circle(Vector2.ZERO, 2.0, Color("fff2b0") if not deflected else Color("dffaff"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _on_body_entered(body: Node2D) -> void:
	if deflected and body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage * 1.5, direction * 180.0)
		queue_free()
	elif not deflected and body.is_in_group("player") and body.has_method("take_damage"):
		# The firing enemy may have died while its projectile was still in flight.
		# Never pass a freed Object into Player.take_damage's typed attacker argument.
		var attacker: Node2D = source_enemy if is_instance_valid(source_enemy) else null
		body.take_damage(damage, -direction * 220.0, attacker)
		queue_free()
	elif not deflected and damages_boss_summons and body.is_in_group(BOSS_SUMMON_GROUP):
		if body.has_method("take_damage"):
			var applied_damage: float = boss_summon_damage if boss_summon_damage > 0.0 else damage
			body.take_damage(applied_damage, direction * 260.0)
		if is_instance_valid(source_enemy) and source_enemy.has_method("on_friendly_fire_hit"):
			source_enemy.on_friendly_fire_hit()
		queue_free()
