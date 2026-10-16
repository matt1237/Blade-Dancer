class_name SharedSwordFormsSafeMain
extends "res://tests/sword_drive_safe_main.gd"
## Read-only GP2 / no-save Main lifecycle inherited from the established rig.
var form_probe_label: Label

func _ready() -> void:
	super._ready()
	player.set_input_mode(Player.INPUT_MODE_KEYBOARD_MOUSE)
	player.set_sword_form(Player.SwordStyle.WINDUP_THRUST)
	player.style_changed.connect(func(form_name: String) -> void:
		print("[SHARED FORMS] ", form_name, " weapon=", _probe_weapon_name(), " writes=", write_attempts)
	)
	var overlay: CanvasLayer = CanvasLayer.new()
	add_child(overlay)
	form_probe_label = Label.new()
	form_probe_label.position = Vector2(18.0, 620.0)
	overlay.add_child(form_probe_label)
	print("[SHARED FORMS] GP2 read-only. 1 Longsword / 2 Dual Blade / 3 Double-ended. Z/X previous/next. No persistence.")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_1, KEY_2, KEY_3]:
		var weapon: String = "Basic Longsword"
		if event.keycode == KEY_2:
			weapon = ArmoryConfig.DUALBLADE_NAME
		elif event.keycode == KEY_3:
			weapon = ArmoryConfig.DOUBLE_ENDED_NAME
		player.set_equipped_sword(weapon)
		print("[SHARED FORMS] selected ", _probe_weapon_name(), " form=", player._style_name(), " writes=", write_attempts)
		get_viewport().set_input_as_handled()
		return

func _process(delta: float) -> void:
	super._process(delta)
	form_probe_label.text = "%s | %s\n1 Longsword / 2 Dual Blade / 3 Double-ended | Z/X forms | writes=%d" % [player._style_name(), _probe_weapon_name(), write_attempts]

func _probe_weapon_name() -> String:
	if player.double_ended_equipped:
		return "Double-ended Sword"
	return "Dual Blade" if player.dualblade_equipped else "Longsword"
