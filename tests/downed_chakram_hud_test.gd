extends Node
const HUD = preload("res://scripts/ui/downed_chakram_hud.gd")
const DISC = preload("res://scenes/chakram.tscn")

class GateFixture extends Node2D:
	var run_over: bool = false

func test_canonical_hud_menu_pause_death_gate() -> void:
	var main: Node2D = GateFixture.new()
	add_child(main)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "CanvasLayer"
	main.add_child(layer)
	var health: Label = Label.new()
	health.name = "HealthLabel"
	layer.add_child(health)
	var overlays: Array[Control] = []
	for title: String in ["HomeMenu", "EndRunHub", "BonusPanel"]:
		var overlay: Control = Control.new()
		overlay.name = title
		overlay.visible = false
		layer.add_child(overlay)
		overlays.append(overlay)
	var hud: Control = HUD.new()
	layer.add_child(hud)
	hud.set_process(false)
	hud._process(0)
	assert(hud.visible)
	for overlay: Control in overlays:
		overlay.visible = true
		hud._process(0)
		assert(not hud.visible and hud.markers.is_empty())
		overlay.visible = false
	health.visible = false
	hud._process(0)
	assert(not hud.visible)
	health.visible = true
	main.run_over = true
	hud._process(0)
	assert(not hud.visible)
	main.run_over = false
	get_tree().paused = true
	hud._process(0)
	assert(not hud.visible)
	get_tree().paused = false
	hud._process(0)
	assert(hud.visible)
	main.free()

func test_grounded_authority_and_halo_asset() -> void:
	var disc: Chakram = DISC.instantiate()
	assert(not disc.is_downed_for_presentation())
	disc.grounded = true
	assert(disc.is_downed_for_presentation())
	var old_time: float = disc.time_left
	disc.on_grapple_attached() # Grounded disc refuses attach, unchanged authority.
	assert(not disc.grapple_attached and disc.time_left == old_time)
	disc.become_airborne_for_grapple()
	assert(not disc.is_downed_for_presentation())
	disc.on_grapple_attached()
	assert(disc.grapple_attached and not disc.is_downed_for_presentation())
	disc.on_grapple_detached()
	assert(not disc.is_downed_for_presentation())
	assert(Chakram.DOWNED_HALO.get_size() == Vector2(128, 128))
	var image: Image = Chakram.DOWNED_HALO.get_image()
	assert(image != null and image.get_pixel(64, 64).a < 0.05, "Halo center stays transparent")
	assert(Chakram.DOWNED_HALO_RECT.size == Vector2(48, 48))
	assert(is_equal_approx(Chakram.downed_halo_alpha(0), Chakram.downed_halo_alpha(1.0 / 1.1)))
	assert(Chakram.downed_halo_alpha(0.25 / 1.1) > Chakram.downed_halo_alpha(0.75 / 1.1) + 0.49)
	disc.free()

func test_edge_geometry_wide_narrow_corners() -> void:
	for dimensions: Vector2 in [Vector2(1280, 720), Vector2(1920, 720), Vector2(640, 360), Vector2(360, 640)]:
		var view: Rect2 = Rect2(Vector2.ZERO, dimensions)
		var safe: Rect2 = HUD.safe_marker_rect(view)
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN, Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
			var target: Vector2 = view.get_center() + direction * 10000
			var point: Vector2 = HUD.edge_position(target, view)
			assert(point.x >= safe.position.x and point.x <= safe.end.x + 0.001)
			assert(point.y >= safe.position.y and point.y <= safe.end.y + 0.001)
			assert(point.x >= 62 and point.y >= 108)
			assert(point.x >= 280 or point.y >= minf(270, safe.end.y), "Avoid the existing upper-left HUD")
			assert((target - point).normalized().dot(direction.normalized()) > 0.95)

func test_camera_projection_multiple_cleanup_and_gating() -> void:
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(640,360), Vector2i(360,640)]:
		var viewport: SubViewport = SubViewport.new()
		viewport.size = dimensions
		add_child(viewport)
		var world: Node2D = Node2D.new()
		viewport.add_child(world)
		var layer: CanvasLayer = CanvasLayer.new()
		world.add_child(layer)
		var hud: Control = HUD.new()
		layer.add_child(hud)
		hud.set_process(false) # Test refresh directly, never Main/Player._ready.
		var camera: Camera2D = Camera2D.new()
		world.add_child(camera)
		camera.position = Vector2(450, -220)
		camera.offset = Vector2(57, 39)
		camera.make_current()
		var first: Chakram = DISC.instantiate()
		var second: Chakram = DISC.instantiate()
		world.add_child(first)
		world.add_child(second)
		first.set_physics_process(false)
		second.set_physics_process(false)
		assert(first.chakram_texture_hd != null and first.chakram_texture_hd.get_size() == Vector2(128, 128))
		first.grounded = true
		second.grounded = true
		for zoom: Vector2 in [Vector2(0.7,0.7), Vector2(1.3,1.3), Vector2(2,2)]:
			camera.zoom = zoom
			camera.force_update_scroll()
			var view: Rect2 = hud.get_viewport_rect()
			var inverse: Transform2D = first.get_canvas_transform().affine_inverse()
			first.global_position = inverse * view.get_center()
			assert((first.get_global_transform_with_canvas() * Vector2.ZERO).distance_to(view.get_center()) < 0.001)
			hud.refresh_markers([first], true)
			assert(hud.markers.is_empty())
			# Part of the actual disc still visible: no premature border marker.
			first.global_position = inverse * Vector2(-5, view.size.y * 0.5)
			assert(not HUD.disc_is_offscreen(first, view))
			first.global_position = inverse * Vector2(-100, view.size.y * 0.5)
			second.global_position = first.global_position
			hud.refresh_markers([first, second], true)
			assert(hud.markers.size() == 2)
			assert(hud.markers[0]["position"].distance_to(hud.markers[1]["position"]) >= 42)
			for marker: Dictionary in hud.markers:
				var target: Vector2 = first.get_global_transform_with_canvas() * Vector2.ZERO
				assert(marker["direction"].is_equal_approx((target - marker["position"]).normalized()))
			first.become_airborne_for_grapple()
			hud.refresh_markers([first, second], true)
			assert(hud.markers.size() == 1)
			first.grounded = true
			hud.refresh_markers([first, second], false)
			assert(not hud.visible and hud.markers.is_empty())
		second.collect()
		hud.refresh_markers([first, second], true)
		assert(hud.markers.size() == 1, "Queued pickup cannot leave a marker")
		world.remove_child(first)
		hud.refresh_markers([first], true)
		assert(hud.markers.is_empty(), "Scene exit removes marker")
		first.free()
		hud.refresh_markers([], true)
		assert(hud.markers.is_empty(), "Reset clears marker snapshot")
		viewport.free()

func test_main_wiring_without_ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var hud: Control = main.get_node("CanvasLayer/DownedChakramHUD")
	assert(hud.get_script() == HUD)
	assert(hud.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(hud.process_mode == Node.PROCESS_MODE_ALWAYS)
	main.free() # Never entered tree; no Main bootstrap, load or save.
