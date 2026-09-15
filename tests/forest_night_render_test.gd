extends SceneTree
## Save-free GPU smoke test. Run without --headless; no Main lifecycle.
const Lighting: GDScript = preload("res://scripts/forest_night_lighting.gd")

class WorldFixture extends Node2D:
	var visual_style: String = "hd"
	var resonance_rush_instance: Node = null
	func get_presentation_rect() -> Rect2:
		return Rect2(-2000.0, -2000.0, 6000.0, 6000.0)
	func get_gameplay_arena_rect() -> Rect2:
		return Rect2(0.0, 0.0, 1280.0, 720.0)
	func _draw() -> void:
		draw_rect(get_presentation_rect(), Color.WHITE)

class ActorFixture extends Player:
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass
	func _draw() -> void:
		pass

class HudPatch extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, 40.0, 40.0), Color.WHITE)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: WorldFixture = WorldFixture.new()
	root.add_child(world)
	current_scene = world
	var actor: Player = load("res://scenes/player.tscn").instantiate() as Player
	actor.set_script(ActorFixture)
	world.add_child(actor)
	actor.position = Vector2(300.0, 250.0)
	actor.previous_blade_start = Vector2(390.0, 250.0)
	actor.previous_blade_end = Vector2(450.0, 250.0)
	var disc: Chakram = Chakram.new()
	disc.grounded = true
	disc.position = Vector2(550.0, 100.0)
	world.add_child(disc)
	actor.active_chakrams.append(disc)
	actor.grapple_controller.active = true
	actor.grapple_controller.anchor_position = Vector2(150.0, 400.0)
	var ambient: ForestAmbientFX = ForestAmbientFX.new()
	world.add_child(ambient)
	var overlay: ForestNightLighting = Lighting.new()
	overlay.setup(world, actor, ambient)
	world.add_child(overlay)
	overlay.apply_visual_settings({"night_strength": 1.0})
	var hud: CanvasLayer = CanvasLayer.new()
	hud.layer = 2
	world.add_child(hud)
	hud.add_child(HudPatch.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(overlay.visible)
	assert(overlay.light_count == ambient.fireflies.size() + 4)
	assert(Vector2(overlay.lights[2].x, overlay.lights[2].y) == disc.global_position)
	assert(Vector2(overlay.lights[3].x, overlay.lights[3].y) == actor.grapple_controller.anchor_position)
	disc.position += Vector2(10.0, 15.0)
	actor.grapple_controller.anchor_position += Vector2(25.0, 5.0)
	overlay.collect_lights()
	assert(Vector2(overlay.lights[2].x, overlay.lights[2].y) == disc.global_position)
	assert(Vector2(overlay.lights[3].x, overlay.lights[3].y) == actor.grapple_controller.anchor_position)
	assert(Vector2(overlay.lights[1].x, overlay.lights[1].y).is_equal_approx(Vector2(429.0, 250.0)))
	var image: Image = root.get_texture().get_image()
	# Convert logical viewport positions to screenshot pixels (stretch-safe).
	var extent: Vector2 = root.get_visible_rect().size
	var scale_factor: Vector2 = Vector2(image.get_width(), image.get_height()) / extent
	var center: Vector2i = Vector2i(actor.position * scale_factor)
	var distant: Vector2i = Vector2i(Vector2(700.0, 350.0) * scale_factor)
	assert(image.get_pixelv(center).r > 0.85, "Player reveal must expose the underlying world, not merely add a halo")
	assert(image.get_pixelv(distant).r < 0.4, "Unlit world must darken")
	assert(image.get_pixelv(Vector2i(Vector2(20.0, 20.0) * scale_factor)).r > 0.85, "HUD must remain untouched")
	world.visual_style = "classic"
	await process_frame
	await process_frame
	assert(not overlay.visible)
	world.visual_style = "hd"
	world.resonance_rush_instance = Node.new()
	await process_frame
	await process_frame
	assert(not overlay.visible)
	world.resonance_rush_instance.free()
	world.resonance_rush_instance = null
	world.visible = false
	await process_frame
	await process_frame
	assert(not overlay.is_visible_in_tree())
	print("Forest night GPU: reveal, darkness, HUD, sword alignment, real fireflies, Classic/Rush/hidden guards PASS")
	quit()
