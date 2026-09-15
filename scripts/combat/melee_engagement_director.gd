class_name MeleeEngagementDirector extends Node2D

## Coordinates melee intent without changing collision or damage legality.
## Bugs and boss AI are deliberately outside this system.
@export_category("Melee Engagement Limits")
## Enemies allowed to occupy the close-pressure layer at once.
@export var maximum_pressure_slots: int = 2
## Pressure enemies allowed to intentionally commit an attack at once.
@export var maximum_attack_commitments: int = 1
## Seconds before a pressure role rotates when additional enemies are waiting.
@export var pressure_lease_duration: float = 4.0
## Brief rest before the same enemy can reclaim a pressure role.
@export var pressure_rest_duration: float = 1.2
## Seconds one enemy owns intentional attack permission before rotation.
@export var attack_lease_duration: float = 2.4
## Brief rest before the same enemy can reclaim attack permission.
@export var attack_rest_duration: float = 0.8

@export_category("Engagement Spacing")
## Preferred radius for the second, supporting pressure enemy.
@export var pressure_ring_radius: float = 118.0
## Preferred radius for melee enemies waiting outside the fight.
@export var outer_ring_radius: float = 205.0
## Waiting enemies inside this radius prioritize peeling outward.
@export var peel_radius: float = 155.0
## Slow shared rotation keeps waiting enemies active without producing a queue.
@export var outer_ring_rotation_speed: float = 0.16

@export_category("Engagement Debug")
@export var debug_draw_engagement: bool = false

var player_ref: Player = null
var pressure_holders: Array[int] = []
var pressure_lease_left: Dictionary[int, float] = {}
var pressure_rest_left: Dictionary[int, float] = {}
var attack_holders: Array[int] = []
var attack_lease_left: Dictionary[int, float] = {}
var attack_rest_left: Dictionary[int, float] = {}
var orbit_time: float = 0.0
var refresh_left: float = 0.0
var known_candidates: Array[Enemy] = []

func _ready() -> void:
	add_to_group("melee_engagement_director")
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty(): player_ref = players[0] as Player
	queue_redraw()

func _process(delta: float) -> void:
	orbit_time += delta
	_tick_dictionary(pressure_lease_left, delta)
	_tick_dictionary(pressure_rest_left, delta)
	_tick_dictionary(attack_lease_left, delta)
	_tick_dictionary(attack_rest_left, delta)
	refresh_left = maxf(0.0, refresh_left - delta)
	if refresh_left <= 0.0:
		refresh_left = 0.12
		_refresh_assignments()
	if debug_draw_engagement: queue_redraw()

func _tick_dictionary(timers: Dictionary[int, float], delta: float) -> void:
	for enemy_id: int in timers.keys():
		var remaining: float = maxf(0.0, timers[enemy_id] - delta)
		if remaining <= 0.0: timers.erase(enemy_id)
		else: timers[enemy_id] = remaining

func _candidate_enemies() -> Array[Enemy]:
	var candidates: Array[Enemy] = []
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy == null or not is_instance_valid(enemy): continue
		if not enemy._uses_melee_engagement(): continue
		if enemy.death_emitted or enemy.health <= 0.0: continue
		candidates.append(enemy)
	return candidates

func _enemy_by_id(enemy_id: int, candidates: Array[Enemy]) -> Enemy:
	for enemy: Enemy in candidates:
		if enemy.get_instance_id() == enemy_id: return enemy
	return null

func _eligible_for_new_role(enemy: Enemy) -> bool:
	return enemy.stun_left <= 0.0 and enemy.health > 0.0 and not enemy.death_emitted

func _release_pressure(enemy_id: int) -> void:
	pressure_holders.erase(enemy_id)
	pressure_lease_left.erase(enemy_id)
	pressure_rest_left[enemy_id] = pressure_rest_duration
	_release_attack(enemy_id)

func _release_attack(enemy_id: int) -> void:
	attack_holders.erase(enemy_id)
	attack_lease_left.erase(enemy_id)
	attack_rest_left[enemy_id] = attack_rest_duration

func _refresh_assignments(candidate_override: Array[Enemy] = []) -> void:
	refresh_left = maxf(refresh_left, 0.12)
	var candidates: Array[Enemy] = candidate_override if not candidate_override.is_empty() else _candidate_enemies()
	known_candidates = candidates.duplicate()
	for holder_id: int in pressure_holders.duplicate():
		var holder: Enemy = _enemy_by_id(holder_id, candidates)
		if holder == null or not _eligible_for_new_role(holder):
			_release_pressure(holder_id)
		elif candidates.size() > maximum_pressure_slots and not pressure_lease_left.has(holder_id) and not holder.engagement_attack_in_progress():
			_release_pressure(holder_id)
	for holder_id: int in attack_holders.duplicate():
		var holder: Enemy = _enemy_by_id(holder_id, candidates)
		if holder == null or not pressure_holders.has(holder_id) or not _eligible_for_new_role(holder):
			_release_attack(holder_id)
		elif not attack_lease_left.has(holder_id) and not holder.engagement_attack_in_progress():
			_release_attack(holder_id)
	_fill_pressure_slots(candidates)
	_fill_attack_slots(candidates)

func _fill_pressure_slots(candidates: Array[Enemy]) -> void:
	while pressure_holders.size() < maximum_pressure_slots:
		var best_enemy: Enemy = null
		var best_distance: float = INF
		for enemy: Enemy in candidates:
			var enemy_id: int = enemy.get_instance_id()
			if pressure_holders.has(enemy_id) or pressure_rest_left.has(enemy_id) or not _eligible_for_new_role(enemy): continue
			var distance: float = enemy.global_position.distance_to(player_ref.global_position) if player_ref != null else 0.0
			if distance < best_distance:
				best_distance = distance
				best_enemy = enemy
		if best_enemy == null:
			# Never leave slots empty solely because every candidate is resting.
			for enemy: Enemy in candidates:
				var enemy_id: int = enemy.get_instance_id()
				if not pressure_holders.has(enemy_id) and _eligible_for_new_role(enemy):
					best_enemy = enemy
					break
		if best_enemy == null: break
		var best_id: int = best_enemy.get_instance_id()
		pressure_holders.append(best_id)
		pressure_lease_left[best_id] = pressure_lease_duration
		pressure_rest_left.erase(best_id)

func _fill_attack_slots(candidates: Array[Enemy]) -> void:
	while attack_holders.size() < maximum_attack_commitments:
		var best_enemy: Enemy = null
		var best_distance: float = INF
		for holder_id: int in pressure_holders:
			var enemy: Enemy = _enemy_by_id(holder_id, candidates)
			if enemy == null or attack_holders.has(holder_id) or attack_rest_left.has(holder_id) or not _eligible_for_new_role(enemy): continue
			var distance: float = enemy.global_position.distance_to(player_ref.global_position) if player_ref != null else 0.0
			if distance < best_distance:
				best_distance = distance
				best_enemy = enemy
		if best_enemy == null:
			for holder_id: int in pressure_holders:
				var enemy: Enemy = _enemy_by_id(holder_id, candidates)
				if enemy != null and not attack_holders.has(holder_id) and _eligible_for_new_role(enemy):
					best_enemy = enemy
					break
		if best_enemy == null: break
		var best_id: int = best_enemy.get_instance_id()
		attack_holders.append(best_id)
		attack_lease_left[best_id] = attack_lease_duration
		attack_rest_left.erase(best_id)

func has_pressure_slot(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy): return false
	if refresh_left <= 0.0: _refresh_assignments()
	return pressure_holders.has(enemy.get_instance_id())

func has_attack_permission(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy): return false
	if refresh_left <= 0.0: _refresh_assignments()
	return attack_holders.has(enemy.get_instance_id())

func waiting_target(enemy: Enemy) -> Vector2:
	if player_ref == null: return enemy.global_position
	var waiting: Array[Enemy] = []
	for candidate: Enemy in known_candidates:
		# An enemy can die between the 0.12-second assignment refreshes.
		if candidate == null or not is_instance_valid(candidate): continue
		if not pressure_holders.has(candidate.get_instance_id()): waiting.append(candidate)
	waiting.sort_custom(func(first: Enemy, second: Enemy) -> bool: return first.get_instance_id() < second.get_instance_id())
	var waiting_index: int = maxi(0, waiting.find(enemy))
	var divisor: float = float(maxi(1, waiting.size()))
	var target_angle: float = TAU * float(waiting_index) / divisor + orbit_time * outer_ring_rotation_speed
	var target: Vector2 = player_ref.global_position + Vector2.RIGHT.rotated(target_angle) * outer_ring_radius
	if is_inside_tree():
		var arena_rect: Rect2 = GameplayBounds.arena_rect(get_tree().current_scene)
		target.x = clampf(target.x, arena_rect.position.x + 48.0, arena_rect.end.x - 48.0)
		target.y = clampf(target.y, arena_rect.position.y + 48.0, arena_rect.end.y - 48.0)
	return target

func _draw() -> void:
	if not debug_draw_engagement or player_ref == null: return
	var player_local: Vector2 = player_ref.global_position - global_position
	draw_arc(player_local, pressure_ring_radius, 0.0, TAU, 64, Color(1.0, 0.65, 0.12, 0.45), 2.0, true)
	draw_arc(player_local, outer_ring_radius, 0.0, TAU, 64, Color(0.25, 0.75, 1.0, 0.35), 2.0, true)
	for enemy: Enemy in _candidate_enemies():
		var color: Color = Color(1.0, 0.25, 0.15, 0.8) if has_attack_permission(enemy) else (Color(1.0, 0.75, 0.18, 0.7) if has_pressure_slot(enemy) else Color(0.25, 0.75, 1.0, 0.55))
		draw_line(player_local, enemy.global_position - global_position, color, 2.0, true)
