extends Node

## PX game suite. Self-contained: modules are bound through PRELOADED PATHS, so
## a moved or renamed module fails loudly here instead of silently riding a stale
## global class cache.

const PX_SCENE: PackedScene = preload("res://blade_dancer_px/scenes/px_game.tscn")
const PXGame = preload("res://blade_dancer_px/scripts/px_game.gd")
const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")

func test_proto_is_source_isolated_from_the_game() -> void:
	# The prototype must not load any game script or scene — it is a look-alike,
	# not a re-skin of production code.
	var source: String = FileAccess.get_file_as_string("res://blade_dancer_px/scripts/px_game.gd")
	for forbidden: String in ["res://scripts/", "res://scenes/", "AITestTools"]:
		assert(not source.contains(forbidden), "PX proto must not reference %s." % forbidden)

func test_proto_builds_player_and_starts_with_an_empty_arena() -> void:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	assert(proto.player != null, "The prototype needs a player body.")
	assert(proto.enemies.is_empty(), "The arena must start empty — enemies are opt-in.")
	proto.queue_free()
	await get_tree().process_frame

func test_enemy_toggles_keep_exactly_one_each() -> void:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	proto._set_chaser_wanted(true)
	proto._set_sword_enemy_wanted(true)
	assert(proto.enemies.size() == 2, "Each toggle should add one enemy.")
	var armed: int = 0
	for entry: Dictionary in proto.enemies:
		if bool(entry["armed"]): armed += 1
	assert(armed == 1, "One armed (sword) and one unarmed (chaser) expected.")
	proto._set_chaser_wanted(false)
	assert(proto.enemies.size() == 1, "Turning the chaser off must remove it.")
	assert(bool(proto.enemies[0]["armed"]), "The sword enemy must survive the chaser toggle.")
	proto.queue_free()
	await get_tree().process_frame

func test_blade_jams_on_a_hard_wall() -> void:
	# Drive the blade straight into a wall and confirm the solver stops it
	# rather than letting it pass through: its tip must stay inside the arena.
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	proto.player.global_position = Vector2(Cfg.ARENA.end.x - 60.0, 0.0)
	for _i: int in range(40):
		await get_tree().physics_frame
	var tip: Vector2 = proto.player_sword.to_global(Vector2(Cfg.BLADE_LENGTH, 0.0))
	assert(tip.x <= Cfg.ARENA.end.x + 6.0, "Blade tunnelled through the wall (tip x=%.1f)." % tip.x)
	proto.queue_free()
	await get_tree().process_frame

func test_an_enemy_on_the_blade_takes_damage() -> void:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	proto._set_chaser_wanted(true)
	var entry: Dictionary = proto.enemies[0]
	for _i: int in range(20):
		var tip: Vector2 = proto.player_sword.to_global(Vector2(Cfg.BLADE_LENGTH, 0.0))
		(entry["body"] as Node2D).global_position = tip
		await get_tree().physics_frame
	assert(float(entry["hp"]) < Cfg.ENEMY_MAX_HEALTH, "A body on the blade must take swing damage.")
	proto.queue_free()
	await get_tree().process_frame

func test_an_enemy_touching_the_player_damages_the_player() -> void:
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	proto._set_chaser_wanted(true)
	var entry: Dictionary = proto.enemies[0]
	for _i: int in range(20):
		(entry["body"] as Node2D).global_position = proto.player.global_position
		await get_tree().physics_frame
	assert(proto.player_health < Cfg.PLAYER_MAX_HEALTH, "Body contact must hurt the player.")
	proto.queue_free()
	await get_tree().process_frame

func test_without_the_metronome_the_motor_holds_the_aim() -> void:
	# The control. A still cursor, the metronome OFF: the blade must sit on the
	# aim, not wander. Anything else means the test below proves nothing.
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	var peak: float = await _peak_blade_deflection(proto, 90, 90)
	assert(peak < 0.2, "Free-aim must hold the blade on the aim (peak %.2f rad off)." % peak)
	proto.queue_free()
	await get_tree().process_frame

func test_the_metronome_sweeps_the_blade_through_the_arc() -> void:
	# Same motor, same still cursor — the ONLY change is the target angle. The
	# blade must actually travel the arc. Measured from the BLADE, so it proves
	# the motor earned the sweep rather than being told where to be.
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	# Let the motor settle on the aim FIRST, so any later deflection can only
	# have come from the arc.
	for _i: int in range(90):
		await get_tree().physics_frame
	proto._set_metronome_wanted(true)
	var peak: float = await _peak_blade_deflection(proto, 0, 150)
	assert(peak > 1.2, "The metronome must sweep the blade (peak %.2f rad off)." % peak)
	assert(peak < 2.2, "The sweep must stay inside the arc, not run away (peak %.2f rad)." % peak)
	proto.queue_free()
	await get_tree().process_frame

## Widest angle the blade ACTUALLY reached away from the aim, over `frames`
## ticks after `warmup`. Signed difference from the aim, so it cannot be fooled
## by the blade's rotation wrapping past a half turn.
func _peak_blade_deflection(proto: PXGame, warmup: int, frames: int) -> float:
	for _i: int in range(warmup):
		await get_tree().physics_frame
	var peak: float = 0.0
	for _i: int in range(frames):
		await get_tree().physics_frame
		peak = maxf(peak, absf(angle_difference(proto.aim_direction.angle(), proto.player_sword.rotation)))
	return peak

func test_tuning_tools_open_and_close_from_the_top_bar() -> void:
	# The game's own Training Tools arrangement: one bar, clicked to drop the
	# panel open, clicked again to hide it. Closed at launch.
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().process_frame
	assert(not proto.tuner.panel.visible, "Tuning Tools must start closed.")
	assert(proto.tuner.bar.position.y < proto.tuner.panel.position.y, "The bar must sit above the panel it opens.")
	assert(is_equal_approx(proto.tuner.bar.size.x, proto.tuner.panel.size.x), "Bar and panel must share one width.")
	proto.tuner.bar.pressed.emit()
	assert(proto.tuner.panel.visible, "Clicking the bar must open the panel.")
	proto.tuner.bar.pressed.emit()
	assert(not proto.tuner.panel.visible, "Clicking the bar again must hide it.")
	proto.queue_free()
	await get_tree().process_frame

func test_the_hand_range_bounds_the_grip() -> void:
	# "The hand" is where the grip orbits, and its reach is the cursor-driven lerp
	# between the tuner's two numbers. Measured on the ANCHOR rather than the
	# variable, so a reach that never actually moved would still fail here.
	var proto: PXGame = PX_SCENE.instantiate() as PXGame
	add_child(proto)
	await get_tree().physics_frame
	# The last pair is deliberately inverted: Min past Max must swap, not collapse.
	for span: Array in [[8.0, 12.0], [50.0, 260.0], [200.0, 60.0]]:
		var lowest: float = minf(span[0], span[1])
		var highest: float = maxf(span[0], span[1])
		proto.tuner.hand_min = span[0]
		proto.tuner.hand_max = span[1]
		await get_tree().physics_frame
		await get_tree().physics_frame
		var reach: float = proto.player_anchor.global_position.distance_to(proto.player.global_position)
		assert(reach >= lowest - 0.5, "Hand reach %.1f fell short of the minimum %.0f." % [reach, lowest])
		assert(reach <= highest + 0.5, "Hand reach %.1f overshot the maximum %.0f." % [reach, highest])
	# And the widget itself has to write the field, not merely the field drive the grip.
	var slider: HSlider = proto.tuner._sliders["hand_max"] as HSlider
	slider.value = 123.0
	assert(is_equal_approx(proto.tuner.hand_max, 123.0), "The Hand Max slider must write the tuner field.")
	proto.queue_free()
	await get_tree().process_frame