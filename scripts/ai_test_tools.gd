extends CanvasLayer

## Console-based AI testing tools. Toggle with backtick (~ / `).
## Add commands over time as needed — just extend _execute().

const COMMAND_HISTORY_MAX: int = 20

var _console_open: bool = false
var _line_edit: LineEdit
var _output_label: RichTextLabel
var _history: Array[String] = []
var _god_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128  # topmost

	# Output label — shows recent command results.
	_output_label = RichTextLabel.new()
	_output_label.anchor_left = 0.05
	_output_label.anchor_right = 0.95
	_output_label.anchor_top = 0.0
	_output_label.offset_top = 8.0
	_output_label.offset_bottom = 220.0
	_output_label.bbcode_enabled = true
	_output_label.fit_content = true
	_output_label.scroll_following = true
	_output_label.add_theme_font_size_override("normal_font_size", 14)
	_output_label.add_theme_color_override("default_color", Color("b0ffb0"))
	_output_label.visible = false
	add_child(_output_label)

	# Command input line.
	_line_edit = LineEdit.new()
	_line_edit.anchor_left = 0.05
	_line_edit.anchor_right = 0.95
	_line_edit.anchor_top = 1.0
	_line_edit.anchor_bottom = 1.0
	_line_edit.offset_top = -36.0
	_line_edit.offset_bottom = -8.0
	_line_edit.placeholder_text = "Type command... (help for list)"
	_line_edit.add_theme_font_size_override("font_size", 16)
	_line_edit.visible = false
	_line_edit.text_submitted.connect(_on_command_entered)
	add_child(_line_edit)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:
		_console_open = not _console_open
		_line_edit.visible = _console_open
		_output_label.visible = _console_open
		if _console_open:
			_line_edit.grab_focus()
			_line_edit.clear()
		get_viewport().set_input_as_handled()

func _log(text: String, color: String = "#b0ffb0") -> void:
	_history.append("[color=%s]> %s[/color]" % [color, text])
	if _history.size() > COMMAND_HISTORY_MAX: _history.pop_front()
	_output_label.text = "\n".join(_history)

func _on_command_entered(command: String) -> void:
	_line_edit.clear()
	if command.is_empty(): return
	_execute(command.strip_edges().to_lower())

func _execute(raw: String) -> void:
	var parts: PackedStringArray = raw.split(" ", false)
	if parts.is_empty(): return
	var cmd: String = parts[0]
	var main_scene: Node = get_tree().current_scene

	match cmd:
		"help":
			_log("Commands: wave N | spawn TYPE [count] | killall | god | heal | flow N | help")
			_log("  spawn names: turkey goblin bug wolf ogre zungar")
		"wave":
			if parts.size() < 2: _log("Usage: wave <number>", "#ff8888"); return
			var wave_num: int = parts[1].to_int()
			if wave_num < 1: _log("Wave must be >= 1", "#ff8888"); return
			_jump_to_wave(wave_num)
		"spawn":
			if parts.size() < 2: _log("Usage: spawn <type> [count]", "#ff8888"); return
			var count: int = parts[2].to_int() if parts.size() >= 3 else 1
			count = clampi(count, 1, 20)
			_spawn_enemies(parts[1], count)
		"killall":
			var killed: int = 0
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy): enemy.queue_free(); killed += 1
			_log("Killed %d enemies." % killed)
		"god":
			_god_mode = not _god_mode
			if main_scene.has_method("_on_god_mode_toggled"):
				main_scene._on_god_mode_toggled(_god_mode)
			else:
				var players: Array[Node] = get_tree().get_nodes_in_group("player")
				if not players.is_empty():
					var player: Player = players[0] as Player
					player.set_meta("ai_god_mode", _god_mode)
			_log("God mode: %s" % ("ON" if _god_mode else "OFF"))
		"heal":
			var players: Array[Node] = get_tree().get_nodes_in_group("player")
			if players.is_empty(): _log("No player found.", "#ff8888"); return
			var player: Player = players[0] as Player
			player.health = player.max_health
			player.health_bar.value = player.max_health
			_log("Player healed to full.")
		"flow":
			if parts.size() < 2: _log("Usage: flow <0-100>", "#ff8888"); return
			var flow_val: float = clampf(parts[1].to_float(), 0.0, 100.0)
			var players: Array[Node] = get_tree().get_nodes_in_group("player")
			if players.is_empty(): _log("No player found.", "#ff8888"); return
			var player: Player = players[0] as Player
			player.flow = flow_val
			_log("Flow set to %.0f" % flow_val)
		_:
			_log("Unknown command: '%s'. Type 'help' for list." % cmd, "#ff8888")

func _jump_to_wave(wave_num: int) -> void:
	var main_scene: Node = get_tree().current_scene
	if main_scene == null: _log("No scene running.", "#ff8888"); return
	var spawner: Node = main_scene.get_node_or_null("WaveSpawner")
	if spawner == null: _log("WaveSpawner not found.", "#ff8888"); return

	# Clear existing enemies and warnings.
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy): enemy.queue_free()
	for warning: Node in get_tree().get_nodes_in_group("spawn_warnings"):
		if is_instance_valid(warning): warning.queue_free()

	# Reset spawner to a clean state right before the target wave.
	spawner.boss_active = false
	spawner.wave_active = false
	spawner.awaiting_next_wave = false
	spawner.current_wave = wave_num - 1
	spawner.enemies_to_spawn = 0
	spawner.enemies_alive = 0
	spawner.wave_timer = 0.0

	# Tear down any leftover boss arena.
	if main_scene.has_method("_clear_boss_arena"): main_scene._clear_boss_arena()

	# Trigger the wave — _start_wave detects boss waves automatically.
	spawner._start_wave()
	_log("Jumped to wave %d." % wave_num)

func _spawn_enemies(type_name: String, count: int) -> void:
	var main_scene: Node = get_tree().current_scene
	var spawner: Node = main_scene.get_node_or_null("WaveSpawner") if main_scene != null else null
	if spawner == null:
		_log("Spawner not available.", "#ff8888")
		return

	var selected_scene: PackedScene = spawner.scene_for_name(StringName(type_name))
	if type_name == "zungar":
		if main_scene.has_method("_on_boss_wave_started"):
			main_scene._on_boss_wave_started(ZungarConfig.BOSS_WAVE)
			_log("Spawned Zungar boss.")
		else:
			_log("Cannot spawn Zungar — main scene missing boss handler.", "#ff8888")
		return
	if selected_scene == null:
		_log("Unknown enemy name: '%s'. Use: turkey goblin bug wolf ogre zungar" % type_name, "#ff8888")
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if main_scene != null and main_scene is Node2D:
		mouse_pos = (main_scene as Node2D).get_global_mouse_position()

	for index: int in range(count):
		var enemy: Node2D = spawner.instantiate_enemy(selected_scene) as Node2D
		if enemy == null: continue
		enemy.global_position = mouse_pos + Vector2(randf_range(-40.0, 40.0), randf_range(-40.0, 40.0))
		enemy.tree_exited.connect(spawner._enemy_died)
		enemy.connect("defeated", spawner._on_enemy_defeated)
		main_scene.add_child(enemy)
	_log("Spawned %d x %s." % [count, type_name])
