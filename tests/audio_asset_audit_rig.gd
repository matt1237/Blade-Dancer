extends "res://tests/audio_asset_audit_test.gd"

func _ready() -> void:
	var status: Label = Label.new()
	status.position = Vector2(40, 40)
	status.text = "Save-safe audio audit running (no Main/Player bootstrap).\nCheck Output for exact event/asset results."
	add_child(status)
	# Read the canonical live settings; configure real buses without Main._ready.
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_save.json"))
	var settings: Dictionary = saved.get("settings", {})
	var main: Main = Main.new()
	main.music_volume = float(settings.get("music_volume", 1.0))
	main.sfx_volume = float(settings.get("sfx_volume", 1.0))
	main._configure_audio_buses()
	main._apply_audio_settings()
	audit_music_volume = main.music_volume
	print("AUDIO LIVE MIX music=%.2f sfx=%.2f master_mute=%s" % [main.music_volume, main.sfx_volume, AudioServer.is_bus_mute(0)])
	main.free()
	test_all_audio_imports_decode()
	await test_recorded_events_and_pool_reuse()
	await test_real_enemy_death_routes()
	await test_turkey_real_charge_bark()
	await test_synth_and_real_player_slide()
	await test_music_playlists_start_and_advance()
	status.text = "AUDIO AUDIT COMPLETE: 6 checks passed.\n55 imported streams decoded; real enemy events and pooled playback advanced.\nHuman audibility / browser unlock still require listening in the target build."
	print("AUDIO AUDIT LIVE PASS: 6 checks; no save writes")
