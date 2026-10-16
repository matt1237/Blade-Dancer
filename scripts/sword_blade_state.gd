class_name SwordBladeState extends RefCounted
## Scoped adapter for the normal-OS contact helpers in Player. NOT a second
## tuning/aim/clock authority. Used by the normal-OS Dualblade capability.
## No await, drawing or asynchronous re-entry while a scope is installed.
## Arrays/dictionaries are copied; Enemy/solver/shell/audio identities are not.
## A newly equipped multi-blade weapon must seed each state from a CLEAN player
## response, never clone a live solver/shell/bind from another blade.

# Exact blade-local property inventory, audited against _check_sword_hits,
# _sword_intent_transform, bone/flesh/shell/roll helpers and Bind/slide helpers.
# Shared, deliberately excluded: phase/time, aim, authored energy/drive/Guard,
# swing_count/hit_ids/enemy_rehit_cooldowns, bonuses, tuning and player momentum.
const FIELDS: Array[StringName] = [
	&"dual_response_aim_offset", &"dual_response_rate", &"dual_committed_pose",
	# Resolved pose, temporal collision geometry and trails.
	&"previous_blade_start", &"previous_blade_end", &"current_blade_samples",
	&"previous_blade_samples", &"blade_velocity", &"blade_trail_points", &"hilt_trail_points",
	&"collision_sword_solver", &"collision_sword_pose", &"collision_sword_roll",
	# Impact/freeze/hold and wall response.
	&"sword_hit_recoil_offset", &"wall_recoil_cooldown", &"clash_recovery_left",
	&"blade_freeze_left", &"frozen_blade_world_angle", &"grip_authority_left", &"rebound_flow_sign",
	&"sword_fire_left", &"blade_contact_flash_left",
	&"blade_core_yield_pending", &"blade_core_yield_multiplier", &"blade_flesh_overlap_active",
	&"blade_sink_strength_active", &"blade_sink_multiplier", &"blade_sink_contact_left",
	&"blade_bone_stop_left", &"blade_bone_stop_cooldown_left", &"bone_clash_cooldown_left",
	&"blade_glance_angle", &"blade_wall_glance_angle", &"blade_bite_pending", &"blade_bite_offset",
	&"blade_body_surface_pending", &"blade_body_surface_offset", &"blade_hard_pending",
	&"blade_hard_offset", &"blade_hard_point", &"blade_hard_bind_left",
	&"blade_hard_clash_cooldown", &"blade_hard_clash_armed",
	# Bone constraint, delayed separation and ownership.
	&"bone_constraint_angle_pending", &"bone_constraint_angle", &"bone_constraint_active",
	&"bone_constraint_enemy_id", &"bone_constraint_fraction", &"bone_constraint_iterations",
	&"bone_constraint_contact", &"bone_constraint_normal", &"bone_constraint_hold",
	&"bone_constraint_last_angle", &"bone_constraint_has_last", &"bone_constraint_depth",
	&"bone_constraint_hilt_inside", &"bone_hilt_push_pending",
	&"pending_sword_impulse", &"pending_sword_impulse_id", &"pending_sword_impulse_left",
	&"pending_sword_recoil", &"pending_sword_recoil_left", &"contact_hold_left",
	&"bone_slide_left", &"bone_slide_target_id", &"bone_bind_left", &"bone_bind_dwell",
	&"bone_bind_missing", &"bone_bind_locked", &"bone_bind_target_id", &"bone_hold_multiplier",
	&"blade_shell", &"blade_shell_offset", &"blade_shell_angle",
	&"flesh_bind_grip", &"flesh_bind_multiplier", &"flesh_bind_pending_depth",
	&"flesh_bind_target_id", &"flesh_bind_prev_aim", &"flesh_bind_contact_normal",
	# Actual edge orientation and slide contact owner.
	&"blade_roll", &"blade_roll_target", &"blade_roll_cooldown_left", &"blade_travel_sign",
	&"blade_travel_sign_candidate", &"blade_travel_sign_candidate_left", &"slide_cling_left",
	&"preset_2_slide_visual_left", &"preset_2_slide_distance_on_blade",
	&"preset_2_slide_contact_point", &"preset_2_slide_opponent",
	&"slide_audio_left", &"slide_audio_player",
	# Bind acquisition, retention, release and later real-contact re-entry.
	&"experimental_bind_opponent", &"experimental_bind_candidate", &"experimental_bind_active",
	&"experimental_bind_contact_seen", &"experimental_bind_stable_time", &"experimental_bind_elapsed",
	&"experimental_bind_missing_time", &"experimental_bind_cooldown_left", &"experimental_bind_contact_point",
	&"experimental_bind_pressure", &"experimental_bind_previous_pressure", &"experimental_bind_player_pressure",
	&"experimental_bind_previous_player_pressure", &"experimental_bind_tangent_speed", &"experimental_bind_tangent_travel",
	&"experimental_bind_leverage", &"experimental_bind_start_enemy_fraction", &"experimental_bind_enemy_fraction",
	&"experimental_bind_total_contact_time", &"experimental_bind_start_roll", &"experimental_bind_roll_crossed",
	&"experimental_bind_beat_consumed", &"experimental_bind_hinge_side", &"experimental_bind_last_enemy_direction",
	&"experimental_bind_release_reason", &"experimental_bind_outcome", &"experimental_bind_wind_reported",
	&"experimental_reentry_opponent", &"experimental_reentry_time_left", &"experimental_reentry_total_window",
	&"experimental_reentry_release_point", &"experimental_reentry_inward_direction",
	&"experimental_reentry_leverage", &"experimental_reentry_was_rollover",
	# Blade-local contact presentation. Session counters remain shared.
	&"sword_event_label", &"sword_event_point", &"sword_event_left", &"contact_spark_left",
	&"contact_spark_point", &"contact_spark_count", &"contact_spark_color", &"contact_spark_direction",
]

var values: Dictionary[StringName, Variant] = {}

func capture(player: Player) -> void:
	for field: StringName in FIELDS:
		values[field] = _copy_value(player.get(field))

func apply(player: Player) -> void:
	assert(values.size() == FIELDS.size(), "Capture a clean response before installing blade state")
	for field: StringName in FIELDS:
		player.set(field, _copy_value(values[field]))

## Install only blade-local state, run one synchronous response operation,
## capture it, and restore the caller's blade state. Shared hit/clock/player
## side effects intentionally survive. Callback must not yield or re-enter.
func with_applied(player: Player, response: Callable) -> void:
	var caller: SwordBladeState = SwordBladeState.new()
	caller.capture(player)
	apply(player)
	response.call()
	capture(player)
	caller.apply(player)

static func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	if value is PackedVector2Array:
		return value.duplicate()
	return value
