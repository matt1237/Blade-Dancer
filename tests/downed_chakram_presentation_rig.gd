extends "res://tests/hud_flow_safe_main.gd"
## Later visual check ONLY, on the existing save-safe real Main/Player harness.
## Auto-spawns a nearby downed disc and two off-camera discs. No manual menu trip.
var recovery_discs: Array[Chakram] = []

func _ready() -> void:
	super._ready()
	_spawn_recovery_discs()
	print("[CHAKRAM PRESENTATION] G ground / F flying / C collect / R respawn. Esc uses canonical pause menu. No persistence.")

func _spawn_recovery_discs() -> void:
	for disc: Chakram in recovery_discs:
		if is_instance_valid(disc): disc.queue_free()
	recovery_discs.clear()
	presentation_camera.force_update_scroll()
	var inverse: Transform2D = get_viewport().canvas_transform.affine_inverse()
	var view: Rect2 = get_viewport_rect()
	for screen_point: Vector2 in [view.get_center() + Vector2(100, 60), Vector2(-180, view.size.y * 0.5), Vector2(view.size.x + 180, -180)]:
		var disc: Chakram = preload("res://scenes/chakram.tscn").instantiate()
		add_child(disc)
		disc.set_physics_process(false)
		disc.owner_player = player
		disc.global_position = inverse * screen_point
		disc.grounded = true
		disc.queue_redraw()
		recovery_discs.append(disc)

func _process(delta: float) -> void:
	super._process(delta)
	for disc: Chakram in recovery_discs:
		if is_instance_valid(disc): disc.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R: _spawn_recovery_discs()
			KEY_C:
				for disc: Chakram in recovery_discs:
					if is_instance_valid(disc): disc.collect()
			KEY_F, KEY_G:
				for disc: Chakram in recovery_discs:
					if is_instance_valid(disc):
						disc.grounded = event.keycode == KEY_G
						disc.queue_redraw()
