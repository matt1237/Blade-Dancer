extends "res://tests/sword_drive_safe_main.gd"
## Real Main, read-only GP2, in-memory Armory equip of Iron Greatsword (Test).
## Writes disabled by the base bench; G is the ONLY explicit grant path.
## Draws the traced variable-width hit outline over the rendered sprite.
var overlay: Node2D

func _ready() -> void:
	super._ready()
	home_progression.add_gear_item(ArmoryConfig.greatsword_test_item())
	assert(home_progression.equip_gear(ArmoryConfig.GREATSWORD_ID))
	_apply_equipped_gear_to_player()
	assert(player.greatsword_equipped)
	overlay = Node2D.new()
	overlay.z_index = 100
	overlay.draw.connect(_draw_trace)
	add_child(overlay)
	print("[GREATSWORD LIVE] in-memory Armory equip; GP2 read-only; writes disabled")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_G:
		print("[GREATSWORD GRANT RESULT] ", grant_approved_greatsword_inventory(), " writes=", write_attempts)
		return
	super._unhandled_input(event)

func _process(delta: float) -> void:
	super._process(delta)
	if overlay != null: overlay.queue_redraw()

func _draw_trace() -> void:
	var samples: PackedVector2Array = player.current_blade_samples
	var radii: PackedFloat32Array = player._blade_sample_radii()
	if samples.size() < 2 or radii.size() != samples.size(): return
	var left: PackedVector2Array = PackedVector2Array()
	var right: PackedVector2Array = PackedVector2Array()
	for i: int in range(samples.size()):
		var a: Vector2 = samples[maxi(i - 1, 0)]
		var b: Vector2 = samples[mini(i + 1, samples.size() - 1)]
		var n: Vector2 = (b - a).normalized().rotated(PI * 0.5)
		left.append(samples[i] + n * radii[i])
		right.append(samples[i] - n * radii[i])
	overlay.draw_polyline(samples, Color(1, 0.2, 0.2), 1.0)
	overlay.draw_polyline(left, Color(1, 1, 0), 1.0)
	overlay.draw_polyline(right, Color(1, 1, 0), 1.0)
