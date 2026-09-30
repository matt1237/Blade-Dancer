class_name PXFleshCoreTest extends Node
## The flesh/core material model behind the Flesh & Core tab. These checks pin the
## physics contract the feel depends on: the blade is DRAGGED inside the flesh ring
## and gripped harder on the bone core, and there is no drag at all in open air.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PXBlade = preload("res://blade_dancer_px/scripts/px_blade.gd")

func _make_manager() -> Dictionary:
	var player: CharacterBody2D = CharacterBody2D.new()
	add_child(player)
	player.global_position = Vector2.ZERO
	var sword: RigidBody2D = PXBlade.make_blade(self, Cfg.L_PLAYER_SWORD, 0x7FFFFFFF)
	sword.global_position = Vector2(40.0, 0.0)
	var manager: PXInWorldEnemies = PXInWorldEnemies.new()
	add_child(manager)
	manager.setup(player, sword)
	manager.set_physics_process(false)
	return {"player": player, "sword": sword, "manager": manager}

func test_drag_is_zero_in_air_and_opposes_the_blade_in_the_flesh_and_on_the_bone() -> void:
	var rig: Dictionary = _make_manager()
	var manager: PXInWorldEnemies = rig["manager"]
	manager.apply_settings({"flesh_radius": 26.0, "core_radius": 10.0, "flesh_drag": 0.5, "bone_friction": 0.35})
	assert(is_equal_approx(manager.flesh_radius, 26.0) and is_equal_approx(manager.core_radius, 10.0), "The material sliders must set the radii.")
	assert(is_equal_approx(manager.flesh_drag, 0.5) and is_equal_approx(manager.bone_friction, 0.35), "The material sliders must set drag and bone friction.")

	# Outside the flesh: no drag at all — the blade is free.
	assert(is_zero_approx(manager._drag_torque_for(40.0, 5.0)), "Beyond the flesh there must be zero drag.")

	# In the flesh ring: drag opposes the spin and scales with the slider.
	var flesh_torque: float = manager._drag_torque_for(18.0, 5.0)
	assert(flesh_torque < 0.0, "A positive (CCW) spin must be retarded by a negative drag in the flesh.")
	assert(is_equal_approx(flesh_torque, -Cfg.FLESH_DRAG_MAX * 0.5 * 5.0), "Flesh drag must scale with the slider and the blade's spin.")

	# On the bone core: it grips harder than the flesh.
	var bone_torque: float = manager._drag_torque_for(5.0, 5.0)
	assert(bone_torque < flesh_torque, "The bone core must grip harder than the flesh.")

	# The drag always OPPOSES motion — reverse the spin and its sign flips.
	assert(manager._drag_torque_for(5.0, -5.0) > 0.0, "Drag must always oppose the blade's motion, whichever way it spins.")

	manager.free()
	_free_rig(rig)

func test_material_defaults_are_medium_and_internally_sane() -> void:
	var defaults: Dictionary = BDPXGlobal.default_settings()
	assert(is_equal_approx(float(defaults["flesh_radius"]), Cfg.FLESH_RADIUS_DEFAULT), "Flesh radius default must come from config.")
	assert(is_equal_approx(float(defaults["core_radius"]), Cfg.BONE_CORE_RADIUS_DEFAULT), "Core radius default must come from config.")
	assert(float(defaults["core_radius"]) > 0.0 and float(defaults["core_radius"]) < float(defaults["flesh_radius"]), "The bone core must be smaller than the flesh ring.")
	assert(is_equal_approx(float(defaults["flesh_drag"]), 0.5), "Flesh drag default must be the MEDIUM 0.5.")
	assert(is_equal_approx(float(defaults["bone_friction"]), 0.35), "Bone friction default must be the MEDIUM 0.35.")
	assert(is_equal_approx(float(defaults["enemy_mass"]), Cfg.ENEMY_MASS), "Enemy mass default must come from config.")

func _free_rig(rig: Dictionary) -> void:
	var player: Node = rig["player"]
	if is_instance_valid(player):
		player.free()
	var sword: Node = rig["sword"]
	if is_instance_valid(sword):
		sword.free()