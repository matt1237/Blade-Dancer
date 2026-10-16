extends Node2D
## Real Chasm scene/population, no Main/Player initialization or user:// writes.
@onready var stage: ChasmStage = $ChasmStage

func _enter_tree() -> void:
	# Preview-only: do not change the editor's persisted debug settings.
	get_tree().debug_collisions_hint = false

func _ready() -> void:
	# Overlay above props; stage keeps production depth independently.
	z_index = 100
	stage.z_as_relative = false
	var camera: Camera2D = Camera2D.new()
	camera.name = "PreviewCamera"
	add_child(camera)
	# Read-only observation of the live active preset, never packaged defaults.
	var presets: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://blade_dancer_global_presets.json"))
	var zoom_value: float = 1.0
	if presets is Dictionary:
		var slot: Dictionary = presets.get("slots", {}).get(str(int(presets.get("active_slot", 2))), {})
		zoom_value = float(slot.get("training_camera_zoom", 1.0)) if slot.get("visual_style", "hd") == "hd" else 1.0
	camera.zoom = Vector2.ONE * zoom_value
	camera.position = stage.arena_rect.get_center()
	var overlay: CanvasLayer = CanvasLayer.new()
	add_child(overlay)
	var caption: Label = Label.new()
	caption.position = Vector2(36, 28)
	caption.text = "SAFE PREVIEW  |  R: regenerate  |  E: center/corners  |  C: collision (cyan), harvest (yellow)"
	overlay.add_child(caption)
	stage.population.population_seed = 42
	stage.regenerate()
	print("[CHASM SAFE PREVIEW] seed=42 objects=", stage.population.get_child_count(), " playable=", stage.get_playable_rect(), " no Main/Player/save initialization")

var collision_outlines: bool = false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_R:
		stage.population.population_seed += 1
		stage.regenerate()
		print("[CHASM SAFE PREVIEW] seed=", stage.population.population_seed, " objects=", stage.population.get_child_count())
	elif event.keycode == KEY_C:
		collision_outlines = not collision_outlines
		print("[CHASM SAFE PREVIEW] collision outlines=", collision_outlines)
	elif event.keycode == KEY_E:
		preview_edge = (preview_edge + 1) % 5
		var targets: Array[Vector2] = [Vector2(640, 360), Vector2(26, 26), Vector2(1254, 26), Vector2(1254, 694), Vector2(26, 694)]
		var camera: Camera2D = $PreviewCamera
		camera.position = Main.clamp_presentation_center(targets[preview_edge], Main.presentation_rect_for_arena(stage.arena_rect), get_viewport_rect().size, camera.zoom)
		print("[CHASM SAFE PREVIEW] edge=", preview_edge, " camera=", camera.position, " zoom=", camera.zoom)
	queue_redraw()

var preview_edge: int = 0

func _draw() -> void:
	if not collision_outlines or stage == null: return
	for child: Node in stage.population.get_children():
		var object: ChasmArenaObject = child as ChasmArenaObject
		if object.body == null:
			# Yellow = nonblocking harvest/placement extent, not a physics body.
			draw_rect(object.world_footprint(), Color.YELLOW, false, 1.0)
			continue
		for node: Node in object.body.get_children():
			var collision: CollisionShape2D = node as CollisionShape2D
			if collision == null or collision.disabled: continue
			var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
			if capsule == null: continue
			var half_segment: float = capsule.height * 0.5 - capsule.radius
			var outline: PackedVector2Array = []
			# Read the actual physical shape/transform, never parallel dimensions.
			for index: int in range(25):
				var angle: float = PI + PI * float(index) / 24.0
				outline.append(to_local(collision.to_global(Vector2(cos(angle), sin(angle)) * capsule.radius + Vector2(0, -half_segment))))
			for index: int in range(25):
				var angle: float = PI * float(index) / 24.0
				outline.append(to_local(collision.to_global(Vector2(cos(angle), sin(angle)) * capsule.radius + Vector2(0, half_segment))))
			outline.append(outline[0])
			draw_polyline(outline, Color.CYAN, 1.5, true)
