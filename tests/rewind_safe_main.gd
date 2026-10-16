extends "res://tests/chasm_walk_safe_main.gd"
## ▽ Rewind visual bench. Real Main/Player, existing pre-tree persistence guards (writes are
## counted and refused), live GP2 combat dictionaries read-only. One real goblin is spawned.
## Keys: T = draw a ▽ by warping the real mouse cursor (drives the live gesture recognizer);
##       R = rig-only fallback calling the same Player.activate_rewind() entry.
var rewind_enemy: Node2D = null
var enemy_pos_at_start: Vector2 = Vector2.ZERO
var draw_points: PackedVector2Array = PackedVector2Array()
var draw_index: int = -1

func _ready() -> void:
	super._ready()
	var library: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_global_presets.json"))
	if library is Dictionary:
		var slot: Dictionary = library.get("slots", {}).get("2", {})
		player.combat_contact_preset = int(slot.get("selected_combat_preset", 2))
		for key: String in ["combat_hand_settings", "combat_contact_settings", "combat_weapon_hand_settings", "blade_profile_settings"]:
			if slot.get(key) is Dictionary:
				player.set(key, (slot[key] as Dictionary).duplicate(true))
	print("[REWIND RIG] GP2 rewind_gesture_enabled=", player.get_combat_contact_setting("rewind_gesture_enabled"), " (key absent in GP2 → built-in default)")
	player.set_combat_contact_setting("rewind_gesture_enabled", 1.0) # in-memory only; never saved
	player.rewind_finished.connect(_on_rewind_finished)
	player.flow = 60.0
	player.flow_changed.emit(player.flow, 100.0)
	rewind_enemy = (WaveSpawner.GOBLIN_SCENE as PackedScene).instantiate() as Node2D
	rewind_enemy.global_position = player.global_position + Vector2(170, -40)
	add_child(rewind_enemy)
	print("[REWIND RIG] goblin spawned at ", rewind_enemy.global_position, " writes=", write_attempts)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_note_start()
			print("[REWIND RIG] R fallback activate=", player.activate_rewind())
		elif event.keycode == KEY_T:
			var origin: Vector2 = get_viewport().get_visible_rect().size * 0.5 + Vector2(-140, -120)
			draw_points = Rewind_Triangle.build(origin)
			draw_index = 0

func _note_start() -> void:
	player.flow = maxf(player.flow, 60.0)
	if is_instance_valid(rewind_enemy): enemy_pos_at_start = rewind_enemy.global_position

func _physics_process(_delta: float) -> void:
	if draw_index >= 0:
		if draw_index == 0: _note_start()
		if draw_index < draw_points.size():
			Input.warp_mouse(draw_points[draw_index])
			draw_index += 1
		else:
			draw_index = -1
			print("[REWIND RIG] ▽ drawn via cursor; rewind_active=", player.rewind_active)
	if player.rewind_active and is_instance_valid(rewind_enemy) and Engine.get_physics_frames() % 6 == 0:
		print("[REWIND RIG] mid-rewind player=", player.global_position, " enemy=", rewind_enemy.global_position, " enemy_moved=", rewind_enemy.global_position.distance_to(enemy_pos_at_start), " paused=", get_tree().paused, " pause_menu=", is_instance_valid(pause_menu) and pause_menu.visible)

func _on_rewind_finished(at: Vector2) -> void:
	print("[REWIND RIG] finished at ", at, " paused=", get_tree().paused, " flow=", player.flow, " writes=", write_attempts)

class Rewind_Triangle:
	static func build(origin: Vector2) -> PackedVector2Array:
		var a: Vector2 = origin
		var b: Vector2 = origin + Vector2(280, 0)
		var c: Vector2 = origin + Vector2(140, 220)
		var points: PackedVector2Array = PackedVector2Array()
		for edge: Array in [[a, b], [b, c], [c, a + Vector2(6, 4)]]:
			for step: int in range(1, 9):
				points.append((edge[0] as Vector2).lerp(edge[1] as Vector2, float(step) / 8.0))
		return points
