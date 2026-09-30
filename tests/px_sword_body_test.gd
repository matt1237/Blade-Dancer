class_name PXSwordBodyTest extends Node

## The sword BODY's physical properties — mass, passive damping, centre of mass —
## are real rigid-body settings on the blade the motor drives. These checks pin the
## contract: the four knobs reach the body, damping is REPLACE (so 0 is honestly 0),
## the centre of mass is CUSTOM and clamped to the blade, and none of it is a pose
## write — the body stays a free rigid body. The PX save is captured and restored so
## the test can never leave stray data behind.

const Cfg = preload("res://blade_dancer_px/scripts/px_config.gd")
const PX_SAVE_PATH: String = "user://bdpx_global.json"

func _read_or_empty(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""

func _restore(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()

func test_sword_body_settings_reach_the_rigid_body() -> void:
	var had_save: bool = FileAccess.file_exists(PX_SAVE_PATH)
	var original: String = _read_or_empty(PX_SAVE_PATH)
	# Start from a clean PX state so the default the body carries is deterministic.
	BDPXGlobal.clear_save()

	# The real player is a CharacterBody2D; the blade makes a collision exception
	# with it, which only works between two PhysicsBody2D nodes.
	var player: CharacterBody2D = CharacterBody2D.new()
	add_child(player)
	var px: PXInWorld = PXInWorld.new()
	px.setup(player)
	add_child(px)  # _ready builds the blade and applies the body.
	assert(px.blade != null, "PXInWorld must build a blade body.")

	# Defaults come from px_config and must be what the body actually carries.
	assert(is_equal_approx(px.blade.mass, Cfg.SWORD_MASS_DEFAULT), "The blade must start at the default mass.")
	assert(px.blade.center_of_mass_mode == RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM, "The centre of mass must be set explicitly so the knob is authoritative.")

	# Apply a deliberate body setup and check each value lands on the rigid body.
	px.apply_settings({
		"sword_mass": 3.5,
		"sword_angular_damp": 4.0,
		"sword_linear_damp": 6.0,
		"com_offset": 20.0,
	})
	assert(is_equal_approx(px.blade.mass, 3.5), "Sword Mass must reach the rigid body.")
	assert(is_equal_approx(px.blade.angular_damp, 4.0), "Angular Damping must reach the rigid body.")
	assert(is_equal_approx(px.blade.linear_damp, 6.0), "Linear Damping must reach the rigid body.")
	assert(px.blade.angular_damp_mode == RigidBody2D.DAMP_MODE_REPLACE, "Angular damping must REPLACE, so 0 is honestly off rather than the project default quietly adding in.")
	assert(px.blade.linear_damp_mode == RigidBody2D.DAMP_MODE_REPLACE, "Linear damping must REPLACE too.")
	assert(px.blade.center_of_mass.is_equal_approx(Vector2(20.0, 0.0)), "Centre of mass must move along the blade from the hilt.")

	# Out-of-range offsets clamp to the blade, never beyond it.
	px.apply_settings({"com_offset": 999.0})
	assert(px.blade.center_of_mass.x <= Cfg.BLADE_LENGTH + 0.001, "Centre of mass must never sit off the blade.")

	# Body properties, not pose writes: the blade must still be a free rigid body.
	assert(not px.blade.freeze and not px.blade.lock_rotation, "The sword body must stay physical — no freeze, no rotation lock, no pose write.")

	px.shutdown()
	px.queue_free()
	player.queue_free()

	BDPXGlobal.clear_save()
	if had_save:
		_restore(PX_SAVE_PATH, original)