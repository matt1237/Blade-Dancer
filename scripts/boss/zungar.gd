class_name Zungar extends Enemy

## Zungar — clean state-machine boss.
## Every attack: TELEGRAPH → ATTACK → RECOVERY → CHASE.
## His persistent Executioner Sword uses the same weapon segment and parry
## infrastructure as other combatants, with a deliberately slow metronome.
enum State { INTRO, CHASE, CHARGE_WINDUP, CHARGING, JUMP_WINDUP, JUMP_TRAVEL, FIRE_STOMP, SPEAR, TREE_THROW, STUNNED, SUMMONING, RECOVERY, DEAD }

var state: State = State.INTRO
var state_left: float = 0.0
var attack_cooldown: float = 2.0
var spear_timer: float = 0.0
var jump_target: Vector2 = Vector2.ZERO
var jump_origin: Vector2 = Vector2.ZERO
var jump_marker_left: float = 0.0
var executioner_sword_hit_cooldown: float = 0.0
var _metronome_phase: float = 0.0
var fire_stomp_taunt_left: float = 0.0
var stomp_campfire: BossCampfire = null
var thrown_tree: DestructibleTree = null
var aggressive_phase: bool = false
var animation_time: float = 0.0
var fire_reaction_left: float = 0.0
var landing_flash_left: float = 0.0
var intro_complete: bool = false
var last_major_ability: String = ""
var charge_elapsed: float = 0.0
var summon_cooldown_left: float = ZungarConfig.SUMMON_START_DELAY
var summon_issued: bool = false
var friendly_fire_bark_cooldown: float = 0.0
var friendly_fire_hit_ids: Dictionary[int, bool] = {}
var friendly_fire_sword_cooldowns: Dictionary[int, float] = {}
## Training Tools can spawn Zungar as a focused sword/parry test target.
var training_mode: bool = false
var charge_fx: ZungarChargeFX = null

@onready var zungar_visual: ZungarVisual = $VisualRoot

func _boss_damage(base_damage: float) -> float:
	return base_damage * maxf(1.0, wave_stat_multiplier)

func _ready() -> void:
	# Zungar owns boss AI and an executioner sword, but has no Ogre shield capability.
	spawn_identity = &"zungar"
	participates_in_melee_engagement = false
	grapple_weight = GrappleWeight.HEAVY
	shield_enabled = false
	moving_weapon_enabled = true
	parry_enabled = true
	max_health = ZungarConfig.MAX_HEALTH * maxf(1.0, wave_stat_multiplier)
	contact_damage = ZungarConfig.CONTACT_DAMAGE * maxf(1.0, wave_stat_multiplier)
	score_value = ZungarConfig.SCORE_VALUE
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = true
	# Persistent Executioner Sword — same collision/parry infrastructure as the
	# goblin spear, with presentation owned by the dedicated visual component.
	weapon_origin_offset = ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET
	blade_length = ZungarConfig.EXECUTIONER_SWORD_REACH
	zungar_visual.configure_weapon(weapon_origin_offset, blade_length)
	# Keep the boss body scale explicit even when the visual controller swaps its
	# runtime-generated animation atlases; sword-rule identity must not resize him.
	zungar_visual.body_sprite.scale = Vector2.ONE * ZungarConfig.BODY_SCALE
	charge_fx = ZungarChargeFX.new()
	charge_fx.name = "ChargeFX"
	add_child(charge_fx)
	move_child(charge_fx, 0)
	# Apply body collision sizing from config.
	var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if collision_shape != null and collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		capsule.radius = ZungarConfig.BODY_COLLISION_RADIUS
		capsule.height = ZungarConfig.BODY_COLLISION_HEIGHT
	add_to_group("enemies")
	add_to_group("zungar")
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty(): player_ref = players[0] as Player
	state = State.INTRO
	state_left = 2.0
	queue_redraw()

func begin_boss_fight() -> void:
	intro_complete = true
	state = State.CHASE
	state_left = 0.6
	summon_cooldown_left = ZungarConfig.SUMMON_START_DELAY
	if training_mode:
		summon_cooldown_left = INF
		return
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("show_zungar_title"): main_scene.show_zungar_title()

func _physics_process(delta: float) -> void:
	if player_ref == null or state == State.DEAD: return
	animation_time += delta
	state_left = maxf(0.0, state_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	# Custom boss loops must explicitly run the shared moving-weapon lifecycle.
	tick_moving_weapon_combat(delta)
	executioner_sword_hit_cooldown = maxf(0.0, executioner_sword_hit_cooldown - delta)
	fire_reaction_left = maxf(0.0, fire_reaction_left - delta)
	landing_flash_left = maxf(0.0, landing_flash_left - delta)
	jump_marker_left = maxf(0.0, jump_marker_left - delta)
	summon_cooldown_left = maxf(0.0, summon_cooldown_left - delta)
	friendly_fire_bark_cooldown = maxf(0.0, friendly_fire_bark_cooldown - delta)
	_tick_friendly_fire_sword_cooldowns(delta)
	aggressive_phase = health / maxf(max_health, 1.0) <= ZungarConfig.AGGRESSIVE_HEALTH_RATIO
	# The Executioner Sword winds slowly between two readable metronome peaks.
	# A parry/clash locks the blade exactly like a normal Duelist; do not let the
	# boss metronome overwrite that locked angle while he is stunned.
	if stun_left > 0.0:
		blade_angle = locked_blade_angle
	else:
		_metronome_phase += delta * ZungarConfig.EXECUTIONER_SWORD_METRONOME_SPEED * TAU
		var oscillation: float = sin(_metronome_phase) * deg_to_rad(ZungarConfig.EXECUTIONER_SWORD_METRONOME_ARC_DEGREES * 0.5)
		var sword_target: float = global_position.direction_to(player_ref.global_position).angle() + oscillation
		blade_angle = lerp_angle(blade_angle, sword_target, clampf(ParryRules.UNIVERSAL_BLADE_ROTATION_SPEED * delta, 0.0, 1.0))
	_executioner_sword_hit_test()

	match state:
		State.INTRO:
			velocity = Vector2.ZERO
			if state_left <= 0.0: begin_boss_fight()
		State.STUNNED:
			# Match Enemy's normal parry/clash recoil path. Previously Zungar
			# zeroed velocity here, so a successful parry only changed visuals and
			# never physically displaced or impaired him like a goblin Duelist.
			blade_angle = locked_blade_angle
			blade_length = ZungarConfig.EXECUTIONER_SWORD_REACH
			velocity = knockback
			knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
			move_and_slide()
			stun_left = maxf(0.0, stun_left - delta)
			if stun_left <= 0.0:
				state = State.CHASE
				clash_latched = false
				locked_blade_angle = blade_angle
		State.SPEAR:
			_process_spear_mode(delta)
		State.CHARGE_WINDUP:
			velocity = Vector2.ZERO
			if is_instance_valid(charge_fx): charge_fx.emit_charge_trail(global_position - charge_direction * 16.0 + Vector2(0.0, 16.0), charge_direction, delta, ZungarConfig.CHARGE_DIRT_WINDUP_RATE)
			if state_left <= 0.0: _begin_charge()
		State.CHARGING:
			_process_charge(delta)
		State.JUMP_WINDUP:
			velocity = Vector2.ZERO
			if state_left <= 0.0: _begin_jump_travel()
		State.JUMP_TRAVEL:
			_process_jump_travel(delta)
		State.FIRE_STOMP:
			_process_fire_stomp(delta)
		State.TREE_THROW:
			_process_tree_throw()
		State.SUMMONING:
			_process_summoning()
		State.RECOVERY:
			velocity = Vector2.ZERO
			if state_left <= 0.0: state = State.CHASE
		State.CHASE:
			_process_chase(delta)
	_sync_illustrated_presentation()
	queue_redraw()

func _sync_illustrated_presentation() -> void:
	var visual_animation: StringName = &"idle"
	match state:
		State.CHASE:
			visual_animation = &"walk" if velocity.length_squared() > 16.0 else &"idle"
		State.FIRE_STOMP:
			visual_animation = &"walk" if velocity.length_squared() > 16.0 else &"idle"
		State.CHARGE_WINDUP:
			visual_animation = &"charge_windup"
		State.CHARGING:
			visual_animation = &"charge_travel"
		State.JUMP_WINDUP, State.JUMP_TRAVEL:
			visual_animation = &"jump"
		State.STUNNED:
			visual_animation = &"stunned"
		_:
			visual_animation = &"idle"
	var facing_left: bool = player_ref.global_position.x < global_position.x
	var fire_strength: float = fire_reaction_left / maxf(ZungarConfig.FIRE_REACTION_DURATION, 0.001)
	var metronome_peak: float = absf(sin(_metronome_phase))
	zungar_visual.sync_presentation(visual_animation, facing_left, blade_angle, aggressive_phase, fire_strength, metronome_peak)

# =============================================================================
# CHASE
# =============================================================================
func _process_chase(_delta: float) -> void:
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	velocity = direction * ZungarConfig.CHASE_SPEED
	move_and_slide()
	_apply_contact_damage()
	if attack_cooldown > 0.0: return
	var speed_multiplier: float = ZungarConfig.AGGRESSIVE_SPEED_MULTIPLIER if aggressive_phase else 1.0
	if _try_stomp_campfire(): attack_cooldown = ZungarConfig.ABILITY_INTERVAL / speed_multiplier; return
	if _try_tree_throw(): attack_cooldown = ZungarConfig.ABILITY_INTERVAL / speed_multiplier; return
	# A finished summon cooldown is a schedule, not another random lottery.
	# Cast at the next major-ability opportunity whenever an ally slot is vacant;
	# otherwise repeated random misses can make the feature appear broken.
	if summon_cooldown_left <= 0.0 and _living_summon_count() < ZungarConfig.SUMMON_MAX_ALIVE:
		_begin_summoning()
		attack_cooldown = ZungarConfig.ABILITY_INTERVAL / speed_multiplier
		return
	var abilities: Array[String] = ["charge", "jump", "spear"]
	if last_major_ability in abilities and abilities.size() > 1:
		abilities.erase(last_major_ability)
	var chosen_ability: String = abilities[randi_range(0, abilities.size() - 1)]
	match chosen_ability:
		"charge": _begin_charge_windup(speed_multiplier)
		"jump": _begin_jump_windup(speed_multiplier)
		"spear": _begin_spear_mode(speed_multiplier)
	attack_cooldown = ZungarConfig.ABILITY_INTERVAL / speed_multiplier

func _apply_contact_damage() -> void:
	var distance: float = global_position.distance_to(player_ref.global_position)
	var main_scene: Node = get_tree().current_scene
	if distance < ZungarConfig.CONTACT_RANGE and contact_cooldown <= 0.0 and main_scene.has_method("has_terrain_line_of_sight") and main_scene.has_terrain_line_of_sight(global_position, player_ref.global_position, 2.0):
		contact_cooldown = 0.8
		player_ref.take_damage(contact_damage, global_position.direction_to(player_ref.global_position) * ZungarConfig.CONTACT_KNOCKBACK, self)

# =============================================================================
# EXECUTIONER SWORD — persistent, metronoming, dangerous, and parryable.
# =============================================================================
func _executioner_sword_hit_test() -> void:
	_executioner_sword_minion_hit_test()
	if executioner_sword_hit_cooldown > 0.0 or stun_left > 0.0: return
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var sword_start: Vector2 = weapon_segment["start"] as Vector2
	var sword_end: Vector2 = weapon_segment["end"] as Vector2
	var distance_to_sword: float = _point_segment_distance(player_ref.global_position, sword_start, sword_end)
	if distance_to_sword <= ZungarConfig.EXECUTIONER_SWORD_HIT_RADIUS:
		player_ref.take_damage(_boss_damage(ZungarConfig.EXECUTIONER_SWORD_DAMAGE), global_position.direction_to(player_ref.global_position) * ZungarConfig.EXECUTIONER_SWORD_KNOCKBACK, self)
		executioner_sword_hit_cooldown = ZungarConfig.EXECUTIONER_SWORD_HIT_COOLDOWN

func get_blade_direction() -> Vector2:
	return Vector2.RIGHT.rotated(blade_angle)

func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var segment_length_squared: float = segment.length_squared()
	if segment_length_squared <= 0.001: return point.distance_to(start)
	var ratio: float = clampf((point - start).dot(segment) / segment_length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func is_blade_contact(player_start: Vector2, player_end: Vector2, tolerance: float = 7.0) -> bool:
	# Use the exact shared Duelist contact gate, including disarm and clash latch.
	return super.is_blade_contact(player_start, player_end, tolerance)

func is_blade_blocking(start: Vector2, end: Vector2, forgiveness: float = 22.0) -> bool:
	# Use the shared ParryRules gate/tolerance so Zungar behaves like the goblin.
	return super.is_blade_blocking(start, end, forgiveness)

# =============================================================================
# CHARGE
# =============================================================================
func _begin_charge_windup(speed_multiplier: float) -> void:
	state = State.CHARGE_WINDUP
	state_left = ZungarConfig.CHARGE_WINDUP_DURATION / speed_multiplier
	charge_direction = global_position.direction_to(player_ref.global_position)
	if charge_direction.length_squared() <= 0.001: charge_direction = Vector2.DOWN
	charge_elapsed = 0.0
	friendly_fire_hit_ids.clear()
	if is_instance_valid(charge_fx): charge_fx.begin_windup(global_position - charge_direction * 16.0 + Vector2(0.0, 16.0), charge_direction)
	last_major_ability = "charge"

func _begin_charge() -> void:
	charge_distance_left = ZungarConfig.CHARGE_DISTANCE
	charge_elapsed = 0.0
	state = State.CHARGING

func _process_charge(delta: float) -> void:
	charge_elapsed += delta
	var speed_multiplier: float = ZungarConfig.AGGRESSIVE_SPEED_MULTIPLIER if aggressive_phase else 1.0
	var acceleration_progress: float = clampf(charge_elapsed / ZungarConfig.CHARGE_ACCELERATION_DURATION, 0.0, 1.0)
	var acceleration_ratio: float = lerpf(ZungarConfig.CHARGE_START_SPEED_RATIO, 1.0, smoothstep(0.0, 1.0, acceleration_progress))
	var deceleration_progress: float = clampf(charge_distance_left / ZungarConfig.CHARGE_DECELERATION_DISTANCE, 0.0, 1.0)
	var deceleration_ratio: float = lerpf(0.58, 1.0, smoothstep(0.0, 1.0, deceleration_progress))
	var step_distance: float = minf(charge_distance_left, ZungarConfig.CHARGE_SPEED * speed_multiplier * acceleration_ratio * deceleration_ratio * delta)
	var previous_position: Vector2 = global_position
	global_position += charge_direction * step_distance
	charge_distance_left -= step_distance
	if is_instance_valid(charge_fx): charge_fx.emit_charge_trail(global_position - charge_direction * 20.0 + Vector2(0.0, 16.0), charge_direction, delta, ZungarConfig.CHARGE_DIRT_TRAVEL_RATE)
	_damage_summons_near_segment(previous_position, global_position, ZungarConfig.BODY_RADIUS + 24.0, ZungarConfig.FRIENDLY_CHARGE_DAMAGE, ZungarConfig.FRIENDLY_CHARGE_KNOCKBACK)
	if _hit_standing_tree() or _hit_runtime_wall(previous_position, global_position) or _hit_arena_wall():
		_enter_charge_stun()
		return
	if global_position.distance_to(player_ref.global_position) < ZungarConfig.CHARGE_CONTACT_RANGE:
		player_ref.take_damage(_boss_damage(ZungarConfig.CHARGE_DAMAGE), charge_direction * ZungarConfig.CHARGE_KNOCKBACK, self)
		state = State.RECOVERY
		state_left = ZungarConfig.CHARGE_RECOVERY_DURATION
		return
	if charge_distance_left <= 0.0 or previous_position.distance_to(global_position) < 0.01:
		state = State.RECOVERY
		state_left = ZungarConfig.CHARGE_RECOVERY_DURATION

func _hit_standing_tree() -> bool:
	for tree_node: Node in get_tree().get_nodes_in_group("zungar_trees"):
		var tree: DestructibleTree = tree_node as DestructibleTree
		if tree == null or tree.destroyed or tree.being_thrown: continue
		if global_position.distance_to(tree.global_position) <= ZungarConfig.BODY_RADIUS + 34.0:
			tree.break_from_charge()
			return true
	return false

func _hit_runtime_wall(start: Vector2, end: Vector2) -> bool:
	var main_scene: Node = get_tree().current_scene
	if not main_scene.has_method("get_terrain_wall_collision"):
		return false
	var wall_hit: Dictionary = main_scene.get_terrain_wall_collision(start, end, ZungarConfig.BODY_RADIUS)
	if wall_hit.is_empty():
		return false
	global_position = wall_hit["position"] as Vector2
	return true

func _hit_arena_wall() -> bool:
	if global_position.x <= ZungarConfig.ARENA_LEFT or global_position.x >= ZungarConfig.ARENA_RIGHT \
		or global_position.y <= ZungarConfig.ARENA_TOP or global_position.y >= ZungarConfig.ARENA_BOTTOM:
		global_position.x = clampf(global_position.x, ZungarConfig.ARENA_LEFT, ZungarConfig.ARENA_RIGHT)
		global_position.y = clampf(global_position.y, ZungarConfig.ARENA_TOP, ZungarConfig.ARENA_BOTTOM)
		return true
	return false

func _enter_charge_stun() -> void:
	if is_instance_valid(charge_fx): charge_fx.impact_burst(global_position, charge_direction)
	var tree_main: Node = get_tree().current_scene
	if tree_main.has_method("show_boss_message"): tree_main.show_boss_message("ZUNGAR CRASHED! NOW'S YOUR CHANCE!")
	# Capture the live sword pose at impact. Without this, the custom stunned
	# state reused an old locked angle and the sword could appear stuck after a
	# charge collision instead of recovering like a normal Duelist.
	locked_blade_angle = blade_angle
	clash_latched = true
	state = State.STUNNED
	stun_left = ZungarConfig.CHARGE_TREE_STUN_DURATION
	state_left = stun_left

# =============================================================================
# JUMP SLAM
# =============================================================================
func _begin_jump_windup(speed_multiplier: float) -> void:
	state = State.JUMP_WINDUP
	state_left = ZungarConfig.JUMP_SLAM_WARNING_DURATION / speed_multiplier
	jump_origin = global_position
	jump_target = player_ref.global_position
	jump_marker_left = (ZungarConfig.JUMP_SLAM_WARNING_DURATION + ZungarConfig.JUMP_SLAM_TRAVEL_DURATION) / speed_multiplier
	last_major_ability = "jump"

func _begin_jump_travel() -> void:
	jump_origin = global_position
	jump_target = player_ref.global_position
	state = State.JUMP_TRAVEL
	state_left = ZungarConfig.JUMP_SLAM_TRAVEL_DURATION

func _process_jump_travel(_delta: float) -> void:
	velocity = Vector2.ZERO
	var travel_duration: float = maxf(ZungarConfig.JUMP_SLAM_TRAVEL_DURATION, 0.001)
	var progress: float = clampf(1.0 - state_left / travel_duration, 0.0, 1.0)
	var height: float = sin(progress * PI) * ZungarConfig.JUMP_HEIGHT
	var ground_position: Vector2 = jump_origin.lerp(jump_target, progress)
	global_position = ground_position + Vector2(0.0, -height)
	if state_left <= 0.0: _perform_jump_slam()

func _perform_jump_slam() -> void:
	global_position = jump_target
	landing_flash_left = 0.45
	jump_marker_left = 0.0
	for campfire_node: Node in get_tree().get_nodes_in_group("zungar_campfire"):
		var campfire: BossCampfire = campfire_node as BossCampfire
		if campfire != null and campfire.fire_active and global_position.distance_to(campfire.global_position) <= campfire.ignition_radius:
			fire_reaction_left = ZungarConfig.FIRE_REACTION_DURATION
			var fire_main: Node = get_tree().current_scene
			if fire_main.has_method("show_boss_message"): fire_main.show_boss_message("ZUNGAR:\\nAH AH AH! HOT! ZUNGAR NO LIKE FLAMES!")
	var distance_to_player: float = global_position.distance_to(player_ref.global_position)
	if distance_to_player <= ZungarConfig.JUMP_SLAM_RADIUS:
		player_ref.take_damage(_boss_damage(ZungarConfig.JUMP_SLAM_DAMAGE), player_ref.global_position.direction_to(global_position) * ZungarConfig.JUMP_SLAM_KNOCKBACK, self)
	_damage_summons_in_radius(global_position, ZungarConfig.JUMP_SLAM_RADIUS, ZungarConfig.FRIENDLY_JUMP_DAMAGE, ZungarConfig.FRIENDLY_JUMP_KNOCKBACK)
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("spawn_impact_fx"): main_scene.spawn_impact_fx(global_position, 2.4)
	if main_scene.has_method("request_screen_shake"): main_scene.request_screen_shake(12.0, 0.3, Vector2.DOWN)
	state = State.RECOVERY
	state_left = ZungarConfig.JUMP_SLAM_RECOVERY_DURATION

# =============================================================================
# FIRE STOMP — taunt → run → stomp → relight
# =============================================================================
func _try_stomp_campfire() -> bool:
	if global_position.distance_to(player_ref.global_position) < 140.0: return false
	if randf() > 0.18: return false
	for campfire_node: Node in get_tree().get_nodes_in_group("zungar_campfire"):
		var campfire: BossCampfire = campfire_node as BossCampfire
		if campfire != null and campfire.fire_active:
			stomp_campfire = campfire
			state = State.FIRE_STOMP
			fire_stomp_taunt_left = ZungarConfig.FIRE_STOMP_TAUNT_DURATION
			state_left = 0.0
			var fire_main: Node = get_tree().current_scene
			if fire_main.has_method("show_boss_message"): fire_main.show_boss_message("Zungar hate fire!")
			last_major_ability = "fire_stomp"
			return true
	return false

func _process_fire_stomp(delta: float) -> void:
	if stomp_campfire == null or not is_instance_valid(stomp_campfire):
		state = State.CHASE
		return
	# Taunt phase — stand still, let the player read the line.
	if fire_stomp_taunt_left > 0.0:
		fire_stomp_taunt_left = maxf(0.0, fire_stomp_taunt_left - delta)
		velocity = Vector2.ZERO
		return
	# Run to campfire.
	var distance: float = global_position.distance_to(stomp_campfire.global_position)
	if distance > 70.0:
		velocity = global_position.direction_to(stomp_campfire.global_position) * ZungarConfig.CHASE_SPEED * 1.7
		move_and_slide()
		return
	# Arrived — stomp it out.
	velocity = Vector2.ZERO
	state_left -= delta
	if state_left <= 0.0:
		stomp_campfire.stomp_out()
		_damage_summons_in_radius(stomp_campfire.global_position, stomp_campfire.ignition_radius + 24.0, ZungarConfig.FRIENDLY_JUMP_DAMAGE, ZungarConfig.FRIENDLY_STOMP_KNOCKBACK)
		state = State.RECOVERY
		state_left = ZungarConfig.FIRE_STOMP_RECOVERY

# =============================================================================
# SPEAR MODE
# =============================================================================
func _begin_spear_mode(speed_multiplier: float) -> void:
	state = State.SPEAR
	spear_timer = 0.6
	state_left = ZungarConfig.SPEAR_MODE_DURATION / speed_multiplier
	last_major_ability = "spear"

func _process_spear_mode(delta: float) -> void:
	velocity = Vector2.ZERO
	spear_timer -= delta
	if spear_timer <= 0.0:
		spear_timer = ZungarConfig.SPEAR_THROW_INTERVAL / (ZungarConfig.AGGRESSIVE_SPEED_MULTIPLIER if aggressive_phase else 1.0)
		_throw_spear()
	if state_left <= 0.0:
		state = State.CHASE

func _throw_spear() -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("spawn_boss_projectile"):
		main_scene.spawn_boss_projectile(global_position, global_position.direction_to(player_ref.global_position), _boss_damage(ZungarConfig.SPEAR_DAMAGE), self, true)

func take_damage(amount: float, force: Vector2 = Vector2.ZERO, stagger_duration: float = 0.18, impact_quality: float = 0.0) -> void:
	super.take_damage(amount, force, stagger_duration, impact_quality)
	# A real sword hit must interrupt the custom boss state machine just as it
	# interrupts a normal armed enemy. Otherwise charge/jump/spear continued
	# running while Enemy.take_damage() silently accumulated unused stun/recoil.
	if health > 0.0 and stun_left > 0.0:
		locked_blade_angle = blade_angle
		state = State.STUNNED

# =============================================================================
# TREE THROW
# =============================================================================
func _try_tree_throw() -> bool:
	if randf() > 0.12: return false
	for tree_node: Node in get_tree().get_nodes_in_group("zungar_trees"):
		var tree: DestructibleTree = tree_node as DestructibleTree
		if tree != null and tree.take_for_throw():
			thrown_tree = tree
			state = State.TREE_THROW
			state_left = 0.9
			last_major_ability = "tree_throw"
			return true
	return false

func _process_tree_throw() -> void:
	velocity = Vector2.ZERO
	if thrown_tree == null or not is_instance_valid(thrown_tree):
		state = State.RECOVERY
		state_left = 0.5
		return
	if state_left > 0.0: return
	var target_position: Vector2 = player_ref.global_position
	var main_scene: Node = get_tree().current_scene
	if not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(global_position, target_position, 2.0):
		if thrown_tree.global_position.distance_to(target_position) < ZungarConfig.TREE_THROW_RADIUS:
			player_ref.take_damage(_boss_damage(thrown_tree.thrown_damage), global_position.direction_to(target_position) * ZungarConfig.TREE_THROW_KNOCKBACK, self)
	_damage_summons_in_radius(target_position, ZungarConfig.TREE_THROW_RADIUS, ZungarConfig.FRIENDLY_JUMP_DAMAGE, ZungarConfig.FRIENDLY_TREE_THROW_KNOCKBACK)
	thrown_tree.break_from_charge()
	thrown_tree = null
	state = State.RECOVERY
	state_left = 0.8

func take_fire_damage(amount: float, force: Vector2 = Vector2.ZERO, stagger_duration: float = 0.18, impact_quality: float = 0.0) -> void:
	fire_reaction_left = 0.35
	take_damage(amount + ZungarConfig.FIRE_BONUS_DAMAGE, force, stagger_duration, impact_quality)

# =============================================================================
# =============================================================================
# SUMMONS, FRIENDLY FIRE, AND BOSS-SPECIFIC WEAPON RESPONSE
# =============================================================================
func _begin_summoning() -> void:
	state = State.SUMMONING
	state_left = ZungarConfig.SUMMON_CAST_DURATION
	summon_issued = false
	summon_cooldown_left = ZungarConfig.SUMMON_COOLDOWN
	last_major_ability = "summon"
	velocity = Vector2.ZERO
	if is_instance_valid(charge_fx): charge_fx.stop_emission()
	var main_scene: Node = get_tree().current_scene
	if main_scene != null and main_scene.has_method("show_boss_message"):
		main_scene.show_boss_message(ZungarConfig.SUMMON_BARK)

func _process_summoning() -> void:
	velocity = Vector2.ZERO
	if not summon_issued and state_left <= ZungarConfig.SUMMON_CAST_DURATION * 0.52:
		summon_issued = true
		var main_scene: Node = get_tree().current_scene
		if main_scene != null and main_scene.has_method("spawn_zungar_reinforcements"):
			main_scene.spawn_zungar_reinforcements(ZungarConfig.SUMMON_MAX_ALIVE)
	if state_left <= 0.0:
		state = State.RECOVERY
		state_left = 0.45

func _living_summon_count() -> int:
	var count: int = 0
	for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
		var summon: Enemy = summon_node as Enemy
		if summon != null and is_instance_valid(summon) and not summon.death_emitted:
			count += 1
	return count

func _tick_friendly_fire_sword_cooldowns(delta: float) -> void:
	var expired_ids: Array[int] = []
	for summon_id: int in friendly_fire_sword_cooldowns:
		var cooldown_left: float = maxf(0.0, friendly_fire_sword_cooldowns[summon_id] - delta)
		friendly_fire_sword_cooldowns[summon_id] = cooldown_left
		if cooldown_left <= 0.0:
			expired_ids.append(summon_id)
	for summon_id: int in expired_ids:
		friendly_fire_sword_cooldowns.erase(summon_id)

func _executioner_sword_minion_hit_test() -> void:
	if stun_left > 0.0:
		return
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var sword_start: Vector2 = weapon_segment["start"] as Vector2
	var sword_end: Vector2 = weapon_segment["end"] as Vector2
	for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
		var summon: Enemy = summon_node as Enemy
		if summon == null or not is_instance_valid(summon) or summon.death_emitted:
			continue
		var summon_id: int = summon.get_instance_id()
		if friendly_fire_sword_cooldowns.has(summon_id):
			continue
		if _point_segment_distance(summon.global_position, sword_start, sword_end) > ZungarConfig.EXECUTIONER_SWORD_HIT_RADIUS:
			continue
		friendly_fire_sword_cooldowns[summon_id] = ZungarConfig.EXECUTIONER_SWORD_HIT_COOLDOWN
		summon.take_damage(_boss_damage(ZungarConfig.FRIENDLY_SWORD_DAMAGE), global_position.direction_to(summon.global_position) * ZungarConfig.FRIENDLY_SWORD_KNOCKBACK, 0.2)
		on_friendly_fire_hit()

func _damage_summons_near_segment(start: Vector2, end: Vector2, radius: float, damage_amount: float, knockback_strength: float) -> void:
	for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
		var summon: Enemy = summon_node as Enemy
		if summon == null or not is_instance_valid(summon) or summon.death_emitted:
			continue
		var summon_id: int = summon.get_instance_id()
		if friendly_fire_hit_ids.has(summon_id) or _point_segment_distance(summon.global_position, start, end) > radius:
			continue
		friendly_fire_hit_ids[summon_id] = true
		var hit_direction: Vector2 = start.direction_to(end)
		if hit_direction.length_squared() <= 0.001: hit_direction = global_position.direction_to(summon.global_position)
		summon.take_damage(_boss_damage(damage_amount), hit_direction * knockback_strength, 0.24)
		on_friendly_fire_hit()

func _damage_summons_in_radius(center: Vector2, radius: float, damage_amount: float, knockback_strength: float) -> void:
	friendly_fire_hit_ids.clear()
	for summon_node: Node in get_tree().get_nodes_in_group("zungar_summons"):
		var summon: Enemy = summon_node as Enemy
		if summon == null or not is_instance_valid(summon) or summon.death_emitted or center.distance_to(summon.global_position) > radius:
			continue
		friendly_fire_hit_ids[summon.get_instance_id()] = true
		summon.take_damage(_boss_damage(damage_amount), center.direction_to(summon.global_position) * knockback_strength, 0.26)
		on_friendly_fire_hit()

func on_friendly_fire_hit() -> void:
	if friendly_fire_bark_cooldown > 0.0:
		return
	friendly_fire_bark_cooldown = ZungarConfig.FRIENDLY_FIRE_BARK_COOLDOWN
	var main_scene: Node = get_tree().current_scene
	if main_scene.has_method("show_boss_message"):
		main_scene.show_boss_message(ZungarConfig.FRIENDLY_FIRE_BARK)

func is_blade_clashing(player_start: Vector2, player_end: Vector2) -> bool:
	# Enemy.is_blade_clashing() is the canonical goblin Duelist path: shared
	# contact tolerance, angle window, cooldown, parry enable, and latch state.
	return super.is_blade_clashing(player_start, player_end)

func parry_blade(player_start: Vector2, player_end: Vector2, incoming_velocity: Vector2 = Vector2.ZERO, contact_preset: int = 1) -> void:
	super.parry_blade(player_start, player_end, incoming_velocity, contact_preset)
	blade_length = ZungarConfig.EXECUTIONER_SWORD_REACH
	weapon_origin_offset = ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET
	state = State.STUNNED
	stun_left = maxf(stun_left, 0.46)
	if is_instance_valid(charge_fx): charge_fx.impact_burst(global_position + get_blade_direction() * weapon_origin_offset, incoming_velocity.normalized())

func weapon_clash(incoming_velocity: Vector2 = Vector2.ZERO, contact_preset: int = 1) -> void:
	super.weapon_clash(incoming_velocity, contact_preset)
	blade_length = ZungarConfig.EXECUTIONER_SWORD_REACH
	weapon_origin_offset = ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET
	state = State.STUNNED
	stun_left = maxf(stun_left, 0.3)

func receive_weapon_beat(incoming_velocity: Vector2, stagger_duration: float, recoil_strength: float) -> void:
	super.receive_weapon_beat(incoming_velocity, stagger_duration, recoil_strength)
	blade_length = ZungarConfig.EXECUTIONER_SWORD_REACH
	weapon_origin_offset = ZungarConfig.EXECUTIONER_SWORD_ORIGIN_OFFSET
	state = State.STUNNED
	state_left = stun_left
	if is_instance_valid(charge_fx):
		charge_fx.impact_burst(global_position + get_blade_direction() * weapon_origin_offset, incoming_velocity.normalized())

# Drawing
# =============================================================================
func _draw_power_aura(aura_color: Color, strength: float) -> void:
	var pulse: float = 1.0 + sin(animation_time * 8.0) * 0.08
	var points: PackedVector2Array = PackedVector2Array()
	for point_index: int in range(24):
		var angle: float = float(point_index) * TAU / 24.0 + animation_time * 0.35
		var radius: float = (62.0 if point_index % 2 == 0 else 42.0) * pulse
		if point_index % 3 == 0: radius += 12.0 + sin(animation_time * 10.0 + float(point_index)) * 5.0
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	draw_colored_polygon(points, Color(aura_color.r, aura_color.g, aura_color.b, 0.12 * strength))
	draw_arc(Vector2.ZERO, 48.0 * pulse, 0.0, TAU, 40, Color(aura_color.r, aura_color.g, aura_color.b, 0.65 * strength), 4.0, true)
	draw_arc(Vector2.ZERO, 57.0 * pulse, animation_time * 1.8, animation_time * 1.8 + PI * 1.35, 24, Color(aura_color.r, aura_color.g, aura_color.b, 0.9 * strength), 3.0, true)
	for spark_index: int in range(10):
		var spark_angle: float = animation_time * (1.2 + float(spark_index % 2) * 0.4) + float(spark_index) * TAU / 10.0
		var spark_radius: float = 45.0 + sin(animation_time * 5.0 + float(spark_index)) * 12.0
		var spark_position: Vector2 = Vector2.RIGHT.rotated(spark_angle) * spark_radius
		draw_line(spark_position, spark_position + Vector2.UP.rotated(spark_angle) * 8.0, Color(aura_color.r, aura_color.g, aura_color.b, 0.8 * strength), 2.5, true)

func _draw() -> void:
	# Character and weapon art live in ZungarVisual. Only gameplay-readable
	# telegraphs remain procedural so their dimensions stay tied to combat data.
	if aggressive_phase:
		_draw_power_aura(Color("17101f"), 1.0)
		draw_arc(Vector2.ZERO, 58.0 + sin(animation_time * 6.0) * 4.0, 0.0, TAU, 36, Color(0.03, 0.02, 0.06, 0.8), 6.0, true)
	if jump_marker_left > 0.0 and state in [State.JUMP_WINDUP, State.JUMP_TRAVEL]:
		var marker_position: Vector2 = jump_target - global_position
		var marker_alpha: float = clampf(jump_marker_left / 0.4, 0.0, 1.0)
		draw_arc(marker_position, 30.0, 0.0, TAU, 32, Color(1.0, 0.35, 0.15, marker_alpha), 3.0, true)
		draw_arc(marker_position, 46.0, 0.0, TAU, 40, Color(1.0, 0.6, 0.2, marker_alpha * 0.7), 3.0, true)
		draw_circle(marker_position, 6.0, Color(1.0, 0.9, 0.4, marker_alpha))
	if state == State.JUMP_WINDUP or state == State.CHARGE_WINDUP:
		draw_arc(Vector2.ZERO, 38.0, 0.0, TAU, 32, Color(1.0, 0.72, 0.22, 0.8), 3.0, true)
	if state == State.SPEAR:
		draw_line(Vector2(0.0, -48.0), Vector2(0.0, -78.0), Color("d9e4ec"), 4.0, true)
	if state == State.TREE_THROW:
		draw_circle(Vector2.ZERO, 42.0, Color(1.0, 0.28, 0.18, 0.22))
		draw_arc(Vector2.ZERO, 48.0, 0.0, TAU, 32, Color(1.0, 0.62, 0.2, 0.85), 4.0, true)
	if landing_flash_left > 0.0:
		draw_arc(Vector2.ZERO, ZungarConfig.JUMP_SLAM_RADIUS, 0.0, TAU, 40, Color(1.0, 0.35, 0.18, landing_flash_left / 0.45), 5.0, true)
	# Zungar owns custom boss telegraphs, but slide sparks, parry flashes, and
	# collision diagnostics belong to the shared moving-weapon capability.
	draw_moving_weapon_combat_fx()
