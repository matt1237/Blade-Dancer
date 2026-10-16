extends "res://tests/chasm_walk_safe_main.gd"
## Ordinary weapon regression bench for the drive/response extraction. Real
## Main/Player, existing no-save Chasm lifecycle, live GP2 read-only. This is
## NOT evidence of a working dual-blade item or independent physical contacts.
var observed_sword_updates: int = 0

func _ready() -> void:
	super._ready()
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_global_presets.json"))
	assert(library is Dictionary, "Read-only regression bench requires the live GP2 library")
	var slot: Dictionary = library.get("slots", {}).get("2", {})
	assert(not slot.is_empty(), "Do not silently test packaged defaults as live GP2")
	# Same property composition as Main._apply_global_preset_state, restricted
	# to combat inputs. No init/migration, active-slot selection, clock or writer.
	player.combat_contact_preset = int(slot.get("selected_combat_preset", 2))
	for key: String in ["combat_hand_settings", "combat_contact_settings", "combat_weapon_hand_settings", "blade_profile_settings"]:
		if slot.get(key) is Dictionary:
			player.set(key, (slot[key] as Dictionary).duplicate(true))
	player.set_equipped_sword("Basic Longsword")
	player.set_input_mode(Player.INPUT_MODE_CONTROLLER)
	player.controller_aim_direction = Vector2.RIGHT
	player.invulnerable = 1000000.0
	print("[SWORD DRIVE REGRESSION] GP2 read-only; ordinary Longsword; 1/2 select Longsword/Curved Sword; no dual capability yet")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2]:
		player.set_equipped_sword("Basic Longsword" if event.keycode == KEY_1 else "Basic Curved Sword")
		print("[SWORD DRIVE REGRESSION] selected ", player.equipped_sword_id)
		get_viewport().set_input_as_handled()
		return

func _process(delta: float) -> void:
	super._process(delta)
	# A real controller-input gesture wakes the GP2 metronome without writing
	# phase, authored energy, reaction state or any weapon pose.
	observed_sword_updates += 1
	var aim: Vector2 = Vector2.from_angle(0.8 * sin(float(Time.get_ticks_msec()) * 0.006))
	for axis: int in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
		event.device = player.preferred_controller_device
		event.axis = axis as JoyAxis
		event.axis_value = aim.x if axis == JOY_AXIS_RIGHT_X else aim.y
		Input.parse_input_event(event)
