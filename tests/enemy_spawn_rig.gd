class_name EnemySpawnRig extends Node
## Auto-spawning enemy test rig — a one-`run_scene` combat bench.
##
## Instances the REAL `res://scenes/main.tscn` and drives it into the Backyard training
## run (the same entry the Backyard tuner uses), so the real Player, WaveSpawner,
## CombatPresentationFX, blood decals, health bars, and audio all run. It then spawns
## `enemy_type` at a fixed distance from the player and logs what happened, so a single
## live run answers: did the enemy spawn, did its health bar appear and drain, did blood
## spray, did the death cry play.
##
## This exists because testing combat used to require the dev to take over and navigate
## the menu to an enemy that may never spawn on its own. Pick the enemy in
## res://tests/enemy_spawn_rig.tscn (or leave it "random") and run that scene.
##
## TEST RIG ONLY: it never writes saves or global presets. Live keys while running:
##   ] / Right   spawn the next enemy type      [ / Left   spawn the previous type
##   K           kill every spawned enemy (real death FX + cry)
##   L           force a status line             space     damage every spawn a little

const TYPE_ORDER: Array[String] = [
	"turkey", "goblin", "archer_goblin", "sword_goblin", "bug", "wolf", "ogre"
]
const ENEMY_SCENES: Dictionary = {
	"turkey": WaveSpawner.TURKEY_SCENE,
	"goblin": WaveSpawner.GOBLIN_SCENE,
	"archer_goblin": WaveSpawner.ARCHER_GOBLIN_SCENE,
	"sword_goblin": WaveSpawner.SWORD_GOBLIN_SCENE,
	"bug": WaveSpawner.BUG_SCENE,
	"wolf": WaveSpawner.WOLF_SCENE,
	"ogre": WaveSpawner.OGRE_SCENE
}
const RANDOM_TYPE: String = "random"
const ZUNGAR_TYPE: String = "zungar"
const STATUS_INTERVAL: float = 2.5
const MAX_READY_FRAMES: int = 120

@export_group("Spawn")
## turkey, goblin, archer_goblin, sword_goblin, bug, wolf, ogre, "random", or "zungar".
@export var enemy_type: String = "turkey"
## How many of that enemy to spawn up front.
@export var spawn_count: int = 3
## Spawn offset to the player's right, so the follow camera already frames it.
@export var spawn_distance: float = 150.0
## Settling time after the backyard run starts, before the first spawn.
@export var startup_delay: float = 0.4
## Drive a synthetic blade sweep through one spawned enemy's core and report what the
## contact did. Off by default so the rig stays a clean arena to actually fight in.
@export var probe_bone_slide: bool = false
## Hold a synthetic blade on one spawned enemy's core across real physics frames and report
## what the shell bodies did. A shell can only show what it does across real physics steps, so
## this one runs over time rather than in a single frame. Off by default.
@export var probe_physics_shells: bool = false

@export_group("Auto Damage")
## Poke the enemies on a timer so health bars, blood, and death FX run unattended.
@export var auto_damage: bool = false
@export var auto_damage_amount: float = 25.0
@export var auto_damage_interval: float = 1.2

var _main: Main = null
var _tracked: Array[Enemy] = []
var _kills: int = 0
var _alive_type: String = "turkey"
var _status_clock: float = 0.0
var _damage_timer: Timer = null
var _shell_probe_enemy: Enemy = null
var _shell_probe_start: Vector2 = Vector2.ZERO
var _shell_probe_frames: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_main = get_parent() as Main
	if _main == null:
		push_error("EnemySpawnRig must be a child of Main: instance res://scenes/main.tscn as this scene's root.")
		return
	if not await _wait_for_main():
		push_error("EnemySpawnRig gave up waiting for Main to finish booting.")
		return
	_main.call("_start_backyard_run")
	_close_tuner()
	_build_damage_timer()
	if startup_delay > 0.0:
		await get_tree().create_timer(startup_delay).timeout
	spawn_now()
	await get_tree().process_frame
	await get_tree().process_frame
	if probe_bone_slide:
		_run_bone_slide_probe()
	if probe_physics_shells:
		_run_physics_shells_probe()
		_run_wall_block_probe()

func _process(delta: float) -> void:
	if _main == null:
		return
	_status_clock += delta
	if _status_clock >= STATUS_INTERVAL:
		_status_clock = 0.0
		_log_status()
	if _shell_probe_enemy != null:
		_step_physics_shells_probe(delta)
	if not _wall_probe_slabs.is_empty():
		_step_wall_block_probe(delta)

## Physics Shells probe, set-up half. A shell can only show what it does across real physics
## steps, so unlike the bone-slide probe this one holds a synthetic blade on one enemy's core
## for a run of frames and reports what the bodies actually did. Read the [SHELLS PROBE] lines.
func _run_physics_shells_probe() -> void:
	var player: Player = _player()
	var scene: PackedScene = _scene_for("sword_goblin")
	if player == null or scene == null:
		print("[SHELLS PROBE] missing player or enemy scene")
		return
	_main.call("_spawn_training_enemy_at", player.global_position + Vector2(120.0, -6.0), scene)
	_track_new_enemies()
	var alive: Array[Enemy] = _alive_enemies()
	if alive.is_empty():
		print("[SHELLS PROBE] no enemy spawned")
		return
	_shell_probe_enemy = alive[alive.size() - 1]
	_shell_probe_start = _shell_probe_enemy.global_position
	_shell_probe_frames = 0
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_core_size_percent", 35.0)
	player.set_combat_contact_setting("blade_bone_debug_enabled", 1.0)
	player.set_combat_contact_setting("bone_core_shell_enabled", 1.0)
	player.set_combat_contact_setting("blade_shell_shove_enabled", 1.0)
	player.set_combat_contact_setting("blade_shell_deflect_enabled", 0.0)
	player.set_combat_contact_setting("blade_shell_query_enabled", 1.0)
	player.set_combat_contact_setting("blade_body_block_enabled", 1.0)
	print("[SHELLS PROBE] start enemy=%s at %s" % [str(_shell_probe_enemy.spawn_identity), str(_shell_probe_start)])

## Physics Shells probe, per-frame half. The blade is driven two pixels INSIDE the enemy's core
## every frame, so the two shells are genuinely in contact rather than merely adjacent. Phase 1
## is the shove shell pushing the core off its authored pose while the core springs back; phase
## 2 hands the contact to deflection, where the blade's own solid yields instead; phase 3 turns
## everything off and checks that nothing at all is left behind in the world.
## Wall Block probe. This one needs no enemy at all, which is the point: it builds two slabs of
## level on the terrain collision layer just outside the player's body but well inside the
## blade's reach, turns Wall Block on, and then lets the player's own swings do the rest. Watch
## for [WALL BLOCK] lines in the output and the [WALL PROBE] report underneath.
var _wall_probe_slabs: Array[StaticBody2D] = []
var _wall_probe_frames: int = 0
var _wall_probe_blocked_frames: int = 0
var _wall_probe_peak_glance: float = 0.0
var _wall_probe_surfaced_frames: int = 0
var _wall_probe_peak_surface: float = 0.0

func _run_wall_block_probe() -> void:
	var player: Player = _player()
	if player == null:
		print("[WALL PROBE] no player")
		return
	player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_debug_enabled", 1.0)
	# Clean constraint measurement: every competitor for the blade angle stands down, so what the
	# log shows is the solver, the true contact duration and why the shove was released.
	player.set_combat_contact_setting("blade_wall_block_enabled", 0.0)
	player.set_combat_contact_setting("blade_body_surface_enabled", 0.0)
	player.set_combat_contact_setting("blade_hard_clash_enabled", 0.0)
	player.set_combat_contact_setting("blade_bone_constraint_enabled", 1.0)
	player.set_combat_contact_setting("blade_bone_debug_enabled", 1.0)
	var placements: Array = [
		[Vector2(55.0, 35.0), Vector2(56.0, 56.0)],
		[Vector2(95.0, 62.0), Vector2(56.0, 56.0)]
	]
	for placement: Array in placements:
		var slab: StaticBody2D = StaticBody2D.new()
		slab.name = "WallProbeSlab"
		slab.collision_layer = PhysicsShell.WORLD_LAYER
		slab.collision_mask = 0
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var box: RectangleShape2D = RectangleShape2D.new()
		box.size = placement[1] as Vector2
		shape_node.shape = box
		slab.add_child(shape_node)
		player.get_parent().add_child(slab)
		slab.global_position = player.global_position + (placement[0] as Vector2)
		_wall_probe_slabs.append(slab)
	_wall_probe_frames = 0
	_wall_probe_blocked_frames = 0
	_wall_probe_peak_glance = 0.0
	# An enemy right on top of the player, so the real swings are guaranteed to overlap a body and
	# Blade Meets Bodies actually has something to refuse. Without this the probe depends on where
	# the spawned enemy happens to wander, which is how an earlier run proved nothing at all.
	var enemy_scene: PackedScene = _scene_for("turkey")
	if enemy_scene != null:
		_main.call("_spawn_training_enemy_at", player.global_position + Vector2(46.0, 0.0), enemy_scene)
		_track_new_enemies()
		print("[WALL PROBE] spawned a turkey 46 px from the player so the body surface has a body to refuse")
	print("[WALL PROBE] %d slabs on layer %d around the player, wall block on" % [_wall_probe_slabs.size(), PhysicsShell.WORLD_LAYER])

func _step_wall_block_probe(_delta: float) -> void:
	var player: Player = _player()
	if player == null:
		return
	_wall_probe_frames += 1
	if player.blade_wall_glance_angle != 0.0:
		_wall_probe_blocked_frames += 1
		_wall_probe_peak_glance = maxf(_wall_probe_peak_glance, absf(rad_to_deg(player.blade_wall_glance_angle)))
	if player.blade_body_surface_offset.length() > 0.01:
		_wall_probe_surfaced_frames += 1
		_wall_probe_peak_surface = maxf(_wall_probe_peak_surface, player.blade_body_surface_offset.length())
	if _wall_probe_frames % 10 == 0:
		var samples: PackedVector2Array = player.current_blade_samples
		var contact: Dictionary = {}
		if samples.size() >= 2:
			contact = player._blade_wall_contact(samples[0], samples[samples.size() - 1])
		var broad_hits: int = -1
		var world: World2D = player.get_world_2d()
		if world != null and world.direct_space_state != null:
			var broad_shape: CircleShape2D = CircleShape2D.new()
			broad_shape.radius = 200.0
			var broad_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
			broad_query.shape = broad_shape
			broad_query.transform = Transform2D(0.0, player.global_position)
			broad_query.collision_mask = PhysicsShell.WORLD_LAYER
			broad_hits = world.direct_space_state.intersect_shape(broad_query, 8).size()
		var slab_pos: String = "none"
		if not _wall_probe_slabs.is_empty() and is_instance_valid(_wall_probe_slabs[0]):
			slab_pos = str(_wall_probe_slabs[0].global_position)
		var blade_tip: String = "none" if samples.is_empty() else str(samples[samples.size() - 1])
		print("[WALL PROBE] frame %d: samples=%d tip=%s touching_level=%s wall_glance=%.1f swing_hold=%.2f body_surface=%.1f px terrain_within_200px=%d slab0=%s player=%s" % [
			_wall_probe_frames,
			samples.size(),
			blade_tip,
			str(not contact.is_empty()),
			rad_to_deg(player.blade_wall_glance_angle),
			player.blade_core_yield_pending,
			player.blade_body_surface_offset.length(),
			broad_hits,
			slab_pos,
			str(player.global_position)])
	if _wall_probe_frames == 300:
		for slab: StaticBody2D in _wall_probe_slabs:
			if is_instance_valid(slab):
				slab.queue_free()
		_wall_probe_slabs.clear()
		print("[WALL PROBE] done: frames_blocked=%d peak_glance=%.1f deg frames_surfaced=%d peak_surface=%.1f px" % [_wall_probe_blocked_frames, _wall_probe_peak_glance, _wall_probe_surfaced_frames, _wall_probe_peak_surface])

func _step_physics_shells_probe(delta: float) -> void:
	var player: Player = _player()
	if player == null or not is_instance_valid(_shell_probe_enemy):
		_shell_probe_enemy = null
		return
	_shell_probe_frames += 1
	if _shell_probe_frames == 1:
		var first_core: PhysicsShell = _shell_probe_enemy.bone_core_shell
		var engine_contact: Dictionary = player._engine_core_contact(_shell_probe_enemy.global_position)
		print("[SHELLS PROBE] setup: enemy_reads_core_switch=%.1f core_shell=%s layer=%d mask=%d shapes=%d query_found=%s query_normal=%s" % [
			_shell_probe_enemy._combat_setting("bone_core_shell_enabled", 0.0),
			"yes" if first_core != null else "no",
			0 if first_core == null else first_core.collision_layer,
			0 if first_core == null else first_core.collision_mask,
			0 if first_core == null else first_core.get_child_count(),
			str(not engine_contact.is_empty()),
			str(engine_contact.get("normal", Vector2.ZERO))])
	if _shell_probe_frames == 60:
		player.set_combat_contact_setting("blade_shell_shove_enabled", 0.0)
		player.set_combat_contact_setting("blade_shell_deflect_enabled", 1.0)
		print("[SHELLS PROBE] phase 2: deflection on")
	if _shell_probe_frames == 120:
		player.set_combat_contact_setting("blade_shell_deflect_enabled", 0.0)
		player.set_combat_contact_setting("full_physical_enabled", 1.0)
		print("[SHELLS PROBE] phase 3: FULL PHYSICAL on (solid sword, whole-outline enemies)")
	if _shell_probe_frames == 180:
		player.set_combat_contact_setting("bone_core_shell_enabled", 0.0)
		player.set_combat_contact_setting("blade_shell_shove_enabled", 0.0)
		player.set_combat_contact_setting("blade_shell_deflect_enabled", 0.0)
		player.set_combat_contact_setting("full_physical_enabled", 0.0)
		print("[SHELLS PROBE] phase 4: all shells off")
	var centre: Vector2 = _shell_probe_enemy.global_position
	var push: Vector2 = (centre - player.global_position).normalized() * 2.0
	var half: float = 46.0
	player._update_blade_shell(centre - Vector2(half, 0.0) + push, centre + Vector2(half, 0.0) + push, delta)
	if _shell_probe_frames % 10 == 0 or _shell_probe_frames >= 180:
		var core_shell: PhysicsShell = _shell_probe_enemy.bone_core_shell
		var core_deviation: float = 0.0
		var mirror_radius: float = 0.0
		if core_shell != null and is_instance_valid(core_shell):
			core_deviation = core_shell.deviation_offset().length()
			if core_shell.get_child_count() > 0:
				var probe_shape: Shape2D = (core_shell.get_child(0) as CollisionShape2D).shape
				if probe_shape is CircleShape2D:
					mirror_radius = (probe_shape as CircleShape2D).radius
		var leftovers: int = 0
		for parent: Node in [player.get_parent(), _shell_probe_enemy.get_parent()]:
			if parent == null:
				continue
			for child: Node in parent.get_children():
				if child.name == "BladeShell" or child.name == "BoneCoreShell":
					leftovers += 1
		var leash_now: float = -1.0
		var frozen_now: bool = false
		var springs_now: bool = true
		var custom_now: bool = false
		var shell_pos: Vector2 = Vector2.ZERO
		if core_shell != null and is_instance_valid(core_shell):
			leash_now = core_shell.max_deviation
			frozen_now = core_shell.freeze
			springs_now = core_shell.springs_enabled
			custom_now = core_shell.custom_integrator
			shell_pos = core_shell.global_position
		print("[SHELLS PROBE] f=%d core_dev=%.1fpx blade_off=%.1fpx blade_ang=%.1fdeg mirror_r=%.1f shell_nodes=%d leash=%.1f frozen=%s springs=%s custom=%s enemy=%s shell=%s" % [
			_shell_probe_frames,
			core_deviation,
			player.blade_shell_offset.length(),
			rad_to_deg(player.blade_shell_angle),
			mirror_radius,
			leftovers,
			leash_now,
			str(frozen_now),
			str(springs_now),
			str(custom_now),
			str(_shell_probe_enemy.global_position),
			str(shell_pos)])
	if _shell_probe_frames >= 200:
		_shell_probe_enemy = null

## Wait until Main has finished its own _ready wiring. The rig is a child node, so its
## _ready runs BEFORE Main's; a couple of frames is the existing harness idiom, but poll
## for the real nodes so a slower boot cannot make the rig drive a half-built Main.
func _wait_for_main() -> bool:
	for _frame: int in range(MAX_READY_FRAMES):
		await get_tree().process_frame
		if _main.get("player") != null and _main.get("spawner") != null and _main.get("home_menu") != null:
			return true
	return false

## The backyard run opens the tuning panel; hide it so a screenshot shows the arena.
func _close_tuner() -> void:
	var menu: Node = _main.get("backyard_training_menu")
	if menu == null:
		return
	if menu.has_method("close"):
		menu.call("close")
	if menu is CanvasItem:
		(menu as CanvasItem).visible = false

func _build_damage_timer() -> void:
	_damage_timer = Timer.new()
	_damage_timer.name = "AutoDamageTimer"
	_damage_timer.one_shot = false
	_damage_timer.wait_time = maxf(auto_damage_interval, 0.05)
	_damage_timer.autostart = auto_damage
	_damage_timer.timeout.connect(_poke_enemies)
	add_child(_damage_timer)

## Spawn `spawn_count` enemies of `enemy_type` right now, going through Main's own
## training-spawn routine so the spawn path is the real one.
func spawn_now() -> void:
	if _main == null:
		return
	_alive_type = _resolve_type(enemy_type)
	var count: int = maxi(spawn_count, 1)
	for index: int in range(count):
		var stack_offset: float = (float(index) - (float(count) - 1.0) * 0.5) * 90.0
		_spawn_one(Vector2(spawn_distance, stack_offset))
	_track_new_enemies()

func _spawn_one(offset: Vector2) -> void:
	var player: Player = _player()
	if player == null:
		push_error("EnemySpawnRig found no player to spawn near.")
		return
	if _alive_type == ZUNGAR_TYPE:
		_main.call("spawn_training_zungar")
		return
	var scene: PackedScene = _scene_for(_alive_type)
	if scene == null:
		push_error("EnemySpawnRig has no scene for enemy_type '%s'." % enemy_type)
		return
	_main.call("_spawn_training_enemy_at", player.global_position + offset, scene)

func _resolve_type(requested: String) -> String:
	var key: String = requested.strip_edges().to_lower()
	if key == ZUNGAR_TYPE or ENEMY_SCENES.has(key):
		return key
	if key != RANDOM_TYPE and not key.is_empty():
		push_warning("EnemySpawnRig: unknown enemy_type '%s' — rolling a random enemy instead." % requested)
	return TYPE_ORDER[randi() % TYPE_ORDER.size()]

func _scene_for(type_name: String) -> PackedScene:
	if not ENEMY_SCENES.has(type_name):
		return null
	return ENEMY_SCENES[type_name] as PackedScene

## Discover enemies that entered the tree through Main's spawn routine and take a
## reference, so the rig can report and drive them without owning the spawn.
func _track_new_enemies() -> void:
	var found: int = 0
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or _tracked.has(enemy):
			continue
		_tracked.append(enemy)
		enemy.defeated.connect(_on_enemy_defeated)
		found += 1
		print("[ENEMY RIG] spawn %s identity=%s hp=%.0f blood_tint=%s at %s" % [
			enemy.name, str(enemy.spawn_identity), enemy.max_health, str(enemy.blood_tint), str(enemy.global_position.round())
		])
	if found == 0 and _tracked.is_empty():
		push_warning("[ENEMY RIG] no enemy entered the tree for '%s'." % _alive_type)
		print("[ENEMY RIG] FAIL: '%s' produced no enemy in the tree." % _alive_type)

func _on_enemy_defeated(points: int) -> void:
	_kills += 1
	print("[ENEMY RIG] defeated %s (+%d points) kills=%d alive=%d" % [_alive_type, points, _kills, _alive_enemies().size()])

func _poke_enemies() -> void:
	var alive: Array[Enemy] = _alive_enemies()
	if alive.is_empty():
		return
	_apply_test_hit(alive[randi() % alive.size()], maxf(auto_damage_amount, 1.0))

## Damage + presentation through the same calls the player's sword makes, so the health
## bar, impact squash, blood spray, and death burst are the real ones.
func _apply_test_hit(enemy: Enemy, amount: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var player: Player = _player()
	var direction: Vector2 = Vector2.RIGHT
	if player != null:
		direction = enemy.global_position - player.global_position
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		direction = direction.normalized()
	var contact_point: Vector2 = enemy.global_position
	enemy.take_damage(amount, direction * 120.0, 0.18, 0.9)
	var killed: bool = enemy.health <= 0.0
	_main.call("spawn_enemy_hit_presentation", enemy, contact_point, direction * 560.0, direction, 0.9, killed, true, true)
	print("[ENEMY RIG] test hit %.0f on %s -> hp %.0f%s" % [amount, str(enemy.spawn_identity), enemy.health, " (KILL)" if killed else ""])
	_track_new_enemies()

## Bone Slide probe. The rig cannot swing the mouse, so this drives the real contact
## path directly: it spawns an enemy through Main's own training routine, then sweeps a
## pair of synthetic blade polylines clean through the enemy's centre and reports what
## the core contact did -- whether it registered, what the reaction maths returned, and
## what the pose angle reached one frame later. Read the [BONE SLIDE] lines with it.
func _run_bone_slide_probe() -> void:
	var player: Player = _player()
	var scene: PackedScene = _scene_for("sword_goblin")
	if player == null or scene == null:
		print("[BONE SLIDE PROBE] missing player or enemy scene")
		return
	print("[BONE SLIDE PROBE] player at %s" % str(player.global_position))
	for core_size: float in [100.0, 35.0]:
		_main.call("_spawn_training_enemy_at", player.global_position + Vector2(120.0, -6.0), scene)
		_track_new_enemies()
		var alive: Array[Enemy] = _alive_enemies()
		if alive.is_empty():
			print("[BONE SLIDE PROBE] core=%.0f%%: no enemy spawned" % core_size)
			continue
		var enemy: Enemy = alive[alive.size() - 1]
		player.set_combat_contact_setting("hit_reaction_enabled", 1.0)
		player.set_combat_contact_setting("blade_physical_reaction_enabled", 1.0)
		player.set_combat_contact_setting("blade_bone_slide_enabled", 1.0)
		player.set_combat_contact_setting("blade_bone_slide_strength", 100.0)
		player.set_combat_contact_setting("blade_bone_bind_enabled", 1.0)
		player.set_combat_contact_setting("blade_bone_bind_strength", 100.0)
		player.set_combat_contact_setting("blade_physical_reaction_strength", 85.0)
		player.set_combat_contact_setting("blade_bone_core_size_percent", core_size)
		player.set_combat_contact_setting("blade_bone_stop_enabled", 0.0)
		player.set_combat_contact_setting("blade_bone_debug_enabled", 1.0)
		var centre: Vector2 = enemy.global_position
		player.blade_glance_angle = 0.0
		player.bone_slide_left = 0.0
		player.previous_blade_samples = PackedVector2Array([centre + Vector2(-320.0, 0.0), centre + Vector2(-200.0, 0.0), centre + Vector2(-80.0, 0.0)])
		player.current_blade_samples = PackedVector2Array([centre + Vector2(80.0, 0.0), centre + Vector2(200.0, 0.0), centre + Vector2(320.0, 0.0)])
		player.blade_velocity = Vector2(600.0, 0.0)
		player._check_sword_hits(centre + Vector2(-80.0, 0.0), centre + Vector2(80.0, 0.0), 1.0 / 60.0)
		var latched: float = player.bone_slide_left
		player._update_sword(1.0 / 60.0)
		print("[BONE SLIDE PROBE] core=%.0f%%: latch=%.3f s, swing held to %.2f, enemy hp=%.0f" % [core_size, latched, player.bone_hold_multiplier, enemy.health])
		# Sustained contact: hold the blade on the core for a run of frames so the bind's
		# capture fills and the lock takes, then report the capture, the lock and the hold.
		var held_previous: PackedVector2Array = PackedVector2Array([centre + Vector2(-40.0, 0.0), centre, centre + Vector2(40.0, 0.0)])
		var held_current: PackedVector2Array = PackedVector2Array([centre + Vector2(-34.0, 0.0), centre + Vector2(6.0, 0.0), centre + Vector2(46.0, 0.0)])
		player.bone_slide_left = 0.0
		player.bone_bind_dwell = 0.0
		player.bone_bind_locked = false
		player.bone_hold_multiplier = 1.0
		for step: int in 8:
			player.previous_blade_samples = held_previous
			player.current_blade_samples = held_current
			player.blade_velocity = Vector2(600.0, 0.0)
			player._check_sword_hits(centre + Vector2(-40.0, 0.0), centre + Vector2(40.0, 0.0), 1.0 / 60.0)
			player._update_sword(1.0 / 60.0)
			print("[BONE BIND PROBE] core=%.0f%% step=%d dwell=%.3f locked=%s slide=%.3f hold=%.2f" % [core_size, step, player.bone_bind_dwell, str(player.bone_bind_locked), player.bone_slide_left, player.bone_hold_multiplier])
		enemy.queue_free()

func _kill_all() -> void:
	var alive: Array[Enemy] = _alive_enemies()
	for enemy: Enemy in alive:
		_apply_test_hit(enemy, 99999.0)
	print("[ENEMY RIG] killed %d enemy(ies)." % alive.size())

func _alive_enemies() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for enemy: Enemy in _tracked:
		if is_instance_valid(enemy) and not enemy.death_emitted and enemy.health > 0.0:
			result.append(enemy)
	return result

func _player() -> Player:
	if _main == null:
		return null
	return _main.get("player") as Player

func _log_status() -> void:
	var player: Player = _player()
	var health_text: String = "n/a" if player == null else "%.0f/%.0f" % [player.health, player.max_health]
	print("[ENEMY RIG] type=%s alive=%d kills=%d player_hp=%s" % [_alive_type, _alive_enemies().size(), _kills, health_text])

func _cycle_type(step: int) -> void:
	var index: int = TYPE_ORDER.find(_alive_type)
	if index < 0:
		index = 0
	var next_index: int = posmod(index + step, TYPE_ORDER.size())
	_alive_type = TYPE_ORDER[next_index]
	enemy_type = _alive_type
	spawn_count = 1
	spawn_now()
	_log_status()

func _unhandled_key_input(event: InputEvent) -> void:
	if _main == null or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_BRACKETRIGHT, KEY_RIGHT:
			_cycle_type(1)
		KEY_BRACKETLEFT, KEY_LEFT:
			_cycle_type(-1)
		KEY_K:
			_kill_all()
		KEY_L:
			_log_status()
		KEY_SPACE:
			_poke_enemies()
		_:
			return
	get_viewport().set_input_as_handled()