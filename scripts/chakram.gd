class_name Chakram extends Area2D

var chakram_texture_hd: Texture2D = null

@export var flight_duration: float = 5.0
@export var base_speed: float = 360.0
@export var boosted_speed: float = 540.0
@export var damage: float = 30.0
## Continuous visual spin in radians per second. The travel-direction marker is
## drawn independently, so it remains aligned with velocity while the art spins.
@export var spin_speed: float = 14.0

@export_category("Chakram Feel")
@export var magnetic_seek_radius: float = 230.0
## Magnetic turning speed by rank is centralized in res://scripts/bonus_config.gd.

@export_category("Player Sword Interaction")
## Delay after throwing before the player's sword can bat this Chakram.
## This does not disable Chakram-to-enemy hits.
@export var sword_launch_grace_duration: float = 0.7
## Minimum delay after a successful bat before the player's sword can bat it again.
@export var sword_rehit_cooldown_duration: float = 0.3

@export_category("Grapple Interaction")
## Same one-time flight extension a successful sword bat grants.
@export var grapple_flight_extension: float = 5.0

@export_category("Enemy Contact")
## Radius used by swept Chakram-to-enemy collision checks.
@export var enemy_hit_radius: float = 28.0

var velocity: Vector2 = Vector2.ZERO
var time_left: float = 5.0
var grounded: bool = false
var boosted: bool = false
var sword_launch_grace: float = 0.0
var sword_cooldown: float = 0.0
var sword_contact_latched: bool = false
var grapple_attached: bool = false
# Grapple Yo-yo constraint data is authored by GrappleController each frame and
# consumed here immediately before movement, so the Chakram cannot tunnel past
# the radial limit between controller and projectile physics ticks.
var yoyo_constraint_active: bool = false
var yoyo_pivot: Vector2 = Vector2.ZERO
var yoyo_local_rope_length: float = 0.0
var yoyo_soft_zone: float = 0.0
var yoyo_radial_damping: float = 0.0
var yoyo_tangential_drag: float = 0.0
var yoyo_last_constraint_correction: float = 0.0
var yoyo_last_enemy_hit_frame: int = -1
var yoyo_last_enemy_hit_incoming: Vector2 = Vector2.ZERO
var yoyo_last_enemy_hit_outgoing: Vector2 = Vector2.ZERO
var yoyo_coil_contact_enemy_id: int = -1
var yoyo_coil_contact_armed: bool = false
## Authoritative gameplay ceiling shared by sword bats and grapple redirection.
var sword_hit_speed_ceiling: float = 900.0
var owner_player: Player = null
var trail_points: Array[Vector2] = []
var hit_enemy_ids: Dictionary[int, bool] = {}
var explosion_armed: bool = false
var explosion_level: int = 0
var explosion_flash: float = 0.0
var explosion_visual_level: int = 0
var pierces_remaining: int = 0
var bat_stretch_left: float = 0.0
var bat_stretch_duration: float = 0.0
var bat_stretch_amount: float = 0.0
var bat_stretch_direction: Vector2 = Vector2.RIGHT
var spin_angle: float = 0.0

func _ready() -> void:
	# Steel Chakram is the only Chakram-slot item today; a future per-item
	# table (mirroring player.gd's ARMOR_VISUALS) can key this off the
	# equipped item's base name once more Chakram variants exist.
	chakram_texture_hd = load("res://assets/generated/steel_chakram_hd_frame_0.png") as Texture2D
	z_as_relative = false
	z_index = 2
	queue_redraw()

func launch(direction: Vector2, player: Player) -> void:
	owner_player = player
	sword_hit_speed_ceiling = maxf(0.0, player.max_chakram_bat_speed)
	velocity = direction.normalized() * base_speed
	time_left = flight_duration
	sword_launch_grace = sword_launch_grace_duration
	grounded = false
	boosted = false
	explosion_armed = false
	explosion_level = 0
	explosion_flash = 0.0
	grapple_attached = false
	clear_yoyo_constraint()
	pierces_remaining = player.chakram_pierce
	hit_enemy_ids.clear()
	queue_redraw()

static func updated_flight_time(current_time: float, delta: float, is_grapple_attached: bool) -> float:
	return current_time if is_grapple_attached else current_time - maxf(delta, 0.0)

static func yoyo_constrained_velocity(moving_position: Vector2, current_velocity: Vector2, pivot: Vector2, maximum_length: float, soft_zone: float, radial_damping: float, tangential_drag: float, delta: float) -> Vector2:
	var offset: Vector2 = moving_position - pivot
	var distance: float = offset.length()
	if distance <= 0.001 or maximum_length <= 0.001:
		return current_velocity
	var radial_direction: Vector2 = offset / distance
	var radial_speed: float = current_velocity.dot(radial_direction)
	var tangential_velocity: Vector2 = current_velocity - radial_direction * radial_speed
	var clean_soft_zone: float = maxf(0.0, soft_zone)
	var zone_start: float = maxf(0.0, maximum_length - clean_soft_zone)
	var zone_ratio: float = 1.0 if clean_soft_zone <= 0.001 else clampf((distance - zone_start) / clean_soft_zone, 0.0, 1.0)
	if radial_speed > 0.0 and zone_ratio > 0.0:
		# Ease off outward energy before the hard limit, avoiding a rubber-band
		# reversal. At full extension no outward radial velocity survives.
		radial_speed *= exp(-maxf(0.0, radial_damping) * zone_ratio * zone_ratio * maxf(0.0, delta))
		if distance >= maximum_length:
			radial_speed = 0.0
	if distance >= maximum_length - 1.0:
		tangential_velocity *= exp(-maxf(0.0, tangential_drag) * maxf(0.0, delta))
	return radial_direction * radial_speed + tangential_velocity

func configure_yoyo_constraint(pivot: Vector2, local_rope_length: float, soft_zone: float, radial_damping: float, tangential_drag: float, coil_enemy_id: int = -1, coil_contact_armed: bool = false) -> void:
	yoyo_constraint_active = true
	yoyo_coil_contact_enemy_id = coil_enemy_id
	yoyo_coil_contact_armed = coil_contact_armed
	yoyo_pivot = pivot
	yoyo_local_rope_length = maxf(1.0, local_rope_length)
	yoyo_soft_zone = maxf(0.0, soft_zone)
	yoyo_radial_damping = maxf(0.0, radial_damping)
	yoyo_tangential_drag = maxf(0.0, tangential_drag)

func clear_yoyo_constraint() -> void:
	yoyo_constraint_active = false
	yoyo_coil_contact_enemy_id = -1
	yoyo_coil_contact_armed = false

func _apply_yoyo_constraint(delta: float) -> void:
	yoyo_last_constraint_correction = 0.0
	if not yoyo_constraint_active:
		return
	var offset: Vector2 = global_position - yoyo_pivot
	var distance: float = offset.length()
	if distance > yoyo_local_rope_length and distance > 0.001:
		yoyo_last_constraint_correction = distance - yoyo_local_rope_length
		global_position = yoyo_pivot + offset / distance * yoyo_local_rope_length
	velocity = yoyo_constrained_velocity(global_position, velocity, yoyo_pivot, yoyo_local_rope_length, yoyo_soft_zone, yoyo_radial_damping, yoyo_tangential_drag, delta)
	velocity = velocity.limit_length(sword_hit_speed_ceiling)

func _physics_process(delta: float) -> void:
	if grounded:
		# A landed Chakram keeps its final authored orientation instead of
		# continuing to rotate while it waits to be collected.
		if owner_player != null and global_position.distance_to(owner_player.global_position) < 30.0: owner_player.collect_chakram(self)
		queue_redraw()
		return
	spin_angle = fmod(spin_angle + spin_speed * delta, TAU)
	sword_cooldown = maxf(0.0, sword_cooldown - delta)
	bat_stretch_left = maxf(0.0, bat_stretch_left - delta)
	explosion_flash = maxf(0.0, explosion_flash - delta)
	if owner_player != null and owner_player.magnetic_level > 0:
		var nearest_enemy: Node2D = null
		var nearest_distance: float = magnetic_seek_radius
		for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
			var candidate: Node2D = enemy_node as Node2D
			if candidate != null:
				var candidate_distance: float = global_position.distance_to(candidate.global_position)
				if candidate_distance < nearest_distance:
					nearest_distance = candidate_distance
					nearest_enemy = candidate
		if nearest_enemy != null and velocity.length_squared() > 0.01:
			var seek_direction: Vector2 = global_position.direction_to(nearest_enemy.global_position)
			var current_direction: Vector2 = velocity.normalized()
			var turn_rate: float = BonusConfig.magnetic_turn_rate(owner_player.magnetic_level)
			var turn_angle: float = clampf(current_direction.angle_to(seek_direction), -turn_rate * delta, turn_rate * delta)
			var preserved_speed: float = maxf(velocity.length(), base_speed)
			velocity = current_direction.rotated(turn_angle) * preserved_speed
	sword_launch_grace = maxf(0.0, sword_launch_grace - delta)
	# Include rope-constraint correction in the same swept collision path as
	# ordinary movement. Otherwise a hard correction can place the Chakram
	# through a wall before terrain collision gets a chance to respond.
	var previous_position: Vector2 = global_position
	_apply_yoyo_constraint(delta)
	var proposed_position: Vector2 = global_position + velocity * delta
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("get_resonant_glyph_hit"):
		var glyph_hit: Dictionary = main_scene.get_resonant_glyph_hit(previous_position, proposed_position, enemy_hit_radius, self)
		if not glyph_hit.is_empty():
			var glyph: ResonantGlyph = glyph_hit["glyph"] as ResonantGlyph
			var glyph_normal: Vector2 = glyph_hit["normal"] as Vector2
			global_position = (glyph_hit["position"] as Vector2) + glyph_normal * 2.0
			velocity = velocity.bounce(glyph_normal)
			if glyph != null:
				glyph.on_chakram_hit(self, velocity)
			if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 0.8)
			queue_redraw()
			return
	if main_scene.has_method("get_terrain_obstruction_hit"): 
		var obstruction_hit: Dictionary = main_scene.get_terrain_obstruction_hit(previous_position, proposed_position, 15.0)
		if not obstruction_hit.is_empty():
			var obstruction: ArenaObject = obstruction_hit.get("object") as ArenaObject
			if obstruction != null:
				obstruction.hit_by_chakram(damage, velocity)
				var rebound: Vector2 = obstruction.global_position.direction_to(previous_position)
				if rebound == Vector2.ZERO: rebound = -velocity.normalized()
				global_position = previous_position + rebound * 3.0
				velocity = velocity.bounce(rebound.normalized())
				if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 0.8)
				queue_redraw()
				return
	if main_scene.has_method("get_terrain_wall_collision"): 
		var wall_hit: Dictionary = main_scene.get_terrain_wall_collision(previous_position, proposed_position, 15.0)
		if not wall_hit.is_empty():
			var wall_normal: Vector2 = wall_hit["normal"] as Vector2
			global_position = (wall_hit["position"] as Vector2) + wall_normal * 2.0
			velocity = velocity.bounce(wall_normal)
			if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 0.45)
		else:
			global_position = proposed_position
	else:
		global_position = proposed_position
	trail_points.push_front(global_position)
	if trail_points.size() > 14: trail_points.pop_back()
	time_left = updated_flight_time(time_left, delta, grapple_attached)
	if owner_player != null and global_position.distance_to(owner_player.global_position) < 28.0:
		owner_player.collect_chakram(self)
		return
	# Enemy contact is active immediately and uses the full traveled segment to prevent tunneling.
	_hit_enemies(previous_position, global_position)
	var arena_rect: Rect2 = GameplayBounds.arena_rect(get_tree().current_scene)
	var minimum_x: float = arena_rect.position.x + 18.0
	var minimum_y: float = arena_rect.position.y + 18.0
	var maximum_x: float = arena_rect.end.x - 18.0
	var maximum_y: float = arena_rect.end.y - 18.0
	if global_position.x < minimum_x:
		global_position.x = minimum_x
		velocity.x = absf(velocity.x)
	elif global_position.x > maximum_x:
		global_position.x = maximum_x
		velocity.x = -absf(velocity.x)
	if global_position.y < minimum_y:
		global_position.y = minimum_y
		velocity.y = absf(velocity.y)
	elif global_position.y > maximum_y:
		global_position.y = maximum_y
		velocity.y = -absf(velocity.y)
	if time_left <= 0.0:
		grounded = true
		velocity = Vector2.ZERO
		boosted = false
		trail_points.clear()
	queue_redraw()

func _chakram_collision_radius() -> float:
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		var shape_scale: Vector2 = shape_node.global_transform.get_scale().abs()
		return (shape_node.shape as CircleShape2D).radius * maxf(shape_scale.x, shape_scale.y)
	return enemy_hit_radius

static func swept_circle_contact(start: Vector2, end: Vector2, center: Vector2, combined_radius: float) -> bool:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	var closest: Vector2 = start
	if length_squared > 0.001:
		var along: float = clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
		closest = start + segment * along
	return closest.distance_squared_to(center) <= combined_radius * combined_radius

static func swept_circle_entry(start: Vector2, end: Vector2, center: Vector2, radius: float) -> Vector2:
	var offset: Vector2 = start - center
	var direction: Vector2 = end - start
	var a: float = direction.length_squared()
	var c: float = offset.length_squared() - radius * radius
	if c <= 0.0 or a < 0.00001:
		var normal: Vector2 = offset.normalized() if offset.length_squared() > 0.00001 else -direction.normalized()
		if normal == Vector2.ZERO:
			normal = Vector2.RIGHT
		return center + normal * radius
	var b: float = offset.dot(direction)
	var discriminant: float = b * b - a * c
	if discriminant < 0.0:
		return end
	return start + direction * clampf((-b - sqrt(discriminant)) / a, 0.0, 1.0)

func _hit_enemies(travel_start: Vector2, travel_end: Vector2) -> void:
	var grapple_controller: GrappleController = owner_player.get_node_or_null("GrappleController") as GrappleController if owner_player != null else null
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not is_instance_valid(enemy): continue
		var collision_circle: Dictionary = GrappleController.enemy_collision_circle(enemy)
		var enemy_center: Vector2 = collision_circle.get("center", enemy.global_position) as Vector2
		var enemy_radius: float = collision_circle.get("radius", enemy_hit_radius) as float
		if not swept_circle_contact(travel_start, travel_end, enemy_center, enemy_radius + _chakram_collision_radius()): continue
		var enemy_id: int = enemy.get_instance_id()
		var is_active_coil: bool = grapple_controller != null and grapple_controller.is_yoyo_coiling_enemy(enemy)
		# Damage suppression is not permission for the wrapped body to become
		# intangible. Resolve its swept boundary even before/after the earned hit.
		if is_active_coil:
			var contact: Vector2 = swept_circle_entry(travel_start, travel_end, enemy_center, enemy_radius + _chakram_collision_radius())
			var normal: Vector2 = enemy_center.direction_to(contact)
			global_position = enemy_center + normal * (enemy_radius + _chakram_collision_radius() + 0.01)
			if velocity.dot(normal) < 0.0:
				velocity = velocity.bounce(normal)
		if is_active_coil and (not yoyo_coil_contact_armed or yoyo_coil_contact_enemy_id != enemy_id):
			continue
		if hit_enemy_ids.has(enemy_id) and not is_active_coil:
			continue
		if is_active_coil:
			yoyo_coil_contact_armed = false
			grapple_controller.notify_yoyo_coil_hit(enemy)
		var incoming_velocity: Vector2 = velocity
		var away: Vector2 = enemy_center.direction_to(global_position)
		if enemy.has_method("chakram_blocked_from_front") and enemy.chakram_blocked_from_front(global_position):
			velocity = velocity.bounce(away).normalized() * velocity.length()
			hit_enemy_ids[enemy_id] = true
			continue
		if enemy.has_method("chakram_hit_from_behind"):
			enemy.chakram_hit_from_behind(velocity.normalized())
		if pierces_remaining > 0:
			pierces_remaining -= 1
		elif not is_active_coil:
			velocity = velocity.bounce(away).normalized() * velocity.length()
		yoyo_last_enemy_hit_frame = Engine.get_physics_frames()
		yoyo_last_enemy_hit_incoming = incoming_velocity
		yoyo_last_enemy_hit_outgoing = velocity
		hit_enemy_ids[enemy_id] = true
		if enemy.has_method("take_damage"):
			if owner_player != null and owner_player.voltage_enabled and enemy.has_method("apply_voltage") and randf() < BonusConfig.voltage_chance(owner_player.voltage_rank): enemy.apply_voltage(owner_player.voltage_rank)
			var speed_bonus: float = clampf(incoming_velocity.length() / 900.0 * 0.25, 0.0, 0.25)
			var dealt_damage: float = damage * (1.0 + speed_bonus)
			var chakram_quality: float = clampf((incoming_velocity.length() - base_speed) / maxf(1.0, 900.0 - base_speed), 0.0, 1.0)
			enemy.take_damage(dealt_damage, away * 180.0, 0.18, chakram_quality)
			if owner_player != null: owner_player.notify_player_damage_dealt(false)
			var typed_enemy: Enemy = enemy as Enemy
			var main_scene: Node = get_tree().current_scene
			if typed_enemy != null and main_scene != null and main_scene.has_method("spawn_enemy_hit_presentation"):
				main_scene.spawn_enemy_hit_presentation(typed_enemy, global_position, incoming_velocity, incoming_velocity.normalized(), chakram_quality, typed_enemy.health <= 0.0, false)
		if owner_player != null: owner_player.gain_flow(6.0)
		if explosion_armed:
			explosion_armed = false
			explosion_flash = 0.3
			explosion_visual_level = explosion_level
			var explosion_radius: float = BonusConfig.explosion_radius(explosion_level)
			var explosion_damage: float = damage * BonusConfig.explosion_damage_multiplier(explosion_level)
			for nearby_node: Node in get_tree().get_nodes_in_group("enemies"):
				var nearby: Node2D = nearby_node as Node2D
				if nearby != null and nearby != enemy and global_position.distance_to(nearby.global_position) < explosion_radius and nearby.has_method("take_damage"):
					nearby.take_damage(explosion_damage, away * (120.0 + float(explosion_level) * 35.0))
					if owner_player != null: owner_player.notify_player_damage_dealt(false)

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001: return point.distance_to(start)
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * factor)

func hit_by_player_sword(hit_position: Vector2, swing_velocity: Vector2 = Vector2.ZERO, sword_weight: float = 0.8, inherited_weight: float = 0.2, minimum_speed: float = 380.0, maximum_speed: float = 900.0) -> bool:
	if grounded or sword_launch_grace > 0.0 or sword_cooldown > 0.0 or sword_contact_latched: return false
	sword_contact_latched = true
	var swing_direction: Vector2 = swing_velocity.normalized()
	if swing_direction == Vector2.ZERO: swing_direction = global_position.direction_to(hit_position)
	var inherited_direction: Vector2 = velocity.normalized()
	var blended_direction: Vector2 = (swing_direction * sword_weight + inherited_direction * inherited_weight).normalized()
	sword_hit_speed_ceiling = maxf(0.0, maximum_speed)
	var swing_speed: float = clampf(swing_velocity.length(), minimum_speed, sword_hit_speed_ceiling)
	velocity = blended_direction * swing_speed
	boosted = true
	if owner_player != null:
		owner_player.gain_flow(4.0)
		if owner_player.chakram_explosion_level > 0:
			explosion_armed = true
			explosion_level = owner_player.chakram_explosion_level
	time_left += 5.0
	sword_cooldown = sword_rehit_cooldown_duration
	queue_redraw()
	return true

func play_bat_stretch(launch_direction: Vector2, duration: float, stretch_amount: float) -> void:
	bat_stretch_direction = launch_direction.normalized() if launch_direction.length_squared() > 0.001 else velocity.normalized()
	if bat_stretch_direction == Vector2.ZERO: bat_stretch_direction = Vector2.RIGHT
	bat_stretch_duration = maxf(duration, 0.001)
	bat_stretch_left = bat_stretch_duration
	bat_stretch_amount = maxf(0.0, stretch_amount)
	queue_redraw()

func _bat_draw_transform() -> Transform2D:
	if bat_stretch_left <= 0.0: return Transform2D.IDENTITY
	var life_ratio: float = clampf(bat_stretch_left / maxf(bat_stretch_duration, 0.001), 0.0, 1.0)
	var amount: float = bat_stretch_amount * life_ratio * life_ratio
	var launch_axis: Vector2 = bat_stretch_direction
	var perpendicular_axis: Vector2 = launch_axis.orthogonal()
	var launch_scale: float = 1.0 + amount
	var perpendicular_scale: float = 1.0 - amount * 0.35
	var x_axis: Vector2 = launch_axis * (launch_scale * launch_axis.x) + perpendicular_axis * (perpendicular_scale * perpendicular_axis.x)
	var y_axis: Vector2 = launch_axis * (launch_scale * launch_axis.y) + perpendicular_axis * (perpendicular_scale * perpendicular_axis.y)
	return Transform2D(x_axis, y_axis, Vector2.ZERO)

func on_grapple_attached() -> void:
	if grounded or grapple_attached:
		return
	grapple_attached = true
	time_left += grapple_flight_extension

func on_grapple_detached() -> void:
	grapple_attached = false
	clear_yoyo_constraint()

func apply_grapple_force(acceleration: Vector2, delta: float) -> void:
	if grounded:
		return
	# Lasso physics remains additive, but can never exceed the same maximum speed
	# accepted from a sword bat. This prevents stacked tension/yank rocket spikes.
	velocity += acceleration * maxf(delta, 0.0)
	velocity = velocity.limit_length(sword_hit_speed_ceiling)

func release_sword_contact() -> void:
	sword_contact_latched = false

func collect() -> void:
	queue_free()

func _draw() -> void:
	var bat_transform: Transform2D = _bat_draw_transform()
	draw_set_transform_matrix(bat_transform)
	if explosion_flash > 0.0:
		var fire_progress: float = 1.0 - explosion_flash / 0.3
		var fire_radius: float = BonusConfig.explosion_radius(explosion_visual_level) * (0.75 + fire_progress * 0.35)
		var fire_alpha: float = explosion_flash / 0.3
		draw_circle(Vector2.ZERO, fire_radius, Color(1.0, 0.12, 0.02, fire_alpha * 0.28))
		draw_arc(Vector2.ZERO, fire_radius, 0.0, TAU, 40, Color(1.0, 0.35, 0.05, fire_alpha * 0.95), 6.0, true)
		draw_circle(Vector2.ZERO, fire_radius * 0.55, Color(1.0, 0.75, 0.12, fire_alpha * 0.42))
	var pulse: float = (sin(Time.get_ticks_msec() * 0.012) + 1.0) * 0.5
	var glow_radius: float = 25.0 if boosted else 20.0
	var glow_color: Color = Color(1.0, 0.75, 0.05, 0.18 if boosted else 0.10)
	draw_circle(Vector2.ZERO, glow_radius + pulse * 5.0, glow_color)
	if boosted:
		var travel_direction: Vector2 = velocity.normalized()
		draw_line(-travel_direction * 34.0, travel_direction * 34.0, Color(1.0, 0.95, 0.45, 0.55), 2.0, true)
		draw_circle(Vector2.ZERO, 22.0 + (8.0 if explosion_armed else 0.0), Color(1.0, 0.9, 0.12, 0.28))
		if explosion_armed: draw_arc(Vector2.ZERO, 32.0, 0.0, TAU, 28, Color(1.0, 0.35, 0.05, 0.8), 3.0, true)
		draw_circle(Vector2.ZERO, 22.0 + pulse * 3.0, Color(1.0, 0.9, 0.12, 0.28))
		for index: int in range(trail_points.size() - 1):
			var first: Vector2 = trail_points[index] - global_position
			var second: Vector2 = trail_points[index + 1] - global_position
			var alpha: float = 0.5 * (1.0 - float(index) / float(trail_points.size()))
			draw_line(first, second, Color(1.0, 0.75, 0.05, alpha), 7.0 - float(index) * 0.35, true)
	if owner_player != null and owner_player.visual_style == "hd":
		var wood_modulate: Color = Color(1.0, 1.0, 1.0, 1.0) if not grounded else Color(0.62, 0.62, 0.62, 1.0)
		if chakram_texture_hd != null:
			# Spin only the art. The boosted travel-direction marker above was
			# already drawn in the velocity frame and stays stable.
			draw_set_transform_matrix(bat_transform * Transform2D(spin_angle, Vector2.ZERO))
			draw_texture_rect(chakram_texture_hd, Rect2(-17.0, -17.0, 34.0, 34.0), false, wood_modulate)
			draw_set_transform_matrix(bat_transform)
	else:
		var ring_color: Color = Color("f2c14e") if not grounded else Color("777777")
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 28, ring_color, 5.0, true)
		draw_circle(Vector2.ZERO, 5.0, Color("423344"))
		# A rotating highlight makes the spin readable even for the symmetric
		# procedural fallback ring.
		draw_arc(Vector2.ZERO, 15.0, spin_angle - 0.28, spin_angle + 0.28, 6, Color("fff0a3"), 2.0, true)
