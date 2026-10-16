class_name BlacksmithStoreTest extends Node

func test_preview_navigation_presentation_and_localized_ambient() -> void:
	var preview: BlacksmithStorePreview = preload("res://tests/blacksmith_store_preview.tscn").instantiate() as BlacksmithStorePreview
	get_tree().root.add_child(preview)
	await get_tree().process_frame
	var hub: EndRunHub = preview.hub
	var backdrop: BlacksmithStoreBackdrop = preview.blacksmith_backdrop
	assert(backdrop != null and backdrop.visible)
	assert(backdrop.painting.texture == BlacksmithStoreBackdrop.ROOM)
	assert(hub.town_menu.blacksmith_page.visible)
	assert(not hub.shop_backdrop.visible)
	assert(backdrop.ember_sprites.size() == BlacksmithStoreBackdrop.EMBER_COUNT)
	assert(backdrop.dust_sprites.size() == BlacksmithStoreBackdrop.DUST_COUNT)
	assert(backdrop.sign_hinge != null and backdrop.sign_sprite != null)
	assert(not backdrop.sign_backing.visible and not backdrop.sign_sprite.visible)
	backdrop.advance_ambient(1.0)
	assert(backdrop.clock > 0.9)
	assert(backdrop.ember_sprites[0].frame != 0 or backdrop.dust_sprites[0].frame != 0)
	assert(is_zero_approx(backdrop.sign_hinge.rotation))
	assert(not backdrop.sign_backing.visible and not backdrop.sign_sprite.visible)
	var menu: TownMenu = hub.town_menu
	assert(menu.jimbo_portrait.size == (menu.general_page.get_node("KajiPortrait") as TextureRect).size)
	assert(menu.blacksmith_page.theme == menu.general_page.theme)
	backdrop.set_ambient_enabled(false)
	assert(not backdrop.sign_backing.visible and not backdrop.sign_sprite.visible)
	for sprite: Sprite2D in backdrop.ember_sprites:
		assert(not sprite.visible)
	for sprite: Sprite2D in backdrop.dust_sprites:
		assert(not sprite.visible)
	var paused_clock: float = backdrop.clock
	backdrop.advance_ambient(1.0)
	assert(is_equal_approx(paused_clock, backdrop.clock))
	backdrop.set_ambient_enabled(true)
	backdrop.bird_wait = 0.0
	backdrop.advance_ambient(0.02)
	assert(backdrop.bird_active)
	var material: ShaderMaterial = backdrop.painting.material as ShaderMaterial
	assert(material.get_shader_parameter("bird_visible"))
	hub.town_menu.open_general()
	assert(hub.shop_backdrop.visible and not backdrop.visible)
	hub.town_menu.open_town()
	assert(not hub.shop_backdrop.visible and not backdrop.visible)
	preview.queue_free()
	await get_tree().process_frame

func test_particles_keep_source_coordinates_after_animation_and_refit() -> void:
	var preview: BlacksmithStorePreview = preload("res://tests/blacksmith_store_preview.tscn").instantiate() as BlacksmithStorePreview
	get_tree().root.add_child(preview)
	await get_tree().process_frame
	var backdrop: BlacksmithStoreBackdrop = preview.blacksmith_backdrop
	backdrop.set_process(false)
	for factor: float in [0.4, 0.765, 1.25]:
		backdrop.painting_factor = factor
		for sample: float in [0.0, 1.0, 9.0, 60.0]:
			backdrop.clock = sample
			backdrop._update_particles(backdrop.ember_sprites, true)
			backdrop._update_particles(backdrop.dust_sprites, false)
			for index: int in range(backdrop.ember_sprites.size()):
				var sprite: Sprite2D = backdrop.ember_sprites[index]
				var source: Vector2 = sprite.position / factor
				var rise: float = fposmod(sample * (12.0 + float(index % 3) * 3.0) + float(index) * 31.0, 110.0)
				var expected: Vector2 = backdrop.ember_source_positions[index] + Vector2(sin(sample * 1.7 + float(index) * 2.1) * 6.0, -rise)
				assert(source.is_equal_approx(expected))
				assert(Rect2(1230, 350, 145, 135).has_point(source))
			for sprite: Sprite2D in backdrop.dust_sprites:
				assert(Rect2(1100, 350, 260, 130).has_point(sprite.position / factor))
	backdrop._fit()
	var position_before: Vector2 = backdrop.ember_sprites[0].position
	backdrop._update_particles(backdrop.ember_sprites, true)
	assert(position_before.is_equal_approx(backdrop.ember_sprites[0].position))
	assert(is_equal_approx(backdrop.dust_sprites[0].scale.x, backdrop.painting_factor * BlacksmithStoreBackdrop.DUST_SIZE / 128.0))
	preview.free()

func test_backdrop_contained_for_aspect_ratios() -> void:
	for viewport_size: Vector2 in [Vector2(1280, 720), Vector2(1024, 768), Vector2(720, 1280)]:
		var rect: Rect2 = BlacksmithStoreBackdrop.image_rect(viewport_size)
		assert(rect.position.x >= -0.01 and rect.position.y >= -0.01)
		assert(rect.end.x <= viewport_size.x + 0.01 and rect.end.y <= viewport_size.y + 0.01)
		assert(is_equal_approx(rect.size.x / BlacksmithStoreBackdrop.SOURCE_SIZE.x, rect.size.y / BlacksmithStoreBackdrop.SOURCE_SIZE.y))
