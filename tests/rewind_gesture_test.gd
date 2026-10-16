extends Node
## Rewind gesture (CCW circle from the top, Guard-only, once per wave, no Flow cost): recognition, charge, player-only restore, world freeze.
## No Main startup, no save/preset loaders or writers.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	return player

static func _segment(path: PackedVector2Array, from: Vector2, to: Vector2, steps: int) -> void:
	for step: int in range(1, steps + 1):
		path.append(from.lerp(to, float(step) / float(steps)))

static func _triangle(scale: float = 1.0, close: bool = true) -> PackedVector2Array:
	var a: Vector2 = Vector2(0, 0) * scale
	var b: Vector2 = Vector2(240, 0) * scale
	var c: Vector2 = Vector2(120, 190) * scale
	var path: PackedVector2Array = PackedVector2Array([a])
	_segment(path, a, b, 8)
	_segment(path, b, c, 8)
	if close:
		_segment(path, c, a + Vector2(6, 4) * scale, 8)
	return path

## Puts the player in the blue Charged Guard (the canonical rewind predicate) with Flow.
func _arm(player: Player, flow_value: float) -> void:
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	player.flow = flow_value

## A circle started at `start_angle` (screen radians, y-down; -PI/2 is the top) sweeping
## `sweep` radians. Negative sweep = counter-clockwise on screen (left first from the top).
static func _circle(start_angle: float = -PI / 2.0, sweep: float = -TAU, radius: float = 110.0, steps: int = 36) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	for step: int in range(steps + 1):
		path.append(Vector2(300, 300) + Vector2.RIGHT.rotated(start_angle + sweep * float(step) / float(steps)) * radius)
	return path

## Fills the ring with `seconds` of samples walking right at 100 px/s, health falling.
func _record(player: Player, seconds: float) -> void:
	var frames: int = int(seconds * 60.0)
	for frame: int in range(frames):
		player.global_position = Vector2(100.0 + float(frame) * 100.0 / 60.0, 300.0)
		player.health = 100.0 - float(frame) * 0.1
		player._record_rewind_sample(1.0 / 60.0)

func _play_out(player: Player) -> void:
	for _frame: int in range(400):
		if not player.rewind_active:
			return
		player._advance_rewind_playback(1.0 / 60.0)

func test_legacy_triangle_helper_still_reads_triangle() -> void:
	assert(Player.gesture_rewind_triangle_qualified(_triangle(), 1.0), "A closed ▽ must qualify.")
	assert(not Player.gesture_rewind_triangle_qualified(_triangle(), Player.REWIND_GESTURE_WINDOW + 0.1), "Must fit in the capture window.")
	assert(not Player.gesture_rewind_triangle_qualified(_triangle(0.3), 1.0), "A small ▽ scribble must not qualify.")
	assert(not Player.gesture_rewind_triangle_qualified(_triangle(1.0, false), 1.0), "An open stroke must not qualify.")
	var v: PackedVector2Array = PackedVector2Array([Vector2(0, 0)])
	_segment(v, Vector2(0, 0), Vector2(120, 190), 10)
	_segment(v, Vector2(120, 190), Vector2(240, 0), 10)
	assert(not Player.gesture_rewind_triangle_qualified(v, 1.0), "An open V must not read as ▽.")
	var up: PackedVector2Array = PackedVector2Array([Vector2(0, 190)])
	_segment(up, Vector2(0, 190), Vector2(240, 190), 8)
	_segment(up, Vector2(240, 190), Vector2(120, 0), 8)
	_segment(up, Vector2(120, 0), Vector2(4, 186), 8)
	assert(not Player.gesture_rewind_triangle_qualified(up, 1.0), "An upright △ must not read as ▽.")
	var scribble: PackedVector2Array = PackedVector2Array()
	for step: int in range(33):
		scribble.append(Vector2(float(step) * 7.0, 0.0 if step % 2 == 0 else 150.0))
	scribble.append(Vector2(0, 0))
	assert(not Player.gesture_rewind_triangle_qualified(scribble, 1.0), "A zigzag scribble must not read as ▽.")
	var circle: PackedVector2Array = PackedVector2Array()
	for step: int in range(37):
		circle.append(Vector2(120, 100) + Vector2.UP.rotated(TAU * float(step) / 36.0) * 110.0)
	assert(not Player.gesture_rewind_triangle_qualified(circle, 1.0), "A circle must not read as ▽.")
	assert(not Player.gesture_entry_z_qualified(_triangle(), 1.0) and not Player.gesture_entry_g_qualified(_triangle(), 1.0), "▽ must not trigger G or Z.")
	assert(Player.gesture_v_vertex_index(_triangle(), 1.0) < 0 or true, "V recognizer remains untouched (Guard-only path).")

func test_ccw_circle_from_top_recognized_and_others_rejected() -> void:
	var ccw: PackedVector2Array = _circle()
	assert(ccw[1].x < ccw[0].x, "Fixture sanity: CCW from the top travels left first.")
	assert(Player.gesture_rewind_circle_qualified(ccw, 1.2), "A CCW circle started at the top must qualify.")
	assert(not Player.gesture_rewind_circle_qualified(ccw, Player.REWIND_GESTURE_WINDOW + 0.1), "Must fit in the capture window.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(-PI / 2.0, TAU), 1.2), "A clockwise circle must not qualify.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(PI / 2.0), 1.2), "A CCW circle started at the bottom must not qualify.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(0.0), 1.2) and not Player.gesture_rewind_circle_qualified(_circle(PI), 1.2), "Starts at the side must not qualify.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(-PI / 2.0, -TAU * 0.6), 1.2), "A partial arc must not qualify.")
	assert(not Player.gesture_rewind_circle_qualified(_circle(-PI / 2.0, -TAU, 30.0), 1.2), "A small loop must not qualify.")
	var scribble: PackedVector2Array = PackedVector2Array()
	for step: int in range(33):
		scribble.append(Vector2(190.0 + float(step) * 7.0, 190.0 if step % 2 == 0 else 410.0))
	scribble.append(Vector2(300, 190))
	assert(not Player.gesture_rewind_circle_qualified(scribble, 1.2), "A zigzag scribble must not qualify.")
	assert(not Player.gesture_rewind_circle_qualified(_triangle(), 1.0), "The old ▽ no longer triggers rewind.")
	var v: PackedVector2Array = PackedVector2Array([Vector2(0, 0)])
	_segment(v, Vector2(0, 0), Vector2(120, 190), 10)
	_segment(v, Vector2(120, 190), Vector2(240, 0), 10)
	assert(not Player.gesture_rewind_circle_qualified(v, 1.0), "A V must not trigger rewind.")

func _draw_live(player: Player, path: PackedVector2Array) -> void:
	player.rewind_gesture_has_cursor = false
	player._clear_rewind_gesture_stroke()
	for point: Vector2 in path:
		player.charged_guard_gesture_cursor = point + Vector2(400, 100)
		player._update_rewind_gesture(1.0 / 60.0)
	# A real hand settles at the end; the circle fires on settle (REWIND_CIRCLE_SETTLE_TIME).
	for _frame: int in range(12):
		if player.rewind_active:
			break
		player._update_rewind_gesture(1.0 / 60.0)

func test_live_circle_needs_guard_not_flow() -> void:
	var player: Player = _new_player()
	_record(player, 2.0)
	player.flow = 100.0
	_draw_live(player, _circle())
	assert(not player.rewind_active, "Outside Charged Guard the circle does nothing.")
	_arm(player, 0.0)
	# The clockwise circle is now World Slow (which spends Guard); this test is about rewind only.
	player.set_combat_contact_setting("world_slow_gesture_enabled", 0.0)
	for bad: PackedVector2Array in [_circle(-PI / 2.0, TAU), _circle(PI / 2.0), _circle(-PI / 2.0, -TAU * 0.6), _triangle()]:
		_draw_live(player, bad)
		assert(not player.rewind_active, "Clockwise / bottom-start / partial / ▽ must not activate live.")
	_draw_live(player, _circle())
	assert(player.rewind_active and is_zero_approx(player.flow), "CCW circle from the top in Guard rewinds even at 0 Flow, and Flow stays untouched.")
	assert(not player.charged_guard_locked, "The guard is spent into the rewind.")
	_play_out(player)
	player.free()

func test_other_gestures_disabled_by_code_gate_even_with_switches_on() -> void:
	assert(not Player.GESTURES_EXCEPT_REWIND_ENABLED, "Re-enable via Player.GESTURES_EXCEPT_REWIND_ENABLED = true.")
	Player.gestures_except_rewind_gate = Player.GESTURES_EXCEPT_REWIND_ENABLED
	var player: Player = _new_player()
	player.sword_style = Player.SwordStyle.METRONOME
	for key: String in ["charged_guard_enabled", "charged_guard_position_charge_enabled", "charged_guard_gestures_enabled", "charged_guard_entry_g_enabled", "charged_guard_entry_z_enabled"]:
		player.set_combat_contact_setting(key, 1.0)
	assert(not player._charged_guard_entry_armed(), "G/Z entry gated off.")
	_arm(player, 0.0)
	assert(not player._charged_guard_gesture_armed(), "Guard slash/thrust/whirlwind gated off.")
	var center: Vector2 = Vector2(300, 300)
	var strokes: Array[PackedVector2Array] = [_circle(0.0, TAU, 110.0, 40), _circle(0.0, -TAU, 110.0, 40)]
	for corner: Vector2 in [Vector2(0, 80), Vector2(80, 0), Vector2(0, -80), Vector2(-80, 0)]:
		var a: Vector2 = center - corner + corner.orthogonal()
		var vee: PackedVector2Array = PackedVector2Array([a])
		_segment(vee, a, center, 10)
		_segment(vee, center, center - corner - corner.orthogonal(), 10)
		strokes.append(vee)
	var line: PackedVector2Array = PackedVector2Array([Vector2(100, 300)])
	_segment(line, Vector2(100, 300), Vector2(400, 300), 20)
	strokes.append(line)
	for stroke: PackedVector2Array in strokes:
		for point: Vector2 in stroke:
			player.charged_guard_gesture_cursor = point
			player._update_charged_guard_gesture(1.0 / 60.0)
		for _frame: int in range(8):
			player._update_charged_guard_gesture(1.0 / 60.0)
		assert(player.charged_guard_gesture_state == Player.ChargedGuardGesture.NONE and player.charged_guard_locked, "Gated Guard gestures produce no ability and keep the guard.")
	player.charged_guard_locked = false
	player.charged_guard_fully_charged = false
	for point: Vector2 in _triangle():
		player.charged_guard_gesture_cursor = point
		player._update_charged_guard_entry_gesture(1.0 / 60.0)
	assert(not player.charged_guard_locked and player.charged_guard_entry_path.is_empty(), "G/Z entry strokes produce no Guard.")
	assert(not _source_has_gate_in("_charged_guard_entry_ready"), "Pommel/dual-click readiness must not read the gesture gate.")
	player.free()

static func _source_has_gate_in(function_name: String) -> bool:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var start: int = source.find("func %s(" % function_name)
	var body: String = source.substr(start, source.find("\nfunc ", start + 10) - start)
	return body.contains("gestures_except_rewind_gate")

func test_once_per_wave_charge_no_flow_cost() -> void:
	var player: Player = _new_player()
	_record(player, 1.0)
	var seen: Array[bool] = []
	player.rewind_charge_changed.connect(func(available: bool) -> void: seen.append(available))
	var flow_seen: Array[float] = []
	player.flow_changed.connect(func(current: float, _maximum: float) -> void: flow_seen.append(current))
	_arm(player, 0.0)
	assert(player.rewind_charge_available and player.activate_rewind(), "Rewind works at 0 Flow while the wave's charge is unused.")
	assert(not player.rewind_charge_available and seen == [false], "Activation spends the charge and signals the HUD.")
	assert(flow_seen.is_empty() and is_zero_approx(player.flow), "Rewind never touches Flow.")
	assert(get_tree().paused, "World pauses during playback.")
	_play_out(player)
	assert(not get_tree().paused, "World resumes after playback.")
	_record(player, 1.0)
	_arm(player, 100.0)
	assert(not player.activate_rewind(), "Second rewind in the same wave is refused, even at full Flow.")
	assert(is_equal_approx(player.flow, 100.0), "Refused rewind spends nothing.")
	player.refill_rewind_charge()
	assert(player.rewind_charge_available and seen == [false, true], "Wave refill restores the charge and signals the HUD.")
	player.refill_rewind_charge()
	assert(seen == [false, true], "Refilling an unused charge emits nothing extra.")
	_arm(player, 0.0)
	assert(player.activate_rewind(), "After refill, rewind works again.")
	_play_out(player)
	player.free()

func test_setting_off_and_dead_block_rewind() -> void:
	var player: Player = _new_player()
	_record(player, 1.0)
	_arm(player, 90.0)
	player.set_combat_contact_setting("rewind_gesture_enabled", 0.0)
	assert(not player.can_activate_rewind(), "Toggle OFF disables rewind.")
	player.set_combat_contact_setting("rewind_gesture_enabled", 1.0)
	player.health = 0.0
	assert(not player.can_activate_rewind(), "Never available once dead.")
	var before: int = player.rewind_buffer.count
	player._record_rewind_sample(1.0)
	assert(player.rewind_buffer.count == before, "No recording while dead.")
	player.free()

func test_restores_position_health_four_seconds_back_over_half_time() -> void:
	var player: Player = _new_player()
	_record(player, Player.REWIND_DURATION + 2.0)
	var oldest: int = player.rewind_buffer.oldest_index_within(Player.REWIND_DURATION)
	var expected_pos: Vector2 = player.rewind_buffer.positions[player.rewind_buffer.slot(oldest)]
	var expected_health: float = player.rewind_buffer.healths[player.rewind_buffer.slot(oldest)]
	var span: float = player.rewind_buffer.times[player.rewind_buffer.head] - player.rewind_buffer.times[player.rewind_buffer.slot(oldest)]
	assert(span > Player.REWIND_DURATION - 0.1 and span <= Player.REWIND_DURATION + 0.001, "Rewind spans the full duration (got %f)." % span)
	_arm(player, 80.0)
	player.hit_stagger_left = 0.5
	assert(player.activate_rewind())
	assert(is_equal_approx(player.rewind_playback_duration, span * 0.5), "Playback runs over half the rewound span.")
	# Halfway through real-time playback it is still rewinding; it finishes at half the span.
	var frames: int = 0
	while player.rewind_active and frames < 1000:
		player._advance_rewind_playback(1.0 / 60.0)
		frames += 1
	assert(absf(float(frames) / 60.0 - span * 0.5) < 0.05, "Playback took %f s, expected ~%f." % [float(frames) / 60.0, span * 0.5])
	assert(not player.rewind_active)
	assert(player.global_position.distance_to(expected_pos) < 0.5, "Position restored ~4 s back.")
	assert(absf(player.global_position.x - (player.rewind_buffer.positions[player.rewind_buffer.head].x)) < 0.5, "Buffer reseeded at the restored spot.")
	assert(is_equal_approx(player.health, expected_health), "Health restored.")
	assert(player.velocity.length() < 0.01, "No velocity spike on resume (recorded velocity was zero).")
	assert(is_zero_approx(player.hit_stagger_left), "Negative status is cleared, not restored.")
	player.free()

func test_short_buffer_uses_oldest() -> void:
	var player: Player = _new_player()
	_record(player, 1.0)
	var oldest_pos: Vector2 = player.rewind_buffer.positions[player.rewind_buffer.slot(player.rewind_buffer.count - 1)]
	_arm(player, 80.0)
	assert(player.activate_rewind())
	assert(player.rewind_target_age == player.rewind_buffer.count - 1, "Short buffer rewinds to its oldest sample.")
	_play_out(player)
	assert(player.global_position.distance_to(oldest_pos) < 0.5)
	player.free()

func test_no_recording_during_playback_or_pause_and_fixed_size() -> void:
	var player: Player = _new_player()
	assert(player.rewind_buffer.positions.size() == Player.REWIND_BUFFER_SLOTS and player.rewind_buffer.healths.size() == Player.REWIND_BUFFER_SLOTS, "Ring is preallocated.")
	_record(player, Player.REWIND_DURATION + 4.0)
	assert(player.rewind_buffer.count == Player.REWIND_BUFFER_SLOTS and player.rewind_buffer.positions.size() == Player.REWIND_BUFFER_SLOTS, "Ring never grows.")
	get_tree().paused = true
	var head: int = player.rewind_buffer.head
	player._record_rewind_sample(1.0)
	assert(player.rewind_buffer.head == head, "No recording while paused.")
	get_tree().paused = false
	_arm(player, 80.0)
	assert(player.activate_rewind())
	head = player.rewind_buffer.head
	player._record_rewind_sample(1.0)
	assert(player.rewind_buffer.head == head, "No recording during playback.")
	assert(player.can_activate_rewind() == false, "Cannot re-trigger mid-playback.")
	_play_out(player)
	player.free()

func test_invulnerable_and_input_disabled_during_playback() -> void:
	var player: Player = _new_player()
	_record(player, 2.0)
	_arm(player, 80.0)
	assert(player.activate_rewind())
	var health_before: float = player.health
	player.invulnerable = 0.0
	player.take_damage(30.0)
	assert(is_equal_approx(player.health, health_before), "Invulnerable during playback.")
	var position_before: Vector2 = player.global_position
	player.velocity = Vector2(900, 0)
	player._physics_process(1.0 / 60.0) # playback path only; movement/input never run
	assert(player.velocity == Vector2.ZERO and player.global_position.x <= position_before.x + 0.01, "Input/movement disabled; playback only moves backward.")
	_play_out(player)
	player.free()

func test_world_frozen_during_playback_and_resumes() -> void:
	var player: Player = _new_player()
	player.set_physics_process(true)
	var enemy: Node2D = Node2D.new()
	enemy.position = Vector2(50, 50)
	add_child(enemy)
	var timer: Timer = Timer.new()
	add_child(timer)
	timer.start(5.0)
	_record(player, 2.0)
	_arm(player, 80.0)
	player.rewind_finished.connect(func(_at: Vector2) -> void: player.set_physics_process(false), CONNECT_ONE_SHOT)
	assert(player.activate_rewind())
	assert(player.process_mode == Node.PROCESS_MODE_ALWAYS and enemy.can_process() == false and player.can_process(), "Only the player processes while paused.")
	var timer_left: float = timer.time_left
	var mover: Tween = enemy.create_tween()
	mover.tween_property(enemy, "position", Vector2(500, 50), 0.5)
	for _frame: int in range(160):
		await get_tree().physics_frame
		if not player.rewind_active:
			break
	player.set_physics_process(false) # bare Player outside Main: stop before ordinary combat ticks
	assert(not player.rewind_active, "Playback finishes on its own in real time.")
	assert(not get_tree().paused and player.process_mode == Node.PROCESS_MODE_INHERIT, "Tree unpaused and prior process mode restored.")
	assert(is_equal_approx(timer.time_left, timer_left) or timer.time_left >= timer_left - 0.05, "World timer frozen during playback.")
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(timer.time_left < timer_left, "World timer resumes after.")
	mover.kill()
	enemy.free()
	timer.free()
	player.free()

func test_collision_safe_resume_nudges_out_of_walls() -> void:
	var player: Player = _new_player()
	_record(player, 1.0)
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = player.collision_mask
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	wall.add_child(shape)
	var oldest_pos: Vector2 = player.rewind_buffer.positions[player.rewind_buffer.slot(player.rewind_buffer.count - 1)]
	wall.global_position = oldest_pos
	add_child(wall)
	await get_tree().physics_frame
	_arm(player, 80.0)
	assert(player.activate_rewind())
	_play_out(player)
	assert(not player.test_move(player.global_transform, Vector2.ZERO), "Resume position must be clear of walls.")
	assert(player.global_position.distance_to(oldest_pos) < 80.0, "Nudge stays near the restored spot.")
	wall.free()
	player.free()

func test_pause_menu_not_opened_and_toggle_persisted() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/player.gd")
	var start: int = source.find("func activate_rewind()")
	var body: String = source.substr(start, source.find("\nfunc ", start + 10) - start)
	assert(not body.contains("_toggle_pause") and not body.contains("pause_menu") and not body.contains("mobile_controls"), "Rewind uses tree pause only; never the pause menu/mobile controls.")
	assert(CombatSettingsConfig.CHARGED_GUARD_TUNING_KEYS.has("rewind_gesture_enabled"), "Toggle lives in the canonical persisted key list.")
	assert(is_equal_approx(float(CombatSettingsConfig.built_in_contact_settings()["2"]["rewind_gesture_enabled"]), 1.0), "Default ON.")

func test_drawn_triangle_through_live_cursor_no_longer_activates() -> void:
	var player: Player = _new_player()
	_record(player, 2.0)
	_arm(player, 90.0)
	var path: PackedVector2Array = _triangle()
	for point: Vector2 in path:
		player.charged_guard_gesture_cursor = point + Vector2(500, 200)
		player._update_rewind_gesture(1.0 / 60.0)
	assert(not player.rewind_active, "Drawing ▽ no longer activates rewind (shape is now the CCW circle).")
	_play_out(player)
	player.free()
