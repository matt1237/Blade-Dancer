class_name WaveSpawner extends Node2D

const WARNING_SCENE: PackedScene = preload("res://scenes/spawn_warning.tscn")
const TURKEY_SCENE: PackedScene = preload("res://scenes/enemies/turkey.tscn")
const GOBLIN_SCENE: PackedScene = preload("res://scenes/enemies/goblin.tscn")
const BUG_SCENE: PackedScene = preload("res://scenes/enemies/bug.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/enemies/wolf.tscn")
const OGRE_SCENE: PackedScene = preload("res://scenes/enemies/ogre.tscn")
@export_category("Wave Pacing")
## Dedicated Forest Wave 20 boss scene.
@export var boss_scene: PackedScene
## References are normally filled automatically from Main.
@export var player_ref: Player
@export var terrain_generator: ArenaGenerator
## Number of enemies in Wave 1.
@export var base_enemy_count: int = 5
## Additional enemies added to later waves.
@export var enemies_per_wave: int = 3
## Seconds between the end of one Forest wave and the next wave beginning.
@export var wave_interval: float = 20.0
## Short between-wave interval used only by the Backyard production-spawner test.
@export var training_wave_interval: float = 5.0
## Delay between the warning appearing and the enemy arriving.
@export var spawn_delay: float = 0.4
## Length of Wave 1, giving new players time to settle into the sword rhythm.
@export var wave_duration_start: float = 30.0
## Additional seconds added to each later wave.
@export var wave_duration_step: float = 5.0
## Maximum length of a wave, preventing endless late-game scaling.
@export var wave_duration_max: float = 60.0
## Direct, non-cumulative stat increase applied to health and damage per wave.
@export_range(0.0, 0.1, 0.005) var enemy_stat_bonus_per_wave: float = 0.01

@export_category("Spawn Composition")
## Chance to ignore population balancing and choose any currently available type.
## Keep this low so compositions stay balanced without becoming perfectly predictable.
@export_range(0.0, 1.0, 0.01) var spawn_balance_randomness: float = 0.12
## Random composition is disabled until this many enemies are already alive.
@export var spawn_randomness_min_alive: int = 5
## Extra interior clearance used when Chasm is active. This is measured from
## the live Chasm wall centerlines, so enemies never appear behind the border.
@export var chasm_spawn_clearance: float = 52.0

var chasm_stage: ChasmStage = null
var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_alive: int = 0
var wave_timer: float = 20.0
var wave_elapsed: float = 0.0
var wave_duration: float = 30.0
var spawn_timer: float = 0.0
var wave_active: bool = false
var awaiting_next_wave: bool = false
var boss_active: bool = false
## Backyard can run this exact production spawner without granting drops or progression.
var training_mode: bool = false
var tutorial_turkey_mode: bool = false
@export var tutorial_turkey_max_alive: int = 3
@export var tutorial_turkey_spawn_interval: float = 2.0
## Hard gate used by boss encounters so queued warnings and ordinary wave slots cannot leak into the fight.
var normal_spawning_suspended: bool = false

signal wave_started(number: int)
signal boss_wave_started(number: int)
signal boss_wave_cleared(number: int)
signal wave_cleared(number: int)
signal enemy_defeated(points: int)
signal enemy_defeated_with_identity(enemy_identity: StringName, points: int)

func set_chasm_stage(stage: ChasmStage) -> void:
	chasm_stage = stage

func stat_multiplier_for_wave(wave_number: int) -> float:
	var wave_steps: int = maxi(0, wave_number)
	return 1.0 + float(wave_steps) * maxf(0.0, enemy_stat_bonus_per_wave)

func _ready() -> void:
	if player_ref == null: player_ref = get_parent().get_node_or_null("Player") as Player
	if terrain_generator == null: terrain_generator = get_parent().get_node_or_null("ArenaGenerator") as ArenaGenerator
	current_wave = 1
	enemies_to_spawn = base_enemy_count
	enemies_alive = 0
	wave_duration = wave_duration_start
	wave_elapsed = 0.0
	wave_active = true
	spawn_timer = 0.0

func _process(delta: float) -> void:
	if tutorial_turkey_mode:
		spawn_timer -= delta
		if spawn_timer <= 0.0 and _count_living_turkeys() < tutorial_turkey_max_alive:
			_create_warning()
			spawn_timer = tutorial_turkey_spawn_interval
		return
	if normal_spawning_suspended:
		return
	if wave_active:
		wave_elapsed += delta
		spawn_timer -= delta
		if enemies_to_spawn > 0 and spawn_timer <= 0.0:
			enemies_to_spawn -= 1
			enemies_alive += 1
			spawn_timer = wave_duration / float(base_enemy_count + (current_wave - 1) * enemies_per_wave)
			var alive_count: int = _count_alive_enemies()
			if alive_count >= 9:
				spawn_timer *= 4.0  # 25 % rate — nearly stalled
			elif alive_count >= 5:
				spawn_timer *= 2.0  # 50 % rate
			_create_warning()
		if wave_elapsed >= wave_duration and not boss_active:
			for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy_node): enemy_node.queue_free()
			for warning_node: Node in get_tree().get_nodes_in_group("spawn_warnings"):
				if is_instance_valid(warning_node): warning_node.queue_free()
			enemies_to_spawn = 0
			enemies_alive = 0
			wave_active = false
			wave_cleared.emit(current_wave)
			if training_mode:
				awaiting_next_wave = false
				wave_timer = training_wave_interval
			else:
				awaiting_next_wave = true
				wave_timer = -1.0
	elif not awaiting_next_wave:
		wave_timer -= delta
		if wave_timer <= 0.0: _start_wave()

func begin_tutorial_turkeys() -> void:
	tutorial_turkey_mode = true
	training_mode = false
	normal_spawning_suspended = false
	spawn_timer = 0.0
	set_process(true)

func end_tutorial_turkeys() -> void:
	tutorial_turkey_mode = false
	normal_spawning_suspended = true
	set_process(false)
	for warning_node: Node in get_tree().get_nodes_in_group("spawn_warnings"):
		if is_instance_valid(warning_node) and bool(warning_node.get_meta("wave_spawner_warning", false)):
			warning_node.queue_free()

func _count_living_turkeys() -> int:
	var count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.death_emitted and enemy.spawn_identity == &"turkey":
			count += 1
	return count

func begin_training_test() -> void:
	training_mode = true
	normal_spawning_suspended = false
	boss_active = false
	current_wave = 1
	enemies_to_spawn = base_enemy_count
	enemies_alive = 0
	wave_duration = wave_duration_start
	wave_elapsed = 0.0
	spawn_timer = 0.0
	wave_timer = wave_interval
	wave_active = true
	awaiting_next_wave = false
	set_process(true)

func end_training_test() -> void:
	training_mode = false
	set_process(false)
	for warning_node: Node in get_tree().get_nodes_in_group("spawn_warnings"):
		if is_instance_valid(warning_node) and bool(warning_node.get_meta("wave_spawner_warning", false)):
			warning_node.queue_free()

func continue_to_next_wave() -> void:
	if awaiting_next_wave:
		awaiting_next_wave = false
		wave_timer = 0.0

func complete_boss_wave() -> void:
	if not boss_active: return
	boss_active = false
	normal_spawning_suspended = false
	awaiting_next_wave = true
	wave_active = false
	boss_wave_cleared.emit(current_wave)
	wave_cleared.emit(current_wave)

func _start_wave() -> void:
	current_wave += 1
	enemies_to_spawn = base_enemy_count + (current_wave - 1) * enemies_per_wave
	enemies_alive = 0
	wave_duration = minf(wave_duration_start + float(current_wave - 1) * wave_duration_step, wave_duration_max)
	wave_elapsed = 0.0
	wave_active = true
	spawn_timer = 0.0
	wave_started.emit(current_wave)
	if current_wave == ZungarConfig.BOSS_WAVE and not training_mode:
		boss_active = true
		normal_spawning_suspended = true
		enemies_to_spawn = 0
		for warning_node: Node in get_tree().get_nodes_in_group("spawn_warnings"):
			if is_instance_valid(warning_node): warning_node.queue_free()
		boss_wave_started.emit(current_wave)

func _create_warning() -> void:
	var spawn_position: Vector2 = _random_position()
	if spawn_position.x < 0.0:
		# Never force an unsafe spawn. Return this slot to the queue and retry shortly.
		enemies_to_spawn += 1
		enemies_alive = maxi(0, enemies_alive - 1)
		spawn_timer = minf(spawn_timer, 0.25)
		push_warning("Enemy spawn postponed because no terrain-safe point was available.")
		return
	var warning: SpawnWarning = WARNING_SCENE.instantiate() as SpawnWarning
	warning.set_meta("wave_spawner_warning", true)
	warning.global_position = spawn_position
	warning.finished.connect(_spawn_enemy)
	get_parent().add_child(warning)

func _random_position() -> Vector2:
	var spawn_rect: Rect2 = terrain_generator.config.arena_rect if terrain_generator != null and terrain_generator.config != null else Rect2(0.0, 0.0, 1280.0, 720.0)
	if chasm_stage != null:
		var chasm_rect: Rect2 = chasm_stage.get_spawn_rect()
		if chasm_rect.size.x > 0.0 and chasm_rect.size.y > 0.0:
			spawn_rect = chasm_rect
	for attempt: int in range(20):
		var candidate_position: Vector2 = Vector2(randf_range(spawn_rect.position.x + 48.0, spawn_rect.end.x - 48.0), randf_range(spawn_rect.position.y + 48.0, spawn_rect.end.y - 48.0))
		if _spawn_position_is_safe(candidate_position): return candidate_position
	# A deterministic grid search replaces the old unchecked random fallback.
	var fallback_candidates: Array[Vector2] = []
	for y: int in range(int(spawn_rect.position.y) + 48, int(spawn_rect.end.y) - 47, 48):
		for x: int in range(int(spawn_rect.position.x) + 48, int(spawn_rect.end.x) - 47, 48):
			var fallback_position: Vector2 = Vector2(float(x), float(y))
			if _spawn_position_is_safe(fallback_position): fallback_candidates.append(fallback_position)
	if not fallback_candidates.is_empty(): return fallback_candidates[randi_range(0, fallback_candidates.size() - 1)]
	return Vector2(-1.0, -1.0)

func _spawn_position_is_safe(candidate_position: Vector2) -> bool:
	var player_clear: bool = player_ref != null and candidate_position.distance_to(player_ref.global_position) > 180.0
	var terrain_clear: bool = terrain_generator != null and terrain_generator.is_position_clear(candidate_position, 52.0)
	var chasm_clear: bool = chasm_stage == null or chasm_stage.is_spawn_position_valid(candidate_position, chasm_spawn_clearance)
	return player_clear and terrain_clear and chasm_clear

func _spawn_enemy(spawn_position: Vector2) -> void:
	if normal_spawning_suspended and not training_mode:
		return
	if chasm_stage != null and not chasm_stage.is_spawn_position_valid(spawn_position, chasm_spawn_clearance):
		push_warning("Enemy spawn cancelled because the Chasm perimeter changed before warning completion.")
		return
	var selected_scene: PackedScene = TURKEY_SCENE if tutorial_turkey_mode else _choose_enemy_scene()
	var enemy: Enemy = instantiate_enemy(selected_scene)
	if enemy == null: return
	enemy.wave_stat_multiplier = stat_multiplier_for_wave(current_wave)
	enemy.global_position = spawn_position
	if training_mode:
		enemy.set_meta("training_no_drops", true)
	enemy.tree_exited.connect(_enemy_died)
	if not training_mode and not tutorial_turkey_mode:
		enemy.defeated.connect(_on_enemy_defeated)
		enemy.defeated.connect(_on_enemy_defeated_with_identity.bind(enemy.spawn_identity))
	get_parent().add_child(enemy)

func instantiate_enemy(scene: PackedScene) -> Enemy:
	return scene.instantiate() as Enemy if scene != null else null

func scene_for_name(enemy_name: StringName) -> PackedScene:
	match enemy_name:
		&"turkey", &"chaser": return TURKEY_SCENE
		&"goblin", &"duelist": return GOBLIN_SCENE
		&"bug", &"ranged": return BUG_SCENE
		&"wolf", &"charger": return WOLF_SCENE
		&"ogre", &"elite": return OGRE_SCENE
		_: return null

func spawn_boss_reinforcement(scene: PackedScene, spawn_position: Vector2) -> Enemy:
	if not boss_active:
		return null
	var enemy: Enemy = instantiate_enemy(scene)
	if enemy == null:
		return null
	enemy.wave_stat_multiplier = stat_multiplier_for_wave(current_wave)
	enemy.global_position = spawn_position
	enemy.set_meta("zungar_summon", true)
	get_parent().add_child(enemy)
	enemy.add_to_group("zungar_summons")
	enemy.defeated.connect(_on_enemy_defeated)
	return enemy

func _available_enemy_scenes() -> Array[PackedScene]:
	var available: Array[PackedScene] = [TURKEY_SCENE]
	if current_wave >= 2: available.append(GOBLIN_SCENE)
	if current_wave >= 3: available.append(BUG_SCENE)
	if current_wave >= 4: available.append(WOLF_SCENE)
	if current_wave >= 5: available.append(OGRE_SCENE)
	return available

func _scene_balance_key(scene: PackedScene) -> StringName:
	if scene == TURKEY_SCENE: return &"turkey"
	if scene == GOBLIN_SCENE: return &"goblin"
	if scene == BUG_SCENE: return &"bug"
	if scene == WOLF_SCENE: return &"wolf"
	if scene == OGRE_SCENE: return &"ogre"
	return StringName(scene.resource_path) if scene != null else &""

func _choose_enemy_scene() -> PackedScene:
	var available: Array[PackedScene] = _available_enemy_scenes()
	if available.size() == 1: return available[0]
	if randf() < spawn_balance_randomness:
		return available[randi_range(0, available.size() - 1)]
	var alive_counts: Dictionary[StringName, int] = {}
	for scene: PackedScene in available:
		alive_counts[_scene_balance_key(scene)] = 0
	var total_living_enemies: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var living_enemy: Enemy = enemy_node as Enemy
		if living_enemy == null or not is_instance_valid(living_enemy) or living_enemy.death_emitted: continue
		total_living_enemies += 1
		var key: StringName = living_enemy.spawn_balance_key()
		if alive_counts.has(key): alive_counts[key] += 1
	if total_living_enemies >= spawn_randomness_min_alive and randf() < spawn_balance_randomness:
		return available[randi_range(0, available.size() - 1)]
	var lowest_alive_count: int = 2147483647
	var least_represented: Array[PackedScene] = []
	for scene: PackedScene in available:
		var key: StringName = _scene_balance_key(scene)
		var alive_count: int = alive_counts[key]
		if alive_count < lowest_alive_count:
			lowest_alive_count = alive_count
			least_represented = [scene]
		elif alive_count == lowest_alive_count:
			least_represented.append(scene)
	return least_represented[randi_range(0, least_represented.size() - 1)]

func _on_enemy_defeated(points: int) -> void:
	enemy_defeated.emit(points)

func _on_enemy_defeated_with_identity(points: int, enemy_identity: StringName) -> void:
	enemy_defeated_with_identity.emit(enemy_identity, points)

func _enemy_died() -> void:
	enemies_alive = maxi(0, enemies_alive - 1)

func _count_alive_enemies() -> int:
	var count: int = 0
	for enemy_node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = enemy_node as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.death_emitted:
			count += 1
	return count
