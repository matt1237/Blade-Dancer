class_name MetronomeVisualizerTest extends Node

func _make_visualizer() -> MetronomeVisualizer:
	var visualizer: MetronomeVisualizer = MetronomeVisualizer.new()
	add_child(visualizer)
	visualizer.set_process(false)
	return visualizer

func test_stationary_single_core_and_fixed_textures() -> void:
	var visualizer: MetronomeVisualizer = _make_visualizer()
	var core_transform: Transform2D = visualizer._core.transform
	var texture: Texture2D = visualizer._energy.texture
	assert(not texture is AtlasTexture)
	assert(texture.resource_path == "res://assets/generated/metronome_gold_corona.png")
	assert(visualizer.get_child_count() == 2)
	assert(bool(visualizer._core_material.get_shader_parameter("core_layer")))
	assert(not bool(visualizer._energy_material.get_shader_parameter("core_layer")))
	for i: int in range(101):
		visualizer._update_visual(float(i) / 100.0)
		assert(visualizer._core.transform == core_transform)
		assert(visualizer._core.position == Vector2.ZERO)
		assert(visualizer._core.visible)
		assert(visualizer._energy.position == Vector2.ZERO)
		assert(visualizer._energy.texture == texture)
		assert(not visualizer._energy.region_enabled)
	visualizer.free()

func test_counted_peak_and_continuous_boundaries() -> void:
	var visualizer: MetronomeVisualizer = _make_visualizer()
	assert(visualizer.visualizer_counts == 2)
	for counts: int in range(1, 5):
		visualizer.set_visualizer_counts(counts)
		for percent: float in [0.0, 10.0, 50.0, 90.0, 100.0]:
			visualizer.set_beat_percent(percent)
			var peak: Dictionary = visualizer.sample_envelope(percent / 100.0, counts - 1)
			assert(is_equal_approx(float(peak["energy"]), 1.0))
			for stroke: int in range(counts * 3):
				var left: Dictionary = visualizer.sample_envelope(1.0 - 0.00001, stroke)
				var right: Dictionary = visualizer.sample_envelope(0.0, stroke + 1)
				assert(absf(float(left["energy"]) - float(right["energy"])) < 0.0001)
			var rest_position: float = float(counts - 1) + percent / 100.0 + float(counts) * 0.5
			assert(is_zero_approx(float(visualizer.sample_envelope(fmod(rest_position, 1.0), floori(rest_position))["energy"])))
	visualizer.free()

func test_settings_safe_before_ready_and_endpoint_thresholds() -> void:
	var visualizer: MetronomeVisualizer = MetronomeVisualizer.new()
	visualizer.configure(null, 30.0, "blue")
	visualizer.set_display_enabled(false)
	add_child(visualizer)
	visualizer.set_process(false)
	assert(not visualizer.visible)
	assert(visualizer.palette == "blue")
	var texture: Texture2D = visualizer._energy.texture
	visualizer.set_palette("green")
	assert(visualizer.palette == "green")
	assert(visualizer._energy.texture == texture)
	assert(is_equal_approx(visualizer.beat_percent, 30.0))
	visualizer.set_palette("unknown")
	assert(visualizer.palette == "gold")
	for percent: float in [0.0, 100.0]:
		visualizer.set_beat_percent(percent)
		assert(is_equal_approx(float(visualizer.sample_envelope(percent / 100.0, visualizer.visualizer_counts - 1)["energy"]), 1.0))
		for i: int in range(101):
			var state: Dictionary = visualizer.sample_envelope(float(i) / 100.0)
			assert(is_finite(float(state["charge"])))
			assert(is_finite(float(state["release"])))
	visualizer.free()

func test_actual_player_phase_is_only_motion_clock() -> void:
	var visualizer: MetronomeVisualizer = _make_visualizer()
	var player: Player = Player.new()
	player.sword_style = Player.SwordStyle.METRONOME_WINDUP
	player.sword_phase = PI * 0.5 + PI * 0.3
	visualizer.configure(player, 30.0)
	visualizer._process(0.016)
	assert(is_equal_approx(visualizer._last_progress, 0.3))
	var energy: float = float(visualizer._energy_material.get_shader_parameter("energy"))
	visualizer._process(100.0)
	assert(is_equal_approx(float(visualizer._energy_material.get_shader_parameter("energy")), energy))
	player.sword_phase = PI * 0.5 + PI * 0.7
	visualizer._process(0.0)
	assert(is_equal_approx(visualizer._last_progress, 0.7))
	player.sword_style = Player.SwordStyle.METRONOME_BIND
	visualizer._process(0.0)
	assert(visualizer.visible, "Form III must retain the same phase-driven metronome visualizer as Forms I–II.")
	visualizer.set_display_enabled(false)
	visualizer._process(0.016)
	assert(not visualizer.visible)
	player.free()
	visualizer._process(0.016)
	assert(not visualizer.visible)
	visualizer.free()
func test_one_peak_per_group_and_slower_full_envelope() -> void:
	var visualizer: MetronomeVisualizer = _make_visualizer()
	for counts: int in range(1, 5):
		visualizer.set_visualizer_counts(counts)
		visualizer.set_beat_percent(50.0)
		var peaks: int = 0
		for stroke: int in range(counts):
			if is_equal_approx(float(visualizer.sample_envelope(0.5, stroke)["energy"]), 1.0):
				peaks += 1
		assert(peaks == 1)
		var quarter_release: float = float(counts - 1) + 0.5 + float(counts) * 0.25
		assert(is_equal_approx(float(visualizer.sample_envelope(fmod(quarter_release, 1.0), floori(quarter_release))["energy"]), 0.5))
	visualizer.set_visualizer_counts(0)
	assert(visualizer.visualizer_counts == 1)
	visualizer.set_visualizer_counts(9)
	assert(visualizer.visualizer_counts == 4)
	visualizer.free()

func test_authoritative_count_wrap_and_reset() -> void:
	var visualizer: MetronomeVisualizer = _make_visualizer()
	var player: Player = Player.new()
	player.sword_style = Player.SwordStyle.METRONOME
	visualizer.configure(player, 50.0, "gold", 4)
	# TAU is in the middle of a stroke, not a count increment.
	player.swing_count = 3
	player.sword_phase = TAU - 0.00001
	visualizer._process(0.0)
	var left: float = float(visualizer._energy_material.get_shader_parameter("energy"))
	player.sword_phase = 0.00001
	visualizer._process(0.0)
	assert(absf(left - float(visualizer._energy_material.get_shader_parameter("energy"))) < 0.0001)
	# Reversal wraps progress and increments the authoritative count together.
	player.sword_phase = PI * 0.5 - 0.00001
	visualizer._process(0.0)
	left = float(visualizer._energy_material.get_shader_parameter("energy"))
	player.swing_count = 4
	player.sword_phase = PI * 0.5 + 0.00001
	visualizer._process(0.0)
	assert(absf(left - float(visualizer._energy_material.get_shader_parameter("energy"))) < 0.0001)
	player.swing_count = 0
	player.sword_phase = 0.0
	visualizer._process(0.0)
	assert(is_equal_approx(float(visualizer._energy_material.get_shader_parameter("energy")), float(visualizer.sample_envelope(0.5, 0)["energy"])))
	player.free()
	visualizer.free()

func test_palette_uniforms_before_ready_and_without_progress_reset() -> void:
	for palette_name: String in ["gold", "blue", "green"]:
		var visualizer: MetronomeVisualizer = MetronomeVisualizer.new()
		visualizer.set_palette(palette_name)
		add_child(visualizer)
		visualizer.set_process(false)
		for material_instance: ShaderMaterial in [visualizer._core_material, visualizer._energy_material]:
			assert(material_instance.get_shader_parameter("selected_color") == MetronomeVisualizer.PALETTE_COLORS[palette_name])
		visualizer._update_visual(0.37)
		var state: Dictionary = visualizer.sample_envelope(0.37)
		for next_palette: String in ["blue", "green", "gold", "invalid"]:
			visualizer.set_palette(next_palette)
			assert(visualizer._last_progress == 0.37)
			assert(visualizer.sample_envelope(0.37) == state)
			assert(bool(visualizer._energy_material.get_shader_parameter("preserve_gold")) == (visualizer.palette == "gold"))
			for material_instance: ShaderMaterial in [visualizer._core_material, visualizer._energy_material]:
				assert(material_instance.get_shader_parameter("selected_color") == MetronomeVisualizer.PALETTE_COLORS[visualizer.palette])
				assert(is_equal_approx(float(material_instance.get_shader_parameter("charge")), float(state["charge"])))
				assert(is_equal_approx(float(material_instance.get_shader_parameter("energy")), float(state["energy"])))
				assert(is_equal_approx(float(material_instance.get_shader_parameter("windup")), float(state["windup"])))
				assert(is_equal_approx(float(material_instance.get_shader_parameter("release_progress")), float(state["release"])))
				assert(bool(material_instance.get_shader_parameter("before_beat")) == bool(state["before"]))
		visualizer.free()

func test_palette_white_endpoints_and_saturated_peak_contract() -> void:
	# Non-rendering contract test: bind shader interpolation to the sampled envelope.
	var core_code: String = MetronomeVisualizer.CORE_SHADER.code
	var energy_code: String = MetronomeVisualizer.EFFECT_SHADER.code
	assert(core_code.contains("render_mode blend_mix, unshaded;"))
	assert(core_code.contains("phase_color = mix(vec3(1.0), selected_color.rgb, charge)"))
	assert(energy_code.contains("mix(vec3(1.0), selected_color.rgb, charge)"))
	assert(energy_code.contains("preserve_gold ? art.rgb : recolored"))
	assert(energy_code.contains("mix(vec3(intensity), charged_art, charge)"))
	assert(energy_code.contains("pulse_color * sparks"))
	assert(energy_code.contains("pulse_color * wave"))
	assert(core_code.contains("TIME * 1.65"))
	assert(core_code.contains("inner_compression"))
	assert(core_code.contains("pow(charge, 10.0)"))
	assert(energy_code.contains("mix(0.62 + seed * 0.28, 0.0, travel)"))
	assert(energy_code.contains("release_progress * release_progress"))
	assert(energy_code.contains("pulse_color * inner_whoosh"))
	assert(energy_code.contains("there is intentionally no central hole"))
	assert(not energy_code.contains("rgb *= smoothstep(0.065, 0.095, r)"))
	var visualizer: MetronomeVisualizer = _make_visualizer()
	visualizer.set_visualizer_counts(1)
	for palette_name: String in ["gold", "blue", "green"]:
		visualizer.set_palette(palette_name)
		var selected: Color = visualizer._core_material.get_shader_parameter("selected_color")
		for progress: float in [0.0, 0.5, 1.0]:
			visualizer._update_visual(progress)
			var charge: float = float(visualizer._core_material.get_shader_parameter("charge"))
			var sampled_color: Color = Color.WHITE.lerp(selected, charge)
			if progress == 0.5:
				assert(sampled_color.is_equal_approx(selected))
				assert(maxf(selected.r, maxf(selected.g, selected.b)) == 1.0)
				assert(minf(selected.r, minf(selected.g, selected.b)) <= 0.12)
			else:
				assert(sampled_color.is_equal_approx(Color.WHITE))
		var windup_charge: float = float(visualizer.sample_envelope(0.25)["charge"])
		var recovery_charge: float = float(visualizer.sample_envelope(0.75)["charge"])
		assert(is_equal_approx(windup_charge, 0.5))
		assert(is_equal_approx(recovery_charge, windup_charge))
	visualizer.free()
