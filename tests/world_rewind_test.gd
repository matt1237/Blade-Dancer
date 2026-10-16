extends Node
## Stage 1 world rewind: CCW inward spiral (blue Guard) rewinds player + enemies + enemy
## projectiles; LMB+RMB early stop for both rewinds; retire/revive of entities. No Main, no saves.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/enemy_projectile.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	return player

func _arm(player: Player) -> void:
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true

func _enemy(scene: PackedScene, at: Vector2) -> Enemy:
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.global_position = at
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_meta("training_no_drops", true)
	return enemy

## Inward/outward spiral around (400,400). sweep < 0 = counter-clockwise on a y-down screen.
static func _spiral(turns: float = 2.0, r0: float = 130.0, r1: float = 35.0, start_angle: float = 0.3, steps: int = 72, direction: float = -1.0) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		var t: float = float(step) / float(steps)
		path.append(Vector2(400, 400) + Vector2.RIGHT.rotated(start_angle + direction * TAU * turns * t) * lerpf(r0, r1, t))
	return path

static func _circle(sweep: float = -TAU, radius: float = 110.0, steps: int = 36) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		path.append(Vector2(300, 300) + Vector2.RIGHT.rotated(-PI / 2.0 + sweep * float(step) / float(steps)) * radius)
	return path

## One 60 Hz frame of "world time": move the player and run `world_step`, then record.
func _tick(player: Player, frame: int, world_step: Callable) -> void:
	player.global_position = Vector2(100.0 + float(frame) * 100.0 / 60.0, 300.0)
	world_step.call(frame)
	player._record_rewind_sample(1.0 / 60.0)

func _play_out(player: Player) -> void:
	for _frame: int in range(400):
		if not player.rewind_active:
			return
		player._advance_rewind_playback(1.0 / 60.0)

func _cleanup_pause() -> void:
	get_tree().paused = false

# --- Gesture ------------------------------------------------------------------

func test_spiral_recognized_any_start_angle() -> void:
	for start: float in [0.0, 1.3, PI, -PI / 2.0, 4.0]:
		assert(Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 130.0, 35.0, start), 2.0), "CCW inward spiral from angle %f must qualify." % start)
	assert(Player.gesture_world_rewind_spiral_qualified(_spiral(1.7, 130.0, 30.0), 2.0), "1.7 turns tightening hard qualifies.")

func test_spiral_rejections() -> void:
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 130.0, 35.0, 0.3, 72, 1.0), 2.0), "Clockwise spiral rejected.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 35.0, 130.0), 2.0), "Outward spiral rejected.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(1.2, 130.0, 35.0), 2.0), "Under 1.5 turns rejected.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 130.0, 100.0), 2.0), "Barely tightening (77 %) rejected.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 50.0, 15.0), 2.0), "Too small rejected.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(), Player.WORLD_REWIND_SPIRAL_WINDOW + 0.1), "Must fit in 3 s.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_spiral(2.0, 130.0, 130.0), 2.0), "Constant-radius double loop is not a spiral.")

func test_circle_and_spiral_do_not_cross_trigger() -> void:
	assert(Player.gesture_rewind_circle_qualified(_circle(), 1.0), "Baseline circle still qualifies.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_circle(), 1.0), "Circle is not a spiral.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_circle(-TAU * 1.3), 1.0), "Even an over-drawn circle is not a spiral.")
	# The circle fires only once the hand settles, so what matters is the whole spiral at rest
	# (its first loop alone may look round; the live reader keeps waiting while it tightens).
	var spiral: PackedVector2Array = _spiral(2.0, 130.0, 35.0, -PI / 2.0, 72)
	assert(not Player.gesture_rewind_circle_qualified(spiral, 1.0), "A finished spiral must not read as the circle.")
	for length: int in range(48, spiral.size() + 1):
		assert(not Player.gesture_rewind_circle_qualified(spiral.slice(0, length), 1.0), "Spiral past 1⅓ turns (%d samples) read as the circle." % length)

func test_live_cursor_spiral_activates_world_rewind() -> void:
	var player: Player = _new_player()
	for frame: int in range(120):
		_tick(player, frame, func(_f: int) -> void: pass)
	_arm(player)
	var path: PackedVector2Array = _spiral(2.0, 130.0, 35.0, -PI / 2.0, 72)
	for point: Vector2 in path:
		player.charged_guard_gesture_cursor = point
		player._update_rewind_gesture(1.0 / 60.0)
		if player.rewind_active:
			break
	assert(player.rewind_active and player.rewind_world_active, "Drawn spiral activates the WORLD rewind, not the circle.")
	assert(not player.rewind_charge_available, "Spiral consumes the shared charge.")
	_play_out(player)
	_cleanup_pause()
	player.free()

func test_shared_charge_and_toggle() -> void:
	var player: Player = _new_player()
	for frame: int in range(60):
		_tick(player, frame, func(_f: int) -> void: pass)
	_arm(player)
	assert(player.activate_world_rewind())
	_play_out(player)
	_arm(player)
	assert(not player.can_activate_rewind() and not player.can_activate_world_rewind(), "Either gesture spends the single per-wave charge.")
	player.refill_rewind_charge()
	for frame: int in range(60):
		_tick(player, frame, func(_f: int) -> void: pass)
	_arm(player)
	assert(player.activate_rewind() and not player.rewind_world_active, "Circle stays player-only.")
	_play_out(player)
	_arm(player)
	assert(not player.can_activate_world_rewind(), "Circle spent the charge for the spiral too.")
	player.set_combat_contact_setting("world_rewind_gesture_enabled", 0.0)
	player.refill_rewind_charge()
	for frame: int in range(10):
		_tick(player, frame, func(_f: int) -> void: pass)
	_arm(player)
	assert(not player.can_activate_world_rewind() and player.can_activate_rewind(), "World toggle OFF only disables the spiral (world=%s circle=%s charge=%s guard=%s paused=%s n=%d)." % [player.can_activate_world_rewind(), player.can_activate_rewind(), player.rewind_charge_available, player._rewind_guard_ready(), get_tree().paused, player.rewind_buffer.count])
	assert(CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS.has("world_rewind_gesture_enabled"), "Persisted key.")
	assert(is_equal_approx(float(CombatSettingsConfig.built_in_contact_settings()["2"]["world_rewind_gesture_enabled"]), 1.0), "Default ON.")
	_cleanup_pause()
	player.free()

# --- Early stop -----------------------------------------------------------------

func _early_stop_case(world: bool) -> void:
	var player: Player = _new_player()
	var enemy: Enemy = _enemy(WaveSpawner.GOBLIN_SCENE, Vector2(600, 300))
	for frame: int in range(300):
		_tick(player, frame, func(f: int) -> void: enemy.global_position = Vector2(600.0 + float(f), 300.0))
	_arm(player)
	var head_x: float = player.global_position.x
	assert(player.activate_world_rewind() if world else player.activate_rewind())
	# The pair held at activation (or none) must be released first: a held pair never stops.
	assert(not player._rewind_early_stop_from_state(true, true), "Pair still held from before activation is ignored.")
	assert(not player._rewind_early_stop_from_state(false, false))
	for _frame: int in range(40):
		player._advance_rewind_playback(1.0 / 60.0)
	var mid_age: float = smoothstep(0.0, 1.0, player.rewind_playback_elapsed / player.rewind_playback_duration) * float(player.rewind_target_age)
	assert(mid_age > 5.0 and mid_age < float(player.rewind_target_age) - 5.0, "Mid-playback.")
	var expected_slot: int = player.rewind_buffer.slot(roundi(mid_age))
	var expected_player: Vector2 = player.rewind_buffer.positions[expected_slot]
	assert(player._rewind_early_stop_from_state(true, true), "Fresh LMB+RMB pair requests the stop.")
	player.rewind_target_age = clampi(roundi(mid_age), 0, player.rewind_target_age)
	player._finish_rewind()
	assert(not player.rewind_active and not get_tree().paused, "Stopped and resumed.")
	assert(player.global_position.distance_to(expected_player) < 12.0, "Player restored to the intermediate instant.")
	assert(player.global_position.x < head_x - 10.0 and player.global_position.x > 100.0 + 0.5 * 60.0, "Intermediate, not the full 4 s.")
	assert(not player.rewind_charge_available, "Charge spent even when stopped early.")
	if world:
		assert(enemy.global_position.x < 600.0 + 299.0 - 10.0 and enemy.global_position.x > 600.0 + 60.0, "Enemy restored to the same intermediate instant (x=%f)." % enemy.global_position.x)
	enemy.free()
	player.free()

func test_early_stop_world_rewind() -> void:
	await _early_stop_case(true)

func test_early_stop_player_rewind() -> void:
	await _early_stop_case(false)

func test_early_stop_runs_in_playback_and_does_not_reenter_guard() -> void:
	var player: Player = _new_player()
	for frame: int in range(200):
		_tick(player, frame, func(_f: int) -> void: pass)
	_arm(player)
	assert(player.activate_world_rewind())
	assert(not player.charged_guard_locked, "Activation spent the Guard.")
	player.rewind_early_stop_needs_release = false # buttons were released after activation
	# Simulate the playback frame reading the pair (the raw read wraps _rewind_early_stop_from_state).
	var source: String = (load("res://scripts/player.gd") as GDScript).source_code
	assert(source.contains("if progress < 1.0 and _rewind_early_stop_pressed():"), "Playback (runs while tree paused, Player ALWAYS) checks the pair.")
	player.rewind_target_age = 30
	player._finish_rewind()
	# Pair still physically held after the stop: latch prevents a Guard toggle on that press.
	player.charged_guard_dual_click_needs_release = true
	player.set_combat_contact_setting("charged_guard_enabled", 1.0)
	for _frame: int in range(30):
		player._update_charged_guard_dual_click_from_state(true, true, 1.0 / 60.0)
	assert(not player.charged_guard_locked, "The stopping press never re-enters Guard.")
	player._update_charged_guard_dual_click_from_state(false, false, 1.0 / 60.0)
	assert(not player.charged_guard_dual_click_needs_release, "Released pair clears the latch.")
	_cleanup_pause()
	player.free()

# --- World state ------------------------------------------------------------------

func test_enemy_state_restored_four_seconds_back() -> void:
	var player: Player = _new_player()
	var enemy: Enemy = _enemy(WaveSpawner.SWORD_GOBLIN_SCENE, Vector2(600, 300))
	var sword: SwordGoblin = enemy as SwordGoblin
	var at_target: Dictionary = {}
	for frame: int in range(360):
		_tick(player, frame, func(f: int) -> void:
			enemy.global_position = Vector2(600.0 + float(f), 300.0)
			enemy.health = enemy.max_health - float(f) * 0.05
			enemy.stun_left = float(f) * 0.001
			enemy.blade_angle = float(f) * 0.01
			enemy.fire_timer = 9.0 - float(f) * 0.01
			if sword != null:
				sword.lunge_cooldown_left = float(f) * 0.002
		)
	var target: int = player.rewind_buffer.slot(player.rewind_buffer.oldest_index_within(Player.REWIND_DURATION))
	var recorded_pos: Vector2 = player.rewind_buffer.positions[target]
	var frame_at_target: float = (recorded_pos.x - 100.0) * 0.6
	_arm(player)
	assert(player.activate_world_rewind())
	for _frame: int in range(30):
		player._advance_rewind_playback(1.0 / 60.0)
	assert(enemy.global_position.x < 600.0 + 359.0 - 5.0, "Enemy position moves backward during playback.")
	_play_out(player)
	assert(absf(enemy.global_position.x - (600.0 + frame_at_target)) < 1.5, "Enemy position ~4 s back (x=%f, want %f)." % [enemy.global_position.x, 600.0 + frame_at_target])
	assert(absf(enemy.health - (enemy.max_health - frame_at_target * 0.05)) < 0.2, "Enemy health restored.")
	assert(absf(enemy.blade_angle - frame_at_target * 0.01) < 0.02 and absf(enemy.fire_timer - (9.0 - frame_at_target * 0.01)) < 0.02, "Weapon phase / AI timers restored.")
	if sword != null:
		assert(absf(sword.lunge_cooldown_left - frame_at_target * 0.002) < 0.01, "Subclass extra state restored.")
	assert(enemy.knockback == Vector2.ZERO, "Transient knockback cleared.")
	_cleanup_pause()
	enemy.free()
	player.free()

func test_enemy_killed_in_window_revives_and_is_excluded_while_retired() -> void:
	var player: Player = _new_player()
	var spawner: WaveSpawner = WaveSpawner.new()
	add_child(spawner)
	spawner.set_process(false)
	var victim: Enemy = _enemy(WaveSpawner.GOBLIN_SCENE, Vector2(600, 300))
	var bystander: Enemy = _enemy(WaveSpawner.GOBLIN_SCENE, Vector2(700, 300))
	var health_at_kill_window: float = 0.0
	# Damaged before recording starts so the restore instant (up to REWIND_DURATION back) sees it.
	victim.health = victim.max_health * 0.6
	for frame: int in range(360):
		_tick(player, frame, func(f: int) -> void:
			if f == 300 and not victim.death_emitted:
				victim.take_damage(9999.0)
		)
	health_at_kill_window = victim.max_health * 0.6
	assert(is_instance_valid(victim) and victim.rewind_retired and not victim.is_queued_for_deletion(), "Death retires instead of freeing while a host records.")
	assert(not victim.visible and not victim.is_in_group("enemies"), "Retired: hidden and out of 'enemies'.")
	assert(spawner._count_alive_enemies() == 1, "Retired enemy excluded from alive counts.")
	var shaman: GoblinShaman = _enemy(WaveSpawner.GOBLIN_SHAMAN_SCENE, Vector2(650, 300)) as GoblinShaman
	assert(not shaman._allies().has(victim), "Retired enemy is not a Shaman heal target.")
	shaman.free()
	_arm(player)
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(not victim.rewind_retired and victim.visible and victim.is_in_group("enemies") and not victim.death_emitted, "Revived at restore.")
	assert(is_equal_approx(victim.health, health_at_kill_window), "Revived with captured health (%f)." % victim.health)
	await get_tree().process_frame
	assert(victim.process_mode == Node.PROCESS_MODE_INHERIT, "Processing re-enabled.")
	assert(spawner._count_alive_enemies() == 2, "Counts again after revive.")
	_cleanup_pause()
	spawner.free()
	victim.free()
	bystander.free()
	player.free()

func test_enemy_spawned_in_window_removed() -> void:
	var player: Player = _new_player()
	var holder: Array[Enemy] = []
	for frame: int in range(240):
		_tick(player, frame, func(f: int) -> void:
			if f == 200:
				holder.append(_enemy(WaveSpawner.TURKEY_SCENE, Vector2(500, 500)))
		)
	var late: Enemy = holder[0]
	_arm(player)
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(late.is_queued_for_deletion(), "Enemy that spawned after the restore instant is removed.")
	_cleanup_pause()
	await get_tree().process_frame
	player.free()

func test_projectiles_restored_and_removed() -> void:
	var player: Player = _new_player()
	var refs: Dictionary = {}
	for frame: int in range(260):
		_tick(player, frame, func(f: int) -> void:
			if f == 0:
				var shot: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
				shot.monitoring = false
				add_child(shot)
				shot.set_physics_process(false)
				shot.launch(Vector2.RIGHT)
				refs["early"] = shot
				var new_bomb: BomberBomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
				add_child(new_bomb)
				new_bomb.set_physics_process(false)
				new_bomb.arm(Vector2(0, 0), Vector2(900, 900), null)
				refs["bomb"] = new_bomb
			if f == 150:
				var late_shot: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
				late_shot.monitoring = false
				add_child(late_shot)
				late_shot.set_physics_process(false)
				refs["late"] = late_shot
			var e: EnemyProjectile = refs["early"]
			if not e.rewind_retired:
				e.global_position = Vector2(200.0 + float(f) * 3.0, 100.0)
				if f == 120:
					e._expire() # e.g. hit a wall
			var b: BomberBomb = refs["bomb"]
			if not b.rewind_retired:
				b.advance_attack(1.0 / 60.0)
		)
	var early: EnemyProjectile = refs["early"]
	var late: EnemyProjectile = refs["late"]
	var bomb: BomberBomb = refs["bomb"]
	assert(early.rewind_retired and not early.is_in_group("enemy_projectiles"), "Projectile expiry retires.")
	assert(bomb.rewind_retired, "Bomb finished its 3.45 s life inside the window and retired (phase=%d elapsed=%f host=%s)." % [bomb.phase, bomb.elapsed, WorldRewindRecorder.retire_enabled(bomb)])
	var target: int = player.rewind_buffer.slot(player.rewind_buffer.oldest_index_within(Player.REWIND_DURATION))
	var frame_at_target: float = (player.rewind_buffer.positions[target].x - 100.0) * 0.6
	_arm(player)
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(not early.rewind_retired and early.is_in_group("enemy_projectiles"), "Projectile revived.")
	assert(absf(early.global_position.x - (200.0 + frame_at_target * 3.0)) < 4.0, "Projectile position restored (x=%f)." % early.global_position.x)
	assert(not bomb.rewind_retired and bomb.phase != BomberBomb.Phase.FINISHED, "Bomb revived mid-life.")
	var expected_elapsed: float = (frame_at_target + 1.0) / 60.0
	assert(absf(bomb.elapsed - expected_elapsed) < 0.05, "Bomb phase timer restored (%f vs %f)." % [bomb.elapsed, expected_elapsed])
	assert(bomb.phase == (BomberBomb.Phase.WARNING if bomb.elapsed < BomberBomb.WARNING_TIME else (BomberBomb.Phase.FLIGHT if bomb.elapsed < BomberBomb.LAND_TIME else BomberBomb.Phase.FUSE)), "Bomb phase consistent with its clock.")
	assert(late.is_queued_for_deletion(), "Projectile fired after the restore instant is removed.")
	_cleanup_pause()
	early.free()
	bomb.free()
	await get_tree().process_frame
	player.free()

func test_retired_freed_after_window_and_main_clear_includes_retired() -> void:
	var player: Player = _new_player()
	var enemy: Enemy = _enemy(WaveSpawner.TURKEY_SCENE, Vector2(600, 300))
	for frame: int in range(10):
		_tick(player, frame, func(_f: int) -> void: pass)
	enemy.take_damage(9999.0)
	assert(enemy.rewind_retired)
	for frame: int in range(10, 10 + int((Player.REWIND_DURATION + WorldRewindRecorder.RETIRE_MARGIN + 0.3) * 60.0)):
		_tick(player, frame, func(_f: int) -> void: pass)
	assert(enemy.is_queued_for_deletion(), "Retired entity is really freed once it leaves the window.")
	var source: String = (load("res://scripts/main.gd") as GDScript).source_code
	assert(source.contains("WorldRewindRecorder.RETIRED_GROUP]"), "_clear_runtime_entities frees the retired group.")
	await get_tree().process_frame
	var other: Enemy = _enemy(WaveSpawner.TURKEY_SCENE, Vector2(600, 300))
	other.take_damage(9999.0)
	assert(get_tree().get_nodes_in_group(WorldRewindRecorder.RETIRED_GROUP).has(other), "Retired enemy sits in the group Main clears.")
	other.free()
	player.free()

func test_no_host_means_plain_free() -> void:
	var enemy: Enemy = _enemy(WaveSpawner.TURKEY_SCENE, Vector2(600, 300))
	enemy.take_damage(9999.0)
	assert(enemy.is_queued_for_deletion() and not enemy.rewind_retired, "Without a recording host, death frees exactly as before.")
	await get_tree().process_frame

func test_benchmark_record_cost() -> void:
	var player: Player = _new_player()
	var nodes: Array[Node] = []
	for index: int in range(20):
		nodes.append(_enemy(WaveSpawner.GOBLIN_SCENE, Vector2(300.0 + float(index) * 30.0, 600.0)))
	for index: int in range(30):
		var projectile: EnemyProjectile = PROJECTILE_SCENE.instantiate() as EnemyProjectile
		projectile.monitoring = false
		projectile.global_position = Vector2(-3000.0, float(index) * 20.0)
		add_child(projectile)
		projectile.set_physics_process(false)
		nodes.append(projectile)
	var recorder: WorldRewindRecorder = WorldRewindRecorder.new(Player.REWIND_BUFFER_SLOTS, Player.REWIND_DURATION)
	recorder.record(get_tree(), 0.0, 0) # first sight allocates each track once
	var started: int = Time.get_ticks_usec()
	for sample: int in range(120):
		recorder.record(get_tree(), float(sample) / 30.0, sample % Player.REWIND_BUFFER_SLOTS)
	var elapsed_usec: int = Time.get_ticks_usec() - started
	var per_sample_usec: float = float(elapsed_usec) / 120.0
	started = Time.get_ticks_usec()
	for frame: int in range(60):
		recorder.apply_playback(frame % 100, frame % 100 + 1, 0.5)
	var playback_usec: float = float(Time.get_ticks_usec() - started) / 60.0
	started = Time.get_ticks_usec()
	recorder.restore(get_tree(), 5)
	var restore_usec: int = Time.get_ticks_usec() - started
	print("[world-rewind bench] 50 entities: record 120 samples = %d us (%.1f us/sample), playback %.1f us/frame, restore %d us" % [elapsed_usec, per_sample_usec, playback_usec, restore_usec])
	assert(per_sample_usec < 1500.0, "Recording 50 entities must stay well under a frame (%.1f us)." % per_sample_usec)
	for node: Node in nodes:
		node.free()
	player.free()
