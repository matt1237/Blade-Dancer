class_name KajiStoreBackgroundTest extends Node

func test_source_transform_preserves_anchors_across_aspects() -> void:
	for viewport_size: Vector2 in [Vector2(1280,720), Vector2(1920,1080), Vector2(1024,768), Vector2(2560,1080), Vector2(720,1280)]:
		var rect: Rect2 = KajiStoreBackdrop.image_rect(viewport_size)
		assert(is_equal_approx(rect.size.x/1672.0,rect.size.y/941.0))
		assert(rect.position.x >= -0.01 and rect.position.y >= -0.01)
		assert(rect.end.x <= viewport_size.x+0.01 and rect.end.y <= viewport_size.y+0.01)
		for source: Vector2 in [Vector2(1560,554),Vector2(1615,286),Vector2(943,108),Vector2(748,448)]:
			var mapped: Vector2 = rect.position + source * rect.size / KajiStoreBackdrop.SOURCE_SIZE
			assert(rect.has_point(mapped), "Enchanted objects must not be cropped")
			assert(((mapped-rect.position)/rect.size*KajiStoreBackdrop.SOURCE_SIZE).is_equal_approx(source))

func test_packed_preview_root_ready_attaches_backdrop_and_keeps_menu_synchronous() -> void:
	# The actual preview adds the hub during its own _ready, while its parent is busy.
	var preview: GeneralStorePreview = preload("res://tests/general_store_preview.tscn").instantiate() as GeneralStorePreview
	get_tree().root.add_child(preview)
	assert(preview.menu != null and preview.menu == preview.hub.town_menu)
	assert(preview.menu.general_page.visible and preview.menu.buy_page.visible)
	assert(preview.menu.progression == preview.progression)
	await get_tree().process_frame
	var backdrop: KajiStoreBackdrop = preview.hub.shop_backdrop
	assert(backdrop.get_parent() == preview)
	assert(backdrop.get_index() < preview.hub.get_index())
	assert(backdrop.visible and backdrop.painting.texture == KajiStoreBackdrop.ROOM)
	assert(preview.menu.general_page.size == get_viewport().get_visible_rect().size - Vector2(32,32))
	assert(preview.menu.global_position == Vector2(16,16))
	preview.menu.sell_tab.pressed.emit()
	assert(preview.menu.sell_page.visible and not preview.menu.buy_page.visible)
	assert(backdrop.visible)
	preview.menu.buy_tab.pressed.emit()
	assert(preview.menu.buy_page.visible and not preview.menu.sell_page.visible)
	preview.menu.shop_back_button.pressed.emit()
	assert(not backdrop.visible and not preview.hub.has_theme_stylebox_override("panel"))
	assert(preview.menu.position == Vector2(44,164))
	preview.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(backdrop), "Sibling backdrop must be freed with the hub")

func test_exit_before_deferred_attachment_cleans_unattached_backdrop() -> void:
	var preview: GeneralStorePreview = preload("res://tests/general_store_preview.tscn").instantiate() as GeneralStorePreview
	get_tree().root.add_child(preview)
	var backdrop: KajiStoreBackdrop = preview.hub.shop_backdrop
	get_tree().root.remove_child(preview)
	preview.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert(not is_instance_valid(backdrop))

func test_canonical_navigation_and_ancestor_hide_restore_backdrop() -> void:
	var root: Control = Control.new()
	get_tree().root.add_child(root)
	var hub: EndRunHub = preload("res://scenes/ui/end_run_hub.tscn").instantiate() as EndRunHub
	root.add_child(hub)
	var progression: HomeProgression = HomeProgression.new()
	progression.add_material("Coins",180)
	progression.add_material("Forest Herb",8)
	hub.configure_town(progression,progression.sell_to_kaji,progression.buy_from_kaji)
	await get_tree().process_frame
	hub.show()
	hub.show_tab(EndRunHub.Tab.TOWN)
	assert(not hub.shop_backdrop.visible)
	hub.town_menu.open_general()
	assert(hub.shop_backdrop.visible)
	assert(hub.shop_backdrop.painting.texture == KajiStoreBackdrop.ROOM)
	assert(not hub.save_load_tab.visible)
	hub.town_menu._select_general_page(false)
	assert(hub.shop_backdrop.visible and hub.town_menu.sell_page.visible)
	hub.hide()
	assert(not hub.shop_backdrop.visible, "Hidden hub must not leave a sibling backdrop visible")
	hub.show()
	assert(hub.shop_backdrop.visible)
	hub.town_menu.open_blacksmiths()
	assert(not hub.shop_backdrop.visible and hub.blacksmith_backdrop.visible and not hub.save_load_tab.visible)
	hub.town_menu.open_general()
	hub.town_menu.open_town()
	assert(not hub.shop_backdrop.visible)
	assert(hub.town_menu.position == Vector2(44,164))
	hub.town_menu.open_general()
	hub.show_tab(EndRunHub.Tab.ADVENTURE)
	assert(not hub.shop_backdrop.visible)
	assert(hub.adventure_card.visible)
	assert(not hub.has_theme_stylebox_override("panel"))
	root.queue_free()
