class_name ResonantGlyph extends Area2D

const GLYPH_RADIUS: float = 32.0
const CHAKRAM_REHIT_COOLDOWN: float = 0.18
const PULSE_VISUAL_DURATION: float = 0.38
const AFTERIMAGE_COUNT: int = 3

var owner_player: Player = null
var rank_value: int = 0
var lifetime_left: float = 0.0
var animation_time: float = 0.0
var pulse_left: float = 0.0
var pulse_radius: float = 0.0
var chakram_hit_cooldowns: Dictionary[int, float] = {}

func setup(player: Player, glyph_rank: int) -> void:
	owner_player = player
	rank_value = clampi(glyph_rank, 1, BonusConfig.MAX_RANK)
	lifetime_left = BonusConfig.resonant_glyph_duration(rank_value)
	queue_redraw()

static func distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared < 0.001:
		return point.distance_to(start)
	var ratio: float = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func segment_hit(start: Vector2, end: Vector2, sweep_radius: float = 0.0) -> Dictionary:
	var hit_distance: float = distance_to_segment(global_position, start, end)
	if hit_distance > GLYPH_RADIUS + maxf(0.0, sweep_radius):
		return {}
	var closest_offset: Vector2 = start
	var segment: Vector2 = end - start
	if segment.length_squared() > 0.001:
		var ratio: float = clampf((global_position - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest_offset = start + segment * ratio
	var normal: Vector2 = global_position.direction_to(closest_offset)
	if normal == Vector2.ZERO:
		normal = global_position.direction_to(start)
	if normal == Vector2.ZERO:
		normal = -segment.normalized() if segment.length_squared() > 0.001 else Vector2.RIGHT
	return {"position": global_position + normal * GLYPH_RADIUS, "normal": normal}

func can_accept_chakram(chakram: Chakram) -> bool:
	if chakram == null:
		return false
	return float(chakram_hit_cooldowns.get(chakram.get_instance_id(), 0.0)) <= 0.0

func on_chakram_hit(chakram: Chakram, impact_velocity: Vector2) -> void:
	if not can_accept_chakram(chakram):
		return
	chakram_hit_cooldowns[chakram.get_instance_id()] = CHAKRAM_REHIT_COOLDOWN
	pulse_left = PULSE_VISUAL_DURATION
	pulse_radius = 28.0
	var main_scene: Node = get_tree().current_scene
	if main_scene != null and main_scene.has_method("play_sfx"):
		main_scene.play_sfx("glyph_bell", 0.85, 1.0 + clampf(impact_velocity.length() / 2400.0, 0.0, 0.12))
	var pulse_range: float = BonusConfig.resonant_glyph_pulse_radius(rank_value)
	var pulse_damage: float = BonusConfig.resonant_glyph_pulse_damage(rank_value)
	var slow_multiplier: float = BonusConfig.resonant_glyph_slow_multiplier(rank_value)
	var slow_duration: float = BonusConfig.resonant_glyph_slow_duration(rank_value)
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) > pulse_range:
			continue
		var push_direction: Vector2 = global_position.direction_to(enemy.global_position)
		if push_direction == Vector2.ZERO:
			push_direction = Vector2.RIGHT
		enemy.apply_timed_movement_modifier(get_instance_id(), slow_multiplier, slow_duration)
		enemy.take_damage(pulse_damage, push_direction * 80.0, 0.12, 0.25)
		if owner_player != null:
			owner_player.notify_player_damage_dealt(false)
		if main_scene != null and main_scene.has_method("spawn_enemy_hit_presentation"):
			main_scene.spawn_enemy_hit_presentation(enemy, enemy.global_position, push_direction * 80.0, push_direction, 0.25, enemy.health <= 0.0, false)
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	lifetime_left -= delta
	pulse_left = maxf(0.0, pulse_left - delta)
	if pulse_left > 0.0:
		pulse_radius = move_toward(pulse_radius, BonusConfig.resonant_glyph_pulse_radius(rank_value), delta * 520.0)
	for chakram_id: int in chakram_hit_cooldowns.keys():
		chakram_hit_cooldowns[chakram_id] = maxf(0.0, float(chakram_hit_cooldowns[chakram_id]) - delta)
		if chakram_hit_cooldowns[chakram_id] <= 0.0:
			chakram_hit_cooldowns.erase(chakram_id)
	if lifetime_left <= 0.0:
		queue_free()
		return
	queue_redraw()

func _glyph_points(angle: float, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(6):
		points.append(Vector2.from_angle(angle + float(point_index) * TAU / 6.0) * radius)
	points.append(points[0])
	return points

func _draw_glyph_shape(angle: float, scale_value: float, color: Color) -> void:
	var outer: PackedVector2Array = _glyph_points(angle, GLYPH_RADIUS * scale_value)
	var inner: PackedVector2Array = _glyph_points(-angle * 0.7, GLYPH_RADIUS * 0.58 * scale_value)
	draw_polyline(outer, color, 3.0, true)
	draw_polyline(inner, Color(color.r, color.g, color.b, color.a * 0.72), 2.0, true)
	draw_circle(Vector2.ZERO, 8.0 * scale_value, Color(0.25, 0.75, 1.0, color.a * 0.34))
	var spoke_end: Vector2 = Vector2.from_angle(angle) * GLYPH_RADIUS * 0.82 * scale_value
	draw_line(-spoke_end, spoke_end, color, 1.5, true)

func _draw() -> void:
	var rotation_phase: float = animation_time * 1.35
	var pulse: float = (sin(animation_time * 4.0) + 1.0) * 0.5
	for afterimage_index: int in range(AFTERIMAGE_COUNT, 0, -1):
		var afterimage_alpha: float = 0.10 + 0.04 * float(AFTERIMAGE_COUNT - afterimage_index)
		_draw_glyph_shape(rotation_phase - float(afterimage_index) * 0.20, 1.0 + pulse * 0.04, Color(0.9, 0.97, 1.0, afterimage_alpha))
	_draw_glyph_shape(rotation_phase, 1.0 + pulse * 0.08, Color(0.18, 0.68, 1.0, 0.92))
	draw_circle(Vector2.ZERO, 5.0 + pulse * 2.0, Color(0.9, 0.98, 1.0, 0.92))
	if pulse_left > 0.0:
		var wave_alpha: float = clampf(pulse_left / PULSE_VISUAL_DURATION, 0.0, 1.0)
		draw_circle(Vector2.ZERO, pulse_radius, Color(0.35, 0.82, 1.0, wave_alpha * 0.08))
		draw_arc(Vector2.ZERO, pulse_radius, 0.0, TAU, 48, Color(0.9, 0.98, 1.0, wave_alpha * 0.9), 4.0, true)
		draw_arc(Vector2.ZERO, pulse_radius * 0.72, 0.0, TAU, 40, Color(0.25, 0.7, 1.0, wave_alpha * 0.7), 2.0, true)
