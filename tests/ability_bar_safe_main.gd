class_name AbilityBarSafeMain
extends "res://tests/chasm_walk_safe_main.gd"
## Real Main/Player HUD and input, existing no-save lifecycle. GP2 is read-only.
var ability_probe_seconds: float = 0.0

func _ready() -> void:
	super._ready()
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_global_presets.json"))
	if library is Dictionary:
		var slot: Dictionary = library.get("slots", {}).get("2", {})
		player.combat_contact_preset = int(slot.get("selected_combat_preset", 2))
		# Same GP2 visualizer settings as normal startup, without migration/writers.
		beat_visualizer_size = clampf(float(slot.get("beat_visualizer_size", 1.0)), 0.5, 2.5)
		beat_pulse_percent = clampf(float(slot.get("beat_pulse_percent", 50.0)), 0.0, 100.0)
		visualizer_counts = clampi(int(slot.get("visualizer_counts", 2)), 1, 4)
		metronome_visualizer_palette = str(slot.get("metronome_visualizer_palette", "gold"))
		for key: String in ["combat_hand_settings", "combat_contact_settings", "combat_weapon_hand_settings", "blade_profile_settings"]:
			if slot.get(key) is Dictionary:
				player.set(key, (slot[key] as Dictionary).duplicate(true))
	player.invulnerable = 1000000.0
	_apply_metronome_visualizer_mode()
	Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)
	player.rewind_finished.connect(func(_at: Vector2) -> void:
		print("[ABILITY RIG] rewind stopped; rewind_cd=", player.ability_cooldowns.left("rewind"), " slow_cd=", player.ability_cooldowns.left("slow"), " writes=", write_attempts)
	)
	print("[ABILITY RIG] 1 Rewind / 2 Slow; repeat to stop; click icons; hover + Q/E to rebind. No persistence.")

func _process(delta: float) -> void:
	super._process(delta)
	ability_probe_seconds += delta
	if ability_probe_seconds >= 1.0:
		ability_probe_seconds = 0.0
		var bar: AbilityBar = $CanvasLayer/AbilityBar
		print("[ABILITY RIG] bindings=", bar.key_labels[0].text, "/", bar.key_labels[1].text, " CDs=", player.ability_cooldowns.remaining, " active=", player.rewind_active, "/", WorldTime.slow_active(), " chakram=", player.chakram_charges, " grapple=", player.grapple_charges, " writes=", write_attempts)
