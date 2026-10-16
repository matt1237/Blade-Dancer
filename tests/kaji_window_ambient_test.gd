class_name KajiWindowAmbientTest extends Node

func test_schedule_variants_and_frames() -> void:
	var backdrop: KajiStoreBackdrop = KajiStoreBackdrop.new()
	get_tree().root.add_child(backdrop)
	backdrop.ambient_rng.seed = 731
	var variants: Dictionary = {}
	var windows: Dictionary = {}
	for i: int in range(80):
		backdrop._begin_bird()
		variants[backdrop.bird_variant] = true
		windows[backdrop.bird_window] = true
		assert(backdrop.bird_duration >= 2.2 and backdrop.bird_duration <= 3.8)
		backdrop._finish_bird()
		assert(backdrop.bird_wait >= 10.0 and backdrop.bird_wait <= 30.0)
	assert(variants.size() == 3 and windows.size() == 2)
	for v: int in range(3):
		for f: int in range(6):
			var frame: Image = backdrop.bird_frames[v][f].get_image()
			assert(frame.get_size() == Vector2i(128,128))
			for edge: int in range(128):
				assert(frame.get_pixel(edge,0).a < 0.01 and frame.get_pixel(edge,127).a < 0.01)
				assert(frame.get_pixel(0,edge).a < 0.01 and frame.get_pixel(127,edge).a < 0.01)
	backdrop.queue_free()

func test_clip_mask_protects_frames_foliage_pots_and_mapping() -> void:
	var matte: Image = KajiStoreBackdrop.WINDOW_MATTE.get_image()
	for p: Vector2i in [Vector2i(379,215),Vector2i(425,220),Vector2i(401,261),Vector2i(1305,265),Vector2i(1321,292),Vector2i(455,211),Vector2i(414,385),Vector2i(1370,398),Vector2i(550,400)]:
		assert(matte.get_pixelv(p).r < 0.01, "Protected paint at %s" % p)
	assert(matte.get_pixel(361,190).r > 0.5)
	assert(matte.get_pixel(1320,245).r > 0.5)
	for viewport_size: Vector2 in [Vector2(1280,720),Vector2(1024,768),Vector2(2560,1080),Vector2(720,1280)]:
		var rect: Rect2 = KajiStoreBackdrop.image_rect(viewport_size)
		var bird: Vector2 = Vector2(402,215)
		var screen: Vector2 = rect.position+bird*rect.size/KajiStoreBackdrop.SOURCE_SIZE
		assert(((screen-rect.position)/rect.size*KajiStoreBackdrop.SOURCE_SIZE).is_equal_approx(bird))

func test_sunbeams_cloud_gate_and_dust_stay_in_floor_light() -> void:
	var shader_text: String = FileAccess.get_file_as_string("res://scripts/ui/kaji_store.gdshader")
	assert(shader_text.contains("ray_pulse"))
	assert(shader_text.contains("float clear_sky"))
	assert(shader_text.contains("floor_bounds*ray_pulse*clear_sky"))
	assert(shader_text.contains("float window_beams"), "Rays should visibly enter through left glass")
	assert(shader_text.contains("float floor_bounds"), "Floor rays need a local safe-light bound")
	assert(shader_text.contains("0.29*strength"), "Cloud shade should be visibly stronger on the painted floor pool")
	assert(shader_text.contains("mod(ambient_time,16.0)"), "Sunbeam cycle should be short enough to notice")
	assert(shader_text.contains("float floor_haze"), "Sunbeams need a visible soft spread over the floor")
	assert(shader_text.contains("window_center_a"), "Sunbeams should fan down from the left window")
	var matte: Image = KajiStoreBackdrop.WINDOW_MATTE.get_image()
	for p: Vector2i in [Vector2i(400,740),Vector2i(500,760),Vector2i(600,760)]:
		assert(matte.get_pixelv(p).g > 0.25, "Ray/dust point must be within painted light %s" % p)
	for p: Vector2i in [Vector2i(550,400),Vector2i(700,700),Vector2i(1000,760)]:
		assert(matte.get_pixelv(p).g < 0.01, "No ray/dust outside the pool %s" % p)

func test_navigation_resets_birds_and_paused_realtime() -> void:
	var preview: GeneralStorePreview = preload("res://tests/general_store_preview.tscn").instantiate() as GeneralStorePreview
	get_tree().root.add_child(preview)
	await get_tree().process_frame
	var backdrop: KajiStoreBackdrop = preview.hub.shop_backdrop
	backdrop._begin_bird()
	assert(backdrop.bird_active)
	get_tree().paused = true
	var before: float = backdrop.ambient_seconds
	await get_tree().process_frame
	await get_tree().process_frame
	assert(backdrop.ambient_seconds > before)
	preview.menu.open_town()
	assert(not backdrop.bird_active and not backdrop.is_processing())
	assert(backdrop.ambient_seconds == 0.0)
	preview.menu.open_general()
	assert(not backdrop.bird_active and backdrop.is_processing())
	get_tree().paused = false
	preview.queue_free()
