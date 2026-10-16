class_name ShamanStaffSpiralPresentation extends GoblinShamanRig
## Real Main spawn/cast path, deterministic time checkpoint; no save writes.
@export_range(0.0, 1.0) var checkpoint: float = 0.5

func _enter_tree() -> void:
	get_tree().debug_collisions_hint = false

func spawn_now() -> void:
	super.spawn_now()
	# Suppress only live-preset diagnostic overlays in memory.
	var player: Player = _player()
	if player != null: player.set_combat_contact_setting("blade_bone_debug_enabled", 0.0)
	if not is_instance_valid(caster) or not is_instance_valid(recipient): return
	# Prevent randomized terrain shoves/AI movement invalidating the checkpoint.
	caster.set_physics_process(false)
	recipient.set_physics_process(false)
	if not caster.begin_cast(recipient): return
	caster.advance_cast(caster.cast_duration * checkpoint)
	caster._update_hd_enemy_sprite()
	print("[STAFF SPIRAL] checkpoint=%.3f frame=%d anchor=%s flip=%s" % [caster.cast_elapsed / caster.cast_duration, caster.staff_spiral.frame, caster.staff_spiral.position, caster.staff_spiral.flip_h])
