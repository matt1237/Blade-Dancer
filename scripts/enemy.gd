class_name Enemy extends CharacterBody2D

enum GrappleWeight { LIGHT, MEDIUM, HEAVY }
enum RangedCoverPhase { SEEK, HIDDEN, PEEK }
const PROJECTILE_SCENE_PATH: String = "res://scenes/enemy_projectile.tscn"
@export_category("Enemy Identity and Rewards")
## Shared base stats. Concrete enemy classes configure identity-specific values.
@export var max_health: float = 50.0
## Direct wave multiplier assigned by WaveSpawner before this enemy enters the tree.
var wave_stat_multiplier: float = 1.0
## Damage dealt when the enemy touches the player.
@export var contact_damage: float = 10.0
## Grapple response is the sole shared classification enum.
@export var grapple_weight: GrappleWeight = GrappleWeight.LIGHT
## Runtime identity and behavior are explicit capabilities configured by concrete classes.
@export var spawn_identity: StringName = &"enemy"
@export var participates_in_melee_engagement: bool = true
@export var moving_weapon_enabled: bool = false
@export var shield_enabled: bool = false
@export var charge_pose_enabled: bool = false
@export var charge_warning_tint_enabled: bool = false
@export var spear_visual_enabled: bool = false
@export var hilt_bash_impulse_multiplier: float = 1.0
@export var loot_material_name: String = ""
@export_range(0.0, 1.0, 0.01) var loot_material_chance: float = 0.0
@export var remnant_color: Color = Color("8d4ac4")
@export var remnant_radius: float = 18.0
## The runtime score awarded when this enemy is defeated.
var score_value: int = 100
## Ogre health remains separately tuneable for backward-compatible inspector values.
@export var elite_max_health: float = 100.0
## Chance that a Duelist uses the Metronome sword rhythm on spawn.
@export_range(0.0, 1.0, 0.05) var duelist_metronome_chance: float = 0.5
## Initial ranged cooldown range. A random value prevents every shooter firing together.
@export var ranged_initial_cooldown_min: float = 2.0
@export var ranged_initial_cooldown_max: float = 4.5
## Bug's normal shot interval, slowed 15% from the original semi-automatic cadence.
@export var ranged_shot_interval: float = 2.07
## Score values by archetype. These make wave rewards easy to tune in one place.
@export var chaser_score_value: int = 100
@export var duelist_score_value: int = 150
@export var ranged_score_value: int = 125
@export var charger_score_value: int = 150
@export var elite_score_value: int = 300

@export_category("Basic Movement and Contact")
## Movement speed in pixels per second.
@export var move_speed: float = 120.0
var death_emitted: bool = false
var impact_deformation_left: float = 0.0
var impact_deformation_duration: float = 0.0
var impact_deformation_compression: float = 0.0
var impact_deformation_overshoot: float = 0.0
var impact_deformation_direction: Vector2 = Vector2.RIGHT

var health: float = 50.0

## RUNTIME TIMER NAMING
## Variables ending in `_left` are countdown bookkeeping: they contain the
## seconds remaining in the current effect. Tune the exported duration/cooldown
## above rather than changing these runtime values.
var player_ref: Variant = null
var knockback: Vector2 = Vector2.ZERO
## Small, slower-decaying momentum tail from being pulled off balance by a taut grapple.
var grapple_slide_velocity: Vector2 = Vector2.ZERO
var fire_timer: float = 1.5
var ranged_reposition_left: float = 3.0
var ranged_orbit_sign: float = 1.0
var ranged_cover_mode_left: float = 0.0
var ranged_cover_cooldown_left: float = 0.0
var ranged_cover_phase: RangedCoverPhase = RangedCoverPhase.SEEK
var ranged_cover_phase_left: float = 0.0
var ranged_cover_has_fired: bool = false
var ranged_hidden_position: Vector2 = Vector2.ZERO
var ranged_peek_position: Vector2 = Vector2.ZERO
var terrain_navigation_override_active: bool = false
var terrain_navigation_override_target: Vector2 = Vector2.ZERO
var terrain_movement_modifiers: Dictionary[int, float] = {}
var timed_terrain_movement_modifiers: Dictionary[int, float] = {}
var contact_cooldown: float = 0.0
var frost_mark_left: float = 0.0
var frost_spark_time: float = 0.0
var electrified_left: float = 0.0
var electrified_tick: float = 1.0
var electrified_tick_interval: float = 1.0
var electrified_stun_chance: float = 0.2
var electrified_stun_duration: float = 0.55
var burning_left: float = 0.0
var burning_tick: float = 1.0
var burning_tick_interval: float = 1.0
var burning_damage_per_tick: float = 1.0
var windup: float = 0.0
var charge_left: float = 0.0
var charge_distance_left: float = 0.0
var charge_recovery_left: float = 0.0
var charge_motion_this_frame: bool = false
var charge_direction: Vector2 = Vector2.ZERO
var blade_angle: float = 0.0
var blade_flash: float = 0.0
var parry_flash: float = 0.0
var sword_parry_cooldown_left: float = 0.0
var stun_left: float = 0.0
var blade_target_angle: float = 0.0
var blade_length: float = 58.0
var thrust_left: float = 0.0
var thrust_cooldown: float = 0.0
var locked_blade_angle: float = 0.0
var clash_latched: bool = false
var clash_cooldown_left: float = 0.0
var charge_cooldown: float = 0.0
var duelist_metronome: bool = false
var disarmed: bool = false
var disarm_flash_left: float = 0.0
var disarm_weapon_angle: float = 0.0
var slide_flash_left: float = 0.0
var slide_visual_time: float = 0.0
var slide_visual_duration: float = ParryRules.SLIDE_VISUAL_DURATION
var slide_travel_direction: float = 1.0
var slide_contact_local: Vector2 = Vector2.ZERO
var slide_contact_distance: float = 24.0
var duelist_swing_time: float = 0.0
var shield_angle: float = 0.0
var shield_bash_left: float = 0.0
var shield_bash_cooldown: float = 1.6
var shield_parry_cooldown_left: float = 0.0
var chaser_attack_left: float = 0.0
var chaser_was_attacking: bool = false
var chaser_retreat_left: float = 0.0
var duelist_state: int = 2
var duelist_state_left: float = 0.8
var duelist_orbit_sign: float = 1.0
var elite_surround_left: float = 0.0
var elite_surround_cooldown: float = 2.0
var terrain_navigation_refresh_left: float = 0.0
var terrain_navigation_direction: Vector2 = Vector2.ZERO
var hd_enemy_sprite: AnimatedSprite2D = null
var hd_enemy_base_scale: float = 0.3
var engagement_director: Node = null
var engagement_orbit_sign: float = 1.0
## Opt-in entry walk used by Zungar's summoned allies: while active the enemy
## walks to entrance_walk_target with normal movement (and its normal walk
## animation) before any combat AI runs. Default off, so ordinary enemies are
## completely unaffected.
var entrance_walk_active: bool = false
var entrance_walk_target: Vector2 = Vector2.ZERO
var entrance_walk_speed: float = 95.0
@export_category("Body Pressure Slowdown")
## Movement multiplier while touching the player or another enemy. 0.6 means 40% slower.
@export_range(0.1, 1.0, 0.05) var body_pressure_speed_multiplier: float = 0.6
## Center-to-center distance where unit pressure begins.
@export var body_pressure_contact_distance: float = 34.0

@export_category("Shared Charge Behavior")
## Recovery after any completed charge. During this window the enemy cannot move or turn.
@export var charge_recovery_duration: float = 0.8

@export_category("Charger Charge")
## Chargers only wind up when the player is close enough for the full charge path to threaten them.
@export var charge_start_distance: float = 340.0
@export var charge_cooldown_duration: float = 3.5
## Seconds of player movement predicted when choosing the locked charge direction.
@export var charger_aim_lead: float = 0.4
## Fixed distance traveled, approximately 25% of the 1280-pixel arena width.
@export var charger_charge_distance: float = 360.0
## Speed multiplier during the actual charge. Distance is fixed independently of speed.
## Charge speed reduced by 10% to leave a fair Dash reaction window.
@export var charger_charge_speed_multiplier: float = 4.95
## Extra warning time gives players enough time to read the charge trajectory.
@export var charger_windup_duration: float = 0.62

@export_category("Elite Charge")
@export var elite_charge_start_distance: float = 340.0
@export var elite_charge_min_distance: float = 115.0
@export var elite_charge_cooldown_duration: float = 3.8
@export var elite_charge_aim_lead: float = 0.45
@export var elite_charge_distance: float = 360.0
## Charge speed reduced by 10% to leave a fair Dash reaction window.
@export var elite_charge_speed_multiplier: float = 4.05
## Extra warning time gives players enough time to read the Elite charge trajectory.
@export var elite_charge_windup_duration: float = 0.68

@export_category("Enemy Combat Behavior")
@export var chaser_attack_duration: float = 2.0
@export var chaser_retreat_duration: float = 1.2
@export var duelist_retreat_health_percent: float = 0.2
@export var duelist_combat_range: float = 145.0
## Goblin spear length while idle, reduced 20% from the former 58px reach.
@export var duelist_blade_length: float = 46.0
## Goblin spear length during its thrust, reduced 20% from the former 92px reach.
@export var duelist_thrust_blade_length: float = 74.0
@export var duelist_retreat_duration: float = 0.5
@export var duelist_circle_duration: float = 0.75
@export var ranged_reposition_interval: float = 4.0
@export_category("Ranged Cover Fire")
## Total seconds a flying ranged enemy repeats its hide, peek, shoot cycle.
@export var ranged_cover_mode_duration: float = 8.0
## Chance checked each second to begin cover mode when suitable wall cover exists.
## 0.14 is roughly a 14% chance per second after the cooldown is ready.
@export_range(0.0, 1.0, 0.01) var ranged_cover_attempt_chance_per_second: float = 0.14
## Minimum seconds before the enemy may begin another cover-fire sequence.
@export var ranged_cover_cooldown_duration: float = 7.0
## Fixed seconds spent safely hidden before every peek. This establishes the rhythm players can learn.
@export var ranged_cover_hide_duration: float = 0.65
## Extra pixels traveled beyond the wall edge before stopping to shoot.
## Higher values make the shooter easier to intercept; lower values make it hug cover.
@export var ranged_cover_peek_distance_past_edge: float = 48.0
## Movement-speed multiplier while traveling between the locked hide and peek points.
@export var ranged_cover_movement_speed_multiplier: float = 1.0
## Seconds the enemy visibly pauses at the peek point before releasing its shot.
@export var ranged_cover_aim_duration: float = 0.22
## Seconds the enemy remains exposed after firing before retreating behind the wall.
@export var ranged_cover_post_shot_exposure_duration: float = 0.45
## Minimum seconds between shots while performing cover fire.
## Cover shots use the same 15% slower Bug cadence.
@export var ranged_cover_shot_interval: float = 1.265
@export_category("Enemy Combat Behavior")
@export var elite_surround_duration: float = 1.2
@export var elite_surround_interval: float = 3.5
@export_category("Enemy Separation")
## Enemies begin steering apart inside this distance.
@export var enemy_separation_distance: float = 62.0
## Strength of the anti-clumping steering.
@export_range(0.0, 2.0, 0.1) var enemy_separation_strength: float = 0.9

@export_category("Enemy Weapon Collision")
## Distance from the enemy center to the actual weapon hilt.
## This keeps the weapon capsule around the body edge instead of through the rib cage.
@export var weapon_origin_offset: float = 16.0
## Draws the weapon capsule, hilt origin, and parry tolerance for diagnosis.
@export var debug_draw_weapon_collision: bool = false

@export_category("Universal Parry Rules")
## Per-unit master switch. Shared responsiveness, timing, tolerance, slide, and cling tuning lives in res://scripts/parry_rules.gd.
@export var parry_enabled: bool = true
## Moving-weapon contact, slide, block, clash, parry, cooldown, and latch rules
## are enabled explicitly by armed concrete classes.

@export_category("Elite Shield")
## Half-angle of the forward cone where the shield can intercept attacks.
@export var elite_shield_arc_degrees: float = 49.0
## Elite parry timing, tolerance, stagger, and forgiveness are centralized in ParryRules.
## Distance from the Elite's center to the middle of its shield.
@export var elite_shield_distance: float = 24.0
## Half of the shield's visible and collidable width.
@export var elite_shield_half_width: float = 14.0
## Extra forward shield movement during a bash.
@export var elite_shield_bash_extension: float = 14.0
## How quickly the Elite turns its shield toward the player. Lower values reduce twitching.
@export var elite_shield_tracking_speed: float = 3.5

var dizzy_stars_left: float = 0.0
var dizzy_stars_time: float = 0.0
@onready var health_bar: ProgressBar = $HealthBar

func _ready() -> void:
	z_as_relative = false
	z_index = 2
	_configure_concrete_enemy()
	var stat_multiplier: float = maxf(1.0, wave_stat_multiplier)
	max_health *= stat_multiplier
	contact_damage *= stat_multiplier
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = false
	add_to_group("enemies")
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty(): player_ref = players[0]
	var engagement_nodes: Array[Node] = get_tree().get_nodes_in_group("melee_engagement_director")
	if not engagement_nodes.is_empty(): engagement_director = engagement_nodes[0]
	engagement_orbit_sign = -1.0 if get_instance_id() % 2 == 0 else 1.0
	_setup_hd_enemy_sprite()
	queue_redraw()

## Concrete named enemies override this hook instead of selecting an enum branch.
func _configure_concrete_enemy() -> void:
	pass

func material_drop_for_roll(roll: float) -> String:
	return loot_material_name if not loot_material_name.is_empty() and roll < loot_material_chance else ""

func spawn_balance_key() -> StringName:
	return spawn_identity

func _is_hd_visual() -> bool:
	return player_ref != null and player_ref.visual_style == "hd"

func _setup_hd_enemy_sprite() -> void:
	hd_enemy_sprite = AnimatedSprite2D.new()
	hd_enemy_sprite.name = "HDEnemySprite"
	hd_enemy_sprite.z_index = -1
	add_child(hd_enemy_sprite)
	var visual_config: Dictionary = _hd_visual_config()
	if visual_config.is_empty():
		hd_enemy_sprite.visible = false
		return
	var atlas_path: String = str(visual_config.get("idle", ""))
	var move_atlas_path: String = str(visual_config.get("move", ""))
	var frame_size: Vector2 = visual_config.get("frame_size", Vector2.ZERO) as Vector2
	var frame_count: int = int(visual_config.get("frame_count", 1))
	hd_enemy_base_scale = float(visual_config.get("scale", 0.3))
	var idle_atlas: Texture2D = load(atlas_path) as Texture2D
	var move_atlas: Texture2D = load(move_atlas_path) as Texture2D
	if idle_atlas == null or move_atlas == null:
		hd_enemy_sprite.visible = false
		return
	var frames: SpriteFrames = SpriteFrames.new()
	_add_hd_animation(frames, "idle", idle_atlas, frame_size, frame_count, 3.0)
	_add_hd_animation(frames, "move", move_atlas, frame_size, frame_count, 5.0)
	hd_enemy_sprite.sprite_frames = frames
	hd_enemy_sprite.play("idle")
	var eyes: Node2D = preload("res://scripts/hd_enemy_eyes.gd").new()
	eyes.actor = self
	eyes.source = hd_enemy_sprite
	hd_enemy_sprite.add_child(eyes)

func _hd_visual_config() -> Dictionary:
	return {}

func _add_hd_animation(frames: SpriteFrames, animation_name: String, atlas: Texture2D, frame_size: Vector2, frame_count: int, speed: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, speed)
	frames.set_animation_loop(animation_name, true)
	for frame_index: int in range(frame_count):
		var frame: AtlasTexture = AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(Vector2(float(frame_index) * frame_size.x, 0.0), frame_size)
		frames.add_frame(animation_name, frame)

func _update_hd_enemy_sprite() -> void:
	if hd_enemy_sprite == null: return
	hd_enemy_sprite.visible = _is_hd_visual()
	if not hd_enemy_sprite.visible: return
	var facing_left: bool = player_ref != null and player_ref.global_position.x < global_position.x
	hd_enemy_sprite.flip_h = facing_left
	var desired_animation: String = "move" if velocity.length_squared() > 400.0 or windup > 0.0 else "idle"
	if hd_enemy_sprite.animation != desired_animation:
		hd_enemy_sprite.play(desired_animation)
	var impact_ratio: float = clampf(impact_deformation_left / maxf(impact_deformation_duration, 0.001), 0.0, 1.0)
	var windup_ratio: float = clampf(windup / maxf(0.01, 0.68), 0.0, 1.0)
	var charge_pose: float = windup_ratio if charge_pose_enabled else 0.0
	hd_enemy_sprite.position = Vector2(0.0, -charge_pose * 2.0)
	hd_enemy_sprite.rotation = (0.04 if facing_left else -0.04) * charge_pose
	hd_enemy_sprite.scale = Vector2(hd_enemy_base_scale * (1.0 + impact_ratio * 0.08 + charge_pose * 0.04), hd_enemy_base_scale * (1.0 - impact_ratio * 0.06 - charge_pose * 0.04))
	# Classic chargers turn red throughout their windup. Keep that warning in HD
	# without changing the sprite's transform, collision, or charge timing.
	var warning_tint: Color = Color.WHITE
	if charge_warning_tint_enabled and windup > 0.0:
		warning_tint = Color(1.0, 0.52, 0.48, 1.0)
	hd_enemy_sprite.self_modulate = warning_tint

func tick_moving_weapon_combat(delta: float) -> void:
	## Shared lifecycle for every independently moving enemy weapon. Custom boss
	## process loops must call this too; otherwise slide/parry/clash latches and
	## cooldowns never recover.
	if not moving_weapon_enabled:
		return
	blade_flash = maxf(0.0, blade_flash - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	sword_parry_cooldown_left = maxf(0.0, sword_parry_cooldown_left - delta)
	disarm_flash_left = maxf(0.0, disarm_flash_left - delta)
	slide_flash_left = maxf(0.0, slide_flash_left - delta)
	if slide_flash_left > 0.0:
		slide_visual_time += delta
	clash_cooldown_left = maxf(0.0, clash_cooldown_left - delta)

func _physics_process(delta: float) -> void:
	_update_hd_enemy_sprite()
	if player_ref == null: return
	charge_motion_this_frame = false
	tick_moving_weapon_combat(delta)
	impact_deformation_left = maxf(0.0, impact_deformation_left - delta)
	stun_left = maxf(0.0, stun_left - delta)
	dizzy_stars_left = maxf(0.0, dizzy_stars_left - delta)
	if dizzy_stars_left > 0.0 or stun_left > 0.0:
		dizzy_stars_time += delta
	thrust_cooldown = maxf(0.0, thrust_cooldown - delta)
	charge_cooldown = maxf(0.0, charge_cooldown - delta)
	shield_bash_left = maxf(0.0, shield_bash_left - delta)
	shield_bash_cooldown = maxf(0.0, shield_bash_cooldown - delta)
	shield_parry_cooldown_left = maxf(0.0, shield_parry_cooldown_left - delta)
	contact_cooldown = maxf(0.0, contact_cooldown - delta)
	chaser_attack_left = maxf(0.0, chaser_attack_left - delta)
	chaser_retreat_left = maxf(0.0, chaser_retreat_left - delta)
	duelist_state_left = maxf(0.0, duelist_state_left - delta)
	charge_recovery_left = maxf(0.0, charge_recovery_left - delta)
	elite_surround_left = maxf(0.0, elite_surround_left - delta)
	elite_surround_cooldown = maxf(0.0, elite_surround_cooldown - delta)
	terrain_navigation_refresh_left = maxf(0.0, terrain_navigation_refresh_left - delta)
	for source_id: int in timed_terrain_movement_modifiers.keys():
		timed_terrain_movement_modifiers[source_id] = maxf(0.0, timed_terrain_movement_modifiers[source_id] - delta)
		if timed_terrain_movement_modifiers[source_id] <= 0.0:
			timed_terrain_movement_modifiers.erase(source_id)
			terrain_movement_modifiers.erase(source_id)
	frost_mark_left = maxf(0.0, frost_mark_left - delta)
	frost_spark_time += delta
	electrified_left = maxf(0.0, electrified_left - delta)
	burning_left = maxf(0.0, burning_left - delta)
	electrified_tick -= delta
	burning_tick -= delta
	if electrified_left > 0.0 and electrified_tick <= 0.0:
		electrified_tick = electrified_tick_interval
		if randf() < electrified_stun_chance: stun_for(electrified_stun_duration)
	if burning_left > 0.0 and burning_tick <= 0.0:
		burning_tick = burning_tick_interval
		take_damage(burning_damage_per_tick, Vector2.ZERO, 0.0)
	if stun_left > 0.0:
		blade_angle = locked_blade_angle
		blade_length = 76.0
		velocity = knockback + grapple_slide_velocity
		knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
		grapple_slide_velocity = grapple_slide_velocity.move_toward(Vector2.ZERO, delta * 180.0)
		move_and_slide()
		queue_redraw()
		return
	if entrance_walk_active:
		# Boss-summon entry: walk out of the cave to the waypoint, then fight.
		# Always returns this frame so combat AI resumes cleanly on the next one.
		var waypoint_remaining: float = global_position.distance_to(entrance_walk_target)
		if waypoint_remaining <= 4.0:
			entrance_walk_active = false
			velocity = Vector2.ZERO
		else:
			velocity = global_position.direction_to(entrance_walk_target) * minf(entrance_walk_speed, waypoint_remaining / maxf(delta, 0.001))
			velocity += knockback + grapple_slide_velocity
			knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
			grapple_slide_velocity = grapple_slide_velocity.move_toward(Vector2.ZERO, delta * 180.0)
			move_and_slide()
		queue_redraw()
		return
	terrain_navigation_override_active = false
	var engagement_positioning_active: bool = _apply_engagement_positioning(delta)
	if not engagement_positioning_active:
		_run_concrete_ai(delta)
	_apply_terrain_navigation()
	if not charge_motion_this_frame and windup <= 0.0 and charge_recovery_left <= 0.0:
		velocity += _enemy_separation_force() * move_speed * enemy_separation_strength
	# Charge motion already incorporates Flow slowdown while preserving fixed travel distance.
	if not charge_motion_this_frame:
		var pressure_multiplier: float = body_pressure_speed_multiplier if _is_under_body_pressure() else 1.0
		var slide_friction_multiplier: float = _combat_setting("slide_friction", 0.45) if has_live_blade_slide_contact() else 1.0
		velocity *= player_ref.get_flow_enemy_speed_multiplier() * pressure_multiplier * slide_friction_multiplier * _terrain_movement_multiplier()
	velocity += knockback + grapple_slide_velocity
	knockback = knockback.move_toward(Vector2.ZERO, delta * 600.0)
	grapple_slide_velocity = grapple_slide_velocity.move_toward(Vector2.ZERO, delta * 180.0)
	move_and_slide()
	var main_scene: Node = get_tree().current_scene
	var can_reach_player: bool = not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(global_position, player_ref.global_position, 2.0)
	if can_reach_player and contact_cooldown <= 0.0 and global_position.distance_to(player_ref.global_position) < 30.0:
		contact_cooldown = 0.55
		player_ref.take_damage(contact_damage, global_position.direction_to(player_ref.global_position) * 260.0, self)
		_on_player_contact()
	queue_redraw()

func _run_concrete_ai(_delta: float) -> void:
	velocity = Vector2.ZERO

func _on_player_contact() -> void:
	pass

func _apply_terrain_navigation() -> void:
	if charge_motion_this_frame or windup > 0.0 or charge_recovery_left > 0.0 or velocity.length_squared() < 0.01: return
	var main_scene: Node = get_tree().current_scene
	if not main_scene.has_method("get_terrain_navigation_direction"): return
	var intended_speed: float = velocity.length()
	if terrain_navigation_refresh_left <= 0.0:
		terrain_navigation_refresh_left = 0.16 + randf_range(0.0, 0.06)
		var intended_direction: Vector2 = velocity.normalized()
		var player_direction: Vector2 = global_position.direction_to(player_ref.global_position)
		var navigation_target: Vector2 = terrain_navigation_override_target if terrain_navigation_override_active else (player_ref.global_position if intended_direction.dot(player_direction) > 0.45 else global_position + intended_direction * 240.0)
		terrain_navigation_direction = main_scene.get_terrain_navigation_direction(global_position, navigation_target)
	if terrain_navigation_direction.length_squared() > 0.01:
		velocity = terrain_navigation_direction.normalized() * intended_speed

func _enemy_separation_force() -> Vector2:
	var separation: Vector2 = Vector2.ZERO
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == self: continue
		var other_enemy: Node2D = enemy_node as Node2D
		if other_enemy == null or not is_instance_valid(other_enemy): continue
		var offset: Vector2 = other_enemy.global_position.direction_to(global_position)
		var distance: float = global_position.distance_to(other_enemy.global_position)
		if distance < 0.01: offset = Vector2.RIGHT.rotated(float(get_instance_id() % 8))
		if distance < enemy_separation_distance:
			separation += offset * (1.0 - distance / enemy_separation_distance)
	return separation.limit_length(1.0)

func set_terrain_movement_modifier(source_id: int, multiplier: float) -> void:
	terrain_movement_modifiers[source_id] = clampf(multiplier, 0.0, 1.0)

func apply_timed_movement_modifier(source_id: int, multiplier: float, duration: float) -> void:
	set_terrain_movement_modifier(source_id, multiplier)
	timed_terrain_movement_modifiers[source_id] = maxf(float(timed_terrain_movement_modifiers.get(source_id, 0.0)), maxf(0.0, duration))

func remove_terrain_movement_modifier(source_id: int) -> void:
	terrain_movement_modifiers.erase(source_id)
	timed_terrain_movement_modifiers.erase(source_id)

func _terrain_movement_multiplier() -> float:
	var result: float = 1.0
	for modifier: float in terrain_movement_modifiers.values(): result = minf(result, modifier)
	return result

func _uses_melee_engagement() -> bool:
	return participates_in_melee_engagement

func _resolve_engagement_director() -> Node:
	if engagement_director != null and is_instance_valid(engagement_director): return engagement_director
	var engagement_nodes: Array[Node] = get_tree().get_nodes_in_group("melee_engagement_director")
	if not engagement_nodes.is_empty(): engagement_director = engagement_nodes[0]
	return engagement_director

func _has_engagement_pressure_slot() -> bool:
	if not _uses_melee_engagement(): return true
	var director: Node = _resolve_engagement_director()
	return true if director == null else director.has_pressure_slot(self)

func _has_engagement_attack_permission() -> bool:
	if not _uses_melee_engagement(): return true
	var director: Node = _resolve_engagement_director()
	return true if director == null else director.has_attack_permission(self)

func engagement_role() -> String:
	if not _uses_melee_engagement(): return "exempt"
	if _has_engagement_attack_permission(): return "attacker"
	if _has_engagement_pressure_slot(): return "pressure"
	return "waiting"

func engagement_attack_in_progress() -> bool:
	return false

func _engagement_action_in_progress() -> bool:
	return false

func _update_engagement_weapon_facing(delta: float, player_direction: Vector2) -> void:
	if spear_visual_enabled:
		blade_length = duelist_blade_length
		blade_target_angle = player_direction.angle()
		blade_angle = lerp_angle(blade_angle, blade_target_angle, clampf(_combat_setting("parry_rotation_speed", ParryRules.UNIVERSAL_BLADE_ROTATION_SPEED) * delta, 0.0, 1.0))
	elif shield_enabled:
		shield_angle = lerp_angle(shield_angle, player_direction.angle(), clampf(elite_shield_tracking_speed * delta, 0.0, 1.0))

func _apply_engagement_positioning(delta: float) -> bool:
	if not _uses_melee_engagement() or _engagement_action_in_progress(): return false
	var director: Node = _resolve_engagement_director()
	if director == null or director.has_attack_permission(self): return false
	var distance: float = global_position.distance_to(player_ref.global_position)
	var player_direction: Vector2 = global_position.direction_to(player_ref.global_position)
	var tangent: Vector2 = player_direction.orthogonal() * engagement_orbit_sign
	_update_engagement_weapon_facing(delta, player_direction)
	if director.has_pressure_slot(self):
		var pressure_target: Vector2 = player_ref.global_position - player_direction * director.pressure_ring_radius + tangent * 42.0
		if is_inside_tree():
			var arena_rect: Rect2 = GameplayBounds.arena_rect(get_tree().current_scene)
			pressure_target.x = clampf(pressure_target.x, arena_rect.position.x + 48.0, arena_rect.end.x - 48.0)
			pressure_target.y = clampf(pressure_target.y, arena_rect.position.y + 48.0, arena_rect.end.y - 48.0)
		terrain_navigation_override_active = true
		terrain_navigation_override_target = pressure_target
		if distance < director.pressure_ring_radius - 20.0:
			velocity = (-player_direction * 0.95 + tangent * 0.7).normalized() * move_speed
		elif distance > director.pressure_ring_radius + 20.0:
			velocity = (player_direction * 0.8 + tangent * 0.35).normalized() * move_speed
		else:
			velocity = tangent * move_speed * 0.72
		return true
	var waiting_target: Vector2 = director.waiting_target(self)
	terrain_navigation_override_active = true
	terrain_navigation_override_target = waiting_target
	if distance < director.peel_radius:
		# Peeling changes intent only. Collision and contact damage remain untouched.
		velocity = (-player_direction * 1.1 + tangent * 0.72).normalized() * move_speed * 1.08
	elif global_position.distance_to(waiting_target) > 22.0:
		velocity = global_position.direction_to(waiting_target) * move_speed * 0.9
	else:
		velocity = tangent * move_speed * 0.45
	return true

func _is_under_body_pressure() -> bool:
	if global_position.distance_to(player_ref.global_position) <= body_pressure_contact_distance:
		return true
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == self: continue
		var other_enemy: Node2D = enemy_node as Node2D
		if other_enemy != null and is_instance_valid(other_enemy) and global_position.distance_to(other_enemy.global_position) <= body_pressure_contact_distance:
			return true
	return false

func _chaser(_delta: float) -> void:
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	if chaser_was_attacking and chaser_attack_left <= 0.0 and chaser_retreat_left <= 0.0:
		chaser_was_attacking = false
		chaser_retreat_left = chaser_retreat_duration
	if chaser_retreat_left > 0.0:
		velocity = -direction * move_speed * 1.15
		blade_length = 0.0
		return
	if chaser_attack_left > 0.0:
		velocity = direction * move_speed if global_position.distance_to(player_ref.global_position) > 28.0 else Vector2.ZERO
		return
	velocity = direction * move_speed

func _duelist(delta: float) -> void:
	duelist_swing_time += delta
	var distance: float = global_position.distance_to(player_ref.global_position)
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	var retreating: bool = disarmed or health <= max_health * duelist_retreat_health_percent
	if retreating:
		velocity = -direction * move_speed * 1.2
		blade_length = 0.0 if disarmed else duelist_blade_length
		return
	if duelist_state_left <= 0.0:
		duelist_state = 0 if duelist_state == 2 else (duelist_state + 1)
		duelist_state_left = duelist_circle_duration if duelist_state == 2 else duelist_retreat_duration
		if duelist_state == 2: duelist_orbit_sign = -duelist_orbit_sign
	var tangent: Vector2 = direction.orthogonal() * duelist_orbit_sign
	if duelist_state == 1:
		velocity = (-direction * 0.85 + tangent * 0.8).normalized() * move_speed
	elif duelist_state == 2:
		velocity = (direction * (1.0 if distance > duelist_combat_range else 0.0) + tangent * 0.35).normalized() * move_speed
	else:
		velocity = direction * move_speed if distance > 90.0 else Vector2.ZERO
	thrust_left = maxf(0.0, thrust_left - delta)
	if thrust_left <= 0.0 and thrust_cooldown <= 0.0 and distance < duelist_combat_range:
		thrust_left = 0.32
		thrust_cooldown = 1.15
	blade_length = duelist_thrust_blade_length if thrust_left > 0.0 else duelist_blade_length
	blade_target_angle = direction.angle() + (PI * 0.55 if blade_flash > 0.0 else 0.0)
	blade_angle = lerp_angle(blade_angle, blade_target_angle, clampf(_combat_setting("parry_rotation_speed", ParryRules.UNIVERSAL_BLADE_ROTATION_SPEED) * delta, 0.0, 1.0))

func _begin_predictive_charge(aim_lead: float, travel_distance: float, speed_multiplier: float, cooldown_duration: float) -> void:
	var predicted_target: Vector2 = player_ref.global_position + player_ref.velocity * aim_lead
	charge_direction = global_position.direction_to(predicted_target)
	if charge_direction == Vector2.ZERO: charge_direction = global_position.direction_to(player_ref.global_position)
	charge_distance_left = travel_distance
	var charge_speed: float = maxf(1.0, move_speed * speed_multiplier)
	charge_left = travel_distance / charge_speed
	charge_cooldown = cooldown_duration
	if shield_enabled: shield_angle = charge_direction.angle()

func _advance_charge(delta: float, speed_multiplier: float) -> bool:
	if charge_distance_left <= 0.0: return false
	charge_motion_this_frame = true
	var charge_speed: float = move_speed * speed_multiplier * player_ref.get_flow_enemy_speed_multiplier()
	velocity = charge_direction * charge_speed
	charge_distance_left = maxf(0.0, charge_distance_left - charge_speed * delta)
	charge_left = charge_distance_left / maxf(charge_speed, 1.0)
	if charge_distance_left <= 0.0:
		charge_recovery_left = charge_recovery_duration
		charge_left = 0.0
	return true

func _elite(delta: float) -> void:
	var distance: float = global_position.distance_to(player_ref.global_position)
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	if _advance_charge(delta, elite_charge_speed_multiplier):
		shield_angle = charge_direction.angle()
		return
	if charge_recovery_left > 0.0:
		# Shield stays locked forward, exposing the Elite's back during recovery.
		velocity = Vector2.ZERO
		return
	shield_angle = lerp_angle(shield_angle, direction.angle(), clampf(elite_shield_tracking_speed * delta, 0.0, 1.0))
	if windup > 0.0:
		windup -= delta
		velocity = Vector2.ZERO
		if windup <= 0.0:
			_begin_predictive_charge(elite_charge_aim_lead, elite_charge_distance, elite_charge_speed_multiplier, elite_charge_cooldown_duration)
		return
	if charge_cooldown <= 0.0 and distance >= elite_charge_min_distance and distance <= elite_charge_start_distance:
		charge_direction = global_position.direction_to(player_ref.global_position + player_ref.velocity * elite_charge_aim_lead)
		windup = elite_charge_windup_duration
		return
	if shield_bash_left <= 0.0 and shield_bash_cooldown <= 0.0 and distance < 145.0:
		shield_bash_left = 0.3
		shield_bash_cooldown = 1.6
	if elite_surround_cooldown <= 0.0 and elite_surround_left <= 0.0 and distance < 360.0:
		elite_surround_left = elite_surround_duration
		elite_surround_cooldown = elite_surround_interval
	if elite_surround_left > 0.0:
		var surround_direction: Vector2 = direction.orthogonal() * (1.0 if sin(global_position.x + global_position.y) >= 0.0 else -1.0)
		velocity = (direction * 0.35 + surround_direction * 0.9).normalized() * move_speed
	else:
		velocity = direction * move_speed * (1.8 if shield_bash_left > 0.0 else 0.9)

func is_shield_blocking(start: Vector2, end: Vector2, forgiveness: float = 18.0) -> bool:
	if not shield_enabled or not ParryRules.can_attempt_parry(parry_enabled, stun_left > 0.0, false, shield_parry_cooldown_left): return false
	var shield_direction: Vector2 = Vector2.RIGHT.rotated(shield_angle)
	var sword_center_direction: Vector2 = global_position.direction_to((start + end) * 0.5)
	var shield_arc_cosine: float = cos(deg_to_rad(elite_shield_arc_degrees))
	if sword_center_direction.dot(shield_direction) < shield_arc_cosine: return false
	var shield_tangent: Vector2 = shield_direction.orthogonal()
	var bash_extension: float = elite_shield_bash_extension if shield_bash_left > 0.0 else 0.0
	var shield_center: Vector2 = global_position + shield_direction * (elite_shield_distance + bash_extension)
	var shield_start: Vector2 = shield_center - shield_tangent * elite_shield_half_width
	var shield_end: Vector2 = shield_center + shield_tangent * elite_shield_half_width
	return _segments_close(start, end, shield_start, shield_end, ParryRules.allowed_contact_tolerance(forgiveness, ParryRules.ELITE_PARRY_CONTACT_TOLERANCE, ParryRules.ELITE_PARRY_FORGIVENESS_MULTIPLIER))

func shield_blocks_projectile(point: Vector2) -> bool:
	if not shield_enabled or stun_left > 0.0: return false
	var from_enemy: Vector2 = global_position.direction_to(point)
	return from_enemy.dot(Vector2.RIGHT.rotated(shield_angle)) > 0.15

func chakram_blocked_from_front(point: Vector2) -> bool:
	return shield_blocks_projectile(point)

func shield_parry(incoming_velocity: Vector2 = Vector2.ZERO) -> void:
	parry_flash = 0.3
	shield_parry_cooldown_left = ParryRules.ELITE_PARRY_COOLDOWN_DURATION
	stun_left = ParryRules.ELITE_PARRY_STAGGER_DURATION
	locked_blade_angle = shield_angle
	clash_latched = true
	if incoming_velocity.length_squared() > 0.01: knockback += incoming_velocity.normalized() * 55.0
	queue_redraw()

func chakram_hit_from_behind(force: Vector2) -> void:
	if not shield_enabled: return
	stun_left = 2.0
	locked_blade_angle = shield_angle
	knockback += force * 0.35
	parry_flash = 0.45
	queue_redraw()

func _ranged(delta: float) -> void:
	var distance: float = global_position.distance_to(player_ref.global_position)
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	fire_timer -= delta
	ranged_cover_cooldown_left = maxf(0.0, ranged_cover_cooldown_left - delta)
	if ranged_cover_mode_left > 0.0:
		# Seeking cover must not consume the whole firing window before the Bug arrives.
		if ranged_cover_phase != RangedCoverPhase.SEEK:
			ranged_cover_mode_left = maxf(0.0, ranged_cover_mode_left - delta)
		if ranged_cover_mode_left > 0.0 or ranged_cover_phase == RangedCoverPhase.SEEK:
			_update_ranged_cover_fire(delta, direction)
			return
		_end_ranged_cover_fire()
	if ranged_cover_cooldown_left <= 0.0 and randf() < ranged_cover_attempt_chance_per_second * delta and _begin_ranged_cover_fire():
		_update_ranged_cover_fire(delta, direction)
		return
	ranged_reposition_left -= delta
	if ranged_reposition_left <= 0.0:
		ranged_reposition_left = ranged_reposition_interval + randf_range(-0.8, 0.8)
		ranged_orbit_sign = -ranged_orbit_sign
	var has_sight: bool = _has_player_line_of_sight()
	if not has_sight:
		# Strafe until a wall edge opens a valid shot rather than firing into terrain.
		velocity = direction.orthogonal() * ranged_orbit_sign * move_speed
	elif distance < 220.0:
		velocity = -direction * minf(move_speed, player_ref.move_speed * 0.85)
	elif distance > 300.0:
		velocity = direction * move_speed
	elif ranged_reposition_left < 0.8:
		velocity = direction.orthogonal() * ranged_orbit_sign * move_speed
	else:
		velocity = Vector2.ZERO
	if fire_timer <= 0.0 and has_sight:
		fire_timer = ranged_shot_interval
		_fire_ranged_projectile(direction)

func _begin_ranged_cover_fire() -> bool:
	var main_scene: Node = get_tree().current_scene
	if not main_scene.has_method("get_ranged_cover_positions"): return false
	var cover: Dictionary = main_scene.get_ranged_cover_positions(global_position, player_ref.global_position, EnemyProjectile.WALL_LOS_CLEARANCE, ranged_cover_peek_distance_past_edge)
	if cover.is_empty():
		ranged_cover_cooldown_left = 2.0
		return false
	ranged_hidden_position = cover["hidden"] as Vector2
	ranged_peek_position = cover["peek"] as Vector2
	ranged_cover_mode_left = ranged_cover_mode_duration
	ranged_cover_phase = RangedCoverPhase.SEEK
	ranged_cover_phase_left = 0.0
	ranged_cover_has_fired = false
	return true

func _update_ranged_cover_fire(delta: float, player_direction: Vector2) -> void:
	match ranged_cover_phase:
		RangedCoverPhase.SEEK:
			terrain_navigation_override_active = true
			terrain_navigation_override_target = ranged_hidden_position
			velocity = global_position.direction_to(ranged_hidden_position) * move_speed * ranged_cover_movement_speed_multiplier
			if global_position.distance_to(ranged_hidden_position) <= 18.0:
				ranged_cover_phase = RangedCoverPhase.HIDDEN
				ranged_cover_phase_left = ranged_cover_hide_duration
				ranged_cover_has_fired = false
				velocity = Vector2.ZERO
		RangedCoverPhase.HIDDEN:
			velocity = Vector2.ZERO
			ranged_cover_phase_left = maxf(0.0, ranged_cover_phase_left - delta)
			if ranged_cover_phase_left <= 0.0:
				ranged_cover_phase = RangedCoverPhase.PEEK
				ranged_cover_phase_left = ranged_cover_aim_duration
				ranged_cover_has_fired = false
				# Cover rhythm owns this shot timing: every valid peek fires after the same aim pause.
				fire_timer = 0.0
		RangedCoverPhase.PEEK:
			terrain_navigation_override_active = true
			terrain_navigation_override_target = ranged_peek_position
			velocity = global_position.direction_to(ranged_peek_position) * move_speed * ranged_cover_movement_speed_multiplier
			if global_position.distance_to(ranged_peek_position) <= 18.0:
				velocity = Vector2.ZERO
				if not ranged_cover_has_fired:
					ranged_cover_phase_left = maxf(0.0, ranged_cover_phase_left - delta)
					if ranged_cover_phase_left <= 0.0:
						if fire_timer <= 0.0 and _has_player_line_of_sight():
							fire_timer = ranged_cover_shot_interval
							_fire_ranged_projectile(player_direction)
							ranged_cover_has_fired = true
							ranged_cover_phase_left = ranged_cover_post_shot_exposure_duration
						else:
							# If the player moved fully behind cover, abandon this peek instead of firing blindly.
							ranged_cover_phase = RangedCoverPhase.SEEK
				else:
					ranged_cover_phase_left = maxf(0.0, ranged_cover_phase_left - delta)
					if ranged_cover_phase_left <= 0.0:
						ranged_cover_phase = RangedCoverPhase.SEEK
						ranged_cover_has_fired = false

func _end_ranged_cover_fire() -> void:
	ranged_cover_mode_left = 0.0
	ranged_cover_cooldown_left = ranged_cover_cooldown_duration + randf_range(0.0, 2.5)
	ranged_cover_phase = RangedCoverPhase.SEEK
	ranged_cover_has_fired = false
	terrain_navigation_override_active = false

func _has_player_line_of_sight() -> bool:
	var main_scene: Node = get_tree().current_scene
	var shot_direction: Vector2 = global_position.direction_to(player_ref.global_position)
	var muzzle_position: Vector2 = global_position + shot_direction * EnemyProjectile.MUZZLE_OFFSET
	return not main_scene.has_method("has_terrain_line_of_sight") or main_scene.has_terrain_line_of_sight(muzzle_position, player_ref.global_position, EnemyProjectile.WALL_LOS_CLEARANCE)

func _fire_ranged_projectile(_direction: Vector2) -> void:
	var shot_direction: Vector2 = global_position.direction_to(player_ref.global_position)
	var muzzle_position: Vector2 = global_position + shot_direction * EnemyProjectile.MUZZLE_OFFSET
	var main_scene: Node = get_tree().current_scene
	# Recheck immediately before spawning so movement during the peek cannot create a stale shot.
	if main_scene.has_method("has_terrain_line_of_sight") and not main_scene.has_terrain_line_of_sight(muzzle_position, player_ref.global_position, EnemyProjectile.WALL_LOS_CLEARANCE): return
	var projectile_scene: PackedScene = load(PROJECTILE_SCENE_PATH) as PackedScene
	if projectile_scene == null:
		push_error("Enemy projectile scene is unavailable; skipping ranged shot safely.")
		return
	var projectile: EnemyProjectile = projectile_scene.instantiate() as EnemyProjectile
	if projectile == null:
		push_error("Enemy projectile scene failed to instantiate; skipping ranged shot safely.")
		return
	get_parent().add_child(projectile)
	projectile.global_position = muzzle_position
	projectile.damage *= maxf(1.0, wave_stat_multiplier)
	projectile.launch(shot_direction, self)

func _charger(delta: float) -> void:
	var direction: Vector2 = global_position.direction_to(player_ref.global_position)
	if _advance_charge(delta, charger_charge_speed_multiplier): return
	if charge_recovery_left > 0.0:
		velocity = Vector2.ZERO
		return
	if windup > 0.0:
		windup -= delta
		velocity = Vector2.ZERO
		if windup <= 0.0:
			_begin_predictive_charge(charger_aim_lead, charger_charge_distance, charger_charge_speed_multiplier, charge_cooldown_duration)
		return
	if charge_cooldown <= 0.0 and global_position.distance_to(player_ref.global_position) <= charge_start_distance:
		charge_direction = global_position.direction_to(player_ref.global_position + player_ref.velocity * charger_aim_lead)
		windup = charger_windup_duration
		return
	# Constant pursuit ensures the Charger repeatedly enters a valid attack range.
	velocity = direction * move_speed

func _combat_setting(setting: String, fallback: float) -> float:
	if player_ref != null and player_ref.has_method("get_combat_contact_setting"):
		return float(player_ref.get_combat_contact_setting(setting))
	return fallback

func _core_setting(setting: String, fallback: float) -> float:
	if player_ref != null and player_ref.has_method("get_combat_hand_setting"):
		return float(player_ref.get_combat_hand_setting(setting))
	return fallback

func _enemy_weapon_segment() -> Dictionary:
	var weapon_direction: Vector2 = Vector2.RIGHT.rotated(blade_angle)
	var weapon_start: Vector2 = global_position + weapon_direction * weapon_origin_offset
	var weapon_end: Vector2 = weapon_start + weapon_direction * blade_length
	return {"start": weapon_start, "end": weapon_end}

func update_blade_contact(start: Vector2, end: Vector2) -> void:
	if clash_latched:
		var weapon_segment: Dictionary = _enemy_weapon_segment()
		var blade_start: Vector2 = weapon_segment["start"] as Vector2
		var blade_end: Vector2 = weapon_segment["end"] as Vector2
		if not _segments_close(start, end, blade_start, blade_end, 22.0):
			clash_latched = false
		elif moving_weapon_enabled:
			slide_flash_left = maxf(slide_flash_left, 0.08)

func is_blade_contact(player_start: Vector2, player_end: Vector2, tolerance: float = 7.0) -> bool:
	if not moving_weapon_enabled or disarmed or blade_length <= 0.0: return false
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var enemy_start: Vector2 = weapon_segment["start"] as Vector2
	var enemy_end: Vector2 = weapon_segment["end"] as Vector2
	return _segments_close(player_start, player_end, enemy_start, enemy_end, tolerance)

func try_blade_slide(player_start: Vector2, player_end: Vector2, incoming_velocity: Vector2 = Vector2.ZERO, contact_preset: int = 1) -> bool:
	if not moving_weapon_enabled or not ParryRules.can_attempt_parry(parry_enabled, stun_left > 0.0, disarmed or clash_latched, sword_parry_cooldown_left): return false
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var enemy_start: Vector2 = weapon_segment["start"] as Vector2
	var enemy_end: Vector2 = weapon_segment["end"] as Vector2
	var contact_tolerance: float = _combat_setting("slide_contact_tolerance", ParryRules.UNIVERSAL_SLIDE_CONTACT_TOLERANCE)
	if not _segments_close(player_start, player_end, enemy_start, enemy_end, contact_tolerance): return false
	var player_direction: Vector2 = (player_end - player_start).normalized()
	var enemy_direction: Vector2 = (enemy_end - enemy_start).normalized()
	var angle_tolerance: float = _combat_setting("slide_angle", ParryRules.UNIVERSAL_SLIDE_ANGLE_DEGREES)
	if absf(player_direction.dot(enemy_direction)) < cos(deg_to_rad(angle_tolerance)): return false
	var player_midpoint: Vector2 = (player_start + player_end) * 0.5
	var contact_point: Vector2 = _closest_point_on_segment(player_midpoint, enemy_start, enemy_end)
	var blade_distance_from_hilt: float = contact_point.distance_to(enemy_start)
	if blade_distance_from_hilt < 24.0: return false
	slide_contact_distance = blade_distance_from_hilt
	slide_contact_local = contact_point - global_position
	slide_visual_duration = _combat_setting("slide_duration", ParryRules.SLIDE_VISUAL_DURATION)
	slide_flash_left = slide_visual_duration
	slide_visual_time = 0.0
	slide_travel_direction = signf(incoming_velocity.dot(enemy_direction)) if contact_preset >= 2 else (-1.0 if randf() < 0.5 else 1.0)
	if slide_travel_direction == 0.0: slide_travel_direction = 1.0
	clash_latched = true
	if contact_preset == 1 and incoming_velocity.length_squared() > 0.01: knockback += incoming_velocity.normalized() * 28.0
	queue_redraw()
	return true

func has_live_blade_slide_contact() -> bool:
	return player_ref != null and player_ref.has_method("has_live_blade_slide_contact") and bool(player_ref.has_live_blade_slide_contact(self))

func end_blade_slide_contact() -> void:
	# Keep only a tiny release tail. slide_flash_left is presentation state and
	# must never continue applying movement friction after live geometry separates.
	slide_flash_left = minf(slide_flash_left, 0.10)
	clash_latched = false
	queue_redraw()

func get_slide_contact_global() -> Vector2:
	# Rebuild the contact from the live blade angle. The old fixed local point
	# drifted away whenever the Duelist rotated while the slide was visible.
	var live_direction: Vector2 = Vector2.RIGHT.rotated(blade_angle)
	return global_position + live_direction * (weapon_origin_offset + slide_contact_distance)

func get_blade_direction() -> Vector2:
	return Vector2.RIGHT.rotated(blade_angle)

func weapon_clash(incoming_velocity: Vector2 = Vector2.ZERO, contact_preset: int = 1) -> void:
	clash_latched = true
	var clash_cooldown_duration: float = _combat_setting("clash_cooldown", 0.35)
	clash_cooldown_left = clash_cooldown_duration
	var active_stagger: float = _combat_setting("clash_stagger", ParryRules.CLASH_STAGGER_DURATION)
	var active_recoil: float = _combat_setting("clash_enemy_recoil", ParryRules.CLASH_RECOIL_TO_ENEMY)
	stun_left = maxf(stun_left, active_stagger)
	knockback += player_ref.global_position.direction_to(global_position) * active_recoil
	if incoming_velocity.length_squared() > 0.01:
		knockback += incoming_velocity.normalized() * (8.0 if contact_preset >= 2 else 18.0)
	queue_redraw()

func receive_weapon_beat(incoming_velocity: Vector2, stagger_duration: float, recoil_strength: float) -> void:
	if not moving_weapon_enabled or disarmed:
		return
	# A beat displaces the weapon/stance only. It deliberately bypasses health
	# damage; the player must still create a later valid swept body collision.
	blade_flash = maxf(blade_flash, 0.22)
	parry_flash = maxf(parry_flash, 0.28)
	clash_latched = true
	clash_cooldown_left = maxf(clash_cooldown_left, _combat_setting("clash_cooldown", 0.35))
	stun_left = maxf(stun_left, stagger_duration)
	thrust_left = 0.0
	var incoming_direction: Vector2 = incoming_velocity.normalized() if incoming_velocity.length_squared() > 0.001 else Vector2.RIGHT
	var beat_side: float = signf(get_blade_direction().cross(incoming_direction))
	if is_zero_approx(beat_side):
		beat_side = 1.0
	locked_blade_angle = blade_angle + beat_side * deg_to_rad(22.0)
	blade_angle = locked_blade_angle
	knockback += incoming_direction * maxf(0.0, recoil_strength)
	queue_redraw()

func is_blade_clashing(player_start: Vector2, player_end: Vector2) -> bool:
	if not moving_weapon_enabled or not ParryRules.can_attempt_parry(parry_enabled, stun_left > 0.0, disarmed or clash_latched, sword_parry_cooldown_left): return false
	if clash_cooldown_left > 0.0: return false
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var blade_start: Vector2 = weapon_segment["start"] as Vector2
	var blade_end: Vector2 = weapon_segment["end"] as Vector2
	var tolerance: float = _combat_setting("clash_contact_tolerance", 18.0)
	if not _segments_close(player_start, player_end, blade_start, blade_end, tolerance): return false
	var player_dir: Vector2 = (player_end - player_start).normalized()
	var enemy_dir: Vector2 = (blade_end - blade_start).normalized()
	# Calculate crossing angle between the two blade lines in degrees (0 = parallel, 90 = perpendicular)
	var alignment: float = clampf(absf(player_dir.dot(enemy_dir)), 0.0, 1.0)
	var cross_angle_deg: float = rad_to_deg(acos(alignment))
	var min_angle: float = _combat_setting("clash_angle_min", 25.0)
	var max_angle: float = _combat_setting("clash_angle_max", 85.0)
	return cross_angle_deg >= min_angle and cross_angle_deg <= max_angle

func is_blade_blocking(start: Vector2, end: Vector2, forgiveness: float = 22.0) -> bool:
	if not moving_weapon_enabled or not ParryRules.can_attempt_parry(parry_enabled, stun_left > 0.0, disarmed or clash_latched, sword_parry_cooldown_left): return false
	var weapon_segment: Dictionary = _enemy_weapon_segment()
	var blade_start: Vector2 = weapon_segment["start"] as Vector2
	var blade_end: Vector2 = weapon_segment["end"] as Vector2
	var contact_tolerance: float = _combat_setting("parry_contact_tolerance", ParryRules.UNIVERSAL_PARRY_CONTACT_TOLERANCE)
	return _segments_close(start, end, blade_start, blade_end, ParryRules.allowed_contact_tolerance(forgiveness, contact_tolerance, 1.0))

func parry_blade(player_start: Vector2, player_end: Vector2, incoming_velocity: Vector2 = Vector2.ZERO, contact_preset: int = 1) -> void:
	blade_flash = 0.2
	parry_flash = 0.45
	sword_parry_cooldown_left = _combat_setting("parry_cooldown", ParryRules.UNIVERSAL_PARRY_COOLDOWN_DURATION)
	stun_left = _combat_setting("parry_stagger", ParryRules.UNIVERSAL_PARRY_STAGGER_DURATION)
	clash_latched = true
	thrust_left = 0.0
	blade_length = 76.0
	var incoming_direction: Vector2 = (player_end - player_start).normalized()
	var incoming_angle: float = incoming_direction.angle()
	var side: float = sign((global_position - player_start).cross(incoming_direction))
	if side == 0.0: side = 1.0
	locked_blade_angle = incoming_angle + side * PI * 0.5
	blade_angle = locked_blade_angle
	var parry_recoil: float = _combat_setting("parry_enemy_recoil", 180.0)
	knockback += player_ref.global_position.direction_to(global_position) * parry_recoil
	if incoming_velocity.length_squared() > 0.01:
		knockback += incoming_velocity.normalized() * (20.0 if contact_preset >= 2 else 35.0)

func _segments_close(start_a: Vector2, end_a: Vector2, start_b: Vector2, end_b: Vector2, threshold: float) -> bool:
	if _segments_intersect(start_a, end_a, start_b, end_b): return true
	var nearest: float = minf(minf(_distance_to_segment(start_a, start_b, end_b), _distance_to_segment(end_a, start_b, end_b)), minf(_distance_to_segment(start_b, start_a, end_a), _distance_to_segment(end_b, start_a, end_a)))
	return nearest <= threshold

func _segments_intersect(start_a: Vector2, end_a: Vector2, start_b: Vector2, end_b: Vector2) -> bool:
	var first: Vector2 = end_a - start_a
	var second: Vector2 = end_b - start_b
	var denominator: float = first.cross(second)
	if absf(denominator) < 0.0001: return false
	var delta: Vector2 = start_b - start_a
	var t: float = delta.cross(second) / denominator
	var u: float = delta.cross(first) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _closest_point_on_segment(point: Vector2, start: Vector2, end: Vector2) -> Vector2:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001: return start
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return start + segment * factor

func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared < 0.001: return point.distance_to(start)
	var factor: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * factor)

func play_impact_deformation(impact_velocity: Vector2, duration: float, compression: float, spring_overshoot: float) -> void:
	impact_deformation_direction = impact_velocity.normalized() if impact_velocity.length_squared() > 0.001 else Vector2.RIGHT
	impact_deformation_duration = maxf(duration, 0.001)
	impact_deformation_left = impact_deformation_duration
	impact_deformation_compression = maxf(0.0, compression)
	impact_deformation_overshoot = maxf(0.0, spring_overshoot)
	queue_redraw()

func _impact_draw_transform() -> Transform2D:
	if impact_deformation_left <= 0.0: return Transform2D.IDENTITY
	var progress: float = 1.0 - impact_deformation_left / maxf(impact_deformation_duration, 0.001)
	var deformation_amount: float = 0.0
	if progress < 0.55:
		deformation_amount = lerpf(impact_deformation_compression, 0.0, progress / 0.55)
	else:
		var spring_progress: float = (progress - 0.55) / 0.45
		deformation_amount = -impact_deformation_overshoot * sin(spring_progress * PI)
	var impact_axis: Vector2 = impact_deformation_direction
	var perpendicular_axis: Vector2 = impact_axis.orthogonal()
	var impact_scale: float = 1.0 - deformation_amount
	var perpendicular_scale: float = 1.0 + deformation_amount * 0.75
	var x_axis: Vector2 = impact_axis * (impact_scale * impact_axis.x) + perpendicular_axis * (perpendicular_scale * perpendicular_axis.x)
	var y_axis: Vector2 = impact_axis * (impact_scale * impact_axis.y) + perpendicular_axis * (perpendicular_scale * perpendicular_axis.y)
	return Transform2D(x_axis, y_axis, Vector2.ZERO)

func _facing_impact_draw_transform(facing_scale: Vector2) -> Transform2D:
	var facing_transform: Transform2D = Transform2D(Vector2(facing_scale.x, 0.0), Vector2(0.0, facing_scale.y), Vector2.ZERO)
	return _impact_draw_transform() * facing_transform

signal defeated(points: int)

func take_damage(amount: float, force: Vector2 = Vector2.ZERO, stagger_duration: float = 0.18, impact_quality: float = 0.0) -> void:
	var actual_damage: float = minf(health, maxf(0.0, amount))
	health = maxf(0.0, health - actual_damage)
	var main_scene: Node = get_tree().current_scene
	if actual_damage > 0.0 and main_scene != null and main_scene.has_method("record_damage_dealt"): main_scene.record_damage_dealt(actual_damage)
	if actual_damage > 0.0 and main_scene != null and main_scene.has_method("spawn_damage_number"):
		main_scene.spawn_damage_number(global_position, actual_damage, false, impact_quality)
	if main_scene != null and main_scene.has_method("play_sfx"): main_scene.play_sfx("enemy_hit", 0.75)
	health_bar.value = health
	health_bar.visible = health < max_health
	knockback += force
	stun_left = maxf(stun_left, stagger_duration)
	if health <= 0.0 and not death_emitted:
		death_emitted = true
		defeated.emit(score_value)
		if not bool(get_meta("training_no_drops", false)) and main_scene.has_method("try_spawn_drop"):
			main_scene.try_spawn_drop(global_position, self)
		queue_free()
	queue_redraw()

func apply_voltage(rank_value: int) -> void:
	electrified_left = maxf(electrified_left, BonusConfig.voltage_duration(rank_value))
	electrified_tick_interval = BonusConfig.voltage_tick_interval(rank_value)
	electrified_stun_chance = BonusConfig.voltage_stun_chance(rank_value)
	electrified_stun_duration = BonusConfig.voltage_stun_duration(rank_value)
	electrified_tick = minf(electrified_tick, electrified_tick_interval)
	queue_redraw()

func apply_burn(rank_value: int) -> void:
	burning_left = maxf(burning_left, BonusConfig.burn_duration(rank_value))
	burning_tick_interval = BonusConfig.burn_tick_interval(rank_value)
	burning_damage_per_tick = BonusConfig.burn_damage_per_tick(rank_value)
	burning_tick = minf(burning_tick, BonusConfig.burn_initial_tick_delay(rank_value))
	queue_redraw()

func stun_for(duration: float) -> void:
	stun_left = maxf(stun_left, duration)
	frost_mark_left = maxf(frost_mark_left, duration)
	locked_blade_angle = blade_angle
	queue_redraw()

func apply_void_pull(direction: Vector2, amount: float) -> void:
	knockback += direction * amount

func apply_grapple_force(acceleration: Vector2, delta: float, speed_cap: float = INF, slide_fraction: float = 0.0) -> void:
	# Grapple tension/yank composes with AI motion through the knockback channel.
	var impulse: Vector2 = acceleration * maxf(delta, 0.0)
	knockback += impulse
	# A small slower-decaying tail makes a yank disturb footing without stunning.
	grapple_slide_velocity += impulse * clampf(slide_fraction, 0.0, 0.25)
	if is_finite(speed_cap):
		knockback = knockback.limit_length(maxf(0.0, speed_cap))
		grapple_slide_velocity = grapple_slide_velocity.limit_length(maxf(0.0, speed_cap) * 0.25)

func try_disarm(chance: float) -> void:
	if not moving_weapon_enabled or disarmed: return
	if randf() < chance:
		disarmed = true
		disarm_flash_left = 0.55
		disarm_weapon_angle = blade_angle
		stun_left = maxf(stun_left, 0.35)
		clash_latched = false
		queue_redraw()

func get_contact_damage() -> float: return contact_damage

func _draw_wild_turkey() -> void:
	var facing: Vector2 = global_position.direction_to(player_ref.global_position) if player_ref != null else Vector2.RIGHT
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing.x < 0.0 else Vector2.ONE
	draw_set_transform_matrix(_facing_impact_draw_transform(facing_scale))
	var feather_outline: Color = Color("30233b")
	var tail_colors: Array[Color] = [Color("5b315b"), Color("75405f"), Color("9b563f"), Color("c27843")]
	# Fan tail: layered vector feathers, deliberately oversized for a readable silhouette.
	for feather_index: int in range(4):
		var feather_x: float = -22.0 - float(feather_index) * 5.0
		var feather_height: float = 27.0 + absf(1.5 - float(feather_index)) * 5.0
		var feather: PackedVector2Array = PackedVector2Array([
			Vector2(-4.0, 5.0), Vector2(feather_x, -feather_height), Vector2(feather_x - 8.0, 0.0), Vector2(feather_x, feather_height), Vector2(-4.0, 12.0)
		])
		draw_colored_polygon(feather, tail_colors[feather_index])
		draw_polyline(PackedVector2Array([feather[0], feather[1], feather[2], feather[3], feather[4]]), feather_outline, 2.0, true)
	# Dark rounded body and bronze wing.
	draw_circle(Vector2.ZERO, 17.0, feather_outline)
	draw_circle(Vector2(2.0, 0.0), 14.0, Color("49304e"))
	draw_circle(Vector2(-2.0, 5.0), 9.0, Color("a65f3f"))
	draw_arc(Vector2(-2.0, 4.0), 10.0, 0.25, 2.65, 12, Color("d58a4c"), 3.0, true)
	# Head, beak, wattle, and bright eye.
	draw_circle(Vector2(14.0, -8.0), 9.0, feather_outline)
	draw_circle(Vector2(15.0, -9.0), 7.0, Color("503b61"))
	draw_colored_polygon(PackedVector2Array([Vector2(20.0, -8.0), Vector2(32.0, -4.0), Vector2(20.0, -1.0)]), Color("d99a45"))
	draw_circle(Vector2(17.0, -11.0), 2.5, Color("f6e7a1"))
	draw_circle(Vector2(17.5, -11.0), 1.2, Color("261b2f"))
	draw_circle(Vector2(12.0, -1.0), 3.0, Color("c94c52"))
	# Little running legs reinforce the chaser silhouette.
	draw_line(Vector2(-2.0, 13.0), Vector2(-7.0, 23.0), Color("d99a45"), 3.0, true)
	draw_line(Vector2(7.0, 12.0), Vector2(12.0, 22.0), Color("d99a45"), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_wolf() -> void:
	var facing: Vector2 = global_position.direction_to(player_ref.global_position) if player_ref != null else Vector2.RIGHT
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing.x < 0.0 else Vector2.ONE
	draw_set_transform_matrix(_facing_impact_draw_transform(facing_scale))
	var outline: Color = Color("202733")
	var fur_dark: Color = Color("4b5663")
	var fur: Color = Color("788594") if windup <= 0.0 else Color("a84d4f")
	var fur_light: Color = Color("aab6bd") if windup <= 0.0 else Color("df7770")
	var muzzle: Color = Color("c2c8c8") if windup <= 0.0 else Color("ef9a88")
	var nose: Color = Color("1a1d26")
	var eye: Color = Color("f1c85b")
	# Chunky pixel silhouette: long back, raised haunch, lifted tail, and four sturdy legs.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-22.0, -7.0), Vector2(-16.0, -17.0), Vector2(2.0, -19.0),
		Vector2(15.0, -13.0), Vector2(18.0, 2.0), Vector2(11.0, 14.0),
		Vector2(-12.0, 15.0), Vector2(-24.0, 7.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-18.0, -6.0), Vector2(-13.0, -13.0), Vector2(1.0, -15.0),
		Vector2(12.0, -10.0), Vector2(14.0, 2.0), Vector2(8.0, 10.0),
		Vector2(-10.0, 11.0), Vector2(-20.0, 5.0)
	]), fur)
	# Dark swept tail with a small light edge so it reads cleanly at game scale.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15.0, -8.0), Vector2(-30.0, -18.0), Vector2(-35.0, -30.0),
		Vector2(-27.0, -25.0), Vector2(-18.0, -15.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-17.0, -9.0), Vector2(-28.0, -18.0), Vector2(-32.0, -25.0),
		Vector2(-25.0, -21.0), Vector2(-18.0, -13.0)
	]), fur_dark)
	draw_rect(Rect2(-12.0, -13.0, 13.0, 4.0), fur_light)
	# Rear and front legs use blocky joints rather than hair-thin lines.
	draw_rect(Rect2(-16.0, 8.0, 8.0, 17.0), outline)
	draw_rect(Rect2(-13.0, 9.0, 4.0, 14.0), fur_dark)
	draw_rect(Rect2(-4.0, 9.0, 8.0, 17.0), outline)
	draw_rect(Rect2(-1.0, 10.0, 4.0, 13.0), fur)
	draw_rect(Rect2(8.0, 7.0, 8.0, 18.0), outline)
	draw_rect(Rect2(10.0, 8.0, 4.0, 15.0), fur_dark)
	draw_rect(Rect2(-18.0, 22.0, 10.0, 5.0), outline)
	draw_rect(Rect2(-6.0, 23.0, 10.0, 5.0), outline)
	draw_rect(Rect2(6.0, 22.0, 11.0, 5.0), outline)
	# Wolf head, pointed ears, cheek ruff, and long muzzle.
	draw_colored_polygon(PackedVector2Array([
		Vector2(5.0, -13.0), Vector2(3.0, -31.0), Vector2(13.0, -23.0), Vector2(18.0, -12.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(8.0, -15.0), Vector2(7.0, -26.0), Vector2(12.0, -22.0), Vector2(15.0, -14.0)
	]), fur_dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18.0, -14.0), Vector2(20.0, -29.0), Vector2(27.0, -17.0), Vector2(27.0, -8.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(21.0, -15.0), Vector2(22.0, -24.0), Vector2(25.0, -17.0), Vector2(25.0, -10.0)
	]), fur)
	draw_colored_polygon(PackedVector2Array([
		Vector2(9.0, -13.0), Vector2(22.0, -15.0), Vector2(30.0, -7.0),
		Vector2(25.0, 2.0), Vector2(14.0, 3.0), Vector2(6.0, -3.0)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(12.0, -12.0), Vector2(21.0, -13.0), Vector2(27.0, -7.0),
		Vector2(23.0, -1.0), Vector2(14.0, 0.0), Vector2(9.0, -4.0)
	]), fur_light)
	draw_rect(Rect2(25.0, -6.0, 8.0, 5.0), muzzle)
	draw_rect(Rect2(31.0, -5.0, 4.0, 4.0), nose)
	draw_rect(Rect2(17.0, -10.0, 5.0, 4.0), fur_dark)
	draw_rect(Rect2(19.0, -10.0, 3.0, 3.0), eye)
	draw_rect(Rect2(20.0, -10.0, 1.5, 3.0), outline)
	# Lower jaw and a couple of square teeth reinforce the canine profile.
	draw_rect(Rect2(23.0, 0.0, 8.0, 3.0), outline)
	draw_rect(Rect2(25.0, 1.0, 2.0, 3.0), Color("e5e8df"))
	draw_rect(Rect2(29.0, 1.0, 2.0, 3.0), Color("e5e8df"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_flying_bug() -> void:
	var facing: Vector2 = global_position.direction_to(player_ref.global_position) if player_ref != null else Vector2.RIGHT
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing.x < 0.0 else Vector2.ONE
	draw_set_transform_matrix(_facing_impact_draw_transform(facing_scale))
	var outline: Color = Color("20263c")
	var shell: Color = Color("4e83d1")
	var wing: Color = Color(0.55, 0.85, 1.0, 0.5)
	# Translucent wings and antennae establish that this enemy is airborne.
	draw_colored_polygon(PackedVector2Array([Vector2(-2.0, -4.0), Vector2(-18.0, -24.0), Vector2(-25.0, -8.0), Vector2(-5.0, 2.0)]), wing)
	draw_colored_polygon(PackedVector2Array([Vector2(2.0, -4.0), Vector2(18.0, -24.0), Vector2(25.0, -8.0), Vector2(5.0, 2.0)]), wing)
	draw_polyline(PackedVector2Array([Vector2(-2.0, -4.0), Vector2(-18.0, -24.0), Vector2(-25.0, -8.0), Vector2(-5.0, 2.0)]), outline, 2.0, true)
	draw_polyline(PackedVector2Array([Vector2(2.0, -4.0), Vector2(18.0, -24.0), Vector2(25.0, -8.0), Vector2(5.0, 2.0)]), outline, 2.0, true)
	draw_circle(Vector2.ZERO, 12.0, outline)
	draw_circle(Vector2(2.0, 1.0), 9.0, shell)
	draw_circle(Vector2(10.0, -5.0), 7.0, outline)
	draw_circle(Vector2(12.0, -6.0), 4.0, Color("80d5e8"))
	draw_circle(Vector2(13.0, -7.0), 1.8, Color("f7f0a0"))
	draw_line(Vector2(13.0, -10.0), Vector2(22.0, -18.0), Color("a8d8e8"), 2.0, true)
	draw_line(Vector2(16.0, -8.0), Vector2(28.0, -10.0), Color("a8d8e8"), 2.0, true)
	draw_line(Vector2(-4.0, 10.0), Vector2(-9.0, 19.0), shell, 3.0, true)
	draw_line(Vector2(4.0, 10.0), Vector2(9.0, 19.0), shell, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_goblin() -> void:
	var facing: Vector2 = global_position.direction_to(player_ref.global_position) if player_ref != null else Vector2.RIGHT
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing.x < 0.0 else Vector2.ONE
	draw_set_transform_matrix(_facing_impact_draw_transform(facing_scale))
	var outline: Color = Color("172b25")
	var skin_dark: Color = Color("3f7a45")
	var skin: Color = Color("65ad55")
	var skin_light: Color = Color("9bd35b")
	var tunic: Color = Color("5b8741")
	var leather: Color = Color("553b37")
	# Hunched goblin ears and head.
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, -13.0), Vector2(-27.0, -22.0), Vector2(-18.0, -5.0)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-9.0, -12.0), Vector2(-23.0, -19.0), Vector2(-17.0, -7.0)]), skin_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(8.0, -13.0), Vector2(27.0, -22.0), Vector2(18.0, -4.0)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(9.0, -12.0), Vector2(23.0, -19.0), Vector2(17.0, -7.0)]), skin)
	draw_circle(Vector2.ZERO, 17.0, outline)
	draw_circle(Vector2(2.0, -2.0), 14.0, skin)
	draw_rect(Rect2(-10.0, -15.0, 18.0, 4.0), skin_light)
	draw_rect(Rect2(-8.0, -9.0, 17.0, 5.0), outline)
	draw_rect(Rect2(-5.0, -8.0, 5.0, 2.0), Color("e2f28a"))
	draw_rect(Rect2(7.0, -8.0, 4.0, 3.0), Color("e2f28a"))
	draw_rect(Rect2(12.0, -1.0, 7.0, 4.0), skin_light)
	draw_rect(Rect2(14.0, 2.0, 5.0, 3.0), outline)
	# Ragged tunic and little legs.
	draw_colored_polygon(PackedVector2Array([Vector2(-14.0, 7.0), Vector2(13.0, 7.0), Vector2(17.0, 19.0), Vector2(8.0, 16.0), Vector2(2.0, 21.0), Vector2(-7.0, 17.0), Vector2(-16.0, 20.0)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-11.0, 8.0), Vector2(10.0, 8.0), Vector2(13.0, 16.0), Vector2(6.0, 14.0), Vector2(1.0, 18.0), Vector2(-6.0, 14.0), Vector2(-13.0, 17.0)]), tunic)
	draw_rect(Rect2(-10.0, 6.0, 19.0, 4.0), leather)
	draw_rect(Rect2(-3.0, 6.0, 4.0, 4.0), Color("d19b45"))
	draw_rect(Rect2(-10.0, 17.0, 8.0, 5.0), outline)
	draw_rect(Rect2(4.0, 16.0, 9.0, 5.0), outline)
	draw_rect(Rect2(-11.0, 21.0, 10.0, 3.0), leather)
	draw_rect(Rect2(3.0, 20.0, 11.0, 3.0), leather)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ogre() -> void:
	var facing: Vector2 = global_position.direction_to(player_ref.global_position) if player_ref != null else Vector2.RIGHT
	var facing_scale: Vector2 = Vector2(-1.0, 1.0) if facing.x < 0.0 else Vector2.ONE
	draw_set_transform_matrix(_facing_impact_draw_transform(facing_scale))
	var charging_warning: bool = windup > 0.0
	var warning_pulse: float = 0.72 + sin(Time.get_ticks_msec() * 0.025) * 0.18
	var outline: Color = Color("381b25") if charging_warning else Color("172b45")
	var blue_shadow: Color = Color("8f2736").lerp(Color("d83a43"), warning_pulse) if charging_warning else Color("315a83")
	var blue: Color = Color("c8323c").lerp(Color("ff5148"), warning_pulse) if charging_warning else Color("4f8fba")
	var blue_light: Color = Color("ff7465").lerp(Color("ffd0b0"), warning_pulse) if charging_warning else Color("83c5d1")
	var belt: Color = Color("573b49")
	# Wide shoulders, belly, and heavy legs sell the ogre silhouette.
	draw_colored_polygon(PackedVector2Array([Vector2(-29.0, -4.0), Vector2(-22.0, -17.0), Vector2(22.0, -17.0), Vector2(30.0, -4.0), Vector2(25.0, 17.0), Vector2(15.0, 25.0), Vector2(-15.0, 25.0), Vector2(-25.0, 16.0)]), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-24.0, -3.0), Vector2(-18.0, -14.0), Vector2(18.0, -14.0), Vector2(25.0, -3.0), Vector2(20.0, 15.0), Vector2(12.0, 20.0), Vector2(-12.0, 20.0), Vector2(-20.0, 14.0)]), blue)
	draw_circle(Vector2(-13.0, -12.0), 11.0, blue_shadow)
	draw_circle(Vector2(13.0, -12.0), 11.0, blue_shadow)
	# Head, brow, ears, tusks.
	draw_circle(Vector2(0.0, -16.0), 19.0, outline)
	draw_circle(Vector2(1.0, -17.0), 15.0, blue)
	draw_rect(Rect2(-18.0, -23.0, 6.0, 10.0), blue_shadow)
	draw_rect(Rect2(15.0, -23.0, 6.0, 10.0), blue_shadow)
	draw_rect(Rect2(-10.0, -20.0, 21.0, 5.0), blue_shadow)
	draw_rect(Rect2(-8.0, -19.0, 5.0, 3.0), Color("e5f08e"))
	draw_rect(Rect2(5.0, -19.0, 5.0, 3.0), Color("e5f08e"))
	draw_rect(Rect2(-7.0, -10.0, 17.0, 4.0), outline)
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(-3.0, -1.0), Vector2(0.0, -8.0)]), blue_light)
	draw_colored_polygon(PackedVector2Array([Vector2(3.0, -8.0), Vector2(8.0, -1.0), Vector2(11.0, -8.0)]), blue_light)
	# Belly highlight, belt, fists, and boots.
	draw_circle(Vector2(3.0, 4.0), 13.0, blue_light)
	draw_rect(Rect2(-18.0, 8.0, 39.0, 6.0), belt)
	draw_rect(Rect2(-2.0, 8.0, 6.0, 6.0), Color("d3a24c"))
	draw_circle(Vector2(-24.0, 4.0), 8.0, outline)
	draw_circle(Vector2(-24.0, 3.0), 6.0, blue)
	draw_circle(Vector2(24.0, 4.0), 8.0, outline)
	draw_circle(Vector2(24.0, 3.0), 6.0, blue)
	draw_rect(Rect2(-17.0, 18.0, 13.0, 8.0), outline)
	draw_rect(Rect2(7.0, 18.0, 14.0, 8.0), outline)
	draw_rect(Rect2(-20.0, 24.0, 16.0, 5.0), belt)
	draw_rect(Rect2(6.0, 24.0, 17.0, 5.0), belt)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_concrete_body() -> void:
	draw_circle(Vector2.ZERO, 16.0, remnant_color)
	draw_circle(Vector2(-5, -3), 3.0, Color("ff5260"))
	draw_circle(Vector2(5, -3), 3.0, Color("ff5260"))

func _draw() -> void:
	if not _is_hd_visual():
		draw_set_transform_matrix(_impact_draw_transform())
		_draw_concrete_body()
		# Weapons, shields, and status overlays stay rigid so the body alone sells the impact.
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		draw_set_transform_matrix(Transform2D.IDENTITY)
	if shield_enabled:
		var shield_direction: Vector2 = Vector2.RIGHT.rotated(shield_angle)
		var shield_tangent: Vector2 = shield_direction.orthogonal()
		var is_bashing: bool = shield_bash_left > 0.0
		var bash_extension: float = elite_shield_bash_extension if is_bashing else 0.0
		var shield_center: Vector2 = shield_direction * (elite_shield_distance + bash_extension)
		var shield_half_width: float = elite_shield_half_width + 7.0
		var shield_depth: float = 10.0
		var shield_outline: PackedVector2Array = PackedVector2Array([
			shield_center - shield_tangent * shield_half_width - shield_direction * shield_depth,
			shield_center + shield_tangent * shield_half_width - shield_direction * shield_depth,
			shield_center + shield_tangent * (shield_half_width - 5.0) + shield_direction * shield_depth,
			shield_center + shield_direction * (shield_depth + 5.0),
			shield_center - shield_tangent * (shield_half_width - 5.0) + shield_direction * shield_depth
		])
		var shield_face: PackedVector2Array = PackedVector2Array([
			shield_center - shield_tangent * (shield_half_width - 4.0) - shield_direction * (shield_depth - 3.0),
			shield_center + shield_tangent * (shield_half_width - 4.0) - shield_direction * (shield_depth - 3.0),
			shield_center + shield_tangent * (shield_half_width - 8.0) + shield_direction * (shield_depth - 1.0),
			shield_center + shield_direction * shield_depth,
			shield_center - shield_tangent * (shield_half_width - 8.0) + shield_direction * (shield_depth - 1.0)
		])
		draw_colored_polygon(shield_outline, Color("172b45"))
		draw_colored_polygon(shield_face, Color("6b4d43"))
		# Blue ogre paint and a crude center boss tie the shield to the Elite's palette.
		draw_line(shield_center - shield_tangent * (shield_half_width - 7.0) - shield_direction * 1.0, shield_center + shield_tangent * (shield_half_width - 7.0) - shield_direction * 1.0, Color("4f8fba"), 5.0, true)
		draw_line(shield_center - shield_direction * 5.0, shield_center + shield_direction * 8.0, Color("315a83"), 4.0, true)
		draw_line(shield_center - shield_tangent * 5.0, shield_center + shield_tangent * 5.0, Color("315a83"), 4.0, true)
		draw_circle(shield_center, 6.0, Color("d3a24c"))
		draw_circle(shield_center, 3.0, Color("e8d283"))
		if is_bashing:
			var bash_alpha: float = clampf(shield_bash_left / 0.22, 0.0, 1.0)
			var bash_normal: Vector2 = shield_direction.orthogonal()
			for bash_index: int in range(3):
				var bash_offset: float = (float(bash_index) - 1.0) * 15.0
				var bash_start: Vector2 = shield_center - shield_direction * (24.0 + float(bash_index) * 7.0) + bash_normal * bash_offset
				var bash_end: Vector2 = bash_start - shield_direction * (20.0 + float(bash_index) * 8.0)
				draw_line(bash_start, bash_end, Color(0.55, 0.8, 0.95, bash_alpha * 0.75), 3.0, true)
			draw_arc(shield_center + shield_direction * 8.0, 23.0, shield_angle - 0.9, shield_angle + 0.9, 14, Color(0.55, 0.8, 0.95, bash_alpha * 0.8), 3.0, true)
	elif spear_visual_enabled and not disarmed:
		var spear_direction: Vector2 = Vector2.RIGHT.rotated(blade_angle)
		var spear_start: Vector2 = spear_direction * weapon_origin_offset
		var spear_end: Vector2 = spear_start + spear_direction * (blade_length + 14.0)
		draw_line(spear_start, spear_end, Color("3c2b2d"), 5.0, true)
		draw_line(spear_start, spear_end, Color("9a6748"), 3.0, true)
		var spear_tip: Vector2 = spear_end + spear_direction * 12.0
		var spear_tangent: Vector2 = spear_direction.orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([spear_end + spear_tangent, spear_tip, spear_end - spear_tangent]), Color("dce8f2"))
		draw_line(spear_end + spear_tangent, spear_tip, Color("7f9eb4"), 2.0, true)
	if electrified_left > 0.0:
		for arc_index: int in range(3):
			var arc_angle: float = float(arc_index) * 2.1 + frost_spark_time * 4.0
			var arc_start: Vector2 = Vector2.RIGHT.rotated(arc_angle) * 12.0
			var arc_end: Vector2 = Vector2.RIGHT.rotated(arc_angle + 0.7) * 23.0
			draw_line(arc_start, arc_end, Color(0.45, 0.85, 1.0, 0.9), 2.5, true)
	if burning_left > 0.0:
		draw_circle(Vector2(0, 3), 20.0, Color(1.0, 0.2, 0.03, 0.22))
		draw_circle(Vector2(0, -17.0 - sin(frost_spark_time * 8.0) * 3.0), 3.5, Color(1.0, 0.55, 0.08, 0.9))
	draw_moving_weapon_combat_fx()
	if frost_mark_left > 0.0:
		var frost_alpha: float = clampf(frost_mark_left / 0.8, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 18.0, Color(0.2, 0.75, 1.0, frost_alpha * 0.42))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color(0.35, 0.9, 1.0, frost_alpha * 0.9), 2.5, true)
		for spark_index: int in range(6):
			var spark_angle: float = float(spark_index) * TAU / 6.0 + frost_spark_time * 2.5
			var spark_radius: float = 22.0 + sin(frost_spark_time * 8.0 + float(spark_index)) * 3.0
			var spark_position: Vector2 = Vector2.RIGHT.rotated(spark_angle) * spark_radius
			draw_circle(spark_position, 2.5, Color(0.65, 0.95, 1.0, frost_alpha))
			draw_line(spark_position - Vector2(0.0, 4.0), spark_position + Vector2(0.0, 4.0), Color(0.8, 1.0, 1.0, frost_alpha * 0.7), 1.5, true)
	if disarm_flash_left > 0.0:
		var weapon_direction: Vector2 = Vector2.RIGHT.rotated(disarm_weapon_angle)
		var weapon_fade: float = disarm_flash_left / 0.55
		draw_line(weapon_direction * 22.0, weapon_direction * (58.0 + (1.0 - weapon_fade) * 18.0), Color(0.85, 0.9, 0.95, weapon_fade), 6.0, true)
	if dizzy_stars_left > 0.0:
		_draw_dizzy_stars()

func draw_moving_weapon_combat_fx() -> void:
	## Shared presentation for every independently moving weapon. Call only from
	## the owner's _draw() notification; bosses with custom drawing call this too.
	if not moving_weapon_enabled:
		return
	if slide_flash_left > 0.0:
		var slide_alpha: float = clampf(slide_flash_left / maxf(slide_visual_duration, 0.001), 0.0, 1.0)
		var slide_progress: float = clampf(slide_visual_time / maxf(slide_visual_duration, 0.001), 0.0, 1.0)
		var slide_direction: Vector2 = Vector2.RIGHT.rotated(blade_angle)
		var slide_normal: Vector2 = slide_direction.orthogonal()
		var contact_distance: float = clampf(weapon_origin_offset + slide_contact_distance, weapon_origin_offset, weapon_origin_offset + blade_length)
		var travel_amount: float = _combat_setting("slide_travel", ParryRules.SLIDE_SPARK_TRAVEL_DISTANCE)
		var travel_offset: float = slide_travel_direction * lerpf(-travel_amount, travel_amount, slide_progress)
		var spark_distance: float = clampf(contact_distance + travel_offset, weapon_origin_offset, weapon_origin_offset + blade_length)
		var spark_center: Vector2 = slide_direction * spark_distance
		var flare_pulse: float = 0.85 + sin(Time.get_ticks_msec() * 0.04) * 0.15
		draw_circle(spark_center, 12.0 * flare_pulse, Color(1.0, 0.75, 0.2, slide_alpha * 0.35))
		draw_circle(spark_center, 5.0 * flare_pulse, Color(1.0, 0.98, 0.9, slide_alpha * 0.90))
		var streak_start: Vector2 = slide_direction * maxf(weapon_origin_offset, contact_distance - 12.0)
		var streak_end: Vector2 = slide_direction * minf(weapon_origin_offset + blade_length, contact_distance + 12.0)
		draw_line(streak_start, streak_end, Color(1.0, 0.95, 0.8, slide_alpha), ParryRules.SLIDE_BLADE_FLASH_WIDTH + 1.0, true)
		var spark_count: int = int(_core_setting("slide_sparks", ParryRules.SLIDE_SPARK_COUNT))
		for spark_index: int in range(spark_count):
			var side: float = 1.0 if spark_index % 2 == 0 else -1.0
			var spread: float = float((spark_index % 3) + 1) / 3.0 * _combat_setting("slide_spread", ParryRules.SLIDE_SPARK_SPREAD) * side
			var spark_position: Vector2 = spark_center + slide_normal * spread
			var spark_direction: Vector2 = (-slide_direction * 0.65 + slide_normal * side * 0.75).normalized()
			var spark_length: float = 10.0 + float(spark_index % 3) * 4.0 + slide_progress * 6.0
			draw_line(spark_position, spark_position + spark_direction * spark_length, Color(1.0, 0.38, 0.08, slide_alpha * 0.85), 2.2, true)
			draw_line(spark_position, spark_position + spark_direction * (spark_length * 0.55), Color(1.0, 0.95, 0.85, slide_alpha), 1.2, true)
	if debug_draw_weapon_collision:
		var debug_weapon: Dictionary = _enemy_weapon_segment()
		var debug_start: Vector2 = (debug_weapon["start"] as Vector2) - global_position
		var debug_end: Vector2 = (debug_weapon["end"] as Vector2) - global_position
		var debug_tolerance: float = ParryRules.UNIVERSAL_PARRY_CONTACT_TOLERANCE
		draw_line(debug_start, debug_end, Color(1.0, 0.15, 0.15, 0.75), debug_tolerance * 2.0, true)
		draw_line(debug_start, debug_end, Color(1.0, 0.85, 0.25, 0.95), 3.0, true)
		draw_circle(debug_start, 5.0, Color(0.3, 0.8, 1.0, 0.9))
	if parry_flash > 0.0:
		var parry_alpha: float = parry_flash / 0.45
		draw_circle(Vector2.ZERO, 27.0, Color(0.2, 0.8, 1.0, parry_alpha * 0.18))
		draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 32, Color(0.45, 0.95, 1.0, parry_alpha), 4.0, true)
		for parry_index: int in range(4):
			var parry_angle: float = float(parry_index) * TAU / 4.0 + (1.0 - parry_alpha) * 0.8
			var parry_direction: Vector2 = Vector2.RIGHT.rotated(parry_angle)
			draw_line(parry_direction * 30.0, parry_direction * 42.0, Color(0.7, 1.0, 1.0, parry_alpha), 3.0, true)

func _draw_dizzy_stars() -> void:
	var alpha: float = clampf(dizzy_stars_left / 0.25, 0.0, 1.0)
	var head_center: Vector2 = Vector2(0.0, -22.0)
	var ellipse_rx: float = 16.0
	var ellipse_ry: float = 6.0
	var star_color: Color = Color(1.0, 0.90, 0.22, alpha)
	var wing_color: Color = Color(1.0, 1.0, 0.75, alpha * 0.9)
	# Draw 3 orbiting stars with flapping birdie wings
	for i: int in range(3):
		var star_angle: float = float(i) * (TAU / 3.0) + dizzy_stars_time * 5.5
		var star_pos: Vector2 = head_center + Vector2(cos(star_angle) * ellipse_rx, sin(star_angle) * ellipse_ry)
		# 4-point golden star
		var star_r: float = 3.5
		draw_line(star_pos - Vector2(star_r, 0.0), star_pos + Vector2(star_r, 0.0), star_color, 1.8, true)
		draw_line(star_pos - Vector2(0.0, star_r), star_pos + Vector2(0.0, star_r), star_color, 1.8, true)
		draw_circle(star_pos, 1.3, Color(1.0, 1.0, 0.85, alpha))
		# Birdie fluttering wings (flaps with sin of dizzy_stars_time)
		var flap: float = sin(dizzy_stars_time * 18.0 + float(i) * 2.0) * 3.0
		var wing_span: float = 3.5
		draw_line(star_pos, star_pos + Vector2(-wing_span, -2.5 + flap), wing_color, 1.2, true)
		draw_line(star_pos, star_pos + Vector2(wing_span, -2.5 + flap), wing_color, 1.2, true)
