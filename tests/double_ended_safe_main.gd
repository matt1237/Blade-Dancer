extends "res://tests/sword_drive_safe_main.gd"
## Real Main, read-only GP2, real Armory equip of Double-Ended Iron Sword (Test).
## Writes disabled by the base bench; G is the ONLY explicit grant path.
var probe_time: float = 0.0
var handle_dummy: Enemy
var end_dummy: Enemy
var placed: bool = false
var logged: Dictionary = {}

func _ready() -> void:
	super._ready()
	home_progression.add_gear_item(ArmoryConfig.double_ended_test_item())
	assert(home_progression.equip_gear(ArmoryConfig.DOUBLE_ENDED_ID))
	_apply_equipped_gear_to_player()
	assert(player.double_ended_equipped)
	print("[DOUBLE LIVE] in-memory Armory equip; GP2 read-only; writes disabled")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		print("[DOUBLE GRANT RESULT] ", grant_approved_double_ended_inventory(), " writes=", write_attempts)
		return
	super._unhandled_input(event)

func _dummy(at: Vector2) -> Enemy:
	var enemy: Enemy = preload("res://scenes/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player_ref = player
	enemy.health = 100000.0
	enemy.max_health = 100000.0
	enemy.moving_weapon_enabled = false
	enemy.shield_enabled = false
	enemy.global_position = at
	return enemy

func _process(delta: float) -> void:
	super._process(delta)
	probe_time += delta
	if not player.double_ended_equipped or player.dual_blade_states.size() != 2: return
	var a: PackedVector2Array = player.dual_blade_states[0].values[&"current_blade_samples"]
	var b: PackedVector2Array = player.dual_blade_states[1].values[&"current_blade_samples"]
	if a.size() < 2 or b.size() < 2: return
	if not placed and probe_time > 0.8:
		placed = true
		# One dummy on end 0's grip zone, one on end 1's blade zone.
		handle_dummy = _dummy(a[0].lerp(a[-1], 0.2))
		end_dummy = _dummy(b[0].lerp(b[-1], 0.8))
		print("[DOUBLE LIVE] dummies placed handle=", handle_dummy.global_position, " end=", end_dummy.global_position)
	if player.sword_event_left > 0.0 and not logged.has(player.sword_event_label):
		logged[player.sword_event_label] = true
		print("[DOUBLE EVENT] ", player.sword_event_label, " at ", player.sword_event_point, " writes=", write_attempts)
	if int(probe_time * 2.0) != int((probe_time - delta) * 2.0):
		print("[DOUBLE TRACE] grip=%s tipA=%s tipB=%s axis_dot_aim=%.3f handleHP=%s endHP=%s writes=%d" % [a[0], a[-1], b[-1], Vector2.from_angle(player.aim_angle).dot((a[-1] - a[0]).normalized()), handle_dummy.health if handle_dummy else -1.0, end_dummy.health if end_dummy else -1.0, write_attempts])
