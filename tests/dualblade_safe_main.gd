extends "res://tests/sword_drive_safe_main.gd"
## Real Main, read-only GP2, real Armory equip, no startup/save/migration writers.
var dual_probe_time: float = 0.0
var probe_enemy: Enemy
var placed: bool = false
var independent_frames: int = 0
var trace_frames: int = 0
var evidence_held: bool = false

func _ready() -> void:
	super._ready()
	home_progression.add_gear_item(ArmoryConfig.dualblade_test_item())
	assert(home_progression.equip_gear(ArmoryConfig.DUALBLADE_ID))
	_apply_equipped_gear_to_player()
	assert(player.dualblade_equipped)
	print("[DUAL LIVE] actual in-memory Armory equip; GP2 unchanged; writes disabled; D = re-equip test, 1/2 ordinary regressions")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		print("[DUAL GRANT RESULT] ", grant_approved_dualblade_inventory())
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		_apply_equipped_gear_to_player()
		return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	dual_probe_time += delta
	if not player.dualblade_equipped or player.dual_blade_states.size() != 2: return
	var first: Dictionary = player.dual_blade_states[0].values
	var second: Dictionary = player.dual_blade_states[1].values
	var points: PackedVector2Array = first[&"current_blade_samples"]
	if points.size() < 2: return
	if not placed and dual_probe_time > 0.8:
		probe_enemy = preload("res://scenes/enemies/sword_goblin.tscn").instantiate()
		add_child(probe_enemy)
		probe_enemy.set_physics_process(false)
		probe_enemy.player_ref = player
		probe_enemy.health = 10000
		probe_enemy.max_health = 10000
		probe_enemy.weapon_origin_offset = 30.0
		probe_enemy.blade_length = 70.0
		probe_enemy.moving_weapon_enabled = true
		probe_enemy.parry_enabled = true
		probe_enemy.blade_angle = (points[-1] - points[0]).angle()
		var direction: Vector2 = Vector2.from_angle(probe_enemy.blade_angle)
		probe_enemy.global_position = points[0] - direction * 15.0
		var collider: CollisionShape2D = probe_enemy.get_node("CollisionShape2D")
		collider.shape = CircleShape2D.new()
		collider.shape.radius = 4.0
		placed = true
		print("[DUAL LIVE] real sword obstacle placed at ", probe_enemy.global_position, " weapon angle=", probe_enemy.blade_angle)
	trace_frames += 1
	var owns_a: bool = first[&"slide_cling_left"] > 0.0 or first[&"experimental_bind_candidate"] or first[&"experimental_bind_active"] or first[&"clash_recovery_left"] > 0.0
	var owns_b: bool = second[&"slide_cling_left"] > 0.0 or second[&"experimental_bind_candidate"] or second[&"experimental_bind_active"] or second[&"clash_recovery_left"] > 0.0
	var pose_a: Dictionary = first[&"dual_committed_pose"]
	var pose_b: Dictionary = second[&"dual_committed_pose"]
	if pose_a.is_empty() or pose_b.is_empty(): return
	var divergence: float = absf(angle_difference(pose_a["angle"], pose_b["angle"]))
	if not evidence_held and owns_a != owns_b and divergence > 0.02:
		independent_frames += 1
		if not evidence_held and independent_frames >= 1:
			evidence_held = true
			player.set_physics_process(false)
			_capture_dual_evidence.call_deferred()
			print("[DUAL INDEPENDENCE PROVED] first_owner=", owns_a, " second_owner=", owns_b, " angle_difference=", divergence, " trails=", first[&"blade_trail_points"], " / ", second[&"blade_trail_points"], " phase=", player.sword_phase, " writes=", write_attempts)
	if trace_frames % 30 == 0 and not evidence_held:
		print("[DUAL TRACE] phase=%.4f owners=%s/%s angles=%.4f/%.4f difference=%.4f independent_frames=%d writes=%d" % [player.sword_phase, owns_a, owns_b, pose_a["angle"], pose_b["angle"], divergence, independent_frames, write_attempts])

## Freezes the real frame for screenshot evidence (no file/save writes).
func _capture_dual_evidence() -> void:
	var first: Dictionary = player.dual_blade_states[0].values
	var second: Dictionary = player.dual_blade_states[1].values
	var a: PackedVector2Array = first[&"current_blade_samples"]
	var b: PackedVector2Array = second[&"current_blade_samples"]
	print("[DUAL EVIDENCE] blade lengths=%.2f/%.2f hilt separation=%.2f writes=%d" % [a[0].distance_to(a[-1]), b[0].distance_to(b[-1]), a[0].distance_to(b[0]), write_attempts])
	player.queue_redraw()
	get_tree().paused = false
