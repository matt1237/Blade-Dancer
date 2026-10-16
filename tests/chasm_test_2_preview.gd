extends "res://tests/chasm_walk_safe_main.gd"
## Reuse pretree persistence guards and canonical Player/Main; open real Adventure.
var corners: Array[Vector2] = [Vector2(640, 360), Vector2(42, 42), Vector2(1238, 42), Vector2(1238, 678), Vector2(42, 678), Vector2(42,360), Vector2(1238,360), Vector2(640,42), Vector2(640,678)]
var corner_index: int = 0
var boundary_overlay: BoundaryOverlay

class BoundaryOverlay extends Node2D:
	var stage: ChasmStage
	func _draw() -> void:
		if stage == null: return
		for collision: CollisionShape2D in stage.get_node("ChasmBounds").get_children():
			if collision.disabled: continue
			var bounds: Rect2 = collision.shape.get_rect()
			var outline: PackedVector2Array = []
			for point: Vector2 in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y), bounds.position]:
				outline.append(to_local(collision.to_global(point)))
			draw_polyline(outline, Color.CYAN, 2.0, true)

func _ready() -> void:
	super._ready()
	_on_pause_return_home()
	_return_to_adventure_from_home()
	boundary_overlay = BoundaryOverlay.new()
	boundary_overlay.stage = chasm_stage
	boundary_overlay.z_index = 100
	boundary_overlay.visible = false
	add_child(boundary_overlay)
	print("[SAFE TEST 2] Click Chasm Test 2; WASD; E cycles center/corners; C collision outlines; Esc/Home. No persistence.")

func _input(event: InputEvent) -> void:
	super._input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			boundary_overlay.visible = not boundary_overlay.visible
			boundary_overlay.queue_redraw()
		elif event.keycode == KEY_E and chasm_test_active:
			corner_index = (corner_index + 1) % corners.size()
			player.position = corners[corner_index]
			_update_presentation_camera_follow(0.0, true)
