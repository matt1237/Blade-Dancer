class_name PXInWorldRespawnTest extends Node
## Integration check for the report "spawned chasers don't respawn after they die".
##
## This boots the REAL res://scenes/main.tscn, drives it into the Backyard run, turns
## PX Mode on, spawns a chaser through the live PX enemy manager, KILLS it exactly the
## way the sword's cut does, then waits real physics frames and asserts a fresh chaser
## is alive again. The isolated unit test already proved the timer maths; this proves
## the wiring runs inside the actual game world (unpaused tree and all).

const RESPAWN_WAIT_FRAMES: int = 150  # Cfg.RESPAWN_DELAY is 1.1 s; 150 frames ~ 2.5 s

func _wait_frames(n: int) -> void:
	for i: int in range(n):
		await get_tree().physics_frame

func test_inworld_chaser_respawns_after_death() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	assert(scene != null, "main.tscn must load.")
	var main: Node = scene.instantiate()
	add_child(main)

	var guard: int = 0
	while guard < 240 and not (main.get("player") != null and is_instance_valid(main.get("player"))):
		await get_tree().process_frame
		guard += 1
	var player: Node2D = main.get("player") as Node2D
	assert(player != null, "Main must boot a player before PX Mode can come online.")

	main.call("_start_backyard_run")
	await _wait_frames(3)
	get_tree().paused = false
	main.call("set_px_mode", true)
	await _wait_frames(10)

	var px: Node = main.get("px_inworld")
	assert(px != null, "PX in-world sword must be live after set_px_mode(true).")
	var enemies: Node = px.get("enemies")
	assert(enemies != null, "The PX enemy manager must exist under the in-world sword.")

	# chaser_wanted on (the saved setup already spawns one at _ready); make sure one is live.
	enemies.set("chaser_wanted", true)
	await _wait_frames(3)
	print("[RESPAWN] after enable: entries=", (enemies.get("enemies") as Array).size(),
		" has_chaser=", enemies.call("_has_enemy", false))
	assert(enemies.call("_has_enemy", false), "A chaser must be alive when chaser_wanted is on.")

	# Kill EVERY chaser exactly the way the sword's cut does (flesh hit -> hp 0 ->
	# despawn + erase), so we start from a clean "none alive".
	var list: Array = enemies.get("enemies")
	for e: Dictionary in list.duplicate():
		if not bool(e.get("test_dummy", false)):
			enemies.call("_despawn_enemy", e)
			list.erase(e)
	await _wait_frames(3)
	print("[RESPAWN] after kill: entries=", (enemies.get("enemies") as Array).size(),
		" has_chaser=", enemies.call("_has_enemy", false))
	assert(not enemies.call("_has_enemy", false), "No chaser may remain after they are killed.")

	# The manager must bring exactly one back after the respawn delay.
	await _wait_frames(RESPAWN_WAIT_FRAMES)
	assert(enemies.call("_has_enemy", false),
		"A chaser must respawn after death inside the real game world.")
	# The respawn must land INSIDE the screen (viewport 1280x720 -> half-extents
	# 640 x 360), so the player actually sees it come back.
	var found: bool = false
	for e: Dictionary in (enemies.get("enemies") as Array):
		if bool(e.get("test_dummy", false)):
			continue
		var b: Node2D = e["body"]
		if not is_instance_valid(b):
			continue
		found = true
		var off: Vector2 = b.global_position - player.global_position
		assert(absf(off.x) <= 640.0 and absf(off.y) <= 360.0,
			"A respawned chaser must land inside one screen; got offset %s." % str(off.round()))
	assert(found, "A respawned chaser must be present to measure.")

	main.queue_free()