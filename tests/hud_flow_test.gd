extends Node
const RIG = preload("res://tests/hud_flow_safe_rig.tscn")

func test_rewind_icon_left_column_and_charge_alpha() -> void:
	var main = RIG.instantiate()
	add_child(main)
	var icon: TextureRect = main.get_node("CanvasLayer/RewindIcon")
	assert(icon.texture.resource_path == "res://assets/generated/Rewind Icon.png")
	assert(icon.size.is_equal_approx(Vector2(40, 40)) and icon.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	# Left column, below the lowest left HUD readout (Deflect), no overlap.
	var deflect: Control = main.get_node("CanvasLayer/DeflectLabel")
	assert(icon.position.x < 100.0 and icon.position.y >= deflect.get_rect().end.y + 8.0)
	for path: String in ["CanvasLayer/DashBar", "CanvasLayer/DashLabel", "CanvasLayer/GrappleLabel", "CanvasLayer/DeflectLabel", "CanvasLayer/StatusLabel"]:
		assert(not icon.get_rect().intersects((main.get_node(path) as Control).get_rect()), "Icon overlaps %s" % path)
	assert(is_equal_approx(icon.modulate.a, 1.0), "Opaque when the wave's rewind is unused.")
	main.player.rewind_charge_available = true
	main.player._consume_rewind_charge()
	assert(is_equal_approx(icon.modulate.a, Main.REWIND_ICON_USED_ALPHA), "Faded once used.")
	main._on_wave_started(4)
	assert(main.player.rewind_charge_available and is_equal_approx(icon.modulate.a, 1.0), "Main's wave start refills it and the icon returns.")
	main._set_world_visible(false)
	assert(not icon.visible, "Hidden with the world HUD.")
	main._set_world_visible(true)
	assert(icon.visible)
	assert(main.write_attempts == 0)
	main.free()

func test_flow_geometry_authority_and_no_caps() -> void:
	var main = RIG.instantiate()
	add_child(main)
	assert(main.flow_bar.size.is_equal_approx(Vector2(170, 25)), "15% shorter, ~15% thicker than 200x22")
	assert(main.flow_bar.position.is_equal_approx(Vector2(20, 78)))
	assert(main.get_node("CanvasLayer/FlowTrack").size.is_equal_approx(main.flow_bar.size))
	assert(main.get_node("CanvasLayer/FlowTrack").position.is_equal_approx(main.flow_bar.position))
	assert(main.flow_fill.position.is_equal_approx(main.flow_bar.position))
	assert(is_equal_approx(main.flow_fill.size.y, main.flow_bar.size.y))
	# Preserve the existing health row spacing; font minimum bounds include padding.
	assert(is_equal_approx(main.flow_bar.position.y - main.health_label.position.y, 30.0))
	assert(main.flow_bar.get_rect().end.y < main.flow_label.position.y)
	assert(main.flow_fill.texture == HealthBar.FILL_TEXTURE)
	assert(main.get_node("CanvasLayer/FlowTrack").texture == HealthBar.TRACK_TEXTURE)
	assert(main.flow_sparkle.text.is_empty())
	assert(main.flow_fill.get_child_count() == 0, "No caps/horns/frame children")
	for amount: float in [0.0, 50.0, 50.125, 100.0, -20.0, 150.0]:
		main._set_probe_flow(amount)
		var expected: float = clampf(amount / 100.0, 0.0, 1.0)
		assert(is_equal_approx(main.flow_fill.size.x, main.flow_bar.size.x * expected))
		assert(is_equal_approx(main.flow_fill.size.y, main.flow_bar.size.y))
		assert(main.flow_fill.visible == (expected > 0.0))
		assert(main.player.flow == amount, "HUD must not mutate Player authority")
	main.player.flow = 100.0
	main.player.flow_changed.emit(100.0, 200.0)
	assert(is_equal_approx(main.flow_fill.size.x, main.flow_bar.size.x * 0.5), "Signal max drives the Range and fill")
	main._set_world_visible(false)
	main._update_flow_fill()
	assert(not main.flow_fill.visible and not main.wave_timer_label.visible and not main.score_label.visible)
	assert(main.write_attempts == 0)
	main.free()

func test_private_three_yellow_palette_and_health_clock() -> void:
	var main = RIG.instantiate()
	var second = RIG.instantiate()
	var fill: TextureRect = main.get_node("CanvasLayer/FlowFill")
	var mat: ShaderMaterial = fill.material
	assert(mat != second.get_node("CanvasLayer/FlowFill").material)
	assert(mat.shader != HealthBar.FLOW_SHADER)
	assert(mat.get_shader_parameter("pale_yellow").is_equal_approx(Color(1, 0.94, 0.58)))
	assert(mat.get_shader_parameter("dark_gold").is_equal_approx(Color(0.65, 0.4, 0.04)))
	assert(mat.get_shader_parameter("bright_yellow").is_equal_approx(Color(1, 0.84, 0.08)))
	assert(is_equal_approx(mat.get_shader_parameter("flow_speed"), 0.35))
	assert(is_equal_approx(mat.get_shader_parameter("flow_bands"), 1.0))
	var clock: String = "sin(UV.x * flow_bands * TAU - TIME * flow_speed * TAU)"
	assert(mat.shader.code.contains(clock) and HealthBar.FLOW_SHADER.code.contains(clock))
	assert(mat.shader.code.contains("COLOR.rgb *= tint"), "Preserve health fill's vertical sheen")
	# Fixed pixel's wave moves with TIME, not Flow value, at the health cadence.
	assert(absf(sin(0.2 * TAU) - sin(0.2 * TAU - 0.35 * TAU)) > 0.5)
	main.free()
	second.free()

func test_centered_timer_score_at_multiple_logical_viewports() -> void:
	# canvas_items + default keep aspect scales 1280x720 on narrow/mobile screens;
	# also exercise wider and smaller logical canvases without changing project settings.
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 720), Vector2i(960, 720), Vector2i(640, 360)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		add_child(viewport)
		var main = RIG.instantiate()
		viewport.add_child(main)
		main._process(0.0)
		assert(main.wave_timer_label.text == "TIME: 17")
		assert(main.wave_label.text == "Wave: 3")
		assert(main.health_label.text.is_empty() and main.flow_label.text.is_empty(), "No numeric HP/Flow readouts")
		# Wave sits immediately left of the centered timer on the same row.
		assert(is_equal_approx(main.wave_label.position.y, main.wave_timer_label.position.y))
		assert(main.wave_label.get_rect().end.x <= dimensions.x * 0.5 and main.wave_timer_label.position.x >= dimensions.x * 0.5)
		assert(main.score == 1234566 and main.score_label.text == "Score: 1234566")
		for label: Label in [main.score_label]:
			assert(is_equal_approx(label.get_rect().get_center().x, dimensions.x * 0.5))
			assert(label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER)
			assert(label.size.x >= label.get_minimum_size().x)
			assert(label.anchor_left == 0.5 and label.anchor_right == 0.5)
		# More digits use the existing score update path, retaining responsive centering.
		main._on_enemy_defeated(1000000000)
		assert(main.score_label.text == "Score: %d" % main.score)
		assert(is_equal_approx(main.score_label.get_rect().get_center().x, dimensions.x * 0.5))
		assert(main.score_label.size.x >= main.score_label.get_minimum_size().x)
		main.spawner.wave_elapsed = 22.0
		main._process(0.0)
		assert(main.wave_timer_label.text == "TIME: 8" and main.wave_label.text == "Wave: 3")
		assert(main.wave_timer_label.get_rect().end.y < main.score_label.position.y)
		assert(main.wave_timer_label.position.y >= 18.0)
		main.mobile_controls.force_visible_on_desktop = true
		main.mobile_controls.set_gameplay_visible(true)
		assert(main.mobile_controls.left_stick_center.y - main.mobile_controls.current_stick_radius > main.score_label.get_rect().end.y)
		assert(main.mobile_controls.right_stick_center.y - main.mobile_controls.current_stick_radius > main.score_label.get_rect().end.y)
		assert(main.score_label.get_rect().end.y < main.flow_bar.position.y)
		for beat_size: float in [0.5, 1.0, 2.5]:
			main.metronome_top_bar.set_beat_visualizer_size(beat_size)
			main.metronome_top_bar._process(0.0)
			var visualizer = main.metronome_top_bar.visualizer
			assert(visualizer.position.y - 88.0 * visualizer.scale.y >= main.score_label.get_rect().end.y + 12.0 - 0.001, "Beat bounds must clear score at every size")
		assert(main.write_attempts == 0)
		viewport.free()
