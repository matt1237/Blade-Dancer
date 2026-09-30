class_name PXInWorldEnemiesTest extends Node
## The lab's spawnable targets, brought into the world. These checks pin the
## contract the Enemies tab depends on: each toggle spawns a REAL rigid body (so
## the blade can shove it), toggling off removes it, and the physics sword's cut
## actually lands on it.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")

func _make_rig() -> Dictionary:
	var player: CharacterBody2D = CharacterBody2D.new()
	add_child(player)
	player.global_position = Vector2.ZERO
	var sword: RigidBody2D = PXBlade.make_blade(self, Cfg.L_PLAYER_SWORD, 0x7FFFFFFF)
	sword.global_position = Vector2(40.0, 0.0)
	var manager: PXInWorldEnemies = PXInWorldEnemies.new()
	add_child(manager)
	manager.setup(player, sword)
	# Now that the rig is up, quiet the automatic step so these checks are
	# deterministic (we drive the manager by hand below).
	manager.set_physics_process(false)
	return {"player": player, "sword": sword, "manager": manager}

func test_toggles_spawn_physical_enemies_and_the_sword_cuts_them() -> void:
	var rig: Dictionary = _make_rig()
	var manager: PXInWorldEnemies = rig["manager"]
	var sword: RigidBody2D = rig["sword"]

	assert(manager.enemies.is_empty(), "The manager must start with no enemies.")

	# Chaser toggle spawns exactly one rigid body (not a kinematic wallbody).
	manager.apply_settings({"chaser_wanted": true})
	assert(manager.enemies.size() == 1, "Spawn Chaser must create one enemy.")
	assert(manager.enemies[0]["body"] is RigidBody2D, "A PX enemy must be a real rigid body, so the sword can shove it.")
	assert(not manager._has_enemy(true), "The chaser must be an unarmed enemy.")

	# Toggling off removes it.
	manager.apply_settings({"chaser_wanted": false})
	assert(manager.enemies.is_empty(), "Toggling Spawn Chaser off must remove the enemy.")

	# Sword enemy is armed and carries its own blade.
	manager.apply_settings({"sword_enemy_wanted": true})
	assert(manager._has_enemy(true), "Spawn Sword Enemy must create an armed enemy.")
	assert(manager.enemies[0]["sword"] is RigidBody2D, "An armed enemy must carry its own blade body.")
	manager.apply_settings({"sword_enemy_wanted": false})
	assert(manager.enemies.is_empty(), "Toggling the sword enemy off must remove it.")

	# Test dummy spawns and the physics sword's segment test damages it.
	manager.apply_settings({"test_dummy_wanted": true})
	assert(manager._has_test_dummy(), "Spawn Test Dummy must create a dummy.")
	var dummy: Dictionary = manager.enemies[0]
	var hp_before: float = float(dummy["hp"])
	# Place the live blade across the dummy (the dummy spawns at player + (0,-170)).
	sword.global_position = Vector2(0.0, -170.0)
	sword.rotation = 0.0
	manager._resolve_sword_hits()
	assert(float(dummy["hp"]) < hp_before, "A blade overlapping the dummy must land a cut.")
	manager.free()
	var player: Node = rig["player"]
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(sword):
		sword.free()