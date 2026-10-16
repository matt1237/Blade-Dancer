extends "res://tests/chasm_walk_safe_main.gd"
## Actual Main HUD, with the existing pretree persistence guards.
## Left = half, Down = empty, Right = full; no combat/preset/save writes.
func _ready() -> void:
	super._ready()
	_clear_chasm_test()
	player.set_physics_process(false)
	player.flow_changed.connect(_on_flow_changed)
	player.health_changed.connect(_on_health_changed)
	player.rewind_charge_changed.connect(_on_rewind_charge_changed)
	player.slow_charge_changed.connect(_on_slow_charge_changed)
	_on_health_changed(player.health, player.max_health)
	_on_style_changed("")
	spawner.wave_active = true
	spawner.current_wave = 3
	spawner.wave_duration = 30.0
	spawner.wave_elapsed = 13.0
	spawner.set_process(false)
	_set_probe_flow(100.0)
	_on_enemy_defeated(617283)
	metronome_visualizer_mode = "top_bar"
	player.sword_style = Player.SwordStyle.METRONOME
	metronome_top_bar.configure(player, "top_bar", 50.0, 1.0, 2)
	_set_world_visible(true)
	print("[HUD] Full/half/empty: Right/Left/Down; canonical round timer and score; writes=", write_attempts)

func _set_probe_flow(value: float) -> void:
	player.flow = value
	player.flow_changed.emit(player.flow, 100.0)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_left"): _set_probe_flow(50.0)
	if Input.is_action_just_pressed("ui_down"): _set_probe_flow(0.0)
	if Input.is_action_just_pressed("ui_right"): _set_probe_flow(100.0)
	super._process(delta)
