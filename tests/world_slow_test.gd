extends Node
## World Slow: clockwise circle from the top (blue Guard) -> enemies, enemy projectiles and
## the wave clock at WorldTime.WORLD_SLOW_SCALE for WORLD_SLOW_DURATION real seconds.
## No Main startup, no save/preset writers.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const DT: float = 1.0 / 60.0

func _new_player() -> Player:
	WorldTime.reset()
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	return player

func _arm(player: Player) -> void:
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true

static func _circle(start_angle: float = -PI / 2.0, sweep: float = TAU, radius: float = 110.0, steps: int = 36) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		path.append(Vector2(300, 300) + Vector2.RIGHT.rotated(start_angle + sweep * float(step) / float(steps)) * radius)
	return path

static func _spiral(direction: float) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	for step: int in range(73):
		var t: float = float(step) / 72.0
		path.append(Vector2(400, 400) + Vector2.RIGHT.rotated(-PI / 2.0 + direction * TAU * 2.0 * t) * lerpf(130.0, 35.0, t))
	return path

func _draw_and_settle(player: Player, path: PackedVector2Array) -> void:
	for point: Vector2 in path:
		player.charged_guard_gesture_cursor = point
		player._update_rewind_gesture(DT)
	for _frame: int in range(12):
		player._update_rewind_gesture(DT)

func test_recognizer_directions() -> void:
	assert(Player.gesture_world_slow_circle_qualified(_circle(), 1.0), "CW circle from top is slow.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(), 1.0), "CW circle is not rewind.")
	assert(not Player.gesture_world_slow_circle_qualified(_circle(-PI / 2.0, -TAU), 1.0), "CCW circle is not slow.")
	assert(Player.gesture_rewind_circle_qualified(_circle(-PI / 2.0, -TAU), 1.0), "CCW circle still rewinds.")
	assert(Player.gesture_world_slow_circle_qualified(_circle(0.0), 1.0), "CW circle from any start point now slows (Whirlwind-style recognizer).")
	assert(Player.gesture_world_slow_circle_qualified(_circle(PI, TAU * 0.8, 60.0, 20), 1.0), "Rough, small, not-quite-closed CW loop still slows.")
	# Hand-drawn wobble: uneven radius, oval, overdrawn past a full turn.
	var wobbly: PackedVector2Array = PackedVector2Array()
	for step: int in range(50):
		var a: float = 0.3 + TAU * 1.15 * float(step) / 49.0
		wobbly.append(Vector2(400, 300) + Vector2(cos(a) * 130.0, sin(a) * 85.0) * (1.0 + 0.18 * sin(float(step) * 1.7)))
	assert(Player.gesture_world_slow_circle_qualified(wobbly, 1.6), "Wobbly overdrawn CW oval slows.")
	var reversed: PackedVector2Array = wobbly.duplicate()
	reversed.reverse()
	assert(not Player.gesture_world_slow_circle_qualified(reversed, 1.6), "The same loop drawn CCW never slows.")
	# Only CCW spirals matter (the world-rewind shape): they must never slow. A clockwise
	# spiral is just a rough clockwise loop and may slow -- nothing else is drawn clockwise.
	var ccw_spiral: PackedVector2Array = _spiral(-1.0)
	assert(not Player.gesture_world_slow_circle_qualified(ccw_spiral, 1.0), "CCW (world rewind) spiral never reads as slow.")
	assert(not Player.gesture_world_rewind_spiral_qualified(_circle(), 1.0), "CW circle is not the world spiral.")

func test_gesture_requires_guard_and_activates() -> void:
	var player: Player = _new_player()
	_draw_and_settle(player, _circle())
	assert(not WorldTime.slow_active(), "No Guard -> no slow.")
	_arm(player)
	_draw_and_settle(player, _circle())
	assert(WorldTime.slow_active() and not player.rewind_active, "Guarded CW circle slows, never rewinds.")
	assert(not player.charged_guard_locked, "Guard released on activation.")
	WorldTime.reset()
	player.free()

func test_slow_fires_mid_stroke_without_stopping() -> void:
	var player: Player = _new_player()
	_arm(player)
	var fired_at: int = -1
	var path: PackedVector2Array = _circle()
	for index: int in range(path.size()):
		player.charged_guard_gesture_cursor = path[index]
		player._update_rewind_gesture(DT)
		if WorldTime.slow_active():
			fired_at = index
			break
	assert(fired_at >= 0 and fired_at < path.size() - 1, "Slow fires while the cursor is still moving (index %d), no settle wait." % fired_at)
	WorldTime.reset()
	player.free()

func test_charge_once_per_wave_with_signal() -> void:
	var player: Player = _new_player()
	var seen: Array[bool] = []
	player.slow_charge_changed.connect(func(a: bool) -> void: seen.append(a))
	_arm(player)
	assert(player.activate_world_slow(), "First activation.")
	assert(not player.slow_charge_available and player.rewind_charge_available, "Own charge, rewind untouched.")
	WorldTime.reset()
	_arm(player)
	assert(not player.activate_world_slow(), "Refused second time this wave.")
	player.refill_slow_charge()
	assert(seen == [false, true], "Signal false then true: %s" % [seen])
	assert(player.activate_world_slow(), "Refilled.")
	_arm(player)
	assert(not player.can_activate_world_slow(), "Cannot activate while already active.")
	player.set_combat_contact_setting("world_slow_gesture_enabled", 0.0)
	WorldTime.reset()
	player.refill_slow_charge()
	assert(not player.can_activate_world_slow(), "Toggle OFF disables.")
	assert(CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS.has("world_slow_gesture_enabled"), "Persisted key.")
	assert(is_equal_approx(float(CombatSettingsConfig.built_in_contact_settings()["2"]["world_slow_gesture_enabled"]), 1.0), "Default ON.")
	player.free()

func test_duration_real_time_and_exact_restore() -> void:
	var player: Player = _new_player()
	_arm(player)
	player.activate_world_slow()
	for _frame: int in range(299):
		player._tick_world_slow(DT)
	assert(WorldTime.slow_active() and is_equal_approx(WorldTime.enemy_scale(), 0.5), "Still slowed just before 5 s.")
	player._tick_world_slow(DT * 2.0)
	assert(not WorldTime.slow_active() and WorldTime.enemy_scale() == 1.0, "Exactly 1.0 after 5 s.")
	assert(player.world_slow_tint_layer == null, "Tint removed.")
	player.free()

## Paused tree (rewind playback): the player's live tick does not run, so the countdown holds.
func test_rewind_playback_freezes_countdown() -> void:
	var player: Player = _new_player()
	_arm(player)
	player.activate_world_slow()
	var before: float = WorldTime.slow_left
	player.rewind_active = true
	player._physics_process(DT) # rewind branch returns before _tick_world_slow
	player.rewind_active = false
	assert(is_equal_approx(WorldTime.slow_left, before), "Countdown frozen during playback.")
	WorldTime.reset()
	player.free()

func _enemy_step(slowed: bool) -> Array[float]:
	var player: Player = _new_player()
	var enemy: Enemy = WaveSpawner.GOBLIN_SCENE.instantiate() as Enemy
	enemy.global_position = Vector2(600, 300)
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.set_meta("training_no_drops", true)
	enemy.player_ref = player
	if slowed: WorldTime.begin_slow()
	enemy.stun_left = 1.0
	enemy.knockback = Vector2(300, 0)
	enemy.charge_cooldown = 1.0
	var start: Vector2 = enemy.global_position
	enemy._physics_process(DT)
	var result: Array[float] = [enemy.global_position.x - start.x, 1.0 - enemy.charge_cooldown, 1.0 - enemy.stun_left, enemy.velocity.x]
	WorldTime.reset()
	enemy.free()
	player.free()
	return result

func test_enemy_motion_and_timers_half_no_double_scale() -> void:
	var normal: Array[float] = _enemy_step(false)
	var slow: Array[float] = _enemy_step(true)
	print("[world-slow-test] enemy dx normal=%.3f slow=%.3f ratio=%.3f" % [normal[0], slow[0], slow[0] / normal[0]])
	assert(absf(slow[0] / normal[0] - 0.5) < 0.02, "Enemy moves half.")
	assert(is_equal_approx(slow[1], normal[1] * 0.5), "Cooldown advances half.")
	assert(is_equal_approx(slow[2], normal[2] * 0.5), "Stun advances half.")
	assert(slow[3] > 299.0 * 0.0 and is_equal_approx(slow[3], normal[3]), "Stored velocity is unscaled (scale removed after move).")

var _probe_scene: Node2D = null

func _ensure_scene() -> void:
	if get_tree().current_scene != null:
		return
	_probe_scene = Node2D.new()
	get_tree().root.add_child(_probe_scene)
	get_tree().current_scene = _probe_scene

func test_projectiles_bomb_orb_spawner_half() -> void:
	_ensure_scene()
	for slowed: bool in [false, true]:
		WorldTime.reset()
		if slowed: WorldTime.begin_slow()
		var shot: EnemyProjectile = (load(Enemy.PROJECTILE_SCENE_PATH) as PackedScene).instantiate() as EnemyProjectile
		add_child(shot)
		shot.set_physics_process(false)
		shot.global_position = Vector2(500, 300)
		shot.direction = Vector2.RIGHT
		shot.speed = 300.0
		shot._physics_process(DT)
		assert(is_equal_approx(shot.global_position.x - 500.0, 300.0 * DT * WorldTime.enemy_scale()), "Projectile scaled (slowed=%s)." % slowed)
		shot.free()
		var bomb: BomberBomb = GoblinBomber.BOMB_SCENE.instantiate() as BomberBomb
		add_child(bomb)
		bomb.set_physics_process(false)
		bomb.armed = true
		bomb._physics_process(0.1)
		assert(is_equal_approx(bomb.elapsed, 0.1 * WorldTime.enemy_scale()), "Bomb phase clock scaled.")
		bomb.free()
		var spawner: WaveSpawner = WaveSpawner.new()
		add_child(spawner)
		spawner.set_process(false)
		spawner.wave_active = true
		spawner.wave_duration = 100.0
		spawner.enemies_to_spawn = 0
		spawner.boss_active = true
		spawner.wave_elapsed = 0.0
		spawner._process(0.2)
		assert(is_equal_approx(spawner.wave_elapsed, 0.2 * WorldTime.enemy_scale()), "Wave clock scaled.")
		spawner.free()
	WorldTime.reset()

func test_heal_orb_half() -> void:
	for slowed: bool in [false, true]:
		WorldTime.reset()
		if slowed: WorldTime.begin_slow()
		var target: Enemy = WaveSpawner.GOBLIN_SCENE.instantiate() as Enemy
		target.global_position = Vector2(2000, 300)
		add_child(target)
		target.set_physics_process(false)
		var orb: ShamanHealOrb = GoblinShaman.HEAL_ORB_SCENE.instantiate() as ShamanHealOrb
		add_child(orb)
		orb.set_physics_process(false)
		orb.launch(Vector2(300, 300), target)
		orb._physics_process(0.1)
		assert(is_equal_approx(orb.elapsed, 0.1 * WorldTime.enemy_scale()), "Orb clock scaled.")
		orb.free()
		target.free()
	WorldTime.reset()

func test_player_unaffected() -> void:
	# Player-owned code never reads the world clock (only the countdown owner does).
	var source: String = (load("res://scripts/player.gd") as GDScript).source_code
	assert(source.count("WorldTime.enemy_scale") == 0, "Player never scales its own delta.")
	for path: String in ["res://scripts/chakram.gd"]:
		assert(not (load(path) as GDScript).source_code.contains("WorldTime"), "%s stays full speed." % path)
	var player: Player = _new_player()
	_arm(player)
	player.activate_world_slow()
	player._tick_world_slow(1.0)
	assert(is_equal_approx(WorldTime.slow_left, WorldTime.WORLD_SLOW_DURATION - 1.0), "Countdown uses unscaled real time.")
	WorldTime.reset()
	player.free()

func test_hud_slow_icon() -> void:
	var main = (load("res://tests/hud_flow_safe_rig.tscn") as PackedScene).instantiate()
	add_child(main)
	var icon: TextureRect = main.get_node("CanvasLayer/SlowIcon")
	var rewind_icon: TextureRect = main.get_node("CanvasLayer/RewindIcon")
	assert(icon.texture.resource_path == "res://assets/generated/Time Slow.png")
	assert(icon.size.is_equal_approx(Vector2(40, 40)) and is_equal_approx(icon.position.y, rewind_icon.position.y), "Same row.")
	assert(icon.position.x >= rewind_icon.get_rect().end.x and not icon.get_rect().intersects(rewind_icon.get_rect()), "Right of RewindIcon, no overlap.")
	assert(is_equal_approx(icon.modulate.a, 1.0))
	main.player._consume_slow_charge()
	assert(is_equal_approx(icon.modulate.a, Main.REWIND_ICON_USED_ALPHA), "Faded once used.")
	main._on_wave_started(4)
	assert(main.player.slow_charge_available and is_equal_approx(icon.modulate.a, 1.0), "Wave start refills.")
	main._set_world_visible(false)
	assert(not icon.visible, "Hidden with world.")
	main._set_world_visible(true)
	assert(icon.visible)
	assert(main.write_attempts == 0)
	WorldTime.reset()
	main.free()
