extends Node
## World rewind stage 2a: persistent tracks (Main score/run counters, WaveSpawner clocks),
## spawn warnings, and the wave-boundary barrier. No Main startup, no saves.
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MAIN_SCRIPT: Script = preload("res://scripts/main.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/wave_spawner.gd")
const HUD_RIG: PackedScene = preload("res://tests/hud_flow_safe_rig.tscn")

func _new_player() -> Player:
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.combat_contact_preset = 2
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	return player

func _tick(player: Player, frame: int) -> void:
	player.global_position = Vector2(100.0 + float(frame), 300.0)
	player._record_rewind_sample(1.0 / 60.0)

func _play_out(player: Player) -> void:
	for _frame: int in range(400):
		if not player.rewind_active:
			return
		player._advance_rewind_playback(1.0 / 60.0)

func test_main_and_spawner_join_the_persistent_group() -> void:
	var main: Node2D = MAIN_SCRIPT.new() as Node2D
	var spawner: Node2D = SPAWNER_SCRIPT.new() as Node2D
	assert(main.is_in_group(WorldRewindRecorder.PERSISTENT_GROUP), "Main is a persistent rewind track from _init (works for safe rigs too).")
	assert(spawner.is_in_group(WorldRewindRecorder.PERSISTENT_GROUP), "WaveSpawner is a persistent rewind track.")
	main.free()
	spawner.free()

## Real Main (save-guarded HUD rig) with its own Player: score + damage totals + HUD revert.
func test_score_and_damage_counters_revert_with_hud() -> void:
	var main = HUD_RIG.instantiate()
	add_child(main)
	var player: Player = main.player
	player.charged_guard_locked = true
	player.charged_guard_fully_charged = true
	main.score = 100
	main.run_damage_dealt = 40.0
	main.run_damage_received = 5.0
	for frame: int in range(120):
		if frame == 60:
			main.score = 350
			main.run_damage_dealt = 90.0
			main.run_damage_received = 12.0
			main.score_label.text = "Score: 350"
		_tick(player, frame)
	assert(player.activate_world_rewind(), "World rewind starts.")
	_play_out(player)
	assert(main.score == 100, "Score returns to its value at the rewound instant (got %d)." % main.score)
	assert(is_equal_approx(main.run_damage_dealt, 40.0) and is_equal_approx(main.run_damage_received, 5.0), "Run damage totals revert.")
	assert(main.score_label.text == "Score: 100", "HUD score text follows the restore.")
	assert(main.write_attempts == 0)
	get_tree().paused = false
	main.free()

func test_spawner_clocks_rewind() -> void:
	var player: Player = _new_player()
	var spawner: Node2D = SPAWNER_SCRIPT.new() as Node2D
	add_child(spawner)
	spawner.set_process(false)
	for frame: int in range(120):
		spawner.set("wave_elapsed", 10.0 + float(frame) / 60.0)
		spawner.set("spawn_timer", 3.0 - float(frame) / 60.0)
		spawner.set("enemies_to_spawn", 8 - frame / 30)
		_tick(player, frame)
	var oldest: int = player.rewind_buffer.oldest_index_within(Player.REWIND_DURATION)
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(float(spawner.get("wave_elapsed")) < 10.2, "Wave clock goes back ~2 s (got %f)." % float(spawner.get("wave_elapsed")))
	assert(float(spawner.get("spawn_timer")) > 2.8, "Spawn cadence timer restored.")
	assert(int(spawner.get("enemies_to_spawn")) == 8, "Spawn queue restored.")
	assert(oldest > 0)
	spawner.free()
	player.free()
	get_tree().paused = false

func test_spawn_warning_spawned_after_target_is_removed() -> void:
	var player: Player = _new_player()
	var early: SpawnWarning = SpawnWarning.new()
	add_child(early)
	early.set_process(false)
	var late: SpawnWarning = null
	for frame: int in range(120):
		if frame == 100:
			late = SpawnWarning.new()
			add_child(late)
			late.set_process(false)
		early.elapsed = float(frame) / 200.0
		_tick(player, frame)
	assert(player.activate_world_rewind())
	_play_out(player)
	await get_tree().process_frame
	assert(is_instance_valid(early) and early.elapsed < 0.05, "A warning alive at the target is restored to its earlier progress.")
	assert(not is_instance_valid(late), "A warning that appeared after the target is removed.")
	early.free()
	player.free()
	get_tree().paused = false

func test_barrier_clamps_world_rewind() -> void:
	var player: Player = _new_player()
	var spawner: Node2D = SPAWNER_SCRIPT.new() as Node2D
	add_child(spawner)
	spawner.set_process(false)
	for frame: int in range(120):
		spawner.set("wave_elapsed", float(frame) / 60.0)
		_tick(player, frame)
		if frame == 80:
			# A wave boundary inside the window.
			player.world_rewind_recorder.mark_barrier(player.rewind_buffer)
	assert(player.activate_world_rewind(), "Rewind still works, but stops at the boundary.")
	_play_out(player)
	var restored: float = float(spawner.get("wave_elapsed"))
	assert(restored > 80.0 / 60.0, "World rewind never crosses the boundary (restored wave_elapsed %f)." % restored)
	spawner.free()
	player.free()
	get_tree().paused = false

func test_barrier_with_too_little_history_refuses_and_keeps_charge() -> void:
	var player: Player = _new_player()
	for frame: int in range(60):
		_tick(player, frame)
	player.world_rewind_recorder.mark_barrier(player.rewind_buffer)
	_tick(player, 60)
	assert(not player.activate_world_rewind(), "Boundary just happened: nothing to rewind to.")
	assert(player.rewind_charge_available, "Refused rewind keeps the wave's charge.")
	assert(not get_tree().paused)
	player.free()

## --- Stage 2b: loot drops + pickups + inventory revert (real Main, save-guarded rig) -------

func _rig_main():
	var main = HUD_RIG.instantiate()
	add_child(main)
	main.chasm_test_active = false
	if main.pickup_feed == null:
		# Real Main builds this in _ready; the save-guarded rig replaces _ready.
		main.pickup_feed = PickupFeed.new()
		main.get_node("CanvasLayer").add_child(main.pickup_feed)
	main.player.charged_guard_locked = true
	main.player.charged_guard_fully_charged = true
	return main

func _spawn_material(main, at: Vector2, item: String, amount: int) -> DropPickup:
	var drop: DropPickup = Main.DROP_SCENE.instantiate() as DropPickup
	main.add_child(drop)
	drop.global_position = at
	drop.setup(item, amount, 1)
	drop.set_physics_process(false)
	return drop

func test_material_pickup_in_window_returns_and_inventory_reverts() -> void:
	var main = _rig_main()
	var player: Player = main.player
	var before: int = main.home_progression.material_count("Stone")
	var bag: DropPickup = _spawn_material(main, Vector2(900, 300), "Stone", 3)
	for frame: int in range(120):
		if frame == 70:
			# Collected inside the window, through the real pickup path.
			player.global_position = bag.global_position
			bag._physics_process(1.0 / 60.0)
		else:
			_tick(player, frame)
	assert(bag.rewind_retired and bag.collected, "Collect retires the bag instead of freeing it.")
	assert(main.home_progression.material_count("Stone") == before + 3 and int(main.run_loot.items.get("Stone", 0)) == 3)
	var writes_before: int = main.write_attempts
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(is_instance_valid(bag) and not bag.rewind_retired and bag.visible and not bag.collected, "The bag is back on the ground.")
	assert(main.home_progression.material_count("Stone") == before, "Inventory gives the Stone back (got %d, expected %d)." % [main.home_progression.material_count("Stone"), before])
	assert(not main.run_loot.items.has("Stone"), "Run loot history no longer lists it.")
	assert(main.write_attempts > writes_before, "The undo is saved, so a save never holds both bag and item.")
	# Picking it up again works and counts once.
	player.global_position = bag.global_position
	bag._physics_process(1.0 / 60.0)
	assert(main.home_progression.material_count("Stone") == before + 3, "Re-collecting gives it once (no duplication).")
	get_tree().paused = false
	main.free()

func test_drop_spawned_in_window_is_removed() -> void:
	var main = _rig_main()
	var player: Player = main.player
	var late: DropPickup = null
	for frame: int in range(120):
		if frame == 90:
			late = _spawn_material(main, Vector2(500, 500), "Wood", 1) # e.g. dropped by an undone kill
		_tick(player, frame)
	assert(player.activate_world_rewind())
	_play_out(player)
	await get_tree().process_frame
	assert(not is_instance_valid(late), "A drop that appeared after the target vanishes.")
	get_tree().paused = false
	main.free()

func test_gear_pickup_in_window_reverts_by_id_without_touching_others() -> void:
	var main = _rig_main()
	var player: Player = main.player
	var keep: Dictionary = ArmoryConfig.roll_item(1, main.home_progression.generate_gear_id())
	main.home_progression.add_gear_item(keep)
	var item: Dictionary = ArmoryConfig.roll_item(1, main.home_progression.generate_gear_id())
	var gear: GearDropPickup = Main.GEAR_DROP_SCENE.instantiate() as GearDropPickup
	main.add_child(gear)
	gear.global_position = Vector2(900, 300)
	gear.setup(item)
	gear.set_physics_process(false)
	for frame: int in range(120):
		if frame == 70:
			player.global_position = gear.global_position
			gear._physics_process(1.0 / 60.0)
		else:
			_tick(player, frame)
	var item_id: String = str(item["id"])
	assert(not main.home_progression.gear_item_by_id(item_id).is_empty(), "Gear was collected.")
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(main.home_progression.gear_item_by_id(item_id).is_empty(), "That exact gear id leaves the inventory.")
	assert(not main.home_progression.gear_item_by_id(str(keep["id"])).is_empty(), "Unrelated gear is untouched.")
	assert(is_instance_valid(gear) and not gear.collected and gear.visible, "The gear bag is back on the ground.")
	var has_record: bool = false
	for record: Dictionary in main.run_loot.gear:
		if str(record.get("id", "")) == item_id: has_record = true
	assert(not has_record, "Run loot no longer lists that gear.")
	get_tree().paused = false
	main.free()

func test_uncollect_never_removes_equipped_gear() -> void:
	var main = _rig_main()
	var item: Dictionary = ArmoryConfig.roll_item(1, main.home_progression.generate_gear_id())
	main.home_progression.add_gear_item(item)
	main.home_progression.equipped_gear_ids[str(item["slot"])] = str(item["id"])
	main.uncollect_gear_drop(item)
	assert(not main.home_progression.gear_item_by_id(str(item["id"])).is_empty(), "Equipped gear is never removed by an undo.")
	main.free()

## Crash regression (live game): an enemy projectile whose shooter was freed must still record.
func test_capture_with_freed_reference_writes_zero_not_crash() -> void:
	var shooter: Node2D = Node2D.new()
	add_child(shooter)
	var projectile: EnemyProjectile = (preload("res://scenes/enemy_projectile.tscn") as PackedScene).instantiate() as EnemyProjectile
	add_child(projectile)
	projectile.set_physics_process(false)
	projectile.source_enemy = shooter
	shooter.free() # source reference is now a freed instance
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(projectile.rewind_stride())
	projectile.rewind_capture(data, 0)
	assert(data[7] == 0.0 and data[8] == 0.0 and data[9] == 0.0, "A freed source is recorded as 'no source'.")
	projectile.rewind_restore(data, 0)
	assert(projectile.source_enemy == null, "Restoring a freed source yields null, not a dangling reference.")
	projectile.free()

## --- Stage 2c: chakram + props -----------------------------------------------------------

const CHAKRAM_SCENE: PackedScene = preload("res://scenes/chakram.tscn")

func test_chakram_flight_restored_and_catch_undone() -> void:
	var player: Player = _new_player()
	var disc: Chakram = CHAKRAM_SCENE.instantiate() as Chakram
	add_child(disc)
	disc.set_physics_process(false)
	disc.launch(Vector2.RIGHT, player)
	player.active_chakrams.append(disc)
	player.chakram = disc
	player.chakram_charges = 0
	for frame: int in range(120):
		if frame < 60:
			disc.global_position = Vector2(200.0 + float(frame) * 4.0, 300.0)
		if frame == 60:
			# Lands, then the player catches it inside the window.
			disc.grounded = true
			player.collect_chakram(disc)
		_tick(player, frame)
	assert(disc.rewind_retired and player.chakram_charges == 1 and not player.active_chakrams.has(disc), "Caught disc is retired and back in hand.")
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(is_instance_valid(disc) and not disc.rewind_retired and disc.visible, "The disc is back in flight.")
	assert(not disc.grounded and disc.global_position.x < 440.0, "Flight position restored (x=%f)." % disc.global_position.x)
	assert(player.chakram_charges == 0, "Hand count follows: the disc is out again (got %d)." % player.chakram_charges)
	assert(player.active_chakrams.has(disc), "Player tracks the revived disc again.")
	disc.free()
	player.free()
	get_tree().paused = false

func test_chakram_thrown_after_target_is_removed_and_charge_returns() -> void:
	var player: Player = _new_player()
	player.chakram_charges = 1
	var late: Chakram = null
	for frame: int in range(120):
		if frame == 100:
			late = CHAKRAM_SCENE.instantiate() as Chakram
			add_child(late)
			late.set_physics_process(false)
			late.launch(Vector2.RIGHT, player)
			player.active_chakrams.append(late)
			player.chakram_charges = 0
		_tick(player, frame)
	assert(player.activate_world_rewind())
	_play_out(player)
	await get_tree().process_frame
	assert(not is_instance_valid(late), "A disc thrown after the target vanishes.")
	assert(player.chakram_charges == 1, "Its charge is back in hand.")
	player.free()
	get_tree().paused = false

func test_prop_broken_in_window_returns_whole_with_collision() -> void:
	var player: Player = _new_player()
	var rock: ArenaObject = ArenaObject.new()
	rock.object_kind = ArenaObject.ObjectKind.ROCK
	rock.blocks_navigation = true
	rock.chakram_breakable = true
	rock.max_health = 30.0
	rock.global_position = Vector2(600, 400)
	add_child(rock)
	for frame: int in range(120):
		if frame == 70:
			rock.hit_by_chakram(100.0)
		_tick(player, frame)
	assert(rock.broken and rock.body == null and not rock.visible, "Rock broke inside the window.")
	assert(player.activate_world_rewind())
	_play_out(player)
	assert(not rock.broken and is_equal_approx(rock.health, 30.0), "Rock is whole again at full health.")
	assert(rock.visible and rock.body != null and rock.body.collision_layer == 4, "Visual and collision are rebuilt.")
	assert(not rock.world_blocking_rects().is_empty(), "It blocks navigation again.")
	rock.free()
	player.free()
	get_tree().paused = false

func test_static_prop_never_removed_by_rewind() -> void:
	var player: Player = _new_player()
	for frame: int in range(100):
		_tick(player, frame)
	# Generated after the oldest sample but before activation: a missing sample must not delete it.
	var herb: ArenaObject = ArenaObject.new()
	herb.object_kind = ArenaObject.ObjectKind.HERB
	add_child(herb)
	for frame: int in range(100, 120):
		_tick(player, frame)
	assert(player.activate_world_rewind())
	_play_out(player)
	await get_tree().process_frame
	assert(is_instance_valid(herb) and not herb.is_queued_for_deletion(), "Map props are never treated as 'spawned mid-window'.")
	herb.free()
	player.free()
	get_tree().paused = false
